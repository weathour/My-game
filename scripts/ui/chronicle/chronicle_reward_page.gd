extends RefCounted
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const CARD := preload("res://scripts/ui/chronicle/chronicle_card.gd")
const DETAILS := preload("res://scripts/ui/chronicle/character_detail_projection.gd")
const SUMMARY := preload("res://scripts/campaign/party_summary.gd")
const INFO := preload("res://scripts/content/skill_information.gd")
const COPY_PATH := "res://assets/data/chronicle/skill_presentation_copy.json"

static func passive_preview(data: Dictionary, id: String) -> String:
	var copy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(COPY_PATH))
	var words: Dictionary = copy.get("owned_bonus", {})
	var lines: Array[String] = []
	for row in DETAILS.owned_rows(data, id):
		var key := "next_effective_delta" if row.owned else "acquisition_effective_delta"
		var gain := float(row.next_delta) if row.owned else float(row.acquisition_delta)
		lines.append("%s · %s %s" % [row.title, words.get(key, ""), SUMMARY.amount_text(row.key, gain)])
	if not lines.is_empty(): lines.append(str(words.get("reward_preview_note", "")))
	return "\n".join(lines)

static func build(shell: Control) -> void:
	var state: RefCounted = shell.session
	if state.data.pending.is_empty():
		var empty: VBoxContainer = shell.PAGES.scaffold(shell, "关末战果", "当前没有待领取的战果。")
		shell.action(empty, "返回行军", shell.resume_view, "reward_return", true)
		return
	var pending: Dictionary = state.data.pending
	var compact: bool = shell.size.y < 650
	var column := T.column(T.panel(shell.page_margin(), true, 18 if compact else 28))
	column.add_theme_constant_override("separation", 8 if compact else 12)
	var heading := T.row(column)
	heading.add_child(T.label("章末战果" if pending.node == "B18" else "关末战果", 29 if compact else 36, T.LIGHT, true))
	heading.add_child(T.label("选择 %d 张" % pending.picks, 17, T.GOLD))
	T.space(heading)
	heading.add_child(T.label("已选 %d / %d" % [pending.selected.size(), pending.picks], 21, T.GOLD))
	shell.action(heading, "菜单", shell.open_menu, "reward_menu")
	var line: String = state.nodes[pending.node].name
	if pending.extra: line += "  ·  精英奖励，多选 1 张"
	if pending.node == "B01": line += "  ·  艾玛的剧情加入不占选卡名额。"
	column.add_child(T.label(line, 13 if compact else 15, T.MUTED))
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(center)
	var display := T.column(center)
	display.add_theme_constant_override("separation", 12 if compact else 16)
	var deck := HBoxContainer.new()
	deck.name = "reward_deck"
	deck.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck.add_theme_constant_override("separation", 8 if compact else 14)
	display.add_child(deck)
	var available: float = shell.size.x - (64 if compact else 88)
	var card_width: float = (available - (pending.candidates.size()-1) * (8 if compact else 14)) / pending.candidates.size()
	card_width = minf(card_width, 230)
	var card_height := minf(390, shell.size.y - (304 if compact else 360))
	if pending.candidates.size() == 7: card_height = minf(card_height, card_width * 1.65)
	var info := T.column(display)
	info.add_theme_constant_override("separation", 4)
	var detail_heading := T.row(info)
	var person_name := T.label("", 18, T.GOLD, true)
	detail_heading.add_child(person_name)
	T.space(detail_heading)
	var detail_button: Button = shell.action(detail_heading, "人物详情", func(): shell.inspect_character(shell.reward_focus,"abilities"), "reward_details")
	T.compact_button(detail_button)
	var descriptions := T.row(info)
	var labels: Array = []
	for title in [INFO.ui("playstyle","玩法特点"), "后台支援", "持有加成"]:
		var block := T.column(descriptions)
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		block.add_theme_constant_override("separation", 3)
		block.add_child(T.label(title, 13, T.GOLD))
		var words := T.paragraph("", T.LIGHT, 13 if compact else 14)
		words.mouse_filter = Control.MOUSE_FILTER_PASS
		words.max_lines_visible = 2
		words.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		words.custom_minimum_size = Vector2(0, 42)
		block.add_child(words)
		labels.append(words)
	var show_person := func(id: String):
		shell.reward_focus = id
		var person: Dictionary = state.characters[id]
		person_name.text = person.name
		var detail: Dictionary = DETAILS.build(state.data,state.characters,id)
		labels[0].text = str(detail.overview)
		labels[0].name = "reward_playstyle_summary"
		labels[0].tooltip_text = str(detail.overview)
		labels[1].text = str(detail.support_info.get("summary",detail.support_state))
		labels[1].name = "reward_support_summary"
		labels[1].tooltip_text = "\n".join([str(detail.support_info.get("summary",detail.support_state)),str(detail.support_info.get("trigger",""))])
		labels[2].text = str(person.owned)
		labels[2].name = "reward_owned_preview"
		labels[2].tooltip_text = DETAILS.precise_owned_text(id)
		var preview := passive_preview(state.data, id)
		if not preview.is_empty():
			labels[2].text = preview
			labels[2].tooltip_text = DETAILS.precise_owned_text(id) + "\n" + preview
	if shell.reward_focus not in pending.candidates: shell.reward_focus = pending.candidates[0]
	show_person.call(shell.reward_focus)
	for id in pending.candidates:
		var target: String = id
		var person: Dictionary = state.characters[id]
		var card := CARD.new()
		card.name = "reward_card_" + id
		card.compact = compact or card_width < 180
		card.important = person.kind == "重要人物"
		var gain := "新加入 · Lv.%d" % person.level
		if state.data.owned.has(id): gain = "Lv.%d → Lv.%d" % [state.data.owned[id].level, state.data.owned[id].level + 1]
		card.configure(id, person.name, gain, "重要人物" if card.important else "", id in pending.selected, person.get("rarity", "common"))
		card.custom_minimum_size = Vector2(card_width, card_height)
		card.focus_entered.connect(show_person.bind(target))
		card.mouse_entered.connect(show_person.bind(target))
		card.pressed.connect(func():
			shell.reward_focus = target
			if state.select_card(target): shell.render())
		deck.add_child(card)
	var bottom := T.row(column)
	T.space(bottom)
	var claim: Button = shell.action(bottom, "确认领取", func():
		if state.claim_reward(): shell.resume_view(true), "reward_claim", true)
	claim.custom_minimum_size.x = 190
	claim.disabled = pending.selected.size() != int(pending.picks)
