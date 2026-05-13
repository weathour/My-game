extends RefCounted

const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")
const PLAYER_DAMAGE_JOB_QUEUE := preload("res://scripts/player/player_damage_job_queue.gd")
const PLAYER_DAMAGE_BATCHER := preload("res://scripts/player/player_damage_batcher.gd")
const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")
const ENEMY_SPATIAL_GRID := preload("res://scripts/enemies/enemy_spatial_grid.gd")

const DAMAGE_JOB_QUEUE_NAME := "PlayerDamageJobQueue"
const QUEUED_HIT_THRESHOLD := 16
const LOW_FPS_QUEUED_HIT_THRESHOLD := 8
const CRITICAL_FPS_QUEUED_HIT_THRESHOLD := 4
const DAMAGE_QUERY_BOUNDS_GROW := 48.0

static var cached_live_enemies: Array = []
static var cached_live_enemies_frame: int = -1
static var cached_live_enemies_source_key: int = -1
static var cached_enemy_grid: Dictionary = {}
static var cached_enemy_grid_frame: int = -1
static var cached_enemy_grid_source_key: int = -1
static var cached_enemy_grid_cell_size: float = 96.0
static var reusable_damage_batcher: RefCounted
static var reusable_candidates: Array = []
static var reusable_seen_enemy_ids: Dictionary = {}
static var reusable_bounds_list: Array[Rect2] = []

static func deal_damage_to_enemy(owner, enemy: Node, damage_amount: float, source_role_id: String, vulnerability_bonus: float = 0.0, vulnerability_duration: float = 2.0, slow_multiplier: float = 1.0, slow_duration: float = 0.0, source_position: Variant = null) -> bool:
	if owner != null and owner.has_method("_deal_damage_to_enemy"):
		return bool(owner._deal_damage_to_enemy(enemy, damage_amount, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position))
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return false
	if vulnerability_bonus > 0.0 and enemy.has_method("apply_vulnerability"):
		enemy.apply_vulnerability(vulnerability_bonus, vulnerability_duration)
	if slow_multiplier < 1.0 and slow_duration > 0.0 and enemy.has_method("apply_slow"):
		enemy.apply_slow(slow_multiplier, slow_duration)
	var adjusted_damage: float = damage_amount
	if source_position is Vector2 and source_role_id == "gunner" and owner.has_method("_get_gunner_distance_damage_multiplier"):
		adjusted_damage *= float(owner._get_gunner_distance_damage_multiplier((enemy.global_position - source_position).length()))
	var killed: bool = bool(enemy.take_damage(adjusted_damage))
	if owner.has_method("_apply_role_damage_lifesteal"):
		owner._apply_role_damage_lifesteal(source_role_id, adjusted_damage)
	if killed and owner.has_method("_on_enemy_killed_by_role"):
		owner._on_enemy_killed_by_role(source_role_id)
	return killed

static func queue_damage_to_enemy(owner, enemy: Node, damage_amount: float, source_role_id: String, vulnerability_bonus: float = 0.0, vulnerability_duration: float = 2.0, slow_multiplier: float = 1.0, slow_duration: float = 0.0, source_position: Variant = null, prefer_silent_feedback: bool = false) -> void:
	var queue := _get_or_create_damage_job_queue(owner)
	if queue == null:
		deal_damage_to_enemy(owner, enemy, damage_amount, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position)
		return
	queue.enqueue_values(weakref(enemy), enemy.get_instance_id(), damage_amount, 1, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position, 0.0, prefer_silent_feedback)

static func apply_or_queue_damage_job(owner, job: Dictionary) -> void:
	var enemy_ref: WeakRef = job.get("enemy_ref", null) as WeakRef
	if enemy_ref == null:
		return
	apply_or_queue_damage_values(
		owner,
		enemy_ref,
		int(job.get("enemy_id", 0)),
		float(job.get("damage_amount", 0.0)),
		int(job.get("hit_count", 1)),
		str(job.get("source_role_id", "")),
		float(job.get("vulnerability_bonus", 0.0)),
		float(job.get("vulnerability_duration", 2.0)),
		float(job.get("slow_multiplier", 1.0)),
		float(job.get("slow_duration", 0.0)),
		job.get("source_position", null),
		float(job.get("kill_energy_bonus", 0.0)),
		bool(job.get("prefer_silent_feedback", false))
	)

