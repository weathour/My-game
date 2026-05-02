extends RefCounted

const FIRST_BATCH_DB := preload("res://scripts/build/build_first_batch_database.gd")
const FIRST_BATCH_RUNTIME := preload("res://scripts/build/build_first_batch_runtime.gd")

const ROLE_SPECIAL_KEYS := {
	"swordsman": {
		"damage": "thrust_level",
		"control": "crescent_level",
		"survival": "stance_level",
		"support": "counter_level",
		"summon": "counter_level",
		"resource": "blood_level",
		"mobility": "pursuit_level"
	},
	"gunner": {
		"damage": "focus_level",
		"control": "lock_level",
		"survival": "lock_level",
		"support": "support_level",
		"summon": "support_level",
		"resource": "reload_level",
		"mobility": "scatter_level"
	},
	"mage": {
		"damage": "storm_level",
		"control": "frost_level",
		"survival": "frost_level",
		"support": "support_level",
		"summon": "support_level",
		"resource": "flow_level",
		"mobility": "echo_level"
	}
}

const ROLE_DAMAGE_SPECIAL := {
	"swordsman": "thrust_level",
	"gunner": "barrage_level",
	"mage": "storm_level"
}

const ROLE_CONTROL_SPECIAL := {
	"swordsman": "crescent_level",
	"gunner": "scatter_level",
	"mage": "gravity_level"
}

const ROLE_RESOURCE_SPECIAL := {
	"swordsman": "blood_level",
	"gunner": "reload_level",
	"mage": "flow_level"
}


static func apply_card(owner, option_id: String) -> bool:
	if option_id == FIRST_BATCH_RUNTIME.FALLBACK_CARD_ID:
		_apply_fallback(owner)
		return true
	var card := FIRST_BATCH_DB.get_card_data(option_id)
	if card.is_empty() or str(card.get("card_type", "")) == FIRST_BATCH_DB.CARD_TYPE_MASTERY:
		return false
	var card_id := str(card.get("id", option_id))
	var next_level := _record_first_batch_pick(owner, card)
	_apply_stat_profile(owner, card, next_level)
	_apply_role_special_profile(owner, card, next_level)
	_apply_axis_profile(owner, card, next_level)
	_apply_named_card_profile(owner, card_id, next_level)
	if owner != null:
		owner.set("current_build_offer", {})
		if owner.has_signal("health_changed"):
			owner.health_changed.emit(owner.current_health, owner.max_health)
		if owner.has_method("_emit_active_mana_changed"):
			owner._emit_active_mana_changed()
	return true


static func _record_first_batch_pick(owner, card: Dictionary) -> int:
	var card_id := str(card.get("id", ""))
	var max_level := int(card.get("max_level", 1))
	var previous := int(owner.card_pick_levels.get(card_id, 0))
	var next_level: int = clamp(previous + 1, 0, max_level)
	owner.card_pick_levels[card_id] = next_level
	if owner.has_method("_record_build_pick"):
		owner._record_build_pick(_slot_for_card(card))
	return next_level


static func _slot_for_card(card: Dictionary) -> String:
	var card_type := str(card.get("card_type", ""))
	if card_type == FIRST_BATCH_DB.CARD_TYPE_RESONANCE_PAIR or card_type == FIRST_BATCH_DB.CARD_TYPE_RESONANCE_TRI:
		return "combat"
	var axes: Array = card.get("upgrade_axes", [])
	if card_type == FIRST_BATCH_DB.CARD_TYPE_CAPSTONE or axes.has(FIRST_BATCH_DB.AXIS_ULTIMATE) or axes.has(FIRST_BATCH_DB.AXIS_CAPSTONE):
		return "skill"
	return "body"


