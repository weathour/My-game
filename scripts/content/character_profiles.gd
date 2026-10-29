extends RefCounted
## Character identity and prose. Progression continues to use stable card IDs.
const PATH := "res://assets/data/chronicle/character_profiles.json"
static var _profiles: Dictionary = {}

static func all() -> Dictionary:
	if _profiles.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary: _profiles = parsed
	return _profiles.duplicate(true)

static func find(id: String) -> Dictionary:
	return all().get(id, {})

static func validate(characters: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for id: String in all():
		var profile: Dictionary = all()[id]
		if id not in characters or profile.get("id") != id or profile.get("name") != characters[id].name:
			errors.append("Character profile identity mismatch: " + id)
		for key in ["name", "title", "origin", "temperament", "goal", "voice", "relationship", "appearance", "biography", "quote"]:
			if not profile.get(key) is String or str(profile.get(key, "")).is_empty():
				errors.append("Missing character profile " + id + "/" + key)
	return errors
