extends RefCounted
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")
const PARTY := preload("res://scripts/ui/chronicle/chronicle_party_pages.gd")
const REWARD := preload("res://scripts/ui/chronicle/chronicle_reward_page.gd")
const BGM := preload("res://scripts/bgm_player.gd")

static func build(shell: Control, page: String) -> void:
	match page:
		"roster": roster(shell)
		"character": character_page(shell)
		"equipment": equipment(shell)
		"reward": reward(shell)
		"event": event_page(shell)
		"replay": shell.build_story_replay()
		"preparation": preparation(shell)
		"failure": failure(shell)
		"saves": saves(shell)
		"journal": journal(shell)
		"settings": settings(shell)
		"music": music(shell)
		"menu": menu(shell)

static func scaffold(shell: Control, title: String, subtitle: String) -> VBoxContainer:
	var column := T.column(T.panel(shell.page_margin(), false, 12 if shell.size.y < 650 else 18))
	var row := T.row(column)
	row.add_child(T.label(title, 24 if shell.size.y < 650 else 30, T.INK, true))
	T.space(row)
	shell.quiet_action(row, "返回", func(): shell.open_page(shell.party_return if shell.page == "equipment" else shell.previous_page), "page_back")
	if not subtitle.is_empty(): column.add_child(T.paragraph(subtitle, T.MUTED, 13 if shell.size.y < 650 else 14))
	column.add_theme_constant_override("separation", 6 if shell.size.y < 650 else 10)
	column.add_child(HSeparator.new())
	return column

static func scroll_column(parent: Node, id: String = "content_scroll") -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = id
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	parent.add_child(scroll)
	return T.column(scroll)

static func roster(shell: Control) -> void:
	PARTY.build(shell)

static func character_page(shell: Control) -> void:
	PARTY.character_page(shell)

static func equipment(shell: Control) -> void:
	var state: RefCounted = shell.session
	var compact: bool = shell.size.y < 650
	var column := scaffold(shell, "整备", "全队共享")
	shell.party_tabs(column)
	var slots := T.row(column)
	for entry in [["weapon", "武器"], ["armor", "护甲"], ["accessory", "饰品"]]:
		var key: String = entry[0]
		var current := ""
		for item in state.EQUIPMENT:
			if item.id == state.data.equipped[key]: current = item.name
		var button: Button = shell.action(slots, "%s   %s" % [entry[1], current], func(): shell.equipment_slot = key; shell.selected_equipment = state.data.equipped[key]; shell.render(), "equip_slot_" + key, shell.equipment_slot == key)
		button.custom_minimum_size.y = 48 if compact else 60
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inventory := scroll_column(column, "equipment_scroll")
	for item in state.EQUIPMENT:
		if item.slot != shell.equipment_slot: continue
		var id: String = item.id
		var equipped: bool = state.data.equipped[item.slot] == id
		var owned: bool = id in state.data.inventory
		var panel := T.panel(inventory, true, 15 if compact else 22, false)
		var row := T.row(panel)
		row.add_theme_constant_override("separation", 20)
		var emblem := T.label(item.mark, 36 if compact else 48, T.GOLD, true)
		emblem.custom_minimum_size = Vector2(65 if compact else 90, 70 if compact else 100)
		emblem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emblem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(emblem)
		var content := T.column(row)
		content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content.add_theme_constant_override("separation", 5)
		content.add_child(T.label(item.name, 22 if compact else 27, T.LIGHT, true))
		content.add_child(T.paragraph(item.effect, T.LIGHT, 15 if compact else 17))
		content.add_child(T.paragraph(item.detail, T.MUTED, 13 if compact else 14))
		if equipped:
			var status := T.label("已装备", 16, T.GOLD)
			status.custom_minimum_size.x = 100
			status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(status)
		elif owned:
			var button: Button = shell.action(row, "换上", func():
				if state.equip(id): shell.render(), "equip_" + id, true)
			button.custom_minimum_size.x = 100
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			button.disabled = not state.data.pending.is_empty()
		else:
			var status := T.label("尚未获得", 14, T.MUTED)
			status.custom_minimum_size.x = 100
			row.add_child(status)
	if not state.data.pending.is_empty(): column.add_child(T.label("完成选卡后可更换行装。", 13, T.GOLD))

static func reward(shell: Control) -> void:
	REWARD.build(shell)

static func event_page(shell: Control) -> void:
	shell.build_story()

static func preparation(shell: Control) -> void:
	PARTY.build(shell, true)

