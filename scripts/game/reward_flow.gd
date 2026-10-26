extends RefCounted

const STATE := preload("res://scripts/game/session_state.gd")
const STORY_PREP_SCENE_PATH := "res://scenes/story_prep.tscn"
const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const GAME_HUD_FLOW := preload("res://scripts/game/game_hud_flow.gd")
const DIRECT_BLESSING_CHOICES_META := "direct_blessing_choices_remaining"
const DIRECT_BLESSING_TIER_META := "direct_blessing_tier"
const BLESSING_BINDING_CHOICE_META := "blessing_binding_choice"
const BLESSING_BINDING_RETURN_CONTEXT_META := "blessing_binding_return_context"
const DIRECT_BLESSING_CHOICE_COUNT := 2
const DIRECT_BLESSING_TIER_TWO := 2
const SKILL_TALENT_CONTEXT := "skill_talent_choice"
const SKILL_POINT_CONTEXT := "skill_point_choice"
const WAVE_BLESSING_CONTEXT := "wave_blessing"
const ENDLESS_TIER_CLEAR_CONTEXT := "endless_tier_clear"
const ENDLESS_TIER_CLEAR_OPTION_ID := "endless_tier_clear_confirm"
const ENDLESS_TIER_CLEAR_RETRY_OPTION_ID := "endless_tier_clear_retry"
const REWARD_OPTIONS_META := "reward_options"
const SAVED_REWARD_META := "saved_reward"
const STORY_PROGRESS := preload("res://scripts/story/story_progress.gd")

static func show_level_up(main: Node, options: Array) -> void:
	if main.game_over:
		return
	if main.level_up_ui == null or not main.level_up_ui.has_method("show_options"):
		return

	main.reward_context = "level_up"
	STATE.set_pause_reason(main, "reward", true)
	if options.is_empty() and main.player != null and main.player.has_method("_build_upgrade_options"):
		options = main.player._build_upgrade_options()
	var offer_context := _get_current_blessing_offer_context(main)
	main.level_up_ui.show_options(options, [], offer_context)

static func show_skill_point_allocation(main: Node, skill_id: String = "", role_id: String = "") -> void:
	if main.game_over or main.player == null or main.level_up_ui == null:
		return
	if main.get_tree().paused or main.player.is_dead or main.player.level_up_active or main.reward_context != "":
		return
	if int(main.player.get("skill_points")) <= 0:
		return
	var active_role_id := str(main.player._get_active_role().get("id", ""))
	if role_id != "" and role_id != active_role_id:
		return
	if skill_id != "":
		var levels = preload("res://scripts/player/player_skill_level_system.gd")
		var progress_id := active_role_id + "_basic" if skill_id.ends_with("_basic_attack") else str(levels.UNLOCKABLE_PROGRESS.find_key(skill_id))
		var visible_skills: Array = main.player._get_active_skill_cooldown_slots(1.0, false)
		var is_visible := false
		for slot in visible_skills:
			if str(slot.get("skill_id", "")) == skill_id:
				is_visible = true
		if not is_visible or not levels.is_progress_upgradeable(main.player, progress_id) or levels.is_talent_pick_pending(main.player, active_role_id, progress_id):
			return
		if main.player.spend_skill_point():
			var build = preload("res://scripts/player/player_build_system.gd")
			var option: Dictionary = build._make_skill_upgrade_option(main.player, active_role_id, 0, progress_id)
			_apply_player_upgrade(main, str(option.get("id", "")))
			if _show_pending_skill_talent_choice(main):
				return
			_schedule_post_reward_maintenance(main)
		return
	if role_id == "":
		return
	var offer: Dictionary = main.player.current_blessing_offer if str(main.player.get("active_upgrade_kind")) == SKILL_POINT_CONTEXT and main.player.get("current_blessing_offer") is Dictionary else {}
	if offer.is_empty():
		offer = main.player.build_skill_point_offer()
	var options: Array = offer.get("options", []) if offer.get("options", []) is Array else []
	if options.is_empty():
		return
	main.player.current_blessing_offer = offer
	main.player.level_up_active = true
	main.player.active_upgrade_kind = SKILL_POINT_CONTEXT
	main.reward_context = SKILL_POINT_CONTEXT
	STATE.set_pause_reason(main, "reward", true)
	main.level_up_ui.show_options(options, [], offer.get("context", {}))

