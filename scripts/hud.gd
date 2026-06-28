extends CanvasLayer
class_name HUD

var crosshair: Control
var scope_overlay: Control
var health_label: Label
var ammo_label: Label
var weapon_label: Label
var score_label: Label
var alive_label: Label
var message_label: Label
var hitmarker: Control
var help_label: Label

var _hit_time := 0.0
var _hit_head := false
var _kill_time := 0.0


func _ready() -> void:
	layer = 10
	crosshair = load("res://scripts/crosshair.gd").new()
	crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)

	scope_overlay = load("res://scripts/scope.gd").new()
	scope_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	scope_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope_overlay.visible = false
	add_child(scope_overlay)

	hitmarker = Control.new()
	hitmarker.set_anchors_preset(Control.PRESET_FULL_RECT)
	hitmarker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hitmarker.draw.connect(_draw_hitmarker)
	add_child(hitmarker)

	var vp := get_viewport().get_visible_rect().size

	health_label = _make_label(Vector2(28, vp.y - 70), Vector2(300, 44), HORIZONTAL_ALIGNMENT_LEFT, 34)
	ammo_label = _make_label(Vector2(vp.x - 280, vp.y - 70), Vector2(252, 44), HORIZONTAL_ALIGNMENT_RIGHT, 34)
	weapon_label = _make_label(Vector2(vp.x - 380, vp.y - 104), Vector2(352, 30), HORIZONTAL_ALIGNMENT_RIGHT, 22)

	score_label = _make_label(Vector2(0, 12), Vector2(vp.x, 38), HORIZONTAL_ALIGNMENT_CENTER, 28)
	score_label.text = "CT  0 : 0  T"
	alive_label = _make_label(Vector2(0, 52), Vector2(vp.x, 26), HORIZONTAL_ALIGNMENT_CENTER, 18)
	alive_label.text = "alive  CT 5 / T 5"

	message_label = _make_label(Vector2(0, vp.y * 0.34), Vector2(vp.x, 64), HORIZONTAL_ALIGNMENT_CENTER, 40)
	message_label.text = ""

	help_label = _make_label(Vector2(0, vp.y - 34), Vector2(vp.x, 26), HORIZONTAL_ALIGNMENT_CENTER, 15)
	help_label.text = "WASD move | Mouse look | LMB fire | RMB scope | Wheel/1/2 switch | R reload | Shift walk | Ctrl crouch | Esc mouse"


func _make_label(pos: Vector2, sz: Vector2, align: int, fsize: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	add_child(l)
	return l


func _process(delta: float) -> void:
	if _hit_time > 0.0:
		_hit_time -= delta
		hitmarker.queue_redraw()
	if _kill_time > 0.0:
		_kill_time -= delta
		if _kill_time <= 0.0 and message_label.text.begins_with("Eliminated"):
			message_label.text = ""


func update_from_player(p: Fighter) -> void:
	if not p.alive:
		health_label.text = "DEAD"
		health_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		return
	health_label.add_theme_color_override("font_color", Color.WHITE)
	health_label.text = "♥ %d" % int(round(p.health))
	if not p.weapons.is_empty():
		ammo_label.text = "%d / %d" % [p.ammo[p.current_index], p.reserve[p.current_index]]
		var w: WeaponData = p.weapons[p.current_index]
		weapon_label.text = w.name + ("  [RELOADING]" if p.reloading else "")


func set_scope(on: bool) -> void:
	scope_overlay.visible = on
	crosshair.visible = not on
	if on:
		scope_overlay.queue_redraw()


func show_hitmarker(head: bool) -> void:
	_hit_time = 0.18
	_hit_head = head
	hitmarker.queue_redraw()


func show_kill() -> void:
	_hit_time = 0.22
	_hit_head = true
	hitmarker.queue_redraw()


func _draw_hitmarker() -> void:
	if _hit_time <= 0.0:
		return
	var c := hitmarker.size * 0.5
	var col := Color(1, 0.25, 0.25) if _hit_head else Color(1, 1, 1)
	col.a = clampf(_hit_time / 0.18, 0.0, 1.0)
	var g := 7.0
	var l := 6.0
	for d in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		hitmarker.draw_line(c + d * g, c + d * (g + l), col, 2.0)


func set_score(ct: int, t: int) -> void:
	score_label.text = "CT  %d : %d  T" % [ct, t]


func set_alive(ct_alive: int, t_alive: int) -> void:
	alive_label.text = "alive  CT %d / T %d" % [ct_alive, t_alive]


func set_message(text: String) -> void:
	message_label.text = text


func flash_eliminated() -> void:
	message_label.text = "Eliminated!"
	_kill_time = 1.5
