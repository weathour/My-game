extends Node2D

const DEFAULT_EXPERIENCE_MULTIPLIER := 0.90
const ATTRACT_START_SPEED := 760.0
const ATTRACT_MAX_SPEED := 1480.0
const ATTRACT_ACCELERATION := 3200.0
const DESPAWN_SECONDS := 50.0

const TIER_VALUES := {
	1: 4,
	2: 9,
	3: 18,
	4: 40
}

const TIER_EXPERIENCE_MULTIPLIERS := {
	1: 1.0,
	2: 1.25,
	3: 1.2,
	4: 1.0
}

const TIER_COLORS := {
	1: Color(0.37, 0.98, 0.57, 1.0),
	2: Color(0.34, 0.74, 1.0, 1.0),
	3: Color(1.0, 0.88, 0.34, 1.0),
	4: Color(1.0, 0.56, 0.22, 1.0)
}

const TIER_SCALES := {
	1: 1.0,
	2: 1.08,
	3: 1.18,
	4: 1.32
}

@export var value: int = 10
@export var tier: int = 1

var polygon_node: Polygon2D
var attraction_target: Vector2 = Vector2.ZERO
var attraction_target_node: Node = null
var attraction_active: bool = false
var attraction_speed: float = 0.0
var age_seconds: float = 0.0
var pooled: bool = false
var batch_simulation_enabled: bool = false

func _ready() -> void:
	if pooled:
		return
	add_to_group("exp_gems")
	_register_runtime_pickup()
	polygon_node = get_node_or_null("Polygon2D") as Polygon2D
	if value <= 0:
		var default_value := _apply_value_multiplier(int(TIER_VALUES.get(tier, 4)), DEFAULT_EXPERIENCE_MULTIPLIER)
		value = _apply_tier_experience_multiplier(default_value, tier)
	_apply_appearance()

func _exit_tree() -> void:
	_unregister_runtime_pickup()

func _physics_process(delta: float) -> void:
	if batch_simulation_enabled and can_use_batch_simulation():
		return
	_run_physics_tick(delta)

func batch_physics_process(delta: float) -> void:
	_run_physics_tick(delta)

func can_use_batch_simulation() -> bool:
	return not pooled

func _run_physics_tick(delta: float) -> void:
	if pooled:
		return
	age_seconds += delta
	if not attraction_active and age_seconds >= DESPAWN_SECONDS:
		recycle()
		return
	if not attraction_active:
		return
	if is_instance_valid(attraction_target_node):
		if attraction_target_node.has_method("get_hurtbox_center"):
			attraction_target = attraction_target_node.get_hurtbox_center()
		elif attraction_target_node is Node2D:
			attraction_target = (attraction_target_node as Node2D).global_position
	var to_target: Vector2 = attraction_target - global_position
	var distance: float = to_target.length()
	if distance <= 0.001:
		return
	attraction_speed = min(ATTRACT_MAX_SPEED, attraction_speed + ATTRACT_ACCELERATION * delta)
	var step: float = min(distance, attraction_speed * delta)
	global_position += to_target.normalized() * step

func configure(new_tier: int, custom_value: int = -1, value_multiplier: float = DEFAULT_EXPERIENCE_MULTIPLIER) -> void:
	pooled = false
	batch_simulation_enabled = false
	show()
	set_process(true)
	set_physics_process(true)
	add_to_group("exp_gems")
	_register_runtime_pickup()
	tier = clamp(new_tier, 1, 4)
	var base_value: int = custom_value if custom_value > 0 else int(TIER_VALUES.get(tier, 4))
	var scaled_value := _apply_value_multiplier(base_value, value_multiplier)
	value = _apply_tier_experience_multiplier(scaled_value, tier)
	attraction_target = Vector2.ZERO
	attraction_target_node = null
	attraction_active = false
	attraction_speed = 0.0
	age_seconds = 0.0
	_apply_appearance()

func set_attraction_target(target) -> void:
	attraction_target_node = null
	if target is Node:
		attraction_target_node = target
		if attraction_target_node.has_method("get_hurtbox_center"):
			attraction_target = attraction_target_node.get_hurtbox_center()
		elif attraction_target_node is Node2D:
			attraction_target = (attraction_target_node as Node2D).global_position
	elif target is Vector2:
		attraction_target = target
	if not attraction_active:
		attraction_active = true
		attraction_speed = ATTRACT_START_SPEED

func collect() -> int:
	var collected_value := value
	recycle()
	return collected_value

func recycle() -> void:
	pooled = true
	batch_simulation_enabled = false
	_unregister_runtime_pickup()
	remove_from_group("exp_gems")
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene != null and scene.has_method("release_runtime_pickup"):
		scene.release_runtime_pickup("exp_gems", self)
		return
	queue_free()

func reset_pickup(new_position: Vector2, new_tier: int, custom_value: int = -1, value_multiplier: float = DEFAULT_EXPERIENCE_MULTIPLIER) -> void:
	global_position = new_position
	configure(new_tier, custom_value, value_multiplier)

func merge_pickup_value(extra_value: int, extra_tier: int = 1) -> void:
	value += max(0, extra_value)
	tier = max(tier, clamp(extra_tier, 1, 4))
	age_seconds = min(age_seconds, DESPAWN_SECONDS * 0.5)
	_apply_appearance()

func _apply_appearance() -> void:
	if polygon_node == null:
		polygon_node = get_node_or_null("Polygon2D") as Polygon2D
	if polygon_node != null:
		polygon_node.color = TIER_COLORS.get(tier, TIER_COLORS[1])
	scale = Vector2.ONE * float(TIER_SCALES.get(tier, 1.0))

func _apply_value_multiplier(base_value: int, multiplier: float) -> int:
	return max(1, int(round(float(base_value) * max(0.0, multiplier))))

func _apply_tier_experience_multiplier(base_value: int, target_tier: int) -> int:
	var tier_multiplier := float(TIER_EXPERIENCE_MULTIPLIERS.get(target_tier, 1.0))
	return max(1, int(round(float(base_value) * max(0.0, tier_multiplier))))

func _register_runtime_pickup() -> void:
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene != null and scene.has_method("register_runtime_pickup"):
		scene.register_runtime_pickup("exp_gems", self)

func _unregister_runtime_pickup() -> void:
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene != null and scene.has_method("unregister_runtime_pickup"):
		scene.unregister_runtime_pickup("exp_gems", self)

func get_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y],
		"value": value,
		"tier": tier,
		"age_seconds": age_seconds
	}

func apply_save_data(data: Dictionary) -> void:
	pooled = false
	batch_simulation_enabled = false
	var position_data = data.get("position", [0.0, 0.0])
	if position_data.size() >= 2:
		global_position = Vector2(float(position_data[0]), float(position_data[1]))

	value = int(data.get("value", value))
	tier = clamp(int(data.get("tier", tier)), 1, 4)
	age_seconds = clamp(float(data.get("age_seconds", 0.0)), 0.0, DESPAWN_SECONDS)
	_apply_appearance()
