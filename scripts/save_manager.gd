extends RefCounted

const STORY_DATA := preload("res://scripts/story_data.gd")
const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const SAVE_FILE_STORE := preload("res://scripts/save/save_file_store.gd")
const SAVE_PROFILE_DEFAULTS := preload("res://scripts/save/save_profile_defaults.gd")
const RUN_PAYLOAD := preload("res://scripts/save/run_payload_validator.gd")
const PERFORMANCE_RECORDER := preload("res://scripts/game/performance_recorder.gd")

const STORY_SLOT_COUNT := 3
const ENDLESS_SLOT_COUNT := 9
const MODE_STORY := "story"
const MODE_ENDLESS := "endless"
const ENDLESS_CLEAR_BONE_REWARD := 8

static var continue_requested: bool = false
static var active_slot_id: int = -1
static var active_mode: String = ""
static var active_endless_slot_id: int = -1

static func _profile_path(slot_id: int) -> String:
	return SAVE_FILE_STORE.story_profile_path(slot_id)

static func _run_path(slot_id: int) -> String:
	return SAVE_FILE_STORE.story_run_path(slot_id)

static func _run_backup_path(slot_id: int) -> String:
	return SAVE_FILE_STORE.story_run_backup_path(slot_id)

static func _endless_profile_path(slot_id: int) -> String:
	return SAVE_FILE_STORE.endless_profile_path(slot_id)

static func _endless_run_path(slot_id: int) -> String:
	return SAVE_FILE_STORE.endless_run_path(slot_id)

static func _endless_run_backup_path(slot_id: int) -> String:
	return SAVE_FILE_STORE.endless_run_backup_path(slot_id)

static func _resolve_slot(slot_id: int = -1) -> int:
	if slot_id != -1:
		return slot_id if slot_id >= 1 and slot_id <= STORY_SLOT_COUNT else -1
	var current := get_active_slot_id()
	if current >= 1 and current <= STORY_SLOT_COUNT:
		return current
	return -1

static func _resolve_endless_slot(slot_id: int = -1) -> int:
	if slot_id != -1:
		return slot_id if slot_id >= 1 and slot_id <= ENDLESS_SLOT_COUNT else -1
	var current := get_active_endless_slot_id()
	if current >= 1 and current <= ENDLESS_SLOT_COUNT:
		return current
	return -1

static func _read_json(path: String) -> Variant:
	return SAVE_FILE_STORE.read_json(path)

static func _write_json(path: String, data: Dictionary) -> int:
	return SAVE_FILE_STORE.write_json(path, data)

static func _load_meta() -> Dictionary:
	return SAVE_FILE_STORE.load_meta()

static func _save_meta(meta: Dictionary) -> void:
	SAVE_FILE_STORE.save_meta(meta)

static func _get_last_slot_id() -> int:
	return int(_load_meta().get("last_slot_id", -1))

static func _get_last_endless_slot_id() -> int:
	return int(_load_meta().get("last_endless_slot_id", -1))

static func _get_last_mode() -> String:
	var saved_mode := str(_load_meta().get("last_mode", MODE_STORY))
	return saved_mode if saved_mode in [MODE_STORY, MODE_ENDLESS] else MODE_STORY

static func set_active_slot(slot_id: int) -> void:
	if slot_id < 1 or slot_id > STORY_SLOT_COUNT:
		return
	active_mode = MODE_STORY
	active_slot_id = slot_id
	var meta := _load_meta()
	meta["last_slot_id"] = slot_id
	meta["last_mode"] = MODE_STORY
	_save_meta(meta)

static func get_active_slot_id() -> int:
	if active_slot_id >= 1 and active_slot_id <= STORY_SLOT_COUNT:
		return active_slot_id
	active_slot_id = _get_last_slot_id()
	return active_slot_id

