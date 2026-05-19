extends RefCounted

const BOSS_VISUAL_SCENE := preload("res://enemies/boss1/boss1.tscn")
const BOSS_PHASE_THREE_CHARGE_DURATION := 5.0
const ENEMY_GEOMETRY := preload("res://scripts/enemies/enemy_geometry.gd")

static func ensure_boss_helpers(enemy) -> void:
	if enemy.boss_helper_root != null:
		return

	enemy.boss_helper_root = Node2D.new()
	enemy.boss_helper_root.name = "BossHelpers"
	enemy.boss_helper_root.z_index = 15
	enemy.add_child(enemy.boss_helper_root)

	for index in range(8):
		var laser := Line2D.new()
		laser.width = 18.0
		laser.default_color = Color(1.0, 0.44, 0.16, 0.36)
		laser.visible = false
		enemy.boss_helper_root.add_child(laser)
		enemy.boss_laser_lines.append(laser)

		var laser_core := Line2D.new()
		laser_core.width = 7.0
		laser_core.default_color = Color(1.0, 0.92, 0.58, 0.94)
		laser_core.visible = false
		enemy.boss_helper_root.add_child(laser_core)
		enemy.boss_laser_core_lines.append(laser_core)

	for index in range(4):
		var charge_ring := Line2D.new()
		charge_ring.width = 4.0 + float(index)
		charge_ring.default_color = Color(0.12, 0.28, 0.88, 0.0)
		charge_ring.closed = true
		charge_ring.visible = false
		enemy.boss_helper_root.add_child(charge_ring)
		enemy.boss_phase_charge_rings.append(charge_ring)

static func ensure_boss_orbit_ball(enemy) -> void:
	ensure_boss_helpers(enemy)
	if enemy.boss_orbit_ball != null:
		return

	enemy.boss_orbit_ball = Node2D.new()
	enemy.boss_orbit_ball.name = "OrbitBomb"
	enemy.boss_helper_root.add_child(enemy.boss_orbit_ball)

	var glow := Polygon2D.new()
	glow.name = "Glow"
	glow.color = Color(1.0, 0.72, 0.28, 0.26)
	glow.polygon = PackedVector2Array([
		Vector2(0.0, -26.0),
		Vector2(26.0, 0.0),
		Vector2(0.0, 26.0),
		Vector2(-26.0, 0.0)
	])
	glow.scale = Vector2(1.55, 1.55)
	enemy.boss_orbit_ball.add_child(glow)

	var core := Polygon2D.new()
	core.name = "Core"
	core.color = Color(1.0, 0.86, 0.56, 0.98)
	core.polygon = PackedVector2Array([
		Vector2(0.0, -18.0),
		Vector2(18.0, 0.0),
		Vector2(0.0, 18.0),
		Vector2(-18.0, 0.0)
	])
	enemy.boss_orbit_ball.add_child(core)

	var ring := Line2D.new()
	ring.name = "Ring"
	ring.width = 4.0
	ring.default_color = Color(1.0, 0.96, 0.7, 0.9)
	ring.closed = true
	ring.points = ENEMY_GEOMETRY.build_circle_points(24.0)
	enemy.boss_orbit_ball.add_child(ring)

static func clear_boss_orbit_ball(enemy) -> void:
	if enemy.boss_orbit_ball != null:
		enemy.boss_orbit_ball.queue_free()
		enemy.boss_orbit_ball = null

static func ensure_boss_peacock_markers(enemy, count: int) -> void:
	ensure_boss_helpers(enemy)
	if enemy.boss_peacock_markers.size() == count:
		return
	clear_boss_peacock_markers(enemy)
	for index in range(count):
		var marker := Polygon2D.new()
		marker.color = Color(0.98, 0.84, 0.38, 0.72)
		marker.polygon = PackedVector2Array([
			Vector2(0.0, -10.0),
			Vector2(10.0, 0.0),
			Vector2(0.0, 10.0),
			Vector2(-10.0, 0.0)
		])
		enemy.boss_helper_root.add_child(marker)
		enemy.boss_peacock_markers.append(marker)

static func clear_boss_peacock_markers(enemy) -> void:
	for marker in enemy.boss_peacock_markers:
		if marker != null:
			marker.queue_free()
	enemy.boss_peacock_markers.clear()

static func update_boss_phase_three_charge_visuals(enemy) -> void:
	ensure_boss_helpers(enemy)
	var progress: float = 1.0 - clamp(enemy.boss_phase_three_intro_remaining / max(BOSS_PHASE_THREE_CHARGE_DURATION, 0.001), 0.0, 1.0)
	var base_radius: float = lerpf(150.0, 18.0, progress)
	for index in range(enemy.boss_phase_charge_rings.size()):
		var ring = enemy.boss_phase_charge_rings[index]
		if ring == null:
			continue
		ring.visible = true
		var ring_ratio: float = float(index) / float(max(1, enemy.boss_phase_charge_rings.size() - 1))
		var radius: float = max(14.0, base_radius + ring_ratio * 34.0 - progress * (24.0 + ring_ratio * 18.0))
		ring.points = ENEMY_GEOMETRY.build_circle_points(radius)
		ring.rotation = enemy.status_visual_time * (0.9 + ring_ratio * 0.45) * (1.0 if index % 2 == 0 else -1.0)
		ring.width = 3.0 + ring_ratio * 2.5
		ring.default_color = Color(0.08, 0.18 + ring_ratio * 0.12, 0.72 + ring_ratio * 0.18, 0.34 + progress * 0.46)

static func clear_boss_phase_three_charge_visuals(enemy) -> void:
	for ring in enemy.boss_phase_charge_rings:
		if ring != null:
			ring.visible = false

static func ensure_boss_visual(enemy) -> void:
	if enemy.enemy_kind != "boss":
		if enemy.boss_visual_instance != null:
			enemy.boss_visual_instance.queue_free()
			enemy.boss_visual_instance = null
		return
	if enemy.boss_visual_instance != null:
		if is_instance_valid(enemy.boss_visual_instance) and not enemy.boss_visual_instance.is_queued_for_deletion():
			if enemy.boss_visual_instance.get_parent() == enemy:
				enemy.boss_visual_instance.visible = true
				return
		enemy.boss_visual_instance = null
	if BOSS_VISUAL_SCENE == null:
		return
	var visual := BOSS_VISUAL_SCENE.instantiate()
	if visual == null:
		return
	enemy.boss_visual_instance = visual as Node2D
	if enemy.boss_visual_instance == null:
		visual.queue_free()
		return
	enemy.boss_visual_instance.name = "BossVisual"
	enemy.boss_visual_instance.z_index = 4
	enemy.add_child(enemy.boss_visual_instance)
