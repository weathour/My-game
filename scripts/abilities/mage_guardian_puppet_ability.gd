extends RefCounted

const CARD_ID := "mag_guardian_puppet"
const ROLE_ID := "mage"
const COOLDOWN := 12.0
const BASE_RADIUS := 72.0
const BASE_DAMAGE_RATIO := 0.34
const DAMAGE_RATIO_PER_LEVEL := 0.09
const PULSE_INTERVAL := 0.42

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
	var center := _select_center(owner)
	var radius := _get_radius(owner, level)
	var damage_amount := float(owner._get_role_damage(ROLE_ID)) * (BASE_DAMAGE_RATIO + DAMAGE_RATIO_PER_LEVEL * float(level))
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -64.0), "守护傀儡", Color(0.7, 0.92, 1.0, 1.0))
	owner._spawn_guard_effect(center, radius, Color(0.62, 0.9, 1.0, 0.38), 0.62 + 0.12 * float(level))
	owner._spawn_vortex_effect(center, radius * 0.86, Color(0.5, 0.82, 1.0, 0.3), 0.45)
	owner._pull_enemies_toward(center, radius * 1.12, 10.0 + 4.0 * float(level))
	var hits := _pulse(owner, center, radius, damage_amount, level)
	_schedule_follow_pulses(owner, center, radius, damage_amount, level)
	if level >= 2:
		owner.guard_cover_remaining = max(float(owner.guard_cover_remaining), 1.4 + 0.45 * float(level))
		owner.guard_cover_damage_multiplier = min(float(owner.guard_cover_damage_multiplier), 0.93 - 0.03 * float(level - 1))
		owner._spawn_guard_effect(owner.global_position, 64.0 * _get_range_multiplier(owner), Color(0.78, 0.94, 1.0, 0.28), 0.36)
	if level >= 3:
		owner._heal(4.0 + float(max(1, hits)) * 1.2)
	return true

func get_cooldown_slot(owner = null) -> Dictionary:
	var duration := _get_cooldown(owner)
	return {
		"name": "守护傀儡",
		"remaining": clamp(cooldown_remaining, 0.0, duration),
		"duration": duration,
		"color": Color(0.68, 0.88, 1.0, 1.0),
		"description": "术师专属：独立冷却召出守护傀儡领域，牵引/嘲讽感并造成脉冲伤害。Lv.2 给减伤护卫，Lv.3 脉冲后回复。"
	}

func get_save_data() -> Dictionary:
	return {"cooldown_remaining": cooldown_remaining}

func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)

func _schedule_follow_pulses(owner, center: Vector2, radius: float, damage_amount: float, level: int) -> void:
	var follow_count: int = 1 + max(0, level - 1)
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		return
	var controller := Node2D.new()
	controller.name = "MageGuardianPuppetController"
	current_scene.add_child(controller)
	var tween := controller.create_tween()
	for _index in range(follow_count):
		tween.tween_interval(PULSE_INTERVAL)
		tween.tween_callback(Callable(self, "_pulse").bind(owner, center, radius, damage_amount, level))
	tween.tween_callback(controller.queue_free)

func _pulse(owner, center: Vector2, radius: float, damage_amount: float, level: int) -> int:
	if owner == null or not is_instance_valid(owner):
		return 0
	owner._spawn_ring_effect(center, radius, Color(0.66, 0.9, 1.0, 0.4), 6.0, 0.16)
	if level >= 2:
		owner._spawn_frost_sigils_effect(center, radius * 0.52, Color(0.84, 0.98, 1.0, 0.7), 0.18)
	var slow_multiplier := 0.88 - 0.04 * float(max(0, level - 1))
	var hits := int(owner._damage_enemies_in_radius(center, radius, damage_amount, 0.04 + 0.02 * float(level), slow_multiplier, 1.1 + 0.18 * float(level), ROLE_ID))
	if hits > 0:
		owner._register_attack_result(ROLE_ID, hits, false)
	return hits

func _select_center(owner) -> Vector2:
	if owner.has_method("_get_enemy_cluster_center"):
		var center: Vector2 = owner._get_enemy_cluster_center()
		if center != Vector2.ZERO:
			return center
	if owner.has_method("_get_closest_enemy"):
		var enemy: Node2D = owner._get_closest_enemy()
		if enemy != null and is_instance_valid(enemy):
			return enemy.global_position
	return owner.global_position

func _get_card_level(owner) -> int:
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_card_level"):
		return max(0, int(owner._get_card_level(CARD_ID)))
	return 0

func _get_range_multiplier(owner) -> float:
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_equipment_skill_range_multiplier"):
		return float(owner._get_equipment_skill_range_multiplier())
	return 1.0

func _get_radius(owner, level: int) -> float:
	return (BASE_RADIUS + 14.0 * float(level)) * _get_range_multiplier(owner)

func _get_cooldown(owner) -> float:
	var level := _get_card_level(owner)
	var cooldown: float = COOLDOWN * max(0.78, 1.0 - 0.06 * float(max(0, level - 1)))
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_equipment_cooldown_multiplier"):
		cooldown *= float(owner._get_equipment_cooldown_multiplier())
	return cooldown
