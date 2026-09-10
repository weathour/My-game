extends SceneTree

const MAGE_SURGE_ABILITY := preload("res://scripts/abilities/mage_tidal_surge_ability.gd")
const MAGE_SURGE_LEVEL_TALENT_FLOW := preload("res://scripts/player/player_mage_surging_wave_talent_flow.gd")
const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_level_talent_definitions()
	_check_ability_modifiers()
	await _check_path_trail()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("MAGE_SURGING_WAVE_LEVEL_TALENTS_SMOKE_OK")
	quit(0)


func _check_level_talent_definitions() -> void:
	var definitions: Array = PLAYER_SKILL_TALENT_SYSTEM.LEVEL_TALENT_DEFINITIONS.get("mage", [])
	_expect(_has_candidate(definitions, MAGE_SURGE_LEVEL_TALENT_FLOW.TALENT_SURGING_WAVE_1), "surging wave I level talent should be registered")
	_expect(_has_candidate(definitions, MAGE_SURGE_LEVEL_TALENT_FLOW.TALENT_SURGING_WAVE_2), "surging wave II level talent should be registered")

	var locked_owner := TalentOwner.new()
	locked_owner.blessing_skill_state = {"unlocked": {}, "tiers": {}}
	var locked_candidates: Array = PLAYER_SKILL_TALENT_SYSTEM._collect_level_talent_candidates(locked_owner, definitions, {}, false)
	_expect(not _has_candidate(locked_candidates, MAGE_SURGE_LEVEL_TALENT_FLOW.TALENT_SURGING_WAVE_1), "surging wave level talents should not refresh before skill unlock")

	var owner := TalentOwner.new()
	var candidates: Array = PLAYER_SKILL_TALENT_SYSTEM._collect_level_talent_candidates(owner, definitions, {}, false)
	_expect(_has_candidate(candidates, MAGE_SURGE_LEVEL_TALENT_FLOW.TALENT_SURGING_WAVE_1), "surging wave I should refresh after skill unlock")
	_expect(_has_candidate(candidates, MAGE_SURGE_LEVEL_TALENT_FLOW.TALENT_SURGING_WAVE_2), "surging wave II should refresh after skill unlock")

	owner.role_special_states["mage"] = {"level_talents": [MAGE_SURGE_LEVEL_TALENT_FLOW.TALENT_SURGING_WAVE_1]}
	candidates = PLAYER_SKILL_TALENT_SYSTEM._collect_level_talent_candidates(owner, definitions, {}, false)
	_expect(not _has_candidate(candidates, MAGE_SURGE_LEVEL_TALENT_FLOW.TALENT_SURGING_WAVE_2), "same-scope surging wave II should be locked after picking I")


func _check_ability_modifiers() -> void:
	var owner := TalentOwner.new()
	var surge := MAGE_SURGE_ABILITY.new()
	owner.level_talents = {MAGE_SURGE_LEVEL_TALENT_FLOW.TALENT_SURGING_WAVE_1: true}
	owner.quantity_count = 3
	var base_range: float = surge._get_scale_multiplier(owner) * MAGE_SURGE_ABILITY.TIDAL_SURGE_RANGE_MULTIPLIER
	_expect(is_equal_approx(surge._get_visual_range_multiplier(owner), base_range * 1.20), "surging wave I should enlarge wave range by 20 percent")
	var directions: Array[Vector2] = surge._get_wave_directions(owner, 1.0, false)
	_expect(directions.size() == 2, "surging wave I should force two shockwaves even with quantity builds")
	if directions.size() == 2:
		_expect(is_equal_approx(abs(directions[0].angle_to(directions[1])), deg_to_rad(30.0)), "surging wave I shockwaves should be 30 degrees apart")

	owner.level_talents = {MAGE_SURGE_LEVEL_TALENT_FLOW.TALENT_SURGING_WAVE_2: true}
	owner.quantity_count = 0
	_expect(is_equal_approx(surge._get_lifetime(owner), MAGE_SURGE_ABILITY.WAVE_LIFETIME + 2.0), "surging wave II should extend wave lifetime by 2 seconds")


