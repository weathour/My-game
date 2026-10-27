extends RefCounted
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const CARD := preload("res://scripts/ui/chronicle/chronicle_card.gd")
const ART := preload("res://scripts/ui/chronicle/chronicle_portraits.gd")
const SUMMARY := preload("res://scripts/ui/chronicle/chronicle_party_summary.gd")

static func build(shell: Control, preparation: bool = false) -> void:
	var state: RefCounted = shell.session
	var compact: bool = shell.size.y < 650
	var column := T.column(T.panel(shell.page_margin(), true, 14 if compact else 22))
	column.add_theme_constant_override("separation", 7 if compact else 10)
	var heading := T.row(column)
	heading.add_child(T.label("出战整备" if preparation else "编队", 26 if compact else 30, T.LIGHT, true))
	if preparation: heading.add_child(T.label(state.nodes[state.data.current].name, 17, T.GOLD))
	T.space(heading)
	shell.action(heading, "返回路线" if preparation else "返回", func(): shell.open_page("route" if preparation else shell.previous_page), "page_back")
	if preparation: shell.action(heading, "进入战斗", shell.start_battle, "prep_start", true)
	party_strip(shell, column)
	var controls := T.row(column)
	if not preparation:
		for filter in [["owned", "已获得 %d" % state.data.owned.size()], ["pool", "已入池 %d" % state.data.pool.size()], ["all", "全部人物"]]:
			var key: String = filter[0]
			var button: Button = shell.action(controls, filter[1], func(): shell.roster_filter = key; shell.render(), "filter_" + key, shell.roster_filter == key)
			T.compact_button(button)
	else: controls.add_child(T.label("选择人物", 17, T.GOLD))
	var search := LineEdit.new()
	search.name = "roster_search"
	search.placeholder_text = "查找人物"
	search.text = shell.search_text
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(search)
	search.text_submitted.connect(func(value: String): shell.search_text = value.strip_edges(); shell.render())
	var search_button: Button = shell.action(controls, "查找", func(): shell.search_text = search.text.strip_edges(); shell.render(), "search_submit")
	T.compact_button(search_button)
	var row := T.row(column)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list: VBoxContainer = shell.PAGES.scroll_column(row, "roster_scroll")
	var grid := GridContainer.new()
	grid.columns = 5 if shell.size.x >= 1700 else 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 9)
	list.add_child(grid)
	var count := 0
	for id in state.characters:
		var person: Dictionary = state.characters[id]
		var owned: bool = state.data.owned.has(id)
		if (preparation or shell.roster_filter == "owned") and not owned: continue
		if not preparation and shell.roster_filter == "pool" and id not in state.data.pool: continue
		if not shell.search_text.is_empty() and not str(person.name).contains(shell.search_text): continue
		count += 1
		var target: String = id
		var card := CARD.new()
		card.name = "character_" + id
		card.compact = true
		card.selected_badge = ""
		card.important = person.kind == "重要人物"
		card.fallen = owned and state.data.owned[id].dead
		var tag := "尚未入池" if id not in state.data.pool else "未获得"
		if owned: tag = "主角" if id == "JIA" else "辅助" if id in state.data.party else ""
		card.configure(id, person.name, "Lv.%d · %s" % [state.data.owned[id].level, person.role] if owned else person.role, tag, shell.selected_character == id, person.get("rarity", "common"))
		card.custom_minimum_size = Vector2(0, 140 if compact else 220)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(func():
			shell.selected_character = target
			if compact:
				shell.character_return = shell.page
				shell.open_page("character")
			else: shell.render())
		grid.add_child(card)
	if count == 0: list.add_child(T.paragraph("没有找到符合条件的人物。"))
	if not compact: detail(shell, row)
	if not state.data.pending.is_empty(): column.add_child(T.label("完成选卡后可更换编队。", 13, T.GOLD))

