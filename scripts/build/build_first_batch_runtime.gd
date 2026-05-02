extends RefCounted

const FIRST_BATCH_DB := preload("res://scripts/build/build_first_batch_database.gd")
const FIRST_BATCH_MODEL := preload("res://scripts/build/build_first_batch_model.gd")

const UI_SLOT_BY_OFFER_SLOT := {
	"continue": "body",
	"link": "combat",
	"pivot": "skill"
}

const UI_LABEL_BY_OFFER_SLOT := {
	"continue": "主轴延续",
	"link": "联动共鸣",
	"pivot": "转向补强"
}

const CARD_TYPE_LABELS := {
	"hero": "英雄卡",
	"capstone": "英雄成型卡",
	"resonance_pair": "双人共鸣卡",
	"resonance_tri": "三人共鸣卡",
	"generic": "队伍通用卡",
	"mastery": "成型节点"
}

const ROLE_LABELS := {
	"swordsman": "剑士",
	"gunner": "射手",
	"mage": "术师"
}

const AXIS_LABELS := {
	"entry": "入场",
	"exit": "离场",
	"core_output": "普攻/核心输出",
	"ultimate": "大招",
	"capstone": "成型",
	"independent_passive": "独立冷却被动",
	"resonance": "联动",
	"generic": "通用"
}

const POSITION_LABELS := {
	"damage": "输出",
	"control": "控制",
	"survival": "生存",
	"support": "支援",
	"summon": "召唤/造物",
	"resource": "资源",
	"mobility": "机动"
}

const FALLBACK_CARD_ID := "first_batch_blank_reforge"


static func build_offer_for_owner(owner, refresh_limit: int = FIRST_BATCH_MODEL.DEFAULT_REFRESH_LIMIT) -> Dictionary:
	var state := make_state_from_owner(owner)
	var offer := FIRST_BATCH_MODEL.build_upgrade_offer(state, refresh_limit)
	return _format_offer(offer, state)


static func refresh_offer_for_owner(owner, current_offer: Dictionary) -> Dictionary:
	var state := make_state_from_owner(owner)
	var refreshed := FIRST_BATCH_MODEL.refresh_upgrade_offer(state, current_offer)
	return _format_offer(refreshed, state)


static func make_state_from_owner(owner) -> Dictionary:
	var team_level := 1
	var card_levels: Dictionary = {}
	if owner != null:
		team_level = max(1, int(owner.get("level")))
		var raw_levels: Variant = owner.get("card_pick_levels")
		if raw_levels is Dictionary:
			card_levels = (raw_levels as Dictionary).duplicate(true)
	return make_state_from_card_levels(team_level, card_levels)


static func make_state_from_card_levels(team_level: int, card_levels: Dictionary) -> Dictionary:
	var state := FIRST_BATCH_MODEL.make_state(max(1, team_level))
	var known_ids := {}
	for card_id in FIRST_BATCH_DB.get_offer_card_ids():
		known_ids[str(card_id)] = true
	var sorted_ids: Array = []
	for raw_card_id in card_levels.keys():
		var card_id := str(raw_card_id)
		if known_ids.has(card_id):
			sorted_ids.append(card_id)
	sorted_ids.sort()
	for card_id_value in sorted_ids:
		var card_id := str(card_id_value)
		var card := FIRST_BATCH_DB.get_card_data(card_id)
		var level: int = clamp(int(card_levels.get(card_id, 0)), 0, int(card.get("max_level", 1)))
		for _i in range(level):
			state = FIRST_BATCH_MODEL.apply_card_pick(state, card_id)
	return state


static func format_options_for_state(options: Array, state: Dictionary, context: Dictionary = {}) -> Array:
	var formatted: Array = []
	for raw_option in options:
		if raw_option is not Dictionary:
			continue
		var option := _format_card_option(raw_option as Dictionary, state, context)
		if not option.is_empty():
			formatted.append(option)
	if formatted.is_empty():
		formatted.append(_make_fallback_option())
	return formatted


