extends RefCounted

const GAME_ACHIEVEMENT_BRIDGE := preload("res://scripts/game/game_achievement_bridge.gd")
const GAME_HUD_FLOW := preload("res://scripts/game/game_hud_flow.gd")
const REWARD_FLOW := preload("res://scripts/game/reward_flow.gd")
const SAVE_MANAGER := preload("res://scripts/save_manager.gd")

# Handoff note:
# Enemy defeat consequences live here so main.gd stays a combat scene
# composition root. Keep spawn construction in enemy_spawn_flow.gd, reward UI in
# reward_flow.gd, and achievement/stat bookkeeping in game_achievement_bridge.gd.

static func handle_enemy_defeated(main: Node, enemy_kind: String, enemy: Node2D) -> void:
	GAME_ACHIEVEMENT_BRIDGE.record_enemy_defeated(main, enemy_kind)

	if main._is_developer_mode() and enemy_kind == "boss":
		_handle_developer_boss_defeated(main, enemy)
		return

	match enemy_kind:
		"elite":
			main._refresh_hud()
		"small_boss":
			_handle_small_boss_defeated(main, enemy)
		"boss":
			_handle_boss_defeated(main, enemy)

static func _handle_developer_boss_defeated(main: Node, enemy: Node2D) -> void:
	if main.boss_enemy == enemy:
		main.boss_enemy = null
		main.boss_spawned = false
	main._refresh_hud()

static func _handle_small_boss_defeated(main: Node, enemy: Node2D) -> void:
	if main.small_boss_enemy == enemy:
		main.small_boss_enemy = null
	if is_instance_valid(main.get("wave_flow")):
		main.wave_flow.boss_defeated(enemy)
		return
	REWARD_FLOW.show_small_boss_reward(main)
	main._refresh_hud()

static func _handle_boss_defeated(main: Node, enemy: Node2D) -> void:
	if main.boss_enemy != enemy:
		return
	if is_instance_valid(main.get("wave_flow")):
		main.wave_flow.boss_defeated(enemy)
		return
	if main.endless_mode_active:
		_handle_endless_boss_defeated(main)
		return
	main._on_stage_cleared()

static func _handle_endless_boss_defeated(main: Node) -> void:
	main.boss_enemy = null
	main.game_over = true
	if main.spawn_timer != null:
		main.spawn_timer.stop()
	GAME_HUD_FLOW.hide_boss_ui(main)
	var settlement := SAVE_MANAGER.complete_current_endless_tier(main.endless_tier, main.endless_run_id, preload("res://scripts/game/run_outcome.gd").capture(main, "victory"))
	if not settlement.is_empty():
		GAME_ACHIEVEMENT_BRIDGE.record_endless_tier_cleared(main, int(settlement.get("highest_cleared_tier", 0)))
	REWARD_FLOW.show_endless_boss_reward(main, settlement)
