extends "res://scripts/tests/chronicle_enemy_sessions_smoke.gd"
## Two bounded continuous production campaigns. All ownership, levels, resources,
## rewards and equipment come from the real campaign service and real battle results.
const CAMPAIGN := preload("res://scripts/campaign/campaign_service.gd")
var campaign_reports: Array = []
var campaign_seed := 781103

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated real campaign storage")
	if failures: quit(1); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): campaign_seed = int(arg.trim_prefix("--seed="))
	for route_name in ["short", "explore"]: await real_campaign(route_name)
	var file := FileAccess.open("/tmp/baimen-enemy-continuous-campaigns.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(campaign_reports,"  "))
	print("CHRONICLE_ENEMY_CAMPAIGN_SMOKE ","PASS" if failures == 0 else "FAIL"," checks=",checks," failures=",failures," routes=",campaign_reports.size())
	quit(0 if failures == 0 else 1)

func team(state: RefCounted, route_name: String) -> void:
	var priorities: Array = ["N16","N17","F11","N07","N01","N04"] if route_name == "short" else ["F11","N07","N16","F05","F06","F02","N13","N17","N01"]
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
		for preferred in (["B04","B08","B13"] if route_name == "short" else ["B05","B09","B14"]):
			if preferred in available: chosen = preferred
		if available.has("B06"): chosen = "S05" if route_name == "short" else "B06"
		if available.has("B10"): chosen = "S06" if route_name == "short" else "B10"
		if available.has("B12"): chosen = "S10" if route_name == "short" else "B12"
		expect(state.choose_node(chosen),"choose real campaign node " + chosen)
		visited.append(chosen)
		if state.event_available(chosen):
			expect(state.resolve_event(),"resolve real campaign story " + chosen)
			reward(state,route_name,choices)
			continue
		team(state,route_name)
		var request: Dictionary = state.start_battle()
		expect(not request.is_empty(),"start real continuous battle " + chosen)
		if request.is_empty(): stopped = "request_rejected"; break
		if chosen == "B01": expect(request.members == ["JIA"],"B01 is single protagonist before card reward and Emma")
		if chosen == "B18":
			for id in carry:
				expect(request.characters[id] == carry[id],"B17 carry remains exact through B18 request " + id)
		var battle := B.new(request)
		var entry := capture_members(battle)
		var boss_entry := {}
		var spell_requests := 0
		var switch_requests := 0
		var elapsed := 0.0
		var field := 3 if "iron_armor" not in state.data.inventory or "long_spear" not in state.data.inventory or "frost_jade" not in state.data.inventory else (1 if route_name == "short" else 2)
		var level_events: Array = []
		for frame in 27000:
			if not battle.outcome.is_empty(): break
			var movement: Vector2 = drive(battle)
			if battle.director.field == -1: movement = (SPACE.FIELD_POSITIONS[field] - battle.position).normalized()
			if frame % 30 == 0:
				battle.request_skill(0); battle.request_skill(1); spell_requests += 2
			if battle.current().hp < battle.current().stats.hp * .25:
				for slot in battle.members.size():
					var actor: RefCounted = battle.characters[battle.members[slot]]
					if not actor.dead and actor.hp > actor.stats.hp * .55:
						battle.request_switch(slot-battle.active); switch_requests += 1; break
			battle.tick(1.0/60.0,movement)
			elapsed += 1.0/60.0
			if boss_entry.is_empty() and battle.director.boss_spawned: boss_entry = {"seconds":battle.director.elapsed,"members":capture_members(battle)}
			for event in battle.events:
				if event.kind == "level": level_events.append({"seconds":battle.director.elapsed,"id":event.id,"level":event.level})
		var record := {"stage":chosen,"members":request.members,"equipment":request.equipment,"entry":entry,"boss_entry":boss_entry,"exit":capture_members(battle),"outcome":battle.outcome if not battle.outcome.is_empty() else "timeout","elapsed":snappedf(elapsed,.1),"kills":battle.director.kills,"field":battle.director.field,"card_elite":battle.director.card_elite,"equipment_elite":battle.director.equipment_elite,"level_events":level_events,"skill_requests":spell_requests,"switch_requests":switch_requests,"owned_count":state.data.owned.size(),"owned_bonus":C.owned_bonuses(state.data.owned)}
		battles.append(record)
		print("CONTINUOUS_REAL_BATTLE ",JSON.stringify({"route":route_name,"record":record}))
		if battle.outcome != "victory": stopped = record.outcome; state.abandon_battle(); break
		expect(state.complete_battle(battle.result),"commit authentic continuous result " + chosen)
		if state.awaiting_battle_story(): expect(state.resolve_event(),"post-victory qualification story " + chosen)
		reward(state,route_name,choices)
		if chosen == "B17": carry = state.data.owned.duplicate(true)
		expect(state.valid(state.data),"real continuous save remains valid")
		await process_frame
	var summary := {"route":route_name,"reward_seed":campaign_seed,"finished":state.data.finished,"stopped":stopped,"visited":visited,"battles":battles,"reward_choices":choices,"final_owned":state.data.owned,"final_inventory":state.data.inventory,"expected_battles":12 if route_name == "short" else 15,"injected_owned_or_resources":false}
	campaign_reports.append(summary)
	print("CONTINUOUS_CAMPAIGN_SUMMARY ",JSON.stringify({"route":route_name,"finished":summary.finished,"stopped":stopped,"battles":battles.size(),"expected":summary.expected_battles,"reward_seed":campaign_seed}))
	expect(summary.finished and battles.size() == summary.expected_battles,"complete bounded real continuous campaign " + route_name)
