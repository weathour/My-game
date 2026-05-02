extends RefCounted

const ENEMY_DIRECTOR := preload("res://scripts/enemy/enemy_director.gd")
const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const DIFFICULTY_PROFILE := preload("res://scripts/game/difficulty_profile.gd")

const DEFAULT_STAGE_DURATION := 720.0

const TEAM_LEVEL_TO_TIME := {
	6: 110.0,
	12: 240.0,
	18: 420.0,
	25: 660.0
}

const PRESSURE_TYPES := [
	"density",
	"durability",
	"contact",
	"ranged",
	"burst",
	"mobility",
	"control",
	"boss"
]

const ARCHETYPE_PRESSURE_TAGS := {
	"chaser": {"density": 0.7, "contact": 0.8, "mobility": 0.35},
	"runner": {"density": 0.65, "contact": 0.7, "mobility": 1.0, "burst": 0.25},
	"swarm": {"density": 1.35, "contact": 0.55, "mobility": 0.8},
	"brute": {"durability": 1.0, "contact": 0.9, "control": 0.2},
	"shooter": {"ranged": 1.0, "density": 0.25, "control": 0.2},
	"dasher": {"burst": 1.0, "mobility": 1.0, "contact": 0.75},
	"shotgunner": {"ranged": 1.15, "burst": 0.7, "durability": 0.5},
	"elite_ram_trail": {"burst": 1.3, "mobility": 1.1, "durability": 1.5, "contact": 1.0},
	"elite_splitshot": {"ranged": 1.45, "burst": 0.9, "durability": 1.4, "control": 0.35},
	"smallboss_glutton": {"durability": 2.0, "boss": 1.2, "control": 0.55, "contact": 0.65},
	"smallboss_rebirth": {"durability": 1.8, "boss": 1.2, "control": 0.75, "mobility": 0.55},
	"smallboss_turret": {"ranged": 1.6, "boss": 1.2, "burst": 0.7, "control": 0.55},
	"boss_spellcore": {"boss": 2.2, "ranged": 1.8, "burst": 1.4, "durability": 2.0, "control": 0.8}
}

const POSITION_COVERAGE := {
	"damage": {"density": 0.65, "durability": 0.85, "boss": 0.72},
	"control": {"density": 0.75, "mobility": 0.75, "burst": 0.45, "contact": 0.35},
	"survival": {"contact": 0.85, "burst": 0.75, "boss": 0.45},
	"support": {"ranged": 0.45, "control": 0.55, "burst": 0.35, "boss": 0.35},
	"summon": {"density": 0.55, "contact": 0.65, "ranged": 0.35, "boss": 0.25},
	"resource": {"durability": 0.35, "boss": 0.65, "ranged": 0.25},
	"mobility": {"ranged": 0.65, "burst": 0.55, "contact": 0.4, "mobility": 0.35}
}

const TAG_COVERAGE := {
	"entry_burst": {"density": 0.45, "burst": 0.45, "mobility": 0.35},
	"projectile_storm": {"density": 0.85, "ranged": 0.45, "durability": 0.35},
	"domain_blast": {"density": 0.75, "control": 0.7, "boss": 0.35},
	"lifesteal_grind": {"contact": 0.65, "durability": 0.35, "boss": 0.3},
	"guard_counter": {"contact": 0.7, "burst": 0.65},
	"mark_execute": {"durability": 0.75, "boss": 0.45, "ranged": 0.25},
	"ultimate_cycle": {"boss": 0.75, "durability": 0.45, "ranged": 0.25},
	"summon_swarm": {"density": 0.45, "contact": 0.6, "ranged": 0.35},
	"healing_push": {"contact": 0.6, "burst": 0.45, "density": 0.35},
	"control_lock": {"mobility": 0.85, "density": 0.45, "burst": 0.35},
	"armor_break": {"durability": 0.5, "boss": 0.25},
	"marked": {"durability": 0.45, "ranged": 0.25, "boss": 0.25},
	"field": {"density": 0.55, "control": 0.55, "mobility": 0.3},
	"slowed": {"mobility": 0.6, "contact": 0.3},
	"guard": {"contact": 0.6, "burst": 0.5},
	"overdrive": {"density": 0.45, "durability": 0.3},
	"charge": {"boss": 0.45, "durability": 0.25}
}


static func get_stage_time_for_team_level(team_level: int) -> float:
	if TEAM_LEVEL_TO_TIME.has(team_level):
		return float(TEAM_LEVEL_TO_TIME.get(team_level))
	return clamp(float(team_level) / 25.0, 0.0, 1.0) * DEFAULT_STAGE_DURATION


