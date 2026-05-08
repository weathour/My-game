extends SceneTree

const ProjectileSpawner := preload("res://scripts/player/player_projectile_spawner.gd")
const BULLET_SCENE := preload("res://effects/gun/bullet/bullet.tscn")
const WAVE_SCENE := preload("res://effects/wizard/wave/wave.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := RuntimeRoot.new()
	root.add_child(scene)
	current_scene = scene
	var owner := OwnerStub.new()
	scene.add_child(owner)
	owner.global_position = Vector2.ZERO

	var first = ProjectileSpawner.spawn_directional_bullet(owner, BULLET_SCENE, Vector2.RIGHT, 12.0, Color.WHITE, "gunner", Vector2.ZERO)
	if first == null:
		failures.append("first projectile should spawn")
	else:
		_assert_size(scene.get_runtime_player_projectiles(), 1, "spawned projectile should register as active")
		first.lifetime = 0.001
		await physics_frame
		await process_frame
		_assert_size(scene.get_runtime_player_projectiles(), 0, "expired projectile should unregister from active registry")
		if scene.get_total_pooled_projectiles() != 1:
			failures.append("expired projectile should be released to scene pool")

	var second = ProjectileSpawner.spawn_directional_bullet(owner, BULLET_SCENE, Vector2.RIGHT, 18.0, Color.YELLOW, "gunner", Vector2.ZERO)
	if first != null and second != first:
		failures.append("second projectile should reuse pooled bullet instance")
	if second != null:
		_assert_size(scene.get_runtime_player_projectiles(), 1, "reused projectile should register as active")
		if scene.get_total_pooled_projectiles() != 0:
			failures.append("reused projectile should be removed from pool")

	await _check_scene_specific_projectile_defaults(scene, owner)

	scene.queue_free()
	await process_frame
	current_scene = null
	if failures.is_empty():
		print("PLAYER_PROJECTILE_POOL_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _assert_size(nodes: Array, expected_size: int, message: String) -> void:
	if nodes.size() != expected_size:
		failures.append("%s: expected %d, got %d" % [message, expected_size, nodes.size()])


func _check_scene_specific_projectile_defaults(_scene: Node, owner: Node2D) -> void:
	var fresh_wave = WAVE_SCENE.instantiate()
	var expected_bounds: Rect2 = fresh_wave.animated_visible_bounds
	var expected_scene_size: Vector2 = fresh_wave.animated_scene_size
	fresh_wave.free()

	var wave_first = ProjectileSpawner.spawn_directional_bullet(owner, WAVE_SCENE, Vector2.RIGHT, 8.0, Color.SKY_BLUE, "mage", Vector2.ZERO)
	if wave_first == null:
		failures.append("wave projectile should spawn")
		return
	if wave_first.animated_visible_bounds != expected_bounds:
		failures.append("wave projectile should keep scene animated_visible_bounds on first reset")
	if wave_first.animated_scene_size != expected_scene_size:
		failures.append("wave projectile should keep scene animated_scene_size on first reset")

	wave_first.animated_visible_bounds = Rect2(1.0, 2.0, 3.0, 4.0)
	wave_first.animated_scene_size = Vector2(64.0, 64.0)
	wave_first.lifetime = 0.001
	await physics_frame
	await process_frame

	var wave_second = ProjectileSpawner.spawn_directional_bullet(owner, WAVE_SCENE, Vector2.RIGHT, 8.0, Color.SKY_BLUE, "mage", Vector2.ZERO)
	if wave_second != wave_first:
		failures.append("wave projectile should reuse same pooled instance")
	if wave_second != null:
		if wave_second.animated_visible_bounds != expected_bounds:
			failures.append("reused wave projectile should restore scene animated_visible_bounds")
		if wave_second.animated_scene_size != expected_scene_size:
			failures.append("reused wave projectile should restore scene animated_scene_size")


class OwnerStub:
	extends Node2D

	func _get_active_role() -> Dictionary:
		return {"id": "gunner"}


class RuntimeRoot:
	extends Node2D

	var active_projectiles: Dictionary = {}
	var pooled_projectiles: Dictionary = {}

	func _can_spawn_runtime_group(_group_name: String, _limit: int) -> bool:
		return true

	func register_runtime_player_projectile(projectile: Node) -> void:
		active_projectiles[projectile.get_instance_id()] = projectile

	func unregister_runtime_player_projectile(projectile: Node) -> void:
		active_projectiles.erase(projectile.get_instance_id())

	func get_runtime_player_projectiles() -> Array:
		var result: Array = []
		for projectile in active_projectiles.values():
			if projectile != null and is_instance_valid(projectile):
				result.append(projectile)
		return result

	func release_runtime_player_projectile(projectile: Node, pool_key: String = "") -> void:
		if not pooled_projectiles.has(pool_key):
			pooled_projectiles[pool_key] = []
		(pooled_projectiles[pool_key] as Array).append(projectile)

	func take_runtime_player_projectile_from_pool(pool_key: String = "") -> Node:
		if not pooled_projectiles.has(pool_key):
			return null
		var pool: Array = pooled_projectiles[pool_key]
		while not pool.is_empty():
			var projectile: Node = pool.pop_back()
			if projectile != null and is_instance_valid(projectile):
				return projectile
		return null

	func get_total_pooled_projectiles() -> int:
		var count := 0
		for pool in pooled_projectiles.values():
			count += (pool as Array).size()
		return count
