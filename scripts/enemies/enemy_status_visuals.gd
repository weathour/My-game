extends RefCounted

const ELITE_DASH_TRAIL_DAMAGE := 12.0
const ELITE_DASH_TRAIL_DURATION := 3.4
const ELITE_DASH_TRAIL_TICK := 0.45
const ENEMY_GEOMETRY := preload("res://scripts/enemies/enemy_geometry.gd")

static func ensure_status_visuals(enemy) -> void:
	if enemy.status_root != null:
		return

	enemy.status_root = Node2D.new()
	enemy.status_root.name = "StatusRoot"
	enemy.add_child(enemy.status_root)

	enemy.slow_ring = Line2D.new()
	enemy.slow_ring.width = 4.0
	enemy.slow_ring.default_color = Color(0.56, 0.92, 1.0, 0.0)
	enemy.slow_ring.closed = true
	enemy.slow_ring.points = ENEMY_GEOMETRY.build_circle_points(24.0)
	enemy.status_root.add_child(enemy.slow_ring)

	enemy.vulnerability_ring = Line2D.new()
	enemy.vulnerability_ring.width = 3.0
	enemy.vulnerability_ring.default_color = Color(1.0, 0.48, 0.38, 0.0)
	enemy.vulnerability_ring.closed = true
	enemy.vulnerability_ring.points = ENEMY_GEOMETRY.build_circle_points(30.0)
	enemy.status_root.add_child(enemy.vulnerability_ring)

	enemy.trait_ring = Line2D.new()
	enemy.trait_ring.width = 3.0
	enemy.trait_ring.default_color = Color(1.0, 1.0, 1.0, 0.0)
	enemy.trait_ring.closed = true
	enemy.trait_ring.points = ENEMY_GEOMETRY.build_circle_points(20.0)
	enemy.status_root.add_child(enemy.trait_ring)

	enemy.dash_warning_ring = Line2D.new()
	enemy.dash_warning_ring.width = 4.0
	enemy.dash_warning_ring.default_color = Color(1.0, 0.88, 0.28, 0.0)
	enemy.dash_warning_ring.closed = true
	enemy.dash_warning_ring.points = ENEMY_GEOMETRY.build_circle_points(34.0)
	enemy.dash_warning_ring.visible = false
	enemy.status_root.add_child(enemy.dash_warning_ring)

	enemy.dash_warning_rect = Polygon2D.new()
	enemy.dash_warning_rect.color = Color(1.0, 0.12, 0.08, 0.22)
	enemy.dash_warning_rect.visible = false
	enemy.status_root.add_child(enemy.dash_warning_rect)

