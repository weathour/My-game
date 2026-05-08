extends SceneTree

const PlayerTargeting := preload("res://scripts/player/player_targeting.gd")

class OwnerStub:
	extends Node2D
	var enemies: Array = []

	func _get_live_enemies() -> Array:
		return enemies

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
	_check_freed_cached_target_is_ignored()
	for enemy in enemies:
		if is_instance_valid(enemy):
			(enemy as Node2D).free()
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

func _check_freed_cached_target_is_ignored() -> void:
	var owner := OwnerStub.new()
	owner.global_position = Vector2.ZERO
	var cached_enemy := _make_enemy(Vector2(12.0, 0.0), 10.0)
	owner.enemies = [cached_enemy]
	if PlayerTargeting.get_owner_closest_enemy(owner) != cached_enemy:
		failures.append("owner closest cache should record initial target")
	cached_enemy.free()
	owner.enemies = []
	var target_after_free: Node2D = PlayerTargeting.get_owner_closest_enemy(owner)
	if target_after_free != null:
		failures.append("owner closest cache should drop freed cached targets")
	owner.free()
