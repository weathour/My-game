extends SceneTree
## 18 isolated real sessions: production enemy stats/AI/damage and ordinary inputs.
## Character levels are explicit fixtures, not evidence of a reachable campaign build.
## Reports defeats and timeouts as playtest results; never synthesizes a victory.
const C := preload("res://scripts/content/combat_catalog.gd")
const S := preload("res://scripts/content/stage_catalog.gd")
const B := preload("res://scripts/battle/battle_session.gd")
const TARGET := preload("res://scripts/battle/targeting.gd")
const G := preload("res://scripts/battle/enemy_geometry.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
var failures := 0
var checks := 0
var reports: Array = []
var only_stage := ""
var ranged_boss := false

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="): only_stage = arg.trim_prefix("--stage=")
		if arg == "--ranged-boss": ranged_boss = true
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func run() -> void:
	for index in S.ROUTE_ORDER.size():
		var id: String = S.ROUTE_ORDER[index]
		if not only_stage.is_empty() and id not in only_stage.split(","): continue
		var level := 1 + int(index * 0.6)
		var members: Array = ["JIA"] if id == "B01" else ["JIA", "F11", "N16"]
		var owned := {}
		for member in members: owned[member] = C.record(member, level)
		var battle := B.new({"attempt_id":"real-session-"+id,"members":members,"characters":owned,"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":"ember_seal"},"stage":S.stage(id),"seed":S.stage(id).seed})
		var seen := {}
		var actions := {}
		var warning_frames := 0
		var elapsed := 0.0
		for frame in 21600:
			if not battle.outcome.is_empty(): break
			if ranged_boss and battle.director.boss_spawned and battle.active != 1 and not battle.characters.F11.dead: battle.request_switch(1 - battle.active)
			var movement := drive(battle)
			if frame % 30 == 0: battle.request_skill(0); battle.request_skill(1)
			if battle.current().hp < battle.current().stats.hp * .25:
				for slot in members.size():
					var candidate: RefCounted = battle.characters[members[slot]]
					if not candidate.dead and candidate.hp > candidate.stats.hp * .55: battle.request_switch(slot - battle.active); break
			battle.tick(1.0/60.0, movement)
			elapsed += 1.0/60.0
			for enemy in battle.enemies:
				seen[enemy.definition_id] = true
				if enemy.windup > 0: actions[enemy.definition_id+":"+enemy.attack] = true
			warning_frames += int(not battle.telegraphs.is_empty())
			if frame % 300 == 0:
				expect(is_finite(battle.position.x) and is_finite(battle.current().hp), id + " finite runtime state")
			expect(battle.enemies.size() <= S.stage(id).enemy_cap + 12, id + " bounded entity population")
		var remaining := {}
		for enemy in battle.enemies:
			if enemy.rank in ["boss","object"]: remaining[enemy.definition_id] = {"hp":snappedf(enemy.hp,.1),"distance":snappedf(enemy.position.distance_to(battle.position),.1)}
		var report := {"remaining":remaining,"strategy":"ranged_on_boss" if ranged_boss else "approach_and_dodge","stage":id,"fixture_level":level,"members":members,"outcome":battle.outcome if not battle.outcome.is_empty() else "timeout","seconds":snappedf(elapsed,.1),"boss_spawned":battle.director.boss_spawned,"kills":battle.director.kills,"jia_hp":snappedf(battle.characters.JIA.hp,.1),"seen":seen.keys(),"actions":actions.keys(),"warning_frames":warning_frames}
		reports.append(report)
		print("ENEMY_REAL_SESSION ",JSON.stringify(report))
		expect(not seen.is_empty() and warning_frames > 0, id + " real AI appeared and warned")
		expect(battle.director.boss_spawned, id + " fixture reached authored boss")
		if battle.outcome == "victory": expect(battle.result.outcome == "victory" and battle.result.attempt_id == "real-session-"+id, id + " authentic terminal result")
		await process_frame
	var file := FileAccess.open("/tmp/baimen-enemy-real-sessions" + ("-"+only_stage if not only_stage.is_empty() else "") + ("-ranged" if ranged_boss else "") + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(reports,"  "))
	print("CHRONICLE_ENEMY_SESSIONS_SMOKE ","PASS" if failures == 0 else "FAIL"," checks=",checks," failures=",failures," sessions=",reports.size())
	quit(0 if failures == 0 else 1)

# Persistent plans use only warnings already visible this frame. The plan holds a
# reachable safe point until that warning ends, then returns to attack range.
var driver_plans: Dictionary = {}
const DRIVER_REVISION := "visible_goal_v2"

func drive(battle: RefCounted) -> Vector2:
	if str(battle.director.config.get("encounter_mode","")) != "boss_duel": return _drive_local_candidates(battle)
	return _drive_visible_warnings(battle)