static func update_status_visuals(enemy) -> void:
	if enemy.status_root == null:
		if not enemy.has_method("_has_status_visual_pressure") or not bool(enemy._has_status_visual_pressure()):
			return
		ensure_status_visuals(enemy)
	var hit_flash_alpha: float = enemy._get_hit_flash_alpha()
	var polygon := enemy.get_node_or_null("Polygon2D") as Polygon2D
	if polygon != null:
		var target_modulate := Color.WHITE
		if enemy.slow_timer > 0.0:
			target_modulate = target_modulate.lerp(Color(0.68, 0.9, 1.0, 1.0), 0.45)
		if enemy.vulnerability_timer > 0.0:
			target_modulate = target_modulate.lerp(Color(1.0, 0.76, 0.76, 1.0), 0.4)
		if enemy.has_trait("accelerator") and enemy.acceleration_remaining > 0.0:
			target_modulate = target_modulate.lerp(Color(1.0, 0.88, 0.64, 1.0), 0.32)
		if enemy.has_trait("dash") and enemy.dash_windup_remaining > 0.0:
			target_modulate = target_modulate.lerp(Color(1.0, 0.92, 0.56, 1.0), 0.46)
		if enemy.has_trait("dash") and enemy.dash_remaining > 0.0:
			target_modulate = target_modulate.lerp(Color(1.0, 0.72, 0.72, 1.0), 0.32)
		polygon.modulate = polygon.modulate.lerp(target_modulate, 0.18)
		polygon.modulate.a = hit_flash_alpha

	if enemy.boss_visual_instance != null and is_instance_valid(enemy.boss_visual_instance):
		enemy._apply_hit_flash_alpha_to_node(enemy.boss_visual_instance, hit_flash_alpha)

	if enemy.slow_ring != null:
		enemy.slow_ring.visible = enemy.slow_timer > 0.0
		enemy.slow_ring.rotation = enemy.status_visual_time * 2.1
		enemy.slow_ring.scale = Vector2.ONE * (1.0 + 0.08 * sin(enemy.status_visual_time * 6.0))
		enemy.slow_ring.default_color = Color(0.56, 0.92, 1.0, 0.72 if enemy.slow_timer > 0.0 else 0.0)

	if enemy.vulnerability_ring != null:
		enemy.vulnerability_ring.visible = enemy.vulnerability_timer > 0.0
		enemy.vulnerability_ring.rotation = -enemy.status_visual_time * 1.6
		enemy.vulnerability_ring.scale = Vector2.ONE * (1.0 + 0.05 * cos(enemy.status_visual_time * 5.0))
		enemy.vulnerability_ring.default_color = Color(1.0, 0.46, 0.36, 0.68 if enemy.vulnerability_timer > 0.0 else 0.0)

	if enemy.trait_ring != null and enemy.trait_ring.visible:
		enemy.trait_ring.rotation = enemy.status_visual_time * 0.8 * (1.0 if enemy.enemy_kind == "boss" else -1.0)
		enemy.trait_ring.scale = Vector2.ONE * (1.0 + 0.05 * sin(enemy.status_visual_time * 4.0))

	if enemy.dash_warning_ring != null:
		enemy.dash_warning_ring.visible = enemy.has_trait("dash") and enemy.dash_windup_remaining > 0.0
		if enemy.dash_warning_ring.visible:
			var windup_ratio: float = clamp(enemy.dash_windup_remaining / max(enemy.dash_windup_duration, 0.001), 0.0, 1.0)
			enemy.dash_warning_ring.rotation = -enemy.status_visual_time * 2.4
			enemy.dash_warning_ring.scale = Vector2.ONE * lerpf(0.72, 1.5, windup_ratio)
			enemy.dash_warning_ring.width = lerpf(5.0, 2.0, windup_ratio)
			enemy.dash_warning_ring.default_color = Color(1.0, 0.9, 0.28, lerpf(0.9, 0.3, windup_ratio))
	if enemy.dash_warning_rect != null:
		enemy.dash_warning_rect.visible = enemy.has_trait("dash") and enemy.dash_windup_remaining > 0.0
		if enemy.dash_warning_rect.visible:
			var dash_length: float = max(56.0, enemy.speed * max(enemy.dash_duration, 0.2) * max(enemy.dash_speed_multiplier, 1.0))
			var dash_width: float = max(24.0, enemy.contact_radius * 0.9)
			enemy.dash_warning_rect.position = enemy.dash_direction * (dash_length * 0.52)
			enemy.dash_warning_rect.rotation = enemy.dash_direction.angle()
			enemy.dash_warning_rect.polygon = PackedVector2Array([
				Vector2(-dash_length * 0.5, -dash_width * 0.5),
				Vector2(dash_length * 0.5, -dash_width * 0.5),
				Vector2(dash_length * 0.5, dash_width * 0.5),
				Vector2(-dash_length * 0.5, dash_width * 0.5)
			])
			enemy.dash_warning_rect.color = Color(1.0, 0.14, 0.08, 0.16 + 0.18 * (1.0 - clamp(enemy.dash_windup_remaining / max(enemy.dash_windup_duration, 0.001), 0.0, 1.0)))

static func spawn_status_burst(enemy, color: Color, radius: float) -> void:
	var current_scene: Node = enemy.get_tree().current_scene
	if current_scene == null:
		return
	if not _can_spawn_temporary_effect(current_scene):
		return

	var ring := Line2D.new()
	ring.add_to_group("temporary_effects")
	ring.global_position = enemy.global_position
	ring.width = 5.0
	ring.default_color = color
	ring.closed = true
	ring.points = ENEMY_GEOMETRY.build_circle_points(radius)
	ring.z_index = 16
	current_scene.add_child(ring)

	var tween := ring.create_tween()
	tween.parallel().tween_property(ring, "scale", Vector2(1.35, 1.35), 0.18)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.18)
	tween.tween_callback(ring.queue_free)

