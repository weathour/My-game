extends Node2D

const ENEMY_BULLET_SCENE_PATH := "res://scenes/enemy_bullet.tscn"
const ENEMY_BULLET_SCENE := preload("res://scenes/enemy_bullet.tscn")
const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")
const MAX_TURN_CATCH_UP_TICKS := 8
const POOL_GROUP := "enemy_projectile_pool"
const POOL_SOFT_LIMIT := 96

@export var speed: float = 260.0
@export var damage: float = 8.0
@export var lifetime: float = 4.0
@export var hit_radius: float = 16.0
@export var visual_color: Color = Color(1.0, 0.45, 0.3, 1.0)
@export var motion_mode: String = "straight"
@export var sine_amplitude: float = 36.0
@export var sine_frequency: float = 1.4
@export var sine_phase: float = 0.0
@export var turn_start_delay: float = 0.45
@export var turn_interval: float = 0.18
@export var turn_angle_step: float = 0.2
@export var turn_direction_sign: float = 1.0
@export var quarter_sine_distance: float = 180.0
@export var quarter_sine_side: float = 1.0
@export var return_after: float = 0.8
@export var return_speed: float = 320.0
@export var return_target_x: float = 0.0
@export var return_target_y: float = 0.0
@export var split_on_return: bool = false
@export var split_count: int = 0
@export var split_speed: float = 180.0
@export var split_damage_scale: float = 0.45
@export var split_lifetime: float = 3.2
@export var split_motion_mode: String = "quarter_sine"
@export var split_after_time: float = 0.0
@export var split_pattern: String = "radial"
@export var split_spread: float = 1.2
@export var size_scale: float = 1.0

var direction: Vector2 = Vector2.RIGHT
var target: Node2D
var travel_time: float = 0.0
var forward_distance: float = 0.0
var base_position: Vector2 = Vector2.ZERO
var base_direction: Vector2 = Vector2.RIGHT
var perpendicular_direction: Vector2 = Vector2.UP
var turn_delay_remaining: float = 0.0
var turn_tick_remaining: float = 0.0
var return_started: bool = false
var split_performed: bool = false
var pooled: bool = false

func _ready() -> void:
	if pooled:
		return
	_initialize_runtime_state()

func reset_projectile(config: Dictionary) -> void:
	pooled = false
	show()
	set_process(true)
	set_physics_process(true)
	global_position = config.get("position", global_position)
	direction = (config.get("direction", Vector2.RIGHT) as Vector2).normalized()
	speed = float(config.get("speed", speed))
	damage = float(config.get("damage", damage))
	lifetime = float(config.get("lifetime", lifetime))
	hit_radius = float(config.get("hit_radius", hit_radius))
	visual_color = config.get("visual_color", visual_color)
	motion_mode = str(config.get("motion_mode", motion_mode))
	target = config.get("target", target)
	sine_amplitude = float(config.get("sine_amplitude", sine_amplitude))
	sine_frequency = float(config.get("sine_frequency", sine_frequency))
	sine_phase = float(config.get("sine_phase", sine_phase))
	turn_start_delay = float(config.get("turn_start_delay", turn_start_delay))
	turn_interval = float(config.get("turn_interval", turn_interval))
	turn_angle_step = float(config.get("turn_angle_step", turn_angle_step))
	turn_direction_sign = float(config.get("turn_direction_sign", turn_direction_sign))
	quarter_sine_distance = float(config.get("quarter_sine_distance", quarter_sine_distance))
	quarter_sine_side = float(config.get("quarter_sine_side", quarter_sine_side))
	return_after = float(config.get("return_after", return_after))
	return_speed = float(config.get("return_speed", return_speed))
	return_target_x = float(config.get("return_target_x", return_target_x))
	return_target_y = float(config.get("return_target_y", return_target_y))
	split_on_return = bool(config.get("split_on_return", split_on_return))
	split_count = int(config.get("split_count", split_count))
	split_speed = float(config.get("split_speed", split_speed))
	split_damage_scale = float(config.get("split_damage_scale", split_damage_scale))
	split_lifetime = float(config.get("split_lifetime", split_lifetime))
	split_motion_mode = str(config.get("split_motion_mode", split_motion_mode))
	split_after_time = float(config.get("split_after_time", split_after_time))
	split_pattern = str(config.get("split_pattern", split_pattern))
	split_spread = float(config.get("split_spread", split_spread))
	size_scale = float(config.get("size_scale", size_scale))
	_initialize_runtime_state()

func recycle() -> void:
	var tree := get_tree()
	if tree != null and tree.get_node_count_in_group(POOL_GROUP) >= POOL_SOFT_LIMIT:
		queue_free()
		return
	pooled = true
	hide()
	set_process(false)
	set_physics_process(false)
	remove_from_group("enemy_projectiles")
	add_to_group(POOL_GROUP)
	target = null

