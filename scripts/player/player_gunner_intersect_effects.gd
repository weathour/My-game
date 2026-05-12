extends RefCounted

const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")
const EFFECT_PART_POOL_LIMIT_PER_SCENE := 48

static var effect_part_pools: Dictionary = {}
static var scene_animation_duration_cache: Dictionary = {}

static func _mark_temporary_effect(node: Node) -> void:
	if node != null:
		node.add_to_group("temporary_effects")
		PERFORMANCE_COUNTERS.add("temporary_effect_spawns", 1)

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
	var playback_direction := direction.normalized()
	if playback_direction.length_squared() <= 0.001:
		playback_direction = Vector2.RIGHT
	if gather_scene == null and beam_scene == null:
		return null
	# Gunner authored beams are already capped by the owning ability; do not let
	# the global temporary-effect guard make the skill completely invisible.

	var effect := Node2D.new()
	_mark_temporary_effect(effect)
	effect.name = "GunnerIntersect2Effect"
	effect.set_meta("gunner_intersect_released", false)
	effect.position = center - owner.global_position
	effect.rotation = playback_direction.angle()
	effect.z_index = 13
	owner.add_child(effect)

	var beam_visible_size: Vector2 = Vector2(visual_length, visual_thickness) * visual_scale
	var gather_length: float = gather_visual_length if gather_visual_length > 0.0 else visual_length
	var gather_visible_size: Vector2 = Vector2(gather_length, visual_thickness) * visual_scale
	var gather_root := create_gunner_intersect_effect_part(gather_scene, scene_size, gather_visible_bounds, gather_visible_size, effect_speed_scale)
	if gather_root != null:
		effect.add_child(gather_root)

	var gather_sprite: AnimatedSprite2D = null
	if gather_root != null:
		gather_sprite = gather_root.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if gather_sprite != null:
		gather_root.visible = true
		gather_sprite.play()
		var play_beam := func() -> void:
			_play_gunner_intersect_beam(effect, gather_root, beam_scene, scene_size, beam_visible_bounds, beam_visible_size, effect_speed_scale)
		gather_sprite.animation_finished.connect(play_beam, CONNECT_ONE_SHOT)
	else:
		_play_gunner_intersect_beam(effect, null, beam_scene, scene_size, beam_visible_bounds, beam_visible_size, effect_speed_scale)
	return effect


static func spawn_owner_gunner_intersect_effect(owner, center: Vector2, direction: Vector2, visual_length: float = 112.0, visual_thickness: float = 18.0, gather_visual_length: float = -1.0) -> Node2D:
	return spawn_gunner_intersect_effect(
		owner,
		center,
		direction,
		visual_length,
		visual_thickness,
		gather_visual_length,
		owner.GUNNER_INTERSECT_GATHER_EFFECT_SCENE,
		owner.GUNNER_INTERSECT_BEAM_EFFECT_SCENE,
		owner.GUNNER_INTERSECT_SCENE_SIZE,
		owner.GUNNER_INTERSECT_GATHER_VISIBLE_BOUNDS,
		owner.GUNNER_INTERSECT_BEAM_VISIBLE_BOUNDS,
		owner.GUNNER_INTERSECT_EFFECT_SPEED_SCALE,
		owner.GUNNER_INTERSECT_VISUAL_SCALE
	)


static func create_gunner_intersect_effect_part(scene: PackedScene, scene_size: Vector2, visible_bounds: Rect2, target_visible_size: Vector2, effect_speed_scale: float) -> Node2D:
	if scene == null:
		return null
	var scene_key := _get_scene_pool_key(scene)
	var root := _acquire_effect_part(scene, scene_key)
	if root == null:
		return null
	root.set_script(null)
	root.visible = true
	root.set_meta("gunner_intersect_part_released", false)
	root.position = Vector2.ZERO
	root.rotation = 0.0
	root.scale = Vector2.ONE
	root.modulate = Color.WHITE
	root.set_meta("gunner_intersect_pool_key", scene_key)
	var sprite := root.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return root
	_disconnect_animation_finished_callbacks(sprite)
	var authored_animation: StringName = sprite.animation
	if root.has_meta("authored_animation"):
		authored_animation = root.get_meta("authored_animation") as StringName
	else:
		root.set_meta("authored_animation", authored_animation)
	sprite.centered = true
	sprite.position = Vector2.ZERO
	sprite.modulate = Color.WHITE
	sprite.material = null
	sprite.offset = scene_size * 0.5 - Vector2(
		visible_bounds.position.x,
		visible_bounds.position.y + visible_bounds.size.y * 0.5
	)
	sprite.scale = Vector2(
		target_visible_size.x / max(1.0, visible_bounds.size.x),
		target_visible_size.y / max(1.0, visible_bounds.size.y)
	)
	sprite.speed_scale = effect_speed_scale
	if sprite.sprite_frames != null:
		var animation_names: PackedStringArray = sprite.sprite_frames.get_animation_names()
		var animation_name: StringName = authored_animation
		if animation_name == StringName() and animation_names.size() > 0:
			animation_name = StringName(animation_names[0])
		elif animation_name != StringName() and not animation_names.has(String(animation_name)) and animation_names.size() > 0:
			animation_name = StringName(animation_names[0])
		if animation_name != StringName():
			sprite.sprite_frames.set_animation_loop(animation_name, false)
			sprite.animation = animation_name
			sprite.frame = 0
			sprite.frame_progress = 0.0
			sprite.stop()
	return root


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


