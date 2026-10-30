extends SceneTree
## Production transcript input, reader rebuilds and read-only campaign/file invariants.
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
const CATALOG := preload("res://scripts/content/story_catalog.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")

class GuardedCampaign extends "res://scripts/campaign/campaign_service.gd":
	var guarded := false
	var calls: Array[String] = []

	func save_slot(slot: String) -> bool:
		if guarded: calls.append("save_slot"); return false
		return super.save_slot(slot)

	func choose_node(id: String) -> bool:
		if guarded: calls.append("choose_node"); return false
		return super.choose_node(id)

	func save_story_checkpoint(event_id: String, line_id: String) -> bool:
		if guarded: calls.append("save_story_checkpoint"); return false
		return super.save_story_checkpoint(event_id, line_id)

	func resolve_event() -> bool:
		if guarded: calls.append("resolve_event"); return false
		return super.resolve_event()

var checks := 0
var failures := 0
var changed_count := 0
var capture_dir := ""
var viewport: SubViewport
var shell: Control
var state: GuardedCampaign
var baseline: Dictionary
var baseline_changes := 0

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func frames(count: int = 8) -> void:
	for i in count: await process_frame

func click(id: String) -> void:
	var button := shell.find_child(id, true, false) as Button
	expect(button != null and button.is_visible_in_tree() and not button.disabled, "usable " + id)
	if button != null and not button.disabled: button.pressed.emit()
	await frames()

func send_key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	viewport.push_input(event)
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event)

func send_mouse(button: int, at: Vector2 = Vector2(-1,-1)) -> void:
	if at.x < 0: at = Vector2(viewport.size) * Vector2(.6,.65)
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.global_position = at
	event.pressed = true
	viewport.push_input(event)
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event)

func words() -> RichTextLabel:
	return shell.find_child("StoryWords", true, false) as RichTextLabel

func history_scroll() -> ScrollContainer:
	return shell.find_child("StoryHistoryScroll", true, false) as ScrollContainer

func snapshot() -> Dictionary:
	var files := {}
	for filename in DirAccess.get_files_at(state.directory):
		var path := state.directory.path_join(filename)
		files[filename] = {"bytes":FileAccess.get_file_as_bytes(path), "mtime":FileAccess.get_modified_time(path)}
	return {"data":state.data.duplicate(true), "rng":state.reward_rng.state, "files":files,
		"battle":state.in_battle, "entry":state.entry_snapshot.duplicate(true), "attempt":state.active_attempt}

func watch() -> void:
	state.calls.clear()
	state.guarded = true
	baseline = snapshot()
	baseline_changes = changed_count

func unchanged(label: String) -> void:
	expect(snapshot() == baseline, label + ": full campaign/RNG/auto/manual/backup bytes and mtimes unchanged")
	expect(state.calls.is_empty() and changed_count == baseline_changes, label + ": no campaign transaction calls or changed signal")

