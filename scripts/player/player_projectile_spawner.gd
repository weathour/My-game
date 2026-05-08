extends RefCounted

const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")
const PROJECTILE_BATCH := preload("res://scripts/player/player_projectile_batch.gd")

const BATCH_NODE_NAME := "PlayerProjectileBatch"

static func apply_role_projectile_modifiers(owner, projectile: Node, role_id: String) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	if role_id != "gunner":
		return
	var barrage_level: float = 0.0
	if barrage_level <= 0:
		return
	projectile.set("speed_multiplier", owner._get_gunner_barrage_speed_multiplier(barrage_level))
	projectile.set("bounce_count", owner._get_gunner_barrage_bounce_count(barrage_level))
	if owner.has_method("_get_gunner_barrage_split_count"):
		projectile.set("split_count", owner._get_gunner_barrage_split_count(barrage_level))
	projectile.set("hit_radius_multiplier", 1.2)

static func spawn_bullet(owner, bullet_scene: PackedScene, target_enemy: Node2D, damage_amount: float, color: Color, role_id: String = "", origin: Variant = null):
	if not _can_spawn_player_projectile(owner):
		return null
	if bullet_scene == null:
		return null
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		return null
	var bullet = _acquire_projectile(current_scene, bullet_scene)
	if bullet == null:
		return null

	var start_position: Vector2 = _resolve_origin(owner, origin)
	var role := _resolve_role_id(owner, role_id)
	var shot_direction := start_position.direction_to(target_enemy.global_position)
	_configure_projectile(bullet, {
		"pool_key": _get_projectile_pool_key(bullet_scene),
		"position": start_position,
		"source_origin_position": start_position,
		"direction": shot_direction,
		"target": target_enemy,
		"damage": damage_amount,
		"visual_color": color,
		"source_player": owner,
		"source_role_id": role
	})
	apply_role_projectile_modifiers(owner, bullet, str(bullet.source_role_id))
	current_scene.add_child(bullet)
	return bullet

static func spawn_directional_bullet(owner, bullet_scene: PackedScene, direction: Vector2, damage_amount: float, color: Color, role_id: String = "", origin: Variant = null):
	return spawn_directional_bullet_from_scene(owner, bullet_scene, direction, damage_amount, color, role_id, origin)

static func spawn_directional_bullet_from_scene(owner, projectile_scene: PackedScene, direction: Vector2, damage_amount: float, color: Color, role_id: String = "", origin: Variant = null):
	if not _can_spawn_player_projectile(owner):
		return null
	if projectile_scene == null:
		return null
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		return null
	var bullet = _acquire_projectile(current_scene, projectile_scene)
	if bullet == null:
		return null

	var start_position: Vector2 = _resolve_origin(owner, origin)
	var role := _resolve_role_id(owner, role_id)
	var shot_direction := direction.normalized()
	if shot_direction.length_squared() <= 0.001:
		shot_direction = Vector2.RIGHT
	_configure_projectile(bullet, {
		"pool_key": _get_projectile_pool_key(projectile_scene),
		"position": start_position,
		"source_origin_position": start_position,
		"direction": shot_direction,
		"target": null,
		"damage": damage_amount,
		"visual_color": color,
		"source_player": owner,
		"source_role_id": role
	})
	apply_role_projectile_modifiers(owner, bullet, str(bullet.source_role_id))
	current_scene.add_child(bullet)
	return bullet

