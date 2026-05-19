extends Control

const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const SURVIVORS_HOVER_DETAIL := preload("res://scripts/ui/components/survivors_hover_detail.gd")
const SKILL_CD_SLOT_COUNT := 6
const SKILL_CD_SLOT_SIZE := 52.0
const ULTIMATE_WIDGET_SIZE := 108.0
const ULTIMATE_WIDGET_GAP := 18.0
const SWITCH_WIDGET_WIDTH := 176.0
const SWITCH_WIDGET_HEIGHT := 72.0
const SWITCH_WIDGET_GAP := 18.0
const SKILL_PANEL_WIDTH := 382.0
const COOLDOWN_REDRAW_EPSILON: float = 0.01
const ENERGY_REDRAW_EPSILON: float = 0.01
const SKETCH_TEXTURES := {
	"swordsman": preload("res://assets/sketch/人设草图/剑士草图.jpg"),
	"gunner": preload("res://assets/sketch/人设草图/枪手草图.jpg"),
	"mage": preload("res://assets/sketch/人设草图/术师草图.jpg")
}

class SkillCooldownIcon:
	extends Control

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

	func _ready() -> void:
		clip_contents = true
		cooldown_overlay = CooldownOverlay.new()
		cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cooldown_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		cooldown_overlay.offset_left = 0.0
		cooldown_overlay.offset_top = 0.0
		cooldown_overlay.offset_right = 0.0
		cooldown_overlay.offset_bottom = 0.0
		add_child(cooldown_overlay)
		cooldown_overlay.set_ratio(cooldown_ratio if unlocked else 0.0)

	func set_state(new_unlocked: bool, new_color: Color, new_cooldown_ratio: float) -> void:
		var resolved_ratio: float = clamp(new_cooldown_ratio, 0.0, 1.0)
		var visual_changed: bool = unlocked != new_unlocked or icon_color != new_color
		var ratio_changed: bool = abs(resolved_ratio - cooldown_ratio) > COOLDOWN_REDRAW_EPSILON
		if not visual_changed and not ratio_changed:
			return
		unlocked = new_unlocked
		icon_color = new_color
		cooldown_ratio = resolved_ratio
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

class SwitchPortraitDisplay:
	extends Control

	var role_texture: Texture2D
	var cooldown_ratio: float = 0.0

	func set_state(new_texture: Texture2D, new_ratio: float) -> void:
		var resolved_ratio: float = clamp(new_ratio, 0.0, 1.0)
		if role_texture == new_texture and abs(resolved_ratio - cooldown_ratio) <= COOLDOWN_REDRAW_EPSILON:
			return
		role_texture = new_texture
		cooldown_ratio = resolved_ratio
		queue_redraw()

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = min(size.x, size.y) * 0.5 - 4.0
		var inner_radius: float = radius - 5.0
		draw_circle(center, radius, Color(0.0, 0.0, 0.0, 0.94))
		draw_circle(center, inner_radius, Color(0.12, 0.13, 0.16, 0.98))

		if role_texture != null:
			var portrait_size: float = inner_radius * 1.34
			var portrait_rect := Rect2(center - Vector2.ONE * portrait_size * 0.5, Vector2.ONE * portrait_size)
			draw_texture_rect_region(role_texture, portrait_rect, Rect2(Vector2.ZERO, role_texture.get_size()), Color(1.0, 1.0, 1.0, 1.0), false)

		if cooldown_ratio > 0.01:
			_draw_cooldown_sector(center, inner_radius, cooldown_ratio)
		draw_arc(center, radius, 0.0, TAU, 32, Color(0.0, 0.0, 0.0, 1.0), 3.0)

	func _draw_cooldown_sector(center: Vector2, radius: float, ratio: float) -> void:
		var shade := Color(0.0, 0.0, 0.0, 0.66)
		if ratio >= 0.99:
			draw_circle(center, radius, shade)
			return
		var angle_total: float = TAU * ratio
		var steps: int = max(6, int(ceil(32.0 * ratio)))
		var points := PackedVector2Array()
		points.append(center)
		for step in range(steps + 1):
			var progress: float = float(step) / float(steps)
			var angle: float = -PI * 0.5 + angle_total * progress
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(points, shade)

