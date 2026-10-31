extends SceneTree
## Campaign story transactions, schema-1 recovery and durable line checkpoints.
const CAMPAIGN := preload("res://scripts/campaign/campaign_service.gd")
var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func fresh(label: String) -> RefCounted:
	var state := CAMPAIGN.new()
	state.directory = "user://story_progress_tests/" + label + "_" + str(Time.get_ticks_usec())
	state.data.reward_seed = 781103
	return state

func persist_fixture(state: RefCounted, snapshot: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(state.directory)
	var file := FileAccess.open(state.directory.path_join("1.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshot))
	file.close()

func complete_first(state: RefCounted, extra: bool = false) -> void:
	expect(state.begin_campaign() and state.resolve_event(), "reach B01")
	var request: Dictionary = state.start_battle()
	expect(not request.is_empty(), "start first battle")
	expect(state.complete_battle({"attempt_id":request.attempt_id, "outcome":"victory", "characters":request.characters, "card_elite":extra}), "commit first victory")

func choose_all(state: RefCounted) -> void:
	for id in state.data.pending.candidates:
		if state.data.pending.selected.size() == state.data.pending.picks: break
		expect(state.select_card(id), "persist first reward selection")

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated save location")
	if failures: quit(1); return
	for extra in [false, true]: first_reward_order(extra)
	checkpoint_validation()
	legacy_recovery()
	print("CHRONICLE_STORY_PROGRESS_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func first_reward_order(extra: bool) -> void:
	var state := fresh("first_" + str(extra))
	complete_first(state, extra)
	expect(state.data.current == "B01" and state.data.pending.candidates.size() == 5 and state.data.pending.picks == (3 if extra else 2), "first reward retains ordinary / elite rule")
	expect("F11" not in state.data.pending.candidates and "F11" not in state.data.pool and not state.data.owned.has("F11"), "Emma not drawable or granted before story")
	var pending: Dictionary = state.data.pending.duplicate(true)
	expect(not state.save_story_checkpoint("S02", "s02_01") and not state.resolve_event() and state.data.pending == pending, "reward blocks story and checkpoint")
	choose_all(state)
	var previous: Dictionary = state.data.duplicate(true)
	var directory: String = state.directory
	state.directory = "/proc/chronicle-story-claim-read-only"
	print("EXPECTED_FAULT_INJECTION: first reward claim write rejected")
	expect(not state.claim_reward() and state.data == previous, "claim failure preserves candidates, choices and roster")
	state.directory = directory
	expect(state.claim_reward() and state.data.current == "S02", "claim advances to S02")
	expect(state.data.owned.size() == 1 + (3 if extra else 2), "all first picks granted separately from Emma")
	expect(state.save_story_checkpoint("S02", "s02_01"), "persist first visible line")
	previous = state.data.duplicate(true)
	state.directory = "/proc/chronicle-story-line-read-only"
	print("EXPECTED_FAULT_INJECTION: story line write rejected")
	expect(not state.save_story_checkpoint("S02", "s02_02") and state.data == previous, "line save failure restores whole state")
	print("EXPECTED_FAULT_INJECTION: story completion write rejected")
	expect(not state.resolve_event() and state.data == previous and not state.data.owned.has("F11"), "event save failure retains checkpoint and does not grant Emma")
	state.directory = directory
	expect(state.save_story_checkpoint("S02", "s02_02"), "retry line checkpoint")
	var loaded := fresh("reload")
	loaded.directory = directory
	expect(loaded.load_slot("auto") and loaded.data.story_checkpoint == {"event":"S02", "line":"s02_02"}, "restart restores exact stable line")
	expect(loaded.resolve_event() and loaded.data.current == "B02" and loaded.data.story_checkpoint.is_empty(), "finishing story clears checkpoint")
	expect(loaded.data.owned.F11.level == 1 and loaded.data.owned.F11.xp == 0 and "F11" in loaded.data.pool and loaded.data.pending.is_empty(), "story grants one Emma and unlocks pool without another reward")
	previous = loaded.data.duplicate(true)
	expect(not loaded.resolve_event() and not loaded.claim_reward() and loaded.data == previous, "completion cannot be claimed twice")
	expect(loaded.load_slot("auto") and loaded.data.owned.F11.level == 1 and loaded.data.pending.is_empty(), "loading completed story grants neither duplicate character nor reward")

func checkpoint_validation() -> void:
	var state := fresh("validation")
	expect(state.data.story_checkpoint.is_empty() and state.save_story_checkpoint("S01", "s01_01"), "new schema has optional checkpoint")
	var original: Dictionary = state.data.duplicate(true)
	for checkpoint in [null, [], {"event":"S01"}, {"event":"S01", "line":""}, {"event":"S02", "line":"x"}, {"event":"B01", "line":"x"}, {"event":"S01", "line":1}, {"event":"S01", "line":"x", "extra":true}]:
		var corrupt: Dictionary = original.duplicate(true)
		corrupt.story_checkpoint = checkpoint
		expect(not state.valid(corrupt), "reject malformed / unreachable checkpoint: " + str(checkpoint))
	expect(not state.save_story_checkpoint("S02", "x") and not state.save_story_checkpoint("S01", "") and state.data == original, "API rejects wrong event / blank line unchanged")
	var old: Dictionary = original.duplicate(true)
	old.erase("story_checkpoint")
	expect(state.valid(old), "schema 1 permits missing optional checkpoint")
	persist_fixture(state, old)
	expect(state.load_slot("1") and state.data.story_checkpoint.is_empty(), "old checkpoint-less save gains empty field")
	expect(state.resolve_event(), "opening completes")
	var request: Dictionary = state.start_battle()
	original = state.data.duplicate(true)
	expect(not request.is_empty() and not state.save_story_checkpoint("B01", "x") and state.data == original, "battle rejects checkpoint writes")
	state.abandon_battle()
	state.data.current = "F01"
	state.data.available = ["F01"]
	expect(state.save_story_checkpoint("F01", "f01_01") and state.resolve_event() and state.data.story_checkpoint.is_empty(), "spring supports and clears checkpoint")

func legacy_recovery() -> void:
	for extra in [false, true]:
		var state := fresh("legacy_deferred_" + str(extra))
		var legacy: Dictionary = state.data.duplicate(true)
		legacy.erase("story_checkpoint")
		legacy.current = "S02"
		legacy.available = ["S02"]
		legacy.completed = ["S01", "B01"]
		legacy.deferred_reward = {"id":"B01", "extra":extra}
		expect(state.valid(legacy), "old deferred schema 1 remains readable")
		persist_fixture(state, legacy)
		expect(state.load_slot("1") and state.data.deferred_reward.is_empty(), "legacy deferred recovered into pending reward")
		expect(state.data.pending.picks == (3 if extra else 2) and "F11" not in state.data.pending.candidates and not state.data.owned.has("F11"), "legacy recovery preserves elite rule and keeps Emma gated")
		var pending: Dictionary = state.data.pending.duplicate(true)
		expect(state.load_slot("auto") and state.data.pending == pending and state.data.reward_index == 1, "repeat load does not reroll or increment reward index")
		choose_all(state)
		expect(state.claim_reward() and state.data.current == "S02" and state.resolve_event(), "legacy recovery follows reward then story")
		expect(state.data.owned.F11.level == 1 and state.data.pending.is_empty(), "legacy completion grants no duplicate reward")
	# An already generated old first draft retains candidates and partial selections,
	# including an Emma duplicate that was legal under the previous order.
	var state := fresh("legacy_pending")
	complete_first(state)
	var legacy: Dictionary = state.data.duplicate(true)
	legacy.erase("story_checkpoint")
	legacy.current = "B02"
	legacy.available = ["B02"]
	legacy.completed = ["S01", "B01", "S02", "S03"]
	legacy.pool.append("F11")
	legacy.owned.F11 = state.new_character("F11")
	legacy.pending.candidates[0] = "F11"
	legacy.pending.selected = ["F11"]
	var pending: Dictionary = legacy.pending.duplicate(true)
	persist_fixture(state, legacy)
	expect(state.load_slot("1") and state.data.pending == pending, "existing B01 candidates and selection remain exact")
	expect("F03" in state.data.pool and "N18" in state.data.pool and state.data.pending == pending, "later unlock reconciliation leaves generated draft unchanged")
	expect(state.select_card(state.data.pending.candidates[1]) and state.claim_reward(), "claim preserved historical draft")
	expect(state.data.owned.F11.level == 2, "historical Emma result is honored")
	expect(state.load_slot("auto") and state.data.owned.F11.level == 2 and not state.claim_reward(), "reload cannot reclaim historical draft")
	# Old B01 candidates before Emma also remain intact rather than being regenerated.
	state = fresh("legacy_before_story")
	complete_first(state)
	legacy = state.data.duplicate(true)
	legacy.erase("story_checkpoint")
	legacy.pending.selected = [legacy.pending.candidates[0]]
	pending = legacy.pending.duplicate(true)
	persist_fixture(state, legacy)
	expect(state.load_slot("1") and state.data.pending == pending and not state.data.owned.has("F11"), "old pre-story pending draft and partial choices survive")
