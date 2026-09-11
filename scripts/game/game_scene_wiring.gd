extends RefCounted

const CHARACTER_PANEL := preload("res://scripts/ui/hud/character_panel.gd")
const ENEMY_DEBUG_RANGE_OVERLAY := preload("res://scripts/debug/enemy_debug_range_overlay.gd")
const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")

# Handoff note:
# This file owns scene-local node creation and signal wiring for scripts/main.gd.
# Keep domain consequences in dedicated flows:
# - enemy defeat -> enemy_defeat_flow.gd
# - rewards -> reward_flow.gd
# - session/pause/death -> game_session_flow.gd
#
# Add new UI panels or scene-local signals here so main.gd remains the battle
# composition root instead of a long list of wiring details.

static func setup_ui(main: Node) -> void:
	_setup_hud(main)
	_setup_character_panel(main)
	_setup_level_up_ui(main)
	_setup_pause_menu(main)
	_setup_game_over_ui(main)
	_setup_enemy_debug_range_overlay(main)

static func connect_player_signals(main: Node) -> void:
	if main.player == null:
		return
	_connect_if_present(main.player, "experience_changed", Callable(main, "_on_player_experience_changed"))
	_connect_if_present(main.player, "level_up_requested", Callable(main, "_on_player_level_up_requested"))
	_connect_if_present(main.player, "stats_changed", Callable(main, "_on_player_stats_changed"))
	_connect_if_present(main.player, "health_changed", Callable(main, "_on_player_health_changed"))
	_connect_if_present(main.player, "mana_changed", Callable(main, "_on_player_mana_changed"))
	_connect_if_present(main.player, "died", Callable(main, "_on_player_died"))
	_connect_if_present(main.player, "blessing_skill_event_announced", Callable(main, "_on_player_blessing_skill_event_announced"))

static func _setup_hud(main: Node) -> void:
	if main.hud_scene == null:
		return
	main.hud = main.hud_scene.instantiate()
	main.add_child(main.hud)
	_connect_if_present(main.hud, "endless_speed_toggled", Callable(main, "_on_endless_speed_toggled"))
	if main.hud.has_method("set_endless_mode_enabled"):
		main.hud.set_endless_mode_enabled(main.endless_mode_active)
	_connect_if_present(main.hud, "developer_level_up_requested", Callable(main, "_on_developer_level_up_requested"))
	_connect_if_present(main.hud, "developer_boss_spawn_requested", Callable(main, "_on_developer_boss_spawn_requested"))
	_connect_if_present(main.hud, "developer_small_boss_spawn_requested", Callable(main, "_on_developer_small_boss_spawn_requested"))
	_connect_if_present(main.hud, "developer_normal_enemy_batch_spawn_requested", Callable(main, "_on_developer_normal_enemy_batch_spawn_requested"))
	_connect_if_present(main.hud, "developer_enemy_spawn_requested", Callable(main, "_on_developer_enemy_spawn_requested"))
	_connect_if_present(main.hud, "developer_skill_unlock_requested", Callable(main, "_on_developer_skill_unlock_requested"))
	_connect_if_present(main.hud, "developer_skill_talent_grant_requested", Callable(main, "_on_developer_skill_talent_grant_requested"))
	_connect_if_present(main.hud, "developer_blessing_grant_requested", Callable(main, "_on_developer_blessing_grant_requested"))
	_connect_if_present(main.hud, "developer_all_blessings_grant_requested", Callable(main, "_on_developer_all_blessings_grant_requested"))
	_connect_if_present(main.hud, "developer_ruan_stone_action_requested", Callable(main, "_on_developer_ruan_stone_action_requested"))
	_connect_if_present(main.hud, "developer_enemy_detail_display_toggled", Callable(main, "_on_developer_enemy_detail_display_toggled"))
	_connect_if_present(main.hud, "developer_glutton_skill_test_requested", Callable(main, "_on_developer_glutton_skill_test_requested"))
	_connect_if_present(main.hud, "developer_endless_tier_test_requested", Callable(main, "_on_developer_endless_tier_test_requested"))

static func _setup_character_panel(main: Node) -> void:
	main.character_panel = CHARACTER_PANEL.new()
	main.add_child(main.character_panel)
	main.character_panel.close_requested.connect(Callable(main, "_hide_character_panel"))

static func _setup_level_up_ui(main: Node) -> void:
	if main.level_up_ui_scene == null:
		return
	main.level_up_ui = main.level_up_ui_scene.instantiate()
	main.add_child(main.level_up_ui)
	_connect_if_present(main.level_up_ui, "upgrade_selected", Callable(main, "_on_upgrade_selected"))
	_connect_if_present(main.level_up_ui, "upgrade_refresh_requested", Callable(main, "_on_upgrade_refresh_requested"))
	_connect_if_present(main.level_up_ui, "upgrade_card_refresh_requested", Callable(main, "_on_upgrade_card_refresh_requested"))

static func _setup_pause_menu(main: Node) -> void:
	if main.pause_menu_scene == null:
		return
	main.pause_menu = main.pause_menu_scene.instantiate()
	main.add_child(main.pause_menu)
	_connect_if_present(main.pause_menu, "resume_requested", Callable(main, "_on_resume_requested"))
	_connect_if_present(main.pause_menu, "restart_requested", Callable(main, "_on_restart_requested"))
	_connect_if_present(main.pause_menu, "main_menu_requested", Callable(main, "_on_main_menu_requested"))
	_connect_if_present(main.pause_menu, "end_run_requested", Callable(main, "_on_endless_return_to_camp_requested"))
	if main.pause_menu.has_method("set_endless_mode_enabled"):
		main.pause_menu.set_endless_mode_enabled(main.endless_mode_active)
	if main.hud != null and main.hud.has_method("set_hud_layout"):
		_connect_if_present(main.pause_menu, "hud_layout_changed", Callable(main.hud, "set_hud_layout"))

static func _setup_game_over_ui(main: Node) -> void:
	if main.game_over_ui_scene == null:
		return
	main.game_over_ui = main.game_over_ui_scene.instantiate()
	main.add_child(main.game_over_ui)
	_connect_if_present(main.game_over_ui, "restart_requested", Callable(main, "_on_restart_requested"))
	_connect_if_present(main.game_over_ui, "return_to_camp_requested", Callable(main, "_on_endless_return_to_camp_requested"))

static func _setup_enemy_debug_range_overlay(main: Node) -> void:
	var overlay := ENEMY_DEBUG_RANGE_OVERLAY.new()
	overlay.name = "EnemyDebugRangeOverlay"
	main.add_child(overlay)
	overlay.configure(main, DEVELOPER_MODE.is_enabled())

static func _connect_if_present(source: Object, signal_name: String, callable: Callable) -> void:
	if source == null:
		return
	if not source.has_signal(signal_name):
		return
	if source.is_connected(signal_name, callable):
		return
	source.connect(signal_name, callable)
