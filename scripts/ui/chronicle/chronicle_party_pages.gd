extends RefCounted
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const CARD := preload("res://scripts/ui/chronicle/chronicle_card.gd")
const DRAG_CARD := preload("res://scripts/ui/chronicle/chronicle_party_drag_card.gd")
const DROP_ZONE := preload("res://scripts/ui/chronicle/chronicle_party_drop_zone.gd")
const SUMMARY := preload("res://scripts/ui/chronicle/chronicle_party_summary.gd")
const PROFILES := preload("res://scripts/content/character_profiles.gd")
const SHEET := preload("res://scripts/ui/chronicle/chronicle_character_sheet.gd")

static func build(shell: Control, preparation: bool = false) -> void:
	var state: RefCounted = shell.session
	var compact: bool = shell.size.y < 650
	var panel := T.panel(shell.page_margin(), true, 12 if compact else 18)
	panel.name = "party_preparation_panel"
	var column := T.column(panel)
	column.add_theme_constant_override("separation", 5 if compact else 8)
	var heading := T.row(column)
	heading.add_child(T.label("出战整备" if preparation else "整备", 25 if compact else 30, T.LIGHT, true))
	if preparation: heading.add_child(T.label(state.nodes[state.data.current].name, 16, T.GOLD))
	T.space(heading)
	shell.quiet_action(heading, "返回路线" if preparation else "返回", func(): shell.open_page(shell.party_return), "page_back")
	if preparation: shell.action(heading, "进入战斗", shell.start_battle, "prep_start", true)
	shell.party_tabs(column)
	party_strip(shell, column)
	var controls := T.row(column)
	controls.add_theme_constant_override("separation", 6)
	if not preparation:
		for filter in [["owned", "已获得 %d" % state.data.owned.size()], ["pool", "已入池 %d" % state.data.pool.size()], ["all", "全部人物"]]:
			var key: String = filter[0]
			var button: Button = shell.quiet_action(controls, filter[1], func(): shell.roster_filter = key; shell.render(), "filter_" + key, shell.roster_filter == key)
			T.compact_button(button)
	else: controls.add_child(T.label("人物卡库", 16, T.GOLD))
	var search := LineEdit.new()
	search.name = "roster_search"
	search.placeholder_text = "查找人物"
	search.text = shell.search_text
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(search)
	search.text_submitted.connect(func(value: String): shell.search_text = value.strip_edges(); shell.render())
	var search_button: Button = shell.quiet_action(controls, "查找", func(): shell.search_text = search.text.strip_edges(); shell.render(), "search_submit")
	T.compact_button(search_button)
	var row := T.row(column)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.name = "roster_scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	row.add_child(scroll)
	var list := DROP_ZONE.new()
	list.name = "party_library_drop_zone"
	list.host = shell
	list.tooltip_text = "拖回人物列表移出编队；也可用空格拾起人物卡，Tab选择辅助位，Enter放入，Esc取消。"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var grid := GridContainer.new()
	grid.name = "party_library_grid"
	grid.columns = 7 if shell.size.x >= 1700 else 5 if shell.size.x >= 1150 else 6
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	list.add_child(grid)
	var count := 0
	for id in state.characters:
		var person: Dictionary = state.characters[id]
		var owned: bool = state.data.owned.has(id)
		if (preparation or shell.roster_filter == "owned") and not owned: continue
		if not preparation and shell.roster_filter == "pool" and id not in state.data.pool: continue
		var terms := "%s %s %s" % [person.name, PROFILES.find(id).get("title", person.get("title", "")), person.role]
		if not shell.search_text.is_empty() and not terms.contains(shell.search_text): continue
		count += 1
		var card := make_card(shell, str(id), -1)
		card.name = "character_" + id
		card.custom_minimum_size = Vector2(0, 112 if compact else 200 if shell.size.x >= 1700 else 144)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
	if count > 0 and count < grid.columns:
		for i in range(grid.columns - count):
			var filler := Control.new()
			filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
			filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(filler)
	if count == 0: list.add_child(T.paragraph("没有找到符合条件的人物。"))
	if not compact: detail(shell, row)
	var hint := T.label("拖入辅助位上阵；拖回卡库移出。空格拾起，Tab选择位置，Enter放入，Esc取消。", 11 if compact else 12, T.MUTED)
	hint.name = "party_drag_hint"
	column.add_child(hint)
	if not state.data.pending.is_empty(): hint.text = "请先完成本关选卡，再调整编队。"

