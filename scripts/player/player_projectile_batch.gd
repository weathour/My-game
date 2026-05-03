extends Node2D

const MAX_BATCHED_PROJECTILES := 1800
const DEFAULT_HIT_RADIUS := 10.0
const DEFAULT_ENEMY_HIT_RADIUS := 8.0
const MAX_HIT_CHECKS_PER_FRAME := 380
const HIT_GRID_CELL_SIZE := 96.0
const BULLET_TEXTURE_SIZE := 32
const TAIL_TEXTURE_SIZE := 8

var positions: Array[Vector2] = []
var source_origins: Array[Vector2] = []
var directions: Array[Vector2] = []
var damages: PackedFloat32Array = PackedFloat32Array()
var colors: Array[Color] = []
var role_ids: PackedStringArray = PackedStringArray()
var speeds: PackedFloat32Array = PackedFloat32Array()
var lifetimes: PackedFloat32Array = PackedFloat32Array()
var hit_radii: PackedFloat32Array = PackedFloat32Array()
var visual_radii: PackedFloat32Array = PackedFloat32Array()
var enemy_hit_radius_scales: PackedFloat32Array = PackedFloat32Array()
var enemy_hit_radius_mins: PackedFloat32Array = PackedFloat32Array()
var enemy_hit_radius_maxs: PackedFloat32Array = PackedFloat32Array()
var vulnerability_bonuses: PackedFloat32Array = PackedFloat32Array()
var vulnerability_durations: PackedFloat32Array = PackedFloat32Array()
var slow_multipliers: PackedFloat32Array = PackedFloat32Array()
var slow_durations: PackedFloat32Array = PackedFloat32Array()
var pierce_counts: PackedInt32Array = PackedInt32Array()
var wave_amplitudes: PackedFloat32Array = PackedFloat32Array()
var wave_frequencies: PackedFloat32Array = PackedFloat32Array()
var wave_phases: PackedFloat32Array = PackedFloat32Array()
var wave_elapsed_times: PackedFloat32Array = PackedFloat32Array()
var wave_travel_distances: PackedFloat32Array = PackedFloat32Array()
var wave_origins: Array[Vector2] = []
var wave_forwards: Array[Vector2] = []
var wave_sides: Array[Vector2] = []
var projectiles: Array = []
var scan_cursor: int = 0
var source_player: Node
var bullet_multimesh_instance: MultiMeshInstance2D
var tail_multimesh_instance: MultiMeshInstance2D
var bullet_multimesh: MultiMesh
var tail_multimesh: MultiMesh

func _ready() -> void:
	add_to_group("temporary_effects")
	z_index = 12
	_setup_multimesh_renderers()

func configure(owner: Node) -> void:
	source_player = owner

func add_projectile(data: Dictionary) -> bool:
	if positions.size() >= MAX_BATCHED_PROJECTILES:
		return false
	var shot_direction: Vector2 = data.get("direction", Vector2.RIGHT) as Vector2
	if shot_direction.length_squared() <= 0.001:
		shot_direction = Vector2.RIGHT
	shot_direction = shot_direction.normalized()
	var position: Vector2 = data.get("position", Vector2.ZERO) as Vector2
	positions.append(position)
	source_origins.append(data.get("source_origin", position) as Vector2)
	directions.append(shot_direction)
	damages.append(float(data.get("damage", 0.0)))
	colors.append(data.get("color", Color(1.0, 0.72, 0.38, 0.94)) as Color)
	role_ids.append(str(data.get("role_id", "gunner")))
	speeds.append(float(data.get("speed", 620.0)))
	lifetimes.append(float(data.get("lifetime", 1.0)))
	hit_radii.append(float(data.get("hit_radius", DEFAULT_HIT_RADIUS)))
	visual_radii.append(float(data.get("visual_radius", 4.2)))
	enemy_hit_radius_scales.append(float(data.get("enemy_hit_radius_scale", 0.2)))
	enemy_hit_radius_mins.append(float(data.get("enemy_hit_radius_min", 4.0)))
	enemy_hit_radius_maxs.append(float(data.get("enemy_hit_radius_max", 12.0)))
	vulnerability_bonuses.append(float(data.get("vulnerability_bonus", 0.0)))
	vulnerability_durations.append(float(data.get("vulnerability_duration", 0.0)))
	slow_multipliers.append(float(data.get("slow_multiplier", 1.0)))
	slow_durations.append(float(data.get("slow_duration", 0.0)))
	pierce_counts.append(int(data.get("pierce_count", 0)))
	wave_amplitudes.append(float(data.get("wave_amplitude", 0.0)))
	wave_frequencies.append(float(data.get("wave_frequency", 0.0)))
	wave_phases.append(float(data.get("wave_phase", 0.0)))
	wave_elapsed_times.append(0.0)
	wave_travel_distances.append(0.0)
	wave_origins.append(data.get("wave_origin", position) as Vector2)
	wave_forwards.append(data.get("wave_forward", shot_direction) as Vector2)
	wave_sides.append(data.get("wave_side", shot_direction.orthogonal().normalized()) as Vector2)
	_sync_projectile_size()
	_update_multimesh_instances()
	return true

