extends SceneTree

const TALENTS := preload("res://scripts/player/player_skill_talent_system.gd")
const STORM_BUILD := preload("res://scripts/player/player_blade_storm_build.gd")
const BladeStorm := preload("res://scripts/abilities/swordsman_blade_storm_ability.gd")
const CrescentWave := preload("res://scripts/abilities/swordsman_crescent_wave_ability.gd")
const CombatResultFlow := preload("res://scripts/player/player_combat_result_flow.gd")
const SurvivalFlow := preload("res://scripts/player/player_survival_flow.gd")
const SwordsmanRole := preload("res://scripts/player/roles/swordsman_role.gd")


func _init() -> void:
	var owner := TalentOwner.new()
	root.add_child(owner)
	_check_trait_states(owner)
	_check_crescent_branches(owner)
	_check_blade_storm_blocks_basic_attack(owner)
	_check_ultimate_talent_snapshot(owner)
	print("SWORDSMAN_ADVANCED_TALENTS_SMOKE_OK")
	quit()


func _check_trait_states(owner: TalentOwner) -> void:
	owner.role_health_values["swordsman"] = 30.0
	CombatResultFlow._activate_swordsman_heal_talents(owner)
	var state: Dictionary = owner.role_special_states["swordsman"]
	for timer in ["blood_surge_remaining", "guard_stance_remaining", "head_high_remaining", "unyielding_remaining"]:
		assert(is_zero_approx(float(state.get(timer, 0.0))), "retired heal nodes must not activate timed buffs")
	assert(is_equal_approx(SurvivalFlow._get_swordsman_talent_damage_taken_multiplier(owner), 1.0))
	assert(is_equal_approx(SurvivalFlow._get_swordsman_talent_move_multiplier(owner), 1.0))
	assert(is_equal_approx(SwordsmanRole.new().get_talent_basic_attack_interval_multiplier(owner), 1.0))
	assert(is_equal_approx(CombatResultFlow.get_swordsman_blood_surge_multiplier(owner), 1.0))


func _check_crescent_branches(owner: TalentOwner) -> void:
	var directions: Array[Vector2] = CrescentWave.new()._get_cast_directions(owner, Vector2.RIGHT)
	assert(directions == [Vector2.RIGHT], "retired twin moons must not add cast directions")
	assert(STORM_BUILD.choices(owner).is_empty(), "retired recall does not grant a current storm branch")


func _check_blade_storm_blocks_basic_attack(_owner: TalentOwner) -> void:
	var role = SwordsmanRole.new()
	var attack_owner := BasicAttackOwner.new()
	root.add_child(attack_owner)
	role.perform_attack(attack_owner)
	role._perform_combo_segment_if_valid(attack_owner, Vector2.RIGHT, 1.0, "test_basic_attack")
	assert(attack_owner.active_checks == 2)
	attack_owner.queue_free()

func _check_ultimate_talent_snapshot(owner: TalentOwner) -> void:
	var role = SwordsmanRole.new()
	var snapshot: Dictionary = role._snapshot_ultimate_talents(owner)
	role._activate_ultimate_triumph(owner, bool(snapshot["swordsman_ultimate_triumph"]))
	assert(not bool(snapshot["swordsman_ultimate_triumph"]))
	assert(not owner.role_special_states["swordsman"].has("ultimate_triumph_remaining"), "retired ultimate node is not captured in new casts")
	role._activate_ultimate_triumph(owner, false)
	assert(not owner.role_special_states["swordsman"].has("ultimate_triumph_remaining"))


class BasicAttackOwner:
	extends Node2D

	var is_dead: bool = false
	var active_checks: int = 0

	func is_swordsman_blade_storm_active() -> bool:
		active_checks += 1
		return true


class TalentOwner:
	extends Node2D

	var blessing_skill_state: Dictionary = {"unlocked": {"blade_storm": true}}
	var role_special_states: Dictionary = {"swordsman": {"skill_talents": {
		"swordsman_trait": ["swordsman_trait_blood_surge", "swordsman_trait_guard_stance", "swordsman_trait_head_high", "swordsman_trait_unyielding"],
		"swordsman_crescent": ["swordsman_crescent_twin_moons"],
		"swordsman_blade_storm": ["swordsman_blade_storm_recall"],
		"swordsman_ultimate": ["swordsman_ultimate_triumph"]
	}}}
	var roles: Array = [{"id": "swordsman"}]
	var active_role_index := 0
	var role_health_values := {"swordsman": 100.0}
	var switch_power_remaining := 0.0
	var switch_power_role_id := ""
	var switch_power_label := ""
	var live_enemies: Array = []
	var facing_direction := Vector2.RIGHT

	func _has_skill_talent(talent_id: String) -> bool:
		return TALENTS.has_talent(self, talent_id)

	func _get_active_role() -> Dictionary:
		return roles[active_role_index]

	func _get_role_current_health(role_id: String) -> float:
		return float(role_health_values.get(role_id, 0.0))

	func _get_role_max_health(_role_id: String) -> float:
		return 100.0

	func _get_live_enemies() -> Array:
		return live_enemies

	func _get_role_special_state(role_id: String) -> Dictionary:
		return role_special_states.get(role_id, {})

	func _get_downward_perpendicular(direction: Vector2) -> Vector2:
		return Vector2(-direction.y, direction.x)
