extends RefCounted

const PLAYER_MAGE_FIREBALL_FLOW := preload("res://scripts/player/player_mage_fireball_flow.gd")
const PLAYER_SKILL_LEVEL_EFFECT_FLOW := preload("res://scripts/player/player_skill_level_effect_flow.gd")
const FIRE_GROUND_VISUAL_SCRIPT := preload("res://scripts/player/mage_fire_ground_visual.gd")
const FIREBALL_PROJECTILE_SCRIPT := preload("res://scripts/player/mage_fireball_projectile.gd")
const FIRE_BLAST_VISUAL_SCRIPT := preload("res://scripts/player/mage_fire_blast_visual.gd")

const SKILL_ID := "fireball"
const COOLDOWN := 28.0
const MAX_RANGE := 450.0
const BASE_BLAST_RADIUS := 200.0
const BASE_BLAST_DAMAGE_RATIO := 6.00
const TALENT_1_RADIUS_BONUS := 75.0
const TALENT_1_DAMAGE_BONUS := 1.50
const CHARGE_DURATION := 0.5
const GROUND_DURATION := 6.0
const GROUND_TICK_INTERVAL := 1.0
const GROUND_BURN_CURRENT_HEALTH_RATIO := 0.01
const SECONDARY_BLAST_RADIUS := 50.0
const SECONDARY_BLAST_DAMAGE_RATIO := 2.00
const SECONDARY_BLAST_COUNT := 8

var cooldown_remaining: float = 0.0
var active_fire_fields: Array[Dictionary] = []
var pending_saved_fields: Array[Dictionary] = []
var pending_impact_remaining: float = 0.0
var pending_impact_center: Vector2 = Vector2.ZERO
var fireball_projectile: Node2D = null


func _has_talent(owner, talent_id: String) -> bool:
	if owner == null or talent_id == "":
		return false
	if owner.has_method("_has_level_talent"):
		return bool(owner._has_level_talent(talent_id))
	return false


func _get_blast_radius(owner) -> float:
	var r: float = BASE_BLAST_RADIUS
	if _has_talent(owner, "mage_level_talent_fireball_1"):
		r += TALENT_1_RADIUS_BONUS
	return r


func _get_blast_damage_ratio(owner) -> float:
	var r: float = BASE_BLAST_DAMAGE_RATIO
	if _has_talent(owner, "mage_level_talent_fireball_1"):
		r += TALENT_1_DAMAGE_BONUS
	r += PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_fireball_damage_ratio_bonus(owner)
	return r


func _get_ground_burn_ratio(owner) -> float:
	return GROUND_BURN_CURRENT_HEALTH_RATIO + PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_fireball_burn_ratio_bonus(owner)


func _get_ground_duration(owner) -> float:
	return GROUND_DURATION + PLAYER_SKILL_LEVEL_EFFECT_FLOW.get_mage_fireball_ground_duration_bonus(owner)


func update(owner, delta: float) -> void:
	cooldown_remaining = max(0.0, cooldown_remaining - delta)
	if pending_impact_remaining > 0.0:
		pending_impact_remaining = max(0.0, pending_impact_remaining - delta)
		if pending_impact_remaining <= 0.0:
			_resolve_pending_impact(owner)
	for index in range(active_fire_fields.size() - 1, -1, -1):
		var data: Dictionary = active_fire_fields[index]
		var ground: Node2D = data.get("node", null) as Node2D
		var remaining: float = float(data.get("remaining", 0.0)) - delta
		data["remaining"] = remaining
		# 底部燃烧地面按剩余时间做结尾淡出。
		if ground != null and is_instance_valid(ground) and ground.has_method("set_remaining"):
			ground.set_remaining(remaining)
		var tick_elapsed: float = float(data.get("tick_elapsed", 0.0)) + delta
		data["tick_elapsed"] = tick_elapsed
		active_fire_fields[index] = data
		while tick_elapsed >= GROUND_TICK_INTERVAL:
			tick_elapsed -= GROUND_TICK_INTERVAL
			PLAYER_MAGE_FIREBALL_FLOW.apply_burn_tick(owner, data.get("center", Vector2.ZERO), data.get("radius", BASE_BLAST_RADIUS), _get_ground_burn_ratio(owner))
		data["tick_elapsed"] = tick_elapsed
		active_fire_fields[index] = data
		if remaining <= 0.0:
			if ground != null and is_instance_valid(ground):
				ground.queue_free()
			active_fire_fields.remove_at(index)


func can_trigger(owner, role_id: String) -> bool:
	return owner != null and is_instance_valid(owner) and role_id == "mage" and not bool(owner.get("is_dead")) and not bool(owner.get("level_up_active")) and _is_unlocked(owner) and cooldown_remaining <= 0.0


