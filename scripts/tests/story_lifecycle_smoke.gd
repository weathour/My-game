extends SceneTree

const SAVE := preload("res://scripts/save_manager.gd")
const STORE := preload("res://scripts/save/save_file_store.gd")
const STORY := preload("res://scripts/story/story_progress.gd")
const DATA := preload("res://scripts/story_data.gd")
const SESSION := preload("res://scripts/game/game_session_flow.gd")
const SLOT := 3
const QUEST := "q.c1.outpost"
const STAGE := "chapter1_stage1"
var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, why: String) -> void:
	if not ok:
		failures += 1
		push_error(why)

func frames() -> void:
	for _i in 5:
		await process_frame

func block(path: String, enabled: bool) -> void:
	var absolute := ProjectSettings.globalize_path(path + ".tmp")
	if enabled:
		DirAccess.make_dir_recursive_absolute(absolute)
	else:
		DirAccess.remove_absolute(absolute)

func run() -> void:
	check(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated saves required")
	if failures:
		quit(1)
		return
	SAVE.delete_story_profile(SLOT)
	check(STORY.open_slot(SLOT).ok, "open slot")
	check(STORY.accept_quest(SLOT, QUEST, "gunner").ok, "accept quest")
	block(STORE.story_run_path(SLOT), true)
	check(not STORY.begin_stage(SLOT, STAGE, "advance").ok, "failed initial run write is reported")
	var starting: Dictionary = SAVE.load_story_profile(SLOT).story.active_attempt
	check(starting.phase == "starting", "keep recoverable attempt intent")
	block(STORE.story_run_path(SLOT), false)
	check(STORY.open_slot(SLOT).ok, "recover interrupted departure")
	check(SAVE.load_story_profile(SLOT).story.active_attempt.attempt_id == starting.attempt_id, "recovery keeps identity")
	check(STORY.continue_attempt(SLOT).ok, "continue recovered departure")
	change_scene_to_file("res://scenes/main.tscn")
	await frames()
	var main = current_scene
	check(main.story_mode_active, "real combat scene recognizes attempt")
	main.survival_time = 12.0
	block(STORE.story_profile_path(SLOT), true)
	SESSION.handle_player_died(main)
	check(main.game_over_ui.visible and paused, "failure remains reviewable")
	check(SAVE.load_run(SLOT, SAVE.MODE_STORY).pending_run_end.outcome == "failed", "failed end commit leaves recoverable intent")
	check(not SAVE.load_story_profile(SLOT).story.active_attempt.is_empty(), "failed write does not publish end")
	SESSION.return_to_main_menu(main)
	await frames()
	block(STORE.story_profile_path(SLOT), false)
	check(STORY.continue_attempt(SLOT).ok, "pending failure can resume")
	change_scene_to_file("res://scenes/main.tscn")
	await frames()
	main = current_scene
	SESSION.resume_game(main)
	await frames()
	check(main.game_over_ui.visible and paused, "resume restores failure result")
	var failed := SAVE.load_story_profile(SLOT)
	check(failed.story.last_settlement.outcome == "failed" and failed.story.active_attempt.is_empty(), "end committed once")
	check(failed.story.quest_states[QUEST] == "active" and failed.story.quest_items.is_empty(), "failure retains accepted task without reward")
	main.game_over_ui.retry_button.pressed.emit()
	await frames()
	main = current_scene
	check(main.story_mode_active and not main.game_over, "retry enters fresh combat")
	check(main.get_meta("story_attempt").attempt_id != starting.attempt_id, "retry receives new identity")
	SESSION.return_to_endless_camp(main)
	await frames()
	check(current_scene.get_script() == preload("res://scripts/story_prep.gd"), "abandon returns to story preparation")
	check(SAVE.load_story_profile(SLOT).story.last_settlement.outcome == "abandoned", "abandon saved")
	SAVE.delete_story_profile(SLOT)
	var legacy := DATA.build_default_story_profile(SLOT)
	STORE.write_json(STORE.story_profile_path(SLOT), legacy)
	STORE.write_json(STORE.story_run_path(SLOT), {"player": {"level": 8}, "survival_time": 47.0})
	check(STORY.open_slot(SLOT).ok, "legacy running save migrates")
	var migrated := SAVE.load_run(SLOT, SAVE.MODE_STORY)
	check(migrated.player.level == 8 and migrated.survival_time == 47.0 and migrated.has("story_attempt"), "migration preserves live build and time")
	var future := SAVE.load_story_profile(SLOT)
	future.schema_version = 999
	STORE.write_json(STORE.story_profile_path(SLOT), future)
	check(SAVE.profile_status(SLOT, SAVE.MODE_STORY).status == "incompatible", "future version never downgraded to backup")
	check(not STORY.open_slot(SLOT).ok, "future version refuses write")
	check(STORE.read_json(STORE.story_profile_path(SLOT)).schema_version == 999, "future raw data preserved")
	SAVE.delete_story_profile(SLOT)
	print("STORY_LIFECYCLE_SMOKE_OK" if failures == 0 else "STORY_LIFECYCLE_SMOKE_FAILED")
	quit(0 if failures == 0 else 1)
