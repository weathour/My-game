extends Control
## Presentation coordinator. Gameplay state lives in CampaignService; combat is a disposable BattleSession.
const STYLE := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const SESSION := preload("res://scripts/campaign/campaign_service.gd")
const MAP := preload("res://scripts/ui/chronicle/chronicle_map.gd")
const CHROME := preload("res://scripts/ui/chronicle/chronicle_campaign_chrome.gd")
const WORLD_PAGE := preload("res://scripts/ui/chronicle/chronicle_world_page.gd")
const ROUTE_PAGE := preload("res://scripts/ui/chronicle/chronicle_route_page.gd")
const PAGES := preload("res://scripts/ui/chronicle/chronicle_pages.gd")
const BATTLE := preload("res://scripts/ui/chronicle/battle_view.gd")
const TERRAIN := preload("res://assets/ui/chronicle/baimen-terrain.png")
const EMMA := preload("res://assets/ui/chronicle/emma.png")
const SETTINGS := preload("res://scripts/game_settings.gd")
const BGM := preload("res://scripts/bgm_player.gd")
const MUSIC_CONTEXT := preload("res://scripts/audio/chronicle_music.gd")
const MUSIC := preload("res://scripts/audio/music_catalog.gd")
const STORIES := preload("res://scripts/content/story_catalog.gd")
const CODEX := preload("res://scripts/ui/chronicle/enemy_codex.gd")
const STORY_VIEW := preload("res://scripts/ui/chronicle/chronicle_story_view.gd")
const CHARACTER_SHEET := preload("res://scripts/ui/chronicle/chronicle_character_sheet.gd")

var session: RefCounted = SESSION.new()
var battle_script: Script = BATTLE
var page := "home"
var previous_page := "world"
var selected_province := "徐州"
var world_tasks_open := false
var selected_node := "S01"
var selected_character := "JIA"
var roster_filter := "owned"
var character_return := "roster"
var reward_focus := ""
var party_return := "route"
var party_preparation := false
var enemy_codex: Control
var character_sheet: Control
var character_sheet_opener: WeakRef
var character_sheet_opener_name := ""
var character_sheet_origin := ""
var menu_return := "route"
var search_text := ""
var segment := 0
var equipment_slot := "weapon"
var selected_equipment := "plain_blade"
var body: Control
var frame: Control
var modal: Control
var status: Label
var battle_view: Control
var story_view: Control
var route_map: Control
var route_scroll := -1.0
var route_view_size := Vector2.ZERO
var replay_event := ""
var replay_line := ""
var replay_return := "route"
var bgm: AudioStreamPlayer
var music_preview: AudioStreamPlayer
var music_index := 0
var music_return := "home"
var music_seeking := false
var scroll_memory := {}
var focus_memory := {}
var rendered_page := ""
var _render_queued := false
var music_tracks: Array[String] = []
var _preview_snapshot := {}
var _replay_snapshot := {}
var _return_music_snapshot := {}
var _last_story_music_line := ""
var _battle_music_outcome := ""

func _ready() -> void:
	theme = STYLE.make_theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	session.problem.connect(_on_session_problem)
	bgm = BGM.new()
	bgm.name = "ChronicleMusic"
	bgm.initial_cue = "title_overture"
	bgm.context_id = "page:home"
	add_child(bgm)
	resized.connect(queue_render)
	render()

func queue_render() -> void:
	if _render_queued or page == "battle": return
	_render_queued = true
	render.call_deferred()

func open_page(value: String) -> void:
	if page == "battle": return
	# Character inspection is an overlay of the current page, including callers
	# which previously requested the standalone character route.
	if value == "character":
		inspect_character(selected_character)
		return
	PAGES.PARTY.cancel_interaction(self)
	if is_instance_valid(character_sheet): close_character_sheet(false)
	if page == "music" and value != "music": close_music()
	if page == "replay" and value != "replay":
		if value == replay_return: _return_music_snapshot = _replay_snapshot
		_clear_story_replay()
	if value in ["roster", "equipment", "preparation"] and page not in ["roster", "equipment", "preparation", "character"]:
		party_return = "route" if value == "preparation" else page
		party_preparation = value == "preparation"
	if value == "preparation": party_preparation = true
	if value in ["event", "preparation"]: previous_page = "route"
	if value in ["roster", "equipment", "saves", "settings", "journal"] and page in ["world", "route", "home", "reward", "preparation", "event", "menu"]:
		previous_page = page
	page = value
	_sync_page_music()
	render()