func _physics_process(delta: float) -> void:
	if positions.is_empty():
		if not projectiles.is_empty():
			projectiles.clear()
			_update_multimesh_instances()
		return
	_update_projectiles(delta)
	_check_projectile_hits()
	_sync_projectile_size()
	_update_multimesh_instances()

func _update_projectiles(delta: float) -> void:
	for index in range(positions.size() - 1, -1, -1):
		lifetimes[index] -= delta
		if lifetimes[index] <= 0.0:
			_remove_projectile(index)
			continue
		var speed: float = speeds[index]
		if wave_amplitudes[index] > 0.0:
			_update_wave_projectile(index, delta, speed)
		else:
			positions[index] += directions[index] * speed * delta
	if scan_cursor >= positions.size():
		scan_cursor = 0

func _update_wave_projectile(index: int, delta: float, speed: float) -> void:
	wave_elapsed_times[index] += delta
	wave_travel_distances[index] += speed * delta
	var wave_offset: float = sin(wave_elapsed_times[index] * wave_frequencies[index] + wave_phases[index]) * wave_amplitudes[index]
	var old_position: Vector2 = positions[index]
	var next_position: Vector2 = wave_origins[index] + wave_forwards[index] * wave_travel_distances[index] + wave_sides[index] * wave_offset
	var move_vector: Vector2 = next_position - old_position
	positions[index] = next_position
	if move_vector.length_squared() > 0.001:
		directions[index] = move_vector.normalized()

func _check_projectile_hits() -> void:
	if source_player == null or not is_instance_valid(source_player):
		_clear_projectiles()
		return
	var enemies: Array = _get_live_enemies()
	if enemies.is_empty() or positions.is_empty():
		return
	var enemy_grid: Dictionary = _build_enemy_grid(enemies)
	var checks_done := 0
	var checked_projectiles := 0
	while checked_projectiles < positions.size() and checks_done < MAX_HIT_CHECKS_PER_FRAME:
		if positions.is_empty():
			return
		if scan_cursor >= positions.size():
			scan_cursor = 0
		var hit_enemy: Node2D = _find_hit_enemy(scan_cursor, enemy_grid)
		checks_done += 1
		if hit_enemy != null:
			_apply_projectile_hit(scan_cursor, hit_enemy)
			if pierce_counts[scan_cursor] > 0:
				pierce_counts[scan_cursor] -= 1
				scan_cursor += 1
			else:
				_remove_projectile(scan_cursor)
			continue
		scan_cursor += 1
		checked_projectiles += 1

func _find_hit_enemy(projectile_index: int, grid: Dictionary) -> Node2D:
	var position: Vector2 = positions[projectile_index]
	var total_cell_radius: float = hit_radii[projectile_index] + DEFAULT_ENEMY_HIT_RADIUS
	var cell_radius: int = int(ceil(total_cell_radius / HIT_GRID_CELL_SIZE))
	var center_cell: Vector2i = _grid_cell(position)
	for x in range(center_cell.x - cell_radius, center_cell.x + cell_radius + 1):
		for y in range(center_cell.y - cell_radius, center_cell.y + cell_radius + 1):
			var cell := Vector2i(x, y)
			if not grid.has(cell):
				continue
			for enemy in grid[cell] as Array:
				if enemy == null or not is_instance_valid(enemy) or enemy is not Node2D:
					continue
				var enemy_radius: float = _get_enemy_hit_radius(enemy as Node2D, enemy_hit_radius_scales[projectile_index], enemy_hit_radius_mins[projectile_index], enemy_hit_radius_maxs[projectile_index])
				var total_radius: float = hit_radii[projectile_index] + enemy_radius
				if position.distance_squared_to((enemy as Node2D).global_position) <= total_radius * total_radius:
					return enemy as Node2D
	return null

