extends SceneTree
## Content contract, strict predicates, durable optional reads and frozen reactions.
const CAMPAIGN := preload("res://scripts/campaign/campaign_service.gd")
const STORIES := preload("res://scripts/content/story_catalog.gd")
const CONDITIONS := preload("res://scripts/content/story_conditions.gd")
const REQUIRED := ["S01","S02","S03","S04","S05","S06","S07","S08","S09","S10","S11","S12","S13","S14","F01","F02","F03","F04","B06","B15","B16","B17"]
var checks := 0
var failures := 0
var report_path := ""

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
	call_deferred("run")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func fresh(label: String) -> RefCounted:
	var state := CAMPAIGN.new()
	state.directory = "user://story_content/" + label + "_" + str(Time.get_ticks_usec())
	return state

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated save location")
	if failures: quit(1); return
	var errors := STORIES.validate()
	expect(errors.is_empty(), "all story content validates: " + str(errors))
	for id in REQUIRED: expect(STORIES.has_event(id), "authored required node " + id)
	expect(STORIES.events().size() == REQUIRED.size(), "only established route scenes")
	expect(STORIES.optional_events().size() == 32, "32 complete independent character stories")
	expect(STORIES.reactions().size() == 48, "48 conditional reactions")
	expect(not STORIES.lore().is_empty(), "read-only lore authored")
	malformed_content()
	reaction_validation_and_ordering()
	predicates()
	optional_transactions()
	multiple_optional_positions()
	frozen_contexts()
	battle_entry_context()
	legacy_and_corruption()
	line_migrations()
	chapter_reachability()
	print("CHRONICLE_STORY_CONTENT_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func predicates() -> void:
	var state := fresh("predicates")
	var optional := STORIES.optional_events()
	for malformed in [null, [], {"party_all":["JIA"]}, {"owned_all":"F11"}, {"owned_all":[1]}, {"alive_all":["missing"]}, {"completed_all":["CE01"]}, {"event_read_all":["S02"]}]:
		expect(not CONDITIONS.validate(malformed, state.characters, state.nodes, optional).is_empty(), "reject malformed/unknown condition " + str(malformed))
	expect(CONDITIONS.matches({}, state.data), "empty predicates pass")
	state.data.pool.append("F11")
	expect(not CONDITIONS.matches({"owned_all":["F11"]}, state.data), "pool is not ownership")
	state.data.owned.F11 = state.new_character("F11")
	expect(CONDITIONS.matches({"owned_all":["F11"], "alive_all":["F11"]}, state.data), "acquired alive character matches")
	state.data.owned.F11.dead = true
	expect(CONDITIONS.matches({"owned_all":["F11"]}, state.data) and not CONDITIONS.matches({"alive_all":["F11"]}, state.data), "dead owned remains acquired but cannot speak")
	expect(not CONDITIONS.matches({"completed_all":["B15"]}, state.data), "current trigger is not assumed completed")
	state.data.completed = ["S02"]
	expect(not CONDITIONS.matches({"owned_all":["F11"], "completed_all":["S03"]}, state.data), "all predicate fields AND")
	expect(not CONDITIONS.matches({"battle_members_all":["F11"]}, state.data, "B06"), "unknown historical battle fails membership")
	state.data.battle_story_contexts.B06 = ["JIA","F11"]
	expect(CONDITIONS.matches({"battle_members_all":["F11"]}, state.data, "B06"), "only actual historical members match")
	expect(not CONDITIONS.matches({"battle_members_all":["F03"]}, state.data, "B06"), "unconfigured owned is not battle participant")

func unlock_optional(state: RefCounted) -> String:
	# Synthetic library fixture, not a claim that all characters occur on one route.
	for id in state.characters:
		if id in state.CONTENT.IDS and not state.data.owned.has(id): state.data.owned[id] = state.new_character(id)
	state.data.completed = state.nodes.keys()
	var ids: Array = state.available_optional_stories()
	return "" if ids.is_empty() else str(ids[0])

func optional_transactions() -> void:
	var state := fresh("optional")
	var id := unlock_optional(state)
	expect(not id.is_empty(), "optional stories discoverable from actual ownership/gates")
	if id.is_empty(): return
	var event: Dictionary = state.story_event(id)
	var before: Dictionary = state.data.duplicate(true)
	var directory: String = state.directory
	state.directory = "/proc/story-optional-read-only"
	print("EXPECTED_FAULT_INJECTION: optional first entry write rejected")
	expect(not state.save_optional_story_checkpoint(id, event.lines[0].id) and state.data == before, "first checkpoint failure rolls back context and checkpoint")
	state.directory = directory
	expect(state.save_optional_story_checkpoint(id, event.lines[0].id), "first optional entry persists")
	before = state.data.duplicate(true)
	state.directory = "/proc/story-optional-read-only"
	print("EXPECTED_FAULT_INJECTION: optional checkpoint write rejected")
	expect(not state.save_optional_story_checkpoint(id, event.lines[1].id) and state.data == before, "failed next line keeps exact checkpoint")
	print("EXPECTED_FAULT_INJECTION: optional completion write rejected")
	expect(not state.complete_optional_story(id) and state.data == before, "failed finish preserves unread and allows retry")
	state.directory = directory
	expect(state.save_optional_story_checkpoint(id, event.lines[1].id), "next line retry")
	var reload := fresh("reload")
	reload.directory = directory
	expect(reload.load_slot("auto") and reload.data.optional_story_checkpoints[id] == event.lines[1].id, "optional breakpoint survives reload")
	before = reload.data.duplicate(true)
	expect(reload.complete_optional_story(id) and id in reload.read_optional_stories() and reload.data.optional_story_checkpoints.is_empty(), "finish marks exactly one optional read")
	var after: Dictionary = reload.data.duplicate(true)
	for key in ["optional_story_read", "optional_story_checkpoints"]:
		before.erase(key); after.erase(key)
	expect(after == before, "optional completion has no rewards/progression/log effects")
	before = reload.data.duplicate(true)
	expect(not reload.complete_optional_story(id) and not reload.save_optional_story_checkpoint(id, event.lines[0].id) and reload.data == before, "finished optional rejects duplicate mutation")
	state.in_battle = true
	expect(not state.can_read_optional_story() and not state.complete_optional_story(id), "battle blocks first optional reading")
	state.in_battle = false
	state.data.deferred_reward = {"id":"B06", "extra":false}
	expect(not state.can_read_optional_story(), "mandatory postbattle story blocks optional entry")

func frozen_contexts() -> void:
	var state := fresh("frozen")
	state.data.current = "S03"
	state.data.available = ["S03"]
	var first: Dictionary = state.story_event("S03")
	expect(state.save_story_checkpoint("S03", first.lines[0].id), "main first entry freezes reaction IDs with checkpoint")
	var context: Dictionary = state.data.story_contexts.S03.duplicate(true)
	var directory: String = state.directory
	unlock_optional(state)
	expect(state.data.story_contexts.S03 == context and state.story_event("S03").lines == first.lines, "later ownership/gates do not reveal unseen reactions")
	expect(state.story_event("S03", true).lines == first.lines, "replay uses same frozen choices")
	expect(state.save_slot("auto"), "persist later inventory with original frozen choices")
	var reload := fresh("frozen_reload")
	reload.directory = directory
	expect(reload.load_slot("auto") and reload.story_event("S03").lines == first.lines, "reload preserves historical choice")
	state = fresh("eligible")
	unlock_optional(state)
	state.data.current = "S03"; state.data.available = ["S03"]
	var selected := STORIES.select_context("S03", state.data)
	expect(selected.reactions.size() == 1, "one highest-priority reaction per S03 anchor")
	var resolved: Dictionary = state.story_event("S03")
	expect(resolved.lines.size() > STORIES.events().S03.lines.size(), "selected reaction inserted into normal flat event")
	var catalog := STORIES.reactions()
	var winner: String = selected.reactions[0]
	for id in catalog:
		if catalog[id].event_id == "S03" and CONDITIONS.matches(catalog[id].conditions, state.data, str(catalog[id].get("battle_id", ""))):
			expect(int(catalog[winner].get("priority", 0)) > int(catalog[id].get("priority", 0)) or (int(catalog[winner].get("priority", 0)) == int(catalog[id].get("priority", 0)) and winner <= id), "priority then lexical reaction ordering " + id)
	state.data.story_contexts.clear()
	expect(state.story_event("S03", true).lines == STORIES.events().S03.lines, "completed old scene without context replays base only")

func battle_entry_context() -> void:
	for id in ["B06", "B15", "B16", "B17"]:
		var state := fresh(id)
		state.data.current = id; state.data.available = [id]
		state.data.owned.F11 = state.new_character("F11")
		state.data.party = ["F11", ""]
		var request: Dictionary = state.start_battle()
		expect(not request.is_empty(), "actual entry request " + id)
		if request.is_empty(): continue
		request.characters.F11.hp = 0.0; request.characters.F11.dead = true
		var victory := {"attempt_id":request.attempt_id, "outcome":"victory", "characters":request.characters}
		var directory: String = state.directory
		state.directory = "/proc/story-battle-read-only"
		print("EXPECTED_FAULT_INJECTION: victory context write rejected " + id)
		expect(not state.complete_battle(victory) and state.in_battle and state.data.battle_story_contexts.is_empty(), "victory rollback clears uncommitted battle context " + id)
		state.directory = directory
		expect(state.complete_battle(victory), "victory context retry " + id)
		expect(state.data.battle_story_contexts[id] == ["JIA","F11"] and "F11" not in state.data.party, "actual entrants frozen before dead auxiliary removal " + id)
		expect(id not in state.data.completed and state.awaiting_battle_story(), "postbattle trigger not completed " + id)
		expect(CONDITIONS.matches({"battle_members_all":["F11"]}, state.data, id) and not CONDITIONS.matches({"alive_all":["F11"]}, state.data), "battle membership and present speech separated " + id)

func legacy_and_corruption() -> void:
	var state := fresh("old")
	var old: Dictionary = state.data.duplicate(true)
	for key in ["optional_story_read", "optional_story_checkpoints", "story_contexts", "battle_story_contexts"]: old.erase(key)
	expect(state.valid(old), "old schema without additive fields valid")
	DirAccess.make_dir_recursive_absolute(state.directory)
	var file := FileAccess.open(state.directory.path_join("1.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(old)); file.close()
	expect(state.load_slot("1") and state.data.optional_story_read.is_empty() and state.data.story_contexts.is_empty() and state.data.battle_story_contexts.is_empty(), "old save defaults empty without inferred reads/participants")
	var before: Dictionary = state.data.duplicate(true)
	for field in ["optional_story_read", "optional_story_checkpoints", "story_contexts", "battle_story_contexts"]:
		var corrupt := before.duplicate(true)
		corrupt[field] = "bad"
		expect(not state.valid(corrupt), "reject corrupted additive type " + field)
	for patch in [{"optional_story_read":["missing"]}, {"optional_story_checkpoints":{"missing":"x"}}, {"story_contexts":{"S03":{"reactions":["missing"]}}}, {"battle_story_contexts":{"B06":["missing"]}}]:
		var corrupt := before.duplicate(true); corrupt.merge(patch, true)
		expect(not state.valid(corrupt), "reject corrupted additive IDs " + str(patch))
	expect(state.save_slot("2") and state.save_slot("2"), "known-good backup created")
	var corrupt := before.duplicate(true); corrupt.optional_story_read = ["missing"]
	file = FileAccess.open(state.directory.path_join("2.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(corrupt)); file.close()
	expect(state.read_slot("2") == before, "corrupt additive data falls back to known-good backup")

func line_migrations() -> void:
	for id in STORIES.LEGACY_LINE_MAP:
		var event: Dictionary = STORIES.events()[id]
		for old_line in STORIES.LEGACY_LINE_MAP[id]:
			var target: String = STORIES.LEGACY_LINE_MAP[id][old_line]
			expect(not STORIES.has_line(event, old_line) and STORIES.has_line(event, target), "retired line maps to authored nearby position " + old_line)
			expect(STORIES.line_id(event, {"event":id,"line":old_line}) == target, "old breakpoint recovers explicit nearest position " + old_line)
	var state := fresh("migration")
	unlock_optional(state)
	state.data.current = "S03"; state.data.available = ["S03"]
	state.data.story_checkpoint = {"event":"S03","line":"s03_t07"}
	var event: Dictionary = state.story_event("S03")
	expect(event.lines == STORIES.events().S03.lines, "pre-feature in-progress checkpoint cannot reveal current-inventory reactions")
	var target := STORIES.line_id(event, state.data.story_checkpoint)
	expect(state.save_story_checkpoint("S03", target) and state.data.story_checkpoint == {"event":"S03","line":"s03_new14"} and state.data.story_checkpoint.size() == 2, "migrated checkpoint commits same two-field shape")
	expect(state.data.story_contexts.S03.reactions.is_empty(), "legacy in-progress base-only choice persists")

func multiple_optional_positions() -> void:
	var state := fresh("multiple_optional")
	unlock_optional(state)
	var ids: Array = state.available_optional_stories()
	expect(ids.size() >= 2, "multiple optional stories can be independently resumed")
	if ids.size() < 2: return
	var a: String = ids[0]; var b: String = ids[1]
	var a_line: String = state.story_event(a).lines[1].id
	var b_line: String = state.story_event(b).lines[0].id
	expect(state.save_optional_story_checkpoint(a, a_line) and state.save_optional_story_checkpoint(b, b_line), "A midway then B persists both")
	expect(state.data.optional_story_checkpoints == {a:a_line,b:b_line}, "no optional entry overwrites another breakpoint")
	var reload := fresh("multiple_reload"); reload.directory = state.directory
	expect(reload.load_slot("auto") and reload.data.optional_story_checkpoints == {a:a_line,b:b_line}, "both positions survive reload")
	expect(reload.complete_optional_story(b) and reload.data.optional_story_checkpoints == {a:a_line}, "finishing B preserves unfinished A")
	var legacy: Dictionary = state.data.duplicate(true)
	legacy.erase("optional_story_checkpoints")
	legacy.optional_story_checkpoint = {"event":a,"line":a_line}
	expect(state.valid(legacy), "intermediate singular optional breakpoint remains loadable")
	var file := FileAccess.open(state.directory.path_join("1.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy)); file.close()
	expect(state.load_slot("1") and state.data.optional_story_checkpoints == {a:a_line} and not state.data.has("optional_story_checkpoint"), "singular breakpoint migrates to per-event dictionary")
	for malformed in [{"event":a}, {"event":a,"line":"missing"}, {"event":"missing","line":a_line}, []]:
		var corrupt := legacy.duplicate(true); corrupt.optional_story_checkpoint = malformed
		expect(not state.valid(corrupt), "malformed singular checkpoint remains rejected " + str(malformed))

func malformed_content() -> void:
	var original: Dictionary = STORIES._events.duplicate(true)
	for value in [false, null, [], 7, "bad"]:
		STORIES._events = {"S01":value}
		expect(not STORIES.validate().is_empty(), "malformed event body rejected without validator exception " + str(value))
	STORIES._events = original
	var state := fresh("malformed_lines")
	for value in [null, false, [], [false], [{"id":[],"text":3,"actors":false}], [{"id":"x","text":"x","actors":[false]}]]:
		expect(not STORIES._validate_lines(value, "fixture", state.characters).is_empty(), "malformed line fields rejected " + str(value))

func reaction_validation_and_ordering() -> void:
	var state := fresh("reaction_schema")
	var original := STORIES.reactions()
	var anchor: String = STORIES.events().S01.lines[0].id
	var base := {"id":"R_A","event_id":"S01","after_line":anchor,"conditions":{},"priority":0,"lines":[{"id":"r_probe_a","text":"fixture","speaker":"","actors":[]}]}
	var b := base.duplicate(true); b.id = "R_B"; b.lines[0].id = "r_probe_b"
	var high := base.duplicate(true); high.id = "R_HIGH"; high.priority = 2; high.lines[0].id = "r_probe_high"
	STORIES._catalogs[STORIES.REACTIONS_PATH] = {"R_B":b,"R_A":base}
	expect(STORIES.select_context("S01", state.data).reactions == ["R_A"], "equal priority resolves lexical ID independently of source order")
	STORIES._catalogs[STORIES.REACTIONS_PATH]["R_HIGH"] = high
	expect(STORIES.select_context("S01", state.data).reactions == ["R_HIGH"], "higher priority wins exactly one reaction at anchor")
	for patch in [{"priority":NAN}, {"priority":INF}, {"priority":[]}, {"priority":{}}, {"priority":1.5}, {"after_line":false}, {"after_line":[]}, {"after_line":{}}, {"event_id":false}, {"conditions":null}, {"lines":false}]:
		var bad := base.duplicate(true); bad.merge(patch, true)
		STORIES._catalogs[STORIES.REACTIONS_PATH] = {"R_A":bad}
		var errors := STORIES.validate()
		expect(not errors.is_empty(), "malformed reaction rejected without exception " + str(patch))
	STORIES._catalogs[STORIES.REACTIONS_PATH] = {"R_A":false}
	expect(not STORIES.validate().is_empty(), "non-dictionary reaction body rejected")
	STORIES._catalogs[STORIES.REACTIONS_PATH] = original

func chapter_reachability() -> void:
	var state := fresh("reachability")
	var optional := STORIES.optional_events()
	var reactions := STORIES.reactions()
	var routes: Array = []
	collect_routes(state.nodes, "S01", [], routes)
	var timelines: Array = []
	for route in routes: timelines.append(path_timeline(route, state))
	var report := {"route_count":routes.size(), "optional_unreachable":[], "reaction_unreachable":[], "shadowed":[]}
	expect(not routes.is_empty(), "complete chapter routes enumerated")
	for id in optional:
		var dependencies: Array = optional[id].get("conditions", {}).get("event_read_all", [])
		expect(id not in dependencies, "optional story cannot require itself " + id)
		var gates := optional_gates(id, optional, [])
		expect("__cycle__" not in gates, "optional dependency graph acyclic " + id)
		var reachable := false
		for route in routes:
			if contains_all(route, gates): reachable = true; break
		expect(reachable, "optional node/dependency gates fit a complete route " + id)
		if not reachable: report.optional_unreachable.append(id)
	for id in reactions:
		var reaction: Dictionary = reactions[id]
		var conditions: Dictionary = reaction.conditions
		var gates: Array = conditions.get("completed_all", []).duplicate()
		for dependency in conditions.get("event_read_all", []): gates.append_array(optional_gates(dependency, optional, []))
		var required: Array = conditions.get("owned_all", []).duplicate()
		required.append_array(conditions.get("alive_all", []))
		var reachable := false
		for timeline in timelines:
			var at: Dictionary = timeline.get(reaction.event_id, timeline.get("__end__", {}) if optional.has(reaction.event_id) else {})
			if at.is_empty() or not contains_all(at.completed, gates) or not contains_all(at.owned, required): continue
			var members: Array = conditions.get("battle_members_all", [])
			if not members.is_empty() and not contains_all(at.battles.get(reaction.get("battle_id", ""), []), members): continue
			reachable = true; break
		expect(reachable, "reaction gates and actual acquisition possible at first entry " + id)
		if not reachable: report.reaction_unreachable.append(id)
		for earlier_id in reactions:
			if earlier_id == id: continue
			var earlier: Dictionary = reactions[earlier_id]
			if earlier.event_id != reaction.event_id or earlier.after_line != reaction.after_line: continue
			var outranks: bool = int(earlier.get("priority", 0)) > int(reaction.get("priority", 0)) or (int(earlier.get("priority", 0)) == int(reaction.get("priority", 0)) and earlier_id < id)
			if outranks and conditions_imply(reaction, earlier): report.shadowed.append({"hidden":id,"by":earlier_id})
	expect(report.shadowed.is_empty(), "no reaction provably hidden by a prior matching condition: " + str(report.shadowed))
	print("STORY_REACHABILITY ", JSON.stringify(report))
	if not report_path.is_empty():
		DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "  ") + "\n"); file.close()

func collect_routes(nodes: Dictionary, id: String, prefix: Array, output: Array) -> void:
	if id in prefix or not nodes.has(id): return
	var path := prefix.duplicate(); path.append(id)
	if nodes[id].next.is_empty(): output.append(path); return
	for next_id in nodes[id].next: collect_routes(nodes, next_id, path, output)

func path_timeline(path: Array, state: RefCounted) -> Dictionary:
	var result := {}
	var owned: Array = ["JIA"]
	var pool: Array = state.INITIAL_POOL.duplicate()
	var completed: Array = []
	var battles := {}
	for id in path:
		var kind: String = state.nodes[id].kind
		if kind in ["battle", "elite", "boss"]: battles[id] = owned.duplicate()
		result[id] = {"owned":owned.duplicate(), "completed":completed.duplicate(), "battles":battles.duplicate(true)}
		for person in state.UNLOCKS.get(id, []):
			if person not in pool: pool.append(person)
		if id == "S02" and "F11" not in owned: owned.append("F11")
		if (kind in ["battle", "elite", "boss"] and id != "B18") or id == "S14":
			for person in pool:
				if id == "B01" and person == "F11": continue
				if person not in owned: owned.append(person)
		completed.append(id)
	result["__end__"] = {"owned":owned,"completed":completed,"battles":battles}
	return result

func optional_gates(id: String, optional: Dictionary, visited: Array) -> Array:
	if id in visited or not optional.has(id): return ["__cycle__"]
	var next := visited.duplicate(); next.append(id)
	var conditions: Dictionary = optional[id].get("conditions", {})
	var result: Array = conditions.get("completed_all", []).duplicate()
	for dependency in conditions.get("event_read_all", []): result.append_array(optional_gates(dependency, optional, next))
	return result

func contains_all(haystack: Array, needles: Array) -> bool:
	for value in needles:
		if value not in haystack: return false
	return true

func conditions_imply(stronger: Dictionary, weaker: Dictionary) -> bool:
	var a: Dictionary = stronger.conditions
	var b: Dictionary = weaker.conditions
	for key in ["alive_all", "completed_all", "event_read_all"]:
		if not contains_all(a.get(key, []), b.get(key, [])): return false
	var a_owned: Array = a.get("owned_all", []).duplicate()
	a_owned.append_array(a.get("alive_all", []))
	if not contains_all(a_owned, b.get("owned_all", [])): return false
	if not b.get("battle_members_all", []).is_empty():
		if stronger.get("battle_id", "") != weaker.get("battle_id", "") or not contains_all(a.get("battle_members_all", []), b.battle_members_all): return false
	return true
