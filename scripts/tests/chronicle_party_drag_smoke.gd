extends SceneTree
## Real native pointer drags exercise the formal campaign/save transaction.
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
const DRAG := preload("res://scripts/ui/chronicle/chronicle_party_drag_card.gd")

class Campaign extends "res://scripts/campaign/campaign_service.gd":
	var auto_writes := 0
	var reject_writes := false
	func save_slot(slot: String) -> bool:
		if slot == "auto": auto_writes += 1
		if reject_writes: return false
		return super.save_slot(slot)

var shell: Control
var viewport: SubViewport
var state: Campaign
var checks := 0
var failures := 0
var changed := 0
var capture_dir := ""
var pointer := Vector2.ZERO
var captured_native := false
var native_attempts := 0
var native_started := 0

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func frames(count: int = 6) -> void:
	for i in count: await process_frame

func files() -> Dictionary:
	var result := {}
	for name in DirAccess.get_files_at(state.directory):
		var path: String = state.directory.path_join(name)
		result[name] = {"bytes":FileAccess.get_file_as_bytes(path), "time":FileAccess.get_modified_time(path)}
	return result

func snapshot() -> Dictionary:
	return {"data":state.data.duplicate(true), "rng":state.reward_rng.state, "files":files(), "entry":state.entry_snapshot.duplicate(true), "battle":state.in_battle, "attempt":state.active_attempt}

func control(id: String) -> Control:
	return shell.find_child(id, true, false) as Control

func move(at: Vector2, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = at - pointer
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	pointer = at
	viewport.push_input(event)
	await frames(2)

func mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = pointer
	event.global_position = pointer
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	viewport.push_input(event)
	await frames(2)

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	viewport.push_input(event)
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event)
	await frames(4)

func begin_drag(id: String, allowed: bool = true) -> void:
	native_attempts += 1
	var source := control(id)
	expect(source != null and source.is_visible_in_tree(), "drag source exists " + id)
	if source == null: return
	if id.begins_with("character_"):
		(control("roster_scroll") as ScrollContainer).ensure_control_visible(source)
		await frames()
	var origin := source.get_global_rect().get_center()
	await move(origin)
	await mouse(true)
	await move(origin + Vector2(24, -18), true)
	if viewport.gui_is_dragging(): native_started += 1
	expect(viewport.gui_is_dragging() == allowed, "native drag availability " + id)

func finish_drag(target: String) -> void:
	var destination := control(target)
	expect(destination != null, "drop target exists " + target)
	if destination != null: await move(destination.get_global_rect().get_center(), true)
	await mouse(false)
	await frames(10)
	await create_timer(.2).timeout

func drag(source: String, target: String, allowed: bool = true) -> void:
	await begin_drag(source, allowed)
	if not captured_native and viewport.gui_is_dragging() and not capture_dir.is_empty():
		captured_native = true
		await move(control(target).get_global_rect().get_center(), true)
		await capture("00-native-drag-1280")
	await finish_drag(target)

func fixture() -> void:
	state.reject_writes = false
	state.reset(false)
	state.data.started = true
	state.data.current = "B04"
	state.data.available = ["B04", "B05"]
	state.data.completed = ["S01", "B01", "S02", "B02", "S03"]
	for id in ["F03", "F07", "F11", "N16", "N17"]:
		state.data.owned[id] = state.new_character(id)
		if id not in state.data.pool: state.data.pool.append(id)
	state.data.owned.F07.dead = true
	state.data.owned.F07.hp = 0.0
	state.data.owned.JIA.hp = 17.0
	state.data.owned.JIA.mp = 2.0
	state.data.party = ["", ""]
	expect(state.valid(state.data) and state.save_slot("auto") and state.save_slot("1"), "persist legal drag fixture")
	shell.search_text = ""
	shell.roster_filter = "owned"
	shell.open_page("roster")
	await frames(12)

