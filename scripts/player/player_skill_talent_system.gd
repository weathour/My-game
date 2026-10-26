extends RefCounted

const LEGACY_SKILL_TALENT_CATALOG := preload("res://scripts/player/data/legacy_skill_talent_catalog.gd")

const ROLE_TALENT_CATALOG := preload("res://scripts/player/data/role_talent_catalog.gd")

const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")
const PLAYER_SKILL_LEVEL_SYSTEM := preload("res://scripts/player/player_skill_level_system.gd")

const OPTION_PREFIX := "skill_talent:"
const CATEGORY_SKILL_TALENT := "skill_talent"
const TALENTS_KEY := "skill_talents"
const LEVEL_TALENTS_KEY := "level_talents"
const LEVEL_TALENT_GROUP_LOCKS_KEY := "level_talent_group_locks"
const LEVEL_TALENT_ROLE_ORDER := ["swordsman", "gunner", "mage"]
const LEVEL_TALENT_ROLE_OPTION_PREFIX := "level_talent_role:"
const LEVEL_TALENT_ROLE_OPTION_COUNT := 3
const LEVEL_TALENT_ROLE_TITLES := ROLE_TALENT_CATALOG.LEVEL_TALENT_ROLE_TITLES

const LEVEL_TALENT_DEFINITIONS := ROLE_TALENT_CATALOG.LEVEL_TALENT_DEFINITIONS

const TRIGGER_LEVEL := 3
const TRIGGER_LEVELS := [3, 6, 9]
const TALENT_STAGE_COUNT := 3

const ROLE_PROGRESS_ORDER := PLAYER_SKILL_LEVEL_SYSTEM.ROLE_PROGRESS_ORDER

const PROGRESS_TITLES := PLAYER_SKILL_LEVEL_SYSTEM.PROGRESS_TITLES

const UNLOCKABLE_PROGRESS := PLAYER_SKILL_LEVEL_SYSTEM.UNLOCKABLE_PROGRESS

const LEVEL_TALENT_REQUIRED_SKILL_RULES := ROLE_TALENT_CATALOG.LEVEL_TALENT_REQUIRED_SKILL_RULES

const TALENT_DEFINITIONS := LEGACY_SKILL_TALENT_CATALOG.TALENT_DEFINITIONS

const TALENT_BUILD_PROJECTIONS := LEGACY_SKILL_TALENT_CATALOG.TALENT_BUILD_PROJECTIONS

const EVOLVED_BUILD_TEXT_OVERRIDES := LEGACY_SKILL_TALENT_CATALOG.EVOLVED_BUILD_TEXT_OVERRIDES

static func get_display(owner, role_id: String, progress_id: String) -> Dictionary:
	if PLAYER_SKILL_LEVEL_SYSTEM.is_custom_basic(progress_id):
		var build = PLAYER_SKILL_LEVEL_SYSTEM.basic_build(progress_id)
		return {"base_name": "普通攻击", "name": "普通攻击", "hud_name": "普攻", "role_id": role_id, "progress_id": progress_id, "description": build.description(owner), "upgrade_note": build.next_preview(owner), "stages": [], "talent_ids": [], "talent_title": "", "path": ""}
	# 旧108节点不参与当前展示；已保存的角色level_talents仍走独立读取链。
	var base_name := str(PROGRESS_TITLES.get(progress_id, progress_id))
	return {"base_name": base_name, "name": base_name, "hud_name": base_name.left(2), "role_id": role_id, "progress_id": progress_id, "description": "", "upgrade_note": "", "stages": [], "talent_ids": [], "talent_title": "", "path": ""}


static func get_display_for_skill_id(owner, skill_id: String) -> Dictionary:
	var progress_id := str(UNLOCKABLE_PROGRESS.find_key(skill_id))
	if skill_id.ends_with("_basic_attack"):
		progress_id = skill_id.trim_suffix("_attack")
	elif skill_id.ends_with("_ultimate"):
		progress_id = skill_id
	var role_id := PLAYER_BLESSING_SKILL_STATE.get_skill_role_id(skill_id)
	if not ROLE_PROGRESS_ORDER.get(role_id, []).has(progress_id):
		return {}
	return get_display(owner, role_id, progress_id)


static func get_talent_definition(progress_id: String, talent_id: String) -> Dictionary:
	if talent_id == "":
		return {}
	for definition_value in TALENT_DEFINITIONS.get(progress_id, []):
		if definition_value is Dictionary and str((definition_value as Dictionary).get("id", "")) == talent_id:
			return (definition_value as Dictionary).duplicate(true)
	return {}


