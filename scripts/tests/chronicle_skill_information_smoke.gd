extends SceneTree
## Copy coverage plus independent gameplay facts and strictly read-only queries.
const INFO := preload("res://scripts/content/skill_information.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const BATTLE := preload("res://scripts/battle/battle_session.gd")
const A := preload("res://scripts/battle/ability_definition.gd")
var checks := 0
var failures := 0

func _init() -> void: call_deferred("run")
func expect(value: bool,label: String) -> void:
	checks += 1
	if not value: failures += 1;push_error(label)

func compact(value: Variant) -> String:
	return str(value).replace(" ","").replace("\n","")

func prose(info: Dictionary) -> String:
	return compact(str(info.get("summary",""))+" "+" ".join(info.get("facts",[]))+" "+" ".join(info.get("conditions",[]))+" "+" ".join(info.get("details",[]))+str(info.get("trigger","")))

func fixture(ids: Array = ["JIA","F11","F10"],level: int = 10) -> RefCounted:
	var records := {}
	for id in ids:records[id]=C.record(id,level)
	var stage := C.stage("B02");stage.boss_time=100000.0;stage.boss_kills=100000
	return BATTLE.new({"attempt_id":"skill-information","members":ids,"characters":records,"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":"ember_seal"},"stage":stage,"seed":61106})

func enemy(b: RefCounted,offset: Vector2 = Vector2(80,0)) -> RefCounted:
	var foe: RefCounted = b.director.spawn("E01",b.position+offset)
	foe.hp=100000;foe.max_hp=100000;b.enemies.append(foe);b.spatial.rebuild(b.enemies)
	return foe

static func snapshot(b: RefCounted) -> Dictionary:
	var actors := {};var foes: Array = []
	for id in b.characters:
		var actor: RefCounted = b.characters[id]
		actors[id]={"record":actor.snapshot(),"stats":actor.stats.duplicate(true),"shield":actor.shield,"haste":actor.haste,"hurt_lock":actor.hurt_lock}
	for foe in b.enemies:foes.append({"id":foe.id,"position":foe.position,"hp":foe.hp,"dead":foe.dead,"targetable":foe.targetable,"action":foe.current_action.duplicate(true),"serial":foe.action_serial})
	return {"actors":actors,"foes":foes,"position":b.position,"facing":b.facing,"active":b.active,"paused":b.paused,"switch":b.switch_cooldown,
		"target":b.target_id,"hold":b.target_hold,"switch_intent":b._switch_intent,"skill_intents":b._skill_intents.duplicate(),"cast":b.cast_serial,"delivery":b.delivery_serial,"presentation":b.presentation_serial,
		"elapsed":b.director.elapsed,"rng":b.director.rng.state,"spawn":b.director.spawn_remaining,"director_serial":b.director.serial,"kills":b.director.kills,"boss":b.director.boss_spawned,
		"roster":b.roster.duplicate(true),"equipment":b.equipment.duplicate(true),"events":b.events.duplicate(true),"effects":b.effects.duplicate(true),"projectiles":b.projectiles.duplicate(true),"patterns":b.pending_patterns.duplicate(true),"hits":b._hits.duplicate(true),"gems":b.gems.duplicate(true),"hazards":b.hazards.duplicate(true),"telegraphs":b.telegraphs.duplicate(true),"outcome":b.outcome,"result":b.result.duplicate(true),
		"mechanics":b.mechanics.states.duplicate(true),"exposures":b.mechanics.exposures.duplicate(true),"curses":b.mechanics.curses.duplicate(true),"refunds":b.mechanics.refunds.duplicate(true),"fields":b.mechanics.fields.duplicate(true),"last_payer":b.mechanics.last_payer,"spread":b.mechanics.spread_targets.duplicate(true),"sparks":b.mechanics.spark_casts.duplicate(true)}

