extends Control
## Read-only campaign navigation. Only the shell's explicit action may advance play.
signal node_selected(id: String)
signal offset_changed(value: float)

const STYLE := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const TERRAIN := preload("res://assets/ui/chronicle/baimen-terrain.png")
const SEGMENTS := ["城外来客", "夺寨聚众", "官印易主", "吕家风波", "协力守城", "白门终战"]
const ICONS := {
	"battle":preload("res://assets/ui/chronicle/route-icons/battle.svg"),
	"elite":preload("res://assets/ui/chronicle/route-icons/elite.svg"),
	"spring":preload("res://assets/ui/chronicle/route-icons/spring.svg"),
	"event":preload("res://assets/ui/chronicle/route-icons/event.svg"),
	"boss":preload("res://assets/ui/chronicle/route-icons/boss.svg")
}
const COLUMN := 184.0
const LEFT := 98.0
const MARKER_SIZE := 52.0
const LANES := {"B04":-1, "B05":1, "B06":-1, "B08":-1, "B09":1,
	"B10":-1, "B12":-1, "B13":-1, "B14":1, "B17":-1}

var session: RefCounted
var selected: String = ""
var scroll_offset: float = -1.0
var positions: Dictionary = {}
var markers: Dictionary = {}
var _order: Array[String] = []
var _segments: Array[Vector2] = []
var _canvas_width := 0.0
var _pointer_active := false
var _dragged := false
var _press_position := Vector2.ZERO
var _press_offset := 0.0
var _press_id := ""
var _hovered := ""
var _focused := ""
var _initialized := false
var _keyboard_focus_move := false
var _initial_layout_scheduled := false
var preserve_left_overlay := false
var _previous_view_size := Vector2.ZERO

class RouteMarker extends Button:
	var route: Control
	var node_id: String

	func _draw() -> void:
		if is_instance_valid(route): route.draw_marker(self, node_id)

	func _gui_input(event: InputEvent) -> void:
		if is_instance_valid(route): route.marker_input(self, node_id, event)

static func state_for(state: RefCounted, id: String) -> String:
	if state == null or not state.nodes.has(id): return "locked"
	var data: Dictionary = state.data
	if id in data.get("completed", []): return "completed"
	var reward: Dictionary = data.get("pending", {})
	var reward_node := str(reward.get("node", ""))
	if reward_node == id: return "reward"
	var available: Array = data.get("available", [])
	if reward.is_empty() and id in available:
		if str(state.nodes[id].kind) in ["battle", "elite", "boss"] and state.has_method("battle_available") and not state.battle_available(id):
			return "unavailable"
		return "available"
	var frontier: Array = available.duplicate()
	# A won branch is already decided while its reward is pending. Its siblings
	# close immediately, and its successors remain future until reward claim.
	# Older drafts may already have advanced: keep their existing future frontier.
	if not reward.is_empty() and reward_node in available and reward_node not in data.get("completed", []) and state.nodes.has(reward_node):
		frontier = state.nodes[reward_node].get("next", []).duplicate()
	var visited := {}
	while not frontier.is_empty():
		var at := str(frontier.pop_back())
		if visited.has(at) or not state.nodes.has(at): continue
		visited[at] = true
		if at == id: return "locked"
		for successor in state.nodes[at].get("next", []): frontier.append(successor)
	return "skipped"

static func state_label(key: String) -> String:
	return str({"completed":"已通过", "available":"可前往", "locked":"尚未解锁",
		"skipped":"未走支路", "reward":"待选奖励", "unavailable":"暂未开放"}.get(key, "尚未解锁"))

static func kind_label(kind: String) -> String:
	return str({"event":"剧情", "battle":"战斗", "elite":"精英", "spring":"泉水", "boss":"终战"}.get(kind, "节点"))

