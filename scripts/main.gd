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
const BLESSING_UNLOCK_NOTICE_FLOW := preload("res://scripts/game/blessing_unlock_notice_flow.gd")
const PICKUP_COMPACTOR := preload("res://scripts/game/pickup_compactor.gd")
const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")
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
var minimap_update_interval: float = 0.18
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
	ENEMY_HIT_FEEDBACK.clear_runtime_state()
	PLAYER_BULLET.clear_runtime_state()
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
	_update_minimap(delta)
	_process_pending_enemy_spawns()
	_update_pickup_compaction(delta)
	_update_distant_enemy_maintenance(delta)
	_update_performance_metrics(delta)

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

func _is_runtime_node_valid(node: Variant) -> bool:
	if node == null:
		return false
	if not is_instance_valid(node):
		return false
	var typed_node := node as Node
	if typed_node == null:
		return false
	return not typed_node.is_queued_for_deletion()

func _rebuild_runtime_registry_cache(registry: Dictionary) -> Array:
	var cache: Array = []
	var stale_ids: Array = []
	for instance_id in registry.keys():
		var node = registry[instance_id]
		if _is_runtime_node_valid(node):
			cache.append(node)
		else:
			stale_ids.append(instance_id)
	for instance_id in stale_ids:
		registry.erase(instance_id)
	return cache

func _ensure_runtime_pickup_registry(group_name: String) -> Dictionary:
	if not runtime_pickup_nodes.has(group_name):
		runtime_pickup_nodes[group_name] = {}
		runtime_pickup_cache[group_name] = []
		runtime_pickup_cache_dirty[group_name] = false
		runtime_pickup_grid_cache[group_name] = {}
		runtime_pickup_grid_cache_dirty[group_name] = true
		runtime_pickup_grid_cache_frame[group_name] = -1
	return runtime_pickup_nodes[group_name]

func _mark_runtime_pickup_cache_dirty(group_name: String) -> void:
	runtime_pickup_cache_dirty[group_name] = true
	runtime_pickup_grid_cache_dirty[group_name] = true

func register_runtime_pickup(group_name: String, node: Node) -> void:
	if node == null:
		return
	var nodes: Dictionary = _ensure_runtime_pickup_registry(group_name)
	var instance_id := node.get_instance_id()
	if not nodes.has(instance_id):
		nodes[instance_id] = node
		_mark_runtime_pickup_cache_dirty(group_name)

func unregister_runtime_pickup(group_name: String, node: Node) -> void:
	if node == null or not runtime_pickup_nodes.has(group_name):
		return
	var nodes: Dictionary = runtime_pickup_nodes[group_name]
	var instance_id := node.get_instance_id()
	if nodes.erase(instance_id):
		_mark_runtime_pickup_cache_dirty(group_name)

func get_runtime_pickups(group_name: String) -> Array:
	var nodes: Dictionary = _ensure_runtime_pickup_registry(group_name)
	if bool(runtime_pickup_cache_dirty.get(group_name, true)) or not runtime_pickup_cache.has(group_name):
		runtime_pickup_cache[group_name] = _rebuild_runtime_registry_cache(nodes)
		runtime_pickup_cache_dirty[group_name] = false
	return runtime_pickup_cache[group_name]

func get_runtime_pickups_in_radius(group_name: String, center: Vector2, radius: float) -> Array:
	var grid: Dictionary = _get_runtime_pickup_grid(group_name)
	if grid.is_empty():
		return []
	return _collect_runtime_pickups_from_grid(grid, center, radius)

func _collect_runtime_pickups_from_grid(grid: Dictionary, center: Vector2, radius: float) -> Array:
	var safe_radius: float = max(1.0, radius)
	var min_cell: Vector2i = _pickup_grid_cell(center - Vector2.ONE * safe_radius)
	var max_cell: Vector2i = _pickup_grid_cell(center + Vector2.ONE * safe_radius)
	var candidates: Array = []
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			var cell: Vector2i = Vector2i(x, y)
			if grid.has(cell):
				candidates.append_array(grid[cell] as Array)
	return candidates

func _get_runtime_pickup_grid(group_name: String) -> Dictionary:
	_ensure_runtime_pickup_registry(group_name)
	var current_frame: int = Engine.get_physics_frames()
	if not bool(runtime_pickup_grid_cache_dirty.get(group_name, true)) \
			and int(runtime_pickup_grid_cache_frame.get(group_name, -1)) == current_frame \
			and runtime_pickup_grid_cache.has(group_name):
		return runtime_pickup_grid_cache[group_name]
	var grid: Dictionary = {}
	for pickup in get_runtime_pickups(group_name):
		if not _is_runtime_node_valid(pickup) or pickup is not Node2D:
			continue
		var cell: Vector2i = _pickup_grid_cell((pickup as Node2D).global_position)
		if not grid.has(cell):
			grid[cell] = []
		(grid[cell] as Array).append(pickup)
	runtime_pickup_grid_cache[group_name] = grid
	runtime_pickup_grid_cache_dirty[group_name] = false
	runtime_pickup_grid_cache_frame[group_name] = current_frame
	return grid

