extends SceneTree
## Derive the costume boundary independently from the authored route, then
## exercise real schema-1 IO, battle retry and the production replay reader.
const CAMPAIGN := preload("res://scripts/campaign/campaign_service.gd")
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
const ART := preload("res://scripts/ui/chronicle/battle_art.gd")
const SETTINGS := preload("res://scripts/shared/settings.gd")
const APPEARANCE_PATH := "res://scripts/ui/chronicle/jia_appearance.gd"
var checks := 0
var failures := 0
var appearance
var state: RefCounted
var route: Dictionary = {}
var campaign_nodes: Dictionary = {}
var campaign_stories: Dictionary = {}
var viewport: SubViewport
var shell: Control

func _init() -> void: call_deferred("run")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func frames(count: int = 3) -> void:
	for index in count: await process_frame

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated campaign IO")
	if failures: quit(1); return
	appearance = load(APPEARANCE_PATH)
	expect(appearance != null, "pure appearance helper exists")
	if appearance == null: quit(1); return
	for node in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/route.json")):
		route[node.id] = node
	var stories: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/story_events.json"))
	expect(route.S10.next == ["S11"] and route.S11.kind == "event", "report and cooperation remain story nodes")
	expect(route.S11.next == ["B13","B14"], "authored first Cao battles follow S11 on either branch")
	expect(stories.has("S10") and stories.has("S11") and route.B13.kind == "battle" and route.B14.kind == "battle", "boundary cross-checks authored story and battle types")
	# Graph reachability is an independent oracle: no numeric-ID threshold or
	# copied implementation list defines which subsequent nodes retain the form.
	var pending: Array = route.S11.next.duplicate()
	while not pending.is_empty():
		var id: String = str(pending.pop_front())
		if campaign_nodes.has(id): continue
		campaign_nodes[id] = true
		pending.append_array(route[id].next)
	expect(campaign_nodes.has("S14") and campaign_nodes.has("F03") and not campaign_nodes.has("S11"), "both combat branches lead through recovery and chapter end")
	for id in stories:
		var expected := "campaign" if campaign_nodes.has(id) else "common"
		expect(appearance.for_story(stories[id]) == expected, "authored main story gate " + id)
		campaign_stories[id] = campaign_nodes.has(id)
	var optional: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/character_events.json"))
	for id in optional:
		var historical_gate: Array = optional[id].get("conditions",{}).get("completed_all",[])
		expect(historical_gate.size() == 1 and route.has(historical_gate[0]), "optional scene has one identifiable historical route gate " + id)
		var campaign: bool = historical_gate.size() == 1 and campaign_nodes.has(historical_gate[0])
		var story_form := "campaign" if campaign else "common"
		if historical_gate.size() == 1 and historical_gate[0] in ["B18","S14"]: story_form = "lord_formal"
		if id == "CE23": story_form = "lord_casual"
		campaign_stories[id] = campaign
		expect(appearance.for_story(optional[id]) == story_form, "optional replay follows its authored gate " + id)
	for fixture in [
		{"conditions":{"completed_any":["B01","B13"]},"expected":"common"},
		{"conditions":{"completed_any":["B13","B14"]},"expected":"campaign"},
		{"conditions":{"completed_any":[]},"expected":"common"},
		{"conditions":{"completed_all":["B13"],"completed_any":["B01","B14"]},"expected":"campaign"},
	]:
		var event := {"id":"synthetic-optional-gate","conditions":fixture.conditions}
		var unchanged := event.duplicate(true)
		expect(appearance.for_story(event) == fixture.expected and event == unchanged, "optional AND/OR gate semantics "+str(fixture.conditions))
	expect(appearance.for_story({"id":"S11","conditions":{"completed_all":["B13"]}}) == "common", "known route scene retains its own boundary before optional fallback")
	state = CAMPAIGN.new()
	state.directory = "user://jia_campaign_progression_" + str(Time.get_ticks_usec())
	var empty: Dictionary = state.data.duplicate(true)
	for id in route:
		var expected := "campaign" if campaign_nodes.has(id) else "common"
		expect(appearance.for_node(id) == expected, "route-derived node appearance " + id)
		var data := empty.duplicate(true)
		data.current = id
		data.available = route.keys()
		var before := data.duplicate(true)
		expect(appearance.for_campaign(data) == expected, "current old-save node " + id)
		expect(data == before and data.schema == 1, "appearance derivation never mutates schema/data " + id)
		if route[id].kind in ["battle","elite","boss"]:
			expect(appearance.for_battle({"node":route[id]}) == expected, "battle request derives its actual node " + id)
	for id in ["B01","B12","S10","S11"]:
		var data := empty.duplicate(true)
		data.current = id
		data.available = ["B13","B14","B18","S14"]
		data.completed = ["S01","B12","S10"]
		expect(appearance.for_campaign(data) == "common", "future available never unlocks early " + id)
		data.completed.append("S11")
		expect(appearance.for_campaign(data) == "common", "cooperation story completion alone never unlocks " + id)
	for id in campaign_nodes:
		var data := empty.duplicate(true)
		data.current = "S01"
		data.completed = [id]
		expect(appearance.for_campaign(data) == ("lord_formal" if id == "B18" else "campaign"), "historical completed phase selects its exact approved form " + id)
	# Backwards-compatible optional context changes JIA alone.
	for id in state.characters:
		if id == "JIA": continue
		expect(ART.actor(id,"campaign") == ART.actor(id,"common"), "companion actor unchanged " + id)
		expect(ART.portrait(id,"campaign") == ART.portrait(id,"common"), "companion portrait unchanged " + id)
	for id in ["B13","B14"]:
		state.data = empty.duplicate(true)
		state.data.current = id
		state.data.available = [id]
		state.data.completed = ["S10","S11"]
		var keys_before: Array = state.data.keys()
		expect(state.valid(state.data) and state.save_slot("1"), "schema-1 old save accepted " + id)
		var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(state.directory.path_join("1.json")))
		expect(disk.keys().size() == keys_before.size() and disk.schema == 1, "no appearance flag or schema added " + id)
		expect(state.load_slot("1") and appearance.for_campaign(state.data) == "campaign", "old-save first Cao battle enters campaign " + id)
		var saved: Dictionary = state.data.duplicate(true)
		var first: Dictionary = state.start_battle()
		expect(not first.is_empty() and appearance.for_battle(first) == "campaign", "first entry has campaign form " + id)
		expect(not state.complete_battle({"attempt_id":first.attempt_id,"outcome":"failed","characters":first.characters}), "failed attempt cannot advance " + id)
		state.abandon_battle()
		expect(state.data == saved and appearance.for_campaign(state.data) == "campaign", "abandon restores exact save and campaign form " + id)
		var retry: Dictionary = state.start_battle()
		expect(appearance.for_battle(retry) == "campaign" and retry.characters == first.characters and retry.equipment == first.equipment, "retry retains visual context without changing combat request " + id)
		state.abandon_battle()
	# Current selection may point backwards in legacy data; completed phase is
	# enough to retain campaign form without consulting available or new flags.
	state.data = empty.duplicate(true)
	state.data.current = "S01"
	state.data.available = ["S01"]
	state.data.completed = ["B14"]
	expect(state.save_slot("2") and state.load_slot("2") and appearance.for_campaign(state.data) == "campaign", "completed old-save fallback survives real IO")
	await check_historical_replay(empty)
	print("JIA_CAMPAIGN_PROGRESSION_SMOKE ","PASS" if failures == 0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)

