extends RefCounted

const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const PLAYER_SWORDSMAN_TRAIT_RUNTIME_FLOW := preload("res://scripts/player/player_swordsman_trait_runtime_flow.gd")
const PLAYER_GUNNER_FLASH_TALENT_FLOW := preload("res://scripts/player/player_gunner_flash_talent_flow.gd")
const PLAYER_GUNNER_ENTRY_TALENT_FLOW := preload("res://scripts/player/player_gunner_entry_talent_flow.gd")
const PLAYER_SWORDSMAN_KING_BLADE_FLOW := preload("res://scripts/player/player_swordsman_king_blade_flow.gd")
const PLAYER_RUAN_STONE_STAT_FLOW := preload("res://scripts/player/player_ruan_stone_stat_flow.gd")

const GLOBAL_UNIT_MOVE_SPEED_SCALE := 0.7


static func build_background_cooldowns(owner) -> Dictionary:
	return {
		"swordsman": owner._get_effective_background_attack_interval("swordsman"),
		"gunner": owner._get_effective_background_attack_interval("gunner"),
		"mage": owner._get_effective_background_attack_interval("mage"),
		"mechanic": owner._get_effective_background_attack_interval("mechanic")
	}


static func get_role_theme_color(owner, role_id: String) -> Color:
	for role_data in owner.roles:
		if str(role_data.get("id", "")) == role_id:
			return role_data.get("color", Color.WHITE)
	return Color.WHITE


static func get_active_interval_bonus(owner, role_id: String) -> float:
	# These fields are retained for old runs and dormant entry effects that still
	# store a reduction in seconds. Convert their combined value once into the
	# additive speed term used by the new formula.
	var legacy_interval_reduction: float = 0.0
	var role_upgrade_levels: Variant = owner.get("role_upgrade_levels")
	if role_upgrade_levels is Dictionary:
		var role_upgrade_data: Variant = (role_upgrade_levels as Dictionary).get(role_id, {})
		if role_upgrade_data is Dictionary:
			legacy_interval_reduction += float((role_upgrade_data as Dictionary).get("interval_bonus", 0.0))
	if _owner_float(owner, "switch_power_remaining") > 0.0 and str(owner.get("switch_power_role_id")) == role_id:
		legacy_interval_reduction += _owner_float(owner, "switch_power_interval_bonus")
	if _owner_float(owner, "entry_blessing_remaining") > 0.0 and str(owner.get("entry_blessing_role_id")) == role_id:
		legacy_interval_reduction += _owner_float(owner, "entry_haste_interval_bonus")
	if _owner_float(owner, "standby_entry_remaining") > 0.0 and str(owner.get("standby_entry_role_id")) == role_id:
		legacy_interval_reduction += _owner_float(owner, "standby_entry_interval_bonus")
	if _owner_float(owner, "borrow_fire_remaining") > 0.0 and str(owner.get("borrow_fire_role_id")) == role_id:
		legacy_interval_reduction += _owner_float(owner, "borrow_fire_interval_bonus")
	if _owner_float(owner, "frenzy_remaining") > 0.0 and int(_owner_float(owner, "frenzy_stacks")) > 0:
		legacy_interval_reduction += 0.012 * _owner_float(owner, "frenzy_stacks")
	return _legacy_interval_bonus_to_speed(get_role_base_attack_speed(owner, role_id), legacy_interval_reduction)


static func _owner_float(owner, property_name: String) -> float:
	var value: Variant = owner.get(property_name)
	if value == null:
		return 0.0
	return float(value)


static func _legacy_interval_bonus_to_speed(base_attack_speed: float, interval_reduction: float) -> float:
	if interval_reduction <= 0.0:
		return 0.0
	var base_interval: float = 1.0 / maxf(0.01, base_attack_speed)
	var updated_interval: float = maxf(0.18, base_interval - interval_reduction)
	return 1.0 / updated_interval - base_attack_speed


static func get_role_base_attack_speed(owner, role_id: String) -> float:
	for role_data in owner.roles:
		if role_data is Dictionary and str((role_data as Dictionary).get("id", "")) == role_id:
			return maxf(0.01, float((role_data as Dictionary).get("base_attack_speed", 1.0)))
	return 1.0