static func set_active_endless_slot(slot_id: int) -> void:
	if slot_id < 1 or slot_id > ENDLESS_SLOT_COUNT:
		return
	active_mode = MODE_ENDLESS
	active_endless_slot_id = slot_id
	var meta := _load_meta()
	meta["last_endless_slot_id"] = slot_id
	meta["last_mode"] = MODE_ENDLESS
	_save_meta(meta)

static func get_active_endless_slot_id() -> int:
	if active_endless_slot_id >= 1 and active_endless_slot_id <= ENDLESS_SLOT_COUNT:
		return active_endless_slot_id
	active_endless_slot_id = _get_last_endless_slot_id()
	return active_endless_slot_id

static func get_active_mode() -> String:
	if active_mode in [MODE_STORY, MODE_ENDLESS]:
		return active_mode
	active_mode = _get_last_mode()
	return active_mode

static func _ensure_profile_defaults(profile: Dictionary, slot_id: int) -> Dictionary:
	return SAVE_PROFILE_DEFAULTS.ensure_story_profile_defaults(profile, slot_id)

static func _build_default_endless_profile(slot_id: int) -> Dictionary:
	return SAVE_PROFILE_DEFAULTS.build_default_endless_profile(slot_id)

static func _ensure_endless_profile_defaults(profile: Dictionary, slot_id: int) -> Dictionary:
	return SAVE_PROFILE_DEFAULTS.ensure_endless_profile_defaults(profile, slot_id)

static func profile_status(slot_id: int, mode: String) -> Dictionary:
	if not mode in [MODE_STORY, MODE_ENDLESS] or slot_id < 1 or slot_id > (STORY_SLOT_COUNT if mode == MODE_STORY else ENDLESS_SLOT_COUNT):
		return {"status": "invalid", "data": {}}
	var path := _profile_path(slot_id) if mode == MODE_STORY else _endless_profile_path(slot_id)
	var backup := SAVE_FILE_STORE.profile_backup_path(path)
	var primary: Variant = _read_json(path)
	var error := SAVE_PROFILE_DEFAULTS.profile_error(primary, slot_id, mode)
	if error == "":
		return {"status": "ok", "data": primary}
	if error == "content_mismatch":
		return {"status": "incompatible", "data": {}}
	var fallback: Variant = _read_json(backup)
	if SAVE_PROFILE_DEFAULTS.profile_error(fallback, slot_id, mode) == "":
		return {"status": "recoverable", "data": fallback}
	var exists := FileAccess.file_exists(path) or FileAccess.file_exists(backup)
	return {"status": "corrupt" if exists else "missing", "data": {}}

static func _load_profile(slot_id: int, mode: String) -> Dictionary:
	var status := profile_status(slot_id, mode)
	var data: Dictionary = status.data
	if data.is_empty():
		return {}
	return _ensure_profile_defaults(data, slot_id) if mode == MODE_STORY else _ensure_endless_profile_defaults(data, slot_id)

static func _save_profile(profile: Dictionary, slot_id: int, mode: String) -> int:
	if DEVELOPER_MODE.should_disable_save() or SAVE_PROFILE_DEFAULTS.profile_error(profile, slot_id, mode) != "":
		return 0
	var status := profile_status(slot_id, mode)
	if status.status in ["corrupt", "incompatible", "invalid"]:
		return 0
	var path := _profile_path(slot_id) if mode == MODE_STORY else _endless_profile_path(slot_id)
	if status.status == "recoverable" and not SAVE_FILE_STORE.preserve_file(path):
		return 0
	var normalized := _ensure_profile_defaults(profile, slot_id) if mode == MODE_STORY else _ensure_endless_profile_defaults(profile, slot_id)
	var written := SAVE_FILE_STORE.write_profile(path, normalized, status.data)
	if written > 0:
		if mode == MODE_STORY:
			set_active_slot(slot_id)
		else:
			set_active_endless_slot(slot_id)
	return written

static func has_story_profile(slot_id: int = -1) -> bool:
	return profile_status(_resolve_slot(slot_id), MODE_STORY).status in ["ok", "recoverable", "corrupt", "incompatible"]

