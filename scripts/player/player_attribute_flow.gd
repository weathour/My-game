extends RefCounted

const PLAYER_STATE_FACTORY := preload("res://scripts/player/player_state_factory.gd")
const ROLE_ATTRIBUTE_RULES := preload("res://scripts/player/roles/role_attribute_rules.gd")

const SWORDSMAN_HEALTH_MARKER_KEY := "_swordsman_trait_health_bonus_level"
const COMMON_PROSPERITY_KEY := "common_prosperity"
const COMMON_PROSPERITY_TRAIT_GAIN := 0.35


static func get_role_attribute_key(role_id: String, attribute_key: String) -> String:
	return PLAYER_STATE_FACTORY.make_role_attribute_key(role_id, attribute_key)


static func normalize_attribute_training_data(raw_data: Variant) -> Dictionary:
	var normalized: Dictionary = PLAYER_STATE_FACTORY.build_attribute_training_data()
	if raw_data is not Dictionary:
		normalized[SWORDSMAN_HEALTH_MARKER_KEY] = 0.0
		return normalized

	var data: Dictionary = raw_data
	for attribute_key in ROLE_ATTRIBUTE_RULES.get_attribute_keys():
		normalized[attribute_key] = ROLE_ATTRIBUTE_RULES.get_effective_level(float(data.get(attribute_key, normalized.get(attribute_key, 0.0))))
	normalized[COMMON_PROSPERITY_KEY] = max(0, int(data.get(COMMON_PROSPERITY_KEY, normalized.get(COMMON_PROSPERITY_KEY, 0))))

	# Old saves used vitality/agility/power, then strength/agility/intelligence.
	# Preserve progress when moving into hero-trait training.
	var migrated_swordsman: bool = false
	if not data.has(ROLE_ATTRIBUTE_RULES.ATTR_SWORDSMAN):
		migrated_swordsman = true
		normalized[ROLE_ATTRIBUTE_RULES.ATTR_SWORDSMAN] = ROLE_ATTRIBUTE_RULES.get_effective_level(max(
			float(data.get("swordsman_trait", 0.0)),
			float(data.get("strength", 0.0)),
			float(data.get("vitality", 0.0)),
			float(data.get("power", 0.0)),
			float(data.get(get_role_attribute_key("swordsman", "vitality"), 0.0))
		))
	if not data.has(ROLE_ATTRIBUTE_RULES.ATTR_GUNNER):
		normalized[ROLE_ATTRIBUTE_RULES.ATTR_GUNNER] = ROLE_ATTRIBUTE_RULES.get_effective_level(max(
			float(data.get("gunner_trait", 0.0)),
			float(data.get("agility", 0.0)),
			float(data.get(get_role_attribute_key("gunner", "agility"), 0.0))
		))
	if not data.has(ROLE_ATTRIBUTE_RULES.ATTR_MAGE):
		normalized[ROLE_ATTRIBUTE_RULES.ATTR_MAGE] = ROLE_ATTRIBUTE_RULES.get_effective_level(max(
			float(data.get("mage_trait", 0.0)),
			float(data.get("intelligence", 0.0)),
			float(data.get(get_role_attribute_key("mage", "agility"), 0.0))
		))

	if data.has(SWORDSMAN_HEALTH_MARKER_KEY):
		normalized[SWORDSMAN_HEALTH_MARKER_KEY] = ROLE_ATTRIBUTE_RULES.get_effective_level(float(data.get(SWORDSMAN_HEALTH_MARKER_KEY, 0.0)))
	elif migrated_swordsman:
		normalized[SWORDSMAN_HEALTH_MARKER_KEY] = 0.0
	else:
		# Saves created after this system already persisted max_health with the
		# swordsman trait health bonus, even if the internal marker was absent. Avoid double-adding.
		normalized[SWORDSMAN_HEALTH_MARKER_KEY] = float(normalized.get(ROLE_ATTRIBUTE_RULES.ATTR_SWORDSMAN, 0.0))
	return normalized


static func sync_swordsman_trait_health_bonus(owner) -> void:
	owner.attribute_training_levels = normalize_attribute_training_data(owner.attribute_training_levels)
	var swordsman_level: float = get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_SWORDSMAN)
	var applied_level: float = float(owner.attribute_training_levels.get(SWORDSMAN_HEALTH_MARKER_KEY, 0.0))
	var health_delta: float = ROLE_ATTRIBUTE_RULES.get_swordsman_trait_max_health_bonus(swordsman_level) - ROLE_ATTRIBUTE_RULES.get_swordsman_trait_max_health_bonus(applied_level)
	if absf(health_delta) > 0.001:
		owner.max_health = max(1.0, float(owner.max_health) + health_delta)
		owner.current_health = clamp(float(owner.current_health) + max(0.0, health_delta), 0.0, float(owner.max_health))
		owner.health_changed.emit(owner.current_health, owner.max_health)
	owner.attribute_training_levels[SWORDSMAN_HEALTH_MARKER_KEY] = swordsman_level


