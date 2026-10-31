extends RefCounted
## Player-facing menu text is authored alongside the chapter's other JSON content.
const PATH := "res://assets/data/chronicle/menu_text.json"
const SETTINGS := preload("res://scripts/shared/settings.gd")
static var _content: Dictionary = {}

static func section(key: String) -> Dictionary:
	if _content.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary: _content = parsed
	return _content.get(key, {})

static func text(group: String, key: String) -> String:
	return resolve(str(section(group).get(key, "")))

static func resolve(value: String) -> String:
	return value.replace("{interact_key}", OS.get_keycode_string(SETTINGS.load_keycode(SETTINGS.ACTION_INTERACT)))
