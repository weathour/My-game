extends RefCounted

const GUARD_TEXTURES := [
	preload("res://effects/mechanic/drone/1.png"),
	preload("res://effects/mechanic/drone/2.png"),
	preload("res://effects/mechanic/drone/3.png"),
	preload("res://effects/mechanic/drone/4.png")
]

const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")

const SKILL_ID := "drone"
const COOLDOWN := 14.0
const BLOCK_CHARGES := 3
const MAX_ACTIVE_GUARDS := 5
const FOLLOW_OFFSET := Vector2(-40.0, -34.0)
const FOLLOW_LERP := 6.0
const GUARD_COLOR := Color(0.95, 0.68, 0.25, 1.0)
const GUARD_VISUAL_SCALE := 0.24
const GUARD_VISUAL_FPS := 9.0
const TALENT_DRONE_1 := "mechanic_level_talent_drone_1"
const TALENT_DRONE_2 := "mechanic_level_talent_drone_2"
const TALENT_CHARGES_BONUS := 2
const TALENT_CAP_BONUS := 2

var cooldown_remaining: float = 0.0
var active_guards: Array[Dictionary] = []
var pending_saved_guards: Array[Dictionary] = []
var cached_guard_frames: SpriteFrames


func update(owner, delta: float) -> void:
	cooldown_remaining = max(0.0, cooldown_remaining - delta)
	for index in range(active_guards.size() - 1, -1, -1):
		var data: Dictionary = active_guards[index]
		var guard: Node2D = data.get("node", null) as Node2D
		if owner == null or not is_instance_valid(owner) or guard == null or not is_instance_valid(guard):
			if guard != null and is_instance_valid(guard):
				guard.queue_free()
			active_guards.remove_at(index)
			continue
		if int(data.get("charges", 0)) <= 0:
			guard.queue_free()
			active_guards.remove_at(index)
			continue
		var facing: float = 1.0
		if owner.get("facing_direction") is Vector2 and (owner.get("facing_direction") as Vector2).x < 0.0:
			facing = -1.0
		var slot_angle: float = TAU * float(index) / float(max(1, active_guards.size())) - PI * 0.5
		var target_position: Vector2 = owner.global_position + Vector2(FOLLOW_OFFSET.x * facing, FOLLOW_OFFSET.y) + Vector2.RIGHT.rotated(slot_angle) * 20.0
		guard.global_position = guard.global_position.lerp(target_position, clamp(FOLLOW_LERP * delta, 0.0, 1.0))


func can_trigger(owner, role_id: String) -> bool:
	return owner != null and is_instance_valid(owner) and role_id == "mechanic" and not bool(owner.get("is_dead")) and not bool(owner.get("level_up_active")) and _is_unlocked(owner) and cooldown_remaining <= 0.0


func try_trigger(owner) -> bool:
	if not can_trigger(owner, "mechanic"):
		return false
	var scene: Node = owner.get_tree().current_scene if owner.get_tree() != null else null
	if scene == null:
		return false
	cooldown_remaining = get_cooldown(owner)
	while active_guards.size() >= _get_max_guards(owner):
		var oldest: Dictionary = active_guards[0]
		var oldest_node: Node2D = oldest.get("node", null) as Node2D
		if oldest_node != null and is_instance_valid(oldest_node):
			oldest_node.queue_free()
		active_guards.remove_at(0)
	_spawn_guard(owner, scene, _get_max_charges(owner))
	return true


func try_block_damage(owner) -> bool:
	for index in range(active_guards.size()):
		var data: Dictionary = active_guards[index]
		var guard: Node2D = data.get("node", null) as Node2D
		var charges: int = int(data.get("charges", 0))
		if guard == null or not is_instance_valid(guard) or charges <= 0:
			continue
		charges -= 1
		data["charges"] = charges
		active_guards[index] = data
		_play_block_feedback(owner, guard)
		if charges <= 0:
			guard.queue_free()
			active_guards.remove_at(index)
		return true
	return false


func get_cooldown(_owner) -> float:
	return COOLDOWN


func get_cooldown_slot(owner = null) -> Dictionary:
	var max_charges: int = _get_max_charges(owner) if owner != null else BLOCK_CHARGES
	var max_guards: int = _get_max_guards(owner) if owner != null else MAX_ACTIVE_GUARDS
	return {
		"name": "守卫机器人",
		"remaining": clamp(cooldown_remaining, 0.0, COOLDOWN),
		"duration": get_cooldown(owner),
		"color": GUARD_COLOR,
		"description": "召唤 1 台跟随自身的守卫机器人，最多同时存在 %d 台；每台替你抵挡 %d 次伤害，抵挡次数耗尽后销毁。" % [max_guards, max_charges]
	}


