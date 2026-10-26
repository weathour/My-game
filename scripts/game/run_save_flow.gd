extends RefCounted

const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const RUN_SAVE_RUNTIME_FLOW := preload("res://scripts/game/run_save_runtime_flow.gd")
const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")
const PERFORMANCE_RECORDER := preload("res://scripts/game/performance_recorder.gd")

static func save_run_state(main: Node) -> bool:
	if main.has_meta("run_restore_failed"):
		main.set_meta("last_run_save_ok", false)
		return false
	if DEVELOPER_MODE.should_disable_save():
		return true
	if main.player == null:
		return false
	if main.game_over and not main.has_meta("pending_story_settlement") and not main.has_meta("pending_run_end"):
		return true
	var save_start_usec: int = Time.get_ticks_usec()
	PERFORMANCE_RECORDER.begin_scope("save_run_ms")

	var game_bgm = main._get_game_bgm()
	var music_position: float = 0.0
	if game_bgm != null and game_bgm.has_method("get_saved_playback_position"):
		music_position = float(game_bgm.get_saved_playback_position())

	var save_data: Dictionary = {
		"survival_time": main.survival_time,
		"reward_state": preload("res://scripts/game/reward_flow.gd").get_save_data(main),
		"music_position": music_position,
		"spawned_elite_count": main.spawned_elite_count,
		"spawned_small_boss_count": main.spawned_small_boss_count,
		"boss_spawned": main.boss_spawned,
		"player": main.player.get_save_data(),
		"enemies": [],
		"enemy_projectiles": [],
		"gems": [],
		"heart_pickups": [],
		"bone_pickups": [],
		"experience_vacuum_pickups": [],
		"swordsman_ground_cracks": [],
		"skull_mage_domains": [],
		"parasite_seeds": []
	}
	if main.has_meta("pending_run_end"):
		save_data["pending_run_end"] = main.get_meta("pending_run_end").duplicate(true)
	if main.story_mode_active:
		save_data["story_attempt"] = main.get_meta("story_attempt", {}).duplicate(true)
		if main.has_meta("pending_story_settlement"):
			save_data["pending_settlement"] = main.get_meta("pending_story_settlement").duplicate(true)
	if main.endless_mode_active:
		save_data["run_tier"] = main.endless_tier
		save_data["run_id"] = main.endless_run_id
	if is_instance_valid(main.get("wave_flow")):
		save_data["combat_wave"] = main.wave_flow.get_save_data()

	RUN_SAVE_RUNTIME_FLOW.append_group_save_data(main, save_data, "enemies", "enemies")
	RUN_SAVE_RUNTIME_FLOW.append_group_save_data(main, save_data, "enemy_projectiles", "enemy_projectiles")
	RUN_SAVE_RUNTIME_FLOW.append_group_save_data(main, save_data, "gems", "exp_gems")
	RUN_SAVE_RUNTIME_FLOW.append_group_save_data(main, save_data, "heart_pickups", "heart_pickups")
	RUN_SAVE_RUNTIME_FLOW.append_group_save_data(main, save_data, "bone_pickups", "bone_pickups")
	RUN_SAVE_RUNTIME_FLOW.append_group_save_data(main, save_data, "experience_vacuum_pickups", "experience_vacuum_pickups")
	RUN_SAVE_RUNTIME_FLOW.append_group_save_data(main, save_data, "swordsman_ground_cracks", "swordsman_ground_cracks")
	RUN_SAVE_RUNTIME_FLOW.append_group_save_data(main, save_data, "skull_mage_domains", "skull_mage_domains")
	RUN_SAVE_RUNTIME_FLOW.append_group_save_data(main, save_data, "parasite_seeds", "parasite_seeds")

	var context: Dictionary = main.get_meta("save_context", {})
	var payload_chars: int = int(SAVE_MANAGER.save_run(save_data, int(context.get("slot", -1)), str(context.get("mode", ""))))
	main.set_meta("last_run_save_ok", payload_chars > 0)
	PERFORMANCE_RECORDER.end_scope("save_run_ms")
	_record_save_probe_counters(save_data, payload_chars, Time.get_ticks_usec() - save_start_usec)
	return payload_chars > 0

static func _record_save_probe_counters(save_data: Dictionary, payload_chars: int, elapsed_usec: int) -> void:
	PERFORMANCE_COUNTERS.add("save_run_calls", 1)
	PERFORMANCE_COUNTERS.add("save_run_ms_x10", int(round(float(max(0, elapsed_usec)) / 100.0)))
	PERFORMANCE_COUNTERS.add("save_payload_kb", int(ceil(float(max(0, payload_chars)) / 1024.0)))
	PERFORMANCE_COUNTERS.add("save_enemies", (save_data.get("enemies", []) as Array).size())
	PERFORMANCE_COUNTERS.add("save_enemy_projectiles", (save_data.get("enemy_projectiles", []) as Array).size())
	PERFORMANCE_COUNTERS.add("save_gems", (save_data.get("gems", []) as Array).size())
	PERFORMANCE_COUNTERS.add("save_hearts", (save_data.get("heart_pickups", []) as Array).size())
	PERFORMANCE_COUNTERS.add("save_bones", (save_data.get("bone_pickups", []) as Array).size())

