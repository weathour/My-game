extends SceneTree
## Character content integration: exact gates, post-battle stories and effective save bounds.
const CAMPAIGN := preload("res://scripts/campaign/campaign_service.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const BATTLE := preload("res://scripts/battle/battle_session.gd")
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
var checks := 0
var failures := 0
var capture_dir := ""

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func fresh(label: String) -> RefCounted:
	var state := CAMPAIGN.new()
	state.directory = "user://character_campaign_tests/" + label + "_" + str(Time.get_ticks_usec())
	state.data.reward_seed = 781103
	return state

func choose_reward(state: RefCounted) -> void:
	for id in state.data.pending.candidates:
		if state.data.pending.selected.size() == state.data.pending.picks: break
		expect(state.select_card(id), "choose persisted candidate")
	expect(state.claim_reward(), "claim exact selected reward")

func write_fixture(state: RefCounted, value: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(state.directory)
	var file := FileAccess.open(state.directory.path_join("1.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated storage")
	if failures: quit(1); return
	gate_contract()
	for extra in [false, true]: await post_battle_story(extra)
	effective_resource_bounds()
	old_save_pool_backfill()
	print("CHRONICLE_CHARACTER_CAMPAIGN_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func gate_contract() -> void:
	var state := fresh("gates")
	expect(C.IDS.size() == 38 and state.characters.size() == 38, "37 collectible plus fixed protagonist")
	expect(state.data.pool == ["N01", "N04", "N07", "N13", "N16", "N17"], "initial six remain exact")
	var seen: Array = state.data.pool.duplicate()
	for gate in CAMPAIGN.UNLOCKS:
		for id in CAMPAIGN.UNLOCKS[gate]:
			expect(id in C.IDS and id != "JIA" and id not in seen, "single acquisition gate " + id)
			seen.append(id)
	expect(seen.size() == 37, "gates cover every collectible exactly once")
	for id in C.IDS:
		expect(state.new_character(id).level == C.entry_level(id), "catalog entry level " + id)
	for number in range(1, 19):
		var id := "B%02d" % number
		expect(state.battle_available(id), "complete chapter battle is authored " + id)

func post_battle_story(extra: bool) -> void:
	# A transaction fixture submits the public victory contract; it does not claim
	# to play the encounter, which the chapter combat regression covers separately.
	var state := fresh("post_story_" + str(extra))
	state.data.started = true
	state.data.current = "B06"
	state.data.available = ["B06", "S05"]
	var owned_before: Dictionary = state.data.owned.duplicate(true)
	var request: Dictionary = state.start_battle()
	expect(not request.is_empty(), "B06 starts before victory")
	var result := {"attempt_id":request.attempt_id, "outcome":"victory", "characters":request.characters, "card_elite":extra}
	expect(state.complete_battle(result), "victory commits before its scene")
	expect(state.awaiting_battle_story() and state.data.pending.is_empty() and state.data.current == "B06", "scene precedes new pool and draft")
	expect("N14" not in state.data.pool and "F05" not in state.data.pool and state.data.owned == owned_before, "unread shrine scene neither unlocks nor gifts")
	expect(state.start_battle().is_empty() and not state.choose_node("S05") and not state.complete_battle(result), "won battle cannot be repeated or bypassed")
	expect(state.event_available("B06") and state.save_story_checkpoint("B06", "b06_01"), "battle scene supports durable checkpoint")
	var before: Dictionary = state.data.duplicate(true)
	var directory: String = state.directory
	state.directory = "/proc/character-campaign-story-write-rejected"
	print("EXPECTED_FAULT_INJECTION: post-battle story save rejected")
	expect(not state.resolve_event() and state.data == before, "failed scene commit rolls back pool draft and checkpoint")
	state.directory = directory
	var loaded := fresh("post_reload")
	loaded.directory = directory
	expect(loaded.load_slot("auto") and loaded.awaiting_battle_story() and loaded.data.story_checkpoint.line == "b06_01", "reload restores won scene without rerunning combat")
	var shell := SHELL.instantiate()
	shell.session = loaded
	root.add_child(shell)
	await process_frame
	shell.resume_view()
	expect(shell.page == "event", "resume opens pending battle scene")
	expect(not shell.can_replay_story("B06"), "uncompleted scene cannot be reviewed")
	if not extra and not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		shell._advance_story("b06_04")
		shell.story_view.reveal_current()
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(capture_dir)
		root.get_texture().get_image().save_png(capture_dir.path_join("shrine-after-victory.png"))
	expect(loaded.resolve_event(), "finish battle scene")
	expect("F05" in loaded.data.pool and "N14" in loaded.data.pool and loaded.data.owned == owned_before, "scene unlocks both without gifting")
	expect(loaded.data.pending.candidates.size() == 5 and loaded.data.pending.picks == 2 + int(extra), "post-scene reward retains five choices and elite extra")
	before = loaded.data.duplicate(true)
	expect(not loaded.resolve_event() and loaded.data == before, "pending reward blocks repeated scene effects")
	choose_reward(loaded)
	expect("B06" in loaded.data.completed and loaded.data.current == "S05", "claim completes node and resumes route")
	before = loaded.data.duplicate(true)
	shell.resume_view()
	expect(shell.can_replay_story("B06") and shell.open_story_replay("B06"), "completed battle scene is reviewable")
	shell._advance_story_replay("")
	expect(loaded.data == before and not loaded.claim_reward(), "battle-scene review never changes progress or duplicates cards")
	root.remove_child(shell)
	shell.queue_free()
	await process_frame

func effective_resource_bounds() -> void:
	var state := fresh("bounds")
	for id in C.IDS: state.data.owned[id] = C.record(id, C.entry_level(id))
	state.data.party = ["F03", "F07"]
	state.data.current = "F01"
	state.data.available = ["F01"]
	state.data.owned.N02.dead = true
	state.data.owned.N02.hp = 0.0
	state.data.owned.F03.cooldowns = {"preserved_clock":3.25}
	var before_bonus := C.owned_bonuses(state.data.owned)
	expect(before_bonus.hp > 0 and before_bonus.mp > 0, "fixture contains real HP and MP passives")
	expect(state.resolve_event(), "spring fills effective maxima and revives reserves")
	expect(state.data.owned.JIA.hp > C.attributes("JIA", 1).hp and state.data.owned.JIA.mp > C.attributes("JIA", 1).mp, "effective maxima exceed naked stats")
	expect(not state.data.owned.N02.dead and state.data.owned.F03.cooldowns.preserved_clock == 3.25, "spring revives without clearing cooldowns")
	expect(state.valid(state.data) and state.save_slot("1"), "full boosted resources are legal and saved")
	var saved: Dictionary = state.data.duplicate(true)
	expect(state.load_slot("1") and state.data.owned == saved.owned, "boosted HP MP round-trip without clamp or loss")
	for stat in ["hp", "mp"]:
		var corrupt: Dictionary = state.data.duplicate(true)
		corrupt.owned.JIA[stat] = state.resource_max("JIA", stat) + 1.0
		expect(not state.valid(corrupt), "reject over effective cap " + stat)
	var malformed: Dictionary = state.data.duplicate(true)
	malformed.owned.N02 = {"level":"wrong"}
	expect(not state.valid(malformed), "malformed passive record rejected before bonus aggregation")
	state.data.current = "B01"
	state.data.available = ["B01"]
	var request: Dictionary = state.start_battle()
	var battle := BATTLE.new(request)
	for id in battle.characters:
		battle.characters[id].hp = battle.characters[id].stats.hp
		battle.characters[id].mp = battle.characters[id].stats.mp
	battle.grant_experience(120)
	var results := {}
	for id in battle.characters: results[id] = battle.characters[id].snapshot()
	expect(state.complete_battle({"attempt_id":request.attempt_id,"outcome":"victory","characters":results}), "victory validates newly leveled full-party effective bounds")
	state.data.pending.selected = state.data.pending.candidates.slice(0, state.data.pending.picks)
	expect(state.claim_reward() and state.valid(state.data), "duplicate-card refill uses all post-reward passives")
	for id in state.data.owned:
		expect(state.data.owned[id].hp <= state.resource_max(id,"hp") and state.data.owned[id].mp <= state.resource_max(id,"mp"), "stored resources stay bounded " + id)

func old_save_pool_backfill() -> void:
	var state := fresh("old_pool")
	var legacy: Dictionary = state.data.duplicate(true)
	legacy.current = "B07"
	legacy.available = ["B07"]
	legacy.completed = ["S01", "B01", "S02", "B02", "S03", "B04", "B03", "S04", "B06", "F01", "S05"]
	legacy.pool.append_array(["F11", "F03", "N18", "F07", "N14"])
	legacy.owned.F11 = C.record("F11", 1)
	legacy.owned.F11.cooldowns = {"F11_frost":4.75}
	legacy.erase("story_checkpoint")
	write_fixture(state, legacy)
	expect(state.load_slot("1"), "load previous twelve-character-era save")
	expect(state.data.pool.size() == 16 and state.data.owned == legacy.owned, "completed gates backfill only eligibility, never gift or reset clocks")
	expect(state.data.current == "B07" and not state.start_battle().is_empty(), "old progress enters newly authored stage without resetting progress")
	state.abandon_battle()
	for id in ["F04", "M07", "F08", "F05", "F09"]: expect(id in state.data.pool, "new early character eligible " + id)
	for id in ["F02", "F06", "F10", "M01", "F01"]: expect(id not in state.data.pool, "unreached future gate stays closed " + id)
	var pending: Dictionary = legacy.duplicate(true)
	pending.current = "B03"
	pending.available = ["B03"]
	pending.pending = {"node":"B03","candidates":["N01","N04","N07","N13","F03"],"selected":["F03"],"picks":2,"extra":false}
	pending.completed = ["S01","B01","S02","B02","S03","B04"]
	write_fixture(state,pending)
	expect(state.load_slot("1") and state.data.pending == pending.pending and state.data.reward_index == pending.reward_index, "backfill never rerolls stored candidates or selections")
	expect("F04" in state.data.pool and "F08" not in state.data.pool, "pending old reward respects actually completed gates")
