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

func drive(battle: RefCounted) -> Vector2:
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
