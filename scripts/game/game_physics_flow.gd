extends RefCounted

const PERFORMANCE_FEATURE_FLAGS := preload("res://scripts/game/performance_feature_flags.gd")
const PERFORMANCE_RECORDER := preload("res://scripts/game/performance_recorder.gd")
const ENEMY_BATCH_SIMULATION := preload("res://scripts/enemies/enemy_batch_simulation.gd")
const ENEMY_PROJECTILE_BATCH_SIMULATION := preload("res://scripts/enemies/enemy_projectile_batch_simulation.gd")
const PICKUP_BATCH_SIMULATION := preload("res://scripts/game/pickup_batch_simulation.gd")


static func physics_process(main: Node, delta: float) -> void:
	if main == null or delta <= 0.0:
		return
	if main.get_tree() == null or main.get_tree().paused or bool(main.get("game_over")):
		return
	PERFORMANCE_RECORDER.begin_scope("physics_phase_ms")
	if PERFORMANCE_FEATURE_FLAGS.is_enabled(main, PERFORMANCE_FEATURE_FLAGS.FLAG_ENEMY_BATCH):
		PERFORMANCE_RECORDER.begin_scope("enemy_batch_ms")
		ENEMY_BATCH_SIMULATION.update_simple_normal_enemies(main, delta)
		PERFORMANCE_RECORDER.end_scope("enemy_batch_ms")
	if PERFORMANCE_FEATURE_FLAGS.is_enabled(main, PERFORMANCE_FEATURE_FLAGS.FLAG_ENEMY_PROJECTILE_BATCH):
		PERFORMANCE_RECORDER.begin_scope("enemy_projectile_batch_ms")
		ENEMY_PROJECTILE_BATCH_SIMULATION.update_enemy_projectiles(main, delta)
		PERFORMANCE_RECORDER.end_scope("enemy_projectile_batch_ms")
	if PERFORMANCE_FEATURE_FLAGS.is_enabled(main, PERFORMANCE_FEATURE_FLAGS.FLAG_PICKUP_BATCH):
		PERFORMANCE_RECORDER.begin_scope("pickup_batch_ms")
		PICKUP_BATCH_SIMULATION.update_pickups(main, delta)
		PERFORMANCE_RECORDER.end_scope("pickup_batch_ms")
	PERFORMANCE_RECORDER.end_scope("physics_phase_ms")
