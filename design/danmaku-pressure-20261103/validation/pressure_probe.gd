extends SceneTree
const B := preload("res://scripts/battle/battle_session.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const S := preload("res://scripts/content/stage_catalog.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
const G := preload("res://scripts/battle/enemy_geometry.gd")
const ES := preload("res://scripts/battle/enemy_system.gd")
var suite := "mobs"
var only_stages := ""
var output := "/tmp/probe.json"
var seeds: Array[int] = []
var reports: Array = []
var snapshots: Dictionary = {}
var observations: Array = []
var direction := Vector2.ZERO
var decisions := 0
var zero_candidates := 0
var warning_decisions := 0
var unsafe_examples: Array = []

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stages="): only_stages=arg.trim_prefix("--stages=")
		if arg.begins_with("--suite="): suite = arg.trim_prefix("--suite=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--seeds="):
			for seed_text in arg.trim_prefix("--seeds=").split(","): seeds.append(int(seed_text))
	call_deferred("run")

func run() -> void:
	for seed_value in seeds:
		if suite in ["mobs","growth"]:
			for stage in ["B01","B05","B12"]:
				if not only_stages.is_empty() and stage not in only_stages.split(","): continue
				for policy in (["reactive"] if suite=="growth" else ["stationary","orbit","reactive"]): reports.append(simulate(stage,seed_value,policy,-1))
		else:
			for stage in (["B17"] if suite=="cadence" else ["B15","B16","B17","B18"]):
				if not only_stages.is_empty() and stage not in only_stages.split(","): continue
				for phase in ([0] if suite in ["duel","cadence"] else [0,1]):
					for start_name in ["center","corner"]:
						for policy in (["reactive"] if suite=="duel" else ["stationary","reactive"]): reports.append(simulate(stage,seed_value,policy,phase,start_name))
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"suite":suite,"dt":1.0/60,"reaction_delay_seconds":0.2,"decision_interval_seconds":0.15,"human_playtest":false,"reports":reports},"  "))
	var snap_file := FileAccess.open(output.trim_suffix(".json")+"-snapshots.json",FileAccess.WRITE)
	snap_file.store_string(JSON.stringify(encode_vectors({"snapshots":snapshots.values()}),"  "))
	print("PRESSURE_PROBE_COMPLETE reports=",reports.size());quit(0)

