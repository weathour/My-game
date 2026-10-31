extends Control
signal province_selected(id: String)
## World inspection map; geographic bounds never define campaign logic.
const STYLE := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const WORLD_RELIEF := preload("res://assets/ui/chronicle/world-relief.png")
const LOCATIONS := {
	"司隶":Vector2(109.7,35.1), "豫州":Vector2(115.1,33.6), "兖州":Vector2(115.7,35.3),
	"徐州":Vector2(118.7,34.3), "青州":Vector2(120.0,36.8), "冀州":Vector2(115.8,37.6),
	"幽州":Vector2(119.4,41.3), "并州":Vector2(113.1,40.3), "凉州":Vector2(102.7,36.8),
	"益州":Vector2(104.0,29.7), "荆州":Vector2(111.8,29.7), "扬州":Vector2(118.1,29.5),
	"交州":Vector2(108.5,22.7)
}
var selected := "徐州"
var land: Array = []
var provinces: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
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
	return Vector2((point.x - 96) / 30.0 * size.x, (45 - point.y) / 26.0 * size.y)

func province_position(id: String) -> Vector2:
	return project(LOCATIONS[id])

func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed: return
	for province in provinces:
		var polygon := PackedVector2Array()
		for point in province.ring: polygon.append(project(Vector2(point[0],point[1])))
		if Geometry2D.is_point_in_polygon(event.position, polygon):
			province_selected.emit(province.name)
			accept_event()
			return

func _draw() -> void:
	draw_world()

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