func resume() -> void:
	if not session.read_slot("auto").is_empty() and not session.load_slot("auto"): return
	resume_view(true)

func resume_view(enter_event: bool = false) -> void:
	PAGES.PARTY.cancel_interaction(self)
	if is_instance_valid(character_sheet): close_character_sheet(false)
	_clear_story_replay()
	route_scroll = -1.0
	selected_node = session.data.current
	segment = int(session.nodes[selected_node].segment)
	page = "reward" if not session.data.pending.is_empty() else "route" if session.data.started and not session.data.finished else "world"
	var checkpoint: Dictionary = session.data.get("story_checkpoint", {})
	var battle_story: bool = session.has_method("awaiting_battle_story") and session.awaiting_battle_story()
	if page == "route" and (battle_story or (session.nodes[selected_node].kind in ["event", "spring"] and (enter_event or checkpoint.get("event") == selected_node))):
		page = "event"
	_sync_page_music()
	render()

func render() -> void:
	_render_queued = false
	if not is_inside_tree() or page == "battle": return
	var reading_state: Dictionary = {}
	if page == rendered_page and page in ["event", "replay"] and is_instance_valid(story_view) and story_view.is_inside_tree():
		reading_state = story_view.reading_state()
	var focus_name := ""
	var focus := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focus) and is_instance_valid(frame) and frame.is_ancestor_of(focus):
		focus_name = str(focus.name)
		focus_memory[rendered_page] = focus_name
	if page != rendered_page: focus_name = focus_memory.get(page, "")
	if is_instance_valid(frame):
		var scrolls := {}
		for scroll in frame.find_children("*", "ScrollContainer", true, false): scrolls[str(scroll.name)] = scroll.scroll_vertical
		scroll_memory[rendered_page] = scrolls
		remove_child(frame)
		frame.queue_free()
	story_view = null
	if is_instance_valid(route_map): route_view_size = route_map.size
	route_map = null
	frame = Control.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)
	var background := TextureRect.new()
	background.texture = TERRAIN
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color("899383")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout := VBoxContainer.new()
	frame.add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 0)
	body = Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	match page:
		"home": build_home()
		"world": build_world()
		"route": build_route()
		_: PAGES.build(self, page)
	if not reading_state.is_empty() and is_instance_valid(story_view):
		story_view.restore_reading_state(reading_state)
	for scroll in frame.find_children("*", "ScrollContainer", true, false):
		if scroll_memory.get(page, {}).has(str(scroll.name)):
			scroll.set_deferred("scroll_vertical", scroll_memory[page][str(scroll.name)])
	rendered_page = page
	if page in ["event", "replay"]:
		pass # The story reader owns its input and initial focus.
	elif is_instance_valid(enemy_codex) or is_instance_valid(character_sheet):
		pass # Read-only overlays retain keyboard ownership through page reflow.
	elif not focus_name.is_empty():
		var replacement := frame.find_child(focus_name, true, false)
		if replacement is Control and replacement.focus_mode != Control.FOCUS_NONE:
			_focus_control.call_deferred(weakref(replacement))
	else:
		for button in body.find_children("*", "Button", true, false):
			if not button.disabled:
				_focus_control.call_deferred(weakref(button))
				break
	if is_instance_valid(enemy_codex): move_child(enemy_codex, -1)
	if is_instance_valid(character_sheet): move_child(character_sheet, -1)
	if is_instance_valid(modal): move_child(modal, -1)

