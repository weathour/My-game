extends RefCounted

const PLAYER_ROLE_PRESENTER := preload("res://scripts/player/player_role_presenter.gd")
const PLAYER_SWITCH_FLOW := preload("res://scripts/player/player_switch_flow.gd")
const PLAYER_ULTIMATE_FLOW := preload("res://scripts/player/player_ultimate_flow.gd")
const PERFORMANCE_RECORDER := preload("res://scripts/game/performance_recorder.gd")

static func build_from_player(owner) -> Dictionary:
	var role_data: Dictionary = owner._get_active_role()
	var role_id: String = role_data["id"]
	var interval: float = owner._get_effective_attack_interval(role_id)
	var skill_cooldown_slots: Array = owner._get_active_skill_cooldown_slots(interval)
	var role_special_data: Dictionary = owner._get_role_special_state(role_id)
	var ultimate_display: Dictionary = _build_ultimate_display(owner, role_id)
	return build_stat_summary({
		"level": owner.level,
		"move_speed": owner._get_current_move_speed(),
		"bullet_damage": owner._get_role_damage(role_id),
		"fire_interval": interval,
		"current_mana": owner._get_role_mana(role_id),
		"max_mana": owner.max_mana,
		"ultimate_energy_cost": owner._get_ultimate_energy_cost(),
		"ultimate_ready": owner._can_use_ultimate(),
		"ultimate_display": ultimate_display,
		"pickup_radius": owner.pickup_radius + (float(owner._get_attribute_pickup_range_bonus()) if owner.has_method("_get_attribute_pickup_range_bonus") else 0.0),
		"role_name": role_data["name"],
		"role_id": role_id,
		"body_slot_label": "",
		"combat_slot_label": "",
		"skill_slot_label": "",
		"team_roles": owner.roles.map(func(role): return role["name"]),
		"active_role_index": owner.active_role_index,
		"auto_attack_enabled": owner.auto_attack_enabled,
		"switch_cooldown": max(0.0, owner.switch_cooldown_remaining),
		"switch_cooldown_base": PLAYER_SWITCH_FLOW.get_switch_cooldown_duration(owner),
		"energy_gain_multiplier": owner.energy_gain_multiplier,
		"background_interval_multiplier": owner.background_interval_multiplier,
		"ultimate_cost_multiplier": owner.ultimate_cost_multiplier,
		"damage_taken_multiplier": owner.damage_taken_multiplier,
		"attribute_swordsman_trait_level": owner._get_attribute_level("swordsman_trait") if owner.has_method("_get_attribute_level") else 0.0,
		"attribute_gunner_trait_level": owner._get_attribute_level("gunner_trait") if owner.has_method("_get_attribute_level") else 0.0,
		"attribute_mage_trait_level": owner._get_attribute_level("mage_trait") if owner.has_method("_get_attribute_level") else 0.0,
		"role_detail_summary": PLAYER_ROLE_PRESENTER.get_role_detail_summary(role_id, role_special_data),
		"role_route_summary": PLAYER_ROLE_PRESENTER.get_role_route_summary(role_id, role_special_data),
		"role_core_summary": PLAYER_ROLE_PRESENTER.get_role_core_summary(role_id),
		"switch_power_label": owner.switch_power_label,
		"switch_power_remaining": owner.switch_power_remaining,
		"entry_blessing_label": owner.entry_blessing_label,
		"entry_blessing_remaining": owner.entry_blessing_remaining,
		"entry_blessing_role_id": owner.entry_blessing_role_id,
		"skill_cooldown_slots": skill_cooldown_slots
	})

static func build_frame_hud_from_player(owner) -> Dictionary:
	PERFORMANCE_RECORDER.begin_scope("hud_payload_active_role_ms")
	var role_data: Dictionary = owner._get_active_role()
	var role_id: String = str(role_data.get("id", "swordsman"))
	PERFORMANCE_RECORDER.end_scope("hud_payload_active_role_ms")
	PERFORMANCE_RECORDER.begin_scope("hud_payload_attack_interval_ms")
	var interval: float = owner._get_effective_attack_interval(role_id)
	PERFORMANCE_RECORDER.end_scope("hud_payload_attack_interval_ms")
	PERFORMANCE_RECORDER.begin_scope("hud_payload_cooldown_slots_ms")
	var cooldown_slots: Array = owner._get_active_skill_cooldown_slots(interval, false)
	PERFORMANCE_RECORDER.end_scope("hud_payload_cooldown_slots_ms")
	PERFORMANCE_RECORDER.begin_scope("hud_payload_misc_ms")
	var summary: Dictionary = {
		"current_mana": owner._get_role_mana(role_id),
		"max_mana": owner.max_mana,
		"ultimate_energy_cost": owner._get_ultimate_energy_cost(),
		"ultimate_ready": owner._can_use_ultimate(),
		"ultimate_display": _build_frame_ultimate_display(role_id),
		"role_name": str(role_data.get("name", "剑士")),
		"role_id": role_id,
		"team_roles": owner.roles.map(func(role): return role["name"]),
		"active_role_index": owner.active_role_index,
		"auto_attack_enabled": owner.auto_attack_enabled,
		"switch_cooldown": max(0.0, owner.switch_cooldown_remaining),
		"switch_cooldown_base": PLAYER_SWITCH_FLOW.get_switch_cooldown_duration(owner),
		"switch_power_label": owner.switch_power_label,
		"switch_power_remaining": owner.switch_power_remaining,
		"entry_blessing_label": owner.entry_blessing_label,
		"entry_blessing_remaining": owner.entry_blessing_remaining,
		"skill_cooldown_slots": cooldown_slots
	}
	PERFORMANCE_RECORDER.end_scope("hud_payload_misc_ms")
	return summary

static func _build_ultimate_display(owner, role_id: String) -> Dictionary:
	var ultimate_display: Dictionary = PLAYER_ULTIMATE_FLOW.get_ultimate_display(owner, role_id)
	if owner.has_method("get_skill_next_requirement_text"):
		var ultimate_skill_id: String = str(ultimate_display.get("skill_id", ""))
		var ultimate_requirement: String = str(owner.get_skill_next_requirement_text(ultimate_skill_id))
		if ultimate_requirement != "":
			ultimate_display["description"] = "%s\n\n进化需求：\n%s" % [str(ultimate_display.get("description", "")), ultimate_requirement]
	return ultimate_display

static func _build_frame_ultimate_display(role_id: String) -> Dictionary:
	var ultimate_display: Dictionary = PLAYER_ULTIMATE_FLOW.get_ultimate_display(null, role_id)
	ultimate_display["description"] = str(ultimate_display.get("description", "当前英雄的大招。"))
	return ultimate_display

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
		"attribute_swordsman_trait_level": context.get("attribute_swordsman_trait_level", 0.0),
		"attribute_gunner_trait_level": context.get("attribute_gunner_trait_level", 0.0),
		"attribute_mage_trait_level": context.get("attribute_mage_trait_level", 0.0),
		"role_detail_summary": context.get("role_detail_summary", ""),
		"role_route_summary": context.get("role_route_summary", ""),
		"role_core_summary": context.get("role_core_summary", ""),
		"switch_power_label": context.get("switch_power_label", ""),
		"switch_power_remaining": context.get("switch_power_remaining", 0.0),
		"entry_blessing_label": context.get("entry_blessing_label", ""),
		"entry_blessing_remaining": context.get("entry_blessing_remaining", 0.0),
		"entry_blessing_role_id": context.get("entry_blessing_role_id", ""),
		"skill_cooldown_slots": context.get("skill_cooldown_slots", [])
	}
