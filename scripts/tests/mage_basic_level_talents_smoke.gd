extends SceneTree

const MAGE_ROLE := preload("res://scripts/player/roles/mage_role.gd")
const MAGE_BASIC_TALENT_FLOW := preload("res://scripts/player/player_mage_basic_talent_flow.gd")
const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_level_talent_definitions()
	_check_secondary_lightning_context()
	await _check_followup_schedule()
	await _check_kill_rewards_and_cooldown_cut()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("MAGE_BASIC_LEVEL_TALENTS_SMOKE_OK")
	quit(0)


func _check_level_talent_definitions() -> void:
	var definitions: Array = PLAYER_SKILL_TALENT_SYSTEM.LEVEL_TALENT_DEFINITIONS.get("mage", [])
	_expect(_has_candidate(definitions, MAGE_BASIC_TALENT_FLOW.TALENT_BASIC_ATTACK_1), "mage basic attack I should be registered")
	_expect(_has_candidate(definitions, MAGE_BASIC_TALENT_FLOW.TALENT_BASIC_ATTACK_2), "mage basic attack II should be registered")

	var owner := TalentOwner.new()
	var candidates: Array = PLAYER_SKILL_TALENT_SYSTEM._collect_level_talent_candidates(owner, definitions, {}, false)
	_expect(_has_candidate(candidates, MAGE_BASIC_TALENT_FLOW.TALENT_BASIC_ATTACK_1), "mage basic attack I should be a level talent candidate")
	_expect(_has_candidate(candidates, MAGE_BASIC_TALENT_FLOW.TALENT_BASIC_ATTACK_2), "mage basic attack II should be a level talent candidate")

	owner.role_special_states["mage"] = {"level_talents": [MAGE_BASIC_TALENT_FLOW.TALENT_BASIC_ATTACK_1]}
	candidates = PLAYER_SKILL_TALENT_SYSTEM._collect_level_talent_candidates(owner, definitions, {}, false)
	_expect(not _has_candidate(candidates, MAGE_BASIC_TALENT_FLOW.TALENT_BASIC_ATTACK_2), "same-scope mage basic attack II should be locked after picking I")

	owner.role_special_states["mage"] = {
		"level_talents": [MAGE_BASIC_TALENT_FLOW.TALENT_BASIC_ATTACK_1],
		"level_talent_group_scope": "period_2"
	}
	candidates = PLAYER_SKILL_TALENT_SYSTEM._collect_level_talent_candidates(owner, definitions, {}, false)
	_expect(_has_candidate(candidates, MAGE_BASIC_TALENT_FLOW.TALENT_BASIC_ATTACK_2), "future group scope should be able to expose mage basic attack II")


func _check_secondary_lightning_context() -> void:
	var owner := MageContextOwner.new()
	var role := MAGE_ROLE.new()
	var contexts: Array = role._build_attack_contexts(owner, "mage_basic:test")
	var centers: Array = contexts[0]
	var damages: Array = contexts[2]
	_expect(centers.size() == 2, "mage basic attack II should create two primary lightning centers")
	_expect(centers[0] == Vector2.ZERO, "first mage lightning should keep the normal aim center")
	_expect(centers[1] == Vector2(240.0, 0.0), "second mage lightning should use a random dense enemy cluster center")
	_expect(is_equal_approx(float(damages[0]), 200.0), "first mage lightning should keep full damage")
	_expect(is_equal_approx(float(damages[1]), 200.0), "second mage lightning should keep full damage")
	owner.free()


func _check_followup_schedule() -> void:
	var owner := MageScheduleOwner.new()
	root.add_child(owner)
	await process_frame
	var role := MAGE_ROLE.new()
	var contexts := [[Vector2.ZERO], [20.0], [100.0], ["mage"], ["mage_basic:test"]]
	role._schedule_level_basic_rehit(owner, contexts, {})
	_expect(owner.schedules.size() == 1, "mage basic attack I should schedule one delayed second lightning")
	if owner.schedules.size() > 0:
		var schedule: Dictionary = owner.schedules[0]
		_expect(is_equal_approx(float(schedule.get("initial_delay", 0.0)), 0.70), "mage basic attack I second lightning should wait for first impact plus 0.2s")
	owner.queue_free()
	await process_frame


