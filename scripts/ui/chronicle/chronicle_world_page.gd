extends RefCounted
## The world is an inspection surface; only its campaign action starts or resumes play.
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const MAP := preload("res://scripts/ui/chronicle/chronicle_map.gd")
const CHROME := preload("res://scripts/ui/chronicle/chronicle_campaign_chrome.gd")
const ROUTE_PAGE := preload("res://scripts/ui/chronicle/chronicle_route_page.gd")
const CAMPAIGN := preload("res://scripts/campaign/campaign_service.gd")
const DETAIL_INK := Color("302d23")
const DETAIL_MUTED := Color("5b5544")

static func build(shell: Control) -> void:
	var slots: Dictionary = CHROME.build(shell, shell.body, "world")
	var state: RefCounted = shell.session
	var phase: String = CAMPAIGN.SEGMENTS[int(state.nodes[state.data.current].segment)]
	var victories := 0
	for id in state.data.completed:
		if state.nodes[id].kind in ["battle", "elite", "boss"]: victories += 1
	var context: VBoxContainer = slots.context
	context.add_child(T.label("天下 · 白门楼", CHROME.font_size(25, shell.size, 21), T.LIGHT, true))
	context.add_child(T.label("已获同伴 %d　已入池 %d　已过战斗 %d" % [maxi(0, state.data.owned.size() - 1), state.data.pool.size(), victories], CHROME.font_size(14, shell.size, 13), T.MUTED))
	var canvas := MAP.new()
	canvas.name = "CampaignWorldMap"
	canvas.selected = shell.selected_province
	slots.map.add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.province_selected.connect(func(id: String): shell.selected_province = id; shell.render())
	for value in MAP.LOCATIONS:
		var province := str(value)
		var button: Button = shell.quiet_action(canvas, province, func(): shell.selected_province = province; shell.render(), "province_" + province, province == shell.selected_province)
		button.custom_minimum_size = Vector2(54, 28) * ROUTE_PAGE.page_scale(shell)
		button.add_theme_font_size_override("font_size", CHROME.font_size(13, shell.size, 13))
		button.size = button.custom_minimum_size
		var position_province := func(): button.position = canvas.province_position(province) - button.size / 2
		canvas.resized.connect(position_province)
		position_province.call_deferred()
	var campaign_card: Button = shell.action(canvas, "白门楼 · " + phase + "\n" + state.nodes[state.data.current].name + " · " + campaign_status(state), func(): shell.selected_province = "徐州"; shell.world_tasks_open = true; shell.render(), "world_campaign_card")
	campaign_card.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	campaign_card.tooltip_text = campaign_card.text
	var scale_factor: float = minf(shell.size.x / 1280.0, shell.size.y / 720.0)
	campaign_card.visible = not shell.world_tasks_open
	campaign_card.custom_minimum_size = Vector2(214, 72) * scale_factor
	campaign_card.size = campaign_card.custom_minimum_size
	T.compact_button(campaign_card)
	campaign_card.add_theme_font_size_override("font_size", CHROME.font_size(15, shell.size, 13))
	var position_campaign := func():
		var point := canvas.province_position("徐州") + Vector2(30, 30) * scale_factor
		campaign_card.position = Vector2(clampf(point.x, 8, maxf(8, canvas.size.x - campaign_card.size.x - 8)), clampf(point.y, 8, maxf(8, canvas.size.y - campaign_card.size.y - 8)))
	canvas.resized.connect(position_campaign)
	position_campaign.call_deferred()
	var tasks: Button = shell.quiet_action(slots.map_tools, "任务", func(): shell.world_tasks_open = not shell.world_tasks_open; shell.render(), "world_tasks", shell.world_tasks_open)
	ROUTE_PAGE.style_map_tool(tasks, shell, true)
	slots.choice_panel.visible = shell.world_tasks_open
	if shell.world_tasks_open:
		build_tasks(shell, slots.choices, phase)
		ROUTE_PAGE.fit_choice_panel(shell, slots)
	build_detail(shell, slots.detail, phase, victories)
	if shell.selected_province == "徐州": build_action(shell, slots.actions)
	elif not state.data.pending.is_empty():
		var resume_reward: Button = shell.action(slots.actions, "完成本关选卡", func(): shell.open_page("reward"), "world_resume_reward", true)
		ROUTE_PAGE.style_primary_action(resume_reward, shell)
	elif state.data.started and not state.data.finished:
		var resume: Button = shell.quiet_action(slots.actions, "返回白门楼行军", shell.resume_view, "world_resume")
		ROUTE_PAGE.style_primary_action(resume, shell)

