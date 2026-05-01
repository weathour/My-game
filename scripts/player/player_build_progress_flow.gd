extends RefCounted

const BUILD_SYSTEM := preload("res://scripts/build/build_system.gd")
const PLAYER_BUILD_STATE := preload("res://scripts/player/player_build_state.gd")


static func get_role_theme_color(owner, role_id: String) -> Color:
	for role_data in owner.roles:
		if str(role_data.get("id", "")) == role_id:
			return role_data.get("color", Color.WHITE)
	return Color.WHITE


static func announce_completed_final_set(owner, set_key: String) -> void:
	var final_set: Dictionary = BUILD_SYSTEM.get_final_set_data(set_key)
	if set_key == "" or final_set.is_empty() or owner.final_set_unlock_announced.has(set_key):
		return
	if not PLAYER_BUILD_STATE.is_final_set_complete(owner.card_pick_levels, final_set):
		return
	owner.final_set_unlock_announced[set_key] = true
	var accent: Color = get_role_theme_color(owner, str(owner._get_active_role().get("id", "swordsman")))
	owner._show_switch_banner("SET", str(final_set.get("full_title", "")), accent)


static func record_card_pick(owner, slot_id: String, option_id: String) -> void:
	var before_theme_ids := BUILD_SYSTEM.get_unlocked_theme_ids(owner.card_pick_levels, owner.special_reward_levels)
	var stored_card_id := BUILD_SYSTEM.get_shared_card_id(option_id)
	var active_role_id := str(owner._get_active_role().get("id", ""))
	var config: Dictionary = BUILD_SYSTEM.get_core_card_config(stored_card_id, active_role_id)
	var max_level := int(config.get("max_level", 999))
	owner.card_pick_levels[stored_card_id] = min(max_level, owner._get_card_level(stored_card_id) + 1)
	record_build_pick(owner, slot_id)
	if not config.is_empty():
		announce_completed_final_set(owner, str(config.get("set_key", "")))
	announce_newly_unlocked_themes(owner, before_theme_ids)


static func announce_newly_unlocked_themes(owner, before_theme_ids: Array) -> void:
	var unlocked_theme_ids := BUILD_SYSTEM.get_newly_unlocked_theme_ids(before_theme_ids, owner.card_pick_levels, owner.special_reward_levels)
	if unlocked_theme_ids.is_empty():
		return
	var accent: Color = get_role_theme_color(owner, str(owner._get_active_role().get("id", "swordsman")))
	for theme_id in unlocked_theme_ids:
		var id := str(theme_id)
		owner.special_reward_levels[id] = max(1, int(owner.special_reward_levels.get(id, 0)))
		var theme_data := BUILD_SYSTEM.BUILD_DATABASE.get_theme_data(id)
		owner._show_switch_banner("THEME", str(theme_data.get("title", id)), accent)


static func record_build_pick(owner, slot_id: String) -> void:
	owner.build_slot_levels[slot_id] = int(owner.build_slot_levels.get(slot_id, 0)) + 1
	owner._check_slot_resonance_unlocks()