func run() -> void:
	check_coverage()
	check_facts()
	check_availability_and_readonly()
	check_mechanic_oracles()
	print("CHRONICLE_SKILL_INFORMATION_SMOKE ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)

func check_coverage() -> void:
	var copy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INFO.COPY_PATH))
	expect(copy.get("schema_version")==1 and copy.characters.size()==38 and copy.abilities.size()==138,"38 playstyles and137 abilities plus explicit spear variant")
	for name in ["battle_skill_tooltip","battle_skill_inspector"]:
		var script := load("res://scripts/ui/chronicle/"+name+".gd") as Script
		expect(script!=null and script.can_instantiate(),"shipped skill inspection module loads "+name)
	var ability_ids := {};var manual_count := 0;var no_k := 0;var support_count := 0;var auto_count := 0;var trait_count := 0
	for id in C.IDS:
		var info := INFO.character(id)
		expect(not info.overview.strip_edges().is_empty() and not info.tags.is_empty(),"complete overview/tags "+id)
		var clean: Array = info.tags.duplicate();info.tags.append("test-only")
		expect(INFO.character(id).tags==clean,"character tags cannot corrupt shared copy cache "+id)
		var kit := C.character_details(id,10)
		var entries: Array = [["basic",kit.basic]]
		for view in kit.automatic:entries.append(["automatic",view]);auto_count+=1
		for index in kit.manual.size():entries.append(["manual_j" if index==0 else "manual_k",kit.manual[index]]);manual_count+=1
		if kit.manual.size()==1:no_k+=1
		if not kit.support.is_empty():entries.append(["support",kit.support]);support_count+=1
		for entry in entries:
			var view: Dictionary = entry[1];var before := view.duplicate(true);var model := INFO.describe(view,entry[0],id)
			expect(not ability_ids.has(view.id),"ability belongs to exactly one character/slot "+view.id);ability_ids[view.id]=true
			expect(copy.abilities.has(view.id) and model.summary==copy.abilities[view.id].summary and not model.summary.strip_edges().is_empty(),"published summary, no silent title fallback "+view.id)
			expect(not model.category.is_empty() and not model.facts.is_empty() and not model.trigger.is_empty(),"structured category/numeric/trigger facts "+view.id)
			expect(not prose(model).contains("{") and not prose(model).contains("}"),"all template placeholders resolved "+view.id)
			expect(view==before,"describing raw fields never mutates projection "+view.id)
		var trait_info := INFO.describe({},"trait",id)
		if not str(kit.trait).is_empty():
			trait_count+=1;expect(not trait_info.summary.is_empty() and not trait_info.facts.is_empty() and not trait_info.conditions.is_empty() and not trait_info.details.is_empty(),"configured trait boundaries complete "+id)
		else:expect(trait_info.summary.is_empty() and trait_info.facts.is_empty(),"no fabricated trait "+id)
	expect(ability_ids.size()==137 and manual_count==61 and no_k==15 and support_count==37 and auto_count==1 and trait_count==9,"independent roster slot counts remain137/61/15/37/1/9")
	var spear := C.character_details("JIA",10,{}, {"weapon":"long_spear"})
	expect(spear.basic.kind=="THRUST" and INFO.describe(spear.basic,"basic","JIA").summary==copy.abilities["JIA_basic:THRUST"].summary,"Jia spear uses explicit variant explanation")
	for key in copy.templates:expect(copy.templates[key] is String and not str(copy.templates[key]).strip_edges().is_empty(),"nonempty template "+key)