func simulate(stage: String, seed_value: int, policy: String, phase: int, start_name: String = "center") -> Dictionary:
	var level := 1 if stage == "B01" else 4 if stage == "B05" else 8 if stage == "B12" else 12
	var members: Array = ["JIA"] if stage == "B01" else ["JIA","F11","N16"]
	var owned := {}
	for member in members: owned[member] = C.record(member,level)
	var config := S.stage(stage)
	if phase >= 0: config.boss_time = 0; config.boss_kills = 0; config.fields_enabled = false
	var request := {"attempt_id":"probe","members":members,"characters":owned,"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":"ember_seal"},"stage":config,"seed":seed_value}
	var b := B.new(request)
	if phase >= 0:
		if start_name == "corner": b.position=Vector2(80,90)
		if b.enemies.is_empty(): b.enemies.append_array(b.director.tick(0,0,b.position,b.enemies))
		for enemy in b.enemies:
			if enemy.rank == "boss": enemy.position=SPACE.challenge_position(b.position)
			if enemy.form_count > 1: enemy._apply_form(phase)
		b.active = 1
	var entry_front_stats: Dictionary = b.current().stats.duplicate(true)
	var entry := {}
	for member in members: entry[member] = b.characters[member].snapshot()
	observations.clear();direction=Vector2.ZERO;decisions=0;zero_candidates=0;warning_decisions=0;unsafe_examples.clear()
	var warning_audits: Array = []
	var phase_records: Array=[];var previous_phase:=-1;var tell_timeline: Array=[];var previous_tell_move:=""
	var releases := {};var tells := {};var last_tell := 0.0;var largest_tell_gap := 0.0;var idle := 0.0;var max_idle := 0.0;var max_pending := 0;var total_pending := 0.0
	var max_alive := 0;var max_near := 0;var max_bullets := 0;var sum_alive := 0.0;var sum_near := 0.0;var sum_bullets := 0.0
	var hurt := 0.0;var hits := 0;var kills := 0;var xp := 0.0;var distance := 0.0;var moving := 0;var boundary := 0;var steps: Array = [];var actions := {};var seen_actions := {};var hit_actions := {};var cast_count := 0;var delayed_max := 0;var frames := 0
	var limit: float = config.boss_time+1.0 if suite=="growth" else 45.0 if suite in ["exposure","cadence"] else 180.0 if suite=="duel" else 60.0 if phase >= 0 else minf(50,config.boss_time-0.1)
	for frame in int(limit*60):
		if not b.outcome.is_empty(): break
		if phase < 0 and b.director.boss_spawned: break
		if phase >= 0 and suite not in ["exposure","cadence","duel"]:
			var crossed := false
			for enemy in b.enemies:
				if enemy.rank == "boss" and enemy.form_index != phase: crossed = true
			if crossed: break
		var movement := Vector2.ZERO
		if policy == "orbit":
			var angle := frame/60.0 * 0.32
			var goal := SPACE.CENTER + Vector2(cos(angle)*520,sin(angle)*340)
			movement = (goal-b.position).normalized()
		elif policy == "reactive": movement = drive(b,frame)
		if suite not in ["exposure","cadence"] and frame % 30 == 0: b.request_skill(0);b.request_skill(1)
		var old: Vector2 = b.position
		var before := Time.get_ticks_usec()
		if suite in ["exposure","cadence"]:
			# Explicit non-survival exposure: suppress all player offense and restore HP.
			for character in b.characters.values():
				var kit: Dictionary = C.definition(character.id)
				var abilities: Array = [kit.basic]+kit.automatic+kit.manual
				if kit.support != null: abilities.append(kit.support)
				for ability in abilities: character.cooldowns[str(ability.id)] = 9999.0
				character.hp=character.stats.hp;character.dead=false
			# Real session tick still drives movement, enemy actions and hostile collisions.
		b.tick(1.0/60.0,movement)
		steps.append((Time.get_ticks_usec()-before)/1000.0)
		frames+=1;distance+=old.distance_to(b.position);moving+=int(old.distance_to(b.position)>0.1)
		boundary += int(b.position.x < 75 or b.position.x > SPACE.SIZE.x-75 or b.position.y < 85 or b.position.y > SPACE.SIZE.y-85)
		var alive := 0;var near := 0;var bullets := 0;var enemy_busy := false
		for enemy in b.enemies:
			if enemy.dead: continue
			if enemy.rank=="boss" and enemy.hp_owner==null and enemy.form_index!=previous_phase:
				var resources := {}
				for member in members: resources[member]=b.characters[member].snapshot()
				phase_records.append({"time":b.director.elapsed,"form_index":enemy.form_index,"transition_remaining":enemy.transition_remaining,"phase_damage_bank":enemy.phase_damage_bank,"active":b.current().id,"resources":resources})
				previous_phase=enemy.form_index
			alive+=1
			if enemy.windup>0 or enemy.active_remaining>0: enemy_busy=true
			if enemy.position.distance_to(b.position) <= 240: near+=1
			if enemy.windup > 0:
				var action_key := "%s:%s:%s" % [enemy.id,enemy.form_index,enemy.action_serial]
				if not seen_actions.has(action_key):
					seen_actions[action_key]=true
					if not enemy.telegraph.is_empty() and str(enemy.telegraph.get("warning_policy","area")) != "none" and not bool(enemy.telegraph.get("projectile_only",enemy.attack in ["shot","fan"])) and float(enemy.telegraph.get("damage",0))>0:
						warning_audits.append(audit_warning(b,enemy.telegraph))
					var action := "%s:%s" % [enemy.definition_id,enemy.current_action.get("id",enemy.attack)]
					actions[action]=int(actions.get(action,0))+1
		for projectile in b.projectiles:
			if projectile.get("hostile",false): bullets+=1
		delayed_max=maxi(delayed_max,b.get("pending_patterns").size() if b.get("pending_patterns") != null else 0)
		idle=0.0 if enemy_busy else idle+1.0/60.0;max_idle=maxf(max_idle,idle)
		var pending_count: int = b.get("pending_patterns").size() if b.get("pending_patterns") != null else 0
		max_pending=maxi(max_pending,pending_count);total_pending+=pending_count
		if output.contains("after-"):
			for metric in ["density","bullet","area"]:
				var score: float = alive if metric=="density" else bullets if metric=="bullet" else largest_danger_area(b)
				var snapshot_key: String = stage+":"+metric
				if not snapshots.has(snapshot_key) or score>float(snapshots[snapshot_key].score):
					snapshots[snapshot_key]=capture_state(b,request,stage,phase,start_name,policy,score,metric)
		max_alive=maxi(max_alive,alive);max_near=maxi(max_near,near);max_bullets=maxi(max_bullets,bullets)
		sum_alive+=alive;sum_near+=near;sum_bullets+=bullets
		for event in b.events:
			match str(event.get("kind","")):
				"enemy_tell":
					var key := str(event.get("move_id",event.get("attack","unattributed")))
					tells[key]=int(tells.get(key,0))+1
					var boss_distance := -1.0
					for enemy in b.enemies:
						if enemy.rank=="boss" and enemy.hp_owner==null: boss_distance=enemy.position.distance_to(b.position);break
					tell_timeline.append({"time":b.director.elapsed,"move_id":key,"previous_move":previous_tell_move,"initial_approach":last_tell==0,"since_previous_tell":b.director.elapsed-last_tell,"boss_distance":boss_distance,"actor_position":b.position})
					previous_tell_move=key
					largest_tell_gap=maxf(largest_tell_gap,b.director.elapsed-last_tell);last_tell=b.director.elapsed
				"enemy_release":
					var key := str(event.get("move_id",event.get("attack","unattributed")))
					releases[key]=int(releases.get(key,0))+1
				"hurt": hurt+=float(event.amount);hits+=1
				"kill":
					if event.get("living",false): kills+=1
				"xp_pickup": xp+=float(event.amount)
				"cast": cast_count+=1
				"damage_taken":
					var key := str(event.get("action_id",event.get("attack","unattributed")))
					hit_actions[key]=int(hit_actions.get(key,0))+1
	steps.sort()
	var exit := {};for member in members: exit[member] = b.characters[member].snapshot()
	var ground_xp := 0.0
	for gem in b.gems: ground_xp+=float(gem.amount)
	var earned_xp := {}
	for member in members:
		var amount: float = float(exit[member].xp)-float(entry[member].xp)
		for l in range(int(entry[member].level),int(exit[member].level)): amount+=C.xp_required(l)
		earned_xp[member]=amount
	var result := {"boss_spawned":b.director.boss_spawned,"stop_reason":"failed" if b.outcome=="failed" else "boss_appeared" if phase<0 and b.director.boss_spawned else b.outcome if not b.outcome.is_empty() else "sample_or_phase_limit","actual_xp_gained_by_member":earned_xp,"xp_on_ground_at_stop":ground_xp,"xp_picked_or_ground":xp+ground_xp,"stage":stage,"seed":seed_value,"phase_fixture":phase,"start":start_name,"entry_front_stats":entry_front_stats,"strategy":policy,"fixture_level":level,"members":members,"front":"F11" if phase >= 0 else "JIA","equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":"ember_seal"},"entry":entry,"exit":exit,"seconds":frames/60.0,"outcome":b.outcome if not b.outcome.is_empty() else "phase_complete" if phase >= 0 and frames<int(limit*60) else "sample_limit","godmode_exposure":suite in ["exposure","cadence"],"peak_alive":max_alive,"mean_alive":sum_alive/maxi(1,frames),"peak_within_240":max_near,"mean_within_240":sum_near/maxi(1,frames),"peak_hostile_projectiles":max_bullets,"mean_hostile_projectiles":sum_bullets/maxi(1,frames),"peak_delayed":delayed_max,"kills":kills,"kills_per_second":kills/maxf(.01,frames/60.0),"xp_collected":xp,"hurt_events":hits,"hurt_total":hurt,"damage_action_events":hit_actions,"distance_moved":distance,"moving_fraction":float(moving)/maxi(1,frames),"boundary_fraction":float(boundary)/maxi(1,frames),"decisions":decisions,"zero_safe_sampled_directions":zero_candidates,"warning_decisions":warning_decisions,"unsafe_direction_examples":unsafe_examples.duplicate(true),"actions_started":actions,"tell_events":tells,"tell_timeline":tell_timeline,"phase_resource_records":phase_records,"release_events":releases,"largest_seconds_between_tells":maxf(largest_tell_gap,b.director.elapsed-last_tell),"max_seconds_without_windup_or_charge":max_idle,"peak_pending_patterns":max_pending,"mean_pending_patterns":total_pending/maxi(1,frames),"warning_initial_reachability":warning_audits,"cast_events":cast_count,"logic_step_ms":{"samples":steps.size(),"p50":steps[int(steps.size()*.5)] if steps.size()>0 else 0,"p95":steps[int(steps.size()*.95)] if steps.size()>0 else 0,"max":steps[-1] if steps.size()>0 else 0},"configuration_error":b.director.configuration_error}
	print("SAMPLE ",JSON.stringify(result));return result