func _apply_projectile_hit(projectile_index: int, enemy: Node2D) -> void:
	var role_id: String = role_ids[projectile_index]
	var killed := false
	if source_player.has_method("_deal_damage_to_enemy"):
		killed = bool(source_player._deal_damage_to_enemy(enemy, damages[projectile_index], role_id, vulnerability_bonuses[projectile_index], vulnerability_durations[projectile_index], slow_multipliers[projectile_index], slow_durations[projectile_index], source_origins[projectile_index]))
	elif enemy.has_method("take_damage"):
		killed = bool(enemy.take_damage(damages[projectile_index]))
	if source_player.has_method("_register_attack_result"):
		source_player._register_attack_result(role_id, 1, killed)

func _build_enemy_grid(enemies: Array) -> Dictionary:
	var grid: Dictionary = {}
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy) or enemy is not Node2D:
			continue
		var cell: Vector2i = _grid_cell((enemy as Node2D).global_position)
		if not grid.has(cell):
			grid[cell] = []
		(grid[cell] as Array).append(enemy)
	return grid

func _get_live_enemies() -> Array:
	var tree: SceneTree = get_tree()
	if tree == null:
		return []
	return tree.get_nodes_in_group("enemies")

func _get_enemy_hit_radius(enemy: Node2D, scale: float, minimum: float, maximum: float) -> float:
	var contact_radius: Variant = enemy.get("contact_radius")
	if contact_radius == null:
		return clamp(DEFAULT_ENEMY_HIT_RADIUS, minimum, maximum)
	return clamp(float(contact_radius) * scale, minimum, maximum)

func _remove_projectile(index: int) -> void:
	var last_index := positions.size() - 1
	if index != last_index:
		positions[index] = positions[last_index]
		source_origins[index] = source_origins[last_index]
		directions[index] = directions[last_index]
		damages[index] = damages[last_index]
		colors[index] = colors[last_index]
		role_ids[index] = role_ids[last_index]
		speeds[index] = speeds[last_index]
		lifetimes[index] = lifetimes[last_index]
		hit_radii[index] = hit_radii[last_index]
		visual_radii[index] = visual_radii[last_index]
		enemy_hit_radius_scales[index] = enemy_hit_radius_scales[last_index]
		enemy_hit_radius_mins[index] = enemy_hit_radius_mins[last_index]
		enemy_hit_radius_maxs[index] = enemy_hit_radius_maxs[last_index]
		vulnerability_bonuses[index] = vulnerability_bonuses[last_index]
		vulnerability_durations[index] = vulnerability_durations[last_index]
		slow_multipliers[index] = slow_multipliers[last_index]
		slow_durations[index] = slow_durations[last_index]
		pierce_counts[index] = pierce_counts[last_index]
		wave_amplitudes[index] = wave_amplitudes[last_index]
		wave_frequencies[index] = wave_frequencies[last_index]
		wave_phases[index] = wave_phases[last_index]
		wave_elapsed_times[index] = wave_elapsed_times[last_index]
		wave_travel_distances[index] = wave_travel_distances[last_index]
		wave_origins[index] = wave_origins[last_index]
		wave_forwards[index] = wave_forwards[last_index]
		wave_sides[index] = wave_sides[last_index]
	positions.pop_back()
	source_origins.pop_back()
	directions.pop_back()
	damages.resize(last_index)
	colors.pop_back()
	role_ids.resize(last_index)
	speeds.resize(last_index)
	lifetimes.resize(last_index)
	hit_radii.resize(last_index)
	visual_radii.resize(last_index)
	enemy_hit_radius_scales.resize(last_index)
	enemy_hit_radius_mins.resize(last_index)
	enemy_hit_radius_maxs.resize(last_index)
	vulnerability_bonuses.resize(last_index)
	vulnerability_durations.resize(last_index)
	slow_multipliers.resize(last_index)
	slow_durations.resize(last_index)
	pierce_counts.resize(last_index)
	wave_amplitudes.resize(last_index)
	wave_frequencies.resize(last_index)
	wave_phases.resize(last_index)
	wave_elapsed_times.resize(last_index)
	wave_travel_distances.resize(last_index)
	wave_origins.pop_back()
	wave_forwards.pop_back()
	wave_sides.pop_back()
	if scan_cursor > positions.size():
		scan_cursor = positions.size()