static func get_offer_context_summary(offer: Dictionary) -> Dictionary:
	var context: Dictionary = (offer.get("context", {}) as Dictionary).duplicate(true)
	context["offer_mode"] = "first_batch"
	context["refresh_button_label"] = _make_refresh_button_label(context)
	return context


static func _format_offer(offer: Dictionary, state: Dictionary) -> Dictionary:
	var context: Dictionary = (offer.get("context", {}) as Dictionary).duplicate(true)
	context["offer_mode"] = "first_batch"
	context["refresh_button_label"] = _make_refresh_button_label(context)
	var formatted_options := format_options_for_state(offer.get("options", []), state, context)
	return {
		"options": formatted_options,
		"context": context,
		"state": state,
		"refreshed": bool(offer.get("refreshed", false))
	}


static func _format_card_option(card: Dictionary, state: Dictionary, context: Dictionary = {}) -> Dictionary:
	var card_id := str(card.get("id", ""))
	if card_id == "":
		return {}
	var offer_slot := str(card.get("offer_slot", FIRST_BATCH_MODEL.SLOT_PIVOT))
	var ui_slot := str(UI_SLOT_BY_OFFER_SLOT.get(offer_slot, "body"))
	var current_level := FIRST_BATCH_MODEL.get_card_level(state, card_id)
	var max_level := int(card.get("max_level", 1))
	var next_level: int = clamp(current_level + 1, 1, max_level)
	var title := "%s Lv.%d" % [str(card.get("title", card_id)), next_level]
	if max_level <= 1:
		title = str(card.get("title", card_id))
	var reason := str(card.get("offer_reason", ""))
	var summary := str(card.get("summary", ""))
	var slot_label := str(UI_LABEL_BY_OFFER_SLOT.get(offer_slot, "Build"))
	var short := summary
	if reason != "":
		short = "%s｜%s" % [slot_label, summary]
	return {
		"id": card_id,
		"slot": ui_slot,
		"slot_label": slot_label,
		"title": title,
		"summary": short,
		"short_description": short,
		"preview_description": summary,
		"description": _make_description(card, state, current_level, next_level, max_level, reason, context),
		"detail_description": _make_description(card, state, current_level, next_level, max_level, reason, context),
		"exact_description": _make_description(card, state, current_level, next_level, max_level, reason, context),
		"build_offer_slot": offer_slot,
		"first_batch_card": true,
		"card_type": str(card.get("card_type", "")),
		"owner_role": str(card.get("owner_role", "")),
		"evolved": _is_milestone_card(card, state)
	}


static func _make_description(card: Dictionary, state: Dictionary, current_level: int, next_level: int, max_level: int, reason: String, context: Dictionary) -> String:
	var lines: Array[String] = []
	var card_type := str(card.get("card_type", ""))
	var owner_role := str(card.get("owner_role", ""))
	var type_label := str(CARD_TYPE_LABELS.get(card_type, card_type))
	if owner_role != "":
		type_label = "%s · %s" % [str(ROLE_LABELS.get(owner_role, owner_role)), type_label]
	lines.append("%s｜Lv.%d / %d" % [type_label, next_level, max_level])
	if reason != "":
		lines.append("发牌理由：%s" % reason)
	var axes := _labels_from_array(card.get("upgrade_axes", []), AXIS_LABELS)
	if not axes.is_empty():
		lines.append("强化面：%s" % "、".join(axes))
	var positions := _labels_from_weight_map(card.get("position_weights", {}), POSITION_LABELS)
	if not positions.is_empty():
		lines.append("定位倾向：%s" % "、".join(positions))
	var milestone_hint := _get_milestone_hint(card, state)
	if milestone_hint != "":
		lines.append(milestone_hint)
	if bool(card.get("has_independent_cooldown", false)):
		lines.append("独立冷却：%.1f 秒｜%s" % [float(card.get("cooldown_seconds", 0.0)), str(card.get("independent_passive_summary", "自动触发新的被动技能。"))])
	var summary := str(card.get("summary", ""))
	if summary != "":
		lines.append(summary)
	var refresh_remaining := int(context.get("refresh_remaining", 0))
	var refresh_limit := int(context.get("refresh_limit", 0))
	if refresh_limit > 0:
		lines.append("本次升级刷新：%d / %d" % [refresh_remaining, refresh_limit])
	if current_level <= 0:
		lines.append("新路线投入：会建立后续解锁权重。")
	elif next_level >= max_level:
		lines.append("本卡达到当前上限；后续发牌会自然转向联动或副轴。")
	return "\n".join(lines)