static func _get_runtime_or_group_nodes(main: Node, group_name: String) -> Array:
	return RUN_SAVE_RUNTIME_FLOW.get_runtime_or_group_nodes(main, group_name)

static func load_saved_run(main: Node) -> bool:
	if main._is_developer_mode():
		return false
	var save_data := SAVE_MANAGER.load_run()
	if save_data.is_empty():
		return _restore_failed(main, "战局文件缺失或无法验证。")
	if main.story_mode_active:
		main.set_meta("story_attempt", save_data.get("story_attempt", {}).duplicate(true))
		if bool(save_data.get("story_initial", false)):
			return false
		if save_data.has("pending_settlement"):
			main.set_meta("pending_story_settlement", save_data.pending_settlement.duplicate(true))

	if save_data.has("pending_run_end"):
		main.set_meta("pending_run_end", save_data.pending_run_end.duplicate(true))
	main.set_meta("saved_reward", save_data.get("reward_state", {}))
	main.survival_time = float(save_data.get("survival_time", 0.0))
	main.autosave_elapsed = 0.0
	main.spawned_elite_count = int(save_data.get("spawned_elite_count", 0))
	main.spawned_small_boss_count = int(save_data.get("spawned_small_boss_count", 0))
	main.boss_spawned = bool(save_data.get("boss_spawned", false))
	if main.endless_mode_active:
		main.endless_tier = int(save_data.get("run_tier", 1))
		main.endless_run_id = str(save_data.get("run_id", ""))
	main.boss_enemy = null
	main.small_boss_enemy = null

	if main.player == null or not main.player.has_method("apply_save_data"):
		return _restore_failed(main, "角色无法恢复。")
	var original_children := main.get_children()
	if main.player.apply_save_data(save_data.get("player", {})) != true:
		return _restore_failed(main, "角色快照无法恢复。")
	for entry in [
		["enemies", RUN_SAVE_RUNTIME_FLOW.restore_enemies], ["enemy_projectiles", RUN_SAVE_RUNTIME_FLOW.restore_enemy_projectiles],
		["gems", RUN_SAVE_RUNTIME_FLOW.restore_gems], ["heart_pickups", RUN_SAVE_RUNTIME_FLOW.restore_heart_pickups],
		["bone_pickups", RUN_SAVE_RUNTIME_FLOW.restore_bone_pickups], ["experience_vacuum_pickups", RUN_SAVE_RUNTIME_FLOW.restore_experience_vacuum_pickups],
		["swordsman_ground_cracks", RUN_SAVE_RUNTIME_FLOW.restore_swordsman_ground_cracks], ["skull_mage_domains", RUN_SAVE_RUNTIME_FLOW.restore_skull_mage_domains],
		["parasite_seeds", RUN_SAVE_RUNTIME_FLOW.restore_parasite_seeds]
	]:
		if not bool(entry[1].call(main, save_data.get(entry[0], []))):
			for child in main.get_children():
				if child not in original_children:
					child.free()
			return _restore_failed(main, "战局对象无法恢复：" + str(entry[0]))

	if is_instance_valid(main.get("wave_flow")):
		main.wave_flow.apply_save_data(save_data.get("combat_wave", {}))

	var game_bgm = main._get_game_bgm()
	if game_bgm != null and game_bgm.has_method("restore_playback_position"):
		game_bgm.restore_playback_position(float(save_data.get("music_position", 0.0)))

	main._refresh_hud()
	save_run_state(main)
	return true

static func _restore_enemies(main: Node, enemies_data: Array) -> bool:
	return RUN_SAVE_RUNTIME_FLOW.restore_enemies(main, enemies_data)

static func _restore_enemy_projectiles(main: Node, projectiles_data: Array) -> bool:
	return RUN_SAVE_RUNTIME_FLOW.restore_enemy_projectiles(main, projectiles_data)

static func _restore_gems(main: Node, gems_data: Array) -> bool:
	return RUN_SAVE_RUNTIME_FLOW.restore_gems(main, gems_data)

static func _restore_heart_pickups(main: Node, hearts_data: Array) -> bool:
	return RUN_SAVE_RUNTIME_FLOW.restore_heart_pickups(main, hearts_data)

static func _restore_bone_pickups(main: Node, bones_data: Array) -> bool:
	return RUN_SAVE_RUNTIME_FLOW.restore_bone_pickups(main, bones_data)

static func _restore_failed(main: Node, reason: String) -> bool:
	main.set_meta("run_restore_failed", reason)
	main.set_meta("last_run_save_ok", false)
	return false
