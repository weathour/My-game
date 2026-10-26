extends RefCounted

const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")
const SPAWN_POSITION_FLOW := preload("res://scripts/game/enemy_spawn_position_flow.gd")
const ENEMY_BOSS_STATE := preload("res://scripts/enemies/enemy_boss_state.gd")
const DIFFICULTY_PROFILE := preload("res://scripts/game/difficulty_profile.gd")

const GLOBAL_ENEMY_HEALTH_MULTIPLIER := 2.04
const GLOBAL_ENEMY_PROJECTILE_DAMAGE_MULTIPLIER := 2.0
const NORMAL_WAVE_HEALTH_END_MULTIPLIER := 10.0
const N5_NORMAL_WAVE_HEALTH_END_MULTIPLIER := 16.0


static func spawn_configured_enemy_at_position(main: Node, kind: String, archetype: String, health_multiplier: float, speed_multiplier: float, spawn_position: Vector2, damage_multiplier: float = 1.0) -> Node2D:
	if archetype == "necro_priest":
		var priest := preload("res://scripts/enemies/enemy_necro_priest.gd")
		if priest.living(main).size() >= priest.LIMIT:
			return null
		spawn_position = priest.spawn_position(main)
	if archetype == "skull_mage" and not preload("res://scripts/enemies/enemy_skull_mage.gd").can_spawn(main):
		return null
	if kind == "normal" and main.has_method("_can_spawn_runtime_group") and not bool(main._can_spawn_runtime_group("enemies", main.ENEMY_SPAWN_FLOW.get_runtime_enemy_limit(main))):
		return null
	# 在取池/实例化之前拒绝内容拼写错误，避免生成默认怪或遗留半初始化对象。
	if not preload("res://scripts/enemy/enemy_archetype_database.gd").PROFILE_PATHS.has(archetype):
		push_error("Unknown authored enemy archetype: %s" % archetype)
		return null
	var profile: Dictionary = main.ENEMY_SPAWN_FLOW.get_enemy_profile(main, kind, archetype)
	if profile.is_empty():
		push_error("Enemy profile could not load: %s" % archetype)
		return null
	var enemy: Variant = take_enemy_from_pool(main, kind)
	if enemy == null:
		enemy = main.enemy_scene.instantiate()
	if enemy == null:
		return null

	enemy.target = main.player
	enemy.projectile_scene = main.enemy_bullet_scene
	enemy.heart_pickup_scene = main.heart_pickup_scene
	if enemy.has_method("apply_enemy_profile"):
		enemy.apply_enemy_profile(kind, profile)
	var waves = main.get("wave_flow")
	if kind == "small_boss" and is_instance_valid(waves) and waves.PLAN.SMALL_BOSS_EXPERIENCE.has(int(waves.wave)):
		enemy.experience_reward = int(waves.PLAN.SMALL_BOSS_EXPERIENCE[int(waves.wave)])
	if kind == "normal" and is_instance_valid(waves) and waves.phase == "combat" and int(waves.wave) in waves.PLAN.REWARD_WAVES:
		enemy.experience_reward = maxi(1, roundi(float(enemy.experience_reward) * 1.5))
	var uses_authored_boss_stats: bool = kind == "boss" and archetype == "boss_spellcore"
	var wave_health_multiplier := _get_normal_wave_health_multiplier(main, kind, waves)
	enemy.max_health *= health_multiplier * wave_health_multiplier * (1.0 if uses_authored_boss_stats else GLOBAL_ENEMY_HEALTH_MULTIPLIER)
	if kind == "boss":
		enemy.current_health = ENEMY_BOSS_STATE.get_boss_spawn_health(enemy)
	else:
		enemy.current_health = enemy.max_health
	enemy.speed *= speed_multiplier
	var attack_multiplier := damage_multiplier
	if uses_authored_boss_stats and bool(main.get("endless_mode_active")):
		# N1 is the authored attack baseline; retain relative N-tier growth.
		attack_multiplier /= float(DIFFICULTY_PROFILE.PROFILES["easy"]["enemy_damage_scale"])
	enemy.attack *= attack_multiplier
	enemy.touch_damage *= damage_multiplier
	enemy.projectile_damage *= damage_multiplier * GLOBAL_ENEMY_PROJECTILE_DAMAGE_MULTIPLIER
	if enemy.has_signal("defeated"):
		disconnect_enemy_defeated_callbacks(enemy, main)
		enemy.defeated.connect(main._on_enemy_defeated.bind(enemy))

	enemy.global_position = SPAWN_POSITION_FLOW.clamp_position_to_spawn_bounds(main, spawn_position)
	main.add_child(enemy)
	enemy.show()
	enemy.set_process(true)
	enemy.set_physics_process(true)
	if enemy.has_method("activate_pooled_enemy"):
		enemy.activate_pooled_enemy()
	return enemy as Node2D


static func _get_normal_wave_health_multiplier(main: Node, kind: String, waves: Variant) -> float:
	if kind != "normal" or not is_instance_valid(waves) or waves.phase != "combat":
		return 1.0
	var wave: int = clampi(int(waves.wave), 1, 20)
	var profile: Dictionary = main.difficulty_profile if main.get("difficulty_profile") is Dictionary else {}
	var tier: int = int(profile.get("tier", 0))
	# N1-N4 use the 1x -> 10x curve; N5 is intentionally tougher at wave 20.
	var end_multiplier := N5_NORMAL_WAVE_HEALTH_END_MULTIPLIER if tier >= 5 else NORMAL_WAVE_HEALTH_END_MULTIPLIER
	return pow(end_multiplier, float(wave - 1) / 19.0)


static func take_enemy_from_pool(main: Node, kind: String) -> Node:
	if kind != "normal":
		return null
	if main != null and main.has_method("take_runtime_enemy_from_pool"):
		var enemy: Node = main.take_runtime_enemy_from_pool()
		if enemy != null and is_instance_valid(enemy):
			return enemy
	return null


static func disconnect_enemy_defeated_callbacks(enemy: Node, main: Node) -> void:
	if enemy == null or main == null or not enemy.has_signal("defeated"):
		return
	for connection in enemy.defeated.get_connections():
		if connection is not Dictionary:
			continue
		var callback: Callable = (connection as Dictionary).get("callable", Callable())
		if callback.is_null():
			continue
		if callback.get_object() == main and callback.get_method() == "_on_enemy_defeated":
			enemy.defeated.disconnect(callback)