func build_story() -> void:
	var id: String = session.data.current
	if not session.data.pending.is_empty() or id not in session.data.available or (session.has_method("event_available") and not session.event_available(id)):
		page = "reward" if not session.data.pending.is_empty() else "route"
		queue_render()
		return
	var event := STORIES.for_node(session.nodes[id])
	if id == "S02" and not session.data.owned.has("F11"):
		event.completion_hint = "剧情结束后，艾玛加入队伍并进入卡池。"
	elif session.UNLOCKS.has(id):
		var names: Array[String] = []
		for person in session.UNLOCKS[id]: names.append(session.characters[person].name)
		event.completion_hint = "剧情结束后加入卡池：" + "、".join(names)
	if session.nodes[id].kind == "spring": event.finish_label = "饮泉休整"
	var checkpoint: Dictionary = session.data.get("story_checkpoint", {})
	var line := STORIES.line_id(event, checkpoint)
	story_view = STORY_VIEW.new()
	story_view.name = "CampaignStory"
	story_view.setup(event, line)
	story_view.line_presented.connect(_on_story_music_line.bind(event, false))
	story_view.advance_requested.connect(_advance_story)
	story_view.leave_requested.connect(func(): open_page("route"))
	body.add_child(story_view)
	_apply_music("story:" + id, MUSIC_CONTEXT.story_cue(event, line))
	if checkpoint != {"event":id, "line":line} and session.has_method("save_story_checkpoint"):
		if not session.save_story_checkpoint(id, line): story_view.show_error("未能保存阅读位置，请重试。")

func _advance_story(line: String) -> void:
	if page != "event" or not is_instance_valid(story_view): return
	story_view.set_busy(true)
	if line.is_empty():
		if session.resolve_event(): resume_view()
		else: story_view.show_error("未能保存本次结果，请重试。")
		return
	var event := STORIES.for_node(session.nodes[session.data.current])
	if not STORIES.has_line(event, line):
		story_view.show_error("未找到这段对白，请返回路线后重试。")
		return
	if not session.has_method("save_story_checkpoint") or session.save_story_checkpoint(session.data.current, line):
		story_view.show_line(line)
	else:
		story_view.show_error("未能保存阅读位置，请重试。")

func can_replay_story(id: String) -> bool:
	if page == "battle" or session.in_battle or id not in session.data.completed or not session.nodes.has(id) or not STORIES.has_event(id): return false
	return session.is_story_node(id) if session.has_method("is_story_node") else session.nodes[id].kind in ["event", "spring"]

func replayable_stories() -> Array[String]:
	var result: Array[String] = []
	for id in session.data.completed:
		if can_replay_story(id) and id not in result: result.append(id)
	return result

func open_story_replay(id: String, return_page: String = "route") -> bool:
	if not can_replay_story(id): return false
	_replay_snapshot = _music_snapshot(return_page)
	_last_story_music_line = ""
	replay_event = id
	replay_line = STORIES.line_id(STORIES.for_node(session.nodes[id]))
	replay_return = "journal" if return_page == "journal" else "route"
	open_page("replay")
	return true

func build_story_replay() -> void:
	if not can_replay_story(replay_event):
		close_story_replay()
		return
	var event := STORIES.for_node(session.nodes[replay_event])
	event.replay = true
	event.return_label = "返回见闻" if replay_return == "journal" else "返回路线"
	story_view = STORY_VIEW.new()
	story_view.name = "CampaignStoryReplay"
	story_view.setup(event, replay_line)
	# A separate callback owns replay. It has no campaign commit/resolve call.
	story_view.line_presented.connect(_on_story_music_line.bind(event, true))
	story_view.advance_requested.connect(_advance_story_replay)
	story_view.leave_requested.connect(close_story_replay)
	body.add_child(story_view)
	_apply_music("replay:" + replay_event, MUSIC_CONTEXT.story_cue(event, replay_line))

func _advance_story_replay(line: String) -> void:
	if page != "replay" or not is_instance_valid(story_view): return
	if not can_replay_story(replay_event) or line.is_empty():
		close_story_replay()
		return
	var event := STORIES.for_node(session.nodes[replay_event])
	if not STORIES.has_line(event, line):
		story_view.show_error("未找到这段对白，请结束回顾后重试。")
		return
	replay_line = line
	story_view.show_line(line)

func close_story_replay() -> void:
	if page != "replay": return
	var target := replay_return
	open_page(target)

