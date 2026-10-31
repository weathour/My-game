extends "res://scripts/tests/chronicle_enemy_sessions_smoke.gd"
## Two bounded continuous production campaigns. All ownership, levels, resources,
## rewards and equipment come from the real campaign service and real battle results.
const CAMPAIGN := preload("res://scripts/campaign/campaign_service.gd")
var campaign_reports: Array = []
var campaign_seed := 781103
var campaign_routes: Array = ["short", "explore"]
var campaign_output := "/tmp/baimen-enemy-continuous-campaigns.json"

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated real campaign storage")
	if failures: quit(1); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): campaign_seed = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--route="): campaign_routes = Array(arg.trim_prefix("--route=").split(","))
		if arg.begins_with("--output="): campaign_output = arg.trim_prefix("--output=")
	for route_name in campaign_routes:
		expect(route_name in ["short","explore","shield"],"known real campaign strategy")
		if route_name in ["short","explore","shield"]: await real_campaign(route_name)
	var file := FileAccess.open(campaign_output,FileAccess.WRITE)
	file.store_string(JSON.stringify(campaign_reports,"  "))
	print("CHRONICLE_ENEMY_CAMPAIGN_SMOKE ","PASS" if failures == 0 else "FAIL"," checks=",checks," failures=",failures," routes=",campaign_reports.size())
	quit(0 if failures == 0 else 1)

func team(state: RefCounted, route_name: String) -> void:
	var priorities: Array = ["N16","N17","F11","N07","N01","N04"] if route_name == "short" else ["F11","N07","N16","F05","F06","F02","N13","N17","N01"]
	if route_name == "shield": priorities = ["F03","F07","N16","N17","F11","N07","N01"]
	var selected: Array = []
	for id in priorities:
		if state.data.owned.has(id) and not state.data.owned[id].dead: selected.append(id)
		if selected.size() == 2: break
	for slot in 2: expect(state.assign(selected[slot] if slot < selected.size() else "",slot),"legal lineup selection")
	for id in ["long_spear","iron_armor","frost_jade"]:
		if id in state.data.inventory: expect(state.equip(id),"equip actually earned " + id)

func reward(state: RefCounted, route_name: String, choices: Array) -> void:
	if state.data.pending.is_empty(): return
	var draft: Dictionary = state.data.pending.duplicate(true)
	var priorities: Array = ["N16","N17","F11","N07","N01","N04","F07","F08","F02","F04","F06","F09","F10"] if route_name == "short" else ["N07","F11","N16","F05","F08","F06","F02","N13","F10","F07","N01","N17"]
	if route_name == "shield": priorities = ["F03","F07","N16","N17","F11","N07","N01","N04","F08","F06","F09"]
	for id in draft.candidates:
		if id not in priorities: priorities.append(id)
	for id in priorities:
		if state.data.pending.selected.size() == state.data.pending.picks: break
		if id not in draft.candidates: continue
		# The short route deliberately retains a low-damage legal team and no
		# physician/rune mana support. Five choices always leave enough alternatives.
		if route_name == "short" and id in ["F03","N13"]: continue
		expect(state.select_card(id),"legal actual candidate " + id)
	choices.append({"node":draft.node,"candidates":draft.candidates,"selected":state.data.pending.selected.duplicate(),"picks":draft.picks})
	expect(state.claim_reward(),"commit earned card reward")

func capture_members(battle: RefCounted) -> Dictionary:
	var result := {}
	for id in battle.members: result[id] = battle.characters[id].snapshot()
	return result

