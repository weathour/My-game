extends Control

signal closed

const SURVIVORS_MODAL := preload("res://scripts/ui/core/survivors_modal.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const SURVIVORS_HOVER_DETAIL := preload("res://scripts/ui/components/survivors_hover_detail.gd")
const BUILD_SKILL_GRAPH_MODEL := preload("res://scripts/build/build_skill_graph_model.gd")
const BUILD_SKILL_GRAPH_VIEW := preload("res://scripts/ui/build_graph/build_skill_graph_view.gd")

var modal: Control
var graph_view: Control
var graph_scroll: ScrollContainer
var hover_detail: Control
var filter_buttons: Dictionary = {}
var route_buttons: Dictionary = {}
var search_box: LineEdit
var search_status_label: Label
var focus_status_label: Label
var paused_by_panel := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()

func show_panel(should_pause: bool = true) -> void:
	var graph: Dictionary = BUILD_SKILL_GRAPH_MODEL.build_graph()
	if modal != null and modal.has_method("set_hint"):
		modal.set_hint("小方块用单字概括技能，所有同等级节点排在同一横排；悬停看详情，点击锁定局部关系。%s" % BUILD_SKILL_GRAPH_MODEL.get_graph_summary(graph))
	if graph_view != null and graph_view.has_method("set_graph"):
		graph_view.set_graph(graph)
		if graph_view.has_method("set_edge_view_mode"):
			graph_view.set_edge_view_mode("overview")
	if search_box != null:
		search_box.text = ""
	if search_status_label != null:
		search_status_label.text = ""
	_refresh_focus_status()
	_refresh_filter_buttons()
	_refresh_route_buttons()
	visible = true
	if hover_detail != null and hover_detail.has_method("hide_detail"):
		hover_detail.hide_detail()
	if graph_view != null and graph_view.has_method("clear_locked_focus"):
		graph_view.clear_locked_focus()
	if should_pause and get_tree() != null and not get_tree().paused:
		paused_by_panel = true
		get_tree().paused = true
	else:
		paused_by_panel = false

func hide_panel() -> void:
	visible = false
	if hover_detail != null and hover_detail.has_method("hide_detail"):
		hover_detail.hide_detail()
	if paused_by_panel and get_tree() != null:
		get_tree().paused = false
	paused_by_panel = false
	closed.emit()

func toggle_panel(should_pause: bool = true) -> void:
	if visible:
		hide_panel()
	else:
		show_panel(should_pause)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			hide_panel()
			get_viewport().set_input_as_handled()

func _build_ui() -> void:
	modal = SURVIVORS_MODAL.new()
	modal.configure(Vector2(1180.0, 660.0), 0.92, 0.90, Vector2(520.0, 320.0))
	modal.set_title("Build 技能图谱")
	modal.set_hint("显示所有首批 Build 的演进层级与逻辑关系。")
	add_child(modal)

	var layout := HBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 12)
	modal.set_body(layout)

	var legend := _build_legend()
	layout.add_child(legend)

	graph_scroll = ScrollContainer.new()
	graph_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	graph_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	layout.add_child(graph_scroll)

	graph_view = BUILD_SKILL_GRAPH_VIEW.new()
	graph_view.node_hovered.connect(_on_graph_node_hovered)
	graph_view.node_unhovered.connect(_on_graph_node_unhovered)
	graph_view.node_focus_changed.connect(_on_graph_node_focus_changed)
	graph_view.node_focus_cleared.connect(_on_graph_node_focus_cleared)
	graph_view.search_changed.connect(_on_graph_search_changed)
	graph_scroll.add_child(graph_view)

	modal.clear_footer()
	modal.add_footer_button("清除锁定", Callable(self, "_on_clear_focus_pressed"), "normal")
	modal.add_footer_button("关闭", Callable(self, "hide_panel"), "primary")

	hover_detail = SURVIVORS_HOVER_DETAIL.new()
	add_child(hover_detail)

