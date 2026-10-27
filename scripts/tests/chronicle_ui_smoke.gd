extends SceneTree

const SESSION := preload("res://scripts/ui/chronicle/chronicle_session.gd")
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
var failures := 0
var capture_dir := ""
var shell: Control

func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="): capture_dir = argument.trim_prefix("--capture=")
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func frames(count: int = 4) -> void:
	for _i in count: await process_frame

func capture(name: String) -> void:
	await frames(8)
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))

func click(id: String) -> void:
	var button := shell.find_child(id, true, false) as Button
	expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, "usable button " + id)
	if is_instance_valid(button) and not button.disabled:
		button.grab_focus()
		button.pressed.emit()
	await frames()

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await frames()

func pick_reward(state: RefCounted) -> void:
	var cards: Array = state.data.pending.candidates.duplicate()
	for index in int(state.data.pending.picks): expect(state.select_card(cards[index]), "pick required card")
	expect(not state.select_card(cards[-1]), "extra selection refused")
	expect(state.claim_reward(), "reward committed")
	expect(not state.claim_reward(), "reward cannot be claimed twice")

func resolve_current(state: RefCounted) -> void:
	var node: Dictionary = state.nodes[state.data.current]
	if node.kind in ["event", "spring"]:
		expect(state.resolve_event(), "event resolves " + node.id)
	else:
		expect(not state.start_battle().is_empty(), "battle request " + node.id)
		expect(state.complete_battle({}), "battle result " + node.id)
	if not state.data.pending.is_empty(): pick_reward(state)

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "run with isolated XDG_DATA_HOME under /tmp")
	if failures:
		quit(1)
		return
	var state := SESSION.new()
	state.directory = "user://chronicle_contract_test"
	expect(state.characters.size() == 38 and state.nodes.size() == 36, "37 cards + protagonist; 36 nodes")
	expect(state.data.owned.size() == 1 and state.roster().size() == 1, "solo opening")
	expect(state.begin_campaign() and state.resolve_event(), "start road")
	state.start_battle()
	expect(state.in_battle and state.save_slot("1"), "battle saves entry snapshot")
	expect(state.read_slot("1").current == "B01", "entry snapshot preserved")
	state.abandon_battle()
	expect(state.data.owned.size() == 1, "failed attempt grants nothing")
	state.start_battle()
	expect(state.complete_battle({}) and state.data.current == "S02", "post battle event before draw")
	expect(state.data.pending.is_empty(), "draw waits for story")
	expect(state.resolve_event(), "Emma story joins")
	expect(state.data.owned.has("F11") and state.data.pending.picks == 2, "Emma does not consume draw")
	var candidates: Array = state.data.pending.candidates.duplicate()
	state.select_card(candidates[0])
	expect(state.save_slot("2"), "pending reward save")
	state.select_card(candidates[1])
	expect(state.load_slot("2"), "pending reward load")
	expect(state.data.pending.candidates == candidates and state.data.pending.selected == [candidates[0]], "candidates AND selection stable")
	state.select_card(candidates[1])
	expect(state.claim_reward(), "initial cards claimed")
	expect(state.assign("F11", 0) and state.assign("F11", 1), "move auxiliary between slots")
	expect(state.data.party == ["", "F11"], "no duplicate slot")
	state.start_battle()
	state.complete_battle({"characters":{"F11":{"hp":0,"mp":30,"dead":true}}})
	expect(state.data.owned.F11.dead and "F11" not in state.data.party, "dead auxiliary leaves next stage selection")
	expect(not state.assign("F11", 0), "cannot field dead auxiliary")
	pick_reward(state)
	while state.data.current != "F01": resolve_current(state)
	expect(state.resolve_event() and not state.data.owned.F11.dead, "spring revives whole roster")
	expect("M02" not in state.data.pool, "Zhang Liao locked before B17")
	var steps := 0
	while not state.data.finished and steps < 80:
		var id: String = state.data.current
		resolve_current(state)
		if id == "B17": expect("M02" in state.data.pool and "M03" in state.data.pool and "M04" in state.data.pool, "B17 unlocks important trio")
		steps += 1
	expect(state.data.finished and "B18" in state.data.completed, "full route terminates")
	var before := state.data.duplicate(true)
	print("EXPECTED_FAULT_INJECTION: write to /proc must fail and rollback")
	state.directory = "/proc/chronicle-test-read-only"
	expect(not state.assign("F11", 0) and state.data == before, "failed write rolls back mutation")
	expect(not state.valid({"schema":1}), "incomplete save rejected")
	state.directory = "user://chronicle_contract_test"
	state = null

	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	shell = SHELL.instantiate()
	# Keep the complete 36-node UI fixture independent of the two real battle stages.
	# Real gameplay and keyboard integration are covered by chronicle_playable_ui_smoke.gd.
	shell.session = SESSION.new()
	shell.session.directory = "user://chronicle_ui_layout_test"
	shell.battle_script = preload("res://scripts/ui/chronicle/chronicle_battle.gd")
	root.add_child(shell)
	current_scene = shell
	await frames()
	await capture("01-title-1280")
	await click("new_campaign")
	await key(KEY_TAB)
	expect(shell.get_viewport().gui_get_focus_owner().name == "modal_cancel", "modal traps tab focus")
	await click("modal_confirm")
	await click("route_forward")
	await capture("02-opening-event-1280")
	await click("event_continue")
	await click("route_forward")
	await capture("03-solo-preparation-1280")
	await click("prep_start")
	await frames()
	shell.battle_view.apply_preview_damage(100)
	await frames()
	expect(shell.page == "failure" and shell.session.data.owned.JIA.hp == 100, "protagonist failure restores entry state")
	await capture("03-failure-1280")
	await click("failure_retry")
	await click("prep_start")
	await key(KEY_J)
	expect(shell.battle_view.records.JIA.mp < 100, "manual skill spends mana")
	await capture("04-solo-hud-1280")
	await key(KEY_ESCAPE)
	expect(shell.battle_view.paused, "Esc pauses rehearsal")
	await capture("05-pause-1280")
	shell.finish_battle({})
	await frames()
	await click("route_forward")
	await click("event_continue")
	await capture("06-first-reward-1280")
	candidates = shell.session.data.pending.candidates.duplicate()
	await click("reward_card_" + candidates[0])
	await click("reward_card_" + candidates[1])
	await capture("07-reward-selected-1280")
	await click("reward_claim")
	shell.session.assign("F11",0)
	for id in shell.session.data.owned:
		if id not in ["JIA","F11"]:
			shell.session.assign(id,1)
			break
	shell.open_page("world")
	await capture("08-world-1280")
	await click("province_荆州")
	expect(shell.selected_province == "荆州", "province selection")
	await capture("09-unavailable-region-1280")
	shell.selected_province = "徐州"
	shell.resume_view()
	resolve_current(shell.session) # B02
	resolve_current(shell.session) # S03
	shell.resume_view()
	await capture("10-route-1280")
	shell.roster_filter = "all"
	shell.selected_character = "F11"
	shell.open_page("roster")
	await capture("11-roster-1280")
	shell.open_page("equipment")
	await capture("12-equipment-1280")
	shell.open_page("saves")
	await capture("13-saves-1280")
	shell.open_page("settings")
	await capture("14-settings-1280")
	await click("settings_music")
	await click("music_next")
	expect(shell.music_index == 1 and shell.music_preview.stream != null, "music catalog plays real track")
	await click("music_pause")
	expect(shell.music_preview.stream_paused, "music pause")
	await capture("14-music-1280")
	await key(KEY_ESCAPE)
	expect(shell.page == "settings" and shell.music_preview == null, "music closes and restores page")
	shell.open_page("journal")
	await capture("15-journal-1280")
	shell.resume_view()
	shell.start_battle()
	await frames()
	await key(KEY_E)
	expect(shell.battle_view.active == 1, "keyboard auxiliary switch")
	shell.battle_view.choose_field(2)
	expect(shell.battle_view.field == 2, "field selected")
	shell.battle_view.choose_field(3)
	expect(shell.battle_view.field == 2, "one field only")
	await capture("16-team-hud-1280")
	shell.finish_battle({"card_elite":true})
	expect(shell.session.data.pending.picks == 3, "extra elite five choose three")
	await capture("17-elite-reward-1280")
	pick_reward(shell.session)
	while shell.session.data.current != "S14": resolve_current(shell.session)
	shell.session.resolve_event()
	expect(shell.session.data.pending.candidates.size() == 7, "chapter seven candidates")
	var important := 0
	for id in shell.session.data.pending.candidates:
		if shell.session.characters[id].kind == "重要人物": important += 1
	expect(important >= 2, "chapter at least two important candidates")
	shell.resume_view()
	await capture("18-chapter-reward-1280")
	for dimensions in [Vector2i(960,540), Vector2i(1920,1080)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await frames()
		for screen in ["reward","roster","equipment","settings","world","route"]:
			shell.open_page(screen)
			await capture("19-%s-%d" % [screen,dimensions.x])
		if dimensions.x == 960:
			shell.open_page("roster")
			await click("character_F11")
			expect(shell.page == "character", "compact character has its own page")
			expect(shell.find_child("character_owned_summary", true, false) != null, "three character roles share detail page")
			await capture("20-character-960")
			await click("character_back")
			await key(KEY_TAB)
			expect(root.gui_get_focus_owner() != null, "keyboard focus exists at 960")
	shell.open_page("home")
	await click("legacy_game")
	var legacy := current_scene.find_child("ChronicleReturn", true, false) as Button
	expect(legacy != null and root.get_visible_rect().encloses(legacy.get_global_rect()), "legacy return entry visible")
	if legacy != null: legacy.pressed.emit()
	await frames(8)
	shell = current_scene
	expect(shell.get_script() == preload("res://scripts/ui/chronicle/chronicle_shell.gd"), "legacy returns to new UI")
	print("CHRONICLE_UI_SMOKE_OK" if failures == 0 else "CHRONICLE_UI_SMOKE_FAILED: %d" % failures)
	shell.queue_free()
	current_scene = null
	shell = null
	await frames(8)
	quit(0 if failures == 0 else 1)
