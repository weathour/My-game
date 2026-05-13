extends SceneTree

const DamageResolver := preload("res://scripts/player/player_damage_resolver.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var root := Node.new()
	get_root().add_child(root)
	current_scene = root
	var owner := DamageOwner.new()
	root.add_child(owner)
	var enemies: Array = [
		_make_enemy(root, Vector2(0.0, 0.0)),
		_make_enemy(root, Vector2(36.0, 0.0)),
		_make_enemy(root, Vector2(180.0, 0.0)),
		_make_enemy(root, Vector2(0.0, 92.0)),
	]
	var radius_hits: int = DamageResolver.damage_enemies_in_radius(owner, Vector2.ZERO, 48.0, 10.0, 0.0, 1.0, 0.0, "swordsman")
	if radius_hits != 2:
		failures.append("radius damage should hit only nearby enemies")
	var line_hits: int = DamageResolver.damage_enemies_in_line(owner, Vector2.ZERO, Vector2(200.0, 0.0), 12.0, 10.0, 0.0, 1.0, 0.0, "gunner")
	if line_hits != 3:
		failures.append("line damage should hit enemies near segment")
	var registry: Dictionary = {}
	var rect_hits_a: int = DamageResolver.damage_enemies_in_oriented_rect_unique(owner, Vector2.ZERO, Vector2.RIGHT, 100.0, 40.0, 10.0, 0.0, 1.0, 0.0, registry, "mage")
	var rect_hits_b: int = DamageResolver.damage_enemies_in_oriented_rect_unique(owner, Vector2.ZERO, Vector2.RIGHT, 100.0, 40.0, 10.0, 0.0, 1.0, 0.0, registry, "mage")
	if rect_hits_a != 2 or rect_hits_b != 0:
		failures.append("unique rect damage should respect hit registry")
	var batched_hits: int = DamageResolver.damage_enemies_in_radius_batched(owner, Vector2.ZERO, 96.0, 10.0, 0.0, 1.0, 0.0, "swordsman")
	var queue: Node = root.get_node_or_null("PlayerDamageJobQueue")
	if batched_hits != 3:
		failures.append("batched radius damage should report all matched hits")
	if queue == null or not ("enemy_refs" in queue) or queue.enemy_refs.size() <= 0:
		failures.append("batched radius damage should enqueue merged jobs")
	if owner.register_calls != 0:
		failures.append("resolver should not register aggregate attack results before queued jobs are applied")
	await physics_frame
	await process_frame
	if owner.damage_calls <= 0:
		failures.append("resolver should call owner damage entrypoint")
	var freeing_owner := FreeingDamageOwner.new()
	root.add_child(freeing_owner)
	var freed_enemy := _make_enemy(root, Vector2(10.0, 10.0))
	var stable_enemy := _make_enemy(root, Vector2(18.0, 10.0))
	freeing_owner.enemy_to_free = freed_enemy
	var first_freeing_hits: int = DamageResolver.damage_enemies_in_radius(freeing_owner, Vector2(12.0, 10.0), 32.0, 10.0, 0.0, 1.0, 0.0, "mage")
	var second_freeing_hits: int = DamageResolver.damage_enemies_in_radius(freeing_owner, Vector2(12.0, 10.0), 32.0, 10.0, 0.0, 1.0, 0.0, "mage")
	if first_freeing_hits < 1 or second_freeing_hits < 1:
		failures.append("resolver should skip queued-for-deletion enemies without aborting later hits")
	if is_instance_valid(stable_enemy):
		stable_enemy.queue_free()
	_check_disjoint_batched_queries()
	_check_runtime_cache_key_switch()
	for enemy in enemies:
		if is_instance_valid(enemy):
			(enemy as Node).queue_free()
	root.queue_free()
	current_scene = null
	if failures.is_empty():
		print("PLAYER_DAMAGE_RESOLVER_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _make_enemy(root: Node, position: Vector2) -> Node2D:
	var enemy := TestEnemy.new()
	enemy.global_position = position
	enemy.contact_radius = 8.0
	enemy.add_to_group("enemies")
	root.add_child(enemy)
	return enemy

func _make_runtime_enemy(root: RuntimeEnemyRoot, position: Vector2) -> Node2D:
	var enemy := TestEnemy.new()
	enemy.global_position = position
	enemy.contact_radius = 8.0
	root.add_child(enemy)
	root.enemies.append(enemy)
	return enemy

func _check_disjoint_batched_queries() -> void:
	var runtime_root := RuntimeEnemyRoot.new()
	get_root().add_child(runtime_root)
	current_scene = runtime_root
	var owner := DamageOwner.new()
	runtime_root.add_child(owner)
	_make_runtime_enemy(runtime_root, Vector2.ZERO)
	_make_runtime_enemy(runtime_root, Vector2(1000.0, 0.0))
	_make_runtime_enemy(runtime_root, Vector2(500.0, 0.0))
	var hits: int = DamageResolver.damage_enemies_in_multiple_radii_batched(owner, [Vector2.ZERO, Vector2(1000.0, 0.0)], 24.0, 10.0, 0.0, 1.0, 0.0, "swordsman")
	if hits != 2:
		failures.append("disjoint batched radii should hit only enemies inside each circle")
	runtime_root.queue_free()

func _check_runtime_cache_key_switch() -> void:
	var root_a := RuntimeEnemyRoot.new()
	var root_b := RuntimeEnemyRoot.new()
	get_root().add_child(root_a)
	get_root().add_child(root_b)
	var owner_a := DamageOwner.new()
	var owner_b := DamageOwner.new()
	root_a.add_child(owner_a)
	root_b.add_child(owner_b)
	_make_runtime_enemy(root_a, Vector2(500.0, 0.0))
	_make_runtime_enemy(root_b, Vector2.ZERO)
	current_scene = root_a
	var first_hits: int = DamageResolver.damage_enemies_in_radius(owner_a, Vector2.ZERO, 24.0, 10.0, 0.0, 1.0, 0.0, "swordsman")
	current_scene = root_b
	var second_hits: int = DamageResolver.damage_enemies_in_radius(owner_b, Vector2.ZERO, 24.0, 10.0, 0.0, 1.0, 0.0, "swordsman")
	if first_hits != 0 or second_hits != 1:
		failures.append("resolver frame caches should be isolated per current scene")
	root_a.queue_free()
	root_b.queue_free()

class DamageOwner:
	extends Node2D

	var damage_calls := 0
	var register_calls := 0

	func _deal_damage_to_enemy(_enemy: Node, _damage_amount: float, _source_role_id: String, _vulnerability_bonus: float = 0.0, _vulnerability_duration: float = 2.0, _slow_multiplier: float = 1.0, _slow_duration: float = 0.0, _source_position: Variant = null) -> bool:
		damage_calls += 1
		return false

	func _get_enemy_hit_radius(enemy: Node) -> float:
		return float(enemy.get("contact_radius"))

	func _register_attack_result(_role_id: String, _hit_count: int, _killed: bool) -> void:
		register_calls += 1

	func _get_active_role() -> Dictionary:
		return {"id": "swordsman"}

class TestEnemy:
	extends Node2D

	var contact_radius: float = 8.0

class FreeingDamageOwner:
	extends DamageOwner

	var enemy_to_free: Node

	func _deal_damage_to_enemy(enemy: Node, _damage_amount: float, _source_role_id: String, _vulnerability_bonus: float = 0.0, _vulnerability_duration: float = 2.0, _slow_multiplier: float = 1.0, _slow_duration: float = 0.0, _source_position: Variant = null) -> bool:
		damage_calls += 1
		if enemy == enemy_to_free and is_instance_valid(enemy):
			enemy.queue_free()
		return false

class RuntimeEnemyRoot:
	extends Node

	var enemies: Array = []

	func get_runtime_enemies() -> Array:
		return enemies
