extends SceneTree

const SAVE := preload("res://scripts/save_manager.gd")
const STORE := preload("res://scripts/save/save_file_store.gd")
const RUN := preload("res://scripts/game/run_save_flow.gd")
const SESSION := preload("res://scripts/game/game_session_flow.gd")
const REWARDS := preload("res://scripts/game/reward_flow.gd")
const SLOT := 9
var failures: Array[String] = []

class SettlementUI:
	extends Control
	var option_id := ""
	func show_menu(_title: String, options: Array) -> void:
		option_id = options[0].id
class SettlementMain:
	extends Node
	var endless_tier := 1
	var reward_context := ""
	var level_up_ui: Node

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func fresh():
	var main = load("res://scenes/main.tscn").instantiate()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(main)
	current_scene = main
	return main

func discard(main) -> void:
	paused = false
	main.suppress_exit_save = true
	main.free()
	current_scene = null

func run() -> void:
	check(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated data required")
	if not failures.is_empty():
		finish()
		return
	SAVE.delete_endless_profile(SLOT)
	SAVE.create_or_load_endless_profile(SLOT)
	var main = fresh()
	check(RUN.save_run_state(main), "real runtime snapshot saves")
	var good := SAVE.load_run(SLOT, SAVE.MODE_ENDLESS)
	good.skull_mage_domains = [{"position": [123.0, 456.0], "remaining": 2.0}]
	check(SAVE.save_run(good, SLOT, SAVE.MODE_ENDLESS) > 0, "valid independent field snapshot saves")
	var serialized := FileAccess.get_file_as_string(STORE.endless_run_path(SLOT))
	check(serialized == FileAccess.get_file_as_string(STORE.endless_run_backup_path(SLOT)), "atomic primary and backup retain the exact same serialized snapshot")
	check(JSON.parse_string(serialized) == JSON.parse_string(JSON.stringify(good)), "compact save retains parsed state independently of object key order")
	var bad := good.duplicate(true)
	bad.skull_mage_domains = [{}]
	check(SAVE.save_run(bad, SLOT, SAVE.MODE_ENDLESS) == 0, "writer rejects malformed nested payload")
	STORE.write_json(STORE.endless_run_path(SLOT), bad)
	check(SAVE.run_status(SLOT, SAVE.MODE_ENDLESS).status == "recoverable", "bad nested primary falls back to good backup")
	check(RUN.load_saved_run(main), "valid backup restores successfully")
	check(SAVE.load_run(SLOT, SAVE.MODE_ENDLESS).skull_mage_domains[0].position == [123.0, 456.0], "fallback retains actual field instead of dropping it")
	discard(main)
	for kind in ["attraction_speed", "role_range", "beam_choices", "beam_axis"]:
		main = fresh()
		check(SAVE.save_run(good, SLOT, SAVE.MODE_ENDLESS) > 0, "prepare good backup for " + kind)
		var malformed := good.duplicate(true)
		match kind:
			"attraction_speed":
				malformed.gems = [{"position": [0, 0], "attraction_active": true, "attraction_speed": {}}]
			"role_range":
				malformed.player.roles[0].range = {}
			"beam_choices":
				malformed.player.ability_runtime.infinite_reload = {"build_version": 1, "cast_snapshot": {"choices": {}}}
			"beam_axis":
				malformed.player.ability_runtime.infinite_reload = {"build_version": 1, "pending_beam_hits": [{"remaining": 1.0, "shapes": [{"type": "oriented_rect", "center": [0, 0], "axis": [0]}]}]}
		STORE.write_json(STORE.endless_run_path(SLOT), malformed)
		check(SAVE.run_status(SLOT, SAVE.MODE_ENDLESS).status == "recoverable", "nested malicious primary chooses good backup: " + kind)
		check(RUN.load_saved_run(main) and not main.has_meta("run_restore_failed"), "real run restore safely hydrates fallback: " + kind)
		discard(main)
	main = fresh()
	var legacy := {"run_id": "legacy-minimal", "run_tier": 1, "player": {"level": 3, "role_upgrade_levels": {"swordsman": {"level": 2}}}}
	check(SAVE.save_run(legacy, SLOT, SAVE.MODE_ENDLESS) > 0 and RUN.load_saved_run(main), "minimal legacy player fully restores without role_share_initialized")
	check(main.player.role_share_initialized, "legacy role shares finish their one-time migration")
	var migrated_shares: Dictionary = main.player.role_upgrade_levels.duplicate(true)
	var shares_unchanged: bool = RUN.load_saved_run(main)
	for role_id in migrated_shares:
		for key in ["level", "interval_bonus", "range_bonus", "skill_bonus"]:
			shares_unchanged = shares_unchanged and is_equal_approx(float(migrated_shares[role_id][key]), float(main.player.role_upgrade_levels[role_id][key]))
	check(shares_unchanged and migrated_shares.gunner.range_bonus > 0.0, "re-reading migrated legacy snapshot does not apply numeric role shares twice")

	discard(main)
	main = fresh()
	good.gems = [{"position": [10.0, 20.0], "value": 1}]
	check(SAVE.save_run(good, SLOT, SAVE.MODE_ENDLESS) > 0, "prepare valid instantiation failure fixture")
	var before_primary := FileAccess.get_file_as_string(STORE.endless_run_path(SLOT))
	var before_backup := FileAccess.get_file_as_string(STORE.endless_run_backup_path(SLOT))
	main.exp_gem_scene = null
	check(not RUN.load_saved_run(main), "missing runtime factory returns explicit restore failure")
	check(main.has_meta("run_restore_failed") and not RUN.save_run_state(main), "failed restore blocks later autosave")
	check(FileAccess.get_file_as_string(STORE.endless_run_path(SLOT)) == before_primary and FileAccess.get_file_as_string(STORE.endless_run_backup_path(SLOT)) == before_backup, "restore failure leaves both files byte-for-byte unchanged")
	SESSION.resume_game(main)
	check(paused and main.pause_menu.visible, "partial restore cannot resume combat")
	SESSION.return_to_main_menu(main)
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/main_menu.tscn", "failed restore may leave safely without saving")
	current_scene.free()
	current_scene = null
	STORE.write_json(STORE.endless_run_path(SLOT), bad)
	STORE.write_json(STORE.endless_run_backup_path(SLOT), bad)
	before_primary = FileAccess.get_file_as_string(STORE.endless_run_path(SLOT))
	before_backup = FileAccess.get_file_as_string(STORE.endless_run_backup_path(SLOT))
	SAVE.request_continue()
	main = fresh()
	check(main.has_meta("run_restore_failed") and paused, "real ready does not turn failed continue into a fresh saved run")
	check(FileAccess.get_file_as_string(STORE.endless_run_path(SLOT)) == before_primary and FileAccess.get_file_as_string(STORE.endless_run_backup_path(SLOT)) == before_backup, "failed continue preserves corrupt files for recovery")
	discard(main)
	check(SAVE.save_run({"run_id": "clear-retry", "run_tier": 1, "player": {}}, SLOT, SAVE.MODE_ENDLESS) > 0, "prepare settlement snapshot")
	var backup_path := ProjectSettings.globalize_path(STORE.endless_run_backup_path(SLOT))
	DirAccess.remove_absolute(backup_path)
	DirAccess.make_dir_absolute(backup_path)
	var settlement := SAVE.complete_current_endless_tier(1, "clear-retry")
	check(settlement.get("applied", false) and settlement.get("error") == "cleanup_failed", "settlement exposes committed reward with cleanup failure")
	var balance: int = SAVE.load_endless_profile(SLOT).bones
	var view := SettlementMain.new()
	view.level_up_ui = SettlementUI.new()
	root.add_child(view)
	view.add_child(view.level_up_ui)
	REWARDS.show_endless_boss_reward(view, settlement)
	check(view.level_up_ui.option_id == REWARDS.ENDLESS_TIER_CLEAR_RETRY_OPTION_ID, "cleanup failure keeps the settlement retry action")
	view.free()
	paused = false
	DirAccess.remove_absolute(backup_path)
	var retry := SAVE.complete_current_endless_tier(1, "clear-retry")
	check(not retry.get("applied", true) and not retry.has("error") and SAVE.load_endless_profile(SLOT).bones == balance, "cleanup retry succeeds without awarding twice")
	check(SAVE.run_status(SLOT, SAVE.MODE_ENDLESS).status == "missing", "retry clears both snapshots")
	SAVE.save_run({"run_id": "selection-retry", "run_tier": 2, "player": {}}, SLOT, SAVE.MODE_ENDLESS)
	DirAccess.remove_absolute(backup_path)
	DirAccess.make_dir_absolute(backup_path)
	check(not SAVE.select_current_endless_tier(1), "tier selection reports cleanup failure instead of starting")
	DirAccess.remove_absolute(backup_path)
	check(SAVE.select_current_endless_tier(1), "tier selection cleanup can retry")
	SAVE.delete_endless_profile(SLOT)
	await process_frame
	finish()

func finish() -> void:
	for message in failures:
		push_error(message)
	print("RUN_RESTORE_INTEGRITY_SMOKE_OK" if failures.is_empty() else "RUN_RESTORE_INTEGRITY_SMOKE_FAILED")
	quit(0 if failures.is_empty() else 1)
