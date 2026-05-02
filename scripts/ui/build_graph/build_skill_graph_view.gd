extends Control

signal node_hovered(item: Dictionary, anchor_rect: Rect2)
signal node_unhovered
signal node_focus_changed(item: Dictionary)
signal node_focus_cleared
signal search_changed(match_ids: Array)

const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")

const NODE_SIZE := Vector2(36.0, 36.0)
const NODE_HORIZONTAL_GAP := 10.0
const LANE_GROUP_GAP := 28.0
const LAYER_ROW_HEIGHT := 88.0
const TOP_MARGIN := 14.0
const LEFT_MARGIN := 98.0
const RIGHT_MARGIN := 42.0
const BOTTOM_MARGIN := 28.0
const MIN_GRAPH_WIDTH := 860.0
const EDGE_BUS_GAP := 7.0
const EDGE_PORT_GAP := 4.5
const EDGE_TYPE_DRAW_ORDER := [
	"progression",
	"mastery",
	"bridge_edge",
	"relay_edge",
	"mirror_edge",
	"edge_unlock",
	"investment",
	"state_logic"
]

var graph: Dictionary = {}
var node_positions: Dictionary = {}
var node_lookup: Dictionary = {}
var node_glyphs: Dictionary = {}
var node_visual_states: Dictionary = {}
var layer_bounds: Dictionary = {}
var lane_group_bounds: Dictionary = {}
var lane_ids: Array[String] = []
var lane_titles: Dictionary = {}
var edge_type_labels: Dictionary = {}
var filtered_edge_types: Dictionary = {}
var visible_edges: Array = []
var hovered_node_id := ""
var locked_node_id := ""
var search_text := ""
var search_match_ids: Array[String] = []
var edge_view_mode := "overview"
var graph_content_width := MIN_GRAPH_WIDTH
var pressed_node_id := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_graph(next_graph: Dictionary) -> void:
	graph = next_graph.duplicate(true)
	edge_type_labels = (graph.get("edge_type_labels", {}) as Dictionary).duplicate(true)
	hovered_node_id = ""
	locked_node_id = ""
	search_text = ""
	search_match_ids.clear()
	_reset_edge_filter()
	_rebuild_layout()

func set_edge_view_mode(next_mode: String) -> void:
	var normalized := next_mode
	if not ["overview", "unlock", "state", "all"].has(normalized):
		normalized = "overview"
	edge_view_mode = normalized
	match edge_view_mode:
		"overview":
			_apply_visible_edge_types(["progression", "mastery", "bridge_edge", "relay_edge", "mirror_edge"])
		"unlock":
			_apply_visible_edge_types(["investment", "edge_unlock"])
		"state":
			_apply_visible_edge_types(["state_logic", "bridge_edge", "relay_edge", "mirror_edge"])
		"all":
			show_all_edge_types()

func get_edge_view_mode() -> String:
	return edge_view_mode

func set_visible_edge_types(edge_types: Array) -> void:
	edge_view_mode = "custom"
	_apply_visible_edge_types(edge_types)

func _apply_visible_edge_types(edge_types: Array) -> void:
	var wanted := {}
	for edge_type_value in edge_types:
		wanted[str(edge_type_value)] = true
	for type_key in _get_all_edge_types():
		filtered_edge_types[type_key] = bool(wanted.get(type_key, false))
	_update_visible_edges()
	queue_redraw()

func set_edge_type_visible(edge_type: String, is_visible: bool) -> void:
	filtered_edge_types[edge_type] = is_visible
	edge_view_mode = "custom"
	_update_visible_edges()
	queue_redraw()

func set_only_edge_type(edge_type: String) -> void:
	for type_key in _get_all_edge_types():
		filtered_edge_types[type_key] = type_key == edge_type
	edge_view_mode = "custom"
	_update_visible_edges()
	queue_redraw()

func show_all_edge_types() -> void:
	for type_key in _get_all_edge_types():
		filtered_edge_types[type_key] = true
	edge_view_mode = "all"
	_update_visible_edges()
	queue_redraw()