func _initialize_runtime_state() -> void:
	direction = direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	base_position = global_position
	base_direction = direction
	perpendicular_direction = base_direction.orthogonal().normalized()
	turn_delay_remaining = turn_start_delay
	turn_tick_remaining = turn_interval
	travel_time = 0.0
	forward_distance = 0.0
	return_started = false
	split_performed = false
	remove_from_group(POOL_GROUP)
	add_to_group("enemy_projectiles")
	_apply_visuals()

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		if motion_mode == "returning_sine" and split_on_return and not split_performed:
			_spawn_split_bullets()
		recycle()
		return

	travel_time += delta

	match motion_mode:
		"sine":
			_update_sine_motion(delta)
		"turning":
			_update_turning_motion(delta)
		"quarter_sine":
			_update_quarter_sine_motion(delta)
		"returning_sine":
			if _update_returning_sine_motion(delta):
				return
		_:
			_update_straight_motion(delta)

	if split_after_time > 0.0 and not split_performed and travel_time >= split_after_time:
		_spawn_split_bullets()
		recycle()
		return

	_try_hit_player()

func _update_straight_motion(delta: float) -> void:
	global_position += direction * speed * delta
	rotation = direction.angle()

func _update_sine_motion(delta: float) -> void:
	forward_distance += speed * delta
	var forward_offset := base_direction * forward_distance
	var lateral_offset := perpendicular_direction * sin(travel_time * TAU * sine_frequency + sine_phase) * sine_amplitude
	global_position = base_position + forward_offset + lateral_offset
	rotation = (base_direction + perpendicular_direction * cos(travel_time * TAU * sine_frequency + sine_phase) * 0.28).angle()

func _update_turning_motion(delta: float) -> void:
	if turn_delay_remaining > 0.0:
		turn_delay_remaining = max(0.0, turn_delay_remaining - delta)
	else:
		turn_tick_remaining -= delta
		var catch_up_ticks := 0
		while turn_tick_remaining <= 0.0 and catch_up_ticks < MAX_TURN_CATCH_UP_TICKS:
			turn_tick_remaining += max(0.05, turn_interval)
			direction = direction.rotated(turn_angle_step * turn_direction_sign).normalized()
			catch_up_ticks += 1
		if catch_up_ticks >= MAX_TURN_CATCH_UP_TICKS and turn_tick_remaining <= 0.0:
			turn_tick_remaining = max(0.05, turn_interval)
	global_position += direction * speed * delta
	rotation = direction.angle()

func _update_quarter_sine_motion(delta: float) -> void:
	forward_distance += speed * delta
	var progress: float = clamp(forward_distance / max(quarter_sine_distance, 1.0), 0.0, 1.0)
	var forward_offset: Vector2 = base_direction * forward_distance
	var lateral_offset: Vector2 = perpendicular_direction * sin(progress * PI * 0.5) * sine_amplitude * quarter_sine_side
	global_position = base_position + forward_offset + lateral_offset
	var curve_strength: float = cos(progress * PI * 0.5) * 0.34 * quarter_sine_side
	rotation = (base_direction + perpendicular_direction * curve_strength).angle()

func _update_returning_sine_motion(delta: float) -> bool:
	if not return_started and travel_time < return_after:
		_update_quarter_sine_motion(delta)
		return false

	return_started = true
	var return_target := Vector2(return_target_x, return_target_y)
	var to_target := return_target - global_position
	var distance_to_target := to_target.length()
	if distance_to_target <= max(hit_radius, return_speed * delta):
		global_position = return_target
		if split_on_return and not split_performed:
			_spawn_split_bullets()
		recycle()
		return true

	direction = to_target.normalized()
	var wobble := direction.orthogonal() * sin(travel_time * TAU * sine_frequency + sine_phase) * sine_amplitude * 0.18
	global_position += (direction * return_speed + wobble) * delta
	rotation = direction.angle()
	return false

func _try_hit_player() -> void:
	if target == null or not is_instance_valid(target):
		return
	var target_center: Vector2 = target.global_position
	var target_radius: float = 0.0
	if target.has_method("get_hurtbox_center"):
		target_center = target.get_hurtbox_center()
	if target.has_method("get_hurtbox_radius"):
		target_radius = float(target.get_hurtbox_radius())
	if global_position.distance_to(target_center) > hit_radius + target_radius:
		return
	if target.has_method("take_damage"):
		target.take_damage(damage)
	recycle()

