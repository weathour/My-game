extends Node2D

const HEAL_AMOUNT := 50.0
const DESPAWN_SECONDS := 45.0

@export var heal_amount: float = HEAL_AMOUNT

var polygon_node: Polygon2D
var age_seconds: float = 0.0

func _ready() -> void:
	add_to_group("heart_pickups")
	_register_runtime_pickup()
	polygon_node = get_node_or_null("Polygon2D") as Polygon2D
	_apply_appearance()

func _exit_tree() -> void:
	_unregister_runtime_pickup()

func _physics_process(delta: float) -> void:
	age_seconds += delta
	if age_seconds >= DESPAWN_SECONDS:
		queue_free()

func collect() -> float:
	queue_free()
	return heal_amount

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
	var position_data = data.get("position", [0.0, 0.0])
	if position_data.size() >= 2:
		global_position = Vector2(float(position_data[0]), float(position_data[1]))
	heal_amount = float(data.get("heal_amount", heal_amount))
	age_seconds = clamp(float(data.get("age_seconds", 0.0)), 0.0, DESPAWN_SECONDS)
	_apply_appearance()