static func project_skill_payload(owner, skill_id: String, payload: Dictionary, include_description: bool = true) -> Dictionary:
	var result := payload.duplicate(true)
	var display := get_display_for_skill_id(owner, skill_id)
	if PLAYER_SKILL_LEVEL_SYSTEM.is_custom_basic(str(display.get("progress_id", ""))):
		result["skill_progress_id"] = str(display.get("progress_id", ""))
		if include_description:
			result["description"] = str(display.get("description", ""))
		return result
	var talent_ids: Array = display.get("talent_ids", [])
	result["hud_name"] = str(display.get("hud_name", str(result.get("name", skill_id)).left(2)))
	if talent_ids.is_empty():
		return result
	result["name"] = str(display.get("name", result.get("name", skill_id)))
	result["evolved"] = true
	result["skill_progress_id"] = str(display.get("progress_id", ""))
	result["talent_id"] = str(display.get("talent_id", ""))
	result["talent_ids"] = talent_ids.duplicate()
	result["talent_path"] = str(display.get("path", "---"))
	result["talent_stages"] = (display.get("stages", []) as Array).duplicate(true)
	if include_description:
		var base_description := str(result.get("description", ""))
		var talent_description := str(display.get("description", ""))
		result["description"] = "%s\n\n当前质变：%s" % [base_description, talent_description] if base_description != "" else talent_description
	return result


static func project_build_option(owner, option: Dictionary) -> Dictionary:
	var result := option.duplicate(true)
	var role_id := str(result.get("role_id", ""))
	var progress_id := str(result.get("skill_progress_id", ""))
	if role_id == "" or progress_id == "":
		return result
	var display := get_display(owner, role_id, progress_id)
	var talent_ids: Array = display.get("talent_ids", [])
	if talent_ids.is_empty():
		return result
	var talent_title := str(display.get("talent_title", ""))
	var base_title := str(result.get("title", result.get("build_id", "")))
	var base_summary := str(result.get("summary", result.get("description", "")))
	var override: Dictionary = {}
	for selected_id in talent_ids:
		var override_key := "%s:%s" % [str(selected_id), str(result.get("build_id", ""))]
		if EVOLVED_BUILD_TEXT_OVERRIDES.has(override_key):
			override = EVOLVED_BUILD_TEXT_OVERRIDES[override_key]
	var title := str(override.get("title", "%s：%s" % [talent_title, base_title]))
	var build_id := str(result.get("build_id", ""))
	var projection_parts: Array[String] = []
	for selected_id in talent_ids:
		var talent_projection: Dictionary = TALENT_BUILD_PROJECTIONS.get(str(selected_id), {})
		var projection_text := str(talent_projection.get(build_id, ""))
		if projection_text != "":
			projection_parts.append("%s：%s" % [_get_talent_title(progress_id, str(selected_id)), projection_text])
	var summary := base_summary
	if not projection_parts.is_empty():
		summary = "%s；当前形态继承：%s" % [base_summary.trim_suffix("。"), "；".join(projection_parts)]
	result["title"] = title
	result["summary"] = summary
	result["short_description"] = summary
	result["description"] = summary
	result["preview_description"] = summary
	result["detail_description"] = summary
	result["exact_description"] = summary
	result["card_title"] = str(display.get("name", result.get("card_title", "")))
	result["hide_card_title"] = false
	result["evolved"] = true
	result["talent_id"] = str(display.get("talent_id", ""))
	result["talent_ids"] = talent_ids.duplicate()
	result["talent_path"] = str(display.get("path", "---"))
	return result


static func is_talent_option_id(option_id: String) -> bool:
	return option_id.begins_with(OPTION_PREFIX)


static func get_skill_progress_level(owner, role_id: String, progress_id: String) -> int:
	return PLAYER_SKILL_LEVEL_SYSTEM.get_skill_level(owner, role_id, progress_id)


static func get_pending_choices(owner) -> Array:
	var result: Array = []
	var pending_count := _get_pending_level_talent_count(owner)
	var acquired_count := _get_acquired_level_talent_count(owner)
	for index in range(pending_count):
		var pick_index := acquired_count + index + 1
		result.append({
			"level_talent_offer": true,
			"talent_stage": pick_index,
			"trigger_level": pick_index * TRIGGER_LEVEL
		})
	return result


static func build_choice_offer(owner, choice: Dictionary = {}) -> Dictionary:
	if not choice.is_empty():
		if bool(choice.get("level_talent_offer", false)):
			return _build_level_talent_offer(owner) if _get_pending_level_talent_count(owner) > 0 else {}
		return {}
	return build_next_offer(owner)


static func get_next_pending(owner) -> Dictionary:
	if _get_pending_level_talent_count(owner) > 0:
		var level_pending := get_pending_choices(owner)
		return level_pending[0] if not level_pending.is_empty() else {}
	return {}


static func has_pending(owner) -> bool:
	return _get_pending_level_talent_count(owner) > 0


static func build_next_offer(owner) -> Dictionary:
	if _get_pending_level_talent_count(owner) > 0:
		var preserved := _get_preserved_level_talent_offer(owner)
		if not preserved.is_empty():
			return preserved
		return _build_level_talent_offer(owner)
	return {}


static func _build_offer_for_choice(owner, pending: Dictionary) -> Dictionary:
	return {}


