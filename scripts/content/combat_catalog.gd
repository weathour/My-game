extends RefCounted
## First playable content. Unimplemented catalogue cards are never silently mapped to a generic hero.
const A := preload("res://scripts/battle/ability_definition.gd")
const STAGES := preload("res://scripts/content/stage_catalog.gd")
const IDS := ["JIA", "F11", "N01", "N04", "N07", "N13", "N16", "N17", "F03", "N18", "F07", "N14"]
const INITIAL_POOL := ["N01", "N04", "N07", "N13", "N16", "N17"]
const EQUIPMENT := [
	{"id":"plain_blade", "name":"旧铁刀", "slot":"weapon", "effect":"主角普攻：近身横斩", "detail":"宽幅横扫；辅助保留自己的攻击形态。", "mark":"刀"},
	{"id":"long_spear", "name":"破阵长枪", "slot":"weapon", "effect":"主角普攻：长线突刺", "detail":"攻击距离更长，命中范围更窄。", "mark":"枪"},
	{"id":"cloth_armor", "name":"行旅布甲", "slot":"armor", "effect":"受伤后移动速度提高25%，持续1.5秒", "detail":"只作用于实际承伤人物。", "mark":"甲"},
	{"id":"iron_armor", "name":"旧军铁甲", "slot":"armor", "effect":"全队防御+4；受伤后获得6点护盾", "detail":"护盾由实际承伤者获得，每2秒至多触发一次。", "mark":"铠"},
	{"id":"ember_seal", "name":"余烬符", "slot":"accessory", "effect":"直接攻击附加15%火焰伤害", "detail":"按发出时的前台攻击判定，后台支援不继承。", "mark":"火"},
	{"id":"frost_jade", "name":"寒泉玉", "slot":"accessory", "effect":"直接攻击使目标减速35%，持续1.5秒", "detail":"切人不改变已发出攻击的附魔资格。", "mark":"霜"}
]
static var _content: Dictionary = {}

static func definition(id: String) -> Dictionary:
	if _content.is_empty(): _build()
	return _content.get(id, {})

