extends RefCounted

const FIRST_BATCH_DB := preload("res://scripts/build/build_first_batch_database.gd")

const LEVEL_6_GATE := 6
const LEVEL_12_GATE := 12
const LEVEL_18_GATE := 18
const LEVEL_25_GATE := 25

const SWD_STAGE_6_COOLDOWN := 2.8
const GUN_STAGE_6_COOLDOWN := 3.2
const MAG_STAGE_6_COOLDOWN := 4.2

static func build_milestone_state_data() -> Dictionary:
	return {
		"last_checked_level": 1,
		"unlocked": {},
		"cooldowns": {}
	}

static func normalize_milestone_state_data(data: Variant) -> Dictionary:
	var state: Dictionary = data.duplicate(true) if data is Dictionary else build_milestone_state_data()
	if not (state.get("unlocked", {}) is Dictionary):
		state["unlocked"] = {}
	if not (state.get("cooldowns", {}) is Dictionary):
		state["cooldowns"] = {}
	state["last_checked_level"] = max(1, int(state.get("last_checked_level", 1)))
	return state

static func get_save_snapshot(owner) -> Dictionary:
	return normalize_milestone_state_data(owner.get("first_batch_milestone_state")).duplicate(true)

static func apply_save_snapshot(owner, data: Variant) -> void:
	owner.set("first_batch_milestone_state", normalize_milestone_state_data(data))

static func check_level_milestones(owner) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var state := normalize_milestone_state_data(owner.get("first_batch_milestone_state"))
	var team_level: int = max(1, int(owner.get("level")))
	var previous_level: int = max(1, int(state.get("last_checked_level", 1)))
	state["last_checked_level"] = max(previous_level, team_level)
	owner.set("first_batch_milestone_state", state)
	for threshold in [LEVEL_6_GATE, LEVEL_12_GATE, LEVEL_18_GATE, LEVEL_25_GATE]:
		if previous_level < threshold and team_level >= threshold:
			_unlock_threshold(owner, threshold)

static func update_cooldowns(owner, delta: float) -> void:
	if owner == null or delta <= 0.0:
		return
	var state := normalize_milestone_state_data(owner.get("first_batch_milestone_state"))
	var cooldowns: Dictionary = (state.get("cooldowns", {}) as Dictionary).duplicate(true)
	for key in cooldowns.keys():
		var next_value: float = max(0.0, float(cooldowns.get(key, 0.0)) - delta)
		cooldowns[key] = next_value
	state["cooldowns"] = cooldowns
	owner.set("first_batch_milestone_state", state)

static func get_milestone_skill_slots(owner, role_id: String) -> Array:
	var slots: Array = []
	if owner == null or not is_instance_valid(owner):
		return slots
	if not is_threshold_unlocked(owner, LEVEL_6_GATE):
		return slots
	var state := normalize_milestone_state_data(owner.get("first_batch_milestone_state"))
	var cooldowns: Dictionary = state.get("cooldowns", {})
	match role_id:
		"swordsman":
			slots.append(_make_slot("破阵牵引", float(cooldowns.get("swd_stage6_break_pull", 0.0)), SWD_STAGE_6_COOLDOWN, Color(1.0, 0.82, 0.34, 1.0), "6级质变：剑士命中会周期性追加破阵牵引，造成范围斩击、易伤和短减速。"))
		"gunner":
			slots.append(_make_slot("火线标记", float(cooldowns.get("gun_stage6_fire_mark", 0.0)), GUN_STAGE_6_COOLDOWN, Color(1.0, 0.52, 0.28, 1.0), "6级质变：枪手命中会周期性追加锁定爆点，标记目标并造成小范围爆破。"))
		"mage":
			slots.append(_make_slot("符印领域", float(cooldowns.get("mag_stage6_field_seal", 0.0)), MAG_STAGE_6_COOLDOWN, Color(0.62, 0.92, 1.0, 1.0), "6级质变：术师命中会周期性展开符印领域，持续伤害并减速敌人。"))
	return slots

static func apply_attack_milestones(owner, role_id: String, hit_count: int, _killed: bool) -> void:
	if owner == null or not is_instance_valid(owner) or hit_count <= 0:
		return
	if not is_threshold_unlocked(owner, LEVEL_6_GATE):
		return
	var safe_role_id := role_id
	if safe_role_id == "":
		safe_role_id = str(owner._get_active_role().get("id", ""))
	match safe_role_id:
		"swordsman":
			_try_trigger_swordsman_stage_6(owner)
		"gunner":
			_try_trigger_gunner_stage_6(owner)
		"mage":
			_try_trigger_mage_stage_6(owner)

