extends RefCounted

const PLAYER_AUTHORED_EFFECTS := preload("res://scripts/player/player_authored_effects.gd")
const COOLDOWN := 13.0
const BASE_DURATION := 1.0
const TIER_TWO_DURATION := 2.0
const TIER_THREE_DURATION := 3.0
const TICK_INTERVAL := 0.1
const MAX_CATCH_UP_TICKS := 6
const MAX_VISUALS := 7
const EXTRA_VISUALS_PER_WIDTH_LEVEL := 3
const BEAM_LENGTH := 168.0
const BEAM_THICKNESS := 34.0
const BASE_WIDTH_MULTIPLIER := 5.0
const GATHER_VISUAL_LENGTH_MULTIPLIER := 1.12
const DIELANG_RANGE_BONUS := 0.42
const DIELANG_DURATION_BONUS := 0.67
const HUICHAO_WIDTH_BONUS := 0.36
const VISUAL_WIDTH_SPREAD_SCALE := 0.92
const INFINITE_RELOAD_SKILL_ID := "infinite_reload"
const TIER_TWO_RANGE_MULTIPLIER := 2.0
const TIER_TWO_MOVE_SPEED_MULTIPLIER := 1.5
const TIER_TWO_TICK_INTERVAL_MULTIPLIER := 0.58
const TIER_THREE_RANGE_MULTIPLIER := 2.5
const TIER_THREE_MOVE_SPEED_MULTIPLIER := 2.0
const TIER_THREE_TICK_INTERVAL_MULTIPLIER := 0.38
const TIER_TWO_DAMAGE_MULTIPLIER := 1.16
const TIER_THREE_DAMAGE_MULTIPLIER := 1.36

var cooldown_remaining: float = 0.0
var active_remaining: float = 0.0
var tick_remaining: float = 0.0
var locked_aim_direction: Vector2 = Vector2.RIGHT
var effects: Array[Node2D] = []

func update(owner, delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = max(0.0, cooldown_remaining - delta)
	if active_remaining <= 0.0:
		return
	if owner == null or not is_instance_valid(owner):
		stop()
		return
	if str(owner._get_active_role().get("id", "")) != "gunner":
		stop()
		return

	active_remaining = max(0.0, active_remaining - delta)
	tick_remaining -= delta
	var catch_up_ticks := 0
	while tick_remaining <= 0.0 and active_remaining > 0.0 and catch_up_ticks < MAX_CATCH_UP_TICKS:
		tick_remaining += _get_tick_interval(owner)
		_trigger_tick(owner)
		catch_up_ticks += 1
	if catch_up_ticks >= MAX_CATCH_UP_TICKS and tick_remaining <= 0.0:
		tick_remaining = _get_tick_interval(owner)
	if active_remaining <= 0.0:
		stop()

func can_trigger(owner, role_id: String) -> bool:
	if owner == null or not is_instance_valid(owner):
		return false
	if bool(owner.get("is_dead")) or bool(owner.get("level_up_active")):
		return false
	if role_id != "gunner":
		return false
	if not _has_required_unlock(owner):
		return false
	return active_remaining <= 0.0 and cooldown_remaining <= 0.0

func try_trigger(owner) -> bool:
	if not can_trigger(owner, str(owner._get_active_role().get("id", ""))):
		return false
	active_remaining = _get_duration(owner)
	cooldown_remaining = _get_cooldown(owner)
	tick_remaining = 0.0
	locked_aim_direction = owner._get_live_mouse_aim_direction(owner.facing_direction)
	if locked_aim_direction.length_squared() <= 0.001:
		locked_aim_direction = Vector2.RIGHT
	owner.facing_direction = locked_aim_direction
	owner.gunner_attack_chain = 0
	_cleanup_effects()
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -64.0), "\u65E0\u9650\u88C5\u586B", Color(1.0, 0.6, 0.34, 1.0))
	owner._spawn_ring_effect(owner.global_position, 104.0, Color(1.0, 0.58, 0.32, 0.34), 8.0, 0.2)
	owner._spawn_burst_effect(owner.global_position, 92.0, Color(1.0, 0.54, 0.28, 0.16), 0.18)
	return true

func stop() -> void:
	active_remaining = 0.0
	tick_remaining = 0.0
	locked_aim_direction = Vector2.RIGHT
	for effect in effects:
		if effect != null and is_instance_valid(effect):
			_release_visual_effect(effect)
	effects.clear()

func is_active() -> bool:
	return active_remaining > 0.0

func register_effect(effect: Node2D, max_visuals: int = MAX_VISUALS) -> void:
	if effect == null or not is_instance_valid(effect):
		return
	_cleanup_effects()
	effects.append(effect)
	while effects.size() > max_visuals:
		var oldest_effect: Node2D = effects.pop_front()
		if oldest_effect != null and is_instance_valid(oldest_effect):
			_release_visual_effect(oldest_effect)

func _release_visual_effect(effect: Node2D) -> void:
	if effect == null or not is_instance_valid(effect):
		return
	PLAYER_AUTHORED_EFFECTS.release_gunner_intersect_effect(effect)

