extends RefCounted

const DEFAULT_STAGE_DURATION := 720.0
const DEFAULT_ELITE_SPAWN_TIMES := [78.0, 138.0, 255.0, 318.0, 438.0, 498.0, 618.0, 684.0]
const DEFAULT_SMALL_BOSS_SPAWN_TIMES := [180.0, 360.0, 540.0]
const DEFAULT_BOSS_SPAWN_TIME := 720.0
const DEFAULT_STARTING_SPAWN_INTERVAL := 1.02
const DEFAULT_MINIMUM_SPAWN_INTERVAL := 0.28
const WAVE_BATCH_INTERVAL_MULTIPLIER := 2.6
const WAVE_BATCH_MIN_INTERVAL := 1.05
const WAVE_BATCH_MAX_INTERVAL := 2.2
const WAVE_BATCH_MAX_PACKS := 5
const ENDLESS_CYCLE_HEALTH_GROWTH := 0.35
const ENDLESS_CYCLE_DAMAGE_GROWTH := 0.18
const ENDLESS_CYCLE_SPEED_GROWTH := 0.04
const ENDLESS_CYCLE_MAX_SPEED_MULTIPLIER := 1.28

static func get_default_stage_duration() -> float:
	return DEFAULT_STAGE_DURATION

static func get_default_elite_spawn_times() -> Array:
	return DEFAULT_ELITE_SPAWN_TIMES.duplicate()

static func get_default_small_boss_spawn_times() -> Array:
	return DEFAULT_SMALL_BOSS_SPAWN_TIMES.duplicate()

static func get_default_boss_spawn_time() -> float:
	return DEFAULT_BOSS_SPAWN_TIME

static func get_default_starting_spawn_interval() -> float:
	return DEFAULT_STARTING_SPAWN_INTERVAL

static func get_default_minimum_spawn_interval() -> float:
	return DEFAULT_MINIMUM_SPAWN_INTERVAL

static func get_effective_boss_spawn_time(
	story_stage: Dictionary,
	story_mode_active: bool,
	endless_mode_active: bool,
	defeated_boss_count: int
) -> float:
	if story_mode_active:
		return float(story_stage.get("boss_spawn_time", DEFAULT_BOSS_SPAWN_TIME))
	if endless_mode_active:
		return DEFAULT_BOSS_SPAWN_TIME * float(defeated_boss_count + 1)
	return DEFAULT_BOSS_SPAWN_TIME

static func get_effective_stage_curve_time(story_stage: Dictionary, story_mode_active: bool) -> float:
	if story_mode_active:
		if str(story_stage.get("type", "")) == "boss":
			return max(60.0, float(story_stage.get("boss_spawn_time", DEFAULT_BOSS_SPAWN_TIME)))
		return max(60.0, float(story_stage.get("target_time", 180.0)))
	return DEFAULT_BOSS_SPAWN_TIME

static func get_story_spawn_interval_multiplier(story_stage: Dictionary, story_mode_active: bool) -> float:
	if not story_mode_active:
		return 1.0
	return float(story_stage.get("spawn_interval_multiplier", 1.0))

static func get_story_enemy_health_multiplier(story_stage: Dictionary, story_mode_active: bool) -> float:
	if not story_mode_active:
		return 1.0
	return float(story_stage.get("enemy_health_multiplier", 1.0))

static func get_story_enemy_speed_multiplier(story_stage: Dictionary, story_mode_active: bool) -> float:
	if not story_mode_active:
		return 1.0
	return float(story_stage.get("enemy_speed_multiplier", 1.0))

static func get_endless_cycle_health_multiplier(cycle_power_level: int) -> float:
	return 1.0 + float(max(0, cycle_power_level)) * ENDLESS_CYCLE_HEALTH_GROWTH

static func get_endless_cycle_damage_multiplier(cycle_power_level: int) -> float:
	return 1.0 + float(max(0, cycle_power_level)) * ENDLESS_CYCLE_DAMAGE_GROWTH

static func get_endless_cycle_speed_multiplier(cycle_power_level: int) -> float:
	return min(ENDLESS_CYCLE_MAX_SPEED_MULTIPLIER, 1.0 + float(max(0, cycle_power_level)) * ENDLESS_CYCLE_SPEED_GROWTH)

