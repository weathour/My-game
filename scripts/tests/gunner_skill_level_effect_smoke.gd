extends SceneTree

const PLAYER_SKILL_LEVEL_SYSTEM := preload("res://scripts/player/player_skill_level_system.gd")
const PLAYER_SKILL_LEVEL_EFFECT_FLOW := preload("res://scripts/player/player_skill_level_effect_flow.gd")
const PLAYER_GUNNER_FLASH_TALENT_FLOW := preload("res://scripts/player/player_gunner_flash_talent_flow.gd")
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_progress_lines()
	_check_flat_bonuses()
	_check_magic_eye_armor()
	_check_milestone_counts()
	_check_preview_text()
	_check_upgrade_card_text()
	if failures.is_empty():
		print("GUNNER_SKILL_LEVEL_EFFECT_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_magic_eye_armor() -> void:
	var owner := _make_owner()
	var ability = preload("res://scripts/abilities/gunner_magic_eye_ability.gd").new()
	var flow = preload("res://scripts/player/player_gunner_magic_eye_flow.gd")
	var enemy := MagicEyeEnemyStub.new()
	_set_level(owner, "gunner_magic_eye", 1)
	_expect_approx(ability.get_armor_shred(owner), 5.0, "level 1 eye shreds 5 armor")
	flow._shred_enemy_armor(enemy, ability.get_armor_shred(owner))
	flow._shred_enemy_armor(enemy, ability.get_armor_shred(owner))
	_expect_approx(enemy.armor, -7.0, "eye stacks armor shred below zero")
	_expect_approx(enemy.damage_reduction_value, 17.0, "base eye must not change legacy reduction")
	_set_level(owner, "gunner_magic_eye", 10)
	_expect_approx(ability.get_armor_shred(owner), 11.75, "level 10 eye shreds 11.75 armor")
	enemy.free()
	owner.free()


class MagicEyeEnemyStub:
	extends Node
	var armor: float = 3.0
	var damage_reduction_value: float = 17.0


func _check_progress_lines() -> void:
	var gunner_lines: Array = PLAYER_SKILL_LEVEL_SYSTEM.ROLE_PROGRESS_ORDER.get("gunner", [])
	_expect(gunner_lines.has("gunner_trait"), "gunner should keep the gunner_trait line")
	_expect(gunner_lines.has("gunner_hunt"), "gunner should gain the separate gunner_hunt line")
	_expect_equal(str(PLAYER_SKILL_LEVEL_SYSTEM.PROGRESS_TITLES.get("gunner_trait", "")), "瞬杀", "gunner_trait should be titled 瞬杀")
	_expect_equal(str(PLAYER_SKILL_LEVEL_SYSTEM.PROGRESS_TITLES.get("gunner_hunt", "")), "猎杀", "gunner_hunt should be titled 猎杀")


func _check_flat_bonuses() -> void:
	var owner := _make_owner()
	_set_level(owner, "gunner_trait", 6)
	_set_level(owner, "gunner_hunt", 4)
	_set_level(owner, "gunner_entry", 3)
	_set_level(owner, "gunner_basic", 5)
	_set_level(owner, "gunner_shrapnel", 4)
	_set_level(owner, "gunner_infinite_reload", 3)
	_set_level(owner, "gunner_explosive_round", 2)
	_set_level(owner, "gunner_magic_grenade", 5)
	_set_level(owner, "gunner_magic_eye", 4)
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_flash_damage_bonus_per_stack(owner), 0.025, "瞬杀 level 6 should add 2.5% damage per stack")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_flash_speed_bonus_per_stack(owner), 0.025, "瞬杀 level 6 should add 2.5% move speed per stack")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_flash_dodge_chance_bonus_per_stack(owner), 0.0175, "level 6 adds 1.75 percent dodge chance per stack after five upgrades")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_hunt_radius_bonus(owner), -15.0, "猎杀 level 4 should shrink the circle by 15")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_hunt_outside_damage_bonus(owner), 0.03, "猎杀 level 4 should add 3% outside damage")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_entry_damage_ratio_bonus(owner), 0.20, "枪火典礼 level 3 should add 20% bullet damage")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_entry_bullet_speed_bonus(owner), 20.0, "枪火典礼 level 3 should add 20 bullet speed")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_basic_range_bonus(owner), 0.0, "LV5 without sniper does not add range before the LV6 milestone")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_basic_bullet_speed_bonus(owner), 0.0, "custom basic uses branch speed rather than the old flat level bonus")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_shrapnel_damage_ratio_bonus(owner), 0.06, "散弹 level 4 should add 6% damage")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_infinite_reload_range_bonus(owner), 0.0, "reload LV3 has no range branch yet")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_infinite_reload_damage_ratio_bonus(owner), 0.15, "reload LV3 adds three five-point upgrades")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_infinite_reload_move_speed_bonus(owner), 0.0, "reload movement bonus requires light_step")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_explosive_round_damage_ratio_bonus(owner), 0.10, "爆破弹 level 2 should add 10% damage")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_explosive_round_cone_radius_bonus(owner), 7.5, "爆破弹 level 2 should add 7.5 cone radius")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_magic_grenade_damage_ratio_bonus(owner), 0.40, "魔法榴弹 level 5 should add 40% damage")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_magic_grenade_crit_bonus(owner), 0.20, "魔法榴弹 level 5 should add 20% crit chance")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_magic_eye_damage_ratio_bonus(owner), 0.06, "魔眼 level 4 should add 6% damage")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_magic_eye_armor_shred_bonus(owner), 2.25, "魔眼 level 4 should add 2.25 armor shred")
	owner.free()


