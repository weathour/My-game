extends RefCounted

const BUILD_SYSTEM := preload("res://scripts/build/build_system.gd")

static func apply_battle_card(owner, option_id: String) -> bool:
	var card_id := BUILD_SYSTEM.get_shared_card_id(option_id)
	match card_id:
		"battle_dangzhen_qichao":
			owner._record_card_pick("body", card_id)
			return true
		"battle_dangzhen_dielang":
			owner._record_card_pick("body", card_id)
			return true
		"battle_dangzhen_huichao":
			owner._record_card_pick("body", card_id)
			return true
		"battle_omni_pierce":
			owner._record_card_pick("body", card_id)
			owner._apply_team_role_bonus(1.4, 0.0, 6.0, 0.05)
			owner._increase_team_specials([
				{"role_id": "swordsman", "key": "thrust_level"},
				{"role_id": "gunner", "key": "focus_level"},
				{"role_id": "mage", "key": "storm_level"}
			])
			return true
		"battle_omni_fan":
			owner._record_card_pick("body", card_id)
			owner._apply_team_role_bonus(1.0, 0.0, 7.0, 0.06)
			owner._increase_team_specials([
				{"role_id": "swordsman", "key": "crescent_level"},
				{"role_id": "gunner", "key": "scatter_level"},
				{"role_id": "mage", "key": "echo_level"}
			])
			return true
		"battle_omni_ring":
			owner._record_card_pick("body", card_id)
			owner._apply_team_role_bonus(0.8, 0.0, 9.0, 0.08)
			owner._increase_team_specials([
				{"role_id": "swordsman", "key": "stance_level"},
				{"role_id": "gunner", "key": "scatter_level"},
				{"role_id": "mage", "key": "flow_level"}
			])
			return true
		"battle_blood_drink":
			owner._record_card_pick("body", card_id)
			owner._increase_team_specials([
				{"role_id": "swordsman", "key": "blood_level"},
				{"role_id": "gunner", "key": "reload_level"},
				{"role_id": "mage", "key": "flow_level"}
			])
			owner._heal(8.0)
			owner._add_active_role_mana(6.0, false)
			owner._emit_active_mana_changed()
			return true
		"battle_blood_shield":
			owner._record_card_pick("body", card_id)
			owner.max_health += 8.0
			owner.current_health = min(owner.max_health, owner.current_health + 8.0)
			owner.damage_taken_multiplier = max(0.55, owner.damage_taken_multiplier - 0.025)
			owner._increase_team_specials([
				{"role_id": "swordsman", "key": "stance_level"},
				{"role_id": "gunner", "key": "lock_level"},
				{"role_id": "mage", "key": "frost_level"}
			])
			owner.health_changed.emit(owner.current_health, owner.max_health)
			return true
		"battle_blood_reflux":
			owner._record_card_pick("body", card_id)
			owner._apply_team_role_bonus(0.8, 0.0, 5.0, 0.05)
			owner.damage_taken_multiplier = max(0.55, owner.damage_taken_multiplier - 0.02)
			owner._increase_team_specials([
				{"role_id": "swordsman", "key": "counter_level"},
				{"role_id": "gunner", "key": "lock_level"},
				{"role_id": "mage", "key": "frost_level"}
			])
			return true
		"battle_finale_charge":
			owner._record_card_pick("body", card_id)
			owner.energy_gain_multiplier += 0.08
			owner.max_mana += 4.0
			owner._add_active_role_mana(10.0)
			return true
		"battle_finale_break":
			owner._record_card_pick("body", card_id)
			owner.ultimate_cost_multiplier = max(0.58, owner.ultimate_cost_multiplier - 0.04)
			owner._increase_team_specials([
				{"role_id": "swordsman", "key": "pursuit_level"},
				{"role_id": "gunner", "key": "barrage_level"},
				{"role_id": "mage", "key": "storm_level"}
			])
			owner._add_active_role_mana(8.0)
			return true
		"battle_finale_unity":
			owner._record_card_pick("body", card_id)
			owner.global_damage_multiplier += 0.03
			owner.background_interval_multiplier = max(0.45, owner.background_interval_multiplier - 0.04)
			owner._increase_team_specials([
				{"role_id": "swordsman", "key": "pursuit_level"},
				{"role_id": "gunner", "key": "support_level"},
				{"role_id": "mage", "key": "flow_level"}
			])
			owner._add_active_role_mana(8.0)
			return true
		"battle_cover":
			owner._record_card_pick("body", option_id)
			owner._apply_team_role_bonus(1.5, 0.0, 10.0, 0.04)
			owner._increase_team_specials([
				{"role_id": "swordsman", "key": "crescent_level"},
				{"role_id": "gunner", "key": "scatter_level"},
				{"role_id": "mage", "key": "frost_level"}
			])
			return true
		"battle_tempo":
			owner._record_card_pick("body", option_id)
			owner._apply_team_role_bonus(0.0, 0.05 * 0.8, 0.0, 0.0)
			return true
		"battle_split":
			owner._record_card_pick("body", option_id)
			owner._apply_team_role_bonus(1.2, 0.0, 4.0, 0.06)
			owner._increase_team_specials([
				{"role_id": "swordsman", "key": "crescent_level"},
				{"role_id": "gunner", "key": "scatter_level"},
				{"role_id": "mage", "key": "echo_level"}
			])
			return true
		"battle_devour":
			owner._record_card_pick("body", option_id)
			owner._increase_team_specials([
				{"role_id": "swordsman", "key": "blood_level"},
				{"role_id": "gunner", "key": "reload_level"},
				{"role_id": "mage", "key": "flow_level"}
			])
			owner.max_health += 8.0
			owner.current_health = min(owner.max_health, owner.current_health + 10.0)
			owner._add_active_role_mana(8.0, false)
			owner.health_changed.emit(owner.current_health, owner.max_health)
			owner._emit_active_mana_changed()
			return true
		"battle_suppress":
			owner._record_card_pick("body", option_id)
			owner._apply_team_role_bonus(1.0, 0.0, 6.0, 0.08)
			owner.damage_taken_multiplier = max(0.58, owner.damage_taken_multiplier - 0.03)
			owner._increase_team_specials([
				{"role_id": "swordsman", "key": "stance_level"},
				{"role_id": "gunner", "key": "lock_level"},
				{"role_id": "mage", "key": "frost_level"}
			])
			return true
		"battle_hunt":
			owner._record_card_pick("body", option_id)
			owner._apply_team_role_bonus(2.4, 0.0, 6.0, 0.08)
			owner._increase_team_specials([
				{"role_id": "swordsman", "key": "thrust_level"},
				{"role_id": "gunner", "key": "focus_level"},
				{"role_id": "mage", "key": "gravity_level"}
			])
			return true
		"battle_focus":
			owner._record_card_pick("body", option_id)
			owner._apply_team_role_bonus(3.4, 0.02, 8.0, 0.1)
			return true
		"battle_overload":
			owner._record_card_pick("body", option_id)
			owner._apply_team_role_bonus(1.8, 0.0, 0.0, 0.04)
			return true
		"battle_chain":
			owner._record_card_pick("body", option_id)
			return true
		"battle_break":
			owner._record_card_pick("body", option_id)
			return true
		"battle_tide":
			owner._record_card_pick("body", option_id)
			return true
		"battle_aftershock":
			owner._record_card_pick("body", option_id)
			return true
		_:
			return false

