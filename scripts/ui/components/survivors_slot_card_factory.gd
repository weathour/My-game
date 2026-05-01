extends RefCounted

const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")

static func build_card(
	title_text: String,
	description_text: String,
	action_text: String,
	pressed_callback: Callable,
	min_height: float = 160.0,
	selected: bool = false,
	disabled: bool = false
) -> Button:
	var card := Button.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, min_height)
	card.disabled = disabled
	card.clip_contents = true
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	SURVIVORS_THEME.apply_card_button_style(card, selected, false, disabled)
	if pressed_callback.is_valid():
		card.pressed.connect(pressed_callback)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD if selected else SURVIVORS_THEME.COLOR_TEXT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)

	var detail := Label.new()
	detail.text = description_text
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_font_size_override("font_size", 16)
	detail.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(detail)

	var action := Label.new()
	action.text = action_text
	action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action.add_theme_font_size_override("font_size", 17)
	action.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD if not disabled else Color(0.55, 0.58, 0.64, 0.72))
	action.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(action)

	return card

static func apply_delete_button_style(delete_button: Button) -> void:
	SURVIVORS_THEME.apply_button_style(delete_button, "danger")
