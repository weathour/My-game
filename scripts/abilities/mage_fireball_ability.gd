extends RefCounted

const PLAYER_MAGE_FIREBALL_FLOW := preload("res://scripts/player/player_mage_fireball_flow.gd")
const FIRE_GROUND_VISUAL_SCRIPT := preload("res://scripts/player/mage_fire_ground_visual.gd")

const SKILL_ID := "fireball"
const COOLDOWN := 28.0
const MAX_RANGE := 450.0
const BLAST_RADIUS := 200.0
const BLAST_DAMAGE_RATIO := 6.00
const CHARGE_DURATION := 0.5
const GROUND_DURATION := 6.0
const GROUND_TICK_INTERVAL := 1.0
const GROUND_BURN_CURRENT_HEALTH_RATIO := 0.01

var cooldown_remaining: float = 0.0
var active_fire_fields: Array[Dictionary] = []
var pending_saved_fields: Array[Dictionary] = []
var pending_impact_remaining: float = 0.0
var pending_impact_center: Vector2 = Vector2.ZERO


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
		var tick_elapsed: float = float(data.get("tick_elapsed", 0.0)) + delta
		data["tick_elapsed"] = tick_elapsed
		active_fire_fields[index] = data
		while tick_elapsed >= GROUND_TICK_INTERVAL:
			tick_elapsed -= GROUND_TICK_INTERVAL
			PLAYER_MAGE_FIREBALL_FLOW.apply_burn_tick(owner, data.get("center", Vector2.ZERO), BLAST_RADIUS, GROUND_BURN_CURRENT_HEALTH_RATIO)
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
	pending_impact_center = PLAYER_MAGE_FIREBALL_FLOW.resolve_target_position(owner, direction, MAX_RANGE)
	pending_impact_remaining = CHARGE_DURATION
	if owner.has_method("_spawn_ring_effect"):
		owner._spawn_ring_effect(pending_impact_center, BLAST_RADIUS * 0.55, Color(1.0, 0.34, 0.08, 0.72), 5.0, CHARGE_DURATION)
		owner._spawn_ring_effect(pending_impact_center, BLAST_RADIUS * 0.30, Color(1.0, 0.86, 0.28, 0.86), 3.0, CHARGE_DURATION)
	if owner.has_method("_spawn_combat_tag"):
		owner._spawn_combat_tag(pending_impact_center + Vector2(0.0, -32.0), "火球聚能", Color(1.0, 0.68, 0.24, 1.0))
	return true


func _resolve_pending_impact(owner) -> void:
	if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")):
		return
	var center := pending_impact_center
	pending_impact_center = Vector2.ZERO
	var damage: float = float(owner._get_role_damage("mage")) * BLAST_DAMAGE_RATIO
	PLAYER_MAGE_FIREBALL_FLOW.apply_impact(owner, center, BLAST_RADIUS, damage)
	if owner.has_method("_spawn_ring_effect"):
		owner._spawn_ring_effect(center, BLAST_RADIUS, Color(1.0, 0.48, 0.14, 0.95), 6.0, 0.3)
		owner._spawn_ring_effect(center, BLAST_RADIUS * 0.6, Color(1.0, 0.82, 0.32, 0.85), 3.0, 0.2)
	if owner.has_method("_spawn_burst_effect"):
		owner._spawn_burst_effect(center, BLAST_RADIUS * 0.5, Color(1.0, 0.62, 0.2, 0.9), 0.26)
	if owner.has_method("_queue_camera_shake"):
		owner._queue_camera_shake(15.0, 0.3)
	# 爆炸后留下按当前生命百分比结算的燃烧地面。
	var ground := _create_fire_ground(owner, center)
	active_fire_fields.append({
		"node": ground,
		"center": center,
		"remaining": GROUND_DURATION,
		"tick_elapsed": 0.0
	})


func get_cooldown_slot(owner = null) -> Dictionary:
	return {
		"name": "火球术",
		"remaining": clamp(cooldown_remaining, 0.0, COOLDOWN),
		"duration": COOLDOWN,
		"color": Color(1.0, 0.45, 0.16, 1.0),
		"description": "在指定地点聚能 0.5 秒后爆炸，造成 600% 范围伤害；留下持续 6 秒的火焰区域，区域内敌人每秒损失当前生命的 1%。"
	}


func get_save_data() -> Dictionary:
	var fields: Array[Dictionary] = []
	for data in active_fire_fields:
		var center: Vector2 = data.get("center", Vector2.ZERO)
		fields.append({
			"center": [center.x, center.y],
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
		var ground := _create_fire_ground(owner, center)
		if ground == null:
			continue
		active_fire_fields.append({
			"node": ground,
			"center": center,
			"remaining": remaining,
			"tick_elapsed": clamp(float(saved_data.get("tick_elapsed", 0.0)), 0.0, GROUND_TICK_INTERVAL)
		})
	pending_saved_fields.clear()


func _create_fire_ground(owner, center: Vector2) -> Node2D:
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
	ground.set("radius", BLAST_RADIUS)
	ground.add_to_group("temporary_effects")
	scene.add_child(ground)
	return ground


func _clear_fire_fields() -> void:
	for data in active_fire_fields:
		var ground: Node2D = data.get("node", null) as Node2D
		if ground != null and is_instance_valid(ground):
			ground.queue_free()
	active_fire_fields.clear()


func _is_unlocked(owner) -> bool:
	return owner != null and owner.has_method("_is_blessing_skill_unlocked") and bool(owner._is_blessing_skill_unlocked(SKILL_ID))
