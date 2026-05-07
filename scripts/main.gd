extends Node2D

const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const DEVELOPER_ACTIONS := preload("res://scripts/developer/developer_actions.gd")
const DEVELOPER_OPTION_PROVIDER := preload("res://scripts/developer/developer_option_provider.gd")
const ENEMY_DIRECTOR := preload("res://scripts/enemy/enemy_director.gd")
const ENEMY_SPAWN_FLOW := preload("res://scripts/game/enemy_spawn_flow.gd")
const REWARD_FLOW := preload("res://scripts/game/reward_flow.gd")
const RUN_SAVE_FLOW := preload("res://scripts/game/run_save_flow.gd")
const GAME_SESSION_FLOW := preload("res://scripts/game/game_session_flow.gd")
const GAME_ACHIEVEMENT_BRIDGE := preload("res://scripts/game/game_achievement_bridge.gd")
const ENEMY_DEFEAT_FLOW := preload("res://scripts/game/enemy_defeat_flow.gd")
const GAME_SCENE_WIRING := preload("res://scripts/game/game_scene_wiring.gd")
const GAME_STORY_CONTEXT_FLOW := preload("res://scripts/game/game_story_context_flow.gd")
const GAME_HUD_FLOW := preload("res://scripts/game/game_hud_flow.gd")
const GAME_CHARACTER_PANEL_FLOW := preload("res://scripts/game/game_character_panel_flow.gd")
const GAME_MAP_FLOW := preload("res://scripts/game/game_map_flow.gd")
const PICKUP_COMPACTOR := preload("res://scripts/game/pickup_compactor.gd")
const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")

@export var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
@export var enemy_bullet_scene: PackedScene = preload("res://scenes/enemy_bullet.tscn")
@export var exp_gem_scene: PackedScene = preload("res://scenes/exp_gem.tscn")
@export var heart_pickup_scene: PackedScene = preload("res://scenes/heart_pickup.tscn")
@export var hud_scene: PackedScene = preload("res://scenes/hud.tscn")
@export var level_up_ui_scene: PackedScene = preload("res://scenes/level_up_ui.tscn")
@export var pause_menu_scene: PackedScene = preload("res://scenes/pause_menu.tscn")
@export var game_over_ui_scene: PackedScene = preload("res://scenes/game_over_ui.tscn")
@export var spawn_distance: float = 350.0
@export var autosave_interval: float = 2.0
@export var map_bounds: Rect2 = Rect2(Vector2(-1600.0, -900.0), Vector2(3200.0, 1800.0))

var player
var spawn_timer: Timer
var hud
var character_panel
var level_up_ui
var pause_menu
var game_over_ui
var rng := RandomNumberGenerator.new()
var survival_time: float = 0.0
var autosave_elapsed: float = 0.0
var game_over: bool = false
var loaded_from_save: bool = false
var spawned_elite_count: int = 0
var spawned_small_boss_count: int = 0
var boss_spawned: bool = false
var stage_cleared: bool = false
var boss_enemy: Node2D
var reward_context: String = ""
var story_stage: Dictionary = {}
var story_mode_active: bool = false
var endless_mode_active: bool = false
var difficulty_id: String = "normal"
var difficulty_profile: Dictionary = {}
var suppress_exit_save: bool = false
var defeated_boss_count: int = 0
var exit_snapshot_saved: bool = false
var performance_sample_elapsed: float = 0.0
var pickup_compact_elapsed: float = 0.0
var distant_enemy_maintenance_elapsed: float = 0.0
var distant_enemy_maintenance_cursor: int = 0
var map_boundary_node: Node2D
var runtime_spawn_budget_frame: int = -1
var runtime_spawn_counts: Dictionary = {}
var runtime_pickup_nodes: Dictionary = {
	"exp_gems": [],
	"heart_pickups": []
}
var runtime_enemy_nodes: Array = []
var runtime_enemy_projectile_nodes: Array = []
var runtime_enemy_projectile_pool_nodes: Array = []

