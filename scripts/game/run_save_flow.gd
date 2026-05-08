extends RefCounted

const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")

static func save_run_state(main: Node) -> void:
	if main.game_over or main.player == null or DEVELOPER_MODE.should_disable_save():
		return

	var game_bgm = main._get_game_bgm()
	var music_position: float = 0.0
	if game_bgm != null and game_bgm.has_method("get_saved_playback_position"):
		music_position = float(game_bgm.get_saved_playback_position())

	var save_data: Dictionary = {
		"survival_time": main.survival_time,
		"music_position": music_position,
		"spawned_elite_count": main.spawned_elite_count,
		"spawned_small_boss_count": main.spawned_small_boss_count,
		"boss_spawned": main.boss_spawned,
		"defeated_boss_count": main.defeated_boss_count,
		"player": main.player.get_save_data(),
		"enemies": [],
		"enemy_projectiles": [],
		"gems": [],
		"heart_pickups": []
	}

	for enemy in _get_runtime_or_group_nodes(main, "enemies"):
		if is_instance_valid(enemy) and enemy.has_method("get_save_data"):
			save_data["enemies"].append(enemy.get_save_data())

	for projectile in _get_runtime_or_group_nodes(main, "enemy_projectiles"):
		if is_instance_valid(projectile) and projectile.has_method("get_save_data"):
			save_data["enemy_projectiles"].append(projectile.get_save_data())

	for gem in _get_runtime_or_group_nodes(main, "exp_gems"):
		if is_instance_valid(gem) and gem.has_method("get_save_data"):
			save_data["gems"].append(gem.get_save_data())

	for heart_pickup in _get_runtime_or_group_nodes(main, "heart_pickups"):
		if is_instance_valid(heart_pickup) and heart_pickup.has_method("get_save_data"):
			save_data["heart_pickups"].append(heart_pickup.get_save_data())

	SAVE_MANAGER.save_run(save_data)

static func _get_runtime_or_group_nodes(main: Node, group_name: String) -> Array:
	if main == null or main.get_tree() == null:
		return []
	if group_name == "enemies" and main.has_method("get_runtime_enemies"):
		return main.get_runtime_enemies()
	if group_name == "enemy_projectiles" and main.has_method("get_runtime_enemy_projectiles"):
		return main.get_runtime_enemy_projectiles()
	if (group_name == "exp_gems" or group_name == "heart_pickups") and main.has_method("get_runtime_pickups"):
		return main.get_runtime_pickups(group_name)
	return main.get_tree().get_nodes_in_group(group_name)

static func load_saved_run(main: Node) -> bool:
	if main._is_developer_mode():
		return false
	var save_data := SAVE_MANAGER.load_run()
	if save_data.is_empty():
		return false

	main.survival_time = float(save_data.get("survival_time", 0.0))
	main.autosave_elapsed = 0.0
	main.spawned_elite_count = int(save_data.get("spawned_elite_count", 0))
	main.spawned_small_boss_count = int(save_data.get("spawned_small_boss_count", 0))
	main.boss_spawned = bool(save_data.get("boss_spawned", false))
	main.defeated_boss_count = int(save_data.get("defeated_boss_count", 0))
	main.boss_enemy = null

	main.player.apply_save_data(save_data.get("player", {}))
	_restore_enemies(main, save_data.get("enemies", []))
	_restore_enemy_projectiles(main, save_data.get("enemy_projectiles", []))
	_restore_gems(main, save_data.get("gems", []))
	_restore_heart_pickups(main, save_data.get("heart_pickups", []))

	var game_bgm = main._get_game_bgm()
	if game_bgm != null and game_bgm.has_method("restore_playback_position"):
		game_bgm.restore_playback_position(float(save_data.get("music_position", 0.0)))

	main._refresh_hud()
	save_run_state(main)
	return true

static func _restore_enemies(main: Node, enemies_data: Array) -> void:
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
		var loaded_enemy_kind := str(enemy_data.get("enemy_kind", "normal"))
		if loaded_enemy_kind == "boss":
			main.boss_enemy = enemy
			main.boss_spawned = true
		elif loaded_enemy_kind == "small_boss" and main.boss_enemy == null:
			main.boss_enemy = enemy

static func _restore_enemy_projectiles(main: Node, projectiles_data: Array) -> void:
	for projectile_data in projectiles_data:
		var projectile = main.enemy_bullet_scene.instantiate()
		if projectile == null:
			continue
		main.add_child(projectile)
		projectile.apply_save_data(projectile_data, main.player)

static func _restore_gems(main: Node, gems_data: Array) -> void:
	for gem_data in gems_data:
		var gem = main.exp_gem_scene.instantiate()
		if gem == null:
			continue
		main.add_child(gem)
		gem.apply_save_data(gem_data)

static func _restore_heart_pickups(main: Node, hearts_data: Array) -> void:
	for heart_data in hearts_data:
		var heart_pickup = main.heart_pickup_scene.instantiate()
		if heart_pickup == null:
			continue
		main.add_child(heart_pickup)
		heart_pickup.apply_save_data(heart_data)