static func get_enemy_pressure_for_team_level(team_level: int, player_growth_score: float = -1.0, difficulty_id: String = DIFFICULTY_PROFILE.DEFAULT_DIFFICULTY_ID) -> Dictionary:
	return get_enemy_pressure_at_time(get_stage_time_for_team_level(team_level), player_growth_score, difficulty_id)


static func get_enemy_pressure_at_time(survival_time: float, player_growth_score: float = -1.0, difficulty_id: String = DIFFICULTY_PROFILE.DEFAULT_DIFFICULTY_ID) -> Dictionary:
	var boss_spawn_time := ENEMY_DIRECTOR.get_default_boss_spawn_time()
	var expected_growth := ENEMY_DIRECTOR.get_expected_growth_score(survival_time, boss_spawn_time)
	var growth_score := expected_growth if player_growth_score < 0.0 else player_growth_score
	var difficulty_profile := DIFFICULTY_PROFILE.get_profile(difficulty_id)
	var wave_profile := DIFFICULTY_PROFILE.apply_to_wave_profile(ENEMY_DIRECTOR.get_wave_profile(
		survival_time,
		ENEMY_DIRECTOR.get_default_elite_spawn_times(),
		growth_score,
		expected_growth
	), difficulty_profile)
	var spawn_interval := ENEMY_DIRECTOR.get_spawn_interval(
		ENEMY_DIRECTOR.get_default_starting_spawn_interval(),
		ENEMY_DIRECTOR.get_default_minimum_spawn_interval() * max(0.2, DIFFICULTY_PROFILE.get_scale(difficulty_profile, "minimum_spawn_interval_scale", 1.0)),
		survival_time,
		boss_spawn_time,
		wave_profile,
		DIFFICULTY_PROFILE.get_scale(difficulty_profile, "spawn_interval_scale", 1.0)
	)
	var normal_mix := _normal_mix_pressure(wave_profile, spawn_interval, difficulty_profile)
	var special_pressure := _special_pressure(survival_time, difficulty_profile)
	var pressure := _empty_pressure()
	_merge_pressure(pressure, normal_mix.get("pressure", {}))
	_merge_pressure(pressure, special_pressure.get("pressure", {}))
	var total := _sum_pressure(pressure)
	return {
		"team_level_estimate": _team_level_estimate(survival_time),
		"survival_time": survival_time,
		"difficulty_id": DIFFICULTY_PROFILE.normalize_id(difficulty_id),
		"expected_growth_score": expected_growth,
		"player_growth_score": growth_score,
		"spawn_interval": spawn_interval,
		"spawn_rate": 1.0 / max(0.001, spawn_interval),
		"wave_profile": wave_profile,
		"normal_mix": normal_mix,
		"special_pressure": special_pressure,
		"pressure": pressure,
		"total_pressure": total,
		"dominant_pressure": _top_key(pressure)
	}


static func evaluate_build_against_pressure(state: Dictionary, enemy_pressure: Dictionary) -> Dictionary:
	var pressure: Dictionary = enemy_pressure.get("pressure", {})
	var coverage := get_build_pressure_coverage(state)
	var resisted := 0.0
	var uncovered := 0.0
	for pressure_type in PRESSURE_TYPES:
		var amount := float(pressure.get(pressure_type, 0.0))
		var cover := float(coverage.get(pressure_type, 0.0))
		resisted += min(amount, cover)
		uncovered += max(0.0, amount - cover)
	var total_pressure: float = max(0.001, float(enemy_pressure.get("total_pressure", _sum_pressure(pressure))))
	var coverage_ratio: float = resisted / total_pressure
	var danger_ratio: float = uncovered / total_pressure
	return {
		"coverage": coverage,
		"resisted_pressure": resisted,
		"uncovered_pressure": uncovered,
		"coverage_ratio": coverage_ratio,
		"danger_ratio": danger_ratio,
		"dominant_uncovered": _dominant_uncovered(pressure, coverage)
	}


static func get_build_pressure_coverage(state: Dictionary) -> Dictionary:
	var coverage := _empty_pressure()
	var position_points: Dictionary = state.get("position_points", {})
	for position in position_points.keys():
		_merge_pressure_scaled(coverage, POSITION_COVERAGE.get(position, {}), float(position_points.get(position, 0.0)))
	var tag_points: Dictionary = state.get("tag_points", {})
	for tag in tag_points.keys():
		_merge_pressure_scaled(coverage, TAG_COVERAGE.get(tag, {}), float(tag_points.get(tag, 0.0)))
	var edge_total: float = _sum_values(state.get("edge_level", {}))
	coverage["boss"] = float(coverage.get("boss", 0.0)) + edge_total * 0.25
	coverage["burst"] = float(coverage.get("burst", 0.0)) + edge_total * 0.12
	return coverage