static func apply_or_queue_damage_values(owner, enemy_ref: WeakRef, enemy_id: int, damage_amount: float, hit_count: int, source_role_id: String, vulnerability_bonus: float = 0.0, vulnerability_duration: float = 2.0, slow_multiplier: float = 1.0, slow_duration: float = 0.0, source_position: Variant = null, kill_energy_bonus: float = 0.0, prefer_silent_feedback: bool = false) -> void:
	if enemy_ref == null:
		return
	var enemy: Node = enemy_ref.get_ref() as Node
	if enemy == null or not is_instance_valid(enemy):
		return
	var queue := _get_or_create_damage_job_queue(owner)
	if queue == null:
		deal_damage_to_enemy(
			owner,
			enemy,
			damage_amount,
			source_role_id,
			vulnerability_bonus,
			vulnerability_duration,
			slow_multiplier,
			slow_duration,
			source_position
		)
		return
	queue.enqueue_values(enemy_ref, enemy_id, damage_amount, hit_count, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position, kill_energy_bonus, prefer_silent_feedback)

static func damage_enemies_in_radius(owner, center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	return damage_enemies_in_radius_with_kill_energy(owner, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id, 0.0)

static func damage_enemies_in_radius_with_kill_energy(owner, center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "", kill_energy_bonus: float = 0.0) -> int:
	var resolved_role_id: String = _resolve_role_id(owner, source_role_id)
	var candidates: Array = _get_candidate_enemies_for_circle(owner, center, radius)
	_record_damage_query(candidates.size())
	var batcher := _get_reusable_damage_batcher(owner)
	for enemy in candidates:
		if not _is_live_enemy(enemy) or enemy is not Node2D:
			continue
		var hit_radius: float = _get_enemy_hit_radius(owner, enemy)
		var total_radius: float = radius + hit_radius
		if center.distance_squared_to(enemy.global_position) <= total_radius * total_radius:
			batcher.add_enemy(enemy, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, center, kill_energy_bonus)
	var hit_count: int = batcher.hit_count
	PERFORMANCE_COUNTERS.add("damage_hits", hit_count)
	return batcher.flush()

static func damage_enemies_in_radius_batched(owner, center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	return damage_enemies_in_radius(owner, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)

static func damage_enemies_in_multiple_radii_batched(owner, centers: Array[Vector2], radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	if centers.is_empty():
		return 0
	if centers.size() == 1:
		return damage_enemies_in_radius_batched(owner, centers[0], radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)
	var resolved_role_id: String = _resolve_role_id(owner, source_role_id)
	var batcher := _get_reusable_damage_batcher(owner)
	var candidates: Array = _get_candidate_enemies_for_multiple_circles(owner, centers, radius)
	var total_candidates := candidates.size()
	for enemy in candidates:
		if not _is_live_enemy(enemy) or enemy is not Node2D:
			continue
		var enemy_position: Vector2 = (enemy as Node2D).global_position
		var hit_radius: float = _get_enemy_hit_radius(owner, enemy)
		for center_index in range(centers.size()):
			var total_radius: float = radius + hit_radius
			var total_radius_squared: float = total_radius * total_radius
			if centers[center_index].distance_squared_to(enemy_position) <= total_radius_squared:
				batcher.add_enemy(enemy, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, centers[center_index])
	_record_damage_query(total_candidates)
	PERFORMANCE_COUNTERS.add("damage_hits", batcher.hit_count)
	return batcher.flush()

static func damage_enemies_in_shapes_batched(owner, shapes: Array[Dictionary]) -> int:
	if shapes.is_empty():
		return 0
	var batcher := _get_reusable_damage_batcher(owner)
	var candidates: Array = _get_candidate_enemies_for_shapes(owner, shapes)
	var total_candidates := candidates.size()
	for enemy in candidates:
		if not _is_live_enemy(enemy) or enemy is not Node2D:
			continue
		var enemy_position: Vector2 = (enemy as Node2D).global_position
		var hit_radius: float = _get_enemy_hit_radius(owner, enemy)
		var enemy_id: int = enemy.get_instance_id()
		for shape in shapes:
			var hit_registry: Dictionary = shape.get("hit_registry", {})
			if not hit_registry.is_empty() and hit_registry.has(enemy_id):
				continue
			if not _shape_hits_enemy(shape, enemy_position, hit_radius):
				continue
			if shape.has("hit_registry"):
				hit_registry[enemy_id] = true
			batcher.add_enemy(
				enemy,
				float(shape.get("damage_amount", 0.0)),
				_resolve_role_id(owner, str(shape.get("source_role_id", ""))),
				float(shape.get("vulnerability_bonus", 0.0)),
				float(shape.get("vulnerability_duration", 2.0)),
				float(shape.get("slow_multiplier", 1.0)),
				float(shape.get("slow_duration", 0.0)),
				shape.get("source_position", null),
				float(shape.get("kill_energy_bonus", 0.0))
			)
	_record_damage_query(total_candidates)
	PERFORMANCE_COUNTERS.add("damage_hits", batcher.hit_count)
	return batcher.flush()

static func damage_enemies_in_radius_count_kills(owner, center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> Dictionary:
	var hit_count := 0
	var kill_count := 0
	var resolved_role_id: String = _resolve_role_id(owner, source_role_id)
	var candidates: Array = _get_candidate_enemies_for_circle(owner, center, radius)
	_record_damage_query(candidates.size())
	var matched_enemies: Array = []
	for enemy in candidates:
		if not _is_live_enemy(enemy):
			continue
		var hit_radius: float = _get_enemy_hit_radius(owner, enemy)
		var total_radius: float = radius + hit_radius
		if center.distance_squared_to(enemy.global_position) <= total_radius * total_radius:
			matched_enemies.append(enemy)
	hit_count = matched_enemies.size()
	if _should_queue_hits(hit_count):
		for enemy in matched_enemies:
			queue_damage_to_enemy(owner, enemy, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, center)
	else:
		for enemy in matched_enemies:
			if deal_damage_to_enemy(owner, enemy, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, center):
				kill_count += 1
	PERFORMANCE_COUNTERS.add("damage_hits", hit_count)
	return {"hits": hit_count, "kills": kill_count}

static func pull_enemies_toward(owner, center: Vector2, radius: float, pull_strength: float) -> void:
	for enemy in _get_candidate_enemies_for_circle(owner, center, radius):
		var offset: Vector2 = center - enemy.global_position
		var distance := offset.length()
		if distance > 0.001 and distance <= radius:
			enemy.global_position += offset.normalized() * min(pull_strength, distance)

static func count_enemies_in_radius(owner, center: Vector2, radius: float) -> int:
	var count := 0
	var radius_squared := radius * radius
	for enemy in _get_candidate_enemies_for_circle(owner, center, radius):
		if not _is_live_enemy(enemy):
			continue
		if center.distance_squared_to(enemy.global_position) <= radius_squared:
			count += 1
	return count

static func get_touching_enemy_damage(owner, center: Vector2, radius: float, query_padding: float = 36.0) -> float:
	var candidates: Array = _get_candidate_enemies_for_circle(owner, center, radius + query_padding)
	for enemy in candidates:
		if not _is_live_enemy(enemy) or enemy is not Node2D:
			continue
		var contact_radius: float = 36.0
		var touch_damage: float = 10.0
		var enemy_contact_radius: Variant = enemy.get("contact_radius")
		var enemy_touch_damage: Variant = enemy.get("touch_damage")
		if enemy_contact_radius != null:
			contact_radius = float(enemy_contact_radius)
		if enemy_touch_damage != null:
			touch_damage = float(enemy_touch_damage)
		var combined_radius: float = contact_radius + radius
		if center.distance_squared_to((enemy as Node2D).global_position) <= combined_radius * combined_radius:
			return touch_damage
	return 0.0

static func collect_enemies_in_radius(owner, center: Vector2, radius: float) -> Array:
	var matched_enemies: Array = []
	var candidates: Array = _get_candidate_enemies_for_circle(owner, center, radius)
	_record_damage_query(candidates.size())
	for enemy in candidates:
		if not _is_live_enemy(enemy):
			continue
		var hit_radius: float = _get_enemy_hit_radius(owner, enemy)
		var total_radius: float = radius + hit_radius
		if center.distance_squared_to(enemy.global_position) <= total_radius * total_radius:
			matched_enemies.append(enemy)
	PERFORMANCE_COUNTERS.add("damage_hits", matched_enemies.size())
	return matched_enemies

static func damage_enemies_in_line(owner, start_position: Vector2, end_position: Vector2, width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	var axis := end_position - start_position
	var length := axis.length()
	if length <= 0.001:
		return damage_enemies_in_radius(owner, start_position, width, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)
	var direction := axis / length
	var resolved_role_id: String = _resolve_role_id(owner, source_role_id)
	var candidates: Array = _get_candidate_enemies_for_rect(owner, start_position + axis * 0.5, abs(axis.x) + width * 2.0, abs(axis.y) + width * 2.0)
	_record_damage_query(candidates.size())
	var batcher := _get_reusable_damage_batcher(owner)
	for enemy in candidates:
		if not _is_live_enemy(enemy):
			continue
		var relative: Vector2 = enemy.global_position - start_position
		var along: float = clamp(relative.dot(direction), 0.0, length)
		var closest: Vector2 = start_position + direction * along
		var total_width: float = width + _get_enemy_hit_radius(owner, enemy)
		if enemy.global_position.distance_squared_to(closest) <= total_width * total_width:
			batcher.add_enemy(enemy, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, start_position)
	var hit_count: int = batcher.hit_count
	PERFORMANCE_COUNTERS.add("damage_hits", hit_count)
	return batcher.flush()

static func damage_enemies_in_oriented_rect(owner, center: Vector2, axis_direction: Vector2, rect_length: float, rect_width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	return damage_enemies_in_oriented_rect_unique(owner, center, axis_direction, rect_length, rect_width, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, {}, source_role_id)

static func damage_enemies_in_oriented_rect_unique(owner, center: Vector2, axis_direction: Vector2, rect_length: float, rect_width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, hit_registry: Dictionary, source_role_id: String = "") -> int:
	var direction := axis_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	var perpendicular := direction.orthogonal()
	var half_length := rect_length * 0.5
	var half_width := rect_width * 0.5
	var resolved_role_id: String = _resolve_role_id(owner, source_role_id)
	var broad_size := rect_length + rect_width + 80.0
	var candidates: Array = _get_candidate_enemies_for_rect(owner, center, broad_size, broad_size)
	_record_damage_query(candidates.size())
	var batcher := _get_reusable_damage_batcher(owner)
	for enemy in candidates:
		if not _is_live_enemy(enemy):
			continue
		var id: int = enemy.get_instance_id()
		if hit_registry.has(id):
			continue
		var relative: Vector2 = enemy.global_position - center
		var hit_radius: float = _get_enemy_hit_radius(owner, enemy)
		if abs(relative.dot(direction)) <= half_length + hit_radius and abs(relative.dot(perpendicular)) <= half_width + hit_radius:
			hit_registry[id] = true
			batcher.add_enemy(enemy, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, center)
	var hit_count: int = batcher.hit_count
	PERFORMANCE_COUNTERS.add("damage_hits", hit_count)
	return batcher.flush()

static func damage_enemies_in_ellipse(owner, center: Vector2, horizontal_radius: float, vertical_radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	var safe_horizontal: float = max(1.0, horizontal_radius)
	var safe_vertical: float = max(1.0, vertical_radius)
	var resolved_role_id: String = _resolve_role_id(owner, source_role_id)
	var candidates: Array = _get_candidate_enemies_for_rect(owner, center, safe_horizontal * 2.0, safe_vertical * 2.0)
	_record_damage_query(candidates.size())
	var batcher := _get_reusable_damage_batcher(owner)
	for enemy in candidates:
		if not _is_live_enemy(enemy):
			continue
		var relative: Vector2 = enemy.global_position - center
		var value := pow(relative.x / safe_horizontal, 2.0) + pow(relative.y / safe_vertical, 2.0)
		if value <= 1.0:
			batcher.add_enemy(enemy, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, center)
	var hit_count: int = batcher.hit_count
	PERFORMANCE_COUNTERS.add("damage_hits", hit_count)
	return batcher.flush()

static func damage_enemies_in_cone(owner, origin: Vector2, direction: Vector2, cone_range: float, cone_angle_radians: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	var forward := direction.normalized()
	if forward.length_squared() <= 0.001:
		forward = Vector2.RIGHT
	var safe_range: float = max(1.0, cone_range)
	var half_angle: float = max(0.0, cone_angle_radians * 0.5)
	var cos_half_angle: float = cos(half_angle)
	var center: Vector2 = origin + forward * (safe_range * 0.5)
	var broad_size: float = safe_range * 2.0
	var resolved_role_id: String = _resolve_role_id(owner, source_role_id)
	var candidates: Array = _get_candidate_enemies_for_rect(owner, center, broad_size, broad_size)
	_record_damage_query(candidates.size())
	var batcher := _get_reusable_damage_batcher(owner)
	for enemy in candidates:
		if not _is_live_enemy(enemy):
			continue
		var enemy_offset: Vector2 = enemy.global_position - origin
		var distance: float = enemy_offset.length()
		var hit_radius: float = _get_enemy_hit_radius(owner, enemy)
		if distance > safe_range + hit_radius:
			continue
		if distance <= hit_radius:
			batcher.add_enemy(enemy, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, origin)
			continue
		var enemy_direction: Vector2 = enemy_offset / distance
		if enemy_direction.dot(forward) >= cos_half_angle or _is_enemy_inside_cone_edge(enemy_offset, forward, safe_range, half_angle, hit_radius):
			batcher.add_enemy(enemy, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, origin)
	var hit_count: int = batcher.hit_count
	PERFORMANCE_COUNTERS.add("damage_hits", hit_count)
	return batcher.flush()

static func _record_damage_query(candidate_count: int) -> void:
	PERFORMANCE_COUNTERS.add("damage_queries", 1)
	PERFORMANCE_COUNTERS.add("damage_candidates", candidate_count)

static func _apply_or_queue_hits(owner, enemies: Array, damage_amount: float, source_role_id: String, vulnerability_bonus: float, vulnerability_duration: float, slow_multiplier: float, slow_duration: float, source_position: Variant) -> void:
	if _should_queue_hits(enemies.size()):
		var batcher := _get_reusable_damage_batcher(owner)
		for enemy in enemies:
			batcher.add_enemy(enemy, damage_amount, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position)
		batcher.flush()
		return
	for enemy in enemies:
		deal_damage_to_enemy(owner, enemy, damage_amount, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position)

static func _should_queue_hits(hit_count: int) -> bool:
	return hit_count >= _get_queued_hit_threshold()

static func _get_queued_hit_threshold() -> int:
	var fps := Engine.get_frames_per_second()
	if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return CRITICAL_FPS_QUEUED_HIT_THRESHOLD
	if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return LOW_FPS_QUEUED_HIT_THRESHOLD
	return QUEUED_HIT_THRESHOLD

static func _get_reusable_damage_batcher(owner) -> RefCounted:
	if reusable_damage_batcher == null:
		reusable_damage_batcher = PLAYER_DAMAGE_BATCHER.new(owner)
	elif reusable_damage_batcher.has_method("reset"):
		reusable_damage_batcher.reset(owner)
	return reusable_damage_batcher

static func _get_or_create_damage_job_queue(owner) -> Node:
	if owner == null or owner.get_tree() == null:
		return null
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		return null
	var queue: Node = current_scene.get_node_or_null(DAMAGE_JOB_QUEUE_NAME)
	if queue != null:
		return queue
	queue = PLAYER_DAMAGE_JOB_QUEUE.new()
	queue.name = DAMAGE_JOB_QUEUE_NAME
	current_scene.add_child(queue)
	if queue.has_method("configure"):
		queue.configure(owner)
	return queue

static func _is_enemy_inside_cone_edge(offset: Vector2, forward: Vector2, cone_range: float, half_angle: float, hit_radius: float) -> bool:
	var side: Vector2 = forward.orthogonal()
	var forward_distance: float = offset.dot(forward)
	if forward_distance < -hit_radius or forward_distance > cone_range + hit_radius:
		return false
	var allowed_side_distance: float = max(0.0, forward_distance) * tan(half_angle) + hit_radius
	return abs(offset.dot(side)) <= allowed_side_distance

static func _get_shape_bounds(shape: Dictionary) -> Rect2:
	var shape_type: String = str(shape.get("type", "circle"))
	if shape_type == "line":
		var start_position: Vector2 = shape.get("start", Vector2.ZERO)
		var end_position: Vector2 = shape.get("end", start_position)
		var width: float = max(1.0, float(shape.get("width", 1.0)))
		var rect := Rect2(start_position, Vector2.ZERO).expand(end_position)
		return rect.grow(width + 48.0)
	if shape_type == "oriented_rect":
		var center: Vector2 = shape.get("center", Vector2.ZERO)
		var broad_size: float = float(shape.get("length", 1.0)) + float(shape.get("width", 1.0)) + 80.0
		return Rect2(center - Vector2.ONE * broad_size * 0.5, Vector2.ONE * broad_size)
	if shape_type == "cone":
		var origin: Vector2 = shape.get("origin", Vector2.ZERO)
		var direction: Vector2 = shape.get("direction", Vector2.RIGHT)
		if direction.length_squared() <= 0.001:
			direction = Vector2.RIGHT
		var cone_range: float = max(1.0, float(shape.get("range", 1.0)))
		var center: Vector2 = origin + direction.normalized() * cone_range * 0.5
		var broad_size: float = cone_range * 2.0
		return Rect2(center - Vector2.ONE * broad_size * 0.5, Vector2.ONE * broad_size)
	if shape_type == "ellipse":
		var ellipse_center: Vector2 = shape.get("center", Vector2.ZERO)
		var horizontal_radius: float = max(1.0, float(shape.get("horizontal_radius", 1.0)))
		var vertical_radius: float = max(1.0, float(shape.get("vertical_radius", 1.0)))
		return Rect2(ellipse_center - Vector2(horizontal_radius, vertical_radius), Vector2(horizontal_radius * 2.0, vertical_radius * 2.0)).grow(48.0)
	var circle_center: Vector2 = shape.get("center", Vector2.ZERO)
	var radius: float = max(1.0, float(shape.get("radius", 1.0)))
	return Rect2(circle_center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)

static func _shape_hits_enemy(shape: Dictionary, enemy_position: Vector2, hit_radius: float) -> bool:
	var shape_type: String = str(shape.get("type", "circle"))
	if shape_type == "line":
		var start_position: Vector2 = shape.get("start", Vector2.ZERO)
		var end_position: Vector2 = shape.get("end", start_position)
		var axis: Vector2 = end_position - start_position
		var length: float = axis.length()
		if length <= 0.001:
			var fallback_radius: float = float(shape.get("width", 1.0)) + hit_radius
			return start_position.distance_squared_to(enemy_position) <= fallback_radius * fallback_radius
		var direction: Vector2 = axis / length
		var relative: Vector2 = enemy_position - start_position
		var along: float = clamp(relative.dot(direction), 0.0, length)
		var closest: Vector2 = start_position + direction * along
		var total_width: float = float(shape.get("width", 1.0)) + hit_radius
		return enemy_position.distance_squared_to(closest) <= total_width * total_width
	if shape_type == "oriented_rect":
		var rect_direction: Vector2 = shape.get("axis", Vector2.RIGHT)
		rect_direction = rect_direction.normalized()
		if rect_direction.length_squared() <= 0.001:
			rect_direction = Vector2.RIGHT
		var perpendicular: Vector2 = rect_direction.orthogonal()
		var relative_rect: Vector2 = enemy_position - Vector2(shape.get("center", Vector2.ZERO))
		return abs(relative_rect.dot(rect_direction)) <= float(shape.get("length", 1.0)) * 0.5 + hit_radius and abs(relative_rect.dot(perpendicular)) <= float(shape.get("width", 1.0)) * 0.5 + hit_radius
	if shape_type == "cone":
		var origin: Vector2 = shape.get("origin", Vector2.ZERO)
		var forward: Vector2 = shape.get("direction", Vector2.RIGHT)
		forward = forward.normalized()
		if forward.length_squared() <= 0.001:
			forward = Vector2.RIGHT
		var safe_range: float = max(1.0, float(shape.get("range", 1.0)))
		var half_angle: float = max(0.0, float(shape.get("angle", 0.0)) * 0.5)
		var enemy_offset: Vector2 = enemy_position - origin
		var distance: float = enemy_offset.length()
		if distance > safe_range + hit_radius:
			return false
		if distance <= hit_radius:
			return true
		var enemy_direction: Vector2 = enemy_offset / distance
		return enemy_direction.dot(forward) >= cos(half_angle) or _is_enemy_inside_cone_edge(enemy_offset, forward, safe_range, half_angle, hit_radius)
	if shape_type == "ellipse":
		var ellipse_center: Vector2 = shape.get("center", Vector2.ZERO)
		var horizontal_radius: float = max(1.0, float(shape.get("horizontal_radius", 1.0)) + hit_radius)
		var vertical_radius: float = max(1.0, float(shape.get("vertical_radius", 1.0)) + hit_radius)
		var ellipse_relative: Vector2 = enemy_position - ellipse_center
		return pow(ellipse_relative.x / horizontal_radius, 2.0) + pow(ellipse_relative.y / vertical_radius, 2.0) <= 1.0
	var circle_center: Vector2 = shape.get("center", Vector2.ZERO)
	var total_radius: float = float(shape.get("radius", 1.0)) + hit_radius
	return circle_center.distance_squared_to(enemy_position) <= total_radius * total_radius

static func schedule_swordsman_slash_followthrough(owner, center: Vector2, axis_direction: Vector2, rect_length: float, rect_width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, animation_duration: float, source_role_id: String, hit_registry: Dictionary) -> void:
	var pulse_count: int = max(0, int(owner.SWORD_SLASH_DAMAGE_FOLLOW_PULSES))
	if pulse_count <= 0:
		return
	var pulse_interval: float = animation_duration / float(pulse_count + 1)
	if owner != null and owner.has_method("_schedule_repeating_sequence"):
		owner._schedule_repeating_sequence(pulse_interval, pulse_count, func(_index: int) -> void:
			if is_instance_valid(owner):
				damage_enemies_in_oriented_rect_unique(owner, center, axis_direction, rect_length, rect_width, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, hit_registry, source_role_id)
		, pulse_interval)

static func apply_gunner_lock(owner, target_enemy: Node2D, lock_level: int) -> void:
	if target_enemy == null or not is_instance_valid(target_enemy):
		owner.gunner_lock_target = null
		owner.gunner_lock_stacks = 0
		return
	if owner.gunner_lock_target != target_enemy:
		owner.gunner_lock_target = target_enemy
		owner.gunner_lock_stacks = 0
	owner.gunner_lock_stacks = min(max(1, lock_level), owner.gunner_lock_stacks + 1)

static func _get_live_enemies(owner) -> Array:
	var tree: SceneTree = owner.get_tree()
	if tree == null:
		return []
	var current_frame := Engine.get_physics_frames()
	var source_key := _get_enemy_source_cache_key(owner, tree)
	if cached_live_enemies_frame == current_frame and cached_live_enemies_source_key == source_key:
		return cached_live_enemies
	cached_live_enemies = []
	var enemy_nodes: Array = _get_runtime_enemies(owner, tree)
	for enemy in enemy_nodes:
		if _is_live_enemy(enemy):
			cached_live_enemies.append(enemy)
	cached_live_enemies_frame = current_frame
	cached_live_enemies_source_key = source_key
	return cached_live_enemies

static func _get_runtime_enemies(owner, tree: SceneTree) -> Array:
	if tree == null:
		return []
	var scene: Node = tree.current_scene
	if scene != null and scene.has_method("get_runtime_enemies"):
		return scene.get_runtime_enemies()
	if owner != null and owner.has_method("get_tree"):
		var owner_tree: SceneTree = owner.get_tree()
		if owner_tree != null:
			return owner_tree.get_nodes_in_group("enemies")
	return tree.get_nodes_in_group("enemies")

static func _get_candidate_enemies_for_circle(owner, center: Vector2, radius: float) -> Array:
	return _get_candidate_enemies_for_rect(owner, center, radius * 2.0, radius * 2.0)

static func _get_candidate_enemies_for_multiple_circles(owner, centers: Array[Vector2], radius: float) -> Array:
	var safe_radius: float = max(1.0, radius)
	reusable_bounds_list.clear()
	for center in centers:
		reusable_bounds_list.append(Rect2(center - Vector2.ONE * safe_radius, Vector2.ONE * safe_radius * 2.0))
	return _get_candidate_enemies_for_bounds_list(owner, reusable_bounds_list)

static func _get_candidate_enemies_for_shapes(owner, shapes: Array[Dictionary]) -> Array:
	reusable_bounds_list.clear()
	for shape in shapes:
		reusable_bounds_list.append(_get_shape_bounds(shape))
	return _get_candidate_enemies_for_bounds_list(owner, reusable_bounds_list)

static func _get_candidate_enemies_for_rect(owner, center: Vector2, width: float, height: float) -> Array:
	var half_width: float = max(1.0, width * 0.5)
	var half_height: float = max(1.0, height * 0.5)
	return _get_candidate_enemies_for_bounds(owner, Rect2(center - Vector2(half_width, half_height), Vector2(half_width * 2.0, half_height * 2.0)))

static func _get_candidate_enemies_for_bounds_list(owner, bounds_list: Array[Rect2]) -> Array:
	var grid: Dictionary = _get_enemy_grid(owner)
	if grid.is_empty() or bounds_list.is_empty():
		reusable_candidates.clear()
		return []
	reusable_candidates.clear()
	reusable_seen_enemy_ids.clear()
	for bounds in bounds_list:
		var expanded_bounds: Rect2 = bounds.grow(DAMAGE_QUERY_BOUNDS_GROW)
		var min_cell: Vector2i = _grid_cell(expanded_bounds.position)
		var max_cell: Vector2i = _grid_cell(expanded_bounds.position + expanded_bounds.size)
		for x in range(min_cell.x, max_cell.x + 1):
			for y in range(min_cell.y, max_cell.y + 1):
				var cell := Vector2i(x, y)
				if not grid.has(cell):
					continue
				for enemy in grid[cell] as Array:
					if not _is_live_enemy(enemy):
						continue
					var enemy_id: int = enemy.get_instance_id()
					if reusable_seen_enemy_ids.has(enemy_id):
						continue
					reusable_seen_enemy_ids[enemy_id] = true
					reusable_candidates.append(enemy)
	return reusable_candidates

static func _get_candidate_enemies_for_bounds(owner, bounds: Rect2) -> Array:
	var grid: Dictionary = _get_enemy_grid(owner)
	if grid.is_empty():
		reusable_candidates.clear()
		return []
	reusable_candidates.clear()
	reusable_seen_enemy_ids.clear()
	var expanded_bounds: Rect2 = bounds.grow(DAMAGE_QUERY_BOUNDS_GROW)
	var min_cell: Vector2i = _grid_cell(expanded_bounds.position)
	var max_cell: Vector2i = _grid_cell(expanded_bounds.position + expanded_bounds.size)
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			var cell := Vector2i(x, y)
			if not grid.has(cell):
				continue
			for enemy in grid[cell] as Array:
				if not _is_live_enemy(enemy):
					continue
				var enemy_id: int = enemy.get_instance_id()
				if reusable_seen_enemy_ids.has(enemy_id):
					continue
				reusable_seen_enemy_ids[enemy_id] = true
				reusable_candidates.append(enemy)
	return reusable_candidates

static func _get_enemy_grid(owner) -> Dictionary:
	var current_frame := Engine.get_physics_frames()
	var tree: SceneTree = owner.get_tree() if owner != null and owner.has_method("get_tree") else null
	var scene: Node = tree.current_scene if tree != null else null
	if scene != null:
		return ENEMY_SPATIAL_GRID.get_grid(scene)
	var source_key := _get_enemy_source_cache_key(owner, tree)
	if cached_enemy_grid_frame == current_frame and cached_enemy_grid_source_key == source_key:
		return cached_enemy_grid
	cached_enemy_grid = {}
	for enemy in _get_live_enemies(owner):
		if not _is_live_enemy(enemy) or enemy is not Node2D:
			continue
		var cell: Vector2i = _grid_cell((enemy as Node2D).global_position)
		if not cached_enemy_grid.has(cell):
			cached_enemy_grid[cell] = []
		(cached_enemy_grid[cell] as Array).append(enemy)
	cached_enemy_grid_frame = current_frame
	cached_enemy_grid_source_key = source_key
	return cached_enemy_grid

static func _get_enemy_source_cache_key(owner, tree: SceneTree) -> int:
	if tree != null:
		var scene: Node = tree.current_scene
		if scene != null:
			return scene.get_instance_id()
	if owner != null and owner is Object:
		return (owner as Object).get_instance_id()
	return 0

static func _grid_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / cached_enemy_grid_cell_size), floori(position.y / cached_enemy_grid_cell_size))

static func _get_enemy_hit_radius(owner, enemy: Node) -> float:
	if not _is_live_enemy(enemy):
		return 12.0
	if owner.has_method("_get_enemy_hit_radius"):
		return float(owner._get_enemy_hit_radius(enemy))
	return 12.0

static func _resolve_role_id(owner, source_role_id: String) -> String:
	if source_role_id != "":
		return source_role_id
	if owner != null and owner.has_method("_get_active_role"):
		return str(owner._get_active_role().get("id", ""))
	return ""

static func _is_live_enemy(enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy is Node and (enemy as Node).is_queued_for_deletion():
		return false
	return true
