extends Node2D

const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")
const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")
const WHITE_KEY_SHADER := preload("res://shaders/white_key.gdshader")
const BULLET_TEXTURE_RELATIVE_PATH := "技能特效/子弹.jpg"
const BULLET_TEXTURE_SIZE := Vector2(1200.0, 1600.0)
const BULLET_VISIBLE_BOUNDS := Rect2(563.0, 641.0, 120.0, 118.0)
const BULLET_EFFECT_SCENE_SIZE := Vector2(1024.0, 1024.0)
const BULLET_EFFECT_VISIBLE_BOUNDS := Rect2(505.0, 476.0, 36.0, 36.0)
const BULLET_VISUAL_SCALE := 0.67
const MAX_IMPACT_EFFECTS_PER_PHYSICS_FRAME := 18
const MAX_SPLIT_BURSTS_PER_PHYSICS_FRAME := 6
const LOW_FPS_IMPACT_EFFECTS_PER_PHYSICS_FRAME := 9
const CRITICAL_FPS_IMPACT_EFFECTS_PER_PHYSICS_FRAME := 4
const LOW_FPS_SPLIT_BURSTS_PER_PHYSICS_FRAME := 3
const CRITICAL_FPS_SPLIT_BURSTS_PER_PHYSICS_FRAME := 1
const ENEMY_GRID_CELL_SIZE := 96.0
const IMPACT_EFFECT_POOL_LIMIT := 96
const SPLIT_RING_POOL_LIMIT := 32
static var shared_bullet_texture: Texture2D
static var cached_enemy_nodes: Array = []
static var cached_enemy_nodes_frame: int = -1
static var cached_enemy_grid: Dictionary = {}
static var cached_enemy_grid_frame: int = -1
static var impact_effect_budget_frame: int = -1
static var impact_effect_budget_used: int = 0
static var split_burst_budget_frame: int = -1
static var split_burst_budget_used: int = 0
static var impact_effect_pool: Array[Polygon2D] = []
static var split_ring_pool: Array[Node2D] = []
static var active_impact_effects: Array[Dictionary] = []
static var active_split_ring_effects: Array[Dictionary] = []
static var effect_animation_frame: int = -1
static var impact_effect_polygon := PackedVector2Array([
	Vector2(0.0, -10.0),
	Vector2(10.0, 0.0),
	Vector2(0.0, 10.0),
	Vector2(-10.0, 0.0)
])
static var split_shard_polygon := PackedVector2Array([
	Vector2(7.0, 0.0),
	Vector2(-4.0, -3.0),
	Vector2(-2.0, 0.0),
	Vector2(-4.0, 3.0)
])

@export var speed: float = 420.0
@export var speed_multiplier: float = 1.0
@export var damage: float = 10.0
@export var lifetime: float = 3.0
@export var hit_radius: float = 14.0
@export var hit_radius_multiplier: float = 1.0
@export var pierce_count: int = 0
@export var bounce_count: int = 0
@export var slow_multiplier: float = 1.0
@export var slow_duration: float = 0.0
@export var vulnerability_bonus: float = 0.0
@export var vulnerability_duration: float = 0.0
@export var visual_color: Color = Color(1.0, 0.93, 0.39, 1.0)
@export var visual_scale_multiplier: float = 1.0
@export var enemy_hit_radius_scale: float = 0.42
@export var enemy_hit_radius_min: float = 10.0
@export var enemy_hit_radius_max: float = 28.0
@export var animated_scene_size: Vector2 = BULLET_EFFECT_SCENE_SIZE
@export var animated_visible_bounds: Rect2 = BULLET_EFFECT_VISIBLE_BOUNDS
@export var min_hit_travel_distance: float = 0.0
@export var hit_scan_interval: float = 0.0
@export var split_count: int = 0
@export var split_radius: float = 58.0
@export var split_visual_bullet_count: int = 12

var direction: Vector2 = Vector2.RIGHT
var target: Node2D
var source_player: Node
var source_role_id: String = ""
var source_origin_position: Vector2 = Vector2.ZERO
var traveled_distance: float = 0.0
var hit_enemy_ids: Dictionary = {}
var wave_amplitude: float = 0.0
var wave_frequency: float = 0.0
var wave_phase: float = 0.0
var wave_elapsed: float = 0.0
var wave_travel_distance: float = 0.0
var wave_origin: Vector2 = Vector2.ZERO
var wave_forward_direction: Vector2 = Vector2.RIGHT
var wave_side_direction: Vector2 = Vector2.DOWN
var hit_scan_elapsed: float = 0.0
var last_hit_scan_position: Vector2 = Vector2.ZERO
var bullet_texture: Texture2D
var visual_cache_ready: bool = false
var cached_hit_radius: float = -9999.0
var cached_visual_scale_multiplier: float = -9999.0
var cached_visual_color: Color = Color(-1.0, -1.0, -1.0, -1.0)
var cached_animated_scene_size: Vector2 = Vector2(-1.0, -1.0)
var cached_animated_visible_bounds: Rect2 = Rect2(-1.0, -1.0, -1.0, -1.0)
var split_triggered: bool = false
var runtime_pool_key: String = ""
var projectile_scene_defaults: Dictionary = {}