static func _apply_stat_profile(owner, card: Dictionary, _next_level: int) -> void:
	var positions: Dictionary = card.get("position_weights", {})
	var card_type := str(card.get("card_type", ""))
	var owner_role := str(card.get("owner_role", ""))
	var is_team_card := owner_role == "" or card_type == FIRST_BATCH_DB.CARD_TYPE_RESONANCE_PAIR or card_type == FIRST_BATCH_DB.CARD_TYPE_RESONANCE_TRI or card_type == FIRST_BATCH_DB.CARD_TYPE_GENERIC
	var damage_w := float(positions.get(FIRST_BATCH_DB.POSITION_DAMAGE, 0.0))
	var control_w := float(positions.get(FIRST_BATCH_DB.POSITION_CONTROL, 0.0))
	var survival_w := float(positions.get(FIRST_BATCH_DB.POSITION_SURVIVAL, 0.0))
	var support_w := float(positions.get(FIRST_BATCH_DB.POSITION_SUPPORT, 0.0))
	var summon_w := float(positions.get(FIRST_BATCH_DB.POSITION_SUMMON, 0.0))
	var resource_w := float(positions.get(FIRST_BATCH_DB.POSITION_RESOURCE, 0.0))
	var mobility_w := float(positions.get(FIRST_BATCH_DB.POSITION_MOBILITY, 0.0))
	var damage_bonus := 0.9 + damage_w * 1.8 + summon_w * 0.6
	var interval_bonus := 0.012 + mobility_w * 0.022 + resource_w * 0.01
	var range_bonus := 2.0 + control_w * 7.0 + support_w * 4.0
	var skill_bonus := 0.035 + control_w * 0.045 + support_w * 0.045 + summon_w * 0.05
	if is_team_card:
		owner._apply_team_role_bonus(damage_bonus * 0.55, interval_bonus * 0.55, range_bonus * 0.55, skill_bonus * 0.55)
	else:
		_apply_role_bonus(owner, owner_role, damage_bonus, interval_bonus, range_bonus, skill_bonus)
	if card_type == FIRST_BATCH_DB.CARD_TYPE_CAPSTONE:
		_apply_role_bonus(owner, owner_role, 2.6, 0.025, 7.0, 0.12)
		owner.ultimate_cost_multiplier = max(0.58, owner.ultimate_cost_multiplier - 0.04)
		owner._add_active_role_mana(12.0, false)
	if survival_w > 0.0:
		var health_gain := 4.0 + survival_w * (10.0 if is_team_card else 14.0)
		owner.max_health += health_gain
		owner.current_health = min(owner.max_health, owner.current_health + health_gain * 0.75)
		owner.damage_taken_multiplier = max(0.55, owner.damage_taken_multiplier - survival_w * 0.01)
	if resource_w > 0.0:
		owner.energy_gain_multiplier += resource_w * 0.025
		owner.max_mana += resource_w * 1.8
		owner._add_active_role_mana(4.0 + resource_w * 4.0, false)
	if mobility_w > 0.0:
		owner.speed += mobility_w * 3.5
		owner.role_switch_cooldown_bonus += mobility_w * 0.035
	if support_w > 0.0:
		owner.background_interval_multiplier = max(0.45, owner.background_interval_multiplier - support_w * 0.012)
	if summon_w > 0.0:
		owner.background_interval_multiplier = max(0.45, owner.background_interval_multiplier - summon_w * 0.008)


static func _apply_role_special_profile(owner, card: Dictionary, _next_level: int) -> void:
	var role_weights: Dictionary = card.get("role_weights", {})
	var owner_role := str(card.get("owner_role", ""))
	if role_weights.is_empty() and owner_role != "":
		role_weights = {owner_role: 1.0}
	var positions: Dictionary = card.get("position_weights", {})
	for role_id_value in role_weights.keys():
		var role_id := str(role_id_value)
		var role_weight := float(role_weights.get(role_id, 0.0))
		if role_weight <= 0.0:
			continue
		var strongest_position := _get_strongest_position(positions)
		var key := _special_key_for_position(role_id, strongest_position)
		if key != "":
			owner._increase_role_special(role_id, key, 1)
		if float(positions.get(FIRST_BATCH_DB.POSITION_DAMAGE, 0.0)) >= 0.6:
			owner._increase_role_special(role_id, str(ROLE_DAMAGE_SPECIAL.get(role_id, key)), 1)
		if float(positions.get(FIRST_BATCH_DB.POSITION_CONTROL, 0.0)) >= 0.6:
			owner._increase_role_special(role_id, str(ROLE_CONTROL_SPECIAL.get(role_id, key)), 1)
		if float(positions.get(FIRST_BATCH_DB.POSITION_RESOURCE, 0.0)) >= 0.55:
			owner._increase_role_special(role_id, str(ROLE_RESOURCE_SPECIAL.get(role_id, key)), 1)