func fixture(line_id: String = "s02_03") -> void:
	state.guarded = false
	state.reset(false)
	state.data.started = true
	state.data.current = "S02"
	state.data.available = ["S02"]
	state.data.completed = ["S01", "B01"]
	state.data.reward_seed = 781103
	expect(state.save_story_checkpoint("S02", line_id), "persist current story checkpoint")
	expect(state.save_slot("auto") and state.save_slot("1") and state.save_slot("1"), "create auto/manual/backup baseline")
	shell.resume_view(true)
	await frames(12)
	expect(shell.page == "event" and shell.story_view.current_line_id == line_id, "reader opens exact saved line")
	watch()

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await frames()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var bitmap := viewport.get_texture().get_image()
	expect(bitmap.get_size() == viewport.size, "exact render size " + name)
	bitmap.save_png(capture_dir.path_join(name + ".png"))

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated campaign data")
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
	state.directory = "user://story_history_" + str(Time.get_ticks_usec())
	state.changed.connect(func(): changed_count += 1)
	shell.session = state
	viewport.add_child(shell)
	await frames(12)
	await partial_line_and_input()
	await scrolling_and_rebuild()
	await replay_with_pending_reward()
	await empty_and_busy()
	await named_npc_and_narrator()
	SETTINGS.save_comfort("reduced_motion", original_motion)
	SETTINGS.save_comfort("large_story_text", original_text)
	shell.queue_free()
	await frames()
	viewport.queue_free()
	await frames()
	print("CHRONICLE_STORY_HISTORY_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func partial_line_and_input() -> void:
	await fixture()
	var reader: Control = shell.story_view
	reader.set_process(false)
	words().visible_characters = 4
	reader._revealed = 4.0
	reader.show_error("未能保存阅读位置，请重试。")
	var current_background: Texture2D = (reader.find_child("StoryBackground", true, false) as TextureRect).texture
	var focus := shell.find_child("event_continue", true, false) as Button
	focus.grab_focus()
	send_mouse(MOUSE_BUTTON_WHEEL_UP)
	reader.set_process(true)
	await frames(12)
	expect(reader.is_history_open() and shell.page == "event", "mouse wheel up opens history inside live reader")
	var entries: Array = reader.history_entries()
	var lines: Array = CATALOG.events().S02.lines
	expect(entries.size() == 3 and entries[0].id == "s02_01" and entries[1].id == "s02_02", "history restores prior current-event prefix")
	expect(entries[0].text == lines[0].text and entries[1].text == lines[1].text and entries[1].speaker_name == "贾苇索", "prior lines and real speaker names match authored text")
	expect(entries[2].id == "s02_03" and entries[2].text == str(lines[2].text).left(4) and entries[2].speaker_name == "艾玛", "current history row includes only already displayed characters")
	expect(reader.find_child("StoryHistoryText_s02_04", true, false) == null, "future unread sentence absent from history UI")
	await create_timer(.3).timeout
	expect(words().visible_characters == 4 and is_equal_approx(reader._revealed, 4.0), "history pauses actual typewriter process")
	for id in ["event_continue", "story_skip", "story_back", "story_history"]:
		var button := reader.find_child(id, true, false) as Button
		expect(button.disabled, "underlying button disabled " + id)
		button.pressed.emit()
	reader._request_continue()
	reader._request_skip()
	reader._request_advance("")
	reader._request_leave()
	expect(reader.is_history_open() and reader.current_line_id == "s02_03" and shell.page == "event", "disabled signals and direct requests cannot bypass history")
	await capture("01-partial-history-1280")
	shell.render()
	await frames(12)
	reader = shell.story_view
	expect(reader.is_history_open() and words().visible_characters == 4 and is_equal_approx(reader._revealed, 4.0), "shell rebuild keeps partially typed history paused")
	send_key(KEY_ESCAPE)
	expect(not reader.is_history_open() and shell.page == "event" and words().visible_characters == 4 and is_equal_approx(reader._revealed, 4.0), "first Escape closes history at same typewriter position")
	expect(viewport.gui_get_focus_owner().name == "event_continue" and reader.find_child("StoryError", true, false).visible, "closing restores focus and pending save error")
	expect((reader.find_child("StoryBackground", true, false) as TextureRect).texture == current_background, "history does not change background")
	reader.set_process(false)
	for code in [KEY_ENTER, KEY_SPACE]:
		send_key(KEY_PAGEUP)
		expect(reader.is_history_open(), "PageUp opens history")
		send_key(code)
		expect(not reader.is_history_open() and reader.current_line_id == "s02_03", "confirmation closes history without advancing")
	send_mouse(MOUSE_BUTTON_WHEEL_UP)
	send_mouse(MOUSE_BUTTON_RIGHT)
	expect(not reader.is_history_open() and shell.page == "event", "right click only returns to dialogue")
	(reader.find_child("story_skip", true, false) as Button).grab_focus()
	send_key(KEY_TAB)
	expect(viewport.gui_get_focus_owner().name == "story_history", "Tab can reach transcript entry")
	send_key(KEY_ENTER)
	expect(reader.is_history_open() and reader.current_line_id == "s02_03", "keyboard entry opens history before current sentence is fully typed")
	send_key(KEY_TAB)
	expect(viewport.gui_get_focus_owner().name == "story_history_close", "history traps Tab on return control")
	send_key(KEY_ENTER)
	expect(not reader.is_history_open() and reader.current_line_id == "s02_03", "keyboard return leaves current sentence untouched")
	await click("story_history")
	await click("story_history_close")
	expect(not reader.is_history_open(), "explicit return button closes history")
	unchanged("partial history and all close controls")
	send_key(KEY_PAGEUP)
	send_key(KEY_ESCAPE)
	expect(shell.page == "event", "single Escape never leaves reader")
	send_key(KEY_ESCAPE)
	await frames()
	expect(shell.page == "route", "second separate Escape retains normal reader exit")
	unchanged("Escape propagation")

func scrolling_and_rebuild() -> void:
	SETTINGS.save_comfort("reduced_motion", true)
	SETTINGS.save_comfort("large_story_text", true)
	await fixture("s02_16")
	var expected_prefix := 0
	for line in CATALOG.events().S02.lines:
		expected_prefix += 1
		if line.id == "s02_16": break
	var future_line: String = CATALOG.events().S02.lines[expected_prefix].id
	send_mouse(MOUSE_BUTTON_WHEEL_UP)
	await frames(14)
	var scroll := history_scroll()
	var bar := scroll.get_v_scroll_bar()
	expect(scroll.scroll_vertical > 0 and scroll.scroll_vertical >= bar.max_value - bar.page - 2, "history initially shows most recent rows")
	send_key(KEY_ENTER)
	send_mouse(MOUSE_BUTTON_WHEEL_UP)
	send_mouse(MOUSE_BUTTON_WHEEL_UP)
	await frames(14)
	scroll = history_scroll()
	bar = scroll.get_v_scroll_bar()
	expect(shell.story_view.is_history_open() and absf(scroll.scroll_vertical - (bar.max_value - bar.page - 64)) < 3, "rapid opening wheel burst browses just above latest records: actual=%s max=%s page=%s" % [scroll.scroll_vertical, bar.max_value, bar.page])
	send_key(KEY_END)
	send_mouse(MOUSE_BUTTON_WHEEL_UP)
	expect(shell.story_view.is_history_open() and scroll.scroll_vertical < bar.max_value - bar.page - 2, "continued up wheel browses earlier lines")
	send_key(KEY_HOME)
	expect(scroll.scroll_vertical == 0, "Home reaches first history row")
	send_mouse(MOUSE_BUTTON_WHEEL_DOWN)
	expect(shell.story_view.is_history_open() and scroll.scroll_vertical > 0, "down wheel inside transcript scrolls without leaving")
	send_key(KEY_PAGEDOWN)
	expect(scroll.scroll_vertical > 64, "PageDown browses history")
	send_key(KEY_PAGEUP)
	expect(shell.story_view.is_history_open(), "PageUp in history scrolls instead of reopening")
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]:
		history_scroll().scroll_vertical = 120
		var before: Dictionary = shell.story_view.reading_state()
		viewport.size = dimensions
		await frames(16)
		expect(shell.story_view.is_history_open() and shell.story_view.current_line_id == "s02_16" and words().visible_characters == -1, "resize keeps history open and same live line " + str(dimensions))
		expect(absf(history_scroll().scroll_vertical - int(before.history_scroll)) < 2, "resize preserves transcript scroll " + str(dimensions))
		var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
		for id in ["StoryHistoryPanel", "StoryHistoryScroll", "story_history_close"]:
			var control := shell.find_child(id, true, false) as Control
			expect(control != null and bounds.encloses(control.get_global_rect()), "large history control fits " + id + str(dimensions))
		expect(shell.story_view.history_entries().size() == expected_prefix and shell.find_child("StoryHistoryText_" + future_line, true, false) == null, "rebuild preserves prefix without future rows")
		await capture("02-large-history-" + str(dimensions.x))
	var ui: Dictionary = shell.story_view.reading_state()
	var invalid: Dictionary = ui.duplicate(true)
	invalid.event_id = "S03"
	invalid.visible_characters = 0
	shell.story_view.restore_reading_state(invalid)
	expect(shell.story_view.reading_state() == ui, "mismatched event snapshot ignored")
	invalid = ui.duplicate(true)
	invalid.line_id = "s02_01"
	shell.story_view.restore_reading_state(invalid)
	expect(shell.story_view.reading_state() == ui, "mismatched line snapshot ignored")
	invalid = ui.duplicate(true)
	invalid.replay = true
	shell.story_view.restore_reading_state(invalid)
	expect(shell.story_view.reading_state() == ui, "snapshot from other reader mode ignored")
	send_key(KEY_END)
	expect(shell.story_view.is_history_open(), "End remains inside history at latest record")
	send_mouse(MOUSE_BUTTON_WHEEL_DOWN)
	expect(not shell.story_view.is_history_open() and shell.page == "event" and shell.story_view.current_line_id == "s02_16", "extra down wheel at bottom returns without advancing")
	unchanged("scrolling and UI rebuild")
	send_mouse(MOUSE_BUTTON_WHEEL_UP)
	shell.render()
	shell.open_page("route")
	await frames(16)
	expect(shell.page == "route" and shell.story_view == null, "rapid page exit cancels deferred history restoration")
	shell.open_page("event")
	await frames(12)
	expect(not shell.story_view.is_history_open() and shell.story_view.current_line_id == "s02_16", "fresh reader keeps checkpoint without lingering overlay")
	unchanged("deferred history lifetime")