func _drive_visible_warnings(battle: RefCounted) -> Vector2:
	var target: RefCounted = TARGET.nearest(battle.enemies,battle.position,4000)
	var objective: Vector2 = battle.position
	if target != null:
		var ranged: bool = C.definition(battle.current().id).basic.reach > 300
		var wanted := 245.0 if ranged else 64.0
		objective = target.position + (battle.position - target.position).normalized() * wanted
	elif not battle.gems.is_empty(): objective = battle.gems[0].position
	var threats: Array = []
	var active_owners := {}
	for enemy in battle.enemies:
		if enemy.active_remaining > 0: active_owners[enemy.id] = true
	for warning in battle.telegraphs:
		if float(warning.get("damage",1)) <= 0: continue
		var threat: Dictionary = warning.duplicate()
		if active_owners.has(int(threat.get("owner_id",-1))): threat.phase = "active"
		threats.append(threat)
	for hazard in battle.hazards:
		if hazard.phase == "active" and str(hazard.get("kind","")) != "slow_strip": threats.append(hazard)
	var speed: float = battle.current().stats.move * (1 - battle.enemy_slow) * (1.25 if battle.current().haste > 0 else 1.0)
	var plan: Dictionary = driver_plans.get(battle.attempt_id,{"signature":"","goal":battle.position,"decisions":[]})
	if threats.is_empty():
		plan.signature = ""
		driver_plans[battle.attempt_id] = plan
		return (objective - battle.position).normalized() if objective.distance_to(battle.position) > 8 else Vector2.ZERO
	var ids: Array[String] = []
	var deadline := 2.0
	for threat in threats:
		ids.append("%s:%s:%s" % [threat.get("owner_id",-1),threat.get("action_serial",-1),threat.get("phase","tell")])
		deadline = minf(deadline,maxf(0.1,float(threat.get("remaining",0.5))))
	ids.sort()
	var signature := ",".join(ids)
	if plan.signature == signature and _visible_path_risk(battle.position,plan.goal,speed,threats) < 1:
		return (plan.goal - battle.position).normalized() if plan.goal.distance_to(battle.position) > 8 else Vector2.ZERO
	var candidates: Array[Vector2] = [battle.position,SPACE.clamp_point(objective,SPACE.PLAYER_MARGIN)]
	var travel := maxf(12,speed * maxf(0.05,deadline - 0.10))
	for ring in [0.25,0.5,0.75,1.0]:
		for index in 32:
			candidates.append(SPACE.clamp_point(battle.position + Vector2.RIGHT.rotated(index * TAU / 32) * travel * float(ring),SPACE.PLAYER_MARGIN))
	var best: Vector2 = battle.position
	var best_risk := INF
	var best_score := INF
	for point in candidates:
		var risk := _visible_path_risk(battle.position,point,speed,threats)
		var score: float = risk * 100000 + point.distance_to(battle.position) + point.distance_to(objective) * 0.15
		if score < best_score: best = point; best_score = score; best_risk = risk
	plan.signature = signature; plan.goal = best
	plan.decisions.append({"seconds":battle.director.elapsed,"from":battle.position,"goal":best,"speed":speed,"visible_deadline":deadline,"risk":best_risk,"warnings":threats.duplicate(true)})
	driver_plans[battle.attempt_id] = plan
	return (best-battle.position).normalized() if best.distance_to(battle.position) > 8 else Vector2.ZERO

func _visible_path_risk(start: Vector2, goal: Vector2, speed: float, threats: Array) -> float:
	var distance := start.distance_to(goal)
	var direction := (goal-start).normalized()
	var risk := 0.0
	for threat in threats:
		var remaining := maxf(0,float(threat.get("remaining",0)))
		if str(threat.get("phase","tell")) == "tell":
			var at_release := start + direction * minf(distance,speed * maxf(0,remaining - 1.0/60.0))
			if G.contains(threat,at_release,28): risk += 1
		else:
			# Active hazards must be avoided along the route, not only at its end.
			for sample in range(1,9):
				var time: float = minf(distance / maxf(1,speed),remaining) * sample / 8.0
				if G.contains(threat,start + direction * minf(distance,speed*time),24): risk += 0.125
	return risk