static func get_effective_attack_speed(owner, role_id: String) -> float:
	var role_data := {}
	for candidate in owner.roles:
		if candidate is Dictionary and str((candidate as Dictionary).get("id", "")) == role_id:
			role_data = candidate
			break
	if role_data.is_empty():
		return 0.01

	var base_attack_speed: float = maxf(0.01, float(role_data.get("base_attack_speed", 1.0)))
	var attack_speed_bonus: float = get_active_interval_bonus(owner, role_id)

	# Percentage bonuses are absolute additions: base speed + 1 × bonus.
	if owner.has_method("_get_role_blessing_stat_bonus"):
		attack_speed_bonus += float(owner._get_role_blessing_stat_bonus(role_id, "basic_attack_speed_percent"))
	if owner.has_method("_get_role_equipment_attack_speed_percent_bonus"):
		attack_speed_bonus += float(owner._get_role_equipment_attack_speed_percent_bonus(role_id))
	elif owner.has_method("_get_role_equipment_bonus_summary"):
		attack_speed_bonus += float(owner._get_role_equipment_bonus_summary(role_id).get("attack_speed_percent_bonus", 0.0))
	attack_speed_bonus += PLAYER_RUAN_STONE_STAT_FLOW.get_attack_speed_percent_bonus(owner)
	attack_speed_bonus += PLAYER_BUILD_SYSTEM.get_basic_attack_speed_percent_bonus(owner, role_id)

	# Keep old interval-based talent hooks compatible. They are dormant in the
	# current game, but if an old save activates one, it still contributes to
	# the same additive final-speed term.
	if role_id == "swordsman" and owner.get("swordsman_role") != null:
		var talent_multiplier: float = maxf(0.01, float(owner.swordsman_role.get_talent_basic_attack_interval_multiplier(owner)))
		attack_speed_bonus += _legacy_interval_multiplier_to_speed(base_attack_speed, talent_multiplier)
	elif role_id == "gunner" and owner.get("gunner_role") != null:
		var talent_multiplier: float = maxf(0.01, float(owner.gunner_role.get_basic_attack_interval_multiplier(owner)))
		attack_speed_bonus += _legacy_interval_multiplier_to_speed(base_attack_speed, talent_multiplier)
	elif role_id == "mechanic" and owner.get("mechanic_role") != null:
		var talent_multiplier: float = maxf(0.01, float(owner.mechanic_role.get_basic_attack_interval_multiplier(owner)))
		attack_speed_bonus += _legacy_interval_multiplier_to_speed(base_attack_speed, talent_multiplier)

	return maxf(0.01, base_attack_speed + attack_speed_bonus)


static func _legacy_interval_multiplier_to_speed(base_attack_speed: float, interval_multiplier: float) -> float:
	if interval_multiplier >= 0.999999:
		return 0.0
	return base_attack_speed * (1.0 / interval_multiplier - 1.0)


static func get_effective_attack_interval(owner, role_id: String) -> float:
	return 1.0 / get_effective_attack_speed(owner, role_id)


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
	return get_role_move_speed(owner, role_id)