func _get_desktop_sketch_path(relative_path: String) -> String:
	return (OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP).replace("\\", "/") + "/草图/" + relative_path)

func _get_project_sketch_path(relative_path: String) -> String:
	return "res://assets/sketch/" + relative_path

func _load_runtime_texture(relative_path: String) -> Texture2D:
	var project_path := _get_project_sketch_path(relative_path)
	if ResourceLoader.exists(project_path):
		var project_texture := load(project_path) as Texture2D
		if project_texture != null:
			return project_texture
	var image := Image.new()
	var load_error := image.load(_get_desktop_sketch_path(relative_path))
	if load_error != OK:
		return null
	return ImageTexture.create_from_image(image)

func _ensure_bullet_sprite() -> Sprite2D:
	var sprite := get_node_or_null("BulletSprite") as Sprite2D
	if sprite != null:
		return sprite
	sprite = Sprite2D.new()
	sprite.name = "BulletSprite"
	sprite.z_index = 2
	sprite.centered = true
	add_child(sprite)
	return sprite

func _refresh_bullet_visual(force: bool = false) -> void:
	if not force and visual_cache_ready:
		if is_equal_approx(cached_hit_radius, hit_radius) \
		and is_equal_approx(cached_visual_scale_multiplier, visual_scale_multiplier) \
		and cached_visual_color == visual_color \
		and cached_animated_scene_size == animated_scene_size \
		and cached_animated_visible_bounds == animated_visible_bounds:
			return

	var animated_sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var polygon := get_node_or_null("Polygon2D") as Polygon2D
	var sprite := get_node_or_null("BulletSprite") as Sprite2D
	if animated_sprite != null:
		if polygon != null:
			polygon.visible = false
		if sprite != null:
			sprite.visible = false
		animated_sprite.visible = true
		animated_sprite.material = null
		animated_sprite.modulate = Color.WHITE
		animated_sprite.centered = true
		animated_sprite.position = Vector2.ZERO
		animated_sprite.offset = animated_scene_size * 0.5 - (animated_visible_bounds.position + animated_visible_bounds.size * 0.5)
		var effect_diameter: float = max(14.0, hit_radius * 2.15) * BULLET_VISUAL_SCALE * visual_scale_multiplier
		var effect_scale: float = effect_diameter / max(animated_visible_bounds.size.x, animated_visible_bounds.size.y)
		animated_sprite.scale = Vector2.ONE * effect_scale
		if animated_sprite.sprite_frames != null:
			var animation_name: StringName = animated_sprite.animation
			var animation_names: PackedStringArray = animated_sprite.sprite_frames.get_animation_names()
			if animation_name == StringName() and animation_names.size() > 0:
				animation_name = StringName(animation_names[0])
			elif animation_name != StringName() and not animation_names.has(String(animation_name)) and animation_names.size() > 0:
				animation_name = StringName(animation_names[0])
			if animation_name != StringName():
				animated_sprite.animation = animation_name
				if not animated_sprite.is_playing():
					animated_sprite.play(animation_name)
		_update_visual_cache()
		return

	if polygon != null:
		polygon.visible = bullet_texture == null
		if polygon.visible:
			polygon.color = visual_color
			polygon.scale = Vector2(1.4, 0.9) * BULLET_VISUAL_SCALE * visual_scale_multiplier

	sprite = _ensure_bullet_sprite()
	if bullet_texture == null:
		if shared_bullet_texture == null:
			shared_bullet_texture = _load_runtime_texture(BULLET_TEXTURE_RELATIVE_PATH)
		bullet_texture = shared_bullet_texture
	if bullet_texture == null:
		sprite.visible = false
		_update_visual_cache()
		return

	sprite.visible = true
	sprite.texture = bullet_texture
	sprite.modulate = Color.WHITE
	sprite.offset = Vector2(
		BULLET_TEXTURE_SIZE.x * 0.5 - (BULLET_VISIBLE_BOUNDS.position.x + BULLET_VISIBLE_BOUNDS.size.x * 0.5),
		BULLET_TEXTURE_SIZE.y * 0.5 - (BULLET_VISIBLE_BOUNDS.position.y + BULLET_VISIBLE_BOUNDS.size.y * 0.5)
	)
	var target_diameter: float = max(10.0, hit_radius * 2.0) * BULLET_VISUAL_SCALE * visual_scale_multiplier
	var base_size: float = max(BULLET_VISIBLE_BOUNDS.size.x, BULLET_VISIBLE_BOUNDS.size.y)
	var visual_scale: float = target_diameter / base_size
	sprite.scale = Vector2.ONE * visual_scale
	sprite.rotation = 0.0

	var shader_material := sprite.material as ShaderMaterial
	if shader_material == null:
		shader_material = ShaderMaterial.new()
		shader_material.shader = WHITE_KEY_SHADER
		sprite.material = shader_material
	_update_visual_cache()