static func refresh_offer_card(owner, option_index: int, role_id: String = "") -> Array:
	if owner == null:
		return []
	var current_offer: Dictionary = owner.get("current_blessing_offer") if owner.get("current_blessing_offer") is Dictionary else {}
	var context: Dictionary = current_offer.get("context", {}) if current_offer.get("context", {}) is Dictionary else {}
	if not _is_level_talent_context(context):
		return _duplicate_option_array(current_offer.get("options", []))
	var options := _duplicate_option_array(current_offer.get("options", []))
	if _has_level_talent_role_entries(options):
		return _refresh_level_talent_role_card(owner, options, context, option_index, role_id)
	if option_index < 0 or option_index >= options.size():
		return options
	var old_option: Dictionary = options[option_index] if options[option_index] is Dictionary else {}
	var fallback_role_order := get_level_talent_role_order(owner)
	var target_role_id := str(old_option.get("role_id", fallback_role_order[clampi(option_index, 0, fallback_role_order.size() - 1)]))
	var old_talent_id := str(old_option.get("talent_id", old_option.get("level_talent_id", "")))
	var replacement := _make_level_talent_option(owner, target_role_id, option_index, [old_talent_id])
	if not replacement.is_empty():
		options[option_index] = replacement
	owner.set("current_blessing_offer", {"options": options, "context": context.duplicate(true)})
	return options


static func apply_option_with_result(owner, option_id: String, current_offer: Dictionary) -> Dictionary:
	if owner == null or not is_talent_option_id(option_id):
		return {}
	var context: Dictionary = current_offer.get("context", {}) if current_offer.get("context", {}) is Dictionary else {}
	var talent_id := option_id.trim_prefix(OPTION_PREFIX)
	if not _is_level_talent_context(context):
		return {}
	if _get_pending_level_talent_count(owner) <= 0:
		return {}
	var offered_option := _find_offered_level_talent_option(current_offer, option_id)
	if offered_option.is_empty():
		return {}
	var role_id := str(offered_option.get("role_id", ""))
	if not _is_valid_level_talent_id(role_id, talent_id):
		return {}
	var definition := _get_level_talent_definition_for_role(role_id, talent_id)
	if definition.is_empty() or not _is_level_talent_skill_requirement_met(owner, definition):
		return {}
	var states: Dictionary = owner.get("role_special_states") if owner.get("role_special_states") is Dictionary else {}
	var role_state: Dictionary = states.get(role_id, {}) if states.get(role_id, {}) is Dictionary else {}
	var level_talents := _normalize_level_talent_ids(role_id, role_state.get(LEVEL_TALENTS_KEY, []))
	if level_talents.has(talent_id) or _is_level_talent_group_locked(owner, role_id, definition):
		return {}
	level_talents.append(talent_id)
	role_state[LEVEL_TALENTS_KEY] = level_talents
	role_state[LEVEL_TALENT_GROUP_LOCKS_KEY] = _record_level_talent_group_lock(owner, role_id, role_state, definition, level_talents)
	states[role_id] = role_state
	owner.set("role_special_states", states)
	_set_pending_level_talent_count(owner, _get_pending_level_talent_count(owner) - 1)
	return {
		"type": CATEGORY_SKILL_TALENT,
		"level_talent_offer": true,
		"role_id": role_id,
		"talent_id": talent_id,
		"talent_stage": int(context.get("talent_stage", _get_acquired_level_talent_count(owner))),
		"trigger_level": int(context.get("trigger_level", 0))
	}


static func apply_choice(owner, option_id: String, expected_progress_id: String = "") -> bool:
	var offer: Dictionary = owner.get("current_blessing_offer") if owner != null and owner.get("current_blessing_offer") is Dictionary else {}
	var context: Dictionary = offer.get("context", {}) if offer.get("context", {}) is Dictionary else {}
	if expected_progress_id != "" and not _is_level_talent_context(context) and str(context.get("skill_progress_id", "")) != expected_progress_id:
		return false
	return not apply_option_with_result(owner, option_id, offer).is_empty()


static func get_selected_level_talents(owner, role_id: String) -> Array:
	if owner == null:
		return []
	var states: Variant = owner.get("role_special_states")
	if states is not Dictionary:
		return []
	var role_state: Variant = (states as Dictionary).get(role_id, {})
	if role_state is not Dictionary:
		return []
	return _normalize_level_talent_ids(role_id, (role_state as Dictionary).get(LEVEL_TALENTS_KEY, []))


static func has_level_talent(owner, talent_id: String) -> bool:
	if owner == null or talent_id == "":
		return false
	for role_id in get_level_talent_role_order(owner):
		if get_selected_level_talents(owner, str(role_id)).has(talent_id):
			return true
	return false


static func get_level_talent_role_order(owner) -> Array:
	var team_order: Array = []
	if owner != null and owner.get("roles") is Array:
		for role_variant in owner.get("roles"):
			if role_variant is not Dictionary:
				continue
			var role_id := str((role_variant as Dictionary).get("id", ""))
			if role_id != "" and LEVEL_TALENT_DEFINITIONS.has(role_id) and not team_order.has(role_id):
				team_order.append(role_id)
	if team_order.size() == LEVEL_TALENT_ROLE_OPTION_COUNT:
		return team_order
	return LEVEL_TALENT_ROLE_ORDER.duplicate()


