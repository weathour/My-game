extends RefCounted

const PLAYER_SWORDSMAN_KNIGHT_THRUST_FLOW := preload("res://scripts/player/player_swordsman_knight_thrust_flow.gd")

const SKILL_ID := "knight_thrust"
const COOLDOWN := 7.0
const THRUST_LENGTH := 250.0
const THRUST_WIDTH := 58.0
const THRUST_LENGTH_BONUS := 50.0
const COMBO_INTERVAL := 0.3
const SIDE_ANGLE := deg_to_rad(15.0)
const SIDE_SCALE := 0.8

const TALENT_KNIGHT_THRUST_1 := "swordsman_level_talent_knight_thrust_1"
const TALENT_KNIGHT_THRUST_2 := "swordsman_level_talent_knight_thrust_2"

var cooldown_remaining: float = 0.0
var combo_remaining: float = 0.0
var combo_direction: Vector2 = Vector2.RIGHT

func update(owner, delta: float) -> void:
	cooldown_remaining = max(0.0, cooldown_remaining - delta)
	if combo_remaining <= 0.0:
		return
	if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")):
		combo_remaining = 0.0
		return
	combo_remaining = max(0.0, combo_remaining - delta)
	if combo_remaining <= 0.0:
		_perform_strike(owner, combo_direction)

func can_trigger(owner, role_id: String) -> bool:
	return owner != null and is_instance_valid(owner) and role_id == "swordsman" and not bool(owner.get("is_dead")) and not bool(owner.get("level_up_active")) and _is_unlocked(owner) and cooldown_remaining <= 0.0

func try_trigger(owner) -> bool:
	if not can_trigger(owner, "swordsman"):
		return false
	cooldown_remaining = COOLDOWN
	var direction: Vector2 = owner._get_live_mouse_aim_direction(owner.facing_direction)
	if direction.length_squared() <= 0.001:
		direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	direction = direction.normalized()
	owner.facing_direction = direction
	combo_direction = direction
	_perform_strike(owner, direction)
	if _has_talent(owner, TALENT_KNIGHT_THRUST_1):
		combo_remaining = COMBO_INTERVAL
	return true

func _perform_strike(owner, direction: Vector2) -> void:
	var has_talent_1 := _has_talent(owner, TALENT_KNIGHT_THRUST_1)
	var has_talent_2 := _has_talent(owner, TALENT_KNIGHT_THRUST_2)
	PLAYER_SWORDSMAN_KNIGHT_THRUST_FLOW.apply(
		owner,
		direction,
		THRUST_LENGTH_BONUS if has_talent_1 else 0.0,
		0.5 if has_talent_2 else 0.0,
		1,
		has_talent_2,
		5.0 if has_talent_1 else 0.0
	)
	var base_length: float = THRUST_LENGTH + (THRUST_LENGTH_BONUS if has_talent_1 else 0.0)
	var angles: Array[float] = [0.0]
	if has_talent_2:
		angles = [-SIDE_ANGLE, 0.0, SIDE_ANGLE]
	for angle in angles:
		var scale: float = SIDE_SCALE if not is_zero_approx(angle) else 1.0
		var thrust_direction: Vector2 = direction.rotated(angle)
		var length: float = base_length * scale
		var width: float = THRUST_WIDTH * scale
		if owner.has_method("_spawn_thrust_effect"):
			owner._spawn_thrust_effect(owner.global_position, owner.global_position + thrust_direction * length, Color(1.0, 0.84, 0.42, 0.92), width, 0.2, true)
		if owner.has_method("_spawn_ring_effect"):
			owner._spawn_ring_effect(owner.global_position + thrust_direction * length, 24.0 * scale, Color(1.0, 0.9, 0.6, 0.6), 4.0, 0.14)
	if owner.has_method("_queue_camera_shake"):
		owner._queue_camera_shake(9.5, 0.16)

func _has_talent(owner, talent_id: String) -> bool:
	return owner != null and owner.has_method("_has_level_talent") and bool(owner._has_level_talent(talent_id))

func get_cooldown_slot(owner = null) -> Dictionary:
	return {
		"name": "骑士突",
		"remaining": clamp(cooldown_remaining, 0.0, COOLDOWN),
		"duration": COOLDOWN,
		"color": Color(1.0, 0.72, 0.24, 1.0),
		"description": "剑士向前刺击，不发生位移；造成 160% 伤害，每命中一名敌人获得 5 点临时血量，持续 5 秒。骑士突 I：变为两次连击，间隔 0.3 秒，距离与特效长度增加 50，每名敌人临时血量额外增加 5 点。骑士突 II：每次生成主刺及左右各 15° 的副刺，副刺范围与特效为 80%，每道突刺伤害增加 50%。"
	}
func get_save_data() -> Dictionary:
	return {"cooldown_remaining": cooldown_remaining}

func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)

func _is_unlocked(owner) -> bool:
	return owner != null and owner.has_method("_is_blessing_skill_unlocked") and bool(owner._is_blessing_skill_unlocked(SKILL_ID))
