extends SceneTree

const DISPATCH := preload("res://scripts/combat/damage_method_dispatch.gd")
const RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const QUEUE := preload("res://scripts/player/player_damage_job_queue.gd")
const HUD_FLOW := preload("res://scripts/game/game_hud_flow.gd")
const STORE := preload("res://scripts/save/save_file_store.gd")
const ENEMY := preload("res://scenes/enemy.tscn")
const SEPARATION := preload("res://scripts/enemies/enemy_body_separation.gd")
const GRID := preload("res://scripts/enemies/enemy_spatial_grid.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_damage_dispatch()
	_check_mana_hud()
	_check_save_pair()
	await _check_spatial_cache()
	print("COMBAT_PERFORMANCE_REGRESSION_SMOKE_OK")
	quit(0)


func _check_damage_dispatch() -> void:
	var single := SingleArgumentEnemy.new()
	var dual := TwoArgumentEnemy.new()
	var queue := QUEUE.new()
	for _index in range(10):
		assert(RESOLVER._call_enemy_take_damage(single, 2.0, true))
		assert(RESOLVER._call_enemy_take_damage(dual, 2.0, true))
		assert(queue._call_enemy_take_batched_damage(single, 3.0, false))
		assert(queue._call_enemy_take_batched_damage(dual, 3.0, false))
	assert(is_equal_approx(single.damage, 50.0))
	assert(is_equal_approx(dual.damage, 50.0))
	assert(dual.criticals == 10)
	assert(not DISPATCH.accepts_arguments(single, "missing_method", 1))
	# An instance changing script must not retain the previous arity.
	single.set_script(TwoArgumentEnemy)
	assert(RESOLVER._call_enemy_take_damage(single, 2.0, true))
	assert(single.get("criticals") == 1)
	queue.free()
	single.free()
	dual.free()


func _check_mana_hud() -> void:
	var main := HudRuntime.new()
	main.player = PlayerPayload.new()
	main.hud = HudSink.new()
	for _index in range(40):
		HUD_FLOW.on_player_mana_changed(main, 25.0, 100.0)
	assert(main.player.full_calls == 0)
	assert(main.player.frame_calls == 1)
	assert(main.hud.mana_updates == 40)
	main.survival_time = 0.04
	HUD_FLOW.on_player_mana_changed(main, 30.0, 100.0)
	assert(main.player.frame_calls == 2)
	assert(main.hud.last_summary.current_mana == 30.0)
	main.player.free()
	main.hud.free()
	main.free()


func _check_save_pair() -> void:
	var path := "user://performance/regression_primary.json"
	var backup := "user://performance/regression_backup.json"
	var payload := {"health": 52.5, "enemies": [{"armor": -5.0}], "label": "存档回归"}
	var written := STORE.write_json_pair(path, backup, payload)
	var serialized := FileAccess.get_file_as_string(path)
	assert(written > 0 and written == serialized.length())
	assert(JSON.parse_string(serialized) == payload)
	assert(FileAccess.get_file_as_string(backup) == serialized)
	assert(STORE.read_json(backup) == payload)
	payload.health = 10.0
	assert(STORE.write_json_pair(path, backup, payload) > 0)
	assert(STORE.read_json(path).health == 10.0)
	assert(STORE.read_json(backup).health == 10.0)
	STORE.remove_if_exists(path)
	STORE.remove_if_exists(backup)


func _check_spatial_cache() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var enemy = ENEMY.instantiate()
	var neighbor = ENEMY.instantiate()
	scene.add_child(enemy)
	scene.add_child(neighbor)
	enemy.position = Vector2(30.0, 30.0)
	neighbor.position = Vector2(40.0, 30.0)
	neighbor.scale = Vector2(0.6, 0.8)
	neighbor.body_collision_reference_scale = 0.8
	neighbor.body_collision_radius = 48.0
	assert(is_equal_approx(SEPARATION.get_body_collision_radius(neighbor), 14.4))
	neighbor.scale = Vector2(-1.6, 1.2)
	assert(is_equal_approx(SEPARATION.get_body_collision_radius(neighbor), 28.8))
	neighbor.body_collision_radius = -1.0
	neighbor.contact_radius = 50.0
	assert(is_equal_approx(SEPARATION.get_body_collision_radius(neighbor), 24.6))
	var first := GRID.get_neighbors(enemy, 144.0)
	assert(first.is_read_only() and first.has(neighbor))
	assert(GRID.get_neighbors(enemy, 144.0) == first)
	var push := SEPARATION.compute_separation_velocity(enemy)
	assert(push.x < 0.0 and is_zero_approx(push.y))
	neighbor.position = Vector2(5000, 5000)
	await physics_frame
	assert(not GRID.get_neighbors(enemy, 144.0).has(neighbor))
	assert(SEPARATION.compute_separation_velocity(enemy).is_zero_approx())
	scene.free()
	current_scene = null


class SingleArgumentEnemy:
	extends Node
	var damage := 0.0
	func take_damage(amount: float) -> bool:
		damage += amount
		return true
	func take_batched_damage(amount: float) -> bool:
		return take_damage(amount)


class TwoArgumentEnemy:
	extends Node
	var damage := 0.0
	var criticals := 0
	func take_damage(amount: float, critical: bool = false) -> bool:
		damage += amount
		criticals += int(critical)
		return true
	func take_batched_damage(amount: float, critical: bool = false) -> bool:
		return take_damage(amount, critical)


class PlayerPayload:
	extends Node
	var full_calls := 0
	var frame_calls := 0
	func get_stat_summary() -> Dictionary:
		full_calls += 1
		return {}
	func get_frame_hud_summary() -> Dictionary:
		frame_calls += 1
		return {"current_mana": 30.0}


class HudSink:
	extends Node
	var mana_updates := 0
	var last_summary: Dictionary = {}
	func update_mana(_value: float, _maximum: float) -> void:
		mana_updates += 1
	func update_stats(summary: Dictionary) -> void:
		last_summary = summary


class HudRuntime:
	extends Node
	var hud: HudSink
	var player: PlayerPayload
	var survival_time := 0.0
