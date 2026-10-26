extends SceneTree

# Manual benchmark: use isolated /tmp XDG data and MY_GAME_BENCHMARK_ISOLATED=1.
const MAIN := preload("res://scenes/main.tscn")
const SAVE := preload("res://scripts/save_manager.gd")
const DEVELOPER := preload("res://scripts/developer_mode.gd")
const RECORDER := preload("res://scripts/game/performance_recorder.gd")
const COUNTERS := preload("res://scripts/game/performance_counters.gd")
const RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const PROJECTILES := preload("res://scripts/enemies/enemy_projectiles.gd")
const ROUTINE := preload("res://scripts/enemies/enemy_boss_routine.gd")
const SEED := 271828
const POOL := ["chaser", "runner", "brute", "shooter", "dasher", "shadow_tree", "vine", "skull_mage"]

var quick := false
var diagnostic := false
var failures: Array[String] = []
var output_path := "user://battle_lifecycle_benchmark.json"

func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--quick":
			quick = true
		elif argument == "--diagnostic":
			diagnostic = true
		elif argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	call_deferred("_run")

func _require(value: bool, message: String) -> bool:
	if not value:
		failures.append(message)
		push_error(message)
	return value

func _run() -> void:
	if not _require(OS.get_environment("MY_GAME_BENCHMARK_ISOLATED") == "1" and ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "Benchmark requires explicit isolated /tmp user data; normal saves must not be touched"):
		quit(1)
		return
	Engine.max_fps = 120
	DEVELOPER.deactivate()
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	SAVE.set_active_endless_slot(3)
	var profile := SAVE.create_or_load_endless_profile(3)
	if not _require(not profile.is_empty(), "isolated benchmark profile"):
		quit(1)
		return
	profile.team_order = ["gunner", "swordsman", "mage"]
	SAVE.save_endless_profile(profile)
	var reports: Array[Dictionary] = []
	var after_exit: Array[Dictionary] = []
	for cycle in range(1 if diagnostic else 2 if quick else 10):
		seed(SEED)
		SAVE.clear_save(-1, SAVE.MODE_ENDLESS)
		var main = MAIN.instantiate()
		root.add_child(main)
		current_scene = main
		main.rng.seed = SEED
		main.player.switch_invulnerability_remaining = 10000.0
		main.wave_flow.spawn_remaining = 60.0
		main.set_meta(&"_profile_boss_projectiles", true)
		var spawn_started := Time.get_ticks_usec()
		_configure_workload(main)
		var spawn_burst_ms := float(Time.get_ticks_usec() - spawn_started) / 1000.0
		var drain_started := Time.get_ticks_usec()
		for frame in range(120):
			if main.get_pending_enemy_spawn_count() == 0:
				break
			await process_frame
		_require(main.get_pending_enemy_spawn_count() == 0, "controlled spawn queue must drain")
		var spawn_drain_wall_ms := float(Time.get_ticks_usec() - drain_started) / 1000.0
		for frame in range(15 if quick or cycle > 0 else 120):
			await process_frame
		var report := await _sample(main, 60 if quick else 360 if cycle == 0 else 30)
		report.cycle = cycle + 1
		report.spawn_burst_cpu_ms = spawn_burst_ms
		report.spawn_queue_drain_wall_ms = spawn_drain_wall_ms
		main.suppress_exit_save = true
		var cleanup_started := Time.get_ticks_usec()
		main.free()
		report.scene_destroy_cpu_ms = float(Time.get_ticks_usec() - cleanup_started) / 1000.0
		current_scene = null
		await process_frame
		await process_frame
		report.after_exit_2_frames = _objects()
		for frame in range(28):
			await process_frame
		report.after_exit = _objects()
		after_exit.append(report.after_exit)
		reports.append(report)
		print("BATTLE_LIFECYCLE_CYCLE ", JSON.stringify({"cycle":cycle + 1, "wall_frame_ms":report.wall_frame_ms, "after_exit":report.after_exit}))
	var stable := false
	if not quick and not diagnostic:
		var last: Dictionary = after_exit.back()
		stable = true
		for row: Dictionary in after_exit.slice(-3):
			for key in ["nodes", "orphans", "resources"]:
				stable = stable and row[key] == last[key]
		_require(stable, "last three exits must have stable node/orphan/resource counts")
	var result := {"scope":"Controlled real main.tscn frames; invulnerable fixture, not a full 20-wave playthrough or balance test", "engine":Engine.get_version_info().string, "display":DisplayServer.get_name(), "rendering_method":RenderingServer.get_current_rendering_method(), "environment":{"cpu":OS.get_processor_name(),"gpu":RenderingServer.get_video_adapter_name(),"gpu_vendor":RenderingServer.get_video_adapter_vendor(),"gpu_type":RenderingServer.get_video_adapter_type(),"engine_arguments":OS.get_cmdline_args(),"display_environment":OS.get_environment("DISPLAY")}, "quick_function_check":quick, "seed":SEED, "max_fps":Engine.max_fps, "workload":{"queued_normal_enemies":40,"elite_ids":["elite_ram_trail","elite_splitshot"],"boss_id":"boss_spellcore","initial_boss_projectiles":512,"player_bullets_per_12_process_frames":32,"aoe_every_30_process_frames":true}, "cycles":reports,"last_three_exits_stable":stable,"failures":failures}
	result.diagnostic_single_cycle = diagnostic
	result.environment.audio_driver = AudioServer.call("get_driver_name") if AudioServer.has_method("get_driver_name") else "not exposed by AudioServer"
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if _require(file != null, "benchmark output must be writable"):
		file.store_string(JSON.stringify(result, "\t") + "\n")
		file.close()
	print("BATTLE_LIFECYCLE_BENCHMARK_", "OK" if failures.is_empty() else "FAILED", " output=", output_path)
	quit(0 if failures.is_empty() else 1)

