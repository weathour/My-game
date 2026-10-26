extends Node2D

const ATTRACT_START_SPEED := 620.0
const ATTRACT_MAX_SPEED := 1280.0
const ATTRACT_ACCELERATION := 2600.0

@export var value: int = 1

var attraction_target: Vector2 = Vector2.ZERO
var attraction_target_node: Node = null
var attraction_active: bool = false
var attraction_speed: float = 0.0
var pooled: bool = false
var pickup_id := ""


func _ready() -> void:
	if pooled:
		return
	if pickup_id == "":
		pickup_id = _new_id()
	add_to_group("bone_pickups")
	_register_runtime_pickup()


func _exit_tree() -> void:
	_unregister_runtime_pickup()


func _physics_process(delta: float) -> void:
	if pooled or not attraction_active:
		return
	if is_instance_valid(attraction_target_node):
		if attraction_target_node.has_method("get_hurtbox_center"):
			attraction_target = attraction_target_node.get_hurtbox_center()
		elif attraction_target_node is Node2D:
			attraction_target = (attraction_target_node as Node2D).global_position
	var to_target := attraction_target - global_position
	var distance := to_target.length()
	if distance <= 0.001:
		return
	attraction_speed = min(ATTRACT_MAX_SPEED, attraction_speed + ATTRACT_ACCELERATION * delta)
	global_position += to_target.normalized() * min(distance, attraction_speed * delta)


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


func reset_pickup(new_position: Vector2, new_value: int = 1) -> void:
	pickup_id = _new_id()
	pooled = false
	show()
	set_process(true)
	set_physics_process(true)
	add_to_group("bone_pickups")
	global_position = new_position
	value = max(1, new_value)
	attraction_target = Vector2.ZERO
	attraction_target_node = null
	attraction_active = false
	attraction_speed = 0.0
	_register_runtime_pickup()


func recycle() -> void:
	pooled = true
	_unregister_runtime_pickup()
	remove_from_group("bone_pickups")
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene != null and scene.has_method("release_runtime_pickup"):
		scene.release_runtime_pickup("bone_pickups", self)
		return
	queue_free()


func get_save_data() -> Dictionary:
	return {
		"pickup_id": pickup_id,
		"position": [global_position.x, global_position.y],
		"value": value
	}


func apply_save_data(data: Dictionary) -> void:
	pooled = false
	pickup_id = str(data.get("pickup_id", pickup_id))
	var position_data: Variant = data.get("position", [0.0, 0.0])
	if position_data is Array and (position_data as Array).size() >= 2:
		global_position = Vector2(float(position_data[0]), float(position_data[1]))
	value = max(1, int(data.get("value", 1)))
	attraction_target = Vector2.ZERO
	attraction_target_node = null
	attraction_active = false
	attraction_speed = 0.0

static func _new_id() -> String:
	return "%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]


func _register_runtime_pickup() -> void:
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene != null and scene.has_method("register_runtime_pickup"):
		scene.register_runtime_pickup("bone_pickups", self)


func _unregister_runtime_pickup() -> void:
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene != null and scene.has_method("unregister_runtime_pickup"):
		scene.unregister_runtime_pickup("bone_pickups", self)
