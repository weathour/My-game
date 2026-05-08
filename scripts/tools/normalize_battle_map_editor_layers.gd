extends SceneTree

const SCENE_PATH := "res://assets/tile/battle_map_editor.tscn"
const LAYER_ORDER := ["GroundLayer", "RoadLayer", "WaterLayer", "DecorLayer"]
const LAYER_Z_INDEX := {
	"GroundLayer": -40,
	"RoadLayer": -30,
	"WaterLayer": -20,
	"DecorLayer": 40
}

func _initialize() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Cannot load " + SCENE_PATH)
		quit(1)
		return

	var root := packed.instantiate()
	_promote_generic_ground_layer(root)
	var tile_set := _find_tile_set(root)

	for layer_name in LAYER_ORDER:
		var layer := root.get_node_or_null(layer_name) as TileMapLayer
		if layer == null:
			layer = TileMapLayer.new()
			layer.name = layer_name
			if tile_set != null:
				layer.tile_set = tile_set
			root.add_child(layer)
			layer.owner = root
		layer.z_index = int(LAYER_Z_INDEX.get(layer_name, 0))
		layer.y_sort_enabled = false

	_remove_duplicate_generic_layers(root)

	root.move_child(root.get_node("GroundLayer"), _get_layer_insert_index(root))
	root.move_child(root.get_node("RoadLayer"), _get_layer_insert_index(root) + 1)
	root.move_child(root.get_node("WaterLayer"), _get_layer_insert_index(root) + 2)
	root.move_child(root.get_node("DecorLayer"), _get_layer_insert_index(root) + 3)

	var normalized := PackedScene.new()
	normalized.pack(root)
	ResourceSaver.save(normalized, SCENE_PATH)
	print("Normalized battle map editor layers.")
	quit()

func _promote_generic_ground_layer(root: Node) -> void:
	var generic_layers := _find_layers(root, "TileMapLayer")
	if generic_layers.is_empty():
		return

	var source := generic_layers[0] as TileMapLayer
	var existing_ground := root.get_node_or_null("GroundLayer") as TileMapLayer
	if existing_ground != null and existing_ground != source:
		root.remove_child(existing_ground)
		existing_ground.free()

	source.name = "GroundLayer"
	source.z_index = int(LAYER_Z_INDEX["GroundLayer"])
	source.y_sort_enabled = false
	source.owner = root

func _remove_duplicate_generic_layers(root: Node) -> void:
	var generic_layers := _find_layers(root, "TileMapLayer")
	for layer in generic_layers:
		if layer == null:
			continue
		root.remove_child(layer)
		layer.free()

func _find_tile_set(root: Node) -> TileSet:
	for child in root.get_children():
		if child is TileMapLayer and (child as TileMapLayer).tile_set != null:
			return (child as TileMapLayer).tile_set
	return null

func _find_layers(root: Node, layer_name: String) -> Array[TileMapLayer]:
	var layers: Array[TileMapLayer] = []
	for child in root.get_children():
		if child is TileMapLayer and child.name == layer_name:
			layers.append(child as TileMapLayer)
	return layers

func _get_layer_insert_index(root: Node) -> int:
	for i in range(root.get_child_count()):
		if root.get_child(i) is TileMapLayer:
			return i
	return root.get_child_count()