static func get_role_move_speed(owner, role_id: String) -> float:
	var role_data := {}
	for candidate in owner.roles:
		if candidate is Dictionary and str((candidate as Dictionary).get("id", "")) == role_id:
			role_data = candidate
			break
	if role_data.is_empty():
		return 0.0
	var active_role_id: String = str(owner._get_active_role().get("id", ""))
	var active_equipment_speed_bonus: float = float(owner.get("equipment_speed_bonus"))
	var role_equipment_speed_bonus := 0.0
	if owner.has_method("_get_role_equipment_bonus_summary"):
		role_equipment_speed_bonus = float(owner._get_role_equipment_bonus_summary(role_id).get("speed_bonus", 0.0))
	var owner_speed_for_role: float = max(0.0, float(owner.get("speed")) - active_equipment_speed_bonus + role_equipment_speed_bonus + PLAYER_RUAN_STONE_STAT_FLOW.get_speed_bonus(owner))
	var move_speed: float
	if role_data.has("move_speed"):
		move_speed = float(role_data.get("move_speed", owner.base_speed)) + (owner_speed_for_role - owner.base_speed)
	else:
		move_speed = owner_speed_for_role * float(role_data.get("speed_scale", 1.0)) * GLOBAL_UNIT_MOVE_SPEED_SCALE
	if owner.has_method("_get_role_blessing_stat_bonus"):
		move_speed += float(owner._get_role_blessing_stat_bonus(role_id, "move_speed"))
		move_speed *= max(0.01, 1.0 + float(owner._get_role_blessing_stat_bonus(role_id, "move_speed_percent")))
	move_speed *= max(0.01, 1.0 + PLAYER_RUAN_STONE_STAT_FLOW.get_move_speed_percent_bonus(owner))
	move_speed += PLAYER_SWORDSMAN_TRAIT_RUNTIME_FLOW.get_move_speed_bonus(owner, role_id)
	if role_id == "gunner" and owner.has_method("_get_gunner_hunt_move_speed_bonus"):
		move_speed += float(owner._get_gunner_hunt_move_speed_bonus(role_id))
	move_speed *= owner._get_role_attribute_move_speed_multiplier(role_id)
	if active_role_id != role_id:
		return move_speed
	if owner.entry_blessing_remaining > 0.0 and owner.entry_blessing_role_id == role_id:
		move_speed *= owner.entry_haste_move_speed_multiplier
	if role_id == "mage" and owner.has_method("_get_mage_flame_path_move_speed_multiplier"):
		move_speed *= float(owner._get_mage_flame_path_move_speed_multiplier())
	if role_id == "gunner" and owner.has_method("_get_gunner_infinite_reload_move_speed_multiplier"):
		move_speed *= float(owner._get_gunner_infinite_reload_move_speed_multiplier())
	if role_id == "gunner" and owner.has_method("_get_gunner_flash_move_speed_multiplier"):
		move_speed *= float(owner._get_gunner_flash_move_speed_multiplier())
	if role_id == "gunner":
		move_speed *= PLAYER_GUNNER_FLASH_TALENT_FLOW.get_move_speed_multiplier(owner, role_id)
	if role_id == "gunner" and owner.get("gunner_role") != null:
		move_speed *= float(owner.gunner_role.get_talent_move_speed_multiplier(owner))
	if owner.ultimate_haste_remaining > 0.0:
		move_speed *= max(0.0, float(owner.ultimate_haste_move_speed_multiplier))
	var mechanic_field = owner.get("mechanic_emp_burst_ability") if owner != null else null
	if mechanic_field != null and mechanic_field.has_method("get_field_haste_multiplier"):
		move_speed *= float(mechanic_field.get_field_haste_multiplier())
	if owner.frenzy_remaining > 0.0 and owner.frenzy_stacks > 0:
		move_speed *= 1.0 + 0.02 * owner.frenzy_stacks
	var slow_multiplier: float = minf(minf(owner.enemy_move_slow_multiplier, preload("res://scripts/enemies/elite_charge_ground.gd").get_slow_multiplier(owner)), preload("res://scripts/enemies/skulltomb_domain_effect.gd").get_slow_multiplier(owner))
	move_speed *= minf(slow_multiplier, preload("res://scripts/player/player_plague_flow.gd").get_slow_multiplier(owner))
	return move_speed


static func get_active_role_base_health(owner) -> float:
	var role_data: Dictionary = owner._get_active_role() if owner != null and owner.has_method("_get_active_role") else {}
	return max(1.0, float(role_data.get("base_health", owner.max_health if owner != null else 1.0)))


static func build_role_health_state(owner) -> Dictionary:
	var result: Dictionary = {}
	if owner == null:
		return result
	for role_data in owner.roles:
		if role_data is not Dictionary:
			continue
		var role_id: String = str((role_data as Dictionary).get("id", ""))
		if role_id == "":
			continue
		result[role_id] = get_role_max_health(owner, role_id)
	return result


