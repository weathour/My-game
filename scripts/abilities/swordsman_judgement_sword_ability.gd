extends RefCounted

const PLAYER_SWORDSMAN_JUDGEMENT_SWORD_FLOW := preload("res://scripts/player/player_swordsman_judgement_sword_flow.gd")

const SKILL_ID := "judgement_sword"
const COOLDOWN := 18.0
const MAX_RANGE := 400.0
const FALL_RADIUS := 100.0
const FALL_DAMAGE_RATIO := 2.00
const SWORD_DURATION := 8.0
const SHOCKWAVE_INTERVAL := 2.0
const SHOCKWAVE_DAMAGE_RATIO := 1.00
const ARMOR_SHRED_PER_SHOCKWAVE := 20.0
const FULL_MAP_RADIUS := 4000.0
# 审判之誓 I/II 天赋加成（均按线性比例相加，不乘算）
const TALENT_JUDGEMENT_SWORD_1 := "swordsman_level_talent_judgement_sword_1"
const TALENT_JUDGEMENT_SWORD_2 := "swordsman_level_talent_judgement_sword_2"
const FALL_DAMAGE_TALENT_BONUS := 1.00
const SHOCKWAVE_INTERVAL_TALENT_REDUCTION := 1.0
const SHOCKWAVE_DAMAGE_TALENT_BONUS := 0.50
const ARMOR_SHRED_TALENT_BONUS := 10.0
const ACTIVE_DAMAGE_REDUCTION_TALENT_BONUS := 80.0
const SHOCKWAVE_HEAL_MISSING_HEALTH_RATIO := 0.015
const SWORD_AREA_TEXTURE_PATH := "res://effects/sword/area/sword area.png"
const SWORD_AREA_TEXTURE_SIZE := Vector2(1254.0, 1254.0)
const SWORD_AREA_VISIBLE_BOUNDS := Rect2(300.0, 50.0, 660.0, 1140.0)
const SWORD_AREA_VISIBLE_SIZE := Vector2(240.0, 240.0)

var cooldown_remaining: float = 0.0
var active_remaining: float = 0.0
var shockwave_timer: float = SHOCKWAVE_INTERVAL
var sword_visual: Node2D = null
var sword_position: Vector2 = Vector2.ZERO


func update(owner, delta: float) -> void:
	cooldown_remaining = max(0.0, cooldown_remaining - delta)
	if active_remaining <= 0.0:
		return
	active_remaining = max(0.0, active_remaining - delta)
	if active_remaining <= 0.0:
		# 巨剑持续时间结束后才开始计算冷却
		cooldown_remaining = COOLDOWN
		_clear_sword_visual()
		return
	shockwave_timer -= delta
	while shockwave_timer <= 0.0:
		shockwave_timer += _get_shockwave_interval(owner)
		_release_shockwave(owner)


func can_trigger(owner, role_id: String) -> bool:
	return owner != null and is_instance_valid(owner) and role_id == "swordsman" and not bool(owner.get("is_dead")) and not bool(owner.get("level_up_active")) and _is_unlocked(owner) and active_remaining <= 0.0 and cooldown_remaining <= 0.0


func try_trigger(owner) -> bool:
	if not can_trigger(owner, "swordsman"):
		return false
	var direction: Vector2 = owner._get_live_mouse_aim_direction(owner.facing_direction)
	if direction.length_squared() <= 0.001:
		direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	direction = direction.normalized()
	owner.facing_direction = direction
	var scene: Node = owner.get_tree().current_scene if owner.get_tree() != null else null
	if scene == null:
		return false
	# 落点 = 鼠标所指位置，鼠标可指定的最远距离为 MAX_RANGE
	var center: Vector2 = PLAYER_SWORDSMAN_JUDGEMENT_SWORD_FLOW.resolve_target_position(owner, direction, MAX_RANGE)
	# 巨剑从天而降命中（审判之誓 I：落地伤害线性增加 100%）
	var fall_ratio: float = FALL_DAMAGE_RATIO + (FALL_DAMAGE_TALENT_BONUS if _has_talent(owner, TALENT_JUDGEMENT_SWORD_1) else 0.0)
	var damage: float = float(owner._get_role_damage("swordsman")) * fall_ratio
	PLAYER_SWORDSMAN_JUDGEMENT_SWORD_FLOW.apply_impact(owner, center, damage, FALL_RADIUS)
	if owner.has_method("_queue_camera_shake"):
		owner._queue_camera_shake(14.0, 0.26)
	# 巨剑插地留场
	sword_position = center
	_spawn_sword_visual(owner, center)
	active_remaining = SWORD_DURATION
	shockwave_timer = _get_shockwave_interval(owner)
	return true