class UltimateEnergyDisplay:
	extends Control

	var fill_ratio: float = 0.0
	var skill_name: String = ""

	func set_state(new_ratio: float) -> void:
		var resolved_ratio: float = clamp(new_ratio, 0.0, 1.0)
		if abs(resolved_ratio - fill_ratio) <= ENERGY_REDRAW_EPSILON:
			return
		fill_ratio = resolved_ratio
		queue_redraw()

	func set_skill_name(new_skill_name: String) -> void:
		if skill_name == new_skill_name:
			return
		skill_name = new_skill_name
		queue_redraw()

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = min(size.x, size.y) * 0.5 - 4.0
		var inner_radius: float = radius - 5.0
		draw_circle(center, radius, Color(0.0, 0.0, 0.0, 0.94))
		draw_circle(center, inner_radius, Color(0.08, 0.1, 0.16, 0.98))
		_draw_fill(center, inner_radius, fill_ratio)
		if fill_ratio >= 0.999:
			draw_circle(center, inner_radius, Color(0.32, 0.76, 1.0, 0.16))
		draw_arc(center, radius, 0.0, TAU, 32, Color(0.0, 0.0, 0.0, 1.0), 3.0)

		if skill_name != "":
			var font := get_theme_default_font()
			var font_size := 14
			var text_size := font.get_string_size(skill_name, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size)
			var text_position := center - text_size * 0.5 + Vector2(0.0, 3.0)
			draw_string(font, text_position + Vector2(1.0, 1.0), skill_name, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.95))
			draw_string(font, text_position, skill_name, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size, Color(1.0, 0.96, 0.72, 1.0))

	func _draw_fill(center: Vector2, radius: float, ratio: float) -> void:
		if ratio <= 0.0:
			return
		if ratio >= 0.999:
			draw_circle(center, radius, Color(0.24, 0.68, 1.0, 0.72))
			return

		var top_y: float = center.y + radius - radius * 2.0 * ratio
		var min_y: float = center.y - radius
		var max_y: float = center.y + radius
		var line_y: float = clamp(top_y, min_y, max_y)
		var y_ratio: float = clamp((line_y - center.y) / radius, -1.0, 1.0)
		var right_angle: float = asin(y_ratio)
		var left_angle: float = PI - right_angle
		var points := PackedVector2Array()
		var steps: int = 28
		for step in range(steps + 1):
			var progress: float = float(step) / float(steps)
			var angle: float = left_angle + (right_angle - left_angle) * progress
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(points, Color(0.22, 0.64, 1.0, 0.62))

		var line_offset: float = line_y - center.y
		if abs(line_offset) <= radius:
			var half_width_at_line: float = sqrt(max(radius * radius - line_offset * line_offset, 0.0))
			draw_line(
				Vector2(center.x - half_width_at_line, line_y),
				Vector2(center.x + half_width_at_line, line_y),
				Color(0.72, 0.9, 1.0, 0.75),
				2.0
			)

var switch_cd_left_key_label: Label
var switch_cd_right_key_label: Label
var switch_cd_time_label: Label
var switch_cd_portrait: SwitchPortraitDisplay
var skill_cd_slots: Array = []
var ultimate_energy_widget: UltimateEnergyDisplay
var ultimate_key_label: Label
var ultimate_current_energy: float = 0.0
var ultimate_required_energy: float = 100.0
var ultimate_display: Dictionary = {}
var experience_bar: ProgressBar
var experience_label: Label
var hover_detail: Control
var action_key_labels_ready: bool = false