func _pickup_grid_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / PICKUP_GRID_CELL_SIZE), floori(position.y / PICKUP_GRID_CELL_SIZE))

func release_runtime_pickup(group_name: String, node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	unregister_runtime_pickup(group_name, node)
	if not runtime_pickup_pool_nodes.has(group_name):
		runtime_pickup_pool_nodes[group_name] = {}
	var pool: Dictionary = runtime_pickup_pool_nodes[group_name]
	if pool.size() >= runtime_pickup_pool_limit:
		node.queue_free()
		return
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.hide()
	node.set_process(false)
	node.set_physics_process(false)
	pool[node.get_instance_id()] = node

func take_runtime_pickup_from_pool(group_name: String) -> Node:
	if not runtime_pickup_pool_nodes.has(group_name):
		return null
	var pool: Dictionary = runtime_pickup_pool_nodes[group_name]
	for instance_id in pool.keys():
		var node = pool[instance_id]
		pool.erase(instance_id)
		if _is_runtime_node_valid(node):
			return node
	return null

func register_runtime_enemy(enemy: Node) -> void:
	if enemy == null:
		return
	var instance_id := enemy.get_instance_id()
	runtime_enemy_pool_nodes.erase(instance_id)
	if not runtime_enemy_nodes.has(instance_id):
		runtime_enemy_nodes[instance_id] = enemy
		runtime_enemy_cache_dirty = true

func unregister_runtime_enemy(enemy: Node) -> void:
	if enemy == null:
		return
	var instance_id := enemy.get_instance_id()
	if runtime_enemy_nodes.erase(instance_id):
		runtime_enemy_cache_dirty = true

func get_runtime_enemies() -> Array:
	if runtime_enemy_cache_dirty:
		runtime_enemy_cache = _rebuild_runtime_registry_cache(runtime_enemy_nodes)
		runtime_enemy_cache_dirty = false
	return runtime_enemy_cache

func queue_runtime_enemy_spawn(request: Dictionary) -> void:
	if request.is_empty():
		return
	pending_enemy_spawn_requests.append(request)

func _process_pending_enemy_spawns() -> void:
	if pending_enemy_spawn_cursor >= pending_enemy_spawn_requests.size():
		_clear_pending_enemy_spawn_requests_if_needed()
		return
	var processed := 0
	var process_limit := _get_enemy_spawn_process_limit()
	while processed < process_limit and pending_enemy_spawn_cursor < pending_enemy_spawn_requests.size():
		var request: Dictionary = pending_enemy_spawn_requests[pending_enemy_spawn_cursor]
		pending_enemy_spawn_cursor += 1
		if not request.is_empty():
			_spawn_queued_enemy_request(request)
		processed += 1
	_clear_pending_enemy_spawn_requests_if_needed()

func _spawn_queued_enemy_request(request: Dictionary) -> void:
	if game_over or player == null or enemy_scene == null:
		return
	var kind: String = str(request.get("kind", "normal"))
	var archetype: String = str(request.get("archetype", "chaser"))
	var health_multiplier: float = float(request.get("health_multiplier", 1.0))
	var speed_multiplier: float = float(request.get("speed_multiplier", 1.0))
	var damage_multiplier: float = float(request.get("damage_multiplier", 1.0))
	var spawn_position: Vector2 = request.get("spawn_position", Vector2.ZERO)
	ENEMY_SPAWN_FLOW.spawn_configured_enemy_at(self, kind, archetype, health_multiplier, speed_multiplier, spawn_position, damage_multiplier)

func _clear_pending_enemy_spawn_requests_if_needed() -> void:
	if pending_enemy_spawn_cursor < pending_enemy_spawn_requests.size():
		return
	pending_enemy_spawn_requests.clear()
	pending_enemy_spawn_cursor = 0

func _get_enemy_spawn_process_limit() -> int:
	var fps := Engine.get_frames_per_second()
	if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return 4
	if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return 7
	return 12

func take_runtime_enemy_from_pool() -> Node:
	for instance_id in runtime_enemy_pool_nodes.keys():
		var enemy = runtime_enemy_pool_nodes[instance_id]
		runtime_enemy_pool_nodes.erase(instance_id)
		if _is_runtime_node_valid(enemy):
			return enemy
	return null

func release_runtime_enemy(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	unregister_runtime_enemy(enemy)
	var instance_id := enemy.get_instance_id()
	if runtime_enemy_pool_nodes.size() >= runtime_enemy_pool_limit:
		enemy.queue_free()
		return
	var parent := enemy.get_parent()
	if parent != null:
		parent.remove_child(enemy)
	enemy.hide()
	enemy.set_process(false)
	enemy.set_physics_process(false)
	runtime_enemy_pool_nodes[instance_id] = enemy

func register_runtime_enemy_projectile(projectile: Node, pooled: bool) -> void:
	if projectile == null:
		return
	var instance_id := projectile.get_instance_id()
	var active_changed := runtime_enemy_projectile_nodes.erase(instance_id)
	var pool_changed := runtime_enemy_projectile_pool_nodes.erase(instance_id)
	if pooled:
		if not runtime_enemy_projectile_pool_nodes.has(instance_id):
			runtime_enemy_projectile_pool_nodes[instance_id] = projectile
			pool_changed = true
	else:
		if not runtime_enemy_projectile_nodes.has(instance_id):
			runtime_enemy_projectile_nodes[instance_id] = projectile
			active_changed = true
	if active_changed:
		runtime_enemy_projectile_cache_dirty = true
	if pool_changed:
		runtime_enemy_projectile_pool_cache_dirty = true

func unregister_runtime_enemy_projectile(projectile: Node) -> void:
	if projectile == null:
		return
	var instance_id := projectile.get_instance_id()
	if runtime_enemy_projectile_nodes.erase(instance_id):
		runtime_enemy_projectile_cache_dirty = true
	if runtime_enemy_projectile_pool_nodes.erase(instance_id):
		runtime_enemy_projectile_pool_cache_dirty = true

func get_runtime_enemy_projectiles() -> Array:
	if runtime_enemy_projectile_cache_dirty:
		runtime_enemy_projectile_cache = _rebuild_runtime_registry_cache(runtime_enemy_projectile_nodes)
		runtime_enemy_projectile_cache_dirty = false
	return runtime_enemy_projectile_cache

func get_runtime_enemy_projectile_pool() -> Array:
	if runtime_enemy_projectile_pool_cache_dirty:
		runtime_enemy_projectile_pool_cache = _rebuild_runtime_registry_cache(runtime_enemy_projectile_pool_nodes)
		runtime_enemy_projectile_pool_cache_dirty = false
	return runtime_enemy_projectile_pool_cache

func take_runtime_enemy_projectile_from_pool() -> Node:
	for instance_id in runtime_enemy_projectile_pool_nodes.keys():
		var projectile = runtime_enemy_projectile_pool_nodes[instance_id]
		runtime_enemy_projectile_pool_nodes.erase(instance_id)
		runtime_enemy_projectile_pool_cache_dirty = true
		if _is_runtime_node_valid(projectile):
			return projectile
	return null

func register_runtime_player_projectile(projectile: Node) -> void:
	if projectile == null:
		return
	var instance_id := projectile.get_instance_id()
	if not runtime_player_projectile_nodes.has(instance_id):
		runtime_player_projectile_nodes[instance_id] = projectile
		runtime_player_projectile_cache_dirty = true

func unregister_runtime_player_projectile(projectile: Node) -> void:
	if projectile == null:
		return
	var instance_id := projectile.get_instance_id()
	if runtime_player_projectile_nodes.erase(instance_id):
		runtime_player_projectile_cache_dirty = true

func get_runtime_player_projectiles() -> Array:
	if runtime_player_projectile_cache_dirty:
		runtime_player_projectile_cache = _rebuild_runtime_registry_cache(runtime_player_projectile_nodes)
		runtime_player_projectile_cache_dirty = false
	return runtime_player_projectile_cache

func release_runtime_player_projectile(projectile: Node, pool_key: String = "") -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	var resolved_key := pool_key if pool_key != "" else projectile.scene_file_path
	if resolved_key == "":
		resolved_key = projectile.get_script().resource_path if projectile.get_script() != null else "default"
	if not runtime_player_projectile_pool_nodes.has(resolved_key):
		runtime_player_projectile_pool_nodes[resolved_key] = {}
		runtime_player_projectile_pool_cache[resolved_key] = []
		runtime_player_projectile_pool_cache_dirty[resolved_key] = false
	var pool: Dictionary = runtime_player_projectile_pool_nodes[resolved_key]
	if pool.size() >= runtime_player_projectile_pool_limit:
		projectile.queue_free()
		return
	var instance_id := projectile.get_instance_id()
	pool[instance_id] = projectile
	runtime_player_projectile_pool_cache_dirty[resolved_key] = true

func take_runtime_player_projectile_from_pool(pool_key: String = "") -> Node:
	var resolved_key := pool_key if pool_key != "" else "default"
	if not runtime_player_projectile_pool_nodes.has(resolved_key):
		return null
	var pool: Dictionary = runtime_player_projectile_pool_nodes[resolved_key]
	for instance_id in pool.keys():
		var projectile = pool[instance_id]
		pool.erase(instance_id)
		runtime_player_projectile_pool_cache_dirty[resolved_key] = true
		if _is_runtime_node_valid(projectile):
			return projectile
	return null

func get_runtime_player_projectile_pool(pool_key: String = "") -> Array:
	var resolved_key := pool_key if pool_key != "" else "default"
	if not runtime_player_projectile_pool_nodes.has(resolved_key):
		return []
	if bool(runtime_player_projectile_pool_cache_dirty.get(resolved_key, true)) or not runtime_player_projectile_pool_cache.has(resolved_key):
		runtime_player_projectile_pool_cache[resolved_key] = _rebuild_runtime_registry_cache(runtime_player_projectile_pool_nodes[resolved_key])
		runtime_player_projectile_pool_cache_dirty[resolved_key] = false
	return runtime_player_projectile_pool_cache[resolved_key]

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
