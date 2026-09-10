extends RefCounted

const TOWER_TEXTURES := [
	preload("res://effects/mechanic/field_tower/1.png"),
	preload("res://effects/mechanic/field_tower/2.png"),
	preload("res://effects/mechanic/field_tower/3.png")
]

const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")

const SKILL_ID := "emp_burst"
const COOLDOWN := 18.0
const FIELD_DURATION := 10.0
const FIELD_RADIUS := 450.0
const TICK_INTERVAL := 0.5
const TICK_DAMAGE_RATIO := 0.3
const SLOW_MULTIPLIER := 0.6
const SLOW_DURATION := 1.0
const SELF_HASTE_MULTIPLIER := 1.3
const HEAL_RATIO_PER_TICK := 0.015
const FIELD_COLOR := Color(0.62, 0.85, 1.0, 1.0)
const TOWER_VISUAL_SCALE := 0.33
const TOWER_VISUAL_OFFSET := Vector2(-2.0, -44.0)
const TOWER_VISUAL_FPS := 9.0
const TOWER_VISUAL_TINT := Color(0.7, 0.88, 1.0, 1.0)

var cooldown_remaining: float = 0.0
var field_remaining: float = 0.0
var tick_elapsed: float = 0.0
var field_position: Vector2 = Vector2.ZERO
var self_buff_active: bool = false
var field_node: Node2D
var cached_tower_frames: SpriteFrames


class FieldRippleVisual:
	extends Node2D

	const RING_COUNT := 3
	const RING_PERIOD := 1.6
	const RING_WIDTH := 5.0
	const RING_POINTS := 96

	var radius: float = 450.0
	var ring_color := Color(0.62, 0.85, 1.0, 1.0)
	var elapsed: float = 0.0


	func _process(delta: float) -> void:
		elapsed += delta
		queue_redraw()


	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, RING_POINTS, Color(ring_color.r, ring_color.g, ring_color.b, 0.16), 2.0, true)
		for index in range(RING_COUNT):
			var phase: float = fposmod(elapsed / RING_PERIOD + float(index) / float(RING_COUNT), 1.0)
			var ring_radius: float = phase * radius
			if ring_radius <= 1.0:
				continue
			var alpha: float = (1.0 - phase) * 0.55
			draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, RING_POINTS, Color(ring_color.r, ring_color.g, ring_color.b, alpha), RING_WIDTH, true)


func update(owner, delta: float) -> void:
	cooldown_remaining = max(0.0, cooldown_remaining - delta)
	if field_remaining <= 0.0:
		self_buff_active = false
		return
	if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")):
		_clear_field()
		return
	field_remaining = max(0.0, field_remaining - delta)
	self_buff_active = owner.global_position.distance_to(field_position) <= FIELD_RADIUS
	tick_elapsed += delta
	while tick_elapsed >= TICK_INTERVAL:
		tick_elapsed -= TICK_INTERVAL
		_tick_field(owner)
	if field_remaining <= 0.0:
		_clear_field()


func can_trigger(owner, role_id: String) -> bool:
	return owner != null and is_instance_valid(owner) and role_id == "mechanic" and not bool(owner.get("is_dead")) and not bool(owner.get("level_up_active")) and _is_unlocked(owner) and cooldown_remaining <= 0.0


func try_trigger(owner) -> bool:
	if not can_trigger(owner, "mechanic"):
		return false
	cooldown_remaining = get_cooldown(owner)
	field_remaining = FIELD_DURATION
	tick_elapsed = 0.0
	field_position = owner.global_position
	_spawn_field_visual(owner)
	_tick_field(owner)
	return true


func get_field_haste_multiplier() -> float:
	return SELF_HASTE_MULTIPLIER if self_buff_active else 1.0


func is_field_active() -> bool:
	return field_remaining > 0.0


func _tick_field(owner) -> void:
	if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")):
		return
	var damage_amount: float = owner._get_role_damage("mechanic") * TICK_DAMAGE_RATIO * _get_field_damage_multiplier(owner) * _get_summon_damage_multiplier(owner)
	var hits: int = owner._damage_enemies_in_radius(field_position, FIELD_RADIUS, damage_amount, 0.0, SLOW_MULTIPLIER, SLOW_DURATION, "mechanic")
	if hits > 0 and owner.has_method("_register_attack_result"):
		owner._register_attack_result("mechanic", hits, false)
	self_buff_active = owner.global_position.distance_to(field_position) <= FIELD_RADIUS
	if not self_buff_active:
		return
	var active_role: Dictionary = owner._get_active_role() if owner.has_method("_get_active_role") else {}
	var active_role_id: String = str(active_role.get("id", ""))
	if active_role_id != "" and owner.has_method("_heal_role"):
		var max_health: float = float(owner._get_role_max_health(active_role_id))
		if max_health > 0.0:
			owner._heal_role(active_role_id, max_health * HEAL_RATIO_PER_TICK)