func get_cooldown_slot(owner = null) -> Dictionary:
	var duration := _get_cooldown(owner)
	return {
		"name": "\u65E0\u9650\u88C5\u586B",
		"remaining": clamp(cooldown_remaining, 0.0, duration),
		"duration": duration,
		"color": Color(1.0, 0.56, 0.28, 1.0),
		"description": "无限装填：枪手荡阵进化。短时间高速释放贯穿火力，冷却结束后可再次触发。"
	}

func get_save_data() -> Dictionary:
	return {
		"cooldown_remaining": cooldown_remaining,
		"active_remaining": active_remaining,
		"tick_remaining": tick_remaining,
		"locked_aim_direction": [locked_aim_direction.x, locked_aim_direction.y]
	}

func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)
	active_remaining = clamp(float(data.get("active_remaining", 0.0)), 0.0, TIER_TWO_DURATION + 3.0 * DIELANG_DURATION_BONUS)
	tick_remaining = clamp(float(data.get("tick_remaining", 0.0)), 0.0, TICK_INTERVAL)
	var direction_data: Array = data.get("locked_aim_direction", [locked_aim_direction.x, locked_aim_direction.y])
	if direction_data.size() >= 2:
		locked_aim_direction = Vector2(float(direction_data[0]), float(direction_data[1])).normalized()
	if locked_aim_direction.length_squared() <= 0.001:
		locked_aim_direction = Vector2.RIGHT
	_cleanup_effects()

func _trigger_tick(owner) -> void:
	var aim_direction: Vector2 = owner._get_live_mouse_aim_direction(locked_aim_direction)
	if aim_direction.length_squared() <= 0.001:
		aim_direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	owner.facing_direction = aim_direction
	var range_multiplier: float = _get_range_multiplier(owner) * float(owner._get_role_attribute_range_multiplier("gunner")) * owner._get_equipment_skill_range_multiplier()
	var beam_length: float = BEAM_LENGTH * range_multiplier
	var hit_width: float = BEAM_THICKNESS * BASE_WIDTH_MULTIPLIER * _get_width_multiplier(owner)
	var base_origin: Vector2 = owner.global_position + aim_direction * 20.0
	var damage_amount: float = float(owner._get_role_damage("gunner")) * 0.52 * _get_damage_multiplier(owner)
	var damage_shapes: Array[Dictionary] = []
	_fire_piercing_beam(owner, base_origin, aim_direction, beam_length, hit_width, damage_amount, 1.0, damage_shapes)
	for combo_scale in _get_combo_scales(owner):
		var offset_origin: Vector2 = _get_random_origin_in_hit_width(owner, base_origin, aim_direction, hit_width)
		_fire_piercing_beam(owner, offset_origin, aim_direction, beam_length, hit_width, damage_amount, float(combo_scale), damage_shapes)
	var hit_count: int = _apply_damage_shapes(owner, damage_shapes)
	if hit_count > 0 and not _uses_batched_damage(owner):
		owner._register_attack_result("gunner", hit_count, false)

func _fire_piercing_beam(owner, base_origin: Vector2, aim_direction: Vector2, beam_length: float, hit_width: float, damage_amount: float, effect_scale: float, damage_shapes: Array[Dictionary]) -> void:
	var safe_scale: float = max(0.05, effect_scale)
	_spawn_visuals(owner, base_origin, aim_direction, beam_length, hit_width * safe_scale)
	var hit_center: Vector2 = base_origin + aim_direction * (beam_length * 0.5)
	damage_shapes.append({
		"type": "oriented_rect",
		"center": hit_center,
		"axis": aim_direction,
		"length": beam_length,
		"width": hit_width * safe_scale,
		"damage_amount": damage_amount * safe_scale,
		"vulnerability_bonus": 0.0,
		"slow_multiplier": 1.0,
		"slow_duration": 0.0,
		"source_role_id": "gunner",
		"source_position": base_origin
	})

func _get_random_origin_in_hit_width(owner, base_origin: Vector2, aim_direction: Vector2, hit_width: float) -> Vector2:
	var perpendicular: Vector2 = owner._get_downward_perpendicular(aim_direction).normalized()
	if perpendicular.length_squared() <= 0.001:
		perpendicular = aim_direction.orthogonal().normalized()
	return base_origin + perpendicular * randf_range(-hit_width * 0.5, hit_width * 0.5)

func _spawn_visuals(owner, base_origin: Vector2, aim_direction: Vector2, beam_length: float, hit_width: float) -> void:
	_cleanup_effects()
	var max_visuals: int = _get_max_visuals(owner)
	if effects.size() >= max_visuals:
		return
	var perpendicular: Vector2 = owner._get_downward_perpendicular(aim_direction).normalized()
	if perpendicular.length_squared() <= 0.001:
		perpendicular = aim_direction.orthogonal().normalized()
	var visual_half_width: float = hit_width * 0.5 * VISUAL_WIDTH_SPREAD_SCALE
	var visual_count: int = _get_visuals_per_tick(owner)
	for visual_index in range(visual_count):
		if effects.size() >= max_visuals:
			break
		var offset := 0.0
		if visual_count <= 1:
			offset = randf_range(-visual_half_width, visual_half_width)
		else:
			var lane_width := visual_half_width * 2.0 / float(visual_count)
			var lane_min := -visual_half_width + lane_width * float(visual_index)
			offset = randf_range(lane_min, lane_min + lane_width)
		var visual_origin: Vector2 = base_origin + perpendicular * offset
		var effect := owner._spawn_gunner_intersect_scene_effect(visual_origin, aim_direction, beam_length, BEAM_THICKNESS, BEAM_LENGTH * GATHER_VISUAL_LENGTH_MULTIPLIER) as Node2D
		register_effect(effect, max_visuals)

