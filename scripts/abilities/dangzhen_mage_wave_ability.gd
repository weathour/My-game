extends RefCounted

const MAGE_GATHERING_EFFECT_SCENE := preload("res://effects/wizard/wave/gathering/gatering.tscn")
const MAGE_WAVE_EFFECT_SCENE := preload("res://effects/wizard/wave/wave.tscn")

const COOLDOWN := 9.0
const DIELANG_INTERVAL := 0.5
const HUICHAO_HALF_SPREAD := deg_to_rad(15.0)
const HUICHAO_FULL_SPREAD := deg_to_rad(30.0)
const WAVE_SPEED := 120.0
const WAVE_LIFETIME := 3.84
const WAVE_HIT_RADIUS := 28.0
const WAVE_VISUAL_SCALE := 5.2
const WAVE_WIDTH_MULTIPLIER := 0.7

var cooldown_remaining: float = 0.0

func update(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = max(0.0, cooldown_remaining - delta)

func can_trigger(owner, role_id: String) -> bool:
	if owner == null or not is_instance_valid(owner):
		return false
	if bool(owner.get("is_dead")) or bool(owner.get("level_up_active")):
		return false
	if role_id != "mage":
		return false
	if owner._has_mage_tidal_surge_reward():
		return false
	if int(owner._get_card_level("battle_dangzhen_qichao")) <= 0:
		return false
	return cooldown_remaining <= 0.0

func try_trigger(owner, wave_direction: Vector2, role_id: String) -> bool:
	if not can_trigger(owner, role_id):
		return false

	cooldown_remaining = _get_cooldown(owner)
	var qichao_level := int(owner._get_card_level("battle_dangzhen_qichao"))
	var split_level := int(owner._get_card_level("battle_dangzhen_dielang"))
	var huichao_level := int(owner._get_card_level("battle_dangzhen_huichao"))
	var qichao_damage := float(owner._get_dangzhen_qichao_damage(role_id, qichao_level))

	var base_direction := wave_direction.normalized()
	if base_direction.length_squared() <= 0.001:
		base_direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT

	var gather_origin: Vector2 = owner.global_position + base_direction * 18.0
	owner._spawn_mage_gathering_scene_effect(gather_origin, base_direction, 1.25 * WAVE_WIDTH_MULTIPLIER * owner._get_equipment_skill_range_multiplier())
	var gather_duration := float(owner._get_scene_animation_duration(MAGE_GATHERING_EFFECT_SCENE, 0.16))
	var tween: Tween = owner.create_tween()
	tween.tween_interval(gather_duration)
	tween.tween_callback(Callable(self, "_spawn_wave_set").bind(owner, gather_origin, base_direction, qichao_damage, role_id, huichao_level))
	for _extra_index in range(split_level):
		tween.tween_interval(DIELANG_INTERVAL)
		tween.tween_callback(Callable(self, "_spawn_wave_set").bind(owner, gather_origin, base_direction, qichao_damage, role_id, huichao_level))
	return true

func get_cooldown_slot(owner = null) -> Dictionary:
	var duration := _get_cooldown(owner)
	return {
		"name": "\u8361\u9635",
		"remaining": clamp(cooldown_remaining, 0.0, duration),
		"duration": duration,
		"color": Color(1.0, 0.54, 0.9, 1.0),
		"description": "荡阵·术师：短暂蓄力后发射波浪；叠浪增加连续波次，回潮扩展为多方向。"
	}

func _spawn_wave_set(owner, origin: Vector2, base_direction: Vector2, damage_amount: float, role_id: String, huichao_level: int) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var normalized_base_direction := base_direction.normalized()
	if normalized_base_direction.length_squared() <= 0.001:
		normalized_base_direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	for angle_offset in _get_angle_offsets(huichao_level):
		var fire_direction := normalized_base_direction.rotated(angle_offset).normalized()
		_spawn_wave(owner, origin, fire_direction, damage_amount, role_id)

func _spawn_wave(owner, origin: Vector2, fire_direction: Vector2, damage_amount: float, role_id: String) -> Node2D:
	var wave = owner._spawn_directional_bullet_from_scene(
		MAGE_WAVE_EFFECT_SCENE,
		fire_direction,
		damage_amount,
		Color(1.0, 0.62, 0.36, 1.0),
		role_id,
		origin + fire_direction * 16.0
	)
	if wave == null:
		return null
	var range_multiplier := float(owner._get_story_style_range_multiplier("mage"))
	wave.speed = WAVE_SPEED
	wave.lifetime = WAVE_LIFETIME
	wave.hit_radius = WAVE_HIT_RADIUS * range_multiplier * WAVE_WIDTH_MULTIPLIER
	wave.pierce_count = 999
	wave.visual_scale_multiplier = WAVE_VISUAL_SCALE * range_multiplier * WAVE_WIDTH_MULTIPLIER
	wave.enemy_hit_radius_scale = 0.62
	wave.enemy_hit_radius_min = 12.0
	wave.enemy_hit_radius_max = 30.0 * WAVE_WIDTH_MULTIPLIER
	return wave

func _get_angle_offsets(huichao_level: int) -> Array[float]:
	if huichao_level <= 0:
		return [0.0]
	if huichao_level == 1:
		return [-HUICHAO_HALF_SPREAD, HUICHAO_HALF_SPREAD]
	return [-HUICHAO_FULL_SPREAD, 0.0, HUICHAO_FULL_SPREAD]

func _get_cooldown(owner) -> float:
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_equipment_cooldown_multiplier"):
		return COOLDOWN * owner._get_equipment_cooldown_multiplier()
	return COOLDOWN