static func kind_icon(kind: String) -> Texture2D:
	return ICONS.get(kind, ICONS.event) as Texture2D

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	custom_minimum_size = Vector2(220, 310)
	resized.connect(_layout)
	if session == null: return
	for id in session.nodes:
		_order.append(str(id))
		var marker := RouteMarker.new()
		marker.route = self
		marker.node_id = str(id)
		marker.name = "node_" + str(id)
		marker.text = ""
		marker.custom_minimum_size = Vector2.ONE * MARKER_SIZE
		marker.size = Vector2.ONE * MARKER_SIZE
		marker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		marker.focus_mode = Control.FOCUS_ALL
		marker.tooltip_text = _node_tooltip(str(id))
		marker.accessibility_name = "%s，%s，%s" % [session.nodes[id].name, kind_label(session.nodes[id].kind), state_label(state_for(session, id))]
		for style in ["normal", "hover", "pressed", "focus", "disabled"]:
			marker.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		marker.pressed.connect(_select_node.bind(str(id)))
		marker.mouse_entered.connect(_set_hover.bind(str(id)))
		marker.mouse_exited.connect(_clear_hover.bind(str(id)))
		marker.focus_entered.connect(_on_marker_focus.bind(str(id)))
		marker.focus_exited.connect(_on_marker_blur.bind(str(id)))
		add_child(marker)
		markers[id] = marker
	_build_topology()
	for index in _order.size():
		var marker: Button = markers[_order[index]]
		if index > 0:
			marker.focus_previous = marker.get_path_to(markers[_order[index - 1]])
			marker.focus_neighbor_left = marker.focus_previous
		if index + 1 < _order.size():
			marker.focus_next = marker.get_path_to(markers[_order[index + 1]])
			marker.focus_neighbor_right = marker.focus_next
	_layout()
	call_deferred("_layout")

func _build_topology() -> void:
	var columns := {}
	for id in _order: columns[id] = 0
	# Relax every edge, independently of dictionary order. The content graph is a DAG.
	for iteration in _order.size():
		var changed := false
		for id in _order:
			for successor in session.nodes[id].next:
				if columns.has(successor) and int(columns[successor]) < int(columns[id]) + 1:
					columns[successor] = int(columns[id]) + 1
					changed = true
		if not changed: break
	_segments.clear()
	for index in SEGMENTS.size(): _segments.append(Vector2(INF, -INF))
	for id in _order:
		var x := LEFT + float(columns[id]) * COLUMN
		positions[id] = Vector2(x, 0)
		var segment: int = int(session.nodes[id].segment)
		_segments[segment].x = minf(_segments[segment].x, x)
		_segments[segment].y = maxf(_segments[segment].y, x)
		_canvas_width = maxf(_canvas_width, x + LEFT)

func _layout() -> void:
	if not is_inside_tree(): return
	if size.x < 64 or size.y < 150: return
	if positions.is_empty():
		queue_redraw()
		return
	var visible_selection := false
	if preserve_left_overlay and _previous_view_size.x > 0 and positions.has(selected):
		var previous_x: float = positions[selected].x - maxf(0, scroll_offset)
		visible_selection = previous_x >= 0 and previous_x <= _previous_view_size.x
	var changed_view_size := _previous_view_size != size
	_previous_view_size = size
	var center := (68.0 + size.y - _footer_height() - 70.0) * 0.5
	var spread := clampf((size.y - 170.0) * 0.31, 55.0, 105.0)
	for id in positions:
		positions[id].y = center + float(LANES.get(id, 0)) * spread
	if scroll_offset < 0:
		# Containers first assign their minimum width, then distribute the final
		# viewport. Keep the auto-location request until that layout has settled.
		if not _initial_layout_scheduled:
			_initial_layout_scheduled = true
			_initialize_view.call_deferred()
		_position_markers()
		queue_redraw()
		return
	var before := scroll_offset
	scroll_offset = clampf(scroll_offset, 0, _max_offset())
	if changed_view_size and visible_selection: _ensure_visible(selected)
	_position_markers()
	queue_redraw()
	if not _initialized or before != scroll_offset:
		_initialized = true
		offset_changed.emit(scroll_offset)

func _initialize_view() -> void:
	if not is_inside_tree(): return
	var tree := get_tree()
	if tree == null: return
	await tree.process_frame
	await tree.process_frame
	_initial_layout_scheduled = false
	if not is_inside_tree() or scroll_offset >= 0: return
	if size.x < 64 or size.y < 150: return
	var target := selected if positions.has(selected) else str(session.data.get("current", ""))
	scroll_offset = maxf(0, positions[target].x - size.x * .36) if positions.has(target) else 0.0
	_layout()

func _position_markers() -> void:
	for id in markers:
		var marker: Button = markers[id]
		marker.position = positions[id] - Vector2(maxf(0, scroll_offset) + MARKER_SIZE * .5, MARKER_SIZE * .5)
		marker.queue_redraw()

func _max_offset() -> float:
	return maxf(0, _canvas_width - size.x)

