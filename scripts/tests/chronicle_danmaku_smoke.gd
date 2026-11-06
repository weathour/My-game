extends SceneTree
## Pressure mechanics: authored temporal salvos, a shared danger core, bounded crowd work.
const B := preload("res://scripts/battle/battle_session.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const D := preload("res://scripts/battle/stage_director.gd")
const E := preload("res://scripts/battle/enemy_system.gd")
const G := preload("res://scripts/battle/enemy_geometry.gd")
const P := preload("res://scripts/battle/projectile_patterns.gd")
const H := preload("res://scripts/battle/player_hurtbox.gd")
const GRID := preload("res://scripts/battle/enemy_spatial_grid.gd")
const TARGET := preload("res://scripts/battle/targeting.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
var checks:=0
var failures:=0
func _init() -> void: call_deferred("run")
func expect(value: bool, label: String) -> void:
	checks+=1
	if not value: failures+=1;push_error(label)
func request(stage: String="B01") -> Dictionary:
	return {"attempt_id":"pressure-test","members":["JIA"],"characters":{"JIA":C.record("JIA",1)},"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":""},"stage":C.stage(stage),"seed":31471,"node":{"id":stage,"name":stage}}
func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"),"isolated pressure settings")
	if failures: quit(1);return
	geometry()
	controlled_core()
	spawning()
	salvos()
	actual_patterns()
	pursuit()
	crowd()
	print("CHRONICLE_DANMAKU_SMOKE ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
	quit(1 if failures else 0)
func geometry() -> void:
	expect(H.RADIUS==4 and B.hurt_radius()==4 and H.center(Vector2(12,31))==Vector2(12,-5),"one identical red-core center and radius authority")
	expect(SPACE.SIZE==Vector2(3200,1800) and SPACE.PLAYER_MARGIN==Vector2(55,65),"world and player boundary margin remain independent")
	var disc:={"shape":"disc","origin":Vector2.ZERO,"radius":30}
	expect(G.contains(disc,Vector2(33.99,0)) and not G.contains(disc,Vector2(34.01,0)),"disc damage uses exactly four units of player radius")
	var line:={"shape":"line","origin":Vector2.ZERO,"direction":Vector2.RIGHT,"length":100,"half_width":12}
	expect(G.contains(line,Vector2(50,15.99)) and not G.contains(line,Vector2(50,16.01)),"line damage uses half-width plus four")
	var sector:={"shape":"sector","origin":Vector2.ZERO,"direction":Vector2.RIGHT,"radius":30,"spread":PI/2}
	expect(G.contains(sector,Vector2(33.99,0)) and not G.contains(sector,Vector2(34.01,0)),"sector outer edge uses exactly four")
	var ring:={"shape":"ring_gap","origin":Vector2.ZERO,"direction":Vector2.RIGHT,"radius":100,"inner_radius":30,"gap_angle":0.0,"gap_width":1.0}
	expect(not G.contains(ring,Vector2(70,0)) and G.contains(ring,Vector2(-70,0)),"ring gap remains a real safe corridor")
	expect(H.contains_swept(Vector2(-100,-36),Vector2(100,-36),4.5,Vector2.ZERO,Vector2.ZERO),"fast bullets cannot tunnel through the small core")
	expect(not H.contains_swept(Vector2(-100,-27.49),Vector2(100,-27.49),4.5,Vector2.ZERO,Vector2.ZERO),"4+4.5 grazing miss stays a miss")
	expect(H.contains_swept(Vector2(-30,-36),Vector2(30,-36),2,Vector2(0,-30),Vector2(0,30)),"relative swept paths catch a moving actor crossing a moving bullet")
	var battle:=B.new(request())
	var enemy: RefCounted=battle.director.spawn("E01",battle.position+Vector2(122,0))
	expect(TARGET.in_shape([enemy],battle.position,Vector2.RIGHT,112,false,true).size()==1,"player attack reach still includes full enemy body radius")
func controlled_core() -> void:
	var battle:=B.new(request())
	battle.enemies.clear();battle.director.spawn_remaining=10000;battle.director.config.boss_time=10000;battle.director.config.boss_kills=10000
	var foot: Vector2=battle.position
	var core:=H.center(foot)
	var hp: float=battle.current().hp
	battle.projectiles=[{"position":foot-Vector2(100,0),"velocity":Vector2(1000,0),"life":1.0,"hostile":true,"damage":10.0,"hit_radius":4.5}]
	battle.tick(.2,Vector2.ZERO)
	expect(battle.current().hp==hp and battle.projectiles.size()==1,"real hostile bullet crossing only the foot anchor does not hurt")
	battle.projectiles=[{"position":core-Vector2(100,0),"velocity":Vector2(1000,0),"life":1.0,"hostile":true,"damage":10.0,"hit_radius":4.5}]
	battle.tick(.2,Vector2.ZERO)
	expect(battle.current().hp<hp and battle.projectiles.is_empty(),"real hostile bullet crossing the body core hurts and is consumed")
	expect(battle.position==foot,"moving the damage core never moves the ground anchor")
	var enemy: RefCounted=battle.director.spawn("E01",foot-Vector2(120,0))
	var marker_action:={"id":"marker","action":"marker","shape":"marker","radius":8.0,"windup":.9,"recovery":1.0}
	var marker:=G.descriptor(enemy,marker_action,foot)
	expect(marker.origin==core and marker.direction.is_equal_approx((core-enemy.position).normalized()),"warning placement and aim lock the shared core once")
	expect(G.contains_actor(marker,foot) and not G.contains(marker,foot),"actor collision uses body center while generic point containment stays mathematical")
	for origin: Vector2 in [foot,core]:
		enemy.current_action=marker_action;enemy.telegraph=marker.duplicate(true);enemy.telegraph.origin=origin
		var out:={"hits":[],"hit_sources":[],"projectiles":[],"effects":[],"spawns":[],"events":[],"configuration_errors":[]}
		E._release(enemy,foot,[enemy],[],out,battle.director.config)
		expect(out.hits.size()==(1 if origin==core else 0),"small warned area hits core rather than foot: "+str(origin==core))
		enemy.position=origin-Vector2(60,0);enemy.active_total=.2;enemy.active_remaining=.2;enemy.active_hit=false
		enemy.telegraph={"origin":enemy.position,"direction":Vector2.RIGHT,"length":120.0,"half_width":4.0,"damage":10.0}
		out.hits.clear();out.hit_sources.clear()
		E._advance_charge(enemy,foot,.2,[enemy],out,foot)
		expect(out.hits.size()==(1 if origin==core else 0),"moving charge agrees with the warned line at the core: "+str(origin==core))
	battle._finish("failed")
func spawning() -> void:
	var config:=C.stage("B01")
	var director:=D.new(config,31471)
	var live: Array=[]
	for index in 20:
		var spawned:=director.tick(.6,live.size(),SPACE.CENTER,live,Vector2(215,0))
		for enemy in spawned:
			expect(enemy.position.distance_to(SPACE.CENTER)>=260,"batch formation never appears on the controlled body")
		live.append_array(spawned)
	expect(live.size()>=40 and live.size()<=int(config.enemy_cap),"high-rate cohorts can build substantial bounded density")
	for formation in ["surround","flank","intercept"]:
		var spec:=config.duplicate(true);spec.waves=[{"at":0.0,"interval":.55,"count":6,"cycle":["E01"],"formation":formation,"spawn_radius":620.0,"formation_spread":1.1,"intercept_lead":1.0}]
		var a:=D.new(spec,991);var b:=D.new(spec,991)
		var left:=a.tick(.61,0,SPACE.CENTER,[],Vector2(215,0));var right:=b.tick(.61,0,SPACE.CENTER,[],Vector2(215,0))
		expect(left.size()==6 and right.size()==6,"full authored cohort: "+formation)
		for index in left.size(): expect(left[index].position==right[index].position,"seed-stable cohort geometry: "+formation)
	var gate:=D.new(config,31471);gate.kills=int(config.boss_kills)
	gate.tick(1,0,SPACE.CENTER,[])
	expect(not gate.boss_spawned,"early mowing cannot bypass authored boss minimum time")
	gate.tick(float(config.get("boss_min_time",28)),0,SPACE.CENTER,[])
	expect(gate.boss_spawned,"kill trigger becomes available after minimum time")
	var legacy:=config.duplicate(true);legacy.erase("boss_min_time")
	var compatible:=D.new(legacy,31471);compatible.kills=int(config.boss_kills);compatible.tick(0,0,SPACE.CENTER,[])
	expect(compatible.boss_spawned,"old configuration without minimum-time field preserves its trigger semantics")
	var duel:=B.new(request("B18"))
	expect(duel.enemies.size()==1 and duel.enemies[0].kind=="boss" and duel.director.boss_spawned,"B18 still starts as a lone duel")
func result() -> Dictionary:
	return {"projectiles":[],"projectile_room":1200}
func context(enemy: RefCounted) -> Dictionary:
	return {"origin":enemy.position,"direction":Vector2.RIGHT,"source_id":enemy.id,"definition_id":enemy.definition_id,"form_index":enemy.form_index,"move_id":"shot","action_serial":7,"visual_id":enemy.visual_id,"damage":10.0}
func salvos() -> void:
	var battle:=B.new(request())
	var enemy: RefCounted=battle.director.spawn("E02",SPACE.CENTER)
	var pending: Array=[];var out:=result()
	var pattern:={"kind":"fan","count":7,"spread":1.3,"speed":240,"life":4.0,"hit_radius":4.5,"burst_count":3,"burst_interval":.2,"angle_step":.15}
	P.launch(pattern,context(enemy),pending,SPACE.CENTER+Vector2(200,0),out)
	expect(out.projectiles.size()==7 and pending.size()==2,"only the first authored wave is immediate")
	P.advance(pending,[enemy],SPACE.CENTER,.19,out)
	expect(out.projectiles.size()==7,"second wave cannot fire before its real interval")
	P.advance(pending,[enemy],SPACE.CENTER,.02,out)
	expect(out.projectiles.size()==14 and pending.size()==1,"second wave fires at its scheduled interval")
	P.advance(pending,[enemy],SPACE.CENTER,.2,out)
	expect(out.projectiles.size()==21 and pending.is_empty(),"finite train completes without hidden looping")
	for bullet in out.projectiles:
		expect(bullet.hit_radius==4.5 and bullet.action_serial==7 and bullet.definition_id=="E02" and bullet.move_id=="shot","every child preserves actual danger radius and authored source identity")
		if bullet.burst_index==1: expect(absf(Vector2(bullet.velocity).angle())<=.81,"per-wave rotation is applied to projectile directions")
	out=result();pending=[]
	pattern={"kind":"ring","count":44,"speed":180,"life":4,"hit_radius":4.5,"gap_width":1.2,"gap_angle_offset":.4,"burst_count":3,"burst_interval":.2,"angle_step":.3}
	P.launch(pattern,context(enemy),pending,SPACE.CENTER,out);P.advance(pending,[enemy],SPACE.CENTER,.5,out)
	expect(out.projectiles.size()>80,"authored ring train supplies substantial real projectile pressure")
	for bullet in out.projectiles: expect(absf(wrapf(Vector2(bullet.velocity).angle()-.4,-PI,PI))>=.6-.00001,"all rotated waves preserve the same true escape corridor")
	out=result();pending=[];P.launch(pattern,context(enemy),pending,SPACE.CENTER,out)
	enemy.dead=true;var before:int=out.projectiles.size();P.advance(pending,[enemy],SPACE.CENTER,1,out)
	expect(pending.is_empty() and out.projectiles.size()==before,"unreleased future waves stop when their owner dies")
func actual_patterns() -> void:
	var battle:=B.new(request())
	battle.enemies.clear();battle.director.spawn_remaining=10000;battle.director.config.boss_time=10000;battle.director.config.boss_kills=10000
	var enemy: RefCounted=battle.director.spawn("E06",battle.position+Vector2(200,0))
	enemy.hp=10000;enemy.max_hp=10000;enemy.cooldown=0;battle.enemies=[enemy]
	enemy.actions=[{"id":"pot","action":"pot","shape":"marker","range":500,"radius":55,"windup":1.1,"recovery":1.2,"duration":2,"major":true,"marker_count":3,"marker_spacing":135,"marker_delay":.2,"warning_policy":"area"}]
	battle.tick(.01,Vector2.ZERO)
	expect(enemy.windup>0 and battle.telegraphs.size()==3,"one real action publishes all locked marker warnings")
	var origins: Array=[]
	for marker in battle.telegraphs:
		origins.append(marker.origin)
		expect(marker.warning_policy=="area","every delayed area marker explicitly remains area-warning")
	battle.tick(.1,Vector2.RIGHT)
	for index in battle.telegraphs.size(): expect(battle.telegraphs[index].origin==origins[index],"marker sites never retarget after admission")
	var warning_time:float=enemy.windup
	battle.set_paused(true);battle.tick(2,Vector2.RIGHT)
	expect(is_equal_approx(enemy.windup,warning_time),"pause freezes marker clocks")
	battle.set_paused(false)
	var boss: RefCounted=battle.director.spawn("B01",battle.position+Vector2(100,0))
	var action: Dictionary=boss.actions[0].duplicate(true)
	action.secondary_pattern={"kind":"ring","count":32,"gap_width":1.2,"speed":180,"life":3,"hit_radius":4.5,"burst_count":3,"burst_interval":.2}
	boss.current_action=action;boss.action_serial=11;boss.telegraph=G.descriptor(boss,action,battle.position)
	var out:={"hits":[],"hit_sources":[],"projectiles":[],"effects":[],"spawns":[],"events":[],"configuration_errors":[],"projectile_room":1200}
	var pending: Array=[]
	E._release(boss,battle.position,[boss],[],out,battle.director.config,pending)
	expect(out.projectiles.size()>20 and pending.size()==2,"real melee release can attach a delayed ring train")
	var releases:=0
	for event in out.events:
		if event.kind=="enemy_release": releases+=1
	expect(releases==1,"many bullets retain one original action release/audio signal")
	for bullet in out.projectiles: expect(bullet.move_id==str(action.id) and bullet.action_serial==11,"attached salvo keeps the existing move binding")
	battle.pending_patterns=pending;boss.receive_damage(boss.hp+1000);battle.enemies=[boss];battle._cleanup_sources()
	expect(battle.pending_patterns.is_empty(),"terminal source cleanup removes pending trains")
	battle.pending_patterns=[{"source_id":1}];battle._finish("failed")
	expect(battle.pending_patterns.is_empty() and battle.projectiles.is_empty() and battle.hazards.is_empty(),"terminal attempt clears delayed and already active danger")
func pursuit() -> void:
	var battle:=B.new(request("B17"))
	var boss: RefCounted=battle.director.spawn("B17",SPACE.CENTER)
	boss.initialized=true;boss.cooldown=0;boss.attack_index=1
	var action: Dictionary=E._next_action(boss)
	expect(str(action.id)=="general_cut" and float(action.get("approach_speed",0))==210,"B17 follow-up explicitly closes the distance after a long charge")
	var actor:=SPACE.CENTER+Vector2(600,0)
	E.step([boss],actor,.1,{"config":battle.director.config})
	expect(is_equal_approx(boss.position.x,SPACE.CENTER.x+21) and boss.windup==0,"follow-up pursues at its authored speed without beginning an out-of-range warning")
	expect(boss.speed==64 and float(boss.actions[0].length)==820,"pursuit preserves the body's normal speed and full long-charge distance")
	E.step([boss],actor,1.5,{"config":battle.director.config})
	E.step([boss],actor,.01,{"config":battle.director.config})
	expect(boss.windup>0 and is_equal_approx(boss.windup,float(action.windup)),"arrival starts the original full read window")
func crowd() -> void:
	var battle:=B.new(request());var enemies: Array=[]
	for index in 240:
		var enemy: RefCounted=battle.director.spawn("E01",SPACE.CENTER+Vector2((index%24-12)*16,(index/24-5)*16))
		enemy.cooldown=0;enemies.append(enemy)
	var grid:=GRID.new();grid.rebuild(enemies)
	E.step(enemies,SPACE.CENTER,.016,{"spatial":grid,"config":{"action_budget":{"major":0,"melee":0}}})
	expect(grid.candidate_visits<=enemies.size()*GRID.MAX_NEIGHBORS,"crowd spacing work is bounded by 32 local candidates per entity")
	expect(TARGET.in_shape(enemies,SPACE.CENTER,Vector2.RIGHT,1000,false,true).size()==240,"spacing budget never removes real attack targets or damage receivers")
	print("PRESSURE_SPACING candidates=",grid.candidate_visits," entities=",enemies.size()," all_pairs=",enemies.size()*(enemies.size()-1))