static func _normal_mix_pressure(wave_profile: Dictionary, spawn_interval: float, difficulty_profile: Dictionary = {}) -> Dictionary:
	var weights: Dictionary = wave_profile.get("weights", {})
	var total_weight: float = max(0.001, _sum_values(weights))
	var average_pack: float = _average_pack_size(wave_profile, weights, total_weight)
	var spawn_rate: float = 1.0 / max(0.001, spawn_interval)
	var density_factor: float = spawn_rate * average_pack
	var pressure := _empty_pressure()
	var archetype_rows: Array = []
	for archetype in weights.keys():
		var share: float = float(weights.get(archetype, 0.0)) / total_weight
		var profile := DIFFICULTY_PROFILE.apply_to_enemy_profile("normal", ENEMY_ARCHETYPE_DATABASE.get_profile("normal", str(archetype)), difficulty_profile)
		var unit := _profile_pressure(str(archetype), profile)
		var count_factor: float = density_factor * share
		_merge_pressure_scaled(pressure, unit, count_factor)
		archetype_rows.append({
			"archetype": str(archetype),
			"share": share,
			"count_factor": count_factor,
			"unit_pressure": unit
		})
	return {
		"average_pack_size": average_pack,
		"density_factor": density_factor,
		"archetypes": archetype_rows,
		"pressure": pressure
	}


static func _special_pressure(survival_time: float, difficulty_profile: Dictionary = {}) -> Dictionary:
	var pressure := _empty_pressure()
	var active: Array = []
	for elite_time in ENEMY_DIRECTOR.get_default_elite_spawn_times():
		var distance: float = abs(float(elite_time) - survival_time)
		if survival_time >= float(elite_time) and distance <= 28.0:
			var archetype: String = "elite_splitshot" if survival_time >= 240.0 and int(float(elite_time)) % 2 == 0 else "elite_ram_trail"
			var profile := DIFFICULTY_PROFILE.apply_to_enemy_profile("elite", ENEMY_ARCHETYPE_DATABASE.get_profile("elite", archetype), difficulty_profile)
			var unit := _profile_pressure(archetype, profile)
			_merge_pressure_scaled(pressure, unit, 0.42)
			active.append({"type": "elite", "archetype": archetype, "weight": 0.42})
	for index in range(ENEMY_DIRECTOR.get_default_small_boss_spawn_times().size()):
		var small_time := float(ENEMY_DIRECTOR.get_default_small_boss_spawn_times()[index])
		var distance: float = abs(small_time - survival_time)
		if survival_time >= small_time and distance <= 42.0:
			var archetype: String = ENEMY_DIRECTOR.pick_small_boss_archetype(index)
			var profile := DIFFICULTY_PROFILE.apply_to_enemy_profile("small_boss", ENEMY_ARCHETYPE_DATABASE.get_profile("small_boss", archetype), difficulty_profile)
			var unit := _profile_pressure(archetype, profile)
			_merge_pressure_scaled(pressure, unit, 0.28)
			active.append({"type": "small_boss", "archetype": archetype, "weight": 0.28})
	if survival_time >= ENEMY_DIRECTOR.get_default_boss_spawn_time() - 45.0:
		var boss_weight: float = clamp((survival_time - (ENEMY_DIRECTOR.get_default_boss_spawn_time() - 45.0)) / 45.0, 0.0, 1.0) * 0.38
		var boss_profile: Dictionary = DIFFICULTY_PROFILE.apply_to_enemy_profile("boss", ENEMY_ARCHETYPE_DATABASE.get_profile("boss", "boss_spellcore"), difficulty_profile)
		_merge_pressure_scaled(pressure, _profile_pressure("boss_spellcore", boss_profile), boss_weight)
		if boss_weight > 0.0:
			active.append({"type": "boss", "archetype": "boss_spellcore", "weight": boss_weight})
	return {
		"active": active,
		"pressure": pressure
	}