static func _build_level_talent_offer(owner) -> Dictionary:
	var options: Array = []
	var role_order := get_level_talent_role_order(owner)
	for role_index in range(role_order.size()):
		var role_id := str(role_order[role_index])
		var option := _make_level_talent_role_option(owner, role_id, role_index)
		if not option.is_empty():
			options.append(option)
	if options.size() != role_order.size():
		return {}
	return {"options": options, "context": _build_level_talent_context(owner)}


static func _build_level_talent_context(owner) -> Dictionary:
	var pick_index := _get_next_level_talent_pick_index(owner)
	var owner_level := _get_owner_level(owner)
	var trigger_level := owner_level if owner_level > 0 and owner_level % TRIGGER_LEVEL == 0 else pick_index * TRIGGER_LEVEL
	var role_names := PackedStringArray()
	for role_id in get_level_talent_role_order(owner):
		role_names.append(str(LEVEL_TALENT_ROLE_TITLES.get(role_id, str(role_id))))
	return {
		"offer_mode": CATEGORY_SKILL_TALENT,
		"skill_talent_offer": true,
		"level_talent_offer": true,
		"role_build_offer": false,
		"selection_count": 1,
		"refresh_limit": 0,
		"refresh_remaining": 0,
		"refresh_unlimited": false,
		"refresh_button_label": "",
		"level_talent_role_select": true,
		"talent_stage": pick_index,
		"trigger_level": trigger_level,
		"summary": "Lv.%d 天赋强化：先选择%s，再从该角色 3 张候选天赋中选择 1 项。" % [trigger_level, "、".join(role_names)]
	}


static func _make_level_talent_role_option(owner, role_id: String, role_index: int) -> Dictionary:
	var role_title := str(LEVEL_TALENT_ROLE_TITLES.get(role_id, role_id))
	var talent_options := _build_level_talent_role_options(owner, role_id)
	return {
		"id": LEVEL_TALENT_ROLE_OPTION_PREFIX + role_id,
		"offer_key": "%s:%s" % [role_id, LEVEL_TALENT_ROLE_OPTION_PREFIX.trim_suffix(":")],
		"option_category": CATEGORY_SKILL_TALENT,
		"slot": "skill",
		"slot_label": "天赋强化",
		"role_id": role_id,
		"level_talent_role_index": role_index,
		"level_talent_role_entry": true,
		"title": "角色%d：%s" % [role_index + 1, role_title],
		"card_title": role_title,
		"summary": "进入%s天赋选择后，从 3 张天赋卡中选择 1 项。" % role_title,
		"short_description": "进入%s天赋选择。" % role_title,
		"description": "进入%s天赋选择后，从 3 张天赋卡中选择 1 项。" % role_title,
		"preview_description": "进入%s天赋选择。" % role_title,
		"detail_description": "进入%s天赋选择后，从 3 张天赋卡中选择 1 项。" % role_title,
		"exact_description": "一级角色入口，不会直接消耗本次天赋选择。",
		"hide_card_title": false,
		"blessing_tier": 1,
		"level_talent_options": talent_options
	}


static func _build_level_talent_role_options(owner, role_id: String) -> Array:
	var options: Array = []
	var excluded_ids: Array = []
	var excluded_group_ids: Array = []
	for option_index in range(LEVEL_TALENT_ROLE_OPTION_COUNT):
		var option := _make_level_talent_option(owner, role_id, option_index, excluded_ids, excluded_group_ids)
		if option.is_empty():
			break
		option["level_talent_option_index"] = option_index
		options.append(option)
		var talent_id := str(option.get("talent_id", option.get("level_talent_id", "")))
		if talent_id != "" and not excluded_ids.has(talent_id):
			excluded_ids.append(talent_id)
		var definition := _get_level_talent_definition_for_role(role_id, talent_id)
		var group_id := _get_level_talent_group_id(definition)
		if group_id != "" and not excluded_group_ids.has(group_id):
			excluded_group_ids.append(group_id)
	return options


static func _make_level_talent_option(owner, role_id: String, option_index: int, excluded_ids: Array = [], excluded_group_ids: Variant = null) -> Dictionary:
	var definition := _pick_level_talent_definition(owner, role_id, excluded_ids, excluded_group_ids)
	if definition.is_empty():
		return {}
	var talent_id := str(definition.get("id", ""))
	var role_title := str(LEVEL_TALENT_ROLE_TITLES.get(role_id, role_id))
	var title := str(definition.get("title", "%s天赋强化" % role_title))
	var summary := str(definition.get("summary", definition.get("description", "预留天赋效果接口。")))
	return {
		"id": OPTION_PREFIX + talent_id,
		"offer_key": "%s:%s" % [role_id, talent_id],
		"option_category": CATEGORY_SKILL_TALENT,
		"slot": "skill",
		"slot_label": "天赋强化",
		"role_id": role_id,
		"level_talent_id": talent_id,
		"talent_id": talent_id,
		"talent_stage": int(option_index) + 1,
		"title": title,
		"card_title": title,
		"summary": summary,
		"short_description": summary,
		"description": summary,
		"preview_description": summary,
		"detail_description": summary,
		"exact_description": summary,
		"hide_card_title": false,
		"blessing_tier": 1
	}


