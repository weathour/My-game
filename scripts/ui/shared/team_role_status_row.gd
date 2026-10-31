extends Control

const SKILL_CD_SLOT_COUNT := 6
const TEAM_STACK_SLOT_SIZE_ACTIVE := 36.0
const TEAM_STACK_SLOT_SIZE_STANDBY := 28.0
const TEAM_STACK_SLOT_GAP_ACTIVE := 7.0
const TEAM_STACK_SLOT_GAP_STANDBY := 6.0
const TEAM_STACK_SLOT_COUNT := SKILL_CD_SLOT_COUNT

var key_text: String = ""
var role_name: String = ""
var role_id: String = ""
var state_text: String = ""
var active: bool = false
var role_color: Color = Color(0.72, 0.57, 0.25, 1.0)
var current_health: float = 0.0
var max_health: float = 1.0
var current_mana: float = 0.0
var max_mana: float = 1.0
var switch_energy: float = 0.0
var switch_energy_required: float = 100.0

func set_status(data: Dictionary, next_key_text: String, next_state_text: String, next_active: bool) -> void:
	key_text = next_key_text
	state_text = next_state_text
	active = next_active
	role_id = str(data.get("role_id", ""))
	role_name = str(data.get("role_name", role_id))
	var color_value: Variant = data.get("color", role_color)
	if color_value is Color:
		role_color = color_value
	current_health = max(0.0, float(data.get("current_health", 0.0)))
	max_health = max(1.0, float(data.get("max_health", 1.0)))
	current_mana = max(0.0, float(data.get("current_mana", 0.0)))
	max_mana = max(1.0, float(data.get("max_mana", 1.0)))
	switch_energy = max(0.0, float(data.get("switch_energy", 0.0)))
	switch_energy_required = max(1.0, float(data.get("switch_energy_required", 100.0)))
	queue_redraw()

func _draw() -> void:
	var outer_rect := Rect2(Vector2.ZERO, size)
	var fill_color := Color("#123c2e") if active else Color("#30171d")
	var border_color := Color("#d3ad56") if active else Color("#76533c")
	draw_rect(outer_rect, fill_color)
	draw_rect(outer_rect.grow(-1.0), border_color, false, 1.0 if active else 0.8)
	if active:
		draw_rect(Rect2(Vector2(4.0, 5.0), Vector2(3.0, max(8.0, size.y - 10.0))), Color("#e4c46d"))
		var pointer := PackedVector2Array([
			Vector2(size.x - 1.0, size.y * 0.36),
			Vector2(size.x + 7.0, size.y * 0.5),
			Vector2(size.x - 1.0, size.y * 0.64)
		])
		draw_colored_polygon(pointer, Color("#d3ad56"))
	_draw_key_tag()
	_draw_role_text()
	_draw_resource_bars()
	_draw_connector_rail()

func _draw_key_tag() -> void:
	var tag_width: float = 68.0 if active else 52.0
	var tag_height: float = 25.0 if active else 24.0
	var tag_pos := Vector2(18.0, (size.y - tag_height) * 0.5)
	var tag_rect := Rect2(tag_pos, Vector2(tag_width, tag_height))
	var tag_fill := Color("#513d1b") if active else Color("#451f25")
	var tag_border := Color("#e0bd68") if active else Color("#8b6246")
	draw_rect(tag_rect, tag_fill)
	draw_rect(tag_rect.grow(-0.5), tag_border, false, 1.0)
	_draw_text_center(tag_rect, key_text, 18 if active else 19, Color("#f8e8bc"))

func _draw_role_text() -> void:
	var name_position := _get_name_position()
	var font := get_theme_default_font()
	var role_font_size: int = 19 if active else 15
	draw_string(font, name_position + Vector2(1.0, 1.0), role_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, role_font_size, Color(0.0, 0.0, 0.0, 0.82))
	draw_string(font, name_position, role_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, role_font_size, Color("#f4dfa0") if active else Color("#d8c7a5"))
	var state_font_size: int = 10
	var state_pos := Vector2(name_position.x, size.y - 6.0)
	draw_string(font, state_pos, state_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, state_font_size, Color("#c5d8a8") if active else Color("#c2a493"))

