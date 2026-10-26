extends SceneTree

const SAVE := preload("res://scripts/save_manager.gd")
const STORE := preload("res://scripts/save/save_file_store.gd")
var failures := 0

func expect(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func raw(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()

func _init() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "Use isolated XDG_DATA_HOME under /tmp")
	if failures:
		quit(1)
		return
	SAVE.delete_endless_profile(9)
	var profile := SAVE.create_or_load_endless_profile(9)
	profile.bones = 123
	expect(SAVE.save_endless_profile(profile, 9) > 0, "save profile")
	profile.bones = 125
	expect(SAVE.save_endless_profile(profile, 9) > 0, "save next revision")
	var path := STORE.endless_profile_path(9)
	raw(path, "{broken")
	expect(SAVE.profile_status(9, SAVE.MODE_ENDLESS).status == "recoverable", "corrupt primary finds previous profile")
	expect(SAVE.load_endless_profile(9).bones == 123, "backup keeps last valid revision")
	SAVE.list_endless_slots()
	expect(FileAccess.get_file_as_string(path) == "{broken", "listing must not modify files")
	expect(SAVE.create_or_load_endless_profile(9).bones == 123, "explicit opening restores backup")
	var run := {"run_id": "recovery-test", "run_tier": 1, "player": {"level": 15}, "survival_time": 456.0}
	expect(SAVE.save_run(run, 9, SAVE.MODE_ENDLESS) > 0, "save run")
	for bad in ["{}", "{\"survival_time\":7}"]:
		raw(STORE.endless_run_path(9), bad)
		expect(SAVE.load_run(9, SAVE.MODE_ENDLESS).get("run_id") == "recovery-test", "semantic primary falls back to valid backup")
		expect(FileAccess.file_exists(STORE.endless_run_backup_path(9)), "valid backup preserved")
	raw(path, "{broken")
	raw(STORE.profile_backup_path(path), "{}")
	expect(SAVE.profile_status(9, SAVE.MODE_ENDLESS).status == "corrupt", "bad pair is not empty slot")
	expect(SAVE.create_or_load_endless_profile(9).is_empty(), "refuse overwrite of corrupt permanent progress")
	expect(FileAccess.get_file_as_string(path) == "{broken", "raw broken profile preserved")
	expect(SAVE.save_endless_profile(profile, 99) == 0, "invalid explicit slot must not fall back to active slot")
	expect(FileAccess.file_exists(STORE.endless_run_backup_path(9)), "profile errors do not delete run backup")
	SAVE.delete_endless_profile(9)
	print("SAVE_RECOVERY_SMOKE_OK" if failures == 0 else "SAVE_RECOVERY_SMOKE_FAILED")
	quit(0 if failures == 0 else 1)