static func is_threshold_unlocked(owner, threshold: int) -> bool:
	var state := normalize_milestone_state_data(owner.get("first_batch_milestone_state"))
	var unlocked: Dictionary = state.get("unlocked", {})
	return bool(unlocked.get(str(threshold), false))

static func _unlock_threshold(owner, threshold: int) -> void:
	var state := normalize_milestone_state_data(owner.get("first_batch_milestone_state"))
	var unlocked: Dictionary = (state.get("unlocked", {}) as Dictionary).duplicate(true)
	if bool(unlocked.get(str(threshold), false)):
		return
	unlocked[str(threshold)] = true
	state["unlocked"] = unlocked
	owner.set("first_batch_milestone_state", state)
	_apply_threshold_payload(owner, threshold)
	_show_threshold_feedback(owner, threshold)

static func _apply_threshold_payload(owner, threshold: int) -> void:
	match threshold:
		LEVEL_6_GATE:
			owner._apply_team_role_bonus(1.2, 0.018, 4.0, 0.07)
			owner.role_switch_cooldown_bonus += 0.18
			owner._increase_team_specials([
				{"role_id": "swordsman", "key": "crescent_level"},
				{"role_id": "gunner", "key": "lock_level"},
				{"role_id": "mage", "key": "frost_level"}
			])
		LEVEL_12_GATE:
			owner._apply_team_role_bonus(1.6, 0.022, 5.0, 0.08)
			owner.energy_gain_multiplier += 0.04
			owner.background_interval_multiplier = max(0.45, owner.background_interval_multiplier - 0.025)
		LEVEL_18_GATE:
			owner._apply_team_role_bonus(2.0, 0.025, 6.0, 0.10)
			owner.ultimate_cost_multiplier = max(0.58, owner.ultimate_cost_multiplier - 0.035)
			owner.role_switch_cooldown_bonus += 0.16
		LEVEL_25_GATE:
			owner._apply_team_role_bonus(2.4, 0.03, 8.0, 0.12)
			owner.energy_gain_multiplier += 0.05
			owner.background_interval_multiplier = max(0.42, owner.background_interval_multiplier - 0.03)
	owner._update_fire_timer()
	owner.stats_changed.emit(owner.get_stat_summary())

static func _show_threshold_feedback(owner, threshold: int) -> void:
	var title := _threshold_title(threshold)
	var color := _threshold_color(threshold)
	if owner.has_method("_show_switch_banner"):
		owner._show_switch_banner("质变", title, color)
	owner._spawn_ring_effect(owner.global_position, 112.0 + float(threshold) * 2.0, Color(color.r, color.g, color.b, 0.82), 10.0, 0.26)
	owner._spawn_burst_effect(owner.global_position, 124.0 + float(threshold) * 2.0, Color(color.r, color.g, color.b, 0.20), 0.28)
	owner._queue_camera_shake(9.0 + float(threshold) * 0.18, 0.24)

static func _threshold_title(threshold: int) -> String:
	match threshold:
		LEVEL_6_GATE:
			return "第一质变"
		LEVEL_12_GATE:
			return "循环成形"
		LEVEL_18_GATE:
			return "跨线成型"
		LEVEL_25_GATE:
			return "主线毕业"
	return "Build质变"

static func _threshold_color(threshold: int) -> Color:
	match threshold:
		LEVEL_6_GATE:
			return Color(1.0, 0.84, 0.34, 1.0)
		LEVEL_12_GATE:
			return Color(0.48, 0.92, 1.0, 1.0)
		LEVEL_18_GATE:
			return Color(0.86, 0.58, 1.0, 1.0)
		LEVEL_25_GATE:
			return Color(1.0, 0.96, 0.58, 1.0)
	return Color.WHITE

