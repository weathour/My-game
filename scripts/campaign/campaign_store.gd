extends RefCounted
## Atomic replace plus one known-good generation. No gameplay mutations here.
static func write(directory: String, slot: String, value: Dictionary, validator: Callable) -> bool:
	if slot not in ["auto", "1", "2", "3"]: return false
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return false
	var path := directory.path_join(slot + ".json")
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(value, "", true, true))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return false
	if FileAccess.file_exists(path):
		var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if validator.call(previous) and DirAccess.copy_absolute(path, path + ".bak") != OK: return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

static func read(directory: String, slot: String, validator: Callable) -> Dictionary:
	if slot not in ["auto", "1", "2", "3"]: return {}
	var path := directory.path_join(slot + ".json")
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if validator.call(value): return value
	return {}
