extends RefCounted

const EQUIPMENT_SLOT_LABEL := "\u88c5\u5907"
const EQUIPMENT_OPTION_COUNT := 3
const EQUIPMENT_MAX_LEVEL := 3

const EQUIPMENT_DEFINITIONS := {
	"small_boss_equipment_flame_amulet": {
		"title": "\u70c8\u7130\u62a4\u7b26",
		"description": "\u6240\u6709\u89d2\u8272\u4f24\u5bb3 +8%\u3002",
		"damage_multiplier_bonus": 0.08
	},
	"small_boss_equipment_wind_amulet": {
		"title": "\u98ce\u606f\u62a4\u7b26",
		"description": "\u6240\u6709\u89d2\u8272\u79fb\u901f +10\uff0c\u5e76\u83b7\u5f97 5% \u901a\u7528\u95ea\u907f\u3002",
		"speed_bonus": 10.0,
		"dodge_bonus": 0.05
	},
	"small_boss_equipment_ocean_amulet": {
		"title": "\u6d0b\u6d41\u62a4\u7b26",
		"description": "\u6700\u5927\u751f\u547d +22\uff0c\u5e76\u83b7\u5f97\u6bcf\u79d2 0.9 \u751f\u547d\u56de\u590d\u3002",
		"max_health_bonus": 22.0,
		"regen_bonus": 0.9
	},
	"small_boss_equipment_earth_child": {
		"title": "\u5927\u5730\u4e4b\u5b50",
		"description": "\u751f\u547d\u4f4e\u4e8e 38% \u65f6\u53d7\u5230\u7684\u4f24\u5bb3\u964d\u4f4e 28%\u3002",
		"low_health_threshold": 0.38,
		"low_health_damage_multiplier": 0.72
	},
	"small_boss_equipment_spyglass": {
		"title": "\u671b\u8fdc\u955c",
		"description": "\u6240\u6709\u6280\u80fd\u7279\u6548\u4e0e\u4f24\u5bb3\u5224\u5b9a\u8303\u56f4 +10%\u3002",
		"skill_range_multiplier_bonus": 0.10
	},
	"small_boss_equipment_strange_cloak": {
		"title": "\u5947\u5f02\u62ab\u98ce",
		"description": "\u5927\u62db\u80fd\u91cf\u83b7\u53d6\u6548\u7387 +15%\u3002",
		"energy_gain_bonus": 0.15
	},
	"small_boss_equipment_spell_prism": {
		"title": "\u6cd5\u672f\u68f1\u955c",
		"description": "\u6240\u6709\u6280\u80fd\u51b7\u5374\u7f29\u77ed 10%\u3002",
		"cooldown_multiplier": 0.9
	}
}


static func get_reward_options(equipment_levels: Dictionary, count: int = EQUIPMENT_OPTION_COUNT) -> Array:
	var ids: Array = []
	for equipment_id in EQUIPMENT_DEFINITIONS.keys():
		if int(equipment_levels.get(str(equipment_id), 0)) < EQUIPMENT_MAX_LEVEL:
			ids.append(str(equipment_id))
	ids.shuffle()
	var options: Array = []
	for index in range(min(max(0, count), ids.size())):
		options.append(make_reward_option(str(ids[index]), equipment_levels))
	if options.is_empty():
		options.append(make_blank_equipment_option())
	return options


static func ensure_role_equipment_levels(owner) -> void:
	if owner.role_equipment_levels == null:
		owner.role_equipment_levels = {}
	if not owner.role_equipment_levels is Dictionary:
		owner.role_equipment_levels = {}
	if owner.role_equipment_levels.is_empty() and owner.equipment_levels is Dictionary and not owner.equipment_levels.is_empty():
		var active_role_id: String = str(owner._get_active_role().get("id", ""))
		if active_role_id != "":
			owner.role_equipment_levels[active_role_id] = owner.equipment_levels.duplicate(true)
	for role_data in owner.roles:
		var role_id: String = str(role_data.get("id", ""))
		if role_id == "":
			continue
		if not owner.role_equipment_levels.has(role_id) or not owner.role_equipment_levels[role_id] is Dictionary:
			owner.role_equipment_levels[role_id] = {}


