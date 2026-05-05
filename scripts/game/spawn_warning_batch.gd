extends Node2D

signal warning_finished(entry: Dictionary)

const CROSS_COLOR := Color(1.0, 0.08, 0.06, 0.92)
const FILL_COLOR := Color(1.0, 0.08, 0.04, 0.18)
const CROSS_WIDTH := 5.0
const FLASH_COUNT := 4
const FLASH_DURATION := 0.11
const FADE_DURATION := 0.06

var warnings: Array[Dictionary] = []

func _ready() -> void:
	add_to_group("temporary_effects")
	z_index = 18

func add_warning(warning_position: Vector2, radius: float, payload: Dictionary) -> void:
	warnings.append({
		"position": warning_position,
		"radius": max(8.0, radius),
		"age": 0.0,
		"payload": payload
	})
	queue_redraw()

func _process(delta: float) -> void:
	if warnings.is_empty():
		queue_redraw()
		return
	var total_duration := FLASH_COUNT * FLASH_DURATION * 2.0 + FADE_DURATION
	var finished_entries: Array[Dictionary] = []
	for index in range(warnings.size() - 1, -1, -1):
		var warning: Dictionary = warnings[index]
		warning["age"] = float(warning.get("age", 0.0)) + delta
		if float(warning.get("age", 0.0)) >= total_duration:
			finished_entries.append(warning)
			warnings.remove_at(index)
		else:
			warnings[index] = warning
	for warning in finished_entries:
		warning_finished.emit(warning)
	queue_redraw()

func _draw() -> void:
	for warning in warnings:
		var alpha := _get_alpha(float(warning.get("age", 0.0)))
		if alpha <= 0.01:
			continue
		var warning_position: Vector2 = warning.get("position", Vector2.ZERO)
		var radius := float(warning.get("radius", 24.0))
		var fill_color := FILL_COLOR
		var cross_color := CROSS_COLOR
		fill_color.a *= alpha
		cross_color.a *= alpha
		draw_circle(warning_position, radius * 0.72, fill_color)
		draw_line(warning_position + Vector2(-radius, -radius), warning_position + Vector2(radius, radius), cross_color, CROSS_WIDTH)
		draw_line(warning_position + Vector2(-radius, radius), warning_position + Vector2(radius, -radius), cross_color, CROSS_WIDTH)

func _get_alpha(age: float) -> float:
	var flash_span := FLASH_DURATION * 2.0
	var active_duration := FLASH_COUNT * flash_span
	if age >= active_duration:
		return lerpf(0.16, 0.0, clamp((age - active_duration) / FADE_DURATION, 0.0, 1.0))
	var flash_progress := fmod(age, flash_span) / flash_span
	if flash_progress < 0.5:
		return lerpf(0.0, 1.0, flash_progress * 2.0)
	return lerpf(1.0, 0.16, (flash_progress - 0.5) * 2.0)
