extends Control
signal province_selected(id: String)
## Two map scales; source bounds are geographic hints, never campaign logic.
const STYLE := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const TERRAIN := preload("res://assets/ui/chronicle/baimen-terrain.png")
const WORLD_RELIEF := preload("res://assets/ui/chronicle/world-relief.png")
const LOCATIONS := {
	"司隶":Vector2(109.7,35.1), "豫州":Vector2(115.1,33.6), "兖州":Vector2(115.7,35.3),
	"徐州":Vector2(118.7,34.3), "青州":Vector2(120.0,36.8), "冀州":Vector2(115.8,37.6),
	"幽州":Vector2(119.4,41.3), "并州":Vector2(113.1,40.3), "凉州":Vector2(102.7,36.8),
	"益州":Vector2(104.0,29.7), "荆州":Vector2(111.8,29.7), "扬州":Vector2(118.1,29.5),
	"交州":Vector2(108.5,22.7)
}
const ROUTE_POSITIONS := [
	[Vector2(.23,.83),Vector2(.37,.66),Vector2(.51,.55),Vector2(.65,.34),Vector2(.80,.19)],
	[Vector2(.28,.39),Vector2(.28,.73),Vector2(.46,.57),Vector2(.61,.41),Vector2(.66,.66),Vector2(.83,.46),Vector2(.85,.18)],
	[Vector2(.22,.78),Vector2(.38,.48),Vector2(.44,.83),Vector2(.58,.60),Vector2(.74,.40),Vector2(.84,.19)],
	[Vector2(.24,.80),Vector2(.37,.60),Vector2(.50,.39),Vector2(.63,.55),Vector2(.78,.76),Vector2(.85,.24)],
	[Vector2(.19,.77),Vector2(.32,.47),Vector2(.38,.86),Vector2(.48,.65),Vector2(.61,.48),Vector2(.69,.73),Vector2(.79,.46),Vector2(.88,.19)],
	[Vector2(.27,.78),Vector2(.46,.56),Vector2(.69,.37),Vector2(.84,.19)]
]
var mode := "world"
var selected := "徐州"
var segment := 0
var session: RefCounted
var land: Array = []
var provinces: Array = []
var positions: Dictionary = {}
var visible_nodes: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if mode == "world" else Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	provinces = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/provinces.json"))
	var geography: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/land.json"))
	for feature in geography.features:
		if feature.geometry.type == "Polygon": land.append(feature.geometry.coordinates[0])
		else:
			for polygon in feature.geometry.coordinates: land.append(polygon[0])
	resized.connect(queue_redraw)

func project(point: Vector2) -> Vector2:
	return Vector2((point.x - 96) / 30.0 * (size.x - 290 if mode == "world" else size.x), (45 - point.y) / 26.0 * size.y)

func province_position(id: String) -> Vector2:
	return project(LOCATIONS[id])

func route_positions() -> Dictionary:
	var result := {}
	var index := 0
	for id in session.nodes:
		if int(session.nodes[id].segment) == segment:
			if visible_nodes.is_empty() or id in visible_nodes: result[id] = route_position(index)
			index += 1
	return result

func route_position(index: int) -> Vector2:
	var point: Vector2 = ROUTE_POSITIONS[segment][index]
	if session.data.owned.has("F11"): point.x = maxf(.31, point.x)
	return point * size

func _gui_input(event: InputEvent) -> void:
	if mode != "world" or not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed: return
	for province in provinces:
		var polygon := PackedVector2Array()
		for point in province.ring: polygon.append(project(Vector2(point[0],point[1])))
		if Geometry2D.is_point_in_polygon(event.position, polygon):
			province_selected.emit(province.name)
			accept_event()
			return

func _draw() -> void:
	if mode == "world": draw_world()
	else: draw_route()

func draw_world() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("657b7d"))
	for ring in land:
		var polygon := PackedVector2Array()
		var uv := PackedVector2Array()
		for point in ring:
			var at := project(Vector2(point[0], point[1]))
			polygon.append(at)
			uv.append(at / size)
		if polygon.size() >= 3:
			draw_polygon(polygon, PackedColorArray([Color("dadacb")]), uv, WORLD_RELIEF)
			draw_polyline(polygon, Color("aaa98d"), 1.0, true)
	for province in provinces:
		var polygon := PackedVector2Array()
		for point in province.ring: polygon.append(project(Vector2(point[0], point[1])))
		var fill := Color("aaa68b40") if province.name != selected else Color("a9b585a0")
		draw_colored_polygon(polygon, fill)
		draw_polyline(polygon, Color("ded9bf") if province.name == selected else Color("6c6e5d"), 2 if province.name == selected else 1, true)
	draw_string(STYLE.FONT.get_heading_font(), Vector2(size.x*.87,size.y*.63), "东 海", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("d1d5cb"))

func draw_route() -> void:
	draw_texture_rect(TERRAIN, Rect2(Vector2.ZERO, size), false, Color("c4c8b5"))
	if session == null: return
	positions = route_positions()
	for id in positions:
		for next in session.nodes[id].next:
			if not positions.has(next): continue
			var done: bool = id in session.data.completed and next in session.data.completed
			var active: bool = (id in session.data.completed and next in session.data.available) or id == selected
			var color := STYLE.RED if done or active else Color("646a5b")
			draw_line(positions[id], positions[next], Color("b9b5a0"), 4, true)
			draw_line(positions[id], positions[next], color, 2, true)
