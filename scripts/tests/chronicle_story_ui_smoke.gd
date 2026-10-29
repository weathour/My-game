extends SceneTree
## Production campaign transitions and reader input; battle victory is a boundary fixture.
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
const CATALOG := preload("res://scripts/content/story_catalog.gd")
const VIEW := preload("res://scripts/ui/chronicle/chronicle_story_view.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")
var checks := 0
var failures := 0
var capture_dir := ""
var viewport: SubViewport
var shell: Control

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func frames(count: int = 4) -> void:
	for i in count: await process_frame

func settle() -> void:
	await create_timer(0.24).timeout
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

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await settle()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var bitmap := viewport.get_texture().get_image()
	expect(bitmap.get_size() == viewport.size, "render size " + name)
	bitmap.save_png(capture_dir.path_join(name + ".png"))

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated user data")
	if failures: quit(1); return
	var errors := CATALOG.validate()
	expect(errors.is_empty(), "story catalog validates: " + str(errors))
	expect(CATALOG.events().size() == 12 and CATALOG.events().S02.lines.size() == 18, "twelve authored story nodes preserve the existing Emma conversation")
	var original_motion := SETTINGS.comfort_enabled("reduced_motion")
	var original_text := SETTINGS.comfort_enabled("large_story_text")
	SETTINGS.save_comfort("reduced_motion", false)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	shell = SHELL.instantiate()
	shell.session.directory = "user://chronicle_story_ui_" + str(Time.get_ticks_usec())
	viewport.add_child(shell)
	await frames(10)
	var state: RefCounted = shell.session
	state.data.reward_seed = 781103
	expect(state.begin_campaign(), "begin production campaign")
	shell.open_page("event")
	await frames()
	expect(shell.story_view.current_line_id == "s01_01" and state.data.story_checkpoint == {"event":"S01", "line":"s01_01"}, "opening reader saves initial line")
	await capture("01-opening-1280")
	await click("story_skip")
	expect(state.data.current == "B01" and state.data.story_checkpoint.is_empty(), "skip resolves opening once")
	var request: Dictionary = state.start_battle()
	expect(not request.is_empty(), "first battle request")
	expect(state.complete_battle({"attempt_id":request.attempt_id, "outcome":"victory", "characters":request.characters}), "validated victory boundary")
	shell.resume_view()
	await frames()
	expect(shell.page == "reward" and not state.data.owned.has("F11") and "F11" not in state.data.pending.candidates, "five-card reward precedes Emma story")
	await capture("02-first-reward-1280")
	var picks: Array = state.data.pending.candidates.slice(0,2)
	await click("reward_card_" + picks[0])
	expect(state.read_slot("auto").pending.selected == [picks[0]], "partial first reward selection persists")
	await click("reward_card_" + picks[1])
	await click("reward_claim")
	expect(shell.page == "event" and state.data.current == "S02" and not state.data.owned.has("F11"), "claim automatically enters S02 without early recruitment")
	expect(shell.story_view.current_line_id == "s02_01" and state.data.story_checkpoint.line == "s02_01", "entry checkpoint committed")
	var reader: Control = shell.story_view
	var words := reader.find_child("StoryWords", true, false) as RichTextLabel
	words.visible_characters = 0
	await key(KEY_ENTER)
	expect(words.visible_characters == -1 and reader.current_line_id == "s02_01", "first confirmation only reveals current sentence")
	await key(KEY_SPACE)
	expect(reader.current_line_id == "s02_02" and state.data.story_checkpoint.line == "s02_02", "Space advances and persists stable line")
	reader.reveal_current()
	await capture("03-jia-speaking-1280")
	await settle()
	var jia := reader.find_child("StoryActor_JIA", true, false) as TextureRect
	var emma := reader.find_child("StoryActor_F11", true, false) as TextureRect
	expect(jia != null and emma != null and jia.texture != emma.texture, "two character identities present")
	expect(jia != null and emma != null and jia.modulate.r > emma.modulate.r, "speaking character is brighter")
	await key(KEY_ENTER)
	expect(reader.current_line_id == "s02_03", "Enter advances to Emma response")
	reader.reveal_current()
	await settle()
	expect((reader.find_child("StorySpeaker",true,false) as Label).text == "艾玛", "speaker name follows current line")
	var snapshot: Dictionary = state.data.duplicate(true)
	await key(KEY_ESCAPE)
	expect(shell.page == "route" and state.data == snapshot, "Escape leaves story without event completion")
	shell.resume()
	await frames()
	expect(shell.page == "event" and shell.story_view.current_line_id == "s02_03" and not state.data.owned.has("F11"), "load resumes exact line without joining")
	reader = shell.story_view
	reader.reveal_current()
	await capture("04-emma-response-1280")
	var directory: String = state.directory
	state.directory = "/proc/chronicle-story-ui-read-only"
	snapshot = state.data.duplicate(true)
	print("EXPECTED_FAULT_INJECTION: story UI line write rejected")
	await click("event_continue")
	expect(state.data == snapshot and reader.current_line_id == "s02_03", "failed save leaves line and campaign unchanged")
	expect(reader._error.visible and not is_instance_valid(shell.modal), "failed save stays in reader with visible error")
	state.directory = directory
	await click("event_continue")
	expect(reader.current_line_id == "s02_04" and state.data.story_checkpoint.line == "s02_04", "same-button retry immediately advances after storage recovers")
	await settle()
	reader.reveal_current()
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]:
		viewport.size = dimensions
		await frames(12)
		reader = shell.story_view
		reader.reveal_current()
		await settle()
		var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
		for name in ["StoryDialogue", "StorySpeaker", "event_continue", "story_back", "story_skip"]:
			var control := reader.find_child(name,true,false) as Control
			expect(control != null and bounds.encloses(control.get_global_rect()), "reading control fits " + str(dimensions) + "/" + name)
		for actor_id in ["JIA", "F11"]:
			var actor := reader.find_child("StoryActor_" + actor_id,true,false) as TextureRect
			expect(actor != null and bounds.encloses(actor.get_global_rect()), "character stays on stage after resize: " + actor_id + "/" + str(dimensions))
			if actor != null:
				var fraction := 0.25 if actor_id == "JIA" else 0.75
				expect(absf(actor.get_global_rect().get_center().x - dimensions.x * fraction) < 3.0, "character retains assigned stage position: " + actor_id)
		expect(reader.find_child("StoryBackground",true,false).texture != null, "scene background is loaded")
		await capture("05-dialogue-%d" % dimensions.x)
	SETTINGS.save_comfort("reduced_motion", true)
	SETTINGS.save_comfort("large_story_text", true)
	viewport.size = Vector2i(960,540)
	shell.render()
	await frames(12)
	reader = shell.story_view
	expect((reader.find_child("StoryWords",true,false) as RichTextLabel).visible_characters == -1, "reduced motion reveals text immediately")
	await capture("06-large-text-960")
	var steps := 0
	while shell.page == "event" and shell.story_view.current_line_id != "s02_18" and steps < 20:
		shell.story_view.reveal_current()
		await settle()
		await click("event_continue")
		steps += 1
	reader = shell.story_view
	reader.reveal_current()
	var outcome := reader.find_child("StoryCompletionHint",true,false) as Label
	expect(reader.current_line_id == "s02_18" and outcome != null and outcome.visible and "艾玛" in outcome.text, "last sentence exposes separate recruitment result")
	expect((reader.find_child("event_continue",true,false) as Button).text == "完成剧情", "last sentence has an explicit completion action")
	await capture("06-ending-960")
	await settle()
	state.directory = "/proc/chronicle-story-ui-read-only"
	snapshot = state.data.duplicate(true)
	print("EXPECTED_FAULT_INJECTION: story UI completion write rejected")
	await click("story_skip")
	expect(shell.page == "event" and state.data == snapshot and not state.data.owned.has("F11"), "failed ending grants no character and retains reader")
	state.directory = directory
	await click("story_skip")
	expect(shell.page == "route" and state.data.current == "B02" and state.data.owned.F11.level == 1 and state.data.story_checkpoint.is_empty(), "successful ending joins Emma once and clears checkpoint")
	shell.resume()
	await frames()
	expect(shell.page == "route" and state.data.owned.F11.level == 1 and state.data.pending.is_empty(), "reload after ending duplicates no cards or rewards")
	await other_scenes()
	shell.queue_free()
	await frames()
	viewport.queue_free()
	await frames()
	SETTINGS.save_comfort("reduced_motion", original_motion)
	SETTINGS.save_comfort("large_story_text", original_text)
	print("CHRONICLE_STORY_UI_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func other_scenes() -> void:
	shell.hide()
	viewport.size = Vector2i(1280,720)
	for pair in [["S03","s03_02"],["S04","s04_03"],["S05","s05_02"],["F01","f01_02"]]:
		var reader := VIEW.new()
		reader.setup(CATALOG.events()[pair[0]], pair[1])
		viewport.add_child(reader)
		await frames(8)
		expect(reader.find_child("StoryBackground",true,false).texture != null, "event background " + pair[0])
		if pair[0] in ["S03","S04"]:
			expect(reader.find_child("StoryActor_F11",true,false) == null, "unrelated Emma portrait absent from " + pair[0])
		await capture("07-scene-" + pair[0])
		reader.queue_free()
		await frames()
