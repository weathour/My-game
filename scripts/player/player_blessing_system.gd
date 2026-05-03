extends RefCounted

const OFFER_COUNT := 3
const TIER_II_UNLOCK_LEVEL := 7
const TIER_II_FULL_LEVEL := 15
const MAX_LEVEL_PER_TIER := 3
const OPTION_PREFIX := "blessing:"
const ROLE_BOUND := "role"
const SKILL_BOUND := "skill"

const DEFINITIONS := {
	"divine_grace": {
		"title": "神赐",
		"binding": ROLE_BOUND,
		"stat": "max_health",
		"tier_values": {1: 18.0, 2: 34.0},
		"description": "增加当前角色血量。"
	},
	"prayer": {
		"title": "祷告",
		"binding": ROLE_BOUND,
		"stat": "cooldown_reduction",
		"tier_values": {1: 0.04, 2: 0.075},
		"description": "减少当前角色技能 CD。"
	},
	"formation_break": {
		"title": "破阵",
		"binding": ROLE_BOUND,
		"stat": "skill_range",
		"tier_values": {1: 0.06, 2: 0.11},
		"description": "增加当前角色技能范围。"
	},
	"benediction": {
		"title": "恩典",
		"binding": ROLE_BOUND,
		"stat": "energy_gain",
		"tier_values": {1: 0.08, 2: 0.15},
		"description": "增加当前角色大招能量回复。"
	},
	"greed": {
		"title": "贪婪",
		"binding": ROLE_BOUND,
		"stat": "lifesteal",
		"tier_values": {1: 0.015, 2: 0.03},
		"description": "增加当前角色吸血。"
	},
	"tailwind": {
		"title": "乘风",
		"binding": ROLE_BOUND,
		"stat": "move_speed",
		"tier_values": {1: 7.0, 2: 13.0},
		"description": "增加当前角色移速。"
	},
	"tide_rain": {
		"title": "潮雨",
		"binding": SKILL_BOUND,
		"stat": "duration_skill_duration",
		"tier_values": {1: 0.06, 2: 0.12},
		"description": "增加持续性技能持续时间。当前先记录等级，具体技能绑定在下一步接入。"
	},
	"blazing_sun": {
		"title": "焰阳",
		"binding": ROLE_BOUND,
		"stat": "damage",
		"tier_values": {1: 0.055, 2: 0.10},
		"description": "增加当前角色造成伤害。"
	},
	"reprise": {
		"title": "再演",
		"binding": SKILL_BOUND,
		"stat": "combo_skill_extra",
		"tier_values": {1: 0.5, 2: 1.0},
		"description": "连段技能 +1。I 级每级给一个 50% 效果的额外连段；II 级每级给一个 100% 效果的额外连段。当前先记录等级，具体技能绑定在下一步接入。"
	},
	"phantom": {
		"title": "幻影",
		"binding": ROLE_BOUND,
		"stat": "dodge",
		"tier_values": {1: 0.035, 2: 0.065},
		"description": "增加当前角色闪避。"
	},
	"unyielding": {
		"title": "不屈",
		"binding": ROLE_BOUND,
		"stat": "damage_reduction",
		"tier_values": {1: 0.035, 2: 0.065},
		"description": "增加当前角色减伤。"
	},
	"trick": {
		"title": "戏法",
		"binding": SKILL_BOUND,
		"stat": "quantity_skill_count",
		"tier_values": {1: 0.5, 2: 1.0},
		"description": "数量技能个数增加。当前先记录等级，具体技能绑定在下一步接入。"
	}
}


static func build_empty_role_state(roles: Array) -> Dictionary:
	var state := {}
	for role_data in roles:
		if role_data is not Dictionary:
			continue
		var role_id := str((role_data as Dictionary).get("id", ""))
		if role_id != "":
			state[role_id] = {}
	return state


static func build_empty_skill_state() -> Dictionary:
	return {}


