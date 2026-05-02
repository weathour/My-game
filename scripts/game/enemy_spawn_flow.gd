extends RefCounted

const ENEMY_DIRECTOR := preload("res://scripts/enemy/enemy_director.gd")
const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")

static func setup_spawn_timer(main: Node) -> void:
	main.spawn_timer = Timer.new()
	main.spawn_timer.wait_time = ENEMY_DIRECTOR.get_default_starting_spawn_interval()
	main.spawn_timer.one_shot = false
	main.spawn_timer.autostart = true
	main.spawn_timer.timeout.connect(Callable(main, "_spawn_enemy"))
	main.add_child(main.spawn_timer)

static func update_spawn_curve(main: Node) -> void:
	if main.spawn_timer == null:
		return
	if main._is_developer_mode():
		main.spawn_timer.stop()
		return
	if main.boss_spawned and is_instance_valid(main.boss_enemy):
		main.spawn_timer.stop()
		return

	var wave_profile := get_wave_profile(main)
	var minimum_spawn_interval := ENEMY_DIRECTOR.get_default_minimum_spawn_interval()
	if main.has_method("_get_difficulty_minimum_spawn_interval_multiplier"):
		minimum_spawn_interval *= max(0.2, float(main._get_difficulty_minimum_spawn_interval_multiplier()))
	var target_interval: float = ENEMY_DIRECTOR.get_spawn_interval(
		ENEMY_DIRECTOR.get_default_starting_spawn_interval(),
		minimum_spawn_interval,
		main.survival_time,
		main._get_effective_stage_curve_time(),
		wave_profile,
		main._get_story_spawn_interval_multiplier() * main._get_difficulty_spawn_interval_multiplier()
	)
	main.spawn_timer.wait_time = target_interval
	if main.spawn_timer.is_stopped() and not main.game_over:
		main.spawn_timer.start()

static func handle_stage_events(main: Node) -> void:
	if main._is_developer_mode():
		return
	var stage_events: Array = ENEMY_DIRECTOR.collect_stage_events(
		main.survival_time,
		ENEMY_DIRECTOR.get_default_elite_spawn_times(),
		main.spawned_elite_count,
		ENEMY_DIRECTOR.get_default_small_boss_spawn_times(),
		main.spawned_small_boss_count,
		main.boss_spawned,
		main._get_effective_boss_spawn_time(),
		has_active_special_enemy(main, "small_boss"),
		main.story_stage,
		main.story_mode_active,
		main.stage_cleared,
		main.endless_mode_active,
		ENEMY_DIRECTOR.get_default_boss_spawn_time()
	)
	for stage_event in stage_events:
		match str(stage_event.get("type", "")):
			"clear_stage":
				main._on_stage_cleared()
				return
			"elite":
				spawn_special_enemy(main, "elite")
				main.spawned_elite_count += 1
			"small_boss":
				main.boss_enemy = spawn_special_enemy(main, "small_boss")
				main.spawned_small_boss_count += 1
			"boss":
				main.boss_spawned = true
				main.boss_enemy = spawn_special_enemy(main, "boss")
				if main.spawn_timer != null:
					main.spawn_timer.stop()

static func spawn_enemy(main: Node) -> void:
	if main.game_over or main.enemy_scene == null or main.player == null or main._is_developer_mode() or (main.boss_spawned and is_instance_valid(main.boss_enemy)):
		return

	var health_multiplier: float = main._get_spawn_enemy_health_multiplier("normal")
	var speed_multiplier: float = main._get_spawn_enemy_speed_multiplier()
	var damage_multiplier: float = main._get_spawn_enemy_damage_multiplier()
	var wave_profile := get_wave_profile(main)
	var spawn_pack: Dictionary = ENEMY_DIRECTOR.pick_spawn_pack(wave_profile, main.rng)
	var requested_count := int(spawn_pack.get("count", 1))
	var count := requested_count
	if main.has_method("_trim_spawn_count_for_group"):
		count = int(main._trim_spawn_count_for_group("enemies", requested_count, PERFORMANCE_GUARD.DEFAULT_ACTIVE_ENEMY_LIMIT))
	if count <= 0:
		return
	spawn_wave_pack(
		main,
		"normal",
		str(spawn_pack.get("archetype", "chaser")),
		count,
		health_multiplier,
		speed_multiplier,
		damage_multiplier
	)