func texture_path(texture: Texture2D) -> String:
	while texture is AtlasTexture: texture = texture.atlas
	return texture.resource_path if texture != null else ""

func file_snapshot() -> Dictionary:
	var result := {}
	for name in DirAccess.get_files_at(state.directory):
		var path: String = state.directory.path_join(name)
		result[name] = {"bytes":FileAccess.get_file_as_bytes(path),"modified":FileAccess.get_modified_time(path)}
	return result

func check_historical_replay(empty: Dictionary) -> void:
	state.data = empty.duplicate(true)
	state.data.current = "B18"
	state.data.available = ["B18"]
	state.data.completed = ["S01","S10","S11","B13","B15","S12","B16","S13","B17"]
	state.data.optional_story_read = ["CE01","CE25"]
	var old_motion := SETTINGS.comfort_enabled("reduced_motion")
	SETTINGS.save_comfort("reduced_motion",true)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	root.add_child(viewport)
	shell = SHELL.instantiate()
	shell.session = state
	viewport.add_child(shell)
	await frames(5)
	var late: Dictionary = state.data.duplicate(true)
	for context in ["common","campaign"]:
		state.data = late.duplicate(true)
		if context == "common":
			state.data.current = "B12"
			state.data.completed = ["S01","S10","S11"]
		for page in ["roster","preparation"]:
			shell.open_page(page)
			await frames()
			var card: Button = shell.find_child("character_JIA" if page == "roster" else "prep_member_0",true,false)
			expect(card != null, "actual campaign menu exposes protagonist card "+page+context)
			if card != null:
				expect(card.appearance == context and texture_path(card.portrait).to_lower().contains("jia-campaign") == (context == "campaign"), "card follows current campaign context "+page+context)
				expect(card._payload().is_empty(), "protagonist stays fixed rather than becoming draggable "+page+context)
		shell.inspect_character("JIA")
		await frames()
		expect(is_instance_valid(shell.character_sheet) and texture_path(shell.character_sheet.portrait.texture).to_lower().contains("jia-campaign") == (context == "campaign"), "character sheet follows campaign appearance "+context)
		shell.close_character_sheet(false)
		await frames()
	state.data = late
	shell.open_page("journal")
	var data_before: Dictionary = state.data.duplicate(true)
	var files_before := file_snapshot()
	for id in ["S01","S10","S11","S12","S13","CE01","CE25"]:
		expect(shell.open_story_replay(id,"journal"), "real replay opens historical scene " + id)
		await frames()
		var event: Dictionary = state.story_event(id,true)
		var line := ""
		for item in event.get("lines",[]):
			for actor in item.get("actors",[]):
				if actor.get("id","") == "JIA": line = str(item.id); break
			if not line.is_empty(): break
		expect(not line.is_empty(), "authored historical scene includes Jia " + id)
		if not line.is_empty():
			shell.story_view.show_line(line)
			await frames()
			var portrait: TextureRect = shell.story_view.find_child("StoryActor_JIA",true,false)
			expect(portrait != null and portrait.texture != null, "reader actually renders Jia " + id)
			if portrait != null and portrait.texture != null:
				var campaign: bool = texture_path(portrait.texture).to_lower().contains("jia-campaign")
				expect(campaign == bool(campaign_stories[id]), "replay texture follows historical event, not late current save " + id)
		shell.close_story_replay()
		await frames()
	expect(state.data == data_before and file_snapshot() == files_before and not state.in_battle, "historical appearance never writes campaign or save files")
	shell.queue_free()
	await frames()
	viewport.queue_free()
	await frames()
	await create_timer(.3).timeout
	SETTINGS.save_comfort("reduced_motion",old_motion)
