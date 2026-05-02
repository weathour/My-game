extends PanelContainer

const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")

const MIN_SIZE := Vector2(260.0, 132.0)
const MAX_SIZE := Vector2(560.0, 420.0)
const COMPACT_MAX_SIZE := Vector2(460.0, 340.0)
const WIDTH_PER_CHAR := 7.8
const LINE_HEIGHT_NORMAL := 18.0
const LINE_HEIGHT_COMPACT := 16.0
const HEADER_HEIGHT := 62.0
const EDGE_PADDING := 14.0
const CURSOR_OFFSET := Vector2(18.0, 18.0)

var title_label: Label
var category_label: Label
var description_label: RichTextLabel
var compact := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_index = 100
	clip_contents = true
	add_theme_stylebox_override("panel", SURVIVORS_THEME.panel_style(Color(0.035, 0.045, 0.070, 0.98), SURVIVORS_THEME.COLOR_BORDER_GOLD, 2, 12, 12.0))
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(request_hide)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 5)
	add_child(content)

	title_label = Label.new()
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	content.add_child(title_label)

	category_label = Label.new()
	category_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	content.add_child(category_label)

	description_label = RichTextLabel.new()
	description_label.bbcode_enabled = false
	description_label.fit_content = false
	description_label.scroll_active = true
	description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_label.mouse_filter = Control.MOUSE_FILTER_STOP
	description_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	description_label.add_theme_color_override("default_color", SURVIVORS_THEME.COLOR_TEXT)
	content.add_child(description_label)
	_apply_size(false)

func show_item(item: Dictionary, global_position_value: Vector2, anchor_rect: Rect2 = Rect2()) -> void:
	var title := str(item.get("title", item.get("name", "选项")))
	var detail := _get_detail_text(item)
	if detail == "":
		detail = title
	var role_effect_text := _format_role_effects(item)
	if role_effect_text != "" and not _contains_role_effect_section(detail):
		detail = "%s\n\n%s" % [detail, role_effect_text]
	title_label.text = title
	category_label.text = _get_category_text(item)
	category_label.visible = category_label.text != ""
	description_label.text = detail
	description_label.scroll_to_line(0)
	_apply_size(SURVIVORS_THEME.viewport_size(self).x < 900.0 or SURVIVORS_THEME.viewport_size(self).y < 560.0)
	visible = true
	_reposition(global_position_value, anchor_rect)

func hide_detail() -> void:
	visible = false

func request_hide() -> void:
	if not visible:
		return
	if _is_mouse_inside_panel():
		return
	hide_detail()

func _get_detail_text(item: Dictionary) -> String:
	for key in ["detail_description", "exact_description", "description", "preview_description"]:
		var value := str(item.get(key, ""))
		if value != "":
			return value
	return ""


func _format_role_effects(item: Dictionary) -> String:
	var role_effects: Array = item.get("role_effects", [])
	if role_effects.is_empty():
		return ""
	var lines: Array[String] = [_get_role_effect_section_title(role_effects)]
	for effect in role_effects:
		if effect is not Dictionary:
			continue
		lines.append("%s｜%s" % [str(effect.get("role_name", "")), str(effect.get("title", ""))])
		for line in effect.get("lines", []):
			lines.append("  - " + str(line))
	return "\n".join(lines)

func _contains_role_effect_section(text_value: String) -> bool:
	return text_value.contains("三英雄对应效果 / 数值") or text_value.contains("队伍英雄对应效果 / 数值")


func _get_role_effect_section_title(role_effects: Array) -> String:
	return "三英雄对应效果 / 数值" if role_effects.size() == 3 else "队伍英雄对应效果 / 数值"

func _get_category_text(item: Dictionary) -> String:
	var parts: Array[String] = []
	var slot_label := str(item.get("slot_label", ""))
	if slot_label != "":
		parts.append(slot_label)
	var card_type_label := str(item.get("card_type_label", ""))
	if card_type_label != "":
		parts.append(card_type_label)
	var current_level := int(item.get("current_level", -1))
	var max_level := int(item.get("max_level", -1))
	if current_level >= 0 and max_level > 0:
		parts.append("Lv.%d/%d" % [current_level, max_level])
	elif item.has("slot") and slot_label == "":
		parts.append(str(item.get("slot", "")))
	return "  ·  ".join(parts)