func expect_party(expected: Array, before: Dictionary, writes: int, signals: int, label: String) -> void:
	expect(state.data.party == expected, label + ": expected lineup")
	var old: Dictionary = before.data.duplicate(true)
	var current: Dictionary = state.data.duplicate(true)
	old.erase("party")
	current.erase("party")
	expect(old == current and state.reward_rng.state == before.rng, label + ": all character resources/progression/RNG unchanged")
	expect(state.auto_writes == writes + 1 and changed == signals + 1, label + ": one atomic save and one change signal")
	expect(not is_instance_valid(shell.character_sheet) and shell.page == "roster", label + ": drag does not open character inspection")

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await frames()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var bitmap := viewport.get_texture().get_image()
	expect(bitmap.get_size() == viewport.size, "capture dimensions " + name)
	bitmap.save_png(capture_dir.path_join(name + ".png"))

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated drag test saves")
	if failures: quit(1); return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	shell = SHELL.instantiate()
	state = Campaign.new()
	state.directory = "user://party_drag_" + str(Time.get_ticks_usec())
	state.changed.connect(func(): changed += 1)
	shell.session = state
	viewport.add_child(shell)
	await frames(12)
	await fixture()
	await native_operations()
	await rejection_and_rollback()
	await keyboard_operations()
	await interaction_lifecycle()
	await layouts()
	shell.queue_free()
	await frames()
	viewport.queue_free()
	await frames()
	print("NATIVE_PARTY_DRAG attempts=", native_attempts, " started=", native_started)
	print("CHRONICLE_PARTY_DRAG_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func native_operations() -> void:
	for operation in [["character_F11", "prep_member_1", ["F11", ""]], ["character_F03", "prep_member_1", ["F03", ""]], ["character_F11", "prep_member_2", ["F03", "F11"]], ["prep_member_1", "prep_member_2", ["F11", "F03"]]]:
		var before := snapshot()
		var writes := state.auto_writes
		var signals := changed
		await drag(operation[0], operation[1])
		expect_party(operation[2], before, writes, signals, operation[0] + " → " + operation[1])
	await capture("01-two-members-1280")
	var before := snapshot()
	var writes := state.auto_writes
	await drag("prep_member_2", "prep_member_2")
	expect(snapshot() == before and state.auto_writes == writes, "same-position drop is a no-op without a save")
	before = snapshot()
	writes = state.auto_writes
	var signals := changed
	await drag("prep_member_2", "character_N16")
	expect_party(["F11", ""], before, writes, signals, "return to library")
	before = snapshot()
	writes = state.auto_writes
	signals = changed
	await drag("prep_member_1", "prep_member_2")
	expect_party(["", "F11"], before, writes, signals, "move fielded member into empty slot")
	before = snapshot()
	writes = state.auto_writes
	await begin_drag("prep_member_2")
	await key(KEY_ESCAPE)
	await move(Vector2(5,5), true)
	await mouse(false)
	await frames()
	expect(not viewport.gui_is_dragging() and shell.page == "roster" and snapshot() == before and state.auto_writes == writes, "Escape cancels native drag once without leaving preparation or writing")
	await create_timer(.2).timeout
	await begin_drag("prep_member_2")
	await move(Vector2(5,5), true)
	await mouse(false)
	await frames()
	expect(snapshot() == before and state.auto_writes == writes, "drop outside all targets does not commit")

func rejection_and_rollback() -> void:
	await fixture()
	var fixed_before := snapshot()
	var fixed_writes := state.auto_writes
	await drag("character_F11", "prep_member_0")
	expect(snapshot() == fixed_before and state.auto_writes == fixed_writes, "fixed protagonist slot rejects incoming auxiliary")
	for id in ["JIA", "F07"]:
		var before := snapshot()
		var writes := state.auto_writes
		await drag("character_" + id, "prep_member_1", false)
		expect(snapshot() == before and state.auto_writes == writes, "fixed/dead source is rejected " + id)
	shell.roster_filter = "all"
	shell.render()
	await frames()
	var before := snapshot()
	var writes := state.auto_writes
	await drag("character_M01", "prep_member_1", false)
	expect(snapshot() == before and state.auto_writes == writes, "unowned source is rejected")
	shell.roster_filter = "owned"
	shell.render()
	await frames()
	state.reject_writes = true
	before = snapshot()
	writes = state.auto_writes
	await drag("character_F11", "prep_member_1")
	expect(snapshot() == before and state.auto_writes == writes + 1, "controlled save refusal rolls back the complete lineup and preserves files")
	state.reject_writes = false
	if is_instance_valid(shell.modal):
		(control("modal_confirm") as Button).pressed.emit()
		await frames()
	expect(state.assign("F11",0), "set up stale-drag source")
	shell.render()
	await frames()
	await begin_drag("prep_member_1")
	expect(state.assign("F03",0), "external transaction changes source before release")
	before = snapshot()
	writes = state.auto_writes
	await finish_drag("prep_member_2")
	expect(snapshot() == before and state.auto_writes == writes, "stale source payload is rejected atomically")
	await fixture()
	expect(state.make_reward("B04",false) and state.select_card(state.data.pending.candidates[0]), "persist pending-reward lock")
	shell.render()
	await frames()
	before = snapshot()
	writes = state.auto_writes
	await drag("character_F11", "prep_member_1", false)
	expect(snapshot() == before and state.auto_writes == writes, "pending rewards reject native configuration")
	await fixture()
	expect(not state.start_battle().is_empty(), "activate battle transaction guard")
	before = snapshot()
	writes = state.auto_writes
	await drag("character_F11", "prep_member_1", false)
	expect(snapshot() == before and state.auto_writes == writes, "battle-in-progress rejects native configuration")
	state.abandon_battle()

func focus_by_tab(id: String) -> void:
	for i in 70:
		var focus := viewport.gui_get_focus_owner()
		if is_instance_valid(focus) and focus.name == id: return
		await key(KEY_TAB)
	expect(false, "Tab can reach " + id)

func keyboard_operations() -> void:
	await fixture()
	control("character_F11").grab_focus()
	var before := snapshot()
	var writes := state.auto_writes
	var signals := changed
	await key(KEY_SPACE)
	expect(not DRAG.carried(shell).is_empty(), "Space picks up a focused owned character")
	await focus_by_tab("prep_member_1")
	await key(KEY_ENTER)
	await frames()
	expect_party(["F11", ""], before, writes, signals, "keyboard assignment")
	await create_timer(.2).timeout
	control("prep_member_1").grab_focus()
	before = snapshot()
	writes = state.auto_writes
	signals = changed
	await key(KEY_SPACE)
	await focus_by_tab("party_library_drop_zone")
	await key(KEY_ENTER)
	await frames()
	expect_party(["", ""], before, writes, signals, "keyboard removal")
	await create_timer(.2).timeout
	control("character_F03").grab_focus()
	before = snapshot()
	writes = state.auto_writes
	await key(KEY_SPACE)
	await key(KEY_ESCAPE)
	expect(DRAG.carried(shell).is_empty() and shell.page == "roster" and snapshot() == before and state.auto_writes == writes, "Escape cancels keyboard pickup without changing the page or files")

func interaction_lifecycle() -> void:
	await fixture()
	control("character_F11").grab_focus()
	var before := snapshot()
	var writes := state.auto_writes
	await key(KEY_SPACE)
	var another_shell := Control.new()
	expect(not DRAG.suppressing_click(another_shell) and not DRAG.carried(shell).is_empty(), "carry is scoped to its shell, never global")
	another_shell.free()
	shell.inspect_character("F11")
	await frames()
	expect(DRAG.carried(shell).is_empty() and is_instance_valid(shell.character_sheet) and snapshot() == before and state.auto_writes == writes, "opening character inspection cancels carry without a campaign transaction")
	shell.close_character_sheet()
	await frames()
	await create_timer(.2).timeout
	await move(control("character_F03").get_global_rect().get_center())
	await mouse(true)
	await mouse(false)
	await frames()
	expect(shell.selected_character == "F03" and not is_instance_valid(shell.character_sheet), "normal character click works after carry cancellation")
	control("character_F11").grab_focus()
	await key(KEY_SPACE)
	await move(control("party_tab_equipment").get_global_rect().get_center())
	await mouse(true)
	await mouse(false)
	await frames()
	expect(shell.page == "equipment" and DRAG.carried(shell).is_empty() and snapshot() == before and state.auto_writes == writes, "leaving the page cancels carry and leaves save/RNG/resources unchanged")
	shell.open_page("roster")
	await frames()
	control("character_F03").grab_focus()
	await key(KEY_SPACE)
	shell.render()
	await frames()
	expect(DRAG.carried(shell).is_empty() and snapshot() == before, "rebuilding card library clears an obsolete keyboard carry")

func layouts() -> void:
	await fixture()
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]:
		viewport.size = dimensions
		await frames(14)
		var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
		for id in ["party_preparation_panel", "party_drag_hint", "prep_member_0", "prep_member_1", "prep_member_2", "roster_scroll", "party_library_drop_zone", "page_back"]:
			var item := control(id)
			expect(item != null and bounds.encloses(item.get_global_rect()), "layout fits " + id + " " + str(dimensions))
		if dimensions.y >= 650:
			expect(control("character_preview_panel") != null and bounds.encloses(control("character_preview_panel").get_global_rect()), "quick preview stays within viewport " + str(dimensions))
		expect(control("assign_0") == null and control("assign_1") == null and control("remove_auxiliary") == null, "no numbered assignment or reserve buttons")
		await capture("02-roster-" + str(dimensions.x))
		shell.open_page("preparation")
		await frames()
		expect(control("prep_start") != null and bounds.encloses(control("prep_start").get_global_rect()), "battle entry remains available " + str(dimensions))
		await capture("03-battle-preparation-" + str(dimensions.x))
		shell.open_page("route")
		shell.open_page("roster")
		await frames()