func get_scroll_offset() -> float:
	return maxf(0, scroll_offset)

func _set_offset(value: float) -> void:
	var clamped := clampf(value, 0, _max_offset())
	if is_equal_approx(clamped, scroll_offset): return
	scroll_offset = clamped
	_position_markers()
	queue_redraw()
	offset_changed.emit(scroll_offset)

func focus_node(id: String) -> void:
	if not positions.has(id): return
	_ensure_visible(id)
	if markers.has(id): markers[id].grab_focus()

func focus_segment(index: int) -> void:
	if index < 0 or index >= _segments.size(): return
	_set_offset(_segments[index].x - 80.0)

func _ensure_visible(id: String) -> void:
	if not positions.has(id): return
	var x: float = positions[id].x
	# The campaign's lower-left description overlays part of the map. Keep
	# keyboard-focused lower-lane markers and their names beyond that paper box.
	var left_margin := 90.0
	var lower_column: bool = positions[id].y + 70.0 > size.y * .72
	if preserve_left_overlay:
		for frontier in session.data.get("available", []):
			if positions.has(frontier) and is_equal_approx(positions[frontier].x, x) and positions[frontier].y + 70.0 > size.y * .72:
				lower_column = true
		if lower_column: left_margin = maxf(left_margin, size.x * .36)
	if x - scroll_offset < left_margin: _set_offset(x - left_margin)
	var right_edge := size.x * .71 - 48.0 if preserve_left_overlay else size.x - 90.0
	if x - scroll_offset > right_edge: _set_offset(x - right_edge)

func _node_tooltip(id: String) -> String:
	var node: Dictionary = session.nodes[id]
	var summary := str(node.get("map_summary", ""))
	if summary.is_empty(): summary = str(node.get("summary", ""))
	return "%s · %s · %s\n%s" % [node.name, kind_label(node.kind), state_label(state_for(session, id)), summary]

func _set_hover(id: String) -> void:
	_hovered = id
	queue_redraw()
	markers[id].queue_redraw()

func _clear_hover(id: String) -> void:
	if _hovered == id: _hovered = ""
	queue_redraw()
	markers[id].queue_redraw()

func _on_marker_focus(id: String) -> void:
	_focused = id
	if _keyboard_focus_move: _ensure_visible(id)
	queue_redraw()
	markers[id].queue_redraw()

func _on_marker_blur(id: String) -> void:
	if _focused == id: _focused = ""
	queue_redraw()
	markers[id].queue_redraw()

func marker_input(marker: Button, id: String, event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if _wheel(event):
			marker.accept_event()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			marker.accept_event()
			_begin_pointer(id, event.global_position)
	elif event is InputEventKey and event.pressed:
		if event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			marker.accept_event()
			var index := _order.find(id)
			var delta := -1 if event.keycode in [KEY_LEFT, KEY_UP] else 1
			focus_node(_order[clampi(index + delta, 0, _order.size() - 1)])

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if _wheel(event):
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			accept_event()
			_begin_pointer("", event.global_position)

func _wheel(event: InputEventMouseButton) -> bool:
	if not event.pressed: return false
	if event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT]:
		get_viewport().set_input_as_handled()
		_set_offset(scroll_offset + 128.0 * event.factor)
		return true
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT]:
		get_viewport().set_input_as_handled()
		_set_offset(scroll_offset - 128.0 * event.factor)
		return true
	return false

func _begin_pointer(id: String, at: Vector2) -> void:
	_pointer_active = true
	_dragged = false
	_press_position = at
	_press_offset = scroll_offset
	_press_id = id

func _input(event: InputEvent) -> void:
	# Focus restoration and mouse clicks must retain the panned view. Tab is the
	# one implicit focus transition that needs to reveal a newly focused marker.
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_keyboard_focus_move = true
	elif event is InputEventMouseButton and event.pressed:
		_keyboard_focus_move = false
	# Start only through GUI delivery, so a modal above the map keeps its input.
	# Once captured, release is handled even beyond the map or a node's touch area.
	if not _pointer_active: return
	if event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
		var delta: Vector2 = event.global_position - _press_position
		if delta.length() > 7.0: _dragged = true
		if _dragged: _set_offset(_press_offset - delta.x)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		get_viewport().set_input_as_handled()
		var id := _press_id
		var was_dragged := _dragged
		_pointer_active = false
		_press_id = ""
		for marker in markers.values(): marker.button_pressed = false
		if not was_dragged and markers.has(id) and markers[id].get_global_rect().has_point(event.global_position):
			markers[id].grab_focus()
			_select_node(id)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_pointer_active = false
		_press_id = ""

