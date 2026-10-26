extends RefCounted

const STYLE := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const BG := Color("#101923")
const PANEL := Color("#151f29")
const TEXT := Color("#ece9de")
const MUTED := Color("#b3bdc6")
const GOLD := Color("#d7bd86")
const LINE := Color("#3e4b56")
const CAMP := preload("res://assets/story/communications_camp.png")

static func add_backdrop(parent: Control, scene: String = "radio") -> TextureRect:
	var picture := TextureRect.new()
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture = CAMP
	# The same camp holds the clues: change the framing, not the story location.
	if scene in ["outpost", "rift"]:
		var crop := AtlasTexture.new()
		crop.atlas = CAMP
		var extent := CAMP.get_size()
		crop.region = Rect2(extent * Vector2(0.1, 0.1), extent * 0.9) if scene == "outpost" else Rect2(extent * Vector2(0.48, 0.23), extent * Vector2(0.52, 0.65))
		picture.texture = crop
	parent.add_child(picture)
	return picture

static func style_button(button: Button, primary: bool = false, quiet: bool = false) -> void:
	var fill := Color("#283544") if primary else PANEL
	if quiet:
		fill = Color.TRANSPARENT
	button.add_theme_font_override("font", STYLE.get_reading_font())
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", GOLD if primary else TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", TEXT)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", STYLE.panel_style(fill, GOLD if primary else LINE, 1 if not quiet else 0, 3, 12))
	button.add_theme_stylebox_override("hover", STYLE.panel_style(Color("#2b3946"), GOLD, 1, 3, 12))
	button.add_theme_stylebox_override("pressed", STYLE.panel_style(Color("#354352"), GOLD, 1, 3, 12))
	button.add_theme_stylebox_override("disabled", STYLE.panel_style(Color("#121b24"), LINE, 0, 3, 12))
	button.add_theme_stylebox_override("focus", STYLE.panel_style(Color.TRANSPARENT, GOLD, 2, 3))
