extends RefCounted

const SWORD_TORNADO_EFFECT_SCENE := preload("res://effects/sword/tornado/tornado.tscn")

const COOLDOWN := 12.0
const BASE_DURATION := 1.0
const TIER_TWO_DURATION := 1.5
const BASE_TICK_INTERVAL := 0.5
const TIER_TWO_TICK_INTERVAL := 0.4
const MAX_CATCH_UP_TICKS := 5
const ROTATION_SPEED := -TAU * 3.45
const BASE_RADIUS := 350.0 * 0.6
const BASE_VISUAL_SCALE := 1.4 * 0.6
const DIELANG_DURATION_BONUS := 0.24
const DIELANG_RADIUS_BONUS := 0.1
const BLADE_STORM_SKILL_ID := "blade_storm"
const BLADE_STORM_WIDTH_LEVEL := "trick"
const EXTRA_STORM_OFFSET := 150.0
const RING_VISUAL_EVERY_TICKS := 2

var cooldown_remaining: float = 0.0
var active_remaining: float = 0.0
var tick_remaining: float = 0.0
var ring_visual_tick_index: int = 0
var effects: Array[Node2D] = []

func update(owner, delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = max(0.0, cooldown_remaining - delta)

	if active_remaining <= 0.0:
		return

	if owner == null or not is_instance_valid(owner):
		stop()
		return

	if str(owner._get_active_role().get("id", "")) != "swordsman":
		stop()
		return

	active_remaining = max(0.0, active_remaining - delta)
	tick_remaining -= delta
	_update_effect(owner, delta)
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
	if role_id != "swordsman":
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
	ring_visual_tick_index = 0
	_ensure_effect(owner)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -66.0), "\u5251\u5203\u98ce\u66b4", Color(0.42, 0.9, 1.0, 1.0))
	owner._spawn_ring_effect(owner.global_position, _get_radius(owner) * 0.95, Color(0.42, 0.9, 1.0, 0.28), 8.0, 0.2)
	return true

func stop() -> void:
	active_remaining = 0.0
	tick_remaining = 0.0
	for effect in effects:
		if effect != null and is_instance_valid(effect):
			effect.queue_free()
	effects.clear()

func get_cooldown_slot(owner = null) -> Dictionary:
	var duration := _get_cooldown(owner)
	return {
		"name": "\u5251\u5203\u98ce\u66b4",
		"remaining": clamp(cooldown_remaining, 0.0, duration),
		"duration": duration,
		"color": Color(0.34, 0.92, 1.0, 1.0),
		"description": "剑刃风暴：剑士荡阵进化。开启环绕剑刃持续切割周围敌人，冷却期间无法再次触发。"
	}

func get_save_data() -> Dictionary:
	return {
		"cooldown_remaining": cooldown_remaining,
		"active_remaining": active_remaining,
		"tick_remaining": tick_remaining
	}

func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)
	active_remaining = clamp(float(data.get("active_remaining", 0.0)), 0.0, TIER_TWO_DURATION + 3.0 * DIELANG_DURATION_BONUS)
	tick_remaining = clamp(float(data.get("tick_remaining", 0.0)), 0.0, BASE_TICK_INTERVAL)

func restore_effect_if_active(owner) -> void:
	if active_remaining > 0.0:
		_ensure_effect(owner)

func _trigger_tick(owner) -> void:
	var radius: float = _get_radius(owner)
	var damage_amount: float = _get_damage(owner)
	var total_hits := 0
	var should_spawn_ring_visual := ring_visual_tick_index % RING_VISUAL_EVERY_TICKS == 0
	ring_visual_tick_index += 1
	for center in _get_storm_centers(owner):
		total_hits += int(owner._damage_enemies_in_radius(center, radius, damage_amount, 0.08, 1.0, 0.0, "swordsman"))
		if should_spawn_ring_visual:
			owner._spawn_ring_effect(center, radius * 0.88, Color(0.38, 0.86, 1.0, 0.14), 5.0, 0.14)
	if total_hits > 0:
		owner._register_attack_result("swordsman", total_hits, false)

