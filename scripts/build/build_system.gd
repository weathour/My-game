extends RefCounted

const BUILD_DATABASE := preload("res://scripts/build/build_database.gd")

const DANGZHEN_CORE_IDS := [
	"battle_dangzhen_qichao",
	"battle_dangzhen_dielang",
	"battle_dangzhen_huichao"
]

const DANGZHEN_EVOLUTION_IDS := [
	"branch_omni_edge",
	"branch_blood_shield",
	"branch_tri_finale"
]

const DANGZHEN_REINFORCEMENT_IDS := [
	"small_boss_dangzhen_qichao",
	"small_boss_dangzhen_dielang",
	"small_boss_dangzhen_huichao"
]

const DANGZHEN_REINFORCEMENT_CARD_IDS := {
	"small_boss_dangzhen_qichao": "battle_dangzhen_qichao",
	"small_boss_dangzhen_dielang": "battle_dangzhen_dielang",
	"small_boss_dangzhen_huichao": "battle_dangzhen_huichao"
}

const LEGACY_DANGZHEN_EVOLUTION_IDS := [
	"small_boss_dangzhen_blade_storm",
	"small_boss_dangzhen_infinite_reload",
	"small_boss_dangzhen_tidal_surge"
]

const INITIAL_THEME_ID := "theme_threefold_tide"


static func get_shared_card_id(card_id: String) -> String:
	return BUILD_DATABASE.canonical_card_id(card_id)


static func get_shared_reward_ids(reward_id: String) -> Array:
	return [BUILD_DATABASE.canonical_reward_id(reward_id)]


static func get_card_level(card_levels: Dictionary, card_id: String) -> int:
	var canonical_card_id := get_shared_card_id(card_id)
	return int(card_levels.get(canonical_card_id, card_levels.get(card_id, 0)))


static func get_reward_level(reward_levels: Dictionary, reward_id: String) -> int:
	var canonical_reward_id := BUILD_DATABASE.canonical_reward_id(reward_id)
	return int(reward_levels.get(canonical_reward_id, reward_levels.get(reward_id, 0)))


static func get_slot_label(slot_id: String) -> String:
	return BUILD_DATABASE.get_slot_label(slot_id)