func _cleanup_effects() -> void:
	var valid_effects: Array[Node2D] = []
	for effect in effects:
		if effect != null and is_instance_valid(effect) and not effect.is_queued_for_deletion() and not bool(effect.get_meta("gunner_intersect_released", false)):
			valid_effects.append(effect)
	effects = valid_effects

func _get_duration(owner) -> float:
	var tier: int = _get_tier(owner)
	var duration := BASE_DURATION
	if tier >= 3:
		duration = TIER_THREE_DURATION
	elif tier >= 2:
		duration = TIER_TWO_DURATION
	if owner != null and owner.has_method("_get_blessing_skill_duration_multiplier"):
		duration *= float(owner._get_blessing_skill_duration_multiplier(INFINITE_RELOAD_SKILL_ID))
	return duration

func _get_range_multiplier(owner) -> float:
	var tier: int = _get_tier(owner)
	var tier_multiplier := 1.0
	if tier >= 3:
		tier_multiplier = TIER_THREE_RANGE_MULTIPLIER
	elif tier >= 2:
		tier_multiplier = TIER_TWO_RANGE_MULTIPLIER
	return float(owner._get_infinite_reload_range_multiplier()) * tier_multiplier

func _get_width_multiplier(_owner) -> float:
	return 1.0

func _get_max_visuals(_owner) -> int:
	return MAX_VISUALS

func _get_visuals_per_tick(owner) -> int:
	return 2 if _get_tier(owner) >= 2 else 1

func _has_required_unlock(owner) -> bool:
	if owner == null or not owner.has_method("_is_blessing_skill_unlocked"):
		return false
	return bool(owner._is_blessing_skill_unlocked(INFINITE_RELOAD_SKILL_ID))

func _get_cooldown(owner) -> float:
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_equipment_cooldown_multiplier"):
		return COOLDOWN * owner._get_equipment_cooldown_multiplier()
	return COOLDOWN

func _get_tier(owner) -> int:
	if owner != null and owner.has_method("_get_blessing_skill_tier"):
		return int(owner._get_blessing_skill_tier(INFINITE_RELOAD_SKILL_ID))
	return 1

func _get_tick_interval(owner) -> float:
	var tier: int = _get_tier(owner)
	if tier >= 3:
		return TICK_INTERVAL * TIER_THREE_TICK_INTERVAL_MULTIPLIER
	if tier >= 2:
		return TICK_INTERVAL * TIER_TWO_TICK_INTERVAL_MULTIPLIER
	return TICK_INTERVAL

func get_move_speed_multiplier(owner) -> float:
	if not is_active():
		return 1.0
	var tier: int = _get_tier(owner)
	if tier >= 3:
		return TIER_THREE_MOVE_SPEED_MULTIPLIER
	if tier >= 2:
		return TIER_TWO_MOVE_SPEED_MULTIPLIER
	return 1.0

func _get_damage_multiplier(owner) -> float:
	var tier: int = _get_tier(owner)
	if tier >= 3:
		return TIER_THREE_DAMAGE_MULTIPLIER
	if tier >= 2:
		return TIER_TWO_DAMAGE_MULTIPLIER
	return 1.0

func _get_combo_scales(owner) -> Array[float]:
	if owner == null or not owner.has_method("_get_blessing_skill_combo_scales"):
		return []
	return owner._get_blessing_skill_combo_scales(INFINITE_RELOAD_SKILL_ID) as Array[float]

func _apply_damage_shapes(owner, shapes: Array[Dictionary]) -> int:
	if shapes.is_empty():
		return 0
	if owner != null and owner.has_method("_damage_enemies_in_shapes_batched"):
		return int(owner._damage_enemies_in_shapes_batched(shapes))
	var hits := 0
	for shape in shapes:
		hits += int(owner._damage_enemies_in_oriented_rect(
			shape.get("center", Vector2.ZERO),
			shape.get("axis", Vector2.RIGHT),
			float(shape.get("length", 1.0)),
			float(shape.get("width", 1.0)),
			float(shape.get("damage_amount", 0.0)),
			float(shape.get("vulnerability_bonus", 0.0)),
			float(shape.get("slow_multiplier", 1.0)),
			float(shape.get("slow_duration", 0.0)),
			str(shape.get("source_role_id", ""))
		))
	return hits

func _uses_batched_damage(owner) -> bool:
	return owner != null and owner.has_method("_damage_enemies_in_shapes_batched")
