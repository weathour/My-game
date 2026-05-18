extends RefCounted

const ENEMY_DIRECTOR := preload("res://scripts/enemy/enemy_director.gd")
const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")
const SPAWN_POSITION_FLOW := preload("res://scripts/game/enemy_spawn_position_flow.gd")
const SPAWN_WARNING_FLOW := preload("res://scripts/game/enemy_spawn_warning_flow.gd")
const SPAWN_INSTANCE_FLOW := preload("res://scripts/game/enemy_spawn_instance_flow.gd")


static func spawn_special_enemy(main: Node, kind: String) -> Node2D:
	var health_multiplier: float = main._get_spawn_enemy_health_multiplier(kind)
	var speed_multiplier: float = main._get_spawn_enemy_speed_multiplier()
	var damage_multiplier: float = main._get_spawn_enemy_damage_multiplier()
	var archetype: String = ENEMY_DIRECTOR.pick_special_archetype(kind, main.survival_time, main.spawned_small_boss_count, main.rng)
	return spawn_configured_enemy(main, kind, archetype, health_multiplier, speed_multiplier, INF, 0.0, damage_multiplier)


static func spawn_wave_pack(main: Node, kind: String, archetype: String, count: int, health_multiplier: float, speed_multiplier: float, damage_multiplier: float = 1.0) -> void:
	var spawn_layout: Array = ENEMY_DIRECTOR.pick_wave_spawn_layout(count, main.rng)
	for spawn_entry in spawn_layout:
		spawn_configured_enemy(
			main,
			kind,
			archetype,
			health_multiplier,
			speed_multiplier,
			float(spawn_entry.get("angle", 0.0)),
			float(spawn_entry.get("distance_offset", 0.0)),
			damage_multiplier
		)


static func spawn_telegraphed_wave_plan(main: Node, spawn_plan: Array, health_multiplier: float, speed_multiplier: float, damage_multiplier: float = 1.0) -> void:
	for pack in spawn_plan:
		if pack is not Dictionary:
			continue
		var archetype: String = str((pack as Dictionary).get("archetype", "chaser"))
		var count: int = int((pack as Dictionary).get("count", 1))
		var spawn_layout: Array = ENEMY_DIRECTOR.pick_wave_spawn_layout(count, main.rng)
		for spawn_entry in spawn_layout:
			var angle: float = float(spawn_entry.get("angle", 0.0))
			var distance: float = ENEMY_DIRECTOR.get_spawn_distance("normal", main.spawn_distance, float(spawn_entry.get("distance_offset", 0.0)))
			var spawn_position: Vector2 = SPAWN_POSITION_FLOW.get_spawn_position(main, angle, distance)
			SPAWN_WARNING_FLOW.show_enemy_spawn_warning(
				main,
				archetype,
				health_multiplier,
				speed_multiplier,
				damage_multiplier,
				spawn_position
			)


static func spawn_configured_enemy(main: Node, kind: String, archetype: String, health_multiplier: float, speed_multiplier: float, spawn_angle: float = INF, distance_offset: float = 0.0, damage_multiplier: float = 1.0) -> Node2D:
	var angle: float = spawn_angle if is_finite(spawn_angle) else main.rng.randf_range(0.0, TAU)
	var distance: float = ENEMY_DIRECTOR.get_spawn_distance(kind, main.spawn_distance, distance_offset)
	return SPAWN_INSTANCE_FLOW.spawn_configured_enemy_at_position(main, kind, archetype, health_multiplier, speed_multiplier, SPAWN_POSITION_FLOW.get_spawn_position(main, angle, distance), damage_multiplier)


static func spawn_configured_enemy_at(main: Node, kind: String, archetype: String, health_multiplier: float, speed_multiplier: float, spawn_position: Vector2, damage_multiplier: float = 1.0) -> Node2D:
	return SPAWN_INSTANCE_FLOW.spawn_configured_enemy_at_position(main, kind, archetype, health_multiplier, speed_multiplier, spawn_position, damage_multiplier)


static func get_runtime_enemy_limit(main: Node) -> int:
	if main != null and main.has_method("_get_runtime_group_limit"):
		return int(main._get_runtime_group_limit("enemies", PERFORMANCE_GUARD.DEFAULT_ACTIVE_ENEMY_LIMIT))
	return PERFORMANCE_GUARD.DEFAULT_ACTIVE_ENEMY_LIMIT
