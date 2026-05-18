extends Node2D

const ALTAR_SOURCE_ID := 7

func _ready() -> void:
	_remove_tile_altar()

func _remove_tile_altar() -> void:
	var stone_layer := get_node_or_null("stone") as TileMapLayer
	if stone_layer == null:
		return

	var altar_cells: Array[Vector2i] = []
	for cell in stone_layer.get_used_cells():
		if stone_layer.get_cell_source_id(cell) != ALTAR_SOURCE_ID:
			continue
		altar_cells.append(cell)

	if altar_cells.is_empty():
		return

	for cell in altar_cells:
		stone_layer.erase_cell(cell)
