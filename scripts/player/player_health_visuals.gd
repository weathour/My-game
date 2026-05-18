extends RefCounted

const PLAYER_VISUAL_STATE := preload("res://scripts/player/player_visual_state.gd")

static func setup_hurt_core_visual(owner, hurt_core_radius: float, outline_width: float) -> void:
	var hurt_core := owner.get_node_or_null("HurtCore") as Node2D
	if hurt_core == null:
		return
	var fill := hurt_core.get_node_or_null("Fill") as Polygon2D
	if fill != null:
		fill.polygon = owner._build_circle_polygon(hurt_core_radius)
	var outline := hurt_core.get_node_or_null("Outline") as Line2D
	if outline != null:
		var ring_points: PackedVector2Array = owner._build_circle_polygon(hurt_core_radius + outline_width * 0.35)
		if ring_points.size() > 0:
			ring_points.append(ring_points[0])
		outline.points = ring_points
		outline.width = outline_width

static func update_hurt_core_visual(owner, role_data: Dictionary, hurt_core_offset: Vector2) -> void:
	var hurt_core := owner.get_node_or_null("HurtCore") as Node2D
	if hurt_core == null:
		return
	if role_data.is_empty():
		role_data = owner._get_active_role()
	var role_id: String = str(role_data.get("id", ""))
	var body_center_offset: Vector2 = PLAYER_VISUAL_STATE.get_role_body_center_offset(role_id)
	hurt_core.position = body_center_offset + hurt_core_offset
	hurt_core.z_index = 60
	var role_color: Color = role_data.get("color", Color(1.0, 0.5, 0.4, 1.0))
	var fill := hurt_core.get_node_or_null("Fill") as Polygon2D
	if fill != null:
		fill.color = Color(1.0, 1.0, 1.0, 0.94)
		fill.visible = true
	var outline := hurt_core.get_node_or_null("Outline") as Line2D
	if outline != null:
		outline.default_color = Color(role_color.r, role_color.g, role_color.b, 1.0)
		outline.visible = true


static func toggle_hurt_core_visual(owner) -> void:
	owner.hurt_core_visual_visible = not owner.hurt_core_visual_visible
	apply_hurt_core_visibility(owner)


static func apply_hurt_core_visibility(owner) -> void:
	var hurt_core := owner.get_node_or_null("HurtCore") as Node2D
	if hurt_core != null:
		hurt_core.visible = owner.hurt_core_visual_visible

static func setup_player_health_bar(owner) -> void:
	if owner.get_node_or_null("PlayerHealthBar") != null:
		return

	var bar_root := Node2D.new()
	bar_root.name = "PlayerHealthBar"
	bar_root.z_index = 70
	owner.add_child(bar_root)

	var background := Polygon2D.new()
	background.name = "Background"
	background.color = Color(0.0, 0.0, 0.0, 0.92)
	bar_root.add_child(background)

	var fill := Polygon2D.new()
	fill.name = "Fill"
	fill.color = Color(0.92, 0.08, 0.06, 1.0)
	bar_root.add_child(fill)

	var border := Line2D.new()
	border.name = "Border"
	border.default_color = Color(0.0, 0.0, 0.0, 1.0)
	border.width = 2.0
	border.closed = true
	bar_root.add_child(border)

	var level_label := Label.new()
	level_label.name = "LevelLabel"
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label.custom_minimum_size = Vector2(48.0, 18.0)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 11)
	level_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35, 1.0))
	level_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	level_label.add_theme_constant_override("shadow_offset_x", 1)
	level_label.add_theme_constant_override("shadow_offset_y", 1)
	bar_root.add_child(level_label)

	update_player_health_bar(owner, owner._get_active_role(), 5.0, 44.0)

static func update_player_health_bar(owner, role_data: Dictionary, bar_height: float, bar_y_offset: float) -> void:
	var bar_root := owner.get_node_or_null("PlayerHealthBar") as Node2D
	if bar_root == null:
		return
	if role_data.is_empty():
		role_data = owner._get_active_role()

	var role_id: String = str(role_data.get("id", ""))
	var body_center_offset: Vector2 = PLAYER_VISUAL_STATE.get_role_body_center_offset(role_id)
	var bar_width: float = owner._get_role_health_bar_width(role_id)
	var half_width: float = bar_width * 0.5
	var half_height: float = bar_height * 0.5
	var health_ratio: float = clamp(owner.current_health / max(owner.max_health, 1.0), 0.0, 1.0)
	bar_root.position = body_center_offset + Vector2(0.0, bar_y_offset)

	var background := bar_root.get_node_or_null("Background") as Polygon2D
	if background != null:
		background.polygon = PackedVector2Array([
			Vector2(-half_width, -half_height),
			Vector2(half_width, -half_height),
			Vector2(half_width, half_height),
			Vector2(-half_width, half_height)
		])

	var fill := bar_root.get_node_or_null("Fill") as Polygon2D
	if fill != null:
		var fill_width: float = max(0.0, bar_width * health_ratio)
		fill.polygon = PackedVector2Array([
			Vector2(-half_width, -half_height),
			Vector2(-half_width + fill_width, -half_height),
			Vector2(-half_width + fill_width, half_height),
			Vector2(-half_width, half_height)
		])

	var border := bar_root.get_node_or_null("Border") as Line2D
	if border != null:
		border.points = PackedVector2Array([
			Vector2(-half_width, -half_height),
			Vector2(half_width, -half_height),
			Vector2(half_width, half_height),
			Vector2(-half_width, half_height)
		])

	var level_label := bar_root.get_node_or_null("LevelLabel") as Label
	if level_label != null:
		level_label.text = "Lv.%d" % _get_owner_level(owner)
		level_label.position = Vector2(half_width + 7.0, -9.5)
		level_label.size = Vector2(48.0, 18.0)


static func _get_owner_level(owner) -> int:
	var level_value: Variant = owner.get("level")
	if level_value == null:
		return 1
	return max(1, int(level_value))


static func get_hurtbox_center(owner) -> Vector2:
	var hurt_core := owner.get_node_or_null("HurtCore") as Node2D
	if hurt_core != null:
		return hurt_core.global_position
	return owner.global_position
