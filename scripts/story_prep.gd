extends Control

const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const STORY_DATA := preload("res://scripts/story_data.gd")
const CONTENT := preload("res://scripts/story/story_content.gd")
const PROGRESS := preload("res://scripts/story/story_progress.gd")
const STYLE := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const VISUALS := preload("res://scripts/ui/story/story_visuals.gd")
const DIALOGUE := preload("res://scripts/ui/story/dialogue_panel.gd")
const JOURNAL := preload("res://scripts/ui/story/story_journal_panel.gd")
const TEAM_SWAP_PANEL_SCENE := preload("res://scenes/UI/team_swap_panel.tscn")
var profile: Dictionary = {}
var team_swap_panel: Control
var dialogue_panel: Control
var journal_panel: Control
var page_root: Control
var notice := ""
var slot := -1
var recovery_needed := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not STORY_DATA.is_story_mode_enabled():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	theme = Theme.new()
	theme.default_font = STYLE.get_reading_font()
	theme.default_font_size = 17
	slot = SAVE_MANAGER.get_active_slot_id()
	var opened := PROGRESS.open_slot(slot)
	notice = "" if opened.ok else PROGRESS.message(opened.reason)
	recovery_needed = not opened.ok and opened.reason in ["run_corrupt", "stale_attempt"]
	profile = SAVE_MANAGER.load_story_profile(slot)
	team_swap_panel = TEAM_SWAP_PANEL_SCENE.instantiate()
	team_swap_panel.visible = false
	team_swap_panel.closed.connect(_rebuild_ui)
	add_child(team_swap_panel)
	dialogue_panel = DIALOGUE.new()
	dialogue_panel.closed.connect(_rebuild_ui)
	add_child(dialogue_panel)
	journal_panel = JOURNAL.new()
	add_child(journal_panel)
	get_viewport().size_changed.connect(_fit_page)
	_rebuild_ui()

func _button(parent: Node, text: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if parent is HBoxContainer:
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.custom_minimum_size.x = 130
	elif parent is HFlowContainer:
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
	VISUALS.style_button(button, primary)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _label(parent: Node, text: String, title: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	STYLE.apply_label_font(label, 25 if title else 17, VISUALS.TEXT)
	parent.add_child(label)
	return label

func _rebuild_ui() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var focus_text: String = focused.text if focused is Button else ""
	if is_instance_valid(page_root):
		remove_child(page_root)
		page_root.queue_free()
	profile = SAVE_MANAGER.load_story_profile(slot)
	page_root = Control.new()
	page_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page_root)
	move_child(page_root, 0)
	var background := ColorRect.new()
	background.color = VISUALS.BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_root.add_child(background)
	var margin := MarginContainer.new()
	margin.name = "PageMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	page_root.add_child(margin)
	var layout := VBoxContainer.new()
	layout.name = "PageLayout"
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	layout.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_small_label(heading, "第一章 · 恢复通讯", VISUALS.GOLD)
	var title := _label(heading, "等一声回答", true)
	title.add_theme_font_size_override("font_size", 32)
	for action in [["任务与记录", _open_journal], ["调整队伍", _on_swap_team_pressed], ["返回主菜单", _on_back_pressed]]:
		var button := _button(header, action[0], action[1])
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.disabled = profile.is_empty() and action[0] != "返回主菜单"
		VISUALS.style_button(button, false, true)
	if profile.is_empty():
		_label(layout, "档案无法读取。请回到选档界面检查备份。")
		return
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 28)
	layout.add_child(columns)
	var field := VBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_stretch_ratio = 1.8
	field.add_theme_constant_override("separation", 14)
	columns.add_child(field)
	_build_field(field)
	_build_route(field)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.0
	scroll.custom_minimum_size.x = 300
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 12)
	scroll.add_child(side)
	_build_objective(side)
	_build_people(side)
	_build_results(side)
	var footer := HBoxContainer.new()
	footer.name = "StoryFooter"
	footer.add_theme_constant_override("separation", 20)
	layout.add_child(footer)
	var team := _small_label(footer, "下次同行  %s" % _team_names(profile.team_order))
	team.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_small_label(footer, "故事档 %d  /  核心 %d" % [slot, int(profile.boss_core_fragments)])
	_fit_page()
	# Rebuilding after a conversation must not strand keyboard users on a freed button.
	var fallback: Button
	for button: Button in page_root.find_children("*", "Button", true, false):
		if button.disabled:
			continue
		if fallback == null or button.text == focus_text:
			fallback = button
		if button.text == focus_text:
			break
	if fallback != null:
		fallback.grab_focus.call_deferred()

