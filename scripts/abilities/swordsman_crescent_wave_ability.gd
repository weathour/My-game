extends RefCounted

const CRESCENT_SCENE := preload("res://effects/sword/fan/fan.tscn")

const SKILL_ID := "crescent_wave"
const COOLDOWN := 6.0
const SLASH_LENGTH := 122.0
const SLASH_WIDTH := 52.0
const WAVE_LENGTH := 430.0
const WAVE_WIDTH := 58.0
const TIER_TWO_WIDTH_MULTIPLIER := 1.2
const TIER_TWO_DAMAGE_MULTIPLIER := 1.45
const TIER_TWO_SPEED_MULTIPLIER := 1.3
const TIER_THREE_WIDTH_MULTIPLIER := 1.4
const TIER_THREE_DAMAGE_MULTIPLIER := 1.65
const TIER_THREE_SPEED_MULTIPLIER := 1.6
const BASE_WAVE_SPEED := 520.0
const COMBO_INTERVAL := 0.16
const VISUAL_AND_HIT_SCALE := 0.6
const FAN_SCENE_SIZE := Vector2(1024.0, 1024.0)
const FAN_SCENE_VISIBLE_BOUNDS := Rect2(485.0, 405.0, 117.0, 50.0)
const FAN_WAVE_BASE_VISIBLE_SIZE := Vector2(138.0, 74.0)
const SLASH_EFFECT_MAX_LIFETIME := 0.32
const SLASH_DAMAGE_RATIO := 1.18
const WAVE_DAMAGE_RATIO := 1.42

var cooldown_remaining: float = 0.0


func update(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = max(0.0, cooldown_remaining - delta)


func can_trigger(owner, role_id: String) -> bool:
	if owner == null or not is_instance_valid(owner):
		return false
	if bool(owner.get("is_dead")) or bool(owner.get("level_up_active")):
		return false
	if role_id != "swordsman":
		return false
	if not _has_required_unlock(owner):
		return false
	return cooldown_remaining <= 0.0


func try_trigger(owner) -> bool:
	if not can_trigger(owner, str(owner._get_active_role().get("id", ""))):
		return false
	cooldown_remaining = _get_cooldown(owner)
	var base_direction: Vector2 = owner._get_live_mouse_aim_direction(owner.facing_direction)
	if base_direction.length_squared() <= 0.001:
		base_direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	owner.facing_direction = base_direction.normalized()
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -68.0), "\u6708\u7259\u5251\u6c14", Color(0.54, 0.92, 1.0, 1.0))
	var directions: Array[Vector2] = _get_cast_directions(owner, owner.facing_direction)
	var combo_scales: Array[float] = _get_combo_scales(owner)
	_cast_direction_group(owner, directions, 1.0)
	for index in range(combo_scales.size()):
		_schedule_combo(owner, directions, float(combo_scales[index]), COMBO_INTERVAL * float(index + 1))
	return true


func get_cooldown_slot(owner = null) -> Dictionary:
	var duration: float = _get_cooldown(owner)
	return {
		"name": "\u6708\u7259\u5251\u6c14",
		"remaining": clamp(cooldown_remaining, 0.0, duration),
		"duration": duration,
		"color": Color(0.48, 0.9, 1.0, 1.0),
		"description": "\u5251\u58eb\u5411\u524d\u65a9\u51fb\u540e\u91ca\u653e\u4e00\u9053\u6708\u7259\u5251\u6c14\uff0c\u5bf9\u524d\u65b9\u957f\u77e9\u5f62\u533a\u57df\u9020\u6210\u4f24\u5bb3\u3002"
	}


func get_save_data() -> Dictionary:
	return {"cooldown_remaining": cooldown_remaining}


func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)


func _schedule_combo(owner, directions: Array[Vector2], scale: float, delay: float) -> void:
	var tree: SceneTree = owner.get_tree()
	if tree == null:
		return
	var timer: SceneTreeTimer = tree.create_timer(delay)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(owner):
			_cast_direction_group(owner, directions, scale)
	)