func drive(b: RefCounted, frame: int) -> Vector2:
	var visible: Array = []
	for warning in b.telegraphs:
		if str(warning.get("warning_policy","area")) != "none": visible.append(warning.duplicate(true))
	var snapshot := {"position":b.position,"telegraphs":visible,"hazards":b.hazards.duplicate(true),"projectiles":[]}
	for projectile in b.projectiles:
		if projectile.get("hostile",false): snapshot.projectiles.append(projectile.duplicate(true))
	observations.append(snapshot)
	if observations.size()>13: observations.pop_front()
	if frame % 9 != 0 or observations.size()<13: return direction
	var observed: Dictionary = observations[0]
	var speed: float = b.current().stats.move * (1-b.enemy_slow)
	var objective: Vector2 = SPACE.CENTER
	var nearest := INF
	for enemy in b.enemies:
		if enemy.dead or not enemy.targetable: continue
		var d: float = b.position.distance_to(enemy.position)
		if d<nearest:
			nearest=d;objective=enemy.position+(b.position-enemy.position).normalized()*(245 if b.active==1 else 64)
	var best := INF;var safe := 0;var warned: bool = not observed.telegraphs.is_empty()
	for i in 33:
		var candidate := Vector2.ZERO if i==32 else Vector2.RIGHT.rotated(i*TAU/32)
		var risk := 0.0
		var endpoint := SPACE.clamp_point(b.position+candidate*speed*.65,SPACE.PLAYER_MARGIN)
		if endpoint.distance_to(b.position+candidate*speed*.65)>3: risk+=10
		for warning in observed.telegraphs+observed.hazards:
			if float(warning.get("damage",1))<=0: continue
			var remaining := float(warning.get("remaining",.5))-.2
			if str(warning.get("phase","tell"))=="tell" and remaining > .85: continue
			for sample in 6:
				var time := sample*.13
				if str(warning.get("phase","tell"))=="tell" and time<remaining: continue
				if G.contains(warning,SPACE.clamp_point(b.position+candidate*speed*time,SPACE.PLAYER_MARGIN),4): risk+=1
		for bullet in observed.projectiles:
			var relative: Vector2 = bullet.position+bullet.velocity*.2-b.position
			var velocity: Vector2 = bullet.velocity-candidate*speed
			var t := clampf(-relative.dot(velocity)/maxf(.001,velocity.length_squared()),0,.75)
			if (relative+velocity*t).length() < float(bullet.get("radius",bullet.get("hit_radius",7)))+7: risk+=2
		if risk<.01: safe+=1
		var score: float = risk*10000+endpoint.distance_to(objective)*.02+candidate.distance_to(direction)*.5
		if score<best: best=score;direction=candidate
	decisions+=1;zero_candidates+=int(safe==0);warning_decisions+=int(warned)
	if safe==0 and unsafe_examples.size()<12: unsafe_examples.append({"time":frame/60.0,"position":b.position,"warnings":observed.telegraphs,"hazards":observed.hazards,"bullets":observed.projectiles.size(),"min_score":best})
	return direction

