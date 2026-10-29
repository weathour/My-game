extends Button
## One card is one focusable action. Art and dynamic text remain separate.
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const ART := preload("res://scripts/ui/chronicle/chronicle_portraits.gd")
const RARITY := preload("res://scripts/ui/chronicle/card_rarity.gd")
var character_id := ""
var character_name := ""
var subtitle := ""
var badge := ""
var selected_card := false
var selected_badge := "已选"
var compact := false
var important := false
var fallen := false
var rarity := "common"
var portrait: Texture2D

func configure(id: String, title: String, line: String, tag: String = "", chosen: bool = false, tier: String = "common") -> void:
	character_id = id
	character_name = title
	subtitle = line
	badge = tag
	selected_card = chosen
	rarity = tier
	portrait = ART.texture(id)
	tooltip_text = title + " · " + RARITY.style(rarity).label + "\n" + line
	queue_redraw()

func _ready() -> void:
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for key in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(key, StyleBoxEmpty.new())
	for event in [mouse_entered, mouse_exited, focus_entered, focus_exited]: event.connect(queue_redraw)
	resized.connect(queue_redraw)

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var style := RARITY.style(rarity)
	draw_rect(rect, Color("0c1914"))
	var footer := 46.0 if compact else 61.0
	var area := Rect2(5, 5, size.x - 10, size.y - footer - 5)
	draw_rect(area, style.field if not character_id.is_empty() else T.DARK)
	if portrait != null and area.size.y > 0:
		draw_texture_rect_region(portrait, area, portrait_source_rect(area.size), Color("777a72") if fallen else ART.tint(character_id))
	draw_rect(Rect2(5, size.y - footer, size.x - 10, footer - 5), style.footer)
	var edge: Color = T.LIGHT if selected_card or has_focus() else style.edge
	draw_rect(rect.grow(-1), edge, false, 2 if selected_card or has_focus() else 1)
	draw_rect(rect.grow(-4), style.edge.darkened(.35), false, 1)
	if is_hovered(): draw_rect(rect.grow(-6), Color(1, .91, .65, .06))
	# Small metal corner brackets preserve the card silhouette at thumbnail scale.
	for corner in [Vector2(3,3), Vector2(size.x-3,3), Vector2(3,size.y-3), size-Vector2(3,3)]:
		var direction := Vector2(1 if corner.x < size.x / 2 else -1, 1 if corner.y < size.y / 2 else -1)
		draw_line(corner, corner + Vector2(12 * direction.x, 0), edge, 2)
		draw_line(corner, corner + Vector2(0, 12 * direction.y), edge, 2)
	var title_size := 17 if compact else 23
	var title_font := T.FONT.get_heading_font()
	var title_width := title_font.get_string_size(character_name, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	if title_width > size.x - 16: title_size = maxi(13, int(title_size * (size.x - 16) / title_width))
	draw_string(title_font, Vector2(8, size.y - footer + (21 if compact else 29)), character_name, HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, title_size, T.LIGHT)
	draw_string(T.FONT.get_reading_font(), Vector2(8, size.y - 13), subtitle, HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 11 if compact else 13, T.GOLD)
	if not character_id.is_empty() and size.y >= 130:
		draw_rect(Rect2(5, size.y - footer - 19, size.x - 10, 19), style.footer)
		draw_string(T.FONT.get_reading_font(), Vector2(8, size.y - footer - 5), style.label, HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 11, T.LIGHT)
	var tag := selected_badge if selected_card and not selected_badge.is_empty() else "阵亡" if fallen else badge
	if selected_card and not selected_badge.is_empty() and not badge.is_empty(): tag += " · " + badge
	if not tag.is_empty():
		var tag_size := T.FONT.get_reading_font().get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 18
		draw_rect(Rect2(5, 8, tag_size, 24), Color("75392d") if selected_card else Color("16271fec"))
		draw_string(T.FONT.get_reading_font(), Vector2(13, 25), tag, HORIZONTAL_ALIGNMENT_LEFT, tag_size-10, 12, T.LIGHT)

func portrait_source_rect(area_size: Vector2) -> Rect2:
	if portrait == null or area_size.x <= 0 or area_size.y <= 0: return Rect2()
	var source: Vector2 = portrait.get_size()
	var ratio := maxf(area_size.x / source.x, area_size.y / source.y)
	var crop := area_size / ratio
	return Rect2((source - crop) * ART.card_anchor(character_id), crop)