func _cast_direction_group(owner, directions: Array[Vector2], damage_scale: float) -> void:
	for direction in directions:
		_cast_once(owner, direction, damage_scale)


func _cast_once(owner, direction: Vector2, damage_scale: float) -> void:
	var width_multiplier: float = _get_width_multiplier(owner)
	var visual_hit_multiplier: float = width_multiplier * VISUAL_AND_HIT_SCALE
	var slash_width: float = SLASH_WIDTH * visual_hit_multiplier
	var slash_length: float = SLASH_LENGTH * visual_hit_multiplier
	var wave_width: float = WAVE_WIDTH * visual_hit_multiplier
	var wave_length: float = WAVE_LENGTH * _get_range_multiplier(owner)
	var slash_center: Vector2 = owner.global_position + direction * (slash_length * 0.42)
	var slash_effect := owner._spawn_sword_fan_scene_effect(slash_center, direction, visual_hit_multiplier) as Node2D
	_schedule_effect_cleanup(owner, slash_effect, SLASH_EFFECT_MAX_LIFETIME)
	var slash_hits: int = int(owner._damage_enemies_in_oriented_rect(
		slash_center,
		direction,
		slash_length,
		slash_width,
		_get_damage(owner) * SLASH_DAMAGE_RATIO * damage_scale,
		0.02,
		1.0,
		0.0,
		"swordsman"
	))
	var wave_origin: Vector2 = owner.global_position + direction * max(24.0, slash_length * 0.72)
	_spawn_crescent_projectile(owner, wave_origin, direction, wave_length, wave_width, visual_hit_multiplier, _get_damage(owner) * WAVE_DAMAGE_RATIO * damage_scale)
	if slash_hits > 0:
		owner._register_attack_result("swordsman", slash_hits, false)


func _spawn_crescent_projectile(owner, origin: Vector2, direction: Vector2, length: float, width: float, visual_scale: float, damage_amount: float) -> void:
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		return
	var projectile: Node2D = CRESCENT_SCENE.instantiate() as Node2D if CRESCENT_SCENE != null else Node2D.new()
	if projectile == null:
		projectile = Node2D.new()
	projectile.name = "SwordsmanCrescentWave"
	projectile.global_position = origin
	projectile.rotation = direction.angle() + PI
	projectile.z_index = 14
	projectile.add_to_group("temporary_effects")
	_configure_crescent_visual(projectile, visual_scale)
	current_scene.add_child(projectile)

	var duration: float = length / max(1.0, _get_wave_speed(owner))
	var hit_registry: Dictionary = {}
	var tween: Tween = projectile.create_tween()
	var update_wave := func(progress: float) -> void:
		if not is_instance_valid(projectile) or not is_instance_valid(owner):
			return
		var current_position: Vector2 = origin + direction * (length * progress)
		projectile.global_position = current_position
		var hit_count: int = int(owner._damage_enemies_in_oriented_rect_unique(
			current_position,
			direction,
			52.0 * VISUAL_AND_HIT_SCALE,
			width,
			damage_amount,
			0.03,
			1.0,
			0.0,
			hit_registry,
			"swordsman"
		))
		if hit_count > 0:
			owner._register_attack_result("swordsman", hit_count, false)
	tween.tween_method(update_wave, 0.0, 1.0, duration)
	tween.tween_callback(_free_projectile.bind(projectile))


