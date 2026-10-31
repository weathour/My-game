extends Control

const COOLDOWN_REDRAW_EPSILON: float = 0.01
const AUTO_BORDER_SPIN_SPEED := 0.85

class CooldownOverlay:
	extends Control

	var cooldown_ratio: float = 0.0

	func set_ratio(new_ratio: float) -> void:
		var resolved_ratio: float = clamp(new_ratio, 0.0, 1.0)
		if abs(resolved_ratio - cooldown_ratio) <= COOLDOWN_REDRAW_EPSILON:
			return
		cooldown_ratio = resolved_ratio
		queue_redraw()

	func _draw() -> void:
		if cooldown_ratio <= 0.01:
			return
		var shade := Color(0.0, 0.0, 0.0, 0.68)
		var inner_rect := Rect2(Vector2(5.0, 5.0), size - Vector2(10.0, 10.0))
		if cooldown_ratio >= 0.99:
			draw_rect(inner_rect, shade, true)
			return

		var center := inner_rect.get_center()
		var radius: float = max(inner_rect.size.x, inner_rect.size.y) * 0.82
		var angle_total: float = TAU * cooldown_ratio
		var steps: int = max(8, int(ceil(32.0 * cooldown_ratio)))
		var points := PackedVector2Array()
		points.append(center)
		for step in range(steps + 1):
			var progress: float = float(step) / float(steps)
			var angle: float = -PI * 0.5 + angle_total * progress
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(points, shade)

var icon_color: Color = Color(0.28, 0.3, 0.34, 1.0)
var cooldown_ratio: float = 0.0
var unlocked: bool = false
var cooldown_overlay: CooldownOverlay
var auto_mode: bool = false
var _auto_border_spin: float = 0.0
var skill_point_highlighted: bool = false
var skill_point_highlight: Panel

func _ready() -> void:
	# The upgrade button sits above the icon; only clip the cooldown sweep.
	clip_contents = false
	cooldown_overlay = CooldownOverlay.new()
	cooldown_overlay.clip_contents = true
	cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	cooldown_overlay.offset_left = 0.0
	cooldown_overlay.offset_top = 0.0
	cooldown_overlay.offset_right = 0.0
	cooldown_overlay.offset_bottom = 0.0
	add_child(cooldown_overlay)
	cooldown_overlay.set_ratio(cooldown_ratio if unlocked else 0.0)
	skill_point_highlight = Panel.new()
	skill_point_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_point_highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skill_point_highlight.z_index = 3
	var highlight_style := StyleBoxFlat.new()
	highlight_style.bg_color = Color(1.0, 0.8, 0.05, 0.015)
	highlight_style.border_color = Color(1.0, 0.83, 0.25, 0.6)
	highlight_style.set_border_width_all(1)
	skill_point_highlight.add_theme_stylebox_override("panel", highlight_style)
	skill_point_highlight.visible = skill_point_highlighted
	add_child(skill_point_highlight)
	_update_processing()

func set_skill_point_highlighted(enabled: bool) -> void:
	if skill_point_highlighted == enabled:
		return
	skill_point_highlighted = enabled
	if skill_point_highlight != null:
		skill_point_highlight.visible = enabled

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_update_processing()

func _update_processing() -> void:
	set_process(auto_mode and unlocked and is_visible_in_tree())

func set_auto_mode(enabled: bool) -> void:
	if auto_mode == enabled:
		return
	auto_mode = enabled
	_update_processing()
	queue_redraw()

func _process(delta: float) -> void:
	if not auto_mode:
		return
	_auto_border_spin = fmod(_auto_border_spin + delta * AUTO_BORDER_SPIN_SPEED, TAU)
	queue_redraw()

func _border_point(rect: Rect2, progress: float) -> Vector2:
	var normalized_progress := fmod(progress, TAU) / TAU
	var width: float = max(1.0, rect.size.x)
	var height: float = max(1.0, rect.size.y)
	var perimeter: float = (width + height) * 2.0
	var distance: float = normalized_progress * perimeter
	if distance < width:
		return rect.position + Vector2(distance, 0.0)
	distance -= width
	if distance < height:
		return rect.position + Vector2(width, distance)
	distance -= height
	if distance < width:
		return rect.position + Vector2(width - distance, height)
	distance -= width
	return rect.position + Vector2(0.0, height - distance)

func _draw_auto_border_glow(rect: Rect2) -> void:
	var span := 0.22
	var segments := 9
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for index in range(segments + 1):
		var step_progress: float = _auto_border_spin * TAU + span * TAU * float(index) / float(segments)
		var fade: float = 1.0 - float(index) / float(segments)
		points.append(_border_point(rect, step_progress))
		colors.append(Color(0.55, 0.92, 1.0, 0.9 * fade))
	if points.size() >= 2:
		draw_polyline_colors(points, colors, 3.0)
	draw_circle(_border_point(rect, _auto_border_spin * TAU), 2.6, Color(0.92, 0.99, 1.0, 0.95))

func set_state(new_unlocked: bool, new_color: Color, new_cooldown_ratio: float) -> void:
	var resolved_ratio: float = clamp(new_cooldown_ratio, 0.0, 1.0)
	var visual_changed: bool = unlocked != new_unlocked or icon_color != new_color
	var ratio_changed: bool = abs(resolved_ratio - cooldown_ratio) > COOLDOWN_REDRAW_EPSILON
	if not visual_changed and not ratio_changed:
		return
	unlocked = new_unlocked
	icon_color = new_color
	cooldown_ratio = resolved_ratio
	_update_processing()
	if cooldown_overlay != null:
		cooldown_overlay.set_ratio(cooldown_ratio if unlocked else 0.0)
	if visual_changed:
		queue_redraw()

func _draw() -> void:
	var outer_rect := Rect2(Vector2.ZERO, size)
	var inner_rect := outer_rect.grow(-5.0)
	var frame_color := Color(0.88, 0.9, 0.96, 0.9) if unlocked else Color(0.34, 0.36, 0.42, 0.82)
	var base_color := icon_color if unlocked else Color(0.12, 0.13, 0.16, 0.92)

	draw_rect(outer_rect, Color(0.04, 0.05, 0.07, 0.86), true)
	draw_rect(inner_rect, base_color, true)
	if not unlocked:
		draw_rect(inner_rect, Color(0.0, 0.0, 0.0, 0.42), true)
	draw_rect(outer_rect.grow(-1.0), frame_color, false, 2.0)
	if auto_mode and unlocked:
		_draw_auto_border_glow(outer_rect.grow(-1.5))
