extends SceneTree
## Title/menu regression against real campaign storage, utility pages and a rendered viewport.
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
const CAMPAIGN := preload("res://scripts/campaign/campaign_service.gd")
const MENU_TEXT := preload("res://scripts/ui/chronicle/chronicle_menu_text.gd")
var viewport: SubViewport
var shell: Control
var checks := 0
var failures := 0
var quit_calls := 0
var quit_signals := 0
var capture_dir := ""

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
	call_deferred("run")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func frames(count: int = 6) -> void:
	for i in count: await process_frame

func button(id: String) -> Button:
	return shell.find_child(id, true, false) as Button

func click(id: String) -> void:
	var target := button(id)
	expect(target != null and target.is_visible_in_tree() and not target.disabled, "usable button " + id)
	if target != null and not target.disabled:
		target.grab_focus()
		target.pressed.emit()
	await frames(10)

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	viewport.push_input(event)
	await frames(2)
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event)
	await frames(6)

func snapshot() -> Dictionary:
	var state: RefCounted = shell.session
	var files := {}
	var directory := ProjectSettings.globalize_path(state.directory)
	if DirAccess.dir_exists_absolute(directory):
		for filename in DirAccess.get_files_at(directory):
			files[filename] = FileAccess.get_file_as_bytes(directory.path_join(filename))
	return {"data":state.data.duplicate(true), "rng":state.reward_rng.state, "files":files,
		"attempt":state.active_attempt, "in_battle":state.in_battle}

