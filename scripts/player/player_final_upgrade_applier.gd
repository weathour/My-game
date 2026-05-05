extends RefCounted


static func apply_final_upgrade(owner, option_id: String, role_id: String, role_data: Dictionary, special_data: Dictionary) -> void:
	match option_id:
		"final_body_core":
			owner.max_health += 36.0
			owner.pickup_radius += 14.0
			owner.damage_taken_multiplier = max(0.56, owner.damage_taken_multiplier - 0.08)
			owner._heal(36.0)
		"final_combat_core":
			apply_final_combat_core(owner, role_id, role_data, special_data)
		"final_skill_core":
			apply_final_skill_core(owner, role_id, special_data)


static func apply_final_combat_core(owner, role_id: String, role_data: Dictionary, _special_data: Dictionary) -> void:
	owner.global_damage_multiplier += 0.12
	role_data["damage_bonus"] = float(role_data["damage_bonus"]) + 8.0
	if role_id == "swordsman":
		role_data["skill_bonus"] = float(role_data["skill_bonus"]) + 0.24
		owner.damage_taken_multiplier = max(0.52, owner.damage_taken_multiplier - 0.05)
		owner._heal(18.0)
	elif role_id == "gunner":
		role_data["range_bonus"] = float(role_data["range_bonus"]) + 16.0
		role_data["interval_bonus"] = float(role_data["interval_bonus"]) + 0.05
		role_data["skill_bonus"] = float(role_data["skill_bonus"]) + 0.18
	elif role_id == "mage":
		role_data["range_bonus"] = float(role_data["range_bonus"]) + 18.0
		role_data["skill_bonus"] = float(role_data["skill_bonus"]) + 0.22
		role_data["damage_bonus"] = float(role_data["damage_bonus"]) + 2.0


static func apply_final_skill_core(owner, _role_id: String, _special_data: Dictionary) -> void:
	owner.energy_gain_multiplier += 0.16
	owner.background_interval_multiplier = max(0.6, owner.background_interval_multiplier - 0.08)
	owner.ultimate_cost_multiplier = max(0.6, owner.ultimate_cost_multiplier - 0.08)
	owner.role_switch_cooldown_bonus += 0.7
	owner._add_active_role_mana(30.0)
