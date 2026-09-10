extends RefCounted

const TURRET_TEXTURES := [
	preload("res://effects/mechanic/tulip_turret/1.png"),
	preload("res://effects/mechanic/tulip_turret/2.png"),
	preload("res://effects/mechanic/tulip_turret/3.png")
]

const SKILL_ID := "tulip_turret"
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const COOLDOWN := 20.0
const DURATION := 8.0
const FIRE_INTERVAL := 0.8
const DAMAGE_RATIO := 1.2
const DEPLOY_OFFSET := 44.0
const TALENT_TURRET_1 := "mechanic_level_talent_turret_1"
const TALENT_TURRET_2 := "mechanic_level_talent_turret_2"
const TALENT_ENTRY_1 := "mechanic_level_talent_entry_1"
const TALENT_FIRE_INTERVAL := 0.6
const TALENT_DURATION_BONUS := 2.0
const TALENT_DAMAGE_RATIO := 1.5
const TURRET_COLOR := Color(0.95, 0.68, 0.25, 1.0)
const TURRET_VISUAL_SCALE := 0.25
const TURRET_VISUAL_OFFSET := Vector2(-2.0, -37.0)
const TURRET_VISUAL_FPS := 9.0

var cooldown_remaining: float = 0.0
var active_turrets: Array[Dictionary] = []
var pending_saved_turrets: Array[Dictionary] = []
var cached_turret_frames: SpriteFrames


func update(owner, delta: float) -> void:
	cooldown_remaining = max(0.0, cooldown_remaining - delta)
	for index in range(active_turrets.size() - 1, -1, -1):
		var data: Dictionary = active_turrets[index]
		var turret: Node2D = data.get("node", null) as Node2D
		if owner == null or not is_instance_valid(owner) or turret == null or not is_instance_valid(turret):
			if turret != null and is_instance_valid(turret):
				turret.queue_free()
			active_turrets.remove_at(index)
			continue
		var remaining: float = float(data.get("remaining", 0.0)) - delta
		if remaining <= 0.0:
			turret.queue_free()
			active_turrets.remove_at(index)
			continue
		var tick_elapsed: float = float(data.get("tick_elapsed", 0.0)) + delta
		data["remaining"] = remaining
		data["tick_elapsed"] = tick_elapsed
		active_turrets[index] = data
		if tick_elapsed >= _get_fire_interval(owner):
			data["tick_elapsed"] = 0.0
			active_turrets[index] = data
			_fire(owner, data)


func can_trigger(owner, role_id: String) -> bool:
	return owner != null and is_instance_valid(owner) and role_id == "mechanic" and not bool(owner.get("is_dead")) and not bool(owner.get("level_up_active")) and _is_unlocked(owner) and cooldown_remaining <= 0.0


func try_trigger(owner) -> bool:
	if not can_trigger(owner, "mechanic"):
		return false
	if deploy_turret(owner, 1.0) == null:
		return false
	cooldown_remaining = get_cooldown(owner)
	return true


func deploy_turret(owner, damage_scale: float = 1.0, direction_sign: float = 1.0):
	if owner == null or not is_instance_valid(owner):
		return null
	var scene: Node = owner.get_tree().current_scene if owner.get_tree() != null else null
	if scene == null:
		return null
	var direction: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	if direction_sign < 0.0:
		direction = -direction
	var turret := Node2D.new()
	turret.name = "MechanicTulipTurret"
	turret.z_index = 25
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = _get_turret_frames()
	sprite.animation = StringName("fire")
	sprite.offset = TURRET_VISUAL_OFFSET
	sprite.scale = Vector2.ONE * TURRET_VISUAL_SCALE
	turret.add_child(sprite)
	turret.global_position = owner.global_position + direction.normalized() * DEPLOY_OFFSET
	turret.rotation = direction.angle()
	scene.add_child(turret)
	var duration: float = DURATION + PLAYER_BUILD_SYSTEM.get_mechanic_turret_duration_bonus(owner)
	if _has_talent(owner, TALENT_TURRET_2) or _has_talent(owner, TALENT_ENTRY_1):
		duration += TALENT_DURATION_BONUS
	active_turrets.append({
		"node": turret,
		"remaining": duration,
		"tick_elapsed": 0.0,
		"damage_scale": max(0.0, damage_scale)
	})
	return turret


func get_cooldown(_owner) -> float:
	return COOLDOWN


func get_cooldown_slot(owner = null) -> Dictionary:
	return {
		"name": "定点机炮",
		"remaining": clamp(cooldown_remaining, 0.0, COOLDOWN),
		"duration": get_cooldown(owner),
		"color": TURRET_COLOR,
		"description": "在原地部署一座定点机炮，持续 8 秒，每 0.8 秒射击最近的敌人，造成 120% 伤害（受战场改装零件加成）。"
	}


