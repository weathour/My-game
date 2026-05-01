extends RefCounted

const BUILD_DATABASE := preload("res://scripts/build/build_database.gd")
const BUILD_SYSTEM := preload("res://scripts/build/build_system.gd")
const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")

static func get_boss_options() -> Array:
	return ENEMY_ARCHETYPE_DATABASE.get_boss_options()

static func get_dangzhen_build_options(card_levels: Dictionary, active_role_id: String = "") -> Array:
	var options: Array = []
	var card_ids: Array = []
	card_ids.append_array(BUILD_SYSTEM.DANGZHEN_CORE_IDS)
	for theme_id in BUILD_DATABASE.get_branch_theme_ids():
		card_ids.append_array(BUILD_DATABASE.get_theme_card_ids(str(theme_id)))
	for card_id in card_ids:
		var config := BUILD_DATABASE.get_role_card_config(card_id, active_role_id) if active_role_id != "" else BUILD_DATABASE.get_core_card(card_id)
		options.append(_make_card_option(
			card_id,
			str(config.get("title", card_id)),
			str(config.get("detail", "")),
			BUILD_SYSTEM.get_card_level(card_levels, card_id),
			int(config.get("max_level", 3)),
			BUILD_SYSTEM.is_card_offerable(card_levels, card_id)
		))
	return options

static func get_special_card_options(reward_levels: Dictionary) -> Array:
	var options: Array = []
	for reward_id in BUILD_SYSTEM.DANGZHEN_EVOLUTION_IDS:
		var reward := BUILD_DATABASE.get_small_boss_reward(reward_id)
		var current_level := BUILD_SYSTEM.get_reward_level(reward_levels, reward_id)
		options.append(_make_card_option(
			reward_id,
			str(reward.get("title", reward_id)),
			str(reward.get("description", "")),
			current_level,
			1,
			current_level <= 0
		))
	return options

static func _make_card_option(card_id: String, title: String, description: String, current_level: int, max_level: int, enabled: bool) -> Dictionary:
	return {
		"id": card_id,
		"title": title,
		"description": description,
		"current_level": current_level,
		"max_level": max_level,
		"enabled": enabled
	}
