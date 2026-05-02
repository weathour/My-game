extends RefCounted

const CARD_ID := "swd_blade_shadow"
const ROLE_ID := "swordsman"
const COOLDOWN := 9.0
const BASE_DAMAGE_RATIO := 0.44
const DAMAGE_RATIO_PER_LEVEL := 0.13
const BASE_LENGTH := 118.0
const BASE_WIDTH := 66.0
const BASE_DELAY := 0.12

var cooldown_remaining: float = 0.0

func update(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = max(0.0, cooldown_remaining - delta)

func can_trigger(owner, role_id: String) -> bool:
	if owner == null or not is_instance_valid(owner):
		return false
	if bool(owner.get("is_dead")) or bool(owner.get("level_up_active")):
		return false
	if role_id != ROLE_ID:
		return false
	if _get_card_level(owner) <= 0:
		return false
	return cooldown_remaining <= 0.0

func try_trigger(owner) -> bool:
	if not can_trigger(owner, str(owner._get_active_role().get("id", ""))):
		return false
	var level := _get_card_level(owner)
	cooldown_remaining = _get_cooldown(owner)
	var direction := _get_aim_direction(owner)
	var origin: Vector2 = owner.global_position
	owner._spawn_combat_tag(origin + Vector2(0.0, -64.0), "剑影留形", Color(0.44, 0.92, 1.0, 1.0))
	owner._spawn_ring_effect(origin, _get_guard_radius(owner, level), Color(0.32, 0.82, 1.0, 0.24), 7.0, 0.18)
	_fire_shadow_slash(owner, origin, direction, level, 0)
	_schedule_follow_slashes(owner, direction, level)
	return true

func get_cooldown_slot(owner = null) -> Dictionary:
	var duration := _get_cooldown(owner)
	return {
		"name": "剑影留形",
		"remaining": clamp(cooldown_remaining, 0.0, duration),
		"duration": duration,
		"color": Color(0.42, 0.92, 1.0, 1.0),
		"description": "剑士专属：独立冷却留下剑影重复斩击。Lv.2 追加牵引/嘲讽感，Lv.3 追加交叉剑影并扩大守护范围。"
	}

func get_save_data() -> Dictionary:
	return {"cooldown_remaining": cooldown_remaining}

func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)

func _schedule_follow_slashes(owner, direction: Vector2, level: int) -> void:
	var follow_count: int = 1 + max(0, level - 1)
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		return
	var controller := Node2D.new()
	controller.name = "SwordsmanBladeShadowController"
	current_scene.add_child(controller)
	var tween := controller.create_tween()
	for index in range(follow_count):
		tween.tween_interval(BASE_DELAY + 0.08 * float(index))
		var slash_direction := direction
		if level >= 3 and index % 2 == 1:
			slash_direction = direction.rotated(PI * 0.5)
		tween.tween_callback(Callable(self, "_fire_shadow_slash").bind(owner, owner.global_position, slash_direction, level, index + 1))
	tween.tween_callback(controller.queue_free)

func _fire_shadow_slash(owner, origin: Vector2, slash_direction: Vector2, level: int, slash_index: int) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var direction := slash_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	var range_multiplier := _get_range_multiplier(owner)
	var length := (BASE_LENGTH + 18.0 * float(level)) * range_multiplier
	var width := (BASE_WIDTH + 10.0 * float(level)) * range_multiplier
	var center := origin + direction * (42.0 + length * 0.22)
	var color := Color(0.36, 0.92, 1.0, 0.72 - min(0.28, float(slash_index) * 0.08))
	owner._spawn_crescent_wave_effect(center, direction, max(length, width) * 0.58, color, 0.18, 210.0, max(18.0, width * 0.3))
	owner._spawn_slash_effect(center, direction, length, max(7.0, width * 0.12), Color(0.68, 0.96, 1.0, 0.84), 0.13)
	var damage_amount := float(owner._get_role_damage(ROLE_ID)) * (BASE_DAMAGE_RATIO + DAMAGE_RATIO_PER_LEVEL * float(level))
	var hits := int(owner._damage_enemies_in_oriented_rect(center, direction, length, width, damage_amount, 0.04 + 0.02 * float(level), 0.86, 0.7 + 0.15 * float(level), ROLE_ID))
	if level >= 2:
		owner._pull_enemies_toward(center, _get_guard_radius(owner, level), 8.0 + 3.0 * float(level))
	if hits > 0:
		owner._register_attack_result(ROLE_ID, hits, false)

func _get_card_level(owner) -> int:
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_card_level"):
		return max(0, int(owner._get_card_level(CARD_ID)))
	return 0

func _get_aim_direction(owner) -> Vector2:
	var fallback: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	if owner.has_method("_get_live_mouse_aim_direction"):
		return owner._get_live_mouse_aim_direction(fallback).normalized()
	return fallback.normalized()

func _get_range_multiplier(owner) -> float:
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_equipment_skill_range_multiplier"):
		return float(owner._get_equipment_skill_range_multiplier())
	return 1.0

func _get_guard_radius(owner, level: int) -> float:
	return (72.0 + 12.0 * float(level)) * _get_range_multiplier(owner)

func _get_cooldown(owner) -> float:
	var level := _get_card_level(owner)
	var cooldown: float = COOLDOWN * max(0.78, 1.0 - 0.06 * float(max(0, level - 1)))
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_equipment_cooldown_multiplier"):
		cooldown *= float(owner._get_equipment_cooldown_multiplier())
	return cooldown
