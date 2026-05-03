extends RefCounted

const PLAYER_REWARD_APPLIER := preload("res://scripts/player/player_reward_applier.gd")
const PLAYER_EQUIPMENT_FLOW := preload("res://scripts/player/player_equipment_flow.gd")
const PLAYER_ELITE_UPGRADE_APPLIER := preload("res://scripts/player/player_elite_upgrade_applier.gd")
const PLAYER_FINAL_UPGRADE_APPLIER := preload("res://scripts/player/player_final_upgrade_applier.gd")
const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")

const MOVE_SPEED_STEP := 12.0
const DAMAGE_STEP := 2.5
const FIRE_RATE_STEP := 0.05
const PICKUP_RANGE_STEP := 8.0
const ENERGY_GAIN_STEP := 0.08
const HEALTH_STEP := 16.0
const DAMAGE_REDUCTION_STEP := 0.05
const SWITCH_COOLDOWN_STEP := 0.4


static func apply_upgrade(owner, option_id: String) -> void:
	if PLAYER_REWARD_APPLIER.is_noop_upgrade(option_id):
		owner.level_up_active = false
		return
	if PLAYER_BLESSING_SYSTEM.apply_option(owner, option_id):
		owner.level_up_active = false
		owner._update_fire_timer()
		owner.health_changed.emit(owner.current_health, owner.max_health)
		owner.stats_changed.emit(owner.get_stat_summary())
		owner._emit_active_mana_changed()
		owner._try_request_level_up()
		return
	if PLAYER_EQUIPMENT_FLOW.apply_equipment_reward(owner, option_id):
		owner.level_up_active = false
		owner._update_fire_timer()
		owner.stats_changed.emit(owner.get_stat_summary())
		owner._try_request_level_up()
		return
	var role_id: String = owner._get_active_role()["id"]
	var role_data: Dictionary = owner.role_upgrade_levels[role_id]
	var special_data: Dictionary = owner._get_role_special_state(role_id)

	if owner._apply_battle_card(option_id) or owner._apply_combat_card(option_id) or owner._apply_skill_card(option_id):
		owner.level_up_active = false
		owner._update_fire_timer()
		owner.stats_changed.emit(owner.get_stat_summary())
		owner._try_request_level_up()
		return
	if PLAYER_REWARD_APPLIER.apply_small_boss_reward(owner, option_id):
		owner.level_up_active = false
		owner._update_fire_timer()
		owner.stats_changed.emit(owner.get_stat_summary())
		owner._try_request_level_up()
		return

	match option_id:
		"body_move_speed", "move_speed":
			owner._record_build_pick("body")
			owner.speed += MOVE_SPEED_STEP
		"body_vitality":
			owner._record_build_pick("body")
			owner.max_health += HEALTH_STEP
			owner.current_health = min(owner.max_health, owner.current_health + HEALTH_STEP)
			owner.health_changed.emit(owner.current_health, owner.max_health)
		"body_pickup_range", "pickup_range":
			owner._record_build_pick("body")
			owner.pickup_radius += PICKUP_RANGE_STEP
		"body_guard":
			owner._record_build_pick("body")
			owner.damage_taken_multiplier = max(0.55, owner.damage_taken_multiplier - DAMAGE_REDUCTION_STEP)
		"combat_move_speed":
			owner._record_build_pick("combat")
			owner.speed += MOVE_SPEED_STEP
		"combat_vitality":
			owner._record_build_pick("combat")
			owner.max_health += HEALTH_STEP
			owner.current_health = min(owner.max_health, owner.current_health + HEALTH_STEP)
			owner.health_changed.emit(owner.current_health, owner.max_health)
		"combat_pickup_range":
			owner._record_build_pick("combat")
			owner.pickup_radius += PICKUP_RANGE_STEP
		"combat_guard":
			owner._record_build_pick("combat")
			owner.damage_taken_multiplier = max(0.55, owner.damage_taken_multiplier - DAMAGE_REDUCTION_STEP)
		"body_sword_blood":
			owner._record_build_pick("body")
			special_data["blood_level"] = int(special_data.get("blood_level", 0)) + 1
			owner.max_health += 10.0
			owner.damage_taken_multiplier = max(0.58, owner.damage_taken_multiplier - 0.03)
			owner._heal(12.0)
		"body_gunner_reload":
			owner._record_build_pick("body")
			special_data["reload_level"] = int(special_data.get("reload_level", 0)) + 1
			owner.speed += 6.0
			owner._add_active_role_mana(6.0)
		"skill_gunner_overheat":
			owner._record_build_pick("skill")
			special_data["reload_level"] = int(special_data.get("reload_level", 0)) + 1
			owner.speed += 6.0
			owner._add_active_role_mana(8.0)
		"body_mage_flow":
			owner._record_build_pick("body")
			special_data["flow_level"] = int(special_data.get("flow_level", 0)) + 1
			owner.max_mana += 8.0
			owner._add_active_role_mana(10.0)
		"skill_mage_tidal_flow":
			owner._record_build_pick("skill")
			special_data["flow_level"] = int(special_data.get("flow_level", 0)) + 1
			owner.max_mana += 8.0
			owner._add_active_role_mana(14.0)
		"combat_team_power", "power_training":
			owner._record_build_pick("combat")
			owner.global_damage_multiplier += 0.08
		"skill_energy_flow", "energy_flow":
			owner._record_build_pick("skill")
			owner.energy_gain_multiplier += ENERGY_GAIN_STEP
		"combat_role_focus", "role_focus":
			owner._record_build_pick("body")
			role_data["level"] = int(role_data["level"]) + 1
			role_data["damage_bonus"] = float(role_data["damage_bonus"]) + DAMAGE_STEP
			if role_id == "swordsman":
				role_data["skill_bonus"] = float(role_data["skill_bonus"]) + 0.18
				owner.damage_taken_multiplier = max(0.6, owner.damage_taken_multiplier - 0.02)
			elif role_id == "gunner":
				role_data["range_bonus"] = float(role_data["range_bonus"]) + 12.0
				role_data["skill_bonus"] = float(role_data["skill_bonus"]) + 0.12
			else:
				role_data["range_bonus"] = float(role_data["range_bonus"]) + 10.0
				role_data["skill_bonus"] = float(role_data["skill_bonus"]) + 0.18
		"combat_rhythm", "rhythm_mastery":
			owner._record_build_pick("body")
			role_data["interval_bonus"] = float(role_data["interval_bonus"]) + FIRE_RATE_STEP
		"combat_role_range":
			owner._record_build_pick("body")
			role_data["damage_bonus"] = float(role_data["damage_bonus"]) + 4.0
			role_data["range_bonus"] = float(role_data["range_bonus"]) + 14.0
		"combat_sword_crescent":
			owner._record_build_pick("body")
			special_data["crescent_level"] = int(special_data.get("crescent_level", 0)) + 1
			role_data["damage_bonus"] = float(role_data["damage_bonus"]) + 2.5
			owner.damage_taken_multiplier = max(0.58, owner.damage_taken_multiplier - 0.015)
		"combat_sword_thrust":
			owner._record_build_pick("body")
			special_data["thrust_level"] = int(special_data.get("thrust_level", 0)) + 1
			role_data["damage_bonus"] = float(role_data["damage_bonus"]) + 4.5
			owner._heal(4.0)
		"combat_gunner_scatter":
			owner._record_build_pick("body")
			special_data["scatter_level"] = int(special_data.get("scatter_level", 0)) + 1
			role_data["damage_bonus"] = float(role_data["damage_bonus"]) + 2.0
			role_data["range_bonus"] = float(role_data["range_bonus"]) + 10.0
		"combat_gunner_focus":
			owner._record_build_pick("body")
			special_data["focus_level"] = int(special_data.get("focus_level", 0)) + 1
			role_data["damage_bonus"] = float(role_data["damage_bonus"]) + 3.5
			role_data["range_bonus"] = float(role_data["range_bonus"]) + 14.0
		"combat_gunner_lock":
			owner._record_build_pick("body")
			special_data["lock_level"] = int(special_data.get("lock_level", 0)) + 1
			role_data["damage_bonus"] = float(role_data["damage_bonus"]) + 2.5
			role_data["range_bonus"] = float(role_data["range_bonus"]) + 10.0
		"combat_mage_echo":
			owner._record_build_pick("body")
			special_data["echo_level"] = int(special_data.get("echo_level", 0)) + 1
			role_data["range_bonus"] = float(role_data["range_bonus"]) + 10.0
			role_data["skill_bonus"] = float(role_data["skill_bonus"]) + 0.08
		"combat_mage_frost":
			owner._record_build_pick("body")
			special_data["frost_level"] = int(special_data.get("frost_level", 0)) + 1
			role_data["damage_bonus"] = float(role_data["damage_bonus"]) + 3.0
			role_data["range_bonus"] = float(role_data["range_bonus"]) + 12.0
		"combat_mage_gravity":
			owner._record_build_pick("body")
			special_data["gravity_level"] = int(special_data.get("gravity_level", 0)) + 1
			role_data["range_bonus"] = float(role_data["range_bonus"]) + 8.0
			role_data["skill_bonus"] = float(role_data["skill_bonus"]) + 0.12
		"skill_switch_mastery", "switch_mastery":
			owner._record_build_pick("skill")
			owner.role_switch_cooldown_bonus += SWITCH_COOLDOWN_STEP
			owner.switch_cooldown_remaining = max(0.0, owner.switch_cooldown_remaining - 1.0)
		"skill_support_link":
			owner._record_build_pick("skill")
			owner.background_interval_multiplier = max(0.55, owner.background_interval_multiplier - 0.1)
		"skill_ultimate_tuning":
			owner._record_build_pick("skill")
			owner.ultimate_cost_multiplier = max(0.62, owner.ultimate_cost_multiplier - 0.06)
			owner._add_active_role_mana(12.0)
		"skill_sword_counter":
			owner._record_build_pick("body")
			special_data["counter_level"] = int(special_data.get("counter_level", 0)) + 1
			owner.damage_taken_multiplier = max(0.56, owner.damage_taken_multiplier - 0.04)
		"skill_sword_pursuit":
			owner._record_build_pick("skill")
			special_data["pursuit_level"] = int(special_data.get("pursuit_level", 0)) + 1
			owner._add_active_role_mana(8.0)
		"skill_sword_stance":
			owner._record_build_pick("body")
			special_data["stance_level"] = int(special_data.get("stance_level", 0)) + 1
			owner._add_active_role_mana(6.0)
		"skill_gunner_support":
			owner._record_build_pick("combat")
			special_data["support_level"] = int(special_data.get("support_level", 0)) + 1
			owner._add_active_role_mana(5.0)
		"skill_gunner_barrage":
			owner._record_build_pick("skill")
			special_data["barrage_level"] = int(special_data.get("barrage_level", 0)) + 1
			owner._add_active_role_mana(9.0)
		"skill_mage_support":
			owner._record_build_pick("combat")
			special_data["support_level"] = int(special_data.get("support_level", 0)) + 1
			owner._add_active_role_mana(6.0)
		"skill_mage_storm":
			owner._record_build_pick("skill")
			special_data["storm_level"] = int(special_data.get("storm_level", 0)) + 1
			owner._add_active_role_mana(9.0)
		"fallback_body_reforge":
			owner._record_build_pick("body")
			owner.global_damage_multiplier += 0.03
			owner.max_health += 12.0
			owner.current_health = min(owner.max_health, owner.current_health + 12.0)
			owner.damage_taken_multiplier = max(0.55, owner.damage_taken_multiplier - 0.03)
			owner.health_changed.emit(owner.current_health, owner.max_health)
		"fallback_combat_reforge":
			owner._record_build_pick("combat")
			owner.role_switch_cooldown_bonus += 0.4
			owner.switch_cooldown_remaining = max(0.0, owner.switch_cooldown_remaining - 0.6)
			owner.background_interval_multiplier = max(0.45, owner.background_interval_multiplier - 0.06)
		"fallback_skill_reforge":
			owner._record_build_pick("skill")
			owner.energy_gain_multiplier += 0.10
			owner.ultimate_cost_multiplier = max(0.5, owner.ultimate_cost_multiplier - 0.04)
			role_data["skill_bonus"] = float(role_data.get("skill_bonus", 0.0)) + 0.08
			owner._add_active_role_mana(10.0)
		"elite_behemoth":
			PLAYER_ELITE_UPGRADE_APPLIER.apply_elite_upgrade(owner, option_id)
		"elite_gale":
			PLAYER_ELITE_UPGRADE_APPLIER.apply_elite_upgrade(owner, option_id)
		"elite_overcharge_reserve":
			PLAYER_ELITE_UPGRADE_APPLIER.apply_elite_upgrade(owner, option_id)
		"elite_mirror_finisher", "elite_fixed_axis_core", "elite_last_stand", "elite_execution_pact", "elite_reactor", "elite_chain_overload", "elite_fate_shift", "elite_perpetual_motion", "elite_battle_frenzy":
			PLAYER_ELITE_UPGRADE_APPLIER.apply_elite_upgrade(owner, option_id)
		"final_body_core":
			PLAYER_FINAL_UPGRADE_APPLIER.apply_final_upgrade(owner, option_id, role_id, role_data, special_data)
		"final_combat_core":
			PLAYER_FINAL_UPGRADE_APPLIER.apply_final_upgrade(owner, option_id, role_id, role_data, special_data)
		"final_skill_core":
			PLAYER_FINAL_UPGRADE_APPLIER.apply_final_upgrade(owner, option_id, role_id, role_data, special_data)
	if option_id in ["body_move_speed", "body_vitality", "body_pickup_range", "body_guard", "body_sword_blood", "combat_role_focus", "combat_rhythm", "combat_role_range", "combat_sword_crescent", "combat_sword_thrust", "combat_gunner_scatter", "combat_gunner_focus", "combat_gunner_lock", "combat_mage_echo", "combat_mage_frost", "combat_mage_gravity", "skill_sword_counter", "skill_sword_stance", "body_gunner_reload", "body_mage_flow"]:
		owner._apply_role_share(role_id, 0.9, 0.0, 2.0, 0.06)
	elif option_id in ["combat_team_power", "skill_switch_mastery", "skill_support_link", "skill_gunner_support", "skill_mage_support", "combat_move_speed", "combat_vitality", "combat_pickup_range", "combat_guard"]:
		owner._apply_role_share(role_id, 1.2, 0.025, 3.0, 0.1)
		owner.role_switch_cooldown_bonus += 0.06
	elif option_id in ["skill_sword_pursuit", "skill_gunner_barrage", "skill_mage_storm", "skill_energy_flow", "skill_ultimate_tuning", "skill_gunner_overheat", "skill_mage_tidal_flow"]:
		owner._apply_role_share(role_id, 2.0, 0.05, 6.0, 0.08)
	elif option_id == "final_combat_core":
		owner._apply_role_share(role_id, 4.0, 0.09, 12.0, 0.18)
	elif option_id == "final_skill_core":
		owner._apply_role_share(role_id, 2.2, 0.04, 5.0, 0.16)

	owner.role_upgrade_levels[role_id] = role_data
	owner.role_special_states[role_id] = special_data
	owner.level_up_active = false
	owner._update_fire_timer()
	owner.stats_changed.emit(owner.get_stat_summary())
	owner._try_request_level_up()
