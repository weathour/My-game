extends Control
## Presentation coordinator. Gameplay state lives in CampaignService; combat is a disposable BattleSession.
const STYLE := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const SESSION := preload("res://scripts/campaign/campaign_service.gd")
const MAP := preload("res://scripts/ui/chronicle/chronicle_map.gd")
const PAGES := preload("res://scripts/ui/chronicle/chronicle_pages.gd")
const BATTLE := preload("res://scripts/ui/chronicle/battle_view.gd")
const TERRAIN := preload("res://assets/ui/chronicle/baimen-terrain.png")
const EMMA := preload("res://assets/ui/chronicle/emma.png")
const SETTINGS := preload("res://scripts/game_settings.gd")
const BGM := preload("res://scripts/bgm_player.gd")
const MUSIC := preload("res://scripts/audio/music_catalog.gd")

var session: RefCounted = SESSION.new()
var battle_script: Script = BATTLE
var page := "home"
var previous_page := "world"
var selected_province := "徐州"
var selected_node := "S01"
var selected_character := "JIA"
var roster_filter := "owned"
var character_return := "roster"
var reward_focus := ""
var route_overview := false
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
var bgm: AudioStreamPlayer
var music_preview: AudioStreamPlayer
var music_index := 0
var music_return := "home"
var scroll_memory := {}
var focus_memory := {}
var rendered_page := ""
var _render_queued := false

func _ready() -> void:
	theme = STYLE.make_theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	session.problem.connect(show_notice)
	bgm = BGM.new()
	bgm.name = "ChronicleMusic"
	add_child(bgm)
	resized.connect(queue_render)
	render()

func queue_render() -> void:
	if _render_queued or page == "battle": return
	_render_queued = true
	render.call_deferred()

func open_page(value: String) -> void:
	if page == "battle": return
	if page == "music" and value != "music": close_music()
	if value in ["event", "preparation"]: previous_page = "route"
	if value in ["roster", "equipment", "saves", "settings", "journal"] and page in ["world", "route", "home", "reward", "preparation", "event", "menu"]:
		previous_page = page
	page = value
	render()

func resume() -> void:
	if not session.read_slot("auto").is_empty(): session.load_slot("auto")
	resume_view()

func resume_view() -> void:
	selected_node = session.data.current
	segment = int(session.nodes[selected_node].segment)
	page = "reward" if not session.data.pending.is_empty() else "route" if session.data.started and not session.data.finished else "world"
	render()

func render() -> void:
	_render_queued = false
	if not is_inside_tree() or page == "battle": return
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
	if page not in ["home", "reward", "event", "character", "menu"]: build_header(layout)
	body = Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	match page:
		"home": build_home()
		"world": build_world()
		"route": build_route()
		_: PAGES.build(self, page)
	if page in ["world", "route"]: build_footer(layout)
	for scroll in frame.find_children("*", "ScrollContainer", true, false):
		if scroll_memory.get(page, {}).has(str(scroll.name)):
			scroll.set_deferred("scroll_vertical", scroll_memory[page][str(scroll.name)])
	rendered_page = page
	if not focus_name.is_empty():
		var replacement := frame.find_child(focus_name, true, false)
		if replacement is Control and replacement.focus_mode != Control.FOCUS_NONE:
			_focus_control.call_deferred(weakref(replacement))
	else:
		for button in body.find_children("*", "Button", true, false):
			if not button.disabled:
				_focus_control.call_deferred(weakref(button))
				break
	if is_instance_valid(modal): move_child(modal, -1)

func build_header(parent: Node) -> void:
	var panel := STYLE.panel(parent, true, 8 if size.y < 650 else 11)
	var row := STYLE.row(panel)
	var brand := STYLE.label("白 门 楼", 25, STYLE.LIGHT, true)
	brand.custom_minimum_size.x = 160
	row.add_child(brand)
	for item in [["world", "天下"], ["route", "战役"], ["roster", "编队"], ["equipment", "行装"]]:
		var target: String = item[0]
		var button := action(row, item[1], func():
			if target == "route": resume_view()
			else: open_page(target), "nav_" + target)
		button.custom_minimum_size = Vector2(70, 34 if size.y < 650 else 40)
		if page == target: button.add_theme_stylebox_override("normal", STYLE.box(STYLE.OLIVE, STYLE.LIGHT, 10))
		if page == target: button.add_theme_color_override("font_color", STYLE.LIGHT)
	STYLE.space(row)
	var menu := action(row, "菜单", open_menu, "nav_settings")
	menu.custom_minimum_size.x = 70