static func _pick_level_talent_definition(owner, role_id: String, excluded_ids: Array = [], excluded_group_ids: Variant = null) -> Dictionary:
	var definitions: Array = LEVEL_TALENT_DEFINITIONS.get(role_id, [])
	if definitions.is_empty():
		return {}
	var excluded_lookup := {}
	for talent_value in get_selected_level_talents(owner, role_id):
		excluded_lookup[str(talent_value)] = true
	for talent_value in excluded_ids:
		excluded_lookup[str(talent_value)] = true
	var excluded_group_lookup := _get_level_talent_group_lookup_for_ids(definitions, excluded_ids)
	if excluded_group_ids is Array:
		excluded_group_lookup = _get_level_talent_group_lookup_for_ids(definitions, excluded_group_ids)
	var candidates: Array = _collect_level_talent_candidates(owner, definitions, excluded_lookup, false, excluded_group_lookup)
	if candidates.is_empty():
		var refresh_excluded_lookup := {}
		for talent_value in excluded_ids:
			refresh_excluded_lookup[str(talent_value)] = true
		candidates = _collect_level_talent_candidates(owner, definitions, refresh_excluded_lookup, false, excluded_group_lookup)
	if candidates.is_empty():
		return {}
	return (candidates[int(randi() % candidates.size())] as Dictionary).duplicate(true)


static func _collect_level_talent_candidates(owner, definitions: Array, excluded_lookup: Dictionary, allow_placeholders: bool, excluded_group_lookup: Dictionary = {}) -> Array:
	var candidates: Array = []
	for definition_value in definitions:
		if definition_value is not Dictionary:
			continue
		var definition := definition_value as Dictionary
		var talent_id := str(definition.get("id", ""))
		if talent_id == "" or excluded_lookup.has(talent_id):
			continue
		var group_id := _get_level_talent_group_id(definition)
		if group_id != "" and excluded_group_lookup.has(group_id):
			continue
		if bool(definition.get("placeholder", false)) and not allow_placeholders:
			continue
		if not _is_level_talent_skill_requirement_met(owner, definition):
			continue
		var role_id := _get_level_talent_role_id_from_definition(definition)
		if role_id != "" and _is_level_talent_group_locked(owner, role_id, definition):
			continue
		candidates.append(definition.duplicate(true))
	return candidates


static func _is_level_talent_skill_requirement_met(owner, definition: Dictionary) -> bool:
	var skill_id := _get_level_talent_required_skill_id(definition)
	if skill_id == "":
		return true
	if PLAYER_BLESSING_SKILL_STATE.INHERENT_SKILL_IDS.has(skill_id) or PLAYER_BLESSING_SKILL_STATE.SHARED_ENTRY_SKILL_IDS.has(skill_id):
		return true
	return PLAYER_BLESSING_SKILL_STATE.is_skill_unlocked(owner, skill_id)


static func _get_level_talent_required_skill_id(definition: Dictionary) -> String:
	var explicit_skill_id := str(definition.get("required_skill_id", definition.get("skill_id", "")))
	if explicit_skill_id != "":
		return explicit_skill_id
	var talent_id := str(definition.get("id", ""))
	for rule_value in LEVEL_TALENT_REQUIRED_SKILL_RULES:
		var rule: Dictionary = rule_value
		var prefix := str(rule.get("prefix", ""))
		if prefix != "" and talent_id.begins_with(prefix):
			return str(rule.get("skill_id", ""))
	return ""


static func _get_level_talent_definition_for_role(role_id: String, talent_id: String) -> Dictionary:
	for definition_value in LEVEL_TALENT_DEFINITIONS.get(role_id, []):
		if definition_value is Dictionary and str((definition_value as Dictionary).get("id", "")) == talent_id:
			return (definition_value as Dictionary).duplicate(true)
	return {}


static func _refresh_level_talent_role_card(owner, options: Array, context: Dictionary, option_index: int, role_id: String) -> Array:
	if role_id == "":
		return []
	var role_option_index := _find_level_talent_role_option_index(options, role_id)
	if role_option_index < 0:
		return []
	var role_option: Dictionary = options[role_option_index] if options[role_option_index] is Dictionary else {}
	var talent_options := _duplicate_option_array(role_option.get("level_talent_options", []))
	if option_index < 0 or option_index >= talent_options.size():
		return talent_options
	var excluded_ids: Array = []
	var sibling_ids: Array = []
	for nested_index in range(talent_options.size()):
		var nested_value: Variant = talent_options[nested_index]
		var nested_option: Dictionary = nested_value if nested_value is Dictionary else {}
		var talent_id := str(nested_option.get("talent_id", nested_option.get("level_talent_id", "")))
		if talent_id == "":
			continue
		if not excluded_ids.has(talent_id):
			excluded_ids.append(talent_id)
		if nested_index != option_index and not sibling_ids.has(talent_id):
			sibling_ids.append(talent_id)
	var sibling_group_ids: Array = _get_level_talent_group_lookup_for_ids(LEVEL_TALENT_DEFINITIONS.get(role_id, []), sibling_ids).keys()
	var replacement := _make_level_talent_option(owner, role_id, option_index, excluded_ids, sibling_group_ids)
	if replacement.is_empty():
		replacement = _make_level_talent_option(owner, role_id, option_index, excluded_ids, [])
	if replacement.is_empty():
		return talent_options
	replacement["level_talent_option_index"] = option_index
	talent_options[option_index] = replacement
	role_option["level_talent_options"] = talent_options
	options[role_option_index] = role_option
	owner.set("current_blessing_offer", {"options": options, "context": context.duplicate(true)})
	return talent_options


