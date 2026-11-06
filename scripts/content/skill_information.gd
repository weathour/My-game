extends RefCounted
## Read-only explanations. Never activates an ability or changes battle intent/targets.
const C := preload("res://scripts/content/combat_catalog.gd")
const A := preload("res://scripts/battle/ability_definition.gd")
const COPY_PATH := "res://assets/data/chronicle/skill_information_copy.json"
const WINDOW_MECHANICS := ["guard", "temper", "rally", "extend", "field", "refund_settle"]
static var _copy: Dictionary = {}
static var _loaded := false

static func _load_copy() -> Dictionary:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(COPY_PATH):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COPY_PATH))
			if parsed is Dictionary: _copy = parsed
	return _copy

static func number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else ("%.2f" % value).rstrip("0").rstrip(".")

static func text(key: String, values: Dictionary = {}) -> String:
	var value: Variant = _load_copy().get("templates", {}).get(key, "")
	return str(value).format(values) if value is String else ""

static func ui(key: String, fallback: String = "") -> String:
	var value: Variant = _load_copy().get("ui", {}).get(key, fallback)
	return value if value is String else fallback

static func character(id: String) -> Dictionary:
	var value: Dictionary = _load_copy().get("characters", {}).get(id, {})
	return {"overview":str(value.get("overview", "")), "tags":value.get("tags", []).duplicate()}

static func _add(lines: Array[String], key: String, values: Dictionary = {}) -> void:
	var line := text(key, values)
	if not line.is_empty(): lines.append(line)

static func _slot(slot: String) -> String:
	var normalized := slot.to_lower()
	return "manual" if normalized.begins_with("manual") else normalized

static func _summary(view: Dictionary) -> String:
	var key := str(view.get("id", ""))
	if key == "JIA_basic" and view.get("kind", "") == "THRUST": key += ":THRUST"
	return str(_load_copy().get("abilities", {}).get(key, {}).get("summary", view.get("title", "")))