func check_facts() -> void:
	var jia := C.character_details("JIA",10)
	expect(jia.manual[1].params.multiplier==.12 and jia.manual[1].params.duration==4 and jia.manual[1].damage_scale==4.5,"independent Jia expose data4s/12%/450%")
	var text := prose(INFO.describe(jia.manual[1],"manual_k","JIA"))
	expect(text.contains("12%") and text.contains("4秒") and text.contains("取最强") and text.contains("不加强本次命中"),"expose displayed timing and strongest/not-retroactive boundaries")
	var frost: Dictionary = C.character_details("F11",10).manual[0]
	var frost_info := INFO.describe(frost,"manual_j","F11")
	text=prose(frost_info)
	expect(frost.slow==.6 and frost.duration==3 and frost.params.charges==2 and frost.params.duration==12 and frost.params.damage_multiplier==.45,"independent frost/echo numeric authority")
	expect(text.contains("2次") and text.contains("12秒") and text.contains("45%") and text.contains("50%") and text.contains("替换") and text.contains("记录时的施放伤害") and text.contains("饰品"),"echo count/time/replacement/snapshot/secondary facts visible")
	var first_layer := compact(str(frost_info.summary)+" ".join(frost_info.facts)+" ".join(frost_info.conditions)+str(frost_info.trigger))
	var expanded := compact(" ".join(frost_info.details))
	expect(first_layer.contains("2次") and first_layer.contains("12秒") and first_layer.contains("替换"),"decision-critical echo count/lifetime/replacement remain before expansion")
	expect(expanded.contains("45%") and expanded.contains("50%"),"echo strength remains explicit in expanded detail")
	text=prose(INFO.describe({},"trait","N07"))
	expect(C.definition("N07").trait_params.interval==1 and C.definition("N07").support.cooldown==3,"unused mark interval differs from actual support cooldown")
	expect(text.contains("3次") and text.contains("3秒") and not text.contains("1秒") and text.contains("冷却中计满会保留") and text.contains("再次命中"),"mark description follows real3s and retained counter")
	text=prose(INFO.describe(C.character_details("N16",10).manual[0],"manual_j","N16"))
	expect(text.contains("恢复60生命") and text.contains("生命比例最低"),"healing includes actual level bonus and chosen receiver")
	text=prose(INFO.describe(C.character_details("N17",10).manual[0],"manual_j","N17"))
	expect(text.contains("45护盾") and text.contains("35%") and text.contains("本人"),"shield quantity/cap/self receiver")
	text=prose(INFO.describe(C.character_details("F04",10).manual[1],"manual_k","F04"))
	expect(text.contains("恢复22魔法") and text.contains("魔法比例最低"),"mana restoration amount and relative receiver")
	text=prose(INFO.describe(C.character_details("N18",10).manual[1],"manual_k","N18"))
	expect(text.contains("10%") and text.contains("4秒") and not text.contains("提供0护盾"),"rally window is not advertised as a zero shield")
	for pair in [["F04","20%","6秒"],["F06","6","8秒"],["F10","20%","1"],["F05","6秒","2秒"]]:
		text=prose(INFO.describe({},"trait",pair[0]));expect(text.contains(pair[1]) and text.contains(pair[2]),"other trait numeric/condition coverage "+pair[0])

func check_availability_and_readonly() -> void:
	var b := fixture();enemy(b)
	b.target_id=9999;b.target_hold=.123;b._switch_intent=-1;b._skill_intents.append(1)
	b.set_paused(true);b._switch_intent=-1;b._skill_intents.append(1)
	var before := snapshot(b)
	for repeat in 100:
		for id in b.members:
			for slot in 2:
				var model := INFO.manual_model(b,id,slot)
				expect(model.has("ability_id") and model.has("nominal_cost") and model.paused,"stable runtime fields in pause")
				INFO.describe(INFO.runtime_view(b,id,"manual",slot),"manual_j" if slot==0 else "manual_k",id)
	expect(snapshot(b)==before,"hundreds of pause queries preserve MP/CD/stats/intents/targets/records/mechanics/RNG/clock")
	b.set_paused(false);b._skill_intents.clear();b._switch_intent=0
	expect(INFO.manual_model(b,"JIA",0).state=="ready","ready eligible manual")
	b.current().cooldowns.jia_sweep=1.25;expect(INFO.manual_model(b,"JIA",0).state=="cooldown" and INFO.manual_model(b,"JIA",0).remaining==1.25,"actual remaining cooldown")
	b.current().mp=0;expect(INFO.manual_model(b,"JIA",0).state=="cooldown","cooldown precedes insufficient mana")
	b.current().cooldowns.clear();expect(INFO.manual_model(b,"JIA",0).state=="mana","insufficient mana reason")
	b.current().mp=b.current().stats.mp;b.enemies.clear()
	expect(INFO.manual_model(b,"JIA",0).state=="ready" and not INFO.manual_model(b,"JIA",0).target_required,"NOVA may be cast without target")
	expect(INFO.manual_model(b,"JIA",1).state=="no_target","THRUST actually requires target")
	expect(INFO.manual_model(b,"F11",0).state=="inactive","configured background actor is not current")
	b.current().level=1;expect(INFO.manual_model(b,"JIA",1).state=="locked","unlock threshold beats target absence")
	b.current().dead=true;expect(INFO.manual_model(b,"JIA",1).state=="dead","dead precedes lock")
	b.current().dead=false;b.current().level=10
	b.mechanics.last_payer="F11"
	var discounted := INFO.manual_model(b,"JIA",0)
	expect(is_equal_approx(discounted.cost,17.6) and discounted.nominal_cost==22,"actual20percent relay discount17.6 separate from nominal22")
	b.characters.F10.dead=true;expect(INFO.manual_model(b,"JIA",0).cost==22,"dead provider cannot grant discount")
	b.characters.F10.dead=false
	b.equipment.weapon="long_spear";expect(INFO.runtime_view(b,"JIA","basic").kind=="THRUST","equipment changes real basic projection")
	b.mechanics.states.JIA.windows.rally={"speed_multiplier":.25};expect(is_equal_approx(INFO.runtime_view(b,"JIA","basic").cooldown,1.0/b.current().stats.speed/1.25),"active rally changes actual basic interval")
	b._finish("failed");before=snapshot(b)
	expect(INFO.manual_model(b,"JIA",0).state=="ended" and snapshot(b)==before,"terminal cleared mechanics safely query without reactivation")
	var single := fixture(["JIA","N07"]);single.characters.N07.dead=true
	expect(INFO.manual_model(single,"N07",1).state=="missing" and not INFO.manual_model(single,"N07",1).present,"unassigned K is not a locked/dead future ability")
	# Compare read-only eligibility with the real activation path on independent attempts.
	for distance in [244.0,270.0,400.0]:
		var query := fixture(["JIA"]);var oracle := fixture(["JIA"])
		enemy(query,Vector2(distance,0));enemy(oracle,Vector2(distance,0))
		var snap := snapshot(query);var available: bool = INFO.manual_model(query,"JIA",1).state=="ready"
		var actual: bool = oracle._cast(C.definition("JIA").manual[1],oracle.current(),true,true)
		expect(available==actual and snapshot(query)==snap,"query agrees with real activation at reach boundary without paying "+str(distance))

