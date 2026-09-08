extends RefCounted

const PLAYER_GUNNER_MAGIC_GRENADE_FLOW := preload("res://scripts/player/player_gunner_magic_grenade_flow.gd")
const MAGIC_GRENADE_VISUAL_SCRIPT := preload("res://scripts/player/gunner_magic_grenade_visual.gd")

const SKILL_ID := "magic_grenade"
const COOLDOWN := 16.0
const COOLDOWN_REDUCTION := 2.0
const TALENT_MAGIC_GRENADE_2 := "gunner_level_talent_magic_grenade_2"
const PROJECTILE_SPEED := 620.0
const MAX_FLIGHT_TIME := 0.6
const MIN_FLIGHT_TIME := 0.18
const ARC_HEIGHT_FACTOR := 0.18
const ARC_HEIGHT_MIN := 40.0
const ARC_HEIGHT_MAX := 110.0

var cooldown_remaining: float = 0.0
var active_grenades: Array[Dictionary] = []
var pending_saved_grenades: Array[Dictionary] = []


func update(owner, delta: float) -> void:
	cooldown_remaining = max(0.0, cooldown_remaining - delta)
	for index in range(active_grenades.size() - 1, -1, -1):
		var data: Dictionary = active_grenades[index]
		var grenade: Node2D = data.get("node", null) as Node2D
		if owner == null or not is_instance_valid(owner) or grenade == null or not is_instance_valid(grenade):
			if grenade != null and is_instance_valid(grenade):
				grenade.queue_free()
			active_grenades.remove_at(index)
			continue
		var elapsed: float = float(data.get("elapsed", 0.0)) + delta
		var duration: float = float(data.get("duration", 0.4))
		var from_position: Vector2 = data.get("from", Vector2.ZERO)
		var target_position: Vector2 = data.get("target", Vector2.ZERO)
		data["elapsed"] = elapsed
		active_grenades[index] = data
		if elapsed >= duration:
			grenade.global_position = target_position
			_explode(owner, grenade.global_position)
			grenade.queue_free()
			active_grenades.remove_at(index)
			continue
		# 沿抛物线弧飞向落点：榴弹只对落点区域结算伤害，飞行途中不碰撞爆炸
		var travel: float = clampf(elapsed / duration, 0.0, 1.0)
		var arc_normal: Vector2 = data.get("arc_normal", Vector2.ZERO)
		var arc_height: float = float(data.get("arc_height", 0.0))
		var previous_position: Vector2 = data.get("previous_position", from_position)
		var arc_offset: Vector2 = arc_normal * (arc_height * sin(PI * travel))
		var new_position: Vector2 = from_position.lerp(target_position, travel) + arc_offset
		data["previous_position"] = new_position
		active_grenades[index] = data
		grenade.global_position = new_position
		var tail: Vector2 = new_position - previous_position
		if tail.length_squared() > 0.001:
			grenade.set("tail_direction", tail)


func can_trigger(owner, role_id: String) -> bool:
	return owner != null and is_instance_valid(owner) and role_id == "gunner" and not bool(owner.get("is_dead")) and not bool(owner.get("level_up_active")) and _is_unlocked(owner) and cooldown_remaining <= 0.0


func try_trigger(owner) -> bool:
	if not can_trigger(owner, "gunner"):
		return false
	var direction: Vector2 = owner._get_live_mouse_aim_direction(owner.facing_direction)
	if direction.length_squared() <= 0.001:
		direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	direction = direction.normalized()
	owner.facing_direction = direction
	var scene: Node = owner.get_tree().current_scene if owner.get_tree() != null else null
	if scene == null:
		return false
	cooldown_remaining = get_cooldown(owner)
	var origin: Vector2 = owner.global_position
	var targets := PLAYER_GUNNER_MAGIC_GRENADE_FLOW.collect_targets(owner, origin, direction)
	var spawn_origin: Vector2 = origin + direction * 26.0
	for target in targets:
		var grenade := _create_grenade(scene, spawn_origin, (target - spawn_origin).normalized())
		var distance: float = spawn_origin.distance_to(target)
		var flight_time: float = clampf(distance / PROJECTILE_SPEED, MIN_FLIGHT_TIME, MAX_FLIGHT_TIME)
		var arc_normal := Vector2.ZERO
		if distance > 1.0:
			var flight_direction: Vector2 = (target - spawn_origin) / distance
			arc_normal = Vector2(-flight_direction.y, flight_direction.x)
		else:
			arc_normal = Vector2.UP
		active_grenades.append({
			"node": grenade,
			"from": spawn_origin,
			"target": target,
			"elapsed": 0.0,
			"duration": flight_time,
			"arc_normal": arc_normal,
			"arc_height": clampf(distance * ARC_HEIGHT_FACTOR, ARC_HEIGHT_MIN, ARC_HEIGHT_MAX),
			"previous_position": spawn_origin
		})
	return true


func get_cooldown(owner) -> float:
	return COOLDOWN - (COOLDOWN_REDUCTION if _has_talent(owner, TALENT_MAGIC_GRENADE_2) else 0.0)


