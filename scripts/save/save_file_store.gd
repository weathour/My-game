extends RefCounted

const STORY_SAVE_ROOT := "user://story_slots"
const ENDLESS_SAVE_ROOT := "user://endless_slots"
const META_PATH := "user://save_meta.json"

static func ensure_save_root() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STORY_SAVE_ROOT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ENDLESS_SAVE_ROOT))

static func story_slot_dir(slot_id: int) -> String:
	return "%s/slot_%d" % [STORY_SAVE_ROOT, slot_id]

static func story_profile_path(slot_id: int) -> String:
	return story_slot_dir(slot_id) + "/story_profile.json"

static func story_run_path(slot_id: int) -> String:
	return story_slot_dir(slot_id) + "/run_save.json"

static func story_run_backup_path(slot_id: int) -> String:
	return story_slot_dir(slot_id) + "/run_save_backup.json"

static func endless_slot_dir(slot_id: int) -> String:
	return "%s/slot_%d" % [ENDLESS_SAVE_ROOT, slot_id]

static func endless_profile_path(slot_id: int) -> String:
	return endless_slot_dir(slot_id) + "/endless_profile.json"

static func endless_run_path(slot_id: int) -> String:
	return endless_slot_dir(slot_id) + "/run_save.json"

static func endless_run_backup_path(slot_id: int) -> String:
	return endless_slot_dir(slot_id) + "/run_save_backup.json"

static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var raw_text := file.get_as_text()
	var json := JSON.new()
	var parse_result := json.parse(raw_text)
	if parse_result != OK:
		printerr("SaveManager JSON parse failed: %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data

static func write_json(path: String, data: Dictionary) -> int:
	ensure_save_root()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return 0
	var serialized := JSON.stringify(data)
	file.store_string(serialized)
	return serialized.length()

static func load_meta() -> Dictionary:
	var parsed: Variant = read_json(META_PATH)
	if parsed is Dictionary:
		return parsed
	return {}

static func save_meta(meta: Dictionary) -> void:
	write_json(META_PATH, meta)

static func remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
