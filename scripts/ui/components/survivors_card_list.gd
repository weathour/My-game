extends Control

signal item_selected(item_id: String, item: Dictionary)
signal item_hovered(item: Dictionary, anchor_rect: Rect2)
signal item_unhovered

const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")

const SUMMARY_LIMIT := 34
const SUMMARY_LIMIT_COMPACT := 22

var scroll_area: ScrollContainer
var content: VBoxContainer
var button_entries: Array = []
var selected_ids: Array[String] = []
var columns: int = 1
var compact := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	scroll_area = ScrollContainer.new()
	scroll_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll_area.follow_focus = true
	scroll_area.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll_area.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll_area)

	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll_area.add_child(content)

func clear() -> void:
	button_entries = []
	selected_ids = []
	columns = 1
	if content == null:
		reset_scroll_to_top()
		return
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	reset_scroll_to_top()

func reset_scroll_to_top() -> void:
	if scroll_area == null:
		return
	scroll_area.scroll_vertical = 0
	call_deferred("_reset_scroll_to_top_deferred")

func _reset_scroll_to_top_deferred() -> void:
	if scroll_area != null:
		scroll_area.scroll_vertical = 0

func set_selected_ids(ids: Array) -> void:
	var next_selected_ids: Array[String] = []
	for id_value in ids:
		next_selected_ids.append(str(id_value))
	if selected_ids == next_selected_ids:
		return
	selected_ids = next_selected_ids
	refresh_styles()

func set_compact(enabled: bool) -> void:
	if compact == enabled:
		return
	compact = enabled
	if content != null:
		content.add_theme_constant_override("separation", 6 if compact else 8)
	refresh_styles()

func add_section(title: String) -> Label:
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 13 if compact else 15)
	label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	content.add_child(label)
	return label

func add_card(item: Dictionary, selected: bool = false, accented: bool = false, disabled: bool = false) -> Button:
	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, SURVIVORS_THEME.CARD_HEIGHT_COMPACT if compact else SURVIVORS_THEME.CARD_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", 12 if compact else 14)
	button.text = _format_item_text(item, compact)
	button.disabled = disabled
	SURVIVORS_THEME.apply_card_button_style(button, selected, accented, disabled)
	_connect_hover_signals(button, item)
	button.pressed.connect(_on_button_pressed.bind(item))
	content.add_child(button)
	button_entries.append({
		"button": button,
		"item": item,
		"accented": accented,
		"disabled": disabled
	})
	return button

func add_card_grid(items: Array, target_columns: int = 2) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = max(1, target_columns)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6 if compact else 8)
	grid.add_theme_constant_override("v_separation", 6 if compact else 8)
	content.add_child(grid)
	for raw_item in items:
		if raw_item is not Dictionary:
			continue
		var item: Dictionary = raw_item
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, SURVIVORS_THEME.CARD_HEIGHT_COMPACT if compact else SURVIVORS_THEME.CARD_HEIGHT)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.add_theme_font_size_override("font_size", 12 if compact else 14)
		button.text = _format_item_text(item, compact)
		var selected := selected_ids.has(str(item.get("id", "")))
		var accented := bool(item.get("evolved", false))
		SURVIVORS_THEME.apply_card_button_style(button, selected, accented, false)
		_connect_hover_signals(button, item)
		button.pressed.connect(_on_button_pressed.bind(item))
		grid.add_child(button)
		button_entries.append({
			"button": button,
			"item": item,
			"accented": accented,
			"disabled": false
		})
	return grid

func refresh_styles() -> void:
	for entry in button_entries:
		if entry is not Dictionary:
			continue
		var button := entry.get("button") as Button
		if button == null:
			continue
		var item: Dictionary = entry.get("item", {})
		var item_id := str(item.get("id", ""))
		var selected := selected_ids.has(item_id)
		var accented := bool(entry.get("accented", false)) or bool(item.get("evolved", false))
		var disabled := bool(entry.get("disabled", false))
		button.custom_minimum_size = Vector2(0.0, SURVIVORS_THEME.CARD_HEIGHT_COMPACT if compact else SURVIVORS_THEME.CARD_HEIGHT)
		button.add_theme_font_size_override("font_size", 12 if compact else 14)
		button.text = ("✓ " if selected else "") + _format_item_text(item, compact)
		button.disabled = disabled
		SURVIVORS_THEME.apply_card_button_style(button, selected, accented, disabled)
	for child in content.get_children():
		if child is GridContainer:
			(child as GridContainer).columns = 1 if compact else max(1, columns)
			(child as GridContainer).add_theme_constant_override("h_separation", 6 if compact else 8)
			(child as GridContainer).add_theme_constant_override("v_separation", 6 if compact else 8)
		elif child is Label:
			(child as Label).add_theme_font_size_override("font_size", 13 if compact else 15)

func _format_item_text(item: Dictionary, is_compact: bool) -> String:
	var title := str(item.get("title", item.get("name", "选项")))
	var summary := _get_summary_text(item)
	if summary == "":
		return title
	var limit := SUMMARY_LIMIT_COMPACT if is_compact else SUMMARY_LIMIT
	if summary.length() > limit:
		summary = summary.substr(0, max(0, limit - 1)) + "…"
	return "%s\n%s" % [title, summary]

func _get_summary_text(item: Dictionary) -> String:
	for key in ["summary", "short_description", "preview_description"]:
		var value := str(item.get(key, ""))
		if value != "":
			return _first_line(value)
	return _first_line(str(item.get("description", "")))

func _get_detail_text(item: Dictionary) -> String:
	for key in ["detail_description", "exact_description", "description", "preview_description", "summary"]:
		var value := str(item.get(key, ""))
		if value != "":
			return value
	return str(item.get("title", item.get("name", "")))

func _first_line(text_value: String) -> String:
	var normalized := text_value.replace("\r", "")
	var newline_index := normalized.find("\n")
	if newline_index >= 0:
		return normalized.substr(0, newline_index)
	return normalized

func _connect_hover_signals(button: Button, item: Dictionary) -> void:
	button.mouse_entered.connect(_on_button_mouse_entered.bind(button, item))
	button.mouse_exited.connect(_on_button_mouse_exited)
	button.focus_entered.connect(_on_button_mouse_entered.bind(button, item))
	button.focus_exited.connect(_on_button_mouse_exited)

func _on_button_mouse_entered(button: Button, item: Dictionary) -> void:
	var rect := Rect2(button.global_position, button.size)
	item_hovered.emit(item, rect)

func _on_button_mouse_exited() -> void:
	item_unhovered.emit()

func _on_button_pressed(item: Dictionary) -> void:
	item_selected.emit(str(item.get("id", "")), item)
