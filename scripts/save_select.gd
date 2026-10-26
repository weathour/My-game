extends Control

const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const STORY_DATA := preload("res://scripts/story_data.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const SURVIVORS_SLOT_CARD := preload("res://scripts/ui/components/survivors_slot_card_factory.gd")
const SAVE_FEEDBACK := preload("res://scripts/ui/save/save_feedback.gd")

func _ready() -> void:
	if not STORY_DATA.is_story_mode_enabled():
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.05, 0.07, 0.12, 1.0)
	add_child(background)

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 36)
	root_margin.add_theme_constant_override("margin_top", 28)
	root_margin.add_theme_constant_override("margin_right", 36)
	root_margin.add_theme_constant_override("margin_bottom", 28)
	add_child(root_margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	root_margin.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	content.add_child(header)

	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_column)

	var title := Label.new()
	title.text = "选择主线存档"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT)
	title_column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "三个独立档案。完成任务、交付调查物品，推进第一章。"
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	title_column.add_child(subtitle)

	var back_button := Button.new()
	back_button.text = "返回主菜单"
	back_button.custom_minimum_size = Vector2(160, 44)
	SURVIVORS_THEME.apply_button_style(back_button)
	back_button.pressed.connect(_on_back_pressed)
	header.add_child(back_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(grid)

	for slot_payload in SAVE_MANAGER.list_story_slots():
		grid.add_child(_build_slot_card(slot_payload))

func _build_slot_card(slot_payload: Dictionary) -> Control:
	var slot_id: int = int(slot_payload.get("slot_id", 0))
	var has_profile: bool = bool(slot_payload.get("has_profile", false))
	var profile: Dictionary = slot_payload.get("profile", {})
	var health := str(slot_payload.get("health", "ok" if has_profile else "missing"))
	var action_text := "继续" if has_profile else "新建"
	var detail_text := "空存档。\n新建后将从第一章第一关开始。"
	if has_profile:
		var stage_index: int = int(profile.get("current_stage_index", 0))
		var stage_data := STORY_DATA.get_stage(stage_index)
		var stage_text := "主线已完成" if stage_data.is_empty() else str(stage_data.get("title", "未知关卡"))
		detail_text = "当前进度：%s\nBoss核心：%d" % [stage_text, int(profile.get("boss_core_fragments", 0))]
	if health == "recoverable":
		detail_text += "\n主档损坏，有可用备份"
		action_text = "恢复备份并继续"
	elif health in ["corrupt", "incompatible"]:
		detail_text = "档案无法读取，原文件已保留。"
		action_text = "查看恢复说明"

	var root := Control.new()
	root.custom_minimum_size = Vector2(0, 172)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var card := SURVIVORS_SLOT_CARD.build_card(
		"存档 %d" % slot_id,
		detail_text,
		action_text,
		Callable(self, "_on_slot_pressed").bind(slot_id),
		172.0
	)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(card)

	if has_profile or health != "missing":
		var delete_button := Button.new()
		delete_button.text = "×"
		delete_button.tooltip_text = "删除存档"
		delete_button.anchor_left = 1.0
		delete_button.anchor_right = 1.0
		delete_button.offset_left = -42.0
		delete_button.offset_top = 10.0
		delete_button.offset_right = -10.0
		delete_button.offset_bottom = 42.0
		delete_button.add_theme_font_size_override("font_size", 24)
		SURVIVORS_SLOT_CARD.apply_delete_button_style(delete_button)
		delete_button.pressed.connect(_on_delete_pressed.bind(slot_id))
		root.add_child(delete_button)

	return root

func _on_slot_pressed(slot_id: int) -> void:
	var health: String = SAVE_MANAGER.profile_status(slot_id, SAVE_MANAGER.MODE_STORY).status
	if SAVE_MANAGER.create_or_load_story_profile(slot_id).is_empty():
		SAVE_FEEDBACK.show_error(self, SAVE_FEEDBACK.health_text(health))
		return
	get_tree().change_scene_to_file(STORY_DATA.PREP_SCENE_PATH)

func _on_delete_pressed(slot_id: int) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "删除故事存档 %d" % slot_id
	dialog.dialog_text = "此档案的任务、剧情物品、情报和当前战局都会删除。确定删除存档 %d 吗？" % slot_id
	dialog.ok_button_text = "删除存档"
	dialog.cancel_button_text = "保留存档"
	add_child(dialog)
	dialog.confirmed.connect(func():
		if SAVE_MANAGER.delete_story_profile(slot_id):
			_build_ui()
		else:
			SAVE_FEEDBACK.show_error(self, "部分文件未能删除，请检查文件权限后重试。")
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(500, 200))

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
