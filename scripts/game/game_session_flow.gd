extends RefCounted

const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const GAME_HUD_FLOW := preload("res://scripts/game/game_hud_flow.gd")
const CONTINUE_BGM_RESUME_DELAY := 0.25

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
		main.get_tree().paused = true
		main.pause_menu.show_ui()

static func show_pause_menu_after_continue(main: Node) -> void:
	if main.pause_menu != null:
		pause_game_bgm(main)
		main.get_tree().paused = true
		main.pause_menu.show_ui()

static func resume_game(main: Node) -> void:
	if main.pause_menu != null and main.pause_menu.has_method("hide_ui"):
		main.pause_menu.hide_ui()
	main.get_tree().paused = false

	var resume_delay: float = CONTINUE_BGM_RESUME_DELAY
	if main.loaded_from_save and main.player != null and main.player.has_method("resume_pending_level_ups"):
		main.player.resume_pending_level_ups()
		resume_delay = CONTINUE_BGM_RESUME_DELAY
		main.loaded_from_save = false

	resume_game_bgm(main, resume_delay)

static func handle_player_died(main: Node) -> void:
	if main.game_over:
		return

	main.game_over = true
	SAVE_MANAGER.clear_save()
	GAME_HUD_FLOW.hide_boss_ui(main)

	if main.pause_menu != null and main.pause_menu.has_method("hide_ui"):
		main.pause_menu.hide_ui()
	if main.level_up_ui != null and main.level_up_ui.has_method("hide_ui"):
		main.level_up_ui.hide_ui()
	if main.game_over_ui != null and main.game_over_ui.has_method("show_game_over"):
		main.game_over_ui.show_game_over(main.survival_time, main.player.level)

	pause_game_bgm(main)
	main.get_tree().paused = true

static func restart(main: Node) -> void:
	main.suppress_exit_save = true
	SAVE_MANAGER.clear_save()
	main.get_tree().paused = false
	main.get_tree().reload_current_scene()

static func return_to_main_menu(main: Node) -> void:
	main._save_run_state()
	main.suppress_exit_save = true
	if main._is_developer_mode():
		SAVE_MANAGER.clear_save()
	main.get_tree().paused = false
	main.get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

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
