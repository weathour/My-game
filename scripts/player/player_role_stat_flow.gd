extends RefCounted


static func build_background_cooldowns(owner) -> Dictionary:
	return {
		"swordsman": owner._get_effective_background_attack_interval("swordsman"),
		"gunner": owner._get_effective_background_attack_interval("gunner"),
		"mage": owner._get_effective_background_attack_interval("mage")
	}


static func get_active_interval_bonus(owner, role_id: String) -> float:
	var interval_bonus: float = float(owner.role_upgrade_levels.get(role_id, {}).get("interval_bonus", 0.0)) + owner._get_story_style_interval_bonus(role_id)
	if owner.switch_power_remaining > 0.0 and owner.switch_power_role_id == role_id:
		interval_bonus += owner.switch_power_interval_bonus
	if owner.entry_blessing_remaining > 0.0 and owner.entry_blessing_role_id == role_id:
		interval_bonus += owner.entry_haste_interval_bonus
	if owner.standby_entry_remaining > 0.0 and owner.standby_entry_role_id == role_id:
		interval_bonus += owner.standby_entry_interval_bonus
	if owner.borrow_fire_remaining > 0.0 and owner.borrow_fire_role_id == role_id:
		interval_bonus += owner.borrow_fire_interval_bonus
	if owner.frenzy_remaining > 0.0 and owner.frenzy_stacks > 0:
		interval_bonus += 0.012 * owner.frenzy_stacks
	return interval_bonus


static func get_effective_attack_interval(owner, role_id: String) -> float:
	var role_data := {}
	for candidate in owner.roles:
		if str(candidate.get("id", "")) == role_id:
			role_data = candidate
			break
	if role_data.is_empty():
		return 0.18
	var flat_reduction: float = 0.0
	if owner.has_method("_get_role_attack_interval_flat_reduction"):
		flat_reduction = float(owner._get_role_attack_interval_flat_reduction(role_id))
	var base_interval: float = max(0.18, float(role_data.get("attack_interval", 0.18)) - get_active_interval_bonus(owner, role_id) - flat_reduction)
	return max(0.18, base_interval * owner._get_role_attack_interval_multiplier(role_id))


static func get_effective_background_attack_interval(owner, role_id: String) -> float:
	return get_effective_attack_interval(owner, role_id) * 1.5 * get_effective_background_interval_multiplier(owner)


static func get_effective_background_interval_multiplier(owner) -> float:
	var multiplier: float = owner.background_interval_multiplier
	if owner.borrow_fire_remaining > 0.0:
		multiplier *= owner.borrow_fire_background_multiplier
	if owner.post_ultimate_flow_remaining > 0.0:
		multiplier *= owner.post_ultimate_flow_background_multiplier
	return max(0.32, multiplier)


static func get_current_move_speed(owner) -> float:
	var role_id: String = str(owner._get_active_role()["id"])
	var move_speed: float = owner.speed * float(owner._get_active_role()["speed_scale"])
	if owner.has_method("_get_role_blessing_stat_bonus"):
		move_speed += float(owner._get_role_blessing_stat_bonus(role_id, "move_speed"))
	move_speed *= owner._get_role_attribute_move_speed_multiplier(role_id)
	move_speed += owner._get_role_attribute_flat_move_speed_bonus(role_id)
	if owner.entry_blessing_remaining > 0.0 and owner.entry_blessing_role_id == role_id:
		move_speed *= owner.entry_haste_move_speed_multiplier
	if role_id == "gunner" and owner.has_method("_get_gunner_infinite_reload_move_speed_multiplier"):
		move_speed *= float(owner._get_gunner_infinite_reload_move_speed_multiplier())
	if owner._is_last_stand_active():
		move_speed *= 1.18
	if owner.frenzy_remaining > 0.0 and owner.frenzy_stacks > 0:
		move_speed *= 1.0 + 0.02 * owner.frenzy_stacks
	move_speed *= owner.enemy_move_slow_multiplier
	return move_speed


