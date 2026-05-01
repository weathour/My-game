extends RefCounted

const PLAYER_ROLE_PRESENTER := preload("res://scripts/player/player_role_presenter.gd")
const PLAYER_SWITCH_FLOW := preload("res://scripts/player/player_switch_flow.gd")
const PLAYER_ULTIMATE_FLOW := preload("res://scripts/player/player_ultimate_flow.gd")

static func build_from_player(owner) -> Dictionary:
	var role_data: Dictionary = owner._get_active_role()
	var role_id: String = role_data["id"]
	var interval: float = owner._get_effective_attack_interval(role_id)
	var skill_cooldown_slots: Array = owner._get_active_skill_cooldown_slots(interval)
	var slot_resonance_labels := {
		"body": owner._get_upgrade_slot_label("body"),
		"combat": owner._get_upgrade_slot_label("combat"),
		"skill": owner._get_upgrade_slot_label("skill")
	}
	var slot_resonance_tiers: Dictionary = {}
	for slot_id in ["body", "combat", "skill"]:
		var tier_text := "-"
		if owner._is_slot_resonance_unlocked(slot_id, 6):
			tier_text = "6"
		elif owner._is_slot_resonance_unlocked(slot_id, 3):
			tier_text = "3"
		slot_resonance_tiers[slot_id] = tier_text
	var role_special_data: Dictionary = owner._get_role_special_state(role_id)
	return build_stat_summary({
		"level": owner.level,
		"move_speed": owner._get_current_move_speed(),
		"bullet_damage": owner._get_role_damage(role_id),
		"fire_interval": interval,
		"current_mana": owner._get_role_mana(role_id),
		"max_mana": owner.max_mana,
		"ultimate_energy_cost": owner._get_ultimate_energy_cost(),
		"ultimate_ready": owner._can_use_ultimate(),
		"ultimate_display": PLAYER_ULTIMATE_FLOW.get_ultimate_display(owner, role_id),
		"pickup_radius": owner.pickup_radius + (float(owner._get_attribute_pickup_range_bonus()) if owner.has_method("_get_attribute_pickup_range_bonus") else 0.0),
		"role_name": role_data["name"],
		"role_id": role_id,
		"body_slot_label": owner._get_upgrade_slot_label("body"),
		"combat_slot_label": owner._get_upgrade_slot_label("combat"),
		"skill_slot_label": owner._get_upgrade_slot_label("skill"),
		"team_roles": owner.roles.map(func(role): return role["name"]),
		"active_role_index": owner.active_role_index,
		"auto_attack_enabled": owner.auto_attack_enabled,
		"switch_cooldown": max(0.0, owner.switch_cooldown_remaining),
		"switch_cooldown_base": PLAYER_SWITCH_FLOW.get_switch_cooldown_duration(owner),
		"energy_gain_multiplier": owner.energy_gain_multiplier,
		"background_interval_multiplier": owner.background_interval_multiplier,
		"ultimate_cost_multiplier": owner.ultimate_cost_multiplier,
		"damage_taken_multiplier": owner.damage_taken_multiplier,
		"body_build_level": int(owner.build_slot_levels.get("body", 0)),
		"combat_build_level": int(owner.build_slot_levels.get("combat", 0)),
		"skill_build_level": int(owner.build_slot_levels.get("skill", 0)),
		"attribute_swordsman_trait_level": owner._get_attribute_level("swordsman_trait") if owner.has_method("_get_attribute_level") else 0.0,
		"attribute_gunner_trait_level": owner._get_attribute_level("gunner_trait") if owner.has_method("_get_attribute_level") else 0.0,
		"attribute_mage_trait_level": owner._get_attribute_level("mage_trait") if owner.has_method("_get_attribute_level") else 0.0,

		"slot_resonance_summary": PLAYER_ROLE_PRESENTER.get_slot_resonance_summary(slot_resonance_labels, slot_resonance_tiers),
		"role_detail_summary": PLAYER_ROLE_PRESENTER.get_role_detail_summary(role_id, role_special_data),
		"role_route_summary": PLAYER_ROLE_PRESENTER.get_role_route_summary(role_id, role_special_data),
		"role_core_summary": PLAYER_ROLE_PRESENTER.get_role_core_summary(role_id),
		"switch_power_label": owner.switch_power_label,
		"switch_power_remaining": owner.switch_power_remaining,
		"entry_blessing_label": owner.entry_blessing_label,
		"entry_blessing_remaining": owner.entry_blessing_remaining,
		"entry_blessing_role_id": owner.entry_blessing_role_id,
		"relay_window_remaining": owner.relay_window_remaining,
		"relay_label": owner.relay_label,
		"relay_bonus_pending": owner.relay_bonus_pending,
		"skill_cooldown_slots": skill_cooldown_slots
	})