static func create_or_load_story_profile(slot_id: int) -> Dictionary:
	if not STORY_DATA.is_story_mode_enabled() or slot_id < 1 or slot_id > STORY_SLOT_COUNT:
		return {}
	var existing := load_story_profile(slot_id)
	if not existing.is_empty():
		set_active_slot(slot_id)
		return existing
	if profile_status(slot_id, MODE_STORY).status in ["ok", "recoverable", "corrupt", "incompatible"]:
		return {}
	var profile := _ensure_profile_defaults(STORY_DATA.build_default_story_profile(slot_id), slot_id)
	return profile if save_story_profile(profile, slot_id) > 0 else {}

static func load_story_profile(slot_id: int = -1) -> Dictionary:
	return _load_profile(_resolve_slot(slot_id), MODE_STORY)

static func save_story_profile(profile: Dictionary, slot_id: int = -1) -> int:
	return _save_profile(profile, _resolve_slot(slot_id), MODE_STORY)

static func delete_story_profile(slot_id: int) -> bool:
	return _delete_profile(slot_id, MODE_STORY)

static func has_endless_profile(slot_id: int = -1) -> bool:
	return profile_status(_resolve_endless_slot(slot_id), MODE_ENDLESS).status in ["ok", "recoverable", "corrupt", "incompatible"]

static func create_or_load_endless_profile(slot_id: int) -> Dictionary:
	if slot_id < 1 or slot_id > ENDLESS_SLOT_COUNT:
		return {}
	var existing := load_endless_profile(slot_id)
	if not existing.is_empty():
		if profile_status(slot_id, MODE_ENDLESS).status == "recoverable" and save_endless_profile(existing, slot_id) <= 0:
			return {}
		set_active_endless_slot(slot_id)
		return existing
	if profile_status(slot_id, MODE_ENDLESS).status in ["ok", "recoverable", "corrupt", "incompatible"]:
		return {}
	var profile := _build_default_endless_profile(slot_id)
	return profile if save_endless_profile(profile, slot_id) > 0 else {}

static func load_endless_profile(slot_id: int = -1) -> Dictionary:
	return _load_profile(_resolve_endless_slot(slot_id), MODE_ENDLESS)

static func save_endless_profile(profile: Dictionary, slot_id: int = -1) -> int:
	return _save_profile(profile, _resolve_endless_slot(slot_id), MODE_ENDLESS)

static func credit_bone_pickup(amount: int, pickup_id: String, run_id: String) -> int:
	if not is_endless_mode_active() or amount <= 0:
		return -1
	var profile := get_current_endless_profile()
	if profile.is_empty():
		return -1
	if pickup_id != "" and run_id != "":
		var receipts: Dictionary = profile.get("bone_pickup_receipts", {})
		if receipts.get("run_id", "") != run_id:
			receipts = {"run_id": run_id, "ids": []}
		if receipts.ids.has(pickup_id):
			return int(profile.bones)
		receipts.ids.append(pickup_id)
		profile.bone_pickup_receipts = receipts
	profile.bones = int(profile.bones) + amount
	return int(profile.bones) if save_endless_profile(profile) > 0 else -1

static func delete_endless_profile(slot_id: int) -> bool:
	return _delete_profile(slot_id, MODE_ENDLESS)

static func _delete_profile(slot_id: int, mode: String) -> bool:
	if slot_id < 1 or slot_id > (STORY_SLOT_COUNT if mode == MODE_STORY else ENDLESS_SLOT_COUNT):
		return false
	var path := _profile_path(slot_id) if mode == MODE_STORY else _endless_profile_path(slot_id)
	var success := clear_save(slot_id, mode)
	for file in [path, SAVE_FILE_STORE.profile_backup_path(path)]:
		if not SAVE_FILE_STORE.remove_if_exists(file):
			success = false
	return success

