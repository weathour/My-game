extends RefCounted

const MINE_TEXTURES := [
	preload("res://effects/mechanic/mine/1.png"),
	preload("res://effects/mechanic/mine/2.png"),
	preload("res://effects/mechanic/mine/3.png"),
	preload("res://effects/mechanic/mine/4.png"),
	preload("res://effects/mechanic/mine/5.png"),
	preload("res://effects/mechanic/mine/6.png"),
	preload("res://effects/mechanic/mine/7.png"),
	preload("res://effects/mechanic/mine/8.png")
]

const SKILL_ID := "mine"
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const COOLDOWN := 16.0
const MINE_COUNT := 3
const TRIGGER_RADIUS := 80.0
const DAMAGE_RATIO := 2.0
const DEPLOY_RADIUS := 48.0
const MINE_COLOR := Color(0.95, 0.68, 0.25, 1.0)
const MINE_VISUAL_SCALE := 0.2
const MINE_VISUAL_OFFSET := Vector2(-2.0, -30.0)
const MINE_IDLE_FPS := 4.0
const MINE_BLAST_FPS := 12.0
const MINE_BLAST_VISUAL_MAX_RADIUS := 172.0
const TALENT_MINE_1 := "mechanic_level_talent_mine_1"
const TALENT_MINE_2 := "mechanic_level_talent_mine_2"
const TALENT_COUNT_BONUS := 2
const TALENT_RADIUS_MULTIPLIER := 1.5
const TALENT_SLOW_MULTIPLIER := 0.7
const TALENT_SLOW_DURATION := 1.0

var cooldown_remaining: float = 0.0
var active_mines: Array[Dictionary] = []
var pending_saved_mines: Array[Dictionary] = []
var cached_mine_frames: SpriteFrames


func update(owner, delta: float) -> void:
	cooldown_remaining = max(0.0, cooldown_remaining - delta)
	if owner == null or not is_instance_valid(owner) or not owner.has_method("_get_live_enemies"):
		return
	for index in range(active_mines.size() - 1, -1, -1):
		var data: Dictionary = active_mines[index]
		var mine: Node2D = data.get("node", null) as Node2D
		if mine == null or not is_instance_valid(mine):
			active_mines.remove_at(index)
			continue
		if _has_enemy_in_range(owner, mine.global_position):
			_explode(owner, mine.global_position)
			mine.queue_free()
			active_mines.remove_at(index)


func can_trigger(owner, role_id: String) -> bool:
	return owner != null and is_instance_valid(owner) and role_id == "mechanic" and not bool(owner.get("is_dead")) and not bool(owner.get("level_up_active")) and _is_unlocked(owner) and cooldown_remaining <= 0.0


func try_trigger(owner) -> bool:
	if not can_trigger(owner, "mechanic"):
		return false
	var scene: Node = owner.get_tree().current_scene if owner.get_tree() != null else null
	if scene == null:
		return false
	cooldown_remaining = get_cooldown(owner)
	var mine_count: int = MINE_COUNT + PLAYER_BUILD_SYSTEM.get_mechanic_mine_count_bonus(owner) + (TALENT_COUNT_BONUS if _has_talent(owner, TALENT_MINE_1) else 0)
	for index in range(mine_count):
		var angle: float = TAU * float(index) / float(mine_count) - PI * 0.5
		_spawn_mine(owner, scene, owner.global_position + Vector2.RIGHT.rotated(angle) * DEPLOY_RADIUS)
	return true


func get_cooldown(_owner) -> float:
	return COOLDOWN


func get_cooldown_slot(owner = null) -> Dictionary:
	return {
		"name": "感应地雷",
		"remaining": clamp(cooldown_remaining, 0.0, COOLDOWN),
		"duration": get_cooldown(owner),
		"color": MINE_COLOR,
		"description": "在自身周围布置 3 枚感应地雷，敌人进入 80 半径时爆炸，造成 200% 范围伤害（受战场改装零件加成）。"
	}


func get_save_data() -> Dictionary:
	var mines: Array[Dictionary] = []
	for data in active_mines:
		var mine: Node2D = data.get("node", null) as Node2D
		if mine == null or not is_instance_valid(mine):
			continue
		mines.append({"position": _encode_vector2(mine.global_position)})
	return {"cooldown_remaining": cooldown_remaining, "mines": mines}


