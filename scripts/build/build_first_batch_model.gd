extends RefCounted

const FIRST_BATCH_DB := preload("res://scripts/build/build_first_batch_database.gd")

const SLOT_CONTINUE := "continue"
const SLOT_LINK := "link"
const SLOT_PIVOT := "pivot"
const OFFER_SLOTS := [SLOT_CONTINUE, SLOT_LINK, SLOT_PIVOT]

const DEFAULT_REFRESH_LIMIT := 1
const REJECTED_OFFER_PENALTY := 1000.0


static func make_state(team_level: int = 1) -> Dictionary:
	return {
		"team_level": team_level,
		"card_levels": {},
		"role_investment": {},
		"package_depth": {},
		"edge_level": {},
		"tag_points": {},
		"position_points": {},
		"recent_momentum": {},
		"last_picks": []
	}


static func make_offer_context(refresh_limit: int = DEFAULT_REFRESH_LIMIT) -> Dictionary:
	return {
		"refresh_limit": refresh_limit,
		"refresh_remaining": refresh_limit,
		"refresh_index": 0,
		"rejected_offer_ids": [],
		"refresh_repair_used": false
	}


static func with_team_level(state: Dictionary, team_level: int) -> Dictionary:
	var next := state.duplicate(true)
	next["team_level"] = team_level
	return next


static func get_card_level(state: Dictionary, card_id: String) -> int:
	return int((state.get("card_levels", {}) as Dictionary).get(card_id, 0))


static func is_card_offerable(state: Dictionary, card_id: String) -> bool:
	var card := FIRST_BATCH_DB.get_card_data(card_id)
	if card.is_empty():
		return false
	if str(card.get("card_type", "")) == FIRST_BATCH_DB.CARD_TYPE_MASTERY:
		return false
	if int(state.get("team_level", 1)) < int(card.get("team_level_min", 0)):
		return false
	if get_card_level(state, card_id) >= int(card.get("max_level", 1)):
		return false
	return _meets_requirements(card, state)


static func get_eligible_card_ids(state: Dictionary) -> Array:
	var result: Array = []
	for card_id in FIRST_BATCH_DB.get_offer_card_ids():
		if is_card_offerable(state, str(card_id)):
			result.append(str(card_id))
	return result


static func apply_card_pick(state: Dictionary, card_id: String) -> Dictionary:
	var card := FIRST_BATCH_DB.get_card_data(card_id)
	if card.is_empty():
		return state.duplicate(true)
	var next := state.duplicate(true)
	var levels: Dictionary = (next.get("card_levels", {}) as Dictionary).duplicate(true)
	levels[card_id] = min(int(levels.get(card_id, 0)) + 1, int(card.get("max_level", 1)))
	next["card_levels"] = levels
	_add_weight_map(next, "role_investment", card.get("trait_gain", {}))
	_add_weight_map(next, "package_depth", card.get("package_gain", {}))
	_add_weight_map(next, "edge_level", card.get("edge_gain", {}))
	_add_weight_map(next, "position_points", card.get("position_weights", {}))
	_add_tag_weights(next, card)
	_add_momentum(next, card)
	var last_picks: Array = (next.get("last_picks", []) as Array).duplicate()
	last_picks.append(card_id)
	while last_picks.size() > 6:
		last_picks.pop_front()
	next["last_picks"] = last_picks
	return next


static func build_upgrade_options(state: Dictionary) -> Array:
	return build_upgrade_options_with_context(state, {})


static func build_upgrade_options_with_context(state: Dictionary, offer_context: Dictionary) -> Array:
	var options: Array = []
	var used := {}
	var repair_used := false
	for slot in OFFER_SLOTS:
		var picked := _pick_best_for_slot(state, str(slot), used, offer_context, false)
		if picked.is_empty() and _has_rejected_offer_ids(offer_context):
			picked = _pick_best_for_slot(state, str(slot), used, offer_context, true)
			if not picked.is_empty():
				repair_used = true
		if not picked.is_empty():
			used[str(picked.get("id", ""))] = true
			picked["offer_slot"] = str(slot)
			picked["offer_reason"] = _make_offer_reason(str(slot), picked)
			picked["refresh_index"] = int(offer_context.get("refresh_index", 0))
			options.append(picked)
	if not offer_context.is_empty():
		offer_context["refresh_repair_used"] = bool(offer_context.get("refresh_repair_used", false)) or repair_used
	return options


