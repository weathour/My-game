extends RefCounted
## Route inspection stays in UI state; only the explicit forward action commits a node.
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const MAP := preload("res://scripts/ui/chronicle/chronicle_route_map.gd")
const CAMPAIGN := preload("res://scripts/campaign/campaign_service.gd")

const CHROME := preload("res://scripts/ui/chronicle/chronicle_campaign_chrome.gd")
const DETAIL_INK := Color("302d23")
const DETAIL_MUTED := Color("5b5544")

static func build(shell: Control) -> void:
	var slots: Dictionary = CHROME.build(shell, shell.body, "route")
	var context: VBoxContainer = slots.context
	context.add_child(T.label("白门楼 · " + CAMPAIGN.SEGMENTS[int(shell.session.nodes[shell.session.data.current].segment)], CHROME.font_size(25, shell.size, 21), T.LIGHT, true))
	var current: Dictionary = shell.session.nodes[shell.session.data.current]
	context.add_child(T.label("当前行军：" + current.name, CHROME.font_size(15, shell.size, 15), T.MUTED))
	var map_region: Control = slots.map
	shell.route_map = MAP.new()
	shell.route_map.name = "CampaignRouteMap"
	shell.route_map.preserve_left_overlay = true
	shell.route_map._previous_view_size = shell.route_view_size
	shell.route_map.session = shell.session
	shell.route_map.selected = shell.selected_node
	shell.route_map.scroll_offset = shell.route_scroll
	shell.route_map.offset_changed.connect(func(value: float): shell.route_scroll = value)
	shell.route_map.node_selected.connect(func(id: String): select_node(shell, id))
	map_region.add_child(shell.route_map)
	shell.route_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var locator: Button = shell.quiet_action(slots.map_tools, "定位\n当前", func(): locate_current(shell), "route_current")
	style_map_tool(locator, shell, false)
	build_choices(shell, slots.choices)
	fit_choice_panel(shell, slots)
	build_details(shell, slots.detail)
	build_action(shell, slots.actions, shell.selected_node, MAP.state_for(shell.session, shell.selected_node))

static func build_choices(shell: Control, parent: VBoxContainer) -> void:
	parent.add_child(T.label("待结算" if not shell.session.data.pending.is_empty() else "前路", CHROME.font_size(21, shell.size, 18), T.LIGHT, true))
	var ids: Array = shell.session.data.available.duplicate()
	if not shell.session.data.pending.is_empty():
		var pending: Dictionary = shell.session.data.pending
		parent.add_child(T.paragraph(shell.session.nodes[pending.node].name + " · 待选奖励", T.LIGHT, CHROME.font_size(16, shell.size, 14)))
		parent.add_child(T.label("已选 %d / %d" % [pending.selected.size(), pending.picks], CHROME.font_size(14, shell.size, 13), T.GOLD))
		return
	elif shell.session.awaiting_battle_story(): ids = [shell.session.data.current]
	if ids.is_empty():
		parent.add_child(T.label("战役已完成" if shell.session.data.finished else "暂无可前往节点", CHROME.font_size(14, shell.size, 13), T.MUTED))
		return
	for value in ids:
		var id := str(value)
		if not shell.session.nodes.has(id): continue
		var node: Dictionary = shell.session.nodes[id]
		var state := MAP.state_for(shell.session, id)
		var selected: bool = shell.selected_node == id
		var card := Button.new()
		card.name = "route_choice_" + id
		card.custom_minimum_size.y = maxf(100, 110 * page_scale(shell))
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.pressed.connect(func(): select_node(shell, id))
		for key in ["normal", "hover", "pressed", "disabled"]:
			var fill := Color("592e28") if selected or key == "pressed" else Color("354934") if key == "hover" else Color("20372a")
			card.add_theme_stylebox_override(key, T.box(fill, T.GOLD if selected else T.BORDER, 6))
		var focus := T.box(Color.TRANSPARENT, T.GOLD, 0)
		focus.set_border_width_all(2)
		card.add_theme_stylebox_override("focus", focus)
		parent.add_child(card)
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(margin)
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, int(8 * maxf(1, page_scale(shell))))
		var content := T.column(margin)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", int(4 * maxf(1, page_scale(shell))))
		var heading := T.row(content)
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heading.add_child(kind_icon(node.kind, int(22 * page_scale(shell))))
		var title := T.label(node.name, CHROME.font_size(18, shell.size, 15), T.LIGHT, true)
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(title)
		content.add_child(T.label(MAP.kind_label(node.kind) + " · " + MAP.state_label(state), CHROME.font_size(12, shell.size, 12), T.GOLD if selected else T.MUTED))
		var brief := T.paragraph(node_summary(node), T.LIGHT, CHROME.font_size(13, shell.size, 12))
		brief.max_lines_visible = 2
		brief.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		content.add_child(brief)
		card.tooltip_text = brief.text

