extends RefCounted

const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")
const PLAYER_GUNNER_INTERSECT_EFFECTS := preload("res://scripts/player/player_gunner_intersect_effects.gd")
const AUTHORED_SCENE_POOL_LIMIT_PER_SCENE := 32
const SKETCH_SPRITE_EFFECT_POOL_LIMIT := 32

static var authored_scene_pools: Dictionary = {}
static var scene_animation_duration_cache: Dictionary = {}
static var sketch_sprite_effect_pool: Array[Node2D] = []
static var authored_scene_spawn_serial: int = 0

static func _mark_temporary_effect(node: Node) -> void:
	if node != null:
		node.add_to_group("temporary_effects")
		PERFORMANCE_COUNTERS.add("temporary_effect_spawns", 1)

static func _can_spawn_temporary_effect(owner) -> bool:
	return owner != null and owner.get_tree() != null

static func spawn_sketch_sprite_effect(
		owner,
		center: Vector2,
		rotation_angle: float,
		texture_path: String,
		full_size: Vector2,
		visible_bounds: Rect2,
		target_visible_size: Vector2,
		duration: float,
		modulate_color: Color = Color.WHITE,
		z_index: int = 13,
		align_visible_center: bool = true,
		preserve_aspect: bool = false,
		value_threshold: float = 0.94,
		saturation_threshold: float = 0.08,
		edge_softness: float = 0.03
	) -> Node2D:
	if not _can_spawn_temporary_effect(owner):
		return null
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		return null

	var texture: Texture2D = owner._get_cached_runtime_texture(texture_path)
	if texture == null:
		return null

	var effect := _acquire_sketch_sprite_effect(current_scene)
	effect.set_meta("sketch_sprite_released", false)
	effect.global_position = center
	effect.rotation = rotation_angle
	effect.z_index = z_index
	effect.scale = Vector2.ONE
	effect.modulate = Color.WHITE

	var sprite := effect.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		effect.add_child(sprite)
	sprite.texture = texture
	sprite.centered = true
	sprite.material = owner._create_white_key_material(value_threshold, saturation_threshold, edge_softness)
	sprite.modulate = modulate_color
	if align_visible_center:
		var visible_center := visible_bounds.position + visible_bounds.size * 0.5
		sprite.offset = full_size * 0.5 - visible_center
	else:
		sprite.offset = Vector2.ZERO
	if preserve_aspect:
		var base_visible_size: float = max(1.0, max(visible_bounds.size.x, visible_bounds.size.y))
		var target_size: float = max(target_visible_size.x, target_visible_size.y)
		sprite.scale = Vector2.ONE * (target_size / base_visible_size)
	else:
		sprite.scale = Vector2(
			target_visible_size.x / max(1.0, visible_bounds.size.x),
			target_visible_size.y / max(1.0, visible_bounds.size.y)
		)

	var tween := effect.create_tween()
	tween.parallel().tween_property(effect, "modulate:a", 0.0, duration)
	tween.parallel().tween_property(effect, "scale", Vector2(1.06, 1.06), duration * 0.35)
	tween.tween_callback(_release_sketch_sprite_effect.bind(effect))
	return effect

static func _acquire_sketch_sprite_effect(current_scene: Node) -> Node2D:
	while not sketch_sprite_effect_pool.is_empty():
		var pooled_effect: Variant = sketch_sprite_effect_pool.pop_back()
		if not is_instance_valid(pooled_effect) or not (pooled_effect is Node2D):
			continue
		var effect := pooled_effect as Node2D
		if effect.is_queued_for_deletion():
			continue
		_prepare_authored_scene(effect, current_scene)
		return effect
	var effect := Node2D.new()
	current_scene.add_child(effect)
	_mark_temporary_effect(effect)
	return effect

static func _release_sketch_sprite_effect(effect: Node2D) -> void:
	if effect == null or not is_instance_valid(effect):
		return
	if bool(effect.get_meta("sketch_sprite_released", false)):
		return
	effect.set_meta("sketch_sprite_released", true)
	effect.hide()
	effect.remove_from_group("temporary_effects")
	if sketch_sprite_effect_pool.size() < SKETCH_SPRITE_EFFECT_POOL_LIMIT and not sketch_sprite_effect_pool.has(effect):
		sketch_sprite_effect_pool.append(effect)
	else:
		effect.queue_free()

