extends SceneTree
## Diagnostic only: real authored enemy admission, hazards and projectile stepping.
## Player combat/health and director reinforcements are omitted to isolate framing.
const BATTLE=preload("res://scripts/battle/battle_session.gd")
const C=preload("res://scripts/content/combat_catalog.gd")
const E=preload("res://scripts/battle/enemy_system.gd")
const CAMERA=preload("res://scripts/ui/chronicle/boss_camera.gd")
const SPACE=preload("res://scripts/battle/battle_space.gd")
const DT=1.0/60.0
const ROOT="res://design/camera-mob-jitter-20261106/"
var results:Array=[]
var stage_id="B17"
var output_root=ROOT

func _init()->void: call_deferred("run")

func vec(v:Vector2)->Array: return [v.x,v.y]
func rect(r:Rect2)->Array: return [r.position.x,r.position.y,r.size.x,r.size.y]

func run()->void:
	var specs=[
		["E03",8,350.0],["E10",4,420.0],["E06",7,420.0],
		["E12",4,200.0],["E09",4,140.0],["E01",10,100.0],
		["E02",7,420.0],["E05",7,420.0],["E04",10,100.0]]
	var only=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="): only=argument.trim_prefix("--only=")
		if argument.begins_with("--stage="): stage_id=argument.trim_prefix("--stage=")
		if argument.begins_with("--out="): output_root=argument.trim_prefix("--out=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(output_root)
	for spec in specs:
		if not only.is_empty() and str(spec[0]) not in only.split(","): continue
		for moving in [false,true]: run_case(str(spec[0]),int(spec[1]),float(spec[2]),moving,false)
	# Two targeted edge variants use the same enemy rules and actual arena clamp.
	if only.is_empty():
		for id in ["E03","E10","E06"]: run_case(id,4,280.0,true,true)
	var result_path=output_root+("results.json" if only.is_empty() else "results-"+only+".json")
	var file=FileAccess.open(result_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"isolated EnemySystem + real BattleSession projectile/telegraph adapters + BossCamera; no player combat, no health reduction, no reinforcements, no Boss, no altered actions/geometry/budgets", "stage":stage_id, "seconds_per_case":20,"dimensions":[1280,720],"safe_top":72,"safe_bottom":188,"cases":results},"\t"));file.close()
	print("MOB_CAMERA_DIAGNOSTIC cases=",results.size()," output=",result_path)
	quit()

