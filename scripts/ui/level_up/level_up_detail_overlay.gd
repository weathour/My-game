extends Control

signal focus_pressed

var focus_blur: ColorRect
var detail_panel: PanelContainer
var detail_title_label: Label
var detail_final_card_button: Button
var detail_desc_label: RichTextLabel
var final_progress_panel: PanelContainer
var final_progress_title_label: Label
var final_progress_list: VBoxContainer
var glossary_panel: PanelContainer
var glossary_title_label: Label
var glossary_desc_label: RichTextLabel
var detail_slot_id: String = ""
var detail_glossary_terms: Dictionary = {}
var detail_final_card_data: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_focus_blur()
	_build_detail_panel()
	_build_final_progress_panel()
	_build_glossary_panel()
	hide_all()

func show_detail(slot_id: String, option: Dictionary, source_button: Button) -> void:
	detail_slot_id = slot_id
	detail_glossary_terms.clear()
	detail_final_card_data = {
		"name": str(option.get("final_card_name", "")),
		"title": str(option.get("final_card_title", "")),
		"requirements": option.get("final_card_requirements", [])
	}
	for entry in option.get("glossary_terms", []):
		if entry is Dictionary:
			detail_glossary_terms[str(entry.get("term", ""))] = entry

	detail_title_label.text = str(option.get("title", "Build"))
	detail_final_card_button.text = str(detail_final_card_data.get("name", ""))
	detail_final_card_button.visible = detail_final_card_button.text != ""
	detail_desc_label.text = _decorate_glossary_terms(_build_detail_text(option))
	detail_panel.visible = true
	detail_panel.set_meta("slot_id", slot_id)
	hide_final_progress()
	hide_glossary()
	call_deferred("_position_detail_panel", source_button)


func _build_detail_text(option: Dictionary) -> String:
	var detail_text := str(option.get("detail_description", option.get("description", "")))
	var card_type_label := str(option.get("card_type_label", ""))
	if card_type_label != "":
		detail_text = "[color=#FFE08A]类型：%s[/color]\n%s" % [card_type_label, detail_text]
	var role_effect_text := _format_role_effects(option)
	if role_effect_text != "" and not _contains_role_effect_section(detail_text):
		detail_text = "%s\n\n%s" % [detail_text, role_effect_text]
	return detail_text


func _format_role_effects(option: Dictionary) -> String:
	var role_effects: Array = option.get("role_effects", [])
	if role_effects.is_empty():
		return ""
	var section_title := "三英雄对应效果 / 数值" if role_effects.size() == 3 else "队伍英雄对应效果 / 数值"
	var lines: Array[String] = ["[color=#A9C8FF]%s[/color]" % section_title]
	for effect in role_effects:
		if effect is not Dictionary:
			continue
		lines.append("[color=#FFE08A]%s｜%s[/color]" % [str(effect.get("role_name", "")), str(effect.get("title", ""))])
		for line in effect.get("lines", []):
			lines.append("  • " + str(line))
	return "\n".join(lines)


func _contains_role_effect_section(text_value: String) -> bool:
	return text_value.contains("三英雄对应效果 / 数值") or text_value.contains("队伍英雄对应效果 / 数值")

func hide_all() -> void:
	hide_detail()
	hide_final_progress()
	hide_glossary()
	set_focus_visible(false)

func hide_detail() -> void:
	if detail_panel != null:
		detail_panel.visible = false
	detail_slot_id = ""
	detail_glossary_terms.clear()
	detail_final_card_data.clear()
	if detail_final_card_button != null:
		detail_final_card_button.visible = false
		detail_final_card_button.text = ""
	hide_final_progress()

func hide_final_progress() -> void:
	if final_progress_panel != null:
		final_progress_panel.visible = false

func hide_glossary() -> void:
	if glossary_panel != null:
		glossary_panel.visible = false

func has_visible_overlay() -> bool:
	return (detail_panel != null and detail_panel.visible) or (glossary_panel != null and glossary_panel.visible) or (final_progress_panel != null and final_progress_panel.visible)

func set_focus_visible(should_show: bool) -> void:
	if focus_blur != null:
		focus_blur.visible = should_show

func get_visible_rects() -> Array:
	var rects: Array = []
	if detail_panel != null and detail_panel.visible:
		rects.append(detail_panel.get_global_rect())
	if glossary_panel != null and glossary_panel.visible:
		rects.append(glossary_panel.get_global_rect())
	if final_progress_panel != null and final_progress_panel.visible:
		rects.append(final_progress_panel.get_global_rect())
	return rects

func _build_focus_blur() -> void:
	focus_blur = ColorRect.new()
	focus_blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	focus_blur.visible = false
	focus_blur.mouse_filter = Control.MOUSE_FILTER_STOP
	focus_blur.material = _create_focus_blur_material()
	focus_blur.gui_input.connect(_on_focus_blur_gui_input)
	add_child(focus_blur)