func _build_legend() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(180.0, 0.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", SURVIVORS_THEME.panel_style(Color(0.035, 0.045, 0.070, 0.86), Color(0.42, 0.54, 0.76, 0.72), 1, 10, 10.0))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	_add_legend_label(content, "读图说明", SURVIVORS_THEME.COLOR_TEXT_GOLD, 17)
	_add_legend_label(content, "从上到下：Lv.1 起步 → Lv.6 第一次质变 → Lv.12 循环 → Lv.18 成型 → Lv.25 毕业；同层级技能固定在同一横排。", SURVIVORS_THEME.COLOR_TEXT, 13)
	_add_legend_label(content, "每个小方块只显示一个字：剑/枪/术代表归属，入/离/攻/绝/被/联/合/终/成代表功能；完整说明放到悬停详情。", SURVIVORS_THEME.COLOR_TEXT_MUTED, 13)
	_add_legend_label(content, "搜索定位", SURVIVORS_THEME.COLOR_TEXT_GOLD, 15)
	search_box = LineEdit.new()
	search_box.placeholder_text = "技能名 / 英雄 / 关键词"
	search_box.custom_minimum_size = Vector2(0.0, 32.0)
	search_box.clear_button_enabled = true
	search_box.add_theme_font_size_override("font_size", 13)
	search_box.add_theme_stylebox_override("normal", SURVIVORS_THEME.panel_style(Color(0.025, 0.035, 0.055, 0.96), Color(0.30, 0.38, 0.56, 0.85), 1, 8, 8.0))
	search_box.add_theme_stylebox_override("focus", SURVIVORS_THEME.panel_style(Color(0.035, 0.045, 0.070, 0.98), SURVIVORS_THEME.COLOR_BORDER_GOLD, 2, 8, 8.0))
	search_box.text_changed.connect(_on_search_text_changed)
	search_box.text_submitted.connect(_on_search_text_submitted)
	content.add_child(search_box)
	search_status_label = Label.new()
	search_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	search_status_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	search_status_label.add_theme_font_size_override("font_size", 12)
	content.add_child(search_status_label)
	_add_legend_label(content, "路线视图", SURVIVORS_THEME.COLOR_TEXT_GOLD, 15)
	_add_route_button(content, "主干", "overview")
	_add_route_button(content, "解锁", "unlock")
	_add_route_button(content, "状态", "state")
	_add_route_button(content, "全部", "all")
	_add_legend_label(content, "关系筛选", SURVIVORS_THEME.COLOR_TEXT_GOLD, 15)
	_add_filter_button(content, "全部关系", "all")
	_add_filter_button(content, "金：同包演进", "progression")
	_add_filter_button(content, "蓝：投入门槛", "investment")
	_add_filter_button(content, "绿：英雄接力", "edge_unlock")
	_add_filter_button(content, "紫：状态逻辑", "state_logic")
	_add_filter_button(content, "橙：桥接路线", "bridge")
	focus_status_label = Label.new()
	focus_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	focus_status_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	focus_status_label.add_theme_font_size_override("font_size", 12)
	content.add_child(focus_status_label)
	_add_legend_label(content, "操作：悬停临时查看局部关系；点击方块可锁定该节点的前置/后续，再点一次或按“清除锁定”恢复。", SURVIVORS_THEME.COLOR_TEXT_MUTED, 13)
	return panel

func _add_legend_label(parent: Control, text_value: String, color: Color, font_size: int) -> void:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)

func _add_filter_button(parent: Control, text_value: String, filter_key: String) -> void:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 32.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 13)
	SURVIVORS_THEME.apply_button_style(button)
	button.pressed.connect(_on_filter_button_pressed.bind(filter_key))
	parent.add_child(button)
	filter_buttons[filter_key] = button

func _add_route_button(parent: Control, text_value: String, mode_key: String) -> void:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 30.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 13)
	SURVIVORS_THEME.apply_button_style(button)
	button.pressed.connect(_on_route_button_pressed.bind(mode_key))
	parent.add_child(button)
	route_buttons[mode_key] = button

func _on_route_button_pressed(mode_key: String) -> void:
	if graph_view == null or not graph_view.has_method("set_edge_view_mode"):
		return
	graph_view.set_edge_view_mode(mode_key)
	_refresh_route_buttons()
	_refresh_filter_buttons()
	_refresh_focus_status()

func _on_filter_button_pressed(filter_key: String) -> void:
	if graph_view == null:
		return
	match filter_key:
		"all":
			graph_view.show_all_edge_types()
		"bridge":
			if graph_view.has_method("set_visible_edge_types"):
				graph_view.set_visible_edge_types(["bridge_edge", "relay_edge", "mirror_edge"])
			else:
				for type_key in graph_view.get_visible_edge_types().keys():
					graph_view.set_edge_type_visible(str(type_key), ["bridge_edge", "relay_edge", "mirror_edge"].has(str(type_key)))
		_:
			graph_view.set_only_edge_type(filter_key)
	_refresh_filter_buttons()
	_refresh_route_buttons()
	_refresh_focus_status()

func _refresh_filter_buttons() -> void:
	if graph_view == null:
		return
	var visible_types: Dictionary = graph_view.get_visible_edge_types()
	var all_visible := true
	for value in visible_types.values():
		all_visible = all_visible and bool(value)
	_update_filter_button_style("all", all_visible)
	_update_filter_button_style("progression", bool(visible_types.get("progression", false)) and _only_types_visible(["progression"], visible_types))
	_update_filter_button_style("investment", bool(visible_types.get("investment", false)) and _only_types_visible(["investment"], visible_types))
	_update_filter_button_style("edge_unlock", bool(visible_types.get("edge_unlock", false)) and _only_types_visible(["edge_unlock"], visible_types))
	_update_filter_button_style("state_logic", bool(visible_types.get("state_logic", false)) and _only_types_visible(["state_logic"], visible_types))
	_update_filter_button_style("bridge", _only_types_visible(["bridge_edge", "relay_edge", "mirror_edge"], visible_types))