static func list_endless_slots() -> Array:
	var slots: Array = []
	for slot_id in range(1, ENDLESS_SLOT_COUNT + 1):
		var profile := load_endless_profile(slot_id)
		var run_data := load_run(slot_id, MODE_ENDLESS)
		slots.append({
			"slot_id": slot_id,
			"has_profile": not profile.is_empty(),
			"health": profile_status(slot_id, MODE_ENDLESS).status,
			"profile": profile,
			"has_run": not run_data.is_empty(),
			"run_tier": int(run_data.get("run_tier", 0))
		})
	return slots

static func list_story_slots() -> Array:
	var slots: Array = []
	for slot_id in range(1, STORY_SLOT_COUNT + 1):
		var profile := load_story_profile(slot_id)
		slots.append({
			"slot_id": slot_id,
			"has_profile": not profile.is_empty(),
			"health": profile_status(slot_id, MODE_STORY).status,
			"profile": profile
		})
	return slots

static func has_save(slot_id: int = -1, mode: String = "") -> bool:
	return not load_run(slot_id, mode).is_empty()

static func save_run(data: Dictionary, slot_id: int = -1, mode: String = "") -> int:
	PERFORMANCE_RECORDER.begin_scope("save_payload_validate_ms")
	var payload_error := RUN_PAYLOAD.error(data)
	PERFORMANCE_RECORDER.end_scope("save_payload_validate_ms")
	if payload_error != "":
		return 0
	var resolved_mode := mode if mode != "" else get_active_mode()
	var resolved := _resolve_slot(slot_id) if resolved_mode == MODE_STORY else _resolve_endless_slot(slot_id)
	if resolved < 1 or not resolved_mode in [MODE_STORY, MODE_ENDLESS]:
		return 0
	if resolved_mode == MODE_STORY:
		set_active_slot(resolved)
		return SAVE_FILE_STORE.write_json_pair(_run_path(resolved), _run_backup_path(resolved), data)
	set_active_endless_slot(resolved)
	return SAVE_FILE_STORE.write_json_pair(_endless_run_path(resolved), _endless_run_backup_path(resolved), data)

static func run_status(slot_id: int = -1, mode: String = "") -> Dictionary:
	var resolved_mode := mode if mode != "" else get_active_mode()
	var resolved := _resolve_slot(slot_id) if resolved_mode == MODE_STORY else _resolve_endless_slot(slot_id)
	if resolved < 1 or not resolved_mode in [MODE_STORY, MODE_ENDLESS]:
		return {"status": "invalid", "data": {}}
	var paths := [_run_path(resolved), _run_backup_path(resolved)] if resolved_mode == MODE_STORY else [_endless_run_path(resolved), _endless_run_backup_path(resolved)]
	var exists := false
	for i in paths.size():
		exists = exists or FileAccess.file_exists(paths[i])
		var parsed: Variant = _read_json(paths[i])
		if RUN_PAYLOAD.error(parsed) != "":
			continue
		var valid := _is_valid_endless_run(parsed, resolved) if resolved_mode == MODE_ENDLESS else _is_valid_story_run(parsed, resolved)
		if valid:
			return {"status": "ok" if i == 0 else "recoverable", "data": parsed}
	return {"status": "corrupt" if exists else "missing", "data": {}}

static func load_run(slot_id: int = -1, mode: String = "") -> Dictionary:
	return run_status(slot_id, mode).data

static func _is_valid_story_run(run: Dictionary, slot_id: int) -> bool:
	if not run.get("player") is Dictionary:
		return false
	if not run.has("story_attempt"):
		return true
	var attempt: Variant = run.story_attempt
	if not attempt is Dictionary or attempt.get("mode") != MODE_STORY or not SAVE_PROFILE_DEFAULTS.STORY_STATE.whole_number(attempt.get("slot_id"), 1) or int(attempt.slot_id) != slot_id:
		return false
	var profile := load_story_profile(slot_id)
	if profile.is_empty():
		return false
	var active: Dictionary = profile.story.active_attempt
	var last: Dictionary = profile.story.last_settlement
	return SAVE_PROFILE_DEFAULTS.STORY_STATE.same_attempt(attempt, active) or SAVE_PROFILE_DEFAULTS.STORY_STATE.same_attempt(attempt, last)

