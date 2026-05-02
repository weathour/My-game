extends RefCounted

const FIRST_BATCH_DB := preload("res://scripts/build/build_first_batch_database.gd")
const FIRST_BATCH_MODEL := preload("res://scripts/build/build_first_batch_model.gd")
const ENEMY_PRESSURE_MODEL := preload("res://scripts/build/build_enemy_pressure_model.gd")

const MILESTONES := [6, 12, 18, 25]
const FINAL_LEVEL := 25
const DOMINANCE_AGGREGATE_GAP_LIMIT := 1.24
const DOMINANCE_CLOSE_POLICY_RATIO := 0.90
const DOMINANCE_MIN_CLOSE_POLICIES := 3
const BAD_POLICY_FINAL_RATIO_LIMIT := 0.88

const POLICY_DEFINITIONS := [
	{
		"id": "swordsman_main",
		"title": "剑士主轴",
		"role_weights": {"swordsman": 3.0, "gunner": 0.35, "mage": 0.25},
		"position_weights": {"damage": 1.0, "survival": 0.9, "control": 0.45, "mobility": 0.35},
		"tag_weights": {"entry_burst": 1.0, "lifesteal_grind": 0.85, "guard_counter": 0.65, "armor_break": 0.7, "direct_hit": 0.55, "healing_push": 0.45},
		"link_bonus": 0.35
	},
	{
		"id": "gunner_main",
		"title": "枪手主轴",
		"role_weights": {"gunner": 3.0, "swordsman": 0.35, "mage": 0.35},
		"position_weights": {"damage": 1.05, "support": 0.65, "resource": 0.55, "control": 0.35},
		"tag_weights": {"projectile_storm": 1.0, "mark_execute": 0.85, "overdrive": 0.8, "marked": 0.7, "projectile_chain": 0.75, "resource_loop": 0.5},
		"link_bonus": 0.35
	},
	{
		"id": "mage_main",
		"title": "术师主轴",
		"role_weights": {"mage": 3.0, "gunner": 0.35, "swordsman": 0.25},
		"position_weights": {"control": 1.0, "damage": 0.8, "support": 0.75, "resource": 0.65, "summon": 0.45},
		"tag_weights": {"domain_blast": 1.0, "control_lock": 0.85, "ultimate_cycle": 0.75, "field": 0.75, "slowed": 0.65, "field_tick": 0.7},
		"link_bonus": 0.35
	},
	{
		"id": "balanced_trio",
		"title": "三人均衡",
		"role_weights": {"swordsman": 1.0, "gunner": 1.0, "mage": 1.0},
		"position_weights": {"damage": 0.7, "control": 0.7, "survival": 0.6, "support": 0.6, "resource": 0.45},
		"tag_weights": {"entry_burst": 0.45, "projectile_storm": 0.45, "domain_blast": 0.45, "guard": 0.35, "marked": 0.35, "field": 0.35},
		"prefer_underused_roles": true,
		"link_bonus": 1.0
	},
	{
		"id": "resonance_hunter",
		"title": "共鸣猎手",
		"role_weights": {"swordsman": 0.9, "gunner": 0.9, "mage": 0.9},
		"position_weights": {"damage": 0.55, "control": 0.55, "support": 0.55, "resource": 0.45},
		"tag_weights": {"armor_break": 0.5, "marked": 0.5, "field": 0.5, "overdrive": 0.45, "charge": 0.45, "guard": 0.45},
		"prefer_underused_roles": true,
		"link_bonus": 1.8
	},
	{
		"id": "summon_support",
		"title": "召唤支援",
		"role_weights": {"mage": 1.2, "gunner": 1.0, "swordsman": 0.9},
		"position_weights": {"summon": 1.2, "support": 1.0, "survival": 0.75, "control": 0.55},
		"tag_weights": {"summon_swarm": 1.0, "summon_unit": 0.9, "command_summon": 0.75, "guard": 0.6, "healing_push": 0.55, "field": 0.45},
		"link_bonus": 0.9
	},
	{
		"id": "ultimate_cycle",
		"title": "大招循环",
		"role_weights": {"mage": 1.25, "gunner": 1.0, "swordsman": 0.75},
		"position_weights": {"resource": 1.1, "support": 0.75, "damage": 0.55, "control": 0.45},
		"tag_weights": {"ultimate_cycle": 1.1, "resource_loop": 0.9, "charge": 0.8, "overdrive": 0.55, "projectile_storm": 0.35, "domain_blast": 0.35},
		"link_bonus": 0.85
	},
	{
		"id": "pivot_sword_to_gunner",
		"title": "剑转枪",
		"pivot_level": 13,
		"early_role_weights": {"swordsman": 3.0, "gunner": 0.4, "mage": 0.2},
		"late_role_weights": {"gunner": 2.8, "swordsman": 0.9, "mage": 0.3},
		"position_weights": {"damage": 1.0, "support": 0.55, "control": 0.45, "resource": 0.35},
		"tag_weights": {"entry_burst": 0.7, "armor_break": 0.65, "projectile_storm": 0.8, "mark_execute": 0.75, "marked": 0.6},
		"link_bonus": 0.9
	},
	{
		"id": "pivot_gunner_to_mage",
		"title": "枪转术",
		"pivot_level": 13,
		"early_role_weights": {"gunner": 3.0, "mage": 0.4, "swordsman": 0.2},
		"late_role_weights": {"mage": 2.8, "gunner": 0.9, "swordsman": 0.3},
		"position_weights": {"damage": 0.9, "control": 0.75, "support": 0.65, "resource": 0.45},
		"tag_weights": {"projectile_storm": 0.65, "marked": 0.75, "domain_blast": 0.85, "field": 0.75, "ultimate_cycle": 0.55},
		"link_bonus": 0.9
	},
	{
		"id": "pivot_mage_to_sword",
		"title": "术转剑",
		"pivot_level": 13,
		"early_role_weights": {"mage": 3.0, "swordsman": 0.4, "gunner": 0.2},
		"late_role_weights": {"swordsman": 2.8, "mage": 0.9, "gunner": 0.3},
		"position_weights": {"control": 0.75, "damage": 0.85, "survival": 0.65, "mobility": 0.35},
		"tag_weights": {"domain_blast": 0.65, "field": 0.75, "slowed": 0.65, "entry_burst": 0.85, "lifesteal_grind": 0.55},
		"link_bonus": 0.9
	},
	{
		"id": "bad_scattered",
		"title": "低协同散选",
		"is_bad_policy": true,
		"role_weights": {"swordsman": -0.4, "gunner": -0.4, "mage": -0.4},
		"position_weights": {"damage": -0.25, "control": -0.2, "survival": -0.15, "support": -0.15, "summon": -0.1, "resource": -0.1},
		"tag_weights": {},
		"link_bonus": -1.0
	}
]


