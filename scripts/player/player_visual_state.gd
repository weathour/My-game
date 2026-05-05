extends RefCounted

const PLAYER_VISUAL_LAYOUT := preload("res://scripts/player/player_visual_layout.gd")


static func get_hidden_role_id(role_id: String, hidden: bool) -> String:
	return role_id if hidden else ""

static func is_role_visual_hidden(role_id: String, active_role_visual_hidden: bool, hidden_role_id: String) -> bool:
	return active_role_visual_hidden and role_id == hidden_role_id

static func apply_active_role_visual_hidden(owner: Node, role_id: String, active_role_visual_hidden: bool, hidden_role_id: String) -> void:
	var should_hide := is_role_visual_hidden(role_id, active_role_visual_hidden, hidden_role_id)
	var sprite := owner.get_node_or_null("RoleVisualRoot/RoleSprite") as Sprite2D
	if sprite != null:
		sprite.visible = not should_hide
	var polygon := owner.get_node_or_null("Polygon2D") as Polygon2D
	if polygon != null:
		polygon.visible = sprite == null and not should_hide


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
		sprite.flip_h = facing_direction.x < 0.0


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
	var sprite := Sprite2D.new()
	sprite.name = "RoleSprite"
	if not configure_role_sprite(owner, sprite, str(role_data["id"])):
		if polygon != null:
			polygon.visible = true
			polygon.color = role_data["color"]
			if is_role_visual_hidden(str(role_data["id"]), active_role_visual_hidden, hidden_role_id):
				polygon.visible = false
		sprite.queue_free()
		return
	visual_root.add_child(sprite)
	var should_hide := is_role_visual_hidden(str(role_data["id"]), active_role_visual_hidden, hidden_role_id)
	if sprite != null:
		sprite.visible = not should_hide
	if polygon != null and not should_hide:
		polygon.visible = false


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