static func _try_trigger_swordsman_stage_6(owner) -> void:
	if _get_cooldown(owner, "swd_stage6_break_pull") > 0.0:
		return
	_set_cooldown(owner, "swd_stage6_break_pull", SWD_STAGE_6_COOLDOWN)
	var direction: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	var center: Vector2 = owner.global_position + direction.normalized() * 48.0
	var radius := 72.0 + float(owner._get_card_level("swd_tide_pull")) * 10.0
	owner._spawn_crescent_wave_effect(center, direction, radius, Color(1.0, 0.78, 0.30, 0.78), 0.18, 260.0, 26.0)
	owner._spawn_ring_effect(center, radius * 0.82, Color(1.0, 0.52, 0.28, 0.56), 7.0, 0.18)
	if owner.has_method("_pull_enemies_toward"):
		owner._pull_enemies_toward(center, radius * 1.15, 26.0)
	var hits: int = owner._damage_enemies_in_radius(center, radius, owner._get_role_damage("swordsman") * 0.42, 0.08, 0.82, 0.9, "swordsman")
	if hits > 0:
		owner._add_active_role_mana(min(8.0, 1.5 + float(hits) * 0.55), false)

static func _try_trigger_gunner_stage_6(owner) -> void:
	if _get_cooldown(owner, "gun_stage6_fire_mark") > 0.0:
		return
	var target: Node2D = owner._get_low_health_enemy()
	if target == null or not is_instance_valid(target):
		target = owner._get_enemy_in_aim_cone(75.0, 460.0)
	if target == null or not is_instance_valid(target):
		target = owner._get_closest_enemy()
	if target == null or not is_instance_valid(target):
		return
	_set_cooldown(owner, "gun_stage6_fire_mark", GUN_STAGE_6_COOLDOWN)
	var origin: Vector2 = owner.global_position
	owner._spawn_dash_line_effect(origin, target.global_position, Color(1.0, 0.48, 0.20, 0.86), 6.0, 0.13)
	owner._spawn_target_lock_effect(target.global_position, 30.0, Color(1.0, 0.66, 0.28, 0.86), 0.18)
	owner._spawn_burst_effect(target.global_position, 36.0, Color(1.0, 0.44, 0.16, 0.22), 0.16)
	if target.has_method("apply_vulnerability"):
		target.apply_vulnerability(0.10, 2.0)
	var killed: bool = bool(owner._deal_damage_to_enemy(target, owner._get_role_damage("gunner") * 0.56, "gunner", 0.08, 2.0, 1.0, 0.0, origin))
	var splash_hits: int = owner._damage_enemies_in_radius(target.global_position, 38.0, owner._get_role_damage("gunner") * 0.18, 0.03, 1.0, 0.0, "gunner")
	owner._register_attack_result("gunner", 1 + splash_hits, killed)

static func _try_trigger_mage_stage_6(owner) -> void:
	if _get_cooldown(owner, "mag_stage6_field_seal") > 0.0:
		return
	var center: Vector2 = owner._get_enemy_cluster_center()
	if center == Vector2.ZERO:
		var target: Node2D = owner._get_closest_enemy()
		if target != null and is_instance_valid(target):
			center = target.global_position
	if center == Vector2.ZERO:
		return
	_set_cooldown(owner, "mag_stage6_field_seal", MAG_STAGE_6_COOLDOWN)
	var radius: float = 64.0 + float(owner._get_card_level("mag_frost_seal")) * 10.0
	var pulse_damage: float = float(owner._get_role_damage("mage")) * 0.28
	owner._spawn_ring_effect(center, radius, Color(0.62, 0.92, 1.0, 0.82), 7.0, 0.22)
	owner._spawn_frost_sigils_effect(center, radius * 0.72, Color(0.84, 0.98, 1.0, 0.86), 0.22)
	owner._spawn_pulsing_field(center, radius, Color(0.52, 0.86, 1.0, 0.18), 3, 0.18, pulse_damage, 0.05, 0.68, 1.4)

static func _make_slot(name: String, remaining: float, duration: float, color: Color, description: String) -> Dictionary:
	return {
		"name": name,
		"remaining": clamp(remaining, 0.0, max(duration, 0.01)),
		"duration": max(duration, 0.01),
		"color": color,
		"slot_label": "Build质变",
		"description": description
	}

static func _get_cooldown(owner, key: String) -> float:
	var state := normalize_milestone_state_data(owner.get("first_batch_milestone_state"))
	var cooldowns: Dictionary = state.get("cooldowns", {})
	return max(0.0, float(cooldowns.get(key, 0.0)))

static func _set_cooldown(owner, key: String, duration: float) -> void:
	var state := normalize_milestone_state_data(owner.get("first_batch_milestone_state"))
	var cooldowns: Dictionary = (state.get("cooldowns", {}) as Dictionary).duplicate(true)
	cooldowns[key] = max(0.0, duration)
	state["cooldowns"] = cooldowns
	owner.set("first_batch_milestone_state", state)