static func apply_combat_card(owner, option_id: String) -> bool:
	match option_id:
		"combat_tuning":
			owner._record_card_pick("combat", option_id)
			owner.role_switch_cooldown_bonus += 0.45
			owner.switch_cooldown_remaining = max(0.0, owner.switch_cooldown_remaining - 1.0)
			return true
		"combat_assault":
			owner._record_card_pick("combat", option_id)
			owner._apply_team_role_bonus(1.4, 0.0, 4.0, 0.08)
			return true
		"combat_legacy":
			owner._record_card_pick("combat", option_id)
			owner.max_health += 6.0
			owner.current_health = min(owner.max_health, owner.current_health + 8.0)
			owner.health_changed.emit(owner.current_health, owner.max_health)
			return true
		"combat_relay":
			owner._record_card_pick("combat", option_id)
			owner.role_switch_cooldown_bonus += 0.12
			return true
		"combat_support":
			owner._record_card_pick("combat", option_id)
			owner.background_interval_multiplier = max(0.5, owner.background_interval_multiplier - 0.08)
			owner._increase_role_special("gunner", "support_level", 1)
			owner._increase_role_special("mage", "support_level", 1)
			return true
		"combat_resonance":
			owner._record_card_pick("combat", option_id)
			owner.global_damage_multiplier += 0.04
			owner.role_switch_cooldown_bonus += 0.18
			owner._apply_team_role_bonus(1.2, 0.0, 3.0, 0.06)
			return true
		"combat_symbol":
			owner._record_card_pick("combat", option_id)
			owner._add_active_role_mana(10.0)
			return true
		"combat_fixed_axis":
			owner._record_card_pick("combat", option_id)
			owner.global_damage_multiplier += 0.08
			owner.background_interval_multiplier = max(0.45, owner.background_interval_multiplier - 0.1)
			return true
		"combat_swap":
			owner._record_card_pick("combat", option_id)
			return true
		"combat_rotation":
			owner._record_card_pick("combat", option_id)
			return true
		"combat_synergy":
			owner._record_card_pick("combat", option_id)
			return true
		"combat_rearguard":
			owner._record_card_pick("combat", option_id)
			return true
		_:
			return false

