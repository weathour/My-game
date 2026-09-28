extends SceneTree

const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const ENEMY := preload("res://scenes/enemy.tscn")
const BODY := preload("res://scripts/enemies/enemy_stalwart_body.gd")
const BEHAVIOR := preload("res://scripts/enemies/enemy_trait_behavior.gd")
const MOVEMENT := preload("res://scripts/enemies/enemy_movement.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for tier in [0, 1, 2, 3, 8]:
		# 各难度用例分别占一帧，避免共享预警创建预算被前一个用例耗尽。
		await physics_frame
		if not _check_tier(tier):
			quit(1)
			return
	print("ENEMY_DASHER_CHARGE_SMOKE_OK")
	quit(0)


func _check_tier(tier: int) -> bool:
	var scene := RuntimeRoot.new()
	scene.difficulty_profile = {"tier": tier} if tier > 0 else {"id": "normal"}
	var windup: float = 0.3 if tier >= 3 else 0.6
	var dash_speed: float = 300.0 if tier >= 3 else 250.0
	root.add_child(scene)
	current_scene = scene
	var target := Node2D.new()
	scene.add_child(target)
	var enemy = ENEMY.instantiate()
	scene.add_child(enemy)
	enemy.apply_enemy_profile("normal", DATABASE.get_profile("normal", "dasher"))
	enemy.target = target
	enemy.current_health = enemy.max_health
	enemy._cached_direction_to_target = Vector2.RIGHT
	assert(is_equal_approx(enemy.attack, 20.0))
	assert(is_equal_approx(enemy.armor, 10.0))
	assert(is_equal_approx(enemy.max_health, 60.0))
	assert(is_zero_approx(enemy.damage_reduction_rate))
	assert(is_equal_approx(enemy.speed, 80.0))
	assert(is_equal_approx(BODY.try_trigger(enemy), 30.0))
	BODY.tick(enemy, 1.0)
	BEHAVIOR.update_behavior_state(enemy, 10.0)
	assert(is_equal_approx(enemy.dash_windup_remaining, windup))
	assert(MOVEMENT.compute_velocity(enemy, 0.0) == Vector2.ZERO)
	enemy._update_status_visuals()
	assert(enemy.dash_warning_ring.scale.is_equal_approx(Vector2.ONE * 1.5))
	assert(is_equal_approx(enemy.dash_warning_rect.color.a, 0.16))
	assert(is_equal_approx(enemy.dash_warning_rect.polygon[1].x - enemy.dash_warning_rect.polygon[0].x, 500.0))
	BEHAVIOR.update_behavior_state(enemy, windup * 0.5)
	assert(is_zero_approx(enemy.dash_remaining))
	var windup_data: Dictionary = JSON.parse_string(JSON.stringify(enemy.get_save_data()))
	enemy.apply_save_data(windup_data, target)
	assert(is_equal_approx(enemy.dash_windup_remaining, windup * 0.5))
	enemy._update_status_visuals()
	assert(is_equal_approx(enemy.dash_warning_rect.color.a, 0.25))
	BEHAVIOR.update_behavior_state(enemy, windup * 0.5)
	assert(is_equal_approx(enemy.dash_remaining, 2.0))
	assert(is_equal_approx(enemy.dash_distance_remaining, 500.0))
	assert(is_equal_approx(BODY.try_trigger(enemy), 50.0))
	assert(is_zero_approx(BODY.try_trigger(enemy)))
	# Spawn speed scaling and moving targets must not alter fixed dash speed/direction.
	enemy.speed *= 2.0
	enemy.slow_multiplier = 0.5
	enemy.skull_soldier_speed_multiplier = 2.0
	enemy._cached_direction_to_target = Vector2.DOWN
	enemy.velocity = MOVEMENT.compute_velocity(enemy, 0.0)
	assert(enemy.velocity.is_equal_approx(Vector2(dash_speed, 0.0)))
	enemy._physics_process(0.4)
	enemy.batch_physics_process(0.4)
	assert(enemy.position.is_equal_approx(Vector2(dash_speed * 0.8, 0.0)))
	var remaining_distance: float = 500.0 - dash_speed * 0.8
	assert(is_equal_approx(enemy.dash_distance_remaining, remaining_distance))
	var data: Dictionary = JSON.parse_string(JSON.stringify(enemy.get_save_data()))
	var restored = ENEMY.instantiate()
	scene.add_child(restored)
	restored.apply_save_data(data, target)
	assert(is_equal_approx(restored.dash_remaining, 1.2))
	assert(is_equal_approx(restored.dash_distance_remaining, remaining_distance))
	restored.velocity = MOVEMENT.compute_velocity(restored, 0.0)
	assert(restored.velocity.is_equal_approx(Vector2(dash_speed, 0.0)))
	# An oversized frame must stop at the maximum distance.
	restored._apply_direct_motion(5.0)
	assert(restored.position.is_equal_approx(Vector2(500.0, 0.0)))
	assert(is_zero_approx(restored.dash_remaining))
	assert(is_equal_approx(restored.dash_timer, 10.0))
	BODY.tick(restored, 1.0)
	assert(is_equal_approx(BODY.try_trigger(restored), 30.0))
	BEHAVIOR.update_behavior_state(restored, 9.5)
	assert(is_zero_approx(restored.dash_windup_remaining))
	BEHAVIOR.update_behavior_state(restored, 0.5)
	assert(is_equal_approx(restored.dash_windup_remaining, windup))
	# 池复用为精英时，两种冲锋共享本局N层的前摇与固定速度。
	enemy._prepare_for_pool()
	enemy.apply_enemy_profile("elite", DATABASE.get_profile("elite", "elite_ram_trail"))
	enemy.target = target
	enemy._cached_direction_to_target = Vector2.RIGHT
	enemy.current_health = enemy.max_health
	BEHAVIOR.update_behavior_state(enemy, 10.0)
	assert(is_equal_approx(enemy.dash_windup_remaining, windup))
	BEHAVIOR.update_behavior_state(enemy, windup * 0.5)
	var elite_windup_data: Dictionary = JSON.parse_string(JSON.stringify(enemy.get_save_data()))
	enemy.apply_save_data(elite_windup_data, target)
	assert(is_equal_approx(enemy.dash_windup_remaining, windup * 0.5))
	BEHAVIOR.update_behavior_state(enemy, windup * 0.5)
	assert(MOVEMENT.compute_velocity(enemy, 0.0).is_equal_approx(Vector2(dash_speed, 0.0)))
	BEHAVIOR.update_behavior_state(enemy, 0.1)
	var elite_origin: Vector2 = enemy.position
	enemy._apply_direct_motion(0.1)
	assert(enemy.position.is_equal_approx(elite_origin + Vector2(dash_speed * 0.1, 0.0)))
	assert(is_equal_approx(enemy.dash_remaining, 1.9))
	assert(is_equal_approx(BODY.try_trigger(enemy), enemy.attack * 2.5))
	var elite_dash_data: Dictionary = JSON.parse_string(JSON.stringify(enemy.get_save_data()))
	enemy.apply_save_data(elite_dash_data, target)
	assert(MOVEMENT.compute_velocity(enemy, 0.0).is_equal_approx(Vector2(dash_speed, 0.0)))
	enemy._apply_direct_motion(5.0)
	assert(enemy.position.is_equal_approx(elite_origin + Vector2(500.0, 0.0)))
	assert(is_zero_approx(enemy.dash_remaining))
	assert(is_equal_approx(enemy.dash_timer, 10.0))
	for child in scene.get_children():
		if child.get_script() == preload("res://scripts/enemies/elite_charge_ground.gd"):
			assert(child.size.is_equal_approx(Vector2(200.0, 80.0)))
	scene.free()
	current_scene = null
	return true


class RuntimeRoot:
	extends Node2D
	var difficulty_profile: Dictionary = {}