static func describe(view: Dictionary, slot: String, character_id: String) -> Dictionary:
	var category := _slot(slot)
	if category == "trait": return _trait(character_id)
	var facts: Array[String] = []
	var conditions: Array[String] = []
	var details: Array[String] = []
	var result := {"summary":_summary(view), "category":text("category."+category), "facts":facts, "conditions":conditions, "details":details, "key_facts":[], "trigger":""}
	if view.is_empty(): return result
	var p: Dictionary = view.get("params", {})
	var kind := str(view.get("kind", ""))
	var mechanic := str(view.get("mechanic", ""))
	var scope := text("scope."+str(view.get("target_scope", "active")))
	var power := float(view.get("damage_scale", 0))
	var duration := float(view.get("duration", 0))
	var slow := float(view.get("slow", 0))
	var seconds := number(float(view.get("cooldown", 0)))
	var definition: Dictionary = C.definition(character_id)
	if mechanic not in WINDOW_MECHANICS:
		if kind == "HEAL": _add(facts,"fact.heal",{"amount":number(power+float(view.get("level",1))*1.5),"scope":scope})
		elif kind == "MANA": _add(facts,"fact.mana",{"amount":number(power),"scope":scope})
		elif kind == "WARD": _add(facts,"fact.shield",{"amount":number(power),"scope":scope,"cap_percent":number(100*float(p.get("shield_cap_ratio",.35)))})
		else: _add(facts,"fact.damage",{"percent":number(power*100),"damage_type":text("damage_type."+str(view.get("damage_type","PHYSICAL")))})
	if mechanic not in WINDOW_MECHANICS: _add(details,"detail.shape."+kind)
	if slow > 0 and duration > 0: _add(facts,"fact.slow",{"percent":number(slow*100),"seconds":number(duration)})
	if category == "manual": result.trigger=text("trigger.manual",{"key":"K" if slot.to_lower()=="manual_k" else "J"})
	elif category == "support":
		var trait_key := str(definition.get("trait", ""))
		if trait_key == "mark": result.trigger=text("trigger.mark",{"hits":int(definition.trait_params.get("hits",3)),"seconds":seconds})
		elif trait_key == "ammo" or mechanic == "ammo_followup": result.trigger=text("trigger.ammo",{"seconds":seconds})
		else: result.trigger=text("trigger.support",{"seconds":seconds})
	else: result.trigger=text("trigger."+category)
	match mechanic:
		"echo_record":
			_add(facts,"fact.echo_record",{"charges":int(p.get("charges",2)),"seconds":number(float(p.get("duration",12)))})
			_add(details,"detail.echo_record_strength",{"damage_percent":number(100*float(p.get("damage_multiplier",.45))),"slow_percent":number(100*float(p.get("slow_multiplier",.5)))})
			_add(conditions,"condition.echo_record")
			_add(details,"detail.echo_record_snapshot"); _add(details,"detail.echo_record_secondary")
		"expose":
			_add(facts,"fact.expose",{"percent":number(100*float(p.get("multiplier",.15))),"seconds":number(float(p.get("duration",4)))})
			_add(details,"detail.expose")
		"guard":
			_add(facts,"fact.guard",{"scope":scope,"seconds":number(float(p.get("duration",4))),"charges":int(p.get("charges",1)),"reduction_percent":number(100*float(p.get("reduction",.5))),"counter_percent":number(100*float(p.get("counter_scale",1.5)))})
			_add(conditions,"condition.guard"); _add(details,"detail.guard")
		"party_heal":
			_add(facts,"fact.party_heal",{"cap_percent":number(100*float(p.get("shield_cap_ratio",.35)))})
			_add(conditions,"condition.party_heal")
		"refund_settle": _add(conditions,"condition.refund_settle")
		"curse":
			_add(facts,"fact.curse",{"seconds":number(float(p.get("duration",6))),"percent":number(100*float(p.get("dot_scale",1)))})
			_add(details,"detail.curse")
			if int(p.get("spread_targets",0))>0:
				_add(facts,"fact.curse_spread",{"count":int(p.spread_targets),"percent":number(100*float(p.get("spread_fraction",0)))})
				_add(conditions,"condition.curse_spread")
		"curse_cashout":
			_add(facts,"fact.curse_cashout",{"percent":number(100*float(p.get("fraction",.5)))})
			_add(conditions,"condition.curse_cashout")
		"ammo_volley":
			_add(facts,"fact.ammo_volley",{"count":int(p.get("max_spend",4)),"percent":number(100*float(p.get("bonus_per_arrow",.35)))})
			_add(conditions,"condition.ammo_volley")
		"ammo_followup":
			_add(facts,"fact.ammo_followup",{"percent":number(100*float(p.get("normal_multiplier",.4)))})
			_add(details,"detail.ammo_followup")
		"shield_strike":
			_add(facts,"fact.shield_strike",{"amount":number(float(p.get("shield_max",30))),"percent":number(100*float(p.get("shield_ratio",.06)))})
			_add(conditions,"condition.shield_strike")
		"temper":
			_add(facts,"fact.temper",{"scope":scope,"seconds":number(float(p.get("duration",8))),"percent":number(100*float(p.get("spark_scale",.25)))})
			_add(details,"detail.temper")
		"extend":
			_add(facts,"fact.extend",{"seconds":number(float(p.get("seconds",2))),"cap_seconds":number(float(p.get("max_extension",4)))})
			_add(conditions,"condition.extend")
		"rally":
			_add(facts,"fact.rally",{"scope":scope,"seconds":number(float(p.get("duration",6))),"attack_percent":number(100*float(p.get("attack_multiplier",.15))),"speed_percent":number(100*float(p.get("speed_multiplier",0)))})
			_add(details,"detail.rally")
		"dash":
			_add(conditions,"condition.dash_back" if float(p.get("distance",100))<0 else "condition.dash_forward")
			_add(details,"detail.dash")
		"field":
			_add(facts,"fact.field",{"seconds":number(float(p.get("duration",6))),"interval":number(float(p.get("interval",1))),"percent":number(power*100)})
			if float(p.get("heal",0))>0: _add(facts,"fact.field_heal",{"amount":number(float(p.heal)),"scope":scope})
			if float(p.get("mana",0))>0: _add(facts,"fact.field_mana",{"amount":number(float(p.mana)),"scope":scope})
			_add(details,"detail.field")
	result.key_facts=facts.duplicate()
	if mechanic not in WINDOW_MECHANICS: _add(facts,"fact.range",{"shape":text("shape."+kind)})
	_add(facts,"fact.cooldown",{"seconds":seconds})
	if category == "manual": _add(facts,"fact.cost",{"amount":number(float(view.get("mana_cost",0)))})
	_add(facts,"fact.unlock",{"level":int(view.get("unlock_level",1))})
	return result