func _draw_resource_bars() -> void:
	var bar_x: float = 236.0
	var bar_width: float = 188.0 if active else 168.0
	var hp_y: float = 10.0 if active else 7.0
	var mp_y: float = 30.0 if active else 22.0
	var hp_height: float = 10.0 if active else 8.0
	var mp_height: float = 8.0 if active else 6.0
	var hp_ratio: float = clamp(current_health / max_health, 0.0, 1.0)
	var mp_ratio: float = clamp(current_mana / max_mana, 0.0, 1.0)
	var hp_color := Color("#ad463e") if hp_ratio > 0.35 else Color("#d44339")
	_draw_bar(Vector2(bar_x, hp_y), Vector2(bar_width, hp_height), hp_ratio, hp_color, "HP")
	_draw_bar(Vector2(bar_x, mp_y), Vector2(bar_width, mp_height), mp_ratio, Color("#83b78b"), "MP")
	var font := get_theme_default_font()
	var value_size: int = 11
	draw_string(font, Vector2(bar_x + bar_width + 8.0, hp_y + hp_height - 1.0), "%.0f/%.0f" % [current_health, max_health], HORIZONTAL_ALIGNMENT_LEFT, -1.0, value_size, Color("#f0e5c7"))
	draw_string(font, Vector2(bar_x + bar_width + 8.0, mp_y + mp_height + 1.0), "%.0f/%.0f" % [current_mana, max_mana], HORIZONTAL_ALIGNMENT_LEFT, -1.0, value_size, Color("#d5d2ad"))

func _draw_connector_rail() -> void:
	var rail_start_x: float = 474.0
	var rail_end_x: float = max(rail_start_x + 24.0, size.x - ((TEAM_STACK_SLOT_SIZE_ACTIVE if active else TEAM_STACK_SLOT_SIZE_STANDBY) * TEAM_STACK_SLOT_COUNT + (TEAM_STACK_SLOT_GAP_ACTIVE if active else TEAM_STACK_SLOT_GAP_STANDBY) * float(TEAM_STACK_SLOT_COUNT - 1)) - 34.0)
	if rail_end_x <= rail_start_x:
		return
	var rail_y: float = size.y * 0.5
	var rail_color := Color("#c9a759", 0.52) if active else Color("#9a7351", 0.30)
	draw_line(Vector2(rail_start_x, rail_y), Vector2(rail_end_x, rail_y), rail_color, 2.0 if active else 1.0)
	draw_line(Vector2(rail_start_x, rail_y + 4.0), Vector2(rail_end_x, rail_y + 4.0), Color(0.0, 0.0, 0.0, 0.24), 1.0)

func _draw_bar(pos: Vector2, bar_size: Vector2, ratio: float, fill_color: Color, label: String) -> void:
	var rect := Rect2(pos, bar_size)
	draw_rect(rect, Color("#0b1714"))
	var fill_width: float = max(0.0, bar_size.x * ratio)
	if fill_width > 2.0:
		draw_rect(Rect2(pos + Vector2(1.0, 1.0), Vector2(fill_width - 2.0, bar_size.y - 2.0)), fill_color)
	draw_rect(rect.grow(-0.5), Color("#b28b4b"), false, 1.0)
	var font := get_theme_default_font()
	draw_string(font, pos + Vector2(5.0, bar_size.y - 1.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#eadfbe"))

func _draw_text_center(rect: Rect2, text: String, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size)
	var text_position := rect.position + (rect.size - text_size) * 0.5 + Vector2(0.0, text_size.y * 0.78)
	draw_string(font, text_position + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.82))
	draw_string(font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _get_name_position() -> Vector2:
	var tag_width: float = 68.0 if active else 52.0
	var emblem_size: float = 42.0 if active else 30.0
	return Vector2(18.0 + tag_width + 14.0 + emblem_size + 12.0, 20.0 if active else 18.0)
