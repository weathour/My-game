extends RefCounted

const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")
const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")

const ELITE_DASH_TRAIL_DAMAGE := 12.0
const ELITE_DASH_TRAIL_DURATION := 3.4
const ELITE_DASH_TRAIL_TICK := 0.45
const ENEMY_GEOMETRY := preload("res://scripts/enemies/enemy_geometry.gd")
const STATUS_VISUAL_BUDGET_PER_FRAME := 18
const LOW_FPS_STATUS_VISUAL_BUDGET_PER_FRAME := 8
const CRITICAL_FPS_STATUS_VISUAL_BUDGET_PER_FRAME := 3
const STATUS_BURST_BUDGET_PER_FRAME := 12
const LOW_FPS_STATUS_BURST_BUDGET_PER_FRAME := 5
const CRITICAL_FPS_STATUS_BURST_BUDGET_PER_FRAME := 2
const STATUS_BURST_POOL_LIMIT := 32
const DASH_TRAIL_POOL_LIMIT := 24

static var status_visual_budget_frame: int = -1
static var status_visual_budget_used: int = 0
static var status_burst_budget_frame: int = -1
static var status_burst_budget_used: int = 0
static var status_burst_enemy_ids_this_frame: Dictionary = {}
static var status_burst_pool: Array[Line2D] = []
static var dash_trail_pool: Array[Line2D] = []
static var active_status_bursts: Array[Dictionary] = []
static var active_dash_trails: Array[Dictionary] = []
static var active_dash_trail_hazards: Array[Dictionary] = []
static var temporary_animation_frame: int = -1

static func update_temporary_animations(delta: float) -> void:
	if delta <= 0.0:
		return
	var current_frame := Engine.get_process_frames()
	if temporary_animation_frame == current_frame:
		return
	temporary_animation_frame = current_frame
	_update_active_status_bursts(delta)
	_update_active_dash_trails(delta)
	_update_active_dash_trail_hazards(delta)

static func ensure_status_visuals(enemy) -> void:
	if enemy.status_root != null:
		return
	if not _consume_status_visual_budget(enemy):
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
		if enemy.status_root == null:
			return
	elif enemy.has_method("_has_status_visual_pressure") and not bool(enemy._has_status_visual_pressure()):
		_clear_status_visuals(enemy)
		return
	var hit_flash_alpha: float = enemy._get_hit_flash_alpha()
	var polygon := enemy.get_node_or_null("Polygon2D") as Polygon2D
	if polygon != null:
		var target_modulate := Color.WHITE
		if enemy.slow_timer > 0.0:
			target_modulate = target_modulate.lerp(Color(0.68, 0.9, 1.0, 1.0), 0.45)
		if enemy.vulnerability_timer > 0.0:
			target_modulate = target_modulate.lerp(Color(1.0, 0.76, 0.76, 1.0), 0.4)
		if enemy._is_accelerator and enemy.acceleration_remaining > 0.0:
			target_modulate = target_modulate.lerp(Color(1.0, 0.88, 0.64, 1.0), 0.32)
		if enemy._is_dasher and enemy.dash_windup_remaining > 0.0:
			target_modulate = target_modulate.lerp(Color(1.0, 0.92, 0.56, 1.0), 0.46)
		if enemy._is_dasher and enemy.dash_remaining > 0.0:
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
		enemy.dash_warning_ring.visible = enemy._is_dasher and enemy.dash_windup_remaining > 0.0
		if enemy.dash_warning_ring.visible:
			var windup_ratio: float = clamp(enemy.dash_windup_remaining / max(enemy.dash_windup_duration, 0.001), 0.0, 1.0)
			enemy.dash_warning_ring.rotation = -enemy.status_visual_time * 2.4
			enemy.dash_warning_ring.scale = Vector2.ONE * lerpf(0.72, 1.5, windup_ratio)
			enemy.dash_warning_ring.width = lerpf(5.0, 2.0, windup_ratio)
			enemy.dash_warning_ring.default_color = Color(1.0, 0.9, 0.28, lerpf(0.9, 0.3, windup_ratio))
	if enemy.dash_warning_rect != null:
		enemy.dash_warning_rect.visible = enemy._is_dasher and enemy.dash_windup_remaining > 0.0
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
	var current_scene: Node = _get_enemy_current_scene(enemy)
	if current_scene == null:
		return
	if not _consume_status_burst_budget(enemy):
		return
	if not _can_spawn_temporary_effect(current_scene):
		return

	var ring := _acquire_status_burst(current_scene)
	ring.global_position = enemy.global_position
	ring.width = 5.0
	ring.default_color = color
	ring.closed = true
	ring.points = ENEMY_GEOMETRY.build_circle_points(radius)
	ring.z_index = 16
	ring.scale = Vector2.ONE
	ring.modulate = Color.WHITE

	active_status_bursts.append({
		"node": ring,
		"elapsed": 0.0,
		"duration": 0.18,
		"start_scale": Vector2.ONE,
		"target_scale": Vector2(1.35, 1.35)
	})

