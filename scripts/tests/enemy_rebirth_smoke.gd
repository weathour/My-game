extends SceneTree

const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const PLAYER_TARGETING := preload("res://scripts/player/player_targeting.gd")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := RuntimeRoot.new()
	root.add_child(scene)
	current_scene = scene

	var target := TargetStub.new()
	target.global_position = Vector2(220.0, 0.0)
	scene.add_child(target)

	var enemy := ENEMY_SCENE.instantiate() as Node2D
	scene.add_child(enemy)
	enemy.target = target
	enemy.apply_enemy_profile("small_boss", ENEMY_ARCHETYPE_DATABASE.get_profile("small_boss", "smallboss_rebirth"))
	enemy.global_position = Vector2.ZERO

	_force_rebirth(enemy, 1, "first lethal hit should start first rebirth")
	enemy.target = null
	enemy._physics_process(enemy.rebirth_delay + 0.1)
	if enemy.rebirth_timer != 0.0:
		failures.append("rebirth timer should expire even if target is temporarily missing")
	var health_after_rebirth: float = enemy.current_health
	enemy.take_batched_damage(1.0)
	if enemy.current_health >= health_after_rebirth:
		failures.append("rebirth enemy should become damageable after timer expires")

	enemy.target = target
	_force_rebirth(enemy, 0, "second lethal hit should start final-life rebirth")
	enemy.target = null
	enemy._physics_process(enemy.rebirth_delay + 0.1)
	if enemy.rebirth_timer != 0.0:
		failures.append("final-life rebirth timer should expire without a valid target")

	enemy.target = target
	var selected_enemy: Node2D = PLAYER_TARGETING.get_closest_enemy(scene.get_runtime_enemies(), target.global_position)
	if selected_enemy != enemy:
		failures.append("final-life rebirth enemy should remain selectable in runtime targeting")
	var position_before_move: Vector2 = enemy.global_position
	enemy._physics_process(0.2)
	if enemy.global_position == position_before_move:
		failures.append("final-life rebirth enemy should resume movement after rebirth timer")
	var final_health: float = enemy.current_health
	enemy.take_batched_damage(1.0)
	if enemy.current_health >= final_health:
		failures.append("final-life rebirth enemy should be damageable")

	scene.queue_free()
	await process_frame
	current_scene = null

	if failures.is_empty():
		print("ENEMY_REBIRTH_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _force_rebirth(enemy: Node2D, expected_lives_remaining: int, message: String) -> void:
	enemy.take_batched_damage(enemy.max_health + 100.0)
	if int(enemy.get("rebirth_lives_remaining")) != expected_lives_remaining:
		failures.append("%s: unexpected lives remaining %d" % [message, int(enemy.get("rebirth_lives_remaining"))])
	if float(enemy.get("rebirth_timer")) <= 0.0:
		failures.append("%s: rebirth timer should be active" % message)
	if float(enemy.get("current_health")) != float(enemy.get("max_health")):
		failures.append("%s: rebirth should refill current health" % message)


class TargetStub:
	extends Node2D

	func apply_enemy_slow(_multiplier: float, _duration: float) -> void:
		pass


class RuntimeRoot:
	extends Node2D

	var active_enemies: Dictionary = {}

	func register_runtime_enemy(enemy: Node) -> void:
		active_enemies[enemy.get_instance_id()] = enemy

	func unregister_runtime_enemy(enemy: Node) -> void:
		active_enemies.erase(enemy.get_instance_id())

	func get_runtime_enemies() -> Array:
		var result: Array = []
		for enemy in active_enemies.values():
			if enemy != null and is_instance_valid(enemy):
				result.append(enemy)
		return result