static func analyze_first_batch() -> Dictionary:
	var runs: Array = []
	for policy in POLICY_DEFINITIONS:
		runs.append(simulate_policy(policy))
	var dominance := analyze_dominance(runs)
	return {
		"milestones": MILESTONES.duplicate(),
		"runs": runs,
		"dominance": dominance,
		"stage_summary": _make_stage_summary(runs)
	}


static func simulate_policy(policy: Dictionary) -> Dictionary:
	var state := FIRST_BATCH_MODEL.make_state(1)
	var picks: Array[String] = []
	var timeline: Array = []
	for level in range(1, FINAL_LEVEL + 1):
		state = FIRST_BATCH_MODEL.with_team_level(state, level)
		var options := FIRST_BATCH_MODEL.build_upgrade_options(state)
		var pick := choose_option(state, options, policy, level)
		if not pick.is_empty():
			var pick_id := str(pick.get("id", ""))
			state = FIRST_BATCH_MODEL.apply_card_pick(state, pick_id)
			picks.append(pick_id)
		if MILESTONES.has(level):
			timeline.append(make_stage_snapshot(state, level))
	return {
		"policy_id": str(policy.get("id", "")),
		"title": str(policy.get("title", policy.get("id", ""))),
		"is_bad_policy": bool(policy.get("is_bad_policy", false)),
		"aggregate_score": _aggregate_timeline_score(timeline),
		"risk_score": _aggregate_timeline_risk(timeline),
		"timeline": timeline,
		"picks": picks,
		"final_state": state
	}


static func choose_option(state: Dictionary, options: Array, policy: Dictionary, level: int) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -999999.0
	for option_variant in options:
		var option: Dictionary = option_variant
		var score := score_option_for_policy(state, option, policy, level)
		if score > best_score or (is_equal_approx(score, best_score) and str(option.get("id", "")) < str(best.get("id", "~"))):
			best = option.duplicate(true)
			best_score = score
	return best