func _update_visual_cache() -> void:
	visual_cache_ready = true
	cached_hit_radius = hit_radius
	cached_visual_scale_multiplier = visual_scale_multiplier
	cached_visual_color = visual_color
	cached_animated_scene_size = animated_scene_size
	cached_animated_visible_bounds = animated_visible_bounds

func _enter_tree() -> void:
	add_to_group("player_projectiles")
	var tree := get_tree()
	if tree != null:
		var scene: Node = tree.current_scene
		if scene != null and scene.has_method("register_runtime_player_projectile"):
			scene.register_runtime_player_projectile(self)

func _ready() -> void:
	_refresh_bullet_visual(true)
	rotation = direction.angle()
	last_hit_scan_position = global_position
	if wave_amplitude > 0.0:
		_initialize_wave_motion()

func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null:
		var scene: Node = tree.current_scene
		if scene != null and scene.has_method("unregister_runtime_player_projectile"):
			scene.unregister_runtime_player_projectile(self)

func _ensure_projectile_scene_defaults() -> void:
	if not projectile_scene_defaults.is_empty():
		return
	projectile_scene_defaults = {
		"speed": speed,
		"speed_multiplier": speed_multiplier,
		"damage": damage,
		"lifetime": lifetime,
		"hit_radius": hit_radius,
		"hit_radius_multiplier": hit_radius_multiplier,
		"pierce_count": pierce_count,
		"bounce_count": bounce_count,
		"slow_multiplier": slow_multiplier,
		"slow_duration": slow_duration,
		"vulnerability_bonus": vulnerability_bonus,
		"vulnerability_duration": vulnerability_duration,
		"visual_color": visual_color,
		"visual_scale_multiplier": visual_scale_multiplier,
		"enemy_hit_radius_scale": enemy_hit_radius_scale,
		"enemy_hit_radius_min": enemy_hit_radius_min,
		"enemy_hit_radius_max": enemy_hit_radius_max,
		"animated_scene_size": animated_scene_size,
		"animated_visible_bounds": animated_visible_bounds,
		"min_hit_travel_distance": min_hit_travel_distance,
		"hit_scan_interval": hit_scan_interval,
		"split_count": split_count,
		"split_radius": split_radius,
		"split_visual_bullet_count": split_visual_bullet_count,
		"wave_amplitude": wave_amplitude,
		"wave_frequency": wave_frequency,
		"wave_phase": wave_phase
	}

func _projectile_scene_default(key: String, fallback: Variant) -> Variant:
	_ensure_projectile_scene_defaults()
	return projectile_scene_defaults.get(key, fallback)

