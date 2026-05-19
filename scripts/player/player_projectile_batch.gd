extends Node2D

const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const PLAYER_DAMAGE_BATCHER := preload("res://scripts/player/player_damage_batcher.gd")
const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")

const MAX_BATCHED_PROJECTILES := 1800
const DEFAULT_HIT_RADIUS := 10.0
const DEFAULT_ENEMY_HIT_RADIUS := 8.0
const MAX_HIT_CHECKS_PER_FRAME := 380
const HIT_GRID_CELL_SIZE := 96.0
const BULLET_FRAME_TEXTURE_PATHS := [
	"res://effects/gun/bullet/1.png",
	"res://effects/gun/bullet/2.png",
	"res://effects/gun/bullet/3.png",
	"res://effects/gun/bullet/4.png",
	"res://effects/gun/bullet/3.png",
	"res://effects/gun/bullet/2.png"
]
const BULLET_FRAME_VISIBLE_REGION := Rect2(505.0, 476.0, 36.0, 36.0)
const BULLET_ANIMATION_SPEED := 28.0
const BULLET_FRAME_BASE_SIZE := 84.0
const MULTIMESH_REFRESH_FRAME_STRIDE_WHEN_HEAVY := 2
const HEAVY_PROJECTILE_COUNT := 360

var positions: Array[Vector2] = []
var source_origins: Array[Vector2] = []
var directions: Array[Vector2] = []
var damages: PackedFloat32Array = PackedFloat32Array()
var colors: Array[Color] = []
var outline_colors: Array[Color] = []
var role_ids: PackedStringArray = PackedStringArray()
var speeds: PackedFloat32Array = PackedFloat32Array()
var lifetimes: PackedFloat32Array = PackedFloat32Array()
var hit_radii: PackedFloat32Array = PackedFloat32Array()
var visual_radii: PackedFloat32Array = PackedFloat32Array()
var visual_min_diameters: PackedFloat32Array = PackedFloat32Array()
var visual_outline_widths: PackedFloat32Array = PackedFloat32Array()
var damage_enabled_flags: Array[bool] = []
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
var hit_enemy_ids: Array = []
var scan_cursor: int = 0
var damage_enabled_count: int = 0
var animation_elapsed: float = 0.0
var current_animation_frame: int = -1
var bullet_frame_textures: Array[Texture2D] = []
var source_player: Node
var bullet_outline_multimesh_instance: MultiMeshInstance2D
var bullet_outline_multimesh: MultiMesh
var bullet_multimesh_instance: MultiMeshInstance2D
var bullet_multimesh: MultiMesh
var last_multimesh_refresh_frame: int = -1
var damage_batcher: RefCounted
var reusable_damage_batcher: RefCounted

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("temporary_effects")
	z_index = 12
	_load_bullet_frame_textures()
	_setup_multimesh_renderers()

func configure(batch_owner: Node) -> void:
	source_player = batch_owner

