extends Node2D

const HEAL_AMOUNT := 50.0
const DESPAWN_SECONDS := 45.0

@export var heal_amount: float = HEAL_AMOUNT

var polygon_node: Polygon2D
var age_seconds: float = 0.0
var pooled: bool = false
var batch_simulation_enabled: bool = false

func _ready() -> void:
	if pooled:
		return
	add_to_group("heart_pickups")
	_register_runtime_pickup()
	polygon_node = get_node_or_null("Polygon2D") as Polygon2D
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
	if age_seconds >= DESPAWN_SECONDS:
		recycle()

func collect() -> float:
	var collected_heal := heal_amount
	recycle()
	return collected_heal

func reset_pickup(new_position: Vector2, new_heal_amount: float = HEAL_AMOUNT) -> void:
	pooled = false
	batch_simulation_enabled = false
	show()
	set_process(true)
	set_physics_process(true)
	add_to_group("heart_pickups")
	global_position = new_position
	heal_amount = new_heal_amount
	age_seconds = 0.0
	_register_runtime_pickup()
	_apply_appearance()

func recycle() -> void:
	pooled = true
	batch_simulation_enabled = false
	_unregister_runtime_pickup()
	remove_from_group("heart_pickups")
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene != null and scene.has_method("release_runtime_pickup"):
		scene.release_runtime_pickup("heart_pickups", self)
		return
	queue_free()

func merge_heal_amount(extra_heal_amount: float) -> void:
	heal_amount += max(0.0, extra_heal_amount)
	age_seconds = min(age_seconds, DESPAWN_SECONDS * 0.5)

func _apply_appearance() -> void:
	if polygon_node == null:
		polygon_node = get_node_or_null("Polygon2D") as Polygon2D
	if polygon_node != null:
		polygon_node.color = Color(1.0, 0.36, 0.48, 1.0)

func _register_runtime_pickup() -> void:
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene != null and scene.has_method("register_runtime_pickup"):
		scene.register_runtime_pickup("heart_pickups", self)

func _unregister_runtime_pickup() -> void:
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene != null and scene.has_method("unregister_runtime_pickup"):
		scene.unregister_runtime_pickup("heart_pickups", self)

func get_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y],
		"heal_amount": heal_amount,
		"age_seconds": age_seconds
	}

func apply_save_data(data: Dictionary) -> void:
	pooled = false
	batch_simulation_enabled = false
	var position_data = data.get("position", [0.0, 0.0])
	if position_data.size() >= 2:
		global_position = Vector2(float(position_data[0]), float(position_data[1]))
	heal_amount = float(data.get("heal_amount", heal_amount))
	age_seconds = clamp(float(data.get("age_seconds", 0.0)), 0.0, DESPAWN_SECONDS)
	_apply_appearance()
