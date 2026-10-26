extends Control

signal closed
const MODAL := preload("res://scripts/ui/core/survivors_modal.gd")
const STYLE := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const VISUALS := preload("res://scripts/ui/story/story_visuals.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")
const CONTENT := preload("res://scripts/story/story_content.gd")
const PROGRESS := preload("res://scripts/story/story_progress.gd")
const STATUS := {"locked": "未解锁", "available": "可接受", "active": "进行中", "ready_to_turn_in": "待交付", "completed": "已完成"}
var modal: Control
var opener: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal = MODAL.new()
	modal.configure(Vector2(980, 660), 0.90, 0.90, Vector2(400, 340))
	modal.set_title("任务与记录")
	modal.set_hint("任务物品不占无尽携带位。谈话记录仅供回看，不会再次执行交付。")
	add_child(modal)
	VISUALS.style_button(modal.add_footer_button("返回准备", close), false, true)
	get_viewport().size_changed.connect(_style_modal.call_deferred)
	hide()

func open(profile: Dictionary, tab_name: String = "任务") -> void:
	opener = get_viewport().gui_get_focus_owner()
	var tabs := TabContainer.new()
	tabs.add_theme_stylebox_override("panel", STYLE.panel_style(VISUALS.PANEL, VISUALS.LINE, 0, 0, 16))
	var bar := tabs.get_tab_bar()
	bar.add_theme_font_override("font", STYLE.get_reading_font())
	bar.add_theme_font_size_override("font_size", 17)
	bar.add_theme_color_override("font_selected_color", VISUALS.TEXT)
	bar.add_theme_color_override("font_unselected_color", VISUALS.MUTED)
	bar.add_theme_stylebox_override("tab_selected", STYLE.panel_style(VISUALS.PANEL, VISUALS.LINE, 1, 3, 12))
	bar.add_theme_stylebox_override("tab_unselected", STYLE.panel_style(VISUALS.BG, VISUALS.LINE, 0, 3, 12))
	bar.add_theme_stylebox_override("tab_hovered", STYLE.panel_style(VISUALS.PANEL.lightened(0.06), VISUALS.LINE, 0, 3, 12))
	bar.add_theme_stylebox_override("tab_focus", STYLE.panel_style(Color(0, 0, 0, 0), VISUALS.GOLD, 2, 3))
	modal.set_body(tabs)
	var quests := _page(tabs, "任务")
	for quest: Dictionary in CONTENT.entries("quests"):
		var state := str(profile.story.quest_states[quest.id])
		if state == "locked":
			_record(quests, "未解锁的任务", "完成当前主线交付后开放。")
		else:
			_record(quests, "%s · %s" % [quest.name, STATUS[state]], quest.ready_text if state == "ready_to_turn_in" else quest.objective_text)
	var items := _page(tabs, "剧情物品")
	var count := 0
	for item: Dictionary in CONTENT.entries("items"):
		var quantity := PROGRESS.item_quantity(profile, item.id)
		if quantity <= 0:
			continue
		count += 1
		var quest := CONTENT.find("quests", item.turn_in_quest_id)
		_record(items, "%s ×%d" % [item.name, quantity], "%s\n来源：%s首通。交付对象：%s。\n剧情物品不能出售、丢弃或转赠。" % [item.description, CONTENT.stage(item.source_stage_id).title, CONTENT.find("speakers", quest.turn_in_npc).name])
	if count == 0:
		_record(items, "当前没有待交付物品", "完成当前任务的关卡后，关键物品会随首通结果保存；已交付内容可在情报页查看。")
	var journal := _page(tabs, "情报")
	for entry_id in profile.story.journal_entries:
		var entry := CONTENT.find("journal_entries", entry_id)
		_record(journal, entry.title, entry.text)
	if profile.story.journal_entries.is_empty():
		_record(journal, "还没有调查结果", "交付记录、样本或核心后，相应成果会保留在这里。")
	var history := _page(tabs, "谈话记录")
	for conversation in profile.story.dialogue_seen_nodes:
		var dialogue := CONTENT.find("dialogues", conversation)
		var text := ""
		for node_id in profile.story.dialogue_seen_nodes[conversation]:
			var node := CONTENT.node(conversation, node_id)
			if node.is_empty():
				continue
			if not str(node.get("narration", "")).is_empty():
				text += "%s\n" % node.narration
			text += "%s：%s\n\n" % [CONTENT.find("speakers", node.speaker).name, node.text]
		_record(history, "与%s的交谈" % CONTENT.find("speakers", dialogue.npc_id).name, text.strip_edges())
	if profile.story.dialogue_seen_nodes.is_empty():
		_record(history, "还没有谈话记录", "与营地人物交谈后，实际读过的内容会保存在这里。")
	for index in tabs.get_tab_count():
		if tabs.get_tab_title(index) == tab_name:
			tabs.current_tab = index
			break
	show()
	modal.apply_layout()
	_style_modal()
	tabs.get_tab_bar().grab_focus.call_deferred()

func _style_modal() -> void:
	modal.panel.add_theme_stylebox_override("panel", STYLE.panel_style(VISUALS.BG, VISUALS.LINE, 1, 3))
	modal.title_label.add_theme_color_override("font_color", VISUALS.TEXT)
	modal.hint_label.add_theme_color_override("font_color", VISUALS.MUTED)
	modal.hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _page(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	scroll.add_child(column)
	return column

func _record(column: VBoxContainer, title: String, text: String) -> void:
	var heading := STYLE.make_title_label(title)
	heading.add_theme_color_override("font_color", VISUALS.GOLD)
	heading.add_theme_font_size_override("font_size", 21)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	var description := Label.new()
	description.text = text
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	STYLE.apply_label_font(description, SETTINGS.story_font_size(17), VISUALS.TEXT)
	column.add_child(description)
	var divider := HSeparator.new()
	divider.add_theme_stylebox_override("separator", STYLE.panel_style(VISUALS.LINE, VISUALS.LINE, 0, 0))
	column.add_child(divider)

func close() -> void:
	hide()
	if is_instance_valid(opener) and opener.is_visible_in_tree():
		opener.grab_focus()
	closed.emit()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if modal.cycle_keyboard_focus(event):
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