static func get_wave_profile(survival_time: float, elite_spawn_times: Array, player_growth_score: float, expected_growth_score: float) -> Dictionary:
	var profile: Dictionary
	if survival_time < 50.0:
		profile = {
			"interval_scale": 0.96,
			"weights": {"chaser": 7.0, "runner": 1.2, "brute": 0.5},
			"swarm_min": 10,
			"swarm_max": 14,
			"pack_chance": 0.18,
			"pack_bonus_max": 2
		}
	elif survival_time < 90.0:
		profile = {
			"interval_scale": 0.84,
			"weights": {"chaser": 5.2, "runner": 2.2, "shooter": 1.4, "brute": 1.0},
			"swarm_min": 11,
			"swarm_max": 15,
			"pack_chance": 0.24,
			"pack_bonus_max": 3
		}
	elif survival_time < 140.0:
		profile = {
			"interval_scale": 0.74,
			"weights": {"chaser": 4.0, "runner": 2.4, "swarm": 1.8, "shooter": 1.8, "brute": 1.4},
			"swarm_min": 12,
			"swarm_max": 18,
			"pack_chance": 0.30,
			"pack_bonus_max": 3
		}
	elif survival_time < 180.0:
		profile = {
			"interval_scale": 0.66,
			"weights": {"chaser": 3.0, "runner": 2.4, "swarm": 2.4, "shooter": 2.0, "brute": 2.0, "dasher": 0.8},
			"swarm_min": 14,
			"swarm_max": 20,
			"pack_chance": 0.34,
			"pack_bonus_max": 3
		}
	elif survival_time < 240.0:
		profile = {
			"interval_scale": 0.58,
			"weights": {"runner": 2.0, "swarm": 3.2, "shooter": 2.2, "brute": 2.6, "dasher": 1.1},
			"swarm_min": 15,
			"swarm_max": 22,
			"pack_chance": 0.38,
			"pack_bonus_max": 4
		}
	elif survival_time < 300.0:
		profile = {
			"interval_scale": 0.51,
			"weights": {"runner": 1.8, "swarm": 3.2, "shooter": 2.0, "brute": 3.0, "dasher": 1.6, "shotgunner": 0.8},
			"swarm_min": 16,
			"swarm_max": 24,
			"pack_chance": 0.42,
			"pack_bonus_max": 4
		}
	elif survival_time < 360.0:
		profile = {
			"interval_scale": 0.46,
			"weights": {"runner": 1.6, "swarm": 3.4, "shooter": 2.0, "brute": 3.2, "dasher": 1.8, "shotgunner": 1.2},
			"swarm_min": 18,
			"swarm_max": 26,
			"pack_chance": 0.46,
			"pack_bonus_max": 4
		}
	elif survival_time < 450.0:
		profile = {
			"interval_scale": 0.42,
			"weights": {"runner": 1.4, "swarm": 3.6, "shooter": 2.0, "brute": 3.4, "dasher": 2.0, "shotgunner": 1.6},
			"swarm_min": 20,
			"swarm_max": 28,
			"pack_chance": 0.48,
			"pack_bonus_max": 4
		}
	elif survival_time < 540.0:
		profile = {
			"interval_scale": 0.38,
			"weights": {"runner": 1.3, "swarm": 3.8, "shooter": 2.2, "brute": 3.4, "dasher": 2.2, "shotgunner": 1.8},
			"swarm_min": 22,
			"swarm_max": 30,
			"pack_chance": 0.54,
			"pack_bonus_max": 5
		}
	elif survival_time < 630.0:
		profile = {
			"interval_scale": 0.34,
			"weights": {"runner": 1.2, "swarm": 4.0, "shooter": 2.2, "brute": 3.8, "dasher": 2.4, "shotgunner": 2.0},
			"swarm_min": 24,
			"swarm_max": 32,
			"pack_chance": 0.58,
			"pack_bonus_max": 5
		}
	else:
		profile = {
			"interval_scale": 0.31,
			"weights": {"runner": 1.2, "swarm": 4.0, "shooter": 2.4, "brute": 4.0, "dasher": 2.5, "shotgunner": 2.2},
			"swarm_min": 24,
			"swarm_max": 34,
			"pack_chance": 0.60,
			"pack_bonus_max": 5
		}
	return apply_elite_prelude(apply_growth_adjustment(profile, survival_time, player_growth_score, expected_growth_score), survival_time, elite_spawn_times)