func _spawn_split_bullets() -> void:
	split_performed = true
	if split_count <= 0:
		return

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	var bullet_scene := ENEMY_BULLET_SCENE
	if bullet_scene == null:
		return

	var count: int = max(1, split_count)
	count = PERFORMANCE_GUARD.trim_requested_count(current_scene, "enemy_projectiles", count, _get_enemy_projectile_limit(current_scene))
	if count <= 0:
		return
	for index in range(count):
		var bullet = bullet_scene.instantiate()
		if bullet == null:
			continue
		var shot_direction := Vector2.RIGHT
		if split_pattern == "fan":
			var angle_offset := 0.0
			if count > 1:
				angle_offset = lerpf(-split_spread * 0.5, split_spread * 0.5, float(index) / float(count - 1))
			shot_direction = direction.rotated(angle_offset)
		else:
			var shot_angle := TAU * float(index) / float(count)
			shot_direction = Vector2.RIGHT.rotated(shot_angle)
		current_scene.add_child(bullet)
		if bullet.has_method("reset_projectile"):
			bullet.reset_projectile({
				"position": global_position,
				"direction": shot_direction,
				"speed": split_speed,
				"damage": damage * split_damage_scale,
				"lifetime": split_lifetime,
				"hit_radius": max(10.0, hit_radius * 0.8),
				"visual_color": visual_color.lightened(0.18),
				"motion_mode": split_motion_mode,
				"sine_amplitude": max(18.0, sine_amplitude * 0.55),
				"sine_frequency": max(1.0, sine_frequency + 0.2),
				"quarter_sine_distance": max(120.0, quarter_sine_distance * 0.72),
				"quarter_sine_side": -1.0 if index % 2 == 0 else 1.0,
				"size_scale": max(0.7, size_scale * 0.75),
				"target": target
			})

func _apply_visuals() -> void:
	var polygon := get_node_or_null("Polygon2D") as Polygon2D
	if polygon == null:
		return

	var glow := get_node_or_null("Glow") as Polygon2D
	if glow == null:
		glow = Polygon2D.new()
		glow.name = "Glow"
		glow.z_index = -1
		add_child(glow)

	var ring := get_node_or_null("Ring") as Line2D
	if ring == null:
		ring = Line2D.new()
		ring.name = "Ring"
		ring.closed = true
		ring.z_index = 1
		add_child(ring)

	var base_shape := _get_shape_for_mode()
	polygon.color = visual_color
	polygon.polygon = base_shape
	polygon.scale = _get_visual_scale()

	glow.color = Color(visual_color.r, visual_color.g, visual_color.b, 0.28)
	glow.polygon = base_shape
	glow.scale = polygon.scale * 1.7

	ring.width = 2.5 * max(size_scale, 0.8)
	ring.default_color = Color(0.05, 0.02, 0.04, 0.7)
	ring.points = _build_ring_points(12.0 * polygon.scale.x)

func _get_shape_for_mode() -> PackedVector2Array:
	match motion_mode:
		"sine", "quarter_sine", "returning_sine":
			return PackedVector2Array([
				Vector2(0.0, -9.0),
				Vector2(10.0, -3.0),
				Vector2(12.0, 0.0),
				Vector2(10.0, 3.0),
				Vector2(0.0, 9.0),
				Vector2(-8.0, 0.0)
			])
		"turning":
			return PackedVector2Array([
				Vector2(0.0, -10.0),
				Vector2(8.0, -4.0),
				Vector2(10.0, 4.0),
				Vector2(0.0, 10.0),
				Vector2(-10.0, 4.0),
				Vector2(-8.0, -4.0)
			])
		_:
			return PackedVector2Array([
				Vector2(0.0, -8.0),
				Vector2(8.0, 0.0),
				Vector2(0.0, 8.0),
				Vector2(-8.0, 0.0)
			])

func _get_visual_scale() -> Vector2:
	match motion_mode:
		"sine":
			return Vector2(1.65, 1.05) * size_scale
		"quarter_sine":
			return Vector2(1.85, 1.08) * size_scale
		"returning_sine":
			return Vector2(1.95, 1.16) * size_scale
		"turning":
			return Vector2(1.3, 1.3) * size_scale
		_:
			return Vector2.ONE * size_scale

func _build_ring_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var segments := 14
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

func get_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y],
		"direction": [direction.x, direction.y],
		"speed": speed,
		"damage": damage,
		"lifetime": lifetime,
		"hit_radius": hit_radius,
		"visual_color": [visual_color.r, visual_color.g, visual_color.b, visual_color.a],
		"motion_mode": motion_mode,
		"sine_amplitude": sine_amplitude,
		"sine_frequency": sine_frequency,
		"sine_phase": sine_phase,
		"turn_start_delay": turn_start_delay,
		"turn_interval": turn_interval,
		"turn_angle_step": turn_angle_step,
		"turn_direction_sign": turn_direction_sign,
		"quarter_sine_distance": quarter_sine_distance,
		"quarter_sine_side": quarter_sine_side,
		"return_after": return_after,
		"return_speed": return_speed,
		"return_target_x": return_target_x,
		"return_target_y": return_target_y,
		"split_on_return": split_on_return,
		"split_count": split_count,
		"split_speed": split_speed,
		"split_damage_scale": split_damage_scale,
		"split_lifetime": split_lifetime,
		"split_motion_mode": split_motion_mode,
		"split_after_time": split_after_time,
		"split_pattern": split_pattern,
		"split_spread": split_spread,
		"size_scale": size_scale,
		"travel_time": travel_time,
		"forward_distance": forward_distance,
		"base_position": [base_position.x, base_position.y],
		"base_direction": [base_direction.x, base_direction.y],
		"turn_delay_remaining": turn_delay_remaining,
		"turn_tick_remaining": turn_tick_remaining,
		"return_started": return_started,
		"split_performed": split_performed
	}