static func spawn_authored_scene_effect(owner, scene: PackedScene, scene_size: Vector2, visible_bounds: Rect2, center: Vector2, rotation_radians: float, scale_multiplier: float, z_index: int = 12) -> Node2D:
	return spawn_scaled_animated_scene(
		owner,
		scene,
		scene_size,
		visible_bounds,
		visible_bounds,
		center,
		rotation_radians,
		Vector2.ONE,
		z_index,
		0.3,
		false,
		scale_multiplier,
		true
	)


static func spawn_sword_slash_scene_effect(owner, center: Vector2, direction: Vector2, radius: float, duration: float, thickness: float, mirror_horizontal: bool = false) -> Node2D:
	var playback_direction: Vector2 = direction.normalized()
	if playback_direction.length_squared() <= 0.001:
		playback_direction = Vector2.DOWN
	return spawn_scaled_animated_scene(
		owner,
		owner.SWORD_SLASH_EFFECT_SCENE,
		owner.SWORD_SLASH_SCENE_SIZE,
		owner.SWORD_SLASH_SCENE_VISIBLE_BOUNDS,
		owner.SWORD_SLASH_SCENE_VISIBLE_BOUNDS,
		center,
		playback_direction.angle() - Vector2.DOWN.angle(),
		Vector2(max(18.0, thickness * 2.0), max(72.0, radius * 2.0)),
		13,
		max(0.24, duration),
		mirror_horizontal
	)


static func spawn_sword_omnislash_scene_effect(owner, center: Vector2, direction: Vector2, length: float, thickness: float) -> Node2D:
	var playback_direction: Vector2 = direction.normalized()
	if playback_direction.length_squared() <= 0.001:
		playback_direction = Vector2.RIGHT
	return spawn_scaled_animated_scene(
		owner,
		owner.SWORD_OMNISLASH_EFFECT_SCENE,
		owner.SWORD_OMNISLASH_SCENE_SIZE,
		owner.SWORD_OMNISLASH_SCENE_VISIBLE_BOUNDS,
		owner.SWORD_OMNISLASH_SCENE_VISIBLE_BOUNDS,
		center,
		playback_direction.angle() - Vector2.RIGHT.angle(),
		Vector2(max(120.0, length), max(28.0, thickness * 1.18)),
		15,
		0.2
	)


static func spawn_sword_fan_scene_effect(owner, center: Vector2, direction: Vector2, scale_multiplier: float = 1.0) -> Node2D:
	var playback_direction: Vector2 = direction.normalized()
	if playback_direction.length_squared() <= 0.001:
		playback_direction = Vector2.RIGHT
	return spawn_scaled_animated_scene(
		owner,
		owner.SWORD_FAN_EFFECT_SCENE,
		owner.SWORD_FAN_SCENE_SIZE,
		owner.SWORD_FAN_SCENE_VISIBLE_BOUNDS,
		owner.SWORD_FAN_SCENE_VISIBLE_BOUNDS,
		center,
		playback_direction.angle() + PI,
		Vector2(138.0, 74.0) * scale_multiplier,
		12,
		0.24,
		false,
		1.0,
		false
	)


static func spawn_mage_gathering_scene_effect(owner, center: Vector2, direction: Vector2, scale_multiplier: float = 1.0) -> Node2D:
	var playback_direction: Vector2 = direction.normalized()
	if playback_direction.length_squared() <= 0.001:
		playback_direction = Vector2.RIGHT
	return spawn_authored_scene_effect(
		owner,
		owner.MAGE_GATHERING_EFFECT_SCENE,
		owner.MAGE_GATHERING_SCENE_SIZE,
		owner.MAGE_GATHERING_SCENE_VISIBLE_BOUNDS,
		center,
		playback_direction.angle() - Vector2.RIGHT.angle(),
		1.55 * scale_multiplier,
		12
	)