static func spawn_batched_directional_bullet(owner, direction: Vector2, damage_amount: float, color: Color, role_id: String = "", origin: Variant = null, config: Dictionary = {}) -> bool:
	var batch: Node = _get_or_create_batch(owner)
	if batch == null:
		return false
	var shot_direction := direction.normalized()
	if shot_direction.length_squared() <= 0.001:
		shot_direction = Vector2.RIGHT
	var start_position := _resolve_origin(owner, origin)
	return bool(batch.add_projectile({
		"position": start_position,
		"source_origin": start_position,
		"direction": shot_direction,
		"damage": damage_amount,
		"color": color,
		"role_id": _resolve_role_id(owner, role_id),
		"speed": float(config.get("speed", 620.0)),
		"lifetime": float(config.get("lifetime", 1.0)),
		"hit_radius": float(config.get("hit_radius", 10.0)),
		"visual_radius": float(config.get("visual_radius", 4.2)),
		"visual_min_diameter": float(config.get("visual_min_diameter", 8.0)),
		"visual_outline_color": config.get("visual_outline_color", Color(1.0, 1.0, 1.0, 0.0)),
		"visual_outline_width": float(config.get("visual_outline_width", 0.0)),
		"enemy_hit_radius_scale": float(config.get("enemy_hit_radius_scale", 0.2)),
		"enemy_hit_radius_min": float(config.get("enemy_hit_radius_min", 4.0)),
		"enemy_hit_radius_max": float(config.get("enemy_hit_radius_max", 12.0)),
		"vulnerability_bonus": float(config.get("vulnerability_bonus", 0.0)),
		"vulnerability_duration": float(config.get("vulnerability_duration", 0.0)),
		"slow_multiplier": float(config.get("slow_multiplier", 1.0)),
		"slow_duration": float(config.get("slow_duration", 0.0)),
		"pierce_count": int(config.get("pierce_count", 0)),
		"wave_amplitude": float(config.get("wave_amplitude", 0.0)),
		"wave_frequency": float(config.get("wave_frequency", 0.0)),
		"wave_phase": float(config.get("wave_phase", 0.0)),
		"wave_elapsed": 0.0,
		"wave_travel_distance": 0.0,
		"wave_origin": start_position,
		"wave_forward": shot_direction,
		"wave_side": shot_direction.orthogonal().normalized()
	}))

static func _can_spawn_player_projectile(owner) -> bool:
	if owner == null or owner.get_tree() == null:
		return false
	var root: Node = owner.get_tree().current_scene
	if root == null:
		return true
	if root.has_method("_can_spawn_runtime_group"):
		return bool(root._can_spawn_runtime_group("player_projectiles", PERFORMANCE_GUARD.DEFAULT_PLAYER_PROJECTILE_LIMIT))
	return PERFORMANCE_GUARD.can_spawn_in_group(root, "player_projectiles", PERFORMANCE_GUARD.DEFAULT_PLAYER_PROJECTILE_LIMIT)

static func _resolve_role_id(owner, role_id: String) -> String:
	if role_id != "":
		return role_id
	if owner != null and owner.has_method("_get_active_role"):
		return str(owner._get_active_role().get("id", ""))
	return ""

static func _resolve_origin(owner, origin: Variant) -> Vector2:
	if origin is Vector2:
		return origin
	if owner is Node2D:
		return (owner as Node2D).global_position
	return Vector2.ZERO

static func _get_projectile_pool_key(projectile_scene: PackedScene) -> String:
	if projectile_scene == null:
		return "default"
	if projectile_scene.resource_path != "":
		return projectile_scene.resource_path
	return "projectile_scene:%s" % str(projectile_scene.get_instance_id())

static func _acquire_projectile(current_scene: Node, projectile_scene: PackedScene):
	if current_scene != null and current_scene.has_method("take_runtime_player_projectile_from_pool"):
		var pooled = current_scene.take_runtime_player_projectile_from_pool(_get_projectile_pool_key(projectile_scene))
		if pooled != null and is_instance_valid(pooled):
			return pooled
	return projectile_scene.instantiate()

static func _configure_projectile(projectile, config: Dictionary) -> void:
	if projectile == null:
		return
	if projectile.has_method("reset_projectile"):
		projectile.reset_projectile(config)
		return
	for key in config.keys():
		if key == "pool_key":
			continue
		projectile.set(key, config[key])

static func _get_or_create_batch(owner) -> Node:
	if owner == null or owner.get_tree() == null:
		return null
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		return null
	var batch: Node = current_scene.get_node_or_null(BATCH_NODE_NAME)
	if batch != null:
		return batch
	batch = PROJECTILE_BATCH.new()
	batch.name = BATCH_NODE_NAME
	current_scene.add_child(batch)
	batch.configure(owner)
	return batch
