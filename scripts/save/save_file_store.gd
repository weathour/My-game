extends RefCounted

const PERFORMANCE_RECORDER := preload("res://scripts/game/performance_recorder.gd")

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

static func profile_backup_path(path: String) -> String:
	return path.get_basename() + "_backup.json"

static func preserve_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	var copy_path := "%s.recovery_%d_%d" % [path, int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	return DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(copy_path)) == OK

static func write_profile(path: String, data: Dictionary, previous_valid: Dictionary) -> int:
	var backup := profile_backup_path(path)
	if not previous_valid.is_empty() and write_json(backup, previous_valid) <= 0:
		return 0
	var written := write_json(path, data)
	if written > 0 and not FileAccess.file_exists(backup):
		write_json(backup, data)
	return written

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
	return _write_serialized_json(path, JSON.stringify(data))

static func write_json_pair(path: String, backup_path: String, data: Dictionary) -> int:
	# JSON object order is not state; both files receive this one snapshot.
	PERFORMANCE_RECORDER.begin_scope("save_json_serialize_ms")
	var serialized := JSON.stringify(data, "", false)
	PERFORMANCE_RECORDER.end_scope("save_json_serialize_ms")
	PERFORMANCE_RECORDER.begin_scope("save_primary_commit_ms")
	var primary_chars := _write_serialized_json(path, serialized)
	PERFORMANCE_RECORDER.end_scope("save_primary_commit_ms")
	if primary_chars > 0:
		PERFORMANCE_RECORDER.begin_scope("save_backup_commit_ms")
		_write_serialized_json(backup_path, serialized)
		PERFORMANCE_RECORDER.end_scope("save_backup_commit_ms")
	return primary_chars

static func _write_serialized_json(path: String, serialized: String) -> int:
	ensure_save_root()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return 0
	file.store_string(serialized)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		remove_if_exists(temporary_path)
		return 0
	if DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path),
		ProjectSettings.globalize_path(path)
	) != OK:
		remove_if_exists(temporary_path)
		return 0
	return serialized.length()

static func load_meta() -> Dictionary:
	var parsed: Variant = read_json(META_PATH)
	if parsed is Dictionary:
		return parsed
	return {}

static func save_meta(meta: Dictionary) -> void:
	write_json(META_PATH, meta)

static func remove_if_exists(path: String) -> bool:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		return false
	if FileAccess.file_exists(path):
		return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
	return true