func _ready() -> void:
	anchor_left = 0.5
	anchor_top = 1.0
	anchor_right = 0.5
	anchor_bottom = 1.0
	var total_width: float = SWITCH_WIDGET_WIDTH + SWITCH_WIDGET_GAP + SKILL_PANEL_WIDTH + ULTIMATE_WIDGET_GAP + ULTIMATE_WIDGET_SIZE
	offset_left = -total_width * 0.5
	offset_top = -128.0
	offset_right = total_width * 0.5
	offset_bottom = -10.0
	_build_widgets()
	hover_detail = SURVIVORS_HOVER_DETAIL.new()
	add_child(hover_detail)

func update_experience(current_experience: int, required_experience: int) -> void:
	if experience_bar != null:
		var resolved_required: int = max(required_experience, 1)
		if int(experience_bar.max_value) != resolved_required:
			experience_bar.max_value = resolved_required
		if int(experience_bar.value) != current_experience:
			experience_bar.value = current_experience
	if experience_label != null:
		var next_text: String = "%d / %d XP" % [current_experience, required_experience]
		if experience_label.text != next_text:
			experience_label.text = next_text

func update_switch_cooldown(role_id: String, cooldown_remaining: float, cooldown_duration: float) -> void:
	_refresh_switch_key_labels()
	if switch_cd_portrait == null:
		return
	var portrait_texture: Texture2D = null
	var texture_value: Variant = SKETCH_TEXTURES.get(role_id, null)
	if texture_value is Texture2D:
		portrait_texture = texture_value
	var duration: float = max(cooldown_duration, 0.01)
	var ratio: float = clamp(cooldown_remaining / duration, 0.0, 1.0)
	switch_cd_portrait.set_state(portrait_texture, ratio)
	if switch_cd_time_label != null:
		var next_text: String = "%.1f" % cooldown_remaining if cooldown_remaining > 0.05 else ""
		if switch_cd_time_label.text != next_text:
			switch_cd_time_label.text = next_text

func update_ultimate_energy(current_energy: float, required_energy: float, display_data: Dictionary = {}) -> void:
	_refresh_action_key_labels()
	ultimate_current_energy = max(current_energy, 0.0)
	ultimate_required_energy = max(required_energy, 1.0)
	ultimate_display = display_data.duplicate(true)
	if ultimate_energy_widget != null:
		ultimate_energy_widget.set_skill_name(str(ultimate_display.get("name", "大招")))
		ultimate_energy_widget.set_state(ultimate_current_energy / ultimate_required_energy)

func update_skill_cooldown_slots(slot_data_list: Array) -> void:
	for index in range(skill_cd_slots.size()):
		var slot_nodes: Dictionary = skill_cd_slots[index]
		var slot_view: SkillCooldownIcon = slot_nodes["view"] as SkillCooldownIcon
		var label: Label = slot_nodes["label"] as Label
		if index >= slot_data_list.size():
			slot_view.set_state(false, Color(0.12, 0.13, 0.16, 1.0), 0.0)
			if slot_view.tooltip_text != "":
				slot_view.tooltip_text = ""
			if label.text != "":
				label.text = ""
			if str(slot_nodes.get("title", "")) != "":
				slot_nodes["title"] = ""
			if str(slot_nodes.get("description", "")) != "":
				slot_nodes["description"] = ""
			if str(slot_nodes.get("slot_label", "")) != "":
				slot_nodes["slot_label"] = ""
			continue

		var slot_data: Dictionary = slot_data_list[index]
		var slot_color: Color = Color(1.0, 1.0, 1.0, 1.0)
		var color_value: Variant = slot_data.get("color", slot_color)
		if color_value is Color:
			slot_color = color_value
		var duration: float = max(float(slot_data.get("duration", 1.0)), 0.01)
		var remaining: float = clamp(float(slot_data.get("remaining", 0.0)), 0.0, duration)
		var ratio: float = remaining / duration
		slot_view.set_state(true, slot_color, ratio)
		var slot_name: String = str(slot_data.get("name", "OK"))
		if label.text != slot_name:
			label.text = slot_name
		if slot_view.tooltip_text != "":
			slot_view.tooltip_text = ""
		if str(slot_nodes.get("title", "")) != slot_name:
			slot_nodes["title"] = slot_name
		var next_description: String = _build_slot_tooltip(slot_data, duration, remaining)
		if str(slot_nodes.get("description", "")) != next_description:
			slot_nodes["description"] = next_description
		var next_slot_label: String = str(slot_data.get("slot_label", "技能冷却"))
		if str(slot_nodes.get("slot_label", "")) != next_slot_label:
			slot_nodes["slot_label"] = next_slot_label