func apply_save_data(data: Dictionary, target_node: Node2D) -> void:
	var position_data = data.get("position", [0.0, 0.0])
	if position_data.size() >= 2:
		global_position = Vector2(float(position_data[0]), float(position_data[1]))

	var direction_data = data.get("direction", [1.0, 0.0])
	if direction_data.size() >= 2:
		direction = Vector2(float(direction_data[0]), float(direction_data[1])).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	speed = float(data.get("speed", speed))
	damage = float(data.get("damage", damage))
	lifetime = float(data.get("lifetime", lifetime))
	hit_radius = float(data.get("hit_radius", hit_radius))
	motion_mode = str(data.get("motion_mode", motion_mode))
	sine_amplitude = float(data.get("sine_amplitude", sine_amplitude))
	sine_frequency = float(data.get("sine_frequency", sine_frequency))
	sine_phase = float(data.get("sine_phase", sine_phase))
	turn_start_delay = float(data.get("turn_start_delay", turn_start_delay))
	turn_interval = float(data.get("turn_interval", turn_interval))
	turn_angle_step = float(data.get("turn_angle_step", turn_angle_step))
	turn_direction_sign = float(data.get("turn_direction_sign", turn_direction_sign))
	quarter_sine_distance = float(data.get("quarter_sine_distance", quarter_sine_distance))
	quarter_sine_side = float(data.get("quarter_sine_side", quarter_sine_side))
	return_after = float(data.get("return_after", return_after))
	return_speed = float(data.get("return_speed", return_speed))
	return_target_x = float(data.get("return_target_x", return_target_x))
	return_target_y = float(data.get("return_target_y", return_target_y))
	split_on_return = bool(data.get("split_on_return", split_on_return))
	split_count = int(data.get("split_count", split_count))
	split_speed = float(data.get("split_speed", split_speed))
	split_damage_scale = float(data.get("split_damage_scale", split_damage_scale))
	split_lifetime = float(data.get("split_lifetime", split_lifetime))
	split_motion_mode = str(data.get("split_motion_mode", split_motion_mode))
	split_after_time = float(data.get("split_after_time", split_after_time))
	split_pattern = str(data.get("split_pattern", split_pattern))
	split_spread = float(data.get("split_spread", split_spread))
	size_scale = float(data.get("size_scale", size_scale))
	travel_time = float(data.get("travel_time", 0.0))
	forward_distance = float(data.get("forward_distance", 0.0))

	var base_position_data = data.get("base_position", [global_position.x, global_position.y])
	if base_position_data.size() >= 2:
		base_position = Vector2(float(base_position_data[0]), float(base_position_data[1]))
	else:
		base_position = global_position

	var base_direction_data = data.get("base_direction", [direction.x, direction.y])
	if base_direction_data.size() >= 2:
		base_direction = Vector2(float(base_direction_data[0]), float(base_direction_data[1])).normalized()
	if base_direction == Vector2.ZERO:
		base_direction = direction

	perpendicular_direction = base_direction.orthogonal().normalized()
	turn_delay_remaining = float(data.get("turn_delay_remaining", turn_start_delay))
	turn_tick_remaining = float(data.get("turn_tick_remaining", turn_interval))
	return_started = bool(data.get("return_started", false))
	split_performed = bool(data.get("split_performed", false))

	var color_data = data.get("visual_color", [visual_color.r, visual_color.g, visual_color.b, visual_color.a])
	if color_data.size() >= 4:
		visual_color = Color(float(color_data[0]), float(color_data[1]), float(color_data[2]), float(color_data[3]))

	target = target_node
	add_to_group("enemy_projectiles")
	_apply_visuals()

func _get_enemy_projectile_limit(current_scene: Node) -> int:
	if current_scene != null and current_scene.has_method("_get_difficulty_limit"):
		return int(current_scene._get_difficulty_limit("enemy_projectile_limit", PERFORMANCE_GUARD.DEFAULT_ENEMY_PROJECTILE_LIMIT))
	return PERFORMANCE_GUARD.DEFAULT_ENEMY_PROJECTILE_LIMIT