static func handle_upgrade_refresh_requested(main: Node) -> void:
	if main.game_over or not ["level_up", "small_boss_blessing_choice"].has(main.reward_context):
		return
	if main.player == null or main.level_up_ui == null:
		return
	if not main.player.has_method("refresh_upgrade_options") or not main.level_up_ui.has_method("show_options"):
		return
	var options: Array = main.player.refresh_upgrade_options()
	main.level_up_ui.show_options(options, [], _get_current_blessing_offer_context(main))

static func handle_upgrade_card_refresh_requested(main: Node, option_index: int) -> void:
	if main.game_over or not ["level_up", SKILL_TALENT_CONTEXT].has(main.reward_context):
		return
	if main.player == null or main.level_up_ui == null:
		return
	var options: Array = []
	if main.reward_context == SKILL_TALENT_CONTEXT:
		if not main.player.has_method("refresh_skill_talent_card"):
			return
		var role_id := ""
		if main.level_up_ui.has_method("get_level_talent_selected_role_id"):
			role_id = str(main.level_up_ui.get_level_talent_selected_role_id())
		options = main.player.refresh_skill_talent_card(option_index, role_id)
	else:
		if not main.player.has_method("refresh_upgrade_card"):
			return
		options = main.player.refresh_upgrade_card(option_index)
	var offer_context := _get_current_blessing_offer_context(main)
	if main.level_up_ui.has_method("show_refreshed_build_options"):
		main.level_up_ui.show_refreshed_build_options(options, offer_context, option_index)
	elif main.level_up_ui.has_method("show_options"):
		main.level_up_ui.show_options(options, [], offer_context)
static func show_final_core(main: Node) -> void:
	if main.story_mode_active:
		finish_story_stage(main)
		return
	if main.game_over or main.player == null or main.level_up_ui == null:
		return
	if not main.level_up_ui.has_method("show_menu"):
		return

	STATE.set_outcome(main, "victory")
	main.stage_cleared = true
	main.reward_context = "final_core"
	main.boss_enemy = null
	main.small_boss_enemy = null
	GAME_HUD_FLOW.hide_boss_ui(main)
	if main.spawn_timer != null:
		main.spawn_timer.stop()
	STATE.set_pause_reason(main, "reward", true)
	main.level_up_ui.show_menu("最终 Boss 已击败", main.player.get_final_core_options())

static func finish_stage_clear(main: Node) -> void:
	if main.game_over:
		return

	if main.story_mode_active:
		finish_story_stage(main)
		return

	STATE.set_outcome(main, "victory")
	main.game_over = true
	main.reward_context = ""
	main.boss_enemy = null
	main.small_boss_enemy = null
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
	STATE.set_pause_reason(main, "result", true)

static func finish_story_stage(main: Node) -> void:
	STATE.set_outcome(main, "victory")
	var attempt: Dictionary = main.get_meta("story_attempt", {})
	var pending := attempt.duplicate(true)
	pending["outcome"] = "victory"
	pending["summary"] = preload("res://scripts/game/run_outcome.gd").capture(main, "victory")
	main.set_meta("pending_story_settlement", pending)
	main.stage_cleared = true
	main.boss_enemy = null
	main.small_boss_enemy = null
	if main.spawn_timer != null:
		main.spawn_timer.stop()
	main._save_run_state()
	main.game_over = true
	STATE.set_pause_reason(main, "result", true)
	var response := STORY_PROGRESS.result(false, "save_failed")
	if bool(main.get_meta("last_run_save_ok", false)):
		response = STORY_PROGRESS.settle_stage(int(attempt.get("slot_id", -1)), str(attempt.get("attempt_id", "")))
	if response.ok:
		main.remove_meta("pending_story_settlement")
		main.suppress_exit_save = true
		main.GAME_SESSION_FLOW.reset_game_speed(main)
		STATE.clear_pause_reasons(main)
		main.get_tree().change_scene_to_file(STORY_PREP_SCENE_PATH)
	else:
		main.reward_context = "story_settlement"
		main.level_up_ui.show_menu("关卡已完成，结果待保存", [{"id": "story_settlement_retry", "title": "重试保存并返营", "description": STORY_PROGRESS.message(response.reason)}])