func _check_milestone_counts() -> void:
	var owner := _make_owner()
	var flash_table := {1: 0, 2: 1, 3: 1, 4: 2, 6: 3, 8: 4, 10: 5}
	for level in flash_table.keys():
		_set_level(owner, "gunner_trait", int(level))
		_expect_equal(
			PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_flash_max_stack_bonus(owner),
			int(flash_table[level]),
			"瞬杀 level %d max stack bonus" % int(level)
		)
	_set_level(owner, "gunner_trait", 10)
	_expect_equal(PLAYER_GUNNER_FLASH_TALENT_FLOW.get_base_flash_stack_capacity(owner), 15, "满级瞬杀 should raise the base stack capacity to 15")
	var split_table := {0: 0, 3: 0, 5: 0, 6: 0, 8: 0, 9: 0}
	for level in split_table.keys():
		_set_level(owner, "gunner_basic", int(level))
		_expect_equal(
			PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_basic_split_bullet_count(owner),
			int(split_table[level]),
			"枪手普攻 level %d split bullet count" % int(level)
		)
	_set_level(owner, "gunner_basic", 6)
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_basic_range_bonus(owner), 75.0, "custom basic LV6 adds 75 range")
	_set_level(owner, "gunner_infinite_reload", 4)
	owner.role_special_states["gunner"]["infinite_reload_build"] = {"4": "light_step"}
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_infinite_reload_range_bonus(owner), 100.0, "light_step grants 100 range")
	_expect_approx(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_infinite_reload_move_speed_bonus(owner), 0.1, "light_step grants ten percent speed")
	_set_level(owner, "gunner_shrapnel", 9)
	_expect_equal(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_shrapnel_extra_field_count(owner), 3, "散弹 level 9 should add three extra fields")
	_set_level(owner, "gunner_explosive_round", 6)
	_expect_equal(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_explosive_round_extra_shot_count(owner), 2, "爆破弹 level 6 should add two extra shots")
	_set_level(owner, "gunner_magic_grenade", 8)
	_expect_equal(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_gunner_magic_grenade_extra_count(owner), 4, "魔法榴弹 level 8 should add four extra grenades")
	owner.free()