func _fit_page() -> void:
	if not is_instance_valid(page_root):
		return
	var compact := get_viewport_rect().size.y < 640
	var margin: MarginContainer = page_root.find_child("PageMargin", true, false)
	var layout: VBoxContainer = page_root.find_child("PageLayout", true, false)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16 if compact else 24)
	layout.add_theme_constant_override("separation", 12 if compact else 18)
	var scene: Control = page_root.find_child("CampScene", true, false)
	if scene != null:
		scene.custom_minimum_size.y = 128 if compact else 180
		var caption: Label = scene.get_node("CampCaption")
		caption.add_theme_font_size_override("font_size", 17 if compact else 19)

func _small_label(parent: Node, text: String, color: Color = VISUALS.MUTED) -> Label:
	var label := _label(parent, text)
	STYLE.apply_label_font(label, 14, color)
	return label

func _build_field(parent: VBoxContainer) -> void:
	var scene := Control.new()
	scene.name = "CampScene"
	scene.custom_minimum_size.y = 180
	scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scene.clip_contents = true
	parent.add_child(scene)
	VISUALS.add_backdrop(scene)
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.04, 0.07, 0.10, 0.12), Color(0.04, 0.07, 0.10, 0.05), Color(0.04, 0.07, 0.10, 0.94)])
	gradient.offsets = PackedFloat32Array([0.0, 0.50, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	shade.texture = texture
	scene.add_child(shade)
	var location := _small_label(scene, "营地 / 通讯台", VISUALS.TEXT)
	location.autowrap_mode = TextServer.AUTOWRAP_OFF
	location.position = Vector2(22, 18)
	var caption := _label(scene, _camp_caption())
	caption.name = "CampCaption"
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_left = 22
	caption.offset_right = -22
	caption.offset_top = -88
	caption.offset_bottom = -20
	caption.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	caption.add_theme_font_size_override("font_size", 19)
	var objects := HFlowContainer.new()
	objects.add_theme_constant_override("h_separation", 8)
	objects.add_theme_constant_override("v_separation", 6)
	parent.add_child(objects)
	var radio := _button(objects, "通讯台 · 谈话记录", _open_record.bind("谈话记录"))
	radio.name = "RadioRecord"
	radio.tooltip_text = "回看已经听过的话，不推进任务。"
	VISUALS.style_button(radio, false, true)
	for quest: Dictionary in CONTENT.entries("quests"):
		var item_id: String = quest.first_clear_reward.items[0].item_id
		var completed: bool = profile.story.quest_states[quest.id] == "completed"
		if not completed and PROGRESS.item_quantity(profile, item_id) <= 0:
			continue
		var object_name: String = CONTENT.find("items", item_id).name
		var button := _button(objects, object_name + (" · 已整理" if completed else " · 待交付"), _open_record.bind("情报" if completed else "剧情物品"))
		button.name = "Clue_" + quest.stage_id
		VISUALS.style_button(button, false, true)

func _camp_caption() -> String:
	if profile.story.flags.get("chapter1.communications_restored", false):
		return "通讯台旁多了一张椅子。\n今晚，终于有了回答。"
	var quest := PROGRESS.current_quest(profile)
	if quest.is_empty():
		return "灯还亮着。"
	var ready: bool = profile.story.quest_states[quest.id] == "ready_to_turn_in"
	match quest.id:
		"q.c1.outpost":
			return "一本沾着沙的记录，被放在了灯下。" if ready else "天黑后，通讯台的灯一直亮着。\n前哨还没有回答。"
		"q.c1.rift":
			return "玻璃瓶轻轻震着。\n杂音跟着停顿了一下。" if ready else "值班记录翻到了最后一页。\n有人把裂隙的方向圈了出来。"
		_:
			return "核心被放到了通讯台旁。\n这一次，大家都没有离开。" if ready else "每一次停顿，都像在等一个回答。"

func _build_route(parent: VBoxContainer) -> void:
	var heading := HBoxContainer.new()
	parent.add_child(heading)
	_small_label(heading, "调查路线", VISUALS.TEXT).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_small_label(heading, "重访仅供练习")
	var route := HBoxContainer.new()
	route.name = "StoryRoute"
	route.add_theme_constant_override("separation", 10)
	parent.add_child(route)
	var index := 0
	for quest: Dictionary in CONTENT.entries("quests"):
		index += 1
		var state: String = profile.story.quest_states[quest.id]
		var cleared: bool = quest.stage_id in profile.story.completed_stage_ids
		var stage_name: String = CONTENT.stage(quest.stage_id).title.trim_prefix("第一章·")
		var status: String = {"locked": "尚未抵达", "available": "等待交谈", "active": "调查中", "ready_to_turn_in": "等待交付", "completed": "已完成 · 重访"}.get(state, "")
		var button := _button(route, "%02d  %s\n%s" % [index, "未知地点" if state == "locked" else stage_name, status], _start_stage.bind(quest.stage_id, "replay"))
		button.name = "Route_" + quest.stage_id
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, 66)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = not cleared or not profile.story.active_attempt.is_empty() or recovery_needed
		button.tooltip_text = "练习不推进主线，也不会重复发放永久剧情材料。" if cleared else "从右侧当前线索继续主线。"
		if state not in ["locked", "completed"]:
			button.add_theme_stylebox_override("disabled", STYLE.panel_style(VISUALS.PANEL, VISUALS.GOLD, 1, 3, 12))
			button.add_theme_color_override("font_disabled_color", VISUALS.GOLD)

func _build_objective(parent: VBoxContainer) -> void:
	_small_label(parent, "当前线索", VISUALS.GOLD)
	if notice != "":
		_label(parent, notice)
	if recovery_needed:
		_button(parent, "保留诊断文件并放弃本关构筑", _confirm_abandon)
	var quest := PROGRESS.current_quest(profile)
	if quest.is_empty():
		_label(parent, "远处的回答", true)
		_label(parent, "通讯已恢复。带回来的线索都留在了这里。")
		_button(parent, "回看调查成果", _open_record.bind("情报"), true)
	else:
		_label(parent, quest.name, true)
		var state: String = profile.story.quest_states[quest.id]
		_label(parent, quest.ready_text if state == "ready_to_turn_in" else quest.objective_text)
	var checkpoint: Dictionary = profile.story.dialogue_checkpoint
	if not checkpoint.is_empty():
		_button(parent, "继续上次交谈", _open_dialogue.bind(checkpoint.conversation_id), true)
	var attempt: Dictionary = profile.story.active_attempt
	if not attempt.is_empty():
		_small_label(parent, "进行中的战局 · %s\n原阵容：%s" % [CONTENT.stage(attempt.stage_id).title, _team_names(attempt.team_order)])
		_button(parent, "继续当前战局", _continue, true).disabled = recovery_needed
		_button(parent, "放弃本关构筑", _confirm_abandon)
	if not quest.is_empty():
		var state: String = profile.story.quest_states[quest.id]
		if state in ["available", "ready_to_turn_in"]:
			var npc: String = quest.turn_in_npc if state == "ready_to_turn_in" else quest.accept_npc
			var conversation: String = quest.dialogues.turn_in if state == "ready_to_turn_in" else quest.dialogues.accept
			_button(parent, ("交付给" if state == "ready_to_turn_in" else "与") + CONTENT.find("speakers", npc).name + ("" if state == "ready_to_turn_in" else "确认任务"), _open_dialogue.bind(conversation), checkpoint.is_empty())
		elif attempt.is_empty():
			_button(parent, "出击：" + CONTENT.stage(quest.stage_id).title, _start_stage.bind(quest.stage_id, "advance"), true).disabled = recovery_needed
			_small_label(parent, "本关从初始构筑出发；任务与调查成果保留。")

func _build_people(parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())
	_small_label(parent, "营地的人", VISUALS.GOLD)
	for speaker: Dictionary in CONTENT.entries("speakers"):
		var conversations := PROGRESS.dialogues_for_npc(profile, speaker.id)
		var button := _button(parent, speaker.name + _npc_hint(conversations), _talk.bind(speaker.id))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = conversations.is_empty()
		VISUALS.style_button(button, false, true)

func _build_results(parent: VBoxContainer) -> void:
	if not profile.story.pending_presentation.is_empty():
		parent.add_child(HSeparator.new())
		_small_label(parent, "这次带回的消息", VISUALS.GOLD)
		for receipt in profile.story.pending_presentation:
			for quest: Dictionary in CONTENT.entries("quests"):
				if receipt == quest.first_clear_reward.receipt_id:
					_small_label(parent, "%s已带回，等待与%s交付。" % [CONTENT.find("items", quest.first_clear_reward.items[0].item_id).name, CONTENT.find("speakers", quest.turn_in_npc).name])
				elif receipt == quest.turn_in.receipt_id:
					_small_label(parent, quest.name + "：已交付，成果已收入情报。")
		_button(parent, "已阅成果", _ack_results)
	var last: Dictionary = profile.story.last_settlement
	if not last.get("summary", {}).is_empty():
		parent.add_child(HSeparator.new())
		var outcome: String = {"victory": "通关", "failed": "失败", "abandoned": "主动结束"}.get(last.get("outcome", ""), "结束")
		_small_label(parent, "上次出击 · %s\n%s" % [outcome, preload("res://scripts/game/run_outcome.gd").describe(last.summary)])

func _open_record(tab_name: String) -> void:
	journal_panel.open(SAVE_MANAGER.load_story_profile(slot), tab_name)

func _npc_hint(conversations: Array) -> String:
	if conversations.is_empty():
		return " · 暂无新消息"
	return {"turn_in": " · 待交付", "accept": " · 可接任务", "reminder": " · 任务提醒", "optional": " · 交谈"}.get(conversations[0].kind, "")

func _team_names(team: Array) -> String:
	var names := PackedStringArray()
	for role in team:
		names.append(CONTENT.find("speakers", role).get("name", role))
	return " → ".join(names)

func _talk(npc: String) -> void:
	var conversations := PROGRESS.dialogues_for_npc(SAVE_MANAGER.load_story_profile(slot), npc)
	if conversations.size() == 1:
		_open_dialogue(conversations[0].id)
	elif not conversations.is_empty():
		var menu := PopupMenu.new()
		add_child(menu)
		for i in conversations.size():
			menu.add_item(_npc_hint([conversations[i]]).trim_prefix(" · "), i)
		menu.id_pressed.connect(func(index): _open_dialogue(conversations[index].id))
		menu.popup_hide.connect(menu.queue_free)
		menu.popup_centered(Vector2i(300, 160))

func _open_dialogue(id: String) -> void:
	if not dialogue_panel.open(slot, id):
		notice = "对话状态已变化或保存失败，请重试。"
		_rebuild_ui()

func _open_journal() -> void:
	journal_panel.open(SAVE_MANAGER.load_story_profile(slot))

func _start_stage(id: String, purpose: String) -> void:
	var response := PROGRESS.begin_stage(slot, id, purpose)
	if response.ok:
		SAVE_MANAGER.request_continue()
		get_tree().change_scene_to_file(STORY_DATA.BATTLE_SCENE_PATH)
	else:
		notice = PROGRESS.message(response.reason)
		_rebuild_ui()

func _continue() -> void:
	var response := PROGRESS.continue_attempt(slot)
	if response.ok:
		get_tree().change_scene_to_file(STORY_DATA.BATTLE_SCENE_PATH)
	else:
		notice = PROGRESS.message(response.reason)
		_rebuild_ui()

func _confirm_abandon() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "放弃本关构筑"
	dialog.dialog_text = "本关等级、技能点分配和局内装备将结束。任务进度、剧情物品和情报保留。"
	dialog.ok_button_text = "放弃本关"
	dialog.cancel_button_text = "保留战局"
	add_child(dialog)
	dialog.confirmed.connect(func():
		var response := PROGRESS.abandon_unreadable_run(slot)
		notice = "本关已结束，可重新出击。" if response.ok else PROGRESS.message(response.reason)
		recovery_needed = not response.ok
		_rebuild_ui()
	)
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			dialog.queue_free()
	)
	dialog.popup_centered(Vector2i(500, 220))

func _ack_results() -> void:
	var response := PROGRESS.ack_presentation(slot, profile.story.pending_presentation)
	notice = "" if response.ok else PROGRESS.message(response.reason)
	_rebuild_ui()

func _on_swap_team_pressed() -> void:
	team_swap_panel.open(SAVE_MANAGER.MODE_STORY)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not dialogue_panel.visible and not journal_panel.visible and not team_swap_panel.visible:
		_on_back_pressed()
		get_viewport().set_input_as_handled()
