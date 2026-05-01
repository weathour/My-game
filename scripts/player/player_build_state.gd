extends RefCounted

const BUILD_SYSTEM := preload("res://scripts/build/build_system.gd")

const SWORDSMAN_BLADE_STORM_REWARD := "small_boss_dangzhen_blade_storm"
const GUNNER_INFINITE_RELOAD_REWARD := "small_boss_dangzhen_infinite_reload"
const MAGE_TIDAL_SURGE_REWARD := "small_boss_dangzhen_tidal_surge"
const OMNI_EDGE_THEME_REWARD := "branch_omni_edge"
const BLOOD_SHIELD_THEME_REWARD := "branch_blood_shield"
const TRI_FINALE_THEME_REWARD := "branch_tri_finale"

static func get_card_level(card_levels: Dictionary, card_id: String) -> int:
	return BUILD_SYSTEM.get_card_level(card_levels, card_id)

static func get_special_reward_level(reward_levels: Dictionary, reward_id: String) -> int:
	return BUILD_SYSTEM.get_reward_level(reward_levels, reward_id)

static func add_special_reward_level(reward_levels: Dictionary, reward_id: String, amount: int = 1) -> int:
	var shared_reward_ids := BUILD_SYSTEM.get_shared_reward_ids(reward_id)
	var next_level: int = get_special_reward_level(reward_levels, reward_id) + max(0, amount)
	if shared_reward_ids.size() > 1:
		next_level = min(next_level, 1)
	for shared_reward_id in shared_reward_ids:
		reward_levels[str(shared_reward_id)] = next_level
	return next_level

static func has_reward(reward_levels: Dictionary, reward_id: String) -> bool:
	return get_special_reward_level(reward_levels, reward_id) > 0

static func has_unlocked_flag(unlocked_flags: Dictionary, flag_id: String) -> bool:
	return bool(unlocked_flags.get(flag_id, false))

static func has_swordsman_blade_storm_reward(reward_levels: Dictionary) -> bool:
	return has_reward(reward_levels, SWORDSMAN_BLADE_STORM_REWARD) or has_reward(reward_levels, OMNI_EDGE_THEME_REWARD)

static func has_gunner_infinite_reload_reward(reward_levels: Dictionary) -> bool:
	return has_reward(reward_levels, GUNNER_INFINITE_RELOAD_REWARD) or has_reward(reward_levels, BLOOD_SHIELD_THEME_REWARD)

static func has_mage_tidal_surge_reward(reward_levels: Dictionary) -> bool:
	return has_reward(reward_levels, MAGE_TIDAL_SURGE_REWARD) or has_reward(reward_levels, TRI_FINALE_THEME_REWARD)

static func can_offer_swordsman_blade_storm_reward(card_levels: Dictionary, reward_levels: Dictionary, final_set_data: Dictionary) -> bool:
	return BUILD_SYSTEM.is_theme_unlocked(card_levels, reward_levels, OMNI_EDGE_THEME_REWARD) and not has_swordsman_blade_storm_reward(reward_levels)

static func can_offer_gunner_infinite_reload_reward(card_levels: Dictionary, reward_levels: Dictionary, final_set_data: Dictionary) -> bool:
	return BUILD_SYSTEM.is_theme_unlocked(card_levels, reward_levels, BLOOD_SHIELD_THEME_REWARD) and not has_gunner_infinite_reload_reward(reward_levels)

static func can_offer_mage_tidal_surge_reward(card_levels: Dictionary, reward_levels: Dictionary, final_set_data: Dictionary) -> bool:
	return BUILD_SYSTEM.is_theme_unlocked(card_levels, reward_levels, TRI_FINALE_THEME_REWARD) and not has_mage_tidal_surge_reward(reward_levels)

static func is_final_set_complete(card_levels: Dictionary, final_set_data: Dictionary) -> bool:
	if final_set_data.is_empty():
		return false
	for requirement in final_set_data.get("requirements", []):
		if not (requirement is Dictionary):
			continue
		var card_id := str(requirement.get("card_id", ""))
		var max_level := int(requirement.get("max_level", 0))
		if card_id == "" or get_card_level(card_levels, card_id) < max_level:
			return false
	return true
