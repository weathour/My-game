extends SceneTree

const SAVE := preload("res://scripts/save_manager.gd")
const PROGRESS := preload("res://scripts/story/story_progress.gd")
const CONTENT := preload("res://scripts/story/story_content.gd")
const MENU := preload("res://scenes/main_menu.tscn")
const SETTINGS := preload("res://scripts/game_settings.gd")
var failures := 0
var capture := false

func _init() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func frames(count: int = 3) -> void:
	for _i in count:
		await process_frame

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await frames()

func click(text: String) -> bool:
	for button in current_scene.find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and button.text == text and not button.disabled:
			button.pressed.emit()
			return true
	expect(false, "Missing usable button: " + text)
	return false

func read_and_click(text: String) -> void:
	if current_scene.dialogue_panel.words.visible_characters >= 0:
		click(text)
	click(text)
	await frames()

func screenshot(name: String) -> void:
	if not capture or DisplayServer.get_name() == "headless":
		return
	await frames()
	if current_scene.get("dialogue_panel") != null and current_scene.dialogue_panel.visible:
		current_scene.dialogue_panel.words.visible_characters = -1
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/story-framework")
	root.get_texture().get_image().save_png("res://artifacts/story-framework/" + name + ".png")

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "Use an isolated save directory")
	if failures:
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	SAVE.delete_story_profile(3)
	var menu := MENU.instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames()
	expect(click("主线模式"), "main menu exposes story entry")
	await frames()
	expect(current_scene.get_script() == preload("res://scripts/save_select.gd"), "story entry opens slot selection")
	await screenshot("00-story-slot-selection")
	var selected := false
	for button in current_scene.find_children("*", "Button", true, false):
		for label in button.find_children("*", "Label", true, false):
			if label.text == "存档 3":
				button.pressed.emit()
				selected = true
	expect(selected, "third slot reachable through its card")
	await frames()
	expect(current_scene.get_script() == preload("res://scripts/story_prep.gd"), "new slot opens story preparation")
	var prep = current_scene
	expect(SAVE.load_story_profile(3).story.quest_states["q.c1.outpost"] == "available", "new slot initializes available first quest")
	for button in prep.page_root.find_children("*", "Button", true, false):
		if button.text in ["任务与记录", "调整队伍", "返回主菜单"]:
			expect(button.size.x >= 120 and button.size.y < 70, "header actions remain readable")
	expect(prep.page_root.find_children("Clue_*", "Button", true, false).is_empty(), "undiscovered objects stay hidden")
	await screenshot("01-preparation-1280")
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	await frames()
	for control_name in ["CampScene", "StoryRoute", "RadioRecord", "StoryFooter"]:
		var control: Control = prep.page_root.find_child(control_name, true, false)
		expect(control != null and Rect2(Vector2.ZERO, Vector2(960, 540)).encloses(control.get_global_rect()), "story scene and route fit minimum window: " + control_name)
	await screenshot("01-preparation-960")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	await frames()
	for quest: Dictionary in CONTENT.entries("quests"):
		var npc := str(CONTENT.find("speakers", quest.accept_npc).name)
		expect(click("与" + npc + "确认任务"), "acceptance reachable from preparation")
		await frames()
		await screenshot("02-dialogue-" + quest.id)
		await read_and_click("接下任务")
		await read_and_click("结束交谈")
		expect(SAVE.load_story_profile(3).story.quest_states[quest.id] == "active", "actual dialogue accepts task")
		expect(click("出击：" + CONTENT.stage(quest.stage_id).title), "battle entry reachable")
		await frames(5)
		var main = current_scene
		expect(bool(main.get("story_mode_active")), "actual combat uses story context")
		expect(main.story_stage.id == quest.stage_id and main.wave_flow == null, "story preserves existing stage and excludes endless waves")
		main.survival_time = float(CONTENT.stage(quest.stage_id).target_time)
		main._on_stage_cleared()
		await frames(5)
		expect(current_scene.get_script() == preload("res://scripts/story_prep.gd"), "victory returns to story preparation")
		expect(SAVE.load_story_profile(3).story.quest_states[quest.id] == "ready_to_turn_in", "victory saves pending delivery")
		var before_inspect := SAVE.load_story_profile(3)
		var item_name: String = CONTENT.find("items", quest.first_clear_reward.items[0].item_id).name
		expect(click(item_name + " · 待交付"), "earned object opens its record")
		await frames()
		expect(current_scene.journal_panel.visible, "object inspection opens journal")
		expect(click("返回准备"), "return from object inspection")
		await frames()
		var after_inspect := SAVE.load_story_profile(3)
		expect(after_inspect.story == before_inspect.story and after_inspect.boss_core_fragments == before_inspect.boss_core_fragments, "inspecting a clue never delivers or consumes it")
		await screenshot("01-returned-" + quest.id)
		expect(click("交付给" + CONTENT.find("speakers", quest.turn_in_npc).name), "delivery reachable")
		await frames()
		var choice: Dictionary = CONTENT.node(quest.dialogues.turn_in, "start").choices[0]
		await read_and_click(choice.text)
		while not current_scene.dialogue_panel.flow.current_node().is_empty():
			var node: Dictionary = current_scene.dialogue_panel.flow.current_node()
			await read_and_click("结束交谈" if bool(node.get("end", false)) else "继续")
		await frames()
		expect(SAVE.load_story_profile(3).story.quest_states[quest.id] == "completed", "actual delivery completes task")
		expect(click(item_name + " · 已整理"), "delivered object remains as a read-only memory")
		await frames()
		expect(click("返回准备"), "return from memory")
		await frames()
	expect(click("任务与记录"), "journal reachable")
	await frames()
	await screenshot("03-journal-1280")
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	await screenshot("04-journal-960")
	click("返回准备")
	await frames()
	for control_name in ["CampScene", "StoryRoute", "RadioRecord", "StoryFooter"]:
		var control: Control = current_scene.page_root.find_child(control_name, true, false)
		expect(Rect2(Vector2.ZERO, Vector2(960, 540)).encloses(control.get_global_rect()), "completed chapter fits minimum window: " + control_name)
	await screenshot("05-completed-960")
	SETTINGS.save_comfort("large_story_text", true)
	SETTINGS.save_comfort("reduced_motion", true)
	expect(click("剑士 · 交谈"), "optional conversation remains reachable after chapter completion")
	await frames()
	var panel = current_scene.dialogue_panel
	expect(panel.words.visible_characters == -1 and panel.words.get_theme_font_size("normal_font_size") == 25, "large text and instant reveal apply on opening")
	for _i in 10:
		await key(KEY_TAB)
		expect(panel.is_ancestor_of(root.gui_get_focus_owner()), "dialogue keyboard focus stays within modal")
	await screenshot("06-dialogue-large-text-960")
	await key(KEY_ESCAPE)
	expect(not panel.visible and SAVE.load_story_profile(3).story.dialogue_checkpoint.conversation_id == "dlg.c1.afterword", "Escape preserves dialogue checkpoint")
	expect(click("任务与记录"), "journal can reopen with large text")
	await frames()
	await screenshot("07-journal-large-text-960")
	await key(KEY_ESCAPE)
	expect(SAVE.load_story_profile(3).story.flags.get("chapter1.communications_restored", false), "chapter completed through real UI")
	SAVE.delete_story_profile(3)
	print("STORY_UI_SMOKE_OK" if failures == 0 else "STORY_UI_SMOKE_FAILED")
	quit(0 if failures == 0 else 1)
