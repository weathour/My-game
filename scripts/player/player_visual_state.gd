extends RefCounted

const PLAYER_VISUAL_LAYOUT := preload("res://scripts/player/player_visual_layout.gd")
const SWORDSMAN_VISUAL_SCENE := preload("res://assets/players/sword/sword.tscn")
const SWORDSMAN_VISUAL_SCALE := Vector2(1.0, 1.0)
const SWORDSMAN_VISUAL_BASE_POSITION := Vector2(0.0, 0.0)
const GUNNER_VISUAL_SCENE := preload("res://assets/players/gun/gun.tscn")
const GUNNER_VISUAL_SCALE := Vector2(1.0, 1.0)
const GUNNER_VISUAL_BASE_POSITION := Vector2(0.0, 0.0)
const WIZARD_VISUAL_SCENE := preload("res://assets/players/wizard/wizard.tscn")
const WIZARD_VISUAL_SCALE := Vector2(1.7, 1.7)
const WIZARD_VISUAL_BASE_POSITION := Vector2(0.0, -20.0)


static func get_hidden_role_id(role_id: String, hidden: bool) -> String:
	return role_id if hidden else ""

static func is_role_visual_hidden(role_id: String, active_role_visual_hidden: bool, hidden_role_id: String) -> bool:
	return active_role_visual_hidden and role_id == hidden_role_id

static func apply_active_role_visual_hidden(owner: Node, role_id: String, active_role_visual_hidden: bool, hidden_role_id: String) -> void:
	var should_hide := is_role_visual_hidden(role_id, active_role_visual_hidden, hidden_role_id)
	var sprite := owner.get_node_or_null("RoleVisualRoot/RoleSprite") as Sprite2D
	if sprite != null:
		sprite.visible = not should_hide
	var scene_visual := owner.get_node_or_null("RoleVisualRoot/RoleSceneVisual") as Node2D
	if scene_visual != null:
		scene_visual.visible = not should_hide
	var polygon := owner.get_node_or_null("Polygon2D") as Polygon2D
	if polygon != null:
		polygon.visible = sprite == null and scene_visual == null and not should_hide


static func set_active_role_visual_hidden(owner, hidden: bool) -> void:
	owner.active_role_visual_hidden = hidden
	var role_id: String = str(owner._get_active_role().get("id", ""))
	owner.active_role_visual_hidden_role_id = get_hidden_role_id(role_id, hidden)
	apply_active_role_visual_hidden(owner, role_id, owner.active_role_visual_hidden, owner.active_role_visual_hidden_role_id)


static func configure_role_sprite(owner, sprite: Sprite2D, role_id: String) -> bool:
	var texture: Texture2D = owner._get_cached_runtime_texture(owner.ROLE_SKETCH_PATHS.get(role_id, ""))
	if texture == null:
		return false
	var visible_bounds: Rect2 = owner.ROLE_SKETCH_VISIBLE_BOUNDS.get(role_id, Rect2())
	if visible_bounds.size.y <= 0.0:
		return false
	sprite.texture = texture
	sprite.centered = true
	sprite.material = owner._create_white_key_material(0.93, 0.12, 0.04)
	sprite.offset = PLAYER_VISUAL_LAYOUT.get_role_sprite_offset(role_id, owner.ROLE_SKETCH_FULL_SIZES, owner.ROLE_SKETCH_VISIBLE_BOUNDS)
	var target_scale: float = PLAYER_VISUAL_LAYOUT.get_role_visual_scale(
		role_id,
		owner.ROLE_SKETCH_TARGET_HEIGHT,
		owner.ROLE_SKETCH_SCALE_MULTIPLIERS,
		owner.ROLE_SKETCH_VISIBLE_BOUNDS
	)
	sprite.scale = Vector2.ONE * target_scale
	sprite.modulate = Color.WHITE
	sprite.set_meta("base_scale", sprite.scale)
	sprite.set_meta("base_position", owner.ROLE_SKETCH_BASE_POSITIONS.get(role_id, Vector2(0.0, -4.0)))
	sprite.position = sprite.get_meta("base_position")
	return true

