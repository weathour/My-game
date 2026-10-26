extends RefCounted

const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const ENDLESS_CAMP_SCENE_PATH := "res://scenes/endless_camp.tscn"
const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const GAME_HUD_FLOW := preload("res://scripts/game/game_hud_flow.gd")
const REWARD_FLOW := preload("res://scripts/game/reward_flow.gd")
const CONTINUE_BGM_RESUME_DELAY := 0.25
const STORY_PROGRESS := preload("res://scripts/story/story_progress.gd")
const RUN_OUTCOME := preload("res://scripts/game/run_outcome.gd")
const STATE := preload("res://scripts/game/session_state.gd")
const NORMAL_GAME_SPEED := 1.0
const ENDLESS_FAST_GAME_SPEED := 2.0

static func set_endless_speed_enabled(main: Node, enabled: bool) -> void:
	var resolved_enabled: bool = enabled and bool(main.get("endless_mode_active")) and not bool(main.get("game_over"))
	main.set("endless_speed_enabled", resolved_enabled)
	Engine.time_scale = ENDLESS_FAST_GAME_SPEED if resolved_enabled else NORMAL_GAME_SPEED
	var hud = main.get("hud")
	if hud != null and is_instance_valid(hud) and hud.has_method("set_endless_speed_active"):
		hud.set_endless_speed_active(resolved_enabled)

static func reset_game_speed(main: Node) -> void:
	set_endless_speed_enabled(main, false)

static func handle_escape_toggle(main: Node) -> void:
	if main.pause_menu == null:
		return
	if main.level_up_ui != null and main.level_up_ui.visible:
		return
	if main.game_over_ui != null and main.game_over_ui.visible:
		return

	if main.pause_menu.visible:
		resume_game(main)
	else:
		pause_game_bgm(main)
		STATE.set_pause_reason(main, "manual", true)
		main.pause_menu.show_ui()

static func show_pause_menu_after_continue(main: Node) -> void:
	if main.pause_menu != null:
		pause_game_bgm(main)
		STATE.set_pause_reason(main, "manual", true)
		main.pause_menu.show_ui()

static func resume_game(main: Node) -> void:
	if main.has_meta("run_restore_failed"):
		_save_error(main)
		return
	if main.pause_menu != null and main.pause_menu.has_method("hide_ui"):
		main.pause_menu.hide_ui()
	STATE.set_pause_reason(main, "manual", false)

	var resume_delay: float = CONTINUE_BGM_RESUME_DELAY
	if main.loaded_from_save and main.player != null:
		var resumed_reward: bool = REWARD_FLOW.resume_saved_reward(main)
		if not resumed_reward and main.player.has_method("resume_pending_level_ups"):
			main.player.resume_pending_level_ups()
		resume_delay = CONTINUE_BGM_RESUME_DELAY
		main.loaded_from_save = false

	resume_game_bgm(main, resume_delay)

static func handle_player_died(main: Node, outcome: String = "failed") -> void:
	if main.game_over:
		return

	var saved := finish_run(main, outcome)
	STATE.set_outcome(main, outcome)
	main.game_over = true
	if is_instance_valid(main.get("wave_flow")):
		main.wave_flow.view.hide_all()
	reset_game_speed(main)
	GAME_HUD_FLOW.hide_boss_ui(main)

	if main.pause_menu != null and main.pause_menu.has_method("hide_ui"):
		main.pause_menu.hide_ui()
	if main.level_up_ui != null and main.level_up_ui.has_method("hide_ui"):
		main.level_up_ui.hide_ui()
	if main.game_over_ui != null and main.game_over_ui.has_method("show_game_over"):
		main.game_over_ui.show_game_over(main.survival_time, main.player.level, main.endless_mode_active or main.story_mode_active)
		if main.game_over_ui.has_method("set_run_summary"):
			main.game_over_ui.set_run_summary(RUN_OUTCOME.capture(main, "failed"), saved)

	pause_game_bgm(main)
	STATE.set_pause_reason(main, "result", true)