static func spawn_mage_boom_scene_effect(owner, center: Vector2, radius: float) -> Node2D:
	return spawn_scaled_animated_scene(
		owner,
		owner.MAGE_BOOM_EFFECT_SCENE,
		owner.MAGE_BOOM_SCENE_SIZE,
		owner.MAGE_BOOM_SCENE_VISIBLE_BOUNDS,
		owner.MAGE_BOOM_IMPACT_FOCUS_BOUNDS,
		center,
		0.0,
		Vector2(max(80.0, radius * 4.0), max(184.0, radius * 4.9)),
		14,
		0.3
	)


static func spawn_mage_warning_scene_effect(owner, center: Vector2, radius: float) -> Node2D:
	return spawn_scaled_animated_scene(
		owner,
		owner.MAGE_WARNING_EFFECT_SCENE,
		owner.MAGE_WARNING_SCENE_SIZE,
		owner.MAGE_WARNING_SCENE_VISIBLE_BOUNDS,
		owner.MAGE_WARNING_SCENE_VISIBLE_BOUNDS,
		center,
		0.0,
		Vector2(max(80.0, radius * 4.0), max(42.0, radius * 1.2)),
		13,
		0.2
	)

static func spawn_scaled_animated_scene(
		owner,
		scene: PackedScene,
		scene_size: Vector2,
		visible_bounds: Rect2,
		offset_bounds: Rect2,
		center: Vector2,
		rotation_radians: float,
		target_visible_size: Vector2,
		z_index: int,
		fallback_duration: float,
		mirror_horizontal: bool = false,
		scale_multiplier: float = 1.0,
		multiply_base_scale: bool = true,
		bypass_spawn_limit: bool = false
	) -> Node2D:
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null or scene == null:
		return null

	var scene_key := _get_scene_pool_key(scene)
	if not bypass_spawn_limit and not _can_spawn_temporary_effect(owner) and not _has_reusable_authored_scene(scene_key):
		return null
	var effect := _acquire_authored_scene(current_scene, scene, scene_key)
	if effect == null:
		return null

	authored_scene_spawn_serial += 1
	var spawn_token: int = authored_scene_spawn_serial
	effect.set_meta("authored_scene_released", false)
	effect.set_meta("authored_scene_token", spawn_token)
	effect.global_position = center
	effect.rotation = rotation_radians
	effect.z_index = z_index
	effect.scale = Vector2.ONE
	effect.modulate = Color.WHITE

	var sprite := effect.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		var base_scale: Vector2 = sprite.scale
		if effect.has_meta("authored_base_sprite_scale"):
			base_scale = effect.get_meta("authored_base_sprite_scale") as Vector2
		else:
			effect.set_meta("authored_base_sprite_scale", base_scale)
		sprite.material = null
		sprite.modulate = Color.WHITE
		sprite.centered = true
		sprite.position = Vector2.ZERO
		sprite.offset = scene_size * 0.5 - (offset_bounds.position + offset_bounds.size * 0.5)
		sprite.flip_h = mirror_horizontal
		if target_visible_size == Vector2.ONE:
			sprite.scale = base_scale * scale_multiplier
		else:
			var target_scale := Vector2(
				target_visible_size.x / max(1.0, visible_bounds.size.x),
				target_visible_size.y / max(1.0, visible_bounds.size.y)
			)
			sprite.scale = Vector2(base_scale.x * target_scale.x, base_scale.y * target_scale.y) if multiply_base_scale else target_scale
		play_effect_sprite(sprite, effect, scene_key, spawn_token)
	else:
		var tween := effect.create_tween()
		tween.tween_interval(fallback_duration)
		tween.tween_callback(_release_authored_scene_if_token.bind(effect, scene_key, spawn_token))

	var cleanup_duration: float = get_scene_animation_duration(scene, fallback_duration) + 0.08
	var cleanup_tween := effect.create_tween()
	cleanup_tween.tween_interval(cleanup_duration)
	cleanup_tween.tween_callback(_release_authored_scene_if_token.bind(effect, scene_key, spawn_token))

	return effect