func reset_projectile(config: Dictionary = {}) -> void:
	_ensure_projectile_scene_defaults()
	set_meta("player_projectile_released", false)
	runtime_pool_key = str(config.get("pool_key", scene_file_path))
	speed = float(config.get("speed", _projectile_scene_default("speed", 420.0)))
	speed_multiplier = float(config.get("speed_multiplier", _projectile_scene_default("speed_multiplier", 1.0)))
	damage = float(config.get("damage", _projectile_scene_default("damage", 10.0)))
	lifetime = float(config.get("lifetime", _projectile_scene_default("lifetime", 3.0)))
	hit_radius = float(config.get("hit_radius", _projectile_scene_default("hit_radius", 14.0)))
	hit_radius_multiplier = float(config.get("hit_radius_multiplier", _projectile_scene_default("hit_radius_multiplier", 1.0)))
	pierce_count = int(config.get("pierce_count", _projectile_scene_default("pierce_count", 0)))
	bounce_count = int(config.get("bounce_count", _projectile_scene_default("bounce_count", 0)))
	slow_multiplier = float(config.get("slow_multiplier", _projectile_scene_default("slow_multiplier", 1.0)))
	slow_duration = float(config.get("slow_duration", _projectile_scene_default("slow_duration", 0.0)))
	vulnerability_bonus = float(config.get("vulnerability_bonus", _projectile_scene_default("vulnerability_bonus", 0.0)))
	vulnerability_duration = float(config.get("vulnerability_duration", _projectile_scene_default("vulnerability_duration", 0.0)))
	visual_color = config.get("visual_color", _projectile_scene_default("visual_color", Color(1.0, 0.93, 0.39, 1.0)))
	visual_scale_multiplier = float(config.get("visual_scale_multiplier", _projectile_scene_default("visual_scale_multiplier", 1.0)))
	enemy_hit_radius_scale = float(config.get("enemy_hit_radius_scale", _projectile_scene_default("enemy_hit_radius_scale", 0.42)))
	enemy_hit_radius_min = float(config.get("enemy_hit_radius_min", _projectile_scene_default("enemy_hit_radius_min", 10.0)))
	enemy_hit_radius_max = float(config.get("enemy_hit_radius_max", _projectile_scene_default("enemy_hit_radius_max", 28.0)))
	animated_scene_size = config.get("animated_scene_size", _projectile_scene_default("animated_scene_size", BULLET_EFFECT_SCENE_SIZE))
	animated_visible_bounds = config.get("animated_visible_bounds", _projectile_scene_default("animated_visible_bounds", BULLET_EFFECT_VISIBLE_BOUNDS))
	min_hit_travel_distance = float(config.get("min_hit_travel_distance", _projectile_scene_default("min_hit_travel_distance", 0.0)))
	hit_scan_interval = float(config.get("hit_scan_interval", _projectile_scene_default("hit_scan_interval", 0.0)))
	split_count = int(config.get("split_count", _projectile_scene_default("split_count", 0)))
	split_radius = float(config.get("split_radius", _projectile_scene_default("split_radius", 58.0)))
	split_visual_bullet_count = int(config.get("split_visual_bullet_count", _projectile_scene_default("split_visual_bullet_count", 12)))

	var configured_direction: Vector2 = config.get("direction", Vector2.RIGHT)
	direction = configured_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	target = config.get("target", null) as Node2D
	source_player = config.get("source_player", null) as Node
	source_role_id = str(config.get("source_role_id", ""))
	global_position = config.get("position", global_position)
	source_origin_position = config.get("source_origin_position", global_position)
	traveled_distance = 0.0
	hit_enemy_ids.clear()
	wave_amplitude = float(config.get("wave_amplitude", _projectile_scene_default("wave_amplitude", 0.0)))
	wave_frequency = float(config.get("wave_frequency", _projectile_scene_default("wave_frequency", 0.0)))
	wave_phase = float(config.get("wave_phase", _projectile_scene_default("wave_phase", 0.0)))
	wave_elapsed = 0.0
	wave_travel_distance = 0.0
	wave_origin = global_position
	wave_forward_direction = direction
	wave_side_direction = direction.orthogonal().normalized()
	hit_scan_elapsed = 0.0
	last_hit_scan_position = global_position
	split_triggered = false
	visible = true
	modulate = Color.WHITE
	set_physics_process(true)
	visual_cache_ready = false
	rotation = direction.angle()
	if wave_amplitude > 0.0:
		_initialize_wave_motion()
	_refresh_bullet_visual(true)

func _physics_process(delta: float) -> void:
	_update_static_effect_animations(delta)
	_refresh_bullet_visual()
	lifetime -= delta
	if lifetime <= 0.0:
		_release_or_free()
		return

	var start_position := global_position
	var effective_speed: float = speed * max(0.0, speed_multiplier)
	if wave_amplitude > 0.0 and target == null:
		_update_wave_motion(delta, effective_speed)
	elif target != null and is_instance_valid(target):
		direction = global_position.direction_to(target.global_position)
		rotation = direction.angle()
		global_position += direction.normalized() * effective_speed * delta
	else:
		rotation = direction.angle()
		global_position += direction.normalized() * effective_speed * delta

	traveled_distance += start_position.distance_to(global_position)
	if traveled_distance < min_hit_travel_distance:
		return
	if hit_scan_interval > 0.0:
		hit_scan_elapsed += delta
		if hit_scan_elapsed < hit_scan_interval:
			return
		hit_scan_elapsed = 0.0
		_try_hit_enemy(last_hit_scan_position, global_position)
		last_hit_scan_position = global_position
	else:
		_try_hit_enemy(start_position, global_position)

func configure_wave_motion(amplitude: float, frequency: float, phase: float = 0.0) -> void:
	wave_amplitude = max(0.0, amplitude)
	wave_frequency = max(0.0, frequency)
	wave_phase = phase
	wave_elapsed = 0.0
	wave_travel_distance = 0.0
	_initialize_wave_motion()

