extends RefCounted

const MAGE_GATHERING_EFFECT_SCENE := preload("res://effects/wizard/wave/gathering/gatering.tscn")
const MAGE_WAVE_EFFECT_SCENE := preload("res://effects/wizard/wave/wave.tscn")

const TIER_ONE_COOLDOWN := 16.0
const TIER_TWO_COOLDOWN := 14.0
const WAVE_REPEAT_INTERVAL := 0.3
const BASE_SCALE_MULTIPLIER := 1.5
const HUICHAO_WIDTH_BONUS := 0.12
const WAVE_SPEED := 120.0
const WAVE_LIFETIME := 3.84
const WAVE_HIT_RADIUS := 28.0
const WAVE_VISUAL_SCALE := 5.2
const WAVE_WIDTH_MULTIPLIER := 0.7
const TIDAL_SURGE_RANGE_MULTIPLIER := 0.7
const SURGE_SKILL_ID := "surging_wave"

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
	if not _has_required_unlock(owner):
		return false
	return cooldown_remaining <= 0.0

func try_trigger(owner, base_direction: Vector2) -> bool:
	if not can_trigger(owner, "mage"):
		return false

	cooldown_remaining = _get_cooldown(owner)
	var direction := base_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	owner.facing_direction = direction

	var gather_origin: Vector2 = owner.global_position + direction * 18.0
	var damage_amount: float = float(owner._get_role_damage("mage")) * _get_damage_multiplier(owner)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -64.0), "\u6CE2\u6D9B\u6C79\u6D8C", Color(0.62, 0.9, 1.0, 1.0))
	owner._spawn_ring_effect(owner.global_position, 112.0, Color(0.56, 0.86, 1.0, 0.34), 8.0, 0.22)

	var gather_duration: float = float(owner._get_scene_animation_duration(MAGE_GATHERING_EFFECT_SCENE, 0.16))
	for gather_direction in _get_all_directions():
		owner._spawn_mage_gathering_scene_effect(gather_origin, gather_direction, 1.55 * _get_visual_range_multiplier(owner) * owner._get_equipment_skill_range_multiplier())

	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		return true
	var controller := Node2D.new()
	controller.name = "MageTidalSurgeController"
	current_scene.add_child(controller)
	var tween := controller.create_tween()
	tween.tween_interval(gather_duration)
	var repeat_count: int = 1 + _get_combo_extra_count(owner)
	for repeat_index in range(repeat_count):
		tween.tween_callback(Callable(self, "_fire_direction_group").bind(owner, gather_origin, damage_amount, _get_wave_directions(owner)))
		if repeat_index < repeat_count - 1:
			tween.tween_interval(WAVE_REPEAT_INTERVAL)
	tween.tween_callback(controller.queue_free)
	return true

func get_cooldown_slot(owner = null) -> Dictionary:
	var duration := _get_cooldown(owner)
	return {
		"name": "\u6CE2\u6D9B\u6C79\u6D8C",
		"remaining": clamp(cooldown_remaining, 0.0, duration),
		"duration": duration,
		"color": Color(0.62, 0.84, 1.0, 1.0),
		"description": "波涛涌动：术师荡阵进化。向多方向释放冲击波组，覆盖大范围敌人。"
	}

func _fire_direction_group(owner, origin: Vector2, damage_amount: float, directions: Array) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	for direction in directions:
		_spawn_wave(owner, origin, direction, damage_amount)

