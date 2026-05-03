extends Node2D

signal finished

const CROSS_COLOR := Color(1.0, 0.08, 0.06, 0.92)
const FILL_COLOR := Color(1.0, 0.08, 0.04, 0.18)
const CROSS_RADIUS := 24.0
const CROSS_WIDTH := 5.0
const FLASH_COUNT := 4
const FLASH_DURATION := 0.11

var _radius: float = CROSS_RADIUS

func configure(radius: float = CROSS_RADIUS) -> void:
	_radius = max(8.0, radius)
	add_to_group("temporary_effects")
	z_index = 18
	modulate.a = 0.0
	queue_redraw()
	_play_warning()

func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius * 0.72, FILL_COLOR)
	draw_line(Vector2(-_radius, -_radius), Vector2(_radius, _radius), CROSS_COLOR, CROSS_WIDTH)
	draw_line(Vector2(-_radius, _radius), Vector2(_radius, -_radius), CROSS_COLOR, CROSS_WIDTH)

func _play_warning() -> void:
	var tween := create_tween()
	for _index in range(FLASH_COUNT):
		tween.tween_property(self, "modulate:a", 1.0, FLASH_DURATION)
		tween.tween_property(self, "modulate:a", 0.16, FLASH_DURATION)
	tween.tween_property(self, "modulate:a", 0.0, 0.06)
	tween.tween_callback(func() -> void:
		finished.emit()
		queue_free()
	)