func get_visible_edge_types() -> Dictionary:
	return filtered_edge_types.duplicate(true)

func get_visible_edges() -> Array:
	return visible_edges.duplicate(true)

func get_edge_counts() -> Dictionary:
	var counts := {
		"total": 0,
		"visible": visible_edges.size(),
		"highlighted": 0
	}
	for raw_edge in graph.get("edges", []):
		if raw_edge is Dictionary:
			counts["total"] = int(counts.get("total", 0)) + 1
	var focus_node_id := _active_focus_node_id()
	if focus_node_id != "":
		for raw_edge in visible_edges:
			if raw_edge is not Dictionary:
				continue
			var edge: Dictionary = raw_edge as Dictionary
			if str(edge.get("from", "")) == focus_node_id or str(edge.get("to", "")) == focus_node_id:
				counts["highlighted"] = int(counts.get("highlighted", 0)) + 1
	return counts

func clear_locked_focus() -> void:
	if locked_node_id == "":
		return
	locked_node_id = ""
	_refresh_node_styles()
	queue_redraw()
	node_focus_cleared.emit()

func get_locked_focus_id() -> String:
	return locked_node_id

func set_search_text(next_text: String) -> Array[String]:
	search_text = next_text.strip_edges().to_lower()
	search_match_ids.clear()
	if search_text != "":
		for node_id_value in node_lookup.keys():
			var node_id := str(node_id_value)
			var node: Dictionary = node_lookup.get(node_id, {})
			if _node_matches_search(node, search_text):
				search_match_ids.append(node_id)
	_refresh_node_styles()
	queue_redraw()
	search_changed.emit(search_match_ids.duplicate())
	return search_match_ids.duplicate()

func clear_search() -> void:
	if search_text == "" and search_match_ids.is_empty():
		return
	search_text = ""
	search_match_ids.clear()
	_refresh_node_styles()
	queue_redraw()
	search_changed.emit([])

func focus_node(node_id: String) -> bool:
	if not node_lookup.has(node_id):
		return false
	locked_node_id = node_id
	hovered_node_id = ""
	_refresh_node_styles()
	queue_redraw()
	node_focus_changed.emit((node_lookup.get(node_id, {}) as Dictionary).duplicate(true))
	return true

func focus_first_search_match() -> bool:
	if search_match_ids.is_empty():
		return false
	return focus_node(search_match_ids[0])

func get_search_match_ids() -> Array[String]:
	return search_match_ids.duplicate()

func get_node_rect(node_id: String) -> Rect2:
	if not node_positions.has(node_id):
		return Rect2()
	return Rect2(node_positions.get(node_id, Vector2.ZERO), NODE_SIZE)

