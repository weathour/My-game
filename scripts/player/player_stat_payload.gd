extends RefCounted

const PLAYER_ROLE_PRESENTER := preload("res://scripts/player/player_role_presenter.gd")
const PLAYER_SWITCH_FLOW := preload("res://scripts/player/player_switch_flow.gd")
const PLAYER_ULTIMATE_FLOW := preload("res://scripts/player/player_ultimate_flow.gd")
const RUAN_STONE_SYSTEM := preload("res://scripts/player/ruan_stone_system.gd")
const PERFORMANCE_RECORDER := preload("res://scripts/game/performance_recorder.gd")

static func build_from_player(owner) -> Dictionary:
	var role_data: Dictionary = owner._get_active_role()
	var role_id: String = role_data["id"]
	var interval: float = owner._get_effective_attack_interval(role_id)
	var skill_cooldown_slots: Array = owner._get_active_skill_cooldown_slots(interval)
	var role_special_data: Dictionary = owner._get_role_special_state(role_id)
	var ultimate_display: Dictionary = _build_ultimate_display(owner, role_id)
	var buff_status_slots: Array = _build_buff_status_slots(owner)
	var team_role_statuses: Array = _build_team_role_statuses(owner, role_id, true)
	var ruan_stone_summary := _build_ruan_stone_summary(owner)
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
		"switch_energy": owner._get_role_switch_energy(role_id),
		"switch_energy_by_role": _build_switch_energy_by_role(owner),
		"switch_energy_required": owner.SWITCH_ENTRY_ENERGY_REQUIRED,
		"energy_gain_multiplier": owner.energy_gain_multiplier,
		"background_interval_multiplier": owner.background_interval_multiplier,
		"ultimate_cost_multiplier": owner.ultimate_cost_multiplier,
		"damage_reduction_value": owner._get_role_damage_reduction_value(role_id) if owner.has_method("_get_role_damage_reduction_value") else 0.0,
		"damage_reduction_rate": owner._get_role_damage_reduction_rate(role_id) if owner.has_method("_get_role_damage_reduction_rate") else 0.0,
		"damage_taken_multiplier": owner._get_effective_damage_taken_multiplier() if owner.has_method("_get_effective_damage_taken_multiplier") else 1.0,
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
		"skill_cooldown_slots": skill_cooldown_slots,
		"team_role_statuses": team_role_statuses,
		"buff_status_slots": buff_status_slots,
		"ruan_bone_count": ruan_stone_summary["ruan_bone_count"],
		"ruan_stone_carried_count": ruan_stone_summary["ruan_stone_carried_count"],
		"ruan_stone_carry_limit": ruan_stone_summary["ruan_stone_carry_limit"],
		"ruan_stone_summary": ruan_stone_summary["ruan_stone_summary"]
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
	var buff_status_slots: Array = _build_buff_status_slots(owner)
	var team_role_statuses: Array = _build_team_role_statuses(owner, role_id, false)
	var ruan_stone_summary := _build_ruan_stone_summary(owner)
	var summary: Dictionary = {
		"current_mana": owner._get_role_mana(role_id),
		"max_mana": owner.max_mana,
		"ultimate_energy_cost": owner._get_ultimate_energy_cost(),
		"ultimate_ready": owner._can_use_ultimate(),
		"ultimate_display": _build_frame_ultimate_display(owner, role_id),
		"role_name": str(role_data.get("name", "剑士")),
		"role_id": role_id,
		"team_roles": owner.roles.map(func(role): return role["name"]),
		"active_role_index": owner.active_role_index,
		"auto_attack_enabled": owner.auto_attack_enabled,
		"switch_cooldown": max(0.0, owner.switch_cooldown_remaining),
		"switch_cooldown_base": PLAYER_SWITCH_FLOW.get_switch_cooldown_duration(owner),
		"switch_energy": owner._get_role_switch_energy(role_id),
		"switch_energy_by_role": _build_switch_energy_by_role(owner),
		"switch_energy_required": owner.SWITCH_ENTRY_ENERGY_REQUIRED,
		"switch_power_label": owner.switch_power_label,
		"switch_power_remaining": owner.switch_power_remaining,
		"entry_blessing_label": owner.entry_blessing_label,
		"entry_blessing_remaining": owner.entry_blessing_remaining,
		"skill_cooldown_slots": cooldown_slots,
		"team_role_statuses": team_role_statuses,
		"buff_status_slots": buff_status_slots,
		"ruan_bone_count": ruan_stone_summary["ruan_bone_count"],
		"ruan_stone_carried_count": ruan_stone_summary["ruan_stone_carried_count"],
		"ruan_stone_carry_limit": ruan_stone_summary["ruan_stone_carry_limit"],
		"ruan_stone_summary": ruan_stone_summary["ruan_stone_summary"]
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

static func _build_frame_ultimate_display(owner, role_id: String) -> Dictionary:
	var ultimate_display: Dictionary = PLAYER_ULTIMATE_FLOW.get_ultimate_display(owner, role_id, false)
	ultimate_display["description"] = str(ultimate_display.get("description", "当前英雄的大招。"))
	return ultimate_display

static func _build_switch_energy_by_role(owner) -> Dictionary:
	var energy_by_role: Dictionary = {}
	for role_data in owner.roles:
		var role_id: String = str(role_data.get("id", ""))
		if role_id == "":
			continue
		energy_by_role[role_id] = owner._get_role_switch_energy(role_id)
	return energy_by_role


static func _build_ruan_stone_summary(owner) -> Dictionary:
	var carried_count: int = int(owner.get_ruan_stone_carried_count()) if owner != null and owner.has_method("get_ruan_stone_carried_count") else 0
	var carry_limit: int = max(1, int(owner.get_ruan_stone_carry_limit())) if owner != null and owner.has_method("get_ruan_stone_carry_limit") else 1
	var summary_text: String = str(owner.get_ruan_stone_carry_summary()) if owner != null and owner.has_method("get_ruan_stone_carry_summary") else "未携带"
	return {
		"ruan_bone_count": max(0, int(owner.get_ruan_bone_count())) if owner != null and owner.has_method("get_ruan_bone_count") else 0,
		"ruan_stone_carried_count": max(0, carried_count),
		"ruan_stone_carry_limit": carry_limit,
		"ruan_stone_summary": summary_text
	}

static func _build_team_role_statuses(owner, active_role_id: String, include_descriptions: bool) -> Array:
	var statuses: Array = []
	for index in range(owner.roles.size()):
		var role_data: Dictionary = owner.roles[index]
		var role_id: String = str(role_data.get("id", ""))
		if role_id == "":
			continue
		var attack_interval: float = owner._get_effective_attack_interval(role_id)
		var cooldown_slots: Array = []
		if owner.has_method("_get_role_skill_cooldown_slots"):
			cooldown_slots = owner._get_role_skill_cooldown_slots(role_id, attack_interval, include_descriptions)
		var max_health: float = max(1.0, float(owner._get_role_max_health(role_id)) if owner.has_method("_get_role_max_health") else float(owner.max_health))
		var current_health: float = clamp(float(owner._get_role_current_health(role_id)) if owner.has_method("_get_role_current_health") else float(owner.current_health), 0.0, max_health)
		var temporary_health: float = max(0.0, float(owner._get_role_temporary_health(role_id)) if owner.has_method("_get_role_temporary_health") else float(owner.current_temporary_health))
		var max_mana: float = max(1.0, float(owner.max_mana))
		var current_mana: float = clamp(float(owner._get_role_mana(role_id)), 0.0, max_mana)
		statuses.append({
			"role_id": role_id,
			"role_name": str(role_data.get("name", role_id)),
			"role_index": index,
			"is_active": role_id == active_role_id,
			"current_health": current_health,
			"temporary_health": temporary_health,
			"max_health": max_health,
			"current_mana": current_mana,
			"max_mana": max_mana,
			"ultimate_energy_cost": owner._get_ultimate_energy_cost(),
			"switch_energy": owner._get_role_switch_energy(role_id),
			"switch_energy_required": owner.SWITCH_ENTRY_ENERGY_REQUIRED,
			"color": role_data.get("color", Color.WHITE),
			"cooldown_slots": cooldown_slots
		})
	return statuses

static func _build_buff_status_slots(owner) -> Array:
	var slots: Array = []
	var plague_slot: Dictionary = preload("res://scripts/player/player_plague_flow.gd").get_buff_slot(owner)
	if not plague_slot.is_empty():
		slots.append(plague_slot)
	var blindness = preload("res://scripts/player/player_blindness.gd").get_effect(owner) if owner != null else null
	if blindness != null and blindness.remaining > 0.0:
		slots.append({
			"id": "blindness",
			"name": "目盲",
			"description": "只能看见自身半径60范围，持续2.5秒；每10秒最多触发一次。",
			"text": "盲",
			"color": Color(0.5, 0.3, 0.7, 1.0),
			"base_color": Color(0.15, 0.08, 0.22, 1.0),
			"remaining": blindness.remaining,
			"duration": 2.5,
			"cooldown": false
		})
	var domain_remaining: float = preload("res://scripts/enemies/skulltomb_domain_effect.gd").get_remaining(owner) if owner != null else 0.0
	if owner != null and (float(owner.get("healing_block_remaining")) > 0.0 or domain_remaining > 0.0):
		var healing_remaining: float = maxf(float(owner.get("healing_block_remaining")), domain_remaining)
		slots.append({
			"id": "healing_block",
			"name": "禁疗",
			"description": "死亡领域内无法回复生命，移动速度降低10%。" if domain_remaining > 0.0 else "无法回复生命。",
			"text": "疗",
			"icon_id": "healing_block",
			"color": Color(0.88, 0.08, 0.06, 0.96),
			"base_color": Color(0.62, 0.06, 0.05, 0.92),
			"remaining": healing_remaining,
			"duration": max(healing_remaining, 1.0),
			"cooldown": false
		})
	if owner != null and float(owner.get("aging_remaining")) > 0.0:
		var aging_remaining: float = float(owner.get("aging_remaining"))
		slots.append({
			"id": "aging",
			"name": "衰老",
			"description": "引渡人周围750范围内，每秒受到当前生命值12%＋最大生命值0.5%的伤害；计算减伤，不计算护甲。",
			"text": "衰",
			"icon_id": "aging",
			"color": Color(0.50, 0.18, 0.56, 0.96),
			"base_color": Color(0.36, 0.06, 0.42, 0.92),
			"remaining": aging_remaining,
			"duration": max(aging_remaining, 1.0),
			"cooldown": false
		})
	if owner != null and owner.has_method("_get_swordsman_bloodthirst_buff_slot"):
		var swordsman_bloodthirst_slot: Dictionary = owner._get_swordsman_bloodthirst_buff_slot()
		if not swordsman_bloodthirst_slot.is_empty():
			slots.append(swordsman_bloodthirst_slot)
	if owner != null and owner.has_method("_get_swordsman_will_buff_slot"):
		var swordsman_will_slot: Dictionary = owner._get_swordsman_will_buff_slot()
		if not swordsman_will_slot.is_empty():
			slots.append(swordsman_will_slot)
	if owner != null and owner.has_method("_get_gunner_flash_buff_slot"):
		var gunner_flash_slot: Dictionary = owner._get_gunner_flash_buff_slot()
		if not gunner_flash_slot.is_empty():
			slots.append(gunner_flash_slot)
	if owner != null and owner.has_method("_get_mage_arcane_charge_buff_slot"):
		var mage_arcane_charge_slot: Dictionary = owner._get_mage_arcane_charge_buff_slot()
		if not mage_arcane_charge_slot.is_empty():
			slots.append(mage_arcane_charge_slot)
	return slots

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
		"switch_energy": context.get("switch_energy", 0.0),
		"switch_energy_by_role": context.get("switch_energy_by_role", {}),
		"switch_energy_required": context.get("switch_energy_required", 100.0),
		"energy_gain_multiplier": context.get("energy_gain_multiplier", 1.0),
		"background_interval_multiplier": context.get("background_interval_multiplier", 1.0),
		"ultimate_cost_multiplier": context.get("ultimate_cost_multiplier", 1.0),
		"damage_reduction_value": context.get("damage_reduction_value", 0.0),
		"damage_reduction_rate": context.get("damage_reduction_rate", 0.0),
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
		"skill_cooldown_slots": context.get("skill_cooldown_slots", []),
		"team_role_statuses": context.get("team_role_statuses", []),
		"buff_status_slots": context.get("buff_status_slots", []),
		"ruan_bone_count": context.get("ruan_bone_count", 0),
		"equipped_ruan_stone": context.get("equipped_ruan_stone", ""),
		"ruan_stone_carried_count": context.get("ruan_stone_carried_count", 0),
		"ruan_stone_carry_limit": context.get("ruan_stone_carry_limit", 1),
		"ruan_stone_summary": context.get("ruan_stone_summary", "未携带")
	}