static func apply_skill_card(owner, option_id: String) -> bool:
	match option_id:
		"skill_energy_loop":
			owner._record_card_pick("skill", option_id)
			owner.energy_gain_multiplier += 0.12
			return true
		"skill_tuning":
			owner._record_card_pick("skill", option_id)
			owner.ultimate_cost_multiplier = max(0.58, owner.ultimate_cost_multiplier - 0.06)
			owner._add_active_role_mana(12.0)
			return true
		"skill_blossom":
			owner._record_card_pick("skill", option_id)
			owner._increase_team_specials([
				{"role_id": "swordsman", "key": "pursuit_level"},
				{"role_id": "gunner", "key": "barrage_level"},
				{"role_id": "mage", "key": "storm_level"}
			])
			owner._add_active_role_mana(8.0)
			return true
		"skill_reprise":
			owner._record_card_pick("skill", option_id)
			return true
		"skill_afterglow":
			owner._record_card_pick("skill", option_id)
			owner._apply_team_role_bonus(1.6, 0.02, 4.0, 0.08)
			return true
		"skill_charge":
			owner._record_card_pick("skill", option_id)
			owner.max_mana += 10.0
			owner._add_active_role_mana(15.0)
			return true
		"skill_resonance":
			owner._record_card_pick("skill", option_id)
			owner.background_interval_multiplier = max(0.5, owner.background_interval_multiplier - 0.05)
			owner.role_switch_cooldown_bonus += 0.25
			return true
		"skill_overdrive":
			owner._record_card_pick("skill", option_id)
			owner._add_active_role_mana(22.0)
			return true
		"skill_extend":
			owner._record_card_pick("skill", option_id)
			return true
		"skill_finale":
			owner._record_card_pick("skill", option_id)
			return true
		"skill_borrow_fire":
			owner._record_card_pick("skill", option_id)
			return true
		"skill_reflux":
			owner._record_card_pick("skill", option_id)
			return true
		_:
			return false