static func get_spawn_interval(starting_interval: float, minimum_interval: float, survival_time: float, curve_time: float, wave_profile: Dictionary, story_interval_multiplier: float) -> float:
	var stage_ratio: float = clamp(survival_time / max(curve_time, 0.01), 0.0, 1.0)
	var base_interval: float = lerpf(starting_interval, minimum_interval, stage_ratio)
	return max(minimum_interval, base_interval * float(wave_profile.get("interval_scale", 1.0)) * story_interval_multiplier)

static func get_wave_batch_interval(pack_interval: float) -> float:
	return clamp(pack_interval * WAVE_BATCH_INTERVAL_MULTIPLIER, WAVE_BATCH_MIN_INTERVAL, WAVE_BATCH_MAX_INTERVAL)

static func pick_spawn_wave_plan(wave_profile: Dictionary, rng: RandomNumberGenerator, pack_interval: float, batch_interval: float, max_count: int) -> Array:
	var plan: Array = []
	if max_count <= 0:
		return plan
	var pack_count: int = clamp(int(round(batch_interval / max(0.05, pack_interval))), 2, WAVE_BATCH_MAX_PACKS)
	var remaining_count: int = max_count
	for _index in range(pack_count):
		if remaining_count <= 0:
			break
		var pack: Dictionary = pick_spawn_pack(wave_profile, rng)
		var count: int = min(remaining_count, max(1, int(pack.get("count", 1))))
		plan.append({
			"archetype": str(pack.get("archetype", "chaser")),
			"count": count
		})
		remaining_count -= count
	return plan

static func collect_stage_events(
	survival_time: float,
	elite_spawn_times: Array,
	spawned_elite_count: int,
	small_boss_spawn_times: Array,
	spawned_small_boss_count: int,
	boss_spawned: bool,
	boss_spawn_time: float,
	has_active_small_boss: bool,
	story_stage: Dictionary,
	story_mode_active: bool,
	stage_cleared: bool,
	endless_mode_active: bool = false,
	cycle_duration: float = DEFAULT_BOSS_SPAWN_TIME
) -> Array:
	var events: Array = []
	if story_mode_active and str(story_stage.get("type", "")) == "normal" and not stage_cleared and survival_time >= float(story_stage.get("target_time", 0.0)):
		events.append({"type": "clear_stage"})
		return events

	if boss_spawned:
		return events

	if endless_mode_active:
		_collect_cyclic_special_events(
			events,
			survival_time,
			elite_spawn_times,
			spawned_elite_count,
			small_boss_spawn_times,
			spawned_small_boss_count,
			has_active_small_boss,
			cycle_duration
		)
	else:
		var pending_elite_count := spawned_elite_count
		while pending_elite_count < elite_spawn_times.size() and survival_time >= float(elite_spawn_times[pending_elite_count]):
			events.append({"type": "elite"})
			pending_elite_count += 1

		if not has_active_small_boss and spawned_small_boss_count < small_boss_spawn_times.size() and survival_time >= float(small_boss_spawn_times[spawned_small_boss_count]):
			events.append({"type": "small_boss"})

	if not boss_spawned and survival_time >= boss_spawn_time:
		events.append({"type": "boss"})

	return events

static func _collect_cyclic_special_events(
	events: Array,
	survival_time: float,
	elite_spawn_times: Array,
	spawned_elite_count: int,
	small_boss_spawn_times: Array,
	spawned_small_boss_count: int,
	has_active_small_boss: bool,
	cycle_duration: float
) -> void:
	var pending_elite_count := spawned_elite_count
	var safe_cycle_duration: float = max(1.0, cycle_duration)
	while _is_cyclic_event_due(survival_time, elite_spawn_times, pending_elite_count, safe_cycle_duration):
		events.append({"type": "elite"})
		pending_elite_count += 1

	if has_active_small_boss:
		return
	if _is_cyclic_event_due(survival_time, small_boss_spawn_times, spawned_small_boss_count, safe_cycle_duration):
		events.append({"type": "small_boss"})