static func _apply_axis_profile(owner, card: Dictionary, _next_level: int) -> void:
	var axes: Array = card.get("upgrade_axes", [])
	var owner_role := str(card.get("owner_role", ""))
	if axes.has(FIRST_BATCH_DB.AXIS_ENTRY):
		owner.role_switch_cooldown_bonus += 0.07
		if owner_role != "":
			_apply_role_bonus(owner, owner_role, 1.0, 0.012, 2.0, 0.035)
	if axes.has(FIRST_BATCH_DB.AXIS_EXIT):
		owner.background_interval_multiplier = max(0.45, owner.background_interval_multiplier - 0.01)
		owner._add_active_role_mana(4.0, false)
	if axes.has(FIRST_BATCH_DB.AXIS_ULTIMATE):
		owner.ultimate_cost_multiplier = max(0.58, owner.ultimate_cost_multiplier - 0.025)
		owner.energy_gain_multiplier += 0.02
		owner._add_active_role_mana(8.0, false)
	if axes.has(FIRST_BATCH_DB.AXIS_INDEPENDENT_PASSIVE):
		owner.role_switch_cooldown_bonus += 0.05
		owner.background_interval_multiplier = max(0.45, owner.background_interval_multiplier - 0.012)


static func _apply_named_card_profile(owner, card_id: String, _next_level: int) -> void:
	match card_id:
		"swd_break_step":
			owner._increase_role_special("swordsman", "thrust_level", 1)
			owner._increase_role_special("swordsman", "pursuit_level", 1)
		"swd_blood_echo":
			owner._increase_role_special("swordsman", "blood_level", 1)
			owner._heal(6.0)
		"swd_tide_pull":
			owner._increase_role_special("swordsman", "crescent_level", 1)
			owner._increase_role_special("swordsman", "stance_level", 1)
		"swd_overheal_guard":
			owner._increase_role_special("swordsman", "stance_level", 1)
			owner.damage_taken_multiplier = max(0.55, owner.damage_taken_multiplier - 0.015)
		"swd_blade_shadow":
			owner._increase_role_special("swordsman", "counter_level", 2)
		"swd_break_execute", "swd_tide_unbound":
			owner._increase_role_special("swordsman", "pursuit_level", 2)
			owner._increase_role_special("swordsman", "thrust_level", 1)
		"gun_entry_barrage":
			owner._increase_role_special("gunner", "barrage_level", 1)
			owner._increase_role_special("gunner", "scatter_level", 1)
		"gun_overload_mag":
			owner._increase_role_special("gunner", "reload_level", 1)
			owner._increase_role_special("gunner", "barrage_level", 1)
		"gun_fireline_mark":
			owner._increase_role_special("gunner", "focus_level", 1)
			owner._increase_role_special("gunner", "lock_level", 1)
		"gun_tactical_reload":
			owner._increase_role_special("gunner", "reload_level", 2)
		"gun_spotter_drone":
			owner._increase_role_special("gunner", "support_level", 2)
			owner._increase_role_special("gunner", "lock_level", 1)
		"gun_suppression_grid":
			owner._increase_role_special("gunner", "scatter_level", 1)
			owner._increase_role_special("gunner", "lock_level", 1)
		"gun_infinite_fireline":
			owner._increase_role_special("gunner", "barrage_level", 2)
			owner._increase_role_special("gunner", "focus_level", 1)
		"mag_starfall_seed":
			owner._increase_role_special("mage", "storm_level", 1)
			owner._increase_role_special("mage", "gravity_level", 1)
		"mag_mana_tide":
			owner._increase_role_special("mage", "flow_level", 2)
			owner._add_active_role_mana(8.0, false)
		"mag_frost_seal":
			owner._increase_role_special("mage", "frost_level", 2)
		"mag_field_convergence":
			owner._increase_role_special("mage", "echo_level", 1)
			owner._increase_role_special("mage", "gravity_level", 1)
		"mag_guardian_puppet":
			owner._increase_role_special("mage", "support_level", 2)
			owner._increase_role_special("mage", "frost_level", 1)
		"mag_orbital_script":
			owner._increase_role_special("mage", "echo_level", 2)
		"mag_sky_dome":
			owner._increase_role_special("mage", "storm_level", 2)
			owner._increase_role_special("mage", "gravity_level", 1)
		"res_swd_gun_open_fire", "res_gun_swd_cover_dash":
			owner._increase_role_special("swordsman", "thrust_level", 1)
			owner._increase_role_special("gunner", "focus_level", 1)
		"res_gun_mag_orbital_lock", "res_mag_gun_arcane_reload":
			owner._increase_role_special("gunner", "lock_level", 1)
			owner._increase_role_special("mage", "flow_level", 1)
		"res_mag_swd_star_cleave", "res_swd_mag_blood_ward":
			owner._increase_role_special("mage", "gravity_level", 1)
			owner._increase_role_special("swordsman", "stance_level", 1)
		"res_tri_three_step_cycle", "res_tri_all_damage_concert", "res_tri_guard_loop":
			owner._increase_team_specials([
				{"role_id": "swordsman", "key": "pursuit_level"},
				{"role_id": "gunner", "key": "barrage_level"},
				{"role_id": "mage", "key": "storm_level"}
			])
		"gen_vital_pace":
			owner.max_health += 8.0
			owner.current_health = min(owner.max_health, owner.current_health + 8.0)
		"gen_pickup_focus":
			owner.pickup_radius += 7.0
			owner.energy_gain_multiplier += 0.025
		"gen_switch_tempo":
			owner.role_switch_cooldown_bonus += 0.18
		"gen_field_rations":
			owner._heal(12.0)
			owner._add_active_role_mana(6.0, false)
		"gen_second_wind":
			owner.damage_taken_multiplier = max(0.55, owner.damage_taken_multiplier - 0.02)
			owner._heal(10.0)