func _rebuild_layout() -> void:
	_clear_node_cache()
	node_positions.clear()
	node_lookup.clear()
	node_glyphs.clear()
	node_visual_states.clear()
	layer_bounds.clear()
	lane_group_bounds.clear()
	_build_lane_data()
	var groups: Dictionary = _group_nodes()
	var layer_count: int = 0
	var max_row_width := MIN_GRAPH_WIDTH
	for raw_layer in graph.get("layers", []):
		if raw_layer is not Dictionary:
			continue
		var layer: Dictionary = raw_layer as Dictionary
		var layer_id: int = int(layer.get("id", 0))
		var row_width := _row_width_for_layer(groups, layer_id)
		max_row_width = max(max_row_width, row_width + RIGHT_MARGIN)
	graph_content_width = max_row_width
	var current_y: float = TOP_MARGIN
	for raw_layer in graph.get("layers", []):
		if raw_layer is not Dictionary:
			continue
		var layer: Dictionary = raw_layer as Dictionary
		var layer_id: int = int(layer.get("id", 0))
		var row_nodes: Array = []
		layer_bounds[layer_id] = Rect2(Vector2(0.0, current_y), Vector2(_graph_width(), LAYER_ROW_HEIGHT))
		var lane_x := LEFT_MARGIN
		for lane_index in range(lane_ids.size()):
			var lane_id: String = lane_ids[lane_index]
			var key: String = _group_key(layer_id, lane_id)
			var layer_lane_nodes: Array = groups.get(key, [])
			_sort_layer_nodes(layer_lane_nodes)
			if layer_lane_nodes.is_empty():
				continue
			var group_start_x := lane_x
			for index in range(layer_lane_nodes.size()):
				var node: Dictionary = layer_lane_nodes[index] as Dictionary
				var node_id: String = str(node.get("id", ""))
				var position := Vector2(lane_x + float(index) * (NODE_SIZE.x + NODE_HORIZONTAL_GAP), current_y + (LAYER_ROW_HEIGHT - NODE_SIZE.y) * 0.5 + 8.0)
				node_positions[node_id] = position
				node_lookup[node_id] = node.duplicate(true)
				node_glyphs[node_id] = _format_node_button_text(node)
				node_visual_states[node_id] = _make_node_visual_state()
				row_nodes.append(node_id)
			var group_width := float(layer_lane_nodes.size()) * NODE_SIZE.x + float(max(0, layer_lane_nodes.size() - 1)) * NODE_HORIZONTAL_GAP
			lane_group_bounds[_lane_group_key(layer_id, lane_id)] = Rect2(Vector2(group_start_x - 4.0, current_y + 20.0), Vector2(group_width + 8.0, NODE_SIZE.y + 16.0))
			lane_x += group_width + LANE_GROUP_GAP
		layer_count += 1
		current_y += LAYER_ROW_HEIGHT
	var resolved_size := Vector2(_graph_width(), TOP_MARGIN + float(layer_count) * LAYER_ROW_HEIGHT + BOTTOM_MARGIN)
	custom_minimum_size = resolved_size
	size = resolved_size
	minimum_size_changed.emit()
	_update_visible_edges()
	_refresh_node_styles()
	queue_redraw()

func _clear_node_cache() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

func _build_lane_data() -> void:
	lane_ids.clear()
	lane_titles.clear()
	for raw_lane in graph.get("lanes", []):
		if raw_lane is not Dictionary:
			continue
		var lane: Dictionary = raw_lane as Dictionary
		var lane_id: String = str(lane.get("id", ""))
		if lane_id == "":
			continue
		lane_ids.append(lane_id)
		lane_titles[lane_id] = str(lane.get("title", lane_id))

func _group_nodes() -> Dictionary:
	var groups: Dictionary = {}
	for raw_node in graph.get("nodes", []):
		if raw_node is not Dictionary:
			continue
		var node: Dictionary = raw_node as Dictionary
		var key: String = _group_key(int(node.get("layer", 0)), str(node.get("lane", "generic")))
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(node)
	return groups

func _row_width_for_layer(groups: Dictionary, layer_id: int) -> float:
	var width := LEFT_MARGIN
	var non_empty_groups := 0
	for lane_id in lane_ids:
		var count: int = (groups.get(_group_key(layer_id, lane_id), []) as Array).size()
		if count <= 0:
			continue
		if non_empty_groups > 0:
			width += LANE_GROUP_GAP
		width += float(count) * NODE_SIZE.x + float(max(0, count - 1)) * NODE_HORIZONTAL_GAP
		non_empty_groups += 1
	return width

func _sort_layer_nodes(nodes: Array) -> void:
	nodes.sort_custom(func(a, b):
		var node_a: Dictionary = a as Dictionary
		var node_b: Dictionary = b as Dictionary
		if int(node_a.get("team_level_min", 0)) != int(node_b.get("team_level_min", 0)):
			return int(node_a.get("team_level_min", 0)) < int(node_b.get("team_level_min", 0))
		return str(node_a.get("title", "")) < str(node_b.get("title", ""))
	)

func _format_node_button_text(node: Dictionary) -> String:
	return _node_glyph(node)