func _configure_crescent_visual(projectile: Node2D, visual_scale: float) -> void:
	var sprite: AnimatedSprite2D = projectile.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return
	sprite.centered = true
	sprite.position = Vector2.ZERO
	sprite.offset = FAN_SCENE_SIZE * 0.5 - (FAN_SCENE_VISIBLE_BOUNDS.position + FAN_SCENE_VISIBLE_BOUNDS.size * 0.5)
	sprite.modulate = Color.WHITE
	var target_visible_size: Vector2 = FAN_WAVE_BASE_VISIBLE_SIZE * visual_scale
	sprite.scale = Vector2(
		target_visible_size.x / max(1.0, FAN_SCENE_VISIBLE_BOUNDS.size.x),
		target_visible_size.y / max(1.0, FAN_SCENE_VISIBLE_BOUNDS.size.y)
	)
	if sprite.sprite_frames != null:
		var animation_name: StringName = sprite.animation
		var animation_names: PackedStringArray = sprite.sprite_frames.get_animation_names()
		if animation_name == StringName() and animation_names.size() > 0:
			animation_name = StringName(animation_names[0])
		if animation_name != StringName():
			sprite.sprite_frames.set_animation_loop(animation_name, true)
			sprite.animation = animation_name
			sprite.frame = 0
			sprite.frame_progress = 0.0
			sprite.play(animation_name)


func _schedule_effect_cleanup(owner, effect: Node2D, delay: float) -> void:
	if effect == null or not is_instance_valid(effect):
		return
	var tree: SceneTree = owner.get_tree()
	if tree == null:
		return
	var timer: SceneTreeTimer = tree.create_timer(delay)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(effect):
			effect.queue_free()
	)


func _free_projectile(projectile: Node2D) -> void:
	if is_instance_valid(projectile):
		projectile.queue_free()


func _get_cast_directions(owner, base_direction: Vector2) -> Array[Vector2]:
	var directions: Array[Vector2] = [base_direction.normalized()]
	var extra_count: int = 0
	if owner != null and owner.has_method("_get_blessing_skill_quantity_count"):
		extra_count = int(owner._get_blessing_skill_quantity_count(SKILL_ID))
	for index in range(extra_count):
		directions.append(base_direction.rotated(deg_to_rad(30.0 * float(index + 1))).normalized())
	return directions


func _get_combo_scales(owner) -> Array[float]:
	if owner == null or not owner.has_method("_get_blessing_skill_combo_scales"):
		return []
	return owner._get_blessing_skill_combo_scales(SKILL_ID) as Array[float]


func _has_required_unlock(owner) -> bool:
	return owner != null and owner.has_method("_is_blessing_skill_unlocked") and bool(owner._is_blessing_skill_unlocked(SKILL_ID))


func _get_tier(owner) -> int:
	if owner != null and owner.has_method("_get_blessing_skill_tier"):
		return int(owner._get_blessing_skill_tier(SKILL_ID))
	return 1


func _get_cooldown(owner) -> float:
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_equipment_cooldown_multiplier"):
		return COOLDOWN * owner._get_equipment_cooldown_multiplier()
	return COOLDOWN


func _get_width_multiplier(owner) -> float:
	var tier: int = _get_tier(owner)
	var tier_multiplier := 1.0
	if tier >= 3:
		tier_multiplier = TIER_THREE_WIDTH_MULTIPLIER
	elif tier >= 2:
		tier_multiplier = TIER_TWO_WIDTH_MULTIPLIER
	return tier_multiplier * float(owner._get_equipment_skill_range_multiplier())


func _get_range_multiplier(owner) -> float:
	return float(owner._get_equipment_skill_range_multiplier())


func _get_wave_speed(owner) -> float:
	var tier: int = _get_tier(owner)
	if tier >= 3:
		return BASE_WAVE_SPEED * TIER_THREE_SPEED_MULTIPLIER
	if tier >= 2:
		return BASE_WAVE_SPEED * TIER_TWO_SPEED_MULTIPLIER
	return BASE_WAVE_SPEED


func _get_damage(owner) -> float:
	var tier: int = _get_tier(owner)
	if tier >= 3:
		return float(owner._get_role_damage("swordsman")) * TIER_THREE_DAMAGE_MULTIPLIER
	if tier >= 2:
		return float(owner._get_role_damage("swordsman")) * TIER_TWO_DAMAGE_MULTIPLIER
	return float(owner._get_role_damage("swordsman"))