static func normalize_role_health_state(owner, value: Variant) -> Dictionary:
	var result := build_role_health_state(owner)
	if value is not Dictionary:
		return result
	for role_id_value in result.keys():
		var role_id := str(role_id_value)
		var max_value: float = get_role_max_health(owner, role_id)
		result[role_id] = clamp(float((value as Dictionary).get(role_id, result.get(role_id, max_value))), 0.0, max_value)
	return result


static func build_role_temporary_health_state(owner) -> Dictionary:
	var result: Dictionary = {}
	if owner == null:
		return result
	for role_data in owner.roles:
		if role_data is not Dictionary:
			continue
		var role_id: String = str((role_data as Dictionary).get("id", ""))
		if role_id == "":
			continue
		result[role_id] = 0.0
	return result


static func normalize_role_temporary_health_state(owner, value: Variant) -> Dictionary:
	var result := build_role_temporary_health_state(owner)
	if value is not Dictionary:
		return result
	for role_id_value in result.keys():
		var role_id := str(role_id_value)
		result[role_id] = max(0.0, float((value as Dictionary).get(role_id, result.get(role_id, 0.0))))
	return result


static func get_role_current_health(owner, role_id: String) -> float:
	if owner == null:
		return 0.0
	if role_id == str(owner._get_active_role().get("id", "")):
		return owner.current_health
	if owner.role_health_values is not Dictionary or owner.role_health_values.is_empty():
		owner.role_health_values = build_role_health_state(owner)
	return clamp(float(owner.role_health_values.get(role_id, get_role_max_health(owner, role_id))), 0.0, get_role_max_health(owner, role_id))


static func get_role_temporary_health(owner, role_id: String) -> float:
	if owner == null:
		return 0.0
	return max(0.0, float(owner.current_temporary_health))


static func set_role_temporary_health(owner, role_id: String, value: float, emit_for_active: bool = true) -> void:
	if owner == null or role_id == "":
		return
	if owner.has_method("_set_temporary_health_total"):
		owner._set_temporary_health_total(value, emit_for_active, role_id)
		return
	owner.current_temporary_health = max(0.0, value)
	if owner.has_signal("temporary_health_changed"):
		owner.temporary_health_changed.emit(role_id, owner.current_temporary_health)
	if emit_for_active:
		owner.health_changed.emit(owner.current_health, owner.max_health)


static func save_active_role_temporary_health(owner) -> void:
	if owner == null:
		return
	var role_id: String = str(owner._get_active_role().get("id", "")) if owner.has_method("_get_active_role") else ""
	if role_id == "":
		return
	if owner.has_method("_sync_temporary_health_state"):
		owner._sync_temporary_health_state(false, role_id)
		return
	set_role_temporary_health(owner, role_id, float(owner.current_temporary_health), false)


static func save_active_role_health(owner) -> void:
	if owner == null:
		return
	var role_id: String = str(owner._get_active_role().get("id", "")) if owner.has_method("_get_active_role") else ""
	if role_id == "":
		return
	if owner.role_health_values is not Dictionary or owner.role_health_values.is_empty():
		owner.role_health_values = build_role_health_state(owner)
	owner.role_health_values[role_id] = clamp(float(owner.current_health), 0.0, max(1.0, float(owner.max_health)))


static func add_all_role_current_health(owner, amount: float) -> void:
	if owner == null or amount <= 0.0:
		return
	save_active_role_health(owner)
	if owner.role_health_values is not Dictionary or owner.role_health_values.is_empty():
		owner.role_health_values = build_role_health_state(owner)
	for role_data in owner.roles:
		if role_data is not Dictionary:
			continue
		var role_id: String = str((role_data as Dictionary).get("id", ""))
		if role_id == "":
			continue
		var role_max_health: float = get_role_max_health(owner, role_id)
		var role_current_health: float = float(owner.role_health_values.get(role_id, role_max_health))
		owner.role_health_values[role_id] = clamp(role_current_health + amount, 0.0, role_max_health)