func _select_node(id: String) -> void:
	if _pointer_active: return
	# Enter can synchronously remove this page through the shell's signal handler.
	if is_inside_tree(): get_viewport().set_input_as_handled()
	selected = id
	for marker in markers.values(): marker.queue_redraw()
	offset_changed.emit(get_scroll_offset())
	node_selected.emit(id)

func _draw() -> void:
	if size.x <= 0 or size.y <= 0: return
	draw_rect(Rect2(Vector2.ZERO, size), STYLE.DARK)
	# Pan the relief slowly under the route, retaining geographic context.
	var tile_width := size.y * float(TERRAIN.get_width()) / float(TERRAIN.get_height())
	var x := -fmod(maxf(0, scroll_offset) * .22, tile_width)
	while x < size.x:
		draw_texture_rect(TERRAIN, Rect2(x, 0, tile_width, size.y), false, Color(.75, .80, .70, .56))
		x += tile_width
	draw_rect(Rect2(Vector2.ZERO, size), Color("10231a94"))
	if session == null: return
	_draw_segments()
	for id in positions:
		for successor in session.nodes[id].next:
			if positions.has(successor): _draw_edge(str(id), str(successor))
	_draw_footer()
	draw_rect(Rect2(Vector2.ZERO, size), STYLE.BORDER, false, 1.0)

func _footer_height() -> float:
	return 12.0

