extends RefCounted


static func append_group_save_data(main: Node, save_data: Dictionary, save_key: String, group_name: String) -> void:
	for node in get_runtime_or_group_nodes(main, group_name):
		if is_instance_valid(node) and node.has_method("get_save_data"):
			(save_data[save_key] as Array).append(node.get_save_data())


static func get_runtime_or_group_nodes(main: Node, group_name: String) -> Array:
	if main == null or main.get_tree() == null:
		return []
	if group_name == "enemies" and main.has_method("get_runtime_enemies"):
		return main.get_runtime_enemies()
	if group_name == "enemy_projectiles" and main.has_method("get_runtime_enemy_projectiles"):
		return main.get_runtime_enemy_projectiles()
	if (group_name == "exp_gems" or group_name == "heart_pickups") and main.has_method("get_runtime_pickups"):
		return main.get_runtime_pickups(group_name)
	return main.get_tree().get_nodes_in_group(group_name)


static func restore_enemies(main: Node, enemies_data: Array) -> void:
	for enemy_data in enemies_data:
		var enemy = main.enemy_scene.instantiate()
		if enemy == null:
			continue
		main.add_child(enemy)
		enemy.projectile_scene = main.enemy_bullet_scene
		enemy.heart_pickup_scene = main.heart_pickup_scene
		enemy.apply_save_data(enemy_data, main.player)
		if enemy.has_signal("defeated"):
			enemy.defeated.connect(main._on_enemy_defeated.bind(enemy))
		var loaded_enemy_kind: String = str(enemy_data.get("enemy_kind", "normal"))
		if loaded_enemy_kind == "boss":
			main.boss_enemy = enemy
			main.boss_spawned = true
		elif loaded_enemy_kind == "small_boss" and main.boss_enemy == null:
			main.boss_enemy = enemy


static func restore_enemy_projectiles(main: Node, projectiles_data: Array) -> void:
	for projectile_data in projectiles_data:
		var projectile = main.enemy_bullet_scene.instantiate()
		if projectile == null:
			continue
		main.add_child(projectile)
		projectile.apply_save_data(projectile_data, main.player)


static func restore_gems(main: Node, gems_data: Array) -> void:
	for gem_data in gems_data:
		var gem = main.exp_gem_scene.instantiate()
		if gem == null:
			continue
		main.add_child(gem)
		gem.apply_save_data(gem_data)


static func restore_heart_pickups(main: Node, hearts_data: Array) -> void:
	for heart_data in hearts_data:
		var heart_pickup = main.heart_pickup_scene.instantiate()
		if heart_pickup == null:
			continue
		main.add_child(heart_pickup)
		heart_pickup.apply_save_data(heart_data)
