extends RefCounted

const EXPERIENCE_VACUUM_SCENE := preload("res://scenes/experience_vacuum_pickup.tscn")
const SWORDSMAN_GROUND := preload("res://scripts/player/swordsman_ground_crack.gd")
const SKULL_MAGE_DOMAIN := preload("res://scripts/enemies/skull_mage_domain.gd")
const PARASITE_SEED := preload("res://scripts/enemies/parasite_seed.gd")
const PAYLOAD := preload("res://scripts/save/run_payload_validator.gd")

static func restore_parasite_seeds(main: Node, seeds_data: Array) -> bool:
	if not PAYLOAD.error({"player": {}, "parasite_seeds": seeds_data}).is_empty():
		return false
	for data in seeds_data:
		var seed := PARASITE_SEED.new()
		main.add_child(seed)
		seed.apply_save_data(data, main.player)
	return true


static func restore_skull_mage_domains(main: Node, fields_data: Array) -> bool:
	if not PAYLOAD.error({"player": {}, "skull_mage_domains": fields_data}).is_empty():
		return false
	for data in fields_data:
		var field := SKULL_MAGE_DOMAIN.new()
		field.player = main.player
		field.position = Vector2(float(data["position"][0]), float(data["position"][1]))
		field.remaining = clampf(float(data.get("remaining", 0.0)), 0.0, 10.0)
		if field.remaining > 0:
			main.add_child(field)
		else:
			field.free()
	return true


static func restore_swordsman_ground_cracks(main: Node, cracks_data: Array) -> bool:
	if not PAYLOAD.error({"player": {}, "swordsman_ground_cracks": cracks_data}).is_empty():
		return false
	for data in cracks_data:
		var crack := SWORDSMAN_GROUND.new()
		main.add_child(crack)
		crack.apply_save_data(data, main.player)
	return true


static func append_group_save_data(main: Node, save_data: Dictionary, save_key: String, group_name: String) -> void:
	for node in get_runtime_or_group_nodes(main, group_name):
		if is_instance_valid(node) and node.has_meta("wave_cleanup"):
			continue
		if is_instance_valid(node) and node.has_method("get_save_data"):
			(save_data[save_key] as Array).append(node.get_save_data())


static func get_runtime_or_group_nodes(main: Node, group_name: String) -> Array:
	if main == null or main.get_tree() == null:
		return []
	if group_name == "enemies" and main.has_method("get_runtime_enemies"):
		return main.get_runtime_enemies()
	if group_name == "enemy_projectiles" and main.has_method("get_runtime_enemy_projectiles"):
		return main.get_runtime_enemy_projectiles()
	if group_name in ["exp_gems", "heart_pickups", "bone_pickups", "experience_vacuum_pickups"] and main.has_method("get_runtime_pickups"):
		return main.get_runtime_pickups(group_name)
	return main.get_tree().get_nodes_in_group(group_name)


static func restore_enemies(main: Node, enemies_data: Array) -> bool:
	if not PAYLOAD.error({"player": {}, "enemies": enemies_data}).is_empty():
		return false
	for enemy_data in enemies_data:
		if main.enemy_scene == null:
			return false
		var enemy = main.enemy_scene.instantiate()
		if enemy == null:
			return false
		main.add_child(enemy)
		enemy.projectile_scene = main.enemy_bullet_scene
		enemy.heart_pickup_scene = main.heart_pickup_scene
		if not enemy.apply_save_data(enemy_data, main.player):
			return false
		if enemy.has_signal("defeated"):
			enemy.defeated.connect(main._on_enemy_defeated.bind(enemy))
		var loaded_enemy_kind: String = str(enemy_data.get("enemy_kind", "normal"))
		if loaded_enemy_kind == "boss":
			main.boss_enemy = enemy
			main.boss_spawned = true
		elif loaded_enemy_kind == "small_boss":
			main.small_boss_enemy = enemy
	return true


static func restore_enemy_projectiles(main: Node, projectiles_data: Array) -> bool:
	if not PAYLOAD.error({"player": {}, "enemy_projectiles": projectiles_data}).is_empty():
		return false
	for projectile_data in projectiles_data:
		if main.enemy_bullet_scene == null:
			return false
		var projectile = main.enemy_bullet_scene.instantiate()
		if projectile == null:
			return false
		main.add_child(projectile)
		projectile.apply_save_data(projectile_data, main.player)
	return true


static func restore_gems(main: Node, gems_data: Array) -> bool:
	if not PAYLOAD.error({"player": {}, "gems": gems_data}).is_empty():
		return false
	for gem_data in gems_data:
		if main.exp_gem_scene == null:
			return false
		var gem = main.exp_gem_scene.instantiate()
		if gem == null:
			return false
		main.add_child(gem)
		gem.apply_save_data(gem_data)
		if bool(gem_data.get("attraction_active", false)) and is_instance_valid(main.player):
			gem.set_attraction_target(main.player)
			gem.attraction_speed = clampf(float(gem_data.get("attraction_speed", gem.ATTRACT_START_SPEED)), gem.ATTRACT_START_SPEED, gem.ATTRACT_MAX_SPEED)
	return true


static func restore_experience_vacuum_pickups(main: Node, pickups_data: Array) -> bool:
	if not PAYLOAD.error({"player": {}, "experience_vacuum_pickups": pickups_data}).is_empty():
		return false
	for pickup_data in pickups_data:
		var pickup := EXPERIENCE_VACUUM_SCENE.instantiate()
		if pickup == null:
			return false
		main.add_child(pickup)
		pickup.apply_save_data(pickup_data)
	return true


static func restore_heart_pickups(main: Node, hearts_data: Array) -> bool:
	if not PAYLOAD.error({"player": {}, "heart_pickups": hearts_data}).is_empty():
		return false
	for heart_data in hearts_data:
		if main.heart_pickup_scene == null:
			return false
		var heart_pickup = main.heart_pickup_scene.instantiate()
		if heart_pickup == null:
			return false
		main.add_child(heart_pickup)
		heart_pickup.apply_save_data(heart_data)
	return true


static func restore_bone_pickups(main: Node, bones_data: Array) -> bool:
	if not PAYLOAD.error({"player": {}, "bone_pickups": bones_data}).is_empty():
		return false
	for index in bones_data.size():
		var bone_data: Dictionary = bones_data[index].duplicate(true)
		if not bone_data.has("pickup_id"):
			bone_data.pickup_id = "legacy:%d" % index
		if main.bone_pickup_scene == null:
			return false
		var bone_pickup = main.bone_pickup_scene.instantiate()
		if bone_pickup == null:
			return false
		main.add_child(bone_pickup)
		bone_pickup.apply_save_data(bone_data)
	return true
