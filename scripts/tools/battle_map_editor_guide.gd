@tool
extends Node2D

@export var bounds: Rect2 = Rect2(Vector2(-1600.0, -900.0), Vector2(3200.0, 1800.0)):
	set(value):
		bounds = value
		queue_redraw()
@export var line_color: Color = Color(1.0, 0.85, 0.15, 0.92):
	set(value):
		line_color = value
		queue_redraw()
@export var fill_color: Color = Color(1.0, 0.85, 0.15, 0.06):
	set(value):
		fill_color = value
		queue_redraw()
@export var line_width: float = 4.0:
	set(value):
		line_width = value
		queue_redraw()
@export var center_on_tile_layers: bool = true:
	set(value):
		center_on_tile_layers = value
		queue_redraw()

func _ready() -> void:
	if Engine.is_editor_hint():
		set_meta("_edit_lock_", true)
		set_meta("_edit_group_", true)

func _draw() -> void:
	var draw_bounds := _get_draw_bounds()
	draw_rect(draw_bounds, fill_color, true)
	draw_rect(draw_bounds, line_color, false, line_width)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and center_on_tile_layers:
		queue_redraw()

func _get_draw_bounds() -> Rect2:
	if not center_on_tile_layers:
		return bounds
	var painted_bounds := _get_sibling_tile_bounds()
	if painted_bounds.size.x <= 0.0 or painted_bounds.size.y <= 0.0:
		return bounds
	var centered_position := painted_bounds.get_center() - bounds.size * 0.5
	return Rect2(centered_position, bounds.size)

func _get_sibling_tile_bounds() -> Rect2:
	var parent_node := get_parent()
	if parent_node == null:
		return Rect2()
	var merged := Rect2()
	var has_bounds := false
	for child in parent_node.get_children():
		if not child is TileMapLayer:
			continue
		var layer_bounds := _get_tile_layer_bounds(child as TileMapLayer)
		if layer_bounds.size.x <= 0.0 or layer_bounds.size.y <= 0.0:
			continue
		if has_bounds:
			merged = merged.merge(layer_bounds)
		else:
			merged = layer_bounds
			has_bounds = true
	return merged if has_bounds else Rect2()

func _get_tile_layer_bounds(layer: TileMapLayer) -> Rect2:
	var used_rect := layer.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return Rect2()
	var tile_size := Vector2(layer.tile_set.tile_size) if layer.tile_set != null else Vector2(16.0, 16.0)
	var local_top_left := layer.map_to_local(used_rect.position) - tile_size * 0.5
	var local_bottom_right := layer.map_to_local(used_rect.position + used_rect.size - Vector2i.ONE) + tile_size * 0.5
	var global_top_left := layer.to_global(local_top_left)
	var global_bottom_right := layer.to_global(local_bottom_right)
	return Rect2(global_top_left, global_bottom_right - global_top_left)