func _initialize_wave_motion() -> void:
	wave_origin = global_position
	wave_forward_direction = direction.normalized()
	if wave_forward_direction.length_squared() <= 0.001:
		wave_forward_direction = Vector2.RIGHT
	wave_side_direction = wave_forward_direction.orthogonal().normalized()

func _update_wave_motion(delta: float, effective_speed: float) -> void:
	wave_elapsed += delta
	wave_travel_distance += effective_speed * delta
	var wave_offset: float = sin(wave_elapsed * wave_frequency + wave_phase) * wave_amplitude
	var next_position: Vector2 = wave_origin + wave_forward_direction * wave_travel_distance + wave_side_direction * wave_offset
	var move_vector: Vector2 = next_position - global_position
	if move_vector.length_squared() > 0.001:
		direction = move_vector.normalized()
		rotation = direction.angle()
	global_position = next_position

func _get_enemy_hit_radius(enemy: Node2D) -> float:
	var enemy_contact_radius: Variant = enemy.get("contact_radius")
	if enemy_contact_radius == null:
		return clamp(12.0 * enemy_hit_radius_scale, enemy_hit_radius_min, enemy_hit_radius_max)
	return clamp(float(enemy_contact_radius) * enemy_hit_radius_scale, enemy_hit_radius_min, enemy_hit_radius_max)

func _segment_hits_enemy(enemy: Node2D, start_position: Vector2, end_position: Vector2) -> bool:
	var total_hit_radius: float = hit_radius * max(0.01, hit_radius_multiplier) + _get_enemy_hit_radius(enemy)
	if start_position.distance_squared_to(end_position) <= 0.001:
		return start_position.distance_squared_to(enemy.global_position) <= total_hit_radius * total_hit_radius
	var closest_point := Geometry2D.get_closest_point_to_segment(enemy.global_position, start_position, end_position)
	return closest_point.distance_squared_to(enemy.global_position) <= total_hit_radius * total_hit_radius

func _find_bounce_target(last_enemy: Node2D) -> Node2D:
	var chosen_enemy: Node2D
	var best_distance: float = INF
	for enemy in _get_candidate_enemies_near(global_position, 260.0):
		if not is_instance_valid(enemy):
			continue
		if enemy == last_enemy:
			continue
		if not _can_hit_enemy(enemy):
			continue
		var distance: float = global_position.distance_to(enemy.global_position)
		if distance > 260.0:
			continue
		if distance < best_distance:
			best_distance = distance
			chosen_enemy = enemy
	return chosen_enemy

func _try_hit_enemy(start_position: Vector2, end_position: Vector2) -> void:
	if target != null and is_instance_valid(target) and _can_hit_enemy(target):
		if _segment_hits_enemy(target, start_position, end_position):
			_apply_hit(target)
			return

	var query_center: Vector2 = (start_position + end_position) * 0.5
	var query_radius: float = start_position.distance_to(end_position) * 0.5 + hit_radius * max(0.01, hit_radius_multiplier) + enemy_hit_radius_max + 8.0
	for enemy in _get_candidate_enemies_near(query_center, query_radius):
		if not is_instance_valid(enemy):
			continue
		if not _can_hit_enemy(enemy):
			continue
		if _segment_hits_enemy(enemy, start_position, end_position):
			_apply_hit(enemy)
			return

func _can_hit_enemy(enemy: Node2D) -> bool:
	return not hit_enemy_ids.has(enemy.get_instance_id())

func _get_cached_enemy_nodes() -> Array:
	var current_frame := Engine.get_physics_frames()
	if cached_enemy_nodes_frame != current_frame:
		cached_enemy_nodes = _get_runtime_enemies()
		cached_enemy_nodes_frame = current_frame
	return cached_enemy_nodes

func _get_runtime_enemies() -> Array:
	var tree := get_tree()
	if tree == null:
		return []
	var scene: Node = tree.current_scene
	if scene != null and scene.has_method("get_runtime_enemies"):
		return scene.get_runtime_enemies()
	return tree.get_nodes_in_group("enemies")

func _get_candidate_enemies_near(center: Vector2, radius: float) -> Array:
	var grid: Dictionary = _get_cached_enemy_grid()
	if grid.is_empty():
		return []
	var cell_radius: int = int(ceil(max(1.0, radius) / ENEMY_GRID_CELL_SIZE))
	var center_cell: Vector2i = _grid_cell(center)
	var result: Array = []
	for x in range(center_cell.x - cell_radius, center_cell.x + cell_radius + 1):
		for y in range(center_cell.y - cell_radius, center_cell.y + cell_radius + 1):
			var cell := Vector2i(x, y)
			if not grid.has(cell):
				continue
			result.append_array(grid[cell] as Array)
	return result