func add_projectile(data: Dictionary) -> bool:
	if positions.size() >= MAX_BATCHED_PROJECTILES:
		return false
	var shot_direction: Vector2 = data.get("direction", Vector2.RIGHT) as Vector2
	if shot_direction.length_squared() <= 0.001:
		shot_direction = Vector2.RIGHT
	shot_direction = shot_direction.normalized()
	var spawn_position: Vector2 = data.get("position", Vector2.ZERO) as Vector2
	positions.append(spawn_position)
	source_origins.append(data.get("source_origin", spawn_position) as Vector2)
	directions.append(shot_direction)
	damages.append(float(data.get("damage", 0.0)))
	colors.append(data.get("color", Color(1.0, 0.72, 0.38, 0.94)) as Color)
	outline_colors.append(data.get("visual_outline_color", Color(1.0, 1.0, 1.0, 0.0)) as Color)
	role_ids.append(str(data.get("role_id", "gunner")))
	speeds.append(float(data.get("speed", 620.0)))
	lifetimes.append(float(data.get("lifetime", 1.0)))
	hit_radii.append(float(data.get("hit_radius", DEFAULT_HIT_RADIUS)))
	visual_radii.append(float(data.get("visual_radius", 4.2)))
	visual_min_diameters.append(float(data.get("visual_min_diameter", 8.0)))
	visual_outline_widths.append(float(data.get("visual_outline_width", 0.0)))
	_append_damage_enabled_flag(damages[damages.size() - 1] > 0.0 and hit_radii[hit_radii.size() - 1] > 0.0)
	enemy_hit_radius_scales.append(float(data.get("enemy_hit_radius_scale", 0.2)))
	enemy_hit_radius_mins.append(float(data.get("enemy_hit_radius_min", 4.0)))
	enemy_hit_radius_maxs.append(float(data.get("enemy_hit_radius_max", 12.0)))
	vulnerability_bonuses.append(float(data.get("vulnerability_bonus", 0.0)))
	vulnerability_durations.append(float(data.get("vulnerability_duration", 0.0)))
	slow_multipliers.append(float(data.get("slow_multiplier", 1.0)))
	slow_durations.append(float(data.get("slow_duration", 0.0)))
	var pierce_count: int = int(data.get("pierce_count", 0))
	pierce_counts.append(pierce_count)
	wave_amplitudes.append(float(data.get("wave_amplitude", 0.0)))
	wave_frequencies.append(float(data.get("wave_frequency", 0.0)))
	wave_phases.append(float(data.get("wave_phase", 0.0)))
	wave_elapsed_times.append(0.0)
	wave_travel_distances.append(0.0)
	wave_origins.append(data.get("wave_origin", spawn_position) as Vector2)
	wave_forwards.append(data.get("wave_forward", shot_direction) as Vector2)
	wave_sides.append(data.get("wave_side", shot_direction.orthogonal().normalized()) as Vector2)
	if pierce_count > 0:
		hit_enemy_ids.append({})
	else:
		hit_enemy_ids.append(null)
	return true

func add_projectile_values(
	spawn_position: Vector2,
	source_origin: Vector2,
	direction: Vector2,
	damage: float,
	color: Color,
	role_id: String,
	speed: float = 620.0,
	lifetime: float = 1.0,
	hit_radius: float = DEFAULT_HIT_RADIUS,
	visual_radius: float = 4.2,
	visual_min_diameter: float = 8.0,
	visual_outline_color: Color = Color(1.0, 1.0, 1.0, 0.0),
	visual_outline_width: float = 0.0,
	enemy_hit_radius_scale: float = 0.2,
	enemy_hit_radius_min: float = 4.0,
	enemy_hit_radius_max: float = 12.0,
	vulnerability_bonus: float = 0.0,
	vulnerability_duration: float = 0.0,
	slow_multiplier: float = 1.0,
	slow_duration: float = 0.0,
	pierce_count: int = 0,
	wave_amplitude: float = 0.0,
	wave_frequency: float = 0.0,
	wave_phase: float = 0.0
) -> bool:
	if positions.size() >= MAX_BATCHED_PROJECTILES:
		return false
	var shot_direction: Vector2 = direction
	if shot_direction.length_squared() <= 0.001:
		shot_direction = Vector2.RIGHT
	shot_direction = shot_direction.normalized()
	positions.append(spawn_position)
	source_origins.append(source_origin)
	directions.append(shot_direction)
	damages.append(damage)
	colors.append(color)
	outline_colors.append(visual_outline_color)
	role_ids.append(role_id)
	speeds.append(speed)
	lifetimes.append(lifetime)
	hit_radii.append(hit_radius)
	visual_radii.append(visual_radius)
	visual_min_diameters.append(visual_min_diameter)
	visual_outline_widths.append(visual_outline_width)
	_append_damage_enabled_flag(damage > 0.0 and hit_radius > 0.0)
	enemy_hit_radius_scales.append(enemy_hit_radius_scale)
	enemy_hit_radius_mins.append(enemy_hit_radius_min)
	enemy_hit_radius_maxs.append(enemy_hit_radius_max)
	vulnerability_bonuses.append(vulnerability_bonus)
	vulnerability_durations.append(vulnerability_duration)
	slow_multipliers.append(slow_multiplier)
	slow_durations.append(slow_duration)
	pierce_counts.append(pierce_count)
	wave_amplitudes.append(wave_amplitude)
	wave_frequencies.append(wave_frequency)
	wave_phases.append(wave_phase)
	wave_elapsed_times.append(0.0)
	wave_travel_distances.append(0.0)
	wave_origins.append(spawn_position)
	wave_forwards.append(shot_direction)
	wave_sides.append(shot_direction.orthogonal().normalized())
	if pierce_count > 0:
		hit_enemy_ids.append({})
	else:
		hit_enemy_ids.append(null)
	return true