static func get_role_equipment_levels(owner, role_id: String) -> Dictionary:
	ensure_role_equipment_levels(owner)
	if role_id == "":
		return {}
	if not owner.role_equipment_levels.has(role_id) or not owner.role_equipment_levels[role_id] is Dictionary:
		owner.role_equipment_levels[role_id] = {}
	return owner.role_equipment_levels[role_id]


static func get_active_role_equipment_levels(owner) -> Dictionary:
	return get_role_equipment_levels(owner, str(owner._get_active_role().get("id", "")))


static func get_active_reward_options(owner, count: int = EQUIPMENT_OPTION_COUNT) -> Array:
	return get_reward_options(get_active_role_equipment_levels(owner), count)


static func make_reward_option(equipment_id: String, equipment_levels: Dictionary) -> Dictionary:
	var definition: Dictionary = EQUIPMENT_DEFINITIONS.get(equipment_id, {})
	var owned_count: int = int(equipment_levels.get(equipment_id, 0))
	var description := "%s\n当前角色已持有 %d / %d 个。同名道具可重复持有，效果按持有数量叠加。" % [
		str(definition.get("description", "")),
		owned_count,
		EQUIPMENT_MAX_LEVEL
	]
	return {
		"id": equipment_id,
		"slot": "equipment",
		"slot_label": EQUIPMENT_SLOT_LABEL,
		"title": str(definition.get("title", equipment_id)),
		"description": description,
		"preview_description": description,
		"exact_description": description
	}


static func make_blank_equipment_option() -> Dictionary:
	return {
		"id": "small_boss_blank_equipment",
		"slot": "equipment",
		"slot_label": EQUIPMENT_SLOT_LABEL,
		"title": "\u6682\u65e0\u53ef\u7528\u9053\u5177",
		"description": "\u6240\u6709\u9053\u5177\u90fd\u5df2\u8fbe\u5230 3 \u4e2a\u6301\u6709\u4e0a\u9650\uff0c\u9009\u62e9\u540e\u4e0d\u83b7\u5f97\u989d\u5916\u9053\u5177\u3002",
		"preview_description": "\u7ee7\u7eed\u5956\u52b1\u9009\u62e9\u3002",
		"exact_description": "\u8fd9\u662f\u9632\u6b62\u83dc\u5355\u5361\u4f4f\u7684\u7a7a\u9053\u5177\u9009\u9879\u3002"
	}


static func is_equipment_reward(option_id: String) -> bool:
	return EQUIPMENT_DEFINITIONS.has(option_id)


static func apply_equipment_reward(owner, option_id: String) -> bool:
	if not is_equipment_reward(option_id):
		return false
	var role_id: String = str(owner._get_active_role().get("id", ""))
	var role_levels: Dictionary = get_role_equipment_levels(owner, role_id)
	var current_level: int = int(role_levels.get(option_id, 0))
	if current_level >= EQUIPMENT_MAX_LEVEL:
		return true
	var definition: Dictionary = EQUIPMENT_DEFINITIONS.get(option_id, {})
	role_levels[option_id] = min(EQUIPMENT_MAX_LEVEL, current_level + 1)
	owner.role_equipment_levels[role_id] = role_levels
	recalculate_active_equipment_stats(owner, true)

	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -62.0), str(definition.get("title", option_id)), Color(0.92, 0.86, 0.52, 1.0))
	owner._spawn_ring_effect(owner.global_position, 96.0, Color(0.92, 0.78, 0.34, 0.38), 8.0, 0.22)
	owner._update_fire_timer()
	owner.health_changed.emit(owner.current_health, owner.max_health)
	return true