func _refresh_route_buttons() -> void:
	if graph_view == null or not graph_view.has_method("get_edge_view_mode"):
		return
	var mode_key: String = graph_view.get_edge_view_mode()
	for key_value in route_buttons.keys():
		var key := str(key_value)
		var button: Button = route_buttons.get(key, null)
		if button == null:
			continue
		var selected := key == mode_key
		SURVIVORS_THEME.apply_button_style(button, "primary" if selected else "normal", selected)

func _update_filter_button_style(filter_key: String, selected: bool) -> void:
	var button: Button = filter_buttons.get(filter_key, null)
	if button == null:
		return
	SURVIVORS_THEME.apply_button_style(button, "primary" if selected else "normal", selected)

func _only_types_visible(expected_types: Array, visible_types: Dictionary) -> bool:
	var has_any_expected := false
	for type_key_value in visible_types.keys():
		var type_key := str(type_key_value)
		var should_be_visible := expected_types.has(type_key)
		var is_visible := bool(visible_types.get(type_key, false))
		if should_be_visible and is_visible:
			has_any_expected = true
		if should_be_visible != is_visible:
			return false
	return has_any_expected

func _on_search_text_changed(new_text: String) -> void:
	if graph_view == null or not graph_view.has_method("set_search_text"):
		return
	var matches: Array = graph_view.set_search_text(new_text)
	_update_search_status(matches)

func _on_search_text_submitted(_new_text: String) -> void:
	if graph_view == null or not graph_view.has_method("focus_first_search_match"):
		return
	if graph_view.focus_first_search_match():
		call_deferred("_scroll_to_focused_node")

func _on_graph_search_changed(matches: Array) -> void:
	_update_search_status(matches)

func _update_search_status(matches: Array) -> void:
	if search_status_label == null:
		return
	var query := search_box.text.strip_edges() if search_box != null else ""
	if query == "":
		search_status_label.text = "输入后会高亮匹配节点；回车锁定第一个结果。"
		return
	if matches.is_empty():
		search_status_label.text = "未找到匹配节点。"
	else:
		search_status_label.text = "找到 %d 个匹配；回车定位第一个。" % matches.size()

func _on_graph_node_focus_changed(item: Dictionary) -> void:
	_refresh_focus_status(item)
	call_deferred("_scroll_to_focused_node")

func _on_graph_node_focus_cleared() -> void:
	_refresh_focus_status()

func _on_clear_focus_pressed() -> void:
	if graph_view != null and graph_view.has_method("clear_locked_focus"):
		graph_view.clear_locked_focus()

func _refresh_focus_status(item: Dictionary = {}) -> void:
	if focus_status_label == null:
		return
	if graph_view == null or not graph_view.has_method("get_locked_focus_id") or graph_view.get_locked_focus_id() == "":
		var counts_text := ""
		if graph_view != null and graph_view.has_method("get_edge_counts"):
			var counts: Dictionary = graph_view.get_edge_counts()
			counts_text = " 当前显示 %d/%d 条关系。" % [int(counts.get("visible", 0)), int(counts.get("total", 0))]
		focus_status_label.text = "未锁定节点：悬停临时聚焦，点击可锁定关系。%s" % counts_text
		return
	var title := str(item.get("title", graph_view.get_locked_focus_id()))
	var local_text := ""
	if graph_view.has_method("get_edge_counts"):
		var counts: Dictionary = graph_view.get_edge_counts()
		local_text = "（%d 条）" % int(counts.get("highlighted", 0))
	focus_status_label.text = "已锁定：%s｜只显示它的直接前置/后续关系%s。" % [title, local_text]

func _scroll_to_focused_node() -> void:
	if graph_view == null or graph_scroll == null:
		return
	if not graph_view.has_method("get_locked_focus_id") or not graph_view.has_method("get_node_rect"):
		return
	var node_id: String = graph_view.get_locked_focus_id()
	if node_id == "":
		return
	var rect: Rect2 = graph_view.get_node_rect(node_id)
	if rect.size == Vector2.ZERO:
		return
	var target_x := int(max(0.0, rect.position.x - graph_scroll.size.x * 0.42 + rect.size.x * 0.5))
	var target_y := int(max(0.0, rect.position.y - graph_scroll.size.y * 0.42 + rect.size.y * 0.5))
	graph_scroll.scroll_horizontal = target_x
	graph_scroll.scroll_vertical = target_y

func _on_graph_node_hovered(item: Dictionary, anchor_rect: Rect2) -> void:
	if hover_detail != null and hover_detail.has_method("show_item"):
		hover_detail.show_item(item, get_viewport().get_mouse_position(), anchor_rect)

func _on_graph_node_unhovered() -> void:
	if hover_detail == null:
		return
	if hover_detail.has_method("request_hide"):
		hover_detail.request_hide()
	elif hover_detail.has_method("hide_detail"):
		hover_detail.hide_detail()
