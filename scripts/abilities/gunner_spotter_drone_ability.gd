extends RefCounted

const CARD_ID := "gun_spotter_drone"
const ROLE_ID := "gunner"
const COOLDOWN := 10.0
const BASE_DAMAGE_RATIO := 0.46
const DAMAGE_RATIO_PER_LEVEL := 0.11
const BASE_SPLASH_RADIUS := 44.0
const BASE_LOCK_RADIUS := 52.0

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
	var target := _select_target(owner)
	if target == null or not is_instance_valid(target):
		return false
	var level := _get_card_level(owner)
	cooldown_remaining = _get_cooldown(owner)
	var target_position: Vector2 = target.global_position
	var origin: Vector2 = owner.global_position
	owner._spawn_combat_tag(origin + Vector2(0.0, -64.0), "侦察无人机", Color(1.0, 0.66, 0.28, 1.0))
	owner._spawn_target_lock_effect(target_position, _get_lock_radius(owner, level), Color(1.0, 0.7, 0.22, 0.82), 0.36)
	owner._spawn_dash_line_effect(origin, target_position, Color(1.0, 0.58, 0.22, 0.62), 4.0, 0.16)
	var damage_amount := float(owner._get_role_damage(ROLE_ID)) * (BASE_DAMAGE_RATIO + DAMAGE_RATIO_PER_LEVEL * float(level))
	var killed := bool(owner._deal_damage_to_enemy(target, damage_amount, ROLE_ID, 0.08 + 0.025 * float(level), 2.4, 0.92, 1.0, origin))
	if owner.has_method("_apply_gunner_lock"):
		owner._apply_gunner_lock(target, max(1, level))
	var splash_hits := 0
	if level >= 2:
		splash_hits = int(owner._damage_enemies_in_radius(target_position, _get_splash_radius(owner, level), damage_amount * 0.38, 0.04, 0.9, 0.75, ROLE_ID))
	if level >= 3:
		owner._spawn_guard_effect(origin, 56.0 * _get_range_multiplier(owner), Color(1.0, 0.72, 0.3, 0.34), 0.36)
		owner._heal(3.0 + float(max(1, splash_hits)) * 1.5)
	owner._register_attack_result(ROLE_ID, 1 + splash_hits, killed)
	return true

func get_cooldown_slot(owner = null) -> Dictionary:
	var duration := _get_cooldown(owner)
	return {
		"name": "侦察无人机",
		"remaining": clamp(cooldown_remaining, 0.0, duration),
		"duration": duration,
		"color": Color(1.0, 0.62, 0.24, 1.0),
		"description": "枪手专属：独立冷却标记关键目标并补一发无人机火力。Lv.2 溅射压制，Lv.3 命中后给少量治疗/护盾感。"
	}

func get_save_data() -> Dictionary:
	return {"cooldown_remaining": cooldown_remaining}

func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)

func _select_target(owner) -> Node2D:
	var target: Node2D = null
	if owner.has_method("_get_low_health_enemy"):
		target = owner._get_low_health_enemy()
	if target != null and is_instance_valid(target):
		return target
	if owner.has_method("_get_enemy_targets"):
		var targets: Array = owner._get_enemy_targets(1, true)
		if not targets.is_empty() and targets[0] is Node2D:
			return targets[0]
	if owner.has_method("_get_closest_enemy"):
		return owner._get_closest_enemy()
	return null

func _get_card_level(owner) -> int:
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_card_level"):
		return max(0, int(owner._get_card_level(CARD_ID)))
	return 0

func _get_range_multiplier(owner) -> float:
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_equipment_skill_range_multiplier"):
		return float(owner._get_equipment_skill_range_multiplier())
	return 1.0

func _get_lock_radius(owner, level: int) -> float:
	return (BASE_LOCK_RADIUS + 8.0 * float(level)) * _get_range_multiplier(owner)

func _get_splash_radius(owner, level: int) -> float:
	return (BASE_SPLASH_RADIUS + 12.0 * float(level)) * _get_range_multiplier(owner)

func _get_cooldown(owner) -> float:
	var level := _get_card_level(owner)
	var cooldown: float = COOLDOWN * max(0.78, 1.0 - 0.06 * float(max(0, level - 1)))
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_equipment_cooldown_multiplier"):
		cooldown *= float(owner._get_equipment_cooldown_multiplier())
	return cooldown
