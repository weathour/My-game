extends RefCounted
## Rance-inspired dark materials, inset borders and restrained reused metalwork.
const FONT := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const INK := Color("eee5ce")
const PAPER := Color("1d3229")
const MUTED := Color("bcbba7")
const DARK := Color("111e19")
const LIGHT := Color("f4ebd5")
const OLIVE := Color("40513a")
const RED := Color("9c4d3e")
const BLUE := Color("527b89")
const GOLD := Color("dfc187")
const BORDER := Color("8d774e")

static func box(color: Color, border: Color = BORDER, pad: float = 16.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.border_width_bottom = 2
	style.set_corner_radius_all(1)
	style.content_margin_left = pad
	style.content_margin_right = pad
	style.content_margin_top = pad
	style.content_margin_bottom = pad
	return style

static func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font = FONT.get_reading_font()
	result.default_font_size = 16
	result.set_color("font_color", "Label", INK)
	result.set_color("font_color", "Button", INK)
	result.set_color("font_hover_color", "Button", INK)
	result.set_color("font_pressed_color", "Button", LIGHT)
	result.set_color("font_focus_color", "Button", INK)
	result.set_color("font_disabled_color", "Button", Color("aaa58c"))
	result.set_stylebox("normal", "Button", box(Color("293e31"), BORDER, 10))
	result.set_stylebox("hover", "Button", box(Color("42553f"), GOLD, 10))
	result.set_stylebox("pressed", "Button", box(Color("592e28"), GOLD, 10))
	result.set_stylebox("disabled", "Button", box(Color("263029"), Color("5a604e"), 10))
	var focus := box(Color.TRANSPARENT, Color("efd491"), 0)
	focus.set_border_width_all(3)
	result.set_stylebox("focus", "Button", focus)
	result.set_stylebox("panel", "PanelContainer", box(PAPER))
	result.set_stylebox("normal", "LineEdit", box(Color("14241d"), BORDER, 8))
	result.set_stylebox("focus", "LineEdit", box(Color("213a2b"), GOLD, 8))
	result.set_color("font_color", "LineEdit", INK)
	result.set_color("caret_color", "LineEdit", INK)
	result.set_color("font_placeholder_color", "LineEdit", MUTED)
	result.set_color("font_color", "OptionButton", LIGHT)
	result.set_color("font_hover_color", "OptionButton", LIGHT)
	result.set_stylebox("normal", "OptionButton", box(Color("293e31"), BORDER, 10))
	result.set_stylebox("hover", "OptionButton", box(Color("42553f"), GOLD, 10))
	result.set_stylebox("focus", "OptionButton", focus)
	result.set_stylebox("panel", "PopupMenu", box(DARK, BORDER, 8))
	result.set_color("font_color", "PopupMenu", LIGHT)
	result.set_stylebox("hover", "PopupMenu", box(OLIVE, GOLD, 5))
	result.set_constant("separation", "VBoxContainer", 10)
	result.set_constant("separation", "HBoxContainer", 10)
	return result

static func label(value: String, size: int = 16, color: Color = INK, serif: bool = false) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	if serif:
		result.add_theme_font_override("font", FONT.get_heading_font())
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func paragraph(value: String, color: Color = MUTED, size: int = 16) -> Label:
	var result := label(value, size, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result

static func button(value: String, action: Callable, primary: bool = false) -> Button:
	var result := Button.new()
	result.text = value
	result.custom_minimum_size.y = 42
	result.add_theme_constant_override("outline_size", 1)
	result.add_theme_color_override("font_outline_color", Color("090e0a"))
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.pressed.connect(action)
	if primary:
		result.add_theme_stylebox_override("normal", box(Color("592e28"), GOLD, 10))
		result.add_theme_color_override("font_color", LIGHT)
		result.add_theme_color_override("font_focus_color", LIGHT)
		FONT.apply_campaign_frame(result, "button")
	return result

static func compact_button(button: Button) -> void:
	for key in ["normal", "hover", "pressed", "disabled"]:
		var style := button.get_theme_stylebox(key).duplicate() as StyleBoxFlat
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		button.add_theme_stylebox_override(key, style)
	button.add_theme_font_size_override("font_size", 14)
	button.custom_minimum_size.y = 32

static func quiet_button(value: String, action: Callable, selected: bool = false) -> Button:
	## Context navigation and local tabs yield visual priority to the page artwork.
	var result := Button.new()
	result.text = value
	result.custom_minimum_size.y = 38
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.pressed.connect(action)
	result.add_theme_color_override("font_color", LIGHT if selected else INK)
	result.add_theme_color_override("font_hover_color", LIGHT)
	result.add_theme_color_override("font_focus_color", LIGHT)
	result.add_theme_color_override("font_pressed_color", GOLD)
	result.add_theme_color_override("font_disabled_color", MUTED)
	for key in ["normal", "hover", "pressed", "disabled"]:
		var active: bool = selected or key == "pressed"
		var fill := Color("2a352c") if active else Color("243129") if key == "hover" else Color(0, 0, 0, 0)
		var surface := box(fill, Color.TRANSPARENT, 12)
		surface.set_border_width_all(0)
		surface.content_margin_top = 6
		surface.content_margin_bottom = 6
		if active:
			surface.border_color = GOLD
			surface.border_width_bottom = 2
		result.add_theme_stylebox_override(key, surface)
	var focus := box(Color.TRANSPARENT, GOLD, 0)
	focus.set_border_width_all(1)
	result.add_theme_stylebox_override("focus", focus)
	return result

static func panel(parent: Node, dark: bool = false, pad: float = 18, decorated: bool = true) -> PanelContainer:
	var result := PanelContainer.new()
	result.add_theme_stylebox_override("panel", box(DARK if dark else PAPER, BORDER, pad))
	parent.add_child(result)
	if decorated: FONT.apply_campaign_frame(result, "panel")
	return result

static func column(parent: Node) -> VBoxContainer:
	var result := VBoxContainer.new()
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(result)
	return result

static func row(parent: Node) -> HBoxContainer:
	var result := HBoxContainer.new()
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(result)
	return result

static func space(parent: Node) -> Control:
	var result := Control.new()
	result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(result)
	return result

static func bar(parent: Node, value: float, maximum: float, color: Color) -> ProgressBar:
	var result := ProgressBar.new()
	result.max_value = maxf(1, maximum)
	result.value = value
	result.show_percentage = false
	result.custom_minimum_size.y = 6
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_stylebox_override("background", box(Color("0d1713"), Color.TRANSPARENT, 0))
	result.add_theme_stylebox_override("fill", box(color, Color.TRANSPARENT, 0))
	parent.add_child(result)
	return result
