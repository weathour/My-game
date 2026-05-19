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
const GAME_MAIN_FLOW := preload("res://scripts/game/game_main_flow.gd")
const GAME_PHYSICS_FLOW := preload("res://scripts/game/game_physics_flow.gd")
const GAME_ACHIEVEMENT_BRIDGE := preload("res://scripts/game/game_achievement_bridge.gd")
const ENEMY_DEFEAT_FLOW := preload("res://scripts/game/enemy_defeat_flow.gd")
const GAME_SCENE_WIRING := preload("res://scripts/game/game_scene_wiring.gd")
const GAME_STORY_CONTEXT_FLOW := preload("res://scripts/game/game_story_context_flow.gd")
const GAME_HUD_FLOW := preload("res://scripts/game/game_hud_flow.gd")
const GAME_CHARACTER_PANEL_FLOW := preload("res://scripts/game/game_character_panel_flow.gd")
const GAME_MAP_FLOW := preload("res://scripts/game/game_map_flow.gd")
const BLESSING_UNLOCK_NOTICE_FLOW := preload("res://scripts/game/blessing_unlock_notice_flow.gd")
const PICKUP_COMPACTOR := preload("res://scripts/game/pickup_compactor.gd")
const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")
const RUNTIME_SPAWN_BUDGET_FLOW := preload("res://scripts/game/runtime_spawn_budget_flow.gd")
const RUNTIME_REGISTRY_FLOW := preload("res://scripts/game/runtime_registry_flow.gd")
const RUNTIME_PICKUP_REGISTRY_FLOW := preload("res://scripts/game/runtime_pickup_registry_flow.gd")
const RUNTIME_ENEMY_REGISTRY_FLOW := preload("res://scripts/game/runtime_enemy_registry_flow.gd")
const RUNTIME_PROJECTILE_REGISTRY_FLOW := preload("res://scripts/game/runtime_projectile_registry_flow.gd")
const ENEMY_HIT_FEEDBACK := preload("res://scripts/enemies/enemy_hit_feedback.gd")
const PLAYER_BULLET := preload("res://scripts/bullet.gd")

const PICKUP_GRID_CELL_SIZE := 128.0

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
var minimap_update_elapsed: float = 0.0
var minimap_update_interval: float = 1.0 / 30.0
var pickup_compact_elapsed: float = 0.0
var distant_enemy_maintenance_elapsed: float = 0.0
var distant_enemy_maintenance_cursor: int = 0
var map_boundary_node: Node2D
var runtime_spawn_budget_frame: int = -1
var runtime_spawn_counts: Dictionary = {}
var runtime_pickup_nodes: Dictionary = {
	"exp_gems": {},
	"heart_pickups": {}
}
var runtime_pickup_cache: Dictionary = {}
var runtime_pickup_cache_dirty: Dictionary = {}
var runtime_pickup_pool_nodes: Dictionary = {}
var runtime_pickup_pool_limit: int = 160
var runtime_pickup_grid_cache: Dictionary = {}
var runtime_pickup_grid_cache_dirty: Dictionary = {}
var runtime_pickup_grid_cache_frame: Dictionary = {}
var runtime_enemy_nodes: Dictionary = {}
var runtime_enemy_cache: Array = []
var runtime_enemy_cache_dirty: bool = true
var runtime_enemy_pool_nodes: Dictionary = {}
var runtime_enemy_pool_limit: int = 160
var pending_enemy_spawn_requests: Array[Dictionary] = []
var pending_enemy_spawn_cursor: int = 0
var runtime_enemy_projectile_nodes: Dictionary = {}
var runtime_enemy_projectile_cache: Array = []
var runtime_enemy_projectile_cache_dirty: bool = true
var runtime_enemy_projectile_pool_nodes: Dictionary = {}
var runtime_enemy_projectile_pool_cache: Array = []
var runtime_enemy_projectile_pool_cache_dirty: bool = true
var runtime_player_projectile_nodes: Dictionary = {}
var runtime_player_projectile_cache: Array = []
var runtime_player_projectile_cache_dirty: bool = true
var runtime_player_projectile_pool_nodes: Dictionary = {}
var runtime_player_projectile_pool_cache: Dictionary = {}
var runtime_player_projectile_pool_cache_dirty: Dictionary = {}
var runtime_player_projectile_pool_limit: int = 96

func _ready() -> void:
	GAME_MAIN_FLOW.ready(self)

func _notification(what: int) -> void:
	GAME_MAIN_FLOW.handle_notification(self, what)

func _exit_tree() -> void:
	GAME_MAIN_FLOW.exit_tree(self)

