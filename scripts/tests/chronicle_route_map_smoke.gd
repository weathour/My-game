extends SceneTree
## Real pointer/keyboard navigation over the production route, including read-only save checks.
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
const MAP := preload("res://scripts/ui/chronicle/chronicle_route_map.gd")

class GuardedCampaign extends "res://scripts/campaign/campaign_service.gd":
	var guarded := false
	var forbidden: Array[String] = []
	var choose_calls := 0

	func choose_node(id: String) -> bool:
		choose_calls += 1
		if guarded: forbidden.append("choose_node"); return false
		return super.choose_node(id)

	func save_slot(slot: String) -> bool:
		if guarded: forbidden.append("save_slot"); return false
		return super.save_slot(slot)

	func resolve_event() -> bool:
		if guarded: forbidden.append("resolve_event"); return false
		return super.resolve_event()

	func save_story_checkpoint(event_id: String, line_id: String) -> bool:
		if guarded: forbidden.append("save_story_checkpoint"); return false
		return super.save_story_checkpoint(event_id, line_id)

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

func frames(count: int = 6) -> void:
	for i in count: await process_frame

func click(id: String) -> void:
	var button := shell.find_child(id, true, false) as Button
	expect(button != null and button.is_visible_in_tree() and not button.disabled, "usable " + id)
	if button != null and not button.disabled: button.pressed.emit()
	await frames()

func move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	viewport.push_input(event)
	await frames(2)