func _drive_local_candidates(battle: RefCounted) -> Vector2:
	var target: RefCounted = TARGET.nearest(battle.enemies,battle.position,4000)
	var objective: Vector2 = battle.position
	if target != null:
		var ranged: bool = C.definition(battle.current().id).basic.reach > 300
		var wanted := 245.0 if ranged else 64.0
		objective = target.position + (battle.position - target.position).normalized() * wanted
	elif not battle.gems.is_empty(): objective = battle.gems[0].position
	var desired: Vector2 = (objective - battle.position).normalized()
	var best: Vector2 = desired
	var best_score := -INF
	for index in 17:
		var direction := Vector2.ZERO if index == 16 else Vector2.RIGHT.rotated(index * TAU / 16)
		var point: Vector2 = SPACE.clamp_point(battle.position + direction * 100.0, SPACE.PLAYER_MARGIN)
		var score: float = -point.distance_to(objective) * .015
		for warning in battle.telegraphs:
			if G.contains(warning, point): score -= 30.0
		for hazard in battle.hazards:
			if G.contains(hazard, point): score -= 30.0
		for projectile in battle.projectiles:
			if not projectile.get("hostile",false): continue
			var end: Vector2 = projectile.position + projectile.velocity * .45
			if Geometry2D.get_closest_point_to_segment(point,projectile.position,end).distance_to(point) < 30: score -= 10.0
		if point.distance_to(battle.position + direction * 100.0) > 5: score -= 10.0
		if score > best_score: best_score = score; best = direction
	return best

# Read-only telemetry for reproducible simulated play. HP/MP snapshots are actual
# runtime values; absent production attribution is reported rather than invented.
func begin_metrics(battle: RefCounted) -> Dictionary:
	var entry := {}
	for id in battle.members: entry[id] = battle.characters[id].snapshot()
	return {"entry":entry,"phase_marks":[],"last_phase":"","casts":{},"paid_mp":{},"shield_spent":{},"shield_gain_exact":{},"shield_observed_gain_lower_bound":{},"shield_absorbed_lower_bound":{},"last_live_shields":{},"shield_cast_events":[],"previous_shield":{},"hurt_total":{},"hurt_events":[],"damage_taken_events":[],"mechanics":{},"boss_damage_by_source":{},"boss_damage_by_ability":{},"boss_support_damage":0.0,"damage_by_source":{},"damage_by_ability":{},"support_damage":0.0,"damage_attribution_available":false,"phase_damage_attribution":{},"boss_spawn_seconds":-1.0,"max_hostiles":0,"boss_remaining":{},"seen_boss_actions":{},"active_seconds":{},"mp_observed_recovery":{},"previous_mp":{}}