static func spawn_dash_trail(enemy, direction_vector: Vector2, length: float) -> void:
	var current_scene: Node = _get_enemy_current_scene(enemy)
	if current_scene == null:
		return
	if not _can_spawn_temporary_effect(current_scene):
		if enemy.enemy_kind == "elite" and enemy.archetype_id == "elite_ram_trail":
			spawn_dash_trail_hazard(enemy, direction_vector, length)
		return

	var trail := _acquire_dash_trail(current_scene)
	trail.width = 8.0
	trail.default_color = Color(1.0, 0.46, 0.46, 0.28 if enemy.enemy_kind != "boss" else 0.38)
	trail.points = PackedVector2Array([
		enemy.global_position - direction_vector * length * 0.2,
		enemy.global_position + direction_vector * length
	])
	trail.z_index = 13
	trail.scale = Vector2.ONE
	trail.modulate = Color.WHITE

	active_dash_trails.append({
		"node": trail,
		"elapsed": 0.0,
		"duration": 0.16,
		"start_width": trail.width,
		"target_width": 2.0
	})
	if enemy.enemy_kind == "elite" and enemy.archetype_id == "elite_ram_trail":
		spawn_dash_trail_hazard(enemy, direction_vector, length)

static func _update_active_status_bursts(delta: float) -> void:
	for index in range(active_status_bursts.size() - 1, -1, -1):
		var data: Dictionary = active_status_bursts[index]
		var ring_value: Variant = data.get("node", null)
		if ring_value == null or not is_instance_valid(ring_value) or not (ring_value is Line2D):
			active_status_bursts.remove_at(index)
			continue
		var ring: Line2D = ring_value as Line2D
		var elapsed: float = float(data.get("elapsed", 0.0)) + delta
		var duration: float = max(0.001, float(data.get("duration", 0.18)))
		var progress: float = clamp(elapsed / duration, 0.0, 1.0)
		ring.scale = (data.get("start_scale", Vector2.ONE) as Vector2).lerp(data.get("target_scale", Vector2.ONE) as Vector2, progress)
		ring.modulate.a = 1.0 - progress
		if elapsed >= duration:
			active_status_bursts.remove_at(index)
			_release_status_burst(ring)
			continue
		data["elapsed"] = elapsed
		active_status_bursts[index] = data

static func _update_active_dash_trails(delta: float) -> void:
	for index in range(active_dash_trails.size() - 1, -1, -1):
		var data: Dictionary = active_dash_trails[index]
		var trail_value: Variant = data.get("node", null)
		if trail_value == null or not is_instance_valid(trail_value) or not (trail_value is Line2D):
			active_dash_trails.remove_at(index)
			continue
		var trail: Line2D = trail_value as Line2D
		var elapsed: float = float(data.get("elapsed", 0.0)) + delta
		var duration: float = max(0.001, float(data.get("duration", 0.16)))
		var progress: float = clamp(elapsed / duration, 0.0, 1.0)
		trail.modulate.a = 1.0 - progress
		trail.width = lerpf(float(data.get("start_width", trail.width)), float(data.get("target_width", 2.0)), progress)
		if elapsed >= duration:
			active_dash_trails.remove_at(index)
			_release_dash_trail(trail)
			continue
		data["elapsed"] = elapsed
		active_dash_trails[index] = data

