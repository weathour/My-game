extends Node2D

const BORDER_COLOR := Color(0.25, 0.78, 1.0, 0.72)
const FILL_COLOR := Color(0.08, 0.16, 0.22, 0.08)
const CORNER_COLOR := Color(1.0, 0.88, 0.42, 0.92)
const EDGE_WIDTH := 5.0
const CORNER_LENGTH := 92.0
const BATTLE_MAP_TEXTURE := preload("res://assets/maps/battle_map.png")

var _bounds := Rect2(Vector2(-1600.0, -900.0), Vector2(3200.0, 1800.0))

func configure(bounds: Rect2) -> void:
	_bounds = bounds
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(BATTLE_MAP_TEXTURE, _bounds, false)
	draw_rect(_bounds, FILL_COLOR, true)
	draw_rect(_bounds, BORDER_COLOR, false, EDGE_WIDTH)
	_draw_corners()

func _draw_corners() -> void:
	var left: float = _bounds.position.x
	var top: float = _bounds.position.y
	var right: float = _bounds.position.x + _bounds.size.x
	var bottom: float = _bounds.position.y + _bounds.size.y
	var length: float = minf(CORNER_LENGTH, minf(_bounds.size.x, _bounds.size.y) * 0.16)
	var width: float = EDGE_WIDTH + 2.0

	_draw_corner(Vector2(left, top), Vector2(left + length, top), Vector2(left, top + length), width)
	_draw_corner(Vector2(right, top), Vector2(right - length, top), Vector2(right, top + length), width)
	_draw_corner(Vector2(left, bottom), Vector2(left + length, bottom), Vector2(left, bottom - length), width)
	_draw_corner(Vector2(right, bottom), Vector2(right - length, bottom), Vector2(right, bottom - length), width)

func _draw_corner(origin: Vector2, horizontal_end: Vector2, vertical_end: Vector2, width: float) -> void:
	draw_line(origin, horizontal_end, CORNER_COLOR, width)
	draw_line(origin, vertical_end, CORNER_COLOR, width)