static func fit_choice_panel(shell: Control, slots: Dictionary) -> void:
	# Absolute campaign regions can shrink to their actual cards without
	# reserving an empty management sidebar beneath the final choice.
	var fit := func():
		if not is_instance_valid(slots.choice_panel): return
		var panel: PanelContainer = slots.choice_panel
		panel.size.y = panel.get_combined_minimum_size().y
		var actions: Control = slots.actions
		actions.position.y = panel.position.y + panel.size.y + 16.0 * shell.size.y / 720.0
	fit.call_deferred()

static func style_map_tool(button: Button, shell: Control, round_tool: bool) -> void:
	var side := (88.0 if round_tool else 76.0) * minf(shell.size.x / 1280.0, shell.size.y / 720.0)
	button.custom_minimum_size = Vector2.ONE * maxf(56, side)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", CHROME.font_size(17, shell.size, 14))
	for key in ["normal", "hover", "pressed"]:
		var style := T.box(Color("354934") if key == "hover" else Color("592e28") if key == "pressed" else Color("17291e"), T.GOLD, 7)
		style.set_border_width_all(2)
		if round_tool: style.set_corner_radius_all(int(side * .5))
		button.add_theme_stylebox_override(key, style)

static func select_node(shell: Control, id: String) -> void:
	if not shell.session.nodes.has(id): return
	shell.selected_node = id
	shell.segment = int(shell.session.nodes[id].segment)
	reset_detail_scroll(shell)
	shell.render()

static func locate_current(shell: Control) -> void:
	shell.selected_node = shell.session.data.current
	shell.segment = int(shell.session.nodes[shell.selected_node].segment)
	shell.route_scroll = -1.0
	reset_detail_scroll(shell)
	shell.focus_memory.erase("route")
	shell.render()

static func reset_detail_scroll(shell: Control) -> void:
	if is_instance_valid(shell.frame):
		var scroll := shell.frame.find_child("route_detail_scroll", true, false) as ScrollContainer
		if scroll != null: scroll.scroll_vertical = 0
	if shell.scroll_memory.has("route"): shell.scroll_memory.route.erase("route_detail_scroll")

static func build_details(shell: Control, column: VBoxContainer) -> void:
	column.add_theme_constant_override("separation", 4)
	var id: String = shell.selected_node
	var node: Dictionary = shell.session.nodes[id]
	var key := MAP.state_for(shell.session, id)
	var metadata := T.row(column)
	var icon := kind_icon(node.kind, int(18 * page_scale(shell)))
	icon.name = "route_detail_icon"
	metadata.add_child(icon)
	metadata.add_child(T.label(MAP.kind_label(node.kind), CHROME.font_size(12, shell.size, 12), DETAIL_MUTED))
	T.space(metadata)
	var state_label := T.label(MAP.state_label(key), CHROME.font_size(12, shell.size, 12), DETAIL_MUTED)
	state_label.name = "route_node_status"
	metadata.add_child(state_label)
	var title := T.paragraph(node.name, DETAIL_INK, CHROME.font_size(21, shell.size, 18))
	title.name = "route_node_title"
	title.add_theme_font_override("font", T.FONT.get_heading_font())
	column.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.name = "route_detail_scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	var detail := T.column(scroll)
	detail.add_theme_constant_override("separation", 4)
	var summary := T.paragraph(node_summary(node), DETAIL_INK, CHROME.font_size(13, shell.size, 13))
	summary.name = "route_node_summary"
	detail.add_child(summary)
	if key in ["locked", "skipped", "unavailable"]:
		detail.add_child(T.paragraph(state_explanation(key), DETAIL_MUTED, CHROME.font_size(12, shell.size, 12)))
	var effect := "" if key == "completed" else effect_text(shell, id)
	if not effect.is_empty(): detail.add_child(T.paragraph(effect, DETAIL_INK, CHROME.font_size(12, shell.size, 12)))
	if node.kind in ["battle", "elite", "boss"]:
		var enemy: Button = shell.quiet_action(detail, "查看敌情", func(): shell.open_enemy_codex(id), "route_enemy_codex")
		enemy.add_theme_color_override("font_color", DETAIL_INK)
		enemy.add_theme_color_override("font_hover_color", DETAIL_INK)
		enemy.add_theme_color_override("font_focus_color", DETAIL_INK)
		enemy.add_theme_color_override("font_pressed_color", DETAIL_INK)
		for state in ["normal", "hover", "pressed"]:
			var fill := Color("c6b68e") if state == "hover" else Color("b8a67d") if state == "pressed" else Color.TRANSPARENT
			var paper_action := T.box(fill, Color.TRANSPARENT, 4 * page_scale(shell))
			paper_action.set_border_width_all(0)
			enemy.add_theme_stylebox_override(state, paper_action)
		var paper_focus := T.box(Color.TRANSPARENT, Color("6b4c27"), 0)
		paper_focus.set_border_width_all(2)
		enemy.add_theme_stylebox_override("focus", paper_focus)
		enemy.custom_minimum_size.y = maxf(28, 28 * page_scale(shell))
		enemy.add_theme_font_size_override("font_size", CHROME.font_size(16, shell.size, 14))