static func _acquire_status_burst(current_scene: Node) -> Line2D:
	while not status_burst_pool.is_empty():
		var pooled_burst = status_burst_pool.pop_back()
		if not is_instance_valid(pooled_burst) or not (pooled_burst is Line2D):
			continue
		var ring := pooled_burst as Line2D
		if ring != null and not ring.is_queued_for_deletion():
			_prepare_pooled_line(ring, current_scene)
			return ring
	var ring := Line2D.new()
	current_scene.add_child(ring)
	ring.add_to_group("temporary_effects")
	return ring

static func _release_status_burst(ring: Line2D) -> void:
	if ring == null or not is_instance_valid(ring):
		return
	ring.hide()
	ring.remove_from_group("temporary_effects")
	if status_burst_pool.size() < STATUS_BURST_POOL_LIMIT and not status_burst_pool.has(ring):
		status_burst_pool.append(ring)
	else:
		ring.queue_free()

static func _acquire_dash_trail(current_scene: Node) -> Line2D:
	while not dash_trail_pool.is_empty():
		var pooled_trail = dash_trail_pool.pop_back()
		if not is_instance_valid(pooled_trail) or not (pooled_trail is Line2D):
			continue
		var trail := pooled_trail as Line2D
		if trail != null and not trail.is_queued_for_deletion():
			_prepare_pooled_line(trail, current_scene)
			return trail
	var trail := Line2D.new()
	current_scene.add_child(trail)
	trail.add_to_group("temporary_effects")
	return trail

static func _release_dash_trail(trail: Line2D) -> void:
	if trail == null or not is_instance_valid(trail):
		return
	trail.hide()
	trail.remove_from_group("temporary_effects")
	if dash_trail_pool.size() < DASH_TRAIL_POOL_LIMIT and not dash_trail_pool.has(trail):
		dash_trail_pool.append(trail)
	else:
		trail.queue_free()

static func _prepare_pooled_line(line: Line2D, current_scene: Node) -> void:
	var parent := line.get_parent()
	if parent != current_scene:
		if parent != null:
			parent.remove_child(line)
		current_scene.add_child(line)
	line.show()
	line.add_to_group("temporary_effects")

static func _can_spawn_temporary_effect(root: Node) -> bool:
	if root != null and root.has_method("_can_spawn_runtime_group"):
		var limit: int = PERFORMANCE_GUARD.get_dynamic_limit(root, "temporary_effects", PERFORMANCE_GUARD.DEFAULT_TEMPORARY_EFFECT_LIMIT)
		return bool(root._can_spawn_runtime_group("temporary_effects", limit))
	return true

static func _consume_status_visual_budget(enemy) -> bool:
	if enemy == null:
		return false
	if str(enemy.get("enemy_kind")) != "normal" or str(enemy.get("secondary_behavior_id")) != "":
		return true
	var current_frame := Engine.get_physics_frames()
	if status_visual_budget_frame != current_frame:
		status_visual_budget_frame = current_frame
		status_visual_budget_used = 0
	var budget := _get_status_visual_budget_per_frame()
	if status_visual_budget_used >= budget:
		PERFORMANCE_COUNTERS.add("suppressed_status_visuals", 1)
		return false
	status_visual_budget_used += 1
	return true

static func _get_status_visual_budget_per_frame() -> int:
	var fps := Engine.get_frames_per_second()
	if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return CRITICAL_FPS_STATUS_VISUAL_BUDGET_PER_FRAME
	if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return LOW_FPS_STATUS_VISUAL_BUDGET_PER_FRAME
	return STATUS_VISUAL_BUDGET_PER_FRAME

