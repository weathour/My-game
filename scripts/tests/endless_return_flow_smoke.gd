extends SceneTree

const REWARD_FLOW := preload("res://scripts/game/reward_flow.gd")
const PAUSE_MENU := preload("res://scripts/pause_menu.gd")
const GAME_OVER_UI := preload("res://scripts/game_over_ui.gd")
const MAIN_MENU_SETTINGS_PANEL := preload("res://scripts/ui/main_menu/main_menu_settings_panel.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var main := MainStub.new()
	root.add_child(main)
	main.player = PlayerStub.new()
	main.add_child(main.player)
	main.level_up_ui = LevelUpStub.new()
	main.add_child(main.level_up_ui)

	REWARD_FLOW.show_endless_boss_reward(main, {
		"applied": true,
		"tier": 3,
		"base_reward": 8,
		"first_clear": true,
		"first_clear_bonus": 14,
		"next_tier": 4
	})
	assert(main.reward_context == REWARD_FLOW.ENDLESS_TIER_CLEAR_CONTEXT)
	assert(main.level_up_ui.last_title == "N3 已通关")
	assert(main.level_up_ui.last_option_ids == [REWARD_FLOW.ENDLESS_TIER_CLEAR_OPTION_ID])
	assert(main.level_up_ui.last_description.contains("首通奖励：14 骨"))
	REWARD_FLOW.handle_upgrade_selected(main, REWARD_FLOW.ENDLESS_TIER_CLEAR_OPTION_ID)
	assert(main.finish_count == 1)

	var pause_menu := PAUSE_MENU.new()
	root.add_child(pause_menu)
	await process_frame
	pause_menu.set_endless_mode_enabled(true)
	await process_frame
	assert(pause_menu.end_run_button.visible)
	pause_menu.settings_panel.open()
	assert(pause_menu.settings_panel.visible)
	pause_menu.settings_panel.close_panel()
	pause_menu._on_end_run_pressed()
	assert(pause_menu.end_run_confirm_dialog != null)
	var end_requested := [false]
	pause_menu.end_run_requested.connect(func(): end_requested[0] = true)
	pause_menu.end_run_confirm_dialog.confirmed.emit()
	assert(end_requested[0])

	var settings_panel := MAIN_MENU_SETTINGS_PANEL.new()
	root.add_child(settings_panel)
	await process_frame
	settings_panel._show_display_settings()
	settings_panel.open()
	settings_panel._show_display_settings()
	await process_frame
	_assert_inside_modal(settings_panel.hud_layout_option, settings_panel.modal)
	settings_panel.page_scroll.ensure_control_visible(settings_panel.comfort_checks["large_story_text"])
	await process_frame
	_assert_inside_modal(settings_panel.comfort_checks["large_story_text"], settings_panel.modal)

	var game_over_ui := GAME_OVER_UI.new()
	root.add_child(game_over_ui)
	await process_frame
	game_over_ui.show_game_over(65.0, 7, true)
	assert(game_over_ui.restart_button.text == "返回营地")
	var camp_requested := [false]
	game_over_ui.return_to_camp_requested.connect(func(): camp_requested[0] = true)
	game_over_ui._on_restart_pressed()
	assert(camp_requested[0])

	print("ENDLESS_RETURN_FLOW_SMOKE_OK")
	quit(0)

func _assert_inside_modal(control: Control, modal: Control) -> void:
	var panel_control := modal.get("panel") as Control
	var control_rect: Rect2 = control.get_global_rect()
	var panel_rect: Rect2 = panel_control.get_global_rect()
	assert(control_rect.position.y >= panel_rect.position.y)
	assert(control_rect.end.y <= panel_rect.end.y)

func _last_label(parent: Node) -> Label:
	for index in range(parent.get_child_count() - 1, -1, -1):
		var child := parent.get_child(index)
		if child is Label:
			return child as Label
	assert(false, "Expected a label")
	return null

class MainStub:
	extends Node

	var player: Node
	var level_up_ui: Node
	var reward_context := ""
	var game_over := false
	var finish_count := 0

	func _finish_endless_tier_clear() -> void:
		finish_count += 1

class PlayerStub:
	extends Node

	pass

class LevelUpStub:
	extends Node

	var last_option_ids: Array = []
	var last_title := ""
	var last_description := ""

	func show_menu(title: String, options: Array) -> void:
		last_title = title
		last_option_ids.clear()
		last_description = ""
		for option_value in options:
			last_option_ids.append(str((option_value as Dictionary).get("id", "")))
			last_description = str((option_value as Dictionary).get("description", ""))

	func hide_ui() -> void:
		pass
