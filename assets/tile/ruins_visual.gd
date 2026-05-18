@tool
extends Node2D

const TILE_DIR := "res://assets/tile"
const TEX_PREFIXES := {
	"pillar": "01_",
	"wall": "02_",
	"altar": "03_",
	"rubble": "04_",
	"bush": "05_",
	"paving": "06_",
	"base": "07_",
	"flower": "08_",
	"tree_a": "generated-image-2",
	"tree_b": "generated-image-3",
}

var textures: Dictionary = {}


func _ready() -> void:
	z_index = 12
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	textures.clear()
	_load_textures()

	_build_outer_ruins()
	_build_center_altar()
	_build_broken_floor()
	_build_rubble()
	_build_nature()
	_build_edge_depth()


func _load_textures() -> void:
	var files := DirAccess.get_files_at(TILE_DIR)
	for key in TEX_PREFIXES.keys():
		var prefix: String = TEX_PREFIXES[key]
		textures[key] = null
		for file_name in files:
			if not file_name.ends_with(".png"):
				continue
			if file_name.begins_with(prefix):
				textures[key] = load("%s/%s" % [TILE_DIR, file_name])
				break


func _add(kind: String, sprite_position: Vector2, scale_value: float = 1.0, sprite_rotation: float = 0.0, tint: Color = Color.WHITE) -> void:
	var texture: Texture2D = textures.get(kind, null)
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = "%s_%03d" % [kind, get_child_count()]
	sprite.texture = texture
	sprite.position = sprite_position
	sprite.scale = Vector2.ONE * scale_value
	sprite.rotation = sprite_rotation
	sprite.modulate = tint
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)


func _build_outer_ruins() -> void:
	_add_wall_run(Vector2(-1240, -720), Vector2(72, 0), 8, [3])
	_add_wall_run(Vector2(470, -720), Vector2(72, 0), 9, [4])
	_add_wall_run(Vector2(-1240, 720), Vector2(72, 0), 8, [4])
	_add_wall_run(Vector2(470, 720), Vector2(72, 0), 9, [3])
	_add_wall_run(Vector2(-1450, -560), Vector2(0, 72), 6, [3])
	_add_wall_run(Vector2(-1450, 270), Vector2(0, 72), 6, [2])
	_add_wall_run(Vector2(1450, -560), Vector2(0, 72), 6, [2])
	_add_wall_run(Vector2(1450, 270), Vector2(0, 72), 6, [3])

	var pillar_positions := [
		Vector2(-1360, -720), Vector2(-700, -720), Vector2(380, -720), Vector2(1260, -720),
		Vector2(-1360, 720), Vector2(-700, 720), Vector2(380, 720), Vector2(1260, 720),
		Vector2(-1450, -650), Vector2(-1450, -100), Vector2(-1450, 570),
		Vector2(1450, -650), Vector2(1450, -100), Vector2(1450, 570),
	]
	for pillar_position in pillar_positions:
		_add_pillar(pillar_position)


func _add_wall_run(start: Vector2, step: Vector2, count: int, gaps: Array[int]) -> void:
	for index in range(count):
		if gaps.has(index):
			continue
		var wall_position := start + step * float(index)
		_add("wall", wall_position, 1.0, step.angle())
		if index % 5 == 0:
			_add("base", wall_position + Vector2(0, 34), 0.78, 0.0, Color(1, 1, 1, 0.92))


func _add_pillar(pillar_position: Vector2) -> void:
	_add("pillar", pillar_position, 1.14)
	_add("base", pillar_position + Vector2(0, 44), 0.95, 0.0, Color(0.88, 0.95, 0.78, 0.85))


func _build_center_altar() -> void:
	_add("altar", Vector2.ZERO, 8.0)
	var ring_radii := [210.0, 300.0, 390.0]
	for ring_index in range(ring_radii.size()):
		var pieces := 12 + ring_index * 4
		for index in range(pieces):
			if (index + ring_index) % 5 == 0:
				continue
			var angle := TAU * float(index) / float(pieces)
			var ring_position := Vector2(cos(angle), sin(angle)) * float(ring_radii[ring_index])
			_add("paving", ring_position, 0.78, angle + PI * 0.5, Color(0.9, 0.98, 0.76, 0.92))


