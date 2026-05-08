extends RefCounted

const PLAYER_LEVEL_CURVE := preload("res://scripts/player/player_level_curve.gd")
const ROLE_RESOURCE_STATE := preload("res://scripts/player/roles/role_resource_state.gd")
const SWORDSMAN_BLADE_STORM_ABILITY := preload("res://scripts/abilities/swordsman_blade_storm_ability.gd")
const MAGE_TIDAL_SURGE_ABILITY := preload("res://scripts/abilities/mage_tidal_surge_ability.gd")
const GUNNER_INFINITE_RELOAD_ABILITY := preload("res://scripts/abilities/gunner_infinite_reload_ability.gd")
const MAGE_META_FIELD_ABILITY := preload("res://scripts/abilities/mage_meta_field_ability.gd")
const SWORDSMAN_CRESCENT_WAVE_ABILITY := preload("res://scripts/abilities/swordsman_crescent_wave_ability.gd")
const GUNNER_SHRAPNEL_FIELD_ABILITY := preload("res://scripts/abilities/gunner_shrapnel_field_ability.gd")
const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")
const PLAYER_ROLE_STAT_FLOW := preload("res://scripts/player/player_role_stat_flow.gd")

static func get_save_data(player) -> Dictionary:
	var pending_upgrade_count: int = player.pending_level_ups
	if player.level_up_active:
		pending_upgrade_count += 1
	if player.has_method("_save_active_role_health"):
		player._save_active_role_health()

	return {
		"position": [player.global_position.x, player.global_position.y],
		"level": player.level,
		"experience": player.experience,
		"experience_to_next_level": player.experience_to_next_level,
		"pending_level_ups": pending_upgrade_count,
		"max_health": player.max_health,
		"max_mana": player.max_mana,
		"current_health": player.current_health,
		"role_health_values": player.role_health_values.duplicate(true),
		"current_mana": player._get_role_mana(player._get_active_role_id()),
		"role_mana_values": player.role_mana_values.duplicate(true),
		"ultimate_energy_lock_remaining": player._get_role_ultimate_lock_remaining(player._get_active_role_id()),
		"role_ultimate_energy_lock_remaining": player.role_ultimate_energy_lock_remaining.duplicate(true),
		"hurt_cooldown_remaining": player.hurt_cooldown_remaining,
		"switch_invulnerability_remaining": player.switch_invulnerability_remaining,
		"level_up_delay_remaining": player.level_up_delay_remaining,
		"switch_cooldown_remaining": player.switch_cooldown_remaining,
		"enemy_move_slow_multiplier": player.enemy_move_slow_multiplier,
		"enemy_move_slow_remaining": player.enemy_move_slow_remaining,
		"gunner_infinite_reload_cooldown_remaining": player.gunner_infinite_reload_ability.cooldown_remaining if player.gunner_infinite_reload_ability != null else 0.0,
		"gunner_infinite_reload_remaining": player.gunner_infinite_reload_ability.active_remaining if player.gunner_infinite_reload_ability != null else 0.0,
		"gunner_infinite_reload_tick_remaining": player.gunner_infinite_reload_ability.tick_remaining if player.gunner_infinite_reload_ability != null else 0.0,
		"gunner_infinite_reload_locked_aim_direction": [
			player.gunner_infinite_reload_ability.locked_aim_direction.x if player.gunner_infinite_reload_ability != null else 1.0,
			player.gunner_infinite_reload_ability.locked_aim_direction.y if player.gunner_infinite_reload_ability != null else 0.0
		],
		"gunner_shrapnel_field_cooldown_remaining": player.gunner_shrapnel_field_ability.cooldown_remaining if player.gunner_shrapnel_field_ability != null else 0.0,
		"mage_tidal_surge_cooldown_remaining": player.mage_tidal_surge_ability.cooldown_remaining if player.mage_tidal_surge_ability != null else 0.0,
		"mage_meta_field_cooldown_remaining": player.mage_meta_field_ability.cooldown_remaining if player.mage_meta_field_ability != null else 0.0,
		"mage_meta_field_remaining": player.mage_meta_field_ability.active_remaining if player.mage_meta_field_ability != null else 0.0,
		"mage_meta_field_tick_remaining": player.mage_meta_field_ability.tick_remaining if player.mage_meta_field_ability != null else 0.0,
		"swordsman_blade_storm_cooldown_remaining": player.swordsman_blade_storm_ability.cooldown_remaining if player.swordsman_blade_storm_ability != null else 0.0,
		"swordsman_blade_storm_remaining": player.swordsman_blade_storm_ability.active_remaining if player.swordsman_blade_storm_ability != null else 0.0,
		"swordsman_blade_storm_tick_remaining": player.swordsman_blade_storm_ability.tick_remaining if player.swordsman_blade_storm_ability != null else 0.0,
		"swordsman_crescent_wave_cooldown_remaining": player.swordsman_crescent_wave_ability.cooldown_remaining if player.swordsman_crescent_wave_ability != null else 0.0,
		"speed": player.speed,
		"pickup_radius": player.pickup_radius,
		"energy_gain_multiplier": player.energy_gain_multiplier,
		"global_damage_multiplier": player.global_damage_multiplier,
		"background_interval_multiplier": player.background_interval_multiplier,
		"ultimate_cost_multiplier": player.ultimate_cost_multiplier,
		"damage_taken_multiplier": player.damage_taken_multiplier,
		"equipment_damage_multiplier_bonus": player.equipment_damage_multiplier_bonus,
		"equipment_speed_bonus": player.equipment_speed_bonus,
		"equipment_max_health_bonus": player.equipment_max_health_bonus,
		"equipment_energy_gain_bonus": player.equipment_energy_gain_bonus,
		"equipment_dodge_chance": player.equipment_dodge_chance,
		"equipment_health_regen_per_second": player.equipment_health_regen_per_second,
		"equipment_low_health_threshold": player.equipment_low_health_threshold,
		"equipment_low_health_damage_taken_multiplier": player.equipment_low_health_damage_taken_multiplier,
		"equipment_skill_range_multiplier": player.equipment_skill_range_multiplier,
		"equipment_cooldown_multiplier": player.equipment_cooldown_multiplier,
		"role_switch_cooldown_bonus": player.role_switch_cooldown_bonus,
		"switch_power_remaining": player.switch_power_remaining,
		"switch_power_role_id": player.switch_power_role_id,
		"switch_power_damage_multiplier": player.switch_power_damage_multiplier,
		"switch_power_interval_bonus": player.switch_power_interval_bonus,
		"switch_power_label": player.switch_power_label,
		"pending_entry_blessing_source_role_id": player.pending_entry_blessing_source_role_id,
		"entry_blessing_role_id": player.entry_blessing_role_id,
		"entry_blessing_label": player.entry_blessing_label,
		"entry_blessing_remaining": player.entry_blessing_remaining,
		"entry_lifesteal_ratio": player.entry_lifesteal_ratio,
		"entry_haste_interval_bonus": player.entry_haste_interval_bonus,
		"entry_haste_move_speed_multiplier": player.entry_haste_move_speed_multiplier,
		"standby_entry_role_id": player.standby_entry_role_id,
		"standby_entry_label": player.standby_entry_label,
		"standby_entry_remaining": player.standby_entry_remaining,
		"standby_entry_damage_multiplier": player.standby_entry_damage_multiplier,
		"standby_entry_interval_bonus": player.standby_entry_interval_bonus,
		"guard_cover_remaining": player.guard_cover_remaining,
		"guard_cover_damage_multiplier": player.guard_cover_damage_multiplier,
		"borrow_fire_role_id": player.borrow_fire_role_id,
		"borrow_fire_remaining": player.borrow_fire_remaining,
		"borrow_fire_damage_multiplier": player.borrow_fire_damage_multiplier,
		"borrow_fire_interval_bonus": player.borrow_fire_interval_bonus,
		"borrow_fire_background_multiplier": player.borrow_fire_background_multiplier,
		"post_ultimate_flow_remaining": player.post_ultimate_flow_remaining,
		"post_ultimate_flow_background_multiplier": player.post_ultimate_flow_background_multiplier,
		"ultimate_guard_remaining": player.ultimate_guard_remaining,
		"ultimate_guard_damage_multiplier": player.ultimate_guard_damage_multiplier,
		"perpetual_motion_cooldown_remaining": player.perpetual_motion_cooldown_remaining,
		"frenzy_remaining": player.frenzy_remaining,
		"frenzy_stacks": player.frenzy_stacks,
		"frenzy_overkill_counter": player.frenzy_overkill_counter,
		"role_standby_elapsed": player.role_standby_elapsed.duplicate(true),
		"role_share_initialized": player.role_share_initialized,
		"active_role_index": player.active_role_index,
		"auto_attack_enabled": player.auto_attack_enabled,
		"role_upgrade_levels": player.role_upgrade_levels.duplicate(true),
		"background_cooldowns": player.background_cooldowns.duplicate(true),
		"equipment_levels": player.equipment_levels.duplicate(true),
		"role_equipment_levels": player.role_equipment_levels.duplicate(true),
		"elite_relics_unlocked": player.elite_relics_unlocked.duplicate(true),
		"attribute_training_levels": player.attribute_training_levels.duplicate(true),
		"role_blessing_levels": player.role_blessing_levels.duplicate(true),
		"skill_blessing_levels": player.skill_blessing_levels.duplicate(true),
		"blessing_skill_state": player.blessing_skill_state.duplicate(true),
		"role_special_states": player.role_special_states.duplicate(true),
		"roles": player._serialize_roles_for_save(),
		"story_equipped_styles": player.story_equipped_styles.duplicate(true)
	}