# Compatibility wrapper for code written while this system was named strength.
static func sync_strength_health_bonus(owner) -> void:
	sync_swordsman_trait_health_bonus(owner)


static func get_attribute_level(owner, attribute_key: String) -> float:
	var key: String = _canonical_attribute_key(attribute_key)
	if key == "":
		return 0.0
	if owner.attribute_training_levels is not Dictionary:
		return 0.0
	return ROLE_ATTRIBUTE_RULES.get_effective_level(float(owner.attribute_training_levels.get(key, 0.0)))


static func get_role_attribute_level(owner, _role_id: String, attribute_key: String) -> float:
	# Role-specific vitality/agility hooks are legacy combat-shape knobs. The new
	# training is global, so only canonical new hero-traits expose their levels.
	if attribute_key in ROLE_ATTRIBUTE_RULES.get_attribute_keys():
		return get_attribute_level(owner, attribute_key)
	return 0.0


static func add_attribute_levels(owner, deltas: Dictionary) -> Dictionary:
	owner.attribute_training_levels = normalize_attribute_training_data(owner.attribute_training_levels)
	for raw_key in deltas.keys():
		var attribute_key: String = _canonical_attribute_key(str(raw_key))
		if attribute_key == "":
			continue
		var current_level: float = get_attribute_level(owner, attribute_key)
		var delta: float = float(deltas.get(raw_key, 0.0))
		owner.attribute_training_levels[attribute_key] = ROLE_ATTRIBUTE_RULES.get_effective_level(current_level + delta)
	sync_swordsman_trait_health_bonus(owner)
	return owner.attribute_training_levels.duplicate(true)


static func increase_role_attribute_level(owner, _role_id: String, attribute_key: String) -> float:
	var key: String = _canonical_attribute_key(attribute_key)
	if key == "":
		return 0.0
	add_attribute_levels(owner, {key: 1.0})
	return get_attribute_level(owner, key)


static func get_max_attribute_level() -> float:
	return ROLE_ATTRIBUTE_RULES.MAX_ATTRIBUTE_LEVEL


static func is_attribute_evolved(level: float) -> bool:
	return ROLE_ATTRIBUTE_RULES.is_attribute_evolved(level)


static func format_attribute_level(level: float) -> String:
	if is_equal_approx(level, roundf(level)):
		return str(int(roundf(level)))
	return "%.1f" % level


static func get_attribute_health_regen_per_second(owner) -> float:
	return 0.0


static func get_attribute_mana_regen_per_second(owner) -> float:
	return 0.0


static func get_attribute_dodge_chance(owner) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_trait_dodge_chance(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_SWORDSMAN))


static func get_attribute_pickup_range_bonus(owner) -> float:
	return 0.0


static func get_swordsman_low_health_flat_heal(owner) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_trait_low_health_flat_heal(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_SWORDSMAN))


static func get_swordsman_low_health_threshold(_owner) -> float:
	return ROLE_ATTRIBUTE_RULES.SWORDSMAN_LOW_HEALTH_THRESHOLD


static func get_gunner_distance_damage_bonus(owner) -> float:
	return ROLE_ATTRIBUTE_RULES.get_gunner_trait_distance_damage_bonus(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_GUNNER))


static func get_mage_skill_range_multiplier(owner) -> float:
	return ROLE_ATTRIBUTE_RULES.get_mage_trait_skill_range_multiplier(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_MAGE))


static func get_mage_kill_energy_multiplier(owner) -> float:
	return ROLE_ATTRIBUTE_RULES.get_mage_trait_kill_energy_multiplier(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_MAGE))


static func get_primary_attribute_damage_bonus(owner, role_id: String) -> float:
	return ROLE_ATTRIBUTE_RULES.get_primary_attribute_damage_bonus(role_id, normalize_attribute_training_data(owner.attribute_training_levels))


static func get_role_trait_level(owner, role_id: String) -> float:
	return get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.get_primary_attribute_for_role(role_id))


static func get_role_entry_damage_multiplier(owner, role_id: String) -> float:
	var level := get_role_trait_level(owner, role_id)
	match role_id:
		"swordsman":
			return ROLE_ATTRIBUTE_RULES.get_swordsman_trait_entry_damage_multiplier(level)
		"gunner":
			return ROLE_ATTRIBUTE_RULES.get_gunner_trait_entry_bullet_damage_multiplier(level)
		"mage":
			return ROLE_ATTRIBUTE_RULES.get_mage_trait_entry_damage_multiplier(level)
	return 1.0