func _build_broken_floor() -> void:
	_add_paving_patch(Vector2(0, -470), [Vector2(0, 0), Vector2(0, 1), Vector2(0, 2), Vector2(-1, 1), Vector2(1, 2), Vector2(0, 3), Vector2(-1, 4)], 5)
	_add_paving_patch(Vector2(0, 380), [Vector2(0, 0), Vector2(0, 1), Vector2(0, 2), Vector2(1, 1), Vector2(-1, 2), Vector2(0, 3), Vector2(1, 4)], 11)
	_add_paving_patch(Vector2(-470, 0), [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(1, -1), Vector2(3, 1), Vector2(4, 0), Vector2(5, -1)], 17)
	_add_paving_patch(Vector2(320, 0), [Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(2, 1), Vector2(3, -1), Vector2(4, 0), Vector2(5, 1)], 23)

	var patches := [
		Vector2(-760, -330), Vector2(-560, 230), Vector2(-260, -520), Vector2(520, -360), Vector2(700, 180),
		Vector2(-960, 400), Vector2(1010, 370), Vector2(-1110, -120), Vector2(1080, -160), Vector2(0, 610),
		Vector2(-300, 430), Vector2(360, 470), Vector2(780, -580), Vector2(-820, -560),
	]
	for index in range(patches.size()):
		var cells := [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 1), Vector2(1, 1)]
		cells.append(Vector2(2, 0) if index % 2 == 0 else Vector2(-2, 0))
		_add_paving_patch(patches[index], cells, index * 9)


func _add_paving_patch(center: Vector2, cells: Array, seed: int) -> void:
	var index := 0
	for cell_value in cells:
		var cell: Vector2 = cell_value
		var jitter := Vector2(sin(float(index + seed) * 2.17) * 5.0, cos(float(index + seed) * 1.61) * 4.0)
		_add("paving", center + cell * 62.0 + jitter, 0.86 + 0.08 * sin(float(index) * 0.7), 0.04 * sin(float(index + 3)))
		index += 1


func _build_rubble() -> void:
	for index in range(20):
		var rubble_x := -1260.0 + float((index * 311) % 2520)
		var rubble_y := -620.0 + float((index * 173) % 1240)
		if abs(rubble_x) < 340.0 and abs(rubble_y) < 300.0:
			rubble_x += 420.0
		_add_rubble_cluster(Vector2(rubble_x, rubble_y), 3 + (index % 3), 58.0 + float(index % 4) * 10.0, index * 13)


func _add_rubble_cluster(center: Vector2, count: int, radius: float, seed: int) -> void:
	for index in range(count):
		var angle := float(seed + index * 37) * 0.73
		var distance: float = radius * (0.28 + 0.72 * abs(sin(float(seed + index) * 1.91)))
		var kind := "rubble" if index % 3 != 0 else "base"
		_add(kind, center + Vector2(cos(angle), sin(angle)) * distance, 0.58 + 0.3 * abs(sin(angle)), angle * 0.25)


func _build_nature() -> void:
	var cluster_positions := [
		Vector2(-1300, -620), Vector2(1280, -610), Vector2(-1300, 650), Vector2(1280, 640),
		Vector2(-1040, -690), Vector2(980, -710), Vector2(-1080, 720), Vector2(930, 710),
		Vector2(-1470, 60), Vector2(1480, 40),
	]
	for cluster_position in cluster_positions:
		_add_nature_cluster(cluster_position, 8, 95.0, int(cluster_position.x + cluster_position.y))

	for index in range(45):
		var plant_x := -1300.0 + float((index * 197) % 2600)
		var plant_y := -700.0 + float((index * 283) % 1400)
		if abs(plant_x) < 360.0 and abs(plant_y) < 280.0:
			continue
		var kind := "flower" if index % 2 == 0 else "bush"
		_add(kind, Vector2(plant_x, plant_y), 0.48 + 0.16 * abs(sin(float(index))), float(index) * 0.37, Color(1, 1, 1, 0.72))


func _add_nature_cluster(center: Vector2, count: int, radius: float, seed: int) -> void:
	for index in range(count):
		var angle := float(seed + index * 19) * 0.67
		var distance: float = radius * (0.25 + 0.75 * abs(cos(float(seed + index) * 1.23)))
		var plant_position: Vector2 = center + Vector2(cos(angle), sin(angle)) * distance
		if index % 5 == 0:
			_add("tree_a" if index % 10 == 0 else "tree_b", plant_position, 0.72 + 0.12 * sin(angle))
		elif index % 2 == 0:
			_add("bush", plant_position, 0.76 + 0.18 * abs(sin(angle)), angle * 0.15)
		else:
			_add("flower", plant_position, 0.7 + 0.16 * abs(cos(angle)), angle)


func _build_edge_depth() -> void:
	var edge_positions := [
		Vector2(-1560, -790), Vector2(-1500, 790), Vector2(1540, -760),
		Vector2(1500, 780), Vector2(-60, -830), Vector2(40, 820),
	]
	for edge_position in edge_positions:
		_add("tree_b", edge_position, 1.05, 0.0, Color(0.45, 0.62, 0.35, 0.55))