static func get_role_base_health(owner, role_id: String) -> float:
	if owner == null:
		return 1.0
	for role_data in owner.roles:
		if role_data is Dictionary and str((role_data as Dictionary).get("id", "")) == role_id:
			return max(1.0, float((role_data as Dictionary).get("base_health", owner.max_health)))
	return max(1.0, float(owner.max_health))


static func get_role_max_health(owner, role_id: String) -> float:
	if owner == null:
		return 1.0
	var base_health: float = get_role_base_health(owner, role_id)
	var blessing_bonus: float = 0.0
	var blessing_percent_bonus: float = 0.0
	if owner.has_method("_get_role_blessing_stat_bonus") and role_id != "":
		blessing_bonus = float(owner._get_role_blessing_stat_bonus(role_id, "max_health"))
		blessing_percent_bonus = float(owner._get_role_blessing_stat_bonus(role_id, "max_health_percent"))
	var equipment_bonus: float = 0.0
	if owner.has_method("_get_role_equipment_bonus_summary") and role_id != "":
		equipment_bonus = float(owner._get_role_equipment_bonus_summary(role_id).get("max_health_bonus", 0.0))
	else:
		equipment_bonus = float(owner.get("equipment_max_health_bonus"))
	var king_blade_health_bonus: float = PLAYER_SWORDSMAN_KING_BLADE_FLOW.get_permanent_health_bonus(owner) if role_id == "swordsman" else 0.0
	return max(1.0, base_health * max(0.01, 1.0 + blessing_percent_bonus) + blessing_bonus + equipment_bonus + king_blade_health_bonus + PLAYER_RUAN_STONE_STAT_FLOW.get_max_health_bonus(owner))


static func get_active_role_max_health(owner) -> float:
	if owner == null:
		return 1.0
	var role_id: String = str(owner._get_active_role().get("id", "")) if owner.has_method("_get_active_role") else ""
	return get_role_max_health(owner, role_id)


static func sync_active_role_max_health(owner, _preserve_ratio: bool = true, restore_gain: bool = false) -> void:
	if owner == null:
		return
	if owner.role_health_values is not Dictionary or owner.role_health_values.is_empty():
		owner.role_health_values = build_role_health_state(owner)
	var role_id: String = str(owner._get_active_role().get("id", "")) if owner.has_method("_get_active_role") else ""
	var new_max: float = get_active_role_max_health(owner)
	var old_role_max: float = max(1.0, float(owner.max_health))
	var stored_current: float = clamp(float(owner.role_health_values.get(role_id, new_max)), 0.0, new_max)
	owner.max_health = new_max
	if restore_gain and new_max > old_role_max:
		owner.current_health = min(new_max, stored_current + (new_max - old_role_max))
	else:
		owner.current_health = stored_current
	owner.role_health_values[role_id] = owner.current_health
	if owner.has_method("_sync_temporary_health_state"):
		owner._sync_temporary_health_state(true, role_id)
	else:
		if owner.role_temporary_health_values is not Dictionary or owner.role_temporary_health_values.is_empty():
			owner.role_temporary_health_values = build_role_temporary_health_state(owner)
		owner.current_temporary_health = max(0.0, float(owner.role_temporary_health_values.get(role_id, 0.0)))
		owner.role_temporary_health_values[role_id] = owner.current_temporary_health
		if owner.has_signal("temporary_health_changed"):
			owner.temporary_health_changed.emit(role_id, owner.current_temporary_health)
	owner.health_changed.emit(owner.current_health, owner.max_health)