static func _labels_from_array(values_variant: Variant, label_map: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if values_variant is not Array:
		return result
	for value in values_variant as Array:
		var key := str(value)
		result.append(str(label_map.get(key, key)))
	return result


static func _labels_from_weight_map(weights_variant: Variant, label_map: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if weights_variant is not Dictionary:
		return result
	var pairs: Array = []
	for key in (weights_variant as Dictionary).keys():
		pairs.append({"key": str(key), "weight": float((weights_variant as Dictionary).get(key, 0.0))})
	pairs.sort_custom(func(a, b): return float(a.get("weight", 0.0)) > float(b.get("weight", 0.0)))
	for pair in pairs:
		if float((pair as Dictionary).get("weight", 0.0)) <= 0.0:
			continue
		var key := str((pair as Dictionary).get("key", ""))
		result.append(str(label_map.get(key, key)))
		if result.size() >= 3:
			break
	return result


static func _is_milestone_card(card: Dictionary, state: Dictionary) -> bool:
	var card_type := str(card.get("card_type", ""))
	if card_type == FIRST_BATCH_DB.CARD_TYPE_CAPSTONE:
		return true
	if bool(card.get("has_independent_cooldown", false)):
		return true
	var team_level := int(state.get("team_level", 1))
	return team_level == 6 or team_level == 12 or team_level == 18 or team_level >= 25


static func _get_milestone_hint(card: Dictionary, state: Dictionary) -> String:
	var team_level := int(state.get("team_level", 1))
	var owner_role := str(card.get("owner_role", ""))
	if team_level >= 6 and team_level < 12 and owner_role != "":
		var stage_6_names := {
			"swordsman": "破阵牵引",
			"gunner": "火线标记",
			"mage": "符印领域"
		}
		var role_label := str(ROLE_LABELS.get(owner_role, owner_role))
		var skill_name := str(stage_6_names.get(owner_role, "角色质变"))
		return "Lv.6 质变：%s命中会显示并触发「%s」独立冷却效果，本卡会放大对应定位。" % [role_label, skill_name]
	if team_level >= 12 and bool(card.get("has_independent_cooldown", false)):
		return "Lv.12 质变：该卡会新增独立冷却被动，不只提供属性。"
	if team_level >= 18 and str(card.get("card_type", "")) == FIRST_BATCH_DB.CARD_TYPE_CAPSTONE:
		return "Lv.18 质变：该卡属于成型节点，会强化大招、入场或离场循环。"
	if team_level >= 25:
		return "Lv.25 成型：主线基本毕业，后续适合扩展副轴或跨英雄共鸣。"
	return ""


static func _make_refresh_button_label(context: Dictionary) -> String:
	var remaining := int(context.get("refresh_remaining", 0))
	var limit := int(context.get("refresh_limit", 0))
	if limit <= 0:
		return ""
	if remaining > 0:
		return "刷新发牌 %d/%d" % [remaining, limit]
	return "刷新已用完"


static func _make_fallback_option() -> Dictionary:
	return {
		"id": FALLBACK_CARD_ID,
		"slot": "body",
		"slot_label": "稳定补强",
		"title": "临场重铸",
		"summary": "当前卡池已无合适新卡，转为基础属性补强。",
		"short_description": "当前卡池已无合适新卡，转为基础属性补强。",
		"preview_description": "最大生命、伤害和回能小幅提高。",
		"description": "当前首批 Build 卡池已耗尽或暂不满足解锁条件。\n效果：最大生命、全队伤害和回能小幅提高。",
		"detail_description": "当前首批 Build 卡池已耗尽或暂不满足解锁条件。\n效果：最大生命、全队伤害和回能小幅提高。",
		"first_batch_card": true,
		"evolved": false
	}