func _apply_size(is_compact: bool) -> void:
	compact = is_compact
	var viewport_size := SURVIVORS_THEME.viewport_size(self)
	var target_max_size := COMPACT_MAX_SIZE if compact else MAX_SIZE
	var viewport_max_size := Vector2(
		max(MIN_SIZE.x, viewport_size.x - EDGE_PADDING * 2.0),
		max(MIN_SIZE.y, viewport_size.y - EDGE_PADDING * 2.0)
	)
	var max_size := Vector2(
		min(target_max_size.x, viewport_max_size.x),
		min(target_max_size.y, viewport_max_size.y)
	)
	var content_size := _estimate_content_size(max_size.x, is_compact)
	var resolved_size := Vector2(
		clamp(content_size.x, MIN_SIZE.x, max_size.x),
		clamp(content_size.y, MIN_SIZE.y, max_size.y)
	)
	custom_minimum_size = resolved_size
	size = resolved_size
	description_label.custom_minimum_size = Vector2(0.0, max(64.0, resolved_size.y - HEADER_HEIGHT))
	title_label.add_theme_font_size_override("font_size", 16 if compact else 18)
	category_label.add_theme_font_size_override("font_size", 12 if compact else 13)
	description_label.add_theme_font_size_override("normal_font_size", 13 if compact else 15)
	description_label.add_theme_font_size_override("bold_font_size", 13 if compact else 15)

func _estimate_content_size(max_width: float, is_compact: bool) -> Vector2:
	var all_lines: Array[String] = []
	all_lines.append(str(title_label.text))
	if category_label.visible:
		all_lines.append(str(category_label.text))
	for line in str(description_label.text).replace("\r", "").split("\n"):
		all_lines.append(str(line))
	var longest_line := 0
	for line in all_lines:
		longest_line = max(longest_line, str(line).length())
	var natural_width: float = min(max_width, max(MIN_SIZE.x, 52.0 + float(longest_line) * WIDTH_PER_CHAR))
	var usable_text_width: float = max(160.0, natural_width - 36.0)
	var estimated_lines := 0
	for line in str(description_label.text).replace("\r", "").split("\n"):
		var length: int = max(1, str(line).length())
		estimated_lines += max(1, int(ceil(float(length) * WIDTH_PER_CHAR / usable_text_width)))
	var title_lines: int = max(1, int(ceil(float(max(1, str(title_label.text).length())) * WIDTH_PER_CHAR / usable_text_width)))
	var category_lines: int = 1 if category_label.visible and category_label.text != "" else 0
	var line_height: float = LINE_HEIGHT_COMPACT if is_compact else LINE_HEIGHT_NORMAL
	var natural_height: float = 34.0 + float(title_lines) * 22.0 + float(category_lines) * 18.0 + float(estimated_lines) * line_height
	return Vector2(natural_width, natural_height)

func _reposition(global_position_value: Vector2, anchor_rect: Rect2) -> void:
	var viewport_size := SURVIVORS_THEME.viewport_size(self)
	var desired := global_position_value + CURSOR_OFFSET
	if anchor_rect.size != Vector2.ZERO:
		desired = anchor_rect.position + Vector2(anchor_rect.size.x + 12.0, 0.0)
		if desired.x + size.x + EDGE_PADDING > viewport_size.x:
			desired.x = anchor_rect.position.x - size.x - 12.0
		desired.y = anchor_rect.position.y
	if desired.x + size.x + EDGE_PADDING > viewport_size.x:
		desired.x = viewport_size.x - size.x - EDGE_PADDING
	if desired.y + size.y + EDGE_PADDING > viewport_size.y:
		desired.y = viewport_size.y - size.y - EDGE_PADDING
	desired.x = max(EDGE_PADDING, desired.x)
	desired.y = max(EDGE_PADDING, desired.y)
	global_position = desired.floor()

func _on_mouse_entered() -> void:
	pass

func _is_mouse_inside_panel() -> bool:
	if not visible:
		return false
	var viewport := get_viewport()
	if viewport == null:
		return false
	return get_global_rect().has_point(viewport.get_mouse_position())