static func spawn_dash_trail(enemy, direction_vector: Vector2, length: float) -> void:
	var current_scene: Node = enemy.get_tree().current_scene
	if current_scene == null:
		return
	if not _can_spawn_temporary_effect(current_scene):
		if enemy.enemy_kind == "elite" and enemy.archetype_id == "elite_ram_trail":
			spawn_dash_trail_hazard(enemy, direction_vector, length)
		return

	var trail := Line2D.new()
	trail.add_to_group("temporary_effects")
	trail.width = 8.0
	trail.default_color = Color(1.0, 0.46, 0.46, 0.28 if enemy.enemy_kind != "boss" else 0.38)
	trail.points = PackedVector2Array([
		enemy.global_position - direction_vector * length * 0.2,
		enemy.global_position + direction_vector * length
	])
	trail.z_index = 13
	current_scene.add_child(trail)

	var tween := trail.create_tween()
	tween.parallel().tween_property(trail, "modulate:a", 0.0, 0.16)
	tween.parallel().tween_property(trail, "width", 2.0, 0.16)
	tween.tween_callback(trail.queue_free)
	if enemy.enemy_kind == "elite" and enemy.archetype_id == "elite_ram_trail":
		spawn_dash_trail_hazard(enemy, direction_vector, length)

static func _can_spawn_temporary_effect(root: Node) -> bool:
	if root != null and root.has_method("_can_spawn_runtime_group"):
		return bool(root._can_spawn_runtime_group("temporary_effects", 160))
	return true

static func spawn_dash_trail_hazard(enemy, direction_vector: Vector2, length: float) -> void:
	var current_scene: Node = enemy.get_tree().current_scene
	if current_scene == null:
		return
	var root := Node2D.new()
	root.global_position = enemy.global_position + direction_vector * length * 0.42
	root.rotation = direction_vector.angle()
	root.z_index = 11
	current_scene.add_child(root)

	var fill := Polygon2D.new()
	var half_length: float = max(32.0, length * 0.6)
	var half_width: float = max(10.0, enemy.contact_radius * 0.3)
	fill.color = Color(0.92, 0.16, 0.1, 0.28)
	fill.polygon = PackedVector2Array([
		Vector2(-half_length, -half_width),
		Vector2(half_length, -half_width),
		Vector2(half_length, half_width),
		Vector2(-half_length, half_width)
	])
	root.add_child(fill)

	var outline := Line2D.new()
	outline.width = 3.0
	outline.default_color = Color(1.0, 0.38, 0.22, 0.82)
	outline.points = PackedVector2Array([
		Vector2(-half_length, -half_width),
		Vector2(half_length, -half_width),
		Vector2(half_length, half_width),
		Vector2(-half_length, half_width),
		Vector2(-half_length, -half_width)
	])
	root.add_child(outline)

	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	area.monitorable = true
	root.add_child(area)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(half_length * 2.0, half_width * 2.0)
	collision.shape = shape
	area.add_child(collision)

	var bodies: Array[Node] = []
	area.body_entered.connect(func(body: Node) -> void:
		if bodies.has(body):
			return
		bodies.append(body)
		if body.has_method("take_damage"):
			body.take_damage(ELITE_DASH_TRAIL_DAMAGE)
	)
	area.body_exited.connect(func(body: Node) -> void:
		bodies.erase(body)
	)

	var tick_timer := Timer.new()
	tick_timer.wait_time = ELITE_DASH_TRAIL_TICK
	tick_timer.one_shot = false
	tick_timer.autostart = true
	root.add_child(tick_timer)
	tick_timer.timeout.connect(func() -> void:
		for body in bodies:
			if is_instance_valid(body) and body.has_method("take_damage"):
				body.take_damage(ELITE_DASH_TRAIL_DAMAGE)
	)

	var timer := Timer.new()
	timer.wait_time = ELITE_DASH_TRAIL_DURATION
	timer.one_shot = true
	timer.autostart = true
	root.add_child(timer)
	timer.timeout.connect(root.queue_free)
