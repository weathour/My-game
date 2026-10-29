extends RefCounted
## Read-only projection of the same content and records used to enter a battle.
const C := preload("res://scripts/content/combat_catalog.gd")
const A := preload("res://scripts/battle/ability_definition.gd")
const STAT_NAMES := {"hp":"生命上限", "mp":"魔法上限", "attack":"攻击", "armor":"防御", "speed":"攻击速度", "move":"移动速度", "regen":"魔法回复", "supply_hp":"补给生命恢复", "supply_mp":"补给魔法恢复"}

static func build(data: Dictionary, characters: Dictionary) -> Dictionary:
	var bonuses := C.owned_bonuses(data.owned)
	var raw: Dictionary = C.owned_raw_bonuses(data.owned)
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

	var result := {"attributes":[], "supports":[], "equipment":[], "totals":totals}
	for key in STAT_NAMES:
		if is_zero_approx(float(totals.get(key, 0))): continue
		result.attributes.append({"key":key, "title":STAT_NAMES[key], "value":float(totals[key]), "text":amount_text(key, totals[key]), "sources":sources.get(key, []), "raw":float(raw.get(key, 0)), "cap":float(C.OWNED_CAPS.get(key, 0)), "owned_value":float(bonuses.get(key, 0)), "equipment_value":float(totals[key]) - float(bonuses.get(key, 0))})
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
		var description := str(definition.back_text) + "\n" + C.ability_description(ability, int(record.level), stats.attack)
		if record.dead: description = "阵亡 · 支援停止"
		elif int(record.level) < ability.unlock_level: description = "Lv.%d 解锁" % ability.unlock_level
		result.supports.append({"id":id, "title":"%s · %s" % [characters[id].name, ability.title], "text":description, "active":active, "interval":ability.cooldown, "mechanic":C.trait_description(id)})
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
	return C.ability_description(ability, level, attack)

static func source_text(stat: Dictionary) -> String:
	var lines: Array[String] = [str(stat.title), "封顶前持有总额：" + amount_text(stat.key, stat.raw), "持有上限：" + amount_text(stat.key, stat.cap), "实际持有加成：" + amount_text(stat.key, stat.owned_value)]
	if not is_zero_approx(float(stat.equipment_value)): lines.append("装备加成：" + amount_text(stat.key, stat.equipment_value))
	lines.append("实际加成：" + str(stat.text))
	lines.append("\n持有来源显示封顶前数值；超过上限的部分不计入实际加成。")
	for source in stat.sources: lines.append(str(source))
	return "\n".join(lines)