static func play_effect_sprite(sprite: AnimatedSprite2D, owner_to_free: Node, scene_key: String = "", spawn_token: int = -1) -> void:
	_disconnect_animation_finished_callbacks(sprite)
	if sprite.sprite_frames != null:
		var animation_names: PackedStringArray = sprite.sprite_frames.get_animation_names()
		var animation_name: StringName = sprite.animation
		if animation_name == StringName() and animation_names.size() > 0:
			animation_name = StringName(animation_names[0])
		elif animation_name != StringName() and not animation_names.has(String(animation_name)) and animation_names.size() > 0:
			animation_name = StringName(animation_names[0])
		if animation_name != StringName():
			sprite.sprite_frames.set_animation_loop(animation_name, false)
			sprite.animation = animation_name
			sprite.frame = 0
			sprite.frame_progress = 0.0
			sprite.play(animation_name)
		else:
			sprite.play()
	else:
		sprite.play()
	sprite.animation_finished.connect(_release_authored_scene_if_token.bind(owner_to_free, scene_key, spawn_token), CONNECT_ONE_SHOT)

static func _disconnect_animation_finished_callbacks(sprite: AnimatedSprite2D) -> void:
	for connection in sprite.animation_finished.get_connections():
		var callback: Callable = connection.get("callable", Callable())
		if callback.is_valid():
			sprite.animation_finished.disconnect(callback)

static func _get_scene_pool_key(scene: PackedScene) -> String:
	if scene == null:
		return ""
	var path := scene.resource_path
	if path != "":
		return path
	return str(scene.get_instance_id())

static func _acquire_authored_scene(current_scene: Node, scene: PackedScene, scene_key: String) -> Node2D:
	var pool: Array = authored_scene_pools.get(scene_key, [])
	while not pool.is_empty():
		var pooled_effect: Variant = pool.pop_back()
		if not is_instance_valid(pooled_effect) or not (pooled_effect is Node2D):
			continue
		var effect := pooled_effect as Node2D
		if effect.is_queued_for_deletion():
			continue
		authored_scene_pools[scene_key] = pool
		_prepare_authored_scene(effect, current_scene)
		return effect
	authored_scene_pools[scene_key] = pool
	var effect := scene.instantiate() as Node2D
	if effect == null:
		return null
	current_scene.add_child(effect)
	_mark_temporary_effect(effect)
	return effect

static func _has_reusable_authored_scene(scene_key: String) -> bool:
	var pool: Array = authored_scene_pools.get(scene_key, [])
	for effect in pool:
		if is_instance_valid(effect) and effect is Node2D and not (effect as Node2D).is_queued_for_deletion():
			return true
	return false

static func _release_authored_scene(effect: Node, scene_key: String) -> void:
	if effect == null or not is_instance_valid(effect):
		return
	if bool(effect.get_meta("authored_scene_released", false)):
		return
	effect.set_meta("authored_scene_released", true)
	var sprite := effect.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		_disconnect_animation_finished_callbacks(sprite)
		sprite.stop()
	effect.hide()
	effect.remove_from_group("temporary_effects")
	var parent := effect.get_parent()
	if parent != null:
		parent.remove_child(effect)
	var pool: Array = authored_scene_pools.get(scene_key, [])
	if pool.size() < AUTHORED_SCENE_POOL_LIMIT_PER_SCENE and not pool.has(effect):
		pool.append(effect)
		authored_scene_pools[scene_key] = pool
	else:
		effect.queue_free()

static func _release_authored_scene_if_token(effect: Node, scene_key: String, spawn_token: int) -> void:
	if effect == null or not is_instance_valid(effect):
		return
	if int(effect.get_meta("authored_scene_token", -1)) != spawn_token:
		return
	_release_authored_scene(effect, scene_key)

static func _prepare_authored_scene(effect: Node2D, current_scene: Node) -> void:
	var parent := effect.get_parent()
	if parent != current_scene:
		if parent != null:
			parent.remove_child(effect)
		current_scene.add_child(effect)
	effect.show()
	effect.add_to_group("temporary_effects")
	PERFORMANCE_COUNTERS.add("temporary_effect_spawns", 1)

