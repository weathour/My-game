extends RefCounted

const COLOR_BACKDROP := Color(0.0, 0.0, 0.0, 0.72)
const COLOR_BG := Color(0.045, 0.052, 0.078, 0.98)
const COLOR_BG_SOFT := Color(0.075, 0.088, 0.13, 0.96)
const COLOR_BG_CARD := Color(0.11, 0.125, 0.18, 0.98)
const COLOR_BG_CARD_ALT := Color(0.085, 0.1, 0.15, 0.98)
const COLOR_BORDER := Color(0.36, 0.42, 0.58, 0.90)
const COLOR_BORDER_GOLD := Color(1.0, 0.76, 0.24, 1.0)
const COLOR_TEXT := Color(0.95, 0.97, 1.0, 1.0)
const COLOR_TEXT_MUTED := Color(0.78, 0.83, 0.94, 0.94)
const COLOR_TEXT_GOLD := Color(1.0, 0.88, 0.44, 1.0)
const COLOR_TEXT_GOOD := Color(0.42, 1.0, 0.58, 1.0)
const COLOR_DANGER := Color(0.84, 0.18, 0.18, 0.96)

const MODAL_MIN_SIZE := Vector2(330.0, 240.0)
const MODAL_DEFAULT_MAX_SIZE := Vector2(760.0, 500.0)
const CARD_HEIGHT := 86.0
const CARD_HEIGHT_COMPACT := 66.0
const BUTTON_HEIGHT := 48.0
const BUTTON_HEIGHT_COMPACT := 40.0

static func viewport_size(node: Node) -> Vector2:
	if node == null or node.get_viewport() == null:
		return Vector2(1280.0, 720.0)
	return node.get_viewport().get_visible_rect().size

static func is_compact_size(size_value: Vector2) -> bool:
	return size_value.x < 620.0 or size_value.y < 420.0

static func scaled_font(base_size: int, viewport: Vector2, compact_delta: int = -2) -> int:
	var scale_value: float = clamp(min(viewport.x / 1280.0, viewport.y / 720.0), 0.78, 1.08)
	var font_size := int(round(float(base_size) * scale_value))
	if viewport.x < 900.0 or viewport.y < 560.0:
		font_size += compact_delta
	return max(10, font_size)

static func panel_style(
	bg_color: Color = COLOR_BG,
	border_color: Color = COLOR_BORDER_GOLD,
	border_width: int = 2,
	corner_radius: int = 16,
	content_margin: float = 0.0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	if content_margin > 0.0:
		style.set_content_margin(SIDE_LEFT, content_margin)
		style.set_content_margin(SIDE_TOP, content_margin)
		style.set_content_margin(SIDE_RIGHT, content_margin)
		style.set_content_margin(SIDE_BOTTOM, content_margin)
	return style

static func card_style(selected: bool = false, accented: bool = false, disabled: bool = false) -> StyleBoxFlat:
	var bg := COLOR_BG_CARD
	var border := COLOR_BORDER
	var border_width := 1
	if accented:
		bg = Color(0.07, 0.16, 0.10, 0.98)
		border = Color(0.30, 0.95, 0.44, 0.92)
		border_width = 2
	if selected:
		bg = Color(0.30, 0.22, 0.08, 0.98)
		border = COLOR_BORDER_GOLD
		border_width = 2
	if disabled:
		bg = bg.darkened(0.28)
		border = border.darkened(0.30)
	return panel_style(bg, border, border_width, 12, 10.0)

static func card_hover_style(selected: bool = false, accented: bool = false) -> StyleBoxFlat:
	var style := card_style(selected, accented, false)
	style.bg_color = style.bg_color.lightened(0.08)
	style.border_color = style.border_color.lightened(0.10)
	return style

static func card_pressed_style(selected: bool = false, accented: bool = false) -> StyleBoxFlat:
	var style := card_style(selected, accented, false)
	style.bg_color = style.bg_color.darkened(0.08)
	return style

static func action_button_style(kind: String = "normal", selected: bool = false) -> StyleBoxFlat:
	var bg := COLOR_BG_SOFT
	var border := COLOR_BORDER
	if kind == "primary" or selected:
		bg = Color(0.22, 0.17, 0.07, 0.98)
		border = COLOR_BORDER_GOLD
	elif kind == "danger":
		bg = COLOR_DANGER
		border = Color(1.0, 0.78, 0.78, 0.98)
	return panel_style(bg, border, 2 if (kind == "primary" or selected) else 1, 10, 8.0)

static func apply_button_style(button: Button, kind: String = "normal", selected: bool = false) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", action_button_style(kind, selected))
	var hover := action_button_style(kind, true if selected else false)
	hover.bg_color = hover.bg_color.lightened(0.08)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := action_button_style(kind, selected)
	pressed.bg_color = pressed.bg_color.darkened(0.08)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	var font_color := COLOR_TEXT_GOLD if (kind == "primary" or selected) else COLOR_TEXT
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color.lightened(0.10))
	button.add_theme_color_override("font_pressed_color", font_color.darkened(0.08))

static func apply_card_button_style(button: Button, selected: bool = false, accented: bool = false, disabled: bool = false) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", card_style(selected, accented, disabled))
	button.add_theme_stylebox_override("hover", card_hover_style(selected, accented))
	button.add_theme_stylebox_override("pressed", card_pressed_style(selected, accented))
	button.add_theme_stylebox_override("focus", card_hover_style(true, accented))
	var font_color := COLOR_TEXT
	if accented:
		font_color = COLOR_TEXT_GOOD
	if selected:
		font_color = COLOR_TEXT_GOLD
	if disabled:
		font_color = Color(0.58, 0.62, 0.70, 0.8)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color.lightened(0.10))
	button.add_theme_color_override("font_pressed_color", font_color.darkened(0.08))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.64, 0.70))

static func make_title_label(text_value: String, font_size: int = 26) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	return label

static func make_hint_label(text_value: String, font_size: int = 14) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

static func apply_label_font(label: Label, font_size: int, color: Color = COLOR_TEXT) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)

static func apply_rich_label_font(label: RichTextLabel, font_size: int) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_font_size_override("bold_font_size", font_size)
	label.add_theme_color_override("default_color", COLOR_TEXT)
	label.add_theme_stylebox_override("normal", panel_style(Color(0.02, 0.03, 0.05, 0.34), Color(0.22, 0.28, 0.40, 0.70), 1, 8, 8.0))