func _node_glyph(node: Dictionary) -> String:
	var card_type: String = str(node.get("card_type", ""))
	if card_type == "mastery":
		return "成"
	if card_type == "capstone":
		return "终"
	if card_type == "resonance_tri":
		return "合"
	if card_type == "resonance_pair":
		return "联"
	if card_type == "generic":
		return "通"
	var axes: String = str(node.get("logic_text", "")) + "\n" + str(node.get("description", ""))
	if axes.contains("入场"):
		return "入"
	if axes.contains("离场"):
		return "离"
	if axes.contains("大招"):
		return "绝"
	if axes.contains("普攻") or axes.contains("核心输出"):
		return "攻"
	if axes.contains("独立冷却"):
		return "被"
	var owner_role: String = str(node.get("owner_role", ""))
	match owner_role:
		"swordsman":
			return "剑"
		"gunner":
			return "枪"
		"mage":
			return "术"
	return "技"

func _draw() -> void:
	_draw_background()
	_draw_edges()
	_draw_nodes()

func _draw_background() -> void:
	var font: Font = get_theme_default_font()
	var font_size := 12
	for raw_layer in graph.get("layers", []):
		if raw_layer is not Dictionary:
			continue
		var layer: Dictionary = raw_layer as Dictionary
		var layer_id: int = int(layer.get("id", 0))
		var rect: Rect2 = layer_bounds.get(layer_id, Rect2())
		if rect.size == Vector2.ZERO:
			continue
		var bg_color := Color(0.11, 0.13, 0.19, 0.26) if layer_id % 2 == 0 else Color(0.06, 0.08, 0.13, 0.22)
		draw_rect(rect, bg_color, true)
		draw_rect(rect, Color(0.35, 0.42, 0.62, 0.30), false, 1.0)
		var title: String = "%s\n%s" % [str(layer.get("subtitle", "")), str(layer.get("title", ""))]
		draw_string(font, Vector2(10.0, rect.position.y + 28.0), title, HORIZONTAL_ALIGNMENT_LEFT, LEFT_MARGIN - 16.0, font_size, SURVIVORS_THEME.COLOR_TEXT_MUTED)
	for raw_key in lane_group_bounds.keys():
		var key := str(raw_key)
		var parts := key.split("|")
		if parts.size() < 2:
			continue
		var lane_id := str(parts[1])
		var rect: Rect2 = lane_group_bounds.get(key, Rect2())
		if rect.size == Vector2.ZERO:
			continue
		draw_rect(rect, _lane_group_color(lane_id), true)
		draw_rect(rect, Color(0.55, 0.62, 0.82, 0.18), false, 1.0)
		draw_string(font, Vector2(rect.position.x, rect.position.y - 4.0), str(lane_titles.get(lane_id, lane_id)), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 10, SURVIVORS_THEME.COLOR_TEXT_MUTED)

func _draw_edges() -> void:
	var ordered_edges := _ordered_visible_edges()
	for raw_edge in ordered_edges:
		if raw_edge is not Dictionary:
			continue
		var edge: Dictionary = raw_edge as Dictionary
		var from_id: String = str(edge.get("from", ""))
		var to_id: String = str(edge.get("to", ""))
		if not node_positions.has(from_id) or not node_positions.has(to_id):
			continue
		var edge_type: String = str(edge.get("type", "progression"))
		var highlighted := _is_edge_highlighted(edge)
		if _active_focus_node_id() != "" and not highlighted:
			continue
		var route: PackedVector2Array = _route_edge(edge)
		if route.size() < 2:
			continue
		var color: Color = _edge_color(edge_type)
		var width: float = 1.55 if edge_type in ["progression", "mastery"] else 0.95
		if highlighted:
			color.a = min(1.0, color.a + 0.42)
			width += 1.0
		elif _has_search_filter():
			color.a *= 0.42
		draw_polyline(route, color, width, true)
		_draw_arrow(route[route.size() - 1], route[route.size() - 2], color)