static func get_swordsman_entry_distance_multiplier(owner) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_trait_entry_distance_multiplier(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_SWORDSMAN))


static func get_swordsman_entry_invulnerability_bonus(owner) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_trait_entry_invulnerability_bonus(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_SWORDSMAN))


static func get_swordsman_exit_lifesteal_bonus(owner) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_trait_exit_lifesteal_bonus(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_SWORDSMAN))


static func get_swordsman_exit_lifesteal_duration_bonus(owner) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_trait_exit_lifesteal_duration_bonus(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_SWORDSMAN))


static func get_gunner_entry_bullet_speed_bonus(owner) -> float:
	return ROLE_ATTRIBUTE_RULES.get_gunner_trait_entry_bullet_speed_bonus(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_GUNNER))


static func get_gunner_entry_wave_count(owner) -> int:
	return ROLE_ATTRIBUTE_RULES.get_gunner_trait_entry_wave_count(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_GUNNER))


static func get_gunner_exit_haste_interval_bonus(owner) -> float:
	return ROLE_ATTRIBUTE_RULES.get_gunner_trait_exit_haste_interval_bonus(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_GUNNER))


static func get_gunner_exit_move_speed_multiplier_bonus(owner) -> float:
	return ROLE_ATTRIBUTE_RULES.get_gunner_trait_exit_move_speed_multiplier_bonus(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_GUNNER))


static func get_gunner_exit_haste_duration_bonus(owner) -> float:
	return ROLE_ATTRIBUTE_RULES.get_gunner_trait_exit_haste_duration_bonus(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_GUNNER))


static func get_mage_entry_radius_multiplier(owner) -> float:
	return ROLE_ATTRIBUTE_RULES.get_mage_trait_entry_radius_multiplier(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_MAGE))


static func get_mage_entry_bombard_count(owner) -> int:
	return ROLE_ATTRIBUTE_RULES.get_mage_trait_entry_bombard_count(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_MAGE))


static func get_mage_exit_energy_bonus(owner) -> float:
	return ROLE_ATTRIBUTE_RULES.get_mage_trait_exit_energy_bonus(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_MAGE))


static func get_mage_exit_slow_field_radius_bonus(owner) -> float:
	return ROLE_ATTRIBUTE_RULES.get_mage_trait_exit_slow_field_radius_bonus(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_MAGE))


static func get_mage_exit_slow_field_damage_ratio(owner) -> float:
	return ROLE_ATTRIBUTE_RULES.get_mage_trait_exit_slow_field_damage_ratio(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_MAGE))


static func get_trait_definitions_for_owner(owner) -> Array:
	if owner != null and owner.get("roles") is Array:
		var definitions := ROLE_ATTRIBUTE_RULES.get_trait_definitions(owner.roles)
		if not definitions.is_empty():
			return definitions
	return ROLE_ATTRIBUTE_RULES.get_trait_definitions()


static func get_trait_keys_for_owner(owner) -> Array:
	var keys: Array = []
	for definition in get_trait_definitions_for_owner(owner):
		if definition is not Dictionary:
			continue
		var trait_key := str((definition as Dictionary).get("trait_key", ""))
		if trait_key != "" and not keys.has(trait_key):
			keys.append(trait_key)
	return keys


static func get_balanced_attribute_description(owner, added_amount: float) -> String:
	return ROLE_ATTRIBUTE_RULES.get_balanced_attribute_description_for_roles(
		normalize_attribute_training_data(owner.attribute_training_levels),
		added_amount,
		get_trait_definitions_for_owner(owner)
	)


static func add_common_prosperity(owner) -> Dictionary:
	owner.attribute_training_levels = normalize_attribute_training_data(owner.attribute_training_levels)
	var deltas := {}
	for trait_key in get_trait_keys_for_owner(owner):
		deltas[str(trait_key)] = COMMON_PROSPERITY_TRAIT_GAIN
	add_attribute_levels(owner, deltas)
	owner.attribute_training_levels[COMMON_PROSPERITY_KEY] = get_common_prosperity_count(owner) + 1
	return owner.attribute_training_levels.duplicate(true)


static func get_common_prosperity_count(owner) -> int:
	var normalized := normalize_attribute_training_data(owner.attribute_training_levels)
	return max(0, int(normalized.get(COMMON_PROSPERITY_KEY, 0)))


static func get_common_prosperity_switch_cooldown_multiplier(owner) -> float:
	return pow(ROLE_ATTRIBUTE_RULES.COMMON_PROSPERITY_SWITCH_COOLDOWN_FACTOR, float(get_common_prosperity_count(owner)))


