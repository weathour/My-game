extends SceneTree

const PLAYER_SKILL_LEVEL_SYSTEM := preload("res://scripts/player/player_skill_level_system.gd")
const PLAYER_SKILL_LEVEL_EFFECT_FLOW := preload("res://scripts/player/player_skill_level_effect_flow.gd")
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")
const META_FIELD := preload("res://scripts/abilities/mage_meta_field_ability.gd")
const COMBAT_MODIFIERS := preload("res://scripts/player/player_combat_modifiers.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_flat_bonuses()
	_check_field_armor()
	_check_milestone_counts()
	_check_preview_text()
	_check_upgrade_card_text()
	if failures.is_empty():
		print("MAGE_SKILL_LEVEL_EFFECT_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_field_armor() -> void:
	var owner := _make_owner()
	var field = META_FIELD.new()
	owner.mage_meta_field_ability = field
	_expect_approx(COMBAT_MODIFIERS.get_role_armor(owner, "mage"), 0.0, "Inactive field grants no armor")
	field.active_remaining = 1.0
	_expect_approx(COMBAT_MODIFIERS.get_role_armor(owner, "mage"), 25.0, "Level 1 field grants 25 armor")
	_set_level(owner, "mage_meta_field", 3)
	_expect_approx(COMBAT_MODIFIERS.get_role_armor(owner, "mage"), 30.0, "Level 3 field grants 30 armor")
	_expect_approx(COMBAT_MODIFIERS.get_role_armor(owner, "swordsman"), 0.0, "Inactive role gets no field armor")
	_expect(not field.has_method("get_damage_reduction_rate"), "Field must not supply damage reduction")
	_expect(not field.has_method("get_damage_reduction_value"), "Field must not supply legacy damage reduction")
	field.stop()
	_expect_approx(COMBAT_MODIFIERS.get_role_armor(owner, "mage"), 0.0, "Stopping field removes armor")
	owner.free()


func _check_flat_bonuses() -> void:
	var owner := _make_owner()
	_set_level(owner, "mage_trait", 5)
	_set_level(owner, "mage_entry", 4)
	_set_level(owner, "mage_basic", 5)
	_set_level(owner, "mage_meta_field", 3)
	_set_level(owner, "mage_surging_wave", 4)
	_set_level(owner, "mage_fireball", 5)
	_set_level(owner, "mage_dark_contract", 3)
	_set_level(owner, "mage_flame_path", 6)
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_arcane_charge_proc_chance_bonus(owner), 0.08, "奥数充能 level 5 should add 8% proc chance")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_arcane_charge_energy_bonus_per_stack(owner), 0.012, "奥数充能 level 5 should add 1.2% energy per stack")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_arcane_surplus_ultimate_energy_bonus(owner), 0.045, "奥法盈余 level 4 should add 4.5% ultimate energy")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_arcane_surplus_switch_energy_bonus(owner), 0.045, "奥法盈余 level 4 should add 4.5% switch energy")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_arcane_surplus_damage_multiplier_bonus(owner), 0.045, "奥法盈余 level 4 should add 4.5% damage")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_basic_range_multiplier(owner), 1.0, "custom basic range requires focus branch")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_basic_damage_ratio_bonus(owner), 1.70, "custom LV5 basic has a total 270 percent ratio")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_meta_field_armor_bonus(owner), 5.0, "梅塔领域 level 3 should add 5 armor")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_meta_field_radius_bonus(owner), 15.0, "梅塔领域 level 3 should add 15 radius")
	_expect_approx(preload("res://scripts/abilities/mage_tidal_surge_ability.gd").new()._get_damage_multiplier(owner), 3.90, "custom wave LV4 retains its 390 percent ratio")
	_expect_approx(preload("res://scripts/abilities/mage_tidal_surge_ability.gd").new()._get_lifetime(owner), 4.0, "custom wave gains no duration until LV6")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_fireball_damage_ratio_bonus(owner), 0.80, "火球术 level 5 should add 80% damage ratio")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_fireball_burn_ratio_bonus(owner), 0.02, "火球术 level 5 should add 2% burn ratio")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_fireball_ground_duration_bonus(owner), 1.0, "火球术 level 5 should add 1s ground duration")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_dark_contract_speed_bonus(owner), 5.0, "黑暗契约 level 3 should add 5 sphere speed")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_dark_contract_distance_bonus(owner), 30.0, "黑暗契约 level 3 should add 30 travel distance")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_dark_contract_attract_radius_bonus(owner), 15.0, "黑暗契约 level 3 should add 15 attract radius")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_dark_contract_damage_ratio_bonus(owner), 0.20, "黑暗契约 level 3 should add 20% damage")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_flame_path_damage_per_second_bonus(owner), 0.125, "火焰之径 level 6 should add 12.5% per-second damage")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_flame_path_move_speed_bonus(owner), 0.025, "火焰之径 level 6 should add 2.5% move speed")
	owner.free()


