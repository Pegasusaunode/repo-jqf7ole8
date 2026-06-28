extends Control
## Classic 4-line crosshair drawn in code.

@export var gap := 5.0
@export var length := 10.0
@export var thickness := 2.0
@export var color := Color(0.2, 1.0, 0.4, 0.9)
@export var dot := false


func _draw() -> void:
	var c := size * 0.5
	# left, right, up, down
	draw_line(c + Vector2(-gap, 0), c + Vector2(-gap - length, 0), color, thickness)
	draw_line(c + Vector2(gap, 0), c + Vector2(gap + length, 0), color, thickness)
	draw_line(c + Vector2(0, -gap), c + Vector2(0, -gap - length), color, thickness)
	draw_line(c + Vector2(0, gap), c + Vector2(0, gap + length), color, thickness)
	if dot:
		draw_circle(c, thickness, color)