static func _trait(id: String) -> Dictionary:
	var definition: Dictionary = C.definition(id)
	var key := str(definition.get("trait", ""))
	var p: Dictionary = definition.get("trait_params", {})
	var facts: Array[String] = []
	var conditions: Array[String] = []
	var details: Array[String] = []
	var result := {"summary":"", "category":text("category.trait"), "facts":facts, "conditions":conditions, "details":details, "key_facts":[], "trigger":text("trigger.trait") if not key.is_empty() else ""}
	if key.is_empty(): return result
	var support: Resource = definition.get("support")
	var interval := number(support.cooldown if support != null else 0.0)
	var values := {}
	match key:
		"echo": values={"charges":int(p.get("charges",2)),"seconds":number(float(p.get("duration",12))),"damage_percent":number(100*float(p.get("damage_multiplier",.45))),"slow_percent":number(100*float(p.get("slow_multiplier",.5)))}
		"mark": values={"hits":int(p.get("hits",3)),"seconds":interval}
		"ammo": values={"capacity":int(p.get("capacity",6)),"initial":int(p.get("initial",6)),"interval":number(float(p.get("refill_interval",8))),"amount":int(p.get("refill_amount",2)),"cast_amount":int(p.get("cast_refill",1)),"seconds":interval}
		"refund": values={"percent":number(100*float(p.get("fraction",.2))),"seconds":number(float(p.get("duration",6))),"ticks":int(p.get("ticks",3))}
		"relay": values={"percent":number(100*float(p.get("fraction",.2))),"minimum":number(float(p.get("min_cost",1)))}
		"curse": values={"interval":number(float(p.get("interval",2))),"seconds":number(float(p.get("duration",5))),"percent":number(100*float(p.get("dot_scale",.3)))}
	_add(facts,"trait."+key+".fact",values)
	_add(conditions,"trait."+key+".condition")
	_add(details,"trait."+key+".detail")
	if key == "echo": _add(details,"detail.echo_record_strength",values)
	# Keep identity and numeric rules separate; legacy/missing-copy fallback never repeats a line.
	result.summary = text("trait."+key+".summary")
	if str(result.summary).is_empty() and not facts.is_empty(): result.summary = facts.pop_front()
	result.key_facts=facts.duplicate()
	return result

static func _view(ability: Resource, level: int, attack: float, speed: float) -> Dictionary:
	if ability == null: return {}
	return {"id":str(ability.id),"title":ability.title,"unlock_level":ability.unlock_level,"unlocked":level>=ability.unlock_level,"level":level,"attack":attack,
		"cooldown":1.0/speed if str(ability.id).ends_with("_basic") and speed>0 else ability.cooldown,"mana_cost":ability.mana_cost,"nominal_mana_cost":ability.mana_cost,
		"reach":ability.reach,"kind":A.Kind.keys()[ability.kind],"damage_scale":ability.damage_scale,"slow":ability.slow,"duration":ability.duration,"damage_type":A.DamageType.keys()[ability.damage_type],
		"mechanic":ability.mechanic,"params":ability.params.duplicate(true),"target_scope":ability.target_scope}

static func _ability(id: String, slot: String, equipment: Dictionary, index: int = 0) -> Resource:
	var definition: Dictionary = C.definition(id)
	if definition.is_empty(): return null
	match _slot(slot):
		"basic": return C.basic(id,equipment)
		"support": return definition.support
		"automatic": return definition.automatic[index] if index>=0 and index<definition.automatic.size() else null
		"manual":
			var at := 1 if slot.to_lower()=="manual_k" else 0 if slot.to_lower()=="manual_j" else index
			return definition.manual[at] if at>=0 and at<definition.manual.size() else null
	return null