func _check_kill_rewards_and_cooldown_cut() -> void:
	var owner := DamageOwner.new()
	root.add_child(owner)
	owner.fire_timer = Timer.new()
	owner.fire_timer.one_shot = true
	owner.add_child(owner.fire_timer)
	await process_frame
	owner.fire_timer.start(1.0)

	var enemy := KillEnemy.new()
	root.add_child(enemy)
	var killed := PLAYER_DAMAGE_RESOLVER.deal_damage_to_enemy(owner, enemy, 2.0, "mage_basic:test")
	_expect(killed, "mage basic test hit should kill the enemy")
	_expect(owner.switch_damage_events.size() == 2, "mage basic attack II kill should add normal and bonus switch energy damage events")
	if owner.switch_damage_events.size() == 2:
		_expect(is_equal_approx(float(owner.switch_damage_events[0].get("damage", 0.0)), 2.0), "normal switch energy should use full final damage")
		_expect(is_equal_approx(float(owner.switch_damage_events[1].get("damage", 0.0)), 1.0), "bonus switch energy should add 50 percent of killing hit damage")
	_expect(owner.kill_energy_events.size() == 2, "mage basic attack II kill should add base and bonus ultimate kill energy")
	if owner.kill_energy_events.size() == 2:
		_expect(is_equal_approx(float(owner.kill_energy_events[0].get("amount", 0.0)), 10.0), "base kill energy should be recorded")
		_expect(is_equal_approx(float(owner.kill_energy_events[1].get("amount", 0.0)), 5.0), "bonus kill energy should be 50 percent")
		_expect(str(owner.kill_energy_events[1].get("bypass", "")) == "mage", "bonus mage basic kill energy should bypass the mage post-ultimate lock")
	_expect(owner.fire_timer.time_left <= 0.91 and owner.fire_timer.time_left >= 0.80, "mage basic attack I kill should cut current basic cooldown by about 0.1s")

	owner.switch_damage_events.clear()
	owner.kill_energy_events.clear()
	var non_basic_enemy := KillEnemy.new()
	root.add_child(non_basic_enemy)
	PLAYER_DAMAGE_RESOLVER.deal_damage_to_enemy(owner, non_basic_enemy, 2.0, "mage")
	_expect(owner.switch_damage_events.size() == 1, "plain mage damage should not receive mage basic bonus switch energy")
	_expect(owner.kill_energy_events.size() == 1, "plain mage damage should not receive mage basic bonus ultimate energy")

	enemy.queue_free()
	non_basic_enemy.queue_free()
	owner.queue_free()
	await process_frame


func _has_candidate(candidates: Array, talent_id: String) -> bool:
	for candidate_value in candidates:
		if candidate_value is Dictionary and str((candidate_value as Dictionary).get("id", "")) == talent_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


class TalentOwner:
	extends RefCounted

	var role_special_states: Dictionary = {"mage": {}}
	var blessing_skill_state: Dictionary = {"unlocked": {"meta_field": true, "surging_wave": true}, "tiers": {"meta_field": 1, "surging_wave": 1}}


