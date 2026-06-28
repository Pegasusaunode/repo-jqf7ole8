extends CharacterBody3D
class_name Fighter
## Base class shared by the Player and the Bots: health, weapons, hitscan.

signal died(victim: Fighter, attacker: Fighter)
signal damaged(victim: Fighter)

const CAPSULE_HEIGHT := 1.8
const CAPSULE_RADIUS := 0.4
const HEAD_FRACTION := 0.80   # above this fraction of height counts as a headshot

# Collision layers: 1 = world, 2 = characters
const LAYER_WORLD := 1
const LAYER_CHARS := 2

var team: int = Teams.Team.CT
var max_health := 100.0
var health := 100.0
var alive := true
var display_name := "Bot"

var weapons: Array[WeaponData] = []
var ammo: Array[int] = []
var reserve: Array[int] = []
var current_index := 0

var fire_cooldown := 0.0
var reloading := false
var reload_timer := 0.0

var body_model: Node3D
var team_marker: MeshInstance3D


func _ready() -> void:
	collision_layer = LAYER_CHARS
	collision_mask = LAYER_WORLD
	_build_collision()
	_build_body()


func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = CAPSULE_HEIGHT
	shape.radius = CAPSULE_RADIUS
	col.shape = shape
	col.position.y = CAPSULE_HEIGHT * 0.5
	add_child(col)


func _build_body() -> void:
	var holder := Node3D.new()
	holder.name = "BodyModel"
	add_child(holder)
	body_model = holder

	var model := _load_model("res://assets/arena/character-soldier.glb")
	if model:
		holder.add_child(model)
		_normalize_model(model, CAPSULE_HEIGHT)

	# Team indicator floating above the head.
	team_marker = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.18
	sph.height = 0.36
	team_marker.mesh = sph
	team_marker.position.y = CAPSULE_HEIGHT + 0.45
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Teams.color_for(team)
	team_marker.material_override = mat
	add_child(team_marker)


func _load_model(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path)
	if packed == null:
		return null
	return packed.instantiate()


## Scales/recenters a model so it is target_height tall with feet at y=0.
func _normalize_model(model: Node3D, target_height: float) -> void:
	var aabb := _model_aabb(model)
	if aabb.size.y <= 0.0001:
		return
	var s: float = target_height / aabb.size.y
	model.scale = Vector3(s, s, s)
	# After scaling, push feet to y=0 and center horizontally.
	model.position = Vector3(-aabb.position.x * s - aabb.size.x * s * 0.5, \
		-aabb.position.y * s, -aabb.position.z * s - aabb.size.z * s * 0.5)


func _model_aabb(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null:
			var box: AABB = mi.mesh.get_aabb()
			# transform relative to root node
			var rel: Transform3D = node.global_transform.affine_inverse() * mi.global_transform
			box = rel * box
			if first:
				result = box
				first = false
			else:
				result = result.merge(box)
		for c in n.get_children():
			if c is Node3D:
				stack.push_back(c)
	return result


func setup_loadout(loadout: Array[WeaponData]) -> void:
	weapons = loadout.duplicate()
	ammo.clear()
	reserve.clear()
	for w in weapons:
		ammo.append(w.magazine)
		reserve.append(w.reserve_ammo)
	current_index = 0


func current_weapon() -> WeaponData:
	if weapons.is_empty():
		return null
	return weapons[current_index]


func process_timers(delta: float) -> void:
	if fire_cooldown > 0.0:
		fire_cooldown -= delta
	if reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_finish_reload()


func start_reload() -> void:
	if reloading:
		return
	var w := current_weapon()
	if w == null:
		return
	if ammo[current_index] >= w.magazine or reserve[current_index] <= 0:
		return
	reloading = true
	reload_timer = w.reload_time


func _finish_reload() -> void:
	reloading = false
	var w := current_weapon()
	var need: int = w.magazine - ammo[current_index]
	var take: int = min(need, reserve[current_index])
	ammo[current_index] += take
	reserve[current_index] -= take


func can_fire() -> bool:
	if not alive or reloading:
		return false
	if fire_cooldown > 0.0:
		return false
	if ammo[current_index] <= 0:
		return false
	return true


## Performs a hitscan shot. Returns a dict describing the result.
func fire_hitscan(from: Vector3, dir: Vector3) -> Dictionary:
	var w := current_weapon()
	var result := {"hit": false, "killed": false, "head": false, "point": from}
	if w == null:
		return result
	fire_cooldown = 1.0 / w.fire_rate
	ammo[current_index] -= 1

	var space := get_world_3d().direct_space_state
	var to: Vector3 = from + dir.normalized() * w.max_range
	var q := PhysicsRayQueryParameters3D.create(from, to, LAYER_WORLD | LAYER_CHARS, [get_rid()])
	q.collide_with_bodies = true
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return result
	result.point = hit.position
	var collider = hit.collider
	if collider is Fighter and collider.alive and collider.team != team:
		var dmg: float = w.damage
		var head := false
		var local_y: float = hit.position.y - collider.global_position.y
		if local_y >= CAPSULE_HEIGHT * HEAD_FRACTION:
			dmg *= w.headshot_multiplier
			head = true
		var was_alive: bool = collider.alive
		collider.take_damage(dmg, self)
		result.hit = true
		result.head = head
		result.killed = was_alive and not collider.alive
	return result


func take_damage(amount: float, attacker: Fighter) -> void:
	if not alive:
		return
	health -= amount
	damaged.emit(self)
	if health <= 0.0:
		health = 0.0
		alive = false
		_set_dead_visual(true)
		died.emit(self, attacker)


func respawn(pos: Vector3, look_yaw: float) -> void:
	health = max_health
	alive = true
	velocity = Vector3.ZERO
	reloading = false
	fire_cooldown = 0.0
	global_position = pos
	rotation.y = look_yaw
	setup_loadout(Arsenal.default_loadout())
	_set_dead_visual(false)


func _set_dead_visual(dead: bool) -> void:
	visible = not dead
	# Disable collision while dead so corpses do not block shots/movement.
	set_collision_layer_value(2, not dead)
