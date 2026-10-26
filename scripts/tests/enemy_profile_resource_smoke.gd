extends SceneTree

const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")

const PLAN := preload("res://scripts/game/combat_wave_plan.gd")
const DIRECTOR := preload("res://scripts/enemy/enemy_director.gd")


const REQUIRED_KEYS := [
	"archetype",
	"behavior",
	"max_health",
	"attack",
	"armor",
	"damage_reduction_rate",
	"speed",
	"touch_damage",
	"contact_radius",
	"body_collision_radius",
	"reward_tier",
	"experience_reward",
	"scale",
	"color"
]


func _init() -> void:
	var failures: Array[String] = []
	for archetype in ENEMY_ARCHETYPE_DATABASE.PROFILE_PATHS:
		var profile: Dictionary = ENEMY_ARCHETYPE_DATABASE.get_profile("normal", archetype)
		if profile.is_empty():
			failures.append("%s profile should load" % archetype)
			continue
		for key in REQUIRED_KEYS:
			if not profile.has(key):
				failures.append("%s profile missing %s" % [archetype, key])
		if str(profile.get("archetype", "")) != archetype:
			failures.append("%s profile archetype mismatch: %s" % [archetype, str(profile.get("archetype", ""))])
		if float(profile.get("max_health", 0.0)) <= 0.0:
			failures.append("%s max_health should be positive" % archetype)
		if int(profile.get("experience_reward", 0)) < 0 or (not ENEMY_ARCHETYPE_DATABASE.INTERNAL_ARCHETYPES.has(archetype) and int(profile.get("experience_reward", 0)) == 0):
			failures.append("%s experience_reward should be positive" % archetype)
	_check_catalog_and_authored_references(failures)
	if not ENEMY_ARCHETYPE_DATABASE.get_profile("normal", "missing_archetype").is_empty():
		failures.append("unknown authored content must not silently become chaser")
	var fallback_profile: Dictionary = ENEMY_ARCHETYPE_DATABASE.get_profile_for_restore("normal", "missing_archetype")
	if str(fallback_profile.get("archetype", "")) != "chaser":
		failures.append("legacy restore explicitly falls back to chaser")
	if failures.is_empty():
		print("enemy_profile_resource_smoke: OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_catalog_and_authored_references(failures: Array[String]) -> void:
	var catalog: Array = []
	for category in [ENEMY_ARCHETYPE_DATABASE.NORMAL_ARCHETYPES, ENEMY_ARCHETYPE_DATABASE.ELITE_ARCHETYPES, ENEMY_ARCHETYPE_DATABASE.SMALL_BOSS_ARCHETYPES, ENEMY_ARCHETYPE_DATABASE.BOSS_ARCHETYPES, ENEMY_ARCHETYPE_DATABASE.INTERNAL_ARCHETYPES]:
		for id in category:
			if catalog.has(id):
				failures.append("duplicate enemy category: " + id)
			catalog.append(id)
	for id in ENEMY_ARCHETYPE_DATABASE.PROFILE_PATHS:
		if not catalog.has(id):
			failures.append("enemy needs a playable or internal category: " + id)
	for file in DirAccess.get_files_at("res://data/enemies"):
		if file.ends_with(".tres") and not ENEMY_ARCHETYPE_DATABASE.PROFILE_PATHS.values().has("res://data/enemies/" + file):
			failures.append("enemy resource is absent from authoritative catalog: " + file)
	var references: Array = catalog.duplicate()
	for pool in PLAN.POOLS:
		references.append_array(pool)
	references.append_array(PLAN.BOSSES.values())
	for elites in PLAN.ELITES.values():
		references.append_array(elites)
	for second in range(int(DIRECTOR.DEFAULT_STAGE_DURATION) + 1):
		references.append_array(DIRECTOR.get_wave_profile(float(second), DIRECTOR.get_default_elite_spawn_times(), 0.0, 0.0).get("weights", {}).keys())
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for second in [0.0, 240.0, 420.0, 720.0]:
		for index in 12:
			for kind in ["elite", "small_boss", "boss"]:
				references.append(DIRECTOR.pick_special_archetype(kind, second, index, rng))
	var developer_ids: Array = []
	for option in ENEMY_ARCHETYPE_DATABASE.get_developer_enemy_options():
		developer_ids.append(option.archetype)
		references.append(option.archetype)
	for id in catalog:
		if developer_ids.has(id) == ENEMY_ARCHETYPE_DATABASE.INTERNAL_ARCHETYPES.has(id):
			failures.append("developer directory must include playable enemies and omit internal-only enemies: " + id)
	for id in references:
		if not ENEMY_ARCHETYPE_DATABASE.PROFILE_PATHS.has(id):
			failures.append("unknown authored enemy reference: " + str(id))
