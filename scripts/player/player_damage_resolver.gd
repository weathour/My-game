extends RefCounted

const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")
const PLAYER_DAMAGE_JOB_QUEUE := preload("res://scripts/player/player_damage_job_queue.gd")
const PLAYER_DAMAGE_BATCHER := preload("res://scripts/player/player_damage_batcher.gd")

const DAMAGE_JOB_QUEUE_NAME := "PlayerDamageJobQueue"
const QUEUED_HIT_THRESHOLD := 16

static var cached_live_enemies: Array = []
static var cached_live_enemies_frame: int = -1
static var cached_enemy_grid: Dictionary = {}
static var cached_enemy_grid_frame: int = -1
static var cached_enemy_grid_cell_size: float = 96.0

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

static func queue_damage_to_enemy(owner, enemy: Node, damage_amount: float, source_role_id: String, vulnerability_bonus: float = 0.0, vulnerability_duration: float = 2.0, slow_multiplier: float = 1.0, slow_duration: float = 0.0, source_position: Variant = null) -> void:
	var queue := _get_or_create_damage_job_queue(owner)
	if queue == null:
		deal_damage_to_enemy(owner, enemy, damage_amount, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position)
		return
	queue.enqueue({
		"enemy_ref": weakref(enemy),
		"enemy_id": enemy.get_instance_id(),
		"damage_amount": damage_amount,
		"hit_count": 1,
		"source_role_id": source_role_id,
		"vulnerability_bonus": vulnerability_bonus,
		"vulnerability_duration": vulnerability_duration,
		"slow_multiplier": slow_multiplier,
		"slow_duration": slow_duration,
		"source_position": source_position
	})

static func apply_or_queue_damage_job(owner, job: Dictionary) -> void:
	var enemy_ref: WeakRef = job.get("enemy_ref", null) as WeakRef
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
			float(job.get("damage_amount", 0.0)),
			str(job.get("source_role_id", "")),
			float(job.get("vulnerability_bonus", 0.0)),
			float(job.get("vulnerability_duration", 2.0)),
			float(job.get("slow_multiplier", 1.0)),
			float(job.get("slow_duration", 0.0)),
			job.get("source_position", null)
		)
		return
	queue.enqueue(job)