func observe_metrics(battle: RefCounted, metric: Dictionary) -> void:
	var now: float = battle.director.elapsed
	metric.max_hostiles = maxi(metric.max_hostiles, battle.enemies.size())
	metric.active_seconds[battle.current().id] = float(metric.active_seconds.get(battle.current().id, 0)) + 1.0/60.0
	for id in battle.members:
		var mp: float = battle.characters[id].mp
		if metric.previous_mp.has(id) and mp > float(metric.previous_mp[id]): metric.mp_observed_recovery[id] = float(metric.mp_observed_recovery.get(id,0)) + mp - float(metric.previous_mp[id])
		metric.previous_mp[id] = mp
	for enemy in battle.enemies:
		if enemy.rank != "boss" or enemy.hp_owner != null: continue
		if metric.boss_spawn_seconds < 0: metric.boss_spawn_seconds = now
		var phase := "%s:%d:%s" % [enemy.definition_id, enemy.form_index, "transition" if enemy.transition_remaining > 0 else "observation" if enemy.observation_remaining > 0 else "combat"]
		if phase != metric.last_phase:
			var resources := {}
			for member in battle.members: resources[member] = battle.characters[member].snapshot()
			metric.phase_marks.append({"seconds":now,"phase":phase,"hp":enemy.hp,"bank":enemy.phase_damage_bank,"form_name":enemy.form_name,"resources":resources,"active":battle.current().id,"player_position":battle.position,"shields":_current_shields(battle)})
			metric.last_phase = phase
		metric.boss_remaining = {"definition":enemy.definition_id,"phase":enemy.form_index,"hp":enemy.hp,"bank":enemy.phase_damage_bank,"position":enemy.position,"player_distance":enemy.position.distance_to(battle.position)}
		if not enemy.attack.is_empty(): metric.seen_boss_actions["%d:%s" % [enemy.form_index, enemy.attack]] = true
	var spent_this_frame := {}
	for event in battle.events:
		match str(event.get("kind", "")):
			"cast":
				var key := str(event.id)+":"+str(event.ability)+":"+("front" if event.direct else "support")
				metric.casts[key] = int(metric.casts.get(key,0)) + 1
				metric.paid_mp[event.id] = float(metric.paid_mp.get(event.id,0)) + float(event.get("paid",0))
				metric.shield_spent[event.id] = float(metric.shield_spent.get(event.id,0)) + float(event.get("shield_spent",0))
				spent_this_frame[event.id] = float(spent_this_frame.get(event.id,0)) + float(event.get("shield_spent",0))
				if str(event.ability) in ["physician_heal","physician_ward","bandit_thrust"]:
					var cast_record: Dictionary = event.duplicate(true)
					cast_record.shield_before = metric.previous_shield.duplicate()
					cast_record.shield_after = {}
					for member in battle.members: cast_record.shield_after[member] = battle.characters[member].shield
					metric.shield_cast_events.append(cast_record)
			"hurt":
				metric.hurt_total[event.id] = float(metric.hurt_total.get(event.id,0)) + float(event.amount)
				var record: Dictionary = event.duplicate(true)
				record.seconds = now; record.position = battle.position; record.phase = metric.last_phase
				metric.hurt_events.append(record)
			"shield_gain":
				var id := str(event.get("id","unknown"))
				metric.shield_gain_exact[id] = float(metric.shield_gain_exact.get(id,0)) + float(event.get("amount",0))
			"damage_taken":
				metric.damage_taken_events.append(event.duplicate(true))
			"mechanic":
				var key := str(event.get("id",""))+":"+str(event.get("mechanic",""))
				metric.mechanics[key] = int(metric.mechanics.get(key,0)) + 1
			"damage", "damage_dealt":
				metric.damage_attribution_available = true
				var source := str(event.get("source",event.get("id","unknown")))
				var ability := str(event.get("ability","unknown"))
				var amount := float(event.get("amount",0))
				metric.damage_by_source[source] = float(metric.damage_by_source.get(source,0)) + amount
				metric.damage_by_ability[ability] = float(metric.damage_by_ability.get(ability,0)) + amount
				var phase_key := str(event.get("definition_id",""))+":"+str(event.get("phase",metric.last_phase))
				metric.phase_damage_attribution[phase_key] = float(metric.phase_damage_attribution.get(phase_key,0)) + amount
				if not bool(event.get("direct",true)): metric.support_damage += amount
				if str(event.get("definition_id", "")) == str(battle.director.config.get("boss_definition", "")):
					metric.boss_damage_by_source[source] = float(metric.boss_damage_by_source.get(source,0)) + amount
					metric.boss_damage_by_ability[ability] = float(metric.boss_damage_by_ability.get(ability,0)) + amount
					if not bool(event.get("direct",true)): metric.boss_support_damage += amount

	for id in battle.members:
		var current_shield: float = battle.characters[id].shield
		var gained := maxf(0,current_shield - float(metric.previous_shield.get(id,0)) + float(spent_this_frame.get(id,0)))
		metric.shield_observed_gain_lower_bound[id] = float(metric.shield_observed_gain_lower_bound.get(id,0)) + gained
		if battle.outcome.is_empty():
			var absorbed := maxf(0,float(metric.previous_shield.get(id,0)) - current_shield - float(spent_this_frame.get(id,0)))
			metric.shield_absorbed_lower_bound[id] = float(metric.shield_absorbed_lower_bound.get(id,0)) + absorbed
			metric.last_live_shields[id] = current_shield
		metric.previous_shield[id] = current_shield

func end_metrics(battle: RefCounted, metric: Dictionary) -> Dictionary:
	var result: Dictionary = metric.duplicate(true)
	result.erase("previous_mp")
	result.erase("previous_shield")
	result.exit = {}
	for id in battle.members: result.exit[id] = battle.characters[id].snapshot()
	result.resource_balance = {}
	for id in battle.members:
		var paid: float = float(result.paid_mp.get(id,0))
		var hurt: float = float(result.hurt_total.get(id,0))
		result.resource_balance[id] = {"paid_mp":paid,"received_hp_damage":hurt,"net_mp_restored_including_level_growth":float(result.exit[id].mp)-float(result.entry[id].mp)+paid,"net_hp_restored_including_level_growth":float(result.exit[id].hp)-float(result.entry[id].hp)+hurt}
	result.outcome = battle.outcome if not battle.outcome.is_empty() else "timeout"
	result.elapsed = battle.director.elapsed
	result.phase_seconds = {}
	for index in result.phase_marks.size():
		var mark: Dictionary = result.phase_marks[index]
		var until: float = float(result.phase_marks[index+1].seconds) if index+1 < result.phase_marks.size() else battle.director.elapsed
		result.phase_seconds[mark.phase] = until - float(mark.seconds)
	result.outcome_reason = "authentic_victory" if battle.outcome == "victory" else "protagonist_dead" if battle.characters.JIA.dead else "simulation_time_limit"
	if battle.outcome == "victory": result.boss_remaining = {}
	return result

func _current_shields(battle: RefCounted) -> Dictionary:
	var result := {}
	for id in battle.members: result[id] = battle.characters[id].shield
	return result
