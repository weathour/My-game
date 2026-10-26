extends SceneTree
const FLOW_TEST = preload("res://scripts/tests/combat_wave_flow_smoke.gd")
const FLOW = preload("res://scripts/game/combat_wave_flow.gd")
const REWARDS = preload("res://scripts/game/reward_flow.gd")
const RUN_SAVE = preload("res://scripts/game/run_save_flow.gd")
const SESSION = preload("res://scripts/game/game_session_flow.gd")
const MAIN_FLOW = preload("res://scripts/game/game_main_flow.gd")
const SAVE = preload("res://scripts/save_manager.gd")
const STORE = preload("res://scripts/save/save_file_store.gd")
const PLAYER = preload("res://scenes/player.tscn")
class TestMain:
	extends FLOW_TEST.TestMain
	func _save_run_state() -> void:
		RUN_SAVE.save_run_state(self)
class CardUI:
	extends Control
	var menu_title = ""
	func show_options(_cards: Array, _attrs: Array, _context: Dictionary) -> void:
		menu_title = "options"
		show()
	func show_small_boss_reward_menu(title: String, _options: Array) -> void:
		menu_title = title
		show()
	func show_menu(title: String, _options: Array) -> void:
		menu_title = title
		show()
	func hide_ui() -> void:
		hide()
func _init() -> void:
	call_deferred("_run")
func fresh():
	var main = TestMain.new()
	root.add_child(main)
	main.set_process(false)
	main.set_physics_process(false)
	main.endless_mode_active = true
	main.endless_tier = 1
	main.endless_run_id = SAVE.create_endless_run_id(1)
	main.player = PLAYER.instantiate()
	main.add_child(main.player)
	main.player.set_process(false)
	main.player.set_physics_process(false)
	main.level_up_ui = CardUI.new()
	main.add_child(main.level_up_ui)
	FLOW.setup(main)
	return main
func discard(main):
	paused = false
	main.free()
func _run() -> void:
	assert(ProjectSettings.globalize_path("user://").begins_with("/tmp/"))
	SAVE.delete_endless_profile(1)
	SAVE.create_or_load_endless_profile(1)
	var main = fresh()
	main.wave_flow.wave = 6
	main.wave_flow.small_boss_reward_pending = true
	main.wave_flow._begin_wave_ending(false)
	FLOW_TEST.finish_ending(main.wave_flow)
	await process_frame
	assert(main.reward_context == "small_boss_reward")
	print("CASE1_BEFORE_CLOSE reward=", main.reward_context, " paused=", paused, " pending_boss=", main.wave_flow.small_boss_reward_pending)
	# Exact handler used on normal window close; no process kill needed.
	MAIN_FLOW.handle_notification(main, main.NOTIFICATION_WM_CLOSE_REQUEST)
	var data = SAVE.load_run()
	assert(not data.is_empty())
	print("CASE1_DISK phase=", data.combat_wave.phase, " pending_boss=", data.combat_wave.small_boss_reward_pending, " pending_wave_blessing=", data.combat_wave.blessing_pending)
	discard(main)
	main = fresh()
	assert(RUN_SAVE.load_saved_run(main))
	main.loaded_from_save = true
	SESSION.resume_game(main)
	print("CASE1_AFTER_CONTINUE reward=", main.reward_context, " menu=", main.level_up_ui.menu_title)
	assert(main.reward_context == "small_boss_reward")
	assert(main.wave_flow.small_boss_reward_pending)
	var options: Array = main.get_meta(REWARDS.REWARD_OPTIONS_META)
	REWARDS.handle_upgrade_selected(main, str(options[0].id))
	assert(not main.wave_flow.small_boss_reward_pending)
	assert(main.reward_context == REWARDS.WAVE_BLESSING_CONTEXT)
	REWARDS.handle_upgrade_selected(main, str(main.wave_flow.blessing_offer.options[0].id))
	print("CASE1_AFTER_BLESSING reward=", main.reward_context, " paused=", paused, " phase=", main.wave_flow.phase)
	assert(main.reward_context == "" and not paused)
	discard(main)
	main = fresh()
	main.wave_flow.wave = 20
	main.wave_flow._begin_wave_ending(true)
	FLOW_TEST.finish_ending(main.wave_flow)
	await process_frame
	assert(main.reward_context == REWARDS.WAVE_BLESSING_CONTEXT)
	# A directory at only the profile temporary path makes profile writing fail;
	# reading its existing valid JSON and writing run snapshots still work.
	var obstruction = ProjectSettings.globalize_path(STORE.endless_profile_path(1) + ".tmp")
	DirAccess.make_dir_recursive_absolute(obstruction)
	REWARDS.handle_upgrade_selected(main, str(main.wave_flow.blessing_offer.options[0].id))
	assert(main.reward_context == REWARDS.ENDLESS_TIER_CLEAR_CONTEXT and main.game_over)
	print("CASE2_AFTER_SAVE_FAILURE reward=", main.reward_context, " game_over=", main.game_over, " menu=", main.level_up_ui.menu_title)
	data = SAVE.load_run()
	assert(not data.is_empty())
	print("CASE2_DISK phase=", data.combat_wave.phase, " pending_wave_blessing=", data.combat_wave.blessing_pending)
	# Closing at the retry menu does not rewrite the save because game_over=true.
	MAIN_FLOW.handle_notification(main, main.NOTIFICATION_WM_CLOSE_REQUEST)
	DirAccess.remove_absolute(obstruction)
	discard(main)
	main = fresh()
	assert(RUN_SAVE.load_saved_run(main))
	main.loaded_from_save = true
	SESSION.resume_game(main)
	for i in range(10):
		main.wave_flow.tick(1.0)
	print("CASE2_AFTER_CONTINUE reward=", main.reward_context, " paused=", paused, " phase=", main.wave_flow.phase, " game_over=", main.game_over)
	assert(main.wave_flow.phase == "complete" and main.reward_context == REWARDS.ENDLESS_TIER_CLEAR_CONTEXT and main.game_over and paused)
	assert(SAVE.load_endless_profile().last_rewarded_run_id == main.endless_run_id)
	var balance := int(SAVE.load_endless_profile().bones)
	assert(not SAVE.complete_current_endless_tier(1, main.endless_run_id).applied)
	assert(int(SAVE.load_endless_profile().bones) == balance)
	print("REWARD_RECOVERY_SMOKE_OK")
	discard(main)
	quit()
