extends RefCounted

const BUILD_SYSTEM := preload("res://scripts/build/build_system.gd")
const PLAYER_LEVEL_CURVE := preload("res://scripts/player/player_level_curve.gd")
const FIRST_BATCH_DB := preload("res://scripts/build/build_first_batch_database.gd")

const DANGZHEN_QICHAO_CARD := "battle_dangzhen_qichao"
const DANGZHEN_DIELANG_CARD := "battle_dangzhen_dielang"
const DANGZHEN_HUICHAO_CARD := "battle_dangzhen_huichao"

const SMALL_BOSS_QICHAO := "small_boss_dangzhen_qichao"
const SMALL_BOSS_DIELANG := "small_boss_dangzhen_dielang"
const SMALL_BOSS_HUICHAO := "small_boss_dangzhen_huichao"
const SMALL_BOSS_BLADE_STORM := "small_boss_dangzhen_blade_storm"
const SMALL_BOSS_INFINITE_RELOAD := "small_boss_dangzhen_infinite_reload"
const SMALL_BOSS_TIDAL_SURGE := "small_boss_dangzhen_tidal_surge"
const SMALL_BOSS_TRAINING_LEVEL_UP := "small_boss_training_level_up"
const BOSS_BUILD_SWORDSMAN := "boss_build_swordsman_blade_shadow"
const BOSS_BUILD_GUNNER := "boss_build_gunner_spotter_drone"
const BOSS_BUILD_MAGE := "boss_build_mage_guardian_puppet"
const BRANCH_OMNI_EDGE := "branch_omni_edge"
const BRANCH_BLOOD_SHIELD := "branch_blood_shield"
const BRANCH_TRI_FINALE := "branch_tri_finale"

const BLADE_STORM_LABEL := "\u5251\u5203\u98CE\u66B4"
const INFINITE_RELOAD_LABEL := "\u65E0\u9650\u88C5\u586B"
const TIDAL_SURGE_LABEL := "\u6CE2\u6D9B\u6D8C\u52A8"


static func is_noop_upgrade(option_id: String) -> bool:
	return option_id == "final_blank_upgrade" \
		or option_id == "endless_blank_upgrade" \
		or option_id.begins_with("small_boss_blank_")


static func apply_small_boss_reward(owner, option_id: String) -> bool:
	match option_id:
		SMALL_BOSS_QICHAO:
			_grant_dangzhen_core_level(owner, DANGZHEN_QICHAO_CARD)
		SMALL_BOSS_DIELANG:
			_grant_dangzhen_core_level(owner, DANGZHEN_DIELANG_CARD)
		SMALL_BOSS_HUICHAO:
			_grant_dangzhen_core_level(owner, DANGZHEN_HUICHAO_CARD)
		SMALL_BOSS_BLADE_STORM:
			_grant_swordsman_blade_storm(owner)
		SMALL_BOSS_INFINITE_RELOAD:
			_grant_gunner_infinite_reload(owner)
		SMALL_BOSS_TIDAL_SURGE:
			_grant_mage_tidal_surge(owner)
		BRANCH_OMNI_EDGE:
			_grant_theme_unlock(owner, BRANCH_OMNI_EDGE, BLADE_STORM_LABEL, Color(0.4, 0.96, 1.0, 1.0))
		BRANCH_BLOOD_SHIELD:
			_grant_theme_unlock(owner, BRANCH_BLOOD_SHIELD, INFINITE_RELOAD_LABEL, Color(1.0, 0.6, 0.34, 1.0))
		BRANCH_TRI_FINALE:
			_grant_theme_unlock(owner, BRANCH_TRI_FINALE, TIDAL_SURGE_LABEL, Color(0.62, 0.9, 1.0, 1.0))
		SMALL_BOSS_TRAINING_LEVEL_UP:
			_grant_training_level(owner)
		BOSS_BUILD_SWORDSMAN:
			_grant_boss_role_build(owner, "swd_blade_shadow", "swordsman", "剑影进阶", Color(0.42, 0.92, 1.0, 1.0))
		BOSS_BUILD_GUNNER:
			_grant_boss_role_build(owner, "gun_spotter_drone", "gunner", "无人机进阶", Color(1.0, 0.64, 0.28, 1.0))
		BOSS_BUILD_MAGE:
			_grant_boss_role_build(owner, "mag_guardian_puppet", "mage", "傀儡进阶", Color(0.68, 0.9, 1.0, 1.0))
		_:
			return false
	return true