static func get_swordsman_heart_interval_multiplier(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_heart_interval_multiplier(level)


static func get_swordsman_heart_range_multiplier(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_heart_range_multiplier(level)


static func get_swordsman_normal_attack_scale(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_normal_attack_scale(level)


static func get_swordsman_normal_attack_width_scale(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_normal_attack_width_scale(level)


static func get_swordsman_bloodthirst_ratio(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_bloodthirst_ratio(level)


static func get_swordsman_bloodthirst_heal_cap(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_bloodthirst_heal_cap(level)


static func get_swordsman_dodge_chance(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_swordsman_dodge_chance(level)


static func get_gunner_barrage_speed_multiplier(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_gunner_barrage_speed_multiplier(level)


static func get_gunner_barrage_interval_reduction(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_gunner_barrage_interval_reduction(level)


static func get_gunner_barrage_bounce_count(level: float) -> int:
	return ROLE_ATTRIBUTE_RULES.get_gunner_barrage_bounce_count(level)


static func get_gunner_barrage_shotgun_wave_count(level: float) -> int:
	return ROLE_ATTRIBUTE_RULES.get_gunner_barrage_shotgun_wave_count(level)


static func get_gunner_barrage_shotgun_pellet_count(level: float) -> int:
	return ROLE_ATTRIBUTE_RULES.get_gunner_barrage_shotgun_pellet_count(level)


static func get_gunner_barrage_split_count(level: float) -> int:
	return ROLE_ATTRIBUTE_RULES.get_gunner_barrage_split_count(level)


static func get_gunner_footwork_range_multiplier(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_gunner_footwork_range_multiplier(level)


static func get_gunner_footwork_move_multiplier(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_gunner_footwork_move_multiplier(level)


static func get_gunner_footwork_flat_speed_bonus(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_gunner_footwork_flat_speed_bonus(level)


static func get_mage_arcane_focus_range_multiplier(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_mage_arcane_focus_range_multiplier(level)


static func get_mage_surplus_energy_multiplier(level: float, role_id: String = "") -> float:
	return ROLE_ATTRIBUTE_RULES.get_mage_surplus_energy_multiplier(level, role_id)


static func get_mage_surplus_passive_energy_per_second(level: float) -> float:
	return ROLE_ATTRIBUTE_RULES.get_mage_surplus_passive_energy_per_second(level)


static func get_role_attribute_range_multiplier(_owner, _role_id: String) -> float:
	if _role_id == "mage":
		return get_mage_skill_range_multiplier(_owner)
	return 1.0


static func get_role_attribute_move_speed_multiplier(_owner, _role_id: String) -> float:
	return 1.0


static func get_role_attribute_flat_move_speed_bonus(owner, _role_id: String) -> float:
	return ROLE_ATTRIBUTE_RULES.get_gunner_trait_flat_move_speed_bonus(get_attribute_level(owner, ROLE_ATTRIBUTE_RULES.ATTR_GUNNER))


static func get_role_attack_interval_multiplier(_owner, _role_id: String) -> float:
	return 1.0


static func get_role_attack_interval_flat_reduction(_owner, _role_id: String) -> float:
	return 0.0


static func get_ultimate_energy_gain_multiplier_for_role(_owner, _role_id: String) -> float:
	if _role_id == "mage":
		return get_mage_kill_energy_multiplier(_owner)
	return 1.0


static func get_role_attribute_titles(role_id: String) -> Dictionary:
	return ROLE_ATTRIBUTE_RULES.get_role_attribute_titles(role_id)


static func get_role_attribute_titles_for_levels(role_id: String, levels: Dictionary) -> Dictionary:
	return ROLE_ATTRIBUTE_RULES.get_role_attribute_titles(role_id, levels)


static func get_role_attribute_description(role_id: String, attribute_key: String, next_level: float) -> String:
	return ROLE_ATTRIBUTE_RULES.get_role_attribute_description(role_id, attribute_key, next_level)


static func get_evolved_title_color() -> Color:
	return ROLE_ATTRIBUTE_RULES.EVOLVED_TITLE_COLOR


static func _canonical_attribute_key(attribute_key: String) -> String:
	match attribute_key:
		ROLE_ATTRIBUTE_RULES.ATTR_STRENGTH:
			return ROLE_ATTRIBUTE_RULES.ATTR_STRENGTH
		ROLE_ATTRIBUTE_RULES.ATTR_AGILITY:
			return ROLE_ATTRIBUTE_RULES.ATTR_AGILITY
		ROLE_ATTRIBUTE_RULES.ATTR_INTELLIGENCE:
			return ROLE_ATTRIBUTE_RULES.ATTR_INTELLIGENCE
		"strength", "vitality", "power":
			return ROLE_ATTRIBUTE_RULES.ATTR_SWORDSMAN
		"agility":
			return ROLE_ATTRIBUTE_RULES.ATTR_GUNNER
		"intelligence":
			return ROLE_ATTRIBUTE_RULES.ATTR_MAGE
		_:
			return ""