func run_case(id:String,count:int,radius:float,moving:bool,edge:bool)->void:
	var label=id+("_moving" if moving else "_still")+("_edge" if edge else "")
	var b=BATTLE.new({"attempt_id":"camera-diagnostic", "members":["JIA"],"characters":{"JIA":C.record("JIA")},"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":"ember_seal"},"stage":C.stage(stage_id),"seed":1717,"node":{"id":stage_id,"name":"diagnostic"}})
	var home:Vector2=Vector2(320,300) if edge else SPACE.CENTER
	b.position=home
	for i in count:
		var point:Vector2=SPACE.clamp_point(home+Vector2.from_angle(TAU*i/count+.21)*radius,Vector2(45,45))
		b.enemies.append(b.director.spawn(id,point))
	var camera=CAMERA.new()
	var single=CAMERA.new()
	var out=FileAccess.open(output_root+label+".jsonl",FileAccess.WRITE)
	var previous:Dictionary={}
	var previous_route=Vector2.ZERO
	var previous_keys=""
	var admissions=0;var releases=0;var route_flips=0;var set_changes=0;var recomputes=0
	var max_origin=0.0;var max_center=0.0;var max_route=0.0;var max_hard=0.0
	var min_scale=1.0;var max_scale=0.0;var double_origin=0.0;var double_center=0.0;var double_zoom=0.0
	var largest:Array=[]
	for frame in 1200:
		var time:float=(frame+1)*DT
		b.director.elapsed=time
		b._actor_previous_position=b.position
		b.enemy_slow_remaining=maxf(0,b.enemy_slow_remaining-DT)
		if b.enemy_slow_remaining<=0: b.enemy_slow=0
		# Ordinary legal horizontal movement, smooth reversals, <= current move speed.
		if moving: b.position=SPACE.clamp_point(home+Vector2(sin(time*.65)*180,0),SPACE.PLAYER_MARGIN)
		b.spatial.rebuild(b.enemies)
		var hostile=E.step(b.enemies,b.position,DT,{"hazards":b.hazards,"patterns":b.pending_patterns,"spatial":b.spatial,"projectiles":b.projectiles,"actor_previous":b._actor_previous_position,"config":b.director.config,"actor_speed":float(b.current().stats.move)*(1-b.enemy_slow)})
		for spawn in hostile.spawns: b.enemies.append(b.director.derivative(spawn,b.enemies))
		b.projectiles.append_array(hostile.projectiles)
		b._update_projectiles(DT,[],[])
		for event in hostile.events:
			if event.kind=="enemy_slow": b.enemy_slow=float(event.slow);b.enemy_slow_remaining=float(event.duration)
			if event.kind=="enemy_tell": admissions+=1
			if event.kind in ["enemy_release","enemy_hazard_release"]: releases+=1
		for i in range(b.enemies.size()-1,-1,-1):
			if b.enemies[i].dead: b.enemies.remove_at(i)
		b._refresh_telegraphs()
		var last_dangers:Array=camera._escape_dangers.duplicate(true)
		var last_player:Vector2=camera._escape_player
		var was_valid:bool=camera._escape_inputs_valid
		camera.consume(hostile.events);single.consume(hostile.events)
		camera.update(b,Vector2(1280,720),DT,false,72,188)
		if camera.mode=="warning" and (not was_valid or last_dangers!=camera._escape_dangers or last_player!=camera._escape_player): recomputes+=1
		var advance:Dictionary=camera.snapshot()
		# Mirrors Canvas advance_presentation(delta) then refresh()->update(0).
		camera.update(b,Vector2(1280,720),0,false,72,188)
		single.update(b,Vector2(1280,720),DT,false,72,188)
		var state:Dictionary=camera.snapshot()
		double_origin=maxf(double_origin,camera.origin.distance_to(single.origin))
		double_center=maxf(double_center,camera.center.distance_to(single.center))
		double_zoom=maxf(double_zoom,absf(camera.zoom-single.zoom))
		var keys:Array=[]
		if camera.mode=="warning":
			for danger in camera._escape_dangers: keys.append(str(danger.owner_id)+":"+str(danger.get("action_serial",0))+":"+str(danger.get("phase","")))
		keys.sort()
		var key_text="|".join(keys)
		if key_text!=previous_keys: set_changes+=1
		var route:Vector2=camera.safe_route[1]-b.position if camera.safe_route.size()>1 else Vector2.ZERO
		var route_jump:float=route.distance_to(previous_route) if frame>0 else 0.0
		var flipped:bool=route.length()>3 and previous_route.length()>3 and route.normalized().dot(previous_route.normalized())<0
		if flipped: route_flips+=1
		var origin_jump:float=camera.origin.distance_to(previous.origin) if not previous.is_empty() else 0.0
		var center_jump:float=camera.center.distance_to(previous.center) if not previous.is_empty() else 0.0
		var target:Vector2=camera.focus_bounds.get_center() if camera.mode=="warning" else b.position+Vector2(0,-20)
		var hard:float=camera.center.distance_to(Vector2(previous.center).lerp(target,1-exp(-DT*6))) if not previous.is_empty() else 0.0
		max_origin=maxf(max_origin,origin_jump);max_center=maxf(max_center,center_jump);max_route=maxf(max_route,route_jump);max_hard=maxf(max_hard,hard)
		min_scale=minf(min_scale,camera.scale);max_scale=maxf(max_scale,camera.scale)
		var row={"frame":frame,"time":time,"player":vec(b.position),"center":vec(camera.center),"origin":vec(camera.origin),"scale":camera.scale,"zoom":camera.zoom,"trauma":camera.trauma,"mode":camera.mode,"route":vec(route),"route_flipped":flipped,"route_jump":route_jump,"origin_jump":origin_jump,"center_jump":center_jump,"post_smoothing_correction_world":hard,"focus":rect(camera.focus_bounds),"requested":rect(camera.requested_bounds),"danger_keys":keys,"danger_set_changed":key_text!=previous_keys,"escape_valid":camera.escape_valid,"escape_needed":camera.escape_needed,"telegraphs":b.telegraphs.size(),"hazards":b.hazards.size(),"events":hostile.events}
		out.store_line(JSON.stringify(row))
		if origin_jump>3 or flipped:
			largest.append({"frame":frame,"time":time,"origin_jump":origin_jump,"center_jump":center_jump,"route_jump":route_jump,"route_flipped":flipped,"danger_set_changed":key_text!=previous_keys,"post_smoothing_correction_world":hard,"trauma":camera.trauma})
		previous=state;previous_route=route;previous_keys=key_text
	out.close()
	largest.sort_custom(func(a,b):return a.origin_jump>b.origin_jump)
	if largest.size()>15: largest.resize(15)
	var summary={"label":label,"enemy_id":id,"count":count,"radius":radius,"moving":moving,"edge":edge,"admissions":admissions,"releases":releases,"route_flips":route_flips,"danger_set_changes":set_changes,"escape_recomputes":recomputes,"max_origin_step_px":max_origin,"max_center_step_world":max_center,"max_route_step_world":max_route,"max_post_smoothing_correction_world":max_hard,"scale_min":min_scale,"scale_max":max_scale,"double_update_max_origin_difference_px":double_origin,"double_update_max_center_difference_world":double_center,"double_update_max_zoom_difference":double_zoom,"largest_changes":largest}
	results.append(summary)
	print("MOB_CAMERA_CASE ",JSON.stringify(summary))