func build_footer(parent: Node) -> void:
	var panel := STYLE.panel(parent, true, 8)
	var row := STYLE.row(panel)
	action(row, "编队与行装", func(): open_page("roster"), "footer_party")
	var names: Array[String] = []
	for id in session.roster(): names.append(session.characters[id].name)
	row.add_child(STYLE.label(" · ".join(names), 14, STYLE.LIGHT))
	STYLE.space(row)
	if not session.data.pending.is_empty(): action(row, "完成选卡", func(): open_page("reward"), "footer_reward", true)
	action(row, "行军档", func(): open_page("saves"), "footer_saves")
	action(row, "见闻", func(): open_page("journal"), "footer_journal")

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
	var canvas := MAP.new()
	canvas.selected = selected_province
	body.add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.province_selected.connect(func(id: String): selected_province = id; render())
	for id in MAP.LOCATIONS:
		var province: String = id
		var button := action(canvas, province, func(): selected_province = province; render(), "province_" + province, province == selected_province)
		button.custom_minimum_size = Vector2(60, 32)
		STYLE.compact_button(button)
		button.size = button.custom_minimum_size
		canvas.resized.connect(func(): button.position = canvas.province_position(province) - button.size / 2)
	var panel := STYLE.panel(body, true, 25)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -290
	panel.offset_right = -18
	panel.offset_top = -160
	panel.offset_bottom = 160
	var column := STYLE.column(panel)
	column.add_child(STYLE.label("天下局势", 14, STYLE.GOLD))
	column.add_child(STYLE.label(selected_province, 38, STYLE.LIGHT, true))
	if selected_province == "徐州":
		column.add_child(STYLE.paragraph("下邳旧城，鬼火未息。", STYLE.MUTED, 15))
		column.add_child(HSeparator.new())
		column.add_child(STYLE.label("白门楼", 27, STYLE.LIGHT, true))
		column.add_child(STYLE.paragraph("旧将据城，鬼曹军已逼近城外。", STYLE.LIGHT, 16))
		STYLE.space(column)
		var text := "查看战果" if session.data.finished else "继续行军" if session.data.started else "进入白门楼"
		action(column, text, func():
			if not session.data.pending.is_empty(): open_page("reward")
			elif session.data.finished: open_page("journal")
			elif session.begin_campaign(): resume_view(), "world_enter", true)
	else:
		column.add_child(STYLE.paragraph("暂无可赴战役", STYLE.MUTED))
		STYLE.space(column)
		var locked := action(column, "暂无可赴战役", func(): pass, "world_locked")
		locked.disabled = true

func sidebar(parent: Node, title: String, subtitle: String) -> VBoxContainer:
	var panel := STYLE.panel(parent, false, 20)
	panel.custom_minimum_size.x = 310 if size.x >= 1150 else 270
	var column := STYLE.column(panel)
	column.add_child(STYLE.label(title, 28, STYLE.INK, true))
	column.add_child(STYLE.paragraph(subtitle, STYLE.MUTED, 14))
	column.add_child(HSeparator.new())
	return column