static func normalize_role_state(value: Variant, roles: Array) -> Dictionary:
	var state := build_empty_role_state(roles)
	if value is Dictionary:
		for role_id_value in (value as Dictionary).keys():
			var role_id := str(role_id_value)
			if not state.has(role_id):
				state[role_id] = {}
			state[role_id] = _normalize_binding_levels((value as Dictionary).get(role_id_value, {}))
	return state


static func normalize_skill_state(value: Variant) -> Dictionary:
	return _normalize_binding_levels(value)


static func build_offer_for_owner(owner) -> Dictionary:
	var options := _pick_options(owner, OFFER_COUNT)
	return {
		"options": options,
		"context": {
			"offer_mode": "blessing",
			"refresh_limit": 0,
			"refresh_remaining": 0,
			"refresh_button_label": "",
			"summary": "祝福三选一；英雄特性训练仍可同时选择。"
		}
	}


static func refresh_offer_for_owner(owner, _current_offer: Dictionary) -> Dictionary:
	return build_offer_for_owner(owner)


static func apply_option(owner, option_id: String) -> bool:
	if not option_id.begins_with(OPTION_PREFIX):
		return false
	var payload := option_id.trim_prefix(OPTION_PREFIX).split(":")
	if payload.size() < 2:
		return false
	var blessing_id := str(payload[0])
	var tier := int(payload[1])
	return apply_blessing(owner, blessing_id, tier)


static func apply_blessing(owner, blessing_id: String, tier: int) -> bool:
	if not DEFINITIONS.has(blessing_id):
		return false
	tier = clamp(tier, 1, 2)
	var definition: Dictionary = DEFINITIONS.get(blessing_id, {})
	var binding := str(definition.get("binding", ROLE_BOUND))
	if binding == ROLE_BOUND:
		return _apply_role_blessing(owner, blessing_id, tier, definition)
	return _apply_skill_blessing(owner, blessing_id, tier, definition)


static func get_role_stat_bonus(owner, role_id: String, stat: String) -> float:
	var levels: Dictionary = _get_shared_role_levels(owner)
	return _sum_stat_bonus(levels, stat)


static func get_skill_stat_bonus(owner, stat: String) -> float:
	var levels: Dictionary = _get_skill_levels(owner)
	return _sum_stat_bonus(levels, stat)


static func get_skill_effect_scales(owner, stat: String) -> Array[float]:
	var levels: Dictionary = _get_skill_levels(owner)
	var scales: Array[float] = []
	for blessing_id in levels.keys():
		var definition: Dictionary = DEFINITIONS.get(str(blessing_id), {})
		if str(definition.get("binding", ROLE_BOUND)) != SKILL_BOUND:
			continue
		if str(definition.get("stat", "")) != stat:
			continue
		var tier_values: Dictionary = definition.get("tier_values", {})
		var blessing_levels: Dictionary = levels.get(blessing_id, {})
		for tier_value in blessing_levels.keys():
			var tier := int(tier_value)
			var count := int(blessing_levels.get(tier_value, 0))
			var scale := float(tier_values.get(tier, 0.0))
			for _index in range(max(0, count)):
				if scale > 0.0:
					scales.append(scale)
	return scales


static func get_blessing_level_summary(owner, role_id: String = "") -> Dictionary:
	var summary := {}
	if role_id != "":
		summary["role"] = _get_shared_role_levels(owner).duplicate(true)
	summary["skill"] = _get_skill_levels(owner).duplicate(true)
	return summary


static func can_compose_role_blessing(owner, role_id: String, blessing_id: String) -> bool:
	var definition: Dictionary = DEFINITIONS.get(blessing_id, {})
	if str(definition.get("binding", ROLE_BOUND)) != ROLE_BOUND:
		return false
	return _can_compose_from_levels(_get_shared_role_levels(owner), blessing_id)


static func can_compose_skill_blessing(owner, blessing_id: String) -> bool:
	var definition: Dictionary = DEFINITIONS.get(blessing_id, {})
	if str(definition.get("binding", ROLE_BOUND)) != SKILL_BOUND:
		return false
	return _can_compose_from_levels(_get_skill_levels(owner), blessing_id)


