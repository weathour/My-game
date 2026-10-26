extends SceneTree

const REWARD_FLOW := preload("res://scripts/game/reward_flow.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_reward_chain_stays_serial()
	await _check_active_talent_save_roundtrip()
	if failures.is_empty():
		print("REWARD_FLOW_TALENT_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_reward_chain_stays_serial() -> void:
	var main := MainStub.new()
	root.add_child(main)
	main.player.pending_binding_choices.append({"blessing_id": "test_blessing"})
	main.player.pending_level_talent_choices = 2
	main.reward_context = "level_up"

	REWARD_FLOW.handle_upgrade_selected(main, "role_build_a", "general_blessing_b")
	_expect(main.player.applied_upgrade_batches == [["role_build_a", "general_blessing_b"]], "normal reward should apply exactly the selected two cards")
	_expect(main.reward_context == "blessing_binding_choice", "blessing binding should run before level talents")
	_expect(main.level_up_ui.talent_option_counts.is_empty(), "talent UI should wait for blessing binding")

	REWARD_FLOW.handle_upgrade_selected(main, "blade_storm")
	_expect(main.player.applied_binding_options == ["blade_storm"], "binding choice should be applied once")
	_expect(main.level_up_ui.talent_option_counts == [3], "first pending level talent should open as three cards")
	_expect(main.maintenance_calls.is_empty(), "maintenance should wait until all talents finish")

	REWARD_FLOW.handle_upgrade_card_refresh_requested(main, 1)
	_expect(main.player.refresh_indices == [1], "skill talent card refresh should be routed to the player")
	_expect(main.player.refresh_role_ids == ["gunner"], "skill talent refresh should include the selected role")
	_expect(main.level_up_ui.refreshed_option_counts == [3], "refreshed talent UI should still show three cards")

	var first_choice := str((main.player.current_blessing_offer.get("options", [])[0] as Dictionary).get("id", ""))
	REWARD_FLOW.handle_upgrade_selected(main, first_choice)
	_expect(main.player.applied_talent_ids.size() == 1, "first level talent should be applied once")
	_expect(main.player.pending_level_talent_choices == 1, "one queued level talent should remain")
	_expect(main.level_up_ui.talent_option_counts == [3, 3], "multiple level talents should open one at a time")
	_expect(main.maintenance_calls.is_empty(), "next normal upgrade should still wait for remaining talents")

	var second_choice := str((main.player.current_blessing_offer.get("options", [])[2] as Dictionary).get("id", ""))
	REWARD_FLOW.handle_upgrade_selected(main, second_choice)
	_expect(main.player.applied_talent_ids.size() == 2, "each pending level talent should be applied once")
	_expect(main.player.pending_level_talent_choices == 0, "all queued level talents should be consumed")
	_expect(main.maintenance_calls == [true], "reward maintenance should resume only after the last talent")
	_expect(main.player.resume_count == 1, "the next normal upgrade should resume once after the talent chain")
	_expect(main.reward_context == "", "reward context should clear after the serial chain")

	main.queue_free()
	paused = false


func _check_active_talent_save_roundtrip() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var source = PLAYER_SCENE.instantiate()
	var target = PLAYER_SCENE.instantiate()
	scene.add_child(source)
	scene.add_child(target)
	await process_frame
	if not source.has_method("get_save_data") or not target.has_method("apply_save_data"):
		_expect(false, "player scene must compile before talent save/resume can be verified")
		scene.queue_free()
		await process_frame
		current_scene = null
		return

	source.level = 3
	source.pending_level_ups = 2
	source.pending_level_talent_choices = 1
	source.level_up_active = true
	source.active_upgrade_kind = "skill_talent"
	source.role_special_states["swordsman"] = {
		"level_talents": ["swordsman_level_talent_frontline"],
		"skill_talents": {"swordsman_trait": ["swordsman_trait_blood_battle"]}
	}
	source.current_blessing_offer = source.build_next_skill_talent_offer()
	var saved: Dictionary = source.get_save_data()
	var saved_context: Dictionary = saved.get("active_skill_talent_context", {})

	_expect(int(saved.get("pending_level_ups", -1)) == 2, "active talent save should not create a duplicate normal level-up")
	_expect(int(saved.get("pending_level_talent_choices", -1)) == 1, "active talent save should keep the queued level talent")
	_expect(int(saved.get("skill_points", -1)) == 0, "legacy level-up queue should not be written as spendable points before migration")
	_expect(str(saved.get("active_upgrade_kind", "")) == "skill_talent", "active talent kind should be saved")
	_expect(bool(saved_context.get("level_talent_offer", false)), "active talent context should be saved as a level talent offer")

	target.apply_save_data(saved)
	var resumed_offer: Dictionary = target.build_next_skill_talent_offer()
	var resumed_context: Dictionary = resumed_offer.get("context", {})
	_expect(target.active_upgrade_kind == "skill_talent", "active talent kind should survive load")
	_expect(not target.level_up_active, "loaded talent should be reopened by reward flow instead of staying falsely active")
	_expect(target.pending_level_ups == 0, "legacy level-up queue should be cleared after migration")
	_expect(target.skill_points == 2, "legacy unspent level-ups should migrate to skill points")
	_expect(target.pending_level_talent_choices == 1, "level talent queue should survive active talent load unchanged")
	_expect((resumed_offer.get("options", []) as Array).size() == 3, "loaded run should derive a three-card level talent offer")
	_expect(bool(resumed_context.get("level_talent_offer", false)), "loaded run should resume the level talent interface")
	_expect(not target._has_skill_talent("swordsman_trait_blood_battle"), "legacy skill talents should be cleared by the save roundtrip")
	_expect((target.role_special_states["swordsman"]["skill_talents"] as Dictionary).is_empty(), "legacy skill talent storage should be empty after load")
	_expect(target._has_level_talent("swordsman_level_talent_frontline"), "selected level talents should survive the save roundtrip")

	var save_main := MainStub.new()
	save_main.player = target
	root.add_child(save_main)
	_expect(REWARD_FLOW.resume_saved_reward(save_main), "continue flow should reopen the saved level talent choice")
	_expect(target.level_up_active and target.active_upgrade_kind == "skill_talent", "reopened talent should become the active reward")
	_expect(save_main.level_up_ui.talent_option_counts == [3], "continue flow should reopen a three-card level talent UI")
	_expect(target.pending_level_talent_choices == 1, "reopening a saved talent should not consume the queued choice")
	save_main.queue_free()
	paused = false

	scene.queue_free()
	await process_frame
	current_scene = null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


class MainStub:
	extends Node

	var game_over := false
	var story_mode_active := false
	var reward_context := ""
	var player: Variant = RewardPlayerStub.new()
	var level_up_ui := LevelUpUiStub.new()
	var maintenance_calls: Array[bool] = []

	func _schedule_reward_maintenance(resume_level_ups: bool) -> void:
		maintenance_calls.append(resume_level_ups)
		if resume_level_ups:
			player.resume_pending_level_ups()

	func _save_run_state() -> void:
		pass


class RewardPlayerStub:
	extends RefCounted

	var pending_binding_choices: Array[Dictionary] = []
	var pending_level_talent_choices: int = 0
	var applied_upgrade_batches: Array = []
	var applied_binding_options: Array[String] = []
	var applied_talent_ids: Array[String] = []
	var refresh_indices: Array[int] = []
	var refresh_role_ids: Array[String] = []
	var current_blessing_offer: Dictionary = {}
	var level_up_active := true
	var active_upgrade_kind := "level_up"
	var resume_count := 0

	func apply_upgrades(option_ids: Array) -> void:
		applied_upgrade_batches.append(option_ids.duplicate())
		level_up_active = false
		active_upgrade_kind = ""

	func consume_pending_blessing_binding_choice() -> Dictionary:
		return pending_binding_choices.pop_front() if not pending_binding_choices.is_empty() else {}

	func build_blessing_binding_options(_choice: Dictionary) -> Array:
		return [{"id": "blade_storm"}]

	func apply_blessing_binding_choice(_choice: Dictionary, option_id: String) -> void:
		applied_binding_options.append(option_id)

	func build_next_skill_talent_offer() -> Dictionary:
		if pending_level_talent_choices <= 0:
			return {}
		return {
			"options": [
				_make_talent_option("swordsman", "a"),
				_make_talent_option("gunner", "a"),
				_make_talent_option("mage", "a")
			],
			"context": {
				"skill_talent_offer": true,
				"level_talent_offer": true,
				"selection_count": 1
			}
		}

	func refresh_skill_talent_card(option_index: int, role_id: String = "") -> Array:
		refresh_indices.append(option_index)
		refresh_role_ids.append(role_id)
		var options: Array = (current_blessing_offer.get("options", []) as Array).duplicate(true)
		if option_index >= 0 and option_index < options.size():
			var option_role_id := str((options[option_index] as Dictionary).get("role_id", ""))
			options[option_index] = _make_talent_option(option_role_id, "refreshed")
		current_blessing_offer["options"] = options
		return options

	func get_current_blessing_offer_context() -> Dictionary:
		return current_blessing_offer.get("context", {})

	func apply_skill_talent_choice(option_id: String, expected_progress_id: String = "") -> bool:
		if expected_progress_id != "" or pending_level_talent_choices <= 0:
			return false
		if not option_id.begins_with("skill_talent:"):
			return false
		applied_talent_ids.append(option_id)
		pending_level_talent_choices -= 1
		return true

	func resume_pending_level_ups() -> void:
		resume_count += 1

	func _make_talent_option(role_id: String, suffix: String) -> Dictionary:
		return {
			"id": "skill_talent:%s_%s" % [role_id, suffix],
			"role_id": role_id,
			"title": "%s %s" % [role_id, suffix]
		}


class LevelUpUiStub:
	extends RefCounted

	var talent_option_counts: Array[int] = []
	var refreshed_option_counts: Array[int] = []
	var selected_role_id := "gunner"

	func hide_ui() -> void:
		pass

	func show_menu(_title: String, _options: Array) -> void:
		pass

	func show_options(options: Array, _attribute_options: Array = [], context: Dictionary = {}) -> void:
		if bool(context.get("skill_talent_offer", false)):
			talent_option_counts.append(options.size())

	func show_refreshed_build_options(options: Array, _offer_context: Dictionary, _refreshed_option_index: int) -> void:
		refreshed_option_counts.append(options.size())

	func get_level_talent_selected_role_id() -> String:
		return selected_role_id