static func pulse_player_visual(owner: Node, peak_scale: float, duration: float) -> void:
	var sprite := owner.get_node_or_null("RoleVisualRoot/RoleSprite") as Sprite2D
	var base_scale := Vector2.ONE
	var target_node: Node2D = null
	if sprite != null:
		target_node = sprite
		var base_scale_value: Variant = sprite.get_meta("base_scale", sprite.scale)
		if base_scale_value is Vector2:
			base_scale = base_scale_value
	else:
		var scene_visual := owner.get_node_or_null("RoleVisualRoot/RoleSceneVisual") as Node2D
		if scene_visual != null:
			target_node = scene_visual
			var scene_base_scale_value: Variant = scene_visual.get_meta("base_scale", scene_visual.scale)
			if scene_base_scale_value is Vector2:
				base_scale = scene_base_scale_value
	if target_node == null:
		var polygon := owner.get_node_or_null("Polygon2D") as Polygon2D
		if polygon == null:
			return
		target_node = polygon
	target_node.scale = base_scale
	var tween := owner.create_tween()
	tween.tween_property(target_node, "scale", base_scale * peak_scale, duration * 0.35)
	tween.tween_property(target_node, "scale", base_scale, duration * 0.65)

static func update_role_idle_visual(owner: Node, role_id: String, facing_direction: Vector2, role_visual_time: float) -> void:
	var visual_root := owner.get_node_or_null("RoleVisualRoot") as Node2D
	if visual_root == null:
		return
	var scene_visual := visual_root.get_node_or_null("RoleSceneVisual") as Node2D
	if scene_visual != null:
		_update_role_scene_visual(owner, scene_visual, role_id, _get_visual_facing_direction(owner, facing_direction), role_visual_time)
		return
	var sprite := visual_root.get_node_or_null("RoleSprite") as Sprite2D
	if sprite == null:
		return

	var base_position := Vector2(0.0, -4.0)
	var base_position_value: Variant = sprite.get_meta("base_position", base_position)
	if base_position_value is Vector2:
		base_position = base_position_value
	var bob_strength := 1.4
	var tilt := 0.0
	match role_id:
		"swordsman":
			bob_strength = 1.6
			tilt = 0.03 * sign(facing_direction.x)
		"gunner":
			bob_strength = 1.1
			tilt = 0.018 * sign(facing_direction.x)
		"mage":
			bob_strength = 2.0
			tilt = 0.012 * sin(role_visual_time * 2.8)

	sprite.position = base_position + Vector2(0.0, sin(role_visual_time * 4.4) * bob_strength)
	sprite.rotation = tilt
	if role_id in ["swordsman", "gunner", "mage"]:
		sprite.flip_h = _get_visual_facing_direction(owner, facing_direction).x < 0.0

static func _update_role_scene_visual(owner: Node, scene_visual: Node2D, role_id: String, facing_direction: Vector2, role_visual_time: float) -> void:
	var base_position := WIZARD_VISUAL_BASE_POSITION
	var base_position_value: Variant = scene_visual.get_meta("base_position", base_position)
	if base_position_value is Vector2:
		base_position = base_position_value
	var bob_strength := 2.0 if role_id == "mage" else 1.4
	scene_visual.position = base_position + Vector2(0.0, sin(role_visual_time * 4.4) * bob_strength)
	scene_visual.rotation = 0.012 * sin(role_visual_time * 2.8) if role_id == "mage" else 0.0
	var animated_sprite := scene_visual.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite != null:
		animated_sprite.flip_h = facing_direction.x < 0.0
		if animated_sprite.sprite_frames != null and not animated_sprite.is_playing():
			animated_sprite.play()
	if scene_visual.has_method("set_moving"):
		var move_direction: Vector2 = owner.velocity
		scene_visual.set_moving(move_direction.length_squared() > 1.0, facing_direction)

static func _get_visual_facing_direction(owner: Node, fallback_direction: Vector2) -> Vector2:
	var visual_x: float = 1.0
	if owner != null:
		visual_x = float(owner.get("visual_facing_direction_x"))
	if abs(visual_x) > 0.01:
		return Vector2(sign(visual_x), 0.0)
	if abs(fallback_direction.x) > 0.01:
		return Vector2(sign(fallback_direction.x), 0.0)
	return Vector2.RIGHT

