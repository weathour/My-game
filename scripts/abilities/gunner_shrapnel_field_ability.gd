extends RefCounted

const SHRAPNEL_SCENE := preload("res://effects/gun/shrapnel/shrapnel.tscn")
const FIELD_TEXTURE := preload("res://effects/gun/shrapnel/散弹圈.png")
const SHRAPNEL_TEXTURES := [
	preload("res://effects/gun/shrapnel/1.png"),
	preload("res://effects/gun/shrapnel/2.png"),
	preload("res://effects/gun/shrapnel/3.png"),
	preload("res://effects/gun/shrapnel/4.png"),
	preload("res://effects/gun/shrapnel/5.png"),
	preload("res://effects/gun/shrapnel/6.png"),
	preload("res://effects/gun/shrapnel/7.png"),
	preload("res://effects/gun/shrapnel/8.png"),
	preload("res://effects/gun/shrapnel/9.png"),
	preload("res://effects/gun/shrapnel/10.png"),
	preload("res://effects/gun/shrapnel/11.png"),
	preload("res://effects/gun/shrapnel/12.png")
]

const SKILL_ID := "shrapnel_field"
const COOLDOWN := 10.0
const DURATION := 6.0
const BASE_RADIUS := 145.0
const RADIUS_MULTIPLIER := 1.30
const TIER_ONE_TICK_INTERVAL := 0.65
const TIER_TWO_TICK_INTERVAL := 0.45
const TIER_THREE_TICK_INTERVAL := 0.25
const TIER_ONE_SLOW := 0.70
const TIER_TWO_SLOW := 0.55
const TIER_THREE_SLOW := 0.45
const TIER_ONE_DAMAGE_RATIO := 0.44
const TIER_TWO_DAMAGE_RATIO := 0.60
const TIER_THREE_DAMAGE_RATIO := 0.60
const TIER_TWO_RADIUS := 200.0
const TIER_THREE_RADIUS := 220.0
const MAX_ACTIVE_VISUALS := 7
const VISUAL_SPAWN_INTERVAL := 0.1
const FIELD_CIRCLE_VISUAL_SCALE := 1.0
const FIELD_CIRCLE_VISIBLE_DIAMETER := 363.0
const FIELD_CIRCLE_VISIBLE_CENTER_OFFSET := Vector2(-18.0, 101.5)
const SHRAPNEL_MAX_VISIBLE_RADIUS := 127.0
const SHRAPNEL_VISUAL_MAX_SCALE := 0.62
const SHRAPNEL_ATLAS_REGION := Rect2(320.0, 320.0, 320.0, 240.0)
const MAX_CATCH_UP_TICKS := 5
const SHRAPNEL_VISUAL_POOL_LIMIT := 32

var cooldown_remaining: float = 0.0
var active_fields: Array[Dictionary] = []
var cached_shrapnel_frames: SpriteFrames
var shrapnel_visual_pool: Array[Node2D] = []


func update(owner, delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = max(0.0, cooldown_remaining - delta)
	if active_fields.is_empty():
		return
	if owner == null or not is_instance_valid(owner):
		stop()
		return
	if str(owner._get_active_role().get("id", "")) != "gunner":
		stop()
		return
	_update_fields(owner, delta)


func can_trigger(owner, role_id: String) -> bool:
	if owner == null or not is_instance_valid(owner):
		return false
	if bool(owner.get("is_dead")) or bool(owner.get("level_up_active")):
		return false
	if role_id != "gunner":
		return false
	if not _has_required_unlock(owner):
		return false
	return active_fields.is_empty() and cooldown_remaining <= 0.0


func try_trigger(owner) -> bool:
	if not can_trigger(owner, str(owner._get_active_role().get("id", ""))):
		return false
	cooldown_remaining = _get_cooldown(owner)
	active_fields.clear()
	var extra_field_count: int = _get_trick_extra_field_count(owner)
	var centers: Array = owner._get_random_enemy_cluster_centers(1 + extra_field_count)
	for center_value in centers:
		var center: Vector2 = center_value if center_value is Vector2 else owner.global_position
		_create_field(owner, center)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -66.0), "\u6563\u5f39", Color(1.0, 0.62, 0.32, 1.0))
	return true


func stop() -> void:
	for field_data in active_fields:
		_free_field(field_data)
	active_fields.clear()