func real_campaign(route_name: String) -> void:
	var short_path := route_name in ["short","shield"]
	var state := CAMPAIGN.new()
	state.directory = "user://enemy_continuous/"+route_name+"_"+str(Time.get_ticks_usec())
	state.data.reward_seed = campaign_seed
	expect(state.begin_campaign(),"begin real continuous " + route_name)
	var choices: Array = []
	var battles: Array = []
	var visited: Array = []
	var carry := {}
	var stopped := ""
	for step in 70:
		if state.data.finished: break
		var chosen: String = state.data.current
		var available: Array = state.data.available
		for preferred in (["B04","B08","B13"] if short_path else ["B05","B09","B14"]):
			if preferred in available: chosen = preferred
		if available.has("B06"): chosen = "S05" if short_path else "B06"
		if available.has("B10"): chosen = "S06" if short_path else "B10"
		if available.has("B12"): chosen = "S10" if short_path else "B12"
		expect(state.choose_node(chosen),"choose real campaign node " + chosen)
		visited.append(chosen)
		if state.event_available(chosen):
			expect(state.resolve_event(),"resolve real campaign story " + chosen)
			reward(state,route_name,choices)
			continue
		team(state,route_name)
		var checkpoint: Dictionary = state.data.duplicate(true)
		var request: Dictionary = state.start_battle()
		expect(not request.is_empty(),"start real continuous battle " + chosen)
		if request.is_empty(): stopped = "request_rejected"; break
		if chosen == "B01": expect(request.members == ["JIA"],"B01 is single protagonist before card reward and Emma")
		if chosen == "B18":
			for id in carry:
				expect(request.characters[id] == carry[id],"B17 carry remains exact through B18 request " + id)
		var battle := B.new(request)
		var entry := capture_members(battle)
		var metrics := begin_metrics(battle)
		var boss_entry := {}
		var spell_requests := 0
		var switch_requests := 0
		var elapsed := 0.0
		var field := 3 if "iron_armor" not in state.data.inventory or "long_spear" not in state.data.inventory or "frost_jade" not in state.data.inventory else (1 if short_path else 2)
		var level_events: Array = []
		for frame in 27000:
			if not battle.outcome.is_empty(): break
			var strategy_switch := shield_rotation(battle,frame) if route_name == "shield" else false
			if strategy_switch: switch_requests += 1
			var movement: Vector2 = drive(battle)
			if bool(battle.director.config.get("fields_enabled", true)) and battle.director.field == -1: movement = (SPACE.FIELD_POSITIONS[field] - battle.position).normalized()
			if frame % 30 == 0 and not strategy_switch:
				if route_name == "shield": spell_requests += shield_skills(battle,frame)
				else: battle.request_skill(0); battle.request_skill(1); spell_requests += 2
			if battle.current().hp < battle.current().stats.hp * .25:
				for slot in battle.members.size():
					var actor: RefCounted = battle.characters[battle.members[slot]]
					if not actor.dead and actor.hp > actor.stats.hp * .55:
						battle.request_switch(slot-battle.active); switch_requests += 1; break
			battle.tick(1.0/60.0,movement)
			observe_metrics(battle, metrics)
			elapsed += 1.0/60.0
			if boss_entry.is_empty() and battle.director.boss_spawned: boss_entry = {"seconds":battle.director.elapsed,"members":capture_members(battle)}
			for event in battle.events:
				if event.kind == "level": level_events.append({"seconds":battle.director.elapsed,"id":event.id,"level":event.level})
		var record := {"strategy":route_name,"driver_revision":DRIVER_REVISION if chosen == "B18" else "local_candidates_v1","request":request.duplicate(true) if chosen in ["B15","B16","B17","B18"] else {},"checkpoint":checkpoint if chosen in ["B15","B16","B17","B18"] else {},"metrics":end_metrics(battle, metrics),"result":battle.result.duplicate(true),"stage":chosen,"members":request.members,"equipment":request.equipment,"entry":entry,"boss_entry":boss_entry,"exit":capture_members(battle),"outcome":battle.outcome if not battle.outcome.is_empty() else "timeout","elapsed":snappedf(elapsed,.1),"kills":battle.director.kills,"field":battle.director.field,"card_elite":battle.director.card_elite,"equipment_elite":battle.director.equipment_elite,"level_events":level_events,"skill_requests":spell_requests,"switch_requests":switch_requests,"owned_count":state.data.owned.size(),"owned_bonus":C.owned_bonuses(state.data.owned)}
		battles.append(record)
		print("CONTINUOUS_REAL_BATTLE ",JSON.stringify({"route":route_name,"record":record}))
		if battle.outcome != "victory": stopped = record.outcome; state.abandon_battle(); break
		expect(state.complete_battle(battle.result),"commit authentic continuous result " + chosen)
		if state.awaiting_battle_story(): expect(state.resolve_event(),"post-victory qualification story " + chosen)
		reward(state,route_name,choices)
		record.reward_after = choices[-1].duplicate(true) if not choices.is_empty() else {}
		if chosen == "B18":
			expect(record.field == -1 and not record.card_elite and not record.equipment_elite,"B18 duel grants no fields or elites")
		if chosen == "B17": carry = state.data.owned.duplicate(true)
		expect(state.valid(state.data),"real continuous save remains valid")
		await process_frame
	for record in battles:
		if record.stage != "B18" or record.outcome != "victory": continue
		for choice in choices:
			if choice.node == "B18": record.reward_after = choice.duplicate(true)
		expect(record.reward_after.get("node", "") == "B18" and record.reward_after.picks == 3 and record.reward_after.candidates.size() == 7,"B18 post-S14 base seven choose three remains")
	if route_name == "shield":
		for record in battles:
			if record.stage not in ["B15","B16","B17","B18"]: continue
			expect(record.members == ["JIA","F03","F07"],"shield strategy actually owns and fields both core members")
			expect(record.entry.F03.level > C.entry_level("F03") and record.entry.F07.level > C.entry_level("F07"),"shield members actually gained campaign levels")
			expect(float(record.metrics.shield_spent.get("F07",0)) >= 30,"mature route actually pays a full shield conversion budget")
			expect(float(record.metrics.paid_mp.get("F03",0)) > 0,"shield generation pays real physician MP")
	var summary := {"route":route_name,"reward_seed":campaign_seed,"finished":state.data.finished,"stopped":stopped,"visited":visited,"battles":battles,"reward_choices":choices,"final_owned":state.data.owned,"final_inventory":state.data.inventory,"expected_battles":12 if short_path else 15,"injected_owned_or_resources":false}
	campaign_reports.append(summary)
	print("CONTINUOUS_CAMPAIGN_SUMMARY ",JSON.stringify({"route":route_name,"finished":summary.finished,"stopped":stopped,"battles":battles.size(),"expected":summary.expected_battles,"reward_seed":campaign_seed}))
	expect(summary.finished and battles.size() == summary.expected_battles,"complete bounded real continuous campaign " + route_name)

