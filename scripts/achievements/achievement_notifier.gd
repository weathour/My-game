extends CanvasLayer

const CARD_WIDTH := 280.0
const CARD_HEIGHT := 72.0
const CARD_MARGIN := 14.0
const SLIDE_DISTANCE := 18.0
const ENTER_SECONDS := 0.22
const HOLD_SECONDS := 2.6
const EXIT_SECONDS := 0.22

var _queue: Array[Dictionary] = []
var _showing := false
var _card: PanelContainer
var _title_label: Label
var _description_label: Label
var _progress_label: Label
var _base_position := Vector2.ZERO
var _hidden_position := Vector2.ZERO

func _ready() -> void:
	layer = 80
	_build_card()
	var achievement_service := get_node_or_null("/root/AchievementService")
	if achievement_service != null and achievement_service.has_signal("achievement_unlocked"):
		achievement_service.achievement_unlocked.connect(_on_achievement_unlocked)

func preview(definition: Dictionary = {}) -> void:
	if definition.is_empty():
		definition = {
			"title": "初战告捷",
			"description": "击败第一个敌人。",
			"id": "ACH_FIRST_BLOOD"
		}
	_enqueue(definition)

func _build_card() -> void:
	_card = PanelContainer.new()
	_card.visible = false
	_card.modulate = Color(1, 1, 1, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.anchor_left = 1.0
	_card.anchor_top = 0.0
	_card.anchor_right = 1.0
	_card.anchor_bottom = 0.0
	_card.offset_left = -CARD_WIDTH - CARD_MARGIN
	_card.offset_top = CARD_MARGIN
	_card.offset_right = -CARD_MARGIN
	_card.offset_bottom = CARD_MARGIN + CARD_HEIGHT

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.055, 0.075, 0.94)
	style.border_color = Color(1.0, 0.78, 0.28, 0.96)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_card.add_theme_stylebox_override("panel", style)
	add_child(_card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_card.add_child(row)

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(42, 42)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(1.0, 0.72, 0.18, 0.96)
	badge_style.border_color = Color(1.0, 0.95, 0.55, 1.0)
	badge_style.set_border_width_all(2)
	badge_style.set_corner_radius_all(21)
	badge.add_theme_stylebox_override("panel", badge_style)
	row.add_child(badge)

	var badge_label := Label.new()
	badge_label.text = "★"
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_size_override("font_size", 23)
	badge_label.add_theme_color_override("font_color", Color(0.12, 0.08, 0.02, 1.0))
	badge.add_child(badge_label)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)

	_progress_label = Label.new()
	_progress_label.text = "成就达成"
	_progress_label.add_theme_font_size_override("font_size", 11)
	_progress_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.36, 1.0))
	text_box.add_child(_progress_label)

	_title_label = Label.new()
	_title_label.text = "成就标题"
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0, 1.0))
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(_title_label)

	_description_label = Label.new()
	_description_label.text = "成就描述"
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.custom_minimum_size.x = 200
	_description_label.max_lines_visible = 2
	_description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_description_label.add_theme_font_size_override("font_size", 12)
	_description_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92, 0.96))
	text_box.add_child(_description_label)

	_base_position = _card.position
	_hidden_position = _base_position + Vector2(SLIDE_DISTANCE, 0.0)
	_card.position = _hidden_position

func _on_achievement_unlocked(_id: String, definition: Dictionary) -> void:
	_enqueue(definition)

func _enqueue(definition: Dictionary) -> void:
	_queue.append(definition.duplicate(true))
	if not _showing:
		_show_next()

func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var definition: Dictionary = _queue.pop_front()
	_title_label.text = str(definition.get("title", definition.get("id", "成就")))
	_description_label.text = str(definition.get("description", ""))
	_progress_label.text = "成就达成"

	_card.visible = true
	_card.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	_card.position = _hidden_position
	_card.modulate = Color(1, 1, 1, 0)

	var tween := create_tween()
	if preload("res://scripts/game_settings.gd").comfort_enabled("reduced_motion"):
		_card.position = _base_position
		_card.modulate = Color.WHITE
		tween.tween_interval(HOLD_SECONDS)
		tween.finished.connect(_on_card_finished)
		return
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card, "position", _base_position, ENTER_SECONDS)
	tween.parallel().tween_property(_card, "modulate", Color(1, 1, 1, 1), ENTER_SECONDS)
	tween.tween_interval(HOLD_SECONDS)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_card, "position", _hidden_position, EXIT_SECONDS)
	tween.parallel().tween_property(_card, "modulate", Color(1, 1, 1, 0), EXIT_SECONDS)
	tween.finished.connect(_on_card_finished)

func _on_card_finished() -> void:
	_card.visible = false
	_show_next()