static func compose_role_blessing(owner, role_id: String, blessing_id: String) -> bool:
	if not can_compose_role_blessing(owner, role_id, blessing_id):
		return false
	var levels: Dictionary = _get_shared_role_levels(owner)
	var blessing_levels: Dictionary = (levels.get(blessing_id, {}) as Dictionary).duplicate(true)
	blessing_levels[2] = 1
	levels[blessing_id] = blessing_levels
	_set_shared_role_levels(owner, levels)
	var definition: Dictionary = DEFINITIONS.get(blessing_id, {})
	_apply_role_stat_delta(owner, role_id, str(definition.get("stat", "")), float((definition.get("tier_values", {}) as Dictionary).get(2, 0.0)))
	if owner.has_method("_update_active_role_state"):
		owner._update_active_role_state()
	if owner.has_method("_spawn_combat_tag"):
		owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -62.0), "%sII 合成" % str(definition.get("title", blessing_id)), Color(0.58, 0.95, 0.55, 1.0))
	return true


static func compose_skill_blessing(owner, blessing_id: String) -> bool:
	if not can_compose_skill_blessing(owner, blessing_id):
		return false
	var levels: Dictionary = _get_skill_levels(owner)
	var blessing_levels: Dictionary = (levels.get(blessing_id, {}) as Dictionary).duplicate(true)
	blessing_levels[2] = 1
	levels[blessing_id] = blessing_levels
	owner.skill_blessing_levels = levels
	var definition: Dictionary = DEFINITIONS.get(blessing_id, {})
	if owner.has_method("_spawn_combat_tag"):
		owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -62.0), "%sII 合成" % str(definition.get("title", blessing_id)), Color(0.58, 0.95, 0.55, 1.0))
	if owner.has_method("_update_fire_timer"):
		owner._update_fire_timer()
	if owner.get("stats_changed") != null:
		owner.stats_changed.emit(owner.get_stat_summary())
	return true


static func _pick_options(owner, count: int) -> Array:
	var candidate_options: Array = []
	var tiers := _available_tiers_for_level(int(owner.get("level")) if owner != null else 1)
	for blessing_id in DEFINITIONS.keys():
		for tier in tiers:
			if _is_offerable(owner, str(blessing_id), int(tier)):
				candidate_options.append(_make_option(owner, str(blessing_id), int(tier)))
	candidate_options.shuffle()
	if candidate_options.size() > count:
		return candidate_options.slice(0, count)
	return candidate_options


static func _available_tiers_for_level(player_level: int) -> Array[int]:
	if player_level < TIER_II_UNLOCK_LEVEL:
		return [1]
	var tier_ii_chance: float = clamp(float(player_level - TIER_II_UNLOCK_LEVEL + 1) / float(max(1, TIER_II_FULL_LEVEL - TIER_II_UNLOCK_LEVEL + 1)), 0.12, 0.65)
	if randf() < tier_ii_chance:
		return [1, 2]
	return [1]


static func _is_offerable(owner, blessing_id: String, tier: int) -> bool:
	var definition: Dictionary = DEFINITIONS.get(blessing_id, {})
	var binding := str(definition.get("binding", ROLE_BOUND))
	var levels := _get_skill_levels(owner) if binding == SKILL_BOUND else _get_shared_role_levels(owner)
	var current := int((levels.get(blessing_id, {}) as Dictionary).get(tier, 0))
	if current >= MAX_LEVEL_PER_TIER:
		return false
	return true


