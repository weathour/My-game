extends RefCounted

const STORY_DATA := preload("res://scripts/story_data.gd")
const SAVE_FILE_STORE := preload("res://scripts/save/save_file_store.gd")
const SAVE_PROFILE_DEFAULTS := preload("res://scripts/save/save_profile_defaults.gd")

const STORY_SLOT_COUNT := 3
const ENDLESS_SLOT_COUNT := 9
const MODE_STORY := "story"
const MODE_ENDLESS := "endless"

static var continue_requested: bool = false
static var active_slot_id: int = -1
static var active_mode: String = MODE_STORY
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
	if slot_id >= 1 and slot_id <= STORY_SLOT_COUNT:
		return slot_id
	var current := get_active_slot_id()
	if current >= 1 and current <= STORY_SLOT_COUNT:
		return current
	return -1

static func _resolve_endless_slot(slot_id: int = -1) -> int:
	if slot_id >= 1 and slot_id <= ENDLESS_SLOT_COUNT:
		return slot_id
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
	return str(_load_meta().get("last_mode", MODE_STORY))

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

static func _build_default_endless_profile(slot_id: int, difficulty: String) -> Dictionary:
	return SAVE_PROFILE_DEFAULTS.build_default_endless_profile(slot_id, difficulty)

static func _ensure_endless_profile_defaults(profile: Dictionary, slot_id: int) -> Dictionary:
	return SAVE_PROFILE_DEFAULTS.ensure_endless_profile_defaults(profile, slot_id)

static func has_story_profile(slot_id: int = -1) -> bool:
	var resolved := _resolve_slot(slot_id)
	if resolved < 1:
		return false
	return FileAccess.file_exists(_profile_path(resolved))

static func create_or_load_story_profile(slot_id: int) -> Dictionary:
	if not STORY_DATA.is_story_mode_enabled():
		return {}
	set_active_slot(slot_id)
	var existing := load_story_profile(slot_id)
	if not existing.is_empty():
		return existing
	var profile := STORY_DATA.build_default_story_profile(slot_id)
	save_story_profile(profile, slot_id)
	return profile

static func load_story_profile(slot_id: int = -1) -> Dictionary:
	var resolved := _resolve_slot(slot_id)
	if resolved < 1:
		return {}
	var parsed: Variant = _read_json(_profile_path(resolved))
	if parsed is Dictionary:
		return _ensure_profile_defaults(parsed, resolved)
	return {}

static func save_story_profile(profile: Dictionary, slot_id: int = -1) -> void:
	var resolved := _resolve_slot(slot_id)
	if resolved < 1:
		return
	set_active_slot(resolved)
	_write_json(_profile_path(resolved), _ensure_profile_defaults(profile, resolved))

static func delete_story_profile(slot_id: int) -> void:
	if slot_id < 1 or slot_id > STORY_SLOT_COUNT:
		return
	var profile_path := _profile_path(slot_id)
	var run_path := _run_path(slot_id)
	var run_backup_path := _run_backup_path(slot_id)
	if FileAccess.file_exists(profile_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path))
	if FileAccess.file_exists(run_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(run_path))
	if FileAccess.file_exists(run_backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(run_backup_path))
	if get_active_slot_id() == slot_id:
		active_slot_id = -1

static func has_endless_profile(slot_id: int = -1) -> bool:
	var resolved := _resolve_endless_slot(slot_id)
	if resolved < 1:
		return false
	return FileAccess.file_exists(_endless_profile_path(resolved))

static func create_or_load_endless_profile(slot_id: int, difficulty: String = "normal") -> Dictionary:
	set_active_endless_slot(slot_id)
	var existing := load_endless_profile(slot_id)
	if not existing.is_empty():
		return existing
	var profile := _build_default_endless_profile(slot_id, difficulty)
	save_endless_profile(profile, slot_id)
	return profile

static func load_endless_profile(slot_id: int = -1) -> Dictionary:
	var resolved := _resolve_endless_slot(slot_id)
	if resolved < 1:
		return {}
	var parsed: Variant = _read_json(_endless_profile_path(resolved))
	if parsed is Dictionary:
		return _ensure_endless_profile_defaults(parsed, resolved)
	return {}

static func save_endless_profile(profile: Dictionary, slot_id: int = -1) -> void:
	var resolved := _resolve_endless_slot(slot_id)
	if resolved < 1:
		return
	set_active_endless_slot(resolved)
	_write_json(_endless_profile_path(resolved), _ensure_endless_profile_defaults(profile, resolved))

static func delete_endless_profile(slot_id: int) -> void:
	if slot_id < 1 or slot_id > ENDLESS_SLOT_COUNT:
		return
	var profile_path := _endless_profile_path(slot_id)
	var run_path := _endless_run_path(slot_id)
	var run_backup_path := _endless_run_backup_path(slot_id)
	if FileAccess.file_exists(profile_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path))
	if FileAccess.file_exists(run_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(run_path))
	if FileAccess.file_exists(run_backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(run_backup_path))
	if get_active_endless_slot_id() == slot_id:
		active_endless_slot_id = -1

static func list_endless_slots() -> Array:
	var slots: Array = []
	for slot_id in range(1, ENDLESS_SLOT_COUNT + 1):
		var profile := load_endless_profile(slot_id)
		var run_data := load_run(slot_id, MODE_ENDLESS)
		slots.append({
			"slot_id": slot_id,
			"has_profile": not profile.is_empty(),
			"profile": profile,
			"has_run": not run_data.is_empty(),
			"survival_time": float(run_data.get("survival_time", 0.0))
		})
	return slots

