extends RefCounted

const FIELD_EFFECT_SCENE := preload("res://effects/wizard/field/field.tscn")

const SKILL_ID := "meta_field"
const COOLDOWN := 24.0
const TIER_ONE_DURATION := 10.0
const TIER_TWO_DURATION := 15.0
const TIER_THREE_DURATION := 17.0
const TIER_ONE_SLOW := 0.55
const TIER_TWO_SLOW := 0.40
const TIER_THREE_SLOW := 0.20
const TIER_ONE_DAMAGE_REDUCTION := 0.12
const TIER_TWO_DAMAGE_REDUCTION := 0.20
const TIER_THREE_DAMAGE_REDUCTION := 0.30
const TIER_ONE_DAMAGE_RATIO := 0.18
const TIER_TWO_DAMAGE_RATIO := 0.28
const TIER_THREE_DAMAGE_RATIO := 0.38
const TIER_ONE_RADIUS := 160.0
const TIER_TWO_RADIUS := 190.0
const TIER_THREE_RADIUS := 218.6
const FIELD_SIZE_MULTIPLIER := 0.70
const TICK_INTERVAL := 1.0
const MAX_CATCH_UP_TICKS := 4

var cooldown_remaining: float = 0.0
var active_remaining: float = 0.0
var tick_remaining: float = 0.0
var effect: Node2D


func update(owner, delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = max(0.0, cooldown_remaining - delta)
	if active_remaining <= 0.0:
		return
	if owner == null or not is_instance_valid(owner):
		stop()
		return
	if str(owner._get_active_role().get("id", "")) != "mage":
		stop()
		return

	active_remaining = max(0.0, active_remaining - delta)
	tick_remaining -= delta
	_update_effect(owner)
	var catch_up_ticks: int = 0
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
	if role_id != "mage":
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
	_ensure_effect(owner)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -70.0), "\u6885\u5854\u9886\u57df", Color(0.58, 0.88, 1.0, 1.0))
	return true


func stop() -> void:
	active_remaining = 0.0
	tick_remaining = 0.0
	if effect != null and is_instance_valid(effect):
		effect.queue_free()
	effect = null


func get_cooldown_slot(owner = null) -> Dictionary:
	var duration: float = _get_cooldown(owner)
	return {
		"name": "\u6885\u5854\u9886\u57df",
		"remaining": clamp(cooldown_remaining, 0.0, duration),
		"duration": duration,
		"color": Color(0.58, 0.86, 1.0, 1.0),
		"description": "\u672f\u5e08\u5468\u56f4\u5c55\u5f00\u51cf\u901f\u548c\u6301\u7eed\u4f24\u5bb3\u9886\u57df\uff0c\u81ea\u8eab\u83b7\u5f97\u51cf\u4f24\u3002"
	}


func get_save_data() -> Dictionary:
	return {
		"cooldown_remaining": cooldown_remaining,
		"active_remaining": active_remaining,
		"tick_remaining": tick_remaining
	}


func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)
	active_remaining = clamp(float(data.get("active_remaining", 0.0)), 0.0, TIER_TWO_DURATION * 2.4)
	tick_remaining = clamp(float(data.get("tick_remaining", 0.0)), 0.0, TICK_INTERVAL)


func restore_effect_if_active(owner) -> void:
	if active_remaining > 0.0:
		_ensure_effect(owner)


func get_damage_taken_multiplier(owner) -> float:
	if active_remaining <= 0.0:
		return 1.0
	return 1.0 - _get_damage_reduction(owner)


func _trigger_tick(owner) -> void:
	var hits: int = 0
	if owner.has_method("_damage_enemies_in_radius_batched"):
		hits = int(owner._damage_enemies_in_radius_batched(owner.global_position, _get_radius(owner), _get_damage(owner), 0.0, _get_slow_multiplier(owner), 1.35, "mage"))
	else:
		hits = int(owner._damage_enemies_in_radius(
			owner.global_position,
			_get_radius(owner),
			_get_damage(owner),
			0.0,
			_get_slow_multiplier(owner),
			1.35,
			"mage"
		))
	if hits > 0:
		owner._register_attack_result("mage", hits, false)