func mouse(at: Vector2, pressed: bool, button: int = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = button
	event.pressed = pressed
	viewport.push_input(event)
	await frames(2)

func point_click(at: Vector2) -> void:
	await move(at)
	await mouse(at, true)
	await mouse(at, false)
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

func marker_center(id: String) -> Vector2:
	return (shell.find_child("node_" + id, true, false) as Control).get_global_rect().get_center()

func visible_marker(id: String) -> bool:
	var marker := shell.find_child("node_" + id, true, false) as Control
	return marker != null and shell.route_map.get_global_rect().encloses(marker.get_global_rect())

func snapshot() -> Dictionary:
	var files := {}
	for filename in DirAccess.get_files_at(state.directory):
		var path := state.directory.path_join(filename)
		files[filename] = {"bytes":FileAccess.get_file_as_bytes(path), "mtime":FileAccess.get_modified_time(path)}
	return {"data":state.data.duplicate(true), "rng":state.reward_rng.state, "files":files,
		"battle":state.in_battle, "entry":state.entry_snapshot.duplicate(true), "attempt":state.active_attempt}

func watch() -> void:
	state.forbidden.clear()
	state.guarded = true
	baseline = snapshot()
	baseline_changes = changed_count

func unchanged(label: String) -> void:
	expect(snapshot() == baseline, label + ": campaign/RNG/files unchanged")
	expect(state.forbidden.is_empty() and changed_count == baseline_changes, label + ": no campaign mutations or save calls")

func fixture(current: String, available: Array, completed: Array) -> void:
	state.guarded = false
	state.reset(false)
	state.data.started = true
	state.data.current = current
	state.data.available = available.duplicate()
	state.data.completed = completed.duplicate()
	state.data.owned.F11 = state.new_character("F11")
	state.data.pool.append("F11")
	state.data.log = ["地图边界夹具"]
	expect(state.valid(state.data), "valid boundary fixture " + current)
	expect(state.save_slot("auto") and state.save_slot("auto") and state.save_slot("1") and state.save_slot("1"), "persist auto/manual/backup boundary")
	shell.selected_node = current
	shell.segment = int(state.nodes[current].segment)
	shell.route_scroll = -1.0
	shell.open_page("route")
	await frames(14)
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
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated campaign saves")
	if failures: quit(1); return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	shell = SHELL.instantiate()
	state = GuardedCampaign.new()
	state.directory = "user://route_map_" + str(Time.get_ticks_usec())
	state.changed.connect(func(): changed_count += 1)
	shell.session = state
	viewport.add_child(shell)
	await frames(12)
	var unopened: Dictionary = state.data.duplicate(true)
	shell.open_page("route")
	shell.open_page("journal")
	await frames(10)
	expect(shell.page == "journal" and shell.route_map == null and shell.route_scroll < 0, "same-frame page exit cancels deferred map initialization")
	expect(state.data == unopened, "rapid route inspection leaves campaign unchanged")
	await fixture("B04", ["B04", "B05"], ["S01", "B01", "S02", "B02", "S03"])
	await topology_and_inspection()
	await gestures()
	await keyboard_and_modal()
	await layout_and_navigation()
	await progression_states()
	await explicit_forward()
	shell.queue_free()
	await frames()
	viewport.queue_free()
	await frames()
	print("CHRONICLE_ROUTE_MAP_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func topology_and_inspection() -> void:
	expect(shell.route_map.positions.size() == 36 and shell.route_map.markers.size() == 36, "continuous map contains every authored node")
	var icon_paths: Array[String] = []
	for kind in ["battle", "elite", "spring", "event", "boss"]:
		var icon: Texture2D = MAP.kind_icon(kind)
		expect(icon != null and icon.get_width() >= 32 and icon.resource_path not in icon_paths, "distinct reusable SVG icon " + kind)
		icon_paths.append(icon.resource_path)
	expect((shell.find_child("route_detail_icon", true, false) as TextureRect).texture == MAP.kind_icon("battle"), "detail matches inspected node icon")
	for id in state.nodes:
		for successor in state.nodes[id].next:
			expect(shell.route_map.positions[successor].x > shell.route_map.positions[id].x, "left-to-right topology " + id + " -> " + successor)
	expect(shell.route_map.positions.B04.x == shell.route_map.positions.B05.x and shell.route_map.positions.B04.y < shell.route_map.positions.B05.y, "fork has two distinct lanes before convergence")
	for entry in [["S03","completed"], ["B04","available"], ["B05","available"], ["B03","locked"], ["B07","locked"]]:
		expect(MAP.state_for(state, entry[0]) == entry[1], "correct route state " + entry[0])
	expect(visible_marker("B04") and visible_marker("B05"), "auto-location includes current fork")
	var alternative := shell.find_child("route_choice_B05", true, false) as Button
	await point_click(alternative.get_global_rect().get_center())
	expect(shell.selected_node == "B05" and state.data.current == "B04", "frontier candidate only inspects the alternate route")
	unchanged("frontier candidate inspection")
	await click("route_current")
	var map_rect: Rect2 = shell.route_map.get_global_rect()
	expect(absf(marker_center("B04").x - map_rect.position.x - map_rect.size.x * .36) < 3.0, "initial location uses allocated map viewport width")
	await capture("01-branching-1280")
	var title := (shell.find_child("route_node_title", true, false) as Label).text
	await move(marker_center("B05"))
	await create_timer(0.8).timeout
	var marker := shell.find_child("node_B05", true, false) as Button
	expect(marker.tooltip_text.contains("冥市暗巷") and marker.tooltip_text.contains("战斗") and marker.tooltip_text.contains("可前往"), "hover includes identity, type, status and summary")
	expect((shell.find_child("route_node_title", true, false) as Label).text == title and shell.selected_node == "B04", "hover does not replace clicked details")
	await capture("02-hover-1280")
	var offset: float = shell.route_scroll
	await point_click(marker_center("B05"))
	expect(shell.selected_node == "B05" and state.data.current == "B04", "real mouse click inspects alternate branch without advancing")
	expect((shell.find_child("route_node_title", true, false) as Label).text == "冥市暗巷" and (shell.find_child("route_node_status", true, false) as Label).text == "可前往", "right panel shows clicked title and actual state")
	expect(is_equal_approx(shell.route_scroll, offset), "selection rebuild retains pan position")
	unchanged("hover and click")

func gestures() -> void:
	var selected: String = shell.selected_node
	var at := marker_center("B05")
	var before: float = shell.route_scroll
	await move(at)
	await mouse(at, true)
	await move(at - Vector2(230, 0))
	await mouse(at - Vector2(230, 0), false)
	expect(shell.route_scroll > before + 200 and shell.selected_node == selected, "drag starting over node pans without clicking")
	expect(not shell.route_map._pointer_active, "drag releases normally")
	var map_rect: Rect2 = shell.route_map.get_global_rect()
	at = map_rect.position + Vector2(map_rect.size.x * .7, 65)
	await move(at)
	await mouse(at, true)
	await move(Vector2(-30, at.y))
	await mouse(Vector2(-30, at.y), false)
	expect(not shell.route_map._pointer_active and shell.selected_node == selected, "release outside map ends drag without selection")
	shell.route_map.focus_segment(0)
	await frames()
	var wheel_start: float = shell.route_scroll
	at = shell.route_map.get_global_rect().position + Vector2(180, 60)
	await move(at)
	await mouse(at, true, MOUSE_BUTTON_WHEEL_DOWN)
	expect(shell.route_scroll > 0, "vertical wheel browses horizontally")
	await mouse(at, true, MOUSE_BUTTON_WHEEL_UP)
	expect(is_equal_approx(shell.route_scroll, wheel_start), "reverse wheel returns to same browsing position")
	await mouse(at, true, MOUSE_BUTTON_WHEEL_RIGHT)
	expect(shell.route_scroll > 0, "horizontal wheel browses route")
	await mouse(at, true, MOUSE_BUTTON_WHEEL_LEFT)
	expect(is_equal_approx(shell.route_scroll, wheel_start), "horizontal wheel reverse")
	await mouse(at, true)
	await move(at - Vector2(100000, 0))
	await mouse(at - Vector2(100000, 0), false)
	expect(is_equal_approx(shell.route_scroll, shell.route_map._max_offset()), "drag clamps to end")
	await move(at)
	await mouse(at, true)
	await move(at + Vector2(100000, 0))
	await mouse(at + Vector2(100000, 0), false)
	expect(is_zero_approx(shell.route_scroll), "drag clamps to beginning")
	await click("route_current")
	expect(shell.selected_node == "B04" and visible_marker("B04"), "locate-current restores current node and details")
	unchanged("drag, wheels and current locator")

func keyboard_and_modal() -> void:
	shell.route_map.focus_node("B04")
	await frames()
	await key(KEY_RIGHT)
	expect(viewport.gui_get_focus_owner().name == "node_B05", "Right focuses alternate branch")
	var paper := shell.find_child("campaign_detail_paper", true, false) as Control
	var branch := shell.find_child("node_B05", true, false) as Control
	expect(not paper.get_global_rect().intersects(branch.get_global_rect()), "keyboard-focused lower branch remains beyond overlapping information paper")
	await key(KEY_ENTER)
	expect(shell.selected_node == "B05" and state.data.current == "B04", "Enter inspects focused node")
	await key(KEY_TAB)
	expect(viewport.gui_get_focus_owner().name == "node_B03", "Tab continues route inspection")
	await key(KEY_ENTER)
	expect(shell.selected_node == "B03" and shell.find_child("route_forward", true, false) == null, "locked future node is inspectable without forward action")
	shell.route_map.focus_node("S04")
	await frames()
	var choices := shell.find_child("campaign_choice_panel", true, false) as Control
	var future := shell.find_child("node_S04", true, false) as Control
	expect(not choices.get_global_rect().intersects(future.get_global_rect()), "keyboard-focused future node remains outside overlaid frontier cards")
	await click("route_current")
	shell.confirm("地图输入检查", "检查上层窗口阻断地图输入。", func(): pass)
	await frames()
	var map_bounds: Rect2 = shell.route_map.get_global_rect()
	await point_click(map_bounds.end - Vector2(22, 22))
	expect(shell.selected_node == "B04" and is_instance_valid(shell.modal), "modal consumes pointer above map outside its own action buttons")
	await click("modal_cancel")
	unchanged("keyboard and modal input")

func layout_and_navigation() -> void:
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]:
		viewport.size = dimensions
		await frames(14)
		await click("route_current")
		var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
		for id in ["CampaignRouteMap", "route_node_title", "route_node_status", "route_forward", "route_current"]:
			var control := shell.find_child(id, true, false) as Control
			expect(control != null and bounds.encloses(control.get_global_rect()), "route layout fits " + id + " " + str(dimensions))
		expect(visible_marker("B04") and visible_marker("B05"), "compact branching nodes remain inside map " + str(dimensions))
		await capture("03-route-" + str(dimensions.x))
	viewport.size = Vector2i(1280,720)
	await frames(14)
	shell.route_map.focus_node("B04")
	shell.route_map.focus_segment(4)
	var stored: float = shell.route_scroll
	viewport.size = Vector2i(960,540)
	await frames(14)
	expect(is_equal_approx(shell.route_scroll, stored), "resize preserves panned view despite old offscreen keyboard focus")
	shell.route_map.focus_segment(5)
	await frames()
	expect(shell.route_scroll > stored and shell.selected_node == "B04" and state.data.current == "B04", "map section positioning moves view without selecting or unlocking")
	await capture("04-final-area-960")
	viewport.size = Vector2i(1280,720)
	await frames(14)
	await click("route_current")
	shell.route_map.focus_node("S02")
	await frames()
	await point_click(marker_center("S02"))
	var replay_offset: float = shell.route_scroll
	await click("route_replay")
	await click("story_skip")
	expect(shell.page == "route" and shell.selected_node == "S02" and is_equal_approx(shell.route_scroll, replay_offset), "completed story replay returns to same selected node and map view")
	unchanged("map positioning, resize and completed-story replay")

func progression_states() -> void:
	await fixture("B03", ["B03"], ["S01", "B01", "S02", "B02", "S03", "B04"])
	expect(MAP.state_for(state, "B04") == "completed" and MAP.state_for(state, "B05") == "skipped" and MAP.state_for(state, "B03") == "available", "fork convergence closes only unchosen branch")
	shell.route_map.focus_node("B05")
	await point_click(marker_center("B05"))
	expect(shell.find_child("route_forward", true, false) == null and (shell.find_child("route_node_status", true, false) as Label).text == "未走支路", "skipped branch cannot be re-entered")
	await capture("05-skipped-branch-1280")
	unchanged("closed alternative branch")
	state.guarded = false
	expect(state.make_reward("B03", false) and state.select_card(state.data.pending.candidates[0]), "create partially selected victory draft")
	shell.selected_node = "B03"
	shell.render()
	await frames(14)
	watch()
	expect(MAP.state_for(state, "B03") == "reward" and shell.find_child("route_reward", true, false) != null and shell.find_child("route_forward", true, false) == null, "pending reward has distinct state and no second battle entry")
	await click("route_current")
	unchanged("pending draft browsing")
	await fixture("B04", ["B04", "B05"], ["S01", "B01", "S02", "B02", "S03"])
	state.guarded = false
	expect(state.make_reward("B04", false) and state.select_card(state.data.pending.candidates[0]), "victory draft while fork is still in saved available list")
	shell.render()
	await frames(14)
	watch()
	expect(MAP.state_for(state, "B04") == "reward" and MAP.state_for(state, "B05") == "skipped" and MAP.state_for(state, "B03") == "locked", "pending winning branch closes sibling without advertising future as available")
	await point_click(marker_center("B05"))
	expect(shell.find_child("route_forward", true, false) == null and shell.find_child("route_reward", true, false) != null, "pending sibling inspection only offers completion of existing reward")
	await capture("06-pending-branch-1280")
	unchanged("pending fork and existing candidates")
	state.guarded = false
	expect(state.select_card(state.data.pending.candidates[1]) and state.claim_reward(), "settle actual pending fork reward")
	expect(MAP.state_for(state, "B03") == "available" and MAP.state_for(state, "B05") == "skipped", "claim opens convergence and preserves closed alternative")
	var legacy := GuardedCampaign.new()
	legacy.data.current = "S02"
	legacy.data.available = ["S02"]
	legacy.data.completed = ["S01", "B01"]
	expect(legacy.make_reward("B01", false) and legacy.valid(legacy.data), "valid old first-reward boundary at next story")
	expect(MAP.state_for(legacy, "S02") == "locked" and MAP.state_for(legacy, "B01") == "completed", "old pending first reward blocks next story without marking it skipped")
	await fixture("B07", ["B07"], ["S01", "B01", "S02", "B02", "S03", "B04", "B03", "S04", "F01", "S05"])
	expect(MAP.state_for(state, "B07") == "available" and not (shell.find_child("route_forward", true, false) as Button).disabled, "authored later encounter is available after reaching its route")
	await capture("07-authored-1280")
	unchanged("authored available node remains inspection-only")

func explicit_forward() -> void:
	await fixture("B04", ["B04", "B05"], ["S01", "B01", "S02", "B02", "S03"])
	await point_click(marker_center("B05"))
	unchanged("inspection before explicit forward")
	state.guarded = false
	state.choose_calls = 0
	await click("route_forward")
	expect(shell.page == "preparation" and state.data.current == "B05" and state.choose_calls == 1, "only explicit right-side action chooses and commits route")
	expect(state.read_slot("auto").current == "B05", "confirmed forward action persists chosen branch")