func _ensure_effect(owner) -> void:
	if owner == null or not is_instance_valid(owner) or SWORD_TORNADO_EFFECT_SCENE == null:
		return
	var desired_count: int = 1 + _get_extra_storm_count(owner)
	while effects.size() < desired_count:
		var instance := SWORD_TORNADO_EFFECT_SCENE.instantiate() as Node2D
		if instance == null:
			return
		instance.name = "SwordsmanBladeStormEffect"
		instance.z_index = 18
		owner.add_child(instance)
		effects.append(instance)
		var sprite := instance.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite != null:
			sprite.centered = true
			sprite.position = Vector2.ZERO
			sprite.scale = Vector2.ONE * BASE_VISUAL_SCALE * _get_size_multiplier(owner) * owner._get_equipment_skill_range_multiplier()
			sprite.modulate = Color(1.0, 1.0, 1.0, 0.96)
			if sprite.sprite_frames != null:
				sprite.play()
	for effect in effects:
		if effect != null and is_instance_valid(effect):
			effect.visible = true

func _update_effect(owner, delta: float) -> void:
	_ensure_effect(owner)
	var centers: Array[Vector2] = _get_storm_local_positions(owner)
	var remain_ratio: float = clamp(active_remaining / max(_get_duration(owner), 0.001), 0.0, 1.0)
	for index in range(effects.size()):
		var effect := effects[index] as Node2D
		if effect == null or not is_instance_valid(effect):
			continue
		effect.position = centers[index] if index < centers.size() else Vector2.ZERO
		effect.rotation = wrapf(effect.rotation + ROTATION_SPEED * delta, 0.0, TAU)
		effect.modulate.a = 0.52 + 0.44 * remain_ratio

func _get_damage(owner) -> float:
	var tier_multiplier := 1.18 if _get_tier(owner) >= 2 else 1.0
	return float(owner._get_role_damage("swordsman")) * 0.72 * tier_multiplier

func _get_duration(owner) -> float:
	var duration := TIER_TWO_DURATION if _get_tier(owner) >= 2 else BASE_DURATION
	if owner != null and owner.has_method("_get_blessing_skill_duration_multiplier"):
		duration *= float(owner._get_blessing_skill_duration_multiplier(BLADE_STORM_SKILL_ID))
	return duration

func _get_tick_interval(owner) -> float:
	return TIER_TWO_TICK_INTERVAL if _get_tier(owner) >= 2 else BASE_TICK_INTERVAL

func _get_size_multiplier(owner) -> float:
	return 1.0

func _get_radius(owner) -> float:
	return BASE_RADIUS * _get_size_multiplier(owner) * owner._get_equipment_skill_range_multiplier()

func _get_extra_storm_count(owner) -> int:
	return _get_trick_bonus(owner) if owner != null else 0

func _get_trick_bonus(owner) -> int:
	if owner != null and owner.has_method("_get_blessing_skill_quantity_count"):
		return int(owner._get_blessing_skill_quantity_count(BLADE_STORM_SKILL_ID))
	return 0

func _has_required_unlock(owner) -> bool:
	if owner == null or not owner.has_method("_is_blessing_skill_unlocked"):
		return false
	return bool(owner._is_blessing_skill_unlocked(BLADE_STORM_SKILL_ID))

func _get_storm_local_positions(owner) -> Array[Vector2]:
	var positions: Array[Vector2] = [Vector2.ZERO]
	var extra_count := _get_extra_storm_count(owner)
	if extra_count <= 0:
		return positions
	var direction: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	direction = direction.normalized()
	var side: Vector2 = owner._get_downward_perpendicular(direction).normalized()
	if side.length_squared() <= 0.001:
		side = Vector2.DOWN
	var distance: float = EXTRA_STORM_OFFSET * _get_size_multiplier(owner) * owner._get_equipment_skill_range_multiplier()
	var ordered_offsets: Array[Vector2] = [
		direction * distance,
		-direction * distance,
		-side * distance,
		side * distance
	]
	for index in range(min(extra_count, ordered_offsets.size())):
		positions.append(ordered_offsets[index])
	return positions

func _get_storm_centers(owner) -> Array[Vector2]:
	var centers: Array[Vector2] = []
	for local_position in _get_storm_local_positions(owner):
		centers.append(owner.global_position + local_position)
	return centers

func _get_cooldown(owner) -> float:
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_equipment_cooldown_multiplier"):
		return COOLDOWN * owner._get_equipment_cooldown_multiplier()
	return COOLDOWN

func _get_tier(owner) -> int:
	if owner != null and owner.has_method("_get_blessing_skill_tier"):
		return int(owner._get_blessing_skill_tier(BLADE_STORM_SKILL_ID))
	return 1