func _check_preview_text() -> void:
	var owner := _make_owner()
	_set_level(owner, "gunner_hunt", 1)
	var hunt_preview := PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_upgrade_preview_text(owner, "gunner", "gunner_hunt")
	_expect(hunt_preview.contains("猎杀圈半径 -5"), "猎杀 preview should mention the circle shrink")
	_expect(hunt_preview.contains("圈外伤害 +1%"), "猎杀 preview should mention the outside damage")
	_set_level(owner, "gunner_trait", 1)
	var execution_preview := PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_upgrade_preview_text(owner, "gunner", "gunner_trait")
	_expect(execution_preview.contains("瞬杀最大层数 +1"), "瞬杀 level 1 preview should mention the level-2 stack cap")
	_set_level(owner, "gunner_basic", 2)
	var basic_preview := PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_upgrade_preview_text(owner, "gunner", "gunner_basic")
	_expect(basic_preview.contains("伤害倍率 +20 个百分点"), "gunner LV2 preview describes the LV3 ratio upgrade")
	_set_level(owner, "gunner_basic", 10)
	_expect_equal(PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_upgrade_preview_text(owner, "gunner", "gunner_basic"), "", "maxed gunner skills should have no upgrade preview")
	owner.free()


func _check_upgrade_card_text() -> void:
	var owner := _make_owner()
	_set_level(owner, "gunner_hunt", 4)
	var options: Array = PLAYER_BUILD_SYSTEM._build_role_options(owner, "gunner", 1)
	var hunt_option := {}
	for option_value in options:
		var option: Dictionary = option_value
		if str(option.get("build_id", "")) == "skill_up_gunner_hunt":
			hunt_option = option
			break
	_expect(not hunt_option.is_empty(), "猎杀 upgrade card should be offered for the gunner slot")
	var hunt_title := str(hunt_option.get("title", ""))
	_expect(hunt_title.contains("升级") and hunt_title.contains("猎杀"), "猎杀 upgrade card title should name the skill, got %s" % hunt_title)
	_expect(str(hunt_option.get("card_title", "")).contains("猎杀"), "猎杀 upgrade card should use the skill name as card title")
	_expect_equal(int(hunt_option.get("skill_level", 0)), 4, "猎杀 upgrade card should expose the current skill level")
	var summary := str(hunt_option.get("summary", ""))
	_expect(summary.contains("猎杀圈半径 -5"), "猎杀 upgrade summary should preview the effect, got %s" % summary)
	owner.free()


func _set_level(owner, progress_id: String, level: int) -> void:
	var states: Dictionary = owner.role_special_states if owner.role_special_states is Dictionary else {}
	var role_state: Dictionary = states.get("gunner", {}) if states.get("gunner", {}) is Dictionary else {}
	var levels: Dictionary = role_state.get("skill_levels", {}) if role_state.get("skill_levels", {}) is Dictionary else {}
	if level <= 1:
		levels.erase(progress_id)
	else:
		levels[progress_id] = level
	role_state["skill_levels"] = levels
	var custom_builds := {"gunner_basic": "gunner_basic_build", "gunner_infinite_reload": "infinite_reload_build"}
	if custom_builds.has(progress_id):
		levels[progress_id] = level
		role_state[custom_builds[progress_id]] = {}
	states["gunner"] = role_state
	owner.role_special_states = states


func _make_owner() -> GunnerLevelOwnerStub:
	var owner := GunnerLevelOwnerStub.new()
	owner.roles = [
		{"id": "swordsman", "name": "剑士"},
		{"id": "gunner", "name": "枪手"},
		{"id": "mage", "name": "法师"}
	]
	for skill_id in ["shrapnel_field", "infinite_reload", "explosive_round", "magic_grenade", "magic_eye"]:
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


class GunnerLevelOwnerStub:
	extends Node

	var roles: Array = []
	var role_special_states: Dictionary = {}
	var blessing_skill_state: Dictionary = {}
	var current_blessing_offer: Dictionary = {}
	var global_position := Vector2.ZERO

	func _spawn_combat_tag(_position: Vector2, _text: String, _color: Color) -> void:
		pass
