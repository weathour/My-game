extends RefCounted

const PROFILE_PATHS := {
	"chaser": "res://data/enemies/chaser.tres",
	"shooter": "res://data/enemies/shooter.tres",
	"brute": "res://data/enemies/brute.tres",
	"runner": "res://data/enemies/runner.tres",
	"swarm": "res://data/enemies/swarm.tres",
	"dasher": "res://data/enemies/dasher.tres",
	"shotgunner": "res://data/enemies/shotgunner.tres",
	"skull_mage": "res://data/enemies/skull_mage.tres",
	"vine": "res://data/enemies/vine.tres",
	"shadow_tree": "res://data/enemies/shadow_tree.tres",
	"shadow_tree_young": "res://data/enemies/shadow_tree_young.tres",
	"tree_seed": "res://data/enemies/tree_seed.tres",
	"necro_priest": "res://data/enemies/necro_priest.tres",
	"angry_porcupine": "res://data/enemies/angry_porcupine.tres",
	"elite_ram_trail": "res://data/enemies/elite_ram_trail.tres",
	"elite_splitshot": "res://data/enemies/elite_splitshot.tres",
	"smallboss_glutton": "res://data/enemies/smallboss_glutton.tres",
	"smallboss_rebirth": "res://data/enemies/smallboss_rebirth.tres",
	"smallboss_turret": "res://data/enemies/smallboss_turret.tres",
	"boss_spellcore": "res://data/enemies/boss_spellcore.tres"
}

const BOSS_ARCHETYPES: Array[String] = ["boss_spellcore"]
const SMALL_BOSS_ARCHETYPES: Array[String] = ["smallboss_glutton", "smallboss_rebirth", "smallboss_turret"]
const ELITE_ARCHETYPES: Array[String] = ["elite_ram_trail", "elite_splitshot"]
const NORMAL_ARCHETYPES: Array[String] = ["chaser", "runner", "swarm", "shooter", "brute", "dasher", "shotgunner", "skull_mage", "vine", "shadow_tree", "shadow_tree_young", "necro_priest", "angry_porcupine"]
const INTERNAL_ARCHETYPES: Array[String] = ["tree_seed"]
const NORMAL_ARCHETYPE_LABELS := {
	"chaser": "追击菇",
	"runner": "疾行史莱姆",
	"swarm": "飞眼群",
	"shooter": "远程骷髅",
	"brute": "重甲南瓜",
	"dasher": "冲锋怪",
	"shotgunner": "散弹骷髅",
	"skull_mage": "骷髅法师",
	"vine": "藤蔓怪",
	"shadow_tree": "幽影树怪",
	"shadow_tree_young": "幽影树怪·幼年",
	"necro_priest": "亡灵牧师",
	"angry_porcupine": "愤怒豪猪"
}
const ELITE_ARCHETYPE_LABELS := {
	"elite_ram_trail": "精英冲锋骷髅",
	"elite_splitshot": "精英分裂骷髅"
}


static func get_profile(_kind: String, archetype: String) -> Dictionary:
	var profile: Resource = _load_profile(archetype)
	if profile != null and profile.has_method("to_dictionary"):
		return profile.to_dictionary()
	return {}


# 仅旧档恢复允许退回基础敌人；作者内容与正式生成必须使用严格查询。
static func get_profile_for_restore(kind: String, archetype: String) -> Dictionary:
	var profile := get_profile(kind, archetype)
	return get_profile("normal", "chaser") if profile.is_empty() else profile


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


static func get_developer_enemy_options() -> Array:
	var options: Array = []
	for archetype_id in NORMAL_ARCHETYPES:
		options.append(_build_developer_enemy_option("normal", archetype_id, str(NORMAL_ARCHETYPE_LABELS.get(archetype_id, archetype_id)), "普通怪"))
	for archetype_id in ELITE_ARCHETYPES:
		options.append(_build_developer_enemy_option("elite", archetype_id, str(ELITE_ARCHETYPE_LABELS.get(archetype_id, archetype_id)), "精英怪"))
	for archetype_id in SMALL_BOSS_ARCHETYPES:
		var profile := get_profile("small_boss", archetype_id)
		options.append(_build_developer_enemy_option("small_boss", archetype_id, str(profile.get("boss_name", archetype_id)), "小 Boss"))
	for archetype_id in BOSS_ARCHETYPES:
		var profile := get_profile("boss", archetype_id)
		options.append(_build_developer_enemy_option("boss", archetype_id, str(profile.get("boss_name", archetype_id)), "Boss"))
	return options


static func get_boss_archetypes() -> Array[String]:
	return BOSS_ARCHETYPES.duplicate()


static func get_small_boss_archetypes() -> Array[String]:
	return SMALL_BOSS_ARCHETYPES.duplicate()


static func get_normal_archetypes() -> Array[String]:
	return NORMAL_ARCHETYPES.duplicate()


static func get_elite_archetypes() -> Array[String]:
	return ELITE_ARCHETYPES.duplicate()


static func get_enemy_kind_for_archetype(archetype: String) -> String:
	if is_boss_archetype(archetype):
		return "boss"
	if is_small_boss_archetype(archetype):
		return "small_boss"
	if is_elite_archetype(archetype):
		return "elite"
	if is_normal_archetype(archetype):
		return "normal"
	return ""


static func is_boss_archetype(archetype: String) -> bool:
	return get_boss_archetypes().has(archetype)


static func is_small_boss_archetype(archetype: String) -> bool:
	return get_small_boss_archetypes().has(archetype)


static func is_normal_archetype(archetype: String) -> bool:
	return get_normal_archetypes().has(archetype)


static func is_elite_archetype(archetype: String) -> bool:
	return get_elite_archetypes().has(archetype)


static func _load_profile(archetype: String) -> Resource:
	var path: String = str(PROFILE_PATHS.get(archetype, ""))
	if path == "":
		return null
	var profile: Resource = load(path) as Resource
	if profile == null:
		push_warning("Enemy profile not found: %s" % path)
	return profile


static func _build_developer_enemy_option(kind: String, archetype_id: String, title: String, category: String) -> Dictionary:
	return {
		"id": "%s:%s" % [kind, archetype_id],
		"kind": kind,
		"archetype": archetype_id,
		"title": "%s｜%s" % [category, title],
		"description": "开发者模式：生成 %s。Archetype: %s" % [category, archetype_id],
		"enabled": true
	}