# Independent initial-tell reachability sampler. It does not predict future moves
# or certify every possible curved route. Static projectiles are excluded.
func audit_warning(b: RefCounted, warning: Dictionary) -> Dictionary:
	var speed: float = b.current().stats.move * (1-b.enemy_slow)
	var deadline := maxf(0,float(warning.get("remaining",0))-.2)
	var reachable := 0
	var best_distance := INF
	for ring in [0.0,.25,.5,.75,1.0]:
		for i in 64:
			var point := SPACE.clamp_point(b.position+Vector2.RIGHT.rotated(i*TAU/64)*speed*deadline*float(ring),SPACE.PLAYER_MARGIN)
			if G.contains(warning,point): continue
			var blocked_extra := false
			for extra in warning.get("extra_markers",[]):
				if G.contains(extra,point): blocked_extra=true;break
			if blocked_extra: continue
			var safe := true
			for hazard in b.hazards:
				if str(hazard.get("phase","tell")) != "active" or str(hazard.get("kind",""))=="slow_strip": continue
				for sample in range(1,9):
					if G.contains(hazard,b.position.lerp(point,sample/8.0)): safe=false;break
				if not safe: break
			if safe: reachable+=1;best_distance=minf(best_distance,b.position.distance_to(point))
	return {"time":b.director.elapsed,"position":b.position,"move_id":warning.get("move_id",warning.get("action_id","")),"shape":warning.shape,"radius":warning.get("radius",0),"windup":warning.get("remaining",0),"reaction_seconds":.2,"speed":speed,"safe_sampled_routes":reachable,"nearest_sampled_escape_distance":best_distance if reachable>0 else -1,"warning":warning.duplicate(true)}

