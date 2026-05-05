extends RefCounted

const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")
const PLAYER_ATTRIBUTE_FLOW := preload("res://scripts/player/player_attribute_flow.gd")
const PLAYER_EQUIPMENT_FLOW := preload("res://scripts/player/player_equipment_flow.gd")
const PLAYER_LEVEL_OPTIONS := preload("res://scripts/player/player_level_options.gd")
const PLAYER_REWARD_APPLIER := preload("res://scripts/player/player_reward_applier.gd")


static func get_attribute_upgrade_options(owner) -> Array:
	owner._sync_swordsman_trait_health_bonus()
	var trait_options: Array = []
	for definition in PLAYER_ATTRIBUTE_FLOW.get_trait_definitions_for_owner(owner):
		if definition is not Dictionary:
			continue
		var trait_key := str((definition as Dictionary).get("trait_key", ""))
		if trait_key == "":
			continue
		var role_id := str((definition as Dictionary).get("role_id", ""))
		var next_level: float = owner._get_attribute_level(trait_key) + 1.0
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
	var options: Array = PLAYER_EQUIPMENT_FLOW.get_active_reward_options(owner)
	options.append_array(get_boss_skill_reward_options(owner))
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


static func get_boss_skill_reward_options(owner) -> Array:
	return [_make_choose_blessing_option()]


static func _make_training_level_up_option() -> Dictionary:
	return {
		"id": PLAYER_REWARD_APPLIER.SMALL_BOSS_TRAINING_LEVEL_UP,
		"slot": "card",
		"slot_label": "技能奖励",
		"title": "潜心修炼",
		"description": "角色等级 +1，并立刻触发一次对应的升级祝福选择。",
		"preview_description": "角色等级 +1，并进入升级选择。",
		"exact_description": "作为技能奖励池暂未开放时的兜底奖励，选择后角色等级提升 1 级，并弹出本次升级的祝福选择。"
	}


static func _make_choose_blessing_option() -> Dictionary:
	return {
		"id": PLAYER_REWARD_APPLIER.SMALL_BOSS_CHOOSE_BLESSING,
		"slot": "card",
		"slot_label": "技能奖励",
		"title": "自选祝福",
		"description": "不提升角色等级，改为从所有当前可用祝福里自选 2 个。",
		"preview_description": "从所有当前可用祝福里自选 2 个。",
		"exact_description": "作为技能奖励池暂未开放时的兜底奖励，选择后不会获得等级 +1，而是连续进行 2 次全祝福自选。"
	}


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
	owner.level_up_requested.emit(build_blessing_upgrade_options(owner))


static func build_blessing_upgrade_options(owner) -> Array:
	var offer := PLAYER_BLESSING_SYSTEM.build_offer_for_owner(owner)
	owner.current_blessing_offer = offer
	return offer.get("options", [])


static func build_all_blessing_options(owner) -> Array:
	var offer := PLAYER_BLESSING_SYSTEM.build_all_offer_for_owner(owner)
	owner.current_blessing_offer = offer
	return offer.get("options", [])


static func refresh_upgrade_options(owner) -> Array:
	var current_offer: Dictionary = owner.current_blessing_offer if owner.current_blessing_offer is Dictionary else {}
	if current_offer.is_empty():
		return build_blessing_upgrade_options(owner)
	var offer := PLAYER_BLESSING_SYSTEM.refresh_offer_for_owner(owner, current_offer)
	owner.current_blessing_offer = offer
	return offer.get("options", [])


static func make_endless_blank_upgrade_option(owner) -> Dictionary:
	var slot_label: String = owner._get_upgrade_slot_label("body")
	return {
		"id": "endless_blank_upgrade",
		"slot": "body",
		"slot_label": slot_label,
		"title": "继续战斗",
		"description": "当前没有可选升级，点击继续。",
		"preview_description": "不获得额外升级，直接继续。",
		"exact_description": "这是继续选项，不提供额外战斗加成。"
	}