func _get_cached_enemy_grid() -> Dictionary:
	var current_frame := Engine.get_physics_frames()
	if cached_enemy_grid_frame == current_frame:
		return cached_enemy_grid
	if source_player != null and is_instance_valid(source_player):
		cached_enemy_grid = PLAYER_DAMAGE_RESOLVER._get_enemy_grid(source_player)
	else:
		cached_enemy_grid = {}
		for enemy in _get_cached_enemy_nodes():
			if enemy == null or not is_instance_valid(enemy) or enemy is not Node2D:
				continue
			var cell: Vector2i = _grid_cell((enemy as Node2D).global_position)
			if not cached_enemy_grid.has(cell):
				cached_enemy_grid[cell] = []
			(cached_enemy_grid[cell] as Array).append(enemy)
	cached_enemy_grid_frame = current_frame
	return cached_enemy_grid

func _grid_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / ENEMY_GRID_CELL_SIZE), floori(position.y / ENEMY_GRID_CELL_SIZE))

func _apply_hit(enemy: Node2D) -> void:
	hit_enemy_ids[enemy.get_instance_id()] = true

	var killed: bool = false
	var queued_damage := false
	if source_player != null and source_player.has_method("_deal_damage_to_enemy"):
		PLAYER_DAMAGE_RESOLVER.queue_damage_to_enemy(source_player, enemy, damage, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_origin_position, true)
		queued_damage = true
	else:
		if enemy.has_method("take_damage"):
			killed = bool(enemy.take_damage(damage))
		if slow_duration > 0.0 and enemy.has_method("apply_slow"):
			enemy.apply_slow(slow_multiplier, slow_duration)
		if vulnerability_duration > 0.0 and enemy.has_method("apply_vulnerability"):
			enemy.apply_vulnerability(vulnerability_bonus, vulnerability_duration)

	if not queued_damage and source_player != null and source_player.has_method("_register_attack_result"):
		source_player._register_attack_result(source_role_id, 1, killed)

	_spawn_impact_effect(enemy.global_position, killed)
	if split_count > 0 and not split_triggered:
		split_triggered = true
		_trigger_split_bursts(enemy.global_position)

	if bounce_count > 0:
		bounce_count -= 1
		var bounce_target := _find_bounce_target(enemy)
		if bounce_target != null:
			target = bounce_target
			direction = global_position.direction_to(bounce_target.global_position)
			return

	if pierce_count > 0:
		pierce_count -= 1
		target = null
		return

	_release_or_free()

func _release_or_free() -> void:
	if bool(get_meta("player_projectile_released", false)):
		return
	set_meta("player_projectile_released", true)
	var tree := get_tree()
	var scene: Node = tree.current_scene if tree != null else null
	hide()
	set_physics_process(false)
	remove_from_group("player_projectiles")
	var animated_sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite != null:
		animated_sprite.stop()
	var parent := get_parent()
	if parent != null:
		parent.remove_child(self)
	if scene != null and scene.has_method("release_runtime_player_projectile"):
		scene.release_runtime_player_projectile(self, runtime_pool_key)
	else:
		queue_free()

func _trigger_split_bursts(center: Vector2) -> void:
	var burst_count: int = clamp(split_count, 0, 2)
	if burst_count <= 0:
		return
	for burst_index in range(burst_count):
		_apply_split_burst(center, burst_index)

func _apply_split_burst(center: Vector2, burst_index: int) -> void:
	if not _consume_split_burst_budget():
		return
	var radius: float = split_radius + float(burst_index) * 20.0
	_spawn_split_visual(center, radius, burst_index)
	if source_player != null and source_player.has_method("_damage_enemies_in_radius"):
		var hit_count: int = int(source_player._damage_enemies_in_radius(center, radius, damage, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id))
		if hit_count > 0 and source_player.has_method("_register_attack_result"):
			source_player._register_attack_result(source_role_id, hit_count, false)

func _consume_split_burst_budget() -> bool:
	var current_frame: int = Engine.get_physics_frames()
	if split_burst_budget_frame != current_frame:
		split_burst_budget_frame = current_frame
		split_burst_budget_used = 0
	if split_burst_budget_used >= _get_split_burst_budget_per_frame():
		return false
	split_burst_budget_used += 1
	return true

func _consume_impact_effect_budget() -> bool:
	var current_frame: int = Engine.get_physics_frames()
	if impact_effect_budget_frame != current_frame:
		impact_effect_budget_frame = current_frame
		impact_effect_budget_used = 0
	if impact_effect_budget_used >= _get_impact_effect_budget_per_frame():
		return false
	impact_effect_budget_used += 1
	return true

func _get_split_burst_budget_per_frame() -> int:
	var fps := Engine.get_frames_per_second()
	if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return CRITICAL_FPS_SPLIT_BURSTS_PER_PHYSICS_FRAME
	if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return LOW_FPS_SPLIT_BURSTS_PER_PHYSICS_FRAME
	return MAX_SPLIT_BURSTS_PER_PHYSICS_FRAME

