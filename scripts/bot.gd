extends Fighter
class_name Bot
## Simple combat AI: acquire nearest visible enemy, face it, shoot, take cover-ish.

const GRAVITY := 24.0
const SPEED := 4.6
const EYE_HEIGHT := 1.55
const ENGAGE_RANGE := 70.0

var target: Fighter = null
var _retarget_timer := 0.0
var _reaction := 0.0
var _strafe_dir := 1.0
var _strafe_timer := 0.0
var skill := 0.8   # 0..1


func _ready() -> void:
	super._ready()
	add_to_group("bots")


func _physics_process(delta: float) -> void:
	if not alive:
		velocity = Vector3.ZERO
		return
	process_timers(delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	_retarget_timer -= delta
	if _retarget_timer <= 0.0 or target == null or not is_instance_valid(target) or not target.alive:
		_acquire_target()
		_retarget_timer = 0.4

	if target and is_instance_valid(target) and target.alive:
		_combat(delta)
	else:
		_wander(delta)

	move_and_slide()


func _acquire_target() -> void:
	var enemy_group := Teams.enemy_group_for(team)
	var best: Fighter = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(enemy_group):
		if n is Fighter and n.alive:
			var d: float = global_position.distance_to(n.global_position)
			if d < best_d:
				best_d = d
				best = n
	target = best
	if target:
		_reaction = lerpf(0.35, 0.08, skill)


func _eye() -> Vector3:
	return global_position + Vector3.UP * EYE_HEIGHT


func _target_point() -> Vector3:
	return target.global_position + Vector3.UP * (CAPSULE_HEIGHT * 0.6)


func _has_los() -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(_eye(), _target_point(), LAYER_WORLD, [get_rid()])
	q.collide_with_bodies = true
	var hit := space.intersect_ray(q)
	return hit.is_empty()


func _combat(delta: float) -> void:
	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0
	var dist := to_target.length()

	# Face the target.
	if to_target.length() > 0.01:
		var desired_yaw := atan2(-to_target.x, -to_target.z)
		rotation.y = lerp_angle(rotation.y, desired_yaw, delta * 8.0)

	var los := _has_los()

	# Movement: keep at a comfortable range and strafe when in a firefight.
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(0.6, 1.6)
		_strafe_dir = 1.0 if randf() > 0.5 else -1.0

	var move := Vector3.ZERO
	var fwd := -global_transform.basis.z
	var right := global_transform.basis.x
	if not los or dist > ENGAGE_RANGE:
		move = fwd                      # close in / chase
	elif dist < 8.0:
		move = -fwd * 0.6               # back off if too close
	else:
		move = right * _strafe_dir      # strafe in the fight
	move.y = 0.0
	move = move.normalized() * SPEED
	velocity.x = move.x
	velocity.z = move.z

	# Shooting.
	if los and dist <= current_weapon().max_range:
		_reaction -= delta
		if _reaction <= 0.0:
			_try_bot_shoot()


func _wander(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, SPEED * delta * 4.0)
	velocity.z = move_toward(velocity.z, 0.0, SPEED * delta * 4.0)


func _try_bot_shoot() -> void:
	if not can_fire():
		if ammo[current_index] <= 0 and not reloading:
			start_reload()
		return
	var w := current_weapon()
	var dir: Vector3 = (_target_point() - _eye()).normalized()
	# Inaccuracy: worse when moving, better with skill.
	var err := deg_to_rad(lerpf(6.0, 0.6, skill * w.bot_accuracy))
	if _is_moving():
		err *= 1.8
	dir = dir.rotated(Vector3.UP, randf_range(-err, err))
	dir = dir.rotated(global_transform.basis.x, randf_range(-err, err))
	fire_hitscan(_eye(), dir)


func _is_moving() -> bool:
	return Vector2(velocity.x, velocity.z).length() > 0.5
