extends RefCounted

const STORY_PREP_SCENE_PATH := "res://scenes/story_prep.tscn"
const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const GAME_HUD_FLOW := preload("res://scripts/game/game_hud_flow.gd")
const DIRECT_BLESSING_CHOICES_META := "direct_blessing_choices_remaining"
const DIRECT_BLESSING_TIER_META := "direct_blessing_tier"
const BLESSING_BINDING_CHOICE_META := "blessing_binding_choice"
const BLESSING_BINDING_RETURN_CONTEXT_META := "blessing_binding_return_context"
const DIRECT_BLESSING_CHOICE_COUNT := 2
const DIRECT_BLESSING_TIER_TWO := 2

static func show_level_up(main: Node, options: Array) -> void:
	if main.game_over:
		return
	if main.level_up_ui == null or not main.level_up_ui.has_method("show_options"):
		return

	main.reward_context = "level_up"
	main.get_tree().paused = true
	if options.is_empty() and main.player != null and main.player.has_method("_build_upgrade_options"):
		options = main.player._build_upgrade_options()
	var attribute_options: Array = []
	if main.player != null and main.player.has_method("get_attribute_upgrade_options"):
		attribute_options = main.player.get_attribute_upgrade_options()
	var offer_context := _get_current_blessing_offer_context(main)
	main.level_up_ui.show_options(options, attribute_options, offer_context)

static func handle_upgrade_refresh_requested(main: Node) -> void:
	if main.game_over or not ["level_up", "small_boss_blessing_choice"].has(main.reward_context):
		return
	if main.player == null or main.level_up_ui == null:
		return
	if not main.player.has_method("refresh_upgrade_options") or not main.level_up_ui.has_method("show_options"):
		return
	var options: Array = main.player.refresh_upgrade_options()
	var attribute_options: Array = []
	if main.reward_context == "level_up" and main.player.has_method("get_attribute_upgrade_options"):
		attribute_options = main.player.get_attribute_upgrade_options()
	main.level_up_ui.show_options(options, attribute_options, _get_current_blessing_offer_context(main))

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

	if main.reward_context == "blessing_binding_choice":
		var choice: Dictionary = main.get_meta(BLESSING_BINDING_CHOICE_META, {})
		var return_context := str(main.get_meta(BLESSING_BINDING_RETURN_CONTEXT_META, ""))
		if main.player != null and main.player.has_method("apply_blessing_binding_choice"):
			main.player.apply_blessing_binding_choice(choice, option_id)
		if main.has_meta(BLESSING_BINDING_CHOICE_META):
			main.remove_meta(BLESSING_BINDING_CHOICE_META)
		if main.has_meta(BLESSING_BINDING_RETURN_CONTEXT_META):
			main.remove_meta(BLESSING_BINDING_RETURN_CONTEXT_META)
		if _show_pending_blessing_binding_choice(main, return_context):
			return
		if return_context == "small_boss_blessing_choice":
			_finish_direct_blessing_choice(main)
			return
		main.reward_context = ""
		_schedule_post_reward_maintenance(main, true)
		return

	if main.reward_context == "small_boss_blessing_choice":
		_apply_player_upgrade(main, option_id)
		if _show_pending_blessing_binding_choice(main):
			return
		_finish_direct_blessing_choice(main)
		return

	if main.reward_context == "level_up" and attribute_option_id != "" and main.player != null and main.player.has_method("apply_attribute_upgrade"):
		main.player.apply_attribute_upgrade(attribute_option_id)
	if main.reward_context == "small_boss_reward":
		_apply_player_upgrade(main, option_id)
		if attribute_option_id != "":
			_apply_player_upgrade(main, attribute_option_id)
		if _show_pending_blessing_binding_choice(main):
			return
		if main.player != null and bool(main.player.get("level_up_active")):
			_schedule_post_reward_maintenance(main)
			return
		main.reward_context = ""
		_schedule_post_reward_maintenance(main)
		return
	if main.reward_context == "endless_boss_reward":
		if option_id == "small_boss_choose_blessing":
			show_direct_blessing_choice(main, DIRECT_BLESSING_CHOICE_COUNT, DIRECT_BLESSING_TIER_TWO)
			return
		_apply_player_upgrade(main, option_id)
		if _show_pending_blessing_binding_choice(main):
			return
		main.reward_context = ""
		_schedule_post_reward_maintenance(main)
		return

	_apply_player_upgrade(main, option_id)
	if _show_pending_blessing_binding_choice(main):
		return

	if main.reward_context == "final_core":
		finish_stage_clear(main)
		return

	main.reward_context = ""
	_schedule_post_reward_maintenance(main, true)

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