func _physics_process(delta: float) -> void:
	if positions.is_empty():
		if bullet_multimesh != null and bullet_multimesh.visible_instance_count != 0:
			_update_multimesh_instances()
		return
	_update_animation_frame(delta)
	_update_projectiles(delta)
	_check_projectile_hits()
	_update_multimesh_instances()
	PERFORMANCE_COUNTERS.add("batched_projectiles", positions.size())

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
	if positions.is_empty() or damage_enabled_count <= 0:
		return
	var enemy_grid: Dictionary = PLAYER_DAMAGE_RESOLVER._get_enemy_grid(source_player)
	if enemy_grid.is_empty():
		return
	damage_batcher = _get_damage_batcher()
	var checks_done := 0
	var checked_projectiles := 0
	while checked_projectiles < positions.size() and checks_done < MAX_HIT_CHECKS_PER_FRAME:
		if positions.is_empty():
			break
		if not _advance_scan_cursor_to_damage_enabled():
			break
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
	if damage_batcher != null:
		damage_batcher.flush()
		damage_batcher = null

func _advance_scan_cursor_to_damage_enabled() -> bool:
	if damage_enabled_count <= 0 or positions.is_empty():
		return false
	var attempts: int = 0
	while attempts < positions.size():
		if scan_cursor >= positions.size():
			scan_cursor = 0
		if damage_enabled_flags[scan_cursor]:
			return true
		scan_cursor += 1
		attempts += 1
	return false

func _get_damage_batcher() -> RefCounted:
	if reusable_damage_batcher == null:
		reusable_damage_batcher = PLAYER_DAMAGE_BATCHER.new(source_player)
	elif reusable_damage_batcher.has_method("reset"):
		reusable_damage_batcher.reset(source_player)
	return reusable_damage_batcher

func _find_hit_enemy(projectile_index: int, grid: Dictionary) -> Node2D:
	var projectile_position: Vector2 = positions[projectile_index]
	var total_cell_radius: float = hit_radii[projectile_index] + DEFAULT_ENEMY_HIT_RADIUS
	var cell_radius: int = int(ceil(total_cell_radius / HIT_GRID_CELL_SIZE))
	var center_cell: Vector2i = _grid_cell(projectile_position)
	for x in range(center_cell.x - cell_radius, center_cell.x + cell_radius + 1):
		for y in range(center_cell.y - cell_radius, center_cell.y + cell_radius + 1):
			var cell := Vector2i(x, y)
			if not grid.has(cell):
				continue
			for enemy in grid[cell] as Array:
				if enemy == null or not is_instance_valid(enemy) or enemy is not Node2D:
					continue
				if _has_projectile_hit_enemy(projectile_index, enemy as Node2D):
					continue
				var enemy_radius: float = _get_enemy_hit_radius(enemy as Node2D, enemy_hit_radius_scales[projectile_index], enemy_hit_radius_mins[projectile_index], enemy_hit_radius_maxs[projectile_index])
				var total_radius: float = hit_radii[projectile_index] + enemy_radius
				if projectile_position.distance_squared_to((enemy as Node2D).global_position) <= total_radius * total_radius:
					return enemy as Node2D
	return null

func _apply_projectile_hit(projectile_index: int, enemy: Node2D) -> void:
	if pierce_counts[projectile_index] > 0:
		_mark_projectile_hit_enemy(projectile_index, enemy)
	var role_id: String = role_ids[projectile_index]
	if damage_batcher != null:
		damage_batcher.add_enemy(
			enemy,
			damages[projectile_index],
			role_id,
			vulnerability_bonuses[projectile_index],
			vulnerability_durations[projectile_index],
			slow_multipliers[projectile_index],
			slow_durations[projectile_index],
			source_origins[projectile_index]
		)
		return
	if source_player.has_method("_deal_damage_to_enemy"):
		source_player._deal_damage_to_enemy(enemy, damages[projectile_index], role_id, vulnerability_bonuses[projectile_index], vulnerability_durations[projectile_index], slow_multipliers[projectile_index], slow_durations[projectile_index], source_origins[projectile_index])
	elif enemy.has_method("take_damage"):
		enemy.take_damage(damages[projectile_index])