static func transfer_equipment(owner, equipment_id: String, from_role_id: String, target_role_id: String) -> bool:
	if not is_equipment_reward(equipment_id) or from_role_id == "" or target_role_id == "" or from_role_id == target_role_id:
		return false
	var from_levels: Dictionary = get_role_equipment_levels(owner, from_role_id)
	var target_levels: Dictionary = get_role_equipment_levels(owner, target_role_id)
	var from_count: int = int(from_levels.get(equipment_id, 0))
	var target_count: int = int(target_levels.get(equipment_id, 0))
	if from_count <= 0 or target_count >= EQUIPMENT_MAX_LEVEL:
		return false
	from_levels[equipment_id] = from_count - 1
	if int(from_levels.get(equipment_id, 0)) <= 0:
		from_levels.erase(equipment_id)
	target_levels[equipment_id] = target_count + 1
	owner.role_equipment_levels[from_role_id] = from_levels
	owner.role_equipment_levels[target_role_id] = target_levels
	recalculate_active_equipment_stats(owner, false)
	owner._update_fire_timer()
	owner.stats_changed.emit(owner.get_stat_summary())
	owner.health_changed.emit(owner.current_health, owner.max_health)
	return true


static func get_role_bonus_summary(owner, role_id: String) -> Dictionary:
	var levels: Dictionary = get_role_equipment_levels(owner, role_id)
	var summary := {
		"damage_multiplier_bonus": 0.0,
		"speed_bonus": 0.0,
		"dodge_chance": 0.0,
		"max_health_bonus": 0.0,
		"regen_per_second": 0.0,
		"low_health_threshold": 0.0,
		"low_health_damage_taken_multiplier": 1.0,
		"skill_range_multiplier": 1.0,
		"energy_gain_bonus": 0.0,
		"cooldown_multiplier": 1.0
	}
	for equipment_id in levels.keys():
		var level: int = int(levels.get(equipment_id, 0))
		if level <= 0:
			continue
		var definition: Dictionary = EQUIPMENT_DEFINITIONS.get(str(equipment_id), {})
		summary["damage_multiplier_bonus"] = float(summary["damage_multiplier_bonus"]) + float(definition.get("damage_multiplier_bonus", 0.0)) * level
		summary["speed_bonus"] = float(summary["speed_bonus"]) + float(definition.get("speed_bonus", 0.0)) * level
		summary["dodge_chance"] = min(0.45, float(summary["dodge_chance"]) + float(definition.get("dodge_bonus", 0.0)) * level)
		summary["max_health_bonus"] = float(summary["max_health_bonus"]) + float(definition.get("max_health_bonus", 0.0)) * level
		summary["regen_per_second"] = float(summary["regen_per_second"]) + float(definition.get("regen_bonus", 0.0)) * level
		var threshold: float = float(definition.get("low_health_threshold", 0.0))
		if threshold > 0.0:
			summary["low_health_threshold"] = max(float(summary["low_health_threshold"]), threshold)
			for _index in range(level):
				summary["low_health_damage_taken_multiplier"] = max(
					0.42,
					float(summary["low_health_damage_taken_multiplier"]) * float(definition.get("low_health_damage_multiplier", 1.0))
				)
		summary["skill_range_multiplier"] = float(summary["skill_range_multiplier"]) + float(definition.get("skill_range_multiplier_bonus", 0.0)) * level
		summary["energy_gain_bonus"] = float(summary["energy_gain_bonus"]) + float(definition.get("energy_gain_bonus", 0.0)) * level
		for _index in range(level):
			summary["cooldown_multiplier"] = max(0.65, float(summary["cooldown_multiplier"]) * float(definition.get("cooldown_multiplier", 1.0)))
	return summary


static func get_role_damage_multiplier_bonus(owner, role_id: String) -> float:
	return float(get_role_bonus_summary(owner, role_id).get("damage_multiplier_bonus", 0.0))


static func get_role_energy_gain_bonus(owner, role_id: String) -> float:
	return float(get_role_bonus_summary(owner, role_id).get("energy_gain_bonus", 0.0))