func _build_widgets() -> void:
	var switch_cd_widget := HBoxContainer.new()
	switch_cd_widget.position = Vector2(0.0, 0.0)
	switch_cd_widget.custom_minimum_size = Vector2(SWITCH_WIDGET_WIDTH, SWITCH_WIDGET_HEIGHT)
	switch_cd_widget.add_theme_constant_override("separation", 8)
	add_child(switch_cd_widget)

	var left_arrow_box := Control.new()
	left_arrow_box.custom_minimum_size = Vector2(38.0, SWITCH_WIDGET_HEIGHT)
	switch_cd_widget.add_child(left_arrow_box)

	var left_arrow_label := Label.new()
	left_arrow_label.text = "<"
	left_arrow_label.position = Vector2(0.0, 17.0)
	left_arrow_label.custom_minimum_size = Vector2(38.0, 32.0)
	left_arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_arrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left_arrow_label.add_theme_font_size_override("font_size", 28)
	left_arrow_label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98, 1.0))
	left_arrow_box.add_child(left_arrow_label)

	switch_cd_left_key_label = Label.new()
	switch_cd_left_key_label.position = Vector2(0.0, 47.0)
	switch_cd_left_key_label.custom_minimum_size = Vector2(38.0, 22.0)
	switch_cd_left_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	switch_cd_left_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	switch_cd_left_key_label.add_theme_font_size_override("font_size", 16)
	left_arrow_box.add_child(switch_cd_left_key_label)

	switch_cd_portrait = SwitchPortraitDisplay.new()
	switch_cd_portrait.size = Vector2(72.0, 72.0)
	switch_cd_portrait.custom_minimum_size = Vector2(72.0, 72.0)
	switch_cd_widget.add_child(switch_cd_portrait)

	switch_cd_time_label = Label.new()
	switch_cd_time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	switch_cd_time_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	switch_cd_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	switch_cd_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	switch_cd_time_label.add_theme_font_size_override("font_size", 15)
	switch_cd_time_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	switch_cd_time_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	switch_cd_time_label.add_theme_constant_override("shadow_offset_x", 1)
	switch_cd_time_label.add_theme_constant_override("shadow_offset_y", 1)
	switch_cd_time_label.text = ""
	switch_cd_portrait.add_child(switch_cd_time_label)

	var right_arrow_box := Control.new()
	right_arrow_box.custom_minimum_size = Vector2(38.0, SWITCH_WIDGET_HEIGHT)
	switch_cd_widget.add_child(right_arrow_box)

	var right_arrow_label := Label.new()
	right_arrow_label.text = ">"
	right_arrow_label.position = Vector2(0.0, 17.0)
	right_arrow_label.custom_minimum_size = Vector2(38.0, 32.0)
	right_arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_arrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right_arrow_label.add_theme_font_size_override("font_size", 28)
	right_arrow_label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98, 1.0))
	right_arrow_box.add_child(right_arrow_label)

	switch_cd_right_key_label = Label.new()
	switch_cd_right_key_label.position = Vector2(0.0, 47.0)
	switch_cd_right_key_label.custom_minimum_size = Vector2(38.0, 22.0)
	switch_cd_right_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	switch_cd_right_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	switch_cd_right_key_label.add_theme_font_size_override("font_size", 16)
	right_arrow_box.add_child(switch_cd_right_key_label)

	var skill_cd_panel := HBoxContainer.new()
	skill_cd_panel.position = Vector2(SWITCH_WIDGET_WIDTH + SWITCH_WIDGET_GAP, 10.0)
	skill_cd_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_cd_panel.add_theme_constant_override("separation", 14)
	add_child(skill_cd_panel)

	for index in range(SKILL_CD_SLOT_COUNT):
		var slot_icon := SkillCooldownIcon.new()
		slot_icon.custom_minimum_size = Vector2(SKILL_CD_SLOT_SIZE, SKILL_CD_SLOT_SIZE)
		slot_icon.set_state(false, Color(0.12, 0.13, 0.16, 1.0), 0.0)
		slot_icon.tooltip_text = ""
		slot_icon.mouse_entered.connect(_on_skill_slot_hovered.bind(slot_icon, index))
		slot_icon.mouse_exited.connect(_on_skill_slot_unhovered)
		skill_cd_panel.add_child(slot_icon)

		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.text = ""
		slot_icon.add_child(label)

		skill_cd_slots.append({
			"view": slot_icon,
			"label": label,
			"title": "",
			"description": "",
			"slot_label": ""
		})

	ultimate_energy_widget = UltimateEnergyDisplay.new()
	ultimate_energy_widget.position = Vector2(SWITCH_WIDGET_WIDTH + SWITCH_WIDGET_GAP + SKILL_PANEL_WIDTH + ULTIMATE_WIDGET_GAP, -18.0)
	ultimate_energy_widget.size = Vector2(ULTIMATE_WIDGET_SIZE, ULTIMATE_WIDGET_SIZE)
	ultimate_energy_widget.custom_minimum_size = Vector2(ULTIMATE_WIDGET_SIZE, ULTIMATE_WIDGET_SIZE)
	ultimate_energy_widget.set_state(0.0)
	ultimate_energy_widget.tooltip_text = ""
	ultimate_energy_widget.mouse_entered.connect(_on_ultimate_energy_hovered)
	ultimate_energy_widget.mouse_exited.connect(_on_skill_slot_unhovered)
	add_child(ultimate_energy_widget)

	ultimate_key_label = Label.new()
	ultimate_key_label.position = ultimate_energy_widget.position + Vector2(0.0, ULTIMATE_WIDGET_SIZE - 4.0)
	ultimate_key_label.custom_minimum_size = Vector2(ULTIMATE_WIDGET_SIZE, 24.0)
	ultimate_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ultimate_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ultimate_key_label.add_theme_font_size_override("font_size", 16)
	ultimate_key_label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98, 1.0))
	ultimate_key_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	ultimate_key_label.add_theme_constant_override("shadow_offset_x", 1)
	ultimate_key_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(ultimate_key_label)

	experience_bar = ProgressBar.new()
	experience_bar.position = Vector2(SWITCH_WIDGET_WIDTH + SWITCH_WIDGET_GAP, 78.0)
	experience_bar.custom_minimum_size = Vector2(SKILL_PANEL_WIDTH, 14.0)
	experience_bar.show_percentage = false
	var exp_fill := StyleBoxFlat.new()
	exp_fill.bg_color = Color(1.0, 0.82, 0.16, 0.95)
	exp_fill.set_corner_radius_all(5)
	var exp_background := StyleBoxFlat.new()
	exp_background.bg_color = Color(0.12, 0.1, 0.04, 0.82)
	exp_background.border_color = Color(0.92, 0.72, 0.16, 0.9)
	exp_background.set_border_width_all(1)
	exp_background.set_corner_radius_all(5)
	experience_bar.add_theme_stylebox_override("fill", exp_fill)
	experience_bar.add_theme_stylebox_override("background", exp_background)
	add_child(experience_bar)

	experience_label = Label.new()
	experience_label.position = Vector2(SWITCH_WIDGET_WIDTH + SWITCH_WIDGET_GAP, 72.0)
	experience_label.custom_minimum_size = Vector2(SKILL_PANEL_WIDTH, 26.0)
	experience_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	experience_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	experience_label.add_theme_font_size_override("font_size", 13)
	experience_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.62, 1.0))
	experience_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	experience_label.add_theme_constant_override("shadow_offset_x", 1)
	experience_label.add_theme_constant_override("shadow_offset_y", 1)
	experience_label.text = "0 / 30 XP"
	add_child(experience_label)

	_refresh_action_key_labels()