func _ready() -> void:
	rng.randomize()
	player = _find_player()

	if player == null:
		push_error("Main.gd could not find a player node.")
		return

	_load_story_stage_context()
	_apply_story_loadout()

	_setup_spawn_timer()
	_setup_ui()
	_setup_map_features()
	_connect_player_signals()

	var should_continue: bool = SAVE_MANAGER.consume_continue_request() and SAVE_MANAGER.has_save()
	if should_continue and _load_saved_run():
		loaded_from_save = true
		_show_pause_menu_after_continue()
	else:
		loaded_from_save = false
		_start_game_bgm()

	if _is_developer_mode():
		_activate_developer_mode()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not game_over:
			_save_run_state()
			exit_snapshot_saved = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not game_over:
			_save_run_state()

func _exit_tree() -> void:
	if not game_over and not suppress_exit_save and not exit_snapshot_saved:
		_save_run_state()
	_cleanup_runtime_nodes()

func _cleanup_runtime_nodes() -> void:
	var game_bgm = _get_game_bgm()
	if game_bgm != null and game_bgm.has_method("stop"):
		game_bgm.stop()
	if game_bgm != null:
		game_bgm.set("stream", null)
	var tree := get_tree()
	if tree != null:
		for effect in tree.get_nodes_in_group("temporary_effects"):
			if effect != null and is_instance_valid(effect):
				if effect is Node and not effect.is_queued_for_deletion():
					effect.free()

func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if GAME_SETTINGS.event_matches_action(event, GAME_SETTINGS.ACTION_CHARACTER_PANEL):
			_toggle_character_panel()
			get_viewport().set_input_as_handled()
			return
		if character_panel != null and character_panel.visible and event.keycode == KEY_ESCAPE:
			_hide_character_panel()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			_handle_escape_toggle()

func _process(delta: float) -> void:
	if game_over or get_tree().paused:
		_update_performance_metrics(delta)
		return

	survival_time += delta
	autosave_elapsed += delta
	if _is_developer_mode():
		_update_developer_mode(delta)
	else:
		_update_spawn_curve()
		_handle_stage_events()

	if autosave_elapsed >= autosave_interval:
		autosave_elapsed = 0.0
		_save_run_state()

	GAME_HUD_FLOW.update_frame_hud(self)
	_update_minimap()
	_update_pickup_compaction(delta)
	_update_distant_enemy_maintenance(delta)
	_update_performance_metrics(delta)

func _setup_spawn_timer() -> void:
	ENEMY_SPAWN_FLOW.setup_spawn_timer(self)

func _setup_ui() -> void:
	GAME_SCENE_WIRING.setup_ui(self)

func _setup_map_features() -> void:
	GAME_MAP_FLOW.setup_map_features(self)

func _update_minimap() -> void:
	GAME_MAP_FLOW.update_minimap(self)

func _connect_player_signals() -> void:
	GAME_SCENE_WIRING.connect_player_signals(self)
	_refresh_hud()

func _refresh_hud() -> void:
	GAME_HUD_FLOW.refresh_hud(self)

func _update_boss_hud() -> void:
	GAME_HUD_FLOW.update_boss_hud(self)

func _update_performance_metrics(delta: float) -> void:
	GAME_HUD_FLOW.update_performance_metrics(self, delta)

func _update_pickup_compaction(delta: float) -> void:
	pickup_compact_elapsed += delta
	if pickup_compact_elapsed < PICKUP_COMPACTOR.COMPACT_INTERVAL:
		return
	pickup_compact_elapsed = 0.0
	PICKUP_COMPACTOR.compact_pickups(self)

func _update_distant_enemy_maintenance(delta: float) -> void:
	distant_enemy_maintenance_elapsed += delta
	if distant_enemy_maintenance_elapsed < 0.75:
		return
	distant_enemy_maintenance_elapsed = 0.0
	ENEMY_SPAWN_FLOW.reposition_distant_normal_enemies(self)

func _toggle_character_panel() -> void:
	GAME_CHARACTER_PANEL_FLOW.toggle_character_panel(self)