static func _consume_status_burst_budget(enemy) -> bool:
	if enemy == null:
		return false
	var current_frame := Engine.get_physics_frames()
	if status_burst_budget_frame != current_frame:
		status_burst_budget_frame = current_frame
		status_burst_budget_used = 0
		status_burst_enemy_ids_this_frame.clear()
	var enemy_id: int = enemy.get_instance_id()
	if status_burst_enemy_ids_this_frame.has(enemy_id):
		PERFORMANCE_COUNTERS.add("suppressed_status_bursts", 1)
		return false
	status_burst_enemy_ids_this_frame[enemy_id] = true
	if str(enemy.get("enemy_kind")) != "normal" or str(enemy.get("secondary_behavior_id")) != "":
		return true
	var budget := _get_status_burst_budget_per_frame()
	if status_burst_budget_used >= budget:
		PERFORMANCE_COUNTERS.add("suppressed_status_bursts", 1)
		return false
	status_burst_budget_used += 1
	return true

static func _get_status_burst_budget_per_frame() -> int:
	var fps := Engine.get_frames_per_second()
	if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return CRITICAL_FPS_STATUS_BURST_BUDGET_PER_FRAME
	if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return LOW_FPS_STATUS_BURST_BUDGET_PER_FRAME
	return STATUS_BURST_BUDGET_PER_FRAME

static func _clear_status_visuals(enemy) -> void:
	if enemy.status_root != null and is_instance_valid(enemy.status_root):
		enemy.status_root.queue_free()
	enemy.status_root = null
	enemy.slow_ring = null
	enemy.vulnerability_ring = null
	enemy.trait_ring = null
	enemy.dash_warning_ring = null
	enemy.dash_warning_rect = null

static func spawn_dash_trail_hazard(enemy, direction_vector: Vector2, length: float) -> void:
	var current_scene: Node = _get_enemy_current_scene(enemy)
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

	active_dash_trail_hazards.append({
		"root": root,
		"bodies": bodies,
		"elapsed": 0.0,
		"duration": ELITE_DASH_TRAIL_DURATION,
		"tick_elapsed": 0.0
	})

static func _update_active_dash_trail_hazards(delta: float) -> void:
	for index in range(active_dash_trail_hazards.size() - 1, -1, -1):
		var data: Dictionary = active_dash_trail_hazards[index]
		var root_node: Variant = data.get("root", null)
		if root_node == null or not is_instance_valid(root_node) or not (root_node is Node):
			active_dash_trail_hazards.remove_at(index)
			continue
		var elapsed: float = float(data.get("elapsed", 0.0)) + delta
		var duration: float = max(0.001, float(data.get("duration", ELITE_DASH_TRAIL_DURATION)))
		var tick_elapsed: float = float(data.get("tick_elapsed", 0.0)) + delta
		if tick_elapsed >= ELITE_DASH_TRAIL_TICK:
			tick_elapsed = fmod(tick_elapsed, ELITE_DASH_TRAIL_TICK)
			var bodies: Array = data.get("bodies", [])
			for body in bodies:
				if is_instance_valid(body) and body.has_method("take_damage"):
					body.take_damage(ELITE_DASH_TRAIL_DAMAGE)
		if elapsed >= duration:
			active_dash_trail_hazards.remove_at(index)
			(root_node as Node).queue_free()
			continue
		data["elapsed"] = elapsed
		data["tick_elapsed"] = tick_elapsed
		active_dash_trail_hazards[index] = data

static func _get_enemy_current_scene(enemy) -> Node:
	if enemy == null or not is_instance_valid(enemy):
		return null
	if enemy is Node and not (enemy as Node).is_inside_tree():
		return null
	var tree: SceneTree = enemy.get_tree()
	if tree == null:
		return null
	return tree.current_scene
