extends SceneTree

const TALENTS := preload("res://scripts/player/player_skill_talent_system.gd")
const STORM_BUILD := preload("res://scripts/player/player_blade_storm_build.gd")
const BladeStorm := preload("res://scripts/abilities/swordsman_blade_storm_ability.gd")
const CrescentWave := preload("res://scripts/abilities/swordsman_crescent_wave_ability.gd")
const SurvivalFlow := preload("res://scripts/player/player_survival_flow.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner := TalentOwner.new()
	root.add_child(owner)
	var crescent = CrescentWave.new()
	if not is_equal_approx(crescent._get_wave_speed(owner), 650.0):
		failures.append("retired full moon must not replace the base wave speed")
	owner.role_special_states["swordsman"]["build_levels"]["crescent_wave_speed"] = 1
	if not is_equal_approx(crescent._get_wave_speed(owner), 680.0):
		failures.append("retained speed build applies to the current 650 base speed")
	owner.role_special_states["swordsman"]["build_levels"].erase("crescent_wave_speed")

	var projectile := Node2D.new()
	root.add_child(projectile)
	crescent.active_crescent_projectiles.append({
		"owner_ref": weakref(owner),
		"projectile": projectile,
		"token": -1,
		"origin": Vector2.ZERO,
		"direction": Vector2.RIGHT,
		"length": 100.0,
		"width": 20.0,
		"damage_amount": 40.0,
		"duration": 1.0,
		"elapsed": 0.0,
		"damage_elapsed": 0.0,
		"last_damage_progress": 0.0,
		"hit_registry": {},
		"returned": false
	})
	projectile.set_meta("crescent_projectile_token", -1)
	crescent._update_crescent_projectiles(1.0)
	if not crescent.active_crescent_projectiles.is_empty():
		failures.append("retired return input must not retain an expired projectile")
	for pooled in crescent.crescent_projectile_pool:
		pooled.free()
	crescent.crescent_projectile_pool.clear()
	if not STORM_BUILD.choices(owner).is_empty() or not is_equal_approx(STORM_BUILD.radius(owner), 150.0):
		failures.append("retired storm nodes must not select current branches or change the base radius")

	_check_last_guard()
	owner.queue_free()
	if failures.is_empty():
		print("SWORDSMAN_SKILL_TALENTS_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_last_guard() -> void:
	var owner := TalentOwner.new()
	root.add_child(owner)
	owner.role_special_states["swordsman"]["build_levels"] = {
		"trait_heal_bonus": 2,
		"knight_glory_duration": 1
	}

	if SurvivalFlow._try_trigger_swordsman_last_guard(owner):
		failures.append("retired last guard input must not rescue another role")
	if owner.active_role_index != 1 or owner.role_switch_energy_values["gunner"] != 100.0:
		failures.append("rejected legacy rescue must not switch role or consume energy")

	owner.queue_free()


class TalentOwner:
	extends Node2D

	signal health_changed(current: float, maximum: float)

	const SWORDSMAN_DEATH_DEFIANCE_COOLDOWN := 80.0

	var blessing_skill_state: Dictionary = {"unlocked": {"crescent_wave": true, "blade_storm": true}}
	var role_special_states: Dictionary = {"swordsman": {"build_levels": {}, "skill_talents": {
		"swordsman_crescent": ["swordsman_crescent_full_moon", "swordsman_crescent_return"],
		"swordsman_blade_storm": ["swordsman_blade_storm_stationary", "swordsman_blade_storm_recall"],
		"swordsman_trait": ["swordsman_trait_last_guard"]
	}}}
	var roles: Array = [{"id": "swordsman"}, {"id": "gunner"}, {"id": "mage"}]
	var active_role_index := 1
	var role_health_values := {"swordsman": 100.0, "gunner": 100.0, "mage": 100.0}
	var role_switch_energy_values := {"swordsman": 0.0, "gunner": 100.0, "mage": 0.0}
	var current_health := 100.0
	var max_health := 100.0
	var current_temporary_health := 0.0
	var is_dead := false
	var switch_invulnerability_remaining := 0.0
	var hurt_cooldown_remaining := 0.0
	var hurt_cooldown := 0.4
	var swordsman_death_defiance_cooldown_remaining := 0.0
	var swordsman_death_defiance_will_remaining := 0.0

	func _has_skill_talent(talent_id: String) -> bool:
		return TALENTS.has_talent(self, talent_id)

	func _get_active_role() -> Dictionary:
		return roles[active_role_index]

	func _try_equipment_dodge() -> bool:
		return false

	func _get_effective_damage_taken_multiplier() -> float:
		return 1.0

	func _save_active_role_health() -> void:
		role_health_values[str(_get_active_role().get("id", ""))] = current_health

	func _has_full_switch_energy(role_id: String) -> bool:
		return float(role_switch_energy_values.get(role_id, 0.0)) >= 100.0

	func _set_role_switch_energy(role_id: String, value: float) -> void:
		role_switch_energy_values[role_id] = value

	func _get_role_current_health(role_id: String) -> float:
		return float(role_health_values.get(role_id, 0.0))

	func _get_role_max_health(_role_id: String) -> float:
		return 100.0

	func _try_switch_role(index: int, _ignore_cooldown: bool = false, _force: bool = false) -> bool:
		active_role_index = index
		return true

	func _play_player_hurt_feedback() -> void:
		pass

	func _damage_enemies_in_oriented_rect_unique(_center: Vector2, _axis: Vector2, _length: float, _width: float, _damage: float, _vulnerability: float, _slow: float, _slow_duration: float, _registry: Dictionary, _role_id: String, _slow_source_id: String = "") -> int:
		return 0

	func _register_attack_result(_role_id: String, _hits: int, _killed: bool) -> void:
		pass