func _show_character_panel() -> void:
	GAME_CHARACTER_PANEL_FLOW.show_character_panel(self)

func _hide_character_panel() -> void:
	GAME_CHARACTER_PANEL_FLOW.hide_character_panel(self)

func _handle_escape_toggle() -> void:
	GAME_SESSION_FLOW.handle_escape_toggle(self)

func _show_pause_menu_after_continue() -> void:
	GAME_SESSION_FLOW.show_pause_menu_after_continue(self)

func _resume_game() -> void:
	GAME_SESSION_FLOW.resume_game(self)

func _update_spawn_curve() -> void:
	ENEMY_SPAWN_FLOW.update_spawn_curve(self)

func _handle_stage_events() -> void:
	ENEMY_SPAWN_FLOW.handle_stage_events(self)

func _spawn_enemy() -> void:
	ENEMY_SPAWN_FLOW.spawn_enemy(self)

func _spawn_special_enemy(kind: String) -> Node2D:
	return ENEMY_SPAWN_FLOW.spawn_special_enemy(self, kind)

func _spawn_wave_pack(kind: String, archetype: String, count: int, health_multiplier: float, speed_multiplier: float, damage_multiplier: float = 1.0) -> void:
	ENEMY_SPAWN_FLOW.spawn_wave_pack(self, kind, archetype, count, health_multiplier, speed_multiplier, damage_multiplier)

func _spawn_configured_enemy(kind: String, archetype: String, health_multiplier: float, speed_multiplier: float, spawn_angle: float = INF, distance_offset: float = 0.0, damage_multiplier: float = 1.0) -> Node2D:
	return ENEMY_SPAWN_FLOW.spawn_configured_enemy(self, kind, archetype, health_multiplier, speed_multiplier, spawn_angle, distance_offset, damage_multiplier)

func _get_wave_profile() -> Dictionary:
	return ENEMY_SPAWN_FLOW.get_wave_profile(self)

func _get_player_growth_score() -> float:
	return ENEMY_SPAWN_FLOW.get_player_growth_score(self)

func _get_expected_growth_score() -> float:
	return ENEMY_SPAWN_FLOW.get_expected_growth_score(self)

func _get_spawn_position(angle: float, distance: float) -> Vector2:
	return ENEMY_SPAWN_FLOW.get_spawn_position(self, angle, distance)

func _get_enemy_profile(kind: String, archetype: String) -> Dictionary:
	return ENEMY_SPAWN_FLOW.get_enemy_profile(self, kind, archetype)

func _save_run_state() -> void:
	GAME_ACHIEVEMENT_BRIDGE.record_survival_time(self)
	RUN_SAVE_FLOW.save_run_state(self)

func _load_saved_run() -> bool:
	return RUN_SAVE_FLOW.load_saved_run(self)

func _get_spawn_enemy_health_multiplier(kind: String = "normal") -> float:
	return _get_story_enemy_health_multiplier() * _get_difficulty_enemy_health_multiplier(kind) * ENEMY_DIRECTOR.get_endless_cycle_health_multiplier(_get_endless_cycle_power_level())

func _get_spawn_enemy_speed_multiplier() -> float:
	return _get_story_enemy_speed_multiplier() * _get_difficulty_enemy_speed_multiplier() * ENEMY_DIRECTOR.get_endless_cycle_speed_multiplier(_get_endless_cycle_power_level())

func _get_spawn_enemy_damage_multiplier() -> float:
	return _get_difficulty_enemy_damage_multiplier() * ENEMY_DIRECTOR.get_endless_cycle_damage_multiplier(_get_endless_cycle_power_level())

func _get_endless_cycle_power_level() -> int:
	if not endless_mode_active:
		return 0
	return max(0, defeated_boss_count)

func _get_game_bgm():
	return GAME_SESSION_FLOW.get_game_bgm(self)

func _start_game_bgm() -> void:
	GAME_SESSION_FLOW.start_game_bgm(self)