func _spawn_field_visual(_owner) -> void:
	_clear_field_visuals()
	var tree: SceneTree = _owner.get_tree() if _owner != null else null
	var scene: Node = tree.current_scene if tree != null else null
	if scene == null:
		return
	var container := Node2D.new()
	container.name = "MechanicSappingField"
	container.z_index = 11
	container.global_position = field_position

	var ripple := FieldRippleVisual.new()
	ripple.name = "Ripple"
	ripple.radius = FIELD_RADIUS
	ripple.ring_color = FIELD_COLOR
	container.add_child(ripple)

	var tower := AnimatedSprite2D.new()
	tower.name = "Tower"
	tower.sprite_frames = _get_tower_frames()
	tower.animation = StringName("spin")
	tower.offset = TOWER_VISUAL_OFFSET
	tower.scale = Vector2.ONE * TOWER_VISUAL_SCALE
	tower.modulate = TOWER_VISUAL_TINT
	container.add_child(tower)

	scene.add_child(container)
	tower.play("spin")
	field_node = container


func _clear_field() -> void:
	field_remaining = 0.0
	tick_elapsed = 0.0
	self_buff_active = false
	_clear_field_visuals()


func _clear_field_visuals() -> void:
	if field_node != null and is_instance_valid(field_node):
		field_node.queue_free()
	field_node = null


func _get_tower_frames() -> SpriteFrames:
	if cached_tower_frames != null:
		return cached_tower_frames
	var frames := SpriteFrames.new()
	frames.add_animation("spin")
	frames.set_animation_loop("spin", true)
	frames.set_animation_speed("spin", TOWER_VISUAL_FPS)
	for texture in TOWER_TEXTURES:
		if texture != null:
			frames.add_frame("spin", texture)
	cached_tower_frames = frames
	return frames


func get_cooldown(owner) -> float:
	return max(6.0, COOLDOWN - PLAYER_BUILD_SYSTEM.get_mechanic_field_cooldown_reduction(owner))


func get_cooldown_slot(owner = null) -> Dictionary:
	return {
		"name": "磁滞力场",
		"remaining": clamp(cooldown_remaining, 0.0, get_cooldown(owner)),
		"duration": get_cooldown(owner),
		"color": FIELD_COLOR,
		"description": "在当前位置部署一座力场塔，展开半径 450 的磁滞力场，持续 10 秒：范围内敌人每 0.5 秒受到 30% 伤害并被减速 40%；自身处于力场范围内时移速提升 30% 且每 0.5 秒回复 1.5% 最大生命（伤害受战场改装零件加成）。"
	}


func get_save_data() -> Dictionary:
	return {
		"cooldown_remaining": cooldown_remaining,
		"field_remaining": field_remaining,
		"tick_elapsed": tick_elapsed,
		"field_position": [field_position.x, field_position.y]
	}


func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)
	field_remaining = clamp(float(data.get("field_remaining", 0.0)), 0.0, FIELD_DURATION)
	tick_elapsed = clamp(float(data.get("tick_elapsed", 0.0)), 0.0, TICK_INTERVAL)
	var saved_position: Variant = data.get("field_position", [])
	if saved_position is Array and (saved_position as Array).size() >= 2:
		field_position = Vector2(float((saved_position as Array)[0]), float((saved_position as Array)[1]))
	else:
		field_position = Vector2.ZERO


func restore_effect_if_active(owner) -> void:
	if field_remaining > 0.0:
		_spawn_field_visual(owner)


func _get_field_damage_multiplier(owner) -> float:
	return 1.0 + 0.25 * float(PLAYER_BUILD_SYSTEM.get_mechanic_field_damage_bonus_count(owner))


func _get_summon_damage_multiplier(owner) -> float:
	var role = owner.get("mechanic_role") if owner != null else null
	if role != null and role.has_method("get_summon_damage_multiplier"):
		return float(role.get_summon_damage_multiplier(owner))
	return 1.0


func _is_unlocked(owner) -> bool:
	return owner != null and owner.has_method("_is_blessing_skill_unlocked") and bool(owner._is_blessing_skill_unlocked(SKILL_ID))


func _has_talent(owner, talent_id: String) -> bool:
	return owner != null and owner.has_method("_has_level_talent") and bool(owner._has_level_talent(talent_id))