func _build_detail_panel() -> void:
	detail_panel = PanelContainer.new()
	detail_panel.visible = false
	detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(detail_panel)

	var detail_box := VBoxContainer.new()
	detail_box.custom_minimum_size = Vector2(320, 0)
	detail_box.add_theme_constant_override("separation", 10)
	detail_panel.add_child(detail_box)

	var detail_header := HBoxContainer.new()
	detail_header.add_theme_constant_override("separation", 12)
	detail_box.add_child(detail_header)

	detail_title_label = Label.new()
	detail_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_title_label.add_theme_font_size_override("font_size", 20)
	detail_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_header.add_child(detail_title_label)

	detail_final_card_button = Button.new()
	detail_final_card_button.flat = true
	detail_final_card_button.visible = false
	detail_final_card_button.text = ""
	detail_final_card_button.add_theme_font_size_override("font_size", 16)
	detail_final_card_button.modulate = Color(0.98, 0.88, 0.48, 1.0)
	detail_final_card_button.mouse_entered.connect(_show_final_progress)
	detail_final_card_button.focus_exited.connect(hide_final_progress)
	detail_final_card_button.pressed.connect(_show_final_progress)
	detail_header.add_child(detail_final_card_button)

	detail_desc_label = RichTextLabel.new()
	detail_desc_label.bbcode_enabled = true
	detail_desc_label.fit_content = true
	detail_desc_label.scroll_active = false
	detail_desc_label.custom_minimum_size = Vector2(360, 140)
	detail_desc_label.add_theme_font_size_override("normal_font_size", 16)
	detail_desc_label.meta_clicked.connect(_on_detail_meta_clicked)
	detail_box.add_child(detail_desc_label)

func _build_final_progress_panel() -> void:
	final_progress_panel = PanelContainer.new()
	final_progress_panel.visible = false
	final_progress_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(final_progress_panel)

	var progress_box := VBoxContainer.new()
	progress_box.custom_minimum_size = Vector2(280, 0)
	progress_box.add_theme_constant_override("separation", 8)
	final_progress_panel.add_child(progress_box)

	final_progress_title_label = Label.new()
	final_progress_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	final_progress_title_label.add_theme_font_size_override("font_size", 18)
	progress_box.add_child(final_progress_title_label)

	final_progress_list = VBoxContainer.new()
	final_progress_list.add_theme_constant_override("separation", 6)
	progress_box.add_child(final_progress_list)

func _build_glossary_panel() -> void:
	glossary_panel = PanelContainer.new()
	glossary_panel.visible = false
	glossary_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(glossary_panel)

	var glossary_box := VBoxContainer.new()
	glossary_box.custom_minimum_size = Vector2(320, 0)
	glossary_box.add_theme_constant_override("separation", 10)
	glossary_panel.add_child(glossary_box)

	glossary_title_label = Label.new()
	glossary_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	glossary_title_label.add_theme_font_size_override("font_size", 20)
	glossary_box.add_child(glossary_title_label)

	glossary_desc_label = RichTextLabel.new()
	glossary_desc_label.bbcode_enabled = true
	glossary_desc_label.fit_content = true
	glossary_desc_label.scroll_active = false
	glossary_desc_label.custom_minimum_size = Vector2(320, 120)
	glossary_desc_label.add_theme_font_size_override("normal_font_size", 16)
	glossary_box.add_child(glossary_desc_label)

func _position_detail_panel(source_button: Button) -> void:
	if source_button == null or detail_panel == null or not detail_panel.visible:
		return
	detail_panel.size = detail_panel.get_combined_minimum_size()
	var button_rect := source_button.get_global_rect()
	var viewport_rect := get_viewport().get_visible_rect()
	var target_x := button_rect.position.x + button_rect.size.x + 14.0
	var target_y := button_rect.position.y + button_rect.size.y * 0.5 - detail_panel.size.y * 0.5
	if target_x + detail_panel.size.x > viewport_rect.end.x - 12.0:
		target_x = button_rect.position.x - detail_panel.size.x - 14.0
	target_x = clamp(target_x, viewport_rect.position.x + 12.0, viewport_rect.end.x - detail_panel.size.x - 12.0)
	target_y = clamp(target_y, viewport_rect.position.y + 12.0, viewport_rect.end.y - detail_panel.size.y - 12.0)
	detail_panel.global_position = Vector2(target_x, target_y)

func _decorate_glossary_terms(text: String) -> String:
	var decorated := text
	for term in detail_glossary_terms.keys():
		var term_text := str(term)
		if term_text == "":
			continue
		var tag := "[url=term:%s][u][color=#6DB3FF]%s[/color][/u][/url]" % [term_text, term_text]
		decorated = decorated.replace(term_text, tag)
	return decorated