static func apply_save_data(player, data: Dictionary) -> void:
	var position_data = data.get("position", [0.0, 0.0])
	if position_data.size() >= 2:
		player.global_position = Vector2(float(position_data[0]), float(position_data[1]))

	player.roles = player._normalize_loaded_roles(data.get("roles", player.roles))
	var saved_active_role_index: int = clampi(
		int(data.get("active_role_index", player.active_role_index)),
		0,
		max(0, player.roles.size() - 1)
	)
	player.level = int(data.get("level", player.level))
	player.experience = int(data.get("experience", player.experience))
	player.experience_to_next_level = PLAYER_LEVEL_CURVE.normalize_required_experience(
		player.level,
		int(data.get("experience_to_next_level", player.experience_to_next_level))
	)
	player.pending_level_ups = max(0, int(data.get("pending_level_ups", player.pending_level_ups)))
	player.max_health = float(data.get("max_health", player.max_health))
	player.max_mana = float(data.get("max_mana", player.max_mana))
	var saved_current_health := float(data.get("current_health", player.current_health))
	player.current_health = saved_current_health
	player.role_health_values = player._build_role_health_state()
	var saved_role_health_values: Variant = data.get("role_health_values", {})
	player.role_mana_values = player._build_role_resource_state_data(0.0)
	player.role_ultimate_energy_lock_remaining = player._build_role_resource_state_data(0.0)
	var saved_role_mana_values: Dictionary = data.get("role_mana_values", {})
	if saved_role_mana_values is Dictionary and not saved_role_mana_values.is_empty():
		ROLE_RESOURCE_STATE.apply_saved_mana(player.role_mana_values, saved_role_mana_values, player.max_mana)
	else:
		var fallback_role_id: String = str(player.roles[clamp(saved_active_role_index, 0, max(0, player.roles.size() - 1))].get("id", ""))
		if fallback_role_id != "":
			ROLE_RESOURCE_STATE.set_mana(player.role_mana_values, fallback_role_id, float(data.get("current_mana", player.current_mana)), player.max_mana)
	var saved_role_locks: Dictionary = data.get("role_ultimate_energy_lock_remaining", {})
	if saved_role_locks is Dictionary and not saved_role_locks.is_empty():
		ROLE_RESOURCE_STATE.apply_saved_locks(player.role_ultimate_energy_lock_remaining, saved_role_locks)
	else:
		var fallback_lock_role_id: String = str(player.roles[clamp(saved_active_role_index, 0, max(0, player.roles.size() - 1))].get("id", ""))
		if fallback_lock_role_id != "":
			ROLE_RESOURCE_STATE.set_lock_remaining(player.role_ultimate_energy_lock_remaining, fallback_lock_role_id, float(data.get("ultimate_energy_lock_remaining", 0.0)))
	player.hurt_cooldown_remaining = max(0.0, float(data.get("hurt_cooldown_remaining", 0.0)))
	player.switch_invulnerability_remaining = max(0.0, float(data.get("switch_invulnerability_remaining", 0.0)))
	player.level_up_delay_remaining = max(0.0, float(data.get("level_up_delay_remaining", 0.0)))
	player.switch_cooldown_remaining = max(0.0, float(data.get("switch_cooldown_remaining", 0.0)))
	player.enemy_move_slow_multiplier = float(data.get("enemy_move_slow_multiplier", 1.0))
	player.enemy_move_slow_remaining = max(0.0, float(data.get("enemy_move_slow_remaining", 0.0)))
	_apply_ability_save_data(player, data)
	_apply_stat_save_data(player, data)
	_apply_switch_buff_save_data(player, data)

	player.role_standby_elapsed = data.get("role_standby_elapsed", player.role_standby_elapsed).duplicate(true)
	player.role_share_initialized = bool(data.get("role_share_initialized", false))
	player.active_role_index = saved_active_role_index
	player.auto_attack_enabled = bool(data.get("auto_attack_enabled", player.auto_attack_enabled))
	player.role_upgrade_levels = data.get("role_upgrade_levels", player.role_upgrade_levels).duplicate(true)
	player.background_cooldowns = data.get("background_cooldowns", player.background_cooldowns).duplicate(true)
	player.equipment_levels = data.get("equipment_levels", player.equipment_levels).duplicate(true)
	var saved_role_equipment_levels: Variant = data.get("role_equipment_levels", {})
	if saved_role_equipment_levels is Dictionary and not saved_role_equipment_levels.is_empty():
		player.role_equipment_levels = saved_role_equipment_levels.duplicate(true)
	elif player.equipment_levels is Dictionary and not player.equipment_levels.is_empty():
		var fallback_role_id: String = str(player.roles[clamp(saved_active_role_index, 0, max(0, player.roles.size() - 1))].get("id", ""))
		if fallback_role_id != "":
			player.role_equipment_levels = {fallback_role_id: player.equipment_levels.duplicate(true)}
	if not data.has("equipment_damage_multiplier_bonus"):
		var active_equipment_role_id: String = str(player.roles[clamp(saved_active_role_index, 0, max(0, player.roles.size() - 1))].get("id", ""))
		var active_equipment_summary: Dictionary = player._get_role_equipment_bonus_summary(active_equipment_role_id)
		player.equipment_damage_multiplier_bonus = float(active_equipment_summary.get("damage_multiplier_bonus", 0.0))
		player.equipment_speed_bonus = float(active_equipment_summary.get("speed_bonus", 0.0))
		player.equipment_max_health_bonus = float(active_equipment_summary.get("max_health_bonus", 0.0))
		player.equipment_energy_gain_bonus = float(active_equipment_summary.get("energy_gain_bonus", 0.0))
	player.elite_relics_unlocked = data.get("elite_relics_unlocked", player.elite_relics_unlocked).duplicate(true)
	player.attribute_training_levels = player._normalize_attribute_training_data(data.get("attribute_training_levels", player.attribute_training_levels))
	player._sync_swordsman_trait_health_bonus()
	player.role_special_states = data.get("role_special_states", player.role_special_states).duplicate(true)
	player.role_blessing_levels = PLAYER_BLESSING_SYSTEM.normalize_role_state(data.get("role_blessing_levels", player.role_blessing_levels), player.roles)
	PLAYER_BLESSING_SYSTEM.sync_shared_role_blessings(player)
	player.skill_blessing_levels = PLAYER_BLESSING_SYSTEM.normalize_skill_state(data.get("skill_blessing_levels", player.skill_blessing_levels))
	player.blessing_skill_state = PLAYER_BLESSING_SKILL_STATE.normalize_state(data.get("blessing_skill_state", player.blessing_skill_state))
	player.story_equipped_styles = data.get("story_equipped_styles", player.story_equipped_styles).duplicate(true)
	_apply_saved_role_health_data(player, saved_role_health_values, saved_current_health, saved_active_role_index)
	if player.swordsman_blade_storm_ability != null:
		player.swordsman_blade_storm_ability.restore_effect_if_active(player)
	if player.mage_meta_field_ability != null:
		player.mage_meta_field_ability.restore_effect_if_active(player)
	if player.has_method("_refresh_blessing_skill_unlocks"):
		player._refresh_blessing_skill_unlocks()
	player._initialize_existing_role_shares()
	player.level_up_active = false
	player.is_dead = false
	player.role_health_values = PLAYER_ROLE_STAT_FLOW.normalize_role_health_state(player, player.role_health_values)

	player._update_active_role_state()
	player.fire_timer.start()

	player.experience_changed.emit(player.experience, player.experience_to_next_level, player.level)
	player.stats_changed.emit(player.get_stat_summary())
	player.health_changed.emit(player.current_health, player.max_health)
	player._emit_active_mana_changed()


