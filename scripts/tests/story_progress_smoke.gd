extends SceneTree

const SAVE := preload("res://scripts/save_manager.gd")
const STORE := preload("res://scripts/save/save_file_store.gd")
const STORY := preload("res://scripts/story/story_progress.gd")
const CONTENT := preload("res://scripts/story/story_content.gd")
const DATA := preload("res://scripts/story_data.gd")
var failures := 0
const SLOT := 3

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func complete_attempt(attempt: Dictionary) -> Dictionary:
	var run := SAVE.load_run(SLOT, SAVE.MODE_STORY)
	run.pending_settlement = attempt.duplicate(true)
	run.pending_settlement.outcome = "victory"
	expect(SAVE.save_run(run, SLOT, SAVE.MODE_STORY) > 0, "persist victory intent")
	return STORY.settle_stage(SLOT, attempt.attempt_id)

func block_profile_write(block: bool) -> void:
	var path := ProjectSettings.globalize_path(STORE.story_profile_path(SLOT) + ".tmp")
	if block:
		DirAccess.make_dir_absolute(path)
	else:
		DirAccess.remove_absolute(path)

func _init() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "Run with isolated XDG_DATA_HOME")
	if failures:
		quit(1)
		return
	expect(CONTENT.validate().is_empty(), "runtime content validates")
	SAVE.delete_story_profile(SLOT)
	expect(STORY.open_slot(SLOT).ok, "create story slot")
	var opening := STORY.open_dialogue(SLOT, "dlg.c1.outpost.accept")
	expect(opening.ok, "open acceptance dialogue")
	expect(STORY.advance_dialogue(SLOT, "dlg.c1.outpost.accept", "start", "later").ok, "defer acceptance")
	expect(SAVE.load_story_profile(SLOT).story.quest_states["q.c1.outpost"] == "available", "defer must not accept")
	STORY.advance_dialogue(SLOT, "dlg.c1.outpost.accept", "later")
	for quest: Dictionary in CONTENT.entries("quests"):
		expect(STORY.open_dialogue(SLOT, quest.dialogues.accept).ok, "open next acceptance")
		expect(STORY.advance_dialogue(SLOT, quest.dialogues.accept, "start", "accept").ok, "accept atomically with checkpoint")
		expect(STORY.open_dialogue(SLOT, quest.dialogues.accept).profile.story.dialogue_checkpoint.node_id == "accepted", "resume post-accept despite changed entry condition")
		var started := STORY.begin_stage(SLOT, quest.stage_id, "advance")
		expect(started.ok, "begin current stage")
		var attempt: Dictionary = started.profile.story.active_attempt
		expect(not STORY.begin_stage(SLOT, quest.stage_id, "advance").ok, "do not replace active run")
		expect(not STORY.settle_stage(SLOT, attempt.attempt_id).ok, "reject victory without saved result")
		block_profile_write(true)
		expect(not complete_attempt(attempt).ok, "write failure preserves pending settlement")
		expect(SAVE.load_story_profile(SLOT).story.quest_states[quest.id] == "active", "failed commit does not publish quest completion")
		block_profile_write(false)
		var pending_run := SAVE.load_run(SLOT, SAVE.MODE_STORY)
		expect(STORY.open_slot(SLOT).ok, "resume and settle pending victory")
		expect(SAVE.save_run(pending_run, SLOT, SAVE.MODE_STORY) > 0, "reproduce crash after profile commit and before run cleanup")
		expect(STORY.settle_stage(SLOT, attempt.attempt_id).ok, "duplicate settlement idempotent")
		expect(SAVE.run_status(SLOT, SAVE.MODE_STORY).status == "missing", "duplicate settlement clears only the matching ended run")
		var item_id: String = quest.first_clear_reward.items[0].item_id
		expect(STORY.item_quantity(SAVE.load_story_profile(SLOT), item_id) == 1, "fixed item granted once")
		expect(not STORY.turn_in_quest(SLOT, quest.id, "ruan_dog").ok, "wrong NPC cannot consume item")
		expect(STORY.open_dialogue(SLOT, quest.dialogues.turn_in).ok, "open delivery")
		block_profile_write(true)
		expect(not STORY.advance_dialogue(SLOT, quest.dialogues.turn_in, "start", "confirm").ok, "failed delivery stays on original choice")
		expect(STORY.item_quantity(SAVE.load_story_profile(SLOT), item_id) == 1, "failed delivery preserves item")
		block_profile_write(false)
		expect(STORY.advance_dialogue(SLOT, quest.dialogues.turn_in, "start", "confirm").ok, "deliver and advance dialogue together")
		expect(STORY.turn_in_quest(SLOT, quest.id, quest.turn_in_npc).ok, "duplicate delivery is harmless")
		expect(STORY.item_quantity(SAVE.load_story_profile(SLOT), item_id) == 0, "item consumed exactly once")
		var replay := STORY.begin_stage(SLOT, quest.stage_id, "replay")
		expect(replay.ok, "completed stage can be replayed")
		expect(STORY.continue_attempt(SLOT).ok, "replay identity survives continue")
		expect(complete_attempt(replay.profile.story.active_attempt).ok, "finish replay")
		expect(STORY.item_quantity(SAVE.load_story_profile(SLOT), item_id) == 0, "replay never reissues permanent reward")
		pending_run.story_attempt.attempt_id = "unmatched_attempt"
		STORE.write_json(STORE.story_run_path(SLOT), pending_run)
		expect(not STORY.begin_stage(SLOT, quest.stage_id, "replay").ok, "new departure cannot silently discard an unmatched run")
		expect(FileAccess.file_exists(STORE.story_run_path(SLOT)), "unmatched run remains until explicit abandonment")
		expect(STORY.abandon_unreadable_run(SLOT).ok, "explicit abandonment can preserve and clear an orphan run")
	var completed := SAVE.load_story_profile(SLOT)
	expect(completed.current_stage_index == 3 and completed.story.flags.get("chapter1.communications_restored", false), "chapter complete")
	expect(completed.story.claimed_reward_ids.size() == 6, "bounded receipts")
	SAVE.set_active_endless_slot(1)
	expect(not STORY.accept_quest(SLOT, "q.c1.outpost", "gunner").ok, "reject cross-mode command")
	for old_index in range(4):
		SAVE.delete_story_profile(SLOT)
		var old := DATA.build_default_story_profile(SLOT)
		old.current_stage_index = old_index
		old.boss_core_fragments = 7
		STORE.write_json(STORE.story_profile_path(SLOT), old)
		expect(STORY.open_slot(SLOT).ok, "migrate legacy progress")
		var migrated := SAVE.load_story_profile(SLOT)
		expect(migrated.current_stage_index == old_index and migrated.boss_core_fragments == 7, "migration retains progress and cores")
		expect(migrated.unlocked_role_ids.size() == 4, "migration retains four roles")
		expect(migrated.story.journal_entries.size() == old_index, "migration restores information without regranting material")
	SAVE.delete_story_profile(SLOT)
	print("STORY_PROGRESS_SMOKE_OK" if failures == 0 else "STORY_PROGRESS_SMOKE_FAILED")
	quit(0 if failures == 0 else 1)