func _pause_game_bgm() -> void:
	GAME_SESSION_FLOW.pause_game_bgm(self)

func _resume_game_bgm(delay_seconds: float = 0.0) -> void:
	GAME_SESSION_FLOW.resume_game_bgm(self, delay_seconds)

func _on_enemy_defeated(enemy_kind: String, enemy: Node2D) -> void:
	ENEMY_DEFEAT_FLOW.handle_enemy_defeated(self, enemy_kind, enemy)

func _on_stage_cleared() -> void:
	REWARD_FLOW.show_final_core(self)

func _finish_stage_clear() -> void:
	REWARD_FLOW.finish_stage_clear(self)

func _on_player_experience_changed(current_experience: int, required_experience: int, current_level: int) -> void:
	GAME_ACHIEVEMENT_BRIDGE.record_player_level(self, current_level)
	GAME_HUD_FLOW.on_player_experience_changed(self, current_experience, required_experience, current_level)

func _on_player_stats_changed(summary: Dictionary) -> void:
	GAME_HUD_FLOW.on_player_stats_changed(self, summary)

func _on_player_health_changed(current_health: float, max_health: float) -> void:
	GAME_HUD_FLOW.on_player_health_changed(self, current_health, max_health)

func _on_player_mana_changed(current_mana: float, max_mana: float) -> void:
	GAME_HUD_FLOW.on_player_mana_changed(self, current_mana, max_mana)

func _on_player_level_up_requested(options: Array) -> void:
	REWARD_FLOW.show_level_up(self, options)

func _on_upgrade_selected(option_id: String, attribute_option_id: String = "") -> void:
	REWARD_FLOW.handle_upgrade_selected(self, option_id, attribute_option_id)

func _on_upgrade_refresh_requested() -> void:
	REWARD_FLOW.handle_upgrade_refresh_requested(self)

func _on_player_died() -> void:
	GAME_ACHIEVEMENT_BRIDGE.record_survival_time(self)
	GAME_SESSION_FLOW.handle_player_died(self)

func _on_resume_requested() -> void:
	GAME_SESSION_FLOW.resume_game(self)

func _on_restart_requested() -> void:
	GAME_SESSION_FLOW.restart(self)

func _on_main_menu_requested() -> void:
	GAME_SESSION_FLOW.return_to_main_menu(self)

func _load_story_stage_context() -> void:
	GAME_STORY_CONTEXT_FLOW.load_story_stage_context(self)

func _apply_story_loadout() -> void:
	GAME_STORY_CONTEXT_FLOW.apply_story_loadout(self)

func _get_effective_boss_spawn_time() -> float:
	return GAME_STORY_CONTEXT_FLOW.get_effective_boss_spawn_time(self)

func _get_effective_stage_curve_time() -> float:
	return GAME_STORY_CONTEXT_FLOW.get_effective_stage_curve_time(self)

func _get_story_spawn_interval_multiplier() -> float:
	return GAME_STORY_CONTEXT_FLOW.get_story_spawn_interval_multiplier(self)

func _get_difficulty_spawn_interval_multiplier() -> float:
	return GAME_STORY_CONTEXT_FLOW.get_difficulty_spawn_interval_multiplier(self)

func _get_difficulty_minimum_spawn_interval_multiplier() -> float:
	return GAME_STORY_CONTEXT_FLOW.get_difficulty_minimum_spawn_interval_multiplier(self)

func _get_difficulty_enemy_health_multiplier(kind: String = "normal") -> float:
	return GAME_STORY_CONTEXT_FLOW.get_difficulty_enemy_health_multiplier(self, kind)

func _get_difficulty_enemy_speed_multiplier() -> float:
	return GAME_STORY_CONTEXT_FLOW.get_difficulty_enemy_speed_multiplier(self)

func _get_difficulty_enemy_damage_multiplier() -> float:
	return GAME_STORY_CONTEXT_FLOW.get_difficulty_enemy_damage_multiplier(self)