func _get_impact_effect_budget_per_frame() -> int:
	var fps := Engine.get_frames_per_second()
	if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return CRITICAL_FPS_IMPACT_EFFECTS_PER_PHYSICS_FRAME
	if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return LOW_FPS_IMPACT_EFFECTS_PER_PHYSICS_FRAME
	return MAX_IMPACT_EFFECTS_PER_PHYSICS_FRAME

func _can_spawn_temporary_effect(current_scene: Node) -> bool:
	if current_scene != null and current_scene.has_method("_can_spawn_runtime_group"):
		var limit: int = PERFORMANCE_GUARD.get_dynamic_limit(current_scene, "temporary_effects", PERFORMANCE_GUARD.DEFAULT_TEMPORARY_EFFECT_LIMIT)
		return bool(current_scene._can_spawn_runtime_group("temporary_effects", limit))
	return current_scene != null

func _acquire_impact_effect() -> Polygon2D:
	while not impact_effect_pool.is_empty():
		var pooled_impact: Variant = impact_effect_pool.pop_back()
		if not is_instance_valid(pooled_impact) or not (pooled_impact is Polygon2D):
			continue
		var impact := pooled_impact as Polygon2D
		if impact.is_queued_for_deletion():
			continue
		return impact
	return Polygon2D.new()

static func _release_impact_effect(impact: Polygon2D) -> void:
	if impact == null or not is_instance_valid(impact):
		return
	if bool(impact.get_meta("bullet_impact_released", false)):
		return
	impact.set_meta("bullet_impact_released", true)
	impact.visible = false
	impact.modulate = Color.WHITE
	impact.remove_from_group("temporary_effects")
	if impact.get_parent() != null:
		impact.get_parent().remove_child(impact)
	if impact_effect_pool.size() < IMPACT_EFFECT_POOL_LIMIT and not impact_effect_pool.has(impact):
		impact_effect_pool.append(impact)
	else:
		impact.queue_free()

func _acquire_split_ring() -> Node2D:
	while not split_ring_pool.is_empty():
		var pooled_ring: Variant = split_ring_pool.pop_back()
		if not is_instance_valid(pooled_ring) or not (pooled_ring is Node2D):
			continue
		var ring := pooled_ring as Node2D
		if ring.is_queued_for_deletion():
			continue
		return ring
	var ring := Node2D.new()
	ring.set_meta("bullet_split_ring_initialized", true)
	var outline := Line2D.new()
	outline.name = "Outline"
	outline.width = 3.0
	outline.closed = true
	ring.add_child(outline)
	return ring

func _ensure_split_ring_children(ring: Node2D, shard_count: int) -> void:
	var existing_shards: Array[Polygon2D] = []
	for child in ring.get_children():
		if child is Polygon2D:
			existing_shards.append(child as Polygon2D)
	while existing_shards.size() < shard_count:
		var shard := Polygon2D.new()
		shard.polygon = split_shard_polygon
		ring.add_child(shard)
		existing_shards.append(shard)
	for index in range(existing_shards.size()):
		existing_shards[index].visible = index < shard_count
	var outline := ring.get_node_or_null("Outline") as Line2D
	if outline == null:
		outline = Line2D.new()
		outline.name = "Outline"
		outline.width = 3.0
		outline.closed = true
		ring.add_child(outline)
	outline.visible = true

static func _release_split_ring(ring: Node2D) -> void:
	if ring == null or not is_instance_valid(ring):
		return
	if bool(ring.get_meta("bullet_split_ring_released", false)):
		return
	ring.set_meta("bullet_split_ring_released", true)
	ring.visible = false
	ring.modulate = Color.WHITE
	ring.remove_from_group("temporary_effects")
	if ring.get_parent() != null:
		ring.get_parent().remove_child(ring)
	if split_ring_pool.size() < SPLIT_RING_POOL_LIMIT and not split_ring_pool.has(ring):
		split_ring_pool.append(ring)
	else:
		ring.queue_free()

