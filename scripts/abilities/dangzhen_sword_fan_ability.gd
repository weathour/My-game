extends RefCounted

const SWORD_FAN_EFFECT_SCENE := preload("res://effects/sword/fan/fan.tscn")

const COOLDOWN := 1.8

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
	if owner._has_swordsman_blade_storm_reward():
		return false
	if int(owner._get_card_level("battle_dangzhen_qichao")) <= 0:
		return false
	return cooldown_remaining <= 0.0

func try_trigger(owner, attack_direction: Vector2, role_id: String) -> int:
	if not can_trigger(owner, role_id):
		return 0

	cooldown_remaining = _get_cooldown(owner)
	var qichao_level := int(owner._get_card_level("battle_dangzhen_qichao"))
	var split_level := int(owner._get_card_level("battle_dangzhen_dielang"))
	var huichao_level := int(owner._get_card_level("battle_dangzhen_huichao"))
	var qichao_damage := float(owner._get_dangzhen_qichao_damage(role_id, qichao_level))
	var extra_count := split_level
	var base_direction := attack_direction.normalized()
	if base_direction.length_squared() <= 0.001:
		base_direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT

	var primary_directions: Array[Vector2] = [base_direction]
	if huichao_level >= 1:
		primary_directions.append(-base_direction)

	var total_hits := 0
	var fan_animation_duration: float = float(owner._get_scene_animation_duration(SWORD_FAN_EFFECT_SCENE, 0.2))
	for slash_direction in primary_directions:
		total_hits += execute_slash(owner, owner.global_position, slash_direction, qichao_damage, split_level, huichao_level, role_id)
		if extra_count > 0:
			_schedule_follow_slashes(owner, slash_direction, qichao_damage, split_level, huichao_level, role_id, extra_count, fan_animation_duration)

	if huichao_level >= 2:
		_schedule_cross_slashes(owner, base_direction, qichao_damage, split_level, huichao_level, role_id, extra_count, fan_animation_duration)

	return total_hits

func execute_slash(owner, slash_origin: Vector2, slash_direction: Vector2, damage_amount: float, split_level: int, huichao_level: int, role_id: String) -> int:
	if owner == null or not is_instance_valid(owner):
		return 0
	var direction := slash_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	var visual_size: Vector2 = owner._get_dangzhen_sword_visual_size(split_level, huichao_level) * owner._get_equipment_skill_range_multiplier()
	var fan_center: Vector2 = slash_origin + direction * 52.0
	owner._spawn_sword_fan_scene_effect(fan_center, direction, visual_size.x / 138.0)
	var hit_center: Vector2 = slash_origin + direction * (34.0 + visual_size.x * 0.18)
	var hit_length: float = visual_size.x * 0.92
	var hit_width: float = visual_size.y * 0.84
	return int(owner._damage_enemies_in_oriented_rect(hit_center, direction, hit_length, hit_width, damage_amount, 0.0, 1.0, 0.0, role_id))

func get_cooldown_slot(owner = null) -> Dictionary:
	var duration := _get_cooldown(owner)
	return {
		"name": "\u8361\u9635",
		"remaining": clamp(cooldown_remaining, 0.0, duration),
		"duration": duration,
		"color": Color(0.36, 0.88, 1.0, 1.0),
		"description": "荡阵·剑士：向前方挥出扇形剑气；叠浪会追加补发，回潮会扩展为反向/十字方向。"
	}

func _get_cooldown(owner) -> float:
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_equipment_cooldown_multiplier"):
		return COOLDOWN * owner._get_equipment_cooldown_multiplier()
	return COOLDOWN

func _schedule_follow_slashes(owner, slash_direction: Vector2, damage_amount: float, split_level: int, huichao_level: int, role_id: String, extra_count: int, interval: float) -> void:
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		return
	var controller := Node2D.new()
	controller.name = "DangzhenSwordFollowController"
	current_scene.add_child(controller)
	var tween := controller.create_tween()
	for _extra_index in range(extra_count):
		tween.tween_interval(interval)
		tween.tween_callback(Callable(self, "_fire_follow_slash").bind(owner, slash_direction, damage_amount, split_level, huichao_level, role_id))
	tween.tween_callback(controller.queue_free)

func _schedule_cross_slashes(owner, base_direction: Vector2, damage_amount: float, split_level: int, huichao_level: int, role_id: String, extra_count: int, interval: float) -> void:
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		return
	var controller := Node2D.new()
	controller.name = "DangzhenSwordCrossController"
	current_scene.add_child(controller)
	var tween := controller.create_tween()
	tween.tween_interval(interval * float(extra_count + 1))
	tween.tween_callback(Callable(self, "_fire_cross_slashes").bind(owner, base_direction, damage_amount, split_level, huichao_level, role_id))
	for _extra_index in range(extra_count):
		tween.tween_interval(interval)
		tween.tween_callback(Callable(self, "_fire_cross_slashes").bind(owner, base_direction, damage_amount, split_level, huichao_level, role_id))
	tween.tween_callback(controller.queue_free)

func _fire_follow_slash(owner, slash_direction: Vector2, damage_amount: float, split_level: int, huichao_level: int, role_id: String) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var hits := execute_slash(owner, owner.global_position, slash_direction, damage_amount, split_level, huichao_level, role_id)
	if hits > 0:
		owner._register_attack_result(role_id, hits, false)

func _fire_cross_slashes(owner, base_direction: Vector2, damage_amount: float, split_level: int, huichao_level: int, role_id: String) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var cross_axis: Vector2 = owner._get_downward_perpendicular(base_direction).normalized()
	if cross_axis.length_squared() <= 0.001:
		cross_axis = Vector2.DOWN
	var cross_directions: Array[Vector2] = [cross_axis, -cross_axis]
	for cross_direction in cross_directions:
		var hits := execute_slash(owner, owner.global_position, cross_direction, damage_amount, split_level, huichao_level, role_id)
		if hits > 0:
			owner._register_attack_result(role_id, hits, false)