static func build_upgrade_offer(state: Dictionary, refresh_limit: int = DEFAULT_REFRESH_LIMIT) -> Dictionary:
	var context := make_offer_context(refresh_limit)
	var options := build_upgrade_options_with_context(state, context)
	return {
		"options": options,
		"context": context
	}


static func refresh_upgrade_offer(state: Dictionary, offer: Dictionary) -> Dictionary:
	var context: Dictionary = (offer.get("context", {}) as Dictionary).duplicate(true)
	if context.is_empty():
		context = make_offer_context(DEFAULT_REFRESH_LIMIT)
	if int(context.get("refresh_remaining", 0)) <= 0:
		var unchanged_options: Array = (offer.get("options", []) as Array).duplicate(true)
		return {
			"options": unchanged_options,
			"context": context,
			"refreshed": false
		}
	var rejected: Array = (context.get("rejected_offer_ids", []) as Array).duplicate()
	for option in (offer.get("options", []) as Array):
		var card_id := str((option as Dictionary).get("id", ""))
		if card_id != "" and not rejected.has(card_id):
			rejected.append(card_id)
	context["rejected_offer_ids"] = rejected
	context["refresh_remaining"] = max(0, int(context.get("refresh_remaining", 0)) - 1)
	context["refresh_index"] = int(context.get("refresh_index", 0)) + 1
	context["refresh_repair_used"] = false
	var options := build_upgrade_options_with_context(state, context)
	return {
		"options": options,
		"context": context,
		"refreshed": true
	}


static func get_triggered_mastery_nodes(state: Dictionary) -> Array:
	var result: Array = []
	for node in FIRST_BATCH_DB.get_mastery_nodes():
		var data: Dictionary = node
		if int(state.get("team_level", 1)) < int(data.get("team_level_min", 0)):
			continue
		if _meets_group(data.get("trigger_requirements", {}), state):
			result.append(data.duplicate(true))
	return result


static func _pick_best_for_slot(state: Dictionary, slot: String, used: Dictionary, offer_context: Dictionary = {}, allow_rejected: bool = false) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -999999.0
	for card_id in get_eligible_card_ids(state):
		if used.has(str(card_id)):
			continue
		if not allow_rejected and _is_rejected_in_context(str(card_id), offer_context):
			continue
		var card := FIRST_BATCH_DB.get_card_data(str(card_id))
		var score := score_card_for_slot(state, card, slot)
		if allow_rejected and _is_rejected_in_context(str(card_id), offer_context):
			score -= REJECTED_OFFER_PENALTY
		if score > best_score or (is_equal_approx(score, best_score) and str(card.get("id", "")) < str(best.get("id", "~"))):
			best = card
			best_score = score
	return best


static func score_card_for_slot(state: Dictionary, card: Dictionary, slot: String) -> float:
	var score := float(card.get("base_weight", 1.0))
	score += float((card.get("slot_affinity", {}) as Dictionary).get(slot, 0.0)) * 2.0
	var role_match := _weighted_state_match(card.get("role_weights", {}), state.get("role_investment", {}))
	var package_match := _package_match(card, state)
	var edge_match := _weighted_state_match(card.get("edge_weights", {}), state.get("edge_level", {}))
	var tag_match := _tag_match(card, state)
	var position_match := _weighted_state_match(card.get("position_weights", {}), state.get("position_points", {}))
	match slot:
		SLOT_CONTINUE:
			score += package_match * 1.2 + role_match * 0.7 + tag_match * 0.2 + position_match * 0.15
		SLOT_LINK:
			score += edge_match * 1.1 + tag_match * 0.5 + _link_type_bonus(card) + role_match * 0.2 + position_match * 0.1
		SLOT_PIVOT:
			score += _underused_role_bonus(card, state) * 1.0 + _underused_position_bonus(card, state) * 0.35 + _bridge_bonus(card, state) * 0.7 + _generic_bonus(card) + tag_match * 0.15
	if _is_package_mature(state, str(card.get("package_id", ""))):
		if slot == SLOT_CONTINUE:
			score *= 0.45
		elif slot == SLOT_PIVOT:
			score *= 1.25
	return score