func _cleanup_runtime_nodes() -> void:
	GAME_MAIN_FLOW.cleanup_runtime_nodes(self)

func _unhandled_input(event: InputEvent) -> void:
	GAME_MAIN_FLOW.unhandled_input(self, event)

func _process(delta: float) -> void:
	GAME_MAIN_FLOW.process(self, delta)

func _physics_process(delta: float) -> void:
	GAME_PHYSICS_FLOW.physics_process(self, delta)

func _setup_spawn_timer() -> void:
	ENEMY_SPAWN_FLOW.setup_spawn_timer(self)

func _setup_ui() -> void:
	GAME_SCENE_WIRING.setup_ui(self)

func _setup_map_features() -> void:
	GAME_MAP_FLOW.setup_map_features(self)

func _update_minimap(delta: float = 0.0) -> void:
	minimap_update_elapsed += delta
	if minimap_update_elapsed < minimap_update_interval:
		return
	minimap_update_elapsed = 0.0
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

func _on_player_blessing_skill_event_announced(event: Dictionary) -> void:
	BLESSING_UNLOCK_NOTICE_FLOW.show_notice(self, event)

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
	return RUNTIME_SPAWN_BUDGET_FLOW.can_spawn_runtime_group(self, group_name, fallback_limit)

func _trim_spawn_count_for_group(group_name: String, requested_count: int, fallback_limit: int) -> int:
	return RUNTIME_SPAWN_BUDGET_FLOW.trim_spawn_count_for_group(self, group_name, requested_count, fallback_limit)

func _get_runtime_group_limit(group_name: String, fallback_limit: int) -> int:
	return RUNTIME_SPAWN_BUDGET_FLOW.get_runtime_group_limit(self, group_name, fallback_limit)

func _reset_runtime_spawn_budget_if_needed() -> void:
	RUNTIME_SPAWN_BUDGET_FLOW.reset_runtime_spawn_budget_if_needed(self)

func _has_runtime_spawn_frame_budget(group_name: String) -> bool:
	return RUNTIME_SPAWN_BUDGET_FLOW.has_runtime_spawn_frame_budget(self, group_name)

func _is_runtime_node_valid(node: Variant) -> bool:
	return RUNTIME_REGISTRY_FLOW.is_runtime_node_valid(node)

func _rebuild_runtime_registry_cache(registry: Dictionary) -> Array:
	return RUNTIME_REGISTRY_FLOW.rebuild_runtime_registry_cache(registry)

func _ensure_runtime_pickup_registry(group_name: String) -> Dictionary:
	return RUNTIME_PICKUP_REGISTRY_FLOW.ensure_runtime_pickup_registry(self, group_name)

func _mark_runtime_pickup_cache_dirty(group_name: String) -> void:
	RUNTIME_PICKUP_REGISTRY_FLOW.mark_runtime_pickup_cache_dirty(self, group_name)

func register_runtime_pickup(group_name: String, node: Node) -> void:
	RUNTIME_PICKUP_REGISTRY_FLOW.register_runtime_pickup(self, group_name, node)

func unregister_runtime_pickup(group_name: String, node: Node) -> void:
	RUNTIME_PICKUP_REGISTRY_FLOW.unregister_runtime_pickup(self, group_name, node)

func get_runtime_pickups(group_name: String) -> Array:
	return RUNTIME_PICKUP_REGISTRY_FLOW.get_runtime_pickups(self, group_name)

func get_runtime_pickups_in_radius(group_name: String, center: Vector2, radius: float) -> Array:
	return RUNTIME_PICKUP_REGISTRY_FLOW.get_runtime_pickups_in_radius(self, group_name, center, radius)

func _collect_runtime_pickups_from_grid(grid: Dictionary, center: Vector2, radius: float) -> Array:
	return RUNTIME_PICKUP_REGISTRY_FLOW.collect_runtime_pickups_from_grid(self, grid, center, radius)

func _get_runtime_pickup_grid(group_name: String) -> Dictionary:
	return RUNTIME_PICKUP_REGISTRY_FLOW.get_runtime_pickup_grid(self, group_name)

func _pickup_grid_cell(position: Vector2) -> Vector2i:
	return RUNTIME_PICKUP_REGISTRY_FLOW.pickup_grid_cell(self, position)

func release_runtime_pickup(group_name: String, node: Node) -> void:
	RUNTIME_PICKUP_REGISTRY_FLOW.release_runtime_pickup(self, group_name, node)

func take_runtime_pickup_from_pool(group_name: String) -> Node:
	return RUNTIME_PICKUP_REGISTRY_FLOW.take_runtime_pickup_from_pool(self, group_name)

