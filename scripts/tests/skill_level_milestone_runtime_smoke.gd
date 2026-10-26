extends SceneTree

const PLAYER_SWORDSMAN_ROLE := preload("res://scripts/player/roles/swordsman_role.gd")
const PLAYER_SKILL_LEVEL_SYSTEM := preload("res://scripts/player/player_skill_level_system.gd")
const PLAYER_SKILL_LEVEL_EFFECT_FLOW := preload("res://scripts/player/player_skill_level_effect_flow.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_basic_attack_extra_slashes()
	if failures.is_empty():
		print("SKILL_LEVEL_MILESTONE_RUNTIME_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_basic_attack_extra_slashes() -> void:
	var role := PLAYER_SWORDSMAN_ROLE.new()
	var expectations := {0: 0, 1: 0, 4: 0, 5: 0, 6: 1, 8: 1, 9: 1}
	for level in expectations.keys():
		var owner := SwordsmanRuntimeStub.new()
		_set_level(owner, "swordsman_basic", int(level))
		role._apply_basic_talent_followup(owner, Vector2.RIGHT, 1.0, "swordsman_basic:test")
		if int(level) >= 6:
			_expect_equal(owner.extra_slash_hits, 0, "combo must wait for its timer")
			owner.global_position = Vector2(300.0, 150.0)
			owner.delayed_callback.call(0)
			_expect_equal(owner.last_slash_center, Vector2(340.0, 150.0), "combo hitbox follows current position and covers the point-blank visual gap")
			_expect_equal(owner.last_interval, 0.25, "combo delay is 0.25 seconds")
		_expect_equal(
			PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_swordsman_basic_attack_extra_slash_count(owner),
			int(expectations[level]),
			"swordsman basic attack level %d milestone count" % int(level)
		)
		_expect_equal(
			owner.extra_slash_hits,
			int(expectations[level]),
			"swordsman basic attack at level %d should fire %s extra slashes" % [int(level), str(expectations[level])]
		)
		_expect_equal(
			owner.scheduled_sequences,
			1 if int(expectations[level]) > 0 else 0,
			"swordsman basic attack at level %d should schedule the extra slashes" % int(level)
		)
		owner.free()


func _set_level(owner, progress_id: String, level: int) -> void:
	var states: Dictionary = owner.role_special_states if owner.role_special_states is Dictionary else {}
	var role_state: Dictionary = states.get("swordsman", {}) if states.get("swordsman", {}) is Dictionary else {}
	var levels: Dictionary = role_state.get("skill_levels", {}) if role_state.get("skill_levels") is Dictionary else {}
	if level <= 1:
		levels.erase(progress_id)
	else:
		levels[progress_id] = level
	role_state["skill_levels"] = levels
	if progress_id == "swordsman_basic":
		levels[progress_id] = level
		role_state["swordsman_basic_build"] = {}
	states["swordsman"] = role_state
	owner.role_special_states = states


func _expect_equal(actual, expected, message: String) -> void:
	if actual != expected:
		failures.append("%s: %s != %s" % [message, str(actual), str(expected)])


class SwordsmanRuntimeStub:
	extends Node

	var roles: Array = [{"id": "swordsman", "name": "剑士", "range": 100.0}]
	var role_upgrade_levels: Dictionary = {"swordsman": {"range_bonus": 0.0}}
	var role_special_states: Dictionary = {}
	var facing_direction := Vector2.RIGHT
	var swordsman_attack_chain: int = 0
	var is_dead: bool = false
	var global_position := Vector2.ZERO
	var extra_slash_hits: int = 0
	var scheduled_sequences: int = 0
	var delayed_callback: Callable
	var last_slash_center := Vector2.ZERO
	var last_interval := 0.0
	var SWORD_SLASH_SCENE_VISIBLE_BOUNDS := Rect2(0.0, 0.0, 100.0, 100.0)
	var SWORD_SLASH_SCENE_SIZE := Vector2(200.0, 200.0)

	func _get_active_role() -> Dictionary:
		return roles[0]

	func _get_active_role_id() -> String:
		return "swordsman"

	func _get_role_damage(_role_id: String) -> float:
		return 10.0

	func _get_attack_aim_direction(fallback: Vector2) -> Vector2:
		return fallback

	func _get_swordsman_normal_attack_scale(_heart_level: float) -> float:
		return 1.0

	func _get_swordsman_normal_attack_width_scale(_heart_level: float) -> float:
		return 1.0

	func _get_role_attribute_range_multiplier(_role_id: String) -> float:
		return 1.0

	func _get_role_equipment_skill_range_multiplier(_role_id: String) -> float:
		return 1.0

	func _get_downward_perpendicular(_direction: Vector2) -> Vector2:
		return Vector2.DOWN

	func _get_sword_slash_scene_animation_duration() -> float:
		return 0.16

	func _spawn_sword_slash_scene_effect(_center: Vector2, _axis: Vector2, _half_length: float, _color: Color, _duration: float, _width: float, _mirrored: bool) -> void:
		pass

	func _damage_enemies_in_oriented_rect_unique(_center: Vector2, _axis: Vector2, _length: float, _rect_width: float, _damage: float, _vulnerability: float, _slow_multiplier: float, _slow_duration: float, _hit_registry: Dictionary, _source_id: String, _slow_source_id: String = "", _knockback_distance: float = 0.0) -> int:
		extra_slash_hits += 1
		last_slash_center = _center
		return 1

	func _schedule_swordsman_slash_followthrough(_center: Vector2, _axis: Vector2, _length: float, _rect_width: float, _damage: float, _vulnerability: float, _slow_multiplier: float, _slow_duration: float, _animation_duration: float, _source_id: String, _hit_registry: Dictionary) -> void:
		pass

	func _spawn_attack_aftershock(_position: Vector2, _role_id: String) -> void:
		pass

	func _register_attack_result(_role_id: String, _hits: int, _killed: bool) -> void:
		pass

	func _get_skill_blessing_effect_scales_for_skill(_skill_id: String, _stat: String) -> Array[float]:
		return []

	func _get_skill_blessing_effect_scales(_stat: String) -> Array[float]:
		return []

	func _schedule_repeating_sequence(_interval: float, repeat_count: int, callback: Callable, _initial_delay: float = 0.0) -> void:
		scheduled_sequences += 1
		last_interval = _initial_delay
		delayed_callback = callback
