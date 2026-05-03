extends Node2D

const WHITE_KEY_SHADER := preload("res://shaders/white_key.gdshader")
const BULLET_TEXTURE_RELATIVE_PATH := "技能特效/子弹.jpg"
const BULLET_TEXTURE_SIZE := Vector2(1200.0, 1600.0)
const BULLET_VISIBLE_BOUNDS := Rect2(563.0, 641.0, 120.0, 118.0)
const BULLET_EFFECT_SCENE_SIZE := Vector2(1024.0, 1024.0)
const BULLET_EFFECT_VISIBLE_BOUNDS := Rect2(505.0, 476.0, 36.0, 36.0)
const BULLET_VISUAL_SCALE := 0.67
const MAX_IMPACT_EFFECTS_PER_PHYSICS_FRAME := 18
const MAX_SPLIT_BURSTS_PER_PHYSICS_FRAME := 6
static var shared_bullet_texture: Texture2D
static var cached_enemy_nodes: Array = []
static var cached_enemy_nodes_frame: int = -1
static var impact_effect_budget_frame: int = -1
static var impact_effect_budget_used: int = 0
static var split_burst_budget_frame: int = -1
static var split_burst_budget_used: int = 0

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

func _ready() -> void:
	add_to_group("player_projectiles")
	_refresh_bullet_visual(true)
	rotation = direction.angle()
	last_hit_scan_position = global_position
	if wave_amplitude > 0.0:
		_initialize_wave_motion()

func _physics_process(delta: float) -> void:
	_refresh_bullet_visual()
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
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
	for enemy in _get_cached_enemy_nodes():
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

	for enemy in _get_cached_enemy_nodes():
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
		cached_enemy_nodes = get_tree().get_nodes_in_group("enemies")
		cached_enemy_nodes_frame = current_frame
	return cached_enemy_nodes

func _apply_hit(enemy: Node2D) -> void:
	hit_enemy_ids[enemy.get_instance_id()] = true

	var killed: bool = false
	if source_player != null and source_player.has_method("_deal_damage_to_enemy"):
		killed = bool(source_player._deal_damage_to_enemy(enemy, damage, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_origin_position))
	else:
		if enemy.has_method("take_damage"):
			killed = bool(enemy.take_damage(damage))
		if slow_duration > 0.0 and enemy.has_method("apply_slow"):
			enemy.apply_slow(slow_multiplier, slow_duration)
		if vulnerability_duration > 0.0 and enemy.has_method("apply_vulnerability"):
			enemy.apply_vulnerability(vulnerability_bonus, vulnerability_duration)

	if source_player != null and source_player.has_method("_register_attack_result"):
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
	if split_burst_budget_used >= MAX_SPLIT_BURSTS_PER_PHYSICS_FRAME:
		return false
	split_burst_budget_used += 1
	return true

func _consume_impact_effect_budget() -> bool:
	var current_frame: int = Engine.get_physics_frames()
	if impact_effect_budget_frame != current_frame:
		impact_effect_budget_frame = current_frame
		impact_effect_budget_used = 0
	if impact_effect_budget_used >= MAX_IMPACT_EFFECTS_PER_PHYSICS_FRAME:
		return false
	impact_effect_budget_used += 1
	return true

func _spawn_split_visual(center: Vector2, radius: float, burst_index: int) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	var ring := Node2D.new()
	ring.add_to_group("temporary_effects")
	ring.global_position = center
	ring.z_index = 14
	current_scene.add_child(ring)

	var bullet_count: int = max(6, split_visual_bullet_count + burst_index * 4)
	for index in range(bullet_count):
		var angle: float = TAU * float(index) / float(bullet_count)
		var shard := Polygon2D.new()
		shard.color = Color(visual_color.r, visual_color.g, visual_color.b, 0.78)
		shard.position = Vector2.RIGHT.rotated(angle) * radius
		shard.rotation = angle
		shard.polygon = PackedVector2Array([
			Vector2(7.0, 0.0),
			Vector2(-4.0, -3.0),
			Vector2(-2.0, 0.0),
			Vector2(-4.0, 3.0)
		])
		ring.add_child(shard)

	var outline := Line2D.new()
	outline.width = 3.0
	outline.default_color = Color(visual_color.r, visual_color.g, visual_color.b, 0.34)
	outline.closed = true
	var points := PackedVector2Array()
	for index in range(24):
		points.append(Vector2.RIGHT.rotated(TAU * float(index) / 24.0) * radius)
	outline.points = points
	ring.add_child(outline)

	ring.scale = Vector2(0.28, 0.28)
	var tween := ring.create_tween()
	tween.parallel().tween_property(ring, "scale", Vector2.ONE, 0.12)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.22)
	tween.tween_callback(ring.queue_free)

func _spawn_impact_effect(position: Vector2, killed: bool) -> void:
	if not _consume_impact_effect_budget():
		return
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var impact := Polygon2D.new()
	impact.add_to_group("temporary_effects")
	impact.global_position = position
	impact.z_index = 15
	impact.color = visual_color if not killed else Color(1.0, 0.92, 0.6, 1.0)
	impact.polygon = PackedVector2Array([
		Vector2(0.0, -10.0),
		Vector2(10.0, 0.0),
		Vector2(0.0, 10.0),
		Vector2(-10.0, 0.0)
	])
	current_scene.add_child(impact)

	impact.scale = Vector2(0.35, 0.35)
	var tween := impact.create_tween()
	tween.parallel().tween_property(impact, "scale", Vector2(1.1, 1.1) if killed else Vector2(0.75, 0.75), 0.12)
	tween.parallel().tween_property(impact, "modulate:a", 0.0, 0.14 if killed else 0.1)
	tween.tween_callback(impact.queue_free)