func replay_with_pending_reward() -> void:
	viewport.size = Vector2i(1280,720)
	await frames(12)
	SETTINGS.save_comfort("large_story_text", false)
	state.guarded = false
	state.reset(false)
	state.data.started = true
	state.data.current = "B06"
	state.data.available = ["B06", "S05"]
	state.data.completed = ["S01", "B01", "S02", "B02", "S03", "B04", "B03", "S04", "F01"]
	state.data.owned.F11 = state.new_character("F11")
	state.data.pool.append("F11")
	state.data.owned.F11.hp = 0.0
	state.data.owned.F11.dead = true
	state.data.owned.JIA.hp = 5.0
	state.data.owned.JIA.mp = 0.0
	expect(state.make_reward("B06", false) and state.select_card(state.data.pending.candidates[0]), "persist damaged party with partial victory reward")
	expect(state.valid(state.data), "valid pending reward replay boundary")
	shell.resume_view()
	shell.open_page("journal")
	await frames(12)
	watch()
	expect(shell.open_story_replay("S02", "journal"), "open completed Emma scene during pending reward")
	shell._advance_story_replay("s02_05")
	await frames(12)
	send_mouse(MOUSE_BUTTON_WHEEL_UP)
	await frames(12)
	expect(shell.story_view.is_history_open() and shell.story_view.history_entries().size() == 5, "replay uses only its current-scene viewed prefix")
	await capture("03-replay-history-1280")
	send_key(KEY_ENTER)
	expect(shell.page == "replay" and not shell.story_view.is_history_open(), "Enter closes replay history without finishing scene")
	await click("story_skip")
	expect(shell.page == "journal", "normal replay end still returns to original journal")
	expect(shell.open_story_replay("F01", "journal"), "open completed spring narration")
	shell._advance_story_replay(CATALOG.events().F01.lines[-1].id)
	await frames(12)
	send_key(KEY_PAGEUP)
	expect(shell.story_view.is_history_open() and shell.story_view.history_entries().size() == CATALOG.events().F01.lines.size(), "spring history available without triggering recovery")
	send_key(KEY_SPACE)
	await click("story_skip")
	unchanged("replay history leaves gift, revival and pending cards untouched")