func _has_projectile_hit_enemy(projectile_index: int, enemy: Node2D) -> bool:
	if projectile_index < 0 or projectile_index >= hit_enemy_ids.size():
		return false
	var hits: Variant = hit_enemy_ids[projectile_index]
	if hits is not Dictionary:
		return false
	return (hits as Dictionary).has(enemy.get_instance_id())

func _mark_projectile_hit_enemy(projectile_index: int, enemy: Node2D) -> void:
	if projectile_index < 0 or projectile_index >= hit_enemy_ids.size():
		return
	var hits: Variant = hit_enemy_ids[projectile_index]
	if hits is not Dictionary:
		hits = {}
		hit_enemy_ids[projectile_index] = hits
	(hits as Dictionary)[enemy.get_instance_id()] = true

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
	var scene: Node = tree.current_scene
	if scene != null and scene.has_method("get_runtime_enemies"):
		return scene.get_runtime_enemies()
	return tree.get_nodes_in_group("enemies")

func _get_enemy_hit_radius(enemy: Node2D, radius_scale: float, minimum: float, maximum: float) -> float:
	var contact_radius: Variant = enemy.get("contact_radius")
	if contact_radius == null:
		return clamp(DEFAULT_ENEMY_HIT_RADIUS, minimum, maximum)
	return clamp(float(contact_radius) * radius_scale, minimum, maximum)

func _remove_projectile(index: int) -> void:
	var last_index := positions.size() - 1
	if index != last_index:
		var removed_damage_enabled: bool = damage_enabled_flags[index]
		positions[index] = positions[last_index]
		source_origins[index] = source_origins[last_index]
		directions[index] = directions[last_index]
		damages[index] = damages[last_index]
		colors[index] = colors[last_index]
		outline_colors[index] = outline_colors[last_index]
		role_ids[index] = role_ids[last_index]
		speeds[index] = speeds[last_index]
		lifetimes[index] = lifetimes[last_index]
		hit_radii[index] = hit_radii[last_index]
		visual_radii[index] = visual_radii[last_index]
		visual_min_diameters[index] = visual_min_diameters[last_index]
		visual_outline_widths[index] = visual_outline_widths[last_index]
		damage_enabled_flags[index] = damage_enabled_flags[last_index]
		if removed_damage_enabled:
			damage_enabled_count -= 1
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
		hit_enemy_ids[index] = hit_enemy_ids[last_index]
	elif damage_enabled_flags[index]:
		damage_enabled_count -= 1
	positions.pop_back()
	source_origins.pop_back()
	directions.pop_back()
	damages.resize(last_index)
	colors.pop_back()
	outline_colors.pop_back()
	role_ids.resize(last_index)
	speeds.resize(last_index)
	lifetimes.resize(last_index)
	hit_radii.resize(last_index)
	visual_radii.resize(last_index)
	visual_min_diameters.resize(last_index)
	visual_outline_widths.resize(last_index)
	damage_enabled_flags.pop_back()
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
	hit_enemy_ids.pop_back()
	if scan_cursor > positions.size():
		scan_cursor = positions.size()

func _clear_projectiles() -> void:
	positions.clear()
	source_origins.clear()
	directions.clear()
	damages.clear()
	colors.clear()
	outline_colors.clear()
	role_ids.clear()
	speeds.clear()
	lifetimes.clear()
	hit_radii.clear()
	visual_radii.clear()
	visual_min_diameters.clear()
	visual_outline_widths.clear()
	damage_enabled_flags.clear()
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
	hit_enemy_ids.clear()
	scan_cursor = 0
	damage_enabled_count = 0
	_update_multimesh_instances()

func _append_damage_enabled_flag(enabled: bool) -> void:
	damage_enabled_flags.append(enabled)
	if enabled:
		damage_enabled_count += 1

func _setup_multimesh_renderers() -> void:
	bullet_outline_multimesh = _create_multimesh()
	bullet_multimesh = _create_multimesh()
	var fallback_texture: Texture2D = bullet_frame_textures[0] if not bullet_frame_textures.is_empty() else null
	bullet_outline_multimesh_instance = _create_multimesh_instance("BatchedBulletOutlines", bullet_outline_multimesh, fallback_texture)
	if bullet_outline_multimesh_instance != null:
		bullet_outline_multimesh_instance.z_index = z_index - 1
	bullet_multimesh_instance = _create_multimesh_instance("BatchedBulletVisuals", bullet_multimesh, fallback_texture)