static func saves(shell: Control) -> void:
	var state: RefCounted = shell.session
	var column := scaffold(shell, "行军档", "")
	var list := scroll_column(column, "saves_scroll")
	for slot in ["auto", "1", "2", "3"]:
		var id: String = slot
		var saved: Dictionary = state.read_slot(slot)
		var row := T.row(T.panel(list, false, 16))
		var info := T.column(row)
		info.add_child(T.label("自动续档" if slot == "auto" else "手动档 " + slot, 22, T.INK, true))
		if saved.is_empty(): info.add_child(T.label("空档 / 无可读取记录", 15, T.MUTED))
		else:
			var location: String = state.nodes[saved.current].name
			var time := Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(state.directory.path_join(slot + ".json")))
			info.add_child(T.label("%s · %d 人物 · %d 节点已过" % [location, saved.owned.size(), saved.completed.size()], 16))
			info.add_child(T.label(time.replace("T", " ") + (" · 待选卡" if not saved.pending.is_empty() else ""), 13, T.MUTED))
		if slot != "auto":
			shell.action(row, "保存", func():
				shell.confirm("保存到手动档 " + id, "该槽的旧进度将被替换。", func():
					if state.save_slot(id): shell.render()
					else: shell.show_notice("保存失败，原有档案保留。")), "save_" + slot)
		var load_button: Button = shell.action(row, "读取", func():
			shell.confirm("读取行军档？", "当前行军状态将整体替换为这份记录。", func():
				if state.load_slot(id): shell.resume_view(true)), "load_" + slot)
		load_button.disabled = saved.is_empty()

static func failure(shell: Control) -> void:
	var center := CenterContainer.new()
	shell.body.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := T.panel(center, false, 28)
	panel.custom_minimum_size.x = 500
	var column := T.column(panel)
	column.add_child(T.label("本关未过", 38, T.RED, true))
	column.add_child(T.label(shell.session.nodes[shell.session.data.current].name, 23, T.INK, true))
	column.add_child(T.paragraph("贾苇索倒下，队伍退回进关之前。\n\n本次尝试的收益已撤销，之前通过的关卡与战果保留。可以重新整备后再来。", T.INK, 17))
	shell.action(column, "重新整备", func(): shell.open_page("preparation"), "failure_retry", true)
	shell.action(column, "返回路线", func(): shell.open_page("route"), "failure_back")

static func journal(shell: Control) -> void:
	var column := scaffold(shell, "行军见闻", "记录已经走过的节点与人物加入。")
	var list := scroll_column(column, "journal_scroll")
	list.add_child(T.label("剧情回顾", 21, T.GOLD))
	list.add_child(T.paragraph("重看已完成的剧情，不影响人物、奖励或行军进度。", T.MUTED, 14))
	var stories: Array[String] = shell.replayable_stories()
	if stories.is_empty(): list.add_child(T.paragraph("还没有可回顾的剧情。", T.MUTED, 14))
	for id in stories:
		var target: String = id
		shell.action(list, shell.session.nodes[id].name + " · 回顾剧情", func(): shell.open_story_replay(target, "journal"), "journal_replay_" + id)
	list.add_child(HSeparator.new())
	list.add_child(T.label("行军记录", 21, T.GOLD))
	if shell.session.data.log.is_empty(): list.add_child(T.paragraph("尚未启程。白门楼的传闻正从徐州传来。"))
	else:
		var index := 1
		for line in shell.session.data.log:
			list.add_child(T.label("%02d    %s" % [index, line], 18))
			list.add_child(HSeparator.new())
			index += 1
	if shell.session.data.finished: column.add_child(T.label("白门楼战役完成 · 全员已返营休整", 24, T.GOLD, true))