func empty_and_busy() -> void:
	SETTINGS.save_comfort("reduced_motion", false)
	await fixture("s02_01")
	shell.story_view.set_process(false)
	words().visible_characters = 0
	shell.story_view._revealed = 0.0
	send_mouse(MOUSE_BUTTON_WHEEL_UP)
	await frames(12)
	expect(shell.story_view.is_history_open() and shell.story_view.history_entries().is_empty(), "zero revealed characters do not leak the first sentence")
	expect(shell.find_child("StoryHistoryEmpty", true, false).visible, "empty transcript explains itself")
	viewport.size = Vector2i(960,540)
	await frames(16)
	expect(shell.story_view.is_history_open() and shell.story_view.history_entries().is_empty(), "empty state survives resize without starting typewriter")
	await capture("04-empty-history-960")
	send_key(KEY_ESCAPE)
	shell.story_view.set_busy(true)
	send_mouse(MOUSE_BUTTON_WHEEL_UP)
	(shell.find_child("story_history", true, false) as Button).pressed.emit()
	expect(not shell.story_view.is_history_open(), "busy commit blocks mouse and button history open")
	shell.story_view.set_busy(false)
	unchanged("empty and busy history")

func named_npc_and_narrator() -> void:
	shell.hide()
	var view := preload("res://scripts/ui/chronicle/chronicle_story_view.gd").new()
	var event: Dictionary = CATALOG.events().S01.duplicate(true)
	event.id = "named_speaker_fixture"
	event.lines = [{"id":"named_npc","speaker":"","speaker_name":"守门人","text":"fixture npc","actors":[]}, {"id":"true_narrator","speaker":"","text":"fixture narration","actors":[]}]
	view.setup(event, "named_npc")
	viewport.add_child(view)
	await frames()
	view.reveal_current()
	var name := view.find_child("StorySpeaker", true, false) as Label
	expect(name.text == "守门人" and name.is_visible_in_tree(), "named world NPC shows explicit name without a card identity")
	expect(view.history_entries()[0].speaker_name == "守门人", "named NPC transcript retains explicit name")
	view.show_line("true_narrator")
	view.reveal_current()
	expect(name.text.is_empty() and not name.is_visible_in_tree(), "true narration keeps nameplate hidden")
	var entries: Array = view.history_entries()
	expect(entries.size() == 2 and entries[0].speaker_name == "守门人" and entries[1].speaker_name.is_empty(), "history distinguishes named NPC from narration")
	(view.find_child("story_history", true, false) as Button).pressed.emit()
	await frames()
	var npc_name := view.find_child("StoryHistorySpeaker_named_npc", true, false) as Label
	var narrator_name := view.find_child("StoryHistorySpeaker_true_narrator", true, false) as Label
	expect(npc_name != null and npc_name.text == "守门人" and npc_name.is_visible_in_tree(), "rendered NPC history name visible")
	expect(narrator_name != null and not narrator_name.is_visible_in_tree(), "rendered narrator history has no false identity")
	view.queue_free(); await frames()
	shell.show()
	unchanged("NPC/narrator transcript is presentation only")
