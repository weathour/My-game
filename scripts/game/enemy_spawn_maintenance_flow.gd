extends RefCounted

const SPAWN_POSITION_FLOW := preload("res://scripts/game/enemy_spawn_position_flow.gd")

const DISTANT_ENEMY_REPOSITION_DISTANCE := 980.0
const DISTANT_ENEMY_REPOSITION_BATCH := 12
const DISTANT_ENEMY_REPOSITION_SCAN_BATCH := 48


static func reposition_distant_normal_enemies(main: Node) -> void:
	if main == null or main.get_tree() == null or main.player == null:
		return
	var player_position: Vector2 = main.player.global_position
	var max_distance_squared: float = DISTANT_ENEMY_REPOSITION_DISTANCE * DISTANT_ENEMY_REPOSITION_DISTANCE
	var moved_count: int = 0
	var enemies: Array = main.get_runtime_enemies() if main.has_method("get_runtime_enemies") else main.get_tree().get_nodes_in_group("enemies")
	var enemy_count: int = enemies.size()
	if enemy_count <= 0:
		main.distant_enemy_maintenance_cursor = 0
		return
	var cursor: int = clamp(int(main.distant_enemy_maintenance_cursor), 0, max(0, enemy_count - 1))
	var scan_count: int = min(enemy_count, DISTANT_ENEMY_REPOSITION_SCAN_BATCH)
	for offset in range(scan_count):
		if moved_count >= DISTANT_ENEMY_REPOSITION_BATCH:
			break
		var enemy: Variant = enemies[(cursor + offset) % enemy_count]
		if enemy == null or not is_instance_valid(enemy) or enemy is not Node2D:
			continue
		if str(enemy.get("enemy_kind")) != "normal":
			continue
		if player_position.distance_squared_to((enemy as Node2D).global_position) <= max_distance_squared:
			continue
		var direction: Vector2 = player_position.direction_to((enemy as Node2D).global_position)
		if direction.length_squared() <= 0.001:
			direction = Vector2.RIGHT.rotated(main.rng.randf_range(0.0, TAU))
		var target_position: Vector2 = SPAWN_POSITION_FLOW.get_spawn_position(main, direction.angle(), main.spawn_distance + main.rng.randf_range(-24.0, 42.0))
		(enemy as Node2D).global_position = target_position
		moved_count += 1
	main.distant_enemy_maintenance_cursor = (cursor + scan_count) % enemy_count
