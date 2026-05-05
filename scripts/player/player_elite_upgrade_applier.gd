extends RefCounted


static func apply_elite_upgrade(owner, option_id: String) -> void:
	owner._unlock_elite_relic(option_id)
	match option_id:
		"elite_behemoth":
			owner.max_health += 45.0
			owner.current_health = min(owner.max_health, owner.current_health + 45.0)
			owner.damage_taken_multiplier = max(0.48, owner.damage_taken_multiplier - 0.08)
			owner.health_changed.emit(owner.current_health, owner.max_health)
		"elite_gale":
			owner.speed += 30.0
			owner.pickup_radius += 12.0
			owner.role_switch_cooldown_bonus += 0.6
			owner.switch_cooldown_remaining = max(0.0, owner.switch_cooldown_remaining - 0.8)
		"elite_overcharge_reserve":
			owner.max_mana += 24.0
			owner._add_active_role_mana(24.0, false)
			owner.energy_gain_multiplier += 0.18
			owner._emit_active_mana_changed()
		"elite_fixed_axis_core":
			owner.global_damage_multiplier += 0.16
			owner.background_interval_multiplier = max(0.42, owner.background_interval_multiplier - 0.14)
		"elite_chain_overload":
			owner.background_interval_multiplier = max(0.38, owner.background_interval_multiplier - 0.18)
		"elite_reactor":
			owner._add_active_role_mana(12.0)
		"elite_perpetual_motion":
			owner.perpetual_motion_cooldown_remaining = 0.0
		"elite_battle_frenzy":
			owner.frenzy_remaining = 0.0
			owner.frenzy_stacks = 0
			owner.frenzy_overkill_counter = 0


static func is_elite_upgrade(option_id: String) -> bool:
	return option_id in [
		"elite_behemoth",
		"elite_gale",
		"elite_overcharge_reserve",
		"elite_mirror_finisher",
		"elite_fixed_axis_core",
		"elite_last_stand",
		"elite_execution_pact",
		"elite_reactor",
		"elite_chain_overload",
		"elite_fate_shift",
		"elite_perpetual_motion",
		"elite_battle_frenzy"
	]
