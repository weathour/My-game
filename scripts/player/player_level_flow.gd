extends RefCounted

const BUILD_SYSTEM := preload("res://scripts/build/build_system.gd")
const FIRST_BATCH_RUNTIME := preload("res://scripts/build/build_first_batch_runtime.gd")
const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")
const PLAYER_ATTRIBUTE_FLOW := preload("res://scripts/player/player_attribute_flow.gd")
const PLAYER_EQUIPMENT_FLOW := preload("res://scripts/player/player_equipment_flow.gd")
const PLAYER_LEVEL_OPTIONS := preload("res://scripts/player/player_level_options.gd")
const PLAYER_UPGRADE_OPTIONS := preload("res://scripts/player/player_upgrade_options.gd")


static func get_attribute_upgrade_options(owner) -> Array:
	owner._sync_swordsman_trait_health_bonus()
	var max_attribute_level: float = owner._get_max_attribute_level()
	var trait_options: Array = []
	for definition in PLAYER_ATTRIBUTE_FLOW.get_trait_definitions_for_owner(owner):
		if definition is not Dictionary:
			continue
		var trait_key := str((definition as Dictionary).get("trait_key", ""))
		if trait_key == "":
			continue
		var role_id := str((definition as Dictionary).get("role_id", ""))
		var next_level: float = min(max_attribute_level, owner._get_attribute_level(trait_key) + 1.0)
		trait_options.append({
			"role_id": role_id,
			"trait_key": trait_key,
			"trait_option_id": str((definition as Dictionary).get("trait_option_id", "level_trait_%s" % trait_key)),
			"trait_name": str((definition as Dictionary).get("trait_name", trait_key)),
			"next_level": next_level,
			"description": owner._get_role_attribute_description(role_id, trait_key, next_level),
			"evolved": owner._is_attribute_evolved(next_level)
		})
	return PLAYER_LEVEL_OPTIONS.build_trait_upgrade_options(
		trait_options,
		owner._get_balanced_attribute_description(PLAYER_ATTRIBUTE_FLOW.COMMON_PROSPERITY_TRAIT_GAIN),
		false,
		owner._get_attribute_evolved_title_color()
	)


static func get_small_boss_reward_options(owner) -> Array:
	var active_role_id: String = str(owner._get_active_role().get("id", ""))
	var options: Array = PLAYER_EQUIPMENT_FLOW.get_active_reward_options(owner)
	options.append_array(BUILD_SYSTEM.get_small_boss_reward_options(owner.card_pick_levels, owner.special_reward_levels, active_role_id))
	return options


static func apply_attribute_upgrade(owner, option_id: String) -> void:
	if option_id == "level_trait_team":
		owner._add_common_prosperity()
	elif option_id.begins_with("level_trait_"):
		var trait_key := ""
		for definition in PLAYER_ATTRIBUTE_FLOW.get_trait_definitions_for_owner(owner):
			if definition is Dictionary and str((definition as Dictionary).get("trait_option_id", "")) == option_id:
				trait_key = str((definition as Dictionary).get("trait_key", ""))
				break
		if trait_key == "":
			trait_key = option_id.trim_prefix("level_trait_")
			if not PLAYER_ATTRIBUTE_FLOW.get_trait_keys_for_owner(owner).has(trait_key):
				return
		owner._add_attribute_levels({trait_key: 1.0})
	else:
		return

	owner._update_fire_timer()
	owner.stats_changed.emit(owner.get_stat_summary())
	owner.health_changed.emit(owner.current_health, owner.max_health)


static func get_final_core_options() -> Array:
	return PLAYER_LEVEL_OPTIONS.get_final_core_options()


static func get_boss_build_reward_options(owner) -> Array:
	var active_role_id: String = str(owner._get_active_role().get("id", ""))
	return BUILD_SYSTEM.get_boss_build_reward_options(owner.card_pick_levels, owner.special_reward_levels, active_role_id)


static func resume_pending_level_ups(owner) -> void:
	try_request_level_up(owner)


static func delay_level_up_requests(owner, duration: float) -> void:
	if duration <= 0.0:
		return
	owner.level_up_delay_remaining = max(owner.level_up_delay_remaining, duration)


static func try_request_level_up(owner) -> void:
	if owner.is_dead or owner.level_up_active or owner.pending_level_ups <= 0 or owner.level_up_delay_remaining > 0.0:
		return

	owner.pending_level_ups -= 1
	owner.level_up_active = true
	owner.level_up_requested.emit(build_upgrade_options(owner))


static func build_upgrade_options(owner) -> Array:
	var offer := PLAYER_BLESSING_SYSTEM.build_offer_for_owner(owner)
	owner.current_build_offer = offer
	return offer.get("options", [])


static func refresh_upgrade_options(owner) -> Array:
	var current_offer: Dictionary = owner.current_build_offer if owner.current_build_offer is Dictionary else {}
	if current_offer.is_empty():
		return build_upgrade_options(owner)
	var offer := PLAYER_BLESSING_SYSTEM.refresh_offer_for_owner(owner, current_offer)
	owner.current_build_offer = offer
	return offer.get("options", [])


static func get_dangzhen_upgrade_pool(owner) -> Array:
	var active_role_id: String = str(owner._get_active_role().get("id", ""))
	return BUILD_SYSTEM.get_upgrade_pool("body", owner.card_pick_levels, owner.special_reward_levels, active_role_id, owner.roles)


static func make_endless_blank_upgrade_option(owner) -> Dictionary:
	return PLAYER_UPGRADE_OPTIONS.make_endless_blank_upgrade_option(owner._get_upgrade_slot_label("body"))
