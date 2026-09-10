extends RefCounted

const CANNON_TEXTURES := [
	preload("res://effects/mechanic/heavy_cannon/1.png"),
	preload("res://effects/mechanic/heavy_cannon/2.png"),
	preload("res://effects/mechanic/heavy_cannon/3.png")
]

const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")

const SKILL_ID := "missile_volley"
const COOLDOWN := 22.0
const DURATION := 10.0
const FIRE_INTERVAL := 1.2
const DAMAGE_RATIO := 2.0
const DEPLOY_OFFSET := 64.0
const BIG_BULLET_HIT_RADIUS := 24.0
const BIG_BULLET_VISUAL_SCALE := 3.6
const BIG_BULLET_SPEED := 380.0
const CANNON_COLOR := Color(1.0, 0.72, 0.3, 1.0)
const CANNON_VISUAL_SCALE := 0.8
const CANNON_VISUAL_TINT := Color(0.85, 0.9, 1.0, 1.0)
const CANNON_VISUAL_OFFSET := Vector2(-2.0, -104.0)
const CANNON_VISUAL_FPS := 9.0

var cooldown_remaining: float = 0.0
var active_cannons: Array[Dictionary] = []
var pending_saved_cannons: Array[Dictionary] = []
var cached_cannon_frames: SpriteFrames


func update(owner, delta: float) -> void:
	cooldown_remaining = max(0.0, cooldown_remaining - delta)
	for index in range(active_cannons.size() - 1, -1, -1):
		var data: Dictionary = active_cannons[index]
		var cannon: Node2D = data.get("node", null) as Node2D
		if owner == null or not is_instance_valid(owner) or cannon == null or not is_instance_valid(cannon):
			if cannon != null and is_instance_valid(cannon):
				cannon.queue_free()
			active_cannons.remove_at(index)
			continue
		var remaining: float = float(data.get("remaining", 0.0)) - delta
		if remaining <= 0.0:
			cannon.queue_free()
			active_cannons.remove_at(index)
			continue
		var tick_elapsed: float = float(data.get("tick_elapsed", 0.0)) + delta
		data["remaining"] = remaining
		data["tick_elapsed"] = tick_elapsed
		active_cannons[index] = data
		if tick_elapsed >= FIRE_INTERVAL:
			data["tick_elapsed"] = 0.0
			active_cannons[index] = data
			_fire(owner, data)


func can_trigger(owner, role_id: String) -> bool:
	return owner != null and is_instance_valid(owner) and role_id == "mechanic" and not bool(owner.get("is_dead")) and not bool(owner.get("level_up_active")) and _is_unlocked(owner) and cooldown_remaining <= 0.0


func try_trigger(owner) -> bool:
	if not can_trigger(owner, "mechanic"):
		return false
	if deploy_cannon(owner) == null:
		return false
	cooldown_remaining = get_cooldown(owner)
	return true


func deploy_cannon(owner):
	if owner == null or not is_instance_valid(owner):
		return null
	var scene: Node = owner.get_tree().current_scene if owner.get_tree() != null else null
	if scene == null:
		return null
	var direction: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	var cannon := Node2D.new()
	cannon.name = "MechanicHeavyCannon"
	cannon.z_index = 25
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = _get_cannon_frames()
	sprite.animation = StringName("fire")
	sprite.offset = CANNON_VISUAL_OFFSET
	sprite.scale = Vector2.ONE * CANNON_VISUAL_SCALE
	sprite.modulate = CANNON_VISUAL_TINT
	cannon.add_child(sprite)
	cannon.global_position = owner.global_position + direction.normalized() * DEPLOY_OFFSET
	cannon.rotation = direction.angle()
	scene.add_child(cannon)
	active_cannons.append({
		"node": cannon,
		"remaining": _get_duration(owner),
		"tick_elapsed": 0.0
	})
	return cannon


func get_cooldown(_owner) -> float:
	return COOLDOWN


func get_cooldown_slot(owner = null) -> Dictionary:
	return {
		"name": "重型炮台",
		"remaining": clamp(cooldown_remaining, 0.0, COOLDOWN),
		"duration": get_cooldown(owner),
		"color": CANNON_COLOR,
		"description": "部署一座重型炮台，持续 10 秒，每 1.2 秒发射一枚大子弹，造成 200% 伤害（受战场改装零件加成）。"
	}