func _check_milestone_counts() -> void:
	var owner := _make_owner()
	var lightning_table := {0: 0, 2: 0, 3: 0, 4: 0, 6: 0, 8: 0, 9: 0}
	for level in lightning_table.keys():
		_set_level(owner, "mage_basic", int(level))
		_expect_equal(
			PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_basic_extra_lightning_count(owner),
			int(lightning_table[level]),
			"法师普攻 level %d extra lightning count" % int(level)
		)
	var ground_table := {1: 0, 2: 0, 3: 1, 5: 1, 6: 2, 8: 2, 9: 3, 10: 3}
	for level in ground_table.keys():
		_set_level(owner, "mage_fireball", int(level))
		_expect_approx(
			PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_fireball_ground_duration_bonus(owner),
			float(ground_table[level]),
			"火球术 level %d ground duration bonus" % int(level)
		)
	owner.free()


func _check_preview_text() -> void:
	var owner := _make_owner()
	_set_level(owner, "mage_basic", 1)
	var basic_preview := PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_upgrade_preview_text(owner, "mage", "mage_basic")
	_expect(basic_preview.contains("伤害倍率 +15 个百分点"), "custom basic LV1 previews its LV2 ratio upgrade")
	_expect(not basic_preview.contains("追加一道雷击"), "legacy extra-lightning milestones stay disabled")
	_set_level(owner, "mage_fireball", 2)
	var fireball_preview := PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_upgrade_preview_text(owner, "mage", "mage_fireball")
	_expect(fireball_preview.contains("灼烧地面持续时间 +1s"), "火球术 level 2 preview should mention the level-3 ground duration")
	_set_level(owner, "mage_entry", 3)
	var entry_preview := PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_upgrade_preview_text(owner, "mage", "mage_entry")
	_expect(entry_preview.contains("奥法盈余：大招回能 +1.5%"), "登场技 preview should describe the arcane surplus bonus")
	_set_level(owner, "mage_trait", 10)
	_expect_equal(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_upgrade_preview_text(owner, "mage", "mage_trait"), "", "maxed mage skills should have no upgrade preview")
	owner.free()


func _check_upgrade_card_text() -> void:
	var owner := _make_owner()
	_set_level(owner, "mage_basic", 3)
	var options: Array = PLAYER_BUILD_SYSTEM._build_role_options(owner, "mage", 2)
	var basic_option := {}
	for option_value in options:
		var option: Dictionary = option_value
		if str(option.get("build_id", "")) == "skill_up_mage_basic":
			basic_option = option
			break
	_expect(not basic_option.is_empty(), "法师普攻 upgrade card should be offered for the mage slot")
	var basic_title := str(basic_option.get("title", ""))
	_expect(basic_title.contains("升级") and basic_title.contains("范围轰炸"), "法师普攻 upgrade card title should name the skill, got %s" % basic_title)
	_expect(str(basic_option.get("card_title", "")).contains("范围轰炸"), "法师普攻 upgrade card should use the skill name as card title")
	_expect_equal(int(basic_option.get("skill_level", 0)), 3, "法师普攻 upgrade card should expose the current skill level")
	var summary := str(basic_option.get("summary", ""))
	_expect(summary.contains("狂雷") and summary.contains("通电"), "custom basic LV3 previews the LV4 branches, got %s" % summary)
	owner.free()


func _set_level(owner, progress_id: String, level: int) -> void:
	var states: Dictionary = owner.role_special_states if owner.role_special_states is Dictionary else {}
	var role_state: Dictionary = states.get("mage", {}) if states.get("mage", {}) is Dictionary else {}
	var levels: Dictionary = role_state.get("skill_levels", {}) if role_state.get("skill_levels", {}) is Dictionary else {}
	if level <= 1:
		levels.erase(progress_id)
	else:
		levels[progress_id] = level
	role_state["skill_levels"] = levels
	var custom_builds := {"mage_basic": "mage_basic_build", "mage_surging_wave": "mage_surging_wave_build"}
	if custom_builds.has(progress_id):
		levels[progress_id] = level
		role_state[custom_builds[progress_id]] = {}
	states["mage"] = role_state
	owner.role_special_states = states


func _make_owner() -> MageLevelOwnerStub:
	var owner := MageLevelOwnerStub.new()
	owner.roles = [
		{"id": "swordsman", "name": "剑士"},
		{"id": "gunner", "name": "枪手"},
		{"id": "mage", "name": "法师"}
	]
	for skill_id in ["meta_field", "surging_wave", "flame_path", "dark_contract", "fireball"]:
		PLAYER_BLESSING_SKILL_STATE.force_unlock_skill(owner, str(skill_id), 1)
	return owner


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _expect_equal(actual, expected, message: String) -> void:
	if actual != expected:
		failures.append("%s: %s != %s" % [message, str(actual), str(expected)])


func _expect_approx(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s: %.4f != %.4f" % [message, actual, expected])


class MageLevelOwnerStub:
	extends Node

	var roles: Array = []
	var role_special_states: Dictionary = {}
	var blessing_skill_state: Dictionary = {}
	var current_blessing_offer: Dictionary = {}
	var global_position := Vector2.ZERO
	var mage_meta_field_ability: Variant = null

	func _get_active_role() -> Dictionary:
		return {"id": "mage"}

	func _spawn_combat_tag(_position: Vector2, _text: String, _color: Color) -> void:
		pass
