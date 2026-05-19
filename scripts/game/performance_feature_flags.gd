extends RefCounted

const FLAG_ENEMY_BATCH := "enemy_batch"
const FLAG_ENEMY_PROJECTILE_BATCH := "enemy_projectile_batch"
const FLAG_PICKUP_BATCH := "pickup_batch"
const FLAG_ADAPTIVE_DEGRADE := "adaptive_degrade"
const FLAG_WORKER_THREADPOOL_PROTOTYPE := "worker_threadpool_prototype"
const FLAG_PROJECT_THREAD_SETTINGS_AB := "project_thread_settings_ab"

const ALL_FLAGS := [
	FLAG_ENEMY_BATCH,
	FLAG_ENEMY_PROJECTILE_BATCH,
	FLAG_PICKUP_BATCH,
	FLAG_ADAPTIVE_DEGRADE,
	FLAG_WORKER_THREADPOOL_PROTOTYPE,
	FLAG_PROJECT_THREAD_SETTINGS_AB
]

const META_KEY := "performance_feature_flags"
const ENV_FLAGS := "MY_GAME_PERF_FLAGS"
const ENV_PREFIX := "MY_GAME_PERF_"


static func is_enabled(root: Node, flag_name: String) -> bool:
	if flag_name == "":
		return false
	if root != null and root.has_meta(META_KEY):
		var meta_flags: Variant = root.get_meta(META_KEY)
		if meta_flags is Dictionary and (meta_flags as Dictionary).has(flag_name):
			return bool((meta_flags as Dictionary).get(flag_name, false))
	var env_key := ENV_PREFIX + flag_name.to_upper()
	if OS.has_environment(env_key):
		return _parse_bool(OS.get_environment(env_key))
	if OS.has_environment(ENV_FLAGS):
		var enabled_flags := _parse_flag_list(OS.get_environment(ENV_FLAGS))
		if enabled_flags.has(flag_name):
			return true
	var setting_key := "application/run/performance_flags/%s" % flag_name
	if ProjectSettings.has_setting(setting_key):
		return bool(ProjectSettings.get_setting(setting_key))
	return false


static func set_flag(root: Node, flag_name: String, enabled: bool) -> void:
	if root == null or flag_name == "":
		return
	var flags: Dictionary = {}
	if root.has_meta(META_KEY) and root.get_meta(META_KEY) is Dictionary:
		flags = (root.get_meta(META_KEY) as Dictionary).duplicate()
	flags[flag_name] = enabled
	root.set_meta(META_KEY, flags)


static func set_flags(root: Node, flags: Dictionary) -> void:
	if root == null:
		return
	var normalized: Dictionary = {}
	for flag_name in ALL_FLAGS:
		if flags.has(flag_name):
			normalized[flag_name] = bool(flags.get(flag_name, false))
	root.set_meta(META_KEY, normalized)


static func get_snapshot(root: Node) -> Dictionary:
	var snapshot: Dictionary = {}
	for flag_name in ALL_FLAGS:
		snapshot[flag_name] = is_enabled(root, flag_name)
	return snapshot


static func _parse_flag_list(raw: String) -> Dictionary:
	var result: Dictionary = {}
	for part in raw.split(",", false):
		var flag_name := part.strip_edges()
		if flag_name != "":
			result[flag_name] = true
	return result


static func _parse_bool(raw: String) -> bool:
	var value := raw.strip_edges().to_lower()
	return value in ["1", "true", "yes", "on", "enabled"]
