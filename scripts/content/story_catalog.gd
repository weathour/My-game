extends RefCounted
## Campaign story content is independent of the legacy quest/save system.
const PATH := "res://assets/data/chronicle/story_events.json"
const CONDITIONS := preload("res://scripts/content/story_conditions.gd")
const OPTIONAL_PATH := "res://assets/data/chronicle/character_events.json"
const REACTIONS_PATH := "res://assets/data/chronicle/story_reactions.json"
const LORE_PATH := "res://assets/data/chronicle/story_lore.json"
const MUSIC := preload("res://scripts/audio/music_catalog.gd")
const BACKGROUNDS := {
	"road": "res://assets/story/chronicle/road.png",
	"market": "res://assets/story/chronicle/market.png",
	"camp": "res://assets/story/chronicle/camp.png"
}
# Explicit nearest-position migrations for retired, non-equivalent lines.
# Narrative rationale: docs/story/baimen-20261030/前半剧情与资料来源.md.
const LEGACY_LINE_MAP := {
	"S03":{"s03_p07":"s03_new12", "s03_t07":"s03_new14"},
	"S04":{"s04_t03":"s04_new01", "s04_t04":"s04_new02", "s04_t05":"s04_anchor_01", "s04_t06":"s04_anchor_01", "s04_t07":"s04_anchor_01", "s04_t08":"s04_new02", "s04_t09":"s04_anchor_01", "s04_p07":"s04_anchor_01"},
	"F01":{"f01_02":"f01_anchor_01"}, "B06":{"b06_06":"b06_new01"},
	"S05":{"s05_p06":"s05_anchor_01", "s05_p07":"s05_new14"}, "S06":{"s06_05":"s06_new01"}
}
static var _events: Dictionary = {}
static var _catalogs: Dictionary = {}

static func events() -> Dictionary:
	if _events.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary: _events = parsed
	return _events.duplicate(true)

static func for_node(node: Dictionary) -> Dictionary:
	var id := str(node.get("id", ""))
	var event: Dictionary = events().get(id, {})
	if not event.is_empty(): return event
	# Unproduced route previews still have a safe, read-only presentation.
	return {"id":id, "title":str(node.get("name", "")), "location":"白门楼", "background":BACKGROUNDS.camp,
		"music":"camp_signal", "lines":[{"id":id + "_summary", "speaker":"", "text":str(node.get("summary", "")), "actors":[]}]}

static func has_event(id: String) -> bool:
	return events().has(id)

static func line_id(event: Dictionary, checkpoint: Dictionary = {}) -> String:
	var requested := str(checkpoint.get("line", "")) if checkpoint.get("event") == event.get("id") else ""
	if has_line(event, requested): return requested
	requested = str(LEGACY_LINE_MAP.get(str(event.get("id", "")), {}).get(requested, requested))
	for line: Dictionary in event.get("lines", []):
		if line.id == requested: return requested
	var lines: Array = event.get("lines", [])
	return "" if lines.is_empty() else str(lines[0].id)

static func has_line(event: Dictionary, id: String) -> bool:
	for line: Dictionary in event.get("lines", []):
		if line.get("id") == id: return true
	return false

static func _catalog(path: String) -> Dictionary:
	if not _catalogs.has(path):
		if not FileAccess.file_exists(path): return {}
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary: return {}
		_catalogs[path] = parsed
	return _catalogs[path].duplicate(true)

static func optional_events() -> Dictionary:
	return _catalog(OPTIONAL_PATH)

static func reactions() -> Dictionary:
	return _catalog(REACTIONS_PATH)

static func lore() -> Dictionary:
	return _catalog(LORE_PATH)

static func select_context(event_id: String, snapshot: Dictionary) -> Dictionary:
	var selected := {}
	var catalog := reactions()
	var ids := catalog.keys()
	ids.sort()
	for id in ids:
		var reaction: Dictionary = catalog[id]
		if reaction.get("event_id") != event_id or not CONDITIONS.matches(reaction.get("conditions", {}), snapshot, str(reaction.get("battle_id", ""))): continue
		var anchor: String = reaction.after_line
		if not selected.has(anchor) or int(reaction.get("priority", 0)) > int(catalog[selected[anchor]].get("priority", 0)):
			selected[anchor] = id
	var result: Array = selected.values()
	result.sort()
	return {"reactions":result}

static func resolved(event: Dictionary, context: Dictionary = {}) -> Dictionary:
	var result := event.duplicate(true)
	var output: Array = []
	var catalog := reactions()
	var anchors := {}
	for id in context.get("reactions", []):
		if not catalog.has(id): continue
		var reaction: Dictionary = catalog[id]
		if reaction.get("event_id") == event.get("id") and not anchors.has(reaction.after_line): anchors[reaction.after_line] = reaction
	for line in event.get("lines", []):
		output.append(line)
		if anchors.has(line.id): output.append_array(anchors[line.id].lines.duplicate(true))
	result.lines = output
	return result