# A normal three-person rotation: F03's paid party heal/ward provides shields,
# F07 spends her own shield on thrust, then JIA takes the remaining attack window.
# The cycle is fixed input timing; no future enemy action or resource injection.
func shield_rotation(battle: RefCounted, frame: int) -> bool:
	if frame % 30 != 0: return false
	var desired := "JIA"
	var part := frame % 720
	if part < 90 and battle.characters.has("F03"): desired = "F03"
	elif part < 390 and battle.characters.has("F07"): desired = "F07"
	var actor: RefCounted = battle.characters[desired]
	if actor.dead or actor.hp < actor.stats.hp * 0.35: desired = "JIA"
	var slot: int = battle.members.find(desired)
	if slot < 0 or slot == battle.active: return false
	battle.request_switch(1 if posmod(slot-battle.active,battle.members.size()) == 1 else -1)
	return true

func shield_skills(battle: RefCounted, frame: int) -> int:
	if battle.current().id == "F03":
		battle.request_skill(0)
		# A ward every third cycle leaves an ordinary mana budget for party heal.
		if int(frame / 720) % 3 == 0: battle.request_skill(1); return 2
		return 1
	if battle.current().id == "F07":
		var target: RefCounted = TARGET.nearest(battle.enemies,battle.position,330)
		if battle.current().shield > 0 and target != null: battle.request_skill(1); return 1
		return 0
	battle.request_skill(0); battle.request_skill(1)
	return 2
