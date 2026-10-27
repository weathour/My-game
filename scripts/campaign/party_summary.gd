extends RefCounted
## Read-only projection of the same content and records used to enter a battle.
const C := preload("res://scripts/content/combat_catalog.gd")
const A := preload("res://scripts/battle/ability_definition.gd")
const STAT_NAMES := {"hp":"生命上限", "mp":"魔法上限", "attack":"攻击", "armor":"防御", "speed":"攻击速度", "move":"移动速度", "regen":"魔法回复", "supply_hp":"补给生命恢复", "supply_mp":"补给魔法恢复"}

static func build(data: Dictionary, characters: Dictionary) -> Dictionary:
	var bonuses := C.owned_bonuses(data.owned)
	var totals := bonuses.duplicate()
	var sources := {}
	for id in data.owned:
		var definition := C.definition(id)
		for key in definition.get("owned", {}):
			if not sources.has(key): sources[key] = []
			var amount := float(definition.owned[key]) * int(data.owned[id].level)
			sources[key].append("%s Lv.%d %s" % [characters[id].name, data.owned[id].level, amount_text(key, amount)])
	if data.equipped.get("armor") == "iron_armor":
		totals.armor = float(totals.get("armor", 0)) + 4.0
		if not sources.has("armor"): sources.armor = []
		sources.armor.append("旧军铁甲 +4")
	var result := {"attributes":[], "supports":[], "equipment":[], "totals":totals}
	for key in STAT_NAMES:
		if is_zero_approx(float(totals.get(key, 0))): continue
		result.attributes.append({"key":key, "title":STAT_NAMES[key], "value":float(totals[key]), "text":amount_text(key, totals[key]), "sources":sources.get(key, [])})
	for id in data.party:
		if str(id).is_empty() or not data.owned.has(id): continue
		var record: Dictionary = data.owned[id]
		var definition := C.definition(id)
		if definition.is_empty():
			result.supports.append({"id":id, "title":characters[id].name, "text":"能力尚未实装", "active":false})
			continue
		var ability: Resource = definition.support
		if ability == null: continue
		var active: bool = not record.dead and int(record.level) >= ability.unlock_level
		var stats := C.attributes(id, int(record.level), bonuses, data.equipped)
		var description := support_text(ability, int(record.level), stats.attack)
		if record.dead: description = "阵亡 · 支援停止"
		elif int(record.level) < ability.unlock_level: description = "Lv.%d 解锁" % ability.unlock_level
		result.supports.append({"id":id, "title":"%s · %s" % [characters[id].name, ability.title], "text":description, "active":active, "interval":ability.cooldown})
	for slot in ["weapon", "armor", "accessory"]:
		for item in C.EQUIPMENT:
			if item.id == data.equipped.get(slot):
				result.equipment.append(item.duplicate())
	return result

static func amount_text(key: String, value: float) -> String:
	if key in ["supply_hp", "supply_mp"]: return "+%s%% 上限" % String.num(value * 100, 2)
	var suffix := " 次/秒" if key == "speed" else " /秒" if key == "regen" else ""
	return "+%s%s" % [String.num(value, 3), suffix]

static func support_text(ability: Resource, level: int, attack: float) -> String:
	var effect := ""
	match ability.kind:
		A.Kind.HEAL: effect = "最多回复当前人物 %s 生命" % String.num(ability.damage_scale + level * 1.5, 2)
		A.Kind.MANA: effect = "最多回复当前人物 %s 魔法" % String.num(ability.damage_scale, 2)
		A.Kind.WARD: effect = "当前人物获得 %s 护盾" % String.num(ability.damage_scale, 2)
		_:
			effect = "基础%s伤害 %s" % ["法术" if ability.damage_type == A.DamageType.MAGIC else "物理", String.num(attack * ability.damage_scale, 2)]
			if ability.slow > 0: effect += "，减速 %s%% · %s秒" % [String.num(ability.slow * 100, 1), String.num(ability.duration, 1)]
	var condition := "；范围内有敌人时发动" if ability.kind in [A.Kind.SWEEP, A.Kind.THRUST, A.Kind.PROJECTILE] else ""
	return "%s%s · 冷却 %s 秒" % [effect, condition, String.num(ability.cooldown, 1)]