func get_cooldown_slot(owner = null) -> Dictionary:
	return {
		"name": "魔法榴弹",
		"remaining": clamp(cooldown_remaining, 0.0, COOLDOWN),
		"duration": get_cooldown(owner),
		"color": Color(0.78, 0.45, 1.0, 1.0),
		"description": "发射 3 枚魔法榴弹飞向前方敌人密集区域，每枚爆炸造成 300% 范围伤害；魔法榴弹更容易暴击，额外获得 20% 暴击率。魔法榴弹 I：爆炸范围+75、每枚伤害+100%、暴击率额外+20%。魔法榴弹 II：数量+1、冷却-2秒。"
	}


func get_save_data() -> Dictionary:
	var grenades: Array[Dictionary] = []
	for data in active_grenades:
		var grenade: Node2D = data.get("node", null) as Node2D
		if grenade == null or not is_instance_valid(grenade):
			continue
		grenades.append({
			"position": _encode_vector2(grenade.global_position),
			"from": _encode_vector2(data.get("from", grenade.global_position)),
			"target": _encode_vector2(data.get("target", grenade.global_position)),
			"elapsed": max(0.0, float(data.get("elapsed", 0.0))),
			"duration": max(0.01, float(data.get("duration", 0.4))),
			"arc_normal": _encode_vector2(data.get("arc_normal", Vector2.UP)),
			"arc_height": max(0.0, float(data.get("arc_height", 0.0)))
		})
	return {"cooldown_remaining": cooldown_remaining, "grenades": grenades}


func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)
	_clear_grenades()
	pending_saved_grenades.clear()
	var saved_grenades: Variant = data.get("grenades", [])
	if saved_grenades is Array:
		for saved_data in saved_grenades:
			if saved_data is Dictionary:
				pending_saved_grenades.append((saved_data as Dictionary).duplicate(true))


func restore_effect_if_active(owner) -> void:
	var tree: SceneTree = owner.get_tree() if owner != null and is_instance_valid(owner) and owner.has_method("get_tree") else null
	var scene: Node = tree.current_scene if tree != null else null
	if scene == null:
		return
	for saved_data in pending_saved_grenades:
		var position := _decode_vector2(saved_data.get("position", []), owner.global_position)
		var target := _decode_vector2(saved_data.get("target", []), position)
		var direction := (target - position).normalized()
		if direction.length_squared() <= 0.001:
			direction = Vector2.RIGHT
		var grenade := _create_grenade(scene, position, direction)
		var from_position := _decode_vector2(saved_data.get("from", []), position)
		var duration: float = max(0.01, float(saved_data.get("duration", 0.4)))
		active_grenades.append({
			"node": grenade,
			"from": from_position,
			"target": target,
			"elapsed": clamp(float(saved_data.get("elapsed", 0.0)), 0.0, duration),
			"duration": duration,
			"arc_normal": _decode_vector2(saved_data.get("arc_normal", []), Vector2.UP),
			"arc_height": max(0.0, float(saved_data.get("arc_height", 0.0))),
			"previous_position": position
		})
	pending_saved_grenades.clear()


func _explode(owner, center: Vector2) -> void:
	PLAYER_GUNNER_MAGIC_GRENADE_FLOW.apply_explosion(owner, center)
	var blast_radius: float = PLAYER_GUNNER_MAGIC_GRENADE_FLOW.get_blast_radius(owner)
	if owner.has_method("_spawn_burst_effect"):
		owner._spawn_burst_effect(center, blast_radius * 0.6, Color(0.85, 0.55, 1.0, 0.85), 0.2)
	if owner.has_method("_spawn_ring_effect"):
		owner._spawn_ring_effect(center, blast_radius, Color(0.8, 0.5, 1.0, 0.9), 3.0, 0.24)
		owner._spawn_ring_effect(center, blast_radius * 0.55, Color(1.0, 0.9, 1.0, 0.8), 2.0, 0.16)
	if owner.has_method("_queue_camera_shake"):
		owner._queue_camera_shake(11.0, 0.2)


func _create_grenade(scene: Node, position: Vector2, direction: Vector2) -> Node2D:
	var grenade := Node2D.new()
	grenade.name = "GunnerMagicGrenade"
	grenade.global_position = position
	grenade.z_index = 26
	grenade.set_script(MAGIC_GRENADE_VISUAL_SCRIPT)
	grenade.set("tail_direction", direction)
	scene.add_child(grenade)
	return grenade


func _clear_grenades() -> void:
	for data in active_grenades:
		var grenade: Node2D = data.get("node", null) as Node2D
		if grenade != null and is_instance_valid(grenade):
			grenade.queue_free()
	active_grenades.clear()


func _encode_vector2(value: Vector2) -> Array:
	return [value.x, value.y]


func _decode_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return fallback


func _is_unlocked(owner) -> bool:
	return owner != null and owner.has_method("_is_blessing_skill_unlocked") and bool(owner._is_blessing_skill_unlocked(SKILL_ID))


func _has_talent(owner, talent_id: String) -> bool:
	return owner != null and owner.has_method("_has_level_talent") and bool(owner._has_level_talent(talent_id))
