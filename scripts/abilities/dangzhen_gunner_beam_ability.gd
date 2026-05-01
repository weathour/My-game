extends RefCounted

const COOLDOWN := 2.8
const BEAM_BASE_LENGTH := 168.0
const BEAM_BASE_THICKNESS := 34.0
const VISUAL_SCALE := 1.5
const FOLLOW_INTERVAL_SCALE := 0.8

var cooldown_remaining: float = 0.0

func update(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = max(0.0, cooldown_remaining - delta)

func can_trigger(owner, role_id: String) -> bool:
	if owner == null or not is_instance_valid(owner):
		return false
	if bool(owner.get("is_dead")) or bool(owner.get("level_up_active")):
		return false
	if role_id != "gunner":
		return false
	if owner._has_gunner_infinite_reload_reward():
		return false
	if owner.has_method("is_gunner_infinite_reload_active") and owner.is_gunner_infinite_reload_active():
		return false
	if int(owner._get_card_level("battle_dangzhen_qichao")) <= 0:
		return false
	return cooldown_remaining <= 0.0

func try_trigger(owner, shot_direction: Vector2, role_id: String) -> int:
	if not can_trigger(owner, role_id):
		return 0

	cooldown_remaining = _get_cooldown(owner)
	var qichao_level := int(owner._get_card_level("battle_dangzhen_qichao"))
	var split_level := int(owner._get_card_level("battle_dangzhen_dielang"))
	var qichao_damage := float(owner._get_dangzhen_qichao_damage(role_id, qichao_level))
	var base_direction := shot_direction.normalized()
	if base_direction.length_squared() <= 0.001:
		base_direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT

	var total_hits := 0
	var beam_origin: Vector2 = owner.global_position + base_direction * 20.0
	total_hits += execute_beam(owner, beam_origin, base_direction, qichao_damage, role_id)

	if split_level > 0:
		var current_scene: Node = owner.get_tree().current_scene
		if current_scene != null:
			var controller := Node2D.new()
			controller.name = "DangzhenGunnerFollowController"
			current_scene.add_child(controller)
			var tween := controller.create_tween()
			var interval := float(owner._get_gunner_intersect_combo_duration()) * FOLLOW_INTERVAL_SCALE
			for _extra_index in range(split_level):
				tween.tween_interval(interval)
				tween.tween_callback(Callable(self, "_fire_follow_beam").bind(owner, base_direction, qichao_damage, role_id))
			tween.tween_callback(controller.queue_free)
	return total_hits

func execute_beam(owner, origin: Vector2, fire_direction: Vector2, damage_amount: float, role_id: String) -> int:
	if owner == null or not is_instance_valid(owner):
		return 0
	var direction := fire_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT

	var huichao_level := int(owner._get_card_level("battle_dangzhen_huichao"))
	var range_multiplier: float = float(owner._get_dangzhen_gunner_range_multiplier(huichao_level)) * float(owner._get_role_attribute_range_multiplier("gunner")) * owner._get_equipment_skill_range_multiplier()
	var beam_visual_length: float = BEAM_BASE_LENGTH * range_multiplier
	var beam_visual_thickness: float = BEAM_BASE_THICKNESS
	var line_length: float = beam_visual_length * VISUAL_SCALE
	var line_width: float = float(owner._get_dangzhen_gunner_beam_hit_half_width(beam_visual_thickness))
	var effect: Node2D = owner._spawn_gunner_intersect_scene_effect(origin, direction, beam_visual_length, beam_visual_thickness, BEAM_BASE_LENGTH)
	if owner.has_method("is_gunner_infinite_reload_active") and owner.is_gunner_infinite_reload_active():
		owner._register_gunner_infinite_reload_effect(effect)
	return int(owner._damage_enemies_in_line(
		origin,
		origin + direction * line_length,
		line_width,
		damage_amount,
		0.0,
		1.0,
		0.0,
		role_id
	))

func get_cooldown_slot(owner = null) -> Dictionary:
	var duration := _get_cooldown(owner)
	return {
		"name": "\u8361\u9635",
		"remaining": clamp(cooldown_remaining, 0.0, duration),
		"duration": duration,
		"color": Color(1.0, 0.44, 0.26, 1.0),
		"description": "荡阵·枪手：沿瞄准方向释放贯穿光束；叠浪会延迟追踪补发，回潮提升覆盖宽度/范围。"
	}

func _get_cooldown(owner) -> float:
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_equipment_cooldown_multiplier"):
		return COOLDOWN * owner._get_equipment_cooldown_multiplier()
	return COOLDOWN

func _fire_follow_beam(owner, fallback_direction: Vector2, damage_amount: float, role_id: String) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var live_fire_direction: Vector2 = owner._get_live_mouse_aim_direction(fallback_direction)
	var follow_hits := execute_beam(owner, owner.global_position + live_fire_direction * 20.0, live_fire_direction, damage_amount, role_id)
	if follow_hits > 0:
		owner._register_attack_result(role_id, follow_hits, false)
