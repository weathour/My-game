extends SceneTree
## External script run with --main-pack from an empty directory; no source fallback.
const STORIES := preload("res://scripts/content/story_catalog.gd")
const CAMPAIGN := preload("res://scripts/campaign/campaign_service.gd")
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("run")

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func frames(count: int = 5) -> void:
	for frame in count: await process_frame

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated packed save location")
	for path in [STORIES.PATH, STORIES.OPTIONAL_PATH, STORIES.REACTIONS_PATH, STORIES.LORE_PATH, "res://assets/data/chronicle/character_profiles.json"]:
		expect(FileAccess.file_exists(path), "raw story JSON packed: " + path)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		expect(parsed is Dictionary and not parsed.is_empty(), "packed story dictionary readable: " + path)
	if failures: quit(1); return
	expect(STORIES.events().size() == 22 and STORIES.optional_events().size() == 32 and STORIES.reactions().size() == 48, "complete story catalogs packed")
	var errors := STORIES.validate()
	expect(errors.is_empty(), "packed catalog references valid: " + str(errors))
	for catalog in [STORIES.events(), STORIES.optional_events()]:
		for event in catalog.values():
			expect(load(str(event.background)) is Texture2D, "packed scene background loads: " + str(event.id))
			for line in event.lines:
				if line.has("background"): expect(load(str(line.background)) is Texture2D, "packed line background loads: " + str(line.id))
	expect(not FileAccess.file_exists("res://docs/story/baimen-20261030/content-contract.json"), "private authoring sources excluded")
	var state := CAMPAIGN.new()
	state.directory = "user://story_pack"
	# Library layout fixture, with real acquired records rather than pool membership.
	for id in state.CONTENT.IDS: state.data.owned[id] = state.new_character(id)
	state.data.completed = state.nodes.keys()
	state.data.current = "B18"; state.data.available = ["B18"]; state.data.started = true
	var shell := SHELL.instantiate()
	shell.session = state
	root.add_child(shell)
	await frames(10)
	shell.open_page("journal")
	await frames()
	var ids: Array = state.available_optional_stories()
	expect(not ids.is_empty(), "packed optional scenes discoverable")
	if not ids.is_empty():
		var id: String = ids[0]
		expect(shell.find_child("journal_optional_" + id, true, false) != null, "packed journal exposes optional entry")
		expect(shell.open_optional_story(id), "packed optional entry opens")
		await frames()
		expect(shell.story_view != null and shell.story_view.current_line_id == STORIES.optional_events()[id].lines[0].id, "packed optional reader presents authored text")
		var background := shell.find_child("StoryBackground", true, false) as TextureRect
		expect(background != null and background.texture != null, "packed optional background resolves imported asset")
		shell._advance_optional_story("")
		await frames()
		expect(id in state.read_optional_stories() and shell.page == "journal", "packed optional completion persists without main progression")
		expect(shell.open_story_replay(id, "journal"), "packed optional replay opens")
		await frames()
		expect(shell.story_view != null, "packed replay reader exists")
		shell.close_story_replay()
	state.data.current = "S03"; state.data.available = ["S03"]
	var context := STORIES.select_context("S03", state.data)
	expect(not context.reactions.is_empty(), "packed conditional reactions resolve from real catalog")
	if not context.reactions.is_empty():
		var reaction: Dictionary = STORIES.reactions()[context.reactions[0]]
		shell.open_page("event")
		await frames()
		shell._advance_story(reaction.lines[0].id)
		await frames()
		expect(shell.story_view.current_line_id == reaction.lines[0].id, "packed reaction is part of production reader/checkpoint flow")
		expect((shell.find_child("StoryWords", true, false) as RichTextLabel).text == reaction.lines[0].text, "packed reaction body is readable")
	shell.open_page("journal")
	var lore: Array = state.available_story_lore()
	expect(not lore.is_empty(), "packed lore available")
	if not lore.is_empty():
		expect(shell.open_story_lore(lore[0].id), "packed lore entry opens")
		await frames()
		expect(shell.find_child("lore_scroll", true, false) != null, "packed lore text presented")
	shell.queue_free(); await frames()
	print("CHRONICLE_STORY_PACK_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
