extends SceneTree

const FirstBatchDB := preload("res://scripts/build/build_first_batch_database.gd")
const FirstBatchModel := preload("res://scripts/build/build_first_batch_model.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_card_catalog_shape()
	_check_role_surface_coverage()
	_check_multi_position_distinction()
	_check_team_level_gates()
	_check_swordsman_progression_and_offers()
	_check_mid_run_pivot_to_gunner()
	_check_single_refresh_offer()
	_check_triad_and_mastery()
	if failures.is_empty():
		print("BUILD_FIRST_BATCH_MODEL_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_card_catalog_shape() -> void:
	var ids: Array = FirstBatchDB.get_offer_card_ids()
	if ids.size() != 35:
		failures.append("complete first batch should define 35 offer cards, got %d" % ids.size())
	_check_type_count(FirstBatchDB.CARD_TYPE_HERO, 18)
	_check_type_count(FirstBatchDB.CARD_TYPE_CAPSTONE, 3)
	_check_type_count(FirstBatchDB.CARD_TYPE_RESONANCE_PAIR, 6)
	_check_type_count(FirstBatchDB.CARD_TYPE_RESONANCE_TRI, 3)
	_check_type_count(FirstBatchDB.CARD_TYPE_GENERIC, 5)
	if FirstBatchDB.get_mastery_nodes().size() != 3:
		failures.append("complete first batch should define 3 mastery nodes")
	for card_id in ["swd_tide_unbound", "gun_infinite_fireline", "mag_sky_dome"]:
		var card := FirstBatchDB.get_card_data(card_id)
		if int(card.get("max_level", 0)) != 1:
			failures.append("capstone %s should be max level 1" % card_id)
	for card_id in ["res_swd_gun_open_fire", "res_tri_three_step_cycle"]:
		var card := FirstBatchDB.get_card_data(card_id)
		if int(card.get("max_level", 0)) != 2:
			failures.append("resonance %s should be max level 2" % card_id)

func _check_role_surface_coverage() -> void:
	for role_id in ["swordsman", "gunner", "mage"]:
		for axis in [
			FirstBatchDB.AXIS_ENTRY,
			FirstBatchDB.AXIS_EXIT,
			FirstBatchDB.AXIS_CORE_OUTPUT,
			FirstBatchDB.AXIS_ULTIMATE,
			FirstBatchDB.AXIS_CAPSTONE,
			FirstBatchDB.AXIS_INDEPENDENT_PASSIVE
		]:
			var cards := FirstBatchDB.get_cards_by_axis(role_id, axis)
			if cards.is_empty():
				failures.append("%s should have at least one %s card" % [role_id, axis])
		var passives := FirstBatchDB.get_independent_passive_cards(role_id)
		if passives.size() != 1:
			failures.append("%s should have exactly one first-batch independent passive, got %d" % [role_id, passives.size()])
		for passive in passives:
			var data: Dictionary = passive
			if str(data.get("skill_surface", "")) != FirstBatchDB.SKILL_SURFACE_INDEPENDENT_PASSIVE:
				failures.append("%s independent passive missing skill surface" % role_id)
			if not bool(data.get("has_independent_cooldown", false)):
				failures.append("%s independent passive missing independent cooldown flag" % role_id)
			if float(data.get("cooldown_seconds", 0.0)) <= 0.0:
				failures.append("%s independent passive should have positive cooldown" % role_id)
			if str(data.get("passive_family", "")) == "":
				failures.append("%s independent passive should declare a passive family" % role_id)

func _check_multi_position_distinction() -> void:
	var signature_positions := {}
	var signature_identities := {}
	for role_id in ["swordsman", "gunner", "mage"]:
		var profile := FirstBatchDB.get_role_identity_profile(role_id)
		if profile.is_empty():
			failures.append("%s should declare a role identity profile" % role_id)
			continue
		signature_positions[role_id] = str(profile.get("signature_position", ""))
		signature_identities[role_id] = str(profile.get("signature_identity", ""))
		var totals := FirstBatchDB.get_role_position_totals(role_id)
		var active_positions := _count_values_at_least(totals, 0.8)
		if active_positions < 3:
			failures.append("%s should support at least 3 positions, got %d from %s" % [role_id, active_positions, str(totals)])
		var identity_totals := FirstBatchDB.get_role_identity_totals(role_id)
		var signature_identity := str(profile.get("signature_identity", ""))
		if float(identity_totals.get(signature_identity, 0.0)) < 1.0:
			failures.append("%s signature identity %s should be represented by card data: %s" % [role_id, signature_identity, str(identity_totals)])
	if signature_positions["swordsman"] == signature_positions["gunner"] or signature_positions["swordsman"] == signature_positions["mage"] or signature_positions["gunner"] == signature_positions["mage"]:
		failures.append("roles should not share the same signature position axis: %s" % str(signature_positions))
	if signature_identities["swordsman"] == signature_identities["gunner"] or signature_identities["swordsman"] == signature_identities["mage"] or signature_identities["gunner"] == signature_identities["mage"]:
		failures.append("roles should not share the same signature identity axis: %s" % str(signature_identities))

func _check_type_count(card_type: String, expected: int) -> void:
	var cards := FirstBatchDB.get_cards_by_type(card_type)
	if cards.size() != expected:
		failures.append("card type %s expected %d cards, got %d" % [card_type, expected, cards.size()])

func _check_team_level_gates() -> void:
	var state := FirstBatchModel.make_state(1)
	var level1_ids := FirstBatchModel.get_eligible_card_ids(state)
	for locked_id in ["swd_tide_pull", "gun_fireline_mark", "mag_frost_seal", "swd_blade_shadow", "res_tri_three_step_cycle"]:
		if level1_ids.has(locked_id):
			failures.append("%s should not be eligible at team level 1" % locked_id)
	if not level1_ids.has("swd_break_step") or not level1_ids.has("gun_entry_barrage") or not level1_ids.has("mag_starfall_seed"):
		failures.append("level 1 should offer seed cards, got %s" % str(level1_ids))
	state = FirstBatchModel.with_team_level(state, 6)
	var level6_without_investment := FirstBatchModel.get_eligible_card_ids(state)
	if level6_without_investment.has("swd_tide_pull"):
		failures.append("team level alone should not unlock swordsman engine without investment")

func _check_swordsman_progression_and_offers() -> void:
	var state := FirstBatchModel.make_state(1)
	state = FirstBatchModel.apply_card_pick(state, "swd_break_step")
	state = FirstBatchModel.apply_card_pick(state, "swd_blood_echo")
	state = FirstBatchModel.with_team_level(state, 6)
	var eligible := FirstBatchModel.get_eligible_card_ids(state)
	if not eligible.has("swd_tide_pull") or not eligible.has("swd_overheal_guard"):
		failures.append("swordsman investment at team level 6 should unlock engine cards, got %s" % str(eligible))
	var options := FirstBatchModel.build_upgrade_options(state)
	_check_offer_slots(options, "swordsman level 6")
	if str(options[0].get("owner_role", "")) != "swordsman":
		failures.append("continue slot should follow swordsman investment, got %s" % str(options[0]))

	state = FirstBatchModel.apply_card_pick(state, "swd_tide_pull")
	state = FirstBatchModel.apply_card_pick(state, "swd_overheal_guard")
	state = FirstBatchModel.with_team_level(state, 12)
	eligible = FirstBatchModel.get_eligible_card_ids(state)
	if not eligible.has("swd_blade_shadow") or not eligible.has("swd_break_execute"):
		failures.append("swordsman investment at team level 12 should unlock payoff cards, got %s" % str(eligible))

func _check_mid_run_pivot_to_gunner() -> void:
	var state := FirstBatchModel.make_state(12)
	for card_id in ["swd_break_step", "swd_blood_echo", "swd_tide_pull", "swd_overheal_guard"]:
		state = FirstBatchModel.apply_card_pick(state, card_id)
	for card_id in ["gun_entry_barrage", "gun_overload_mag", "gun_fireline_mark"]:
		state = FirstBatchModel.apply_card_pick(state, card_id)
	var options := FirstBatchModel.build_upgrade_options(state)
	_check_offer_slots(options, "pivot to gunner")
	var has_gunner_or_swd_gun := false
	for option in options:
		var role := str((option as Dictionary).get("owner_role", ""))
		var id := str((option as Dictionary).get("id", ""))
		if role == "gunner" or id.begins_with("res_swd_gun") or id.begins_with("res_gun_swd"):
			has_gunner_or_swd_gun = true
	if not has_gunner_or_swd_gun:
		failures.append("after repeated gunner picks, offers should include gunner continuation or sword-gunner resonance: %s" % str(options))

func _check_single_refresh_offer() -> void:
	var state := FirstBatchModel.make_state(12)
	for card_id in ["swd_break_step", "swd_blood_echo", "swd_tide_pull", "gun_entry_barrage"]:
		state = FirstBatchModel.apply_card_pick(state, card_id)
	var offer := FirstBatchModel.build_upgrade_offer(state)
	var options: Array = offer.get("options", [])
	_check_offer_slots(options, "initial refreshable offer")
	var initial_ids := _offer_ids(options)
	var context: Dictionary = offer.get("context", {})
	if int(context.get("refresh_remaining", -1)) != 1:
		failures.append("initial offer should have one refresh remaining, got %s" % str(context))

	var refreshed := FirstBatchModel.refresh_upgrade_offer(state, offer)
	var refreshed_options: Array = refreshed.get("options", [])
	_check_offer_slots(refreshed_options, "refreshed offer")
	var refreshed_context: Dictionary = refreshed.get("context", {})
	if not bool(refreshed.get("refreshed", false)):
		failures.append("first refresh should be consumed")
	if int(refreshed_context.get("refresh_remaining", -1)) != 0:
		failures.append("refreshed offer should have zero refresh remaining, got %s" % str(refreshed_context))
	if int(refreshed_context.get("refresh_index", -1)) != 1:
		failures.append("refreshed offer should advance refresh index, got %s" % str(refreshed_context))
	for card_id in initial_ids:
		if not (refreshed_context.get("rejected_offer_ids", []) as Array).has(card_id):
			failures.append("refreshed context should remember rejected card %s, got %s" % [card_id, str(refreshed_context)])
	var overlap := 0
	var refreshed_ids := _offer_ids(refreshed_options)
	for card_id in refreshed_ids:
		if initial_ids.has(card_id):
			overlap += 1
	if overlap >= initial_ids.size() and not bool(refreshed_context.get("refresh_repair_used", false)):
		failures.append("refresh should avoid returning the exact same full offer unless repair is used")
	var state_before := state.duplicate(true)
	var _ignored := FirstBatchModel.refresh_upgrade_offer(state, refreshed)
	if str(state) != str(state_before):
		failures.append("refresh should not mutate build state")
	var second_refresh := FirstBatchModel.refresh_upgrade_offer(state, refreshed)
	if bool(second_refresh.get("refreshed", true)):
		failures.append("second refresh in same offer should be blocked")
	if int((second_refresh.get("context", {}) as Dictionary).get("refresh_remaining", -1)) != 0:
		failures.append("blocked second refresh should keep zero remaining")

func _check_triad_and_mastery() -> void:
	var state := FirstBatchModel.make_state(18)
	var picks := [
		"swd_break_step", "swd_blood_echo", "swd_tide_pull",
		"gun_entry_barrage", "gun_overload_mag", "gun_fireline_mark",
		"mag_starfall_seed", "mag_mana_tide", "mag_frost_seal",
		"res_swd_gun_open_fire", "res_gun_mag_orbital_lock", "res_mag_swd_star_cleave"
	]
	for card_id in picks:
		state = FirstBatchModel.apply_card_pick(state, card_id)
	var eligible := FirstBatchModel.get_eligible_card_ids(state)
	if not eligible.has("res_tri_three_step_cycle"):
		failures.append("three invested heroes/edges should unlock triad cycle at team level 18, got %s" % str(eligible))

	var mature := FirstBatchModel.make_state(25)
	for card_id in ["swd_break_step", "swd_blood_echo", "swd_tide_pull", "swd_overheal_guard", "swd_blade_shadow", "swd_break_execute", "swd_tide_unbound"]:
		mature = FirstBatchModel.apply_card_pick(mature, card_id)
	var masteries := FirstBatchModel.get_triggered_mastery_nodes(mature)
	var mastery_ids: Array[String] = []
	for node in masteries:
		mastery_ids.append(str((node as Dictionary).get("id", "")))
	if not mastery_ids.has("swd_break_mastery"):
		failures.append("mature swordsman package at team level 25 should trigger mastery node, got %s" % str(masteries))

func _check_offer_slots(options: Array, label: String) -> void:
	if options.size() != 3:
		failures.append("%s should generate 3 offer slots, got %d: %s" % [label, options.size(), str(options)])
		return
	var slots: Array[String] = []
	for option in options:
		slots.append(str((option as Dictionary).get("offer_slot", "")))
	if slots != ["continue", "link", "pivot"]:
		failures.append("%s slots mismatch: %s" % [label, str(slots)])

func _offer_ids(options: Array) -> Array[String]:
	var result: Array[String] = []
	for option in options:
		result.append(str((option as Dictionary).get("id", "")))
	return result

func _count_values_at_least(values: Dictionary, threshold: float) -> int:
	var result := 0
	for key in values.keys():
		if float(values.get(key, 0.0)) >= threshold:
			result += 1
	return result
