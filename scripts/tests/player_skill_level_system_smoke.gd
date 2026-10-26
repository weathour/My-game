extends SceneTree

const PLAYER_SKILL_LEVEL_SYSTEM := preload("res://scripts/player/player_skill_level_system.gd")
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")
const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")

var failures: Array[String] = []

class StateOwner:
	extends RefCounted
	var role_special_states: Variant = {}
	var property_list_reads := 0

	func _get_property_list() -> Array[Dictionary]:
		property_list_reads += 1
		return []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(20260218)
	_check_read_only_queries()
	_check_initial_levels()
	_check_unlock_gate()
	_check_level_cap_and_pending()
	_check_talent_offer_and_pick()
	_check_auto_second_slot()
	_check_build_pool_composition()
	_check_option_weight_ratio()
	_check_save_normalization()
	if failures.is_empty():
		print("PLAYER_SKILL_LEVEL_SYSTEM_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_read_only_queries() -> void:
	var owner := StateOwner.new()
	for raw_state in [{}, {"gunner": {"sentinel": 7}}, {"swordsman": null}, {"swordsman": {"build_levels": []}}, null]:
		owner.role_special_states = raw_state
		var before: Variant = raw_state.duplicate(true) if raw_state is Dictionary else raw_state
		_expect_equal(PLAYER_SKILL_LEVEL_SYSTEM.get_skill_level(owner, "swordsman", "swordsman_basic"), 0, "missing or malformed state should use LV0")
		_expect_equal(PLAYER_BUILD_SYSTEM.get_count(owner, "swordsman", "attack"), 0, "missing or malformed build state should report zero")
		_expect_equal(owner.role_special_states, before, "queries must not initialize or repair saved state")
	_expect_equal(owner.property_list_reads, 0, "queries must not enumerate the player's properties")
	PLAYER_SKILL_LEVEL_SYSTEM.add_skill_level(owner, "swordsman", "swordsman_basic")
	_expect_equal(PLAYER_SKILL_LEVEL_SYSTEM.get_skill_level(owner, "swordsman", "swordsman_basic"), 1, "a write should initialize absent LV0 skill state")
	PLAYER_BUILD_SYSTEM._increment_build_count(owner, "swordsman", "attack")
	_expect_equal(PLAYER_BUILD_SYSTEM.get_count(owner, "swordsman", "attack"), 1, "a write should initialize absent build state")
	_expect_equal(PLAYER_SKILL_LEVEL_SYSTEM.get_skill_level(owner, "swordsman", "swordsman_basic"), 1, "build writes should preserve skill levels")
	var untyped_owner := RefCounted.new()
	_expect_equal(PLAYER_SKILL_LEVEL_SYSTEM.get_skill_level(untyped_owner, "swordsman", "swordsman_basic"), 0, "owners without saved state should use LV0")
	_expect_equal(PLAYER_BUILD_SYSTEM.get_count(untyped_owner, "swordsman", "attack"), 0, "owners without saved state should report zero builds")


func _check_initial_levels() -> void:
	var owner := _make_owner()
	_expect_equal(PLAYER_SKILL_LEVEL_SYSTEM.get_skill_level(owner, "swordsman", "swordsman_trait"), 1, "natural skill lines should start at level 1")
	_expect_equal(PLAYER_SKILL_LEVEL_SYSTEM.get_skill_level(owner, "gunner", "gunner_infinite_reload"), 0, "locked active skills should report level 0")
	PLAYER_BLESSING_SKILL_STATE.force_unlock_skill(owner, "infinite_reload", 1)
	_expect_equal(PLAYER_SKILL_LEVEL_SYSTEM.get_skill_level(owner, "gunner", "gunner_infinite_reload"), 0, "custom reload unlock starts at LV0")
	_expect_equal(PLAYER_SKILL_LEVEL_SYSTEM.get_skill_level(owner, "swordsman", "swordsman_ultimate"), 1, "ultimate skills still report their level")
	owner.free()


func _check_unlock_gate() -> void:
	var owner := _make_owner()
	var locked_pool: Array = PLAYER_SKILL_LEVEL_SYSTEM.get_upgradeable_progress_ids(owner, "gunner")
	_expect(not locked_pool.has("gunner_infinite_reload"), "locked skills should not be upgradeable")
	_expect(locked_pool.has("gunner_trait"), "gunner trait should be upgradeable")
	_expect(locked_pool.has("gunner_entry"), "gunner entry skill should be upgradeable")
	_expect(locked_pool.has("gunner_basic"), "gunner basic attack should be upgradeable")
	_expect(not locked_pool.has("gunner_ultimate"), "ultimate skills should stay out of the upgrade pool")
	PLAYER_BLESSING_SKILL_STATE.force_unlock_skill(owner, "infinite_reload", 1)
	var unlocked_pool: Array = PLAYER_SKILL_LEVEL_SYSTEM.get_upgradeable_progress_ids(owner, "gunner")
	_expect(unlocked_pool.has("gunner_infinite_reload"), "unlocked skills should enter the upgrade pool")
	owner.free()


func _check_level_cap_and_pending() -> void:
	var owner := _make_owner()
	for _index in range(4):
		PLAYER_SKILL_LEVEL_SYSTEM.add_skill_level(owner, "swordsman", "swordsman_basic")
	_expect_equal(PLAYER_SKILL_LEVEL_SYSTEM.get_skill_level(owner, "swordsman", "swordsman_basic"), 4, "four upgrades should reach level 4 from LV0")
	_expect(PLAYER_SKILL_LEVEL_SYSTEM.is_talent_pick_pending(owner, "swordsman", "swordsman_basic"), "level 4 should open a pending stage-4 pick")
	_expect(PLAYER_SKILL_LEVEL_SYSTEM.has_pending_talent_pick(owner), "pending talent picks should be reported")
	for _index in range(10):
		PLAYER_SKILL_LEVEL_SYSTEM.add_skill_level(owner, "swordsman", "swordsman_basic")
	_expect_equal(PLAYER_SKILL_LEVEL_SYSTEM.get_skill_level(owner, "swordsman", "swordsman_basic"), 9, "skill levels should clamp to the cap")
	_expect(not PLAYER_SKILL_LEVEL_SYSTEM.get_upgradeable_progress_ids(owner, "swordsman").has("swordsman_basic"), "maxed skills should leave the upgrade pool")
	owner.free()


func _check_talent_offer_and_pick() -> void:
	var owner := _make_owner()
	for _index in range(4):
		PLAYER_SKILL_LEVEL_SYSTEM.add_skill_level(owner, "swordsman", "swordsman_basic")
	var offer: Dictionary = PLAYER_SKILL_LEVEL_SYSTEM.build_talent_offer(owner)
	var options: Array = offer.get("options", [])
	var context: Dictionary = offer.get("context", {})
	_expect_equal(options.size(), 2, "LV4 custom build offer should present two branches")
	_expect(bool(context.get("skill_talent_offer", false)), "talent offer should present the skill talent context")
	_expect(not bool(context.get("level_talent_offer", false)), "skill talent offers should not masquerade as player-level talents")
	_expect_equal(str(context.get("skill_progress_id", "")), "swordsman_basic", "talent offer should target the leveled skill")
	owner.current_blessing_offer = offer
	var first_id := str((options[0] as Dictionary).get("id", ""))
	_expect(PLAYER_SKILL_LEVEL_SYSTEM.is_skill_talent_option_id(first_id), "talent option ids should use the skill-level prefix")
	var result: Dictionary = PLAYER_SKILL_LEVEL_SYSTEM.apply_option_with_result(owner, first_id, offer)
	_expect(not result.is_empty(), "picking a talent slot should apply")
	_expect_equal(str(owner.role_special_states["swordsman"].get("swordsman_basic_build", {}).get("4", "")), "heavy", "stage-4 choice should be recorded")
	_expect(not PLAYER_SKILL_LEVEL_SYSTEM.is_talent_pick_pending(owner, "swordsman", "swordsman_basic"), "picking should clear the pending state")
	_expect(PLAYER_SKILL_LEVEL_SYSTEM.apply_option_with_result(owner, first_id, offer).is_empty(), "the same pending pick should not be applied twice")
	owner.free()


func _check_auto_second_slot() -> void:
	var owner := _make_owner()
	for _index in range(9):
		PLAYER_SKILL_LEVEL_SYSTEM.add_skill_level(owner, "gunner", "gunner_trait")
	_expect_equal(PLAYER_SKILL_LEVEL_SYSTEM.get_skill_level(owner, "gunner", "gunner_trait"), PLAYER_SKILL_LEVEL_SYSTEM.MAX_SKILL_LEVEL, "nine upgrades should reach level 10")
	_expect_equal(PLAYER_SKILL_LEVEL_SYSTEM.get_granted_talent_slots(owner, "gunner", "gunner_trait"), [1, 2], "level 10 should grant the remaining talent slot automatically")
	_expect(not PLAYER_SKILL_LEVEL_SYSTEM.is_talent_pick_pending(owner, "gunner", "gunner_trait"), "auto grant should not leave a pending pick")
	var owner_with_pick := _make_owner()
	for _index in range(4):
		PLAYER_SKILL_LEVEL_SYSTEM.add_skill_level(owner_with_pick, "gunner", "gunner_trait")
	var offer: Dictionary = PLAYER_SKILL_LEVEL_SYSTEM.build_talent_offer(owner_with_pick)
	var options: Array = offer.get("options", [])
	PLAYER_SKILL_LEVEL_SYSTEM.apply_option_with_result(owner_with_pick, str((options[1] as Dictionary).get("id", "")), offer)
	for _index in range(5):
		PLAYER_SKILL_LEVEL_SYSTEM.add_skill_level(owner_with_pick, "gunner", "gunner_trait")
	_expect_equal(PLAYER_SKILL_LEVEL_SYSTEM.get_granted_talent_slots(owner_with_pick, "gunner", "gunner_trait"), [1, 2], "level 10 should also complete a partially picked skill")
	_expect_equal(PLAYER_SKILL_LEVEL_SYSTEM.get_picked_talent_slot(owner_with_pick, "gunner", "gunner_trait"), 2, "the manual pick should stay recorded")
	owner.free()
	owner_with_pick.free()


func _check_build_pool_composition() -> void:
	var owner := _make_owner()
	var options: Array = PLAYER_BUILD_SYSTEM._build_role_options(owner, "swordsman", 0)
	_expect(not options.is_empty(), "swordsman role options should not be empty")
	var has_upgrade := false
	for option_value in options:
		var option: Dictionary = option_value
		var build_id := str(option.get("build_id", ""))
		if bool(option.get("skill_upgrade", false)):
			has_upgrade = true
			_expect(build_id.begins_with("skill_up_"), "upgrade options should use the skill_up build id prefix")
			continue
		_expect(str(option.get("unlock_skill", "")) != "", "role options should only be unlock cards or skill upgrade cards")
	_expect(has_upgrade, "swordsman options should contain skill upgrade cards")
	PLAYER_BLESSING_SKILL_STATE.force_unlock_skill(owner, "blade_storm", 1)
	var unlocked_options: Array = PLAYER_BUILD_SYSTEM._build_role_options(owner, "swordsman", 0)
	var has_blade_storm_upgrade := false
	for option_value in unlocked_options:
		var option: Dictionary = option_value
		if str(option.get("skill_progress_id", "")) == "swordsman_blade_storm" and bool(option.get("skill_upgrade", false)):
			has_blade_storm_upgrade = true
	_expect(has_blade_storm_upgrade, "unlocked active skills should offer upgrade cards")
	var applied: Dictionary = PLAYER_BUILD_SYSTEM.apply_option_with_result(owner, "role_build:swordsman:skill_up_swordsman_basic")
	_expect(not applied.is_empty(), "applying an upgrade card should succeed")
	_expect_equal(PLAYER_SKILL_LEVEL_SYSTEM.get_skill_level(owner, "swordsman", "swordsman_basic"), 1, "upgrade cards should raise LV0 to LV1")
	owner.free()


func _check_option_weight_ratio() -> void:
	var owner := _make_owner()
	var unlock_picks := 0
	var upgrade_picks := 0
	for _index in range(3000):
		var option: Dictionary = PLAYER_BUILD_SYSTEM._pick_role_option(owner, "swordsman", 0)
		if bool(option.get("skill_upgrade", false)):
			upgrade_picks += 1
		elif str(option.get("unlock_skill", "")) != "":
			unlock_picks += 1
	var total := unlock_picks + upgrade_picks
	_expect(total > 0, "weighted picks should produce options")
	if total > 0:
		var unlock_ratio := float(unlock_picks) / float(total)
		_expect(unlock_ratio > 0.52 and unlock_ratio < 0.68, "unlock cards should be picked around 60%% of the time, got %.3f" % unlock_ratio)
	owner.free()


func _check_save_normalization() -> void:
	var owner := _make_owner()
	PLAYER_BLESSING_SKILL_STATE.force_unlock_skill(owner, "infinite_reload", 1)
	for _index in range(4):
		PLAYER_SKILL_LEVEL_SYSTEM.add_skill_level(owner, "gunner", "gunner_infinite_reload")
	var raw: Dictionary = owner.role_special_states.duplicate(true)
	var normalized: Dictionary = PLAYER_SKILL_TALENT_SYSTEM.normalize_role_special_states(raw)
	owner.role_special_states = normalized
	_expect_equal(PLAYER_SKILL_LEVEL_SYSTEM.get_skill_level(owner, "gunner", "gunner_infinite_reload"), 4, "normalization should keep the four purchased custom levels")
	_expect(PLAYER_SKILL_LEVEL_SYSTEM.is_talent_pick_pending(owner, "gunner", "gunner_infinite_reload"), "normalization should keep pending talent picks")
	var offer: Dictionary = PLAYER_SKILL_LEVEL_SYSTEM.build_talent_offer(owner)
	var options: Array = offer.get("options", [])
	PLAYER_SKILL_LEVEL_SYSTEM.apply_option_with_result(owner, str((options[0] as Dictionary).get("id", "")), offer)
	var normalized_again: Dictionary = PLAYER_SKILL_TALENT_SYSTEM.normalize_role_special_states(owner.role_special_states.duplicate(true))
	owner.role_special_states = normalized_again
	_expect_equal(owner.role_special_states["gunner"]["infinite_reload_build"].get("4", ""), "light_step", "normalization should keep the chosen custom branch")
	_expect_equal(PLAYER_SKILL_LEVEL_SYSTEM.get_granted_talent_slots(owner, "gunner", "gunner_infinite_reload"), [], "custom branches must not grant generic LV5/10 slots")
	_expect_equal(PLAYER_SKILL_LEVEL_SYSTEM.get_skill_level(owner, "gunner", "gunner_trait"), 1, "untouched skill lines should stay at level 1")
	owner.free()


func _make_owner() -> SkillLevelOwnerStub:
	var owner := SkillLevelOwnerStub.new()
	owner.roles = [
		{"id": "swordsman", "name": "剑士"},
		{"id": "gunner", "name": "枪手"},
		{"id": "mage", "name": "法师"}
	]
	return owner


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _expect_equal(actual, expected, message: String) -> void:
	if actual != expected:
		failures.append("%s: %s != %s" % [message, str(actual), str(expected)])


class SkillLevelOwnerStub:
	extends Node

	var roles: Array = []
	var role_special_states: Dictionary = {}
	var blessing_skill_state: Dictionary = {}
	var current_blessing_offer: Dictionary = {}
	var global_position := Vector2.ZERO

	func _spawn_combat_tag(_position: Vector2, _text: String, _color: Color) -> void:
		pass