static func get_scene_animation_duration(scene: PackedScene, default_duration: float = 0.18) -> float:
	if scene == null:
		return default_duration
	var cache_key := "%s|%.3f" % [_get_scene_pool_key(scene), default_duration]
	if scene_animation_duration_cache.has(cache_key):
		return float(scene_animation_duration_cache[cache_key])
	var effect := scene.instantiate() as Node2D
	if effect == null:
		return default_duration
	var duration: float = default_duration
	var sprite := effect.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null and sprite.sprite_frames != null:
		var animation_name: StringName = sprite.animation
		var animation_names: PackedStringArray = sprite.sprite_frames.get_animation_names()
		if animation_name == StringName() and animation_names.size() > 0:
			animation_name = StringName(animation_names[0])
		elif animation_name != StringName() and not animation_names.has(String(animation_name)) and animation_names.size() > 0:
			animation_name = StringName(animation_names[0])
		if animation_name != StringName():
			var frame_count: int = sprite.sprite_frames.get_frame_count(animation_name)
			var total_relative_duration: float = 0.0
			for frame_index in range(frame_count):
				total_relative_duration += sprite.sprite_frames.get_frame_duration(animation_name, frame_index)
			var animation_speed: float = sprite.sprite_frames.get_animation_speed(animation_name) * max(sprite.speed_scale, 0.001)
			if animation_speed <= 0.001:
				animation_speed = 1.0
			duration = max(0.05, total_relative_duration / animation_speed)
	effect.queue_free()
	scene_animation_duration_cache[cache_key] = duration
	return duration

static func spawn_gunner_intersect_effect(
		owner,
		center: Vector2,
		direction: Vector2,
		visual_length: float,
		visual_thickness: float,
		gather_visual_length: float,
		gather_scene: PackedScene,
		beam_scene: PackedScene,
		scene_size: Vector2,
		gather_visible_bounds: Rect2,
		beam_visible_bounds: Rect2,
		effect_speed_scale: float,
		visual_scale: float
	) -> Node2D:
	return PLAYER_GUNNER_INTERSECT_EFFECTS.spawn_gunner_intersect_effect(owner, center, direction, visual_length, visual_thickness, gather_visual_length, gather_scene, beam_scene, scene_size, gather_visible_bounds, beam_visible_bounds, effect_speed_scale, visual_scale)


static func spawn_owner_gunner_intersect_effect(owner, center: Vector2, direction: Vector2, visual_length: float = 112.0, visual_thickness: float = 18.0, gather_visual_length: float = -1.0) -> Node2D:
	return PLAYER_GUNNER_INTERSECT_EFFECTS.spawn_owner_gunner_intersect_effect(owner, center, direction, visual_length, visual_thickness, gather_visual_length)

static func release_gunner_intersect_effect(effect: Node2D) -> void:
	PLAYER_GUNNER_INTERSECT_EFFECTS.release_gunner_intersect_effect(effect)

static func create_gunner_intersect_effect_part(scene: PackedScene, scene_size: Vector2, visible_bounds: Rect2, target_visible_size: Vector2, effect_speed_scale: float) -> Node2D:
	return PLAYER_GUNNER_INTERSECT_EFFECTS.create_gunner_intersect_effect_part(scene, scene_size, visible_bounds, target_visible_size, effect_speed_scale)

static func get_gunner_intersect_combo_duration(gather_scene: PackedScene, beam_scene: PackedScene, effect_speed_scale: float) -> float:
	return PLAYER_GUNNER_INTERSECT_EFFECTS.get_gunner_intersect_combo_duration(gather_scene, beam_scene, effect_speed_scale)


static func get_owner_gunner_intersect_combo_duration(owner) -> float:
	return PLAYER_GUNNER_INTERSECT_EFFECTS.get_owner_gunner_intersect_combo_duration(owner)

static func _play_gunner_intersect_beam(
		effect: Node2D,
		gather_root: Node2D,
		beam_scene: PackedScene,
		scene_size: Vector2,
		beam_visible_bounds: Rect2,
		beam_visible_size: Vector2,
		effect_speed_scale: float
	) -> void:
	PLAYER_GUNNER_INTERSECT_EFFECTS._play_gunner_intersect_beam(effect, gather_root, beam_scene, scene_size, beam_visible_bounds, beam_visible_size, effect_speed_scale)
