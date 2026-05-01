extends RefCounted

const STORY_PREP_SCENE_PATH := "res://scenes/story_prep.tscn"
const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const BUILD_SYSTEM := preload("res://scripts/build/build_system.gd")
const GAME_HUD_FLOW := preload("res://scripts/game/game_hud_flow.gd")

static func show_level_up(main: Node, options: Array) -> void:
	if main.game_over:
		return
	if main.level_up_ui == null or not main.level_up_ui.has_method("show_options"):
		return

	main.reward_context = "level_up"
	main.get_tree().paused = true
	var attribute_options: Array = []
	if main.player != null and main.player.has_method("get_attribute_upgrade_options"):
		attribute_options = main.player.get_attribute_upgrade_options()
	main.level_up_ui.show_options(options, attribute_options)

static func show_final_core(main: Node) -> void:
	if main.game_over or main.player == null or main.level_up_ui == null:
		return
	if not main.level_up_ui.has_method("show_menu"):
		return

	main.stage_cleared = true
	main.reward_context = "final_core"
	main.boss_enemy = null
	GAME_HUD_FLOW.hide_boss_ui(main)
	if main.spawn_timer != null:
		main.spawn_timer.stop()
	main.get_tree().paused = true
	main.level_up_ui.show_menu("最终 Boss 已击败", main.player.get_final_core_options())

static func finish_stage_clear(main: Node) -> void:
	if main.game_over:
		return

	if main.story_mode_active:
		main.game_over = true
		main.reward_context = ""
		main.boss_enemy = null
		GAME_HUD_FLOW.hide_boss_ui(main)
		if main.spawn_timer != null:
			main.spawn_timer.stop()
		var material_reward: int = int(main.story_stage.get("boss_material_reward", 0))
		SAVE_MANAGER.complete_current_story_stage(material_reward)
		main.get_tree().paused = false
		main.get_tree().change_scene_to_file(STORY_PREP_SCENE_PATH)
		return

	main.game_over = true
	main.reward_context = ""
	main.boss_enemy = null
	GAME_HUD_FLOW.hide_boss_ui(main)
	SAVE_MANAGER.clear_save()
	if main.spawn_timer != null:
		main.spawn_timer.stop()
	if main.pause_menu != null and main.pause_menu.has_method("hide_ui"):
		main.pause_menu.hide_ui()
	if main.level_up_ui != null and main.level_up_ui.has_method("hide_ui"):
		main.level_up_ui.hide_ui()
	if main.game_over_ui != null and main.game_over_ui.has_method("show_victory"):
		main.game_over_ui.show_victory(main.survival_time, main.player.level)
	main._pause_game_bgm()
	main.get_tree().paused = true

static func handle_upgrade_selected(main: Node, option_id: String, attribute_option_id: String = "") -> void:
	if main.level_up_ui != null and main.level_up_ui.has_method("hide_ui"):
		main.level_up_ui.hide_ui()

	main.get_tree().paused = false

	if main.reward_context == "level_up" and attribute_option_id != "" and main.player != null and main.player.has_method("apply_attribute_upgrade"):
		main.player.apply_attribute_upgrade(attribute_option_id)
	if main.reward_context == "small_boss_reward":
		_apply_player_upgrade(main, option_id)
		if attribute_option_id != "":
			_apply_player_upgrade(main, attribute_option_id)
		if main.player != null and bool(main.player.get("level_up_active")):
			main._refresh_hud()
			main._save_run_state()
			return
		main.reward_context = ""
		main._refresh_hud()
		main._save_run_state()
		return
	if main.reward_context == "endless_boss_reward":
		_apply_player_upgrade(main, option_id)
		main.reward_context = ""
		main._refresh_hud()
		main._save_run_state()
		return

	_apply_player_upgrade(main, option_id)

	if main.reward_context == "final_core":
		finish_stage_clear(main)
		return

	main.reward_context = ""
	main._refresh_hud()
	main._save_run_state()

static func show_small_boss_reward(main: Node) -> void:
	if main.level_up_ui == null:
		return
	main.reward_context = "small_boss_reward"
	main.get_tree().paused = true
	var options: Array = get_blank_small_boss_reward_options()
	if main.player != null and main.player.has_method("get_small_boss_reward_options"):
		options = main.player.get_small_boss_reward_options()
	if main.level_up_ui.has_method("show_small_boss_reward_menu"):
		main.level_up_ui.show_small_boss_reward_menu("\u5c0f Boss \u5956\u52b1", options)
	elif main.level_up_ui.has_method("show_menu"):
		main.level_up_ui.show_menu("\u5c0f Boss \u5956\u52b1", options)

static func show_endless_boss_reward(main: Node) -> void:
	if main.level_up_ui == null or not main.level_up_ui.has_method("show_menu"):
		main._refresh_hud()
		main._save_run_state()
		return
	main.reward_context = "endless_boss_reward"
	main.get_tree().paused = true
	var options: Array = []
	if main.player != null and main.player.has_method("get_final_core_options"):
		options = main.player.get_final_core_options()
	if options.is_empty():
		options = [_make_final_blank_upgrade_option()]
	main.level_up_ui.show_menu("Boss 奖励", options)

static func get_blank_small_boss_reward_options() -> Array:
	return BUILD_SYSTEM.get_blank_small_boss_reward_options()

static func _apply_player_upgrade(main: Node, option_id: String) -> void:
	if main.player != null and main.player.has_method("apply_upgrade"):
		main.player.apply_upgrade(option_id)

static func _make_final_blank_upgrade_option() -> Dictionary:
	return {
		"id": "final_blank_upgrade",
		"title": "结束本局",
		"description": "最终 Boss 已击败。确认后进入胜利结算。",
		"preview_description": "确认胜利并完成本局。",
		"exact_description": "这是结算确认选项，不提供额外战斗加成。"
	}