func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)
	_clear_mines()
	pending_saved_mines.clear()
	var saved_mines: Variant = data.get("mines", [])
	if saved_mines is Array:
		for saved_data in saved_mines:
			if saved_data is Dictionary:
				pending_saved_mines.append((saved_data as Dictionary).duplicate(true))


func restore_effect_if_active(owner) -> void:
	var tree: SceneTree = owner.get_tree() if owner != null and is_instance_valid(owner) and owner.has_method("get_tree") else null
	var scene: Node = tree.current_scene if tree != null else null
	if scene == null:
		return
	for saved_data in pending_saved_mines:
		_spawn_mine(owner, scene, _decode_vector2(saved_data.get("position", []), owner.global_position))
	pending_saved_mines.clear()


func _spawn_mine(_owner, scene: Node, position: Vector2) -> Node2D:
	var mine := Node2D.new()
	mine.name = "MechanicMine"
	mine.z_index = 25
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = _get_mine_frames()
	sprite.animation = StringName("idle")
	sprite.offset = MINE_VISUAL_OFFSET
	sprite.scale = Vector2.ONE * MINE_VISUAL_SCALE
	mine.add_child(sprite)
	mine.global_position = position
	scene.add_child(mine)
	sprite.play("idle")
	active_mines.append({"node": mine})
	return mine


func _has_enemy_in_range(owner, center: Vector2) -> bool:
	var trigger_radius: float = TRIGGER_RADIUS * (TALENT_RADIUS_MULTIPLIER if _has_talent(owner, TALENT_MINE_2) else 1.0)
	for enemy in owner._get_live_enemies():
		if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if (enemy as Node2D).global_position.distance_squared_to(center) <= trigger_radius * trigger_radius:
			return true
	return false


func _explode(owner, center: Vector2) -> void:
	var damage_amount: float = owner._get_role_damage("mechanic") * DAMAGE_RATIO * PLAYER_BUILD_SYSTEM.get_mechanic_mine_damage_multiplier(owner) * _get_summon_damage_multiplier(owner)
	var blast_radius: float = TRIGGER_RADIUS
	var slow_multiplier: float = 1.0
	var slow_duration: float = 0.0
	if _has_talent(owner, TALENT_MINE_2):
		blast_radius *= TALENT_RADIUS_MULTIPLIER
		slow_multiplier = TALENT_SLOW_MULTIPLIER
		slow_duration = TALENT_SLOW_DURATION
	_spawn_blast_visual(owner, center, blast_radius)
	owner._damage_enemies_in_radius(center, blast_radius, damage_amount, 0.0, slow_multiplier, slow_duration, "mechanic")


func _spawn_blast_visual(owner, center: Vector2, blast_radius: float) -> void:
	var scene: Node = owner.get_tree().current_scene if owner.get_tree() != null else null
	if scene == null:
		return
	var sprite := AnimatedSprite2D.new()
	sprite.name = "MechanicMineBlast"
	sprite.z_index = 12
	sprite.sprite_frames = _get_mine_frames()
	sprite.animation = StringName("explode")
	sprite.scale = Vector2.ONE * (blast_radius / MINE_BLAST_VISUAL_MAX_RADIUS)
	sprite.global_position = center
	sprite.add_to_group("temporary_effects")
	scene.add_child(sprite)
	sprite.animation_finished.connect(sprite.queue_free, CONNECT_ONE_SHOT)
	sprite.play("explode")


func _get_mine_frames() -> SpriteFrames:
	if cached_mine_frames != null:
		return cached_mine_frames
	cached_mine_frames = _build_mine_frames()
	return cached_mine_frames


func _build_mine_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", MINE_IDLE_FPS)
	for texture in MINE_TEXTURES.slice(0, 2):
		if texture != null:
			frames.add_frame("idle", texture)
	frames.add_animation("explode")
	frames.set_animation_loop("explode", false)
	frames.set_animation_speed("explode", MINE_BLAST_FPS)
	for texture in MINE_TEXTURES.slice(2):
		if texture != null:
			frames.add_frame("explode", texture)
	return frames


func _clear_mines() -> void:
	for data in active_mines:
		var mine: Node2D = data.get("node", null) as Node2D
		if mine != null and is_instance_valid(mine):
			mine.queue_free()
	active_mines.clear()


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