func get_save_data() -> Dictionary:
	var cannons: Array[Dictionary] = []
	for data in active_cannons:
		var cannon: Node2D = data.get("node", null) as Node2D
		if cannon == null or not is_instance_valid(cannon):
			continue
		cannons.append({
			"position": _encode_vector2(cannon.global_position),
			"rotation": cannon.rotation,
			"remaining": max(0.0, float(data.get("remaining", 0.0))),
			"tick_elapsed": max(0.0, float(data.get("tick_elapsed", 0.0)))
		})
	return {"cooldown_remaining": cooldown_remaining, "cannons": cannons}


func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)
	_clear_cannons()
	pending_saved_cannons.clear()
	var saved_cannons: Variant = data.get("cannons", [])
	if saved_cannons is Array:
		for saved_data in saved_cannons:
			if saved_data is Dictionary:
				pending_saved_cannons.append((saved_data as Dictionary).duplicate(true))


func restore_effect_if_active(owner) -> void:
	var tree: SceneTree = owner.get_tree() if owner != null and is_instance_valid(owner) and owner.has_method("get_tree") else null
	var scene: Node = tree.current_scene if tree != null else null
	if scene == null:
		return
	for saved_data in pending_saved_cannons:
		var remaining: float = max(0.0, float(saved_data.get("remaining", 0.0)))
		if remaining <= 0.0:
			continue
		var cannon = deploy_cannon(owner)
		if cannon == null:
			continue
		cannon.global_position = _decode_vector2(saved_data.get("position", []), owner.global_position)
		cannon.rotation = float(saved_data.get("rotation", 0.0))
		for index in range(active_cannons.size()):
			if active_cannons[index].get("node", null) == cannon:
				var data: Dictionary = active_cannons[index]
				data["remaining"] = remaining
				data["tick_elapsed"] = clamp(float(saved_data.get("tick_elapsed", 0.0)), 0.0, FIRE_INTERVAL)
				active_cannons[index] = data
				break
	pending_saved_cannons.clear()


func _fire(owner, data: Dictionary) -> void:
	var cannon: Node2D = data.get("node", null) as Node2D
	if cannon == null or not is_instance_valid(cannon) or not owner.has_method("_get_enemy_nearest_to_position"):
		return
	var target: Node2D = owner._get_enemy_nearest_to_position(cannon.global_position)
	if target == null or not is_instance_valid(target):
		return
	var sprite := cannon.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.frame = 1
		sprite.frame_progress = 0.0
		sprite.play("fire")
	var damage_amount: float = owner._get_role_damage("mechanic") * DAMAGE_RATIO * _get_cannon_damage_multiplier(owner) * _get_summon_damage_multiplier(owner)
	var bullet = owner._spawn_bullet(target, damage_amount, CANNON_COLOR, "mechanic", cannon.global_position)
	if bullet != null and is_instance_valid(bullet):
		bullet.speed = BIG_BULLET_SPEED
		bullet.hit_radius = BIG_BULLET_HIT_RADIUS
		bullet.visual_scale_multiplier = BIG_BULLET_VISUAL_SCALE
		if bullet.has_method("_refresh_bullet_visual"):
			bullet._refresh_bullet_visual(true)


func _get_cannon_frames() -> SpriteFrames:
	if cached_cannon_frames != null:
		return cached_cannon_frames
	var frames := SpriteFrames.new()
	frames.add_animation("fire")
	frames.set_animation_loop("fire", false)
	frames.set_animation_speed("fire", CANNON_VISUAL_FPS)
	for texture in CANNON_TEXTURES:
		if texture != null:
			frames.add_frame("fire", texture)
	cached_cannon_frames = frames
	return frames


func _get_duration(owner) -> float:
	return DURATION + PLAYER_BUILD_SYSTEM.get_mechanic_cannon_duration_bonus(owner)


func _get_cannon_damage_multiplier(owner) -> float:
	return 1.0 + 0.2 * float(PLAYER_BUILD_SYSTEM.get_mechanic_cannon_damage_bonus_count(owner))


func _clear_cannons() -> void:
	for data in active_cannons:
		var cannon: Node2D = data.get("node", null) as Node2D
		if cannon != null and is_instance_valid(cannon):
			cannon.queue_free()
	active_cannons.clear()


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
