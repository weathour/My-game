extends RefCounted
## Read-only UI projection. Numeric effects and descriptions come from the battle catalog.
const C := preload("res://scripts/content/combat_catalog.gd")
const SUMMARY := preload("res://scripts/campaign/party_summary.gd")
const ATTRIBUTE_ORDER := ["hp", "mp", "attack", "armor", "speed", "move", "regen"]

static func build(data: Dictionary, characters: Dictionary, id: String) -> Dictionary:
	var owned: bool = data.owned.has(id)
	var level: int = int(data.owned[id].level) if owned else C.entry_level(id)
	var bonuses: Dictionary = C.owned_bonuses(data.owned)
	var model: Dictionary = C.character_details(id, level, bonuses, data.equipped)
	model.owned = owned
	model.preview = not owned
	model.dead = owned and bool(data.owned[id].dead)
	model.configured = id in data.party
	model.gate = str(characters[id].get("gate", ""))
	model.attribute_lines = []
	model.attribute_rows = []
	var natural: Dictionary = C.attributes(id, level)
	var with_owned: Dictionary = C.attributes(id, level, bonuses)
	for key in model.stats:
		var growth: float = float(natural[key]) - float(model.base_stats[key])
		var passive: float = float(with_owned[key]) - float(natural[key])
		var equipment: float = float(model.stats[key]) - float(with_owned[key])
		model.attribute_rows.append({"key":key,"title":str(SUMMARY.STAT_NAMES.get(key,key)),"current":float(model.stats[key]),"base":float(model.base_stats[key]),"growth":growth,"owned":passive,"equipment":equipment})
		model.attribute_lines.append("%s  %s\n  Lv.1基础 %s  累计成长 %s  持有 %s  装备 %s" % [SUMMARY.STAT_NAMES.get(key, key), String.num(model.stats[key], 3), String.num(model.base_stats[key], 3), signed(growth), signed(passive), signed(equipment)])
	model.attribute_rows.sort_custom(func(a: Dictionary,b: Dictionary): return ATTRIBUTE_ORDER.find(str(a.key)) < ATTRIBUTE_ORDER.find(str(b.key)))
	model.owned_lines = []
	var definition: Dictionary = C.definition(id)
	for key in definition.get("owned", {}):
		var amount: float = float(definition.owned[key]) * level
		var cap: float = float(C.OWNED_CAPS.get(key, 0))
		model.owned_lines.append("%s：本卡 Lv.%d %s%s；全队实际 %s，上限 %s" % [SUMMARY.STAT_NAMES.get(key, key), level, SUMMARY.amount_text(key, amount), "（预览，未计入）" if not owned else "（封顶前）", SUMMARY.amount_text(key, float(bonuses.get(key, 0))), SUMMARY.amount_text(key, cap)])
	if model.support.is_empty(): model.support_state = "无后台支援"
	elif not owned: model.support_state = "能力预览 · 获得并配置后可触发"
	elif model.dead: model.support_state = "阵亡 · 支援停止"
	elif not bool(model.support.unlocked): model.support_state = "Lv.%d 解锁 · 当前未解锁" % model.support.unlock_level
	elif not model.configured: model.support_state = "未配置 · 支援不触发"
	else: model.support_state = "已配置 · 后台时可触发"
	var record: Dictionary = data.owned.get(id, {})
	var has_xp := owned and record.has("xp")
	model.experience = {"available":has_xp,"value":float(record.xp) if has_xp else null,"required":C.xp_required(level) if has_xp else null}
	model.resources = {"available":owned,"hp":float(record.get("hp",0)) if owned else null,"mp":float(record.get("mp",0)) if owned else null,"max_hp":float(model.stats.hp),"max_mp":float(model.stats.mp)}
	model.next_unlock = {}
	var candidates: Array = [model.basic] + model.automatic + model.manual + [model.support]
	for ability in candidates:
		if ability.is_empty() or bool(ability.unlocked): continue
		if model.next_unlock.is_empty() or int(ability.unlock_level) < int(model.next_unlock.level):
			model.next_unlock = {"id":str(ability.id),"title":str(ability.title),"level":int(ability.unlock_level)}
	return model

static func signed(value: float) -> String:
	return ("+" if value >= 0 else "") + String.num(value, 3)