func get_save_data() -> Dictionary:
	var guards: Array[Dictionary] = []
	for data in active_guards:
		var guard: Node2D = data.get("node", null) as Node2D
		if guard == null or not is_instance_valid(guard):
			continue
		guards.append({"charges": int(data.get("charges", 0))})
	return {"cooldown_remaining": cooldown_remaining, "guards": guards}


func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)
	_clear_guards()
	pending_saved_guards.clear()
	var saved_guards: Variant = data.get("guards", [])
	if saved_guards is Array:
		for saved_data in saved_guards:
			if saved_data is Dictionary:
				pending_saved_guards.append((saved_data as Dictionary).duplicate(true))


func restore_effect_if_active(owner) -> void:
	var tree: SceneTree = owner.get_tree() if owner != null and is_instance_valid(owner) and owner.has_method("get_tree") else null
	var scene: Node = tree.current_scene if tree != null else null
	if scene == null:
		return
	for saved_data in pending_saved_guards:
		var charges: int = int(saved_data.get("charges", 0))
		if charges <= 0:
			continue
		_spawn_guard(owner, scene, charges)
	pending_saved_guards.clear()


func _spawn_guard(owner, scene: Node, charges: int) -> Node2D:
	var guard := Node2D.new()
	guard.name = "MechanicGuardBot"
	guard.z_index = 26
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = _get_guard_frames()
	sprite.animation = StringName("guard")
	sprite.scale = Vector2.ONE * GUARD_VISUAL_SCALE
	guard.add_child(sprite)
	guard.global_position = owner.global_position + FOLLOW_OFFSET
	scene.add_child(guard)
	sprite.play("guard")
	active_guards.append({
		"node": guard,
		"charges": charges
	})
	return guard


func _play_block_feedback(owner, guard: Node2D) -> void:
	var sprite := guard.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.modulate = Color(2.2, 2.2, 2.2, 1.0)
		var tween: Tween = guard.create_tween()
		if tween != null:
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	if owner != null and is_instance_valid(owner):
		if owner.has_method("_spawn_combat_tag"):
			owner._spawn_combat_tag(guard.global_position + Vector2(0.0, -18.0), "格挡", GUARD_COLOR)
		if owner.has_method("_spawn_ring_effect"):
			owner._spawn_ring_effect(guard.global_position, 26.0, Color(0.95, 0.68, 0.25, 0.85), 2.0, 0.18)


func _get_guard_frames() -> SpriteFrames:
	if cached_guard_frames != null:
		return cached_guard_frames
	var frames := SpriteFrames.new()
	frames.add_animation("guard")
	frames.set_animation_loop("guard", true)
	frames.set_animation_speed("guard", GUARD_VISUAL_FPS)
	for texture in GUARD_TEXTURES:
		if texture != null:
			frames.add_frame("guard", texture)
	cached_guard_frames = frames
	return frames


func _get_max_charges(owner) -> int:
	var charges: int = BLOCK_CHARGES + PLAYER_BUILD_SYSTEM.get_mechanic_guard_block_bonus(owner)
	if _has_talent(owner, TALENT_DRONE_1):
		charges += TALENT_CHARGES_BONUS
	return max(1, charges)


func _get_max_guards(owner) -> int:
	var cap: int = MAX_ACTIVE_GUARDS + PLAYER_BUILD_SYSTEM.get_mechanic_guard_cap_bonus(owner)
	if _has_talent(owner, TALENT_DRONE_2):
		cap += TALENT_CAP_BONUS
	return max(1, cap)


func _clear_guards() -> void:
	for data in active_guards:
		var guard: Node2D = data.get("node", null) as Node2D
		if guard != null and is_instance_valid(guard):
			guard.queue_free()
	active_guards.clear()


func _is_unlocked(owner) -> bool:
	return owner != null and owner.has_method("_is_blessing_skill_unlocked") and bool(owner._is_blessing_skill_unlocked(SKILL_ID))


func _has_talent(owner, talent_id: String) -> bool:
	return owner != null and owner.has_method("_has_level_talent") and bool(owner._has_level_talent(talent_id))