static func handle_upgrade_selected(main: Node, option_id: String, attribute_option_id: String = "") -> void:
	if main.reward_context == "story_settlement":
		if option_id == "story_settlement_retry":
			finish_story_stage(main)
		return
	if main.reward_context == WAVE_BLESSING_CONTEXT:
		var flow = main.get("wave_flow")
		if not is_instance_valid(flow) or not flow.blessing_pending:
			return
		var offered := false
		for option: Dictionary in flow.blessing_offer.get("options", []):
			if str(option.get("id", "")) == option_id:
				offered = true
				break
		if not offered or attribute_option_id != "":
			return
		main.level_up_ui.hide_ui()
		STATE.set_pause_reason(main, "reward", false)
		_apply_player_upgrade(main, option_id)
		flow.finish_wave_blessing()
		return
	if main.level_up_ui != null and main.level_up_ui.has_method("hide_ui"):
		main.level_up_ui.hide_ui()

	STATE.set_pause_reason(main, "reward", false)

	if main.reward_context == ENDLESS_TIER_CLEAR_CONTEXT:
		main.reward_context = ""
		if option_id == ENDLESS_TIER_CLEAR_RETRY_OPTION_ID:
			show_endless_boss_reward(
				main,
				SAVE_MANAGER.complete_current_endless_tier(main.endless_tier, main.endless_run_id, preload("res://scripts/game/run_outcome.gd").capture(main, "victory"))
			)
			return
		if main.has_method("_finish_endless_tier_clear"):
			main._finish_endless_tier_clear()
		return

	if main.reward_context == SKILL_TALENT_CONTEXT:
		var progress_id := ""
		if main.player != null and main.player.has_method("get_current_blessing_offer_context"):
			var offer_context: Dictionary = main.player.get_current_blessing_offer_context()
			if not bool(offer_context.get("level_talent_offer", false)):
				progress_id = str(offer_context.get("skill_progress_id", ""))
		var applied: bool = (
			main.player != null
			and main.player.has_method("apply_skill_talent_choice")
			and main.player.apply_skill_talent_choice(option_id, progress_id)
		)
		if not applied:
			_show_pending_skill_talent_choice(main)
			return
		main.player.level_up_active = false
		main.player.active_upgrade_kind = ""
		main.player.current_blessing_offer = {}
		if _show_pending_skill_talent_choice(main):
			return
		main.reward_context = ""
		_schedule_post_reward_maintenance(main, true)
		return

	if main.reward_context == SKILL_POINT_CONTEXT:
		var offer: Dictionary = main.player.current_blessing_offer if main.player != null and main.player.get("current_blessing_offer") is Dictionary else {}
		var options: Array = offer.get("options", []) if offer.get("options", []) is Array else []
		var was_offered := false
		for option_value in options:
			if option_value is Dictionary and str((option_value as Dictionary).get("id", "")) == option_id:
				was_offered = true
				break
		if was_offered and main.player != null and main.player.spend_skill_point():
			_apply_player_upgrade(main, option_id)
		if main.player != null:
			main.player.level_up_active = false
			main.player.active_upgrade_kind = ""
			main.player.current_blessing_offer = {}
		if _show_pending_blessing_binding_choice(main, SKILL_POINT_CONTEXT):
			return
		main.reward_context = ""
		_schedule_post_reward_maintenance(main)
		return

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
		if return_context == "level_up" and _show_pending_skill_talent_choice(main):
			return
		if return_context == SKILL_POINT_CONTEXT:
			main.reward_context = ""
			_schedule_post_reward_maintenance(main)
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

	if main.reward_context == "level_up":
		var upgrade_ids: Array[String] = []
		if option_id != "":
			upgrade_ids.append(option_id)
		if attribute_option_id != "":
			if _is_attribute_upgrade_option_id(attribute_option_id):
				if main.player != null and main.player.has_method("apply_attribute_upgrade"):
					main.player.apply_attribute_upgrade(attribute_option_id)
			else:
				upgrade_ids.append(attribute_option_id)
		_apply_player_upgrades(main, upgrade_ids)
		if _show_pending_blessing_binding_choice(main):
			return
		if _show_pending_skill_talent_choice(main):
			return
		main.reward_context = ""
		_schedule_post_reward_maintenance(main, true)
		return

	if main.reward_context == "small_boss_reward":
		var offered: Array = main.get_meta(REWARD_OPTIONS_META, [])
		var ids: Array = offered.map(func(option): return str(option.get("id", "")))
		if not ids.has(option_id) or (attribute_option_id != "" and (attribute_option_id == option_id or not ids.has(attribute_option_id))):
			show_small_boss_reward(main)
			return
		var flow = main.get("wave_flow")
		if is_instance_valid(flow):
			flow.small_boss_reward_pending = false
		main.remove_meta(REWARD_OPTIONS_META)
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
	STATE.set_pause_reason(main, "reward", true)
	var options: Array = get_blank_small_boss_reward_options()
	if main.has_meta(REWARD_OPTIONS_META):
		options = main.get_meta(REWARD_OPTIONS_META)
	elif main.player != null and main.player.has_method("get_small_boss_reward_options"):
		options = main.player.get_small_boss_reward_options()
	main.set_meta(REWARD_OPTIONS_META, options.duplicate(true))
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
	STATE.set_pause_reason(main, "reward", true)
	var options: Array = []
	if tier > 0 and main.player.has_method("build_tier_blessing_options"):
		options = main.player.build_tier_blessing_options(tier)
	elif main.player.has_method("build_direct_blessing_options"):
		options = main.player.build_direct_blessing_options()
	var offer_context := _get_current_blessing_offer_context(main)
	var tier_text := "全部祝福" if tier <= 0 else "%s级祝福" % ("II" if tier >= 2 else "I")
	offer_context["summary"] = "Boss 奖励：从%s中自选。剩余 %d 次。" % [tier_text, max(1, choices_remaining)]
	main.level_up_ui.show_options(options, [], offer_context)

