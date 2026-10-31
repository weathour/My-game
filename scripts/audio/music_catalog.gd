extends RefCounted
## Current campaign music catalog. Playback routing is owned by ChronicleMusic.
const MANIFEST := "res://assets/data/audio/music_catalog.json"
static var _chapter: Dictionary = {}
static var _loaded := false

static func _load_chapter() -> void:
	if _loaded: return
	_loaded = true
	if not FileAccess.file_exists(MANIFEST): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not parsed is Dictionary: return
	for entry: Dictionary in parsed.get("cues", []):
		var id := str(entry.get("id", ""))
		if not id.is_empty(): _chapter[id] = entry.duplicate(true)

static func chapter_cues() -> Array[String]:
	_load_chapter()
	var result: Array[String] = []
	for id: String in _chapter:
		if ResourceLoader.exists(path(id)): result.append(id)
	return result

static func info(cue: String) -> Dictionary:
	_load_chapter()
	return _chapter.get(cue, {}).duplicate(true)

static func has_cue(cue: String) -> bool:
	_load_chapter()
	return _chapter.has(cue)

static func path(cue: String) -> String:
	return str(info(cue).get("path", ""))

static func is_one_shot(cue: String) -> bool:
	return has_cue(cue) and not bool(info(cue).get("loop", true))

static func same_phase_family(from: String, to: String) -> bool:
	var a := info(from)
	var b := info(to)
	var family := str(a.get("phase_family", ""))
	return not family.is_empty() and family == str(b.get("phase_family", "")) and a.get("bpm") == b.get("bpm") and a.get("beats") == b.get("beats") and bool(a.get("loop", false)) and bool(b.get("loop", false))