static func _is_cyclic_event_due(survival_time: float, event_times: Array, spawned_count: int, cycle_duration: float) -> bool:
	if event_times.is_empty():
		return false
	var cycle_index: int = int(spawned_count / event_times.size())
	var event_index: int = spawned_count % event_times.size()
	var event_time: float = float(event_times[event_index])
	var absolute_event_time: float = float(cycle_index) * cycle_duration + event_time
	return survival_time >= absolute_event_time

static func pick_normal_archetype(wave_profile: Dictionary, rng: RandomNumberGenerator) -> String:
	return weighted_pick(wave_profile.get("weights", {"chaser": 1.0}), "chaser", rng)

static func pick_spawn_pack(wave_profile: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var archetype := pick_normal_archetype(wave_profile, rng)
	var count := 1
	if archetype == "swarm":
		count = rng.randi_range(int(wave_profile.get("swarm_min", 8)), int(wave_profile.get("swarm_max", 14)))
	elif rng.randf() < float(wave_profile.get("pack_chance", 0.0)):
		count += rng.randi_range(1, int(wave_profile.get("pack_bonus_max", 2)))
	return {
		"archetype": archetype,
		"count": count
	}

static func get_spawn_distance(kind: String, base_spawn_distance: float, distance_offset: float = 0.0) -> float:
	return base_spawn_distance + (100.0 if kind == "boss" else 0.0) + distance_offset

static func pick_wave_spawn_layout(count: int, rng: RandomNumberGenerator) -> Array:
	var layout := []
	var base_angle: float = rng.randf_range(0.0, TAU)
	for index in range(count):
		layout.append({
			"angle": base_angle + rng.randf_range(-0.34, 0.34) + float(index) * 0.05,
			"distance_offset": rng.randf_range(-18.0, 36.0)
		})
	return layout

static func pick_elite_archetype(survival_time: float, rng: RandomNumberGenerator) -> String:
	var choices: Array[String] = ["elite_ram_trail"]
	if survival_time >= 240.0:
		choices.append("elite_splitshot")
	if survival_time >= 420.0:
		choices.append("elite_ram_trail")
	return choices[rng.randi_range(0, choices.size() - 1)]

static func pick_small_boss_archetype(spawned_small_boss_count: int) -> String:
	match spawned_small_boss_count % 3:
		0:
			return "smallboss_glutton"
		1:
			return "smallboss_rebirth"
		_:
			return "smallboss_turret"

static func pick_special_archetype(kind: String, survival_time: float, spawned_small_boss_count: int, rng: RandomNumberGenerator) -> String:
	match kind:
		"elite":
			return pick_elite_archetype(survival_time, rng)
		"small_boss":
			return pick_small_boss_archetype(spawned_small_boss_count)
		"boss":
			return "boss_spellcore"
		_:
			return "chaser"

static func get_player_growth_score(
	player_level: int,
	stat_summary: Dictionary,
	slot_resonances_unlocked: Dictionary,
	elite_relics_unlocked: Dictionary
) -> float:
	var score := 0.0
	score += float(max(0, player_level - 1)) * 0.95
	score += float(int(stat_summary.get("body_build_level", 0))) * 0.7
	score += float(int(stat_summary.get("combat_build_level", 0))) * 0.75
	score += float(int(stat_summary.get("skill_build_level", 0))) * 0.8
	score += float(count_unlocked_entries(slot_resonances_unlocked)) * 1.4
	score += float(count_unlocked_entries(elite_relics_unlocked)) * 1.7
	score += float(stat_summary.get("bullet_damage", 0.0)) / 18.0
	return score

static func get_expected_growth_score(survival_time: float, boss_spawn_time: float) -> float:
	var build_ratio: float = clamp(min(survival_time, boss_spawn_time) / boss_spawn_time, 0.0, 1.0)
	var expected: float = 1.4 + build_ratio * 17.5
	if survival_time >= 140.0:
		expected += 0.8
	if survival_time >= 280.0:
		expected += 0.9
	if survival_time >= 400.0:
		expected += 0.8
	return expected

static func apply_elite_prelude(base_profile: Dictionary, survival_time: float, elite_spawn_times: Array) -> Dictionary:
	var adjusted: Dictionary = base_profile.duplicate(true)
	for elite_time in elite_spawn_times:
		var remaining: float = float(elite_time) - survival_time
		if remaining < 0.0 or remaining > 12.0:
			continue
		var weights: Dictionary = adjusted.get("weights", {}).duplicate(true)
		adjusted["interval_scale"] = max(0.28, float(adjusted.get("interval_scale", 1.0)) * 0.88)
		adjusted["pack_chance"] = min(0.62, float(adjusted.get("pack_chance", 0.0)) + 0.08)
		adjusted["swarm_max"] = int(adjusted.get("swarm_max", 10)) + 3
		tune_weight(weights, "shooter", 1.18)
		tune_weight(weights, "brute", 1.22)
		tune_weight(weights, "dasher", 1.28)
		tune_weight(weights, "shotgunner", 1.24)
		adjusted["weights"] = weights
		return adjusted
	return adjusted

static func apply_growth_adjustment(base_profile: Dictionary, survival_time: float, player_growth_score: float, expected_growth_score: float) -> Dictionary:
	var adjusted: Dictionary = base_profile.duplicate(true)
	var delta: float = player_growth_score - expected_growth_score
	var weights: Dictionary = adjusted.get("weights", {}).duplicate(true)

	if delta <= -2.6:
		adjusted["interval_scale"] = float(adjusted.get("interval_scale", 1.0)) + 0.08
		adjusted["pack_chance"] = max(0.02, float(adjusted.get("pack_chance", 0.0)) - 0.08)
		adjusted["swarm_max"] = max(int(adjusted.get("swarm_min", 8)), int(adjusted.get("swarm_max", 10)) - 2)
		tune_weight(weights, "chaser", 1.18)
		tune_weight(weights, "runner", 1.08)
		tune_weight(weights, "swarm", 1.08)
		tune_weight(weights, "shooter", 0.9)
		tune_weight(weights, "brute", 0.74)
		tune_weight(weights, "dasher", 0.6)
		tune_weight(weights, "shotgunner", 0.7)
	elif delta >= 2.6:
		adjusted["interval_scale"] = max(0.28, float(adjusted.get("interval_scale", 1.0)) - 0.07)
		adjusted["pack_chance"] = min(0.58, float(adjusted.get("pack_chance", 0.0)) + 0.08)
		adjusted["swarm_max"] = int(adjusted.get("swarm_max", 10)) + 1
		tune_weight(weights, "chaser", 0.84)
		tune_weight(weights, "runner", 0.96)
		tune_weight(weights, "swarm", 0.92)
		tune_weight(weights, "shooter", 1.14)
		tune_weight(weights, "brute", 1.26)
		tune_weight(weights, "dasher", 1.3)
		tune_weight(weights, "shotgunner", 1.2)
		if survival_time >= 110.0 and not weights.has("brute"):
			weights["brute"] = 0.8
		if survival_time >= 205.0 and not weights.has("dasher"):
			weights["dasher"] = 0.5
		if survival_time >= 260.0 and not weights.has("shotgunner"):
			weights["shotgunner"] = 0.5

	adjusted["weights"] = weights
	return adjusted

static func tune_weight(weights: Dictionary, key: String, multiplier: float) -> void:
	if not weights.has(key):
		return
	weights[key] = max(0.0, float(weights.get(key, 0.0)) * multiplier)

static func count_unlocked_entries(unlock_map: Dictionary) -> int:
	var count := 0
	for value in unlock_map.values():
		if bool(value):
			count += 1
	return count

static func weighted_pick(weight_map: Dictionary, fallback: String, rng: RandomNumberGenerator) -> String:
	var total_weight: float = 0.0
	for value in weight_map.values():
		total_weight += float(value)
	if total_weight <= 0.0:
		return fallback

	var roll: float = rng.randf() * total_weight
	var cumulative: float = 0.0
	for key in weight_map.keys():
		cumulative += float(weight_map[key])
		if roll <= cumulative:
			return str(key)
	return fallback
