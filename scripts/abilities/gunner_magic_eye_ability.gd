extends RefCounted

const PLAYER_GUNNER_MAGIC_EYE_FLOW := preload("res://scripts/player/player_gunner_magic_eye_flow.gd")
const MAGIC_EYE_VISUAL_SCRIPT := preload("res://scripts/player/gunner_magic_eye_visual.gd")

const SKILL_ID := "magic_eye"
const COOLDOWN := 16.0
const SHOT_COUNT := 5
const SHOT_INTERVAL := 0.4
const SHOT_DAMAGE_RATIO := 0.80
const BEAM_LENGTH := 450.0
const BEAM_WIDTH := 64.0
const ARMOR_SHRED_PER_HIT := 30.0

const TALENT_MAGIC_EYE_1 := "gunner_level_talent_magic_eye_1"
const TALENT_MAGIC_EYE_2 := "gunner_level_talent_magic_eye_2"
# 魔眼聚合 I（绝对加法）：每次伤害 +50%（80%→130%）；持续时间 +1.2s → 总 2.8s，发数按 2.8÷0.4 = 7 发。
const SHOT_DAMAGE_RATIO_BONUS := 0.50
const EXTRA_SHOTS := 2
# 魔眼聚合 II：每次命中减伤值 +30（-30→-60）。
const ARMOR_SHRED_BONUS := 30.0

var cooldown_remaining: float = 0.0
var shots_remaining: int = 0
var shot_timer: float = 0.0
var locked_direction: Vector2 = Vector2.RIGHT
var beam_visual: Node2D = null


func update(owner, delta: float) -> void:
	cooldown_remaining = max(0.0, cooldown_remaining - delta)
	if shots_remaining <= 0:
		return
	shot_timer -= delta
	while shots_remaining > 0 and shot_timer <= 0.0:
		_fire_shot(owner)
		shot_timer += SHOT_INTERVAL
		shots_remaining -= 1
	if shots_remaining <= 0:
		# 5 次伤害全部打完才开始计算冷却
		cooldown_remaining = COOLDOWN
		_clear_beam_visual()


func can_trigger(owner, role_id: String) -> bool:
	return owner != null and is_instance_valid(owner) and role_id == "gunner" and not bool(owner.get("is_dead")) and not bool(owner.get("level_up_active")) and _is_unlocked(owner) and shots_remaining <= 0 and cooldown_remaining <= 0.0


func try_trigger(owner) -> bool:
	if not can_trigger(owner, "gunner"):
		return false
	var direction: Vector2 = owner._get_live_mouse_aim_direction(owner.facing_direction)
	if direction.length_squared() <= 0.001:
		direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	direction = direction.normalized()
	owner.facing_direction = direction
	locked_direction = direction
	var scene: Node = owner.get_tree().current_scene if owner.get_tree() != null else null
	if scene == null:
		return false
	_spawn_beam_visual(owner)
	shots_remaining = get_shot_count(owner)
	# 无天赋：第一发立即出，5 发在 1.6s 内打完；魔眼聚合 I：第一发 0.4s 时打出，7 发正好铺满 2.8s。
	shot_timer = SHOT_INTERVAL if _has_talent(owner, TALENT_MAGIC_EYE_1) else 0.0
	return true


func get_shot_damage_ratio(owner) -> float:
	return SHOT_DAMAGE_RATIO + (SHOT_DAMAGE_RATIO_BONUS if _has_talent(owner, TALENT_MAGIC_EYE_1) else 0.0)


func get_armor_shred(owner) -> float:
	return ARMOR_SHRED_PER_HIT + (ARMOR_SHRED_BONUS if _has_talent(owner, TALENT_MAGIC_EYE_2) else 0.0)


func get_shot_count(owner) -> int:
	return SHOT_COUNT + (EXTRA_SHOTS if _has_talent(owner, TALENT_MAGIC_EYE_1) else 0)


