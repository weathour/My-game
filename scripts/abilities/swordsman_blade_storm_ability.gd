extends RefCounted

const SWORD_TORNADO_EFFECT_SCENE := preload("res://effects/sword/tornado/tornado.tscn")

const COOLDOWN := 8.0
const BASE_DURATION := 1.6
const TICK_INTERVAL := 0.2
const MAX_CATCH_UP_TICKS := 5
const ROTATION_SPEED := -TAU * 4.9
const BASE_RADIUS := 350.0 * 0.6
const BASE_VISUAL_SCALE := 1.4 * 0.6
const DIELANG_DURATION_BONUS := 0.24
const DIELANG_RADIUS_BONUS := 0.1
const EXTRA_STORM_ORBIT_RADIUS := 170.0
const EXTRA_STORM_ORBIT_SPEED := TAU * 0.72
const RING_VISUAL_EVERY_TICKS := 2

var cooldown_remaining: float = 0.0
var active_remaining: float = 0.0
var tick_remaining: float = 0.0
var orbit_angle: float = 0.0
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
		tick_remaining += TICK_INTERVAL
		_trigger_tick(owner)
		catch_up_ticks += 1
	if catch_up_ticks >= MAX_CATCH_UP_TICKS and tick_remaining <= 0.0:
		tick_remaining = TICK_INTERVAL
	if active_remaining <= 0.0:
		stop()

func can_trigger(owner, role_id: String) -> bool:
	if owner == null or not is_instance_valid(owner):
		return false
	if bool(owner.get("is_dead")) or bool(owner.get("level_up_active")):
		return false
	if role_id != "swordsman":
		return false
	if not owner._has_swordsman_blade_storm_reward():
		return false
	return active_remaining <= 0.0 and cooldown_remaining <= 0.0

func try_trigger(owner) -> bool:
	if not can_trigger(owner, str(owner._get_active_role().get("id", ""))):
		return false
	active_remaining = _get_duration(owner)
	cooldown_remaining = _get_cooldown(owner)
	tick_remaining = 0.0
	orbit_angle = 0.0
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
	active_remaining = clamp(float(data.get("active_remaining", 0.0)), 0.0, BASE_DURATION + 3.0 * DIELANG_DURATION_BONUS)
	tick_remaining = clamp(float(data.get("tick_remaining", 0.0)), 0.0, TICK_INTERVAL)

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
	orbit_angle = wrapf(orbit_angle + EXTRA_STORM_ORBIT_SPEED * delta, 0.0, TAU)
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
	var fury_level: int = max(0, int(owner._get_card_level("battle_blade_storm_fury")))
	return float(owner._get_role_damage("swordsman")) * (0.72 + float(fury_level) * 0.18)

func _get_duration(owner) -> float:
	return BASE_DURATION + float(max(0, int(owner._get_card_level("battle_blade_storm_eye")))) * DIELANG_DURATION_BONUS

func _get_size_multiplier(owner) -> float:
	return 1.0 + float(max(0, int(owner._get_card_level("battle_blade_storm_eye")))) * DIELANG_RADIUS_BONUS

func _get_radius(owner) -> float:
	return BASE_RADIUS * _get_size_multiplier(owner) * owner._get_equipment_skill_range_multiplier()

func _get_extra_storm_count(owner) -> int:
	return max(0, int(owner._get_card_level("battle_blade_storm_multi")))

func _get_storm_local_positions(owner) -> Array[Vector2]:
	var positions: Array[Vector2] = [Vector2.ZERO]
	var extra_count := _get_extra_storm_count(owner)
	if extra_count <= 0:
		return positions
	var orbit_radius: float = EXTRA_STORM_ORBIT_RADIUS * _get_size_multiplier(owner) * owner._get_equipment_skill_range_multiplier()
	for index in range(extra_count):
		var angle := orbit_angle + TAU * float(index) / float(extra_count)
		positions.append(Vector2.RIGHT.rotated(angle) * orbit_radius)
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
