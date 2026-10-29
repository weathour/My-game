extends SceneTree
## Exercise the production reader and prove that replay never enters campaign transactions.
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
const CATALOG := preload("res://scripts/content/story_catalog.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")

class GuardedCampaign extends "res://scripts/campaign/campaign_service.gd":
	var guarded := false
	var mutation_calls: Array[String] = []

	func blocked(method: String) -> bool:
		if guarded: mutation_calls.append(method)
		return guarded

	func commit(previous: Dictionary) -> bool:
		return false if blocked("commit") else super.commit(previous)

	func save_slot(slot: String) -> bool:
		return false if blocked("save_slot") else super.save_slot(slot)

	func load_slot(slot: String) -> bool:
		return false if blocked("load_slot") else super.load_slot(slot)

	func choose_node(id: String) -> bool:
		return false if blocked("choose_node") else super.choose_node(id)

	func save_story_checkpoint(event_id: String, line_id: String) -> bool:
		return false if blocked("save_story_checkpoint") else super.save_story_checkpoint(event_id, line_id)

	func resolve_event() -> bool:
		return false if blocked("resolve_event") else super.resolve_event()

var checks := 0
var failures := 0
var changed_count := 0
var capture_dir := ""
var viewport: SubViewport
var shell: Control
var state: GuardedCampaign
var watched_state: Dictionary
var watched_files: Dictionary
var watched_changes := 0

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func frames(count: int = 5) -> void:
	for i in count: await process_frame

func settle() -> void:
	await create_timer(0.18).timeout
	await frames()

func click(id: String) -> void:
	var button := shell.find_child(id, true, false) as Button
	expect(button != null and button.is_visible_in_tree() and not button.disabled, "usable " + id)
	if button != null and not button.disabled: button.pressed.emit()
	await frames()

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	viewport.push_input(event)
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event)
	await frames()

func campaign_snapshot() -> Dictionary:
	return {"data":state.data.duplicate(true), "rng":state.reward_rng.state,
		"entry":state.entry_snapshot.duplicate(true), "attempt":state.active_attempt, "battle":state.in_battle}

func files_snapshot() -> Dictionary:
	var result := {}
	for file in DirAccess.get_files_at(state.directory):
		var path := state.directory.path_join(file)
		result[file] = {"bytes":FileAccess.get_file_as_bytes(path), "modified":FileAccess.get_modified_time(path)}
	return result

func watch() -> void:
	state.mutation_calls.clear()
	state.guarded = true
	watched_state = campaign_snapshot()
	watched_files = files_snapshot()
	watched_changes = changed_count

