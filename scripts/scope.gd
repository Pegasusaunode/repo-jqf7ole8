extends Control
## Sniper scope overlay: darkened screen with a clear circle and fine cross.

func _draw() -> void:
	var c := size * 0.5
	var radius: float = min(size.x, size.y) * 0.42
	# Darken the four regions outside the scope circle (approximate vignette).
	var dark := Color(0, 0, 0, 0.85)
	draw_rect(Rect2(0, 0, size.x, c.y - radius), dark)
	draw_rect(Rect2(0, c.y + radius, size.x, c.y - radius), dark)
	draw_rect(Rect2(0, c.y - radius, c.x - radius, radius * 2.0), dark)
	draw_rect(Rect2(c.x + radius, c.y - radius, c.x - radius, radius * 2.0), dark)
	# Scope ring.
	draw_arc(c, radius, 0, TAU, 96, Color(0, 0, 0, 0.95), 3.0)
	# Fine cross.
	var line := Color(0, 0, 0, 0.9)
	draw_line(Vector2(c.x, 0), Vector2(c.x, size.y), line, 1.0)
	draw_line(Vector2(0, c.y), Vector2(size.x, c.y), line, 1.0)