func get_cooldown_slot(owner = null) -> Dictionary:
	var duration: float = _get_cooldown(owner)
	return {
		"name": "\u6563\u5f39",
		"remaining": clamp(cooldown_remaining, 0.0, duration),
		"duration": duration,
		"color": Color(1.0, 0.58, 0.28, 1.0),
		"description": "\u67aa\u624b\u5728\u602a\u7269\u5bc6\u96c6\u5904\u5236\u9020\u6563\u5f39\u533a\u57df\uff0c\u533a\u57df\u5185\u6301\u7eed\u9020\u6210\u4f24\u5bb3\u5e76\u51cf\u901f\u3002"
	}


func get_save_data() -> Dictionary:
	return {"cooldown_remaining": cooldown_remaining}


func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)
	stop()


func _update_fields(owner, delta: float) -> void:
	var next_fields: Array[Dictionary] = []
	var damage_shapes: Array[Dictionary] = []
	for field_data in active_fields:
		var remaining: float = max(0.0, float(field_data.get("remaining", 0.0)) - delta)
		field_data["remaining"] = remaining
		if remaining <= 0.0:
			_free_field(field_data)
			continue
		field_data["tick_remaining"] = float(field_data.get("tick_remaining", 0.0)) - delta
		var catch_up_ticks: int = 0
		while float(field_data.get("tick_remaining", 0.0)) <= 0.0 and catch_up_ticks < MAX_CATCH_UP_TICKS:
			field_data["tick_remaining"] = float(field_data.get("tick_remaining", 0.0)) + _get_tick_interval(owner)
			_add_damage_field_shape(owner, field_data, damage_shapes)
			catch_up_ticks += 1
		field_data["visual_remaining"] = float(field_data.get("visual_remaining", 0.0)) - delta
		while float(field_data.get("visual_remaining", 0.0)) <= 0.0:
			field_data["visual_remaining"] = float(field_data.get("visual_remaining", 0.0)) + VISUAL_SPAWN_INTERVAL
			_spawn_shrapnel_visual_if_room(field_data)
		next_fields.append(field_data)
	active_fields = next_fields
	var hits: int = _apply_damage_shapes(owner, damage_shapes)
	if hits > 0 and not _uses_batched_damage(owner):
		owner._register_attack_result("gunner", hits, false)


func _create_field(owner, center: Vector2) -> void:
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		return
	var radius: float = _get_radius(owner)
	var root: Node2D = null
	root = Node2D.new()
	root.name = "GunnerShrapnelField"
	root.global_position = center
	root.z_index = 10
	root.add_to_group("temporary_effects")
	current_scene.add_child(root)

	var circle: Sprite2D = Sprite2D.new()
	circle.name = "FieldCircle"
	circle.texture = FIELD_TEXTURE
	circle.centered = true
	circle.offset = FIELD_CIRCLE_VISIBLE_CENTER_OFFSET
	circle.modulate = Color(1.0, 1.0, 1.0, 0.602)
	circle.scale = Vector2.ONE * (radius * 2.0 / FIELD_CIRCLE_VISIBLE_DIAMETER * FIELD_CIRCLE_VISUAL_SCALE)
	root.add_child(circle)

	var field_data: Dictionary = {
		"root": root,
		"center": center,
		"remaining": _get_duration(owner),
		"tick_remaining": 0.0,
		"visual_remaining": 0.0,
		"visuals": [],
		"radius": radius
	}
	active_fields.append(field_data)


func _add_damage_field_shape(owner, field_data: Dictionary, damage_shapes: Array[Dictionary]) -> void:
	var center: Vector2 = field_data.get("center", owner.global_position)
	var radius: float = float(field_data.get("radius", _get_radius(owner)))
	damage_shapes.append({
		"type": "circle",
		"center": center,
		"radius": radius,
		"damage_amount": _get_damage(owner),
		"vulnerability_bonus": 0.0,
		"slow_multiplier": _get_slow_multiplier(owner),
		"slow_duration": 1.1,
		"source_role_id": "gunner",
		"source_position": center
	})