func _check_path_trail() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var owner := TalentOwner.new()
	owner.level_talents = {MAGE_SURGE_LEVEL_TALENT_FLOW.TALENT_SURGING_WAVE_2: true}
	scene.add_child(owner)
	var wave := WaveStub.new()
	wave.lifetime = 1.0
	wave.damage = 200.0
	wave.hit_radius = 20.0
	wave.set_meta("mage_surge_token", 7)
	wave.set_meta("player_projectile_released", false)
	scene.add_child(wave)
	await process_frame

	MAGE_SURGE_LEVEL_TALENT_FLOW.start_path_trail(owner, wave, 7, Vector2.ZERO, "mage")
	_expect(owner.schedules.size() == 1, "surging wave II should schedule one path trail scanner")
	_expect(_find_trail_polygon(scene) != null, "surging wave II should create a rectangular trail visual")
	if owner.schedules.size() > 0:
		wave.global_position = Vector2(100.0, 0.0)
		# 拖尾多边形由 trail 节点的 _process 驱动; 等两帧让出一帧处理(信号先于节点 _process 触发)
		await process_frame
		await process_frame
		var callback: Callable = owner.schedules[0].get("callback")
		callback.call(0)
	_expect(owner.rect_damage_calls.size() == 1, "surging wave II trail should damage enemies along one oriented rectangle each tick")
	if owner.rect_damage_calls.size() == 1:
		var call: Dictionary = owner.rect_damage_calls[0]
		_expect(is_equal_approx(float(call.get("damage", 0.0)), 12.0), "surging wave II trail tick damage should be 30 percent per second")
		_expect(is_equal_approx(float(call.get("slow_multiplier", 1.0)), MAGE_SURGE_LEVEL_TALENT_FLOW.TRAIL_SLOW_MULTIPLIER), "surging wave II trail should apply configured 70 percent slow")
		_expect(is_equal_approx(float(call.get("width", 0.0)), 40.0), "surging wave II trail rectangle width should follow wave hit width")
	var trail := _find_trail_polygon(scene)
	if trail != null:
		_expect(is_equal_approx(trail.color.a, MAGE_SURGE_LEVEL_TALENT_FLOW.TRAIL_ALPHA), "surging wave II trail visual should use 10 percent alpha")
		_expect(trail.polygon.size() == 4, "surging wave II trail visual should be a rectangle without outline")

	wave.set_meta("player_projectile_released", true)
	if owner.schedules.size() > 0:
		var callback: Callable = owner.schedules[0].get("callback")
		callback.call(1)
	if trail != null:
		_expect(not trail.visible, "surging wave II trail should hide after wave release")

	scene.queue_free()
	await process_frame
	current_scene = null


func _find_trail_polygon(scene: Node) -> Polygon2D:
	for child in scene.get_children():
		if child is Polygon2D:
			return child as Polygon2D
	return null


func _has_candidate(candidates: Array, talent_id: String) -> bool:
	for candidate_value in candidates:
		if candidate_value is Dictionary and str((candidate_value as Dictionary).get("id", "")) == talent_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


class TalentOwner:
	extends Node2D

	var level_talents: Dictionary = {}
	var blessing_skill_state: Dictionary = {"unlocked": {"surging_wave": true}, "tiers": {"surging_wave": 1}}
	var role_special_states: Dictionary = {"mage": {"level_talents": []}}
	var facing_direction := Vector2.RIGHT
	var quantity_count := 0
	var schedules: Array[Dictionary] = []
	var rect_damage_calls: Array[Dictionary] = []

	func _has_level_talent(talent_id: String) -> bool:
		return bool(level_talents.get(talent_id, false))


	func _get_blessing_skill_tier(_skill_id: String) -> int:
		return 1

	func _get_blessing_skill_quantity_count(_skill_id: String) -> int:
		return quantity_count

	func _get_kebiru_magic_range_multiplier(_skill_id: String) -> float:
		return 1.0

	func _get_blessing_skill_duration_multiplier(_skill_id: String) -> float:
		return 1.0

	func _get_blessing_skill_duration_flat_bonus(_skill_id: String) -> float:
		return 0.0

	func _schedule_repeating_sequence(interval: float, count: int, callback: Callable, initial_delay: float = 0.0) -> void:
		schedules.append({
			"interval": interval,
			"count": count,
			"callback": callback,
			"initial_delay": initial_delay
		})

	func _damage_enemies_in_oriented_rect(center: Vector2, direction: Vector2, length: float, width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
		rect_damage_calls.append({
			"center": center,
			"direction": direction,
			"length": length,
			"width": width,
			"damage": damage_amount,
			"vulnerability_bonus": vulnerability_bonus,
			"slow_multiplier": slow_multiplier,
			"slow_duration": slow_duration,
			"source_role_id": source_role_id
		})
		return 1


class WaveStub:
	extends Node2D

	var lifetime := 1.0
	var damage := 0.0
	var hit_radius := 20.0
