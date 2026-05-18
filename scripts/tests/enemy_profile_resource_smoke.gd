extends SceneTree

const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")

const REQUIRED_ARCHETYPES := [
	"chaser",
	"shooter",
	"brute",
	"runner",
	"swarm",
	"dasher",
	"shotgunner",
	"elite_ram_trail",
	"elite_splitshot",
	"smallboss_glutton",
	"smallboss_rebirth",
	"smallboss_turret",
	"boss_spellcore"
]

const REQUIRED_KEYS := [
	"archetype",
	"behavior",
	"max_health",
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
	for archetype in REQUIRED_ARCHETYPES:
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
		if int(profile.get("experience_reward", 0)) <= 0:
			failures.append("%s experience_reward should be positive" % archetype)
	var fallback_profile: Dictionary = ENEMY_ARCHETYPE_DATABASE.get_profile("normal", "missing_archetype")
	if str(fallback_profile.get("archetype", "")) != "chaser":
		failures.append("missing archetype should fall back to chaser")
	if failures.is_empty():
		print("enemy_profile_resource_smoke: OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