static func _acquire_effect_part(scene: PackedScene, scene_key: String) -> Node2D:
	var pool: Array = effect_part_pools.get(scene_key, [])
	while not pool.is_empty():
		var pooled_root: Variant = pool.pop_back()
		if not is_instance_valid(pooled_root) or not (pooled_root is Node2D):
			continue
		var root := pooled_root as Node2D
		if root.is_queued_for_deletion():
			continue
		effect_part_pools[scene_key] = pool
		_mark_temporary_effect(root)
		return root
	effect_part_pools[scene_key] = pool
	var root := scene.instantiate() as Node2D
	if root != null:
		_mark_temporary_effect(root)
	return root


static func _release_effect_part(root: Node2D) -> void:
	if root == null or not is_instance_valid(root):
		return
	if bool(root.get_meta("gunner_intersect_part_released", false)):
		return
	root.set_meta("gunner_intersect_part_released", true)
	var scene_key: String = str(root.get_meta("gunner_intersect_pool_key", ""))
	var sprite := root.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.stop()
	root.hide()
	root.remove_from_group("temporary_effects")
	var parent := root.get_parent()
	if parent != null:
		parent.remove_child(root)
	var pool: Array = effect_part_pools.get(scene_key, [])
	if pool.size() < EFFECT_PART_POOL_LIMIT_PER_SCENE:
		pool.append(root)
		effect_part_pools[scene_key] = pool
	else:
		root.queue_free()


static func release_gunner_intersect_effect(effect: Node2D) -> void:
	if effect == null or not is_instance_valid(effect):
		return
	if bool(effect.get_meta("gunner_intersect_released", false)):
		return
	effect.set_meta("gunner_intersect_released", true)
	for child in effect.get_children():
		var child_node := child as Node2D
		if child_node != null and child_node.has_meta("gunner_intersect_pool_key"):
			_release_effect_part(child_node)
	effect.queue_free()


static func get_gunner_intersect_combo_duration(gather_scene: PackedScene, beam_scene: PackedScene, effect_speed_scale: float) -> float:
	var gather_duration: float = get_scene_animation_duration(gather_scene, 0.18) / max(effect_speed_scale, 0.001)
	var beam_duration: float = get_scene_animation_duration(beam_scene, 0.18) / max(effect_speed_scale, 0.001)
	return max(0.05, gather_duration + beam_duration)


static func get_owner_gunner_intersect_combo_duration(owner) -> float:
	return get_gunner_intersect_combo_duration(owner.GUNNER_INTERSECT_GATHER_EFFECT_SCENE, owner.GUNNER_INTERSECT_BEAM_EFFECT_SCENE, owner.GUNNER_INTERSECT_EFFECT_SPEED_SCALE)


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


static func _play_gunner_intersect_beam(
		effect: Node2D,
		gather_root: Node2D,
		beam_scene: PackedScene,
		scene_size: Vector2,
		beam_visible_bounds: Rect2,
		beam_visible_size: Vector2,
		effect_speed_scale: float
	) -> void:
	if not is_instance_valid(effect):
		return
	if is_instance_valid(gather_root):
		_release_effect_part(gather_root)
	var beam_root := create_gunner_intersect_effect_part(beam_scene, scene_size, beam_visible_bounds, beam_visible_size, effect_speed_scale)
	if beam_root == null:
		release_gunner_intersect_effect(effect)
		return
	effect.add_child(beam_root)
	var beam_sprite := beam_root.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if beam_sprite != null:
		beam_root.visible = true
		beam_sprite.play()
		beam_sprite.animation_finished.connect(func() -> void:
			_release_effect_part(beam_root)
			release_gunner_intersect_effect(effect)
		, CONNECT_ONE_SHOT)
	else:
		var tween := effect.create_tween()
		tween.tween_interval(get_scene_animation_duration(beam_scene, 0.18))
		tween.tween_callback(func() -> void:
			_release_effect_part(beam_root)
			release_gunner_intersect_effect(effect)
		)