func _configure_workload(main: Node) -> void:
	for index in range(40):
		var angle := TAU * float(index) / 40.0
		main.queue_runtime_enemy_spawn({"kind":"normal", "archetype":POOL[index % POOL.size()], "health_multiplier":10.0, "speed_multiplier":1.0,"damage_multiplier":1.0,"spawn_position":Vector2.RIGHT.rotated(angle) * 400.0})
	for archetype in ["elite_ram_trail", "elite_splitshot"]:
		main.ENEMY_SPAWN_FLOW.spawn_special_enemy_with_archetype(main, "elite", archetype)
	var boss = main.ENEMY_SPAWN_FLOW.spawn_special_enemy_with_archetype(main, "boss", "boss_spellcore")
	main.boss_enemy = boss
	main.boss_spawned = true
	boss.global_position = Vector2(540, 0)
	boss.boss_phase = 3
	boss.current_health = boss.max_health / 3.0
	boss.boss_shield_break_intro_played = true
	boss.boss_attack_pressure_scale = 1.65
	ROUTINE.reset(boss, 5)
	boss.boss_routine.stage = "performance"
	for index in range(512):
		PROJECTILES.spawn_projectile(boss, boss.global_position, Vector2.RIGHT.rotated(TAU * float(index) / 512.0), 120.0, 1.0, 8.0, Color(0.6,0.2,0.9), "straight", {"visual_style":"boss_danmaku_violet_orb"})

func _sample(main: Node, frames: int) -> Dictionary:
	var physics_start := Engine.get_physics_frames()
	var survival_start: float = main.survival_time
	var wave_start: Dictionary = main.wave_flow.get_save_data()
	RECORDER.start_session("real_main_frames")
	COUNTERS.frame_index = -1
	COUNTERS.counters.clear()
	COUNTERS.last_frame_snapshot.clear()
	COUNTERS.peak_snapshot.clear()
	var wall_ms: Array[float] = []
	var cpu_ms: Array[float] = []
	var saves_ms: Array[float] = []
	var peak_counts := {"enemies":0,"enemy_projectiles":0,"player_projectiles":0}
	var completed_jobs := 0
	var queued_jobs := 0
	var collision_checks := 0
	var previous_usec := Time.get_ticks_usec()
	for frame in range(frames):
		await process_frame
		var now := Time.get_ticks_usec()
		wall_ms.append(float(now - previous_usec) / 1000.0)
		previous_usec = now
		cpu_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		var counters: Dictionary = COUNTERS.get_snapshot()
		completed_jobs += int(counters.get("completed_damage_jobs", 0))
		queued_jobs += int(counters.get("queued_damage_jobs", 0))
		collision_checks += int(counters.get("player_projectile_collision_checks", 0))
		peak_counts.enemies = maxi(peak_counts.enemies, main.get_runtime_enemies().size())
		peak_counts.enemy_projectiles = maxi(peak_counts.enemy_projectiles, main.get_runtime_enemy_projectiles().size())
		var batch := main.get_node_or_null("PlayerProjectileBatch")
		if batch != null:
			peak_counts.player_projectiles = maxi(peak_counts.player_projectiles, batch.positions.size())
		if frame % 12 == 0:
			for index in range(32):
				main.player._spawn_batched_directional_bullet_values(Vector2.RIGHT.rotated(TAU * float(index) / 32.0), 1.0, Color(1,0.5,0.2), "gunner", null, 620.0, 3.0, 2.0)
			batch = main.get_node_or_null("PlayerProjectileBatch")
			if batch != null:
				peak_counts.player_projectiles = maxi(peak_counts.player_projectiles, batch.positions.size())
		if frame % 30 == 0:
			RESOLVER.damage_enemies_in_radius_batched(main.player, main.player.global_position, 1000.0, 1.0, 0.0, 1.0, 0.0, "gunner")
		if frame in [frames / 4, frames * 3 / 4]:
			var started := Time.get_ticks_usec()
			main._save_run_state()
			saves_ms.append(float(Time.get_ticks_usec() - started) / 1000.0)
			_require(bool(main.get_meta("last_run_save_ok", false)), "measured real save must succeed")
	_require(not main.game_over and not paused, "benchmark must remain a running battle")
	var engine_delta_snapshot := RECORDER.stop_session()
	return {"wall_frame_ms":RECORDER._build_snapshot(wall_ms),"engine_process_cpu_ms":RECORDER._build_snapshot(cpu_ms),"real_main_recorder":engine_delta_snapshot,"explicit_save_cpu_ms":saves_ms,"peak_entities":peak_counts,"queued_damage_jobs":queued_jobs,"completed_damage_jobs":completed_jobs,"player_collision_checks":collision_checks,"counter_peaks":COUNTERS.get_snapshot().peak,"running_scene_objects":_objects(),"path_history_allocated":false,"physics_steps":Engine.get_physics_frames() - physics_start,"survival_time_start":survival_start,"survival_time_end":main.survival_time,"wave_start":wave_start,"wave_end":main.wave_flow.get_save_data()}

func _objects() -> Dictionary:
	return {"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"static_memory_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC))}