static func _apply_saved_role_health_data(player, saved_role_health_values: Variant, saved_current_health: float, saved_active_role_index: int) -> void:
	player.role_health_values = player._build_role_health_state()
	if saved_role_health_values is Dictionary and not (saved_role_health_values as Dictionary).is_empty():
		player.role_health_values = PLAYER_ROLE_STAT_FLOW.normalize_role_health_state(player, saved_role_health_values)
	else:
		var fallback_health_role_id: String = str(player.roles[clamp(saved_active_role_index, 0, max(0, player.roles.size() - 1))].get("id", ""))
		if fallback_health_role_id != "":
			var role_max_health: float = PLAYER_ROLE_STAT_FLOW.get_role_max_health(player, fallback_health_role_id)
			player.role_health_values[fallback_health_role_id] = clamp(saved_current_health, 0.0, role_max_health)
	var active_role_id: String = str(player.roles[clamp(saved_active_role_index, 0, max(0, player.roles.size() - 1))].get("id", ""))
	if active_role_id != "":
		player.current_health = float(player.role_health_values.get(active_role_id, saved_current_health))

static func _apply_ability_save_data(player, data: Dictionary) -> void:
	if player.gunner_infinite_reload_ability == null:
		player.gunner_infinite_reload_ability = GUNNER_INFINITE_RELOAD_ABILITY.new()
	player.gunner_infinite_reload_ability.apply_save_data({
		"cooldown_remaining": float(data.get("gunner_infinite_reload_cooldown_remaining", 0.0)),
		"active_remaining": float(data.get("gunner_infinite_reload_remaining", 0.0)),
		"tick_remaining": float(data.get("gunner_infinite_reload_tick_remaining", 0.0)),
		"locked_aim_direction": data.get("gunner_infinite_reload_locked_aim_direction", [1.0, 0.0])
	})
	if player.mage_tidal_surge_ability == null:
		player.mage_tidal_surge_ability = MAGE_TIDAL_SURGE_ABILITY.new()
	player.mage_tidal_surge_ability.cooldown_remaining = max(0.0, float(data.get("mage_tidal_surge_cooldown_remaining", 0.0)))
	if player.mage_meta_field_ability == null:
		player.mage_meta_field_ability = MAGE_META_FIELD_ABILITY.new()
	player.mage_meta_field_ability.apply_save_data({
		"cooldown_remaining": float(data.get("mage_meta_field_cooldown_remaining", 0.0)),
		"active_remaining": float(data.get("mage_meta_field_remaining", 0.0)),
		"tick_remaining": float(data.get("mage_meta_field_tick_remaining", 0.0))
	})
	if player.swordsman_blade_storm_ability == null:
		player.swordsman_blade_storm_ability = SWORDSMAN_BLADE_STORM_ABILITY.new()
	player.swordsman_blade_storm_ability.apply_save_data({
		"cooldown_remaining": float(data.get("swordsman_blade_storm_cooldown_remaining", 0.0)),
		"active_remaining": float(data.get("swordsman_blade_storm_remaining", 0.0)),
		"tick_remaining": float(data.get("swordsman_blade_storm_tick_remaining", 0.0))
	})
	if player.swordsman_crescent_wave_ability == null:
		player.swordsman_crescent_wave_ability = SWORDSMAN_CRESCENT_WAVE_ABILITY.new()
	player.swordsman_crescent_wave_ability.apply_save_data({
		"cooldown_remaining": float(data.get("swordsman_crescent_wave_cooldown_remaining", 0.0))
	})
	if player.gunner_shrapnel_field_ability == null:
		player.gunner_shrapnel_field_ability = GUNNER_SHRAPNEL_FIELD_ABILITY.new()
	player.gunner_shrapnel_field_ability.apply_save_data({
		"cooldown_remaining": float(data.get("gunner_shrapnel_field_cooldown_remaining", 0.0))
	})