func try_trigger(owner) -> bool:
	if not can_trigger(owner, "mage"):
		return false
	var direction: Vector2 = owner._get_live_mouse_aim_direction(owner.facing_direction)
	if direction.length_squared() <= 0.001:
		direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	direction = direction.normalized()
	owner.facing_direction = direction
	var scene: Node = owner.get_tree().current_scene if owner.get_tree() != null else null
	if scene == null:
		return false
	cooldown_remaining = COOLDOWN
	var blast_radius: float = _get_blast_radius(owner)
	pending_impact_center = PLAYER_MAGE_FIREBALL_FLOW.resolve_target_position(owner, direction, MAX_RANGE)
	pending_impact_remaining = CHARGE_DURATION
	_spawn_projectile(owner, pending_impact_center)
	if owner.has_method("_spawn_ring_effect"):
		owner._spawn_ring_effect(pending_impact_center, blast_radius * 0.55, Color(1.0, 0.34, 0.08, 0.72), 5.0, CHARGE_DURATION)
		owner._spawn_ring_effect(pending_impact_center, blast_radius * 0.30, Color(1.0, 0.86, 0.28, 0.86), 3.0, CHARGE_DURATION)
	if owner.has_method("_spawn_combat_tag"):
		owner._spawn_combat_tag(pending_impact_center + Vector2(0.0, -32.0), "火球聚能", Color(1.0, 0.68, 0.24, 1.0))
	return true


func _resolve_pending_impact(owner) -> void:
	if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")):
		_release_projectile()
		return
	var center := pending_impact_center
	pending_impact_center = Vector2.ZERO
	var blast_radius: float = _get_blast_radius(owner)
	var damage: float = float(owner._get_role_damage("mage")) * _get_blast_damage_ratio(owner)
	# 第一次爆炸
	PLAYER_MAGE_FIREBALL_FLOW.apply_impact(owner, center, blast_radius, damage)
	# 天赋II：8个方向的第二次小爆炸
	if _has_talent(owner, "mage_level_talent_fireball_2"):
		var secondary_damage: float = float(owner._get_role_damage("mage")) * SECONDARY_BLAST_DAMAGE_RATIO
		var ring_distance: float = blast_radius + SECONDARY_BLAST_RADIUS
		for i in range(SECONDARY_BLAST_COUNT):
			var angle: float = TAU * float(i) / float(SECONDARY_BLAST_COUNT)
			var offset: Vector2 = Vector2.RIGHT.rotated(angle) * ring_distance
			var secondary_center: Vector2 = center + offset
			PLAYER_MAGE_FIREBALL_FLOW.apply_impact(owner, secondary_center, SECONDARY_BLAST_RADIUS, secondary_damage)
			if owner.has_method("_spawn_ring_effect"):
				owner._spawn_ring_effect(secondary_center, SECONDARY_BLAST_RADIUS, Color(1.0, 0.5, 0.15, 0.8), 3.0, 0.2)
	_spawn_blast(owner, center, blast_radius)
	if owner.has_method("_spawn_ring_effect"):
		owner._spawn_ring_effect(center, blast_radius, Color(1.0, 0.48, 0.14, 0.95), 6.0, 0.3)
		owner._spawn_ring_effect(center, blast_radius * 0.6, Color(1.0, 0.82, 0.32, 0.85), 3.0, 0.2)
	if owner.has_method("_spawn_burst_effect"):
		owner._spawn_burst_effect(center, blast_radius * 0.5, Color(1.0, 0.62, 0.2, 0.9), 0.26)
	if owner.has_method("_queue_camera_shake"):
		owner._queue_camera_shake(15.0, 0.3)
	# 爆炸后留下按当前生命百分比结算的燃烧地面
	var ground := _create_fire_ground(owner, center, blast_radius)
	active_fire_fields.append({
		"node": ground,
		"center": center,
		"radius": blast_radius,
		"remaining": _get_ground_duration(owner),
		"tick_elapsed": 0.0
	})


func get_cooldown_slot(owner = null) -> Dictionary:
	return {
		"name": "火球术",
		"remaining": clamp(cooldown_remaining, 0.0, COOLDOWN),
		"duration": COOLDOWN,
		"color": Color(1.0, 0.45, 0.16, 1.0),
		"description": "在指定地点聚能后爆炸，留下持续灼烧的火焰区域。",
		"effect_rows": [
			{"label": "聚能时间", "value": "%.1f 秒" % CHARGE_DURATION},
			{"label": "爆炸伤害倍率", "value": "%.0f%%" % (_get_blast_damage_ratio(owner) * 100.0)},
			{"label": "爆炸半径", "value": "%.0f" % _get_blast_radius(owner)},
			{"label": "灼烧持续时间", "value": "%.1f 秒" % _get_ground_duration(owner)},
			{"label": "每秒灼烧", "value": "当前生命 %.1f%%" % (_get_ground_burn_ratio(owner) * 100.0)}
		],
		"effect_note": "第二次爆炸：%d 处、每处 %.0f%% 伤害、半径 %.0f。" % [SECONDARY_BLAST_COUNT, SECONDARY_BLAST_DAMAGE_RATIO * 100.0, SECONDARY_BLAST_RADIUS] if _has_talent(owner, "mage_level_talent_fireball_2") else "伤害还受角色攻击力、暴击和目标防御影响。"
	}