func _get_difficulty_limit(key: String, fallback: int) -> int:
	return GAME_STORY_CONTEXT_FLOW.get_difficulty_limit(self, key, fallback)

func _apply_difficulty_to_wave_profile(wave_profile: Dictionary) -> Dictionary:
	return GAME_STORY_CONTEXT_FLOW.apply_difficulty_to_wave_profile(self, wave_profile)

func _apply_difficulty_to_enemy_profile(kind: String, enemy_profile: Dictionary) -> Dictionary:
	return GAME_STORY_CONTEXT_FLOW.apply_difficulty_to_enemy_profile(self, kind, enemy_profile)

func _can_spawn_runtime_group(group_name: String, fallback_limit: int) -> bool:
	_reset_runtime_spawn_budget_if_needed()
	if not _has_runtime_spawn_frame_budget(group_name):
		return false
	var reserved_count: int = int(runtime_spawn_counts.get(group_name, 0))
	var can_spawn := PERFORMANCE_GUARD.can_spawn_in_group_with_reserved(self, group_name, _get_runtime_group_limit(group_name, fallback_limit), reserved_count)
	if can_spawn:
		runtime_spawn_counts[group_name] = reserved_count + 1
	return can_spawn

func _trim_spawn_count_for_group(group_name: String, requested_count: int, fallback_limit: int) -> int:
	_reset_runtime_spawn_budget_if_needed()
	var reserved_count: int = int(runtime_spawn_counts.get(group_name, 0))
	var allowed_count := PERFORMANCE_GUARD.trim_requested_count_with_reserved(self, group_name, requested_count, _get_runtime_group_limit(group_name, fallback_limit), reserved_count)
	if allowed_count > 0:
		runtime_spawn_counts[group_name] = reserved_count + allowed_count
	return allowed_count

func _get_runtime_group_limit(group_name: String, fallback_limit: int) -> int:
	var base_limit := _get_difficulty_limit(_limit_key_for_group(group_name), fallback_limit)
	return PERFORMANCE_GUARD.get_dynamic_limit(self, group_name, base_limit)

func _reset_runtime_spawn_budget_if_needed() -> void:
	var current_frame := Engine.get_process_frames()
	if runtime_spawn_budget_frame == current_frame:
		return
	runtime_spawn_budget_frame = current_frame
	runtime_spawn_counts.clear()

func _has_runtime_spawn_frame_budget(group_name: String) -> bool:
	var limit := _get_runtime_spawn_frame_limit(group_name)
	if limit <= 0:
		return true
	return int(runtime_spawn_counts.get(group_name, 0)) < limit

func register_runtime_pickup(group_name: String, node: Node) -> void:
	if node == null:
		return
	if not runtime_pickup_nodes.has(group_name):
		runtime_pickup_nodes[group_name] = []
	var nodes: Array = runtime_pickup_nodes[group_name]
	if not nodes.has(node):
		nodes.append(node)

func unregister_runtime_pickup(group_name: String, node: Node) -> void:
	if node == null or not runtime_pickup_nodes.has(group_name):
		return
	var nodes: Array = runtime_pickup_nodes[group_name]
	nodes.erase(node)

func get_runtime_pickups(group_name: String) -> Array:
	if not runtime_pickup_nodes.has(group_name):
		return []
	return runtime_pickup_nodes[group_name]

func register_runtime_enemy(enemy: Node) -> void:
	if enemy == null:
		return
	if not runtime_enemy_nodes.has(enemy):
		runtime_enemy_nodes.append(enemy)

func unregister_runtime_enemy(enemy: Node) -> void:
	if enemy == null:
		return
	runtime_enemy_nodes.erase(enemy)

func get_runtime_enemies() -> Array:
	return runtime_enemy_nodes

func register_runtime_enemy_projectile(projectile: Node, pooled: bool) -> void:
	if projectile == null:
		return
	runtime_enemy_projectile_nodes.erase(projectile)
	runtime_enemy_projectile_pool_nodes.erase(projectile)
	if pooled:
		runtime_enemy_projectile_pool_nodes.append(projectile)
	else:
		runtime_enemy_projectile_nodes.append(projectile)