class MageContextOwner:
	extends Node2D

	var roles: Array = [{"id": "mage", "range": 100.0}]
	var role_upgrade_levels: Dictionary = {"mage": {"range_bonus": 0.0}}
	var role_special_states: Dictionary = {
		"mage": {"level_talents": [MAGE_BASIC_TALENT_FLOW.TALENT_BASIC_ATTACK_2]}
	}

	func _has_level_talent(talent_id: String) -> bool:
		return (role_special_states["mage"].get("level_talents", []) as Array).has(talent_id)

	func _get_active_role() -> Dictionary:
		return roles[0]

	func _get_role_special_state(role_id: String) -> Dictionary:
		return role_special_states.get(role_id, {})

	func _get_mage_mouse_bombard_center(_base_range: float) -> Vector2:
		return Vector2.ZERO

	func _get_random_enemy_cluster_centers(_count: int) -> Array:
		return [Vector2(240.0, 0.0), Vector2(360.0, 0.0)]

	func _get_enemy_targets(_count: int, _include_boss: bool) -> Array:
		return []

	func _get_enemy_near_position(_position: Vector2, _max_distance: float) -> Node2D:
		return null

	func _get_role_attribute_range_multiplier(_role_id: String) -> float:
		return 1.0

	func _get_role_equipment_skill_range_multiplier(_role_id: String) -> float:
		return 1.0

	func _get_mage_arcane_focus_range_multiplier(_arcane_focus_level: float) -> float:
		return 1.0

	func _get_role_damage(_role_id: String) -> float:
		return 100.0

	func _get_priority_target_bonus(_target_enemy: Node2D) -> float:
		return 1.0

	func _get_basic_attack_range_multiplier(_skill_id: String) -> float:
		return 1.0

	func _get_skill_blessing_effect_scales_for_skill(_skill_id: String, _stat: String) -> Array[float]:
		return []


class MageScheduleOwner:
	extends Node2D

	var MAGE_WARNING_EFFECT_SCENE = null
	var MAGE_BOOM_EFFECT_SCENE = null
	var is_dead := false
	var schedules: Array[Dictionary] = []
	var role_special_states: Dictionary = {
		"mage": {"level_talents": [MAGE_BASIC_TALENT_FLOW.TALENT_BASIC_ATTACK_1]}
	}

	func _has_level_talent(talent_id: String) -> bool:
		return (role_special_states["mage"].get("level_talents", []) as Array).has(talent_id)

	func _get_scene_animation_duration(_scene, fallback: float) -> float:
		return fallback

	func _schedule_repeating_sequence(interval: float, count: int, callback: Callable, initial_delay: float = 0.0) -> void:
		schedules.append({
			"interval": interval,
			"count": count,
			"callback": callback,
			"initial_delay": initial_delay
		})


class DamageOwner:
	extends Node

	var fire_timer: Timer
	var role_special_states: Dictionary = {
		"mage": {
			"level_talents": [
				MAGE_BASIC_TALENT_FLOW.TALENT_BASIC_ATTACK_1,
				MAGE_BASIC_TALENT_FLOW.TALENT_BASIC_ATTACK_2
			]
		}
	}
	var switch_damage_events: Array[Dictionary] = []
	var kill_energy_events: Array[Dictionary] = []

	func _has_level_talent(talent_id: String) -> bool:
		return (role_special_states["mage"].get("level_talents", []) as Array).has(talent_id)

	func _add_switch_energy_from_damage(damage_amount: float, source_role_id: String = "") -> void:
		switch_damage_events.append({"damage": damage_amount, "source": source_role_id})

	func _add_kill_energy(amount: float, bypass_lock_role_id: String = "", source_role_id: String = "") -> void:
		kill_energy_events.append({"amount": amount, "bypass": bypass_lock_role_id, "source": source_role_id})

	func _get_kill_energy_from_enemy(_enemy: Node) -> float:
		return 10.0

	func _try_apply_mage_kill_energy_proc(_source_role_id: String, _base_energy: float, _bypass_lock_role_id: String = "") -> void:
		pass

	func _record_attack_result_instance(_role_id: String, _was_critical: bool, _killed: bool, _target_position: Variant = null, _raw_source_role_id: String = "") -> void:
		pass


class KillEnemy:
	extends Node2D

	var current_health := 1.0
	var max_health := 1.0
	var enemy_kind := "normal"
	var reward_tier := 1

	func take_damage(amount: float, _is_critical: bool = false) -> bool:
		current_health = max(0.0, current_health - amount)
		return current_health <= 0.0