static func show_endless_boss_reward(main: Node, settlement: Dictionary = {}) -> void:
	STATE.set_outcome(main, "victory")
	main.reward_context = ENDLESS_TIER_CLEAR_CONTEXT
	STATE.set_pause_reason(main, "result", true)
	if main.level_up_ui == null or not main.level_up_ui.has_method("show_menu"):
		if settlement.is_empty() or str(settlement.get("error", "")) in ["save_failed", "cleanup_failed"]:
			push_error("Endless tier settlement failed and no retry UI is available; the run was preserved.")
			return
		if main.has_method("_finish_endless_tier_clear"):
			main._finish_endless_tier_clear()
		return
	var tier := int(settlement.get("tier", main.get("endless_tier")))
	var description := "本次结算已处理，返回营地。"
	var option_id := ENDLESS_TIER_CLEAR_OPTION_ID
	var option_title := "返回营地"
	if settlement.is_empty() or str(settlement.get("error", "")) in ["save_failed", "cleanup_failed"]:
		description = "奖励已保存，战局清理未完成。请重试结算。" if str(settlement.get("error", "")) == "cleanup_failed" else "永久档案写入失败，当前战局仍保留。请重试结算。"
		option_id = ENDLESS_TIER_CLEAR_RETRY_OPTION_ID
		option_title = "重试结算"
	if bool(settlement.get("applied", false)):
		description = "通关奖励：%d 骨。" % int(settlement.get("base_reward", 0))
		if bool(settlement.get("first_clear", false)):
			description += "\n首通奖励：%d 骨。已解锁 N%d。" % [
				int(settlement.get("first_clear_bonus", 0)),
				int(settlement.get("next_tier", tier + 1))
			]
		if str(settlement.get("error", "")) == "cleanup_failed":
			description += "\n奖励已保存，战局清理未完成。请重试结算。"
	main.level_up_ui.show_menu("N%d 已通关" % tier, [{
		"id": option_id,
		"title": option_title,
		"description": description
	}])

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
	_apply_player_upgrades(main, [option_id])

static func _apply_player_upgrades(main: Node, option_ids: Array) -> void:
	if main.player == null:
		return
	if main.player.has_method("apply_upgrades"):
		main.player.apply_upgrades(option_ids)
		return
	if main.player.has_method("apply_upgrade"):
		for raw_option_id in option_ids:
			var upgrade_id := str(raw_option_id)
			if upgrade_id != "":
				main.player.apply_upgrade(upgrade_id)

static func _is_attribute_upgrade_option_id(option_id: String) -> bool:
	return option_id == "level_trait_team" or option_id.begins_with("level_trait_")
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
	STATE.set_pause_reason(main, "reward", true)
	main.level_up_ui.show_menu("祝福绑定技能", options)
	return true

static func _show_pending_skill_talent_choice(main: Node) -> bool:
	if main.game_over or main.player == null or main.level_up_ui == null:
		return false
	if not main.player.has_method("build_next_skill_talent_offer") or not main.level_up_ui.has_method("show_options"):
		return false
	var offer: Dictionary = main.player.build_next_skill_talent_offer()
	var options: Array = offer.get("options", []) if offer.get("options", []) is Array else []
	var context: Dictionary = offer.get("context", {}) if offer.get("context", {}) is Dictionary else {}
	var expected_option_count := 3 if bool(context.get("level_talent_offer", false)) else 2
	if options.size() != expected_option_count or not bool(context.get("skill_talent_offer", false)):
		if str(main.player.get("active_upgrade_kind")) == "skill_talent":
			main.player.active_upgrade_kind = ""
			main.player.level_up_active = false
			main.player.current_blessing_offer = {}
		return false
	main.player.current_blessing_offer = offer
	main.player.level_up_active = true
	main.player.active_upgrade_kind = "skill_talent"
	main.reward_context = SKILL_TALENT_CONTEXT
	STATE.set_pause_reason(main, "reward", true)
	main.level_up_ui.show_options(options, [], context)
	if main.has_method("_save_run_state"):
		main._save_run_state()
	return true

