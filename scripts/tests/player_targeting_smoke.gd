extends SceneTree

const PlayerTargeting := preload("res://scripts/player/player_targeting.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var enemies: Array = [
		_make_enemy(Vector2(10.0, 0.0), 10.0),
		_make_enemy(Vector2(80.0, 0.0), 10.0),
		_make_enemy(Vector2(92.0, 10.0), 10.0),
		_make_enemy(Vector2(420.0, 0.0), 10.0),
	]
	if PlayerTargeting.get_closest_enemy(enemies, Vector2.ZERO) != enemies[0]:
		failures.append("closest enemy should use nearest squared distance")
	if PlayerTargeting.get_farthest_enemy(enemies, Vector2.ZERO) != enemies[3]:
		failures.append("farthest enemy should use farthest squared distance")
	var near_targets: Array = PlayerTargeting.get_enemy_targets(enemies, Vector2.ZERO, 2, false)
	if near_targets.size() != 2 or near_targets[0] != enemies[0] or near_targets[1] != enemies[1]:
		failures.append("nearest target selection should preserve ordering")
	var far_targets: Array = PlayerTargeting.get_enemy_targets(enemies, Vector2.ZERO, 2, true)
	if far_targets.size() != 2 or far_targets[0] != enemies[3] or far_targets[1] != enemies[2]:
		failures.append("farthest target selection should preserve ordering")
	var cluster_center: Vector2 = PlayerTargeting.get_enemy_cluster_center(enemies)
	if cluster_center.distance_squared_to(Vector2(420.0, 0.0)) < 900.0:
		failures.append("cluster center should favor dense local enemies")
	for enemy in enemies:
		(enemy as Node2D).queue_free()
	if failures.is_empty():
		print("PLAYER_TARGETING_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _make_enemy(position: Vector2, contact_radius: float) -> Node2D:
	var enemy := Node2D.new()
	enemy.global_position = position
	enemy.set("contact_radius", contact_radius)
	return enemy
