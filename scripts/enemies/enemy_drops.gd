extends RefCounted

const PICKUP_COMPACTOR := preload("res://scripts/game/pickup_compactor.gd")

const HEART_DROP_CHANCE := 0.012
const HEART_DROP_CHANCE_ELITE := 0.02
const HEART_DROP_CHANCE_BOSS := 0.044

static func drop_experience_gem(enemy) -> void:
	if enemy.exp_gem_scene == null:
		return

	var current_scene: Node = _get_enemy_current_scene(enemy)
	if current_scene == null:
		return

	if PICKUP_COMPACTOR.should_merge_new_exp_gem(current_scene):
		if PICKUP_COMPACTOR.merge_exp_value_into_existing(current_scene, enemy.global_position, enemy.experience_reward, enemy.reward_tier):
			return

	var gem: Node = _take_pickup_from_pool(current_scene, "exp_gems")
	if gem == null:
		gem = enemy.exp_gem_scene.instantiate()
	if gem == null:
		return

	current_scene.add_child(gem)
	if gem.has_method("reset_pickup"):
		gem.reset_pickup(enemy.global_position, enemy.reward_tier, enemy.experience_reward)
	elif gem.has_method("configure"):
		gem.global_position = enemy.global_position
		gem.configure(enemy.reward_tier, enemy.experience_reward)
	else:
		gem.global_position = enemy.global_position
		gem.value = enemy.experience_reward

static func maybe_drop_heart(enemy) -> void:
	if enemy.heart_pickup_scene == null:
		return

	var drop_chance := get_heart_drop_chance(enemy.enemy_kind)
	if randf() > drop_chance:
		return

	var current_scene: Node = _get_enemy_current_scene(enemy)
	if current_scene == null:
		return

	var spawn_position: Vector2 = enemy.global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0))
	if PICKUP_COMPACTOR.should_merge_new_heart(current_scene):
		if PICKUP_COMPACTOR.merge_heal_into_existing(current_scene, spawn_position, 50.0):
			return

	var heart_pickup: Node = _take_pickup_from_pool(current_scene, "heart_pickups")
	if heart_pickup == null:
		heart_pickup = enemy.heart_pickup_scene.instantiate()
	if heart_pickup == null:
		return

	current_scene.add_child(heart_pickup)
	if heart_pickup.has_method("reset_pickup"):
		heart_pickup.reset_pickup(spawn_position, 50.0)
	else:
		heart_pickup.global_position = spawn_position

static func get_heart_drop_chance(enemy_kind: String) -> float:
	match enemy_kind:
		"elite":
			return HEART_DROP_CHANCE_ELITE
		"boss":
			return HEART_DROP_CHANCE_BOSS
		_:
			return HEART_DROP_CHANCE

static func _take_pickup_from_pool(current_scene: Node, group_name: String) -> Node:
	if current_scene != null and current_scene.has_method("take_runtime_pickup_from_pool"):
		var pickup: Node = current_scene.take_runtime_pickup_from_pool(group_name) as Node
		if pickup != null and is_instance_valid(pickup):
			return pickup
	return null

static func _get_enemy_current_scene(enemy) -> Node:
	if enemy == null or not is_instance_valid(enemy):
		return null
	if enemy is Node and not (enemy as Node).is_inside_tree():
		return null
	var tree: SceneTree = enemy.get_tree()
	if tree == null:
		return null
	return tree.current_scene
