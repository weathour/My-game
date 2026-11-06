extends RefCounted
## Authoritative numeric character kits and read-only projections for battle and panels.
const A := preload("res://scripts/battle/ability_definition.gd")
const STAGES := preload("res://scripts/content/stage_catalog.gd")
const KITS := preload("res://scripts/content/roster_kit_data.gd")
const IDS := ["JIA", "M01", "M02", "M03", "M04", "M05", "M06", "M07", "M08", "F01", "F02", "F03", "F04", "F05", "F06", "F07", "F08", "F09", "F10", "F11", "N01", "N02", "N03", "N04", "N05", "N06", "N07", "N08", "N09", "N10", "N11", "N12", "N13", "N14", "N15", "N16", "N17", "N18"]
const INITIAL_POOL := ["N01", "N04", "N07", "N13", "N16", "N17"]
const OWNED_CAPS := {"hp":180.0, "mp":100.0, "attack":40.0, "armor":20.0, "speed":0.35, "move":35.0, "regen":3.0, "supply_hp":0.3, "supply_mp":0.3}
const GROWTH := {"hp":16.0, "mp":5.0, "attack":3.0, "armor":0.5}
const STAT_LABELS := {"hp":"生命上限", "mp":"魔法上限", "attack":"攻击", "armor":"防御", "speed":"每秒普攻次数", "move":"移速", "regen":"每秒回魔", "supply_hp":"补给回血比例", "supply_mp":"补给回魔比例"}
const EQUIPMENT := [
	{"id":"plain_blade", "name":"旧铁刀", "slot":"weapon", "effect":"主角普攻：近身横斩", "detail":"宽幅横扫；辅助保留自己的攻击形态。", "mark":"刀"},
	{"id":"long_spear", "name":"破阵长枪", "slot":"weapon", "effect":"主角普攻：长线突刺", "detail":"攻击距离更长，命中范围更窄。", "mark":"枪"},
	{"id":"cloth_armor", "name":"行旅布甲", "slot":"armor", "effect":"受伤后移动速度提高25%，持续1.5秒", "detail":"只作用于实际承伤人物。", "mark":"甲"},
	{"id":"iron_armor", "name":"旧军铁甲", "slot":"armor", "effect":"全队防御+4；受伤后获得6点护盾", "detail":"护盾由实际承伤者获得，每2秒至多触发一次。", "mark":"铠"},
	{"id":"ember_seal", "name":"余烬符", "slot":"accessory", "effect":"直接攻击附加15%火焰伤害", "detail":"按发出时的前台攻击判定，后台支援不继承。", "mark":"火"},
	{"id":"frost_jade", "name":"寒泉玉", "slot":"accessory", "effect":"直接攻击使目标减速35%，持续1.5秒", "detail":"切人不改变已发出攻击的附魔资格。", "mark":"霜"}
]
static var _content: Dictionary = {}
static var _spear_basic: Resource

static func definition(id: String) -> Dictionary:
	if _content.is_empty(): _build()
	return _content.get(id, {})

static func _skill(spec: Dictionary) -> Resource:
	var value: Resource = A.make(spec.id, spec.title, A.Kind.get(spec.kind, A.Kind.SWEEP), float(spec.power), float(spec.reach), float(spec.cooldown), float(spec.mana_cost), int(spec.unlock_level))
	value.mechanic = spec.mechanic
	value.params = spec.params.duplicate(true)
	value.target_scope = spec.target_scope
	value.slow = float(spec.slow)
	value.duration = float(spec.duration)
	value.damage_type = A.DamageType.MAGIC if spec.magic else A.DamageType.PHYSICAL
	return value

static func _build() -> void:
	for id in IDS:
		var kit: Dictionary = KITS.DATA[id]
		var manuals: Array = []
		var automatic: Array = []
		for spec in kit.manual: manuals.append(_skill(spec))
		for spec in kit.automatic: automatic.append(_skill(spec))
		var support: Resource = _skill(kit.support) if not kit.support.is_empty() else null
		var item := {"name":kit.name, "entry_level":kit.entry_level, "base":kit.base.duplicate(true), "basic":_skill(kit.basic), "manual":manuals, "automatic":automatic, "support":support,
			"owned":kit.owned.duplicate(true), "trait":kit.trait, "trait_params":kit.trait_params.duplicate(true), "back_text":"", "owned_text":""}
		item.owned_text = _owned_description(item.owned)
		item.back_text = _back_description(item)
		for key in ["base", "owned", "trait_params", "manual", "automatic"]: item[key].make_read_only()
		item.make_read_only()
		_content[id] = item