static func show_direct_blessing_choice(main: Node, choices_remaining: int = DIRECT_BLESSING_CHOICE_COUNT, tier: int = 0) -> void:
	if main.game_over or main.player == null or main.level_up_ui == null:
		return
	if not main.level_up_ui.has_method("show_options"):
		return
	main.reward_context = "small_boss_blessing_choice"
	main.set_meta(DIRECT_BLESSING_CHOICES_META, max(1, choices_remaining))
	main.set_meta(DIRECT_BLESSING_TIER_META, tier)
	main.get_tree().paused = true
	var options: Array = []
	if tier > 0 and main.player.has_method("build_tier_blessing_options"):
		options = main.player.build_tier_blessing_options(tier)
	elif main.player.has_method("build_direct_blessing_options"):
		options = main.player.build_direct_blessing_options()
	var offer_context := _get_current_blessing_offer_context(main)
	var tier_text := "全部祝福" if tier <= 0 else "%s级祝福" % ("II" if tier >= 2 else "I")
	offer_context["summary"] = "Boss 奖励：从%s中自选。剩余 %d 次。" % [tier_text, max(1, choices_remaining)]
	main.level_up_ui.show_options(options, [], offer_context)

static func show_endless_boss_reward(main: Node) -> void:
	if main.level_up_ui == null or not main.level_up_ui.has_method("show_menu"):
		_schedule_post_reward_maintenance(main)
		return
	main.reward_context = "endless_boss_reward"
	main.get_tree().paused = true
	var options: Array = []
	if main.player != null and main.player.has_method("get_boss_skill_reward_options"):
		options = main.player.get_boss_skill_reward_options()
	if options.is_empty():
		options = get_blank_small_boss_reward_options()
	main.level_up_ui.show_menu("技能奖励（三选一）", options)

static func get_blank_small_boss_reward_options() -> Array:
	return [
		{
			"id": "small_boss_blank_continue",
			"title": "继续战斗",
			"description": "当前没有可选奖励。",
			"preview_description": "不获得额外奖励，直接继续。",
			"exact_description": "不获得额外奖励，直接继续。"
		}
	]

static func _apply_player_upgrade(main: Node, option_id: String) -> void:
	if main.player != null and main.player.has_method("apply_upgrade"):
		main.player.apply_upgrade(option_id)

static func _get_current_blessing_offer_context(main: Node) -> Dictionary:
	if main.player != null and main.player.has_method("get_current_blessing_offer_context"):
		return main.player.get_current_blessing_offer_context()
	return {}

static func _show_pending_blessing_binding_choice(main: Node, return_context_override: String = "") -> bool:
	if main.game_over or main.player == null or main.level_up_ui == null:
		return false
	if not main.player.has_method("consume_pending_blessing_binding_choice"):
		return false
	if not main.player.has_method("build_blessing_binding_options"):
		return false
	if not main.level_up_ui.has_method("show_menu"):
		return false
	var choice: Dictionary = main.player.consume_pending_blessing_binding_choice()
	if choice.is_empty():
		return false
	var options: Array = main.player.build_blessing_binding_options(choice)
	if options.is_empty():
		return false
	main.set_meta(BLESSING_BINDING_CHOICE_META, choice)
	var return_context := return_context_override if return_context_override != "" else str(main.reward_context)
	main.set_meta(BLESSING_BINDING_RETURN_CONTEXT_META, return_context)
	main.reward_context = "blessing_binding_choice"
	main.get_tree().paused = true
	main.level_up_ui.show_menu("祝福绑定技能", options)
	return true

static func _finish_direct_blessing_choice(main: Node) -> void:
	var remaining_choices: int = max(0, int(main.get_meta(DIRECT_BLESSING_CHOICES_META, 1)) - 1)
	main.set_meta(DIRECT_BLESSING_CHOICES_META, remaining_choices)
	if remaining_choices > 0:
		show_direct_blessing_choice(main, remaining_choices, int(main.get_meta(DIRECT_BLESSING_TIER_META, 0)))
		return
	main.remove_meta(DIRECT_BLESSING_CHOICES_META)
	if main.has_meta(DIRECT_BLESSING_TIER_META):
		main.remove_meta(DIRECT_BLESSING_TIER_META)
	main.reward_context = ""
	_schedule_post_reward_maintenance(main)

static func _schedule_post_reward_maintenance(main: Node, resume_level_ups: bool = false) -> void:
	if main.has_method("_schedule_reward_maintenance"):
		main._schedule_reward_maintenance(resume_level_ups)
		return
	main._refresh_hud()
	main._save_run_state()
	if resume_level_ups and main.player != null and main.player.has_method("resume_pending_level_ups"):
		main.player.resume_pending_level_ups()

static func _make_final_blank_upgrade_option() -> Dictionary:
	return {
		"id": "final_blank_upgrade",
		"title": "结束本局",
		"description": "最终 Boss 已击败。确认后进入胜利结算。",
		"preview_description": "确认胜利并完成本局。",
		"exact_description": "这是结算确认选项，不提供额外战斗加成。"
	}