static func get_role_damage(owner, role_id: String) -> float:
	for role_data in owner.roles:
		if role_data["id"] != role_id:
			continue
		var upgrade_data: Dictionary = owner.role_upgrade_levels[role_id]
		var base_global_multiplier: float = owner.global_damage_multiplier - owner.equipment_damage_multiplier_bonus
		var role_equipment_bonus: float = owner._get_role_equipment_damage_multiplier_bonus(role_id)
		if owner.has_method("_get_role_blessing_stat_bonus"):
			role_equipment_bonus += float(owner._get_role_blessing_stat_bonus(role_id, "damage"))
		var primary_attribute_bonus: float = 0.0
		if owner.has_method("_get_primary_attribute_damage_bonus"):
			primary_attribute_bonus = float(owner._get_primary_attribute_damage_bonus(role_id))
		var damage_amount: float = (float(role_data["damage"]) + float(upgrade_data["damage_bonus"]) + primary_attribute_bonus) * max(0.01, base_global_multiplier + role_equipment_bonus)
		damage_amount *= owner._get_story_style_damage_multiplier(role_id)
		if owner.switch_power_remaining > 0.0 and owner.switch_power_role_id == role_id:
			damage_amount *= owner.switch_power_damage_multiplier
		if owner._is_last_stand_active():
			damage_amount *= 1.22
		if owner._has_elite_relic("elite_chain_overload") and role_id == str(owner._get_active_role().get("id", "")):
			damage_amount *= 0.92
		if owner.standby_entry_remaining > 0.0 and owner.standby_entry_role_id == role_id:
			damage_amount *= owner.standby_entry_damage_multiplier
		if owner.borrow_fire_remaining > 0.0 and owner.borrow_fire_role_id == role_id:
			damage_amount *= owner.borrow_fire_damage_multiplier
		if owner.frenzy_remaining > 0.0 and owner.frenzy_stacks > 0:
			damage_amount *= 1.0 + 0.015 * owner.frenzy_stacks
		return damage_amount
	return 0.0


static func apply_team_role_bonus(owner, damage_bonus: float, interval_bonus: float, range_bonus: float, skill_bonus: float) -> void:
	for role_data in owner.roles:
		var role_id: String = str(role_data["id"])
		var upgrade_data: Dictionary = owner.role_upgrade_levels.get(role_id, {}).duplicate(true)
		upgrade_data["damage_bonus"] = float(upgrade_data.get("damage_bonus", 0.0)) + damage_bonus
		upgrade_data["interval_bonus"] = float(upgrade_data.get("interval_bonus", 0.0)) + interval_bonus
		upgrade_data["range_bonus"] = float(upgrade_data.get("range_bonus", 0.0)) + range_bonus
		upgrade_data["skill_bonus"] = float(upgrade_data.get("skill_bonus", 0.0)) + skill_bonus
		owner.role_upgrade_levels[role_id] = upgrade_data


static func apply_role_share(owner, source_role_id: String, damage_bonus: float, interval_bonus: float, range_bonus: float, skill_bonus: float) -> void:
	for role_data in owner.roles:
		var target_role_id: String = str(role_data["id"])
		if target_role_id == source_role_id:
			continue
		var upgrade_data: Dictionary = owner.role_upgrade_levels.get(target_role_id, {}).duplicate(true)
		upgrade_data["damage_bonus"] = float(upgrade_data.get("damage_bonus", 0.0)) + damage_bonus * owner.ROLE_SHARE_DAMAGE_RATIO
		upgrade_data["interval_bonus"] = float(upgrade_data.get("interval_bonus", 0.0)) + interval_bonus * owner.ROLE_SHARE_INTERVAL_RATIO
		upgrade_data["range_bonus"] = float(upgrade_data.get("range_bonus", 0.0)) + range_bonus * owner.ROLE_SHARE_RANGE_RATIO
		upgrade_data["skill_bonus"] = float(upgrade_data.get("skill_bonus", 0.0)) + skill_bonus * owner.ROLE_SHARE_SKILL_RATIO
		owner.role_upgrade_levels[target_role_id] = upgrade_data


static func initialize_existing_role_shares(owner) -> void:
	if owner.role_share_initialized:
		return

	for role_data in owner.roles:
		var role_id: String = str(role_data["id"])
		var upgrade_data: Dictionary = owner.role_upgrade_levels.get(role_id, {})
		var special_data: Dictionary = owner._get_role_special_state(role_id)
		var role_level: int = int(upgrade_data.get("level", 0))
		var special_total: int = 0
		for value in special_data.values():
			special_total += int(value)
		if role_level <= 0 and special_total <= 0:
			continue
		apply_role_share(owner, role_id, role_level * 2.2 + special_total * 1.1, role_level * 0.04, role_level * 6.0 + special_total * 2.0, role_level * 0.1 + special_total * 0.05)

	owner.role_share_initialized = true