static func _find_level_talent_role_option_index(options: Array, role_id: String) -> int:
	for option_index in range(options.size()):
		var option: Dictionary = options[option_index] if options[option_index] is Dictionary else {}
		if bool(option.get("level_talent_role_entry", false)) and str(option.get("role_id", "")) == role_id:
			return option_index
	return -1


static func _has_level_talent_role_entries(options: Array) -> bool:
	for option_value in options:
		if option_value is Dictionary and bool((option_value as Dictionary).get("level_talent_role_entry", false)):
			return true
	return false


static func _find_offered_level_talent_option(current_offer: Dictionary, option_id: String) -> Dictionary:
	for option_value in current_offer.get("options", []):
		if option_value is not Dictionary:
			continue
		var option: Dictionary = option_value
		if str(option.get("id", "")) == option_id:
			return option.duplicate(true)
		var nested_options: Array = option.get("level_talent_options", []) if option.get("level_talent_options", []) is Array else []
		for nested_value in nested_options:
			if nested_value is Dictionary and str((nested_value as Dictionary).get("id", "")) == option_id:
				return (nested_value as Dictionary).duplicate(true)
	return {}


static func _duplicate_option_array(value: Variant) -> Array:
	var result: Array = []
	if value is not Array:
		return result
	for option_value in value:
		if option_value is Dictionary:
			result.append((option_value as Dictionary).duplicate(true))
	return result


static func _is_level_talent_context(context: Dictionary) -> bool:
	return bool(context.get("skill_talent_offer", false)) and bool(context.get("level_talent_offer", false))


static func _get_preserved_level_talent_offer(owner) -> Dictionary:
	if owner == null or str(owner.get("active_upgrade_kind")) != CATEGORY_SKILL_TALENT:
		return {}
	var offer: Variant = owner.get("current_blessing_offer")
	if offer is not Dictionary:
		return {}
	var context: Dictionary = (offer as Dictionary).get("context", {}) if (offer as Dictionary).get("context", {}) is Dictionary else {}
	if not _is_level_talent_context(context):
		return {}
	var options := _duplicate_option_array((offer as Dictionary).get("options", []))
	if options.size() != get_level_talent_role_order(owner).size():
		return {}
	return {"options": options, "context": context.duplicate(true)}


static func _get_pending_level_talent_count(owner) -> int:
	if owner == null:
		return 0
	var value: Variant = owner.get("pending_level_talent_choices")
	return max(0, int(value)) if value != null else 0


static func _set_pending_level_talent_count(owner, count: int) -> void:
	if owner != null:
		owner.set("pending_level_talent_choices", max(0, count))


static func _get_acquired_level_talent_count(owner) -> int:
	var result := 0
	for role_id in get_level_talent_role_order(owner):
		result += get_selected_level_talents(owner, str(role_id)).size()
	return result


static func _get_next_level_talent_pick_index(owner) -> int:
	return _get_acquired_level_talent_count(owner) + 1


static func _get_owner_level(owner) -> int:
	if owner == null:
		return 0
	var value: Variant = owner.get("level")
	return max(0, int(value)) if value != null else 0


static func _is_valid_level_talent_id(role_id: String, talent_id: String) -> bool:
	for definition_value in LEVEL_TALENT_DEFINITIONS.get(role_id, []):
		if definition_value is Dictionary and str((definition_value as Dictionary).get("id", "")) == talent_id:
			return true
	return false


static func _get_level_talent_role_id_from_definition(definition: Dictionary) -> String:
	var talent_id := str(definition.get("id", ""))
	for role_id in LEVEL_TALENT_DEFINITIONS.keys():
		if _is_valid_level_talent_id(str(role_id), talent_id):
			return str(role_id)
	return ""


static func _get_level_talent_group_lookup_for_ids(definitions: Array, talent_ids: Array) -> Dictionary:
	var id_lookup: Dictionary = {}
	for talent_value in talent_ids:
		var talent_id := str(talent_value)
		if talent_id != "":
			id_lookup[talent_id] = true
	var result: Dictionary = {}
	if id_lookup.is_empty():
		return result
	for definition_value in definitions:
		if definition_value is not Dictionary:
			continue
		var definition := definition_value as Dictionary
		var talent_id := str(definition.get("id", ""))
		if not id_lookup.has(talent_id):
			continue
		var group_id := _get_level_talent_group_id(definition)
		if group_id != "":
			result[group_id] = true
	return result