func capture(label: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await frames(2)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	viewport.get_texture().get_image().save_png(capture_dir.path_join(label + ".png"))

func fit_home(ids: Array, dimensions: Vector2i) -> void:
	var view_bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
	var panel := shell.find_child("home_menu_panel", true, false) as Control
	expect(panel != null and view_bounds.encloses(panel.get_global_rect()), "home panel fits " + str(dimensions))
	for id in ids:
		var item := button(str(id))
		expect(item != null and item.is_visible_in_tree(), "home action visible " + str(id) + " at " + str(dimensions))
		if item == null: continue
		expect(view_bounds.encloses(item.get_global_rect()), "home action does not overflow " + str(id) + " at " + str(dimensions))
		item.grab_focus()
		expect(viewport.gui_get_focus_owner() == item, "home action is keyboard-focusable " + str(id) + " at " + str(dimensions))
	var codex := button("home_codex")
	var music := button("music_room")
	if codex != null and music != null:
		expect(is_equal_approx(codex.size.y, music.size.y), "home enemy entry matches neighboring button height")
		var a := codex.get_theme_stylebox("normal")
		var b := music.get_theme_stylebox("normal")
		expect(a.get_class() == b.get_class(), "home enemy entry uses the same ordinary border type")
		if a is StyleBoxFlat and b is StyleBoxFlat:
			expect(a.border_width_left == b.border_width_left and a.border_width_top == b.border_width_top and a.border_width_right == b.border_width_right and a.border_width_bottom == b.border_width_bottom and a.border_color == b.border_color and a.corner_radius_top_left == b.corner_radius_top_left and a.corner_radius_top_right == b.corner_radius_top_right and a.corner_radius_bottom_left == b.corner_radius_bottom_left and a.corner_radius_bottom_right == b.corner_radius_bottom_right, "home enemy entry ordinary border matches neighboring button")

func keyboard_home_grid() -> void:
	var opener := button("new_campaign")
	opener.grab_focus()
	await key(KEY_RIGHT)
	var right_focus := viewport.gui_get_focus_owner() as Button
	var expected_right := button("home_load") if not button("home_load").disabled else opener
	expect(right_focus == expected_right, "Right follows the title row and skips a disabled Load action")
	opener.grab_focus()
	await key(KEY_DOWN)
	var down_focus := viewport.gui_get_focus_owner() as Button
	expect(down_focus != null and down_focus != opener and down_focus.is_visible_in_tree() and not down_focus.disabled, "Down reaches an enabled title action from New Campaign")

func install_state(label: String) -> RefCounted:
	var state := CAMPAIGN.new()
	state.directory = "user://home_menu_" + label + "_" + str(Time.get_ticks_usec())
	shell.session = state
	shell.open_page("home")
	await frames(8)
	return state

func utility_round_trip(id: String, destination: String, expected_cue: String, before: Dictionary) -> void:
	var opener := button(id)
	if opener != null: opener.grab_focus()
	await click(id)
	expect(shell.page == destination, id + " opens " + destination)
	if destination in ["settings", "help", "about", "saves", "music"]:
		expect(shell.navigation_contexts.get(destination, {}).get("return_page", "") == "home", id + " records home as its return page")
	if destination in ["settings", "help", "about", "saves"]:
		expect(bool(shell.navigation_contexts.get(destination, {}).get("read_only", false)), id + " is read-only when opened from title")
	if destination == "music":
		expect(shell.music_preview != null and shell.bgm.paused_by_script, "title music preview pauses the source bed")
	await capture("title-" + destination)
	await key(KEY_ESCAPE)
	expect(shell.page == "home", id + " returns to title")
	if destination == "music":
		expect(shell.music_preview == null and not shell.bgm.paused_by_script, "music preview is removed and source bed resumes")
	expect(shell.bgm.current_cue == expected_cue, id + " preserves the source music cue")
	expect(shell.session.data == before.data and shell.session.reward_rng.state == before.rng and snapshot().files == before.files, id + " browsing does not change campaign or save bytes")
	var restored := button(id)
	expect(restored != null and viewport.gui_get_focus_owner() == restored, id + " restores opener focus")

func make_pending_and_story_slots(state: RefCounted) -> Dictionary:
	state.data.reward_seed = 781103
	expect(state.begin_campaign() and state.resolve_event(), "read fixture begins a real run")
	var request: Dictionary = state.start_battle()
	expect(not request.is_empty(), "read fixture starts B01")
	if request.is_empty(): return {}
	var result := {"attempt_id":request.attempt_id, "outcome":"victory", "characters":request.characters.duplicate(true), "card_elite":false}
	expect(state.complete_battle(result), "read fixture creates real pending reward")
	if state.data.pending.is_empty(): return {}
	var first_id: String = state.data.pending.candidates[0]
	expect(state.select_card(first_id), "read fixture persists a partial reward selection")
	var pending_snapshot: Dictionary = state.data.duplicate(true)
	expect(state.save_slot("1"), "manual slot stores selected reward candidates")
	for id in state.data.pending.candidates:
		if state.data.pending.selected.size() >= state.data.pending.picks: break
		if id not in state.data.pending.selected: state.select_card(id)
	expect(state.claim_reward() and state.data.current == "S02", "read fixture advances into the Emma story")
	expect(state.save_story_checkpoint("S02", "s02_02"), "read fixture stores a stable story checkpoint")
	var story_snapshot: Dictionary = state.data.duplicate(true)
	expect(state.save_slot("3"), "manual slot stores the story checkpoint")
	return {"pending":pending_snapshot, "story":story_snapshot}

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "test campaign data is isolated")
	if failures: quit(1); return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	shell = SHELL.instantiate()
	shell.session.directory = "user://home_menu_empty_" + str(Time.get_ticks_usec())
	shell.quit_callback = func(): quit_calls += 1
	shell.quit_confirmed.connect(func(): quit_signals += 1)
	viewport.add_child(shell)
	await frames(12)
	expect(shell.page == "home", "fresh install opens the title page")
	expect(button("new_campaign") != null and not button("new_campaign").disabled, "fresh title can start a new campaign")
	expect(button("continue_campaign") == null, "continue is absent without a valid automatic save")
	expect(button("home_load") != null and button("home_load").disabled, "load is disabled without a readable save")
	var initial_ids := ["new_campaign", "home_load", "music_room", "home_codex", "inspect_world", "home_settings", "home_help", "home_about", "home_quit"]
	for dimensions in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		viewport.size = dimensions
		await frames(14)
		fit_home(initial_ids, dimensions)
		await keyboard_home_grid()
		await capture("home-empty-%d" % dimensions.x)
	var text_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MENU_TEXT.PATH))
	expect(text_data is Dictionary and not MENU_TEXT.text("home", "title").strip_edges().is_empty() and not MENU_TEXT.text("help", "intro").strip_edges().is_empty() and not MENU_TEXT.text("about", "intro").strip_edges().is_empty() and not MENU_TEXT.text("exit", "confirm").strip_edges().is_empty(), "title/help/about/exit copy resolves from current menu text")
	expect(shell.find_child("home_no_saves", true, false) != null, "empty install explains that there are no readable saves")
	var initial_state: RefCounted = shell.session
	var initial_snapshot := snapshot()
	var cue: String = shell.bgm.current_cue
	var music_context: String = shell.bgm.context_id
	for entry in [["home_settings", "settings"], ["home_help", "help"], ["home_about", "about"], ["music_room", "music"]]:
		await utility_round_trip(str(entry[0]), str(entry[1]), cue, initial_snapshot)
		expect(shell.bgm.context_id == music_context, "title browsing preserves BGM context through " + str(entry[1]))
	await click("home_about")
	var license := button("about_license_0")
	expect(license != null, "about page exposes expandable license text")
	if license != null:
		license.button_pressed = true
		await frames()
		expect((shell.find_child("about_license_body_0", true, false) as Control).visible, "about license expands on activation")
		await key(KEY_ESCAPE)
		expect(shell.page == "home" and snapshot().files == initial_snapshot.files, "expanded license returns without writes")
	var codex_opener := button("home_codex")
	if codex_opener != null: codex_opener.grab_focus()
	await click("home_codex")
	expect(shell.enemy_codex != null and shell.enemy_codex.stage_id.is_empty(), "title codex opens the complete read-only enemy catalog")
	await capture("title-codex")
	await key(KEY_ESCAPE)
	expect(shell.page == "home" and shell.enemy_codex == null and viewport.gui_get_focus_owner() == button("home_codex"), "title codex closes once and restores opener focus")
	expect(snapshot().files == initial_snapshot.files and shell.session.data == initial_snapshot.data, "codex browsing preserves empty campaign and save bytes")
	var world_opener := button("inspect_world")
	if world_opener != null: world_opener.grab_focus()
	await click("inspect_world")
	expect(shell.page == "world" and not shell.session.data.started, "world inspection opens without creating a campaign")
	await key(KEY_ESCAPE)
	expect(shell.page == "home" and snapshot().files == initial_snapshot.files and shell.session.data == initial_snapshot.data, "unstarted world inspection writes no empty session")
	button("home_quit").grab_focus()
	await key(KEY_ESCAPE)
	expect(shell.modal != null and shell.modal.name == "QuitConfirmation", "title Escape opens the named exit confirmation")
	expect(viewport.gui_get_focus_owner() == button("modal_cancel"), "exit confirmation defaults keyboard focus to cancel")
	expect(Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(button("modal_cancel").get_global_rect()), "exit controls fit the rendered viewport")
	for direction in [KEY_RIGHT, KEY_DOWN, KEY_LEFT, KEY_UP]:
		await key(direction)
		var focused := viewport.gui_get_focus_owner()
		expect(shell.modal != null and shell.modal.is_ancestor_of(focused) and focused in [button("modal_cancel"), button("modal_confirm")], "exit confirmation arrow focus stays inside its controls")
	await key(KEY_TAB)
	var modal_tab_focus := viewport.gui_get_focus_owner()
	expect(shell.modal != null and shell.modal.is_ancestor_of(modal_tab_focus) and modal_tab_focus in [button("modal_cancel"), button("modal_confirm")], "exit confirmation Tab focus stays inside its controls")
	await capture("title-quit-confirmation")
	await key(KEY_ESCAPE)
	expect(shell.page == "home" and shell.modal == null and viewport.gui_get_focus_owner() == button("home_quit"), "canceling exit stays on title and restores its opener")
	expect(quit_calls == 0 and quit_signals == 0 and snapshot().files == initial_snapshot.files, "canceling exit neither quits nor writes campaign")
	await click("home_quit")
	await click("modal_confirm")
	expect(quit_calls == 1 and quit_signals == 1 and shell.page == "home", "confirmed exit emits request and injected callback without ending the test tree")
	expect(snapshot().files == initial_snapshot.files, "confirmed exit request does not write campaign saves")
	await click("new_campaign")
	expect(not initial_state.data.started and initial_state.read_slot("auto").is_empty(), "new campaign waits for explicit confirmation")
	expect(viewport.gui_get_focus_owner() == button("modal_confirm"), "new campaign keeps its established confirm-first default")
	await click("modal_confirm")
	expect(initial_state.data.started and not initial_state.read_slot("auto").is_empty(), "confirmed new campaign creates a valid automatic save")
	shell.open_page("home")
	await frames(12)
	var auto_ids := ["continue_campaign", "new_campaign", "home_load", "music_room", "home_codex", "inspect_world", "home_settings", "home_help", "home_about", "home_quit"]
	for dimensions in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		viewport.size = dimensions
		await frames(12)
		fit_home(auto_ids, dimensions)
		await keyboard_home_grid()

	# Build a genuine partial reward and story checkpoint in manual slots. Remove
	# the auto generation to test a manual-only title independently.
	var saved_state: RefCounted = await install_state("manual")
	var saved := make_pending_and_story_slots(saved_state)
	expect(not saved.is_empty(), "manual-only fixtures are valid")
	var directory := ProjectSettings.globalize_path(saved_state.directory)
	for slot in ["auto.json", "auto.json.bak"]:
		var path: String = directory.path_join(slot)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	var corrupt_auto := FileAccess.open(saved_state.directory.path_join("auto.json"), FileAccess.WRITE)
	corrupt_auto.store_string("{}")
	corrupt_auto.close()
	var corrupt := FileAccess.open(saved_state.directory.path_join("2.json"), FileAccess.WRITE)
	corrupt.store_string("{}")
	corrupt.close()
	saved_state.reset(false)
	shell.open_page("home")
	await frames(12)
	expect(button("continue_campaign") == null, "manual-only and corrupt-autosave title omits Continue")
	expect(button("home_load") != null and not button("home_load").disabled, "one valid manual slot enables Load")
	expect(saved_state.read_slot("auto").is_empty() and saved_state.read_slot("2").is_empty(), "corrupt automatic and manual slots remain unreadable")
	var manual_ids := ["new_campaign", "home_load", "music_room", "home_codex", "inspect_world", "home_settings", "home_help", "home_about", "home_quit"]
	for dimensions in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		viewport.size = dimensions
		await frames(12)
		fit_home(manual_ids, dimensions)
		await keyboard_home_grid()
	var before_manual_browse := snapshot()
	await click("home_load")
	expect(shell.page == "saves" and shell.saves_read_only(), "title load opens read-only saves")
	expect(button("save_1") == null and button("save_2") == null and button("save_3") == null, "title save list has no write controls")
	expect(button("load_1") != null and not button("load_1").disabled and button("load_2").disabled and button("load_3") != null and not button("load_3").disabled, "valid manual slots remain distinct from corrupt and empty slots")
	await key(KEY_ESCAPE)
	expect(shell.page == "home" and viewport.gui_get_focus_owner() == button("home_load"), "read-only title save list returns focus")
	expect(snapshot() == before_manual_browse, "listing manual saves changes no campaign or file bytes")

	# Home utility navigation must restore the source cue even after the full
	# auto/manual state becomes readable.
	var cue_with_manual: String = shell.bgm.current_cue
	var saved_nav := snapshot()
	for entry in [["home_settings", "settings"], ["home_help", "help"], ["home_about", "about"], ["music_room", "music"]]:
		await utility_round_trip(str(entry[0]), str(entry[1]), cue_with_manual, saved_nav)
	var pending_expected: Dictionary = saved.pending.pending
	await click("home_load")
	await click("load_1")
	await click("modal_confirm")
	expect(shell.page == "reward" and shell.session.data.pending == pending_expected, "manual load restores exact candidates and partial selection")
	await shell.open_page("home")
	await frames()
	expect(button("continue_campaign") != null and not button("continue_campaign").disabled, "valid automatic progress exposes Continue")
	await click("home_load")
	expect(shell.saves_read_only(), "title load remains read-only after a manual load")
	await click("load_3")
	await click("modal_confirm")
	expect(shell.page == "event" and shell.session.data.story_checkpoint == {"event":"S02", "line":"s02_02"}, "manual load restores the exact story checkpoint")
	await frames(4)
	expect(shell.story_view != null and shell.story_view.current_line_id == "s02_02", "story reader resumes at the stored line")
	await shell.open_page("home")
	await frames()
	await click("continue_campaign")
	await frames(12)
	expect(shell.page == "event" and shell.story_view.current_line_id == "s02_02", "Continue restores the automatic story checkpoint")

	shell.queue_free()
	await frames()
	viewport.queue_free()
	await frames(2)
	print("CHRONICLE_HOME_MENU_RENDER_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
