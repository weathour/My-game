extends SceneTree

const STATE := preload("res://scripts/game/session_state.gd")
const SESSION := preload("res://scripts/game/game_session_flow.gd")
const CHARACTER := preload("res://scripts/game/game_character_panel_flow.gd")
const REWARDS := preload("res://scripts/game/reward_flow.gd")
const HUD := preload("res://scripts/game/game_hud_flow.gd")
const MODE := preload("res://scripts/developer_mode.gd")
var failures: Array[String] = []

class PanelFixture:
	extends Control
	func show_for_player(_player): show()
	func hide_panel(): hide()
	func show_options(_options: Array, _attributes: Array, _context: Dictionary): show()
class Player:
	extends Node
	func apply_upgrades(_ids: Array): pass
class Hud:
	extends Node
	var caption := ""
	var value := -1.0
	func set_time_caption(text: String): caption = text
	func update_time(seconds: float): value = seconds
class Main:
	extends Node
	var game_over := false
	var loaded_from_save := false
	var story_mode_active := true
	var endless_mode_active := false
	var stage_cleared := false
	var story_stage := {"id": "chapter1_stage1", "type": "normal", "target_time": 180.0}
	var survival_time := 60.0
	var reward_context := ""
	var wave_flow: Node
	var player: Node
	var character_panel: Control
	var level_up_ui: Control
	var pause_menu: Control
	var hud: Node
	func _refresh_hud(): pass
	func _save_run_state(): pass

func _init():
	call_deferred("run")

func check(ok: bool, message: String):
	if not ok:
		failures.append(message)

func run():
	check(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated settings required")
	if not failures.is_empty():
		finish()
		return
	var main := Main.new()
	root.add_child(main)
	main.player = Player.new()
	main.character_panel = PanelFixture.new()
	main.level_up_ui = PanelFixture.new()
	main.pause_menu = PanelFixture.new()
	main.hud = Hud.new()
	for node in [main.player, main.character_panel, main.level_up_ui, main.pause_menu, main.hud]:
		main.add_child(node)
	main.character_panel.hide()
	main.level_up_ui.hide()
	main.pause_menu.hide()
	REWARDS.show_level_up(main, [{"id": "fixture"}])
	CHARACTER.show_character_panel(main)
	check(paused and STATE.has_pause_reason(main, "reward") and STATE.has_pause_reason(main, "character"), "reward and inspection own separate pause reasons")
	REWARDS.handle_upgrade_selected(main, "fixture")
	check(paused and main.character_panel.visible and not STATE.has_pause_reason(main, "reward"), "claiming reward cannot release open character panel")
	CHARACTER.hide_character_panel(main)
	check(not paused, "last panel releases the combat pause")
	STATE.set_pause_reason(main, "cutscene", true)
	STATE.set_pause_reason(main, "manual", true)
	SESSION.resume_game(main)
	check(paused and STATE.has_pause_reason(main, "cutscene") and not STATE.has_pause_reason(main, "manual"), "manual resume does not cancel another session owner")
	STATE.set_pause_reason(main, "cutscene", false)
	check(not paused, "independent pause reason is explicitly released")
	var view := STATE.presentation(main)
	check(view.is_read_only() and view.mode == "story" and view.phase == "combat" and view.stage_id == "chapter1_stage1", "presentation is a stable read-only value")
	HUD._update_time(main)
	check(main.hud.caption == "本关剩余" and main.hud.value == 120.0, "survival objective keeps its actual countdown")
	main.story_stage = {"id": "chapter1_stage3", "type": "boss", "target_time": 300.0}
	main.survival_time = 450.0
	HUD._update_time(main)
	var boss_view := STATE.presentation(main)
	check(boss_view.target_kind == "defeat_boss" and main.hud.caption == "讨伐用时" and main.hud.value == 450.0, "Boss objective displays elapsed time past the old 300-second hint")
	check(view.stage_id == "chapter1_stage1", "later state changes do not mutate a prior presentation snapshot")
	STATE.set_outcome(main, "victory")
	main.game_over = true
	main.reward_context = "renamed_result_ui"
	check(STATE.presentation(main).outcome == "victory", "result identity is independent of reward menu strings")
	STATE.clear_pause_reasons(main)
	main.free()
	finish()

func finish():
	for message in failures:
		push_error(message)
	print("SESSION_STATE_SMOKE_OK" if failures.is_empty() else "SESSION_STATE_SMOKE_FAILED")
	quit(0 if failures.is_empty() else 1)
