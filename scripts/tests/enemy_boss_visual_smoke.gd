extends SceneTree

const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene

	var enemy := ENEMY_SCENE.instantiate() as Node2D
	enemy.apply_enemy_profile("boss", ENEMY_ARCHETYPE_DATABASE.get_profile("boss", "boss_spellcore"))
	scene.add_child(enemy)
	enemy._apply_visuals()
	await process_frame

	var polygon := enemy.get_node_or_null("Polygon2D") as Polygon2D
	if polygon == null:
		failures.append("boss smoke enemy should keep base Polygon2D node")
	elif polygon.visible:
		failures.append("boss fallback polygon should be hidden when authored boss visual is active")

	var boss_visual: Node2D = enemy.get_node_or_null("BossVisual") as Node2D
	if boss_visual == null:
		failures.append("boss visual should remain present after ready/apply_visuals")
	elif boss_visual.is_queued_for_deletion():
		failures.append("boss visual should not be queued for deletion after repeated apply_visuals")
	elif not boss_visual.visible:
		failures.append("boss visual should be visible")
	elif boss_visual.get_child_count() <= 0:
		failures.append("boss visual should instantiate authored child sprites")

	scene.queue_free()
	await process_frame
	current_scene = null

	if failures.is_empty():
		print("ENEMY_BOSS_VISUAL_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


class RuntimeRoot:
	extends Node2D

	func register_runtime_enemy(_enemy: Node) -> void:
		pass

	func unregister_runtime_enemy(_enemy: Node) -> void:
		pass