func capture_state(b: RefCounted, request: Dictionary, stage: String, phase: int, start_name: String, policy: String, score: float, metric: String) -> Dictionary:
	var state := {"position":b.position,"active":b.active,"characters":{},"enemies":[],"projectiles":b.projectiles.duplicate(true),"hazards":b.hazards.duplicate(true),"telegraphs":b.telegraphs.duplicate(true),"effects":b.effects.duplicate(true),"gems":b.gems.duplicate(true),"director_elapsed":b.director.elapsed,"boss_spawned":b.director.boss_spawned,"field":b.director.field,"kills":b.director.kills,"target_id":b.target_id,"facing":b.facing,"outcome":b.outcome,"cast_serial":b.cast_serial}
	for id in b.members:
		state.characters[id]=b.characters[id].snapshot()
		for property in ["id","stats","shield","haste","hurt_lock"]:
			var value: Variant = b.characters[id].get(property)
			state.characters[id][property]=value.duplicate(true) if value is Dictionary or value is Array else value
	for enemy in b.enemies:
		var record := {}
		for property in ["definition_id","behavior_id","elite_rule_id","visual_id","rank","reward_tag","parent_id","hp_owner_id","targetable","counts_for_threshold","death_reason","body_height","state","active_remaining","active_total","active_hit","guard_active","action_serial","telegraph","definition","actions","current_action","params","spawned_total","initialized","anchor_position","healing_received","rule_cooldown","protection_remaining","command_remaining","form_index","form_count","form_name","forms","encounter_max_hp","transition_remaining","observation_remaining","phase_damage_bank","phase_change_pending","age","id","kind","position","hp","max_hp","radius","speed","damage","xp","dead","slow","slow_time","cooldown","windup","aim","attack","attack_index"]: 
			var value: Variant = enemy.get(property)
			record[property]=value.duplicate(true) if value is Dictionary or value is Array else value
		state.enemies.append(record)
	return {"score":score,"stage":stage,"phase_fixture":phase,"start":start_name,"strategy":policy,"godmode_exposure":suite in ["exposure","cadence"],"seconds":b.director.elapsed,"request":request.duplicate(true),"state":state,"provenance":{"metric":metric,"frame":int(round(b.director.elapsed*60)),"seconds":b.director.elapsed,"phase_fixture":phase,"start":start_name,"strategy":policy,"seed":request.seed,"godmode_exposure":suite in ["exposure","cadence"],"suite":suite}}

func encode_vectors(value: Variant) -> Variant:
	if value is Vector2: return {"$vector2":[value.x,value.y]}
	if value is Dictionary:
		var result := {}
		for key in value: result[key]=encode_vectors(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value: result.append(encode_vectors(item))
		return result
	if value is Object: return null
	return value

func largest_danger_area(b: RefCounted) -> float:
	var result := 0.0
	for g in b.telegraphs+b.hazards:
		if float(g.get("damage",0))<=0 or str(g.get("warning_policy","area"))!="area" or bool(g.get("projectile_only",false)): continue
		var r := float(g.get("radius",0))
		var area := PI*r*r
		match str(g.get("shape","disc")):
			"sector", "fan": area=.5*float(g.get("spread",TAU))*r*r
			"ring_gap": area=.5*(TAU-float(g.get("gap_width",0)))*(r*r-pow(float(g.get("inner_radius",0)),2))
			"line":
				var width := float(g.get("half_width",0))
				area=2*width*float(g.get("length",0))+PI*width*width
		result=maxf(result,area)
	return result
