extends SceneTree

const SCENE_PATH := "res://assets/tile/battle_map_editor.tscn"
const ROCK_TEXTURES := [
	"res://assets/tile/Rock1.png",
	"res://assets/tile/Rock2.png",
	"res://assets/tile/Rock3.png",
	"res://assets/tile/Rock4.png"
]

func _initialize() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Cannot load " + SCENE_PATH)
		quit(1)
		return

	var root := packed.instantiate()
	var tile_set := _find_tile_set(root)
	if tile_set == null:
		push_error("No TileSet found in " + SCENE_PATH)
		quit(1)
		return

	_remove_invalid_unused_sources(root, tile_set)
	_add_rock_sources(tile_set)
	_assign_tile_set_to_layers(root, tile_set)

	var saved := PackedScene.new()
	saved.pack(root)
	ResourceSaver.save(saved, SCENE_PATH)
	print("Repaired battle map TileSet.")
	quit()

func _find_tile_set(root: Node) -> TileSet:
	for child in root.get_children():
		if child is TileMapLayer and (child as TileMapLayer).tile_set != null:
			return (child as TileMapLayer).tile_set
	return null

func _remove_invalid_unused_sources(root: Node, tile_set: TileSet) -> void:
	var used_source_ids := {}
	for child in root.get_children():
		if not child is TileMapLayer:
			continue
		var layer := child as TileMapLayer
		for cell in layer.get_used_cells():
			used_source_ids[layer.get_cell_source_id(cell)] = true

	for source_id in _get_tile_set_source_ids(tile_set):
		if used_source_ids.has(source_id):
			continue
		var source := tile_set.get_source(source_id)
		if source is TileSetAtlasSource and not _is_valid_atlas_source(source as TileSetAtlasSource):
			tile_set.remove_source(source_id)

func _is_valid_atlas_source(source: TileSetAtlasSource) -> bool:
	if source.texture == null:
		return false
	var region_size := source.texture_region_size
	if region_size.x <= 0 or region_size.y <= 0:
		return false
	for tile_id in source.get_tiles_count():
		var coords := source.get_tile_id(tile_id)
		var tile_end := Vector2i((coords.x + 1) * region_size.x, (coords.y + 1) * region_size.y)
		if tile_end.x > source.texture.get_width() or tile_end.y > source.texture.get_height():
			return false
	return true

func _add_rock_sources(tile_set: TileSet) -> void:
	for texture_path in ROCK_TEXTURES:
		if _has_texture_source(tile_set, texture_path):
			continue
		var texture := load(texture_path) as Texture2D
		if texture == null:
			continue
		var source := TileSetAtlasSource.new()
		source.texture = texture
		source.texture_region_size = Vector2i(texture.get_width(), texture.get_height())
		source.create_tile(Vector2i.ZERO)
		tile_set.add_source(source)

func _has_texture_source(tile_set: TileSet, texture_path: String) -> bool:
	var expected_texture := load(texture_path) as Texture2D
	if expected_texture == null:
		return false
	for source_id in _get_tile_set_source_ids(tile_set):
		var source := tile_set.get_source(source_id)
		if source is TileSetAtlasSource and (source as TileSetAtlasSource).texture == expected_texture:
			return true
	return false

func _assign_tile_set_to_layers(root: Node, tile_set: TileSet) -> void:
	for child in root.get_children():
		if child is TileMapLayer:
			(child as TileMapLayer).tile_set = tile_set

func _get_tile_set_source_ids(tile_set: TileSet) -> Array[int]:
	var ids: Array[int] = []
	for index in range(tile_set.get_source_count()):
		ids.append(tile_set.get_source_id(index))
	return ids