static func kind_icon(kind: String, pixels: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = MAP.kind_icon(kind)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * pixels
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

static func build_action(shell: Control, parent: Control, id: String, key: String) -> void:
	var action: Button
	if not shell.session.data.pending.is_empty():
		action = shell.action(parent, "完成%s选卡" % shell.session.nodes[shell.session.data.pending.node].name, func(): shell.open_page("reward"), "route_reward", true)
	elif key == "completed":
		if shell.can_replay_story(id):
			action = shell.action(parent, "回顾 · " + shell.session.nodes[id].name, func(): shell.open_story_replay(id), "route_replay", true)
	elif key in ["available", "unavailable"]:
		var node: Dictionary = shell.session.nodes[id]
		var event: bool = node.kind in ["event", "spring"] or (shell.session.has_method("event_available") and shell.session.event_available(id))
		action = shell.action(parent, "暂不可前往" if key == "unavailable" else "前往 · " + node.name, func():
			if shell.session.choose_node(id): shell.open_page("event" if event else "preparation"), "route_forward", true)
		action.disabled = key == "unavailable"
	if action != null:
		style_primary_action(action, shell)
		action.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		action.tooltip_text = action.text

static func effect_text(shell: Control, id: String) -> String:
	if id == "S02" and not shell.session.data.owned.has("F11"):
		return "剧情结束后：艾玛加入队伍并进入卡池。"
	if shell.session.nodes[id].kind == "spring":
		return "饮泉休整后：已获得人物生命、魔法回满，阵亡辅助复活。"
	if shell.session.UNLOCKS.has(id):
		var names: Array[String] = []
		for person in shell.session.UNLOCKS[id]: names.append(shell.session.characters[person].name)
		return ("战后剧情结束后加入卡池：" if shell.session.nodes[id].kind in ["battle", "elite", "boss"] else "剧情结束后加入卡池：") + "、".join(names)
	return ""

static func state_color(key: String) -> Color:
	if key in ["available", "reward"]: return T.GOLD
	if key == "completed": return Color("acbea4")
	return T.MUTED

static func state_explanation(key: String) -> String:
	return str({"completed":"节点已完成，不能再次领取收益。", "available":"可从这里继续行军。",
		"locked":"尚未到达此节点。", "skipped":"当前行军已选择其他前路，无法再进入。",
		"reward":"请先完成本关选卡，再继续行军。", "unavailable":"此节点尚未开放，暂不可前往。"}.get(key, ""))

static func node_summary(node: Dictionary) -> String:
	var summary := str(node.get("map_summary", "")).strip_edges()
	return str(node.get("summary", "")) if summary.is_empty() else summary

static func page_scale(shell: Control) -> float:
	return minf(shell.size.x / 1280.0, shell.size.y / 720.0)

static func style_primary_action(button: Button, shell: Control) -> void:
	button.custom_minimum_size.y = maxf(42, 48 * page_scale(shell))
	button.add_theme_font_size_override("font_size", CHROME.font_size(16, shell.size, 14))
