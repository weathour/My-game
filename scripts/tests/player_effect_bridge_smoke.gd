extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var player := PLAYER_SCENE.instantiate()
	scene.add_child(player)
	await process_frame

	_check_authored_effect_bridges(player)
	await _check_primitive_effect_bridges(player)

	scene.queue_free()
	await process_frame
	current_scene = null
	if failures.is_empty():
		print("PLAYER_EFFECT_BRIDGE_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_authored_effect_bridges(player: Node) -> void:
	var slash = player._spawn_sword_slash_scene_effect(Vector2.ZERO, Vector2.RIGHT, 40.0, Color.WHITE, 0.2, 10.0)
	if slash == null:
		failures.append("sword slash authored bridge should spawn an effect")
	var fan = player._spawn_sword_fan_scene_effect(Vector2(20.0, 0.0), Vector2.RIGHT, 1.0)
	if fan == null:
		failures.append("sword fan authored bridge should spawn an effect")
	var warning = player._spawn_mage_warning_scene_effect(Vector2(40.0, 0.0), 28.0)
	if warning == null:
		failures.append("mage warning authored bridge should spawn an effect")


func _check_primitive_effect_bridges(player: Node) -> void:
	player._spawn_ring_effect(Vector2.ZERO, 30.0, Color.WHITE, 3.0, 0.1)
	player._spawn_burst_effect(Vector2(16.0, 0.0), 28.0, Color(1.0, 0.6, 0.2, 0.3), 0.1)
	player._spawn_cross_slash_effect(Vector2(32.0, 0.0), Vector2.RIGHT, 48.0, 8.0, Color.WHITE, 0.1)
	player._spawn_guard_effect(Vector2(48.0, 0.0), 24.0, Color(0.7, 0.9, 1.0, 0.3), 0.1)
	player._spawn_target_lock_effect(Vector2(64.0, 0.0), 18.0, Color(1.0, 0.8, 0.4, 0.8), 0.1)
	await process_frame
	var temporary_effect_count := 0
	for child in current_scene.get_children():
		if child is Node and child.is_in_group("temporary_effects"):
			temporary_effect_count += 1
	if temporary_effect_count <= 0:
		failures.append("primitive effect bridges should create temporary effects")