func check_mechanic_oracles() -> void:
	var b := fixture(["JIA","F11"]);enemy(b);b.active=1
	var actor: RefCounted = b.current();var attack: float = actor.stats.attack
	expect(b._cast(C.definition("F11").manual[0],actor,true,true),"real frost record is created by successful paid cast")
	var record: Dictionary = b.mechanics.states.F11.echo
	expect(record.remaining==2 and record.life==12 and is_equal_approx(record.context.damage,attack*1.8*.45) and record.context.slow==.3 and record.context.duration==1.5,"real echo snapshots2/12 and45percent damage/half slow")
	var old: Dictionary = record.duplicate(true);actor.stats.attack*=2;actor.cooldowns.clear()
	expect(b._cast(C.definition("F11").manual[1],actor,true,true),"new paid star replaces frost record")
	record=b.mechanics.states.F11.echo
	expect(record.context.ability=="emma_star" and record.remaining==2 and record.life==12 and is_equal_approx(record.context.damage,attack*2*5*.45) and old.context.ability=="emma_frost","latest spell replaces rather than stacks prior snapshot")
	b.active=0;b.current().cooldowns.clear();expect(b._cast(C.definition("JIA").manual[0],b.current(),true,true),"teammate actual payment triggers echo")
	expect(b.mechanics.states.F11.echo.remaining==1,"one successful teammate payment consumes one record charge")
	b=fixture(["JIA","N07"]);enemy(b);b.characters.N07.cooldowns.bow_support=1.5
	for hit in 3:
		b._hits.clear();b.current().cooldowns.clear();b._cast(C.basic("JIA",b.equipment),b.current(),true);b._resolve_hits()
	expect(b.mechanics.states.N07.mark==3 and b.characters.N07.cooldowns.bow_support==1.5,"real three basic hits retain full mark during support cooldown")
	b.characters.N07.cooldowns.bow_support=0
	expect(b.mechanics.states.N07.mark==3,"cooldown expiry alone does not consume held mark")
	b._hits.clear();b.current().cooldowns.clear();b._cast(C.basic("JIA",b.equipment),b.current(),true);b._resolve_hits()
	expect(b.mechanics.states.N07.mark==0 and b.characters.N07.cooldowns.bow_support==3,"next real basic hit spends held mark and starts actual3sec cooldown")