static func build_stat_summary(context: Dictionary) -> Dictionary:
	return {
		"level": context.get("level", 1),
		"move_speed": context.get("move_speed", 0.0),
		"bullet_damage": context.get("bullet_damage", 0.0),
		"fire_interval": context.get("fire_interval", 0.0),
		"current_mana": context.get("current_mana", 0.0),
		"max_mana": context.get("max_mana", 0.0),
		"ultimate_energy_cost": context.get("ultimate_energy_cost", 0.0),
		"ultimate_ready": context.get("ultimate_ready", false),
		"ultimate_display": context.get("ultimate_display", {}),
		"pickup_radius": context.get("pickup_radius", 0.0),
		"role_name": context.get("role_name", ""),
		"role_id": context.get("role_id", ""),
		"body_slot_label": context.get("body_slot_label", ""),
		"combat_slot_label": context.get("combat_slot_label", ""),
		"skill_slot_label": context.get("skill_slot_label", ""),
		"team_roles": context.get("team_roles", []),
		"active_role_index": context.get("active_role_index", 0),
		"auto_attack_enabled": context.get("auto_attack_enabled", false),
		"switch_cooldown": context.get("switch_cooldown", 0.0),
		"switch_cooldown_base": context.get("switch_cooldown_base", 0.0),
		"energy_gain_multiplier": context.get("energy_gain_multiplier", 1.0),
		"background_interval_multiplier": context.get("background_interval_multiplier", 1.0),
		"ultimate_cost_multiplier": context.get("ultimate_cost_multiplier", 1.0),
		"damage_taken_multiplier": context.get("damage_taken_multiplier", 1.0),
		"body_build_level": context.get("body_build_level", 0),
		"combat_build_level": context.get("combat_build_level", 0),
		"skill_build_level": context.get("skill_build_level", 0),
		"attribute_swordsman_trait_level": context.get("attribute_swordsman_trait_level", 0.0),
		"attribute_gunner_trait_level": context.get("attribute_gunner_trait_level", 0.0),
		"attribute_mage_trait_level": context.get("attribute_mage_trait_level", 0.0),

		"slot_resonance_summary": context.get("slot_resonance_summary", ""),
		"role_detail_summary": context.get("role_detail_summary", ""),
		"role_route_summary": context.get("role_route_summary", ""),
		"role_core_summary": context.get("role_core_summary", ""),
		"switch_power_label": context.get("switch_power_label", ""),
		"switch_power_remaining": context.get("switch_power_remaining", 0.0),
		"entry_blessing_label": context.get("entry_blessing_label", ""),
		"entry_blessing_remaining": context.get("entry_blessing_remaining", 0.0),
		"entry_blessing_role_id": context.get("entry_blessing_role_id", ""),
		"relay_window_remaining": context.get("relay_window_remaining", 0.0),
		"relay_label": context.get("relay_label", ""),
		"relay_bonus_pending": context.get("relay_bonus_pending", false),
		"skill_cooldown_slots": context.get("skill_cooldown_slots", [])
	}