static func list_story_slots() -> Array:
	var slots: Array = []
	for slot_id in range(1, STORY_SLOT_COUNT + 1):
		var profile := load_story_profile(slot_id)
		slots.append({
			"slot_id": slot_id,
			"has_profile": not profile.is_empty(),
			"profile": profile
		})
	return slots

static func has_save(slot_id: int = -1, mode: String = "") -> bool:
	var resolved_mode := mode if mode != "" else get_active_mode()
	var resolved := _resolve_slot(slot_id) if resolved_mode == MODE_STORY else _resolve_endless_slot(slot_id)
	if resolved < 1:
		return false
	var run_path := _run_path(resolved) if resolved_mode == MODE_STORY else _endless_run_path(resolved)
	var backup_path := _run_backup_path(resolved) if resolved_mode == MODE_STORY else _endless_run_backup_path(resolved)
	return FileAccess.file_exists(run_path) or FileAccess.file_exists(backup_path)

static func save_run(data: Dictionary, slot_id: int = -1, mode: String = "") -> int:
	var resolved_mode := mode if mode != "" else get_active_mode()
	var resolved := _resolve_slot(slot_id) if resolved_mode == MODE_STORY else _resolve_endless_slot(slot_id)
	if resolved < 1:
		return 0
	if resolved_mode == MODE_STORY:
		set_active_slot(resolved)
		var story_payload_chars := _write_json(_run_path(resolved), data)
		_write_json(_run_backup_path(resolved), data)
		return story_payload_chars
	set_active_endless_slot(resolved)
	var endless_payload_chars := _write_json(_endless_run_path(resolved), data)
	_write_json(_endless_run_backup_path(resolved), data)
	return endless_payload_chars

static func load_run(slot_id: int = -1, mode: String = "") -> Dictionary:
	var resolved_mode := mode if mode != "" else get_active_mode()
	var resolved := _resolve_slot(slot_id) if resolved_mode == MODE_STORY else _resolve_endless_slot(slot_id)
	if resolved < 1:
		return {}
	var run_path := _run_path(resolved) if resolved_mode == MODE_STORY else _endless_run_path(resolved)
	var backup_path := _run_backup_path(resolved) if resolved_mode == MODE_STORY else _endless_run_backup_path(resolved)
	var parsed: Variant = _read_json(run_path)
	if parsed is Dictionary:
		return parsed
	var backup_parsed: Variant = _read_json(backup_path)
	if backup_parsed is Dictionary:
		_write_json(run_path, backup_parsed)
		return backup_parsed
	return {}

static func clear_save(slot_id: int = -1, mode: String = "") -> void:
	var resolved_mode := mode if mode != "" else get_active_mode()
	var resolved := _resolve_slot(slot_id) if resolved_mode == MODE_STORY else _resolve_endless_slot(slot_id)
	if resolved < 1:
		return
	var run_path := _run_path(resolved) if resolved_mode == MODE_STORY else _endless_run_path(resolved)
	var run_backup_path := _run_backup_path(resolved) if resolved_mode == MODE_STORY else _endless_run_backup_path(resolved)
	if not FileAccess.file_exists(run_path):
		if FileAccess.file_exists(run_backup_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(run_backup_path))
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run_path))
	if FileAccess.file_exists(run_backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(run_backup_path))

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
	if has_save(slot_id, MODE_STORY):
		return STORY_DATA.BATTLE_SCENE_PATH
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

static func get_current_story_stage() -> Dictionary:
	if not STORY_DATA.is_story_mode_enabled():
		return {}
	var profile := load_story_profile()
	if profile.is_empty():
		return {}
	return STORY_DATA.get_stage(int(profile.get("current_stage_index", 0)))

static func complete_current_story_stage(material_reward: int = 0) -> Dictionary:
	var profile := load_story_profile()
	if profile.is_empty():
		return {}
	profile["boss_core_fragments"] = int(profile.get("boss_core_fragments", 0)) + material_reward
	profile["current_stage_index"] = int(profile.get("current_stage_index", 0)) + 1
	save_story_profile(profile)
	clear_save()
	return profile

static func unlock_style(role_id: String, style_id: String) -> bool:
	var profile := load_story_profile()
	if profile.is_empty():
		return false
	var unlocked_styles: Dictionary = profile.get("unlocked_styles", {}).duplicate(true)
	var role_styles: Array = unlocked_styles.get(role_id, []).duplicate()
	if role_styles.has(style_id):
		return true
	var boss_cores: int = int(profile.get("boss_core_fragments", 0))
	if boss_cores <= 0:
		return false
	role_styles.append(style_id)
	unlocked_styles[role_id] = role_styles
	profile["unlocked_styles"] = unlocked_styles
	profile["boss_core_fragments"] = boss_cores - 1
	save_story_profile(profile)
	return true

static func equip_style(role_id: String, style_id: String) -> void:
	var profile := load_story_profile()
	if profile.is_empty():
		return
	var equipped_styles: Dictionary = profile.get("equipped_styles", {}).duplicate(true)
	equipped_styles[role_id] = style_id
	profile["equipped_styles"] = equipped_styles
	save_story_profile(profile)

static func update_team_order(team_order: Array) -> void:
	var profile := load_story_profile()
	if profile.is_empty():
		return
	profile["team_order"] = team_order.duplicate()
	save_story_profile(profile)