static func _normalize_level_talent_ids(role_id: String, value: Variant) -> Array:
	var raw: Array = []
	if value is Array:
		raw = value
	elif value is Dictionary:
		raw = [value]
	elif str(value) != "":
		raw = [str(value)]
	var result: Array = []
	for talent_value in raw:
		var talent_id := ""
		if talent_value is Dictionary:
			talent_id = str((talent_value as Dictionary).get("id", (talent_value as Dictionary).get("talent_id", "")))
		else:
			talent_id = str(talent_value)
		if _is_valid_level_talent_id(role_id, talent_id):
			result.append(talent_id)
	return result


static func _get_level_talent_group_id(definition: Dictionary) -> String:
	var explicit_group := str(definition.get("level_talent_group_id", definition.get("talent_group_id", "")))
	if explicit_group != "":
		return explicit_group
	var talent_id := str(definition.get("id", ""))
	var suffix_index := talent_id.rfind("_")
	if suffix_index <= 0:
		return ""
	var suffix := talent_id.substr(suffix_index + 1)
	if not suffix.is_valid_int():
		return ""
	return talent_id.substr(0, suffix_index)


static func _get_level_talent_group_scope(owner, role_id: String, definition: Dictionary) -> String:
	var explicit_scope := str(definition.get("level_talent_group_scope", definition.get("talent_group_scope", "")))
	if explicit_scope != "":
		return explicit_scope
	if owner != null and owner.get("role_special_states") is Dictionary:
		var states: Dictionary = owner.get("role_special_states")
		var role_state: Dictionary = states.get(role_id, {}) if states.get(role_id, {}) is Dictionary else {}
		var state_scope := str(role_state.get("level_talent_group_scope", ""))
		if state_scope != "":
			return state_scope
	return "default"


static func _get_level_talent_group_locks(owner, role_id: String) -> Dictionary:
	if owner == null or owner.get("role_special_states") is not Dictionary:
		return {}
	var states: Dictionary = owner.get("role_special_states")
	var role_state: Dictionary = states.get(role_id, {}) if states.get(role_id, {}) is Dictionary else {}
	var selected := _normalize_level_talent_ids(role_id, role_state.get(LEVEL_TALENTS_KEY, []))
	return _normalize_level_talent_group_locks(role_id, role_state.get(LEVEL_TALENT_GROUP_LOCKS_KEY, {}), selected)


static func _is_level_talent_group_locked(owner, role_id: String, definition: Dictionary) -> bool:
	var group_id := _get_level_talent_group_id(definition)
	if group_id == "":
		return false
	var locks := _get_level_talent_group_locks(owner, role_id)
	var scope := _get_level_talent_group_scope(owner, role_id, definition)
	var scope_locks: Dictionary = locks.get(scope, {}) if locks.get(scope, {}) is Dictionary else {}
	return str(scope_locks.get(group_id, "")) != ""


static func _record_level_talent_group_lock(owner, role_id: String, role_state: Dictionary, definition: Dictionary, selected_level_talents: Array) -> Dictionary:
	var locks := _normalize_level_talent_group_locks(role_id, role_state.get(LEVEL_TALENT_GROUP_LOCKS_KEY, {}), selected_level_talents)
	var group_id := _get_level_talent_group_id(definition)
	if group_id == "":
		return locks
	var scope := _get_level_talent_group_scope(owner, role_id, definition)
	var scope_locks: Dictionary = locks.get(scope, {}) if locks.get(scope, {}) is Dictionary else {}
	scope_locks[group_id] = str(definition.get("id", ""))
	locks[scope] = scope_locks
	return locks


static func _normalize_level_talent_group_locks(role_id: String, value: Variant, selected_level_talents: Array) -> Dictionary:
	var result: Dictionary = {}
	var selected_lookup: Dictionary = {}
	for talent_value in selected_level_talents:
		selected_lookup[str(talent_value)] = true
	if value is Dictionary:
		for scope_value in (value as Dictionary).keys():
			var scope := str(scope_value)
			if scope == "":
				continue
			var raw_scope_locks: Variant = (value as Dictionary).get(scope_value, {})
			if raw_scope_locks is not Dictionary:
				continue
			var scope_locks: Dictionary = {}
			for group_value in (raw_scope_locks as Dictionary).keys():
				var group_id := str(group_value)
				var talent_id := str((raw_scope_locks as Dictionary).get(group_value, ""))
				var definition := _get_level_talent_definition_for_role(role_id, talent_id)
				if group_id == "" or not selected_lookup.has(talent_id) or definition.is_empty() or _get_level_talent_group_id(definition) != group_id:
					continue
				scope_locks[group_id] = talent_id
			if not scope_locks.is_empty():
				result[scope] = scope_locks
	for talent_value in selected_level_talents:
		var talent_id := str(talent_value)
		var definition := _get_level_talent_definition_for_role(role_id, talent_id)
		var group_id := _get_level_talent_group_id(definition)
		if group_id == "":
			continue
		var scope := _get_level_talent_group_scope(null, role_id, definition)
		var scope_locks: Dictionary = result.get(scope, {}) if result.get(scope, {}) is Dictionary else {}
		if not scope_locks.has(group_id):
			scope_locks[group_id] = talent_id
		result[scope] = scope_locks
	return result