func get_save_data() -> Dictionary:
	var fields: Array[Dictionary] = []
	for data in active_fire_fields:
		var center: Vector2 = data.get("center", Vector2.ZERO)
		fields.append({
			"center": [center.x, center.y],
			"radius": float(data.get("radius", BASE_BLAST_RADIUS)),
			"remaining": max(0.0, float(data.get("remaining", 0.0))),
			"tick_elapsed": max(0.0, float(data.get("tick_elapsed", 0.0)))
		})
	return {"cooldown_remaining": cooldown_remaining, "fields": fields}


func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)
	_clear_fire_fields()
	pending_saved_fields.clear()
	var saved_fields: Variant = data.get("fields", [])
	if saved_fields is Array:
		for saved_data in saved_fields:
			if saved_data is Dictionary:
				pending_saved_fields.append((saved_data as Dictionary).duplicate(true))


func restore_effect_if_active(owner) -> void:
	for saved_data in pending_saved_fields:
		var center_data: Variant = saved_data.get("center", [owner.global_position.x, owner.global_position.y])
		var center: Vector2 = owner.global_position
		if center_data is Array and (center_data as Array).size() >= 2:
			center = Vector2(float(center_data[0]), float(center_data[1]))
		var remaining: float = max(0.0, float(saved_data.get("remaining", 0.0)))
		if remaining <= 0.0:
			continue
		var saved_radius: float = float(saved_data.get("radius", BASE_BLAST_RADIUS))
		var ground := _create_fire_ground(owner, center, saved_radius)
		if ground == null:
			continue
		active_fire_fields.append({
			"node": ground,
			"center": center,
			"radius": saved_radius,
			"remaining": remaining,
			"tick_elapsed": clamp(float(saved_data.get("tick_elapsed", 0.0)), 0.0, GROUND_TICK_INTERVAL)
		})
	pending_saved_fields.clear()


func _spawn_projectile(owner, center: Vector2) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var scene: Node = owner.get_tree().current_scene if owner.get_tree() != null else null
	if scene == null:
		return
	var projectile := Node2D.new()
	projectile.name = "MageFireball"
	projectile.set_script(FIREBALL_PROJECTILE_SCRIPT)
	projectile.set("start_position", owner.global_position)
	projectile.set("target_position", center)
	projectile.set("radius", 26.0)
	projectile.global_position = owner.global_position
	scene.add_child(projectile)
	fireball_projectile = projectile


func _spawn_blast(owner, center: Vector2, radius: float) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var scene: Node = owner.get_tree().current_scene if owner.get_tree() != null else null
	if scene == null:
		return
	var blast := Node2D.new()
	blast.name = "MageFireBlast"
	blast.set_script(FIRE_BLAST_VISUAL_SCRIPT)
	blast.set("radius", radius)
	blast.global_position = center
	scene.add_child(blast)


func _create_fire_ground(owner, center: Vector2, radius: float) -> Node2D:
	if owner == null or not is_instance_valid(owner):
		return null
	var scene: Node = owner.get_tree().current_scene if owner.get_tree() != null else null
	if scene == null:
		return null
	var ground := Node2D.new()
	ground.name = "MageFireGround"
	ground.global_position = center
	ground.z_index = 15
	ground.set_script(FIRE_GROUND_VISUAL_SCRIPT)
	ground.set("radius", radius)
	ground.add_to_group("temporary_effects")
	scene.add_child(ground)
	return ground


func _release_projectile() -> void:
	if fireball_projectile != null and is_instance_valid(fireball_projectile):
		fireball_projectile.queue_free()
	fireball_projectile = null


func _clear_fire_fields() -> void:
	for data in active_fire_fields:
		var ground: Node2D = data.get("node", null) as Node2D
		if ground != null and is_instance_valid(ground):
			ground.queue_free()
	active_fire_fields.clear()


func _is_unlocked(owner) -> bool:
	return owner != null and owner.has_method("_is_blessing_skill_unlocked") and bool(owner._is_blessing_skill_unlocked(SKILL_ID))
