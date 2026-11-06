extends SceneTree
# Bounded supplemental check: production Battle/Enemy events enter CombatFeedback.consume.
const C := preload("res://scripts/content/combat_catalog.gd")
const BATTLE := preload("res://scripts/battle/battle_session.gd")
const FEEDBACK := preload("res://scripts/ui/chronicle/combat_feedback.gd")
const SETTINGS := preload("res://scripts/shared/settings.gd")
var checks := 0
var failures := 0
var feedback: Node
func _init() -> void: call_deferred("run")
func expect(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func fixture(ids: Array = ["JIA"], stage: String = "B01") -> RefCounted:
	var records := {}
	for id in ids: records[id] = C.record(id, 20)
	var spec := C.stage(stage)
	if stage != "B18": spec.boss_time = 10000.0; spec.boss_kills = 10000; spec.spawn_interval = 10000.0
	var b := BATTLE.new({"attempt_id":"event-routing", "members":ids, "characters":records, "equipment":{}, "stage":spec, "seed":47})
	b.director.spawn_remaining = 10000.0
	for id in ids:
		var actor: RefCounted = b.characters[id]
		actor.cooldowns[str(C.basic(id,b.equipment).id)] = 10000.0
		for ability in C.definition(id).automatic: actor.cooldowns[str(ability.id)] = 10000.0
		var support: Resource = C.definition(id).support
		if support != null: actor.cooldowns[str(support.id)] = 10000.0
	return b
func spawn(b: RefCounted, id: String, distance: float = 40.0) -> RefCounted:
	var enemy: RefCounted = b.director.spawn(id,b.position+Vector2(distance,0))
	enemy.cooldown = 10000.0; enemy.speed = 0.0
	b.enemies.append(enemy)
	return enemy
func consume(b: RefCounted) -> void:
	feedback.clear()
	await process_frame
	feedback.consume(b.events,b,Rect2())
	var routing: Array = []
	for record in feedback.audio.records:
		if not record.is_empty(): routing.append({"cue":record.cue,"owner":record.owner,"stage":record.stage,"category":record.category})
	print("EVENTS ", JSON.stringify(b.events.map(func(event: Dictionary): return event.kind)), " ROUTING ", JSON.stringify(routing))
func mapped(stage: String, category: String, owner_prefix: String = "", cue: String = "") -> bool:
	var found := false
	for record in feedback.audio.records:
		if record.is_empty() or str(record.stage)!=stage or not str(record.owner).begins_with(owner_prefix) or (not cue.is_empty() and str(record.cue)!=cue): continue
		found = true
		if str(record.category)!=category: return false
	return found
func cast(b: RefCounted, id: String, ability: Resource, direct: bool, manual: bool = false) -> void:
	b.events.clear(); b.characters[id].cooldowns[str(ability.id)] = 0.0
	b._cast(ability,b.characters[id],direct,manual); b._resolve_hits(); await consume(b)
func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"),"isolated XDG settings")
	if failures: quit(1); return
	SETTINGS.save_audio_muted(false); SETTINGS.save_sfx_volume(.65)
	for category in SETTINGS.AUDIO_CATEGORIES: SETTINGS.save_audio_volume(category,1.0)
	feedback = FEEDBACK.new(); root.add_child(feedback)
	var b := fixture(); var enemy := spawn(b,"E01",70)
	enemy.hp=100000.0; enemy.max_hp=enemy.hp
	await cast(b,"JIA",C.basic("JIA",b.equipment),true)
	expect(mapped("cast","player_attack","character:JIA"),"real basic cast -> player_attack")
	expect(mapped("impact","player_attack","character:JIA"),"real basic confirmed damage -> player_attack")
	b.equipment.weapon="long_spear"
	await cast(b,"JIA",C.basic("JIA",b.equipment),true)
	expect(mapped("cast","player_attack","character:JIA") and mapped("impact","player_attack","character:JIA"),"equipped spear basic cast and impact retain attack category")
	await cast(b,"JIA",C.definition("JIA").manual[0],true,true)
	expect(mapped("cast","player_skill","character:JIA"),"real manual skill cast -> player_skill")
	expect(mapped("impact","player_skill","character:JIA"),"real manual skill damage -> player_skill")
	b=fixture(["JIA","F03"]); b.current().hp-=50
	await cast(b,"F03",C.definition("F03").support,false)
	expect(mapped("cast","player_skill","character:F03"),"real background support cast -> player_skill")
	expect(mapped("impact","player_skill","character:F03"),"real support healing effect -> player_skill")
	for id in C.IDS:
		if C.definition(id).automatic.is_empty(): continue
		b=fixture(["JIA",id]); enemy=spawn(b,"E01",70); enemy.hp=100000.0; enemy.max_hp=enemy.hp
		await cast(b,id,C.definition(id).automatic[0],true)
		expect(mapped("cast","player_skill","character:"+id),"real automatic ability cast -> player_skill ("+id+")")
		break
	b=fixture(); enemy=spawn(b,"E01"); enemy.cooldown=0.0
	b.tick(.01,Vector2.ZERO); await consume(b)
	expect(mapped("tell","enemy_attack","enemy:"),"ordinary real tell -> enemy_attack")
	b.tick(enemy.windup+.01,Vector2.ZERO); await consume(b)
	expect(mapped("release","enemy_attack","enemy:"),"ordinary real release -> enemy_attack")
	expect(mapped("impact","enemy_attack","enemy:"),"ordinary real player_hit source impact -> enemy_attack")
	expect(mapped("hurt","hurt","character:JIA","feedback.hurt"),"ordinary real player_hit extra accent -> hurt")
	b=fixture(); enemy=spawn(b,"B01"); enemy.cooldown=0.0; b.director.boss_spawned=true
	b.tick(.01,Vector2.ZERO); await consume(b)
	expect(mapped("tell","boss","enemy:"),"Boss real tell -> boss")
	b.tick(enemy.windup+.01,Vector2.ZERO); await consume(b)
	expect(mapped("release","boss","enemy:"),"Boss real release -> boss")
	expect(mapped("impact","boss","enemy:"),"Boss real player_hit source impact -> boss")
	b=fixture(["JIA"],"B18"); enemy=b.enemies[0]
	enemy.receive_damage(enemy.hp); b.tick(0,Vector2.ZERO); await consume(b)
	expect(mapped("phase","boss","enemy:"),"Boss real form depletion -> boss phase")
	enemy.advance_form(enemy.transition_remaining+enemy.observation_remaining+.01)
	enemy.receive_damage(enemy.hp+1); b.tick(0,Vector2.ZERO); await consume(b)
	expect(mapped("defeated","boss","enemy:"),"Boss real final defeat -> boss defeated")
	b=fixture(["JIA","F02"]); enemy=spawn(b,"E01"); enemy.hp=100000.0; enemy.max_hp=enemy.hp
	b.current().shield=100; b.current().stats.armor=0
	b.characters.F02.cooldowns[str(C.definition("F02").support.id)] = 0.0
	b._cast(C.definition("F02").support,b.characters.F02,false)
	b.events.clear(); enemy.cooldown=0.0; b.tick(.01,Vector2.ZERO)
	b.tick(enemy.windup+.01,Vector2.ZERO); await consume(b)
	expect(mapped("hurt","hurt","character:JIA","feedback.guard"),"real protected player_hit extra guard -> hurt")
	expect(mapped("impact","player_skill","character:F02"),"real guard counter delivery -> player_skill")
	b=fixture(); enemy=spawn(b,"E01",70); enemy.receive_damage(enemy.hp+1); b.tick(0,Vector2.ZERO); await consume(b)
	expect(mapped("death","death"),"real non-Boss kill -> death")
	b=fixture(); b.current().xp=C.xp_required(b.current().level)-1
	b.gems=[{"position":b.position+Vector2(10,0),"amount":2.0}]
	b.tick(0,Vector2.ZERO); await consume(b)
	expect(mapped("pickup","pickup"),"real contact XP collection -> pickup")
	expect(mapped("level","rewards"),"real party level event -> rewards")
	for id in ["card_elite","equipment_elite"]:
		b=fixture(); enemy=spawn(b,id,70); enemy.receive_damage(enemy.hp+1); b.tick(0,Vector2.ZERO); await consume(b)
		expect(mapped("elite","rewards"),"real "+id+" reward event -> rewards")
	feedback.clear(); await create_timer(.15).timeout
	feedback.queue_free(); await process_frame
	b=null; enemy=null; feedback=null
	await create_timer(.15).timeout
	call_deferred("finish")
func finish() -> void:
	print("EVENT_ROUTING ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
	quit(1 if failures else 0)