func _clear_story_replay() -> void:
	_replay_snapshot = {}
	_last_story_music_line = ""
	replay_event = ""
	replay_line = ""
	replay_return = "route"

func _on_session_problem(message: String) -> void:
	if page == "event" and is_instance_valid(story_view) and story_view.is_inside_tree():
		story_view.show_error(message)
	else:
		show_notice(message)

func quiet_action(parent: Node, title: String, callback: Callable, id: String, selected: bool = false) -> Button:
	var button := STYLE.quiet_button(title, callback, selected)
	button.name = id
	parent.add_child(button)
	return button

func party_tabs(parent: Node) -> void:
	var row := STYLE.row(parent)
	row.name = "party_tabs"
	quiet_action(row, "编队", func(): open_page("preparation" if party_preparation else "roster"), "party_tab_roster", page in ["roster", "preparation"])
	quiet_action(row, "行装", func(): open_page("equipment"), "party_tab_equipment", page == "equipment")

func inspect_character(id: String, tab: String = "abilities") -> void:
	if page == "battle" or not session.characters.has(id): return
	if is_instance_valid(enemy_codex) or is_instance_valid(modal): return
	PAGES.PARTY.cancel_interaction(self)
	selected_character = id
	if is_instance_valid(character_sheet):
		character_sheet.show_character(id, tab)
		return
	var focused := get_viewport().gui_get_focus_owner()
	character_sheet_opener = weakref(focused) if is_instance_valid(focused) else null
	character_sheet_opener_name = str(focused.name) if is_instance_valid(focused) and is_instance_valid(frame) and frame.is_ancestor_of(focused) else ""
	character_sheet_origin = page
	var return_label := str({"route":"返回行军", "world":"返回天下", "roster":"返回整备", "preparation":"返回出战整备"}.get(page, "关闭"))
	character_sheet = CHARACTER_SHEET.new()
	character_sheet.name = "CharacterInspection"
	character_sheet.z_index = 30
	character_sheet.theme = STYLE.make_theme()
	character_sheet.setup(session, id, tab, return_label)
	character_sheet.closed.connect(func(): close_character_sheet())
	add_child(character_sheet)
	character_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func close_character_sheet(restore_focus: bool = true) -> void:
	if not is_instance_valid(character_sheet): return
	var opener := character_sheet_opener
	var opener_name := character_sheet_opener_name
	var origin := character_sheet_origin
	remove_child(character_sheet)
	character_sheet.queue_free()
	character_sheet = null
	character_sheet_opener = null
	character_sheet_opener_name = ""
	character_sheet_origin = ""
	if restore_focus: _restore_character_focus.call_deferred(opener, opener_name, origin)

func _restore_character_focus(reference: WeakRef, opener_name: String, origin: String) -> void:
	if page != origin or is_instance_valid(character_sheet) or is_instance_valid(enemy_codex) or not is_instance_valid(frame): return
	var target: Variant = reference.get_ref() if reference != null else null
	if not is_instance_valid(target) or not target.is_inside_tree() or not frame.is_ancestor_of(target):
		target = frame.find_child(opener_name, true, false) if not opener_name.is_empty() else null
	if is_instance_valid(target) and target is Control: _focus_control(weakref(target))

func open_enemy_codex(stage_id: String = "") -> void:
	if is_instance_valid(enemy_codex): return
	var focused := get_viewport().gui_get_focus_owner()
	var opener: WeakRef = weakref(focused) if is_instance_valid(focused) else null
	var opener_name := str(focused.name) if is_instance_valid(focused) and frame.is_ancestor_of(focused) else ""
	var opener_page := page
	enemy_codex = CODEX.new()
	enemy_codex.stage_id = stage_id
	enemy_codex.z_index = 30
	enemy_codex.theme = STYLE.make_theme()
	enemy_codex.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(enemy_codex)
	enemy_codex.closed.connect(func():
		if is_instance_valid(enemy_codex):
			enemy_codex.queue_free()
			enemy_codex = null
		_restore_codex_focus.call_deferred(opener, opener_name, opener_page))