static func runtime_view(battle: RefCounted, id: String, slot: String, index: int = 0) -> Dictionary:
	if battle == null or not battle.characters.has(id): return {}
	var actor: RefCounted = battle.characters[id]
	var ability := _ability(id,slot,battle.equipment,index)
	var result := _view(ability,actor.level,actor.stats.attack,actor.stats.speed)
	if not result.is_empty() and _slot(slot)=="manual": result.mana_cost=battle.manual_cost(ability,id)
	if not result.is_empty() and _slot(slot)=="basic" and battle.outcome.is_empty():
		var windows: Dictionary = battle.mechanics.states[id].windows
		if windows.has("rally"): result.cooldown /= 1.0+float(windows.rally.get("speed_multiplier",0))
	return result

static func manual_model(battle: RefCounted, id: String, slot: int) -> Dictionary:
	var definition: Dictionary = C.definition(id)
	var key := "K" if slot==1 else "J"
	var ability: Resource = _ability(id,"manual",{},slot) if slot in [0,1] else null
	var model := {"character_id":id,"character_name":str(definition.get("name","")),"key":key,"title":text("missing.title"),"present":false,
		"summary":text("missing.summary"),"category":text("category.manual"),"facts":[],"key_facts":[],"conditions":[],"details":[],"trigger":text("trigger.manual",{"key":key}),
		"ability_id":"","nominal_cost":0.0,"cost":0.0,"remaining":0.0,"cooldown":0.0,"state":"missing","state_text":text("state.missing"),"unlocked":false,"paused":false,"target_required":false,"has_target":false}
	if ability==null: return model
	var actor: RefCounted = battle.characters.get(id) if battle!=null else null
	var level: int = actor.level if actor!=null else C.entry_level(id)
	var attack: float = actor.stats.attack if actor!=null else 0.0
	var speed: float = actor.stats.speed if actor!=null else 0.0
	var view := _view(ability,level,attack,speed)
	var cost: float = battle.manual_cost(ability,id) if actor!=null else ability.mana_cost
	view.mana_cost=cost
	model.merge(describe(view,"manual_k" if slot==1 else "manual_j",id),true)
	model.merge({"title":ability.title,"present":true,"ability_id":str(ability.id),"cost":cost,"nominal_cost":ability.mana_cost,"cooldown":ability.cooldown,"unlocked":level>=ability.unlock_level},true)
	if actor==null:
		model.state="inactive"
	else:
		model.paused=battle.paused
		model.remaining=maxf(0,float(actor.cooldowns.get(ability.id,0)))
		model.target_required=ability.kind in [A.Kind.SWEEP,A.Kind.THRUST,A.Kind.PROJECTILE]
		model.has_target=not model.target_required or (battle.outcome.is_empty() and _has_target(battle,ability,actor))
		if actor.dead: model.state="dead"
		elif not model.unlocked: model.state="locked"
		elif not battle.outcome.is_empty(): model.state="ended"
		elif battle.current().id!=id: model.state="inactive"
		elif model.remaining>0: model.state="cooldown"
		elif actor.mp+0.00001<cost: model.state="mana"
		elif not model.has_target: model.state="no_target"
		else: model.state="ready"
	model.state_text=text("state."+str(model.state),{"level":ability.unlock_level,"seconds":number(model.remaining),"amount":number(cost)})
	return model

static func _has_target(battle: RefCounted, ability: Resource, actor: RefCounted) -> bool:
	# Match activation's circular eligibility pass. Do not choose or hold a target.
	var reach: float = battle.mechanics.query_reach(ability,actor,true)
	var melee: bool = ability.kind in [A.Kind.SWEEP,A.Kind.THRUST]
	for enemy in battle.enemies:
		if enemy.dead or not enemy.targetable: continue
		var distance: float = battle.position.distance_to(enemy.position)
		if distance <= reach + (float(enemy.radius) if melee else 0.0): return true
	return false