static func _meets_requirements(card: Dictionary, state: Dictionary) -> bool:
	if not _meets_group(card.get("investment_requirements", {}), state):
		return false
	var any_groups: Array = card.get("requires_any", [])
	if any_groups.is_empty():
		return true
	for group in any_groups:
		if group is Dictionary and _meets_group(group, state):
			return true
	return false


static func _meets_group(group_variant: Variant, state: Dictionary) -> bool:
	if group_variant is not Dictionary:
		return true
	var group: Dictionary = group_variant
	if group.is_empty():
		return true
	if not _meets_thresholds(group.get("role_investment", {}), state.get("role_investment", {})):
		return false
	if not _meets_thresholds(group.get("package_depth", {}), state.get("package_depth", {})):
		return false
	if not _meets_thresholds(group.get("edge_level", {}), state.get("edge_level", {})):
		return false
	if not _meets_thresholds(group.get("tag_points", {}), state.get("tag_points", {})):
		return false
	if group.has("edge_total_min") and _edge_total(state) < float(group.get("edge_total_min", 0.0)):
		return false
	return true


static func _meets_thresholds(requirements_variant: Variant, values_variant: Variant) -> bool:
	if requirements_variant is not Dictionary:
		return true
	var requirements: Dictionary = requirements_variant
	var values: Dictionary = values_variant if values_variant is Dictionary else {}
	for key in requirements.keys():
		if float(values.get(key, 0.0)) < float(requirements.get(key, 0.0)):
			return false
	return true


static func _add_weight_map(state: Dictionary, key: String, weights_variant: Variant) -> void:
	if weights_variant is not Dictionary:
		return
	var target: Dictionary = (state.get(key, {}) as Dictionary).duplicate(true)
	for weight_key in (weights_variant as Dictionary).keys():
		target[weight_key] = float(target.get(weight_key, 0.0)) + float((weights_variant as Dictionary).get(weight_key, 0.0))
	state[key] = target


static func _add_tag_weights(state: Dictionary, card: Dictionary) -> void:
	for key in ["function_weights", "mechanic_weights", "archetype_weights", "produce_weights", "consume_weights", "amplify_weights"]:
		_add_weight_map(state, "tag_points", card.get(key, {}))


static func _add_momentum(state: Dictionary, card: Dictionary) -> void:
	var momentum: Dictionary = (state.get("recent_momentum", {}) as Dictionary).duplicate(true)
	for key in momentum.keys():
		momentum[key] = float(momentum.get(key, 0.0)) * 0.65
	for weight_map_key in ["role_weights", "archetype_weights"]:
		var weights: Dictionary = card.get(weight_map_key, {})
		for weight_key in weights.keys():
			momentum[weight_key] = float(momentum.get(weight_key, 0.0)) + float(weights.get(weight_key, 0.0))
	var package_id := str(card.get("package_id", ""))
	if package_id != "":
		momentum[package_id] = float(momentum.get(package_id, 0.0)) + 1.0
	state["recent_momentum"] = momentum


static func _weighted_state_match(weights_variant: Variant, values_variant: Variant) -> float:
	if weights_variant is not Dictionary or values_variant is not Dictionary:
		return 0.0
	var result := 0.0
	var weights: Dictionary = weights_variant
	var values: Dictionary = values_variant
	for key in weights.keys():
		result += float(weights.get(key, 0.0)) * float(values.get(key, 0.0))
	return result


static func _package_match(card: Dictionary, state: Dictionary) -> float:
	var package_id := str(card.get("package_id", ""))
	if package_id == "":
		return 0.0
	return float((state.get("package_depth", {}) as Dictionary).get(package_id, 0.0))


static func _tag_match(card: Dictionary, state: Dictionary) -> float:
	var result := 0.0
	for key in ["function_weights", "mechanic_weights", "archetype_weights", "consume_weights", "produce_weights"]:
		result += _weighted_state_match(card.get(key, {}), state.get("tag_points", {}))
	return result