func _on_detail_meta_clicked(meta: Variant) -> void:
	var meta_text := str(meta)
	if not meta_text.begins_with("term:"):
		return
	_show_glossary(meta_text.trim_prefix("term:"))

func _show_glossary(term: String) -> void:
	if not detail_glossary_terms.has(term):
		return
	var entry: Dictionary = detail_glossary_terms.get(term, {})
	glossary_title_label.text = str(entry.get("title", term))
	glossary_desc_label.text = "%s\n\n[color=#A9C8FF]每层效果[/color]\n%s" % [
		str(entry.get("description", "")),
		str(entry.get("per_level", ""))
	]
	glossary_panel.set_meta("slot_id", detail_slot_id)
	glossary_panel.visible = true
	call_deferred("_position_glossary_panel")

func _show_final_progress() -> void:
	if detail_final_card_data.is_empty():
		return
	final_progress_title_label.text = str(detail_final_card_data.get("title", ""))
	for child in final_progress_list.get_children():
		child.queue_free()
	for requirement in detail_final_card_data.get("requirements", []):
		if requirement is not Dictionary:
			continue
		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false
		label.custom_minimum_size = Vector2(250, 0)
		label.add_theme_font_size_override("normal_font_size", 16)
		var current_level := int(requirement.get("current_level", 0))
		var max_level := int(requirement.get("max_level", 0))
		var level_parts: Array[String] = []
		for level in range(1, max_level + 1):
			var text := "LV%d" % level
			if level <= current_level:
				text = "[color=#FFE08A]%s[/color]" % text
			else:
				text = "[color=#6E7380]%s[/color]" % text
			level_parts.append(text)
		label.text = "%s %s" % [str(requirement.get("label", "")), " / ".join(level_parts)]
		final_progress_list.add_child(label)
	final_progress_panel.visible = true
	final_progress_panel.set_meta("slot_id", detail_slot_id)
	call_deferred("_position_final_progress_panel")

func _position_final_progress_panel() -> void:
	if final_progress_panel == null or not final_progress_panel.visible or detail_panel == null or not detail_panel.visible:
		return
	final_progress_panel.size = final_progress_panel.get_combined_minimum_size()
	var detail_rect := detail_panel.get_global_rect()
	var viewport_rect := get_viewport().get_visible_rect()
	var target_x := detail_rect.end.x + 14.0
	var target_y := detail_rect.position.y
	if glossary_panel != null and glossary_panel.visible:
		target_y = glossary_panel.get_global_rect().end.y + 12.0
	if target_x + final_progress_panel.size.x > viewport_rect.end.x - 12.0:
		target_x = detail_rect.position.x - final_progress_panel.size.x - 14.0
	target_x = clamp(target_x, viewport_rect.position.x + 12.0, viewport_rect.end.x - final_progress_panel.size.x - 12.0)
	target_y = clamp(target_y, viewport_rect.position.y + 12.0, viewport_rect.end.y - final_progress_panel.size.y - 12.0)
	final_progress_panel.global_position = Vector2(target_x, target_y)

func _position_glossary_panel() -> void:
	if glossary_panel == null or not glossary_panel.visible or detail_panel == null or not detail_panel.visible:
		return
	glossary_panel.size = glossary_panel.get_combined_minimum_size()
	var detail_rect := detail_panel.get_global_rect()
	var viewport_rect := get_viewport().get_visible_rect()
	var target_x := detail_rect.end.x + 14.0
	var target_y := detail_rect.position.y
	if target_x + glossary_panel.size.x > viewport_rect.end.x - 12.0:
		target_x = detail_rect.position.x - glossary_panel.size.x - 14.0
	target_x = clamp(target_x, viewport_rect.position.x + 12.0, viewport_rect.end.x - glossary_panel.size.x - 12.0)
	target_y = clamp(target_y, viewport_rect.position.y + 12.0, viewport_rect.end.y - glossary_panel.size.y - 12.0)
	glossary_panel.global_position = Vector2(target_x, target_y)

func _create_focus_blur_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur_scale = 1.8;

void fragment() {
	vec2 pixel_size = 1.0 / vec2(textureSize(screen_texture, 0));
	vec3 accum = vec3(0.0);
	float total = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			vec2 dir = vec2(float(x), float(y));
			float weight = 1.0 / (1.0 + length(dir));
			accum += texture(screen_texture, SCREEN_UV + dir * pixel_size * blur_scale * 2.0).rgb * weight;
			total += weight;
		}
	}
	vec3 blurred = accum / max(total, 0.001);
	vec3 tinted = mix(blurred, vec3(0.05, 0.07, 0.10), 0.22);
	COLOR = vec4(tinted, 0.94);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _on_focus_blur_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		focus_pressed.emit()