static func entry_level(id: String) -> int:
	return int(definition(id).get("entry_level", 1))

static func owned_raw_bonuses(records: Dictionary) -> Dictionary:
	var result := {}
	for id in records:
		var def: Dictionary = definition(str(id))
		var level: int = maxi(1, int(records[id].get("level", 1)))
		for stat in def.get("owned", {}): result[stat] = float(result.get(stat, 0.0)) + float(def.owned[stat]) * level
	return result

static func owned_bonuses(records: Dictionary) -> Dictionary:
	var result: Dictionary = owned_raw_bonuses(records)
	for stat in result: result[stat] = minf(float(result[stat]), float(OWNED_CAPS.get(stat, result[stat])))
	return result

static func attributes(id: String, level: int, bonuses: Dictionary = {}, equipment: Dictionary = {}) -> Dictionary:
	var def: Dictionary = definition(id)
	if def.is_empty(): return {}
	var stats: Dictionary = def.base.duplicate()
	for key in GROWTH: stats[key] += (maxi(level, 1) - 1) * float(GROWTH[key])
	for key in stats: stats[key] += float(bonuses.get(key, 0.0))
	if equipment.get("armor", "") == "iron_armor": stats.armor += 4.0
	return stats

static func record(id: String, level: int = 1) -> Dictionary:
	var stats: Dictionary = attributes(id, level)
	return {"level":level, "xp":0.0, "hp":stats.hp, "mp":stats.mp, "dead":false, "cooldowns":{}}

static func xp_required(level: int) -> float:
	return 18.0 + level * 12.0

static func basic(id: String, equipment: Dictionary) -> Resource:
	definition(id)
	if id == "JIA" and equipment.get("weapon", "") == "long_spear":
		if _spear_basic == null: _spear_basic = A.make("JIA_basic", "突刺", A.Kind.THRUST, 1.15, 180, 1.0 / 1.45)
		return _spear_basic
	return definition(id).basic

static func stage(id: String) -> Dictionary:
	return STAGES.stage(id)

static func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else ("%.2f" % value).rstrip("0").rstrip(".")

static func _scope_label(scope: String) -> String:
	return {"active":"当前人物", "self":"施放者本人", "party":"全部存活编队人物", "lowest_hp":"生命比例最低的存活编队人物", "lowest_mp":"魔法比例最低的存活编队人物"}.get(scope, "当前人物")

static func _owned_description(values: Dictionary) -> String:
	if values.is_empty(): return "固定主角；阵亡则本关失败。"
	var lines: Array[String] = []
	for stat in values:
		var amount: float = float(values[stat])
		var suffix := "%" if stat in ["supply_hp", "supply_mp"] else ""
		lines.append("每级%s＋%s%s" % [STAT_LABELS.get(stat, stat), _number(amount * 100 if not suffix.is_empty() else amount), suffix])
	return "；".join(lines) + "。持有即生效，候补与阵亡仍保留；全库同属性合计有上限。"

static func trait_description(id: String) -> String:
	var def: Dictionary = definition(id)
	var p: Dictionary = def.get("trait_params", {})
	match str(def.get("trait", "")):
		"echo": return "付费法术留下记录；离场后，其他存活队友实际付费施法消耗1次，重放伤害、减速强度与时长均削弱的版本。回响不再触发施法。"
		"ammo": return "特制箭上限%d，进关%d；每%s秒补%d，其他编队队友成功付费施法补%d。后台强化追击每%s秒至多花1；前台普攻不花箭。" % [p.get("capacity",6),p.get("initial",6),_number(p.get("refill_interval",8)),p.get("refill_amount",2),p.get("cast_refill",1),_number(p.get("followup_interval",2))]
		"refund": return "在后台时，其他队友实际扣除魔法的%s%%会在%s秒内分%s次返还原施法者；返还不再触发施法。" % [_number(100 * p.get("fraction",.2)),_number(p.get("duration",6)),p.get("ticks",3)]
		"relay": return "上一位成功付费施法者与本次不同时，本次耗魔减少%s%%，最低仍付%s；同一人连放不奖励，换人不算施法。" % [_number(100*p.get("fraction",.2)),_number(p.get("min_cost",1))]
		"curse": return "本人直接普攻／自动攻击至多每%s秒挂一次咒伤，%s秒共造成%s%%攻击伤害；相同来源刷新而不无限叠加。" % [_number(p.get("interval",2)),_number(p.get("duration",5)),_number(100*p.get("dot_scale",.3))]
		"mark": return "在后台时，前台真实普攻命中每%d次触发一次本人的支援，至少间隔%s秒；同一次普攻命中多人只算1次，追击不再累计。" % [p.get("hits",3),_number(p.get("interval",1))]
	return ""