static func _apply_stat_save_data(player, data: Dictionary) -> void:
	player.speed = float(data.get("speed", player.speed))
	player.pickup_radius = float(data.get("pickup_radius", player.pickup_radius))
	player.energy_gain_multiplier = float(data.get("energy_gain_multiplier", player.energy_gain_multiplier))
	player.global_damage_multiplier = float(data.get("global_damage_multiplier", player.global_damage_multiplier))
	player.background_interval_multiplier = float(data.get("background_interval_multiplier", player.background_interval_multiplier))
	player.ultimate_cost_multiplier = float(data.get("ultimate_cost_multiplier", player.ultimate_cost_multiplier))
	player.damage_taken_multiplier = float(data.get("damage_taken_multiplier", player.damage_taken_multiplier))
	player.equipment_damage_multiplier_bonus = float(data.get("equipment_damage_multiplier_bonus", player.equipment_damage_multiplier_bonus))
	player.equipment_speed_bonus = float(data.get("equipment_speed_bonus", player.equipment_speed_bonus))
	player.equipment_max_health_bonus = float(data.get("equipment_max_health_bonus", player.equipment_max_health_bonus))
	player.equipment_energy_gain_bonus = float(data.get("equipment_energy_gain_bonus", player.equipment_energy_gain_bonus))
	player.equipment_dodge_chance = float(data.get("equipment_dodge_chance", player.equipment_dodge_chance))
	player.equipment_health_regen_per_second = float(data.get("equipment_health_regen_per_second", player.equipment_health_regen_per_second))
	player.equipment_low_health_threshold = float(data.get("equipment_low_health_threshold", player.equipment_low_health_threshold))
	player.equipment_low_health_damage_taken_multiplier = float(data.get("equipment_low_health_damage_taken_multiplier", player.equipment_low_health_damage_taken_multiplier))
	player.equipment_skill_range_multiplier = float(data.get("equipment_skill_range_multiplier", player.equipment_skill_range_multiplier))
	player.equipment_cooldown_multiplier = float(data.get("equipment_cooldown_multiplier", player.equipment_cooldown_multiplier))
	player.role_switch_cooldown_bonus = float(data.get("role_switch_cooldown_bonus", player.role_switch_cooldown_bonus))

