extends "res://scripts/tests/chronicle_story_replay_smoke.gd"
## Actual journal, optional reader and lore rendering plus guarded optional replay.

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated save location")
	if failures: quit(1); return
	var original_motion := SETTINGS.comfort_enabled("reduced_motion")
	var original_text := SETTINGS.comfort_enabled("large_story_text")
	SETTINGS.save_comfort("reduced_motion", true)
	SETTINGS.save_comfort("large_story_text", true)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	shell = SHELL.instantiate()
	state = GuardedCampaign.new()
	state.directory = "user://optional_render_" + str(Time.get_ticks_usec())
	state.changed.connect(func(): changed_count += 1)
	# Content library layout fixture, independent of route canon.
	for id in state.CONTENT.IDS: state.data.owned[id] = state.new_character(id)
	state.data.current = "B18"; state.data.available = ["B18"]
	state.data.completed = state.nodes.keys()
	state.data.completed.erase("B18")
	state.data.completed.erase("S14")
	state.data.started = true
	var optional := CATALOG.optional_events()
	var longest_id := ""
	var longest_line := ""
	var length := 0
	for id in optional:
		for line in optional[id].lines:
			if str(line.text).length() > length:
				length = str(line.text).length(); longest_id = id; longest_line = line.id
	expect(not longest_id.is_empty(), "long optional dialogue exists")
	if longest_id.is_empty(): quit(1); return
	shell.session = state
	viewport.add_child(shell)
	await frames(10)
	expect(state.save_slot("auto"), "layout fixture persists")
	var initial := state.data.duplicate(true)
	state.guarded = true
	expect(shell.open_optional_story(longest_id), "optional failed initial entry stays retryable")
	await frames()
	expect(shell.story_view == null and shell.find_child("StoryWords", true, false) == null and shell.find_child("story_entry_retry", true, false) != null, "failed initial commit exposes no uncommitted story text")
	expect(state.data == initial, "initial entry rejection preserves all campaign state")
	state.guarded = false
	await click("story_entry_retry")
	expect(shell.story_view != null and not state.data.optional_story_checkpoints.is_empty(), "first-entry retry creates reader only after persistence")
	await click("story_back")
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]:
		viewport.size = dimensions
		shell.open_page("journal")
		await frames(12)
		var buttons := shell.find_children("journal_optional_*", "Button", true, false)
		expect(buttons.size() == state.available_optional_stories().size() and buttons.size() >= 24, "all available story entries listed " + str(dimensions))
		var scroll := shell.find_child("journal_scroll", true, false) as ScrollContainer
		expect(scroll != null and scroll.size.y > 200 and scroll.get_global_rect().end.y <= dimensions.y, "journal has bounded scroll area " + str(dimensions))
		buttons[-1].grab_focus()
		await frames(12)
		expect(scroll.scroll_vertical > 0, "keyboard focus reaches lower story entries " + str(dimensions))
		await capture("journal-optional-" + str(dimensions.x))
		expect(shell.open_optional_story(longest_id), "first read reachable " + str(dimensions))
		await frames()
		shell._advance_optional_story(longest_line)
		await frames()
		shell.story_view.reveal_current()
		expect(shell.story_view.current_line_id == longest_line and state.data.optional_story_checkpoints[longest_id] == longest_line, "long line checkpoint " + str(dimensions))
		var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
		for id in ["story_back", "story_skip", "event_continue", "StoryWords"]:
			var control := shell.find_child(id, true, false) as Control
			expect(control != null and control.is_visible_in_tree() and bounds.encloses(control.get_global_rect()), "long optional control fits " + id + str(dimensions))
		await capture("optional-long-" + str(dimensions.x))
		await click("story_back")
		expect(shell.page == "journal" and longest_id not in state.read_optional_stories(), "leave preserves independent unread checkpoint")
		await click("journal_optional_" + longest_id)
		expect(shell.story_view.current_line_id == longest_line, "reentry resumes exact optional line")
		await click("story_back")
	# Render a real resolved main scene with its selected conditional insertion.
	var reaction_event := "S03"
	var reaction_line := ""
	var reaction_length := 0
	for main_id in CATALOG.events():
		if not state.nodes[main_id].kind in ["event", "spring"]: continue
		var resolved: Dictionary = state.story_event(main_id)
		for line in resolved.lines:
			if not CATALOG.has_line(CATALOG.events()[main_id], line.id) and str(line.text).length() > reaction_length:
				reaction_event = main_id; reaction_line = line.id; reaction_length = str(line.text).length()
	expect(not reaction_line.is_empty(), "conditional main line available in layout fixture")
	state.data.current = reaction_event; state.data.available = [reaction_event]
	shell.open_page("event")
	await frames()
	if not reaction_line.is_empty(): shell._advance_story(reaction_line)
	var frozen: Dictionary = state.data.story_contexts.get(reaction_event, {}).duplicate(true)
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]:
		viewport.size = dimensions
		await frames(12)
		shell.story_view.reveal_current()
		expect(shell.story_view.current_line_id == reaction_line and state.data.story_contexts[reaction_event] == frozen, "resize preserves frozen conditional line " + str(dimensions))
		await capture("main-reaction-" + str(dimensions.x))
	shell.open_page("journal")
	await frames()
	# First completion only changes its read bit, with normal skip semantics.
	expect(shell.open_optional_story(longest_id), "open optional for completion")
	await frames()
	await click("story_skip")
	expect(longest_id in state.read_optional_stories() and shell.page == "journal", "first finish enters read-only library")
	watch()
	await click("journal_optional_" + longest_id)
	expect(shell.page == "replay" and shell.replay_event == longest_id, "read entry routes through separate replay callbacks")
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]:
		viewport.size = dimensions
		await frames(12)
		shell.story_view.reveal_current()
		await capture("optional-replay-" + str(dimensions.x))
	unchanged("optional replay resize")
	await click("story_skip")
	unchanged("optional replay completion")
	var lore: Array = state.available_story_lore()
	expect(not lore.is_empty(), "lore is discoverable")
	if not lore.is_empty():
		expect(shell.open_story_lore(lore[0].id), "lore opens from existing journal")
		await frames()
		var scroll := shell.find_child("lore_scroll", true, false) as ScrollContainer
		expect(scroll != null and scroll.size.y > 0, "long lore has scroll")
		await capture("lore-1920")
		await click("page_back")
		unchanged("lore viewing")
	state.guarded = false
	# Pending/deferred mandatory transaction blocks first reads, while completed replay stays safe.
	state.data.pending = {"node":"B18"}
	expect(not shell.open_optional_story(str(optional.keys()[-1])), "pending reward blocks first optional read")
	state.data.pending = {}
	state.data.deferred_reward = {"id":"B17", "extra":false}
	expect(not shell.open_optional_story(str(optional.keys()[-1])), "postbattle mandatory scene blocks first optional read")
	state.data.deferred_reward = {}
	SETTINGS.save_comfort("reduced_motion", original_motion)
	SETTINGS.save_comfort("large_story_text", original_text)
	shell.queue_free(); await frames()
	viewport.queue_free(); await frames()
	print("CHRONICLE_STORY_OPTIONAL_RENDER_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
