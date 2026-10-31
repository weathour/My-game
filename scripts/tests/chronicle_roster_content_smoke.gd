extends SceneTree
const C := preload("res://scripts/content/combat_catalog.gd")
const A := preload("res://scripts/battle/ability_definition.gd")
const RUNTIME := preload("res://scripts/battle/character_runtime.gd")
const BATTLE := preload("res://scripts/battle/battle_session.gd")
const ENEMY := preload("res://scripts/battle/enemy_runtime.gd")
var failures := 0
var checks := 0
func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	expect(C.IDS.size() == 38, "38 distinct roster definitions")
	expect(C.EQUIPMENT.size() == 6, "six existing equipment pieces")
	var ids := {}
	var abilities := {}
	var records := {}
	var exports: Array = []
	var mechanics := ["", "echo_record", "party_heal", "shield_strike", "guard", "refund_settle", "curse", "curse_cashout", "ammo_followup", "ammo_volley", "temper", "extend", "expose", "rally", "dash", "field"]
	for id in C.IDS:
		var def: Dictionary = C.definition(id)
		expect(not ids.has(id), "unique character " + id)
		ids[id] = true
		expect(not def.is_empty(), "defined " + id)
		expect(C.entry_level(id) >= 1, "valid entry level " + id)
		expect(def.manual.size() in [1, 2], "one or two manual slots " + id)
		expect(def.manual[0].unlock_level <= C.entry_level(id), "core available on acquisition " + id)
		expect(id == "JIA" or not def.owned.is_empty(), "all collectible identities have owned value " + id)
		expect(id == "JIA" or def.support != null, "all auxiliaries have actual support " + id)
		var list: Array = [def.basic] + def.manual + def.automatic
		if def.support != null: list.append(def.support)
		for skill in list:
			expect(not abilities.has(str(skill.id)), "unique ability " + str(skill.id))
			abilities[str(skill.id)] = true
			expect(skill.cooldown > 0 and skill.reach >= 0, "valid timing/reach " + str(skill.id))
			expect(skill.mechanic in mechanics, "implemented mechanic " + str(skill.id))
			expect(not C.ability_description(skill, C.entry_level(id), 20).is_empty(), "numeric description " + str(skill.id))
			if skill in def.manual and skill.kind == A.Kind.MANA and skill.mechanic != "refund_settle": expect(skill.damage_scale < skill.mana_cost * .8, "paid MP restoration stays lossy even with one eligible refund/relay auxiliary " + str(skill.id))
			if skill not in def.manual: expect(skill.mana_cost == 0, "automatic/support never charge MP " + str(skill.id))
		var detail: Dictionary = C.character_details(id,C.entry_level(id))
		expect(detail.manual.size() == def.manual.size(), "projection manual slots " + id)
		expect(is_equal_approx(detail.basic.cooldown,1.0/detail.stats.speed), "projected basic timing " + id)
		expect(detail.support.is_empty() == (def.support == null), "support projection " + id)
		exports.append(detail)
		records[id] = C.record(id,999)
	var raw: Dictionary = C.owned_raw_bonuses(records)
	var capped: Dictionary = C.owned_bonuses(records)
	for stat in capped:
		expect(capped[stat] <= C.OWNED_CAPS[stat], "owned cap " + stat)
		expect(raw[stat] >= capped[stat], "raw/capped separation " + stat)
	var before: Dictionary = C.owned_bonuses(records)
	for rec in records.values(): rec.dead = true
	expect(C.owned_bonuses(records) == before, "death does not remove owned bonuses")
	var base: Dictionary = C.attributes("JIA",1)
	var grown: Dictionary = C.attributes("JIA",2)
	expect(grown.hp == base.hp + 16 and grown.mp == base.mp + 5 and grown.attack == base.attack + 3, "shared linear level growth")
	var equipped: Dictionary = C.attributes("JIA",1,{}, {"armor":"iron_armor"})
	expect(equipped.armor == base.armor + 4, "iron armor adds exactly four defense")
	expect(C.basic("JIA",{"weapon":"long_spear"}).kind == A.Kind.THRUST, "main weapon changes protagonist form")
	expect(C.basic("F07",{"weapon":"long_spear"}) == C.definition("F07").basic, "main weapon never changes auxiliary form")
	expect(C.definition("F07").manual[1].unlock_level == 1, "shield conversion immediately available")
	expect(C.definition("F11").manual[0].params.charges == 2 and C.definition("F11").manual[0].params.duration == 12, "early echo uses approved window")
	expect(C.definition("F06").manual[0].mana_cost == 30 and C.definition("F06").manual[0].cooldown == 10, "volley uses agreed cost and cooldown")
	var ward_view: Dictionary = C.character_details("F03",5).manual[1]
	expect(ward_view.description.contains("55护盾") and ward_view.description.contains("35%"), "ordinary WARD projection includes grant and personal total shield cap")
	var override_ward: Resource = A.make("test_ward_cap","cap fixture",A.Kind.WARD,20,0,10)
	override_ward.params = {"shield_cap_ratio":.25}
	expect(C.ability_description(override_ward).contains("25%"), "WARD description reads per-ability cap instead of hardcoding default")
	expect(not C.character_details("F09",3).manual[0].description.contains("提供"), "special WARD replacement does not advertise a shield grant")
	var live := RUNTIME.new("JIA",C.record("JIA",1),base)
	live.mp = 20
	live.tick(2)
	expect(is_equal_approx(live.mp,25.6), "natural recovery remains per actor without level-up")
	all_kit_activations()
	var output := {"schema":1,"owned_caps":C.OWNED_CAPS,"growth":C.GROWTH,"equipment":C.EQUIPMENT,"characters":exports}
	var file := FileAccess.open("/tmp/my-game-character-kit-spec.json",FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(output,"\t")); file.close()
	expect(file != null, "export machine-readable numeric panel specification")
	print("CHRONICLE_ROSTER_CONTENT_SMOKE %s checks=%d failures=%d" % ["FAIL" if failures else "PASS",checks,failures])
	quit(1 if failures else 0)

func all_kit_activations() -> void:
	for id in C.IDS:
		var member_ids: Array = ["JIA"] if id == "JIA" else ["JIA",id]
		var records := {}
		for member in member_ids: records[member] = C.record(member,C.entry_level(member))
		var stage: Dictionary = C.stage("B01").duplicate(true)
		stage.boss_time = 9999.0
		stage.boss_kills = 99999
		stage.spawn_interval = 9999.0
		var battle := BATTLE.new({"attempt_id":"roster_"+id,"members":member_ids,"characters":records,"equipment":{},"stage":stage,"seed":7})
		battle.director.spawn_remaining = 9999
		battle.active = member_ids.find(id)
		var actor: RefCounted = battle.characters[id]
		for skill in C.definition(id).manual:
			if skill.unlock_level > actor.level: continue
			var enemy := ENEMY.new(9001,"melee",battle.position+Vector2(40,0))
			enemy.hp = 10000
			enemy.max_hp = 10000
			battle.enemies = [enemy]
			expect(battle._cast(skill,actor,true,true), "entry-level manual executes " + str(skill.id))
			battle.tick(.05,Vector2.ZERO)
		expect(actor.mp >= 0 and actor.mp <= actor.stats.mp, "manual MP remains valid " + id)
		if id != "JIA":
			battle.active = 0
			battle.tick(.1,Vector2.ZERO)
			expect(battle.characters.has(id) and not battle.characters[id].dead, "background kit remains a real configured actor " + id)