static func get_role_damage(owner, role_id: String) -> float:
	for role_data in owner.roles:
		if role_data["id"] != role_id:
			continue
		var base_global_multiplier: float = owner.global_damage_multiplier - owner.equipment_damage_multiplier_bonus
		var role_equipment_bonus: float = owner._get_role_equipment_damage_multiplier_bonus(role_id)
		var blessing_damage_percent := 0.0
		if owner.has_method("_get_role_blessing_stat_bonus"):
			blessing_damage_percent = float(owner._get_role_blessing_stat_bonus(role_id, "damage"))
		var blazing_sun_flat_base_damage := 0.0
		if owner.has_method("_get_blazing_sun_flat_base_damage"):
			blazing_sun_flat_base_damage = float(owner._get_blazing_sun_flat_base_damage(role_id))
		var king_blade_flat_base_damage := 0.0
		if owner.has_method("_get_king_blade_flat_base_damage"):
			king_blade_flat_base_damage = float(owner._get_king_blade_flat_base_damage(role_id))
		var current_role_base_damage: float = float(role_data["damage"]) + blazing_sun_flat_base_damage + king_blade_flat_base_damage
		var damage_amount: float = (current_role_base_damage + PLAYER_RUAN_STONE_STAT_FLOW.get_attack_bonus(owner)) * max(0.01, 1.0 + blessing_damage_percent) * max(0.01, base_global_multiplier + role_equipment_bonus) * (1.0 + PLAYER_RUAN_STONE_STAT_FLOW.get_damage_bonus(owner))
		if owner.switch_power_remaining > 0.0 and owner.switch_power_role_id == role_id:
			damage_amount *= owner.switch_power_damage_multiplier
		if owner._has_elite_relic("elite_chain_overload") and role_id == str(owner._get_active_role().get("id", "")):
			damage_amount *= 0.92
		if owner.standby_entry_remaining > 0.0 and owner.standby_entry_role_id == role_id:
			damage_amount *= owner.standby_entry_damage_multiplier
		if owner.borrow_fire_remaining > 0.0 and owner.borrow_fire_role_id == role_id:
			damage_amount *= owner.borrow_fire_damage_multiplier
		if owner.frenzy_remaining > 0.0 and owner.frenzy_stacks > 0:
			damage_amount *= 1.0 + 0.015 * owner.frenzy_stacks
		if role_id == "gunner" and owner.has_method("_get_gunner_flash_damage_multiplier"):
			damage_amount *= float(owner._get_gunner_flash_damage_multiplier())
		if role_id == "gunner" and owner.has_method("_get_gunner_hunt_damage_multiplier"):
			damage_amount *= float(owner._get_gunner_hunt_damage_multiplier(role_id))
		if role_id == "gunner":
			damage_amount *= PLAYER_GUNNER_ENTRY_TALENT_FLOW.get_gunner_damage_multiplier(owner, role_id)
		if role_id == "mage" and owner.has_method("_get_mage_arcane_charge_damage_multiplier"):
			damage_amount *= float(owner._get_mage_arcane_charge_damage_multiplier())
		if owner.has_method("_get_mage_arcane_surplus_damage_multiplier"):
			damage_amount *= float(owner._get_mage_arcane_surplus_damage_multiplier(role_id))
		damage_amount *= PLAYER_SWORDSMAN_TRAIT_RUNTIME_FLOW.get_damage_multiplier(owner, role_id)
		return damage_amount
	return 0.0


static func apply_team_role_bonus(owner, interval_bonus: float, range_bonus: float, skill_bonus: float) -> void:
	for role_data in owner.roles:
		var role_id: String = str(role_data["id"])
		var upgrade_data: Dictionary = owner.role_upgrade_levels.get(role_id, {}).duplicate(true)
		upgrade_data["interval_bonus"] = float(upgrade_data.get("interval_bonus", 0.0)) + interval_bonus
		upgrade_data["range_bonus"] = float(upgrade_data.get("range_bonus", 0.0)) + range_bonus
		upgrade_data["skill_bonus"] = float(upgrade_data.get("skill_bonus", 0.0)) + skill_bonus
		owner.role_upgrade_levels[role_id] = upgrade_data


static func apply_role_share(owner, source_role_id: String, interval_bonus: float, range_bonus: float, skill_bonus: float) -> void:
	for role_data in owner.roles:
		var target_role_id: String = str(role_data["id"])
		if target_role_id == source_role_id:
			continue
		var upgrade_data: Dictionary = owner.role_upgrade_levels.get(target_role_id, {}).duplicate(true)
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
		apply_role_share(owner, role_id, role_level * 0.04, role_level * 6.0 + special_total * 2.0, role_level * 0.1 + special_total * 0.05)

	owner.role_share_initialized = true