static func _make_option(owner, blessing_id: String, tier: int) -> Dictionary:
	var definition: Dictionary = DEFINITIONS.get(blessing_id, {})
	var binding := str(definition.get("binding", ROLE_BOUND))
	var role_id := str(owner._get_active_role().get("id", "")) if owner != null and owner.has_method("_get_active_role") else ""
	var levels := _get_skill_levels(owner) if binding == SKILL_BOUND else _get_shared_role_levels(owner)
	var current := int((levels.get(blessing_id, {}) as Dictionary).get(tier, 0))
	var next_level: int = min(MAX_LEVEL_PER_TIER, current + 1)
	var tier_label := _tier_label(tier)
	var title := "%s%s Lv.%d" % [str(definition.get("title", blessing_id)), tier_label, next_level]
	var binding_text := "绑定：技能（下一步接入具体技能）" if binding == SKILL_BOUND else "绑定：三名角色共享"
	var value_text := _format_value(definition, tier)
	var description := "%s\n%s\n当前：%s Lv.%d / %d\n每级效果：%s\n%s" % [
		str(definition.get("description", "")),
		binding_text,
		tier_label,
		next_level,
		MAX_LEVEL_PER_TIER,
		value_text,
		"提示：I 级 Lv.3 后可在角色面板手动合成 II Lv.1。" if tier == 1 else "提示：II 级从 Lv.7 后按概率独立刷出，也可由 I Lv.3 手动合成。"
	]
	return {
		"id": "%s%s:%d" % [OPTION_PREFIX, blessing_id, tier],
		"slot": "body",
		"slot_label": "祝福",
		"title": title,
		"summary": str(definition.get("description", "")),
		"short_description": str(definition.get("description", "")),
		"description": description,
		"preview_description": description,
		"detail_description": description,
		"exact_description": description,
		"blessing_id": blessing_id,
		"blessing_tier": tier,
		"blessing_binding": binding,
		"evolved": tier >= 2
	}


static func _apply_role_blessing(owner, blessing_id: String, tier: int, definition: Dictionary) -> bool:
	var role_id := str(owner._get_active_role().get("id", ""))
	if role_id == "":
		return false
	var role_levels: Dictionary = _get_shared_role_levels(owner)
	var blessing_levels: Dictionary = (role_levels.get(blessing_id, {}) as Dictionary).duplicate(true)
	var previous_level := int(blessing_levels.get(tier, 0))
	if previous_level >= MAX_LEVEL_PER_TIER:
		return true
	blessing_levels[tier] = previous_level + 1
	role_levels[blessing_id] = blessing_levels
	_set_shared_role_levels(owner, role_levels)
	_apply_role_stat_delta(owner, role_id, str(definition.get("stat", "")), float((definition.get("tier_values", {}) as Dictionary).get(tier, 0.0)))
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -62.0), "%s%s" % [str(definition.get("title", blessing_id)), _tier_label(tier)], Color(0.92, 0.86, 0.54, 1.0))
	return true


static func _apply_skill_blessing(owner, blessing_id: String, tier: int, definition: Dictionary) -> bool:
	owner.skill_blessing_levels = normalize_skill_state(owner.skill_blessing_levels)
	var skill_levels: Dictionary = _get_skill_levels(owner)
	var blessing_levels: Dictionary = (skill_levels.get(blessing_id, {}) as Dictionary).duplicate(true)
	var previous_level := int(blessing_levels.get(tier, 0))
	if previous_level >= MAX_LEVEL_PER_TIER:
		return true
	blessing_levels[tier] = previous_level + 1
	skill_levels[blessing_id] = blessing_levels
	owner.skill_blessing_levels = skill_levels
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -62.0), "%s%s" % [str(definition.get("title", blessing_id)), _tier_label(tier)], Color(0.64, 0.90, 1.0, 1.0))
	return true


