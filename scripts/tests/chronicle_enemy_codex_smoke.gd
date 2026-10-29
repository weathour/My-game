extends SceneTree
## Real input over a live shell; inspection never owns campaign or save mutations.
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
const CODEX := preload("res://scripts/ui/chronicle/enemy_codex.gd")
const CATALOG := preload("res://scripts/content/enemy_catalog.gd")
var viewport: SubViewport
var shell: Control
var codex: Control
var checks := 0
var failures := 0
var captures := "docs/design-reviews/evidence/2026-10-29/ui-simplification/codex/screens"

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): captures = arg.trim_prefix("--capture=")
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func frames(count: int = 4) -> void:
	for i in count: await process_frame

func capture(label: String) -> void:
	await frames()
	if DisplayServer.get_name() == "headless" or captures.is_empty(): return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(captures)
	viewport.get_texture().get_image().save_png(captures.path_join(label + ".png"))

func press(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code;event.physical_keycode = code;event.pressed = true
	viewport.push_input(event)
	await frames(1)
	event = InputEventKey.new();event.keycode = code;event.physical_keycode = code;event.pressed = false
	viewport.push_input(event)
	await frames(1)

func click(name: String) -> void:
	var button := codex.find_child(name, true, false) as BaseButton
	expect(button != null and button.is_visible_in_tree() and not button.disabled, "available " + name)
	if button == null or button.disabled: return
	var point: Vector2 = button.get_global_rect().get_center()
	var move := InputEventMouseMotion.new();move.position = point;move.global_position = point;viewport.push_input(move)
	for down in [true,false]:
		var event := InputEventMouseButton.new();event.button_index = MOUSE_BUTTON_LEFT;event.pressed = down;event.position = point;event.global_position = point
		viewport.push_input(event)
		await frames(1)
	await frames()

func snapshot() -> Dictionary:
	var state: RefCounted = shell.session
	var files := {}
	if DirAccess.dir_exists_absolute(state.directory):
		for filename in DirAccess.get_files_at(state.directory):
			var path: String = state.directory.path_join(filename)
			files[filename] = FileAccess.get_file_as_bytes(path)
	return {"data":state.data.duplicate(true),"rng":state.reward_rng.state,"files":files,"attempt":state.active_attempt,"in_battle":state.in_battle}

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated campaign storage")
	if failures: quit(1);return
	viewport = SubViewport.new();viewport.size = Vector2i(1280,720);viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	shell = SHELL.instantiate();viewport.add_child(shell);await frames()
	shell.page = "route";shell.selected_node = "B17";shell.render();await frames()
	var before := snapshot()
	var route_selection: String = shell.selected_node
	var route_offset: float = shell.route_scroll
	var route_button := shell.find_child("route_enemy_codex",true,false) as Button
	expect(route_button != null,"route enemy inspection entry")
	if route_button == null: quit(1);return
	route_button.grab_focus();route_button.pressed.emit();await frames()
	codex = shell.get_node_or_null("EnemyCodex")
	expect(codex != null,"real shell opens illustrated codex")
	if codex == null: quit(1);return
	expect(codex.stage_only,"stage scope remains the default")
	expect(codex.mode_key == "portrait" and codex.portrait.visible and codex.preview == null,"default displays one large standing illustration")
	expect(codex.find_child("enemy_combat_details",true,false) == null,"combat detail hidden by default")
	codex.show_entry("B18");await frames()
	var selected := codex.find_child("enemy_codex_B18",true,false) as Button
	expect(codex.index_scroll.get_global_rect().encloses(selected.get_global_rect()), "external selection reveals selected index entry")
	await click("enemy_codex_B17")
	expect(codex.selected_id == "B17" and viewport.gui_get_focus_owner().name == "enemy_codex_B17", "real index click preserves selected entry focus")
	await press(KEY_TAB)
	expect(viewport.gui_get_focus_owner().name != "enemy_codex_B17" and codex.is_ancestor_of(viewport.gui_get_focus_owner()), "Tab continues from clicked index entry")
	codex.show_entry("B18");await frames()
	await capture("portrait-1280-b18")
	var categories := {}
	for id in CODEX.all_ids():
		var key: String = CODEX.category_for(CATALOG.definition(id))
		categories[key] = int(categories.get(key,0)) + 1
	expect(categories == {"ordinary":12,"elite":7,"boss":18,"other":6},"four categories partition every catalog record exactly once")
	for id in CODEX.all_ids():
		codex.show_entry(id)
		expect(codex.selected_id == id and codex.portrait.texture != null,"standing illustration accessible " + id)
		for button in codex.roster.get_children(): expect(not button.text.begins_with(str(id) + "  "),"program IDs stay out of index labels")
	codex.show_entry("B18");await frames()
	await click("codex_mode_moves")
	expect(viewport.gui_get_focus_owner().name == "codex_mode_moves", "real moves click restores the replacement mode button focus")
	await press(KEY_TAB)
	expect(viewport.gui_get_focus_owner().name == "enemy_preview_clip", "Tab follows moves tab into animation control")
	expect(not codex.portrait.visible and codex.animation_stage.visible and codex.preview != null,"moves replace the standing art in the same main region")
	expect("slam" in codex.preview_clips,"extra boss clip remains selectable")
	var slam_index: int = codex.preview_clips.find("slam")
	codex.clip_choice.select(slam_index)
	codex.clip_choice.item_selected.emit(slam_index)
	await frames(8)
	expect(codex.selected_clip == "slam" and codex.clip_choice.get_item_text(codex.clip_choice.selected) == "重击" and codex.preview.clip_name == "slam", "actual selector label and displayed extra action agree")
	await click("enemy_preview_pause")
	var current_frame: int = codex.preview.sprite.frame
	await frames(10)
	expect(codex.animation_paused and codex.preview.sprite.frame == current_frame,"pause keeps the exact animation frame")
	await capture("moves-1280-b18")
	await click("enemy_preview_pause")
	await click("enemy_combat_toggle")
	expect(codex.find_child("enemy_combat_details",true,false) != null,"combat advice opens on request")
	for label in codex.detail.find_children("*","Label",true,false):
		expect(not "受击半径" in label.text and not "身高" in label.text and not "预告 0." in label.text and not "回气 0." in label.text,"engineering values stay out of player-facing combat text")
	for i in 24:
		await press(KEY_TAB)
		var focus := viewport.gui_get_focus_owner()
		expect(focus != null and codex.is_ancestor_of(focus),"Tab remains inside modal")
	for key in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]: await press(key)
	expect(shell.selected_node == route_selection and is_equal_approx(shell.route_scroll,route_offset),"keyboard does not inspect or pan underlying route")
	var wheel := InputEventMouseButton.new();wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed = true;wheel.position = Vector2(110,410);wheel.global_position = wheel.position
	viewport.push_input(wheel);await frames()
	expect(shell.selected_node == route_selection and is_equal_approx(shell.route_scroll,route_offset),"wheel belongs to the modal index")
	codex.combat_open = false;codex.set_mode("portrait")
	for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		viewport.size = dimensions;codex.show_entry("B18");await frames(6)
		expect(codex.size == Vector2(dimensions),"modal follows viewport " + str(dimensions))
		expect(codex.portrait.size.y > dimensions.y * .6,"standing illustration has visual priority " + str(dimensions))
		expect(codex.get_global_rect().encloses(codex.portrait.get_global_rect()),"portrait region fits viewport " + str(dimensions))
		await capture("portrait-%d-b18" % dimensions.x)
		codex.show_entry("B16");await frames();await capture("portrait-%d-b16" % dimensions.x)
		codex.set_mode("moves");await frames()
		var bounds: Rect2 = codex._preview_bounds("B16")
		expect(Rect2(Vector2.ZERO,codex.animation_stage.size).encloses(codex.preview.transform * bounds),"full animation union fits " + str(dimensions))
		await capture("moves-%d-b16" % dimensions.x)
		codex.set_mode("portrait")
	expect(snapshot() == before,"all browsing, modes, animation controls and resize leave campaign/RNG/files unchanged")
	var page_before: String = shell.page
	await press(KEY_ESCAPE);await frames()
	expect(shell.get_node_or_null("EnemyCodex") == null and shell.page == page_before,"one Escape closes only the codex")
	expect(viewport.gui_get_focus_owner() == shell.find_child("route_enemy_codex",true,false),"opener focus restores through the shell")
	expect(snapshot() == before,"close does not save or advance")
	shell.queue_free();viewport.queue_free();await frames()
	print("CHRONICLE_ENEMY_CODEX_SMOKE ","PASS" if failures == 0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