func get_cooldown_slot(owner = null) -> Dictionary:
	return {
		"name": "魔眼聚合",
		"remaining": clamp(cooldown_remaining, 0.0, COOLDOWN),
		"duration": COOLDOWN,
		"color": Color(0.32, 0.66, 1.0, 1.0),
		"description": "向前方释放持续的蓝色加农炮，对前方敌人造成 5 次 80% 伤害，每次命中使敌人减伤值降低 30 点。魔眼聚合 I：每次伤害+50%、持续时间+1.2s。魔眼聚合 II：每次命中减伤值+30。"
	}


func get_save_data() -> Dictionary:
	return {
		"cooldown_remaining": cooldown_remaining,
		"shots_remaining": shots_remaining,
		"shot_timer": shot_timer,
		"locked_direction": [locked_direction.x, locked_direction.y]
	}


func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)
	shots_remaining = max(0, int(data.get("shots_remaining", 0)))
	shot_timer = clamp(float(data.get("shot_timer", 0.0)), -SHOT_INTERVAL, SHOT_INTERVAL)
	var direction_data: Variant = data.get("locked_direction", [1.0, 0.0])
	if direction_data is Array and (direction_data as Array).size() >= 2:
		locked_direction = Vector2(float(direction_data[0]), float(direction_data[1]))
	if locked_direction.length_squared() <= 0.001:
		locked_direction = Vector2.RIGHT
	else:
		locked_direction = locked_direction.normalized()
	_clear_beam_visual()


func restore_effect_if_active(owner) -> void:
	if shots_remaining > 0:
		_spawn_beam_visual(owner)


func _fire_shot(owner) -> void:
	var center: Vector2 = owner.global_position + locked_direction * (BEAM_LENGTH * 0.5)
	var damage: float = float(owner._get_role_damage("gunner")) * get_shot_damage_ratio(owner)
	var damage_taken: int = PLAYER_GUNNER_MAGIC_EYE_FLOW.fire_shot(owner, locked_direction, BEAM_LENGTH, BEAM_WIDTH, damage, get_armor_shred(owner))
	if owner.has_method("_register_attack_result"):
		owner._register_attack_result("gunner", damage_taken, false)
	if beam_visual != null and is_instance_valid(beam_visual) and beam_visual.has_method("fire_pulse"):
		beam_visual.fire_pulse()
	if owner.has_method("_spawn_ring_effect"):
		owner._spawn_ring_effect(center, BEAM_WIDTH * 0.5, Color(0.4, 0.75, 1.0, 0.9), 2.0, 0.14)
	if owner.has_method("_queue_camera_shake"):
		owner._queue_camera_shake(3.2, 0.08)


func _spawn_beam_visual(owner) -> void:
	if owner == null or not is_instance_valid(owner) or (beam_visual != null and is_instance_valid(beam_visual)):
		return
	var scene: Node = owner.get_tree().current_scene if owner.get_tree() != null else null
	if scene == null:
		return
	var visual := Node2D.new()
	visual.name = "GunnerMagicEye"
	visual.set_script(MAGIC_EYE_VISUAL_SCRIPT)
	visual.set("follow_target", owner)
	visual.set("origin_position", owner.global_position + locked_direction * 20.0)
	visual.set("beam_direction", locked_direction)
	visual.set("beam_length", BEAM_LENGTH)
	visual.set("beam_width", BEAM_WIDTH)
	visual.add_to_group("temporary_effects")
	scene.add_child(visual)
	beam_visual = visual


func _clear_beam_visual() -> void:
	if beam_visual != null and is_instance_valid(beam_visual):
		beam_visual.queue_free()
	beam_visual = null


func _is_unlocked(owner) -> bool:
	return owner != null and owner.has_method("_is_blessing_skill_unlocked") and bool(owner._is_blessing_skill_unlocked(SKILL_ID))


func _has_talent(owner, talent_id: String) -> bool:
	return owner != null and owner.has_method("_has_level_talent") and bool(owner._has_level_talent(talent_id))
