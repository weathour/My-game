extends RefCounted

const BUILD_DATABASE := preload("res://scripts/build/build_database.gd")
const BUILD_SYSTEM := preload("res://scripts/build/build_system.gd")
const FIRST_BATCH_DB := preload("res://scripts/build/build_first_batch_database.gd")
const FIRST_BATCH_RUNTIME := preload("res://scripts/build/build_first_batch_runtime.gd")
const FIRST_BATCH_MODEL := preload("res://scripts/build/build_first_batch_model.gd")
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

static func get_first_batch_build_options(card_levels: Dictionary, team_level: int = 1) -> Array:
	var state := FIRST_BATCH_RUNTIME.make_state_from_card_levels(team_level, card_levels)
	var eligible := {}
	for card_id in FIRST_BATCH_MODEL.get_eligible_card_ids(state):
		eligible[str(card_id)] = true
	var options: Array = []
	for card_id_value in FIRST_BATCH_DB.get_offer_card_ids():
		var card_id := str(card_id_value)
		var card := FIRST_BATCH_DB.get_card_data(card_id)
		if card.is_empty():
			continue
		var current_level: int = FIRST_BATCH_MODEL.get_card_level(state, card_id)
		var max_level := int(card.get("max_level", 1))
		var enabled := bool(eligible.get(card_id, false))
		var description := str(card.get("summary", ""))
		var gate_text := "队伍Lv.%d" % int(card.get("team_level_min", 0))
		if not enabled:
			description = "%s\n解锁：%s；当前 Lv.%d/%d" % [description, gate_text, current_level, max_level]
		options.append(_make_card_option(
			card_id,
			str(card.get("title", card_id)),
			description,
			current_level,
			max_level,
			enabled
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