func _route_edge(edge: Dictionary) -> PackedVector2Array:
	var from_id: String = str(edge.get("from", ""))
	var to_id: String = str(edge.get("to", ""))
	var from_position: Vector2 = node_positions.get(from_id, Vector2.ZERO)
	var to_position: Vector2 = node_positions.get(to_id, Vector2.ZERO)
	var edge_type: String = str(edge.get("type", "progression"))
	var source_layer: int = int((node_lookup.get(from_id, {}) as Dictionary).get("layer", 0))
	var target_layer: int = int((node_lookup.get(to_id, {}) as Dictionary).get("layer", 0))
	var type_offset: float = _edge_type_offset(edge_type)
	var pair_offset: float = float(edge.get("route_offset", 0.0))
	var start: Vector2
	var end: Vector2
	if target_layer == source_layer:
		start = from_position + Vector2(NODE_SIZE.x + 2.0, NODE_SIZE.y * 0.5 + type_offset)
		end = to_position + Vector2(-2.0, NODE_SIZE.y * 0.5 + type_offset)
		if end.x < start.x:
			start = from_position + Vector2(-2.0, NODE_SIZE.y * 0.5 + type_offset)
			end = to_position + Vector2(NODE_SIZE.x + 2.0, NODE_SIZE.y * 0.5 + type_offset)
		var same_row_bus_y: float = min(start.y, end.y) - 12.0 - absf(pair_offset) * 0.55
		return PackedVector2Array([start, Vector2(start.x, same_row_bus_y), Vector2(end.x, same_row_bus_y), end])
	if target_layer < source_layer:
		start = from_position + Vector2(NODE_SIZE.x * 0.5 + type_offset, -1.0)
		end = to_position + Vector2(NODE_SIZE.x * 0.5 + type_offset, NODE_SIZE.y + 1.0)
		var reverse_bus_y: float = (start.y + end.y) * 0.5 - pair_offset
		return PackedVector2Array([start, Vector2(start.x, reverse_bus_y), Vector2(end.x, reverse_bus_y), end])
	start = from_position + Vector2(NODE_SIZE.x * 0.5 + type_offset, NODE_SIZE.y + 1.0)
	end = to_position + Vector2(NODE_SIZE.x * 0.5 + type_offset, -1.0)
	var layer_gap_top: float = start.y + 6.0
	var layer_gap_bottom: float = end.y - 6.0
	var bus_y: float = (layer_gap_top + layer_gap_bottom) * 0.5 + pair_offset
	var lane_delta: float = absf(end.x - start.x)
	if lane_delta < 4.0 and absf(pair_offset) < 1.0:
		return PackedVector2Array([start, end])
	var start_bus := Vector2(start.x + type_offset * 0.35, bus_y)
	var end_bus := Vector2(end.x - type_offset * 0.35, bus_y)
	return PackedVector2Array([start, start_bus, end_bus, end])

func _draw_arrow(end: Vector2, start: Vector2, color: Color) -> void:
	var direction: Vector2 = (end - start).normalized()
	if direction.length_squared() <= 0.01:
		direction = Vector2.DOWN
	var normal := Vector2(-direction.y, direction.x)
	var arrow_points := PackedVector2Array([
		end,
		end - direction * 5.0 + normal * 2.5,
		end - direction * 5.0 - normal * 2.5
	])
	draw_colored_polygon(arrow_points, color)

