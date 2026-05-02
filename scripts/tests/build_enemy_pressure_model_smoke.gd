extends SceneTree

const EnemyPressureModel := preload("res://scripts/build/build_enemy_pressure_model.gd")
const FirstBatchModel := preload("res://scripts/build/build_first_batch_model.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_pressure_shape_and_growth()
	_check_build_pressure_fit()
	if failures.is_empty():
		print("BUILD_ENEMY_PRESSURE_MODEL_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_pressure_shape_and_growth() -> void:
	var p6 := EnemyPressureModel.get_enemy_pressure_for_team_level(6)
	var p12 := EnemyPressureModel.get_enemy_pressure_for_team_level(12)
	var p18 := EnemyPressureModel.get_enemy_pressure_for_team_level(18)
	var p25 := EnemyPressureModel.get_enemy_pressure_for_team_level(25)
	for payload in [p6, p12, p18, p25]:
		var pressure: Dictionary = (payload as Dictionary).get("pressure", {})
		if pressure.is_empty():
			failures.append("enemy pressure payload should include pressure map: %s" % str(payload))
		for pressure_type in EnemyPressureModel.PRESSURE_TYPES:
			if not pressure.has(pressure_type):
				failures.append("pressure map missing %s: %s" % [pressure_type, str(pressure)])
		if float((payload as Dictionary).get("spawn_interval", 0.0)) <= 0.0:
			failures.append("spawn interval should be positive: %s" % str(payload))
		if float((payload as Dictionary).get("total_pressure", 0.0)) <= 0.0:
			failures.append("total pressure should be positive: %s" % str(payload))
	if float(p25.get("total_pressure", 0.0)) <= float(p6.get("total_pressure", 0.0)) * 1.8:
		failures.append("late enemy pressure should be much higher than early pressure: L6 %.2f L25 %.2f" % [float(p6.get("total_pressure", 0.0)), float(p25.get("total_pressure", 0.0))])
	if float((p25.get("pressure", {}) as Dictionary).get("ranged", 0.0)) <= float((p6.get("pressure", {}) as Dictionary).get("ranged", 0.0)):
		failures.append("ranged pressure should increase by late game")
	if float((p25.get("pressure", {}) as Dictionary).get("durability", 0.0)) <= float((p6.get("pressure", {}) as Dictionary).get("durability", 0.0)):
		failures.append("durability pressure should increase by late game")

func _check_build_pressure_fit() -> void:
	var empty := FirstBatchModel.make_state(18)
	var developed := FirstBatchModel.make_state(18)
	for card_id in ["mag_starfall_seed", "mag_mana_tide", "mag_frost_seal", "mag_field_convergence", "mag_guardian_puppet", "gun_entry_barrage", "gun_fireline_mark", "res_gun_mag_orbital_lock"]:
		developed = FirstBatchModel.apply_card_pick(developed, card_id)
	var pressure := EnemyPressureModel.get_enemy_pressure_for_team_level(18)
	var empty_fit := EnemyPressureModel.evaluate_build_against_pressure(empty, pressure)
	var developed_fit := EnemyPressureModel.evaluate_build_against_pressure(developed, pressure)
	if float(developed_fit.get("coverage_ratio", 0.0)) <= float(empty_fit.get("coverage_ratio", 0.0)):
		failures.append("developed build should cover more enemy pressure than empty build: empty %s developed %s" % [str(empty_fit), str(developed_fit)])
	if str(developed_fit.get("dominant_uncovered", "")) == "":
		failures.append("pressure fit should report dominant uncovered pressure")