static func _apply_role_stat_delta(owner, role_id: String, stat: String, value: float) -> void:
	var role_data: Dictionary = owner.role_upgrade_levels.get(role_id, {}).duplicate(true)
	match stat:
		"max_health":
			owner.max_health += value
			owner.current_health = min(owner.max_health, owner.current_health + value)
			owner.health_changed.emit(owner.current_health, owner.max_health)
		"cooldown_reduction":
			if str(owner._get_active_role().get("id", "")) == role_id:
				owner.equipment_cooldown_multiplier = max(0.45, owner.equipment_cooldown_multiplier * max(0.2, 1.0 - value))
		"skill_range":
			if str(owner._get_active_role().get("id", "")) == role_id:
				owner.equipment_skill_range_multiplier += value
		"energy_gain":
			pass
		"lifesteal":
			pass
		"move_speed":
			pass
		"damage":
			pass
		"dodge":
			if str(owner._get_active_role().get("id", "")) == role_id:
				owner.equipment_dodge_chance = min(0.55, owner.equipment_dodge_chance + value)
		"damage_reduction":
			if str(owner._get_active_role().get("id", "")) == role_id:
				owner.damage_taken_multiplier = max(0.45, owner.damage_taken_multiplier * max(0.2, 1.0 - value))
	if not role_data.is_empty():
		owner.role_upgrade_levels[role_id] = role_data
	owner._update_fire_timer()
	owner.stats_changed.emit(owner.get_stat_summary())


static func apply_active_role_runtime_bonuses(owner) -> void:
	if owner == null or not owner.has_method("_get_active_role"):
		return
	var role_id := str(owner._get_active_role().get("id", ""))
	if role_id == "":
		return
	var cooldown_bonus := get_role_stat_bonus(owner, role_id, "cooldown_reduction")
	var range_bonus := get_role_stat_bonus(owner, role_id, "skill_range")
	var dodge_bonus := get_role_stat_bonus(owner, role_id, "dodge")
	var reduction_bonus := get_role_stat_bonus(owner, role_id, "damage_reduction")
	if cooldown_bonus > 0.0:
		owner.equipment_cooldown_multiplier = max(0.45, owner.equipment_cooldown_multiplier * max(0.2, 1.0 - cooldown_bonus))
	if range_bonus > 0.0:
		owner.equipment_skill_range_multiplier += range_bonus
	if dodge_bonus > 0.0:
		owner.equipment_dodge_chance = min(0.55, owner.equipment_dodge_chance + dodge_bonus)
	if reduction_bonus > 0.0:
		owner.damage_taken_multiplier = max(0.45, owner.damage_taken_multiplier * max(0.2, 1.0 - reduction_bonus))


static func _sum_stat_bonus(levels: Dictionary, stat: String) -> float:
	var result := 0.0
	for blessing_id in levels.keys():
		var definition: Dictionary = DEFINITIONS.get(str(blessing_id), {})
		if str(definition.get("stat", "")) != stat:
			continue
		var tier_values: Dictionary = definition.get("tier_values", {})
		var blessing_levels: Dictionary = levels.get(blessing_id, {})
		for tier_value in blessing_levels.keys():
			var tier := int(tier_value)
			result += float(tier_values.get(tier, 0.0)) * float(blessing_levels.get(tier_value, 0))
	return result


static func _get_role_levels(owner, role_id: String) -> Dictionary:
	if owner == null or role_id == "":
		return {}
	if not owner.role_blessing_levels is Dictionary:
		owner.role_blessing_levels = {}
	if not owner.role_blessing_levels.has(role_id) or not owner.role_blessing_levels[role_id] is Dictionary:
		owner.role_blessing_levels[role_id] = {}
	return owner.role_blessing_levels[role_id]


static func sync_shared_role_blessings(owner) -> void:
	if owner == null:
		return
	_set_shared_role_levels(owner, _get_shared_role_levels(owner))


