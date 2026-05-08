extends RefCounted

const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")

const NOTICE_LAYER_NAME := "BlessingUnlockNoticeLayer"
const NOTICE_DURATION := 3.6
const NOTICE_FADE_SECONDS := 0.18
const NOTICE_MAX_WIDTH := 560.0
const NOTICE_MIN_WIDTH := 320.0


static func show_notice(main: Node, event: Dictionary) -> void:
	if main == null or not bool(event.get("consumes_blessing_material", false)):
		return
	var layer := _get_or_create_layer(main)
	if layer == null:
		return
	var popup := _build_popup(main, event, layer.get_child_count())
	layer.add_child(popup)
	_play_notice_animation(popup)


static func _get_or_create_layer(main: Node) -> CanvasLayer:
	var existing := main.get_node_or_null(NOTICE_LAYER_NAME) as CanvasLayer
	if existing != null:
		return existing
	var layer := CanvasLayer.new()
	layer.name = NOTICE_LAYER_NAME
	layer.layer = 8
	layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	main.add_child(layer)
	return layer


static func _build_popup(main: Node, event: Dictionary, stack_index: int) -> Panel:
	var viewport_size: Vector2 = SURVIVORS_THEME.viewport_size(main)
	var max_width: float = min(NOTICE_MAX_WIDTH, viewport_size.x - 32.0)
	var width: float = clampf(viewport_size.x * 0.44, NOTICE_MIN_WIDTH, max_width)
	var material_lines: Array = _get_material_lines(event)
	var height: float = 128.0 + float(min(material_lines.size(), 4)) * 22.0
	var panel := Panel.new()
	panel.name = "BlessingUnlockNotice"
	panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = Vector2(width, height)
	panel.position = Vector2(max(16.0, (viewport_size.x - width) * 0.5), 28.0 + float(stack_index) * 14.0)
	panel.add_theme_stylebox_override("panel", SURVIVORS_THEME.panel_style(Color(0.055, 0.075, 0.105, 0.97), Color(0.42, 1.0, 0.72, 0.94), 2, 14, 10.0))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)

	var action_text := "解锁" if str(event.get("action", "unlock")) == "unlock" else "进化"
	var title_label := SURVIVORS_THEME.make_title_label("祝福材料已消耗", 19)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOOD)
	content.add_child(title_label)

	var skill_label := SURVIVORS_THEME.make_hint_label("%s：%s" % [action_text, str(event.get("title", "技能"))], 15)
	skill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	skill_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT)
	content.add_child(skill_label)

	var body_label := SURVIVORS_THEME.make_hint_label(_build_body_text(material_lines), 13)
	body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	content.add_child(body_label)
	return panel


static func _get_material_lines(event: Dictionary) -> Array:
	var material_lines: Array = []
	var material_variant: Variant = event.get("material_lines", [])
	if material_variant is Array:
		material_lines = material_variant
	return material_lines


static func _build_body_text(material_lines: Array) -> String:
	if material_lines.is_empty():
		return "本次技能配方已锁定对应祝福材料；这些材料仍保留数值加成，但不会再重复用于其他技能解锁。"
	var shown_lines: Array[String] = []
	for index in range(min(4, material_lines.size())):
		shown_lines.append("· %s" % str(material_lines[index]))
	if material_lines.size() > shown_lines.size():
		shown_lines.append("· 其余材料已一并锁定")
	return "已锁定材料：\n%s" % "\n".join(shown_lines)


static func _play_notice_animation(popup: Control) -> void:
	if popup == null:
		return
	popup.modulate.a = 0.0
	var tween := popup.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(popup, "modulate:a", 1.0, NOTICE_FADE_SECONDS)
	tween.tween_interval(NOTICE_DURATION)
	tween.tween_property(popup, "modulate:a", 0.0, NOTICE_FADE_SECONDS)
	tween.tween_callback(popup.queue_free)
