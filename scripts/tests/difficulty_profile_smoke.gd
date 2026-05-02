extends SceneTree

const DifficultyProfile := preload("res://scripts/game/difficulty_profile.gd")
const EnemyDirector := preload("res://scripts/enemy/enemy_director.gd")
const EnemyArchetypeDB := preload("res://scripts/enemy/enemy_archetype_database.gd")
const EnemyPressureModel := preload("res://scripts/build/build_enemy_pressure_model.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_profiles()
	_check_wave_and_enemy_scaling()
	_check_pressure_scaling()
	if failures.is_empty():
		print("DIFFICULTY_PROFILE_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_profiles() -> void:
	var profiles := DifficultyProfile.get_ordered_profiles()
	if profiles.size() != 4:
		failures.append("difficulty profile should expose 4 difficulties, got %d" % profiles.size())
	for expected_id in ["easy", "normal", "hard", "hell"]:
		var profile := DifficultyProfile.get_profile(expected_id)
		if str(profile.get("id", "")) != expected_id:
			failures.append("profile id mismatch for %s: %s" % [expected_id, str(profile)])
		if not bool(profile.get("available", false)):
			failures.append("difficulty %s should be available in first implementation" % expected_id)
		if int(profile.get("active_enemy_limit", 0)) <= 0 or int(profile.get("enemy_projectile_limit", 0)) <= 0:
			failures.append("difficulty %s should define performance limits" % expected_id)
	if DifficultyProfile.normalize_id("unknown") != "normal":
		failures.append("unknown difficulty should normalize to normal")
	if float(DifficultyProfile.get_profile("hell").get("spawn_interval_scale", 1.0)) >= float(DifficultyProfile.get_profile("easy").get("spawn_interval_scale", 1.0)):
		failures.append("hell should have denser spawn interval than easy")
	if float(DifficultyProfile.get_profile("hell").get("spawn_interval_scale", 1.0)) > 0.65:
		failures.append("hell spawn interval scale should be meaningfully aggressive after tuning")
	if float(DifficultyProfile.get_profile("hell").get("minimum_spawn_interval_scale", 1.0)) > 0.65:
		failures.append("hell minimum spawn interval should also be lowered so late-game density can exceed normal")
	if float(DifficultyProfile.get_profile("hell").get("enemy_damage_scale", 1.0)) < 1.45:
		failures.append("hell enemy damage scale should be high enough to matter")
	if float(DifficultyProfile.get_profile("hell").get("boss_attack_pressure_scale", 1.0)) < 1.60:
		failures.append("hell boss pressure should be a true high-pressure profile")

func _check_wave_and_enemy_scaling() -> void:
	var base_wave := EnemyDirector.get_wave_profile(420.0, EnemyDirector.get_default_elite_spawn_times(), 12.0, 12.0)
	var easy_wave := DifficultyProfile.apply_to_wave_profile(base_wave, DifficultyProfile.get_profile("easy"))
	var hell_wave := DifficultyProfile.apply_to_wave_profile(base_wave, DifficultyProfile.get_profile("hell"))
	if float((hell_wave.get("weights", {}) as Dictionary).get("dasher", 0.0)) <= float((easy_wave.get("weights", {}) as Dictionary).get("dasher", 0.0)):
		failures.append("hell wave should weight dashers above easy: easy %s hell %s" % [str(easy_wave), str(hell_wave)])
	if int(hell_wave.get("swarm_max", 0)) < int(easy_wave.get("swarm_max", 0)):
		failures.append("hell swarm max should not be below easy")

	var base_boss := EnemyArchetypeDB.get_profile("boss", "boss_spellcore")
	var easy_boss := DifficultyProfile.apply_to_enemy_profile("boss", base_boss, DifficultyProfile.get_profile("easy"))
	var hell_boss := DifficultyProfile.apply_to_enemy_profile("boss", base_boss, DifficultyProfile.get_profile("hell"))
	if float(hell_boss.get("boss_attack_pressure_scale", 1.0)) <= float(easy_boss.get("boss_attack_pressure_scale", 1.0)):
		failures.append("hell boss attack pressure should be above easy")
	# Boss attack cadence is applied at runtime through boss_attack_pressure_scale,
	# not by mutating every boss pattern interval in the static archetype row.

func _check_pressure_scaling() -> void:
	var easy := EnemyPressureModel.get_enemy_pressure_for_team_level(18, -1.0, "easy")
	var normal := EnemyPressureModel.get_enemy_pressure_for_team_level(18, -1.0, "normal")
	var hell := EnemyPressureModel.get_enemy_pressure_for_team_level(18, -1.0, "hell")
	if float(easy.get("total_pressure", 0.0)) >= float(normal.get("total_pressure", 0.0)):
		failures.append("easy pressure should be below normal: easy %.2f normal %.2f" % [float(easy.get("total_pressure", 0.0)), float(normal.get("total_pressure", 0.0))])
	if float(hell.get("total_pressure", 0.0)) <= float(normal.get("total_pressure", 0.0)):
		failures.append("hell pressure should be above normal: hell %.2f normal %.2f" % [float(hell.get("total_pressure", 0.0)), float(normal.get("total_pressure", 0.0))])
	if float(hell.get("total_pressure", 0.0)) < float(normal.get("total_pressure", 0.0)) * 1.55:
		failures.append("hell pressure should be at least 55%% above normal after tuning: hell %.2f normal %.2f" % [float(hell.get("total_pressure", 0.0)), float(normal.get("total_pressure", 0.0))])
	if float((hell.get("pressure", {}) as Dictionary).get("burst", 0.0)) <= float((easy.get("pressure", {}) as Dictionary).get("burst", 0.0)):
		failures.append("hell burst pressure should be above easy")
