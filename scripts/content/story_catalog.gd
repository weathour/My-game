extends RefCounted
## Campaign story content is independent of the legacy quest/save system.
const PATH := "res://assets/data/chronicle/story_events.json"
const MUSIC := preload("res://scripts/audio/music_catalog.gd")
const BACKGROUNDS := {
	"road": "res://assets/story/chronicle/road.png",
	"market": "res://assets/story/chronicle/market.png",
	"camp": "res://assets/story/chronicle/camp.png"
}
static var _events: Dictionary = {}

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
	for line: Dictionary in event.get("lines", []):
		if line.id == requested: return requested
	var lines: Array = event.get("lines", [])
	return "" if lines.is_empty() else str(lines[0].id)

static func has_line(event: Dictionary, id: String) -> bool:
	for line: Dictionary in event.get("lines", []):
		if line.get("id") == id: return true
	return false

static func validate() -> Array[String]:
	var errors: Array[String] = []
	var characters: Dictionary = {}
	for person: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")):
		characters[person.id] = true
	for id: String in events():
		var event: Dictionary = events()[id]
		if event.get("id") != id or str(event.get("title", "")).is_empty() or str(event.get("location", "")).is_empty():
			errors.append("Invalid story identity: " + id)
		if not MUSIC.has_cue(str(event.get("music", ""))): errors.append("Unknown story music: " + id)
		if not FileAccess.file_exists(str(event.get("background", ""))): errors.append("Missing story background: " + id)
		var seen: Dictionary = {}
		var lines: Array = event.get("lines", [])
		if lines.is_empty(): errors.append("Story has no lines: " + id)
		for line: Dictionary in lines:
			for field in ["music", "stinger"]:
				if line.has(field) and not MUSIC.has_cue(str(line[field])): errors.append("Unknown line music: " + id + "/" + str(line.get("id", "")))
			var key := str(line.get("id", ""))
			if key.is_empty() or seen.has(key) or str(line.get("text", "")).is_empty(): errors.append("Invalid story line: " + id + "/" + key)
			seen[key] = true
			if line.get("speaker", "") != "" and not characters.has(line.speaker): errors.append("Unknown story speaker: " + id + "/" + key)
			var cast: Dictionary = {}
			for actor: Dictionary in line.get("actors", []):
				if not characters.has(actor.get("id")) or actor.get("slot") not in ["left", "center", "right"] or cast.has(actor.get("id")):
					errors.append("Invalid story actor: " + id + "/" + key)
				cast[actor.get("id")] = true
	return errors