func _ensure_effect(owner) -> void:
	if effect != null and is_instance_valid(effect):
		return
	if owner == null or not is_instance_valid(owner) or FIELD_EFFECT_SCENE == null:
		return
	effect = FIELD_EFFECT_SCENE.instantiate() as Node2D
	if effect == null:
		return
	effect.name = "MageMetaFieldEffect"
	effect.z_index = 9
	owner.add_child(effect)
	var sprite: AnimatedSprite2D = effect.get_node_or_null("field") as AnimatedSprite2D
	if sprite != null:
		sprite.centered = true
		sprite.position = Vector2.ZERO
		sprite.scale = Vector2.ONE * _get_visual_scale(owner)
		sprite.modulate = Color(0.78, 0.94, 1.0, 0.72)
		if sprite.sprite_frames != null:
			sprite.play()
	_update_effect(owner)


func _update_effect(owner) -> void:
	_ensure_effect(owner)
	if effect == null or not is_instance_valid(effect):
		return
	effect.position = Vector2.ZERO
	var ratio: float = clamp(active_remaining / max(_get_duration(owner), 0.001), 0.0, 1.0)
	effect.modulate.a = 0.52 + ratio * 0.32


func _has_required_unlock(owner) -> bool:
	return owner != null and owner.has_method("_is_blessing_skill_unlocked") and bool(owner._is_blessing_skill_unlocked(SKILL_ID))


func _get_tier(owner) -> int:
	if owner != null and owner.has_method("_get_blessing_skill_tier"):
		return int(owner._get_blessing_skill_tier(SKILL_ID))
	return 1


func _get_duration(owner) -> float:
	var tier: int = _get_tier(owner)
	var duration: float = TIER_ONE_DURATION
	if tier >= 3:
		duration = TIER_THREE_DURATION
	elif tier >= 2:
		duration = TIER_TWO_DURATION
	if owner != null and owner.has_method("_get_blessing_skill_duration_multiplier"):
		duration *= float(owner._get_blessing_skill_duration_multiplier(SKILL_ID))
	return duration


func _get_cooldown(owner) -> float:
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_equipment_cooldown_multiplier"):
		return COOLDOWN * owner._get_equipment_cooldown_multiplier()
	return COOLDOWN


func _get_radius(owner) -> float:
	var tier: int = _get_tier(owner)
	var base_radius: float = TIER_ONE_RADIUS
	if tier >= 3:
		base_radius = TIER_THREE_RADIUS
	elif tier >= 2:
		base_radius = TIER_TWO_RADIUS
	var range_multiplier: float = 1.0
	if owner != null and owner.has_method("_get_equipment_skill_range_multiplier"):
		range_multiplier *= float(owner._get_equipment_skill_range_multiplier())
	return base_radius * range_multiplier * FIELD_SIZE_MULTIPLIER


func _get_visual_scale(owner) -> float:
	return max(1.0, _get_radius(owner) / 90.0)


func _get_slow_multiplier(owner) -> float:
	var tier: int = _get_tier(owner)
	if tier >= 3:
		return TIER_THREE_SLOW
	if tier >= 2:
		return TIER_TWO_SLOW
	return TIER_ONE_SLOW


func _get_damage_reduction(owner) -> float:
	var tier: int = _get_tier(owner)
	if tier >= 3:
		return TIER_THREE_DAMAGE_REDUCTION
	if tier >= 2:
		return TIER_TWO_DAMAGE_REDUCTION
	return TIER_ONE_DAMAGE_REDUCTION


func _get_damage(owner) -> float:
	var tier: int = _get_tier(owner)
	var ratio: float = TIER_ONE_DAMAGE_RATIO
	if tier >= 3:
		ratio = TIER_THREE_DAMAGE_RATIO
	elif tier >= 2:
		ratio = TIER_TWO_DAMAGE_RATIO
	return float(owner._get_role_damage("mage")) * ratio
