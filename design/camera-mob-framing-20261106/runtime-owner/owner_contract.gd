extends SceneTree
const CAMERA=preload("res://scripts/ui/chronicle/boss_camera.gd")
const BATTLE=preload("res://scripts/battle/battle_session.gd")
const C=preload("res://scripts/content/combat_catalog.gd")
const E=preload("res://scripts/battle/enemy_system.gd")
const SPACE=preload("res://scripts/battle/battle_space.gd")
var checks=0
var failures=0

func _init()->void: call_deferred("run")
func expect(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)

func battle()->RefCounted:
	return BATTLE.new({"attempt_id":"camera-owner-contract","members":["JIA"],"characters":{"JIA":C.record("JIA")},"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":"ember_seal"},"stage":C.stage("B17"),"seed":1717,"node":{"id":"B17","name":"diagnostic"}})

func run()->void:
	var b=battle()
	var sources={}
	for id in ["E01","E02","E03","E04","E05","E06","E07","E08","E09","E10","E11","E12","L05","B17"]:
		var enemy=b.director.spawn(id,SPACE.CENTER+Vector2(250,0))
		sources[enemy.id]=enemy
		b.enemies.append(enemy)
		expect(CAMERA.framing_owner({"owner_id":enemy.id},sources)==(enemy.id if enemy.rank in ["field_elite","boss"] else 0),"actual rank qualification "+id)
	var boss=b.enemies[-1]
	for id in ["D01","D03","D05","E10"]:
		var child=b.director.derivative({"definition_id":id,"position":boss.position+Vector2(80,-50),"parent_id":boss.id},b.enemies)
		sources[child.id]=child;b.enemies.append(child)
		expect(CAMERA.framing_owner({"owner_id":child.id},sources)==0,"ordinary/heavy/object child does not inherit "+id)
	var proxy=b.director.derivative({"definition_id":"M03_WAR","position":boss.position+Vector2(80,-50),"parent_id":boss.id},b.enemies)
	sources[proxy.id]=proxy;b.enemies.append(proxy)
	expect(CAMERA.framing_owner({"owner_id":proxy.id},sources)==boss.id,"true apparition proxy inherits Boss")
	var owner=b.director.spawn("B10",SPACE.CENTER+Vector2(0,-200))
	b.enemies.append(owner);sources[owner.id]=owner
	var partner=b.director.derivative({"definition_id":"B10_R","position":owner.position+Vector2(0,150),"parent_id":owner.id,"hp_owner_id":owner.id},b.enemies)
	sources[partner.id]=partner
	expect(partner.hp_owner==owner and CAMERA.framing_owner({"owner_id":partner.id},sources)==owner.id,"real shared-health B10_R inherits")
	expect(CAMERA.framing_owner({"owner_id":boss.id,"action_id":"collaboration"},sources)==boss.id,"B17 collaboration directly owned by Boss")
	expect(CAMERA.framing_owner({},sources)==0 and CAMERA.framing_owner({"owner_id":-1},sources)==0,"missing/invalid owners excluded")
	var detached=sources.duplicate();detached.erase(owner.id)
	expect(CAMERA.framing_owner({"owner_id":partner.id},detached)==0,"removed owner excluded despite retained object reference")
	owner.dead=true
	expect(CAMERA.framing_owner({"owner_id":partner.id},sources)==0,"dead shared owner excluded")
	owner.dead=false;proxy.parent_id=proxy.id
	expect(CAMERA.framing_owner({"owner_id":proxy.id},sources)==0,"cyclic proxy parent excluded")
	proxy.parent_id=boss.id;proxy.dead=true
	expect(CAMERA.framing_owner({"owner_id":proxy.id},sources)==0,"dead proxy excluded")
	# Real L05 hook admission/release, with unmodified B17 budgets and timings.
	b=battle()
	var elite=b.director.spawn("L05",SPACE.CENTER+Vector2(350,40))
	b.enemies.append(elite)
	b.enemies.append(b.director.spawn("E06",SPACE.CENTER+Vector2(-420,0)))
	var camera=CAMERA.new();var warnings=0;var routes=0;var minimum=1.0;var center_offset=0.0;var poison_veto=0
	for frame in 240:
		var dt=1.0/60.0
		b.director.elapsed+=dt;b._actor_previous_position=b.position;b.spatial.rebuild(b.enemies)
		var result=E.step(b.enemies,b.position,dt,{"hazards":b.hazards,"patterns":b.pending_patterns,"spatial":b.spatial,"projectiles":b.projectiles,"config":b.director.config,"actor_speed":b.current().stats.move})
		b.projectiles.append_array(result.projectiles);b._update_projectiles(dt,[],[]);b._refresh_telegraphs()
		camera.consume(result.events);camera.update(b,Vector2(1280,720),dt,false,72,188)
		if camera.mode=="warning": warnings+=1
		if camera.escape_valid: routes+=1
		if camera.mode=="warning":
			var active:Array[Dictionary]=[]
			for hazard:Dictionary in b.hazards:
				if hazard.get("phase","")!="tell" and float(hazard.get("damage",0))>0: active.append(hazard)
			var without=camera._escape(b.position,camera._escape_dangers,[],b.current().stats.move,b.position+Vector2(0,-100))
			var with_poison=camera._escape(b.position,camera._escape_dangers,active,b.current().stats.move,b.position+Vector2(0,-100))
			if without.valid and not with_poison.valid: poison_veto+=1
		minimum=minf(minimum,camera.scale)
		center_offset=maxf(center_offset,camera.center.distance_to(b.position+Vector2(0,-20)))
	expect(warnings>0 and center_offset>1,"actual field elite hook still changes framing")
	expect(routes>0,"actual field elite hook retains reachable exit framing")
	expect(poison_veto>0,"actual ordinary pot vetoes otherwise valid elite exit without owning framing")
	print("CAMERA_OWNER_CONTRACT checks=",checks," failures=",failures," elite_warning_frames=",warnings," elite_route_frames=",routes," elite_min_scale=",minimum," elite_center_offset=",center_offset," poison_veto_frames=",poison_veto)
	quit(0 if failures==0 else 1)