func unchanged(label: String) -> void:
	expect(campaign_snapshot() == watched_state, label + ": entire campaign, RNG and battle state unchanged")
	expect(state.mutation_calls.is_empty(), label + ": no campaign transaction calls: " + str(state.mutation_calls))
	expect(changed_count == watched_changes, label + ": no campaign changed signal")
	expect(files_snapshot() == watched_files, label + ": auto/manual/backup files and timestamps unchanged")

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await settle()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var bitmap := viewport.get_texture().get_image()
	expect(bitmap.get_size() == viewport.size, "render size " + name)
	bitmap.save_png(capture_dir.path_join(name + ".png"))

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated save location")
	if failures: quit(1); return
	var original_motion := SETTINGS.comfort_enabled("reduced_motion")
	var original_text := SETTINGS.comfort_enabled("large_story_text")
	SETTINGS.save_comfort("reduced_motion", false)
	SETTINGS.save_comfort("large_story_text", false)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	shell = SHELL.instantiate()
	state = GuardedCampaign.new()
	state.directory = "user://story_replay_" + str(Time.get_ticks_usec())
	state.data.reward_seed = 781103
	state.changed.connect(func(): changed_count += 1)
	shell.session = state
	viewport.add_child(shell)
	await frames(10)
	shell.open_page("journal")
	expect(shell.replayable_stories().is_empty() and shell.find_child("journal_replay_S02", true, false) == null, "new save exposes no future dialogue")
	expect(not shell.open_story_replay("S02") and shell.page == "journal", "unseen story cannot open by ID")
	# Produce the real first draft, claim it, then complete Emma's first-run reader.
	expect(state.begin_campaign() and state.resolve_event(), "opening advances normally")
	var request: Dictionary = state.start_battle()
	expect(not request.is_empty() and state.complete_battle({"attempt_id":request.attempt_id, "outcome":"victory", "characters":request.characters}), "first victory creates normal draft")
	for id in state.data.pending.candidates.slice(0,2): expect(state.select_card(id), "select first reward")
	expect(state.claim_reward() and state.data.current == "S02" and not state.data.owned.has("F11"), "claim precedes Emma first encounter")
	shell.resume_view(true)
	await frames()
	await click("story_skip")
	expect(state.data.current == "B02" and state.data.owned.F11.level == 1 and "F11" in state.data.pool, "normal completion grants and unlocks Emma once")
	var after_emma: Dictionary = state.data.duplicate(true)
	for slot in ["1", "2"]:
		expect(state.save_slot(slot) and state.save_slot(slot), "create manual save and backup " + slot)
	expect(files_snapshot().size() >= 6, "auto/manual/backup baseline exists")
	await route_replay()
	await live_checkpoint_replay()
	await pending_replay()
	await effects_replay(after_emma)
	await older_save_gate()
	SETTINGS.save_comfort("reduced_motion", original_motion)
	SETTINGS.save_comfort("large_story_text", original_text)
	shell.queue_free()
	await frames()
	viewport.queue_free()
	await frames()
	print("CHRONICLE_STORY_REPLAY_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func route_replay() -> void:
	watch()
	await click("node_S02")
	expect(state.data.current == "B02" and shell.selected_node == "S02", "selecting past node does not revisit campaign node")
	await capture("01-route-entry-1280")
	await click("route_replay")
	expect(shell.page == "replay" and shell.story_view.current_line_id == "s02_01", "past route node starts replay from first line")
	expect((shell.find_child("StoryLocation", true, false) as Label).text.begins_with("剧情回顾"), "reader labels replay")
	expect((shell.find_child("story_skip", true, false) as Button).text == "结束回顾", "skip explicitly ends replay")
	var words := shell.find_child("StoryWords", true, false) as RichTextLabel
	words.visible_characters = 0
	await key(KEY_ENTER)
	expect(shell.story_view.current_line_id == "s02_01" and words.visible_characters == -1, "first confirmation reveals whole replay sentence")
	await key(KEY_SPACE)
	expect(shell.story_view.current_line_id == "s02_02", "replay advances with normal input")
	SETTINGS.save_comfort("large_story_text", true)
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]:
		viewport.size = dimensions
		await frames(12)
		expect(shell.story_view.current_line_id == "s02_02" and shell.replay_line == "s02_02", "resize preserves only transient replay position " + str(dimensions))
		shell.story_view.reveal_current()
		var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
		for id in ["story_back", "story_skip", "event_continue", "StoryReplayHint"]:
			var control := shell.find_child(id, true, false) as Control
			expect(control.is_visible_in_tree() and bounds.encloses(control.get_global_rect()), "replay control fits " + id + str(dimensions))
		await capture("02-replay-large-" + str(dimensions.x))
	SETTINGS.save_comfort("large_story_text", false)
	viewport.size = Vector2i(1280,720)
	await frames(12)
	var lines: Array = CATALOG.events().S02.lines
	for i in range(1, lines.size()):
		expect(shell.page == "replay" and shell.story_view.current_line_id == lines[i].id, "read replay line " + str(i + 1))
		shell.story_view.reveal_current()
		await settle()
		if i == lines.size() - 1:
			expect(not shell.find_child("StoryCompletionHint", true, false).visible and (shell.find_child("event_continue", true, false) as Button).text == "结束回顾", "last line promises no repeated recruitment")
		await key(KEY_ENTER)
	expect(shell.page == "route" and shell.selected_node == "S02", "full replay returns to same selected past route node")
	unchanged("full reading and resize")
	for exit in ["story_skip", "story_back", "escape"]:
		await click("route_replay")
		expect(shell.story_view.current_line_id == "s02_01", "each new replay starts at first sentence")
		if exit == "escape": await key(KEY_ESCAPE)
		else: await click(exit)
		expect(shell.page == "route" and shell.replay_event.is_empty(), "single return clears transient state: " + exit)
		unchanged("repeat replay " + exit)
	expect(not shell.open_story_replay("B01") and not shell.open_story_replay("S03") and not shell.open_story_replay("missing"), "battle, unseen and missing IDs rejected")
	state.guarded = false
	state.in_battle = true
	expect(not shell.open_story_replay("S02"), "active battle rejects replay")
	state.in_battle = false