static func _is_valid_endless_run(run_data: Dictionary, slot_id: int) -> bool:
	if not _has_endless_run_identity(run_data):
		return false
	var run_tier := int(run_data.get("run_tier", 0))
	var profile := load_endless_profile(slot_id)
	return _has_endless_run_identity(run_data) and not profile.is_empty() and (run_tier == int(profile.get("selected_tier", 1)) or str(run_data.get("run_id", "")) == str(profile.get("last_rewarded_run_id", "")))

static func _has_endless_run_identity(run_data: Dictionary) -> bool:
	return run_data.get("run_id") is String and run_data.run_id != "" and SAVE_PROFILE_DEFAULTS.STORY_STATE.whole_number(run_data.get("run_tier"), 1)

static func _archive_legacy_endless_run_before_replacement(slot_id: int) -> bool:
	for path in [_endless_run_path(slot_id), _endless_run_backup_path(slot_id)]:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = _read_json(path)
		if not parsed is Dictionary or not _has_endless_run_identity(parsed):
			if not SAVE_FILE_STORE.preserve_file(path):
				return false
	return true

static func has_unarchived_legacy_endless_run(slot_id: int = -1) -> bool:
	return run_status(slot_id, MODE_ENDLESS).status == "corrupt"

static func clear_save(slot_id: int = -1, mode: String = "") -> bool:
	if DEVELOPER_MODE.should_disable_save():
		return false
	var resolved_mode := mode if mode != "" else get_active_mode()
	var resolved := _resolve_slot(slot_id) if resolved_mode == MODE_STORY else _resolve_endless_slot(slot_id)
	if resolved < 1 or not resolved_mode in [MODE_STORY, MODE_ENDLESS]:
		return false
	if resolved_mode == MODE_ENDLESS and not _archive_legacy_endless_run_before_replacement(resolved):
		return false
	var paths := [_run_path(resolved), _run_backup_path(resolved)] if resolved_mode == MODE_STORY else [_endless_run_path(resolved), _endless_run_backup_path(resolved)]
	var success := true
	for path in paths:
		if not SAVE_FILE_STORE.remove_if_exists(path):
			success = false
	return success

static func has_continue_target() -> bool:
	return get_continue_target_scene() != ""

static func get_continue_target_scene() -> String:
	var mode := _get_last_mode()
	if mode == MODE_ENDLESS:
		var endless_slot_id := _get_last_endless_slot_id()
		if endless_slot_id >= 1 and endless_slot_id <= ENDLESS_SLOT_COUNT and has_save(endless_slot_id, MODE_ENDLESS):
			return STORY_DATA.BATTLE_SCENE_PATH
		return ""

	if not STORY_DATA.is_story_mode_enabled():
		return ""

	var slot_id := _get_last_slot_id()
	if slot_id < 1 or slot_id > STORY_SLOT_COUNT:
		return ""
	if has_story_profile(slot_id):
		return STORY_DATA.PREP_SCENE_PATH
	return ""

static func request_continue_to_last_target() -> String:
	var scene_path := get_continue_target_scene()
	if scene_path == "":
		return ""
	if _get_last_mode() == MODE_ENDLESS:
		var endless_slot_id := _get_last_endless_slot_id()
		if endless_slot_id < 1:
			return ""
		set_active_endless_slot(endless_slot_id)
	else:
		var slot_id := _get_last_slot_id()
		if slot_id < 1:
			return ""
		set_active_slot(slot_id)
	continue_requested = scene_path == STORY_DATA.BATTLE_SCENE_PATH
	return scene_path

static func request_continue() -> void:
	continue_requested = true

static func consume_continue_request() -> bool:
	var requested := continue_requested
	continue_requested = false
	return requested

static func is_endless_mode_active() -> bool:
	return get_active_mode() == MODE_ENDLESS and get_active_endless_slot_id() >= 1