func build_route() -> void:
	var row := map_split()
	var region := VBoxContainer.new()
	region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	region.add_theme_constant_override("separation", 0)
	row.add_child(region)
	if route_overview:
		var tabs := STYLE.row(STYLE.panel(region, true, 8))
		for index in SESSION.SEGMENTS.size():
			var target := index
			var button := action(tabs, SESSION.SEGMENTS[index], func(): segment = target; render(), "segment_%d" % index, index == segment)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			STYLE.compact_button(button)
	var canvas := MAP.new()
	canvas.mode = "route"
	canvas.session = session
	canvas.segment = segment
	if not route_overview:
		canvas.visible_nodes = session.data.available.duplicate()
		for available in session.data.available:
			for next in session.nodes[available].next:
				if next not in canvas.visible_nodes: canvas.visible_nodes.append(next)
		if not session.data.completed.is_empty(): canvas.visible_nodes.append(session.data.completed[-1])
	canvas.selected = selected_node
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	region.add_child(canvas)
	if session.data.owned.has("F11"):
		var art := portrait(canvas, 235 if size.x >= 1150 else 165)
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var index := 0
	for id in session.nodes:
		var node: Dictionary = session.nodes[id]
		if int(node.segment) != segment: continue
		var target: String = id
		var position_index := index
		index += 1
		if not canvas.visible_nodes.is_empty() and id not in canvas.visible_nodes: continue
		var prefix: String = {"event":"◇", "spring":"泉", "battle":"战", "elite":"精", "boss":"将"}[node.kind]
		if id in session.data.completed: prefix = "✓"
		var button := action(canvas, "%s  %s" % [prefix, node.name], func(): selected_node = target; render(), "node_" + id, id == selected_node)
		button.add_theme_font_size_override("font_size", 14)
		button.custom_minimum_size = Vector2(110, 38)
		button.size = button.get_combined_minimum_size()
		canvas.resized.connect(func(): button.position = canvas.route_position(position_index) - button.size * .5)
	var heading := STYLE.label("徐州 · 下邳", 24, STYLE.LIGHT, true)
	canvas.add_child(heading)
	heading.position = Vector2(250 if session.data.owned.has("F11") else 22, 16)
	heading.add_theme_color_override("font_shadow_color", Color("222a24"))
	heading.add_theme_constant_override("shadow_offset_x", 2)
	heading.add_theme_constant_override("shadow_offset_y", 2)
	var column := sidebar(row, "行军路线", SESSION.SEGMENTS[segment])
	action(column, "收起总览" if route_overview else "区域总览", func():
		route_overview = not route_overview
		if not route_overview:
			segment = int(session.nodes[session.data.current].segment)
			selected_node = session.data.current
		render(), "route_overview")
	var node: Dictionary = session.nodes[selected_node]
	column.add_child(STYLE.label(node.name, 25, STYLE.INK, true))
	var summary: String = node.get("map_summary", node.summary)
	if not summary.is_empty(): column.add_child(STYLE.paragraph(summary))
	column.add_child(HSeparator.new())
	column.add_child(STYLE.label("前路", 17, STYLE.GOLD))
	for id in session.data.available:
		var target: String = id
		action(column, session.nodes[id].name, func(): selected_node = target; segment = int(session.nodes[target].segment); render(), "choice_" + id, selected_node == id)
	STYLE.space(column)
	if not session.data.pending.is_empty(): action(column, "完成本关选卡", func(): open_page("reward"), "route_reward", true)
	elif selected_node in session.data.completed:
		column.add_child(STYLE.paragraph("已通过"))
	elif selected_node not in session.data.available:
		column.add_child(STYLE.paragraph("尚未到达"))
	else:
		var event: bool = node.kind in ["event", "spring"]
		var available: bool = event or not session.has_method("battle_available") or session.battle_available(selected_node)
		var forward := action(column, "暂不可前往" if not available else "前往泉水" if node.kind == "spring" else "查看事件" if event else "出战整备", func():
			if session.choose_node(selected_node):
				open_page("event" if event else "preparation"), "route_forward", true)
		forward.disabled = not available

func start_battle() -> void:
	var request: Dictionary = session.start_battle()
	if request.is_empty(): return
	page = "battle"
	frame.hide()
	battle_view = battle_script.new()
	battle_view.setup(request, session.characters)
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
	bgm.set_cue("stage_frontpost" if request.node.id == "B01" else "stage_rift")

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
	bgm.set_cue("camp_signal")

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
		control.grab_focus()

func open_music() -> void:
	music_return = page
	previous_page = page
	bgm.pause_music()
	music_preview = AudioStreamPlayer.new()
	add_child(music_preview)
	music_preview.finished.connect(render)
	page = "music"
	play_track(music_index)

func play_track(index: int) -> void:
	if not is_instance_valid(music_preview): return
	music_index = posmod(index, MUSIC.CUES.size())
	var stream := load(MUSIC.path(MUSIC.CUES[music_index])) as AudioStream
	if stream == null:
		show_notice("这首配乐暂时无法读取。")
		return
	music_preview.stream = stream
	music_preview.stream_paused = false
	music_preview.play()
	render()

func close_music() -> void:
	if is_instance_valid(music_preview):
		music_preview.stop()
		music_preview.queue_free()
		music_preview = null
	bgm.resume_music()

func _process(_delta: float) -> void:
	if page != "music" or not is_instance_valid(music_preview): return
	music_preview.volume_linear = 0.0 if BGM.load_music_muted() else BGM.load_music_volume()
	var seek := frame.find_child("music_seek", true, false) as HSlider
	var clock := frame.find_child("music_clock", true, false) as Label
	if seek == null or music_preview.stream == null: return
	var position := music_preview.get_playback_position()
	seek.set_value_no_signal(position)
	clock.text = "%02d:%02d / %02d:%02d" % [int(position) / 60, int(position) % 60, int(seek.max_value) / 60, int(seek.max_value) % 60]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if page == "battle" and not is_instance_valid(modal): return
	if event.keycode == KEY_ESCAPE:
		if is_instance_valid(modal):
			modal.queue_free()
			modal = null
		elif page != "battle":
			if page == "home": open_page("world")
			elif page in ["roster", "equipment", "saves", "settings", "journal"]: open_page(previous_page)
			elif page == "reward": show_notice("请完成本关选卡；也可以保存行军档，稍后继续同一组候选。")
			elif page in ["event", "preparation", "failure"]: open_page("route")
			elif page == "character": open_page(character_return)
			elif page == "menu": open_page(menu_return)
			elif page == "music": open_page(music_return)
			else: open_page("home")
		get_viewport().set_input_as_handled()