func unregister_runtime_enemy_projectile(projectile: Node) -> void:
	if projectile == null:
		return
	runtime_enemy_projectile_nodes.erase(projectile)
	runtime_enemy_projectile_pool_nodes.erase(projectile)

func get_runtime_enemy_projectiles() -> Array:
	return runtime_enemy_projectile_nodes

func get_runtime_enemy_projectile_pool() -> Array:
	return runtime_enemy_projectile_pool_nodes

func take_runtime_enemy_projectile_from_pool() -> Node:
	while not runtime_enemy_projectile_pool_nodes.is_empty():
		var projectile: Node = runtime_enemy_projectile_pool_nodes.pop_back()
		if projectile != null and is_instance_valid(projectile):
			return projectile
	return null

func _get_runtime_spawn_frame_limit(group_name: String) -> int:
	match group_name:
		"temporary_effects":
			var fps := Engine.get_frames_per_second()
			if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
				return 8
			if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
				return 14
			return 24
		"player_projectiles":
			return 36
		"enemy_projectiles":
			return 28
		_:
			return 0

func _limit_key_for_group(group_name: String) -> String:
	match group_name:
		"enemies":
			return "active_enemy_limit"
		"enemy_projectiles":
			return "enemy_projectile_limit"
		"player_projectiles":
			return "player_projectile_limit"
		"temporary_effects":
			return "temporary_effect_limit"
		_:
			return ""

func _get_story_enemy_health_multiplier() -> float:
	return GAME_STORY_CONTEXT_FLOW.get_story_enemy_health_multiplier(self)

func _get_story_enemy_speed_multiplier() -> float:
	return GAME_STORY_CONTEXT_FLOW.get_story_enemy_speed_multiplier(self)

func _find_player() -> Node2D:
	if has_node("player"):
		return get_node("player") as Node2D
	if has_node("Player"):
		return get_node("Player") as Node2D

	for child in get_children():
		if child is CharacterBody2D:
			return child as Node2D

	return null

func _is_developer_mode() -> bool:
	return DEVELOPER_MODE.is_enabled()

func _activate_developer_mode() -> void:
	DEVELOPER_ACTIONS.activate(self)

func _update_developer_mode(_delta: float) -> void:
	DEVELOPER_ACTIONS.update(self)

func _on_developer_level_up_requested() -> void:
	DEVELOPER_ACTIONS.grant_level_up(self)

func _on_developer_boss_spawn_requested(archetype_id: String) -> void:
	DEVELOPER_ACTIONS.spawn_boss(self, archetype_id)

func _on_developer_small_boss_spawn_requested(archetype_id: String) -> void:
	DEVELOPER_ACTIONS.spawn_small_boss(self, archetype_id)

func _on_developer_skill_unlock_requested(skill_id: String, tier: int) -> void:
	DEVELOPER_ACTIONS.unlock_skill(self, skill_id, tier)

func _on_developer_blessing_grant_requested(blessing_id: String, tier: int) -> void:
	DEVELOPER_ACTIONS.grant_blessing(self, blessing_id, tier)

func _get_developer_boss_options() -> Array:
	return DEVELOPER_OPTION_PROVIDER.get_boss_options()

func _get_developer_skill_options() -> Array:
	return DEVELOPER_OPTION_PROVIDER.get_skill_options(player)

func _get_developer_blessing_options() -> Array:
	return DEVELOPER_OPTION_PROVIDER.get_blessing_options(player)

func _spawn_developer_boss(archetype_id: String = "boss_spellcore") -> void:
	DEVELOPER_ACTIONS.spawn_boss(self, archetype_id)

func _spawn_developer_small_boss(archetype_id: String) -> void:
	DEVELOPER_ACTIONS.spawn_small_boss(self, archetype_id)

func _has_active_special_enemy(kind: String) -> bool:
	return ENEMY_SPAWN_FLOW.has_active_special_enemy(self, kind)