func _draw_nodes() -> void:
	var font: Font = get_theme_default_font()
	for node_id_value in node_positions.keys():
		var node_id := str(node_id_value)
		var position: Vector2 = node_positions.get(node_id, Vector2.ZERO)
		var rect := Rect2(position, NODE_SIZE)
		var state: Dictionary = node_visual_states.get(node_id, _make_node_visual_state())
		var selected := bool(state.get("selected", false))
		var accented := bool(state.get("accented", false))
		var disabled := bool(state.get("disabled", false))
		var style := _node_style(selected, accented, disabled)
		draw_rect(rect, style.get("bg", Color.WHITE), true)
		draw_rect(rect, style.get("border", Color.WHITE), false, float(style.get("border_width", 1.0)))
		var glyph := str(node_glyphs.get(node_id, "技"))
		var text_color: Color = style.get("text", SURVIVORS_THEME.COLOR_TEXT)
		var font_size := 20
		var text_width := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		var text_height := font.get_height(font_size)
		var text_position := Vector2(
			rect.position.x + (rect.size.x - text_width) * 0.5,
			rect.position.y + (rect.size.y - text_height) * 0.5 + font.get_ascent(font_size)
		)
		draw_string(font, text_position, glyph, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, font_size, text_color)

func _node_style(selected: bool, accented: bool, disabled: bool) -> Dictionary:
	var bg := Color(0.11, 0.125, 0.18, 0.98)
	var border := Color(0.36, 0.42, 0.58, 0.90)
	var text := SURVIVORS_THEME.COLOR_TEXT
	var border_width := 1.0
	if accented:
		bg = Color(0.07, 0.16, 0.10, 0.98)
		border = Color(0.30, 0.95, 0.44, 0.92)
		text = SURVIVORS_THEME.COLOR_TEXT_GOOD
		border_width = 2.0
	if selected:
		bg = Color(0.30, 0.22, 0.08, 0.98)
		border = SURVIVORS_THEME.COLOR_BORDER_GOLD
		text = SURVIVORS_THEME.COLOR_TEXT_GOLD
		border_width = 2.0
	if disabled:
		bg = bg.darkened(0.28)
		border = border.darkened(0.30)
		text = Color(0.58, 0.62, 0.70, 0.82)
	return {
		"bg": bg,
		"border": border,
		"text": text,
		"border_width": border_width
	}

func _edge_color(edge_type: String) -> Color:
	match edge_type:
		"progression":
			return Color(1.0, 0.80, 0.28, 0.58)
		"mastery":
			return Color(1.0, 0.96, 0.48, 0.78)
		"investment":
			return Color(0.62, 0.92, 1.0, 0.34)
		"edge_unlock":
			return Color(0.66, 1.0, 0.62, 0.38)
		"state_logic":
			return Color(0.88, 0.62, 1.0, 0.30)
		"bridge_edge", "relay_edge", "mirror_edge":
			return Color(1.0, 0.54, 0.36, 0.52)
	return Color(0.68, 0.76, 0.96, 0.24)

func _lane_group_color(lane_id: String) -> Color:
	match lane_id:
		"swordsman":
			return Color(0.32, 0.18, 0.13, 0.18)
		"gunner":
			return Color(0.12, 0.23, 0.36, 0.18)
		"mage":
			return Color(0.22, 0.15, 0.38, 0.18)
		"resonance":
			return Color(0.28, 0.25, 0.10, 0.18)
	return Color(0.16, 0.18, 0.22, 0.18)

func get_node_count() -> int:
	return node_lookup.size()

func get_node_size() -> Vector2:
	return NODE_SIZE

func get_layer_row_count() -> int:
	var count := 0
	for raw_layer in graph.get("layers", []):
		if raw_layer is Dictionary:
			count += 1
	return count

func get_layer_node_rows() -> Dictionary:
	var rows := {}
	for node_id_value in node_positions.keys():
		var node_id := str(node_id_value)
		var node: Dictionary = node_lookup.get(node_id, {})
		var layer_id := int(node.get("layer", -1))
		if not rows.has(layer_id):
			rows[layer_id] = []
		(rows[layer_id] as Array).append(node_id)
	return rows

func _on_node_hovered(node_id: String) -> void:
	if not node_lookup.has(node_id):
		return
	if hovered_node_id == node_id and locked_node_id == "":
		return
	if locked_node_id == "":
		hovered_node_id = node_id
	_refresh_node_styles()
	queue_redraw()
	var item: Dictionary = (node_lookup.get(node_id, {}) as Dictionary).duplicate(true)
	var local_rect := get_node_rect(node_id)
	node_hovered.emit(item, Rect2(global_position + local_rect.position, local_rect.size))