static func score_option_for_policy(state: Dictionary, card: Dictionary, policy: Dictionary, level: int) -> float:
	var score := 0.0
	var slot := str(card.get("offer_slot", FIRST_BATCH_MODEL.SLOT_CONTINUE))
	score += FIRST_BATCH_MODEL.score_card_for_slot(state, card, slot) * 0.15
	score += _weighted_match(card.get("role_weights", {}), _get_policy_role_weights(policy, level)) * 2.2
	score += _weighted_match(card.get("position_weights", {}), policy.get("position_weights", {})) * 1.7
	score += _card_tag_match(card, policy.get("tag_weights", {})) * 1.25
	score += _link_policy_bonus(card, policy)
	if bool(policy.get("prefer_underused_roles", false)):
		score += _underused_role_pick_bonus(card, state) * 1.2
	if bool(card.get("has_independent_cooldown", false)):
		score += 0.35
	if str(card.get("card_type", "")) == FIRST_BATCH_DB.CARD_TYPE_CAPSTONE and level >= 18:
		score += 0.8
	if bool(policy.get("is_bad_policy", false)):
		score = _score_bad_policy_pick(state, card)
	return score


static func make_stage_snapshot(state: Dictionary, level: int) -> Dictionary:
	var strength := evaluate_strength(state, level)
	var enemy_pressure := ENEMY_PRESSURE_MODEL.get_enemy_pressure_for_team_level(level)
	var pressure_fit := ENEMY_PRESSURE_MODEL.evaluate_build_against_pressure(state, enemy_pressure)
	return {
		"level": level,
		"strength": strength,
		"score": float(strength.get("total", 0.0)),
		"enemy_pressure": enemy_pressure,
		"pressure_fit": pressure_fit,
		"risk": float(pressure_fit.get("danger_ratio", 0.0)),
		"role_investment": (state.get("role_investment", {}) as Dictionary).duplicate(true),
		"package_depth": (state.get("package_depth", {}) as Dictionary).duplicate(true),
		"edge_level": (state.get("edge_level", {}) as Dictionary).duplicate(true),
		"position_points": (state.get("position_points", {}) as Dictionary).duplicate(true),
		"role_entropy": _effective_count(state.get("role_investment", {})),
		"position_entropy": _effective_count(state.get("position_points", {})),
		"mastery_count": FIRST_BATCH_MODEL.get_triggered_mastery_nodes(state).size()
	}


static func evaluate_strength(state: Dictionary, level: int) -> Dictionary:
	var card_score := 0.0
	var independent_passives := 0
	var capstones := 0
	var resonance_levels := 0
	var produce_totals := {}
	var consume_totals := {}
	var card_levels: Dictionary = state.get("card_levels", {})
	for card_id in card_levels.keys():
		var card := FIRST_BATCH_DB.get_card_data(str(card_id))
		if card.is_empty():
			continue
		var card_level := int(card_levels.get(card_id, 0))
		card_score += _card_stage_strength(card, level) * _upgrade_level_factor(card_level)
		_add_weight_map(produce_totals, card.get("produce_weights", {}), float(card_level))
		_add_weight_map(consume_totals, card.get("consume_weights", {}), float(card_level))
		if bool(card.get("has_independent_cooldown", false)):
			independent_passives += card_level
		var card_type := str(card.get("card_type", ""))
		if card_type == FIRST_BATCH_DB.CARD_TYPE_CAPSTONE:
			capstones += card_level
		elif card_type == FIRST_BATCH_DB.CARD_TYPE_RESONANCE_PAIR or card_type == FIRST_BATCH_DB.CARD_TYPE_RESONANCE_TRI:
			resonance_levels += card_level

	var edge_total := _sum_values(state.get("edge_level", {}))
	var package_total := _sum_capped_values(state.get("package_depth", {}), 8.0)
	var closure_score := _closure_score(produce_totals, consume_totals)
	var role_eff := _effective_count(state.get("role_investment", {}))
	var position_eff := _effective_count(state.get("position_points", {}))
	var mastery_count := FIRST_BATCH_MODEL.get_triggered_mastery_nodes(state).size()
	var synergy_score := 0.0
	synergy_score += edge_total * _stage_edge_weight(level)
	synergy_score += package_total * 0.32
	synergy_score += closure_score * _stage_closure_weight(level)
	synergy_score += max(0.0, role_eff - 1.0) * 1.1
	synergy_score += max(0.0, position_eff - 1.0) * 0.55
	synergy_score += float(resonance_levels) * _stage_resonance_weight(level)
	synergy_score += float(capstones) * (2.2 if level >= 18 else 0.35)
	synergy_score += float(independent_passives) * (0.85 if level >= 12 else 0.25)
	synergy_score += float(mastery_count) * 2.0
	return {
		"total": card_score + synergy_score,
		"card_score": card_score,
		"synergy_score": synergy_score,
		"edge_total": edge_total,
		"package_total": package_total,
		"closure_score": closure_score,
		"role_effective_count": role_eff,
		"position_effective_count": position_eff,
		"resonance_levels": resonance_levels,
		"capstones": capstones,
		"independent_passives": independent_passives
	}