static func party_strip(shell: Control, parent: Node) -> void:
	var state: RefCounted = shell.session
	var compact: bool = shell.size.y < 650
	var row := T.row(parent)
	row.name = "party_overview"
	row.add_theme_constant_override("separation", 16)
	var left := T.column(row)
	left.name = "party_members"
	left.size_flags_horizontal = Control.SIZE_FILL
	left.add_theme_constant_override("separation", 6)
	var members := T.row(left)
	members.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	members.add_theme_constant_override("separation", 10)
	for i in 3:
		var id: String = "JIA" if i == 0 else state.data.party[i-1]
		var slot := T.column(members)
		slot.size_flags_horizontal = Control.SIZE_FILL
		slot.add_theme_constant_override("separation", 2)
		var slot_title := "主角" if i == 0 else "辅助 %d" % i
		if i > 0 and not id.is_empty(): slot_title += " · " + CARD.RARITY.style(state.characters[id].get("rarity", "common")).label
		slot.add_child(T.label(slot_title, 12, T.GOLD))
		var thumbnail := CARD.new()
		thumbnail.compact = true
		thumbnail.custom_minimum_size = Vector2(96 if compact else 114, 105 if compact else 132)
		thumbnail.name = "prep_member_%d" % i
		thumbnail.fallen = not id.is_empty() and state.data.owned[id].dead
		thumbnail.configure(id, "空位" if id.is_empty() else state.characters[id].name, "" if id.is_empty() else "Lv.%d" % state.data.owned[id].level, "", false, state.characters[id].get("rarity", "common") if not id.is_empty() else "common")
		slot.add_child(thumbnail)
		if not id.is_empty():
			var record: Dictionary = state.data.owned[id]
			slot.add_child(T.label("生命 %d   魔法 %d" % [record.hp, record.mp], 10 if compact else 11, T.MUTED))
		var member: String = id
		thumbnail.pressed.connect(func():
			if member.is_empty(): return
			shell.selected_character = member
			if shell.size.y < 650: shell.character_return = shell.page; shell.open_page("character")
			else: shell.render())
	var gear := T.row(left)
	gear.add_theme_constant_override("separation", 4)
	for entry in [["weapon", "武器"], ["armor", "护甲"], ["accessory", "饰品"]]:
		var key: String = entry[0]
		var equipment_name := ""
		for item in state.EQUIPMENT:
			if item.id == state.data.equipped[key]: equipment_name = item.name
		var button: Button = shell.action(gear, equipment_name, func(): shell.equipment_slot = key; shell.open_page("equipment"), "prep_gear_" + key)
		button.tooltip_text = entry[1] + " · " + equipment_name
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		T.compact_button(button)
	SUMMARY.build(shell, row)

static func character_page(shell: Control) -> void:
	var column := T.column(shell.page_margin())
	var top := T.row(column)
	shell.action(top, "返回编队", func(): shell.open_page(shell.character_return), "character_back")
	var row := T.row(column)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var art := TextureRect.new()
	art.texture = ART.standing(shell.selected_character)
	art.custom_minimum_size.x = 230
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(art)
	detail(shell, row, true)

static func detail(shell: Control, parent: Node, full: bool = false) -> void:
	var state: RefCounted = shell.session
	var id: String = shell.selected_character
	var person: Dictionary = state.characters[id]
	var panel := T.panel(parent, false, 18)
	panel.custom_minimum_size.x = 0 if full else 330
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if full else Control.SIZE_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := T.column(panel)
	column.add_theme_constant_override("separation", 6)
	var heading := T.row(column)
	heading.add_child(T.label(person.name, 26, T.LIGHT, true))
	T.space(heading)
	var attr: Button = shell.action(heading, "属性", func():
		var stats: Array = state.display_stats(id) if state.has_method("display_stats") else ["生命上限 100", "魔法上限 100"]
		var lines: Array[String] = []
		for value in stats: lines.append(str(value))
		shell.show_notice(person.name + "\n\n" + "\n".join(lines) + "\n\n获取条件\n" + person.gate), "character_stats")
	T.compact_button(attr)
	var owned: bool = state.data.owned.has(id)
	if owned:
		var record: Dictionary = state.data.owned[id]
		column.add_child(T.label("Lv.%d   生命 %d   魔法 %d" % [record.level, record.hp, record.mp], 13, T.MUTED))
		if id != "JIA":
			var buttons := T.row(column)
			buttons.add_theme_constant_override("separation", 4)
			for i in 2:
				var index := i
				var button: Button = shell.action(buttons, "辅助 %d" % [i+1], func():
					if state.assign(id, index): shell.render(), "assign_%d" % i, id == state.data.party[i])
				T.compact_button(button)
				button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				button.disabled = record.dead or not state.data.pending.is_empty()
			if id in state.data.party:
				var remove: Button = shell.action(buttons, "候补", func():
					if state.assign("", state.data.party.find(id)): shell.render(), "remove_auxiliary")
				T.compact_button(remove)
				remove.disabled = not state.data.pending.is_empty()
	else: column.add_child(T.label("已入池 · 尚未获得" if id in state.data.pool else "尚未入池", 13, T.MUTED))
	var content: VBoxContainer = shell.PAGES.scroll_column(column, "character_detail_scroll")
	content.add_theme_constant_override("separation", 5)
	for entry in [["前台能力", "front"], ["后台支援", "back"], ["持有加成", "owned"]]:
		content.add_child(T.label(entry[0], 15, T.GOLD))
		var words := T.paragraph(person[entry[1]], T.LIGHT, 13)
		words.name = "character_" + entry[1] + "_summary"
		content.add_child(words)
		if entry[1] == "front":
			for i in person.skills.size(): content.add_child(T.label("%s  %s" % ["J" if i == 0 else "K", person.skills[i]], 12, T.MUTED))