static func get_current_endless_profile() -> Dictionary:
	if not is_endless_mode_active():
		return {}
	return load_endless_profile()

static func get_endless_unlocked_max(profile: Dictionary) -> int:
	return max(1, int(profile.get("highest_cleared_tier", 0)) + 1)

static func select_current_endless_tier(tier: int) -> bool:
	var resolved := _resolve_endless_slot()
	if resolved < 1 or not _archive_legacy_endless_run_before_replacement(resolved):
		return false
	var profile := get_current_endless_profile()
	if profile.is_empty() or tier < 1 or tier > get_endless_unlocked_max(profile):
		return false
	profile["selected_tier"] = tier
	if save_endless_profile(profile) <= 0:
		return false
	return clear_save(-1, MODE_ENDLESS)

static func create_endless_run_id(tier: int) -> String:
	return "%d_%d_%d_%d" % [
		max(1, get_active_endless_slot_id()),
		max(1, tier),
		int(Time.get_unix_time_from_system()),
		Time.get_ticks_usec()
	]

static func settle_endless_profile(profile: Dictionary, tier: int, run_id: String) -> Dictionary:
	var safe_tier: int = maxi(1, tier)
	var previous_highest: int = maxi(0, int(profile.get("highest_cleared_tier", 0)))
	var first_clear: bool = safe_tier > previous_highest
	var first_clear_bonus: int = 5 + 3 * safe_tier if first_clear else 0
	var result: Dictionary = {
		"applied": false,
		"tier": safe_tier,
		"base_reward": 0,
		"first_clear_bonus": 0,
		"total_reward": 0,
		"first_clear": first_clear,
		"highest_cleared_tier": previous_highest,
		"next_tier": previous_highest + 1
	}
	if run_id == "" or run_id == str(profile.get("last_rewarded_run_id", "")):
		return result
	var total_reward: int = ENDLESS_CLEAR_BONE_REWARD + first_clear_bonus
	profile["bones"] = max(0, int(profile.get("bones", 0))) + total_reward
	profile["highest_cleared_tier"] = max(previous_highest, safe_tier)
	profile["selected_tier"] = safe_tier + 1 if first_clear else safe_tier
	profile["last_rewarded_run_id"] = run_id
	profile.erase("bone_pickup_receipts")
	profile["last_clear_summary"] = {"tier": safe_tier, "bones": total_reward, "first_clear": first_clear}
	result.merge({
		"applied": true,
		"base_reward": ENDLESS_CLEAR_BONE_REWARD,
		"first_clear_bonus": first_clear_bonus,
		"total_reward": total_reward,
		"highest_cleared_tier": int(profile["highest_cleared_tier"]),
		"next_tier": int(profile["highest_cleared_tier"]) + 1
	}, true)
	return result

static func complete_current_endless_tier(tier: int, run_id: String, summary: Dictionary = {}) -> Dictionary:
	var profile := get_current_endless_profile()
	if profile.is_empty():
		return {}
	var settlement := settle_endless_profile(profile, tier, run_id)
	if bool(settlement.get("applied", false)):
		if not summary.is_empty():
			profile["last_run_summary"] = summary.duplicate(true)
		if save_endless_profile(profile) <= 0:
			settlement["applied"] = false
			settlement["error"] = "save_failed"
			return settlement
	if run_id != "" and not clear_save(-1, MODE_ENDLESS):
		settlement["error"] = "cleanup_failed"
	return settlement

static func get_current_story_stage() -> Dictionary:
	if get_active_mode() != MODE_STORY or not STORY_DATA.is_story_mode_enabled():
		return {}
	var profile := load_story_profile()
	if profile.is_empty():
		return {}
	var attempt: Dictionary = profile.story.active_attempt
	for stage: Dictionary in STORY_DATA.STORY_STAGES:
		if stage.id == attempt.get("stage_id", ""):
			return stage.duplicate(true)
	return {}