func _spawn_wave(owner, origin: Vector2, fire_direction: Vector2, damage_amount: float) -> Node2D:
	var wave = owner._spawn_directional_bullet_from_scene(
		MAGE_WAVE_EFFECT_SCENE,
		fire_direction,
		damage_amount,
		Color(0.56, 0.88, 1.0, 1.0),
		"mage",
		origin + fire_direction * 18.0
	)
	if wave == null:
		return null
	var range_multiplier: float = float(owner._get_story_style_range_multiplier("mage")) * float(owner._get_role_attribute_range_multiplier("mage")) * _get_visual_range_multiplier(owner)
	wave.speed = WAVE_SPEED
	wave.lifetime = WAVE_LIFETIME * _get_lifetime_multiplier(owner)
	wave.hit_radius = WAVE_HIT_RADIUS * range_multiplier * WAVE_WIDTH_MULTIPLIER
	wave.pierce_count = 999
	wave.visual_scale_multiplier = WAVE_VISUAL_SCALE * range_multiplier * WAVE_WIDTH_MULTIPLIER
	wave.enemy_hit_radius_scale = 0.62
	wave.enemy_hit_radius_min = 12.0
	wave.enemy_hit_radius_max = 72.0 * _get_scale_multiplier(owner) * WAVE_WIDTH_MULTIPLIER
	return wave

func _get_scale_multiplier(owner) -> float:
	var quantity_bonus := float(_get_quantity_extra_count(owner)) * HUICHAO_WIDTH_BONUS
	return BASE_SCALE_MULTIPLIER * (1.0 + quantity_bonus)

func _get_visual_range_multiplier(owner) -> float:
	return _get_scale_multiplier(owner) * TIDAL_SURGE_RANGE_MULTIPLIER

func _get_cardinal_directions() -> Array[Vector2]:
	return [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]

func _get_diagonal_directions() -> Array[Vector2]:
	return [
		Vector2(1.0, 1.0).normalized(),
		Vector2(-1.0, 1.0).normalized(),
		Vector2(-1.0, -1.0).normalized(),
		Vector2(1.0, -1.0).normalized()
	]

func _get_all_directions() -> Array[Vector2]:
	var directions := _get_cardinal_directions()
	directions.append_array(_get_diagonal_directions())
	return directions

func _get_wave_directions(owner) -> Array[Vector2]:
	var quantity_count := _get_quantity_extra_count(owner)
	if quantity_count <= 0:
		var direction: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
		return [direction.normalized()]
	var directions: Array[Vector2] = []
	var total_count: int = min(8, 1 + quantity_count)
	for index in range(total_count):
		directions.append(Vector2.RIGHT.rotated(TAU * float(index) / float(total_count)))
	return directions

func _get_cooldown(owner) -> float:
	var base_cooldown := TIER_TWO_COOLDOWN if _get_tier(owner) >= 2 else TIER_ONE_COOLDOWN
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_equipment_cooldown_multiplier"):
		return base_cooldown * owner._get_equipment_cooldown_multiplier()
	return base_cooldown

func _has_required_unlock(owner) -> bool:
	if owner == null or not owner.has_method("_is_blessing_skill_unlocked"):
		return false
	return bool(owner._is_blessing_skill_unlocked(SURGE_SKILL_ID))

func _get_tier(owner) -> int:
	if owner != null and owner.has_method("_get_blessing_skill_tier"):
		return int(owner._get_blessing_skill_tier(SURGE_SKILL_ID))
	return 1

func _get_combo_extra_count(owner) -> int:
	if owner == null or not owner.has_method("_get_blessing_skill_combo_scales"):
		return 0
	return (owner._get_blessing_skill_combo_scales(SURGE_SKILL_ID) as Array).size()

func _get_quantity_extra_count(owner) -> int:
	if owner == null or not owner.has_method("_get_blessing_skill_quantity_count"):
		return 0
	return int(owner._get_blessing_skill_quantity_count(SURGE_SKILL_ID))

func _get_lifetime_multiplier(owner) -> float:
	var multiplier := 4.0 / 3.0 if _get_tier(owner) >= 2 else 1.0
	if owner != null and owner.has_method("_get_blessing_skill_duration_multiplier"):
		multiplier *= float(owner._get_blessing_skill_duration_multiplier(SURGE_SKILL_ID))
	return multiplier

func _get_damage_multiplier(owner) -> float:
	return 1.5 if _get_tier(owner) >= 2 else 1.0
