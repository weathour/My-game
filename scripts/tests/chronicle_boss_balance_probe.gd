extends "res://scripts/tests/chronicle_enemy_campaign_smoke.gd"
## Branches only genuine saved pre-battle checkpoints, preserving every resource.
## Party/equipment assignments use CampaignService; all victories are simulated.
## These are reproducible simulated samples, not human balance acceptance.
var source_path := "/tmp/baimen-enemy-continuous-campaigns.json"
var output_path := "/tmp/baimen-boss-balance.json"
var branch_reports: Array = []
var original_lineup := false
var build_filter := ""
var route_filter := ""
var movement_policy := "read_telegraphs"
const BUILDS := [
	{"id":"ordinary_heal","party":["N16","N17"],"front":"JIA","equipment":["plain_blade","cloth_armor","ember_seal"]},
	{"id":"followup","party":["N07","N01"],"front":"JIA","equipment":["long_spear","iron_armor","ember_seal"]},
	{"id":"echo","party":["F11","N13"],"front":"F11","equipment":["long_spear","iron_armor","frost_jade"]},
	{"id":"shield_conversion","party":["F07","N16"],"front":"F07","equipment":["long_spear","iron_armor","ember_seal"]},
	{"id":"curse","party":["F05","N14"],"front":"F05","equipment":["long_spear","iron_armor","frost_jade"]},
	{"id":"ammo_followup","party":["F06","N07"],"front":"JIA","equipment":["long_spear","iron_armor","ember_seal"]},
	{"id":"strong_echo_heal","party":["F11","N16"],"front":"F11","equipment":["long_spear","iron_armor","frost_jade"]},
	{"id":"plain_protagonist","party":["",""],"front":"JIA","equipment":["plain_blade","cloth_armor","ember_seal"]}
]

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"),"isolated checkpoint branches")
	for arg in OS.get_cmdline_user_args():
		if arg == "--original-lineup": original_lineup = true
		if arg.begins_with("--build="): build_filter = arg.trim_prefix("--build=")
		if arg.begins_with("--route="): route_filter = arg.trim_prefix("--route=")
		if arg.begins_with("--movement="): movement_policy = arg.trim_prefix("--movement=")
		if arg.begins_with("--source="): source_path = arg.trim_prefix("--source=")
		if arg.begins_with("--output="): output_path = arg.trim_prefix("--output=")
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	expect(source is Array,"genuine campaign report exists")
	if failures: quit(1); return
	for route in source:
		if not route_filter.is_empty() and route.route != route_filter: continue
		for record in route.battles:
			if record.stage not in ["B15","B16","B17","B18"] or record.get("checkpoint",{}).is_empty(): continue
			if not only_stage.is_empty() and record.stage not in only_stage.split(","): continue
			var sample_builds: Array = [{"id":"route_original","party":record.checkpoint.party.duplicate(),"front":"JIA","equipment":record.checkpoint.equipped.values()}] if original_lineup else BUILDS
			for build in sample_builds:
				if not build_filter.is_empty() and build.id not in build_filter.split(","): continue
				var missing: Array = []
				for id in build.party:
					if id != "" and (not record.checkpoint.owned.has(id) or record.checkpoint.owned[id].dead): missing.append(id)
				if not missing.is_empty():
					branch_reports.append({"route":route.route,"stage":record.stage,"build":build.id,"skipped":true,"reason":"not_actually_owned_alive","missing":missing})
					continue
				await branch(route.route, record, build)
	var file := FileAccess.open(output_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"source":source_path,"boundary":"Reproducible simulated checkpoint branches; no human balance acceptance; no injected owned characters, levels or resources.","reports":branch_reports},"  "))
	print("CHRONICLE_BOSS_BALANCE_PROBE ","PASS" if failures == 0 else "FAIL"," checks=",checks," failures=",failures," branches=",branch_reports.size())
	quit(0 if failures == 0 else 1)

