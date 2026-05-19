extends RefCounted

const CELL_SIZE := 96.0

static var cached_frame: int = -1
static var cached_scene_id: int = -1
static var cached_grid: Dictionary = {}
static var active_cells: Array[Vector2i] = []


static func get_grid(scene: Node) -> Dictionary:
	if scene == null:
		return {}
	return _get_grid(scene)


static func get_neighbors(enemy: Node2D, query_radius: float) -> Array:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return []
	var scene := enemy.get_tree().current_scene
	if scene == null:
		return []
	var grid := _get_grid(scene)
	if grid.is_empty():
		return []
	var center_cell := _grid_cell(enemy.global_position)
	var cell_radius := int(ceil(max(1.0, query_radius) / CELL_SIZE))
	var candidates: Array = []
	for x in range(center_cell.x - cell_radius, center_cell.x + cell_radius + 1):
		for y in range(center_cell.y - cell_radius, center_cell.y + cell_radius + 1):
			var cell := Vector2i(x, y)
			if not grid.has(cell):
				continue
			candidates.append_array(grid[cell] as Array)
	return candidates


static func for_each_neighbor(enemy: Node2D, query_radius: float, callback: Callable) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return
	var scene: Node = enemy.get_tree().current_scene
	if scene == null:
		return
	var grid: Dictionary = _get_grid(scene)
	if grid.is_empty():
		return
	var center_cell: Vector2i = _grid_cell(enemy.global_position)
	var cell_radius: int = int(ceil(max(1.0, query_radius) / CELL_SIZE))
	for x in range(center_cell.x - cell_radius, center_cell.x + cell_radius + 1):
		for y in range(center_cell.y - cell_radius, center_cell.y + cell_radius + 1):
			var cell: Vector2i = Vector2i(x, y)
			if not grid.has(cell):
				continue
			for other in grid[cell] as Array:
				if not bool(callback.call(other)):
					return


static func compute_separation_velocity(enemy: Node2D, query_radius: float, contact_radius: float, max_processed: int = 8) -> Vector2:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return Vector2.ZERO
	var scene: Node = enemy.get_tree().current_scene
	if scene == null:
		return Vector2.ZERO
	var grid: Dictionary = _get_grid(scene)
	if grid.is_empty():
		return Vector2.ZERO
	var enemy_position: Vector2 = enemy.global_position
	var center_cell: Vector2i = _grid_cell(enemy_position)
	var cell_radius: int = int(ceil(max(1.0, query_radius) / CELL_SIZE))
	var push: Vector2 = Vector2.ZERO
	var processed: int = 0
	for x in range(center_cell.x - cell_radius, center_cell.x + cell_radius + 1):
		for y in range(center_cell.y - cell_radius, center_cell.y + cell_radius + 1):
			var cell: Vector2i = Vector2i(x, y)
			if not grid.has(cell):
				continue
			for other in grid[cell] as Array:
				if other == null or other == enemy or not is_instance_valid(other) or not (other is Node2D):
					continue
				var offset: Vector2 = enemy_position - (other as Node2D).global_position
				var other_radius: float = contact_radius
				var other_contact_radius: Variant = other.get("contact_radius")
				if other_contact_radius != null:
					other_radius = float(other_contact_radius)
				var radius: float = max(16.0, (contact_radius + other_radius) * 0.58)
				var radius_sq: float = radius * radius
				var distance_sq: float = offset.length_squared()
				if distance_sq > radius_sq:
					continue
				if distance_sq <= 0.001:
					offset = Vector2.RIGHT.rotated(float(enemy.get_instance_id() % 360) * PI / 180.0)
					distance_sq = 1.0
				var distance: float = sqrt(distance_sq)
				var max_push: float = max(24.0, radius * 0.55)
				var strength: float = (radius - distance) / radius
				push += (offset / distance) * strength * max_push
				processed += 1
				if processed >= max_processed:
					return push
	return push


static func _get_grid(scene: Node) -> Dictionary:
	var current_frame := Engine.get_physics_frames()
	var scene_id := scene.get_instance_id()
	if cached_frame == current_frame and cached_scene_id == scene_id:
		return cached_grid
	if cached_scene_id != scene_id:
		cached_grid.clear()
		active_cells.clear()
	cached_frame = current_frame
	cached_scene_id = scene_id
	_clear_grid_cells()
	var enemies: Array = scene.get_runtime_enemies() if scene.has_method("get_runtime_enemies") else scene.get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not _is_live_node2d(enemy):
			continue
		var cell := _grid_cell((enemy as Node2D).global_position)
		if not cached_grid.has(cell):
			cached_grid[cell] = []
		var cell_enemies: Array = cached_grid[cell]
		if cell_enemies.is_empty():
			active_cells.append(cell)
		cell_enemies.append(enemy)
	return cached_grid


static func _clear_grid_cells() -> void:
	for cell in active_cells:
		if not cached_grid.has(cell):
			continue
		var cell_enemies: Array = cached_grid[cell] as Array
		cell_enemies.clear()
	active_cells.clear()


static func _grid_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / CELL_SIZE), floori(position.y / CELL_SIZE))


static func _is_live_node2d(node: Variant) -> bool:
	if node == null or not is_instance_valid(node) or not (node is Node2D):
		return false
	if node is Node and (node as Node).is_queued_for_deletion():
		return false
	return true