func _restore_codex_focus(reference: WeakRef, opener_name: String, opener_page: String) -> void:
	if page != opener_page or is_instance_valid(enemy_codex) or not is_instance_valid(frame): return
	var target: Variant = reference.get_ref() if reference != null else null
	if not is_instance_valid(target) or not target.is_inside_tree() or not frame.is_ancestor_of(target):
		target = frame.find_child(opener_name, true, false) if not opener_name.is_empty() else null
	if is_instance_valid(target) and target is Control: _focus_control(weakref(target))

func open_menu() -> void:
	menu_return = page
	open_page("menu")

func action(parent: Node, title: String, callback: Callable, id: String, primary: bool = false) -> Button:
	var button := STYLE.button(title, callback, primary)
	button.name = id
	parent.add_child(button)
	if size.y < 650: STYLE.compact_button(button)
	return button

func page_margin() -> MarginContainer:
	var margin := MarginContainer.new()
	body.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 10 if size.y < 650 else 16)
	return margin

func portrait(parent: Control, width: float, bottom: float = 0.0) -> TextureRect:
	var art := TextureRect.new()
	art.texture = EMMA
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	art.offset_left = -12
	art.offset_right = width
	art.offset_top = 0
	art.offset_bottom = bottom
	return art

func build_home() -> void:
	portrait(body, size.x * .43)
	var margin := page_margin()
	var row := STYLE.row(margin)
	STYLE.space(row)
	var panel := STYLE.panel(row, false, 28)
	panel.custom_minimum_size.x = 370
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var column := STYLE.column(panel)
	column.add_child(STYLE.label("三国志怪 · 战役录", 15, STYLE.MUTED))
	column.add_child(STYLE.label("白门楼", 52, STYLE.INK, true))
	column.add_child(STYLE.paragraph("白骨露于野，千里无鸡鸣。\n山河还在，且从这座鬼城起家。", STYLE.INK, 18))
	column.add_child(HSeparator.new())
	if not session.read_slot("auto").is_empty(): action(column, "继续行军", resume, "continue_campaign", true)
	action(column, "启程白门楼", func():
		confirm("重新开始行军？", "自动续档将回到贾苇索独自启程。另存的手动档保留。", func():
			if session.reset() and session.begin_campaign(): resume_view()), "new_campaign", true)
	action(column, "天下局势", func(): open_page("world"), "inspect_world")
	var utilities := STYLE.row(column)
	action(utilities, "音乐鉴赏", open_music, "music_room")
	action(utilities, "旧版战斗", func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"), "legacy_game")

func map_split() -> HBoxContainer:
	var row := STYLE.row(body)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	return row

func build_world() -> void:
	WORLD_PAGE.build(self)

func sidebar(parent: Node, title: String, subtitle: String) -> VBoxContainer:
	var panel := STYLE.panel(parent, false, 20)
	panel.custom_minimum_size.x = 310 if size.x >= 1150 else 270
	var column := STYLE.column(panel)
	column.add_child(STYLE.label(title, 28, STYLE.INK, true))
	column.add_child(STYLE.paragraph(subtitle, STYLE.MUTED, 14))
	column.add_child(HSeparator.new())
	return column

func build_route() -> void:
	ROUTE_PAGE.build(self)

func start_battle() -> void:
	PAGES.PARTY.cancel_interaction(self)
	var request: Dictionary = session.start_battle()
	if request.is_empty(): return
	page = "battle"
	_battle_music_outcome = ""
	bgm.context_id = "battle:" + str(request.node.id)
	bgm.restart_cue(MUSIC_CONTEXT.node_cue(str(request.node.id)))
	frame.hide()
	battle_view = battle_script.new()
	battle_view.setup(request, session.characters)
	if battle_view.has_signal("music_context_changed"): battle_view.music_context_changed.connect(_on_battle_music_context)
	battle_view.completed.connect(finish_battle)
	battle_view.failed.connect(func():
		close_battle()
		session.abandon_battle()
		open_page("failure"))
	battle_view.cancelled.connect(func():
		close_battle()
		session.abandon_battle()
		resume_view())
	add_child(battle_view)

func finish_battle(result: Dictionary) -> void:
	if session.complete_battle(result):
		close_battle()
		resume_view()

func close_battle() -> void:
	if is_instance_valid(battle_view):
		remove_child(battle_view)
		battle_view.queue_free()
	page = "route"
	frame.show()
	bgm.resume_music()

func show_notice(message: String) -> void:
	confirm("行军提示", message, Callable(), false)

func confirm(title: String, message: String, callback: Callable, cancellable: bool = true) -> void:
	if is_instance_valid(modal): modal.queue_free()
	var opener := get_viewport().gui_get_focus_owner()
	modal = ColorRect.new()
	modal.color = Color(0.08, .1, .08, .78)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var center := CenterContainer.new()
	modal.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := STYLE.panel(center)
	panel.custom_minimum_size.x = 470
	var column := STYLE.column(panel)
	column.add_child(STYLE.label(title, 26, STYLE.INK, true))
	var scroll := ScrollContainer.new()
	scroll.name = "modal_content"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content_height := maxf(64, (ceilf(message.length() / 25.0) + message.count("\n")) * 25)
	scroll.custom_minimum_size.y = minf(content_height, size.y - 220)
	if content_height > scroll.custom_minimum_size.y: scroll.focus_mode = Control.FOCUS_ALL
	column.add_child(scroll)
	var words := STYLE.paragraph(message)
	words.custom_minimum_size.x = 420
	scroll.add_child(words)
	var buttons := STYLE.row(column)
	var close := func():
		if is_instance_valid(modal):
			modal.queue_free()
			modal = null
		if is_instance_valid(opener): opener.grab_focus()
	var yes := action(buttons, "确认" if cancellable else "知道了", func(): close.call(); if callback.is_valid(): callback.call(), "modal_confirm", true)
	var no: Button
	if cancellable: no = action(buttons, "取消", close, "modal_cancel")
	var targets: Array = [yes, no] if cancellable else [yes]
	if scroll.focus_mode == Control.FOCUS_ALL: targets.append(scroll)
	for i in targets.size():
		targets[i].focus_next = targets[(i + 1) % targets.size()].get_path()
		targets[i].focus_previous = targets[(i + targets.size() - 1) % targets.size()].get_path()
	_focus_control.call_deferred(weakref(yes))

func _focus_control(reference: WeakRef) -> void:
	var control: Variant = reference.get_ref()
	if is_instance_valid(control) and control is Control and control.is_inside_tree() and control.is_visible_in_tree():
		if is_instance_valid(character_sheet) and not character_sheet.is_ancestor_of(control): return
		control.grab_focus()

func open_music() -> void:
	if page == "music": return
	music_return = page
	previous_page = page
	_preview_snapshot = _music_snapshot(page)
	bgm.cancel_stinger()
	bgm.pause_music()
	music_tracks = MUSIC.chapter_cues()
	if music_tracks.is_empty(): music_tracks.assign(MUSIC.CUES)
	music_preview = AudioStreamPlayer.new()
	add_child(music_preview)
	music_preview.finished.connect(render)
	page = "music"
	play_track(music_index)

func play_track(index: int) -> void:
	if not is_instance_valid(music_preview): return
	var next_index := posmod(index, music_tracks.size())
	var resource_path := MUSIC.path(music_tracks[next_index])
	var stream := load(resource_path) as AudioStream if ResourceLoader.exists(resource_path) else null
	if stream == null:
		show_notice("这首配乐暂时无法读取。")
		return
	music_seeking = false
	music_index = next_index
	music_preview.volume_linear = 0.0 if BGM.load_music_muted() else BGM.load_music_volume()
	# Preview plays the published original mix once; duplicate to keep bed loop settings private.
	stream = stream.duplicate()
	if stream is AudioStreamOggVorbis: stream.loop = false
	music_preview.stream = stream
	music_preview.stream_paused = false
	music_preview.play()
	render()

func close_music() -> void:
	if is_instance_valid(music_preview):
		music_preview.stop()
		music_preview.queue_free()
		music_preview = null
	_return_music_snapshot = _preview_snapshot
	_preview_snapshot = {}

func _process(_delta: float) -> void:
	if page != "music" or not is_instance_valid(music_preview): return
	music_preview.volume_linear = 0.0 if BGM.load_music_muted() else BGM.load_music_volume()
	var seek := frame.find_child("music_seek", true, false) as HSlider
	var clock := frame.find_child("music_clock", true, false) as Label
	if seek == null or music_preview.stream == null: return
	var position := music_preview.get_playback_position()
	if not music_seeking: seek.set_value_no_signal(position)
	clock.text = "%02d:%02d / %02d:%02d" % [int(position) / 60, int(position) % 60, int(seek.max_value) / 60, int(seek.max_value) % 60]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if is_instance_valid(enemy_codex) or is_instance_valid(character_sheet): return # Overlays own Escape while open.
	if page == "battle" and not is_instance_valid(modal): return
	if event.keycode == KEY_ESCAPE:
		if is_instance_valid(modal):
			modal.queue_free()
			modal = null
		elif page != "battle":
			if page == "home": open_page("world")
			elif page in ["roster", "equipment"]: open_page(party_return)
			elif page in ["saves", "settings", "journal"]: open_page(previous_page)
			elif page == "reward": show_notice("请完成本关选卡；也可以保存行军档，稍后继续同一组候选。")
			elif page == "replay": close_story_replay()
			elif page in ["event", "preparation", "failure"]: open_page("route")
			elif page == "character": open_page(character_return)
			elif page == "menu": open_page(menu_return)
			elif page == "music": open_page(music_return)
			else: open_page("home")
		get_viewport().set_input_as_handled()

func _session_music_key() -> String:
	return JSON.stringify(session.data)

func _music_snapshot(return_page: String) -> Dictionary:
	return {"playback":bgm.capture_snapshot(), "session":_session_music_key(), "page":return_page}

func _sync_page_music() -> void:
	if not _return_music_snapshot.is_empty():
		var saved := _return_music_snapshot
		_return_music_snapshot = {}
		if saved.get("session") == _session_music_key() and saved.get("page") == page:
			bgm.restore_snapshot(saved.playback)
			return
		bgm.resume_music()
	if page in ["music", "replay", "event", "battle"]: return
	_last_story_music_line = ""
	var cue := MUSIC_CONTEXT.page_cue(page, str(session.data.current), "preparation" if party_preparation else previous_page)
	if cue.is_empty(): return
	# A pending result stinger owns the short battle tail until its natural completion.
	if page in ["reward", "failure"] and bgm.context_id == "result:" + str(session.data.current): return
	_apply_music("page:" + page, cue)

func _apply_music(context: String, cue: String) -> void:
	var changed: bool = bgm.context_id != context
	if changed:
		bgm.cancel_stinger()
		bgm.context_id = context
	bgm.set_cue(cue)
	if changed: bgm.resume_music()

func _on_story_music_line(line: String, event: Dictionary, replay: bool) -> void:
	var id := str(event.get("id", ""))
	_apply_music(("replay:" if replay else "story:") + id, MUSIC_CONTEXT.story_cue(event, line))
	var key := ("replay:" if replay else "story:") + id + ":" + line
	if key == _last_story_music_line: return
	_last_story_music_line = key
	var cue := MUSIC_CONTEXT.line_stinger(event, line)
	if not cue.is_empty(): bgm.play_stinger(cue)

func _on_battle_music_context(id: String, form_index: int, paused: bool, outcome: String) -> void:
	if page != "battle": return
	if paused: bgm.pause_music()
	else: bgm.resume_music()
	if not outcome.is_empty():
		if outcome == _battle_music_outcome: return
		_battle_music_outcome = outcome
		bgm.context_id = "result:" + id
		bgm.cancel_stinger()
		if outcome == "failed":
			bgm.play_stinger("stinger_defeat", "story_solitude")
		elif id not in MUSIC_CONTEXT.SERIOUS_RESULTS:
			bgm.play_stinger("stinger_important_victory" if id == "B18" else "stinger_victory", "results_flow")
		return
	var cue := MUSIC_CONTEXT.battle_cue(id, form_index)
	if cue != bgm.current_cue:
		bgm.set_cue(cue, 0.65)
		if form_index > 0: bgm.play_stinger("stinger_transform")
