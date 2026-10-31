extends Node2D
## Visible missing-art marker. No behavior, damage, collision, or asset fallbacks.
func body_profile() -> Vector2:
	return Vector2(64, 0)

func set_moving(_moving: bool, _direction: Vector2) -> void:
	pass

func _draw() -> void:
	var outline := PackedVector2Array([Vector2(0,-64),Vector2(20,-32),Vector2(0,0),Vector2(-20,-32),Vector2(0,-64)])
	draw_colored_polygon(outline, Color("453e4c"))
	draw_polyline(outline, Color("d5a8d6"), 2, true)
	draw_line(Vector2(-7,-40),Vector2(7,-24),Color("f5d7f2"),2,true)
	draw_line(Vector2(7,-40),Vector2(-7,-24),Color("f5d7f2"),2,true)
