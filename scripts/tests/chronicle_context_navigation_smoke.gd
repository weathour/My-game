extends SceneTree
## Context navigation preserves expedition state, preparation origin and reward blocking.
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")

var checks := 0
var failures := 0
var viewport: SubViewport
var shell: Control
var capture_dir := ""

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

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	viewport.push_input(event)
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event)
	await frames()

func pointer_click(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	viewport.push_input(event)
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event)
	await frames()

func snapshot() -> Dictionary:
	var state: RefCounted = shell.session
	var files := {}
	for filename in DirAccess.get_files_at(state.directory):
		var path: String = state.directory.path_join(filename)
		files[filename] = {"bytes":FileAccess.get_file_as_bytes(path), "mtime":FileAccess.get_modified_time(path)}
	return {"data":state.data.duplicate(true), "rng":state.reward_rng.state, "files":files,
		"entry":state.entry_snapshot.duplicate(true), "attempt":state.active_attempt, "battle":state.in_battle}

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await frames()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var bitmap := viewport.get_texture().get_image()
	expect(bitmap.get_size() == viewport.size, "exact render dimensions " + name)
	bitmap.save_png(capture_dir.path_join(name + ".png"))

func fits(ids: Array, dimensions: Vector2i) -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
	for id in ids:
		var control := shell.find_child(id, true, false) as Control
		expect(control != null and control.is_visible_in_tree() and bounds.encloses(control.get_global_rect()), "control fits " + id + " " + str(dimensions))

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated navigation saves")
	if failures: quit(1); return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	shell = SHELL.instantiate()
	shell.session.directory = "user://context_navigation_" + str(Time.get_ticks_usec())
	viewport.add_child(shell)
	await frames(12)
	var state: RefCounted = shell.session
	state.reset(false)
	state.data.started = true
	state.data.current = "B04"
	state.data.available = ["B04", "B05"]
	state.data.completed = ["S01", "B01", "S02", "B02", "S03"]
	for id in ["F11", "F03", "N16", "N17"]:
		state.data.owned[id] = state.new_character(id)
		if id not in state.data.pool: state.data.pool.append(id)
	state.data.party = ["F11", "N16"]
	state.data.owned.JIA.hp = 17.0
	state.data.owned.JIA.mp = 2.0
	expect(state.valid(state.data) and state.save_slot("auto") and state.save_slot("1"), "persist valid navigation boundary")
	shell.resume_view()
	await frames()
	var baseline := snapshot()
	for dimensions in [Vector2i(1280,720), Vector2i(960,540), Vector2i(1920,1080)]:
		viewport.size = dimensions
		await frames(14)
		fits(["nav_world", "nav_party", "nav_settings", "route_current", "route_forward", "CampaignRouteMap"], dimensions)
		var route_paper := shell.find_child("campaign_detail_paper", true, false) as Control
		var lower_frontier := shell.find_child("node_B05", true, false) as Control
		expect(not route_paper.get_global_rect().intersects(lower_frontier.get_global_rect()), "visible lower frontier stays beyond paper when resizing from another viewport")
		expect(shell.find_child("route_overview", true, false) == null and shell.find_child("footer_party", true, false) == null, "map has one navigation layer")
		await capture("01-route-" + str(dimensions.x))
		var route_member := shell.find_child("campaign_member_0", true, false) as Button
		route_member.grab_focus()
		var route_frame_id: int = shell.frame.get_instance_id()
		await click("campaign_member_0")
		expect(shell.page == "route" and is_instance_valid(shell.character_sheet) and shell.frame.get_instance_id() == route_frame_id, "route inspection preserves the actual map instead of navigating away")
		expect((shell.character_sheet.find_child("character_back", true, false) as Button).text == "返回行军", "character overlay identifies its route context")
		await capture("01b-route-character-" + str(dimensions.x))
		await key(KEY_TAB)
		expect(shell.character_sheet.is_ancestor_of(viewport.gui_get_focus_owner()), "character overlay traps Tab focus")
		await key(KEY_ESCAPE)
		expect(shell.page == "route" and not is_instance_valid(shell.character_sheet) and snapshot() == baseline, "Escape closes character inspection once without mutations")
		expect(viewport.gui_get_focus_owner() == route_member, "character overlay restores the original route card focus")
		await click("nav_world")
		await click("province_徐州")
		expect(not shell.world_tasks_open and shell.find_child("world_tasks_close", true, false) == null, "world opens as map without a permanent task list")
		fits(["world_tasks", "world_campaign_card", "world_enter"], dimensions)
		var xuzhou := shell.find_child("province_徐州", true, false) as Button
		var jingzhou := shell.find_child("province_荆州", true, false) as Button
		var yangzhou := shell.find_child("province_扬州", true, false) as Button
		var campaign_card := shell.find_child("world_campaign_card", true, false) as Button
		expect(xuzhou.position.distance_to(jingzhou.position) > 70, "province controls use their local geographic positions")
		expect(not campaign_card.get_global_rect().intersects(yangzhou.get_global_rect()) and not campaign_card.get_global_rect().intersects(xuzhou.get_global_rect()), "campaign card leaves adjacent province controls usable")
		await capture("02-world-" + str(dimensions.x))
		await click("world_tasks")
		fits(["world_tasks_close", "world_task_baimen"], dimensions)
		await capture("02b-world-tasks-" + str(dimensions.x))
		await click("world_tasks_close")
		var world_member := shell.find_child("campaign_member_1", true, false) as Button
		world_member.grab_focus()
		await click("campaign_member_1")
		expect(shell.page == "world" and is_instance_valid(shell.character_sheet) and (shell.character_sheet.find_child("character_back", true, false) as Button).text == "返回天下", "world status card inspects in place")
		await click("character_back")
		expect(not is_instance_valid(shell.character_sheet) and not shell.world_tasks_open and snapshot() == baseline and viewport.gui_get_focus_owner() == world_member, "character inspection closes to the unchanged world and its opener")
		await click("province_荆州")
		fits(["world_resume", "nav_party", "nav_settings"], dimensions)
		expect(shell.find_child("world_locked", true, false) == null, "unmade province has one informational message")
		await capture("02c-world-other-" + str(dimensions.x))
		await click("world_resume")
		expect(shell.page == "route" and snapshot() == baseline, "world inspection and return preserve full expedition/resources/files")
		await click("nav_party")
		fits(["party_tab_roster", "party_tab_equipment", "page_back"], dimensions)
		expect(shell.find_child("nav_world", true, false) == null, "management page owns title and return")
		await capture("03-party-" + str(dimensions.x))
		await click("party_tab_equipment")
		fits(["party_tab_roster", "party_tab_equipment", "page_back"], dimensions)
		await capture("04-equipment-" + str(dimensions.x))
		await key(KEY_ESCAPE)
		expect(shell.page == "route" and snapshot() == baseline, "gear Escape returns to real route origin without state changes")
	# Resizing the page beneath an open sheet keeps the same character and tab,
	# then restores focus to the rebuilt source control on close.
	(shell.find_child("campaign_member_0", true, false) as Button).grab_focus()
	shell.inspect_character("JIA", "growth")
	await frames()
	viewport.size = Vector2i(960,540)
	await frames(14)
	expect(is_instance_valid(shell.character_sheet) and shell.character_sheet.character_id == "JIA" and shell.character_sheet.active_tab == "growth", "resize keeps character identity and growth tab open")
	expect(shell.character_sheet.is_ancestor_of(viewport.gui_get_focus_owner()), "resize keeps keyboard focus in character inspection")
	await pointer_click(Vector2(24, 520))
	expect(shell.page == "route" and is_instance_valid(shell.character_sheet) and snapshot() == baseline, "sheet backdrop blocks the underlying menu click")
	await key(KEY_TAB)
	expect(shell.character_sheet.is_ancestor_of(viewport.gui_get_focus_owner()), "Tab after character resize remains in the sheet")
	await key(KEY_ESCAPE)
	expect(shell.page == "route" and not is_instance_valid(shell.character_sheet) and viewport.gui_get_focus_owner() == shell.find_child("campaign_member_0", true, false), "closing resized character sheet restores the rebuilt opener")
	expect(snapshot() == baseline, "character tabs, reflow and backdrop never write campaign or random state")
	viewport.size = Vector2i(1280,720)
	await frames(14)
	await click("nav_world")
	await click("nav_party")
	await click("party_tab_equipment")
	await click("party_tab_roster")
	await click("page_back")
	expect(shell.page == "world", "party and gear preserve world origin across repeated switching")
	await click("world_resume")
	await click("route_forward")
	expect(shell.page == "preparation", "explicit forward alone enters preparation")
	baseline = snapshot()
	await click("party_tab_equipment")
	await capture("05-preparation-equipment-1280")
	await click("party_tab_roster")
	expect(shell.page == "preparation" and shell.find_child("prep_start", true, false) != null, "gear tab returns to battle preparation and retains start action")
	await capture("06-preparation-1280")
	await click("page_back")
	expect(shell.page == "route" and snapshot() == baseline, "preparation and gear inspection leave entry state unchanged")
	await click("nav_settings")
	for target in ["saves", "journal", "settings"]:
		await click("menu_" + target)
		await key(KEY_ESCAPE)
		expect(shell.page == "menu", "management Escape returns through original menu " + target)
	await click("menu_music")
	await key(KEY_ESCAPE)
	expect(shell.page == "menu" and shell.music_preview == null, "music closes to its menu source")
	var opener := shell.find_child("menu_codex", true, false) as Button
	opener.grab_focus()
	await click("menu_codex")
	expect(is_instance_valid(shell.enemy_codex) and shell.enemy_codex.stage_id.is_empty(), "menu opens complete read-only codex")
	await key(KEY_ESCAPE)
	expect(shell.page == "menu" and not is_instance_valid(shell.enemy_codex) and viewport.gui_get_focus_owner() == opener, "codex Escape closes once and restores menu focus")
	await click("menu_codex")
	viewport.size = Vector2i(960,540)
	await frames(14)
	var codex_focus := viewport.gui_get_focus_owner()
	expect(is_instance_valid(codex_focus) and shell.enemy_codex.is_ancestor_of(codex_focus), "menu resize keeps focus inside codex")
	await key(KEY_TAB)
	expect(shell.enemy_codex.is_ancestor_of(viewport.gui_get_focus_owner()), "Tab after resize remains in codex")
	await key(KEY_ESCAPE)
	var rebuilt_menu_opener := shell.find_child("menu_codex", true, false) as Button
	expect(shell.page == "menu" and not is_instance_valid(shell.enemy_codex) and viewport.gui_get_focus_owner() == rebuilt_menu_opener, "resize and Escape restore rebuilt menu entry without leaving menu")
	await capture("08-menu-after-codex-resize-960")
	await click("menu_resume")
	expect(shell.page == "route" and snapshot() == baseline, "all information pages preserve campaign and RNG/files")
	(shell.find_child("route_enemy_codex", true, false) as Button).grab_focus()
	await click("route_enemy_codex")
	expect(is_instance_valid(shell.enemy_codex) and shell.enemy_codex.stage_id == "B04", "battle node opens its stage codex")
	viewport.size = Vector2i(1280,720)
	await frames(14)
	expect(shell.enemy_codex.is_ancestor_of(viewport.gui_get_focus_owner()), "route resize keeps focus inside codex")
	await key(KEY_ESCAPE)
	var rebuilt_route_opener := shell.find_child("route_enemy_codex", true, false) as Button
	expect(shell.page == "route" and not is_instance_valid(shell.enemy_codex) and viewport.gui_get_focus_owner() == rebuilt_route_opener, "stage codex Escape restores rebuilt route entry and stays on route")
	expect(snapshot() == baseline, "codex resizing and focus restoration preserve campaign, RNG and files")
	await capture("09-route-after-codex-resize-1280")
	shell.selected_node = "S02"
	shell.render()
	await frames()
	expect(shell.find_child("route_enemy_codex", true, false) == null and shell.find_child("route_replay", true, false) != null, "story node offers replay without a battle enemy entry")
	expect(not (shell.find_child("route_node_summary", true, false) as Label).text.is_empty(), "empty map summary falls back to authored story summary")
	await capture("10-completed-story-detail-1280")
	expect(state.make_reward("B04", false) and state.select_card(state.data.pending.candidates[0]), "persist partially selected reward")
	shell.render()
	await frames()
	baseline = snapshot()
	expect(shell.find_child("route_reward", true, false) != null and shell.find_child("route_replay", true, false) == null and shell.find_child("route_forward", true, false) == null, "pending reward overrides replay and forward with one completion action")
	fits(["nav_world", "route_current", "nav_party", "nav_settings", "route_reward"], viewport.size)
	await capture("07-pending-reward-route-1280")
	await click("route_reward")
	expect(shell.page == "reward" and state.data.pending.selected.size() == 1 and snapshot() == baseline, "reward remains reachable with same candidates/partial selection")
	shell.open_page("route")
	await frames()
	await click("nav_world")
	await click("province_徐州")
	expect((shell.find_child("world_campaign_card", true, false) as Button).text.contains("待完成选卡"), "world card labels an unsettled reward rather than offering a walkable frontier")
	for dimensions in [Vector2i(960,540), Vector2i(1280,720)]:
		viewport.size = dimensions
		await frames(14)
		fits(["world_detail_scroll", "world_enter", "nav_settings"], dimensions)
		var paper := shell.find_child("campaign_detail_paper", true, false) as Control
		var menu := shell.find_child("nav_settings", true, false) as Control
		expect(paper.get_global_rect().end.y < menu.get_global_rect().position.y, "pending world information remains inside paper above corner menu")
		await capture("11-world-pending-" + str(dimensions.x))
	await click("world_enter")
	expect(shell.page == "reward" and snapshot() == baseline, "world completion action returns to the same partial reward transaction")
	shell.queue_free()
	await frames()
	viewport.queue_free()
	await frames()
	print("CHRONICLE_CONTEXT_NAVIGATION_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