func branch(route_name: String, original: Dictionary, build: Dictionary) -> void:
	var state := CAMPAIGN.new()
	state.directory = "user://boss_branch/"+route_name+"_"+original.stage+"_"+build.id
	state.data = original.checkpoint.duplicate(true)
	expect(state.valid(state.data),"real checkpoint shape valid")
	for slot in 2: expect(state.assign(build.party[slot],slot),"assign only actual owned build member")
	var unavailable_equipment: Array = []
	for id in build.equipment:
		if id in state.data.inventory: expect(state.equip(id),"equip actual inventory")
		else: unavailable_equipment.append(id)
	var request: Dictionary = state.start_battle()
	expect(not request.is_empty(),"start authentic checkpoint branch")
	if request.is_empty(): return
	for id in request.characters: expect(request.characters[id] == original.checkpoint.owned[id],"branch preserves every owned record "+id)
	var battle := B.new(request)
	var metric := begin_metrics(battle)
	var skill_requests := 0
	var switch_requests := 0
	for frame in 27000:
		if not battle.outcome.is_empty(): break
		# Normal readable movement and skill inputs. Echo builds deliberately rotate
		# after a paid record cast so another actor can actually trigger the record.
		if build.front != "JIA" and battle.characters.has(build.front) and not battle.characters[build.front].dead and battle.characters[build.front].hp > battle.characters[build.front].stats.hp * .35:
			var preferred: int = battle.members.find(build.front)
			if build.id in ["echo","strong_echo_heal"] and int(frame / 360) % 2 == 1: preferred = 0
			if battle.active != preferred and frame % 60 == 0:
				battle.request_switch(preferred - battle.active); switch_requests += 1
		var movement := blind_approach(battle) if movement_policy == "blind_approach" else Vector2.ZERO if movement_policy == "stationary" else drive(battle)
		if bool(battle.director.config.get("fields_enabled",true)) and battle.director.field == -1:
			movement = (SPACE.FIELD_POSITIONS[0] - battle.position).normalized()
		if frame % 30 == 0: battle.request_skill(0); battle.request_skill(1); skill_requests += 2
		if battle.current().hp < battle.current().stats.hp * .25:
			for slot in battle.members.size():
				var actor: RefCounted = battle.characters[battle.members[slot]]
				if not actor.dead and actor.hp > actor.stats.hp * .55:
					battle.request_switch(slot-battle.active); switch_requests += 1; break
		battle.tick(1.0/60.0,movement)
		observe_metrics(battle,metric)
	var report := {"result":battle.result.duplicate(true),"request":request.duplicate(true),"route":route_name,"stage":original.stage,"build":build.id,"movement_policy":movement_policy,"driver_revision":DRIVER_REVISION,"driver_decisions":driver_plans.get(battle.attempt_id,{}).get("decisions",[]).duplicate(true),"members":request.members,"equipment":request.equipment,"unavailable_equipment":unavailable_equipment,"entry_owned":request.characters,"metrics":end_metrics(battle,metric),"skill_requests":skill_requests,"switch_requests":switch_requests,"injected_owned_or_resources":false,"committed":false,"reward_after":{}}
	if battle.outcome == "victory":
		expect(state.complete_battle(battle.result),"commit real branch victory")
		report.committed = not state.in_battle
		if state.awaiting_battle_story(): expect(state.resolve_event(),"resolve real branch qualification story")
		if original.stage == "B18":
			expect(state.choose_node("S14") and state.resolve_event(),"resolve authored chapter-end story before reward")
		var choices: Array = []
		reward(state,route_name,choices)
		if not choices.is_empty(): report.reward_after = choices[-1]
		expect(state.valid(state.data),"branch save valid after real reward")
	else: state.abandon_battle()
	branch_reports.append(report)
	print("BOSS_BALANCE_BRANCH ",JSON.stringify({"route":route_name,"stage":original.stage,"build":build.id,"movement_policy":movement_policy,"driver_revision":DRIVER_REVISION,"driver_decisions":driver_plans.get(battle.attempt_id,{}).get("decisions",[]).duplicate(true),"outcome":report.metrics.outcome,"seconds":report.metrics.elapsed,"boss_remaining":report.metrics.boss_remaining,"hurt":report.metrics.hurt_total}))
	await process_frame

# Control comparison: ordinary pursuit only, no warning/hazard/projectile reads.
# Keep the baseline driver's preferred basic attack distance, without retreating.
func blind_approach(battle: RefCounted) -> Vector2:
	var target: RefCounted = TARGET.nearest(battle.enemies,battle.position,4000)
	if target == null: return Vector2.ZERO
	var ranged: bool = C.definition(battle.current().id).basic.reach > 300
	var wanted := 245.0 if ranged else 64.0
	return (target.position - battle.position).normalized() if target.position.distance_to(battle.position) > wanted + 5 else Vector2.ZERO