func _spawn_split_visual(center: Vector2, radius: float, burst_index: int) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	if not _can_spawn_temporary_effect(current_scene):
		return
	var ring := _acquire_split_ring()
	ring.set_meta("bullet_split_ring_released", false)
	ring.add_to_group("temporary_effects")
	PERFORMANCE_COUNTERS.add("temporary_effect_spawns", 1)
	ring.global_position = center
	ring.z_index = 14
	ring.visible = true
	ring.modulate = Color.WHITE
	current_scene.add_child(ring)

	var bullet_count: int = max(6, split_visual_bullet_count + burst_index * 4)
	_ensure_split_ring_children(ring, bullet_count)
	var shard_index := 0
	for index in range(bullet_count):
		var angle: float = TAU * float(index) / float(bullet_count)
		var shard := ring.get_child(shard_index) as Polygon2D
		while shard == null:
			shard_index += 1
			shard = ring.get_child(shard_index) as Polygon2D
		shard.color = Color(visual_color.r, visual_color.g, visual_color.b, 0.78)
		shard.position = Vector2.RIGHT.rotated(angle) * radius
		shard.rotation = angle
		shard.polygon = split_shard_polygon
		shard.visible = true
		shard_index += 1

	var outline := ring.get_node_or_null("Outline") as Line2D
	outline.width = 3.0
	outline.default_color = Color(visual_color.r, visual_color.g, visual_color.b, 0.34)
	outline.closed = true
	var points := PackedVector2Array()
	for index in range(24):
		points.append(Vector2.RIGHT.rotated(TAU * float(index) / 24.0) * radius)
	outline.points = points

	ring.scale = Vector2(0.28, 0.28)
	active_split_ring_effects.append({
		"node": ring,
		"elapsed": 0.0,
		"duration": 0.22,
		"scale_duration": 0.12
	})

func _spawn_impact_effect(position: Vector2, killed: bool) -> void:
	if not _consume_impact_effect_budget():
		return
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	if not _can_spawn_temporary_effect(current_scene):
		return

	var impact := _acquire_impact_effect()
	impact.set_meta("bullet_impact_released", false)
	impact.add_to_group("temporary_effects")
	PERFORMANCE_COUNTERS.add("temporary_effect_spawns", 1)
	impact.global_position = position
	impact.z_index = 15
	impact.visible = true
	impact.modulate = Color.WHITE
	impact.color = visual_color if not killed else Color(1.0, 0.92, 0.6, 1.0)
	impact.polygon = impact_effect_polygon
	current_scene.add_child(impact)

	impact.scale = Vector2(0.35, 0.35)
	active_impact_effects.append({
		"node": impact,
		"elapsed": 0.0,
		"duration": 0.14 if killed else 0.1,
		"scale_duration": 0.12,
		"target_scale": Vector2(1.1, 1.1) if killed else Vector2(0.75, 0.75)
	})

static func _update_static_effect_animations(delta: float) -> void:
	var current_frame := Engine.get_physics_frames()
	if effect_animation_frame == current_frame:
		return
	effect_animation_frame = current_frame
	_update_active_impact_effects(delta)
	_update_active_split_ring_effects(delta)

static func _update_active_impact_effects(delta: float) -> void:
	for index in range(active_impact_effects.size() - 1, -1, -1):
		var data: Dictionary = active_impact_effects[index]
		var impact := data.get("node", null) as Polygon2D
		if impact == null or not is_instance_valid(impact):
			active_impact_effects.remove_at(index)
			continue
		var elapsed: float = float(data.get("elapsed", 0.0)) + delta
		var duration: float = max(0.001, float(data.get("duration", 0.1)))
		var scale_duration: float = max(0.001, float(data.get("scale_duration", duration)))
		var target_scale: Vector2 = data.get("target_scale", Vector2.ONE)
		impact.scale = Vector2(0.35, 0.35).lerp(target_scale, clamp(elapsed / scale_duration, 0.0, 1.0))
		impact.modulate.a = 1.0 - clamp(elapsed / duration, 0.0, 1.0)
		if elapsed >= duration:
			active_impact_effects.remove_at(index)
			_release_impact_effect(impact)
			continue
		data["elapsed"] = elapsed
		active_impact_effects[index] = data

static func _update_active_split_ring_effects(delta: float) -> void:
	for index in range(active_split_ring_effects.size() - 1, -1, -1):
		var data: Dictionary = active_split_ring_effects[index]
		var ring := data.get("node", null) as Node2D
		if ring == null or not is_instance_valid(ring):
			active_split_ring_effects.remove_at(index)
			continue
		var elapsed: float = float(data.get("elapsed", 0.0)) + delta
		var duration: float = max(0.001, float(data.get("duration", 0.22)))
		var scale_duration: float = max(0.001, float(data.get("scale_duration", 0.12)))
		ring.scale = Vector2(0.28, 0.28).lerp(Vector2.ONE, clamp(elapsed / scale_duration, 0.0, 1.0))
		ring.modulate.a = 1.0 - clamp(elapsed / duration, 0.0, 1.0)
		if elapsed >= duration:
			active_split_ring_effects.remove_at(index)
			_release_split_ring(ring)
			continue
		data["elapsed"] = elapsed
		active_split_ring_effects[index] = data