func get_cooldown_slot(owner = null) -> Dictionary:
	var description := "指定地点降下巨剑，对击中的敌人造成 200% 伤害；巨剑留地 8 秒，每 2 秒释放全图冲击波造成 100% 伤害，并使受到冲击的敌人减伤值降低 20 点（可叠加）。"
	if owner != null and _has_talent(owner, TALENT_JUDGEMENT_SWORD_1):
		description += " 审判之誓 I：落地伤害增加 100%，冲击波间隔减少 1 秒，每道冲击波伤害增加 50%，并额外降低 10 点减伤值。"
	if owner != null and _has_talent(owner, TALENT_JUDGEMENT_SWORD_2):
		description += " 审判之誓 II：冲击波间隔减少 1 秒，每道冲击波为当前站场角色回复 1.5% 已损失生命，巨剑存在期间剑士获得 80 点减伤值。"
	return {
		"name": "审判之誓",
		"remaining": clamp(cooldown_remaining, 0.0, COOLDOWN),
		"duration": COOLDOWN,
		"color": Color(1.0, 0.85, 0.4, 1.0),
		"description": description
	}


func get_save_data() -> Dictionary:
	return {
		"cooldown_remaining": cooldown_remaining,
		"active_remaining": active_remaining,
		"shockwave_timer": shockwave_timer,
		"sword_position": [sword_position.x, sword_position.y]
	}


func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)
	active_remaining = clamp(float(data.get("active_remaining", 0.0)), 0.0, SWORD_DURATION)
	shockwave_timer = clamp(float(data.get("shockwave_timer", SHOCKWAVE_INTERVAL)), 0.0, SHOCKWAVE_INTERVAL)
	var position_data: Variant = data.get("sword_position", [0.0, 0.0])
	if position_data is Array and (position_data as Array).size() >= 2:
		sword_position = Vector2(float(position_data[0]), float(position_data[1]))
	_clear_sword_visual()


func restore_effect_if_active(owner) -> void:
	if active_remaining > 0.0:
		_spawn_sword_visual(owner, sword_position)


func _release_shockwave(owner) -> void:
	var has_talent_1 := _has_talent(owner, TALENT_JUDGEMENT_SWORD_1)
	var shockwave_ratio: float = SHOCKWAVE_DAMAGE_RATIO + (SHOCKWAVE_DAMAGE_TALENT_BONUS if has_talent_1 else 0.0)
	var armor_shred: float = ARMOR_SHRED_PER_SHOCKWAVE + (ARMOR_SHRED_TALENT_BONUS if has_talent_1 else 0.0)
	var heal_ratio: float = SHOCKWAVE_HEAL_MISSING_HEALTH_RATIO if _has_talent(owner, TALENT_JUDGEMENT_SWORD_2) else 0.0
	var damage: float = float(owner._get_role_damage("swordsman")) * shockwave_ratio
	PLAYER_SWORDSMAN_JUDGEMENT_SWORD_FLOW.release_shockwave(owner, sword_position, damage, armor_shred, heal_ratio)
	if owner.has_method("_spawn_ring_effect"):
		owner._spawn_ring_effect(sword_position, FULL_MAP_RADIUS, Color(1.0, 0.9, 0.6, 0.55), 4.0, 0.6)
	if owner.has_method("_spawn_burst_effect"):
		owner._spawn_burst_effect(sword_position, 120.0, Color(1.0, 0.88, 0.5, 0.7), 0.3)
	if owner.has_method("_queue_camera_shake"):
		owner._queue_camera_shake(7.0, 0.16)


func get_active_damage_reduction_value(owner) -> float:
	if active_remaining > 0.0 and _has_talent(owner, TALENT_JUDGEMENT_SWORD_2):
		return ACTIVE_DAMAGE_REDUCTION_TALENT_BONUS
	return 0.0


func _get_shockwave_interval(owner) -> float:
	if owner != null and (_has_talent(owner, TALENT_JUDGEMENT_SWORD_1) or _has_talent(owner, TALENT_JUDGEMENT_SWORD_2)):
		return SHOCKWAVE_INTERVAL - SHOCKWAVE_INTERVAL_TALENT_REDUCTION
	return SHOCKWAVE_INTERVAL


func _has_talent(owner, talent_id: String) -> bool:
	return owner != null and owner.has_method("_has_level_talent") and bool(owner._has_level_talent(talent_id))


func _spawn_sword_visual(owner, center: Vector2) -> void:
	if owner == null or not is_instance_valid(owner) or (sword_visual != null and is_instance_valid(sword_visual)):
		return
	var scene: Node = owner.get_tree().current_scene if owner.get_tree() != null else null
	if scene == null:
		return
	if owner.has_method("_spawn_sketch_sprite_effect"):
		sword_visual = owner._spawn_sketch_sprite_effect(
			center,
			0.0,
			SWORD_AREA_TEXTURE_PATH,
			SWORD_AREA_TEXTURE_SIZE,
			SWORD_AREA_VISIBLE_BOUNDS,
			SWORD_AREA_VISIBLE_SIZE,
			SWORD_DURATION,
			Color.WHITE,
			20,
			true,
			true,
			0.94,
			0.08,
			0.03,
			false
		)


func _clear_sword_visual() -> void:
	if sword_visual != null and is_instance_valid(sword_visual):
		sword_visual.queue_free()
	sword_visual = null


func _is_unlocked(owner) -> bool:
	return owner != null and owner.has_method("_is_blessing_skill_unlocked") and bool(owner._is_blessing_skill_unlocked(SKILL_ID))
