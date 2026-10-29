extends SceneTree
## Identity, existing progression gates and the player's actual character/story pages.
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
const PROFILES := preload("res://scripts/content/character_profiles.gd")
const STORY := preload("res://scripts/content/story_catalog.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")
var failures := 0
var checks := 0
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

func frames(count: int = 8) -> void:
	for i in count: await process_frame

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var bitmap := viewport.get_texture().get_image()
	expect(bitmap.get_size() == viewport.size, "capture size " + name)
	bitmap.save_png(capture_dir.path_join(name + ".png"))

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated test storage")
	if failures: quit(1); return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	shell = SHELL.instantiate()
	shell.session.directory = "user://character_profiles_" + str(Time.get_ticks_usec())
	viewport.add_child(shell)
	await frames()
	var state: RefCounted = shell.session
	expect(PROFILES.validate(state.characters).is_empty(), "authored profiles match stable character identities")
	expect(PROFILES.all().size() == 38 and state.SCHEMA == 1 and C.IDS.size() == 38, "complete character profiles and combat definitions retain the save schema")
	for id in C.IDS:
		expect(not PROFILES.find(id).is_empty(), "combat identity has a complete profile " + id)
	expect(state.data.owned.size() == 1 and state.data.pool == C.INITIAL_POOL and "B07" not in state.data.available and state.data.current == "S01", "full character library does not grant ownership, expand the initial pool or unlock future battles")
	expect(state.characters.F03.name == "田秀" and state.characters.F07.name == "马三娘", "concrete names replace generic job names")
	for id in ["F03", "F07"]:
		expect(state.characters[id].rarity == "rare" and id not in state.data.pool and not state.data.owned.has(id), "named character remains gated " + id)
	var old_ids := {"S03":["s03_01","s03_02","s03_03","s03_04"], "S04":["s04_01","s04_02","s04_03","s04_04"]}
	for event in old_ids:
		var content: Dictionary = STORY.events()[event]
		expect(content.lines.size() >= 10, "event contains individual dialogue " + event)
		for id in old_ids[event]:
			expect(STORY.has_line(content, id) and STORY.line_id(content, {"event":event,"line":id}) == id, "prior sentence checkpoint remains reachable " + id)
	# Explicit event-boundary fixtures: only entry eligibility is set, no battle is claimed.
	for pair in [["S03", "F03"], ["S04", "F07"]]:
		state.data.current = pair[0]
		state.data.available = [pair[0]]
		expect(state.resolve_event() and pair[1] in state.data.pool and not state.data.owned.has(pair[1]), "event unlocks pool rather than granting named character " + pair[1])
	# Existing saves store IDs, not display names. Names and biographies are a read-only projection.
	state.data.owned.F03 = C.record("F03", 3)
	state.data.owned.F07 = C.record("F07", 4)
	expect(state.save_slot("1") and state.load_slot("1"), "ID-based character records round-trip")
	expect(state.data.owned.F03.level == 3 and state.data.owned.F07.level == 4, "existing growth preserved after naming")
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]:
		viewport.size = dimensions
		await frames()
		for id in ["F03", "F07"]:
			shell.selected_character = id
			var before: Dictionary = state.data.duplicate(true)
			shell.inspect_character(id, "profile")
			await frames()
			expect(state.data == before, "viewing personality never alters party or resources")
			for name in ["CharacterName", "CharacterTitle", "CharacterBiography", "CharacterQuote", "CharacterRelationship"]:
				expect(shell.character_sheet.find_child(name,true,false) != null, "profile page includes " + id + "/" + name)
			expect((shell.character_sheet.find_child("CharacterBiography",true,false) as Label).text == PROFILES.find(id).biography, "actual authored biography shown")
			var scroll := shell.character_sheet.find_child("character_detail_scroll",true,false) as ScrollContainer
			expect(scroll != null and scroll.size.y >= 100 and Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(scroll.get_global_rect()), "profile reading area fits viewport")
			await capture("profile-" + id + "-%d" % dimensions.x)
			scroll.scroll_vertical = 10000
			await frames()
			var ending := shell.character_sheet.find_child("CharacterRelationship",true,false) as Label
			expect(ending.get_global_rect().end.y <= scroll.get_global_rect().end.y + 1, "last profile line reachable by scrolling")
	shell.roster_filter = "all"
	shell.search_text = "女医者"
	shell.open_page("roster")
	await frames()
	expect(shell.find_child("character_F03",true,false) != null and shell.find_child("character_F07",true,false) == null, "original occupation still finds the newly named character")
	shell.search_text = "马三娘"
	shell.render()
	await frames()
	expect(shell.find_child("character_F07",true,false) != null, "concrete name is searchable")
	var motion := SETTINGS.comfort_enabled("reduced_motion")
	SETTINGS.save_comfort("reduced_motion", true)
	viewport.size = Vector2i(1280,720)
	for entry in [["S03", "s03_02", "田秀"], ["S04", "s04_03", "马三娘"]]:
		state.data.pending.clear()
		state.data.story_checkpoint.clear()
		state.data.current = entry[0]
		state.data.available = [entry[0]]
		expect(state.save_story_checkpoint(entry[0],entry[1]), "prior authored checkpoint can be resumed")
		shell.open_page("event")
		await frames()
		expect(shell.story_view.current_line_id == entry[1], "reader restores previous sentence identity")
		expect((shell.find_child("StorySpeaker",true,false) as Label).text == entry[2], "dialogue uses new individual name")
		await capture("story-" + entry[0] + "-1280")
	SETTINGS.save_comfort("reduced_motion", motion)
	shell.queue_free()
	await frames()
	viewport.queue_free()
	await frames()
	print("CHRONICLE_CHARACTER_PROFILES_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