static func _back_description(def: Dictionary) -> String:
	var support: Resource = def.support
	if support == null: return "无后台支援；主角保留独立生命、魔法与冷却。"
	var condition := "后台每%s秒自动发动" % _number(support.cooldown)
	if def.trait == "mark": condition = "后台由前台普攻累计命中触发"
	elif def.trait == "ammo": condition = "后台由前台直接攻击命中触发，至少间隔%s秒" % _number(def.trait_params.followup_interval)
	return "%s「%s」，不耗魔法；仅配置且存活时生效。" % [condition,support.title]

static func ability_description(ability: Resource, level: int = 1, attack: float = 0.0) -> String:
	if ability == null: return ""
	var p: Dictionary = ability.params
	var lines: Array[String] = []
	var kind: int = int(ability.kind)
	if str(ability.mechanic) in ["guard", "temper", "rally", "extend", "field", "refund_settle"]: pass
	elif kind == A.Kind.HEAL: lines.append("为%s恢复%s生命" % [_scope_label(ability.target_scope),_number(ability.damage_scale + level * 1.5)])
	elif kind == A.Kind.MANA and ability.mechanic != "refund_settle": lines.append("为%s恢复%s魔法" % [_scope_label(ability.target_scope),_number(ability.damage_scale)])
	elif kind == A.Kind.WARD: lines.append("给%s提供%s护盾；每位受益者的总护盾不超过自身生命上限的%s%%" % [_scope_label(ability.target_scope),_number(ability.damage_scale),_number(100 * float(p.get("shield_cap_ratio",.35)))])
	elif kind not in [A.Kind.MANA]:
		var shape: String = {A.Kind.SWEEP:"扇形",A.Kind.THRUST:"贯穿直线",A.Kind.PROJECTILE:"单体弹道",A.Kind.NOVA:"圆形范围"}.get(kind,"攻击")
		var damage: String = "%s%%攻击" % _number(ability.damage_scale * 100)
		if attack > 0: damage += "（约%s基础伤害）" % _number(attack * ability.damage_scale)
		lines.append("%s攻击，范围%s，造成%s" % [shape,_number(ability.reach),damage])
	if ability.slow > 0 and ability.duration > 0: lines.append("减速%s%%，持续%s秒" % [_number(100*ability.slow),_number(ability.duration)])
	match str(ability.mechanic):
		"echo_record": lines.append("付费成功后替换为%d次记录，保留%s秒；离场后队友付费技能触发原伤害%s%%、减速强度与时长各为原%s%%的回响" % [p.get("charges",2),_number(p.get("duration",12)),_number(100*p.get("damage_multiplier",.45)),_number(100*p.get("slow_multiplier",.5))])
		"party_heal": lines.append("逐人溢出治疗转为各自护盾，总盾不超过各自生命上限%s%%；不复活" % _number(100*p.get("shield_cap_ratio",.35)))
		"shield_strike": lines.append("成功施放后消耗自身至多%s盾；每点使本击伤害＋%s%%，满额增加%s范围；无盾仍有基础攻击" % [_number(p.get("shield_max",30)),_number(100*p.get("shield_ratio",.06)),_number(p.get("reach_bonus",80))])
		"guard": lines.append("%s进入%s秒守势；至多承接%d次敌击，减伤%s%%并在%s范围反击%s%%攻击；敌击被护盾吸收也可触发，反击不递归" % [_scope_label(ability.target_scope),_number(p.get("duration",4)),p.get("charges",1),_number(100*p.get("reduction",.5)),_number(p.get("radius",150)),_number(100*p.get("counter_scale",1.5))])
		"refund_settle": lines.append("提前结清本人的返还能力尚未付出的余额；不额外复制返还，仍付自身魔法与冷却")
		"curse":
			lines.append("命中附加%s秒咒伤，总计%s%%攻击；同源刷新" % [_number(p.get("duration",6)),_number(100*p.get("dot_scale",1))])
			if p.get("spread_targets",0) > 0: lines.append("已有咒伤时向%s范围至多%d个邻敌复制%s%%剩余咒伤，不递归传播" % [_number(p.get("spread_radius",160)),p.spread_targets,_number(100*p.get("spread_fraction",0))])
		"curse_cashout": lines.append("提前结算并移除目标剩余咒伤的%s%%；未中咒也有基础伤害" % _number(100*p.get("fraction",.5)))
		"ammo_followup": lines.append("有箭消耗1特制箭；无箭仍有%s%%威力普通支援，不继承当前人物饰品" % _number(100*p.get("normal_multiplier",.4)))
		"ammo_volley": lines.append("消耗至多%d箭，每箭使本击伤害＋%s%%；零箭仍能普通齐射" % [p.get("max_spend",4),_number(100*p.get("bonus_per_arrow",.35))])
		"temper": lines.append("%s直接攻击强化%s秒，范围＋%s，并产生%s范围／%s%%攻击的次级火花；后台支援不继承，火花不再触发命中" % [_scope_label(ability.target_scope),_number(p.get("duration",8)),_number(p.get("reach_bonus",50)),_number(p.get("splash_radius",45)),_number(100*p.get("spark_scale",.25))])
		"extend": lines.append("将其他存活队友已生效的法术记录／淬刃延长%s秒；同一实例总延长上限%s秒，不补次数、不会恢复已结束的效果" % [_number(p.get("seconds",2)),_number(p.get("max_extension",4))])
		"expose": lines.append("使命中目标承伤增加%s%%，持续%s秒；同类取最强不相加" % [_number(100*p.get("multiplier",.15)),_number(p.get("duration",4))])
		"rally": lines.append("%s获得%s秒强化：攻击＋%s%%、攻速＋%s%%；同类取最强" % [_scope_label(ability.target_scope),_number(p.get("duration",6)),_number(100*p.get("attack_multiplier",.15)),_number(100*p.get("speed_multiplier",0))])
		"dash":
			var distance: float = float(p.get("distance",100))
			lines.append(("沿攻击方向后撤%s，不提供无敌" if distance < 0 else "向攻击方向移动%s，不提供无敌") % _number(absf(distance)))
		"field":
			lines.append("原地部署半径%s区域%s秒，每%s秒造成%s%%施放者攻击伤害；离场后仍按施放者计算" % [_number(p.get("radius",120)),_number(p.get("duration",6)),_number(p.get("interval",1)),_number(ability.damage_scale*100)])
			if float(p.get("heal",0)) > 0: lines.append("每次脉冲为区域内的%s恢复%s生命" % [_scope_label(ability.target_scope),_number(p.get("heal",0))])
			if float(p.get("mana",0)) > 0: lines.append("每次脉冲为区域内的%s恢复%s魔法" % [_scope_label(ability.target_scope),_number(p.get("mana",0))])

	if level < ability.unlock_level: lines.append("Lv.%d解锁" % ability.unlock_level)
	return "；".join(lines) + "。"