static func _build() -> void:
	var rows := [
		["JIA", 220, 90, 27, 7, 1.45, 215, 2.8, A.Kind.SWEEP, 112],
		["F11", 155, 130, 25, 3, 1.15, 205, 4.2, A.Kind.PROJECTILE, 470],
		["N01", 240, 80, 21, 12, 1.1, 190, 2.0, A.Kind.SWEEP, 104],
		["N04", 185, 85, 24, 6, 1.0, 205, 2.1, A.Kind.THRUST, 165],
		["N07", 150, 90, 19, 3, 1.45, 215, 2.4, A.Kind.PROJECTILE, 480],
		["N13", 145, 140, 16, 3, 1.0, 200, 5.0, A.Kind.PROJECTILE, 400],
		["N16", 170, 120, 14, 4, 1.0, 200, 3.2, A.Kind.SWEEP, 95],
		["N17", 205, 95, 17, 6, 1.1, 205, 2.6, A.Kind.SWEEP, 100],
		["F03", 145, 145, 11, 3, 1.0, 200, 4.0, A.Kind.PROJECTILE, 400],
		["N18", 170, 105, 12, 5, 1.0, 200, 3.2, A.Kind.SWEEP, 100],
		["F07", 175, 95, 31, 2, 1.6, 225, 2.2, A.Kind.SWEEP, 120],
		["N14", 145, 125, 20, 3, 1.0, 200, 3.5, A.Kind.PROJECTILE, 460]
	]
	for row in rows:
		var id: String = row[0]
		var basic: Resource = A.make(id + "_basic", "普攻", row[8], 1.0, row[9], 1.0 / float(row[5]))
		_content[id] = {"base":{"hp":float(row[1]), "mp":float(row[2]), "attack":float(row[3]), "armor":float(row[4]), "speed":float(row[5]), "move":float(row[6]), "regen":float(row[7])},
			"basic":basic, "automatic":[], "manual":[A.make(id + "_strike", "蓄势一击", row[8], 3.2, row[9] + 25, 7, 24)], "support":null, "owned":{}, "back_text":"", "owned_text":""}
	_content.JIA.manual = [A.make("jia_sweep", "横扫", A.Kind.NOVA, 2.5, 150, 5, 22), A.make("jia_break", "破阵", A.Kind.THRUST, 4.5, 245, 10, 36, 3)]
	_content.F11.manual = [A.make("emma_frost", "霜环", A.Kind.NOVA, 1.8, 190, 7, 28), A.make("emma_star", "星火", A.Kind.PROJECTILE, 5.0, 580, 11, 42, 3)]
	_content.F11.manual[0].slow = 0.6
	_content.F11.manual[0].duration = 3.0
	var ice: Resource = A.make("emma_ice", "冰星", A.Kind.PROJECTILE, 1.8, 480, 8, 0, 2)
	ice.slow = 0.3
	ice.duration = 1.8
	_content.F11.automatic = [ice]
	_content.F11.support = A.make("emma_support", "术法支援", A.Kind.PROJECTILE, 0.8, 500, 3.5)
	_content.N01.support = A.make("militia_support", "援斩", A.Kind.SWEEP, 0.8, 135, 4)
	_content.N04.support = A.make("spear_support", "援刺", A.Kind.THRUST, 1.2, 210, 4.5)
	_content.N07.support = A.make("bow_support", "援射", A.Kind.PROJECTILE, 1.0, 520, 3)
	_content.N13.support = A.make("talisman_support", "回元", A.Kind.MANA, 6, 0, 5)
	_content.N16.support = A.make("healer_support", "敷药", A.Kind.HEAL, 7, 0, 7)
	_content.N17.support = A.make("cook_support", "热汤", A.Kind.HEAL, 4, 0, 5)
	_content.N16.manual = [A.make("healer_aid", "急救", A.Kind.HEAL, 45, 0, 12, 32)]
	_content.N17.manual = [A.make("cook_guard", "护身", A.Kind.WARD, 45, 0, 12, 30)]
	_content.F03.manual = [A.make("physician_heal", "回春", A.Kind.HEAL, 65, 0, 10, 34), A.make("physician_ward", "护命", A.Kind.WARD, 70, 0, 16, 42, 5)]
	_content.F03.support = A.make("physician_support", "敷药", A.Kind.HEAL, 12, 0, 6)
	_content.N18.manual = [A.make("clerk_guard", "护身符", A.Kind.WARD, 55, 0, 13, 30)]
	_content.N18.support = A.make("clerk_support", "回元", A.Kind.MANA, 8, 0, 6)
	_content.F07.manual = [A.make("bandit_sweep", "寨风斩", A.Kind.NOVA, 3.0, 165, 6, 28), A.make("bandit_thrust", "断阵刺", A.Kind.THRUST, 4.2, 230, 10, 38, 5)]
	_content.F07.support = A.make("bandit_support", "援斩", A.Kind.SWEEP, 1.1, 150, 4)
	_content.F07.support.slow = 0.45
	_content.F07.support.duration = 1.5
	_content.N14.manual = [A.make("curse_bind", "缚行咒", A.Kind.NOVA, 2.0, 210, 9, 30)]
	_content.N14.manual[0].slow = 0.65
	_content.N14.manual[0].duration = 3.5
	_content.N14.support = A.make("curse_support", "缚行咒", A.Kind.PROJECTILE, 0.65, 480, 4.5)
	_content.N14.support.slow = 0.4
	_content.N14.support.duration = 2.0
	var bonuses := {"JIA":{}, "F11":{"regen":0.15}, "N01":{"attack":0.5}, "N04":{"attack":0.35}, "N07":{"speed":0.012}, "N13":{"regen":0.25}, "N16":{"supply_hp":0.025}, "N17":{"supply_mp":0.04}}
	var notes := {"JIA":"主角阵亡即本关失败。", "F11":"每级为全队提供0.15魔法回复。", "N01":"每级为全队提供0.5攻击。", "N04":"每级为全队提供0.35攻击。", "N07":"每级为全队提供0.012攻击速度。", "N13":"每级为全队提供0.25魔法回复。", "N16":"每级提高补给场域生命恢复2.5%。", "N17":"每级提高补给场域魔法恢复4%。"}
	bonuses.merge({"F03":{"armor":0.12}, "N18":{"supply_mp":0.03}, "F07":{"attack":0.4}, "N14":{"regen":0.12}})
	notes.merge({"F03":"每级为全队提供0.12防御。", "N18":"每级提高补给场域魔法恢复3%。", "F07":"每级为全队提供0.4攻击。", "N14":"每级为全队提供0.12魔法回复。"})
	for id in IDS:
		_content[id].owned = bonuses[id]
		_content[id].owned_text = notes[id]
		var ability: Resource = _content[id].support
		_content[id].back_text = "无后台支援，主角仍保留独立生命与冷却。" if ability == null else "后台每%.1f秒自动施放「%s」；不耗魔法，阵亡停止。" % [ability.cooldown, ability.title]
		if id in ["F11", "N13", "N14", "F03"]:
			_content[id].basic.damage_type = A.DamageType.MAGIC
			for skill in _content[id].manual + _content[id].automatic: skill.damage_type = A.DamageType.MAGIC
			if ability != null: ability.damage_type = A.DamageType.MAGIC
		for key in ["base", "owned", "manual", "automatic"]: _content[id][key].make_read_only()
		_content[id].make_read_only()

static func owned_bonuses(records: Dictionary) -> Dictionary:
	var result := {}
	for id in records:
		var def := definition(id)
		for stat in def.get("owned", {}): result[stat] = float(result.get(stat, 0)) + float(def.owned[stat]) * int(records[id].level)
	return result

static func attributes(id: String, level: int, bonuses: Dictionary = {}, equipment: Dictionary = {}) -> Dictionary:
	var def := definition(id)
	if def.is_empty(): return {}
	var stats: Dictionary = def.base.duplicate()
	stats.hp += (level - 1) * 16
	stats.mp += (level - 1) * 5
	stats.attack += (level - 1) * 3.0
	stats.armor += (level - 1) * 0.5
	for key in stats: stats[key] += float(bonuses.get(key, 0))
	if equipment.get("armor") == "iron_armor": stats.armor += 4
	return stats

static func record(id: String, level: int = 1) -> Dictionary:
	var stats := attributes(id, level)
	return {"level":level, "xp":0.0, "hp":stats.hp, "mp":stats.mp, "dead":false, "cooldowns":{}}

static func xp_required(level: int) -> float:
	return 18.0 + level * 12.0

static func basic(id: String, equipment: Dictionary) -> Resource:
	definition(id)
	if id == "JIA" and equipment.get("weapon") == "long_spear":
		if not _content.has("_spear"): _content._spear = A.make("JIA_basic", "突刺", A.Kind.THRUST, 1.15, 180, 1.0 / 1.45)
		return _content._spear
	return definition(id).basic

static func stage(id: String) -> Dictionary:
	return STAGES.stage(id)
