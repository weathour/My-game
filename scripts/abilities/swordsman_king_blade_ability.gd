extends RefCounted

const PLAYER_SWORDSMAN_KING_BLADE_FLOW := preload("res://scripts/player/player_swordsman_king_blade_flow.gd")

const SKILL_ID := "king_blade"
const COOLDOWN := 24.0
const SLASH_LENGTH := 350.0
const SLASH_WIDTH := 150.0
const MULTI_SLASH_COUNT := 3
const MULTI_SLASH_INTERVAL := 0.8
const TALENT_KING_BLADE_1 := "swordsman_level_talent_king_blade_1"

var cooldown_remaining: float = 0.0
var pending_slashes: int = 0
var slash_timer: float = 0.0


func update(owner, delta: float) -> void:
	cooldown_remaining = max(0.0, cooldown_remaining - delta)
	if pending_slashes <= 0:
		return
	if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")):
		pending_slashes = 0
		slash_timer = 0.0
		return
	slash_timer = max(0.0, slash_timer - delta)
	if slash_timer > 0.0:
		return
	_perform_slash(owner)
	pending_slashes -= 1
	if pending_slashes > 0:
		slash_timer = MULTI_SLASH_INTERVAL
	else:
		cooldown_remaining = COOLDOWN + 8.0


func can_trigger(owner, role_id: String) -> bool:
	return owner != null and is_instance_valid(owner) and role_id == "swordsman" and not bool(owner.get("is_dead")) and not bool(owner.get("level_up_active")) and pending_slashes <= 0 and _is_unlocked(owner) and cooldown_remaining <= 0.0


func try_trigger(owner) -> bool:
	if not can_trigger(owner, "swordsman"):
		return false
	if _has_talent(owner, TALENT_KING_BLADE_1):
		pending_slashes = MULTI_SLASH_COUNT
		slash_timer = 0.0
		_perform_slash(owner)
		pending_slashes -= 1
		slash_timer = MULTI_SLASH_INTERVAL
	else:
		_perform_slash(owner)
		cooldown_remaining = COOLDOWN
	return true


func _perform_slash(owner) -> void:
	var origin: Vector2 = owner.global_position
	var direction: Vector2 = owner._get_live_mouse_aim_direction(owner.facing_direction)
	if direction.length_squared() <= 0.001:
		direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	direction = direction.normalized()
	var target_position: Vector2 = origin + direction * (SLASH_LENGTH * 0.5)
	var cast_data: Dictionary = PLAYER_SWORDSMAN_KING_BLADE_FLOW.resolve_cast(owner, origin, direction)
	direction = cast_data.get("direction", direction)
	target_position = cast_data.get("target_position", target_position)
	owner.facing_direction = direction
	# 收集 350 半径内的敌人，随机挑一个密集区域作为斩击目标
	owner.facing_direction = direction
	# 直线宽斩：从玩家位置沿方向延伸 SLASH_LENGTH，中心在玩家前方一半处
	var center: Vector2 = origin + direction * (SLASH_LENGTH * 0.5)
	var damage_ratio: float = 4.0 if _has_talent(owner, TALENT_KING_BLADE_1) else 6.0
	var hits: int = PLAYER_SWORDSMAN_KING_BLADE_FLOW.apply_slash(owner, origin, direction, damage_ratio)
	if owner.has_method("_register_attack_result"):
		owner._register_attack_result("swordsman", hits, false)
	if owner.has_method("_spawn_sword_omnislash_scene_effect"):
		owner._spawn_sword_omnislash_scene_effect(center, direction, SLASH_LENGTH, SLASH_WIDTH)
	if owner.has_method("_spawn_ring_effect"):
		owner._spawn_ring_effect(origin + direction * SLASH_LENGTH, 30.0, Color(1.0, 0.88, 0.5, 0.85), 4.0, 0.18)
	if owner.has_method("_spawn_ring_effect"):
		owner._spawn_ring_effect(target_position, 44.0, Color(1.0, 0.95, 0.7, 0.5), 5.0, 0.22)
	if owner.has_method("_queue_camera_shake"):
		owner._queue_camera_shake(11.0, 0.2)


func _has_talent(owner, talent_id: String) -> bool:
	return owner != null and owner.has_method("_has_level_talent") and bool(owner._has_level_talent(talent_id))


func get_cooldown_slot(owner = null) -> Dictionary:
	var cooldown_duration: float = COOLDOWN + 8.0 if _has_talent(owner, TALENT_KING_BLADE_1) else COOLDOWN
	return {
		"name": "王者之剑",
		"remaining": clamp(cooldown_remaining, 0.0, cooldown_duration),
		"duration": cooldown_duration,
		"color": Color(1.0, 0.86, 0.4, 1.0),
		"description": "王者之剑优先锁定 Boss，否则锁定敌人密集区域，造成 600% 伤害；每击杀一个敌人永久增加剑士 0.01 点攻击力。王者之剑 I：变为间隔 0.8 秒的三道斩击，每道造成 400% 伤害，冷却时间增加 8 秒。王者之剑 II：在基础效果上额外使每次击杀永久增加最大生命值 0.05 点。"
	}


func get_save_data() -> Dictionary:
	return {"cooldown_remaining": cooldown_remaining}


func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN + 8.0)


func _is_unlocked(owner) -> bool:
	return owner != null and owner.has_method("_is_blessing_skill_unlocked") and bool(owner._is_blessing_skill_unlocked(SKILL_ID))