static func recalculate_active_equipment_stats(owner, restore_new_health_bonus: bool = false) -> void:
	ensure_role_equipment_levels(owner)
	var active_role_id: String = str(owner._get_active_role().get("id", ""))
	var summary: Dictionary = get_role_bonus_summary(owner, active_role_id)
	var old_damage_bonus: float = owner.equipment_damage_multiplier_bonus
	var old_speed_bonus: float = owner.equipment_speed_bonus
	var old_health_bonus: float = owner.equipment_max_health_bonus
	var old_energy_bonus: float = owner.equipment_energy_gain_bonus
	var old_cooldown_multiplier: float = owner.equipment_cooldown_multiplier

	owner.equipment_damage_multiplier_bonus = float(summary.get("damage_multiplier_bonus", 0.0))
	owner.equipment_speed_bonus = float(summary.get("speed_bonus", 0.0))
	owner.equipment_max_health_bonus = float(summary.get("max_health_bonus", 0.0))
	owner.equipment_energy_gain_bonus = float(summary.get("energy_gain_bonus", 0.0))
	owner.equipment_dodge_chance = float(summary.get("dodge_chance", 0.0))
	owner.equipment_health_regen_per_second = float(summary.get("regen_per_second", 0.0))
	owner.equipment_low_health_threshold = float(summary.get("low_health_threshold", 0.0))
	owner.equipment_low_health_damage_taken_multiplier = float(summary.get("low_health_damage_taken_multiplier", 1.0))
	owner.equipment_skill_range_multiplier = float(summary.get("skill_range_multiplier", 1.0))
	owner.equipment_cooldown_multiplier = float(summary.get("cooldown_multiplier", 1.0))
	owner.equipment_levels = get_active_role_equipment_levels(owner).duplicate(true)

	owner.global_damage_multiplier = max(0.01, owner.global_damage_multiplier - old_damage_bonus + owner.equipment_damage_multiplier_bonus)
	owner.speed = max(0.0, owner.speed - old_speed_bonus + owner.equipment_speed_bonus)
	owner.energy_gain_multiplier = max(0.01, owner.energy_gain_multiplier - old_energy_bonus + owner.equipment_energy_gain_bonus)
	var health_delta: float = owner.equipment_max_health_bonus - old_health_bonus
	owner.max_health = max(1.0, owner.max_health + health_delta)
	if restore_new_health_bonus and health_delta > 0.0:
		owner.current_health = min(owner.max_health, owner.current_health + health_delta)
	else:
		owner.current_health = min(owner.current_health, owner.max_health)
	if not is_equal_approx(old_cooldown_multiplier, owner.equipment_cooldown_multiplier):
		var remaining_scale: float = owner.equipment_cooldown_multiplier / max(old_cooldown_multiplier, 0.001)
		_scale_active_cooldowns(owner, remaining_scale)


static func apply_passives(owner, delta: float) -> void:
	if delta <= 0.0 or owner.is_dead:
		return
	var regen_amount: float = owner.equipment_health_regen_per_second * delta
	if regen_amount > 0.0:
		owner._heal(regen_amount)


static func try_dodge(owner) -> bool:
	if owner.equipment_dodge_chance <= 0.0:
		return false
	return randf() < owner.equipment_dodge_chance


static func get_low_health_damage_taken_multiplier(owner) -> float:
	if owner.max_health <= 0.0 or owner.equipment_low_health_threshold <= 0.0:
		return 1.0
	if owner.current_health / owner.max_health > owner.equipment_low_health_threshold:
		return 1.0
	return owner.equipment_low_health_damage_taken_multiplier


static func get_skill_range_multiplier(owner) -> float:
	return max(0.2, owner.equipment_skill_range_multiplier)


static func get_cooldown_multiplier(owner) -> float:
	return clamp(owner.equipment_cooldown_multiplier, 0.45, 1.0)


static func _scale_active_cooldowns(owner, scale: float) -> void:
	owner.switch_cooldown_remaining = max(0.0, owner.switch_cooldown_remaining * scale)
	owner.perpetual_motion_cooldown_remaining = max(0.0, owner.perpetual_motion_cooldown_remaining * scale)
	for ability in [
		owner.swordsman_blade_storm_ability,
		owner.swordsman_crescent_wave_ability,
		owner.gunner_infinite_reload_ability,
		owner.gunner_shrapnel_field_ability,
		owner.mage_tidal_surge_ability,
		owner.mage_meta_field_ability
	]:
		if ability != null and ability.get("cooldown_remaining") != null:
			ability.cooldown_remaining = max(0.0, float(ability.cooldown_remaining) * scale)
