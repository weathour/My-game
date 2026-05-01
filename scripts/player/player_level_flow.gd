extends RefCounted

const BUILD_SYSTEM := preload("res://scripts/build/build_system.gd")
const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const PLAYER_ATTRIBUTE_FLOW := preload("res://scripts/player/player_attribute_flow.gd")
const PLAYER_EQUIPMENT_FLOW := preload("res://scripts/player/player_equipment_flow.gd")
const PLAYER_LEVEL_OPTIONS := preload("res://scripts/player/player_level_options.gd")
const PLAYER_UPGRADE_OPTIONS := preload("res://scripts/player/player_upgrade_options.gd")


static func get_attribute_upgrade_options(owner) -> Array:
	owner._sync_swordsman_trait_health_bonus()
	var max_attribute_level: float = owner._get_max_attribute_level()
	var swordsman_next_level: float = min(max_attribute_level, owner._get_attribute_level("swordsman_trait") + 1.0)
	var gunner_next_level: float = min(max_attribute_level, owner._get_attribute_level("gunner_trait") + 1.0)
	var mage_next_level: float = min(max_attribute_level, owner._get_attribute_level("mage_trait") + 1.0)
	return PLAYER_LEVEL_OPTIONS.build_attribute_upgrade_options(
		swordsman_next_level,
		gunner_next_level,
		mage_next_level,
		owner._get_role_attribute_description("swordsman", "swordsman_trait", swordsman_next_level),
		owner._get_role_attribute_description("gunner", "gunner_trait", gunner_next_level),
		owner._get_role_attribute_description("mage", "mage_trait", mage_next_level),
		owner._get_balanced_attribute_description(PLAYER_ATTRIBUTE_FLOW.COMMON_PROSPERITY_TRAIT_GAIN),
		owner._is_attribute_evolved(swordsman_next_level),
		owner._is_attribute_evolved(gunner_next_level),
		owner._is_attribute_evolved(mage_next_level),
		false,
		owner._get_attribute_evolved_title_color()
	)


static func get_small_boss_reward_options(owner) -> Array:
	var active_role_id: String = str(owner._get_active_role().get("id", ""))
	var options: Array = PLAYER_EQUIPMENT_FLOW.get_active_reward_options(owner)
	options.append_array(BUILD_SYSTEM.get_small_boss_reward_options(owner.card_pick_levels, owner.special_reward_levels, active_role_id))
	return options


static func apply_attribute_upgrade(owner, option_id: String) -> void:
	match option_id:
		"level_trait_swordsman":
			owner._add_attribute_levels({"swordsman_trait": 1.0})
		"level_trait_gunner":
			owner._add_attribute_levels({"gunner_trait": 1.0})
		"level_trait_mage":
			owner._add_attribute_levels({"mage_trait": 1.0})
		"level_trait_team":
			owner._add_common_prosperity()
		_:
			return

	owner._update_fire_timer()
	owner.stats_changed.emit(owner.get_stat_summary())
	owner.health_changed.emit(owner.current_health, owner.max_health)


static func get_final_core_options() -> Array:
	return PLAYER_LEVEL_OPTIONS.get_final_core_options()


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
	if DEVELOPER_MODE.should_offer_all_build_cards() and owner.has_method("get_all_upgrade_options"):
		return owner.get_all_upgrade_options()

	var pick_count: int = 4 if owner._has_elite_relic("elite_fate_shift") else 3
	return PLAYER_UPGRADE_OPTIONS.build_upgrade_options(
		get_dangzhen_upgrade_pool(owner),
		[],
		[],
		pick_count,
		owner._uses_blank_upgrade_fallback(),
		make_endless_blank_upgrade_option(owner)
	)


static func get_dangzhen_upgrade_pool(owner) -> Array:
	var active_role_id: String = str(owner._get_active_role().get("id", ""))
	return BUILD_SYSTEM.get_upgrade_pool("body", owner.card_pick_levels, owner.special_reward_levels, active_role_id)


static func make_endless_blank_upgrade_option(owner) -> Dictionary:
	return PLAYER_UPGRADE_OPTIONS.make_endless_blank_upgrade_option(owner._get_upgrade_slot_label("body"))