func register_runtime_enemy(enemy: Node) -> void:
	RUNTIME_ENEMY_REGISTRY_FLOW.register_runtime_enemy(self, enemy)

func unregister_runtime_enemy(enemy: Node) -> void:
	RUNTIME_ENEMY_REGISTRY_FLOW.unregister_runtime_enemy(self, enemy)

func get_runtime_enemies() -> Array:
	return RUNTIME_ENEMY_REGISTRY_FLOW.get_runtime_enemies(self)

func queue_runtime_enemy_spawn(request: Dictionary) -> void:
	RUNTIME_ENEMY_REGISTRY_FLOW.queue_runtime_enemy_spawn(self, request)

func _process_pending_enemy_spawns() -> void:
	RUNTIME_ENEMY_REGISTRY_FLOW.process_pending_enemy_spawns(self)

func _spawn_queued_enemy_request(request: Dictionary) -> void:
	RUNTIME_ENEMY_REGISTRY_FLOW.spawn_queued_enemy_request(self, request)

func _clear_pending_enemy_spawn_requests_if_needed() -> void:
	RUNTIME_ENEMY_REGISTRY_FLOW.clear_pending_enemy_spawn_requests_if_needed(self)

func _get_enemy_spawn_process_limit() -> int:
	return RUNTIME_ENEMY_REGISTRY_FLOW.get_enemy_spawn_process_limit(self)

func take_runtime_enemy_from_pool() -> Node:
	return RUNTIME_ENEMY_REGISTRY_FLOW.take_runtime_enemy_from_pool(self)

func release_runtime_enemy(enemy: Node) -> void:
	RUNTIME_ENEMY_REGISTRY_FLOW.release_runtime_enemy(self, enemy)

func register_runtime_enemy_projectile(projectile: Node, pooled: bool) -> void:
	RUNTIME_PROJECTILE_REGISTRY_FLOW.register_runtime_enemy_projectile(self, projectile, pooled)

func unregister_runtime_enemy_projectile(projectile: Node) -> void:
	RUNTIME_PROJECTILE_REGISTRY_FLOW.unregister_runtime_enemy_projectile(self, projectile)

func get_runtime_enemy_projectiles() -> Array:
	return RUNTIME_PROJECTILE_REGISTRY_FLOW.get_runtime_enemy_projectiles(self)

func get_runtime_enemy_projectile_pool() -> Array:
	return RUNTIME_PROJECTILE_REGISTRY_FLOW.get_runtime_enemy_projectile_pool(self)

func take_runtime_enemy_projectile_from_pool() -> Node:
	return RUNTIME_PROJECTILE_REGISTRY_FLOW.take_runtime_enemy_projectile_from_pool(self)

func register_runtime_player_projectile(projectile: Node) -> void:
	RUNTIME_PROJECTILE_REGISTRY_FLOW.register_runtime_player_projectile(self, projectile)

func unregister_runtime_player_projectile(projectile: Node) -> void:
	RUNTIME_PROJECTILE_REGISTRY_FLOW.unregister_runtime_player_projectile(self, projectile)

func get_runtime_player_projectiles() -> Array:
	return RUNTIME_PROJECTILE_REGISTRY_FLOW.get_runtime_player_projectiles(self)

func release_runtime_player_projectile(projectile: Node, pool_key: String = "") -> void:
	RUNTIME_PROJECTILE_REGISTRY_FLOW.release_runtime_player_projectile(self, projectile, pool_key)

func take_runtime_player_projectile_from_pool(pool_key: String = "") -> Node:
	return RUNTIME_PROJECTILE_REGISTRY_FLOW.take_runtime_player_projectile_from_pool(self, pool_key)

func get_runtime_player_projectile_pool(pool_key: String = "") -> Array:
	return RUNTIME_PROJECTILE_REGISTRY_FLOW.get_runtime_player_projectile_pool(self, pool_key)

func _get_runtime_spawn_frame_limit(group_name: String) -> int:
	return RUNTIME_SPAWN_BUDGET_FLOW.get_runtime_spawn_frame_limit(self, group_name)

func _limit_key_for_group(group_name: String) -> String:
	return RUNTIME_SPAWN_BUDGET_FLOW.limit_key_for_group(group_name)

func _get_story_enemy_health_multiplier() -> float:
	return GAME_STORY_CONTEXT_FLOW.get_story_enemy_health_multiplier(self)

func _get_story_enemy_speed_multiplier() -> float:
	return GAME_STORY_CONTEXT_FLOW.get_story_enemy_speed_multiplier(self)

func _find_player() -> Node2D:
	return GAME_MAIN_FLOW.find_player(self)

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
