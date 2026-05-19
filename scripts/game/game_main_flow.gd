extends RefCounted

const PERFORMANCE_RECORDER := preload("res://scripts/game/performance_recorder.gd")


static func ready(main: Node) -> void:
	main.rng.randomize()
	main.player = find_player(main)

	if main.player == null:
		push_error("Main.gd could not find a player node.")
		return

	main._load_story_stage_context()
	main._apply_story_loadout()

	main._setup_spawn_timer()
	main._setup_ui()
	main._setup_map_features()
	main._connect_player_signals()

	var should_continue: bool = bool(main.SAVE_MANAGER.consume_continue_request()) and bool(main.SAVE_MANAGER.has_save())
	if should_continue and main._load_saved_run():
		main.loaded_from_save = true
		main._show_pause_menu_after_continue()
	else:
		main.loaded_from_save = false
		main._start_game_bgm()

	if main._is_developer_mode():
		main._activate_developer_mode()


static func handle_notification(main: Node, what: int) -> void:
	if what == main.NOTIFICATION_WM_CLOSE_REQUEST:
		if not main.game_over:
			main._save_run_state()
			main.exit_snapshot_saved = true
	elif what == main.NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not main.game_over:
			main._save_run_state()


static func exit_tree(main: Node) -> void:
	if not main.game_over and not main.suppress_exit_save and not main.exit_snapshot_saved:
		main._save_run_state()
	main._cleanup_runtime_nodes()


static func cleanup_runtime_nodes(main: Node) -> void:
	main.ENEMY_HIT_FEEDBACK.clear_runtime_state()
	main.PLAYER_BULLET.clear_runtime_state()
	var game_bgm = main._get_game_bgm()
	if game_bgm != null and game_bgm.has_method("stop"):
		game_bgm.stop()
	if game_bgm != null:
		game_bgm.set("stream", null)
	var tree: SceneTree = main.get_tree()
	if tree != null:
		for effect in tree.get_nodes_in_group("temporary_effects"):
			if effect != null and is_instance_valid(effect):
				if effect is Node and not effect.is_queued_for_deletion():
					effect.free()


static func unhandled_input(main: Node, event: InputEvent) -> void:
	if main.game_over:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if main.GAME_SETTINGS.event_matches_action(event, main.GAME_SETTINGS.ACTION_CHARACTER_PANEL):
			main._toggle_character_panel()
			main.get_viewport().set_input_as_handled()
			return
		if main.character_panel != null and main.character_panel.visible and event.keycode == KEY_ESCAPE:
			main._hide_character_panel()
			main.get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			main._handle_escape_toggle()


static func process(main: Node, delta: float) -> void:
	PERFORMANCE_RECORDER.record_frame(delta)
	if main.game_over or main.get_tree().paused:
		main._update_performance_metrics(delta)
		return

	PERFORMANCE_RECORDER.begin_scope("script_logic_ms")
	main.survival_time += delta
	main.autosave_elapsed += delta
	if main._is_developer_mode():
		PERFORMANCE_RECORDER.begin_scope("developer_mode_ms")
		main._update_developer_mode(delta)
		PERFORMANCE_RECORDER.end_scope("developer_mode_ms")
	else:
		PERFORMANCE_RECORDER.begin_scope("spawn_events_ms")
		main._update_spawn_curve()
		main._handle_stage_events()
		PERFORMANCE_RECORDER.end_scope("spawn_events_ms")

	if main.autosave_elapsed >= main.autosave_interval:
		main.autosave_elapsed = 0.0
		main._save_run_state()

	PERFORMANCE_RECORDER.begin_scope("hud_frame_ms")
	main.GAME_HUD_FLOW.update_frame_hud(main)
	PERFORMANCE_RECORDER.end_scope("hud_frame_ms")
	PERFORMANCE_RECORDER.begin_scope("minimap_ms")
	main._update_minimap(delta)
	PERFORMANCE_RECORDER.end_scope("minimap_ms")
	PERFORMANCE_RECORDER.begin_scope("pending_spawns_ms")
	main._process_pending_enemy_spawns()
	PERFORMANCE_RECORDER.end_scope("pending_spawns_ms")
	PERFORMANCE_RECORDER.begin_scope("pickup_compaction_ms")
	main._update_pickup_compaction(delta)
	PERFORMANCE_RECORDER.end_scope("pickup_compaction_ms")
	PERFORMANCE_RECORDER.begin_scope("distant_enemy_maintenance_ms")
	main._update_distant_enemy_maintenance(delta)
	PERFORMANCE_RECORDER.end_scope("distant_enemy_maintenance_ms")
	PERFORMANCE_RECORDER.begin_scope("performance_metrics_ms")
	main._update_performance_metrics(delta)
	PERFORMANCE_RECORDER.end_scope("performance_metrics_ms")
	PERFORMANCE_RECORDER.end_scope("script_logic_ms")


static func find_player(main: Node) -> Node2D:
	if main.has_node("player"):
		return main.get_node("player") as Node2D
	if main.has_node("Player"):
		return main.get_node("Player") as Node2D

	for child in main.get_children():
		if child is CharacterBody2D:
			return child as Node2D

	return null