static func _get_shared_role_levels(owner) -> Dictionary:
	if owner == null:
		return {}
	owner.role_blessing_levels = normalize_role_state(owner.role_blessing_levels, owner.roles)
	var shared: Dictionary = {}
	for role_id_value in owner.role_blessing_levels.keys():
		var role_levels: Dictionary = owner.role_blessing_levels.get(role_id_value, {})
		for blessing_id_value in role_levels.keys():
			var blessing_id := str(blessing_id_value)
			var definition: Dictionary = DEFINITIONS.get(blessing_id, {})
			if str(definition.get("binding", ROLE_BOUND)) != ROLE_BOUND:
				continue
			var source_levels: Dictionary = role_levels.get(blessing_id_value, {})
			var merged_levels: Dictionary = (shared.get(blessing_id, {}) as Dictionary).duplicate(true)
			for tier_value in source_levels.keys():
				var tier := int(tier_value)
				var amount := int(source_levels.get(tier_value, 0))
				merged_levels[tier] = max(int(merged_levels.get(tier, 0)), amount)
			if not merged_levels.is_empty():
				shared[blessing_id] = merged_levels
	_set_shared_role_levels(owner, shared)
	return shared


static func _set_shared_role_levels(owner, shared_levels: Dictionary) -> void:
	if owner == null:
		return
	if not owner.role_blessing_levels is Dictionary:
		owner.role_blessing_levels = {}
	for role_data in owner.roles:
		if role_data is not Dictionary:
			continue
		var role_id := str((role_data as Dictionary).get("id", ""))
		if role_id == "":
			continue
		owner.role_blessing_levels[role_id] = shared_levels.duplicate(true)


static func _get_skill_levels(owner) -> Dictionary:
	if owner == null:
		return {}
	if not owner.skill_blessing_levels is Dictionary:
		owner.skill_blessing_levels = {}
	return owner.skill_blessing_levels


static func _normalize_binding_levels(value: Variant) -> Dictionary:
	var result := {}
	if value is not Dictionary:
		return result
	for blessing_id_value in (value as Dictionary).keys():
		var blessing_id := str(blessing_id_value)
		var raw_levels: Variant = (value as Dictionary).get(blessing_id_value, {})
		var levels := {}
		if raw_levels is Dictionary:
			for tier_value in (raw_levels as Dictionary).keys():
				var tier := int(tier_value)
				if tier < 1 or tier > 2:
					continue
				var amount: int = clamp(int((raw_levels as Dictionary).get(tier_value, 0)), 0, MAX_LEVEL_PER_TIER)
				if amount > 0:
					levels[tier] = amount
		if not levels.is_empty():
			result[blessing_id] = levels
	return result


static func _can_compose_from_levels(levels: Dictionary, blessing_id: String) -> bool:
	if not DEFINITIONS.has(blessing_id):
		return false
	var blessing_levels: Dictionary = levels.get(blessing_id, {})
	return int(blessing_levels.get(1, 0)) >= MAX_LEVEL_PER_TIER and int(blessing_levels.get(2, 0)) <= 0


static func _format_value(definition: Dictionary, tier: int) -> String:
	var stat := str(definition.get("stat", ""))
	var value := float((definition.get("tier_values", {}) as Dictionary).get(tier, 0.0))
	match stat:
		"max_health":
			return "+%.0f 血量" % value
		"cooldown_reduction":
			return "-%.1f%% 技能 CD" % (value * 100.0)
		"skill_range":
			return "+%.1f%% 技能范围" % (value * 100.0)
		"energy_gain":
			return "+%.1f%% 大招能量回复" % (value * 100.0)
		"lifesteal":
			return "+%.1f%% 吸血" % (value * 100.0)
		"move_speed":
			return "+%.0f 移速" % value
		"damage":
			return "+%.1f%% 造成伤害" % (value * 100.0)
		"dodge":
			return "+%.1f%% 闪避" % (value * 100.0)
		"damage_reduction":
			return "+%.1f%% 减伤" % (value * 100.0)
		"combo_skill_extra":
			return "+1 连段，效果为 %.0f%%" % (value * 100.0)
		"duration_skill_duration":
			return "+%.1f%% 持续性技能持续时间" % (value * 100.0)
		"quantity_skill_count":
			return "+1 数量技能，效果为 %.0f%%" % (value * 100.0)
	return str(value)


static func _tier_label(tier: int) -> String:
	return "II" if tier >= 2 else "I"