static func settings(shell: Control) -> void:
	var column := scaffold(shell, "设定", "")
	var list := scroll_column(column, "settings_scroll")
	list.add_child(T.label("声音", 24, T.INK, true))
	for item in [["音乐音量", BGM.load_music_volume(), true], ["音效音量", SETTINGS.load_sfx_volume(), false]]:
		var is_music: bool = item[2]
		var row := T.row(list)
		row.add_child(T.label(item[0], 17))
		var slider := HSlider.new()
		slider.name = "music_volume" if is_music else "sfx_volume"
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.min_value = 0
		slider.max_value = 1
		slider.step = .05
		slider.value = item[1]
		row.add_child(slider)
		var amount := T.label("%d%%" % int(slider.value * 100), 16)
		amount.custom_minimum_size.x = 65
		row.add_child(amount)
		slider.value_changed.connect(func(value: float):
			if is_music: BGM.save_music_volume(value)
			else: SETTINGS.save_sfx_volume(value)
			amount.text = "%d%%" % int(value * 100))
	var muted := CheckButton.new()
	muted.text = "音乐静音"
	muted.button_pressed = BGM.load_music_muted()
	muted.toggled.connect(BGM.save_music_muted)
	list.add_child(muted)
	list.add_child(T.label("显示", 24, T.INK, true))
	var hud_row := T.row(list)
	hud_row.add_child(T.label("战斗界面", 17))
	var hud_choice := OptionButton.new()
	hud_choice.name = "hud_layout"
	for key in SETTINGS.get_hud_layout_options(): hud_choice.add_item(SETTINGS.get_hud_layout_label(key))
	hud_choice.select(SETTINGS.get_hud_layout_options().find(SETTINGS.load_hud_layout()))
	hud_choice.item_selected.connect(func(index: int): SETTINGS.save_hud_layout(SETTINGS.get_hud_layout_options()[index]))
	hud_row.add_child(hud_choice)
	var row := T.row(list)
	for resolution in ["1280x720", "1600x900", "1920x1080"]:
		var key: String = resolution
		shell.action(row, resolution, func(): shell.get_node("/root/WindowDisplayManager").apply_window_size(key), "resolution_" + key)
	shell.action(row, "切换全屏", func():
		var manager: Node = shell.get_node("/root/WindowDisplayManager")
		manager.apply_window_mode("windowed" if manager.get_current_window_mode() == "fullscreen" else "fullscreen"), "toggle_fullscreen")
	list.add_child(T.label("操作", 24, T.INK, true))
	list.add_child(T.paragraph("菜单：Tab / 方向键移动焦点，Enter 确认，Esc 返回。\n战斗：WASD / 方向键移动，Q / E 切人，J / K 释放当前人物关键技能，Esc 暂停。\n普攻、常规技能与方向自动；无需鼠标。", T.INK))
	var actions := T.row(column)
	shell.action(actions, "音乐鉴赏", shell.open_music, "settings_music")
	shell.action(actions, "返回标题", func(): shell.open_page("home"), "settings_home")
	shell.action(actions, "退出游戏", func(): shell.get_tree().quit(), "quit_game")

static func music(shell: Control) -> void:
	var column := scaffold(shell, "音乐鉴赏", "收录已有的 14 首原创配乐。曲名与原作场景记录沿用，新的战役配乐分配另行制作。")
	var row := T.row(column)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := scroll_column(row, "music_list")
	for i in shell.MUSIC.CUES.size():
		var index: int = i
		var cue: String = shell.MUSIC.CUES[i]
		shell.action(list, "%02d   %s" % [i+1, shell.MUSIC.TRACK_INFO[cue].title], func(): shell.play_track(index), "music_track_%d" % i, shell.music_index == i)
	var panel := T.panel(row, true, 22)
	panel.custom_minimum_size.x = 380
	var player := T.column(panel)
	var cue: String = shell.MUSIC.CUES[shell.music_index]
	player.add_child(T.label("已暂停" if shell.music_preview.stream_paused else "正在播放" if shell.music_preview.playing else "播放结束", 15, Color("bfc7b1")))
	player.add_child(T.paragraph(shell.MUSIC.TRACK_INFO[cue].title, T.LIGHT, 28))
	player.add_child(T.paragraph(shell.MUSIC.TRACK_INFO[cue].kind, Color("bfc7b1"), 16))
	T.space(player)
	var seek := HSlider.new()
	seek.name = "music_seek"
	seek.max_value = shell.music_preview.stream.get_length() if shell.music_preview.stream != null else 1
	seek.value_changed.connect(func(value: float): shell.music_preview.seek(value))
	player.add_child(seek)
	var clock := T.label("00:00", 15, T.LIGHT)
	clock.name = "music_clock"
	player.add_child(clock)
	var controls := T.row(player)
	shell.action(controls, "上一首", func(): shell.play_track(shell.music_index-1), "music_previous")
	var pause: Button = shell.action(controls, "播放" if shell.music_preview.stream_paused or not shell.music_preview.playing else "暂停", func():
		if not shell.music_preview.playing: shell.music_preview.play()
		else: shell.music_preview.stream_paused = not shell.music_preview.stream_paused
		shell.render(), "music_pause")
	pause.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.action(controls, "下一首", func(): shell.play_track(shell.music_index+1), "music_next")

static func menu(shell: Control) -> void:
	if shell.session.data.owned.has("F11"): shell.portrait(shell.body, shell.size.x * .36)
	var center := CenterContainer.new()
	shell.body.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := T.panel(center, true, 30)
	panel.custom_minimum_size.x = 470
	var column := T.column(panel)
	column.add_child(T.label("菜单", 30, T.LIGHT, true))
	shell.action(column, "返回", func(): shell.open_page(shell.menu_return), "menu_resume", true)
	for item in [["roster", "整备"], ["saves", "行军档"], ["journal", "见闻"], ["settings", "设定"]]:
		var page: String = item[0]
		shell.action(column, item[1], func(): shell.open_page(page), "menu_" + page)
	shell.quiet_action(column, "敌情图鉴", shell.open_enemy_codex, "menu_codex")
	shell.action(column, "音乐鉴赏", shell.open_music, "menu_music")
	shell.action(column, "返回标题", func(): shell.open_page("home"), "menu_home")
