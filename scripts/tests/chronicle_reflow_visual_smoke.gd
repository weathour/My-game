extends SceneTree
## Layout fixture only; later chapter ownership/rewards are not gameplay progress.
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
const SESSION := preload("res://scripts/ui/chronicle/chronicle_session.gd")
var viewport: SubViewport
var shell: Control
var failures := 0
var capture_dir := ""

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
	call_deferred("run")

func frames(count: int = 8) -> void:
	for i in count: await process_frame

func expect(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)

func fits(id: String) -> void:
	var target := shell.find_child(id, true, false) as Control
	expect(target != null and Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(target.get_global_rect()), "visible within viewport: " + id)

func capture(name: String) -> void:
	await frames()
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	viewport.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))
	print("CAPTURE ", name, " ", viewport.size)

func click(id: String) -> void:
	var button := shell.find_child(id, true, false) as Button
	expect(button != null and button.is_visible_in_tree() and not button.disabled, "usable " + id)
	if button != null and not button.disabled: button.grab_focus(); button.pressed.emit()
	await frames()

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated test storage")
	if failures: quit(1); return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	shell = SHELL.instantiate()
	shell.session = SESSION.new()
	shell.session.directory = "user://reflow_layout/" + str(Time.get_ticks_usec())
	viewport.add_child(shell)
	await frames()
	var state: RefCounted = shell.session
	state.begin_campaign()
	state.data.current = "B02"
	state.data.available = ["B02"]
	state.data.completed = ["S01", "B01", "S02"]
	state.data.pool = state.characters.keys()
	for id in state.characters: state.data.owned[id] = state.new_character(id)
	state.data.party = ["F11", "M02"]
	state.data.inventory = []
	for item in state.EQUIPMENT: state.data.inventory.append(item.id)
	shell.selected_node = "B02"
	shell.selected_character = "M02"
	shell.roster_filter = "all"
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]:
		viewport.size = dimensions
		await frames()
		for screen in ["world", "route", "roster", "preparation", "equipment", "settings"]:
			shell.open_page(screen)
			await capture("%s-%d" % [screen, dimensions.x])
			if screen == "preparation": fits("prep_start"); fits("prep_gear_accessory")
			if screen == "route": fits("route_forward")
		shell.open_page("roster")
		if dimensions.x == 960:
			await click("character_M02")
			expect(shell.page == "character", "compact details open")
			await capture("character-960")
			fits("character_back"); fits("assign_0")
			await click("character_stats")
			await capture("attributes-960")
			fits("modal_confirm")
			await click("modal_confirm")
		shell.open_page("route")
		shell.open_menu()
		await capture("menu-%d" % dimensions.x)
		await click("menu_resume")
		expect(shell.page == "route", "menu resumes the prior page")
		for count in [5, 7]:
			var ids := ["F11", "M02", "N13", "F01", "M03", "M01", "F04"]
			ids.resize(count)
			state.data.pending = {"node":"B18" if count == 7 else "B02", "candidates":ids, "picks":3 if count == 7 else 2, "selected":[], "extra":false}
			shell.open_page("reward")
			await frames()
			for id in ids: fits("reward_card_" + id)
			fits("reward_claim")
			await click("reward_card_M02")
			expect(state.data.pending.selected == ["M02"], "whole card selects")
			shell.find_child("reward_card_M03", true, false).grab_focus()
			await frames()
			expect(shell.reward_focus == "M03", "keyboard focus updates detail")
			await capture("reward-%d-%d" % [count,dimensions.x])
			if dimensions.x == 960 and count == 7:
				await click("reward_details")
				fits("modal_confirm")
				await capture("reward-details-960")
				await click("modal_confirm")
			state.data.pending = {}
	shell.queue_free()
	await frames()
	print("CHRONICLE_REFLOW_VISUAL_SMOKE PASS" if failures == 0 else "CHRONICLE_REFLOW_VISUAL_SMOKE FAIL %d" % failures)
	quit(0 if failures == 0 else 1)