static func normalize_dangzhen_card_levels(card_levels: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for raw_card_id in card_levels.keys():
		var canonical_card_id := get_shared_card_id(str(raw_card_id))
		var config := BUILD_DATABASE.get_core_card(canonical_card_id)
		if config.is_empty():
			normalized[str(raw_card_id)] = int(card_levels.get(raw_card_id, 0))
			continue
		var max_level := int(config.get("max_level", 3))
		var raw_level := int(card_levels.get(raw_card_id, 0))
		normalized[canonical_card_id] = clamp(max(raw_level, int(normalized.get(canonical_card_id, 0))), 0, max_level)
	return normalized


static func normalize_dangzhen_reward_levels(reward_levels: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for raw_reward_id in reward_levels.keys():
		var canonical_reward_id := BUILD_DATABASE.canonical_reward_id(str(raw_reward_id))
		normalized[canonical_reward_id] = max(int(normalized.get(canonical_reward_id, 0)), int(reward_levels.get(raw_reward_id, 0)))
	return normalized


static func get_core_card_config(card_id: String, active_role_id: String = "") -> Dictionary:
	return BUILD_DATABASE.get_role_card_config(card_id, active_role_id)


static func get_card_type(card_id: String) -> String:
	return BUILD_DATABASE.get_card_type(card_id)


static func has_independent_skill_cooldown(card_id: String) -> bool:
	return BUILD_DATABASE.has_independent_skill_cooldown(card_id)


static func get_role_effect_payload(card_id: String) -> Array:
	return BUILD_DATABASE.get_role_effect_payload(card_id)


static func get_final_set_data(set_key: String) -> Dictionary:
	return BUILD_DATABASE.get_final_set_data(set_key)


static func is_card_offerable(card_levels: Dictionary, card_id: String) -> bool:
	var canonical_card_id := get_shared_card_id(card_id)
	var config := BUILD_DATABASE.get_core_card(canonical_card_id)
	if config.is_empty():
		return false
	for required_id in config.get("requires", []):
		if get_card_level(card_levels, str(required_id)) <= 0:
			return false
	return get_card_level(card_levels, canonical_card_id) < int(config.get("max_level", 3))


static func is_final_set_complete(card_levels: Dictionary, set_key: String) -> bool:
	var final_set := get_final_set_data(set_key)
	if final_set.is_empty():
		return false
	for requirement in final_set.get("requirements", []):
		if not (requirement is Dictionary):
			continue
		var card_id := str(requirement.get("card_id", ""))
		var max_level := int(requirement.get("max_level", 0))
		if card_id == "" or get_card_level(card_levels, card_id) < max_level:
			return false
	return true


static func get_unlocked_theme_ids(card_levels: Dictionary, reward_levels: Dictionary = {}) -> Array:
	var theme_ids: Array = [INITIAL_THEME_ID]
	for theme_id in BUILD_DATABASE.get_branch_theme_ids():
		var branch_id := str(theme_id)
		if is_theme_unlocked(card_levels, reward_levels, branch_id):
			theme_ids.append(branch_id)
	return theme_ids


static func get_newly_unlocked_theme_ids(before_theme_ids: Array, card_levels: Dictionary, reward_levels: Dictionary = {}) -> Array:
	var before := {}
	for theme_id in before_theme_ids:
		before[str(theme_id)] = true
	var result: Array = []
	for theme_id in get_unlocked_theme_ids(card_levels, reward_levels):
		var id := str(theme_id)
		if not before.has(id):
			result.append(id)
	return result


static func is_theme_unlocked(card_levels: Dictionary, reward_levels: Dictionary, theme_id: String) -> bool:
	if theme_id == INITIAL_THEME_ID:
		return true
	if get_reward_level(reward_levels, theme_id) > 0:
		return true
	return _is_theme_recipe_met(card_levels, theme_id)


static func _is_theme_recipe_met(card_levels: Dictionary, theme_id: String) -> bool:
	var recipes := BUILD_DATABASE.get_theme_unlock_recipes()
	var recipe: Dictionary = recipes.get(theme_id, {})
	if recipe.is_empty():
		return false
	for card_id in recipe.get("requirements", {}).keys():
		if get_card_level(card_levels, str(card_id)) < int(recipe.get("requirements", {}).get(card_id, 0)):
			return false
	return true


static func get_upgrade_pool(slot_id: String, card_levels: Dictionary, reward_levels: Dictionary = {}, active_role_id: String = "") -> Array:
	var options: Array = []
	var used_ids := {}
	for theme_id in get_unlocked_theme_ids(card_levels, reward_levels):
		for raw_card_id in BUILD_DATABASE.get_card_ids_for_theme_slot(str(theme_id), slot_id):
			var card_id := get_shared_card_id(str(raw_card_id))
			if used_ids.has(card_id):
				continue
			if is_card_offerable(card_levels, card_id):
				options.append(make_core_card_option(slot_id, card_id, card_levels, active_role_id))
				used_ids[card_id] = true
	return options


static func make_core_card_option(slot_id: String, card_id: String, card_levels: Dictionary, active_role_id: String = "") -> Dictionary:
	var canonical_card_id := get_shared_card_id(card_id)
	var config := BUILD_DATABASE.get_role_card_config(canonical_card_id, active_role_id)
	var next_level := get_card_level(card_levels, canonical_card_id) + 1
	var title := str(config.get("title", canonical_card_id))
	var description := _make_core_card_detail_description(config)
	var role_effect_description := _make_role_effect_description(config)
	if role_effect_description != "":
		description = "%s\n\n%s" % [description, role_effect_description]
	var preview := str(config.get("preview", description))
	var final_set := get_final_set_data(str(config.get("set_key", "")))
	var theme_id := str(config.get("theme_id", INITIAL_THEME_ID))
	var theme_data := BUILD_DATABASE.get_theme_data(theme_id)
	var display_title := "%s Lv.%d" % [title, next_level]
	if not theme_data.is_empty() and theme_id != INITIAL_THEME_ID:
		display_title = "%s｜%s" % [str(theme_data.get("title", "")), display_title]
	return {
		"id": canonical_card_id,
		"slot": slot_id,
		"slot_label": BUILD_DATABASE.get_slot_label(slot_id),
		"title": display_title,
		"card_title": title,
		"card_type": str(config.get("card_type", "passive_attack")),
		"card_type_label": str(config.get("card_type_label", "")),
		"is_new_passive_skill": bool(config.get("is_new_passive_skill", false)),
		"has_independent_cooldown": bool(config.get("has_independent_cooldown", false)),
		"role_effects": config.get("role_effects", []),
		"preview_description": preview,
		"description": description,
		"detail_description": description,
		"glossary_terms": [],
		"exact_description": description,
		"theme_id": theme_id,
		"theme_title": str(theme_data.get("title", "")),
		"final_card_name": str(final_set.get("main_name", "")),
		"final_card_title": str(final_set.get("full_title", "")),
		"final_card_requirements": _make_final_set_requirement_payload(final_set, card_levels),
		"max_level": int(config.get("max_level", 3))
	}


static func _make_core_card_detail_description(config: Dictionary) -> String:
	var detail_lines: Array = config.get("detail_lines", [])
	if detail_lines.is_empty():
		return str(config.get("detail", ""))
	var lines: Array[String] = [str(config.get("detail", ""))]
	for detail_line in detail_lines:
		lines.append("- " + str(detail_line))
	return "\n".join(lines)


static func _make_role_effect_description(config: Dictionary) -> String:
	var role_effects: Array = config.get("role_effects", [])
	if role_effects.is_empty():
		return ""
	var lines: Array[String] = ["【三英雄对应效果 / 数值】"]
	for effect in role_effects:
		if effect is not Dictionary:
			continue
		lines.append("%s｜%s" % [str(effect.get("role_name", "")), str(effect.get("title", ""))])
		for line in effect.get("lines", []):
			lines.append("  - " + str(line))
	return "\n".join(lines)


static func _make_final_set_requirement_payload(final_set: Dictionary, card_levels: Dictionary) -> Array:
	var requirement_payload: Array = []
	for requirement in final_set.get("requirements", []):
		if not (requirement is Dictionary):
			continue
		var card_id := str(requirement.get("card_id", ""))
		var max_level := int(requirement.get("max_level", 0))
		requirement_payload.append({
			"label": str(requirement.get("label", "")),
			"current_level": min(get_card_level(card_levels, card_id), max_level),
			"max_level": max_level
		})
	return requirement_payload


static func get_small_boss_reward_options(card_levels: Dictionary, reward_levels: Dictionary, active_role_id: String = "") -> Array:
	var options: Array = []
	for reward_id in DANGZHEN_REINFORCEMENT_IDS:
		if _is_reinforcement_reward_offerable(card_levels, str(reward_id)):
			options.append(_make_small_boss_reward_option(str(reward_id)))
	for branch_id in BUILD_DATABASE.get_branch_theme_ids():
		var theme_id := str(branch_id)
		if _is_theme_recipe_met(card_levels, theme_id) and get_reward_level(reward_levels, theme_id) <= 0:
			options.append(_make_small_boss_reward_option(theme_id))
	if options.is_empty():
		options.append(make_small_boss_training_reward_option())
	return options.slice(0, 3)


static func get_blank_small_boss_reward_options(count: int = 3) -> Array:
	var options: Array = []
	for index in range(max(0, count)):
		options.append(_make_small_boss_blank_reward_option(index + 1))
	return options


static func _is_reinforcement_reward_offerable(card_levels: Dictionary, reward_id: String) -> bool:
	var card_id := str(DANGZHEN_REINFORCEMENT_CARD_IDS.get(reward_id, ""))
	if card_id == "":
		return false
	return is_card_offerable(card_levels, card_id)


static func _make_small_boss_reward_option(reward_id: String) -> Dictionary:
	var reward := BUILD_DATABASE.get_small_boss_reward(reward_id)
	var description := str(reward.get("description", ""))
	return {
		"id": reward_id,
		"slot": "special",
		"slot_label": BUILD_DATABASE.get_slot_label("special"),
		"title": str(reward.get("title", reward_id)),
		"description": description,
		"preview_description": description,
		"exact_description": description
	}


static func _make_small_boss_blank_reward_option(index: int) -> Dictionary:
	return {
		"id": "small_boss_blank_%d" % index,
		"slot": "special",
		"slot_label": "Special Reward",
		"title": "Skip Reward",
		"description": "No special reward is currently available. Continue.",
		"preview_description": "Continue without an extra reward.",
		"exact_description": "This option gives no extra combat bonus."
	}


static func make_small_boss_training_reward_option() -> Dictionary:
	return {
		"id": "small_boss_training_level_up",
		"slot": "special",
		"slot_label": BUILD_DATABASE.get_slot_label("special"),
		"title": "\u6f5c\u5fc3\u4fee\u70bc",
		"description": "\u6240\u6709\u53ef\u9009\u5361\u724c\u5df2\u83b7\u5f97\u3002\u89d2\u8272\u7b49\u7ea7 +1\uff0c\u5e76\u7acb\u5373\u8fdb\u5165\u4e00\u6b21 Build \u5347\u7ea7\u9009\u62e9\u3002",
		"preview_description": "\u89d2\u8272\u7b49\u7ea7 +1\uff0c\u5e76\u89e6\u53d1 Build \u5347\u7ea7\u3002",
		"exact_description": "\u8fd9\u662f\u5c0f Boss \u5361\u724c\u6c60\u8017\u5c3d\u540e\u7684\u515c\u5e95\u5956\u52b1\uff1a\u63d0\u5347 1 \u7ea7\uff0c\u7136\u540e\u5f39\u51fa\u5bf9\u5e94\u7684 Build \u5347\u7ea7\u83dc\u5355\u3002"
	}