static func party_strip(shell: Control, parent: Node) -> void:
	var state: RefCounted = shell.session
	var compact: bool = shell.size.y < 650
	var row := T.row(parent)
	row.name = "party_overview"
	row.add_theme_constant_override("separation", 12)
	var left := T.column(row)
	left.name = "party_members"
	left.size_flags_horizontal = Control.SIZE_FILL
	left.add_theme_constant_override("separation", 5)
	var members := T.row(left)
	members.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	members.add_theme_constant_override("separation", 8)
	for i in 3:
		var id: String = "JIA" if i == 0 else state.data.party[i - 1]
		var slot := T.column(members)
		slot.size_flags_horizontal = Control.SIZE_FILL
		slot.add_theme_constant_override("separation", 2)
		var card := make_card(shell, id, -2 if i == 0 else i - 1)
		card.name = "prep_member_%d" % i
		card.custom_minimum_size = Vector2(126 if compact else 186 if shell.size.x >= 1700 else 144, 130 if compact else 224 if shell.size.x >= 1700 else 160)
		slot.add_child(card)
		if not id.is_empty():
			var record: Dictionary = state.data.owned[id]
			var hp := "生命 %d / %d" % [record.hp, state.resource_max(id, "hp")] if state.has_method("resource_max") else "生命 %d" % record.hp
			var mp := "魔法 %d / %d" % [record.mp, state.resource_max(id, "mp")] if state.has_method("resource_max") else "魔法 %d" % record.mp
			slot.add_child(T.label(hp, 11 if compact else 12, T.MUTED))
			slot.add_child(T.label(mp, 11 if compact else 12, T.MUTED))
		else:
			slot.add_child(T.label(" ", 11 if compact else 12, T.MUTED))
			slot.add_child(T.label(" ", 11 if compact else 12, T.MUTED))
	var gear := T.row(left)
	gear.add_theme_constant_override("separation", 4)
	for entry in [["weapon", "武器"], ["armor", "护甲"], ["accessory", "饰品"]]:
		var key: String = entry[0]
		var equipment_name := ""
		for item in state.EQUIPMENT:
			if item.id == state.data.equipped[key]: equipment_name = item.name
		var button: Button = shell.quiet_action(gear, equipment_name, func(): shell.equipment_slot = key; shell.open_page("equipment"), "prep_gear_" + key)
		button.tooltip_text = entry[1] + " · " + equipment_name
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		T.compact_button(button)
	SUMMARY.build(shell, row)

static func make_card(shell: Control, id: String, target_slot: int) -> Button:
	var card := DRAG_CARD.new()
	card.host = shell
	card.slot_index = target_slot
	card.compact = true
	card.selected_badge = ""
	if id.is_empty():
		card.configure("", "放入辅助位", "拖入人物卡")
		card.tooltip_text = "放入辅助位；Tab选择此位后按Enter放入已拾起的人物卡。"
		return card
	var person: Dictionary = shell.session.characters[id]
	var owned: bool = shell.session.data.owned.has(id)
	card.important = person.kind == "重要人物"
	card.fallen = owned and bool(shell.session.data.owned[id].dead)
	var tag := "尚未入池" if id not in shell.session.data.pool else "未获得"
	if owned: tag = "主角" if id == "JIA" else "辅助" if id in shell.session.data.party else ""
	var subtitle: String = "Lv.%d · %s" % [shell.session.data.owned[id].level, person.role] if owned else person.role
	card.configure(id, person.name, subtitle, tag, shell.selected_character == id, person.get("rarity", "common"))
	card.tooltip_text += "\n" + ("主角固定出战" if id == "JIA" else "尚未获得，可预览能力" if not owned else "已阵亡，无法上阵" if card.fallen else "请先完成本关选卡，再调整编队" if not shell.session.data.pending.is_empty() else "拖入辅助位；拖回人物列表移出编队。空格拾起，Tab选择位置，Enter放入，Esc取消。")
	card.pressed.connect(func():
		if DRAG_CARD.suppressing_click(shell): return
		_select_character(shell, id)
		if shell.size.y < 650: shell.inspect_character(id)
		else: shell.render())
	return card

static func character_page(shell: Control) -> void:
	shell.inspect_character(shell.selected_character)

static func detail(shell: Control, parent: Node, _full: bool = false) -> void:
	SHEET.build_preview(shell, parent)

static func _select_character(shell: Control, id: String) -> void:
	shell.selected_character = id

static func cancel_interaction(shell: Control) -> void:
	DRAG_CARD.cancel(shell)