static func analyze_dominance(runs: Array) -> Dictionary:
	var reasonable := _reasonable_runs(runs)
	reasonable.sort_custom(Callable(BuildFirstBatchBalanceSorter, "sort_by_aggregate_desc"))
	var top: Dictionary = reasonable[0] if not reasonable.is_empty() else {}
	var runner_up: Dictionary = reasonable[1] if reasonable.size() > 1 else {}
	var top_score := float(top.get("aggregate_score", 0.0))
	var runner_score: float = max(0.001, float(runner_up.get("aggregate_score", 0.0)))
	var aggregate_gap: float = top_score / runner_score
	var close_policy_count := 0
	for run in reasonable:
		if float((run as Dictionary).get("aggregate_score", 0.0)) >= top_score * DOMINANCE_CLOSE_POLICY_RATIO:
			close_policy_count += 1
	var stage_winners := _stage_winners(reasonable)
	var top_win_count := 0
	var top_large_win_count := 0
	for milestone in MILESTONES:
		var winner: Dictionary = (stage_winners.get(milestone, {}) as Dictionary)
		if str(winner.get("policy_id", "")) == str(top.get("policy_id", "")):
			top_win_count += 1
			if float(winner.get("gap", 1.0)) > 1.10:
				top_large_win_count += 1
	var bad_run := _find_run(runs, "bad_scattered")
	var median_final := _median_final_score(reasonable)
	var bad_final := _final_score(bad_run)
	var bad_is_weaker := bad_final <= median_final * BAD_POLICY_FINAL_RATIO_LIMIT
	var has_obvious_optimum: bool = aggregate_gap > DOMINANCE_AGGREGATE_GAP_LIMIT
	if close_policy_count < DOMINANCE_MIN_CLOSE_POLICIES:
		has_obvious_optimum = true
	if top_win_count == MILESTONES.size() and (aggregate_gap > 1.08 or top_large_win_count >= 2):
		has_obvious_optimum = true
	return {
		"top_policy": str(top.get("policy_id", "")),
		"runner_up_policy": str(runner_up.get("policy_id", "")),
		"aggregate_gap": aggregate_gap,
		"close_policy_count": close_policy_count,
		"top_win_count": top_win_count,
		"top_large_win_count": top_large_win_count,
		"bad_policy_final_score": bad_final,
		"median_reasonable_final_score": median_final,
		"bad_policy_is_weaker": bad_is_weaker,
		"has_obvious_optimum": has_obvious_optimum,
		"stage_winners": stage_winners
	}