func _clear_projectiles() -> void:
	positions.clear()
	source_origins.clear()
	directions.clear()
	damages.clear()
	colors.clear()
	role_ids.clear()
	speeds.clear()
	lifetimes.clear()
	hit_radii.clear()
	visual_radii.clear()
	enemy_hit_radius_scales.clear()
	enemy_hit_radius_mins.clear()
	enemy_hit_radius_maxs.clear()
	vulnerability_bonuses.clear()
	vulnerability_durations.clear()
	slow_multipliers.clear()
	slow_durations.clear()
	pierce_counts.clear()
	wave_amplitudes.clear()
	wave_frequencies.clear()
	wave_phases.clear()
	wave_elapsed_times.clear()
	wave_travel_distances.clear()
	wave_origins.clear()
	wave_forwards.clear()
	wave_sides.clear()
	projectiles.clear()
	scan_cursor = 0
	_update_multimesh_instances()

func _sync_projectile_size() -> void:
	if projectiles.size() != positions.size():
		projectiles.resize(positions.size())

func _setup_multimesh_renderers() -> void:
	bullet_multimesh = _create_multimesh()
	tail_multimesh = _create_multimesh()
	bullet_multimesh_instance = _create_multimesh_instance("BatchedBulletHeads", bullet_multimesh, _create_circle_texture(BULLET_TEXTURE_SIZE))
	tail_multimesh_instance = _create_multimesh_instance("BatchedBulletTails", tail_multimesh, _create_rect_texture(TAIL_TEXTURE_SIZE))

func _create_multimesh() -> MultiMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = MAX_BATCHED_PROJECTILES
	multimesh.visible_instance_count = 0
	return multimesh

func _create_multimesh_instance(node_name: String, multimesh: MultiMesh, texture: Texture2D) -> MultiMeshInstance2D:
	var instance := MultiMeshInstance2D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.texture = texture
	instance.z_index = z_index
	add_child(instance)
	return instance

func _update_multimesh_instances() -> void:
	if bullet_multimesh == null or tail_multimesh == null:
		return
	var count: int = min(positions.size(), MAX_BATCHED_PROJECTILES)
	bullet_multimesh.visible_instance_count = count
	tail_multimesh.visible_instance_count = count
	for index in range(count):
		var position: Vector2 = positions[index]
		var direction: Vector2 = directions[index]
		var radius: float = visual_radii[index]
		var color: Color = colors[index]
		var tail_length: float = radius * 2.8
		var tail_width: float = max(2.0, radius * 0.7)
		var tail_center: Vector2 = position - direction * tail_length * 0.5
		bullet_multimesh.set_instance_transform_2d(index, _make_transform(position, direction, Vector2(radius * 2.0, radius * 2.0)))
		bullet_multimesh.set_instance_color(index, color)
		tail_multimesh.set_instance_transform_2d(index, _make_transform(tail_center, direction, Vector2(tail_length, tail_width)))
		tail_multimesh.set_instance_color(index, Color(color.r, color.g, color.b, color.a * 0.55))

func _make_transform(position: Vector2, direction: Vector2, size: Vector2) -> Transform2D:
	var forward := direction.normalized()
	if forward.length_squared() <= 0.001:
		forward = Vector2.RIGHT
	var side := forward.orthogonal()
	return Transform2D(forward * size.x, side * size.y, position)

func _create_circle_texture(size: int) -> Texture2D:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(size - 1) * 0.5, float(size - 1) * 0.5)
	var radius := float(size) * 0.46
	for x in range(size):
		for y in range(size):
			var distance: float = center.distance_to(Vector2(float(x), float(y)))
			var alpha: float = clamp((radius - distance) / 2.0, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)

func _create_rect_texture(size: int) -> Texture2D:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for x in range(size):
		for y in range(size):
			image.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(image)

func _grid_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / HIT_GRID_CELL_SIZE), floori(position.y / HIT_GRID_CELL_SIZE))