static func _apply_fallback(owner) -> void:
	if owner.has_method("_record_build_pick"):
		owner._record_build_pick("body")
	owner.max_health += 10.0
	owner.current_health = min(owner.max_health, owner.current_health + 10.0)
	owner.global_damage_multiplier += 0.02
	owner.energy_gain_multiplier += 0.02
	owner.set("current_build_offer", {})
	if owner.has_signal("health_changed"):
		owner.health_changed.emit(owner.current_health, owner.max_health)


static func _apply_role_bonus(owner, role_id: String, damage_bonus: float, interval_bonus: float, range_bonus: float, skill_bonus: float) -> void:
	if role_id == "":
		return
	var upgrade_data: Dictionary = owner.role_upgrade_levels.get(role_id, {}).duplicate(true)
	upgrade_data["damage_bonus"] = float(upgrade_data.get("damage_bonus", 0.0)) + damage_bonus
	upgrade_data["interval_bonus"] = float(upgrade_data.get("interval_bonus", 0.0)) + interval_bonus
	upgrade_data["range_bonus"] = float(upgrade_data.get("range_bonus", 0.0)) + range_bonus
	upgrade_data["skill_bonus"] = float(upgrade_data.get("skill_bonus", 0.0)) + skill_bonus
	owner.role_upgrade_levels[role_id] = upgrade_data


static func _get_strongest_position(positions: Dictionary) -> String:
	var best_key := FIRST_BATCH_DB.POSITION_DAMAGE
	var best_weight := -999.0
	for key in positions.keys():
		var weight := float(positions.get(key, 0.0))
		if weight > best_weight:
			best_key = str(key)
			best_weight = weight
	return best_key


static func _special_key_for_position(role_id: String, position: String) -> String:
	var map: Dictionary = ROLE_SPECIAL_KEYS.get(role_id, {})
	return str(map.get(position, ""))