static func _ability_view(ability: Resource, level: int, attack: float, speed: float = 0.0) -> Dictionary:
	if ability == null: return {}
	var interval: float = 1.0 / speed if str(ability.id).ends_with("_basic") and speed > 0 else ability.cooldown
	return {"id":str(ability.id),"title":ability.title,"unlock_level":ability.unlock_level,"unlocked":level>=ability.unlock_level,"cooldown":interval,"mana_cost":ability.mana_cost,"reach":ability.reach,"kind":A.Kind.keys()[ability.kind],"mechanic":ability.mechanic,"params":ability.params.duplicate(true),"target_scope":ability.target_scope,"description":ability_description(ability,level,attack)}

static func character_details(id: String, level: int, bonuses: Dictionary = {}, equipment: Dictionary = {}) -> Dictionary:
	var def: Dictionary = definition(id)
	if def.is_empty(): return {}
	var stats: Dictionary = attributes(id,level,bonuses,equipment)
	var manuals: Array = []
	var automatic: Array = []
	for ability in def.manual: manuals.append(_ability_view(ability,level,stats.attack))
	for ability in def.automatic: automatic.append(_ability_view(ability,level,stats.attack))
	return {"id":id,"name":def.name,"entry_level":entry_level(id),"level":level,"stats":stats,"base_stats":def.base.duplicate(true),"growth":GROWTH.duplicate(),"basic":_ability_view(basic(id,equipment),level,stats.attack,stats.speed),"automatic":automatic,"manual":manuals,"support":_ability_view(def.support,level,stats.attack),"trait":def.trait,"trait_params":def.trait_params.duplicate(true),"trait_description":trait_description(id),"back_text":def.back_text,"owned_text":def.owned_text,"owned":def.owned.duplicate(true)}