func _build_slot_tooltip(slot_data: Dictionary, duration: float, remaining: float) -> String:
	var description := str(slot_data.get("description", ""))
	var status := "剩余 %.1f / %.1f 秒" % [remaining, duration] if remaining > 0.05 else "冷却就绪"
	if description == "":
		description = status
	else:
		description = "%s\n%s" % [description, status]
	return description

func _on_skill_slot_hovered(slot_icon: Control, index: int) -> void:
	if index < 0 or index >= skill_cd_slots.size():
		return
	var slot_nodes: Dictionary = skill_cd_slots[index]
	var title := str(slot_nodes.get("title", ""))
	if title == "":
		title = "技能"
	var description := str(slot_nodes.get("description", ""))
	if description == "":
		return
	var item := {
		"title": title,
		"slot_label": str(slot_nodes.get("slot_label", "技能冷却")),
		"description": description
	}
	if hover_detail != null and hover_detail.has_method("show_item"):
		hover_detail.show_item(item, get_viewport().get_mouse_position(), Rect2(slot_icon.global_position, slot_icon.size))

func _on_ultimate_energy_hovered() -> void:
	if ultimate_energy_widget == null:
		return
	var ultimate_key := ""
	if ultimate_key_label != null:
		ultimate_key = ultimate_key_label.text
	if ultimate_key == "":
		ultimate_key = GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_ULTIMATE))
	var status := "已充满，可以按 %s 释放大招。" % ultimate_key if ultimate_current_energy >= ultimate_required_energy else "还需 %.0f 点能量。" % max(0.0, ultimate_required_energy - ultimate_current_energy)
	var ultimate_name := str(ultimate_display.get("name", "大招"))
	var ultimate_description := str(ultimate_display.get("description", "当前英雄的大招。"))
	var item := {
		"title": ultimate_name,
		"slot_label": "大招 / 能量",
		"description": "%s\n\n能量 %.0f / %.0f。\n%s\n攻击命中与战斗节奏会积累大招能量，充满后释放当前角色的大招。" % [
			ultimate_description,
			ultimate_current_energy,
			ultimate_required_energy,
			status
		]
	}
	if hover_detail != null and hover_detail.has_method("show_item"):
		hover_detail.show_item(item, get_viewport().get_mouse_position(), Rect2(ultimate_energy_widget.global_position, ultimate_energy_widget.size))

func _on_skill_slot_unhovered() -> void:
	if hover_detail != null:
		if hover_detail.has_method("request_hide"):
			hover_detail.request_hide()
		elif hover_detail.has_method("hide_detail"):
			hover_detail.hide_detail()

func _refresh_switch_key_labels() -> void:
	_refresh_action_key_labels()

func _refresh_action_key_labels(force: bool = false) -> void:
	if action_key_labels_ready and not force:
		return
	if switch_cd_left_key_label != null:
		switch_cd_left_key_label.text = GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_SWITCH_PREV))
	if switch_cd_right_key_label != null:
		switch_cd_right_key_label.text = GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_SWITCH_NEXT))
	if ultimate_key_label != null:
		ultimate_key_label.text = GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_ULTIMATE))
	action_key_labels_ready = true
