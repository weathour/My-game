extends SceneTree

const PlayerBlessingSystem := preload("res://scripts/player/player_blessing_system.gd")
const PlayerBlessingSkillState := preload("res://scripts/player/player_blessing_skill_state.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_low_level_tier_one_only()
	_check_tier_two_independent_offer_after_level_twelve()
	_check_tier_two_weight_increases_with_level()
	_check_blessing_offer_refresh_is_once_per_offer()
	_check_blessings_stack_to_level_cap()
	_check_random_and_tier_specific_blessing_rewards()
	_check_manual_compose_from_tier_one_level_three()
	_check_role_bound_state()
	_check_skill_bound_state_is_record_only()
	_check_blessing_skill_unlock_and_binding()
	_check_new_blessing_skill_unlocks()
	_check_tier_two_counts_as_three_for_skill_recipes()
	_check_tier_two_equivalent_recipe_lock()
	_check_basic_attack_evolution_does_not_lock_recipe()
	_check_locked_blessing_offer_display_count()
	_check_locked_blessing_cap_uses_available_count()
	_check_multi_skill_blessing_binding_choice()
	_check_skipped_binding_locks_one_material()
	_check_skill_unlock_uses_skill_role_not_active_role()
	_check_ultimate_skills_are_always_available_and_evolve()
	_check_shared_entry_skills_unlock_and_do_not_lock_materials()
	_check_shared_entry_skills_visible_in_role_graph()
	if failures.is_empty():
		print("PLAYER_BLESSING_SYSTEM_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_low_level_tier_one_only() -> void:
	var owner := _OwnerStub.new()
	owner.level = 3
	var offer: Dictionary = PlayerBlessingSystem.build_offer_for_owner(owner)
	var options: Array = offer.get("options", [])
	if options.size() != 3:
		failures.append("low level blessing offer should provide 3 options, got %d" % options.size())
	for option in options:
		if option is Dictionary and int((option as Dictionary).get("blessing_tier", 0)) != 1:
			failures.append("levels before 12 should only offer tier I blessings: %s" % str(option))


func _check_tier_two_independent_offer_after_level_twelve() -> void:
	var owner := _OwnerStub.new()
	owner.level = 15
	var saw_tier_two := false
	for index in range(60):
		var offer: Dictionary = PlayerBlessingSystem.build_offer_for_owner(owner)
		for option in offer.get("options", []):
			if option is Dictionary and int((option as Dictionary).get("blessing_tier", 0)) == 2:
				saw_tier_two = true
				break
		if saw_tier_two:
			break
	if not saw_tier_two:
		failures.append("tier II should be independently offerable after level 12 without tier I x3")


func _check_tier_two_weight_increases_with_level() -> void:
	var low_owner := _OwnerStub.new()
	low_owner.level = 12
	var high_owner := _OwnerStub.new()
	high_owner.level = 20
	var low_count := _count_tier_two_options(low_owner, 80)
	var high_count := _count_tier_two_options(high_owner, 80)
	if high_count <= low_count:
		failures.append("tier II should become more common at higher levels, low=%d high=%d" % [low_count, high_count])


func _check_blessing_offer_refresh_is_once_per_offer() -> void:
	var owner := _OwnerStub.new()
	owner.level = 8
	var offer: Dictionary = PlayerBlessingSystem.build_offer_for_owner(owner)
	var context: Dictionary = offer.get("context", {})
	if int(context.get("refresh_limit", 0)) != 1 or int(context.get("refresh_remaining", 0)) != 1:
		failures.append("blessing offer should start with one refresh, got %s" % str(context))
	var refreshed_offer: Dictionary = PlayerBlessingSystem.refresh_offer_for_owner(owner, offer)
	var refreshed_context: Dictionary = refreshed_offer.get("context", {})
	if int(refreshed_context.get("refresh_limit", 0)) != 1 or int(refreshed_context.get("refresh_remaining", 0)) != 0:
		failures.append("blessing offer refresh should be consumed after one use, got %s" % str(refreshed_context))
	var next_offer: Dictionary = PlayerBlessingSystem.build_offer_for_owner(owner)
	var next_context: Dictionary = next_offer.get("context", {})
	if int(next_context.get("refresh_limit", 0)) != 1 or int(next_context.get("refresh_remaining", 0)) != 1:
		failures.append("new blessing offer should restore one refresh, got %s" % str(next_context))


func _check_blessings_stack_to_level_cap() -> void:
	var owner := _OwnerStub.new()
	for _index in range(8):
		if not PlayerBlessingSystem.apply_option(owner, "blessing:blazing_sun:1"):
			failures.append("repeatable blessing option did not apply")
			return
	var level := int(((owner.role_blessing_levels.get("swordsman", {}) as Dictionary).get("blazing_sun", {}) as Dictionary).get(1, 0))
	if level != 6:
		failures.append("blessings should stack up to x6 and then cap, got x%d" % level)


func _check_random_and_tier_specific_blessing_rewards() -> void:
	var owner := _OwnerStub.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1221
	var granted: Array[String] = PlayerBlessingSystem.grant_random_blessings(owner, 1, 3, rng)
	if granted.size() != 3:
		failures.append("small boss fallback should grant three tier I blessings, got %s" % str(granted))
	var total_tier_one := 0
	for role_id in ["swordsman", "gunner", "mage"]:
		var role_levels: Dictionary = owner.role_blessing_levels.get(role_id, {})
		for blessing_levels in role_levels.values():
			total_tier_one += int((blessing_levels as Dictionary).get(1, 0))
		break
	for blessing_levels in owner.skill_blessing_levels.values():
		total_tier_one += int((blessing_levels as Dictionary).get(1, 0))
	if total_tier_one != 3:
		failures.append("random tier I blessing grant should add exactly three tier I counts, got %d" % total_tier_one)

	var tier_owner := _OwnerStub.new()
	tier_owner.level = 1
	var tier_offer: Dictionary = PlayerBlessingSystem.build_tier_offer_for_owner(tier_owner, 2)
	for option in tier_offer.get("options", []):
		if option is Dictionary and str((option as Dictionary).get("id", "")) != "blessing_blank_continue" and int((option as Dictionary).get("blessing_tier", 0)) != 2:
			failures.append("boss fallback tier-specific offer should only include tier II blessings, got %s" % str(option))


func _count_tier_two_options(owner, rolls: int) -> int:
	var count := 0
	for _index in range(rolls):
		var offer: Dictionary = PlayerBlessingSystem.build_offer_for_owner(owner)
		for option in offer.get("options", []):
			if option is Dictionary and int((option as Dictionary).get("blessing_tier", 0)) == 2:
				count += 1
	return count


func _check_manual_compose_from_tier_one_level_three() -> void:
	var owner := _OwnerStub.new()
	owner.role_blessing_levels["swordsman"]["divine_grace"] = {1: 3}
	if not PlayerBlessingSystem.can_compose_role_blessing(owner, "swordsman", "divine_grace"):
		failures.append("role blessing should be composable at tier I Lv.3")
	if not PlayerBlessingSystem.compose_role_blessing(owner, "swordsman", "divine_grace"):
		failures.append("role blessing compose should succeed")
	var levels: Dictionary = owner.role_blessing_levels["swordsman"]["divine_grace"]
	if int(levels.get(1, 0)) != 0 or int(levels.get(2, 0)) != 1:
		failures.append("compose should consume I Lv.3 and add II Lv.1, got %s" % str(levels))
	for role_id in ["swordsman", "gunner", "mage"]:
		var shared_levels: Dictionary = (owner.role_blessing_levels.get(role_id, {}) as Dictionary).get("divine_grace", {})
		if int(shared_levels.get(1, 0)) != 0 or int(shared_levels.get(2, 0)) != 1:
			failures.append("composed role blessing should be shared by all roles, got %s=%s" % [role_id, str(shared_levels)])
	if PlayerBlessingSystem.can_compose_role_blessing(owner, "swordsman", "divine_grace"):
		failures.append("same blessing should not be composable again without another three tier I levels")
	for _index in range(3):
		PlayerBlessingSystem.apply_option(owner, "blessing:divine_grace:1")
	if not PlayerBlessingSystem.can_compose_role_blessing(owner, "swordsman", "divine_grace"):
		failures.append("same blessing should be composable again after collecting another three tier I levels")
	if not PlayerBlessingSystem.compose_role_blessing(owner, "swordsman", "divine_grace"):
		failures.append("repeat compose should succeed")
	levels = owner.role_blessing_levels["swordsman"]["divine_grace"]
	if int(levels.get(1, 0)) != 0 or int(levels.get(2, 0)) != 2:
		failures.append("repeat compose should consume another I Lv.3 and add II Lv.2, got %s" % str(levels))
	for _index in range(12):
		PlayerBlessingSystem.apply_option(owner, "blessing:divine_grace:1")
		PlayerBlessingSystem.compose_role_blessing(owner, "swordsman", "divine_grace")
	levels = owner.role_blessing_levels["swordsman"]["divine_grace"]
	if int(levels.get(2, 0)) != 6:
		failures.append("compose should cap tier II at x6, got %s" % str(levels))
	if PlayerBlessingSystem.can_compose_role_blessing(owner, "swordsman", "divine_grace"):
		failures.append("tier I should not compose into tier II after tier II reaches x6")


func _check_role_bound_state() -> void:
	var owner := _OwnerStub.new()
	var applied := PlayerBlessingSystem.apply_option(owner, "blessing:blazing_sun:1")
	if not applied:
		failures.append("role-bound blessing option did not apply")
	for role_id in ["swordsman", "gunner", "mage"]:
		var role_levels: Dictionary = owner.role_blessing_levels.get(role_id, {})
		var level := int((role_levels.get("blazing_sun", {}) as Dictionary).get(1, 0))
		if level != 1:
			failures.append("role-bound blessing should be shared by all roles, got %s" % str(owner.role_blessing_levels))
		var damage_bonus := PlayerBlessingSystem.get_role_stat_bonus(owner, role_id, "damage")
		if not is_equal_approx(damage_bonus, 0.02):
			failures.append("shared role-bound damage bonus mismatch for %s: %.3f" % [role_id, damage_bonus])


func _check_skill_bound_state_is_record_only() -> void:
	var owner := _OwnerStub.new()
	var speed_before := owner.speed
	var applied := PlayerBlessingSystem.apply_option(owner, "blessing:reprise:1")
	if not applied:
		failures.append("skill-bound blessing option did not apply")
	var level := int((owner.skill_blessing_levels.get("reprise", {}) as Dictionary).get(1, 0))
	if level != 1:
		failures.append("skill-bound blessing should be stored in skill state, got %s" % str(owner.skill_blessing_levels))
	if not is_equal_approx(speed_before, owner.speed):
		failures.append("skill-bound blessing should not mutate role stats before skill binding is implemented")


func _check_blessing_skill_unlock_and_binding() -> void:
	var owner := _OwnerStub.new()
	for option_id in [
		"blessing:formation_break:1",
		"blessing:blazing_sun:1"
	]:
		PlayerBlessingSystem.apply_option(owner, option_id)
	PlayerBlessingSkillState.refresh_unlocks(owner)
	if not PlayerBlessingSkillState.is_skill_unlocked(owner, PlayerBlessingSkillState.SKILL_BLADE_STORM):
		failures.append("blade storm should unlock from formation_break Lv.3 + blazing_sun Lv.3")

	owner.role_blessing_levels["swordsman"]["formation_break"] = {1: 4}
	owner.role_blessing_levels["swordsman"]["blazing_sun"] = {1: 4}
	PlayerBlessingSystem.sync_shared_role_blessings(owner)
	PlayerBlessingSkillState.refresh_unlocks(owner)
	if PlayerBlessingSkillState.get_skill_tier(owner, PlayerBlessingSkillState.SKILL_BLADE_STORM) != 2:
		failures.append("blade storm should evolve from formation_break I x3 + blazing_sun I x3")
	owner.skill_blessing_levels["tide_rain"] = {2: 3}
	owner.skill_blessing_levels["trick"] = {2: 3}
	PlayerBlessingSkillState.refresh_unlocks(owner)
	if PlayerBlessingSkillState.get_skill_tier(owner, PlayerBlessingSkillState.SKILL_BLADE_STORM) != 3:
		failures.append("blade storm should evolve to tier III from tide_rain II x3 + trick II x3")
	var bound_skill := PlayerBlessingSkillState.get_bound_skill_for_blessing(owner, "trick")
	if bound_skill != "":
		failures.append("skill-type blessings should no longer be exclusively bound, got %s" % bound_skill)
	var basic_scales := PlayerBlessingSkillState.get_skill_effect_scales(owner, "swordsman_basic_attack", "quantity_skill_count")
	if basic_scales.is_empty():
		failures.append("basic attack should read trick because it has the quantity tag")
	var blade_scales := PlayerBlessingSkillState.get_skill_effect_scales(owner, PlayerBlessingSkillState.SKILL_BLADE_STORM, "quantity_skill_count")
	if blade_scales.size() != 3:
		failures.append("blade storm should use trick II locked into its own tier III evolution recipe, got %s" % str(blade_scales))


func _check_new_blessing_skill_unlocks() -> void:
	var mage_owner := _OwnerStub.new()
	mage_owner.active_role_index = 2
	mage_owner.role_blessing_levels["mage"]["divine_grace"] = {1: 1}
	mage_owner.skill_blessing_levels["tide_rain"] = {1: 1}
	PlayerBlessingSystem.sync_shared_role_blessings(mage_owner)
	PlayerBlessingSkillState.refresh_unlocks(mage_owner)
	if not PlayerBlessingSkillState.is_skill_unlocked(mage_owner, PlayerBlessingSkillState.SKILL_META_FIELD):
		failures.append("meta field should unlock from tide_rain I x1 + divine_grace I x1")
	mage_owner.role_blessing_levels["mage"]["divine_grace"] = {1: 4}
	mage_owner.skill_blessing_levels["tide_rain"] = {1: 4}
	PlayerBlessingSystem.sync_shared_role_blessings(mage_owner)
	PlayerBlessingSkillState.refresh_unlocks(mage_owner)
	if PlayerBlessingSkillState.get_skill_tier(mage_owner, PlayerBlessingSkillState.SKILL_META_FIELD) != 2:
		failures.append("meta field should evolve to tier II from divine_grace I x3 + tide_rain I x3")
	mage_owner.role_blessing_levels["mage"]["formation_break"] = {2: 3}
	mage_owner.skill_blessing_levels["tide_rain"] = {1: 3, 2: 3}
	PlayerBlessingSystem.sync_shared_role_blessings(mage_owner)
	PlayerBlessingSkillState.refresh_unlocks(mage_owner)
	if PlayerBlessingSkillState.get_skill_tier(mage_owner, PlayerBlessingSkillState.SKILL_META_FIELD) != 3:
		failures.append("meta field should evolve to tier III from tide_rain II x3 + formation_break II x3")

	var swordsman_owner := _OwnerStub.new()
	swordsman_owner.skill_blessing_levels["trick"] = {1: 1}
	swordsman_owner.skill_blessing_levels["reprise"] = {1: 1}
	PlayerBlessingSkillState.refresh_unlocks(swordsman_owner)
	if not PlayerBlessingSkillState.is_skill_unlocked(swordsman_owner, PlayerBlessingSkillState.SKILL_CRESCENT_WAVE):
		failures.append("crescent wave should unlock from trick I Lv.3 + reprise I Lv.3")

	var gunner_owner := _OwnerStub.new()
	gunner_owner.active_role_index = 1
	gunner_owner.role_blessing_levels["gunner"]["blazing_sun"] = {1: 1}
	gunner_owner.skill_blessing_levels["tide_rain"] = {1: 1}
	PlayerBlessingSystem.sync_shared_role_blessings(gunner_owner)
	PlayerBlessingSkillState.refresh_unlocks(gunner_owner)
	if not PlayerBlessingSkillState.is_skill_unlocked(gunner_owner, PlayerBlessingSkillState.SKILL_SHRAPNEL_FIELD):
		failures.append("shrapnel field should unlock from tide_rain I Lv.3 + blazing_sun I Lv.3")


func _check_tier_two_counts_as_three_for_skill_recipes() -> void:
	var owner := _OwnerStub.new()
	owner.active_role_index = 1
	owner.skill_blessing_levels["reprise"] = {2: 1}
	owner.skill_blessing_levels["tide_rain"] = {2: 1}
	PlayerBlessingSkillState.refresh_unlocks(owner)
	if not PlayerBlessingSkillState.is_skill_unlocked(owner, PlayerBlessingSkillState.SKILL_INFINITE_RELOAD):
		failures.append("one tier II skill blessing should count as three tier I blessings for unlock recipes")

	var blade_owner := _OwnerStub.new()
	blade_owner.role_blessing_levels["swordsman"]["formation_break"] = {2: 1}
	blade_owner.role_blessing_levels["swordsman"]["blazing_sun"] = {2: 1}
	PlayerBlessingSystem.sync_shared_role_blessings(blade_owner)
	PlayerBlessingSkillState.refresh_unlocks(blade_owner)
	if not PlayerBlessingSkillState.is_skill_unlocked(blade_owner, PlayerBlessingSkillState.SKILL_BLADE_STORM):
		failures.append("one tier II role blessing should count as three tier I blessings for unlock recipes")

func _check_tier_two_equivalent_recipe_lock() -> void:
	var owner := _OwnerStub.new()
	owner.active_role_index = 2
	owner.role_blessing_levels["mage"]["divine_grace"] = {1: 3}
	owner.role_blessing_levels["mage"]["formation_break"] = {2: 1}
	owner.skill_blessing_levels["tide_rain"] = {2: 1}
	PlayerBlessingSystem.sync_shared_role_blessings(owner)
	PlayerBlessingSkillState.refresh_unlocks(owner)
	if not PlayerBlessingSkillState.is_skill_unlocked(owner, PlayerBlessingSkillState.SKILL_META_FIELD):
		failures.append("tier II tide_rain should satisfy meta field's tier I unlock requirement")
	if PlayerBlessingSkillState.is_skill_unlocked(owner, PlayerBlessingSkillState.SKILL_SURGING_WAVE):
		failures.append("same tier II tide_rain should be locked after meta field unlock and not unlock surging wave too")

func _check_basic_attack_evolution_does_not_lock_recipe() -> void:
	var owner := _OwnerStub.new()
	owner.active_role_index = 1
	owner.role_blessing_levels["gunner"]["prayer"] = {2: 3}
	owner.role_blessing_levels["gunner"]["formation_break"] = {1: 3}
	owner.skill_blessing_levels["reprise"] = {1: 3}
	owner.skill_blessing_levels["trick"] = {1: 3, 2: 3}
	owner.skill_blessing_levels["tide_rain"] = {1: 3}
	PlayerBlessingSystem.sync_shared_role_blessings(owner)
	PlayerBlessingSkillState.refresh_unlocks(owner)
	if PlayerBlessingSkillState.get_skill_tier(owner, PlayerBlessingSkillState.SKILL_GUNNER_BASIC_ATTACK) != 3:
		failures.append("gunner basic attack should evolve from prayer II x3 + trick II x3")
	if PlayerBlessingSkillState.get_skill_tier(owner, PlayerBlessingSkillState.SKILL_GUNNER_ULTIMATE) != 2:
		failures.append("basic attack evolution should not lock trick away from gunner ultimate evolution")

func _check_locked_blessing_offer_display_count() -> void:
	var owner := _OwnerStub.new()
	PlayerBlessingSystem.apply_option(owner, "blessing:formation_break:1")
	PlayerBlessingSystem.apply_option(owner, "blessing:blazing_sun:1")
	PlayerBlessingSkillState.refresh_unlocks(owner)
	var option: Dictionary = PlayerBlessingSystem._make_option(owner, "formation_break", 1)
	if not str(option.get("title", "")).contains("0/6"):
		failures.append("locked recipe blessing should display available count 0/6, got %s" % str(option.get("title", "")))

func _check_locked_blessing_cap_uses_available_count() -> void:
	var owner := _OwnerStub.new()
	owner.level = 12
	for _index in range(6):
		PlayerBlessingSystem.apply_option(owner, "blessing:formation_break:1")
	PlayerBlessingSystem.apply_option(owner, "blessing:blazing_sun:1")
	PlayerBlessingSkillState.refresh_unlocks(owner)
	var option: Dictionary = PlayerBlessingSystem._make_option(owner, "formation_break", 1)
	if not str(option.get("title", "")).contains("5/6"):
		failures.append("locked recipe material should free one blessing cap slot, got %s" % str(option.get("title", "")))
	var offer: Dictionary = PlayerBlessingSystem.build_tier_offer_for_owner(owner, 1)
	var found := false
	for offered_option in offer.get("options", []):
		if offered_option is Dictionary and str((offered_option as Dictionary).get("blessing_id", "")) == "formation_break":
			found = true
	if not found:
		failures.append("locked recipe material should remain offerable until available count reaches x6")
	PlayerBlessingSystem.apply_option(owner, "blessing:formation_break:1")
	option = PlayerBlessingSystem._make_option(owner, "formation_break", 1)
	if not str(option.get("title", "")).contains("6/6"):
		failures.append("available blessing cap should refill to 6/6 after one more pick, got %s" % str(option.get("title", "")))

func _check_multi_skill_blessing_binding_choice() -> void:
	var owner := _OwnerStub.new()
	owner.active_role_index = 2
	owner.role_blessing_levels["mage"]["divine_grace"] = {1: 1}
	owner.role_blessing_levels["mage"]["formation_break"] = {1: 1}
	owner.skill_blessing_levels["tide_rain"] = {1: 1}
	PlayerBlessingSystem.sync_shared_role_blessings(owner)
	var events: Array[Dictionary] = PlayerBlessingSkillState.refresh_unlocks(owner, "tide_rain", 1, PlayerBlessingSkillState.SKILL_BOUND)
	if events.size() != 1 or str(events[0].get("type", "")) != "binding_choice":
		failures.append("shared tide_rain should produce a binding choice when multiple skills can use it, got %s" % str(events))
		return
	var candidates: Array = events[0].get("candidates", [])
	if candidates.size() != 2:
		failures.append("binding choice should contain both candidate skills, got %s" % str(candidates))
		return
	PlayerBlessingSkillState.apply_recipe_candidate(owner, candidates[0])
	var first_skill_id := str((candidates[0] as Dictionary).get("skill_id", ""))
	if not PlayerBlessingSkillState.is_skill_unlocked(owner, first_skill_id):
		failures.append("selected binding candidate should unlock/evolve its skill")
	var second_skill_id := str((candidates[1] as Dictionary).get("skill_id", ""))
	if PlayerBlessingSkillState.is_skill_unlocked(owner, second_skill_id):
		failures.append("unselected candidate should not consume the same blessing material")
	var option: Dictionary = PlayerBlessingSystem._make_option(owner, "tide_rain", 1)
	if not str(option.get("title", "")).contains("0/6"):
		failures.append("selected binding should lock tide_rain and display 0/6, got %s" % str(option.get("title", "")))

func _check_skipped_binding_locks_one_material() -> void:
	var owner := _OwnerStub.new()
	owner.active_role_index = 2
	owner.role_blessing_levels["mage"]["divine_grace"] = {1: 1}
	owner.role_blessing_levels["mage"]["formation_break"] = {1: 1}
	owner.skill_blessing_levels["tide_rain"] = {1: 1}
	PlayerBlessingSystem.sync_shared_role_blessings(owner)
	PlayerBlessingSkillState.lock_one_blessing_material(owner, PlayerBlessingSkillState.SKILL_BOUND, "tide_rain", 1)
	var events: Array[Dictionary] = PlayerBlessingSkillState.refresh_unlocks(owner, "tide_rain", 1, PlayerBlessingSkillState.SKILL_BOUND)
	for event in events:
		if str((event as Dictionary).get("type", "")) == "binding_choice":
			failures.append("skipped binding should lock the material and avoid repeated binding prompts")
	var option: Dictionary = PlayerBlessingSystem._make_option(owner, "tide_rain", 1)
	if not str(option.get("title", "")).contains("0/6"):
		failures.append("skipped binding should display available count 0/6, got %s" % str(option.get("title", "")))


func _check_skill_unlock_uses_skill_role_not_active_role() -> void:
	var owner := _OwnerStub.new()
	owner.active_role_index = 2
	owner.role_blessing_levels["gunner"]["blazing_sun"] = {1: 1}
	owner.skill_blessing_levels["tide_rain"] = {1: 1}
	PlayerBlessingSystem.sync_shared_role_blessings(owner)
	PlayerBlessingSkillState.refresh_unlocks(owner, "", 0, "", "gunner")
	if not PlayerBlessingSkillState.is_skill_unlocked(owner, PlayerBlessingSkillState.SKILL_SHRAPNEL_FIELD):
		failures.append("shrapnel field should unlock from gunner materials when the gunner panel refreshes")


func _check_ultimate_skills_are_always_available_and_evolve() -> void:
	var owner := _OwnerStub.new()
	if not PlayerBlessingSkillState.is_skill_unlocked(owner, PlayerBlessingSkillState.SKILL_SWORDSMAN_ULTIMATE):
		failures.append("swordsman ultimate should be available as tier I without an unlock recipe")
	if PlayerBlessingSkillState.get_skill_tier(owner, PlayerBlessingSkillState.SKILL_GUNNER_ULTIMATE) != 1:
		failures.append("gunner ultimate should default to tier I")
	if PlayerBlessingSkillState.get_skill_effect_scales(owner, PlayerBlessingSkillState.SKILL_SWORDSMAN_ULTIMATE, "combo_skill_extra").size() != 0:
		failures.append("swordsman ultimate should not gain combo extras before reprise is owned")

	var swordsman_owner := _OwnerStub.new()
	swordsman_owner.skill_blessing_levels["reprise"] = {1: 3}
	swordsman_owner.role_blessing_levels["swordsman"]["blazing_sun"] = {1: 3}
	PlayerBlessingSystem.sync_shared_role_blessings(swordsman_owner)
	PlayerBlessingSkillState.refresh_unlocks(swordsman_owner)
	if PlayerBlessingSkillState.get_skill_tier(swordsman_owner, PlayerBlessingSkillState.SKILL_SWORDSMAN_ULTIMATE) != 2:
		failures.append("swordsman ultimate should evolve from reprise I x3 + blazing_sun I x3")
	var combo_scales := PlayerBlessingSkillState.get_skill_effect_scales(swordsman_owner, PlayerBlessingSkillState.SKILL_SWORDSMAN_ULTIMATE, "combo_skill_extra")
	if combo_scales.size() != 3 or not is_equal_approx(float(combo_scales[0]), 0.5):
		failures.append("tier I reprise should grant 50 percent combo visual/hit scales for ultimate, got %s" % str(combo_scales))
	swordsman_owner.role_blessing_levels["swordsman"]["blazing_sun"] = {1: 3, 2: 3}
	swordsman_owner.role_blessing_levels["swordsman"]["greed"] = {1: 3}
	PlayerBlessingSystem.sync_shared_role_blessings(swordsman_owner)
	PlayerBlessingSkillState.refresh_unlocks(swordsman_owner)
	if PlayerBlessingSkillState.get_skill_tier(swordsman_owner, PlayerBlessingSkillState.SKILL_SWORDSMAN_ULTIMATE) != 3:
		failures.append("swordsman ultimate should evolve to tier III from blazing_sun II x3 + greed I x3")

	var gunner_owner := _OwnerStub.new()
	gunner_owner.active_role_index = 1
	gunner_owner.skill_blessing_levels["tide_rain"] = {1: 3}
	gunner_owner.role_blessing_levels["gunner"]["formation_break"] = {1: 3}
	PlayerBlessingSystem.sync_shared_role_blessings(gunner_owner)
	PlayerBlessingSkillState.refresh_unlocks(gunner_owner)
	if PlayerBlessingSkillState.get_skill_tier(gunner_owner, PlayerBlessingSkillState.SKILL_GUNNER_ULTIMATE) != 2:
		failures.append("gunner ultimate should evolve from tide_rain I x3 + formation_break I x3")
	if not PlayerBlessingSkillState.get_duration_multiplier(gunner_owner, PlayerBlessingSkillState.SKILL_GUNNER_ULTIMATE) > 1.0:
		failures.append("gunner ultimate should read tide_rain because it has the duration tag")
	gunner_owner.role_blessing_levels["gunner"]["blazing_sun"] = {2: 3}
	gunner_owner.role_blessing_levels["gunner"]["formation_break"] = {1: 3, 2: 3}
	PlayerBlessingSystem.sync_shared_role_blessings(gunner_owner)
	PlayerBlessingSkillState.refresh_unlocks(gunner_owner)
	if PlayerBlessingSkillState.get_skill_tier(gunner_owner, PlayerBlessingSkillState.SKILL_GUNNER_ULTIMATE) != 3:
		failures.append("gunner ultimate should evolve to tier III from blazing_sun II x3 + formation_break II x3")

	var mage_owner := _OwnerStub.new()
	mage_owner.active_role_index = 2
	mage_owner.skill_blessing_levels["reprise"] = {1: 3}
	mage_owner.role_blessing_levels["mage"]["formation_break"] = {1: 3}
	PlayerBlessingSystem.sync_shared_role_blessings(mage_owner)
	PlayerBlessingSkillState.refresh_unlocks(mage_owner)
	if PlayerBlessingSkillState.get_skill_tier(mage_owner, PlayerBlessingSkillState.SKILL_MAGE_ULTIMATE) != 2:
		failures.append("mage ultimate should evolve from reprise I x3 + formation_break I x3")
	mage_owner.skill_blessing_levels["reprise"] = {1: 3, 2: 3}
	mage_owner.role_blessing_levels["mage"]["benediction"] = {2: 3}
	PlayerBlessingSystem.sync_shared_role_blessings(mage_owner)
	PlayerBlessingSkillState.refresh_unlocks(mage_owner)
	if PlayerBlessingSkillState.get_skill_tier(mage_owner, PlayerBlessingSkillState.SKILL_MAGE_ULTIMATE) != 3:
		failures.append("mage ultimate should evolve to tier III from reprise II x3 + benediction II x3")


func _check_shared_entry_skills_unlock_and_do_not_lock_materials() -> void:
	var owner := _OwnerStub.new()
	owner.role_blessing_levels["swordsman"]["support"] = {1: 1}
	owner.role_blessing_levels["swordsman"]["divine_grace"] = {1: 1}
	owner.skill_blessing_levels["reprise"] = {1: 1}
	PlayerBlessingSystem.sync_shared_role_blessings(owner)
	PlayerBlessingSkillState.refresh_unlocks(owner)
	if not PlayerBlessingSkillState.is_skill_unlocked(owner, PlayerBlessingSkillState.SKILL_ENTRY_RESCUE):
		failures.append("entry rescue should unlock from support I x1 + divine_grace I x1")
	if not PlayerBlessingSkillState.is_skill_unlocked(owner, PlayerBlessingSkillState.SKILL_HERO_ENTRY):
		failures.append("hero entry should unlock from support I x1 + reprise I x1")
	if not is_equal_approx(PlayerBlessingSkillState.get_entry_rescue_regen_per_second(owner), 0.525):
		failures.append("entry rescue tier I should grant 0.525 regen per second")
	if PlayerBlessingSkillState.get_hero_entry_effect(owner).get("extra_count", 0) != 1:
		failures.append("hero entry tier I should grant one extra entry segment")
	var option: Dictionary = PlayerBlessingSystem._make_option(owner, "support", 1)
	if not str(option.get("title", "")).contains("1/6"):
		failures.append("shared entry skills should not lock support materials, got %s" % str(option.get("title", "")))

	owner.role_blessing_levels["swordsman"]["support"] = {1: 3}
	owner.role_blessing_levels["swordsman"]["divine_grace"] = {1: 3}
	owner.skill_blessing_levels["reprise"] = {1: 3}
	PlayerBlessingSystem.sync_shared_role_blessings(owner)
	PlayerBlessingSkillState.refresh_unlocks(owner)
	if PlayerBlessingSkillState.get_skill_tier(owner, PlayerBlessingSkillState.SKILL_ENTRY_RESCUE) != 2:
		failures.append("entry rescue should evolve to tier II from support I x3 + divine_grace I x3")
	if PlayerBlessingSkillState.get_skill_tier(owner, PlayerBlessingSkillState.SKILL_HERO_ENTRY) != 2:
		failures.append("hero entry should evolve to tier II from support I x3 + reprise I x3")
	if not is_equal_approx(PlayerBlessingSkillState.get_entry_rescue_regen_per_second(owner), 0.975):
		failures.append("entry rescue tier II should grant 0.975 regen per second")
	if not is_equal_approx(float(PlayerBlessingSkillState.get_hero_entry_effect(owner).get("effect_scale", 0.0)), 0.5):
		failures.append("hero entry tier II should use 50 percent extra entry effect")

	owner.role_blessing_levels["swordsman"]["divine_grace"] = {1: 3, 2: 3}
	owner.role_blessing_levels["swordsman"]["support"] = {1: 3, 2: 3}
	owner.skill_blessing_levels["tide_rain"] = {2: 3}
	owner.skill_blessing_levels["reprise"] = {1: 3, 2: 3}
	PlayerBlessingSystem.sync_shared_role_blessings(owner)
	PlayerBlessingSkillState.refresh_unlocks(owner)
	if PlayerBlessingSkillState.get_skill_tier(owner, PlayerBlessingSkillState.SKILL_ENTRY_RESCUE) != 3:
		failures.append("entry rescue should evolve to tier III from tide_rain II x3 + divine_grace II x3")
	if PlayerBlessingSkillState.get_skill_tier(owner, PlayerBlessingSkillState.SKILL_HERO_ENTRY) != 3:
		failures.append("hero entry should evolve to tier III from support II x3 + reprise II x3")
	if not is_equal_approx(PlayerBlessingSkillState.get_entry_rescue_regen_per_second(owner), 1.5):
		failures.append("entry rescue tier III should grant 1.5 regen per second")
	if int(PlayerBlessingSkillState.get_hero_entry_effect(owner).get("extra_count", 0)) != 2:
		failures.append("hero entry tier III should grant two extra entry segments")


func _check_shared_entry_skills_visible_in_role_graph() -> void:
	var owner := _OwnerStub.new()
	var text := PlayerBlessingSkillState.get_skill_graph_text(owner, "swordsman")
	if not text.contains(PlayerBlessingSkillState.get_skill_title(PlayerBlessingSkillState.SKILL_ENTRY_RESCUE)):
		failures.append("shared entry rescue should be visible in role-filtered skill graph")
	if not text.contains(PlayerBlessingSkillState.get_skill_title(PlayerBlessingSkillState.SKILL_HERO_ENTRY)):
		failures.append("shared hero entry should be visible in role-filtered skill graph")


class _OwnerStub:
	var level: int = 1
	var roles: Array = [
		{"id": "swordsman", "name": "剑士"},
		{"id": "gunner", "name": "枪手"},
		{"id": "mage", "name": "术师"}
	]
	var active_role_index: int = 0
	var role_blessing_levels: Dictionary = {
		"swordsman": {},
		"gunner": {},
		"mage": {}
	}
	var skill_blessing_levels: Dictionary = {}
	var blessing_skill_state: Dictionary = {}
	var role_upgrade_levels: Dictionary = {
		"swordsman": {"damage_bonus": 0.0},
		"gunner": {"damage_bonus": 0.0},
		"mage": {"damage_bonus": 0.0}
	}
	var speed: float = 100.0
	var max_health: float = 100.0
	var current_health: float = 100.0
	var equipment_cooldown_multiplier: float = 1.0
	var equipment_skill_range_multiplier: float = 1.0
	var equipment_dodge_chance: float = 0.0
	var damage_taken_multiplier: float = 1.0
	var global_position: Vector2 = Vector2.ZERO
	var health_changed := _SignalStub.new()
	var stats_changed := _SignalStub.new()

	func _get_active_role() -> Dictionary:
		return roles[active_role_index]

	func _spawn_combat_tag(_position: Vector2, _text: String, _color: Color) -> void:
		pass

	func _update_fire_timer() -> void:
		pass

	func get_stat_summary() -> Dictionary:
		return {}

	func get_role_blessing_levels(role_id: String) -> Dictionary:
		PlayerBlessingSystem.sync_shared_role_blessings(self)
		return (role_blessing_levels.get(role_id, {}) as Dictionary).duplicate(true)

	func get_skill_blessing_levels() -> Dictionary:
		skill_blessing_levels = PlayerBlessingSystem.normalize_skill_state(skill_blessing_levels)
		return skill_blessing_levels.duplicate(true)


class _SignalStub:
	func emit(_a = null, _b = null, _c = null, _d = null) -> void:
		pass