static func get_selected_talent(owner, role_id: String, progress_id: String) -> String:
	return ""


static func get_selected_talents(owner, role_id: String, progress_id: String) -> Array:
	return []


static func has_talent(owner, talent_id: String) -> bool:
	return false


static func get_progress_text(owner, role_id: String) -> String:
	var role_title := str(LEVEL_TALENT_ROLE_TITLES.get(role_id, role_id))
	var selected := get_selected_level_talents(owner, role_id)
	var pending_count := _get_pending_level_talent_count(owner)
	var status := "%s等级天赋：已记录 %d 项" % [role_title, selected.size()]
	if pending_count > 0:
		status += " · 待选择 %d 次" % pending_count
	if not selected.is_empty():
		status += " · %s" % ", ".join(selected)
	return status

static func _get_talent_title(progress_id: String, talent_id: String) -> String:
	return str(get_talent_definition(progress_id, talent_id).get("title", talent_id))


static func normalize_role_special_states(value: Variant) -> Dictionary:
	var states: Dictionary = value.duplicate(true) if value is Dictionary else {}
	for role_id in ROLE_PROGRESS_ORDER:
		var role_state: Dictionary = states.get(role_id, {}) if states.get(role_id, {}) is Dictionary else {}
		role_state[TALENTS_KEY] = {}
		var level_talents := _normalize_level_talent_ids(role_id, role_state.get(LEVEL_TALENTS_KEY, []))
		role_state[LEVEL_TALENTS_KEY] = level_talents
		role_state[LEVEL_TALENT_GROUP_LOCKS_KEY] = _normalize_level_talent_group_locks(role_id, role_state.get(LEVEL_TALENT_GROUP_LOCKS_KEY, {}), level_talents)
		states[role_id] = PLAYER_SKILL_LEVEL_SYSTEM.normalize_role_state(str(role_id), role_state)
	return states

static func _normalize_selected_talents(progress_id: String, value: Variant) -> Array:
	var raw: Array = value if value is Array else ([str(value)] if str(value) != "" else [])
	var result: Array = []
	for index in range(mini(raw.size(), TALENT_STAGE_COUNT)):
		var talent_id := str(raw[index])
		var definition := get_talent_definition(progress_id, talent_id)
		if talent_id == "" or int(definition.get("stage", 0)) != index + 1:
			break
		result.append(talent_id)
	return result


static func _get_stage_definitions(progress_id: String, stage: int) -> Array:
	var result: Array = []
	for definition_value in TALENT_DEFINITIONS.get(progress_id, []):
		if definition_value is Dictionary and int((definition_value as Dictionary).get("stage", 0)) == stage:
			result.append((definition_value as Dictionary).duplicate(true))
	return result


static func _get_path(talent_ids: Array) -> String:
	var path := ""
	for talent_id in talent_ids:
		var side := str(_find_talent_definition(str(talent_id)).get("side", ""))
		path += "1" if side == "left" else ("2" if side == "right" else "-")
	return path.rpad(TALENT_STAGE_COUNT, "-").left(TALENT_STAGE_COUNT)


static func _find_talent_definition(talent_id: String) -> Dictionary:
	for progress_id in TALENT_DEFINITIONS:
		var definition := get_talent_definition(progress_id, talent_id)
		if not definition.is_empty():
			return definition
	return {}


static func _is_choice_pending(owner, choice: Dictionary) -> bool:
	var role_id := str(choice.get("role_id", ""))
	var progress_id := str(choice.get("progress_id", ""))
	var stage := int(choice.get("talent_stage", 0))
	if stage < 1 or stage > TALENT_STAGE_COUNT or not ROLE_PROGRESS_ORDER.get(role_id, []).has(progress_id):
		return false
	if get_selected_talents(owner, role_id, progress_id).size() + 1 != stage:
		return false
	return get_skill_progress_level(owner, role_id, progress_id) >= int(TRIGGER_LEVELS[stage - 1])


static func _get_preserved_offer_choice(owner) -> Dictionary:
	if owner == null or str(owner.get("active_upgrade_kind")) != CATEGORY_SKILL_TALENT:
		return {}
	var offer: Variant = owner.get("current_blessing_offer")
	if offer is not Dictionary:
		return {}
	var context: Variant = (offer as Dictionary).get("context", {})
	if context is not Dictionary or not bool((context as Dictionary).get("skill_talent_offer", false)):
		return {}
	return {
		"role_id": str((context as Dictionary).get("role_id", "")),
		"progress_id": str((context as Dictionary).get("skill_progress_id", "")),
		"talent_stage": int((context as Dictionary).get("talent_stage", 1))
	}


static func _get_stage_roman(stage: int) -> String:
	return ["I", "II", "III"][clampi(stage, 1, TALENT_STAGE_COUNT) - 1]


static func _get_team_role_ids(owner) -> Array:
	var result: Array = []
	if owner != null and owner.get("roles") is Array:
		for role_value in owner.get("roles"):
			if role_value is Dictionary:
				var role_id := str((role_value as Dictionary).get("id", ""))
				if role_id != "" and not result.has(role_id):
					result.append(role_id)
	return result