static func _grant_dangzhen_core_level(owner, card_id: String) -> void:
	var before_theme_ids := BUILD_SYSTEM.get_unlocked_theme_ids(owner.card_pick_levels, owner.special_reward_levels)
	owner.card_pick_levels[card_id] = min(3, owner._get_card_level(card_id) + 1)
	owner._announce_completed_final_set("battle_dangzhen")
	_announce_new_theme_unlocks(owner, before_theme_ids)


static func _announce_new_theme_unlocks(owner, before_theme_ids: Array) -> void:
	var new_theme_ids := BUILD_SYSTEM.get_newly_unlocked_theme_ids(before_theme_ids, owner.card_pick_levels, owner.special_reward_levels)
	if new_theme_ids.is_empty():
		return
	var accent := Color(1.0, 0.92, 0.58, 1.0)
	if owner.has_method("_get_role_theme_color"):
		accent = owner._get_role_theme_color(str(owner._get_active_role().get("id", "swordsman")))
	for theme_id in new_theme_ids:
		var id := str(theme_id)
		owner.special_reward_levels[id] = max(1, int(owner.special_reward_levels.get(id, 0)))
		var theme_data: Dictionary = BUILD_SYSTEM.BUILD_DATABASE.get_theme_data(id)
		if owner.has_method("_show_switch_banner"):
			owner._show_switch_banner("THEME", str(theme_data.get("title", id)), accent)


static func _grant_swordsman_blade_storm(owner) -> void:
	owner._add_special_reward_level(SMALL_BOSS_BLADE_STORM, 1)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -62.0), BLADE_STORM_LABEL, Color(0.4, 0.96, 1.0, 1.0))
	owner._spawn_ring_effect(owner.global_position, 92.0, Color(0.4, 0.96, 1.0, 0.82), 10.0, 0.24)
	owner._spawn_burst_effect(owner.global_position, 104.0, Color(0.2, 0.76, 1.0, 0.18), 0.22)
	var ability = owner.get("swordsman_blade_storm_ability")
	if ability != null and ability.can_trigger(owner, str(owner._get_active_role().get("id", ""))):
		owner._start_swordsman_blade_storm()


static func _grant_gunner_infinite_reload(owner) -> void:
	owner._add_special_reward_level(SMALL_BOSS_INFINITE_RELOAD, 1)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -62.0), INFINITE_RELOAD_LABEL, Color(1.0, 0.6, 0.34, 1.0))
	owner._spawn_ring_effect(owner.global_position, 96.0, Color(1.0, 0.56, 0.28, 0.78), 10.0, 0.24)
	owner._spawn_burst_effect(owner.global_position, 108.0, Color(1.0, 0.48, 0.2, 0.18), 0.22)
	var ability = owner.get("gunner_infinite_reload_ability")
	if ability != null and ability.can_trigger(owner, str(owner._get_active_role().get("id", ""))):
		owner._start_gunner_infinite_reload()


static func _grant_mage_tidal_surge(owner) -> void:
	owner._add_special_reward_level(SMALL_BOSS_TIDAL_SURGE, 1)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -62.0), TIDAL_SURGE_LABEL, Color(0.62, 0.9, 1.0, 1.0))
	owner._spawn_ring_effect(owner.global_position, 104.0, Color(0.56, 0.86, 1.0, 0.78), 10.0, 0.24)
	owner._spawn_burst_effect(owner.global_position, 116.0, Color(0.46, 0.78, 1.0, 0.18), 0.24)
	var ability = owner.get("mage_tidal_surge_ability")
	if ability != null and ability.can_trigger(owner, str(owner._get_active_role().get("id", ""))):
		owner._start_mage_tidal_surge()


static func _grant_theme_unlock(owner, theme_id: String, fallback_label: String, color: Color) -> void:
	owner._add_special_reward_level(theme_id, 1)
	var theme_data: Dictionary = BUILD_SYSTEM.BUILD_DATABASE.get_theme_data(theme_id)
	var label := str(theme_data.get("title", fallback_label))
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -62.0), label, color)
	owner._spawn_ring_effect(owner.global_position, 96.0, Color(color.r, color.g, color.b, 0.78), 10.0, 0.24)
	owner._spawn_burst_effect(owner.global_position, 108.0, Color(color.r, color.g, color.b, 0.18), 0.22)