func _spawn_shrapnel_visual_if_room(field_data: Dictionary) -> void:
	var root: Node2D = field_data.get("root", null) as Node2D
	if root == null or not is_instance_valid(root):
		return
	var visuals: Array = field_data.get("visuals", [])
	var live_visuals: Array = []
	for visual in visuals:
		if visual != null and is_instance_valid(visual) and bool(visual.get_meta("shrapnel_active", false)) and visual.get_parent() == root:
			live_visuals.append(visual)
	if live_visuals.size() >= MAX_ACTIVE_VISUALS:
		field_data["visuals"] = live_visuals
		return
	var visual: Node2D = _create_shrapnel_visual(root, float(field_data.get("radius", BASE_RADIUS)))
	if visual != null:
		live_visuals.append(visual)
	field_data["visuals"] = live_visuals


func _create_shrapnel_visual(root: Node2D, radius: float) -> Node2D:
	var visual: Node2D = _acquire_shrapnel_visual(root)
	if visual == null:
		visual = Node2D.new()
	visual.name = "ShrapnelVisual"
	visual.z_index = 11
	visual.visible = true
	visual.modulate = Color.WHITE
	visual.set_meta("shrapnel_active", true)
	visual.set_meta("shrapnel_released", false)
	var sprite: AnimatedSprite2D = visual.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		sprite = AnimatedSprite2D.new()
		sprite.name = "AnimatedSprite2D"
		visual.add_child(sprite)
	if sprite.sprite_frames == null:
		sprite.sprite_frames = _get_centered_shrapnel_frames()
	sprite.animation = StringName("shrapnel")
	sprite.centered = true
	sprite.position = Vector2.ZERO
	sprite.offset = Vector2.ZERO
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ONE * randf_range(0.38, 0.48)
	sprite.rotation = 0.0
	_place_visual_randomly(visual, radius)
	sprite.frame = 0
	sprite.frame_progress = 0.0
	_disconnect_shrapnel_finish_callbacks(sprite)
	sprite.play("shrapnel")
	sprite.animation_finished.connect(_release_shrapnel_visual.bind(visual), CONNECT_ONE_SHOT)
	return visual


func _acquire_shrapnel_visual(root: Node2D) -> Node2D:
	while not shrapnel_visual_pool.is_empty():
		var pooled_visual: Variant = shrapnel_visual_pool.pop_back()
		if not is_instance_valid(pooled_visual) or not (pooled_visual is Node2D):
			continue
		var visual := pooled_visual as Node2D
		if visual.is_queued_for_deletion():
			continue
		var parent := visual.get_parent()
		if parent != root:
			if parent != null:
				parent.remove_child(visual)
			root.add_child(visual)
		return visual
	var visual: Node2D = null
	if SHRAPNEL_SCENE != null:
		visual = SHRAPNEL_SCENE.instantiate() as Node2D
	if visual == null:
		visual = Node2D.new()
	root.add_child(visual)
	return visual


func _release_shrapnel_visual(visual: Node2D) -> void:
	if visual == null or not is_instance_valid(visual):
		return
	if bool(visual.get_meta("shrapnel_released", false)):
		return
	if not bool(visual.get_meta("shrapnel_active", false)) and visual.get_parent() == null:
		return
	visual.set_meta("shrapnel_released", true)
	visual.set_meta("shrapnel_active", false)
	visual.hide()
	var sprite: AnimatedSprite2D = visual.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.stop()
		_disconnect_shrapnel_finish_callbacks(sprite)
	var parent := visual.get_parent()
	if parent != null:
		parent.remove_child(visual)
	if shrapnel_visual_pool.size() < SHRAPNEL_VISUAL_POOL_LIMIT:
		shrapnel_visual_pool.append(visual)
	else:
		visual.queue_free()


func _disconnect_shrapnel_finish_callbacks(sprite: AnimatedSprite2D) -> void:
	for connection in sprite.animation_finished.get_connections():
		var callback: Callable = connection.get("callable", Callable())
		if callback.get_object() == self and String(callback.get_method()) == "_release_shrapnel_visual":
			sprite.animation_finished.disconnect(callback)


func _get_centered_shrapnel_frames() -> SpriteFrames:
	if cached_shrapnel_frames != null:
		return cached_shrapnel_frames
	cached_shrapnel_frames = _build_centered_shrapnel_frames()
	return cached_shrapnel_frames


func _build_centered_shrapnel_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("shrapnel")
	frames.set_animation_loop("shrapnel", false)
	frames.set_animation_speed("shrapnel", 16.0)
	for texture in SHRAPNEL_TEXTURES:
		if texture != null:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = SHRAPNEL_ATLAS_REGION
			frames.add_frame("shrapnel", atlas)
	return frames