static func damage_enemies_in_radius(owner, center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	var hit_count := 0
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
	_apply_or_queue_hits(owner, matched_enemies, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, center)
	PERFORMANCE_COUNTERS.add("damage_hits", hit_count)
	return hit_count

static func damage_enemies_in_radius_batched(owner, center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	var resolved_role_id: String = _resolve_role_id(owner, source_role_id)
	var batcher := PLAYER_DAMAGE_BATCHER.new(owner)
	for enemy in collect_enemies_in_radius(owner, center, radius):
		batcher.add_enemy(enemy, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, center)
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
	var hit_count := 0
	var resolved_role_id: String = _resolve_role_id(owner, source_role_id)
	var candidates: Array = _get_candidate_enemies_for_rect(owner, start_position + axis * 0.5, abs(axis.x) + width * 2.0, abs(axis.y) + width * 2.0)
	_record_damage_query(candidates.size())
	var matched_enemies: Array = []
	for enemy in candidates:
		if not _is_live_enemy(enemy):
			continue
		var relative: Vector2 = enemy.global_position - start_position
		var along: float = clamp(relative.dot(direction), 0.0, length)
		var closest: Vector2 = start_position + direction * along
		var total_width: float = width + _get_enemy_hit_radius(owner, enemy)
		if enemy.global_position.distance_squared_to(closest) <= total_width * total_width:
			matched_enemies.append(enemy)
	hit_count = matched_enemies.size()
	_apply_or_queue_hits(owner, matched_enemies, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, start_position)
	PERFORMANCE_COUNTERS.add("damage_hits", hit_count)
	return hit_count

static func damage_enemies_in_oriented_rect(owner, center: Vector2, axis_direction: Vector2, rect_length: float, rect_width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	return damage_enemies_in_oriented_rect_unique(owner, center, axis_direction, rect_length, rect_width, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, {}, source_role_id)

static func damage_enemies_in_oriented_rect_unique(owner, center: Vector2, axis_direction: Vector2, rect_length: float, rect_width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, hit_registry: Dictionary, source_role_id: String = "") -> int:
	var direction := axis_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	var perpendicular := direction.orthogonal()
	var half_length := rect_length * 0.5
	var half_width := rect_width * 0.5
	var hit_count := 0
	var resolved_role_id: String = _resolve_role_id(owner, source_role_id)
	var broad_size := rect_length + rect_width + 80.0
	var candidates: Array = _get_candidate_enemies_for_rect(owner, center, broad_size, broad_size)
	_record_damage_query(candidates.size())
	var matched_enemies: Array = []
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
			matched_enemies.append(enemy)
	hit_count = matched_enemies.size()
	_apply_or_queue_hits(owner, matched_enemies, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, center)
	PERFORMANCE_COUNTERS.add("damage_hits", hit_count)
	return hit_count

static func damage_enemies_in_ellipse(owner, center: Vector2, horizontal_radius: float, vertical_radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	var hit_count := 0
	var safe_horizontal: float = max(1.0, horizontal_radius)
	var safe_vertical: float = max(1.0, vertical_radius)
	var resolved_role_id: String = _resolve_role_id(owner, source_role_id)
	var candidates: Array = _get_candidate_enemies_for_rect(owner, center, safe_horizontal * 2.0, safe_vertical * 2.0)
	_record_damage_query(candidates.size())
	var matched_enemies: Array = []
	for enemy in candidates:
		if not _is_live_enemy(enemy):
			continue
		var relative: Vector2 = enemy.global_position - center
		var value := pow(relative.x / safe_horizontal, 2.0) + pow(relative.y / safe_vertical, 2.0)
		if value <= 1.0:
			matched_enemies.append(enemy)
	hit_count = matched_enemies.size()
	_apply_or_queue_hits(owner, matched_enemies, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, center)
	PERFORMANCE_COUNTERS.add("damage_hits", hit_count)
	return hit_count

static func damage_enemies_in_cone(owner, origin: Vector2, direction: Vector2, cone_range: float, cone_angle_radians: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	var forward := direction.normalized()
	if forward.length_squared() <= 0.001:
		forward = Vector2.RIGHT
	var safe_range: float = max(1.0, cone_range)
	var half_angle: float = max(0.0, cone_angle_radians * 0.5)
	var cos_half_angle: float = cos(half_angle)
	var center: Vector2 = origin + forward * (safe_range * 0.5)
	var broad_size: float = safe_range * 2.0
	var hit_count := 0
	var resolved_role_id: String = _resolve_role_id(owner, source_role_id)
	var candidates: Array = _get_candidate_enemies_for_rect(owner, center, broad_size, broad_size)
	_record_damage_query(candidates.size())
	var matched_enemies: Array = []
	for enemy in candidates:
		if not _is_live_enemy(enemy):
			continue
		var enemy_offset: Vector2 = enemy.global_position - origin
		var distance: float = enemy_offset.length()
		var hit_radius: float = _get_enemy_hit_radius(owner, enemy)
		if distance > safe_range + hit_radius:
			continue
		if distance <= hit_radius:
			matched_enemies.append(enemy)
			continue
		var enemy_direction: Vector2 = enemy_offset / distance
		if enemy_direction.dot(forward) >= cos_half_angle or _is_enemy_inside_cone_edge(enemy_offset, forward, safe_range, half_angle, hit_radius):
			matched_enemies.append(enemy)
	hit_count = matched_enemies.size()
	_apply_or_queue_hits(owner, matched_enemies, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, origin)
	PERFORMANCE_COUNTERS.add("damage_hits", hit_count)
	return hit_count

static func _record_damage_query(candidate_count: int) -> void:
	PERFORMANCE_COUNTERS.add("damage_queries", 1)
	PERFORMANCE_COUNTERS.add("damage_candidates", candidate_count)

static func _apply_or_queue_hits(owner, enemies: Array, damage_amount: float, source_role_id: String, vulnerability_bonus: float, vulnerability_duration: float, slow_multiplier: float, slow_duration: float, source_position: Variant) -> void:
	if _should_queue_hits(enemies.size()):
		for enemy in enemies:
			queue_damage_to_enemy(owner, enemy, damage_amount, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position)
		return
	for enemy in enemies:
		deal_damage_to_enemy(owner, enemy, damage_amount, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position)

static func _should_queue_hits(hit_count: int) -> bool:
	return hit_count >= QUEUED_HIT_THRESHOLD

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

static func schedule_swordsman_slash_followthrough(owner, center: Vector2, axis_direction: Vector2, rect_length: float, rect_width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, animation_duration: float, source_role_id: String, hit_registry: Dictionary) -> void:
	for index in range(max(0, int(owner.SWORD_SLASH_DAMAGE_FOLLOW_PULSES))):
		var tree: SceneTree = owner.get_tree()
		if tree == null:
			return
		var timer := tree.create_timer(animation_duration * (float(index + 1) / float(owner.SWORD_SLASH_DAMAGE_FOLLOW_PULSES + 1)))
		timer.timeout.connect(func() -> void:
			if is_instance_valid(owner):
				damage_enemies_in_oriented_rect_unique(owner, center, axis_direction, rect_length, rect_width, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, hit_registry, source_role_id)
		)

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
	if cached_live_enemies_frame == current_frame:
		return cached_live_enemies
	cached_live_enemies = []
	for enemy in tree.get_nodes_in_group("enemies"):
		if _is_live_enemy(enemy):
			cached_live_enemies.append(enemy)
	cached_live_enemies_frame = current_frame
	return cached_live_enemies

static func _get_candidate_enemies_for_circle(owner, center: Vector2, radius: float) -> Array:
	return _get_candidate_enemies_for_rect(owner, center, radius * 2.0, radius * 2.0)

static func _get_candidate_enemies_for_rect(owner, center: Vector2, width: float, height: float) -> Array:
	var grid: Dictionary = _get_enemy_grid(owner)
	if grid.is_empty():
		return []
	var half_width: float = max(1.0, width * 0.5 + 48.0)
	var half_height: float = max(1.0, height * 0.5 + 48.0)
	var min_cell: Vector2i = _grid_cell(center - Vector2(half_width, half_height))
	var max_cell: Vector2i = _grid_cell(center + Vector2(half_width, half_height))
	var candidates: Array = []
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			var cell := Vector2i(x, y)
			if grid.has(cell):
				for enemy in grid[cell] as Array:
					if _is_live_enemy(enemy):
						candidates.append(enemy)
	return candidates

static func _get_enemy_grid(owner) -> Dictionary:
	var current_frame := Engine.get_physics_frames()
	if cached_enemy_grid_frame == current_frame:
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
	return cached_enemy_grid

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