static func _apply_switch_buff_save_data(player, data: Dictionary) -> void:
	player.switch_power_remaining = float(data.get("switch_power_remaining", 0.0))
	player.switch_power_role_id = str(data.get("switch_power_role_id", ""))
	player.switch_power_damage_multiplier = float(data.get("switch_power_damage_multiplier", 1.0))
	player.switch_power_interval_bonus = float(data.get("switch_power_interval_bonus", 0.0))
	player.switch_power_label = str(data.get("switch_power_label", ""))
	player.pending_entry_blessing_source_role_id = str(data.get("pending_entry_blessing_source_role_id", ""))
	player.entry_blessing_role_id = str(data.get("entry_blessing_role_id", ""))
	player.entry_blessing_label = str(data.get("entry_blessing_label", ""))
	player.entry_blessing_remaining = float(data.get("entry_blessing_remaining", 0.0))
	player.entry_lifesteal_ratio = float(data.get("entry_lifesteal_ratio", 0.0))
	player.entry_haste_interval_bonus = float(data.get("entry_haste_interval_bonus", 0.0))
	player.entry_haste_move_speed_multiplier = float(data.get("entry_haste_move_speed_multiplier", 1.0))
	player.standby_entry_role_id = str(data.get("standby_entry_role_id", ""))
	player.standby_entry_label = str(data.get("standby_entry_label", "待机蓄势"))
	player.standby_entry_remaining = float(data.get("standby_entry_remaining", 0.0))
	player.standby_entry_damage_multiplier = float(data.get("standby_entry_damage_multiplier", 1.0))
	player.standby_entry_interval_bonus = float(data.get("standby_entry_interval_bonus", 0.0))
	player.guard_cover_remaining = float(data.get("guard_cover_remaining", 0.0))
	player.guard_cover_damage_multiplier = float(data.get("guard_cover_damage_multiplier", 1.0))
	player.borrow_fire_role_id = str(data.get("borrow_fire_role_id", ""))
	player.borrow_fire_remaining = float(data.get("borrow_fire_remaining", 0.0))
	player.borrow_fire_damage_multiplier = float(data.get("borrow_fire_damage_multiplier", 1.0))
	player.borrow_fire_interval_bonus = float(data.get("borrow_fire_interval_bonus", 0.0))
	player.borrow_fire_background_multiplier = float(data.get("borrow_fire_background_multiplier", 1.0))
	player.post_ultimate_flow_remaining = float(data.get("post_ultimate_flow_remaining", 0.0))
	player.post_ultimate_flow_background_multiplier = float(data.get("post_ultimate_flow_background_multiplier", 1.0))
	player.ultimate_guard_remaining = float(data.get("ultimate_guard_remaining", 0.0))
	player.ultimate_guard_damage_multiplier = float(data.get("ultimate_guard_damage_multiplier", 1.0))
	player.perpetual_motion_cooldown_remaining = float(data.get("perpetual_motion_cooldown_remaining", 0.0))
	player.frenzy_remaining = float(data.get("frenzy_remaining", 0.0))
	player.frenzy_stacks = int(data.get("frenzy_stacks", 0))
	player.frenzy_overkill_counter = int(data.get("frenzy_overkill_counter", 0))
