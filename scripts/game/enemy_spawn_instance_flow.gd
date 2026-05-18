extends RefCounted

const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")
const SPAWN_POSITION_FLOW := preload("res://scripts/game/enemy_spawn_position_flow.gd")

const GLOBAL_ENEMY_HEALTH_MULTIPLIER := 2.04
const GLOBAL_ENEMY_PROJECTILE_DAMAGE_MULTIPLIER := 2.0


static func spawn_configured_enemy_at_position(main: Node, kind: String, archetype: String, health_multiplier: float, speed_multiplier: float, spawn_position: Vector2, damage_multiplier: float = 1.0) -> Node2D:
	if kind == "normal" and main.has_method("_can_spawn_runtime_group") and not bool(main._can_spawn_runtime_group("enemies", PERFORMANCE_GUARD.DEFAULT_ACTIVE_ENEMY_LIMIT)):
		return null
	var enemy: Variant = take_enemy_from_pool(main, kind)
	if enemy == null:
		enemy = main.enemy_scene.instantiate()
	if enemy == null:
		return null

	enemy.target = main.player
	enemy.projectile_scene = main.enemy_bullet_scene
	enemy.heart_pickup_scene = main.heart_pickup_scene
	if enemy.has_method("apply_enemy_profile"):
		enemy.apply_enemy_profile(kind, main.ENEMY_SPAWN_FLOW.get_enemy_profile(main, kind, archetype))
	enemy.max_health *= health_multiplier * GLOBAL_ENEMY_HEALTH_MULTIPLIER
	enemy.current_health = enemy.max_health
	enemy.speed *= speed_multiplier
	enemy.touch_damage *= damage_multiplier
	enemy.projectile_damage *= damage_multiplier * GLOBAL_ENEMY_PROJECTILE_DAMAGE_MULTIPLIER
	if enemy.has_signal("defeated"):
		disconnect_enemy_defeated_callbacks(enemy, main)
		enemy.defeated.connect(main._on_enemy_defeated.bind(enemy))

	enemy.global_position = SPAWN_POSITION_FLOW.clamp_position_to_spawn_bounds(main, spawn_position)
	main.add_child(enemy)
	enemy.show()
	enemy.set_process(true)
	enemy.set_physics_process(true)
	if enemy.has_method("activate_pooled_enemy"):
		enemy.activate_pooled_enemy()
	return enemy as Node2D


static func take_enemy_from_pool(main: Node, kind: String) -> Node:
	if kind != "normal":
		return null
	if main != null and main.has_method("take_runtime_enemy_from_pool"):
		var enemy: Node = main.take_runtime_enemy_from_pool()
		if enemy != null and is_instance_valid(enemy):
			return enemy
	return null


static func disconnect_enemy_defeated_callbacks(enemy: Node, main: Node) -> void:
	if enemy == null or main == null or not enemy.has_signal("defeated"):
		return
	for connection in enemy.defeated.get_connections():
		if connection is not Dictionary:
			continue
		var callback: Callable = (connection as Dictionary).get("callable", Callable())
		if callback.is_null():
			continue
		if callback.get_object() == main and callback.get_method() == "_on_enemy_defeated":
			enemy.defeated.disconnect(callback)
