extends Control

const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const STORY_DATA := preload("res://scripts/story_data.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")

var profile: Dictionary = {}

func _ready() -> void:
	if not STORY_DATA.is_story_mode_enabled():
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	profile = SAVE_MANAGER.load_story_profile()
	if profile.is_empty():
		get_tree().change_scene_to_file(STORY_DATA.SAVE_SELECT_SCENE_PATH)
		return
	_rebuild_ui()

func _rebuild_ui() -> void:
	for child in get_children():
		child.queue_free()

	profile = SAVE_MANAGER.load_story_profile()
	var current_stage := STORY_DATA.get_stage(int(profile.get("current_stage_index", 0)))

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.05, 0.07, 0.12, 1.0)
	add_child(background)

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 42)
	root_margin.add_theme_constant_override("margin_top", 30)
	root_margin.add_theme_constant_override("margin_right", 42)
	root_margin.add_theme_constant_override("margin_bottom", 30)
	add_child(root_margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	root_margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	root.add_child(header)

	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_column)

	var title := Label.new()
	title.text = "主线准备"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT)
	title_column.add_child(title)

	var slot_label := Label.new()
	slot_label.text = "存档 %d  |  Boss核心 %d" % [int(profile.get("slot_id", 1)), int(profile.get("boss_core_fragments", 0))]
	slot_label.add_theme_font_size_override("font_size", 18)
	slot_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	title_column.add_child(slot_label)

	var back_button := Button.new()
	back_button.text = "返回主菜单"
	back_button.custom_minimum_size = Vector2(160, 46)
	SURVIVORS_THEME.apply_button_style(back_button)
	back_button.pressed.connect(_on_back_pressed)
	header.add_child(back_button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root.add_child(body)

	body.add_child(_build_roster_panel())
	body.add_child(_build_stage_panel(current_stage))

	var start_button := Button.new()
	start_button.text = "进入下一关" if not current_stage.is_empty() else "主线已完成"
	start_button.disabled = current_stage.is_empty()
	start_button.custom_minimum_size = Vector2(260, 58)
	start_button.add_theme_font_size_override("font_size", 24)
	SURVIVORS_THEME.apply_button_style(start_button, "primary")
	start_button.pressed.connect(_on_start_pressed)
	root.add_child(start_button)

func _build_roster_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	panel.add_theme_stylebox_override("panel", SURVIVORS_THEME.panel_style(SURVIVORS_THEME.COLOR_BG, SURVIVORS_THEME.COLOR_BORDER, 1, 14))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var section_title := Label.new()
	section_title.text = "队伍编成（当前可用3人，预留2个锁定位）"
	section_title.add_theme_font_size_override("font_size", 24)
	column.add_child(section_title)

	var team_order: Array = profile.get("team_order", []).duplicate()
	for index in range(team_order.size()):
		column.add_child(_build_team_slot(index, str(team_order[index]), team_order.size()))

	var locked_title := Label.new()
	locked_title.text = "未解锁角色"
	locked_title.add_theme_font_size_override("font_size", 20)
	column.add_child(locked_title)

	for role_payload in STORY_DATA.ROLE_POOL:
		if bool(role_payload.get("available", false)):
			continue
		var locked_card := PanelContainer.new()
		locked_card.custom_minimum_size = Vector2(0, 62)
		locked_card.add_theme_stylebox_override("panel", SURVIVORS_THEME.card_style(false, false, true))
		var locked_label := Label.new()
		locked_label.text = "%s  |  预留锁定位" % str(role_payload.get("name", "未命名"))
		locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		locked_card.add_child(locked_label)
		column.add_child(locked_card)

	return panel

func _build_team_slot(slot_index: int, role_id: String, team_size: int) -> Control:
	var role_style_id := str(profile.get("equipped_styles", {}).get(role_id, "default"))
	var style_payload := STORY_DATA.get_role_style(role_id, role_style_id)
	var unlock_style_id := STORY_DATA.get_unlock_style_id(role_id)
	var unlock_style_payload := STORY_DATA.get_role_style(role_id, unlock_style_id)
	var unlocked_styles: Array = profile.get("unlocked_styles", {}).get(role_id, []).duplicate()
	var has_unlock_style: bool = unlocked_styles.has(unlock_style_id)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 122)
	panel.add_theme_stylebox_override("panel", SURVIVORS_THEME.card_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var title := Label.new()
	title.text = "%d号位：%s" % [slot_index + 1, _get_role_name(role_id)]
	title.add_theme_font_size_override("font_size", 22)
	info.add_child(title)

	var desc := Label.new()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.text = "当前风格：%s\n%s" % [str(style_payload.get("name", "默认")), str(style_payload.get("short_description", ""))]
	info.add_child(desc)

	var actions := VBoxContainer.new()
	actions.custom_minimum_size = Vector2(220, 0)
	actions.add_theme_constant_override("separation", 8)
	row.add_child(actions)

	var order_row := HBoxContainer.new()
	order_row.add_theme_constant_override("separation", 8)
	actions.add_child(order_row)

	var up_button := Button.new()
	up_button.text = "上移"
	up_button.disabled = slot_index == 0
	SURVIVORS_THEME.apply_button_style(up_button)
	up_button.pressed.connect(_on_move_team_role.bind(slot_index, slot_index - 1))
	order_row.add_child(up_button)

	var down_button := Button.new()
	down_button.text = "下移"
	down_button.disabled = slot_index >= team_size - 1
	SURVIVORS_THEME.apply_button_style(down_button)
	down_button.pressed.connect(_on_move_team_role.bind(slot_index, slot_index + 1))
	order_row.add_child(down_button)

	var style_row := HBoxContainer.new()
	style_row.add_theme_constant_override("separation", 8)
	actions.add_child(style_row)

	var default_button := Button.new()
	default_button.text = "装备默认"
	default_button.disabled = role_style_id == "default"
	SURVIVORS_THEME.apply_button_style(default_button)
	default_button.pressed.connect(_on_equip_style.bind(role_id, "default"))
	style_row.add_child(default_button)

	var unlock_button := Button.new()
	if has_unlock_style:
		unlock_button.text = "装备%s" % str(unlock_style_payload.get("name", "风格"))
		unlock_button.disabled = role_style_id == unlock_style_id
		unlock_button.pressed.connect(_on_equip_style.bind(role_id, unlock_style_id))
	else:
		unlock_button.text = "解锁%s" % str(unlock_style_payload.get("name", "风格"))
		unlock_button.disabled = int(profile.get("boss_core_fragments", 0)) <= 0
		unlock_button.pressed.connect(_on_unlock_style.bind(role_id, unlock_style_id))
	SURVIVORS_THEME.apply_button_style(unlock_button, "primary")
	style_row.add_child(unlock_button)

	var unlock_desc := Label.new()
	unlock_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unlock_desc.text = "可解锁：%s" % str(unlock_style_payload.get("short_description", ""))
	actions.add_child(unlock_desc)

	return panel

func _build_stage_panel(stage_data: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", SURVIVORS_THEME.panel_style(SURVIVORS_THEME.COLOR_BG, SURVIVORS_THEME.COLOR_BORDER, 1, 14))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var title := Label.new()
	title.text = "下一关信息"
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)

	if stage_data.is_empty():
		var done_label := Label.new()
		done_label.text = "第一阶段主线已经打通。"
		done_label.add_theme_font_size_override("font_size", 22)
		column.add_child(done_label)
		return panel

	var stage_title := Label.new()
	stage_title.text = str(stage_data.get("title", "未知关卡"))
	stage_title.add_theme_font_size_override("font_size", 28)
	column.add_child(stage_title)

	var stage_desc := Label.new()
	stage_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage_desc.text = str(stage_data.get("description", ""))
	column.add_child(stage_desc)

	var type_label := Label.new()
	type_label.text = "关卡类型：%s" % ("Boss关" if str(stage_data.get("type", "")) == "boss" else "普通关")
	column.add_child(type_label)

	var timing_label := Label.new()
	if str(stage_data.get("type", "")) == "boss":
		timing_label.text = "Boss登场时间：%d 秒" % int(round(float(stage_data.get("boss_spawn_time", 0.0))))
	else:
		timing_label.text = "目标生存时间：%d 秒" % int(round(float(stage_data.get("target_time", 0.0))))
	column.add_child(timing_label)

	var tip_label := Label.new()
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.text = "第一阶段说明：普通关先验证主线骨架，Boss关负责掉落Boss核心并解锁风格。"
	column.add_child(tip_label)

	return panel

func _get_role_name(role_id: String) -> String:
	match role_id:
		"swordsman":
			return "剑士"
		"gunner":
			return "枪手"
		"mage":
			return "术师"
	return role_id

func _on_move_team_role(from_index: int, to_index: int) -> void:
	if to_index < 0:
		return
	var team_order: Array = profile.get("team_order", []).duplicate()
	if from_index >= team_order.size() or to_index >= team_order.size():
		return
	var temp = team_order[from_index]
	team_order[from_index] = team_order[to_index]
	team_order[to_index] = temp
	SAVE_MANAGER.update_team_order(team_order)
	_rebuild_ui()

func _on_unlock_style(role_id: String, style_id: String) -> void:
	SAVE_MANAGER.unlock_style(role_id, style_id)
	_rebuild_ui()

func _on_equip_style(role_id: String, style_id: String) -> void:
	SAVE_MANAGER.equip_style(role_id, style_id)
	_rebuild_ui()

func _on_start_pressed() -> void:
	if not STORY_DATA.is_story_mode_enabled():
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
		return
	get_tree().change_scene_to_file(STORY_DATA.BATTLE_SCENE_PATH)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
