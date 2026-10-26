extends SceneTree

const SAVE := preload("res://scripts/save_manager.gd")
const STORE := preload("res://scripts/save/save_file_store.gd")
const PROGRESS := preload("res://scripts/story/story_progress.gd")
const CONTENT := preload("res://scripts/story/story_content.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")
const DIALOGUE := preload("res://scripts/ui/story/dialogue_panel.gd")
const JOURNAL := preload("res://scripts/ui/story/story_journal_panel.gd")
var failures := 0

func _init() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func frames() -> void:
	for _i in 4:
		await process_frame

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	root.push_input(event)
	event.pressed = false
	root.push_input(event)
	await frames()

func capture(name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	await frames()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://design/story-20261025")
	root.get_texture().get_image().save_png("res://design/story-20261025/reading-" + name + ".png")

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "Use isolated XDG_DATA_HOME")
	if failures:
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	SAVE.delete_story_profile(3)
	expect(PROGRESS.open_slot(3).ok, "create isolated story slot")
	SETTINGS.save_comfort("reduced_motion", false)
	var opener := Button.new()
	opener.text = "营地"
	root.add_child(opener)
	opener.grab_focus()
	var panel := DIALOGUE.new()
	root.add_child(panel)
	await frames()
	expect(panel.open(3, "dlg.c1.outpost.accept"), "open first task")
	await frames()
	var node := panel.flow.current_node()
	expect(panel.narration.text == node.narration and panel.narration.visible, "environmental narration is separate from spoken words")
	expect(panel.words.text == node.text, "spoken prose remains intact")
	expect(panel.location.text == CONTENT.find("dialogues", "dlg.c1.outpost.accept").location, "scene location is visible")
	expect(panel.options.get_child(0).has_focus(), "first choice owns meaningful focus")
	panel.words.visible_characters = 0
	panel._choose("accept")
	expect(panel.words.visible_characters == -1 and SAVE.load_story_profile(3).story.quest_states["q.c1.outpost"] == "available", "first confirmation reveals without accepting")
	panel._skip()
	expect(panel.flow.current_node().id == "start", "skip never chooses an answer")
	await capture("choices-1280")
	SETTINGS.save_comfort("large_story_text", true)
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	panel._render()
	panel.words.visible_characters = -1
	await frames()
	for button in panel.options.get_children():
		expect(panel.modal.panel.get_global_rect().encloses(button.get_global_rect()), "choices fit minimum viewport at 120 percent text")
	await capture("choices-large-960")
	var blocked := ProjectSettings.globalize_path(STORE.story_profile_path(3) + ".tmp")
	DirAccess.make_dir_absolute(blocked)
	panel._choose("accept")
	expect(panel.error_label.visible and not panel.error_label.text.is_empty(), "failed save remains visible")
	expect(SAVE.load_story_profile(3).story.quest_states["q.c1.outpost"] == "available", "failed save preserves task")
	DirAccess.remove_absolute(blocked)
	panel._choose("accept")
	await frames()
	expect(SAVE.load_story_profile(3).story.quest_states["q.c1.outpost"] == "active", "explicit choice commits task")
	await key(KEY_ESCAPE)
	expect(not panel.visible and opener.has_focus(), "Escape restores opener focus")
	SETTINGS.save_comfort("reduced_motion", true)
	SETTINGS.save_comfort("large_story_text", true)
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	expect(panel.open(3, "dlg.c1.outpost.accept"), "resume saved checkpoint")
	await frames()
	expect(panel.flow.current_node().id == "accepted", "postponement retains checkpoint")
	expect(panel.words.visible_characters == -1 and panel.words.get_theme_font_size("normal_font_size") == 25, "reduced motion and 120 percent text work")
	for _i in 12:
		await key(KEY_TAB)
		expect(panel.modal.is_ancestor_of(root.gui_get_focus_owner()), "Tab focus stays in reading band")
	var bounds: Rect2 = panel.modal.panel.get_global_rect()
	expect(root.get_visible_rect().encloses(bounds), "reading band fits minimum viewport")
	for button in panel.modal.footer.get_children():
		expect(bounds.encloses(button.get_global_rect()), "footer remains in reading band")
	await capture("large-960")
	for dialogue: Dictionary in CONTENT.entries("dialogues"):
		for entry: Dictionary in dialogue.nodes:
			panel.flow.profile.story.dialogue_checkpoint = {"conversation_id": dialogue.id, "node_id": entry.id}
			panel._render()
			await frames()
			var scroll: ScrollContainer = panel.words.get_parent().get_parent()
			expect(scroll.get_global_rect().encloses(panel.narration.get_global_rect()), "narration stays readable: " + dialogue.id + "/" + entry.id)
			expect(scroll.get_global_rect().encloses(panel.words.get_global_rect()), "full prose fits: " + dialogue.id + "/" + entry.id)
			for button in panel.options.get_children():
				expect(scroll.get_global_rect().encloses(button.get_global_rect()), "choice stays readable: " + dialogue.id + "/" + entry.id)
	panel.close()
	var journal := JOURNAL.new()
	root.add_child(journal)
	await frames()
	var profile := SAVE.load_story_profile(3)
	journal.open(profile, "情报")
	await frames()
	var tabs: TabContainer = journal.modal.body_host.get_child(0)
	expect(tabs.get_tab_title(tabs.current_tab) == "情报", "objects can open a specific journal tab")
	var history := tabs.get_child(3)
	var history_text := ""
	for label in history.find_children("*", "Label", true, false):
		history_text += label.text
	for seen_id in profile.story.dialogue_seen_nodes["dlg.c1.outpost.accept"]:
		expect(history_text.contains(CONTENT.node("dlg.c1.outpost.accept", seen_id).narration), "history includes seen environmental narration")
	expect(not history_text.contains(CONTENT.node("dlg.c1.outpost.turn_in", "start").narration), "history excludes unseen narration")
	tabs.current_tab = 3
	await capture("history-large-960")
	journal.close()
	SAVE.delete_story_profile(3)
	print("STORY_READING_SMOKE_OK" if failures == 0 else "STORY_READING_SMOKE_FAILED")
	quit(0 if failures == 0 else 1)