static func _grant_boss_role_build(owner, card_id: String, role_id: String, label: String, color: Color) -> void:
	var card := FIRST_BATCH_DB.get_card_data(card_id)
	var max_level := int(card.get("max_level", 3))
	var previous := int(owner.card_pick_levels.get(card_id, 0))
	if previous < max_level:
		owner.card_pick_levels[card_id] = min(max_level, previous + 1)
		_apply_boss_role_specials(owner, card_id, role_id, false)
	else:
		_apply_boss_role_specials(owner, card_id, role_id, true)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -62.0), label, color)
	owner._spawn_ring_effect(owner.global_position, 92.0, Color(color.r, color.g, color.b, 0.52), 9.0, 0.22)
	owner._spawn_burst_effect(owner.global_position, 102.0, Color(color.r, color.g, color.b, 0.18), 0.22)
	if role_id == str(owner._get_active_role().get("id", "")):
		_trigger_boss_role_build_preview(owner, card_id)


static func _apply_boss_role_specials(owner, card_id: String, role_id: String, overflow: bool) -> void:
	var role_data: Dictionary = owner.role_upgrade_levels.get(role_id, {}).duplicate(true)
	role_data["damage_bonus"] = float(role_data.get("damage_bonus", 0.0)) + (2.0 if overflow else 1.2)
	role_data["interval_bonus"] = float(role_data.get("interval_bonus", 0.0)) + (0.026 if overflow else 0.014)
	role_data["range_bonus"] = float(role_data.get("range_bonus", 0.0)) + (6.0 if overflow else 3.0)
	role_data["skill_bonus"] = float(role_data.get("skill_bonus", 0.0)) + (0.12 if overflow else 0.07)
	owner.role_upgrade_levels[role_id] = role_data
	match card_id:
		"swd_blade_shadow":
			owner._increase_role_special("swordsman", "counter_level", 2 if overflow else 1)
			owner._increase_role_special("swordsman", "stance_level", 1)
		"gun_spotter_drone":
			owner._increase_role_special("gunner", "support_level", 2 if overflow else 1)
			owner._increase_role_special("gunner", "lock_level", 1)
		"mag_guardian_puppet":
			owner._increase_role_special("mage", "support_level", 2 if overflow else 1)
			owner._increase_role_special("mage", "frost_level", 1)
			if overflow:
				owner.damage_taken_multiplier = max(0.55, owner.damage_taken_multiplier - 0.012)
	owner.background_interval_multiplier = max(0.42, owner.background_interval_multiplier - (0.018 if overflow else 0.01))
	owner._add_active_role_mana(5.0 if overflow else 3.0, false)
	if owner.has_signal("health_changed"):
		owner.health_changed.emit(owner.current_health, owner.max_health)
	if owner.has_signal("stats_changed"):
		owner.stats_changed.emit(owner.get_stat_summary() if owner.has_method("get_stat_summary") else {})


static func _trigger_boss_role_build_preview(owner, card_id: String) -> void:
	match card_id:
		"swd_blade_shadow":
			var ability = owner.get("swordsman_blade_shadow_ability")
			if ability != null:
				ability.cooldown_remaining = 0.0
				owner._start_swordsman_blade_shadow()
		"gun_spotter_drone":
			var ability = owner.get("gunner_spotter_drone_ability")
			if ability != null:
				ability.cooldown_remaining = 0.0
				owner._start_gunner_spotter_drone()
		"mag_guardian_puppet":
			var ability = owner.get("mage_guardian_puppet_ability")
			if ability != null:
				ability.cooldown_remaining = 0.0
				owner._start_mage_guardian_puppet()


static func _grant_training_level(owner) -> void:
	owner.level += 1
	owner.experience_to_next_level = PLAYER_LEVEL_CURVE.get_next_required_experience_after_level_up(owner.level)
	owner.pending_level_ups += 1
	owner.experience_changed.emit(owner.experience, owner.experience_to_next_level, owner.level)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -62.0), "\u6f5c\u5fc3\u4fee\u70bc Lv.+1", Color(0.66, 1.0, 0.58, 1.0))
	owner._spawn_ring_effect(owner.global_position, 88.0, Color(0.58, 1.0, 0.48, 0.45), 8.0, 0.22)