static func update_visuals(owner: Node, role_data: Dictionary, active_role_visual_hidden: bool, hidden_role_id: String) -> void:
	var polygon := owner.get_node_or_null("Polygon2D") as Polygon2D
	if polygon != null:
		polygon.visible = false

	for child in owner.get_children():
		if child is Node and str(child.name).begins_with("RoleVisualRoot"):
			owner.remove_child(child)
			child.free()

	var visual_root := Node2D.new()
	visual_root.name = "RoleVisualRoot"
	owner.add_child(visual_root)
	var role_id := str(role_data["id"])
	if role_id == "swordsman":
		var scene_visual := _create_swordsman_scene_visual()
		if scene_visual != null:
			visual_root.add_child(scene_visual)
			var should_hide_scene := is_role_visual_hidden(role_id, active_role_visual_hidden, hidden_role_id)
			scene_visual.visible = not should_hide_scene
			if polygon != null and not should_hide_scene:
				polygon.visible = false
			return
	if role_id == "gunner":
		var scene_visual := _create_gunner_scene_visual()
		if scene_visual != null:
			visual_root.add_child(scene_visual)
			var should_hide_scene := is_role_visual_hidden(role_id, active_role_visual_hidden, hidden_role_id)
			scene_visual.visible = not should_hide_scene
			if polygon != null and not should_hide_scene:
				polygon.visible = false
			return
	if role_id == "mage":
		var scene_visual := _create_mage_scene_visual()
		if scene_visual != null:
			visual_root.add_child(scene_visual)
			var should_hide_scene := is_role_visual_hidden(role_id, active_role_visual_hidden, hidden_role_id)
			scene_visual.visible = not should_hide_scene
			if polygon != null and not should_hide_scene:
				polygon.visible = false
			return
	var sprite := Sprite2D.new()
	sprite.name = "RoleSprite"
	if not configure_role_sprite(owner, sprite, role_id):
		if polygon != null:
			polygon.visible = true
			polygon.color = role_data["color"]
			if is_role_visual_hidden(role_id, active_role_visual_hidden, hidden_role_id):
				polygon.visible = false
		sprite.queue_free()
		return
	visual_root.add_child(sprite)
	var should_hide := is_role_visual_hidden(role_id, active_role_visual_hidden, hidden_role_id)
	if sprite != null:
		sprite.visible = not should_hide
	if polygon != null and not should_hide:
		polygon.visible = false

static func _create_swordsman_scene_visual() -> Node2D:
	var scene_visual := SWORDSMAN_VISUAL_SCENE.instantiate() as Node2D
	if scene_visual == null:
		return null
	scene_visual.name = "RoleSceneVisual"
	scene_visual.position = SWORDSMAN_VISUAL_BASE_POSITION
	scene_visual.scale = SWORDSMAN_VISUAL_SCALE
	scene_visual.set_meta("base_position", SWORDSMAN_VISUAL_BASE_POSITION)
	scene_visual.set_meta("base_scale", SWORDSMAN_VISUAL_SCALE)
	if scene_visual.has_method("set_moving"):
		scene_visual.set_moving(false)
	return scene_visual

static func _create_gunner_scene_visual() -> Node2D:
	var scene_visual := GUNNER_VISUAL_SCENE.instantiate() as Node2D
	if scene_visual == null:
		return null
	scene_visual.name = "RoleSceneVisual"
	scene_visual.position = GUNNER_VISUAL_BASE_POSITION
	scene_visual.scale = GUNNER_VISUAL_SCALE
	scene_visual.set_meta("base_position", GUNNER_VISUAL_BASE_POSITION)
	scene_visual.set_meta("base_scale", GUNNER_VISUAL_SCALE)
	if scene_visual.has_method("set_moving"):
		scene_visual.set_moving(false)
	return scene_visual

static func _create_mage_scene_visual() -> Node2D:
	var scene_visual := WIZARD_VISUAL_SCENE.instantiate() as Node2D
	if scene_visual == null:
		return null
	scene_visual.name = "RoleSceneVisual"
	scene_visual.position = WIZARD_VISUAL_BASE_POSITION
	scene_visual.scale = WIZARD_VISUAL_SCALE
	scene_visual.set_meta("base_position", WIZARD_VISUAL_BASE_POSITION)
	scene_visual.set_meta("base_scale", WIZARD_VISUAL_SCALE)
	var animated_sprite := scene_visual.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite != null:
		animated_sprite.centered = true
		if animated_sprite.sprite_frames != null:
			animated_sprite.play()
	return scene_visual


static func update_active_role_state(owner) -> void:
	var role_data: Dictionary = owner._get_active_role()
	if owner.has_method("_sync_active_role_max_health"):
		owner._sync_active_role_max_health(true, false)
	owner._sync_active_role_ultimate_state()
	update_visuals(owner, role_data, owner.active_role_visual_hidden, owner.active_role_visual_hidden_role_id)
	owner._update_hurt_core_visual(role_data)
	owner._update_player_health_bar(role_data)
	update_fire_timer(owner)
	owner.stats_changed.emit(owner.get_stat_summary())
	owner._emit_active_mana_changed()
	owner.active_role_changed.emit(role_data["id"], role_data["name"])


static func update_fire_timer(owner) -> void:
	if owner.fire_timer == null:
		return

	var role_data: Dictionary = owner._get_active_role()
	owner.fire_timer.wait_time = owner._get_effective_attack_interval(str(role_data["id"]))
	owner.fire_timer.start()