static func spawn_special_enemy(main: Node, kind: String) -> Node2D:
	var health_multiplier: float = main._get_spawn_enemy_health_multiplier(kind)
	var speed_multiplier: float = main._get_spawn_enemy_speed_multiplier()
	var damage_multiplier: float = main._get_spawn_enemy_damage_multiplier()
	var archetype := ENEMY_DIRECTOR.pick_special_archetype(kind, main.survival_time, main.spawned_small_boss_count, main.rng)
	return spawn_configured_enemy(main, kind, archetype, health_multiplier, speed_multiplier, INF, 0.0, damage_multiplier)

static func spawn_wave_pack(main: Node, kind: String, archetype: String, count: int, health_multiplier: float, speed_multiplier: float, damage_multiplier: float = 1.0) -> void:
	var spawn_layout: Array = ENEMY_DIRECTOR.pick_wave_spawn_layout(count, main.rng)
	for spawn_entry in spawn_layout:
		spawn_configured_enemy(
			main,
			kind,
			archetype,
			health_multiplier,
			speed_multiplier,
			float(spawn_entry.get("angle", 0.0)),
			float(spawn_entry.get("distance_offset", 0.0)),
			damage_multiplier
		)

static func spawn_configured_enemy(main: Node, kind: String, archetype: String, health_multiplier: float, speed_multiplier: float, spawn_angle: float = INF, distance_offset: float = 0.0, damage_multiplier: float = 1.0) -> Node2D:
	if kind == "normal" and main.has_method("_can_spawn_runtime_group") and not bool(main._can_spawn_runtime_group("enemies", PERFORMANCE_GUARD.DEFAULT_ACTIVE_ENEMY_LIMIT)):
		return null
	var enemy = main.enemy_scene.instantiate()
	if enemy == null:
		return null

	enemy.target = main.player
	enemy.projectile_scene = main.enemy_bullet_scene
	enemy.heart_pickup_scene = main.heart_pickup_scene
	if enemy.has_method("apply_enemy_profile"):
		enemy.apply_enemy_profile(kind, get_enemy_profile(main, kind, archetype))
	enemy.max_health *= health_multiplier
	enemy.current_health = enemy.max_health
	enemy.speed *= speed_multiplier
	enemy.touch_damage *= damage_multiplier
	enemy.projectile_damage *= damage_multiplier
	if enemy.has_signal("defeated"):
		enemy.defeated.connect(main._on_enemy_defeated.bind(enemy))

	var angle: float = spawn_angle if is_finite(spawn_angle) else main.rng.randf_range(0.0, TAU)
	var distance: float = ENEMY_DIRECTOR.get_spawn_distance(kind, main.spawn_distance, distance_offset)
	enemy.global_position = get_spawn_position(main, angle, distance)
	main.add_child(enemy)
	return enemy

static func get_wave_profile(main: Node) -> Dictionary:
	var profile := ENEMY_DIRECTOR.get_wave_profile(
		main.survival_time,
		ENEMY_DIRECTOR.get_default_elite_spawn_times(),
		get_player_growth_score(main),
		get_expected_growth_score(main)
	)
	if main.has_method("_apply_difficulty_to_wave_profile"):
		return main._apply_difficulty_to_wave_profile(profile)
	return profile

static func get_player_growth_score(main: Node) -> float:
	if main.player == null:
		return 0.0

	var summary: Dictionary = {}
	if main.player.has_method("get_stat_summary"):
		summary = main.player.get_stat_summary()

	return ENEMY_DIRECTOR.get_player_growth_score(
		int(main.player.level),
		summary,
		main.player.slot_resonances_unlocked,
		main.player.elite_relics_unlocked
	)

static func get_expected_growth_score(main: Node) -> float:
	return ENEMY_DIRECTOR.get_expected_growth_score(main.survival_time, ENEMY_DIRECTOR.get_default_boss_spawn_time())

static func get_spawn_position(main: Node, angle: float, distance: float) -> Vector2:
	return main.player.global_position + Vector2.RIGHT.rotated(angle) * max(180.0, distance)

static func get_enemy_profile(main: Node, kind: String, archetype: String) -> Dictionary:
	var profile := ENEMY_ARCHETYPE_DATABASE.get_profile(kind, archetype)
	if main != null and main.has_method("_apply_difficulty_to_enemy_profile"):
		return main._apply_difficulty_to_enemy_profile(kind, profile)
	return profile

static func has_active_special_enemy(main: Node, kind: String) -> bool:
	if main.boss_enemy == null or not is_instance_valid(main.boss_enemy):
		return false
	return str(main.boss_enemy.get("enemy_kind")) == kind