static func finish_run(main: Node, outcome: String) -> bool:
	if main._is_developer_mode():
		return true
	if bool(main.get_meta("run_finished", false)):
		return true
	var summary: Dictionary = main.get_meta("pending_run_end", {}).get("summary", RUN_OUTCOME.capture(main, outcome))
	main.set_meta("pending_run_end", {"outcome": outcome, "summary": summary})
	main._save_run_state()
	if not bool(main.get_meta("last_run_save_ok", true)):
		return false
	if main.story_mode_active:
		var attempt: Dictionary = main.get_meta("story_attempt", {})
		var response := STORY_PROGRESS.end_attempt(int(attempt.get("slot_id", -1)), str(attempt.get("attempt_id", "")), outcome, summary)
		if not response.ok:
			return false
	elif main.endless_mode_active:
		var profile := SAVE_MANAGER.get_current_endless_profile()
		if profile.is_empty():
			return false
		profile["last_run_summary"] = summary
		profile.erase("bone_pickup_receipts")
		if SAVE_MANAGER.save_endless_profile(profile) <= 0:
			return false
	if not SAVE_MANAGER.clear_save():
		return false
	main.remove_meta("pending_run_end")
	main.set_meta("run_finished", true)
	return true

static func _save_error(main: Node) -> void:
	if main.game_over_ui != null and main.game_over_ui.visible and main.game_over_ui.has_method("set_run_summary"):
		main.game_over_ui.set_run_summary(RUN_OUTCOME.capture(main, "failed"), false)
	elif main.pause_menu != null:
		STATE.set_pause_reason(main, "restore_failed" if main.has_meta("run_restore_failed") else "manual", true)
		main.pause_menu.show_ui()
		main.pause_menu.modal.set_hint("恢复失败，原战局文件已保留。请返回主菜单重试。" if main.has_meta("run_restore_failed") else "保存失败，已保留当前战局。请检查存储空间后重试。")

static func restart(main: Node) -> void:
	if not finish_run(main, "failed" if main.game_over else "abandoned"):
		_save_error(main)
		return
	if main.story_mode_active:
		var attempt: Dictionary = main.get_meta("story_attempt", {})
		var response := STORY_PROGRESS.begin_stage(int(attempt.get("slot_id", -1)), str(attempt.get("stage_id", "")), str(attempt.get("purpose", "advance")))
		if not response.ok:
			_save_error(main)
			return
		SAVE_MANAGER.request_continue()
	elif main.endless_mode_active:
		if not SAVE_MANAGER.select_current_endless_tier(main.endless_tier):
			_save_error(main)
			return
	reset_game_speed(main)
	main.suppress_exit_save = true
	STATE.clear_pause_reasons(main)
	main.get_tree().reload_current_scene()

static func return_to_main_menu(main: Node) -> void:
	if main.has_meta("run_restore_failed"):
		reset_game_speed(main)
		main.suppress_exit_save = true
		STATE.clear_pause_reasons(main)
		main.get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
		return
	main._save_run_state()
	if not bool(main.get_meta("last_run_save_ok", true)):
		_save_error(main)
		return
	reset_game_speed(main)
	main.suppress_exit_save = true
	STATE.clear_pause_reasons(main)
	main.get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

static func return_to_endless_camp(main: Node) -> void:
	if not main.endless_mode_active and not main.story_mode_active:
		return
	var profile := SAVE_MANAGER.get_current_endless_profile() if main.endless_mode_active else {}
	var won: bool = main.endless_mode_active and main.endless_run_id != "" and profile.get("last_rewarded_run_id") == main.endless_run_id
	if not won and not finish_run(main, "failed" if main.game_over else "abandoned"):
		_save_error(main)
		return
	reset_game_speed(main)
	main.suppress_exit_save = true
	STATE.clear_pause_reasons(main)
	main.get_tree().change_scene_to_file("res://scenes/story_prep.tscn" if main.story_mode_active else ENDLESS_CAMP_SCENE_PATH)

static func get_game_bgm(main: Node):
	return main.get_node_or_null("GameBGM")

static func start_game_bgm(main: Node) -> void:
	var game_bgm = get_game_bgm(main)
	if game_bgm != null and game_bgm.has_method("start_music"):
		game_bgm.start_music()

static func pause_game_bgm(main: Node) -> void:
	var game_bgm = get_game_bgm(main)
	if game_bgm != null and game_bgm.has_method("pause_music"):
		game_bgm.pause_music()

static func resume_game_bgm(main: Node, delay_seconds: float = 0.0) -> void:
	var game_bgm = get_game_bgm(main)
	if game_bgm != null and game_bgm.has_method("resume_music"):
		game_bgm.resume_music(delay_seconds)
