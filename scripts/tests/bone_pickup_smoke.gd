extends SceneTree

const ENEMY_DROPS := preload("res://scripts/enemies/enemy_drops.gd")
const BONE_PICKUP_SCENE := preload("res://scenes/bone_pickup.tscn")
const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const PLAYER_SURVIVAL_FLOW := preload("res://scripts/player/player_survival_flow.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_drop_rules()
	_check_developer_runtime_collection()
	await _check_pickup_roundtrip()
	if failures.is_empty():
		print("BONE_PICKUP_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_drop_rules() -> void:
	var expected := {"elite": 1, "small_boss": 3}
	for kind in expected:
		var actual := ENEMY_DROPS.get_bone_drop_count(kind, 0.99)
		if actual != int(expected[kind]):
			failures.append("%s should drop %d bones, got %d" % [kind, expected[kind], actual])
	if ENEMY_DROPS.get_bone_drop_count("normal", 0.0099) != 1:
		failures.append("normal roll below 1% should drop one bone")
	if ENEMY_DROPS.get_bone_drop_count("normal", 0.01) != 0:
		failures.append("normal roll at 1% boundary should not drop a bone")
	if ENEMY_DROPS.get_bone_drop_count("boss", 0.0) != 0:
		failures.append("final boss bones are credited by tier settlement, not spawned as a pickup")
	if ENEMY_DROPS.get_bone_drop_count("unknown", 0.0) != 0:
		failures.append("unknown enemy kind should not drop bones")


func _check_developer_runtime_collection() -> void:
	var owner := BoneOwner.new()
	DEVELOPER_MODE.activate()
	PLAYER_SURVIVAL_FLOW._collect_bones(owner, 3)
	DEVELOPER_MODE.deactivate()
	if owner.bones != 3:
		failures.append("developer mode should collect bones into runtime state without blocking the pickup")
	owner.free()


func _check_pickup_roundtrip() -> void:
	var scene := RuntimeRoot.new()
	root.add_child(scene)
	current_scene = scene
	var enemy := DropEnemy.new()
	scene.add_child(enemy)
	scene.endless_mode_active = false
	ENEMY_DROPS.maybe_drop_bones(enemy)
	if scene.get_runtime_pickups("bone_pickups").size() != 0:
		failures.append("story mode should not spawn bone pickups")
	scene.endless_mode_active = true
	ENEMY_DROPS.maybe_drop_bones(enemy)
	var gated_drops := scene.get_runtime_pickups("bone_pickups")
	if gated_drops.size() != 1:
		failures.append("endless elite should spawn one bone pickup")
	else:
		(gated_drops[0] as Node).call("recycle")

	var pickup := BONE_PICKUP_SCENE.instantiate() as Node2D
	scene.add_child(pickup)
	pickup.reset_pickup(Vector2(12.0, -7.0), 3)
	var saved: Dictionary = pickup.get_save_data()
	if int(saved.get("value", 0)) != 3:
		failures.append("bone pickup should save its bundled value")
	pickup.recycle()

	var restored := BONE_PICKUP_SCENE.instantiate() as Node2D
	scene.add_child(restored)
	restored.apply_save_data(saved)
	if restored.global_position != Vector2(12.0, -7.0) or int(restored.get("value")) != 3:
		failures.append("bone pickup should restore position and value")
	if scene.get_runtime_pickups("bone_pickups").size() != 1:
		failures.append("restored bone pickup should register in runtime registry")
	var target := Node2D.new()
	target.global_position = Vector2(120.0, -7.0)
	scene.add_child(target)
	restored.set_attraction_target(target)
	restored._physics_process(0.1)
	if restored.global_position.x <= 12.0:
		failures.append("bone pickup should move toward its attraction target")

	scene.free_pooled_pickups()
	scene.queue_free()
	await process_frame
	current_scene = null


class RuntimeRoot:
	extends Node2D

	var endless_mode_active: bool = false
	var active_pickups: Dictionary = {"bone_pickups": {}}
	var pooled_pickups: Dictionary = {"bone_pickups": {}}

	func register_runtime_pickup(group_name: String, node: Node) -> void:
		active_pickups[group_name][node.get_instance_id()] = node

	func unregister_runtime_pickup(group_name: String, node: Node) -> void:
		active_pickups[group_name].erase(node.get_instance_id())

	func get_runtime_pickups(group_name: String) -> Array:
		return active_pickups[group_name].values()

	func release_runtime_pickup(group_name: String, node: Node) -> void:
		unregister_runtime_pickup(group_name, node)
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.hide()
		node.set_process(false)
		node.set_physics_process(false)
		pooled_pickups[group_name][node.get_instance_id()] = node

	func free_pooled_pickups() -> void:
		for pickup in pooled_pickups["bone_pickups"].values():
			if pickup != null and is_instance_valid(pickup):
					(pickup as Node).queue_free()


class DropEnemy:
	extends Node2D

	var enemy_kind: String = "elite"


class BoneOwner:
	extends Node

	var bones := 0

	func collect_ruan_bones(amount: int, _pickup_id: String = "") -> int:
		bones += amount
		return bones