func _on_node_unhovered() -> void:
	if locked_node_id == "":
		hovered_node_id = ""
		_refresh_node_styles()
		queue_redraw()
	node_unhovered.emit()

func _on_node_pressed(node_id: String) -> void:
	if not node_lookup.has(node_id):
		return
	if locked_node_id == node_id:
		clear_locked_focus()
		return
	locked_node_id = node_id
	hovered_node_id = ""
	_refresh_node_styles()
	queue_redraw()
	node_focus_changed.emit((node_lookup.get(node_id, {}) as Dictionary).duplicate(true))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var node_id := _node_id_at_position(motion.position)
		if node_id != hovered_node_id:
			if node_id == "":
				_on_node_unhovered()
			else:
				_on_node_hovered(node_id)
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			pressed_node_id = _node_id_at_position(mouse_event.position)
		else:
			var released_node_id := _node_id_at_position(mouse_event.position)
			if pressed_node_id != "" and pressed_node_id == released_node_id:
				_on_node_pressed(pressed_node_id)
			pressed_node_id = ""

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		if hovered_node_id != "":
			_on_node_unhovered()

func _node_id_at_position(local_position: Vector2) -> String:
	for node_id_value in node_positions.keys():
		var node_id := str(node_id_value)
		var rect := Rect2(node_positions.get(node_id, Vector2.ZERO), NODE_SIZE)
		if rect.has_point(local_position):
			return node_id
	return ""

func _reset_edge_filter() -> void:
	filtered_edge_types.clear()
	for type_key in _get_all_edge_types():
		filtered_edge_types[type_key] = true

func _update_visible_edges() -> void:
	visible_edges = []
	var route_counts: Dictionary = {}
	for raw_edge in graph.get("edges", []):
		if raw_edge is not Dictionary:
			continue
		var edge: Dictionary = (raw_edge as Dictionary).duplicate(true)
		var edge_type: String = str(edge.get("type", ""))
		if not bool(filtered_edge_types.get(edge_type, true)):
			continue
		var from_id: String = str(edge.get("from", ""))
		var to_id: String = str(edge.get("to", ""))
		var route_key: String = "%s|%s|%s|%s" % [
			from_id,
			to_id,
			edge_type,
			str((node_lookup.get(from_id, {}) as Dictionary).get("layer", "")) + ">" + str((node_lookup.get(to_id, {}) as Dictionary).get("layer", ""))
		]
		var route_index: int = int(route_counts.get(route_key, 0))
		route_counts[route_key] = route_index + 1
		edge["route_offset"] = _route_offset_for(edge_type, route_index)
		visible_edges.append(edge)

func _ordered_visible_edges() -> Array:
	var edges := visible_edges.duplicate(true)
	edges.sort_custom(func(a, b):
		var edge_a: Dictionary = a as Dictionary
		var edge_b: Dictionary = b as Dictionary
		var highlighted_a := _is_edge_highlighted(edge_a)
		var highlighted_b := _is_edge_highlighted(edge_b)
		if highlighted_a != highlighted_b:
			return not highlighted_a and highlighted_b
		var order_a := _edge_type_order(str(edge_a.get("type", "")))
		var order_b := _edge_type_order(str(edge_b.get("type", "")))
		if order_a != order_b:
			return order_a < order_b
		return str(edge_a.get("from", "")) < str(edge_b.get("from", ""))
	)
	return edges