func live_checkpoint_replay() -> void:
	# Boundary fixture: currently reading the later bandit conversation.
	state.data.current = "S04"
	state.data.available = ["S04"]
	var line: String = CATALOG.events().S04.lines[3].id
	expect(state.save_story_checkpoint("S04", line), "persist live story line before reviewing an old story")
	shell.resume_view(true)
	await frames()
	expect(shell.page == "event" and shell.story_view.current_line_id == line, "live reader resumes its checkpoint")
	watch()
	await key(KEY_ESCAPE)
	await click("nav_settings")
	await click("menu_journal")
	await capture("03-journal-1280")
	await click("journal_replay_S01")
	expect(shell.replay_event == "S01", "first journal closure opens its own event")
	await click("story_back")
	await click("journal_replay_S02")
	expect(shell.replay_event == "S02" and (shell.find_child("story_back", true, false) as Button).text == "返回见闻", "journal replay returns to journal")
	await key(KEY_ESCAPE)
	expect(shell.page == "journal" and shell.previous_page == "menu", "Escape is consumed once and preserves journal parent")
	await click("page_back")
	await click("menu_resume")
	shell.resume_view(true)
	await frames()
	expect(shell.page == "event" and shell.story_view.current_line_id == line, "review leaves exact live sentence available")
	unchanged("live checkpoint coexistence")
	state.guarded = false

func pending_replay() -> void:
	state.data.story_checkpoint = {}
	state.data.current = "B02"
	state.data.available = ["B02"]
	expect(state.make_reward("B02", false) and state.select_card(state.data.pending.candidates[0]), "persist partly selected reward")
	shell.resume_view()
	await frames()
	watch()
	await click("reward_menu")
	await click("menu_journal")
	await click("journal_replay_S02")
	await click("story_skip")
	expect(shell.page == "journal" and shell.previous_page == "menu", "pending reward replay returns through original journal/menu")
	await click("page_back")
	await click("menu_resume")
	expect(shell.page == "reward" and state.data.pending.selected.size() == 1, "returns to same partial reward selection")
	unchanged("pending reward candidates and selection")
	state.guarded = false

func effects_replay(after_emma: Dictionary) -> void:
	# Boundary fixture: damaged/dead reserves after previously completed story gates.
	state.data = after_emma.duplicate(true)
	state.data.current = "B07"
	state.data.available = ["B07"]
	state.data.completed.append_array(["S03", "S04", "F01", "S05", "S07", "F02"])
	state.data.owned.JIA.hp = 5.0
	state.data.owned.JIA.mp = 0.0
	state.data.owned.F11.hp = 0.0
	state.data.owned.F11.mp = 0.0
	state.data.owned.F11.dead = true
	state.data.owned.F03 = state.new_character("F03")
	state.data.owned.F03.hp = 0.0
	state.data.owned.F03.dead = true
	state.data.party = ["", ""]
	for id in ["F03", "N18", "F07"]: state.data.pool.erase(id)
	expect(state.valid(state.data) and state.save_slot("auto"), "persist legal damaged/dead story-replay boundary")
	shell.open_page("journal")
	await frames()
	watch()
	expect(shell.replayable_stories() == ["S01", "S02", "S03", "S04", "F01", "S05"], "only completed authored event/spring scripts enter journal")
	expect(not shell.open_story_replay("S07") and not shell.open_story_replay("F02"), "unproduced event/spring summaries have no replay")
	for id in ["S03", "S04", "S05", "F01"]:
		await click("journal_replay_" + id)
		if id == "F01":
			var last: String = CATALOG.events().F01.lines[-1].id
			shell._advance_story_replay(last)
			shell.story_view.reveal_current()
			expect((shell.find_child("event_continue", true, false) as Button).text == "结束回顾" and not shell.find_child("StoryCompletionHint", true, false).visible, "spring replay offers no drink or heal action")
			await capture("04-spring-replay-1280")
			await key(KEY_ENTER)
		else: await click("story_skip")
		expect(shell.page == "journal", "finished story replay returns to journal " + id)
		unchanged("no pool unlock/heal/revival " + id)
	state.guarded = false
	state.data.owned.erase("F11")
	state.data.pool.erase("F11")
	expect(state.save_slot("auto"), "persist completed-story save without Emma record")
	watch()
	await click("journal_replay_S02")
	await click("story_skip")
	expect(not state.data.owned.has("F11") and "F11" not in state.data.pool, "replay never fills missing past gifts or unlocks")
	unchanged("past gift absent")
	state.guarded = false

func older_save_gate() -> void:
	expect(state.reset(false) and state.save_slot("3") and state.load_slot("3"), "load an earlier save with no completed stories")
	shell.resume_view()
	shell.open_page("journal")
	await frames()
	watch()
	expect(shell.replayable_stories().is_empty() and shell.find_child("journal_replay_S02", true, false) == null, "older save hides previously replayed content")
	expect(not shell.open_story_replay("S02") and shell.replay_event.is_empty(), "no cross-save replay unlock leaks")
	unchanged("older save eligibility")
	state.guarded = false
