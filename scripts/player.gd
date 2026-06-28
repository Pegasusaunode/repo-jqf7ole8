extends Fighter
class_name Player
## First-person player controller.

const GRAVITY := 24.0
const SPEED := 5.6
const WALK_SPEED := 2.6
const CROUCH_SPEED := 2.0
const JUMP_VELOCITY := 8.0
const MOUSE_SENS := 0.0024
const STAND_CAM_Y := 1.6
const CROUCH_CAM_Y := 1.05

var head: Node3D
var camera: Camera3D
var weapon_holder: Node3D
var viewmodel: Node3D

var hud: Node = null
var scoped := false
var crouching := false
var _recoil := 0.0          # current extra pitch from recoil
var _base_fov := 75.0


func _ready() -> void:
	super._ready()
	display_name = "YOU"
	# Local player does not render its own full body / marker.
	if body_model:
		body_model.visible = false
	if team_marker:
		team_marker.visible = false

	head = Node3D.new()
	head.name = "Head"
	head.position.y = STAND_CAM_Y
	add_child(head)

	camera = Camera3D.new()
	camera.fov = _base_fov
	camera.current = true
	head.add_child(camera)

	weapon_holder = Node3D.new()
	weapon_holder.name = "WeaponHolder"
	weapon_holder.position = Vector3(0.28, -0.26, -0.6)
	camera.add_child(weapon_holder)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_equip_viewmodel()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and alive:
		var sens := MOUSE_SENS
		if scoped:
			sens *= 0.45
		rotate_y(-event.relative.x * sens)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * sens, -1.5, 1.5)
	if event.is_action_pressed("toggle_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	process_timers(delta)
	# Recover recoil smoothly.
	if _recoil > 0.0:
		var recover: float = min(_recoil, delta * 6.0)
		_recoil -= recover
		head.rotation.x -= recover
	_update_scope(delta)
	if hud:
		hud.update_from_player(self)


func _physics_process(delta: float) -> void:
	if not alive:
		velocity = Vector3.ZERO
		return
	_handle_movement(delta)
	_handle_actions()


func _handle_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	crouching = Input.is_action_pressed("crouch")
	var target_cam_y := CROUCH_CAM_Y if crouching else STAND_CAM_Y
	head.position.y = lerpf(head.position.y, target_cam_y, delta * 12.0)

	var speed := SPEED
	if crouching:
		speed = CROUCH_SPEED
	elif Input.is_action_pressed("walk"):
		speed = WALK_SPEED

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if dir:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
	move_and_slide()


func _handle_actions() -> void:
	if Input.is_action_just_pressed("fire"):
		_try_shoot()
	if Input.is_action_just_pressed("reload"):
		start_reload()
	if Input.is_action_just_pressed("slot1"):
		switch_to(0)
	if Input.is_action_just_pressed("slot2"):
		switch_to(1)
	if Input.is_action_just_pressed("weapon_next"):
		switch_to(current_index + 1)
	if Input.is_action_just_pressed("weapon_prev"):
		switch_to(current_index - 1)


func _is_moving() -> bool:
	return Vector2(velocity.x, velocity.z).length() > 0.5


func _try_shoot() -> void:
	if not can_fire():
		if alive and ammo[current_index] <= 0 and not reloading:
			start_reload()
		return
	var w := current_weapon()
	var dir := -camera.global_transform.basis.z
	# Spread cone.
	var spread_deg: float = w.base_spread
	if _is_moving():
		spread_deg += w.move_spread
	if scoped:
		spread_deg *= 0.15
	dir = _apply_spread(dir, spread_deg)
	var res := fire_hitscan(camera.global_position, dir)
	# Recoil kick.
	var kick: float = deg_to_rad(w.recoil)
	_recoil += kick
	head.rotation.x += kick
	if hud:
		if res.killed:
			hud.show_kill()
		elif res.hit:
			hud.show_hitmarker(res.head)


func _apply_spread(dir: Vector3, spread_deg: float) -> Vector3:
	if spread_deg <= 0.001:
		return dir.normalized()
	var rad := deg_to_rad(spread_deg)
	var yaw := randf_range(-rad, rad)
	var pitch := randf_range(-rad, rad)
	var basis := Basis(camera.global_transform.basis)
	var d := basis * Vector3(0, 0, -1)
	d = d.rotated(basis * Vector3.UP, yaw)
	d = d.rotated(basis * Vector3.RIGHT, pitch)
	return d.normalized()


func switch_to(index: int) -> void:
	if weapons.is_empty():
		return
	index = wrapi(index, 0, weapons.size())
	if index == current_index:
		return
	current_index = index
	reloading = false
	scoped = false
	camera.fov = _base_fov
	_equip_viewmodel()


func _equip_viewmodel() -> void:
	if viewmodel and is_instance_valid(viewmodel):
		viewmodel.queue_free()
	viewmodel = null
	var w := current_weapon()
	if w == null:
		return
	var m := _load_model(w.model_path)
	if m == null:
		return
	weapon_holder.add_child(m)
	_normalize_viewmodel(m, w)
	viewmodel = m


func _normalize_viewmodel(m: Node3D, w: WeaponData) -> void:
	var aabb := _model_aabb(m)
	var longest: float = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
	if longest > 0.0001:
		var target := 0.5 if not w.is_sniper else 0.85
		var s: float = target / longest
		m.scale = Vector3(s, s, s)
	# Kenney blasters point toward +X; rotate so the barrel faces forward (-Z).
	m.rotation_degrees = Vector3(0, -90, 0)


func _update_scope(_delta: float) -> void:
	var w := current_weapon()
	var want_scope := false
	if w and w.is_sniper and Input.is_action_pressed("scope") and alive:
		want_scope = true
	if want_scope != scoped:
		scoped = want_scope
		camera.fov = w.scope_fov if scoped else _base_fov
		if viewmodel:
			viewmodel.visible = not scoped
	if hud:
		hud.set_scope(scoped)


func respawn(pos: Vector3, look_yaw: float) -> void:
	super.respawn(pos, look_yaw)
	scoped = false
	_recoil = 0.0
	if camera:
		camera.fov = _base_fov
	if head:
		head.rotation.x = 0.0
	_equip_viewmodel()
	if body_model:
		body_model.visible = false
	if team_marker:
		team_marker.visible = false
