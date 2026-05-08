extends SceneTree

const OUTPUT_SCENE := "res://assets/tile/battle_map_editor.tscn"
const OUTPUT_TILESET := "res://assets/tile/battle_tileset.tres"
const TILE_TEXTURE := "res://assets/tile/Tilemap_color1.png"
const REFERENCE_TEXTURE := "res://assets/maps/battle_map.png"
const GUIDE_SCRIPT := "res://scripts/tools/battle_map_editor_guide.gd"
const TILE_SIZE := Vector2i(32, 32)
const MAP_CELLS := Vector2i(100, 57)
const MAP_ORIGIN_CELL := Vector2i(-50, -28)

func _initialize() -> void:
	var tile_set := _create_tile_set()
	ResourceSaver.save(tile_set, OUTPUT_TILESET)

	var root := Node2D.new()
	root.name = "BattleMapEditor"

	var reference := Sprite2D.new()
	reference.name = "ReferenceImage"
	reference.texture = load(REFERENCE_TEXTURE)
	reference.centered = true
	reference.modulate = Color(1.0, 1.0, 1.0, 0.38)
	reference.z_index = -100
	root.add_child(reference)
	reference.owner = root

	var guide := Node2D.new()
	guide.name = "BorderGuide_3200x1800"
	guide.set_script(load(GUIDE_SCRIPT))
	guide.z_index = 100
	root.add_child(guide)
	guide.owner = root

	for layer_name in ["GroundLayer", "RoadLayer", "WaterLayer", "DecorLayer"]:
		var layer := TileMapLayer.new()
		layer.name = layer_name
		layer.tile_set = tile_set
		layer.z_index = _get_layer_z_index(layer_name)
		root.add_child(layer)
		layer.owner = root
		if layer_name == "GroundLayer":
			_fill_ground(layer)

	var scene := PackedScene.new()
	scene.pack(root)
	ResourceSaver.save(scene, OUTPUT_SCENE)
	print("Created ", OUTPUT_SCENE, " with ", OUTPUT_TILESET)
	quit()

func _create_tile_set() -> TileSet:
	var texture: Texture2D = load(TILE_TEXTURE)
	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_SIZE

	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = TILE_SIZE
	atlas.margins = Vector2i.ZERO
	atlas.separation = Vector2i.ZERO

	var columns: int = ceili(float(texture.get_width()) / float(TILE_SIZE.x))
	var rows: int = ceili(float(texture.get_height()) / float(TILE_SIZE.y))
	for y in range(rows):
		for x in range(columns):
			var coords := Vector2i(x, y)
			var rect := Rect2i(coords * TILE_SIZE, TILE_SIZE)
			if rect.position.x + rect.size.x <= texture.get_width() and rect.position.y + rect.size.y <= texture.get_height():
				atlas.create_tile(coords)

	tile_set.add_source(atlas, 0)
	return tile_set

func _fill_ground(layer: TileMapLayer) -> void:
	var grass_tile := Vector2i(0, 0)
	for y in range(MAP_CELLS.y):
		for x in range(MAP_CELLS.x):
			layer.set_cell(MAP_ORIGIN_CELL + Vector2i(x, y), 0, grass_tile)

func _get_layer_z_index(layer_name: String) -> int:
	match layer_name:
		"GroundLayer":
			return -40
		"RoadLayer":
			return -30
		"WaterLayer":
			return -20
		"DecorLayer":
			return -10
		_:
			return 0