static func get_save_data(main: Node) -> Dictionary:
	var state := {"context": str(main.reward_context)}
	for key in [REWARD_OPTIONS_META, DIRECT_BLESSING_CHOICES_META, DIRECT_BLESSING_TIER_META, BLESSING_BINDING_CHOICE_META, BLESSING_BINDING_RETURN_CONTEXT_META]:
		if main.has_meta(key):
			state[key] = main.get_meta(key)
	return state

static func resume_saved_reward(main: Node) -> bool:
	if main.has_meta("pending_run_end"):
		main.GAME_SESSION_FLOW.handle_player_died(main, str(main.get_meta("pending_run_end", {}).get("outcome", "failed")))
		return true
	if main.story_mode_active and main.has_meta("pending_story_settlement"):
		finish_story_stage(main)
		return true
	var saved: Dictionary = main.get_meta(SAVED_REWARD_META, {})
	main.remove_meta(SAVED_REWARD_META)
	for key in [REWARD_OPTIONS_META, DIRECT_BLESSING_CHOICES_META, DIRECT_BLESSING_TIER_META, BLESSING_BINDING_CHOICE_META, BLESSING_BINDING_RETURN_CONTEXT_META]:
		if saved.has(key):
			main.set_meta(key, saved[key])
	var wave = main.get("wave_flow")
	if is_instance_valid(wave) and wave.phase == "complete" and not wave.blessing_pending:
		if main.endless_mode_active:
			main.ENEMY_DEFEAT_FLOW._handle_endless_boss_defeated(main)
		else:
			main._on_stage_cleared()
		return true
	if saved.get("context", "") == "small_boss_reward" or (is_instance_valid(wave) and wave.small_boss_reward_pending and wave.phase == "preparation"):
		show_small_boss_reward(main)
		return true
	if saved.get("context", "") == "blessing_binding_choice" and main.has_meta(BLESSING_BINDING_CHOICE_META):
		main.reward_context = "blessing_binding_choice"
		STATE.set_pause_reason(main, "reward", true)
		main.level_up_ui.show_menu("祝福绑定技能", main.player.build_blessing_binding_options(main.get_meta(BLESSING_BINDING_CHOICE_META)))
		return true
	if saved.get("context", "") == "small_boss_blessing_choice":
		show_direct_blessing_choice(main, int(saved.get(DIRECT_BLESSING_CHOICES_META, 1)), int(saved.get(DIRECT_BLESSING_TIER_META, 0)))
		return true
	if saved.get("context", "") == "final_core":
		show_final_core(main)
		return true
	if str(main.player.get("active_upgrade_kind")) == SKILL_POINT_CONTEXT:
		if int(main.player.get("skill_points")) <= 0 or main.level_up_ui == null:
			return false
		main.player.level_up_active = true
		main.reward_context = SKILL_POINT_CONTEXT
		STATE.set_pause_reason(main, "reward", true)
		var offer: Dictionary = main.player.current_blessing_offer
		main.level_up_ui.show_options(offer.get("options", []), [], offer.get("context", {}))
		return true
	if _show_pending_skill_talent_choice(main):
		return true
	var flow = main.get("wave_flow")
	return flow.show_pending_blessing() if is_instance_valid(flow) else false

static func show_wave_blessing(main: Node) -> bool:
	if main.player == null or main.level_up_ui == null or not main.level_up_ui.has_method("show_options"):
		return false
	var flow = main.get("wave_flow")
	if not is_instance_valid(flow) or not flow.blessing_pending:
		return false
	if flow.blessing_offer.is_empty():
		flow.blessing_offer = preload("res://scripts/player/player_blessing_system.gd").build_wave_offer_for_owner(main.player)
	main.player.current_blessing_offer = flow.blessing_offer.duplicate(true)
	main.reward_context = WAVE_BLESSING_CONTEXT
	STATE.set_pause_reason(main, "reward", true)
	main.level_up_ui.show_options(flow.blessing_offer.get("options", []), [], flow.blessing_offer.get("context", {}))
	main._save_run_state()
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
	var wave_flow = main.get("wave_flow")
	if is_instance_valid(wave_flow) and wave_flow.show_pending_blessing():
		return
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