static func _link_type_bonus(card: Dictionary) -> float:
	var card_type := str(card.get("card_type", ""))
	if card_type == FIRST_BATCH_DB.CARD_TYPE_RESONANCE_PAIR:
		return 2.0
	if card_type == FIRST_BATCH_DB.CARD_TYPE_RESONANCE_TRI:
		return 2.5
	if card_type == FIRST_BATCH_DB.CARD_TYPE_CAPSTONE:
		return 1.2
	return 0.0


static func _underused_role_bonus(card: Dictionary, state: Dictionary) -> float:
	var weights: Dictionary = card.get("role_weights", {})
	if weights.is_empty():
		return 0.4
	var investments: Dictionary = state.get("role_investment", {})
	var min_value := 999999.0
	for role_id in ["swordsman", "gunner", "mage"]:
		min_value = min(min_value, float(investments.get(role_id, 0.0)))
	var bonus := 0.0
	for role_id in weights.keys():
		bonus += max(0.0, 2.0 - float(investments.get(role_id, 0.0)) + min_value) * float(weights.get(role_id, 0.0))
	return bonus


static func _underused_position_bonus(card: Dictionary, state: Dictionary) -> float:
	var weights: Dictionary = card.get("position_weights", {})
	if weights.is_empty():
		return 0.2
	var positions: Dictionary = state.get("position_points", {})
	var min_value := 999999.0
	for position in [
		FIRST_BATCH_DB.POSITION_DAMAGE,
		FIRST_BATCH_DB.POSITION_CONTROL,
		FIRST_BATCH_DB.POSITION_SURVIVAL,
		FIRST_BATCH_DB.POSITION_SUPPORT,
		FIRST_BATCH_DB.POSITION_SUMMON,
		FIRST_BATCH_DB.POSITION_RESOURCE,
		FIRST_BATCH_DB.POSITION_MOBILITY
	]:
		min_value = min(min_value, float(positions.get(position, 0.0)))
	var bonus := 0.0
	for position in weights.keys():
		bonus += max(0.0, 1.5 - float(positions.get(position, 0.0)) + min_value) * float(weights.get(position, 0.0))
	return bonus


static func _bridge_bonus(card: Dictionary, state: Dictionary) -> float:
	var result := 0.0
	var bridge_weights: Dictionary = card.get("bridge_weights", {})
	var tag_points: Dictionary = state.get("tag_points", {})
	for bridge_key in bridge_weights.keys():
		var parts := str(bridge_key).split("->")
		if parts.size() > 0:
			result += float(bridge_weights.get(bridge_key, 0.0)) * float(tag_points.get(parts[0], 0.0))
	return result


static func _generic_bonus(card: Dictionary) -> float:
	return 0.8 if str(card.get("card_type", "")) == FIRST_BATCH_DB.CARD_TYPE_GENERIC else 0.0


static func _edge_total(state: Dictionary) -> float:
	var result := 0.0
	var edges: Dictionary = state.get("edge_level", {})
	for key in edges.keys():
		result += float(edges.get(key, 0.0))
	return result


static func _is_package_mature(state: Dictionary, package_id: String) -> bool:
	if package_id == "" or int(state.get("team_level", 1)) < 25:
		return false
	return float((state.get("package_depth", {}) as Dictionary).get(package_id, 0.0)) >= 8.0


static func _has_rejected_offer_ids(offer_context: Dictionary) -> bool:
	return offer_context.has("rejected_offer_ids") and not (offer_context.get("rejected_offer_ids", []) as Array).is_empty()


static func _is_rejected_in_context(card_id: String, offer_context: Dictionary) -> bool:
	if offer_context.is_empty() or not offer_context.has("rejected_offer_ids"):
		return false
	return (offer_context.get("rejected_offer_ids", []) as Array).has(card_id)


static func _make_offer_reason(slot: String, card: Dictionary) -> String:
	match slot:
		SLOT_CONTINUE:
			return "延续当前投入"
		SLOT_LINK:
			return "形成英雄接力或共鸣"
		SLOT_PIVOT:
			return "补缺、转向或通用稳定"
	return ""
