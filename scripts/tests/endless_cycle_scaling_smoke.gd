extends SceneTree

const EnemyDirector := preload("res://scripts/enemy/enemy_director.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_cycle_multipliers()
	_check_ranged_profile_scaling_skips_boss()
	if failures.is_empty():
		print("ENDLESS_CYCLE_SCALING_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_cycle_multipliers() -> void:
	_expect_close(EnemyDirector.get_endless_cycle_health_multiplier(0), 1.0, "cycle 1 health")
	_expect_close(EnemyDirector.get_endless_cycle_damage_multiplier(0), 1.0, "cycle 1 damage")
	_expect_close(EnemyDirector.get_endless_cycle_spawn_count_multiplier(0), 0.88, "cycle 1 spawn count")
	_expect_close(EnemyDirector.get_endless_cycle_ranged_frequency_multiplier(0), 1.0, "cycle 1 ranged frequency")

	_expect_close(EnemyDirector.get_endless_cycle_health_multiplier(1), 1.5, "cycle 2 health")
	_expect_close(EnemyDirector.get_endless_cycle_damage_multiplier(1), 2.0, "cycle 2 damage")
	_expect_close(EnemyDirector.get_endless_cycle_spawn_count_multiplier(1), 2.0, "cycle 2 spawn count")
	_expect_close(EnemyDirector.get_endless_cycle_ranged_frequency_multiplier(1), 1.5, "cycle 2 ranged frequency")

	_expect_close(EnemyDirector.get_endless_cycle_health_multiplier(2), 2.0, "cycle 3 health")
	_expect_close(EnemyDirector.get_endless_cycle_damage_multiplier(2), 2.5, "cycle 3 damage")
	_expect_close(EnemyDirector.get_endless_cycle_spawn_count_multiplier(2), 2.5, "cycle 3 spawn count")
	_expect_close(EnemyDirector.get_endless_cycle_ranged_frequency_multiplier(2), 2.0, "cycle 3 ranged frequency")

func _check_ranged_profile_scaling_skips_boss() -> void:
	var profile := {
		"shot_interval": 2.4,
		"turret_bombard_interval": 3.0
	}
	var normal_profile: Dictionary = EnemyDirector.apply_endless_cycle_to_enemy_profile("normal", profile, 1)
	_expect_close(float(normal_profile.get("shot_interval", 0.0)), 1.6, "normal shot interval")
	_expect_close(float(normal_profile.get("turret_bombard_interval", 0.0)), 2.0, "normal turret interval")

	var boss_profile: Dictionary = EnemyDirector.apply_endless_cycle_to_enemy_profile("boss", profile, 1)
	_expect_close(float(boss_profile.get("shot_interval", 0.0)), 2.4, "boss shot interval")
	_expect_close(float(boss_profile.get("turret_bombard_interval", 0.0)), 3.0, "boss turret interval")

func _expect_close(actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s expected %.3f got %.3f" % [label, expected, actual])