static func validate() -> Array[String]:
	var errors: Array[String] = []
	var characters := {}
	var nodes := {}
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")): characters[person.id] = true
	for node in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/route.json")): nodes[node.id] = true
	for path in [PATH, OPTIONAL_PATH, REACTIONS_PATH, LORE_PATH]:
		if not FileAccess.file_exists(path) or not JSON.parse_string(FileAccess.get_file_as_string(path)) is Dictionary: errors.append("Story catalog must be a dictionary: " + path)
	var optional := optional_events()
	for id in optional:
		if events().has(id): errors.append("Optional ID overlaps main event: " + str(id))
	for catalog in [events(), optional]:
		for id in catalog:
			if not catalog[id] is Dictionary: errors.append("Invalid story: " + str(id)); continue
			var event: Dictionary = catalog[id]
			if event.get("id") != id or not _nonempty(event.get("title")) or not _nonempty(event.get("location")): errors.append("Invalid story identity: " + str(id))
			if not MUSIC.has_cue(str(event.get("music", ""))): errors.append("Unknown story music: " + str(id))
			if not ResourceLoader.exists(str(event.get("background", ""))): errors.append("Missing story background: " + str(id))
			errors.append_array(_validate_lines(event.get("lines"), str(id), characters))
			errors.append_array(CONDITIONS.validate(event.get("conditions", {}), characters, nodes, optional))
	var all_events := events()
	all_events.merge(optional)
	var line_ids := {}
	for id in all_events:
		if not all_events[id] is Dictionary: continue
		line_ids[id] = {}
		if all_events[id].get("lines") is Array:
			for line in all_events[id].lines:
				if line is Dictionary: line_ids[id][line.get("id", "")] = true
	var reaction_catalog := reactions()
	for id in reaction_catalog:
		var reaction: Variant = reaction_catalog[id]
		if not reaction is Dictionary: errors.append("Invalid reaction: " + str(id)); continue
		var event_id := str(reaction.get("event_id", ""))
		if reaction.get("id") != id or not reaction.get("event_id") is String or not _nonempty(reaction.get("after_line")) or not all_events.has(event_id) or not line_ids.get(event_id, {}).has(reaction.get("after_line")): errors.append("Invalid reaction anchor: " + str(id))
		if reaction.has("priority") and (typeof(reaction.priority) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(reaction.priority)) or reaction.priority != int(reaction.priority)): errors.append("Invalid priority: " + str(id))
		var conditions: Variant = reaction.get("conditions")
		errors.append_array(CONDITIONS.validate(conditions, characters, nodes, optional, true))
		if reaction.has("battle_id") and (not reaction.battle_id is String or not nodes.has(reaction.battle_id) or not str(reaction.battle_id).begins_with("B")): errors.append("Invalid battle: " + str(id))
		if conditions is Dictionary and conditions.has("battle_members_all") and not reaction.has("battle_id"): errors.append("Battle membership needs battle_id: " + str(id))
		errors.append_array(_validate_lines(reaction.get("lines"), str(id), characters))
		if event_id in line_ids and reaction.get("lines") is Array:
			for line in reaction.lines:
				if not line is Dictionary: continue
				if line_ids[event_id].has(line.get("id")): errors.append("Duplicate resolved line: " + str(id))
				line_ids[event_id][line.get("id", "")] = true
	var lore_catalog := lore()
	for id in lore_catalog:
		var entry: Variant = lore_catalog[id]
		if not entry is Dictionary: errors.append("Invalid lore: " + str(id)); continue
		if entry.get("id") != id or not _nonempty(entry.get("kind")) or not _nonempty(entry.get("title")) or not _nonempty(entry.get("text")): errors.append("Invalid lore identity: " + str(id))
		errors.append_array(CONDITIONS.validate(entry.get("conditions", {}), characters, nodes, optional))
	return errors

static func _nonempty(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()

static func _validate_lines(value: Variant, id: String, characters: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not value is Array or value.is_empty(): return ["Story has no lines: " + id]
	var seen := {}
	for line in value:
		if not line is Dictionary: errors.append("Invalid story line: " + id); continue
		var key := str(line.get("id", ""))
		if not _nonempty(line.get("id")) or seen.has(key) or not _nonempty(line.get("text")): errors.append("Invalid story line: " + id + "/" + key)
		seen[key] = true
		if not line.get("speaker", "") is String or (line.get("speaker", "") != "" and not characters.has(line.speaker)): errors.append("Unknown story speaker: " + id + "/" + key)
		if line.has("speaker_name") and not line.speaker_name is String: errors.append("Invalid speaker name: " + id + "/" + key)
		for field in ["music", "stinger"]:
			if line.has(field) and not MUSIC.has_cue(str(line[field])): errors.append("Unknown line music: " + id + "/" + key)
		if line.has("background") and not ResourceLoader.exists(str(line.background)): errors.append("Missing line background: " + id + "/" + key)
		if not line.get("actors", []) is Array: errors.append("Invalid actors: " + id + "/" + key); continue
		var cast := {}
		for actor in line.get("actors", []):
			if not actor is Dictionary: errors.append("Invalid actor: " + id + "/" + key); continue
			if not characters.has(actor.get("id")) or actor.get("slot") not in ["left", "center", "right"] or cast.has(actor.get("id")): errors.append("Invalid story actor: " + id + "/" + key)
			cast[actor.get("id")] = true
	return errors
