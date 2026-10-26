extends RefCounted

const STYLE := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const BG := Color("#101a13")
const PANEL := Color("#182b20")
const TEXT := Color("#f3ead0")
const MUTED := Color("#c5b99b")
const GOLD := Color("#dfbd68")
const LINE := Color("#786138")
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
	STYLE.apply_button_style(button, "primary" if primary else "normal")
	button.add_theme_font_override("font", STYLE.get_reading_font())
	button.add_theme_font_size_override("font_size", 16)
	if quiet:
		button.add_theme_color_override("font_color", GOLD)