static func build_tasks(shell: Control, parent: VBoxContainer, phase: String) -> void:
	var header := T.row(parent)
	header.add_child(T.label("任务", CHROME.font_size(22, shell.size, 18), T.LIGHT, true))
	T.space(header)
	var close: Button = shell.quiet_action(header, "×", func():
		shell.world_tasks_open = false
		shell.render()
		var opener := shell.frame.find_child("world_tasks", true, false) as Button
		if opener != null: shell._focus_control.call_deferred(weakref(opener)), "world_tasks_close")
	close.add_theme_font_size_override("font_size", CHROME.font_size(16, shell.size, 14))
	var button: Button = shell.quiet_action(parent, "徐州 · 白门楼\n" + phase, func(): shell.selected_province = "徐州"; shell.render(), "world_task_baimen", shell.selected_province == "徐州")
	button.custom_minimum_size.y = maxf(58, 76 * ROUTE_PAGE.page_scale(shell))
	button.add_theme_font_size_override("font_size", CHROME.font_size(16, shell.size, 14))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(T.paragraph("当前行军：" + shell.session.nodes[shell.session.data.current].name, T.MUTED, CHROME.font_size(14, shell.size, 14)))
	if not shell.session.data.pending.is_empty(): parent.add_child(T.label("待完成本关选卡", CHROME.font_size(14, shell.size, 13), T.GOLD))
	elif shell.session.data.finished: parent.add_child(T.label("战役已完成", CHROME.font_size(14, shell.size, 13), T.GOLD))

static func build_detail(shell: Control, parent: VBoxContainer, phase: String, victories: int) -> void:
	parent.add_theme_constant_override("separation", 5)
	parent.add_child(T.label(shell.selected_province + (" · 白门楼" if shell.selected_province == "徐州" else ""), CHROME.font_size(23, shell.size, 19), DETAIL_INK, true))
	var scroll := ScrollContainer.new()
	scroll.name = "world_detail_scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.focus_mode = Control.FOCUS_ALL
	parent.add_child(scroll)
	var detail := T.column(scroll)
	detail.add_theme_constant_override("separation", 4)
	if shell.selected_province != "徐州":
		detail.add_child(T.paragraph("暂无可赴战役。", DETAIL_MUTED, CHROME.font_size(14, shell.size, 14)))
		return
	detail.add_child(T.paragraph("下邳旧城，鬼火未息。旧将据城，鬼曹军已逼近城外。", DETAIL_INK, CHROME.font_size(14, shell.size, 14)))
	detail.add_child(T.label(phase + " · 已过%d战" % victories, CHROME.font_size(13, shell.size, 13), DETAIL_MUTED))
	detail.add_child(T.paragraph("当前行军：" + shell.session.nodes[shell.session.data.current].name, DETAIL_INK, CHROME.font_size(13, shell.size, 13)))
	if not shell.session.data.pending.is_empty(): detail.add_child(T.label("完成本关选卡后继续行军。", CHROME.font_size(13, shell.size, 13), DETAIL_MUTED))

static func build_action(shell: Control, parent: VBoxContainer) -> void:
	var state: RefCounted = shell.session
	var text := "完成选卡" if not state.data.pending.is_empty() else "查看战果" if state.data.finished else "继续行军" if state.data.started else "进入白门楼"
	var action: Button = shell.action(parent, text, func():
		if not state.data.pending.is_empty(): shell.open_page("reward")
		elif state.data.finished: shell.open_page("journal")
		elif state.data.started: shell.resume_view()
		elif state.begin_campaign(): shell.resume_view(), "world_enter", true)
	ROUTE_PAGE.style_primary_action(action, shell)

static func campaign_status(state: RefCounted) -> String:
	if not state.data.pending.is_empty(): return "待完成选卡"
	if state.awaiting_battle_story(): return "待续剧情"
	if state.data.finished: return "战役告捷"
	var count := 0
	for id in state.data.available:
		if ROUTE_PAGE.MAP.state_for(state, str(id)) == "available": count += 1
	return "前路%d处" % count