func get_save_data() -> Dictionary:
	var turrets: Array[Dictionary] = []
	for data in active_turrets:
		var turret: Node2D = data.get("node", null) as Node2D
		if turret == null or not is_instance_valid(turret):
			continue
		turrets.append({
			"position": _encode_vector2(turret.global_position),
			"rotation": turret.rotation,
			"remaining": max(0.0, float(data.get("remaining", 0.0))),
			"tick_elapsed": max(0.0, float(data.get("tick_elapsed", 0.0))),
			"damage_scale": max(0.0, float(data.get("damage_scale", 1.0)))
		})
	return {"cooldown_remaining": cooldown_remaining, "turrets": turrets}


func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)
	_clear_turrets()
	pending_saved_turrets.clear()
	var saved_turrets: Variant = data.get("turrets", [])
	if saved_turrets is Array:
		for saved_data in saved_turrets:
			if saved_data is Dictionary:
				pending_saved_turrets.append((saved_data as Dictionary).duplicate(true))


func restore_effect_if_active(owner) -> void:
	var tree: SceneTree = owner.get_tree() if owner != null and is_instance_valid(owner) and owner.has_method("get_tree") else null
	var scene: Node = tree.current_scene if tree != null else null
	if scene == null:
		return
	for saved_data in pending_saved_turrets:
		var remaining: float = max(0.0, float(saved_data.get("remaining", 0.0)))
		if remaining <= 0.0:
			continue
		var turret = deploy_turret(owner, float(saved_data.get("damage_scale", 1.0)))
		if turret == null:
			continue
		turret.global_position = _decode_vector2(saved_data.get("position", []), owner.global_position)
		turret.rotation = float(saved_data.get("rotation", 0.0))
		for index in range(active_turrets.size()):
			if active_turrets[index].get("node", null) == turret:
				var data: Dictionary = active_turrets[index]
				data["remaining"] = remaining
				data["tick_elapsed"] = clamp(float(saved_data.get("tick_elapsed", 0.0)), 0.0, FIRE_INTERVAL)
				active_turrets[index] = data
				break
	pending_saved_turrets.clear()


func _fire(owner, data: Dictionary) -> void:
	var turret: Node2D = data.get("node", null) as Node2D
	if turret == null or not is_instance_valid(turret) or not owner.has_method("_get_enemy_nearest_to_position"):
		return
	var target: Node2D = owner._get_enemy_nearest_to_position(turret.global_position)
	if target == null or not is_instance_valid(target):
		return
	var sprite := turret.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.frame = 1
		sprite.frame_progress = 0.0
		sprite.play("fire")
	var damage_ratio: float = TALENT_DAMAGE_RATIO if _has_talent(owner, TALENT_TURRET_2) else DAMAGE_RATIO
	var damage_amount: float = owner._get_role_damage("mechanic") * damage_ratio * float(data.get("damage_scale", 1.0)) * PLAYER_BUILD_SYSTEM.get_mechanic_turret_damage_multiplier(owner) * _get_summon_damage_multiplier(owner)
	owner._spawn_bullet(target, damage_amount, TURRET_COLOR, "mechanic", turret.global_position)


func _get_turret_frames() -> SpriteFrames:
	if cached_turret_frames != null:
		return cached_turret_frames
	cached_turret_frames = _build_turret_frames()
	return cached_turret_frames


func _build_turret_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("fire")
	frames.set_animation_loop("fire", false)
	frames.set_animation_speed("fire", TURRET_VISUAL_FPS)
	for texture in TURRET_TEXTURES:
		if texture != null:
			frames.add_frame("fire", texture)
	return frames


func _get_fire_interval(owner) -> float:
	return TALENT_FIRE_INTERVAL if _has_talent(owner, TALENT_TURRET_1) else FIRE_INTERVAL


func _clear_turrets() -> void:
	for data in active_turrets:
		var turret: Node2D = data.get("node", null) as Node2D
		if turret != null and is_instance_valid(turret):
			turret.queue_free()
	active_turrets.clear()


func _encode_vector2(value: Vector2) -> Array:
	return [value.x, value.y]


func _decode_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return fallback


func _get_summon_damage_multiplier(owner) -> float:
	var role = owner.get("mechanic_role") if owner != null else null
	if role != null and role.has_method("get_summon_damage_multiplier"):
		return float(role.get_summon_damage_multiplier(owner))
	return 1.0


func _is_unlocked(owner) -> bool:
	return owner != null and owner.has_method("_is_blessing_skill_unlocked") and bool(owner._is_blessing_skill_unlocked(SKILL_ID))


func _has_talent(owner, talent_id: String) -> bool:
	return owner != null and owner.has_method("_has_level_talent") and bool(owner._has_level_talent(talent_id))
