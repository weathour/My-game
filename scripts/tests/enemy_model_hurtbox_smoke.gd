extends SceneTree

const ENEMY_MODEL_HURTBOX := preload("res://scripts/enemies/enemy_model_hurtbox.gd")
const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var square := {"type": "square", "center": Vector2.ZERO, "half_extent": 10.0}
	if PLAYER_DAMAGE_RESOLVER._enemy_shape_hits_line(square, Vector2(14, 14), Vector2(14, 14), 5.0):
		failures.append("stationary projectile must not hit outside a square's rounded corner")
	if not PLAYER_DAMAGE_RESOLVER._enemy_shape_hits_line(square, Vector2(13, 14), Vector2(13, 14), 5.0):
		failures.append("stationary projectile must hit a tangent square corner")
	var root := Node2D.new()
	get_root().add_child(root)
	var visual_cases := [
		["res://assets/enemies/Unas/Unas.tscn", "BossVisual", 2.35],
		["res://assets/enemies/rose/rose.tscn", "ProfileVisual", 1.95],
		["res://assets/enemies/treeboss/treeboss.tscn", "ProfileVisual", 2.05],
		["res://assets/enemies/skulltomb/skulltomb.tscn", "ProfileVisual", 1.0]
	]
	for visual_case in visual_cases:
		var enemy := ModelEnemy.new()
		enemy.enemy_kind = "boss" if visual_case[1] == "BossVisual" else "small_boss"
		enemy.contact_radius = 64.0
		enemy.scale = Vector2.ONE * float(visual_case[2])
		root.add_child(enemy)
		var visual := load(str(visual_case[0])).instantiate() as Node2D
		visual.name = str(visual_case[1])
		enemy.add_child(visual)
		await process_frame
		var shape: Dictionary = ENEMY_MODEL_HURTBOX.get_shape(enemy)
		if str(shape.get("type", "")) != "square":
			failures.append("model hurtbox type missing for %s" % str(visual_case[0]))
			continue
		var half_extent: float = float(shape.get("half_extent", 0.0))
		if half_extent <= 1.0 or float(shape.get("horizontal_radius", 0.0)) != half_extent or float(shape.get("vertical_radius", 0.0)) != half_extent:
			failures.append("model hurtbox is not square for %s" % str(visual_case[0]))
		if PLAYER_DAMAGE_RESOLVER._enemy_shape_hits_circle(shape, shape.get("center", Vector2.ZERO), 0.0) == false:
			failures.append("model hurtbox center should be damageable for %s" % str(visual_case[0]))
		enemy.queue_free()
	root.queue_free()
	if failures.is_empty():
		print("ENEMY_MODEL_HURTBOX_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


class ModelEnemy:
	extends Node2D

	var enemy_kind: String = "small_boss"
	var contact_radius: float = 64.0