static func make_text_report(analysis: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("First-batch build balance report")
	lines.append("")
	lines.append("Milestone scores:")
	for run in analysis.get("runs", []):
		var data: Dictionary = run
		var cells: Array[String] = []
		for snapshot in data.get("timeline", []):
			var stage: Dictionary = snapshot
			cells.append("L%d=%.2f/risk%.2f" % [int(stage.get("level", 0)), float(stage.get("score", 0.0)), float(stage.get("risk", 0.0))])
		lines.append("- %s: %s | agg=%.2f risk=%.2f" % [str(data.get("policy_id", "")), ", ".join(cells), float(data.get("aggregate_score", 0.0)), float(data.get("risk_score", 0.0))])
	var dominance: Dictionary = analysis.get("dominance", {})
	lines.append("")
	lines.append("Dominance:")
	lines.append("- top=%s runner=%s gap=%.3f close=%d obvious=%s" % [
		str(dominance.get("top_policy", "")),
		str(dominance.get("runner_up_policy", "")),
		float(dominance.get("aggregate_gap", 0.0)),
		int(dominance.get("close_policy_count", 0)),
		str(dominance.get("has_obvious_optimum", false))
	])
	return "\n".join(lines)


static func _card_stage_strength(card: Dictionary, level: int) -> float:
	var result := 0.6
	result += _weighted_match(card.get("position_weights", {}), _stage_position_coefficients(level)) * 1.35
	result += _card_tag_match(card, _stage_tag_coefficients(level)) * 0.78
	result += _weighted_match(card.get("timing_weights", {}), _stage_timing_coefficients(level)) * 0.85
	var card_type := str(card.get("card_type", ""))
	if card_type == FIRST_BATCH_DB.CARD_TYPE_RESONANCE_PAIR:
		result += 0.9 if level >= 12 else 0.35
	elif card_type == FIRST_BATCH_DB.CARD_TYPE_RESONANCE_TRI:
		result += 1.35 if level >= 18 else 0.2
	elif card_type == FIRST_BATCH_DB.CARD_TYPE_CAPSTONE:
		result += 1.65 if level >= 18 else 0.15
	if bool(card.get("has_independent_cooldown", false)):
		result += 0.75 if level >= 12 else 0.2
	return result


static func _stage_position_coefficients(level: int) -> Dictionary:
	if level <= 6:
		return {"damage": 1.15, "survival": 0.75, "control": 0.65, "support": 0.45, "summon": 0.35, "resource": 0.45, "mobility": 0.7}
	if level <= 12:
		return {"damage": 1.05, "survival": 0.85, "control": 0.8, "support": 0.65, "summon": 0.7, "resource": 0.7, "mobility": 0.55}
	if level <= 18:
		return {"damage": 0.98, "survival": 0.88, "control": 0.92, "support": 0.82, "summon": 0.92, "resource": 0.88, "mobility": 0.45}
	return {"damage": 0.92, "survival": 0.92, "control": 0.95, "support": 0.9, "summon": 1.0, "resource": 0.98, "mobility": 0.38}


static func _stage_tag_coefficients(level: int) -> Dictionary:
	if level <= 6:
		return {"entry_burst": 1.0, "projectile_storm": 0.95, "domain_blast": 0.78, "lifesteal_grind": 0.72, "mark_execute": 0.55, "ultimate_cycle": 0.35, "summon_swarm": 0.35, "healing_push": 0.45, "control_lock": 0.58, "direct_hit": 0.8, "projectile_chain": 0.8, "field_tick": 0.55}
	if level <= 12:
		return {"entry_burst": 0.9, "projectile_storm": 0.9, "domain_blast": 0.88, "lifesteal_grind": 0.78, "mark_execute": 0.75, "ultimate_cycle": 0.65, "summon_swarm": 0.72, "healing_push": 0.68, "control_lock": 0.76, "direct_hit": 0.72, "projectile_chain": 0.78, "field_tick": 0.75}
	if level <= 18:
		return {"entry_burst": 0.82, "projectile_storm": 0.86, "domain_blast": 0.94, "lifesteal_grind": 0.82, "mark_execute": 0.9, "ultimate_cycle": 0.88, "summon_swarm": 0.94, "healing_push": 0.82, "control_lock": 0.9, "direct_hit": 0.68, "projectile_chain": 0.75, "field_tick": 0.88}
	return {"entry_burst": 0.76, "projectile_storm": 0.82, "domain_blast": 0.98, "lifesteal_grind": 0.85, "mark_execute": 0.92, "ultimate_cycle": 1.0, "summon_swarm": 1.02, "healing_push": 0.9, "control_lock": 0.95, "direct_hit": 0.62, "projectile_chain": 0.72, "field_tick": 0.92}


static func _stage_timing_coefficients(level: int) -> Dictionary:
	if level <= 6:
		return {"entry": 0.65, "exit": 0.35, "active": 0.48, "ultimate": 0.15}
	if level <= 12:
		return {"entry": 0.5, "exit": 0.45, "active": 0.55, "ultimate": 0.32}
	if level <= 18:
		return {"entry": 0.42, "exit": 0.5, "active": 0.58, "ultimate": 0.5}
	return {"entry": 0.38, "exit": 0.55, "active": 0.6, "ultimate": 0.62}


static func _stage_edge_weight(level: int) -> float:
	return 0.3 if level <= 6 else (0.45 if level <= 12 else (0.58 if level <= 18 else 0.65))


static func _stage_closure_weight(level: int) -> float:
	return 0.18 if level <= 6 else (0.32 if level <= 12 else (0.45 if level <= 18 else 0.52))


static func _stage_resonance_weight(level: int) -> float:
	return 0.25 if level <= 6 else (0.75 if level <= 12 else (1.15 if level <= 18 else 1.25))


static func _upgrade_level_factor(card_level: int) -> float:
	if card_level <= 0:
		return 0.0
	return 1.0 + max(0, card_level - 1) * 0.72


static func _aggregate_timeline_score(timeline: Array) -> float:
	var weights := {6: 0.16, 12: 0.24, 18: 0.30, 25: 0.30}
	var result := 0.0
	for snapshot in timeline:
		var data: Dictionary = snapshot
		result += float(data.get("score", 0.0)) * float(weights.get(int(data.get("level", 0)), 0.0))
	return result


static func _aggregate_timeline_risk(timeline: Array) -> float:
	var weights := {6: 0.16, 12: 0.24, 18: 0.30, 25: 0.30}
	var result := 0.0
	for snapshot in timeline:
		var data: Dictionary = snapshot
		result += float(data.get("risk", 0.0)) * float(weights.get(int(data.get("level", 0)), 0.0))
	return result


static func _link_policy_bonus(card: Dictionary, policy: Dictionary) -> float:
	var card_type := str(card.get("card_type", ""))
	var link_bonus := float(policy.get("link_bonus", 0.0))
	if card_type == FIRST_BATCH_DB.CARD_TYPE_RESONANCE_PAIR:
		return link_bonus * 1.0
	if card_type == FIRST_BATCH_DB.CARD_TYPE_RESONANCE_TRI:
		return link_bonus * 1.35
	if card_type == FIRST_BATCH_DB.CARD_TYPE_CAPSTONE:
		return max(0.0, link_bonus) * 0.45
	return 0.0


static func _get_policy_role_weights(policy: Dictionary, level: int) -> Dictionary:
	if policy.has("pivot_level"):
		if level < int(policy.get("pivot_level", 999)):
			return policy.get("early_role_weights", {})
		return policy.get("late_role_weights", {})
	return policy.get("role_weights", {})


static func _card_tag_match(card: Dictionary, weights_variant: Variant) -> float:
	var result := 0.0
	for map_key in ["function_weights", "mechanic_weights", "archetype_weights", "produce_weights", "consume_weights", "amplify_weights"]:
		result += _weighted_match(card.get(map_key, {}), weights_variant)
	return result


static func _weighted_match(values_variant: Variant, weights_variant: Variant) -> float:
	if values_variant is not Dictionary or weights_variant is not Dictionary:
		return 0.0
	var values: Dictionary = values_variant
	var weights: Dictionary = weights_variant
	var result := 0.0
	for key in values.keys():
		result += float(values.get(key, 0.0)) * float(weights.get(key, 0.0))
	return result


static func _underused_role_pick_bonus(card: Dictionary, state: Dictionary) -> float:
	var role_weights: Dictionary = card.get("role_weights", {})
	if role_weights.is_empty():
		return 0.3
	var investments: Dictionary = state.get("role_investment", {})
	var result := 0.0
	for role_id in role_weights.keys():
		result += max(0.0, 2.5 - float(investments.get(role_id, 0.0))) * float(role_weights.get(role_id, 0.0))
	return result


static func _score_bad_policy_pick(state: Dictionary, card: Dictionary) -> float:
	var score := 0.0
	score -= _card_stage_strength(card, int(state.get("team_level", 1)))
	score -= _card_tag_match(card, state.get("tag_points", {})) * 0.4
	score -= _weighted_match(card.get("role_weights", {}), state.get("role_investment", {})) * 0.4
	score -= _weighted_match(card.get("edge_weights", {}), state.get("edge_level", {})) * 0.8
	if str(card.get("card_type", "")) == FIRST_BATCH_DB.CARD_TYPE_GENERIC:
		score += 1.5
	return score


static func _closure_score(produce_totals: Dictionary, consume_totals: Dictionary) -> float:
	var keys := {}
	for key in produce_totals.keys():
		keys[key] = true
	for key in consume_totals.keys():
		keys[key] = true
	var result := 0.0
	for key in keys.keys():
		result += min(float(produce_totals.get(key, 0.0)), float(consume_totals.get(key, 0.0)))
	return result


static func _effective_count(values_variant: Variant) -> float:
	if values_variant is not Dictionary:
		return 0.0
	var values: Dictionary = values_variant
	var total := _sum_values(values)
	if total <= 0.0001:
		return 0.0
	var sum_sq := 0.0
	for key in values.keys():
		var p := float(values.get(key, 0.0)) / total
		sum_sq += p * p
	if sum_sq <= 0.0001:
		return 0.0
	return 1.0 / sum_sq


static func _sum_values(values_variant: Variant) -> float:
	if values_variant is not Dictionary:
		return 0.0
	var result := 0.0
	for key in (values_variant as Dictionary).keys():
		result += float((values_variant as Dictionary).get(key, 0.0))
	return result


static func _sum_capped_values(values_variant: Variant, cap_value: float) -> float:
	if values_variant is not Dictionary:
		return 0.0
	var result := 0.0
	for key in (values_variant as Dictionary).keys():
		result += min(cap_value, float((values_variant as Dictionary).get(key, 0.0)))
	return result


static func _add_weight_map(target: Dictionary, weights_variant: Variant, level_factor: float = 1.0) -> void:
	if weights_variant is not Dictionary:
		return
	var weights: Dictionary = weights_variant
	for key in weights.keys():
		target[key] = float(target.get(key, 0.0)) + float(weights.get(key, 0.0)) * level_factor


static func _reasonable_runs(runs: Array) -> Array:
	var result: Array = []
	for run in runs:
		if not bool((run as Dictionary).get("is_bad_policy", false)):
			result.append(run)
	return result


static func _stage_winners(runs: Array) -> Dictionary:
	var result := {}
	for milestone in MILESTONES:
		var ordered: Array = []
		for run in runs:
			var score := _score_at_level(run, milestone)
			ordered.append({"policy_id": str((run as Dictionary).get("policy_id", "")), "score": score})
		ordered.sort_custom(Callable(BuildFirstBatchBalanceSorter, "sort_stage_desc"))
		var winner: Dictionary = ordered[0]
		var second: Dictionary = ordered[1] if ordered.size() > 1 else {"score": 0.001}
		winner["gap"] = float(winner.get("score", 0.0)) / max(0.001, float(second.get("score", 0.0)))
		result[milestone] = winner
	return result


static func _make_stage_summary(runs: Array) -> Dictionary:
	var result := {}
	for milestone in MILESTONES:
		var scores: Array[float] = []
		for run in runs:
			if bool((run as Dictionary).get("is_bad_policy", false)):
				continue
			scores.append(_score_at_level(run, milestone))
		scores.sort()
		result[milestone] = {
			"min": scores[0] if not scores.is_empty() else 0.0,
			"median": scores[int(scores.size() / 2)] if not scores.is_empty() else 0.0,
			"max": scores[scores.size() - 1] if not scores.is_empty() else 0.0
		}
	return result


static func _find_run(runs: Array, policy_id: String) -> Dictionary:
	for run in runs:
		if str((run as Dictionary).get("policy_id", "")) == policy_id:
			return (run as Dictionary)
	return {}


static func _score_at_level(run_variant: Variant, level: int) -> float:
	if run_variant is not Dictionary:
		return 0.0
	var run: Dictionary = run_variant
	for snapshot in run.get("timeline", []):
		var data: Dictionary = snapshot
		if int(data.get("level", 0)) == level:
			return float(data.get("score", 0.0))
	return 0.0


static func _final_score(run: Dictionary) -> float:
	return _score_at_level(run, FINAL_LEVEL)


static func _median_final_score(runs: Array) -> float:
	var scores: Array[float] = []
	for run in runs:
		scores.append(_final_score(run))
	scores.sort()
	if scores.is_empty():
		return 0.0
	return scores[int(scores.size() / 2)]


class BuildFirstBatchBalanceSorter:
	static func sort_by_aggregate_desc(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("aggregate_score", 0.0)) > float(b.get("aggregate_score", 0.0))

	static func sort_stage_desc(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