func _place_visual_randomly(visual: Node2D, radius: float) -> void:
	var angle: float = randf() * TAU
	var safe_radius: float = radius * 0.28
	var distance: float = sqrt(randf()) * safe_radius
	visual.position = Vector2.RIGHT.rotated(angle) * distance
	visual.rotation = 0.0
	visual.scale = Vector2.ONE


func _free_field(field_data: Dictionary) -> void:
	var visuals: Array = field_data.get("visuals", [])
	for visual in visuals:
		if visual != null and is_instance_valid(visual):
			_release_shrapnel_visual(visual)
	field_data["visuals"] = []
	var root: Node = field_data.get("root", null)
	if root != null and is_instance_valid(root):
		root.queue_free()


func _has_required_unlock(owner) -> bool:
	return owner != null and owner.has_method("_is_blessing_skill_unlocked") and bool(owner._is_blessing_skill_unlocked(SKILL_ID))


func _get_tier(owner) -> int:
	if owner != null and owner.has_method("_get_blessing_skill_tier"):
		return int(owner._get_blessing_skill_tier(SKILL_ID))
	return 1


func _get_trick_extra_field_count(owner) -> int:
	if owner == null or not owner.has_method("_get_blessing_skill_quantity_count"):
		return 0
	return max(0, int(owner._get_blessing_skill_quantity_count(SKILL_ID)))


func _get_cooldown(owner) -> float:
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_equipment_cooldown_multiplier"):
		return COOLDOWN * owner._get_equipment_cooldown_multiplier()
	return COOLDOWN


func _get_radius(owner) -> float:
	var range_multiplier: float = 1.0
	if owner != null and owner.has_method("_get_equipment_skill_range_multiplier"):
		range_multiplier *= float(owner._get_equipment_skill_range_multiplier())
	var tier: int = _get_tier(owner)
	var base_radius: float = BASE_RADIUS * RADIUS_MULTIPLIER
	if tier >= 3:
		base_radius = TIER_THREE_RADIUS
	elif tier >= 2:
		base_radius = TIER_TWO_RADIUS
	return base_radius * range_multiplier


func _get_tick_interval(owner) -> float:
	var tier: int = _get_tier(owner)
	if tier >= 3:
		return TIER_THREE_TICK_INTERVAL
	if tier >= 2:
		return TIER_TWO_TICK_INTERVAL
	return TIER_ONE_TICK_INTERVAL


func _get_slow_multiplier(owner) -> float:
	var tier: int = _get_tier(owner)
	if tier >= 3:
		return TIER_THREE_SLOW
	if tier >= 2:
		return TIER_TWO_SLOW
	return TIER_ONE_SLOW


func _get_damage(owner) -> float:
	var tier: int = _get_tier(owner)
	var ratio: float = TIER_ONE_DAMAGE_RATIO
	if tier >= 3:
		ratio = TIER_THREE_DAMAGE_RATIO
	elif tier >= 2:
		ratio = TIER_TWO_DAMAGE_RATIO
	return float(owner._get_role_damage("gunner")) * ratio


func _get_duration(owner) -> float:
	var duration: float = DURATION
	if owner != null and owner.has_method("_get_blessing_skill_duration_multiplier"):
		duration *= float(owner._get_blessing_skill_duration_multiplier(SKILL_ID))
	return duration

func _apply_damage_shapes(owner, shapes: Array[Dictionary]) -> int:
	if shapes.is_empty():
		return 0
	if owner != null and owner.has_method("_damage_enemies_in_shapes_batched"):
		return int(owner._damage_enemies_in_shapes_batched(shapes))
	var hits := 0
	for shape in shapes:
		hits += int(owner._damage_enemies_in_radius(
			shape.get("center", Vector2.ZERO),
			float(shape.get("radius", 1.0)),
			float(shape.get("damage_amount", 0.0)),
			float(shape.get("vulnerability_bonus", 0.0)),
			float(shape.get("slow_multiplier", 1.0)),
			float(shape.get("slow_duration", 0.0)),
			str(shape.get("source_role_id", ""))
		))
	return hits

func _uses_batched_damage(owner) -> bool:
	return owner != null and owner.has_method("_damage_enemies_in_shapes_batched")