func _load_bullet_frame_textures() -> void:
	bullet_frame_textures.clear()
	for path in BULLET_FRAME_TEXTURE_PATHS:
		var texture := load(path) as Texture2D
		if texture != null:
			bullet_frame_textures.append(_create_bullet_frame_texture(texture))

func _create_bullet_frame_texture(texture: Texture2D) -> Texture2D:
	var source_image := texture.get_image()
	var crop_rect := Rect2i(
		Vector2i(int(BULLET_FRAME_VISIBLE_REGION.position.x), int(BULLET_FRAME_VISIBLE_REGION.position.y)),
		Vector2i(int(BULLET_FRAME_VISIBLE_REGION.size.x), int(BULLET_FRAME_VISIBLE_REGION.size.y))
	)
	var cropped := Image.create(crop_rect.size.x, crop_rect.size.y, false, Image.FORMAT_RGBA8)
	cropped.blit_rect(source_image, crop_rect, Vector2i.ZERO)
	for x in range(cropped.get_width()):
		for y in range(cropped.get_height()):
			var pixel := cropped.get_pixel(x, y)
			var max_channel: float = max(pixel.r, max(pixel.g, pixel.b))
			var min_channel: float = min(pixel.r, min(pixel.g, pixel.b))
			if max_channel >= 0.94 and max_channel - min_channel <= 0.08:
				pixel.a = 0.0
				cropped.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(cropped)

func _update_animation_frame(delta: float) -> void:
	if bullet_frame_textures.is_empty() or bullet_multimesh_instance == null:
		return
	animation_elapsed += delta
	var frame_index := int(floor(animation_elapsed * BULLET_ANIMATION_SPEED)) % bullet_frame_textures.size()
	if frame_index == current_animation_frame:
		return
	current_animation_frame = frame_index
	if bullet_outline_multimesh_instance != null:
		bullet_outline_multimesh_instance.texture = bullet_frame_textures[frame_index]
	bullet_multimesh_instance.texture = bullet_frame_textures[frame_index]

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
	if bullet_multimesh == null:
		return
	var current_frame := Engine.get_process_frames()
	if positions.size() >= HEAVY_PROJECTILE_COUNT and last_multimesh_refresh_frame >= 0:
		if current_frame - last_multimesh_refresh_frame < MULTIMESH_REFRESH_FRAME_STRIDE_WHEN_HEAVY:
			return
	last_multimesh_refresh_frame = current_frame
	var count: int = min(positions.size(), MAX_BATCHED_PROJECTILES)
	bullet_multimesh.visible_instance_count = count
	if bullet_outline_multimesh != null:
		bullet_outline_multimesh.visible_instance_count = count
	for index in range(count):
		var projectile_position: Vector2 = positions[index]
		var direction: Vector2 = directions[index]
		var radius: float = visual_radii[index]
		var color: Color = colors[index]
		var diameter: float = max(visual_min_diameters[index], radius * 2.0)
		var frame_size := Vector2(diameter, diameter) * (BULLET_FRAME_BASE_SIZE / 32.0)
		bullet_multimesh.set_instance_transform_2d(index, _make_transform(projectile_position, direction, frame_size))
		bullet_multimesh.set_instance_color(index, color)
		if bullet_outline_multimesh != null:
			var outline_width: float = visual_outline_widths[index]
			var outline_color: Color = outline_colors[index] if outline_width > 0.0 else Color(1.0, 1.0, 1.0, 0.0)
			var outline_diameter: float = diameter + outline_width * 2.0
			var outline_size := Vector2(outline_diameter, outline_diameter) * (BULLET_FRAME_BASE_SIZE / 32.0)
			bullet_outline_multimesh.set_instance_transform_2d(index, _make_transform(projectile_position, direction, outline_size))
			bullet_outline_multimesh.set_instance_color(index, outline_color)

func _make_transform(transform_position: Vector2, direction: Vector2, size: Vector2) -> Transform2D:
	var forward := direction
	if forward.length_squared() <= 0.001:
		forward = Vector2.RIGHT
	var side := forward.orthogonal()
	return Transform2D(forward * size.x, side * size.y, transform_position)

func _grid_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / HIT_GRID_CELL_SIZE), floori(world_position.y / HIT_GRID_CELL_SIZE))
