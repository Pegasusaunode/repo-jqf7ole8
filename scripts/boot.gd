extends Node
## Registers all input actions in code so the game does not depend on a
## hand-authored InputMap inside project.godot.

func _enter_tree() -> void:
	_key("move_forward", KEY_W)
	_key("move_back", KEY_S)
	_key("move_left", KEY_A)
	_key("move_right", KEY_D)
	_key("jump", KEY_SPACE)
	_key("crouch", KEY_CTRL, KEY_C)
	_key("walk", KEY_SHIFT)
	_key("reload", KEY_R)
	_key("slot1", KEY_1)
	_key("slot2", KEY_2)
	_key("restart", KEY_F5)
	_key("toggle_mouse", KEY_ESCAPE)

	_mouse("fire", MOUSE_BUTTON_LEFT)
	_mouse("scope", MOUSE_BUTTON_RIGHT)
	_mouse("weapon_next", MOUSE_BUTTON_WHEEL_UP)
	_mouse("weapon_prev", MOUSE_BUTTON_WHEEL_DOWN)


func _key(action: String, keycode: int, alt_keycode: int = -1) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)
	if alt_keycode != -1:
		var ev2 := InputEventKey.new()
		ev2.physical_keycode = alt_keycode
		InputMap.action_add_event(action, ev2)


func _mouse(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