func _draw_segments() -> void:
	var compact := size.y < 390
	var font: Font = STYLE.FONT.get_heading_font()
	for index in _segments.size():
		var start := _segments[index].x - 66.0 - scroll_offset
		var end := _segments[index].y + 76.0 - scroll_offset
		if end < 0 or start > size.x: continue
		draw_line(Vector2(start, 18), Vector2(start, size.y - _footer_height() - 7), Color("b1a27836"), 1.0)
		draw_line(Vector2(start + 14, 36 if compact else 50), Vector2(end - 10, 36 if compact else 50), Color("aa926c70"), 1.0)
		draw_string(font, Vector2(start + 14, 28 if compact else 39), SEGMENTS[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 20 if compact else 23, STYLE.GOLD)

func _draw_edge(from: String, to: String) -> void:
	var a: Vector2 = positions[from] - Vector2(scroll_offset, 0)
	var b: Vector2 = positions[to] - Vector2(scroll_offset, 0)
	if maxf(a.x, b.x) < -40 or minf(a.x, b.x) > size.x + 40: return
	var first := state_for(session, from)
	var second := state_for(session, to)
	var completed := first == "completed" and second == "completed"
	var active := first == "completed" and second in ["available", "reward", "unavailable"]
	var skipped := first == "skipped" or second == "skipped"
	var color := Color("aaa786")
	if completed: color = STYLE.RED.lightened(.18)
	elif active: color = STYLE.GOLD
	elif skipped: color = Color("82877665")
	var direction := (b - a).normalized()
	a += direction * 25
	b -= direction * 29
	# A long shortcut follows a low bypass, keeping optional elite branches legible.
	var points := PackedVector2Array([a])
	if b.x - a.x > COLUMN * 1.45:
		var bypass := maxf(a.y, b.y) + 53.0
		points.append(Vector2(a.x + 65, a.y))
		points.append(Vector2(a.x + 65, bypass))
		points.append(Vector2(b.x - 65, bypass))
		points.append(Vector2(b.x - 65, b.y))
	points.append(b)
	if completed or active:
		draw_polyline(points, Color("0b1712dd"), 7.0, true)
		draw_polyline(points, color, 3.0 if active else 2.6, true)
	else:
		for index in points.size() - 1:
			_draw_dashes(points[index], points[index + 1], color, 1.5)
	var end_direction := (points[-1] - points[-2]).normalized()
	var perpendicular := Vector2(-end_direction.y, end_direction.x)
	draw_colored_polygon(PackedVector2Array([b, b - end_direction * 10 + perpendicular * 4, b - end_direction * 10 - perpendicular * 4]), color)

func _draw_dashes(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var length := a.distance_to(b)
	var direction := (b - a).normalized()
	var at := 0.0
	while at < length:
		draw_line(a + direction * at, a + direction * minf(at + 7.0, length), color, width, true)
		at += 13.0

func _draw_footer() -> void:
	var height := _footer_height()
	var top := size.y - height
	draw_rect(Rect2(0, top, size.x, height), Color("102018ee"))
	draw_line(Vector2(14, top), Vector2(size.x - 14, top), Color("a990626d"), 1)
	# An honest viewport-position indicator also makes the long horizontal map discoverable.
	var track := Rect2(14, size.y - 4, maxf(1, size.x - 28), 2)
	draw_rect(track, Color("4b5947"))
	var ratio := minf(1, size.x / maxf(1, _canvas_width))
	var thumb := maxf(18, track.size.x * ratio)
	var fraction := scroll_offset / _max_offset() if _max_offset() > 0 else 0.0
	draw_rect(Rect2(track.position + Vector2((track.size.x - thumb) * fraction, 0), Vector2(thumb, 2)), STYLE.GOLD)

func _fit_text(value: String, width: float, font_size: int, font: Font) -> String:
	if font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width: return value
	while value.length() > 1 and font.get_string_size(value + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		value = value.left(value.length() - 1)
	return value + "…"

func draw_marker(marker: Button, id: String) -> void:
	var state := state_for(session, id)
	var at := marker.size * .5
	var color := STYLE.MUTED
	if state == "completed": color = Color("c89474")
	elif state in ["available", "reward"]: color = STYLE.GOLD
	elif state == "unavailable": color = Color("cdab91")
	elif state == "skipped": color = Color("93998c")
	var highlighted := id == selected
	var hovered := id == _hovered or marker.has_focus()
	if highlighted: marker.draw_circle(at, 26, Color("60714c65"))
	marker.draw_circle(at, 20, Color("14271fee"))
	marker.draw_arc(at, 20, 0, TAU, 48, color, 2.0 if state in ["available", "reward"] else 1.2, true)
	if hovered or highlighted: marker.draw_arc(at, 25, 0, TAU, 48, STYLE.GOLD if hovered else STYLE.OLIVE.lightened(.4), 1.8, true)
	marker.draw_texture_rect(kind_icon(str(session.nodes[id].kind)), Rect2(at - Vector2.ONE * 16, Vector2.ONE * 32), false)
	if state == "completed":
		marker.draw_polyline(PackedVector2Array([at + Vector2(10, 14), at + Vector2(14, 18), at + Vector2(22, 9)]), STYLE.INK, 2.5, true)
	elif state == "locked":
		marker.draw_rect(Rect2(at + Vector2(12, 11), Vector2(9, 8)), Color("182a20"))
		marker.draw_rect(Rect2(at + Vector2(12, 11), Vector2(9, 8)), color, false, 1)
		marker.draw_arc(at + Vector2(16.5, 11), 3.0, PI, TAU, 10, color, 1, true)
	elif state == "skipped": marker.draw_line(at + Vector2(-16, 16), at + Vector2(16, -16), color, 1.3, true)
	elif state == "unavailable":
		marker.draw_line(at + Vector2(14, 11), at + Vector2(14, 20), color, 2)
		marker.draw_line(at + Vector2(20, 11), at + Vector2(20, 20), color, 2)
	elif state == "reward":
		marker.draw_circle(at + Vector2(17, -15), 7, STYLE.RED)
		marker.draw_string(STYLE.FONT.get_reading_font(), at + Vector2(13, -11), "赏", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, STYLE.INK)
	if id == str(session.data.get("current", "")):
		marker.draw_colored_polygon(PackedVector2Array([at + Vector2(-6, -35), at + Vector2(6, -35), at + Vector2(0, -27)]), STYLE.GOLD)
	var font: Font = STYLE.FONT.get_reading_font()
	var title := _fit_text(str(session.nodes[id].name), COLUMN - 14, 16, font)
	var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	# A thin ink backing preserves contrast over the relief without card-shaped controls.
	marker.draw_rect(Rect2(at.x - width * .5 - 5, 55, width + 10, 23), Color("12251de8"))
	marker.draw_string(font, Vector2(at.x - width * .5, 72), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, STYLE.INK if state != "skipped" else STYLE.MUTED)
	var caption := "%s · %s" % [kind_label(session.nodes[id].kind), state_label(state)]
	var caption_width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	marker.draw_rect(Rect2(at.x - caption_width * .5 - 4, 79, caption_width + 8, 19), Color("12251de8"))
	marker.draw_string(font, Vector2(at.x - caption_width * .5, 93), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

