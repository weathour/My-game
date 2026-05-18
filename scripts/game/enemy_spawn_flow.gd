extends RefCounted

const SPAWN_POSITION_FLOW := preload("res://scripts/game/enemy_spawn_position_flow.gd")
const SPAWN_WARNING_FLOW := preload("res://scripts/game/enemy_spawn_warning_flow.gd")
const SPAWN_INSTANCE_FLOW := preload("res://scripts/game/enemy_spawn_instance_flow.gd")
const SPAWN_MAINTENANCE_FLOW := preload("res://scripts/game/enemy_spawn_maintenance_flow.gd")
const SPAWN_TIMELINE_FLOW := preload("res://scripts/game/enemy_spawn_timeline_flow.gd")
const SPAWN_PROFILE_FLOW := preload("res://scripts/game/enemy_spawn_profile_flow.gd")
const SPAWN_PACK_FLOW := preload("res://scripts/game/enemy_spawn_pack_flow.gd")

static func setup_spawn_timer(main: Node) -> void:
	SPAWN_TIMELINE_FLOW.setup_spawn_timer(main)

static func update_spawn_curve(main: Node) -> void:
	SPAWN_TIMELINE_FLOW.update_spawn_curve(main)

static func handle_stage_events(main: Node) -> void:
	SPAWN_TIMELINE_FLOW.handle_stage_events(main)

static func spawn_enemy(main: Node) -> void:
	SPAWN_TIMELINE_FLOW.spawn_enemy(main)

static func _get_current_pack_interval(main: Node, wave_profile: Dictionary) -> float:
	return SPAWN_TIMELINE_FLOW.get_current_pack_interval(main, wave_profile)

static func spawn_special_enemy(main: Node, kind: String) -> Node2D:
	return SPAWN_PACK_FLOW.spawn_special_enemy(main, kind)

static func spawn_wave_pack(main: Node, kind: String, archetype: String, count: int, health_multiplier: float, speed_multiplier: float, damage_multiplier: float = 1.0) -> void:
	SPAWN_PACK_FLOW.spawn_wave_pack(main, kind, archetype, count, health_multiplier, speed_multiplier, damage_multiplier)

static func spawn_telegraphed_wave_plan(main: Node, spawn_plan: Array, health_multiplier: float, speed_multiplier: float, damage_multiplier: float = 1.0) -> void:
	SPAWN_PACK_FLOW.spawn_telegraphed_wave_plan(main, spawn_plan, health_multiplier, speed_multiplier, damage_multiplier)

static func spawn_configured_enemy(main: Node, kind: String, archetype: String, health_multiplier: float, speed_multiplier: float, spawn_angle: float = INF, distance_offset: float = 0.0, damage_multiplier: float = 1.0) -> Node2D:
	return SPAWN_PACK_FLOW.spawn_configured_enemy(main, kind, archetype, health_multiplier, speed_multiplier, spawn_angle, distance_offset, damage_multiplier)

static func spawn_configured_enemy_at(main: Node, kind: String, archetype: String, health_multiplier: float, speed_multiplier: float, spawn_position: Vector2, damage_multiplier: float = 1.0) -> Node2D:
	return SPAWN_PACK_FLOW.spawn_configured_enemy_at(main, kind, archetype, health_multiplier, speed_multiplier, spawn_position, damage_multiplier)

static func _spawn_configured_enemy_at_position(main: Node, kind: String, archetype: String, health_multiplier: float, speed_multiplier: float, spawn_position: Vector2, damage_multiplier: float = 1.0) -> Node2D:
	return SPAWN_INSTANCE_FLOW.spawn_configured_enemy_at_position(main, kind, archetype, health_multiplier, speed_multiplier, spawn_position, damage_multiplier)

static func get_wave_profile(main: Node) -> Dictionary:
	return SPAWN_PROFILE_FLOW.get_wave_profile(main)

static func get_player_growth_score(main: Node) -> float:
	return SPAWN_PROFILE_FLOW.get_player_growth_score(main)

static func get_expected_growth_score(main: Node) -> float:
	return SPAWN_PROFILE_FLOW.get_expected_growth_score(main)

static func get_cycle_elapsed_time(main: Node) -> float:
	return SPAWN_PROFILE_FLOW.get_cycle_elapsed_time(main)

static func _get_cycle_spawn_count_multiplier(main: Node) -> float:
	return SPAWN_PROFILE_FLOW.get_cycle_spawn_count_multiplier(main)

static func get_spawn_position(main: Node, angle: float, distance: float) -> Vector2:
	return SPAWN_POSITION_FLOW.get_spawn_position(main, angle, distance)

static func get_enemy_profile(main: Node, kind: String, archetype: String) -> Dictionary:
	return SPAWN_PROFILE_FLOW.get_enemy_profile(main, kind, archetype)

static func has_active_special_enemy(main: Node, kind: String) -> bool:
	return SPAWN_PROFILE_FLOW.has_active_special_enemy(main, kind)

static func _show_enemy_spawn_warning(main: Node, archetype: String, health_multiplier: float, speed_multiplier: float, damage_multiplier: float, spawn_position: Vector2) -> void:
	SPAWN_WARNING_FLOW.show_enemy_spawn_warning(main, archetype, health_multiplier, speed_multiplier, damage_multiplier, spawn_position)

static func _get_spawn_warning_batch(main: Node) -> Node:
	return SPAWN_WARNING_FLOW.get_spawn_warning_batch(main)

static func _spawn_after_warning(main: Node, archetype: String, health_multiplier: float, speed_multiplier: float, damage_multiplier: float, spawn_position: Vector2) -> void:
	SPAWN_WARNING_FLOW.spawn_after_warning(main, archetype, health_multiplier, speed_multiplier, damage_multiplier, spawn_position)

static func _take_enemy_from_pool(main: Node, kind: String) -> Node:
	return SPAWN_INSTANCE_FLOW.take_enemy_from_pool(main, kind)

static func _disconnect_enemy_defeated_callbacks(enemy: Node, main: Node) -> void:
	SPAWN_INSTANCE_FLOW.disconnect_enemy_defeated_callbacks(enemy, main)

static func reposition_distant_normal_enemies(main: Node) -> void:
	SPAWN_MAINTENANCE_FLOW.reposition_distant_normal_enemies(main)

static func _get_runtime_enemy_limit(main: Node) -> int:
	return SPAWN_PACK_FLOW.get_runtime_enemy_limit(main)

static func _get_spawn_bounds(main: Node) -> Rect2:
	return SPAWN_POSITION_FLOW.get_spawn_bounds(main)

static func _is_position_inside_spawn_bounds(main: Node, position: Vector2) -> bool:
	return SPAWN_POSITION_FLOW.is_position_inside_spawn_bounds(main, position)

static func _clamp_position_to_spawn_bounds(main: Node, position: Vector2) -> Vector2:
	return SPAWN_POSITION_FLOW.clamp_position_to_spawn_bounds(main, position)
