extends RefCounted

const PROFILE_PATHS := {
	"chaser": "res://data/enemies/chaser.tres",
	"shooter": "res://data/enemies/shooter.tres",
	"brute": "res://data/enemies/brute.tres",
	"runner": "res://data/enemies/runner.tres",
	"swarm": "res://data/enemies/swarm.tres",
	"dasher": "res://data/enemies/dasher.tres",
	"shotgunner": "res://data/enemies/shotgunner.tres",
	"elite_ram_trail": "res://data/enemies/elite_ram_trail.tres",
	"elite_splitshot": "res://data/enemies/elite_splitshot.tres",
	"smallboss_glutton": "res://data/enemies/smallboss_glutton.tres",
	"smallboss_rebirth": "res://data/enemies/smallboss_rebirth.tres",
	"smallboss_turret": "res://data/enemies/smallboss_turret.tres",
	"boss_spellcore": "res://data/enemies/boss_spellcore.tres"
}

const BOSS_ARCHETYPES: Array[String] = ["boss_spellcore"]
const SMALL_BOSS_ARCHETYPES: Array[String] = ["smallboss_glutton", "smallboss_rebirth", "smallboss_turret"]
const NORMAL_ARCHETYPES: Array[String] = ["chaser", "runner", "swarm", "shooter", "brute", "dasher", "shotgunner"]
const NORMAL_ARCHETYPE_LABELS := {
	"chaser": "追击菇",
	"runner": "疾行史莱姆",
	"swarm": "飞眼群",
	"shooter": "远程骷髅",
	"brute": "重甲南瓜",
	"dasher": "冲锋怪",
	"shotgunner": "散弹骷髅"
}


static func get_profile(_kind: String, archetype: String) -> Dictionary:
	var profile: Resource = _load_profile(archetype)
	if profile == null:
		profile = _load_profile("chaser")
	if profile != null and profile.has_method("to_dictionary"):
		return profile.to_dictionary()
	return {}


static func get_boss_options() -> Array:
	return [
		{
			"id": "boss_spellcore",
			"title": "Boss+1",
			"description": "生成当前 Boss",
			"current_level": 0,
			"max_level": 1,
			"enabled": true
		}
	]


static func get_normal_enemy_options() -> Array:
	var options: Array = []
	for archetype_id in NORMAL_ARCHETYPES:
		options.append({
			"id": archetype_id,
			"title": str(NORMAL_ARCHETYPE_LABELS.get(archetype_id, archetype_id)),
			"description": "开发者模式：按当前批量数生成该小怪。\nArchetype: %s" % archetype_id,
			"enabled": true
		})
	return options


static func get_boss_archetypes() -> Array[String]:
	return BOSS_ARCHETYPES.duplicate()


static func get_small_boss_archetypes() -> Array[String]:
	return SMALL_BOSS_ARCHETYPES.duplicate()


static func get_normal_archetypes() -> Array[String]:
	return NORMAL_ARCHETYPES.duplicate()


static func is_boss_archetype(archetype: String) -> bool:
	return get_boss_archetypes().has(archetype)


static func is_small_boss_archetype(archetype: String) -> bool:
	return get_small_boss_archetypes().has(archetype)


static func is_normal_archetype(archetype: String) -> bool:
	return get_normal_archetypes().has(archetype)


static func _load_profile(archetype: String) -> Resource:
	var path: String = str(PROFILE_PATHS.get(archetype, ""))
	if path == "":
		return null
	var profile: Resource = load(path) as Resource
	if profile == null:
		push_warning("Enemy profile not found: %s" % path)
	return profile