static func _profile_pressure(archetype: String, profile: Dictionary) -> Dictionary:
	var pressure := _empty_pressure()
	var health := float(profile.get("max_health", 20.0))
	var touch_damage := float(profile.get("touch_damage", 0.0))
	var speed := float(profile.get("speed", 0.0))
	var behavior := str(profile.get("behavior", "chaser"))
	pressure["durability"] += sqrt(max(1.0, health)) / 24.0
	pressure["contact"] += touch_damage / 16.0
	pressure["mobility"] += speed / 130.0
	if behavior == "shooter" or str(profile.get("secondary_behavior", "")) == "shooter":
		var interval: float = max(0.25, float(profile.get("shot_interval", 2.4)))
		var projectile_count: int = max(1, int(profile.get("projectile_count", 1)))
		var projectile_damage := float(profile.get("projectile_damage", 0.0))
		pressure["ranged"] += projectile_damage * float(projectile_count) / interval / 8.0
		pressure["burst"] += max(0.0, float(projectile_count) - 1.0) * projectile_damage / 30.0
	if behavior == "dash":
		pressure["burst"] += float(profile.get("dash_speed_multiplier", 1.0)) * touch_damage / 34.0
		pressure["mobility"] += float(profile.get("dash_speed_multiplier", 1.0)) * 0.35
	if behavior == "turret":
		pressure["ranged"] += float(profile.get("turret_bombard_projectiles", 0)) * float(profile.get("projectile_damage", 0.0)) / max(0.5, float(profile.get("turret_bombard_interval", 3.0))) / 10.0
		pressure["control"] += 0.55
	if behavior == "boss":
		pressure["boss"] += 3.0
		pressure["ranged"] += float(profile.get("boss_radial_bullets", 0)) * float(profile.get("projectile_damage", 0.0)) / max(0.5, float(profile.get("boss_radial_interval", 1.0))) / 36.0
		pressure["burst"] += 1.5
		pressure["control"] += 0.8
	_merge_pressure(pressure, ARCHETYPE_PRESSURE_TAGS.get(archetype, {}))
	return pressure


static func _average_pack_size(wave_profile: Dictionary, weights: Dictionary, total_weight: float) -> float:
	var average := 0.0
	var pack_chance := float(wave_profile.get("pack_chance", 0.0))
	var pack_bonus_average := float(wave_profile.get("pack_bonus_max", 0)) * 0.5
	var swarm_average := (float(wave_profile.get("swarm_min", 1)) + float(wave_profile.get("swarm_max", 1))) * 0.5
	for archetype in weights.keys():
		var share: float = float(weights.get(archetype, 0.0)) / total_weight
		if str(archetype) == "swarm":
			average += share * swarm_average
		else:
			average += share * (1.0 + pack_chance * pack_bonus_average)
	return max(1.0, average)


static func _team_level_estimate(survival_time: float) -> int:
	var best_level := 1
	var best_delta := INF
	for level in TEAM_LEVEL_TO_TIME.keys():
		var delta: float = abs(float(TEAM_LEVEL_TO_TIME.get(level)) - survival_time)
		if delta < best_delta:
			best_delta = delta
			best_level = int(level)
	return best_level


static func _empty_pressure() -> Dictionary:
	var result := {}
	for pressure_type in PRESSURE_TYPES:
		result[pressure_type] = 0.0
	return result


static func _merge_pressure(target: Dictionary, source_variant: Variant) -> void:
	if source_variant is not Dictionary:
		return
	for key in (source_variant as Dictionary).keys():
		target[key] = float(target.get(key, 0.0)) + float((source_variant as Dictionary).get(key, 0.0))


static func _merge_pressure_scaled(target: Dictionary, source_variant: Variant, scale: float) -> void:
	if source_variant is not Dictionary:
		return
	for key in (source_variant as Dictionary).keys():
		target[key] = float(target.get(key, 0.0)) + float((source_variant as Dictionary).get(key, 0.0)) * scale


static func _sum_pressure(pressure: Dictionary) -> float:
	var result := 0.0
	for pressure_type in PRESSURE_TYPES:
		result += float(pressure.get(pressure_type, 0.0))
	return result


static func _sum_values(values_variant: Variant) -> float:
	if values_variant is not Dictionary:
		return 0.0
	var result := 0.0
	for key in (values_variant as Dictionary).keys():
		result += float((values_variant as Dictionary).get(key, 0.0))
	return result


static func _top_key(values: Dictionary) -> String:
	var best_key := ""
	var best_value := -INF
	for key in values.keys():
		var value := float(values.get(key, 0.0))
		if value > best_value:
			best_value = value
			best_key = str(key)
	return best_key


static func _dominant_uncovered(pressure: Dictionary, coverage: Dictionary) -> String:
	var uncovered := {}
	for pressure_type in PRESSURE_TYPES:
		uncovered[pressure_type] = max(0.0, float(pressure.get(pressure_type, 0.0)) - float(coverage.get(pressure_type, 0.0)))
	return _top_key(uncovered)