func _refresh_node_styles() -> void:
	var active_focus := _active_focus_node_id()
	var has_search := _has_search_filter()
	for node_id_value in node_lookup.keys():
		var node_id: String = str(node_id_value)
		var matches_search := not has_search or search_match_ids.has(node_id)
		var related := active_focus == "" or node_id == active_focus or _node_is_connected_to_focus(node_id, active_focus)
		var selected := active_focus != "" and node_id == active_focus
		var accented := (active_focus != "" and related and not selected) or (has_search and matches_search and not selected)
		var disabled := (active_focus != "" and not related) or (has_search and not matches_search and not selected)
		node_visual_states[node_id] = _make_node_visual_state(selected, accented, disabled)

func _make_node_visual_state(selected: bool = false, accented: bool = false, disabled: bool = false) -> Dictionary:
	return {
		"selected": selected,
		"accented": accented,
		"disabled": disabled
	}

func _node_is_connected_to_focus(node_id: String, focus_node_id: String) -> bool:
	if focus_node_id == "":
		return false
	for raw_edge in visible_edges:
		if raw_edge is not Dictionary:
			continue
		var edge: Dictionary = raw_edge as Dictionary
		if str(edge.get("from", "")) == focus_node_id and str(edge.get("to", "")) == node_id:
			return true
		if str(edge.get("to", "")) == focus_node_id and str(edge.get("from", "")) == node_id:
			return true
	return false

func _is_edge_highlighted(edge: Dictionary) -> bool:
	var active_focus := _active_focus_node_id()
	if active_focus == "":
		return false
	return str(edge.get("from", "")) == active_focus or str(edge.get("to", "")) == active_focus

func _active_focus_node_id() -> String:
	return locked_node_id if locked_node_id != "" else hovered_node_id

func _get_all_edge_types() -> Array[String]:
	var edge_types: Array[String] = []
	for raw_edge in graph.get("edges", []):
		if raw_edge is not Dictionary:
			continue
		var edge_type: String = str((raw_edge as Dictionary).get("type", ""))
		if edge_type != "" and not edge_types.has(edge_type):
			edge_types.append(edge_type)
	edge_types.sort_custom(func(a, b): return _edge_type_order(str(a)) < _edge_type_order(str(b)))
	return edge_types

func _has_search_filter() -> bool:
	return search_text != ""

func _node_matches_search(node: Dictionary, query: String) -> bool:
	if query == "":
		return true
	var fields: Array[String] = [
		str(node.get("id", "")),
		str(node.get("title", "")),
		str(node.get("summary", "")),
		str(node.get("description", "")),
		str(node.get("card_type_label", "")),
		str(node.get("owner_role_label", "")),
		str(node.get("package_id", "")),
		str(node.get("requires_text", "")),
		str(node.get("logic_text", ""))
	]
	return "\n".join(fields).to_lower().contains(query)

func _edge_type_order(edge_type: String) -> int:
	var index := EDGE_TYPE_DRAW_ORDER.find(edge_type)
	return index if index >= 0 else EDGE_TYPE_DRAW_ORDER.size()

func _edge_type_offset(edge_type: String) -> float:
	match edge_type:
		"progression":
			return -EDGE_PORT_GAP
		"mastery":
			return EDGE_PORT_GAP
		"investment":
			return -EDGE_PORT_GAP * 1.7
		"edge_unlock":
			return EDGE_PORT_GAP * 1.7
		"state_logic":
			return EDGE_PORT_GAP * 2.4
		"bridge_edge", "relay_edge", "mirror_edge":
			return -EDGE_PORT_GAP * 2.4
	return 0.0

func _route_offset_for(edge_type: String, route_index: int) -> float:
	var sign := -1.0 if route_index % 2 == 0 else 1.0
	var magnitude := float(int(route_index / 2) + 1) * EDGE_BUS_GAP
	var base := _edge_type_offset(edge_type) * 0.75
	return base + sign * magnitude

func _group_key(layer_id: int, lane_id: String) -> String:
	return "%d|%s" % [layer_id, lane_id]

func _lane_group_key(layer_id: int, lane_id: String) -> String:
	return "%d|%s" % [layer_id, lane_id]

func _graph_width() -> float:
	return max(MIN_GRAPH_WIDTH, graph_content_width)
