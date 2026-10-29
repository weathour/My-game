extends SceneTree
## Data/topology and campaign transaction fixtures. This does not simulate combat.
const E := preload("res://scripts/content/enemy_catalog.gd")
const S := preload("res://scripts/content/stage_catalog.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const CAMPAIGN := preload("res://scripts/campaign/campaign_service.gd")
var checks := 0
var failures := 0
var paths: Array = []
var route := {}

func _init() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated storage")
	if failures: quit(1); return
	data_contract()
	for node in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/route.json")): route[node.id] = node
	walk("S01", [])
	expect(paths.size() == 64, "unchanged route has 64 complete legal paths")
	var combat_counts: Array = []
	for path in paths:
		var families := {}
		var battles := 0
		for id in path:
			if id.begins_with("B"):
				battles += 1
				expect(not C.stage(id).is_empty(), "reachable authored encounter " + id)
				families[E.definition(id).behavior_id] = true
		expect(families.size() >= 8 and families.size() <= 10, "each legal path sees 8–10 boss families")
		expect(battles >= 12 and battles <= 15, "each legal path has 12–15 battles")
		combat_counts.append(battles)
	# Pairwise branches plus both all-optional and all-bypass choices cover every node.
	for options in [["B04","B08","B13",true],["B05","B09","B14",false],["B04","B09","B14",true],["B05","B08","B13",true]]:
		transaction_path(options)
	print("CHRONICLE_ENEMY_CONTENT_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures, " paths=", paths.size(), " transaction_routes=4")
	quit(0 if failures == 0 else 1)

func data_contract() -> void:
	expect(E.validate().is_empty(), "enemy definition schema: " + str(E.validate()))
	expect(S.validate().is_empty(), "stage schema: " + str(S.validate()))
	expect(E.ordinary_ids().size() == 12 and E.elite_ids().size() == 6 and E.boss_ids().size() == 18, "12 ordinary, 6 rules, 18 boss identities")
	var families := {}
	for id in E.boss_ids(): families[E.definition(id).behavior_id] = true
	expect(families.size() == 10, "ten boss action families")
	for id in E.DEFINITIONS:
		var value := E.definition(id)
		expect(not value.description.is_empty() and not value.counterplay[0].is_empty() and not value.counterplay[1].is_empty(), "authored inspection text " + id)
		value.params["test_mutation"] = true
		expect(not E.definition(id).params.has("test_mutation"), "definition copy isolates mutation " + id)
	var introduced := {}
	var introduced_elites := {}
	var segments := [["B01","B02"],["B04","B05","B03","B06"],["B07","B08","B09","B10"],["B11","B12"],["B13","B14","B15","B16"],["B17","B18"]]
	var ordinary_totals := [2,6,9,11,12,12]
	var elite_totals := [1,2,4,5,6,6]
	for i in segments.size():
		for id in segments[i]:
			var stage := S.stage(id)
			for wave in stage.waves:
				for enemy_id in wave.cycle: introduced[enemy_id] = true
			for elite_id in stage.field_elites:
				if elite_id != "L00": introduced_elites[elite_id] = true
		expect(introduced.size() == ordinary_totals[i], "ordinary introduction cumulative segment " + str(i))
		expect(introduced_elites.size() == elite_totals[i], "elite introduction cumulative segment " + str(i))
	for id in E.derivative_ids():
		var value := E.definition(id)
		expect(value.xp == 0 and not value.params.counts_for_threshold, "derivative has no economic gate identity " + id)
	expect(E.definition("B10").params.partner_id == "B10_R", "B10 identifies its shared-health partner")
	expect(E.definition("B17").params.collaborators == ["M03_WAR","M04_WAR"], "B17 identifies two non-targetable apparitions")

func walk(id: String, path: Array) -> void:
	expect(id not in path, "acyclic route " + id)
	if id in path: return
	var next_path := path.duplicate()
	next_path.append(id)
	if route[id].next.is_empty(): paths.append(next_path); return
	for successor in route[id].next: walk(successor, next_path)

func claim(state: RefCounted) -> void:
	var pending: Dictionary = state.data.pending.duplicate(true)
	if pending.is_empty(): return
	expect(state.save_slot("1") and state.load_slot("1") and state.data.pending == pending, "concrete reward round-trip never rerolls")
	for id in pending.candidates:
		if state.data.pending.selected.size() == state.data.pending.picks: break
		expect(state.select_card(id), "select persisted reward " + id)
	expect(state.claim_reward(), "claim transaction reward")

func transaction_path(options: Array) -> void:
	var state := CAMPAIGN.new()
	state.directory = "user://enemy_chapter_transactions/" + str(options.hash()) + "_" + str(Time.get_ticks_usec())
	state.data.reward_seed = 781103
	expect(state.begin_campaign(), "begin transaction campaign")
	var visited: Array = []
	var carried := {}
	for step in 70:
		if state.data.finished: break
		var available: Array = state.data.available
		var chosen: String = state.data.current
		for preferred in options.slice(0,3):
			if preferred in available: chosen = preferred
		if available.has("B06"): chosen = "B06" if options[3] else "S05"
		if available.has("B10"): chosen = "B10" if options[3] else "S06"
		if available.has("B12"): chosen = "B12" if options[3] else "S10"
		expect(state.choose_node(chosen), "choose legal transaction node " + chosen)
		visited.append(chosen)
		if state.event_available(chosen):
			expect(state.resolve_event(), "resolve authored story/spring " + chosen)
			if chosen == "S02": expect(state.data.owned.has("F11"), "Emma joins after reward and her event")
			claim(state)
			continue
		if chosen == "B17":
			state.data.owned.JIA.hp = 111.0
			state.data.owned.JIA.mp = 7.0
			state.data.owned.JIA.cooldowns = {"carry_test":3.25}
			carried = state.data.owned.JIA.duplicate(true)
		if chosen == "B18": expect(state.data.owned.JIA == carried, "B17 resources and cooldowns reach B18 without a fountain")
		var request: Dictionary = state.start_battle()
		expect(not request.is_empty(), "authored campaign starts " + chosen)
		if request.is_empty(): return
		var result := {"attempt_id":request.attempt_id,"outcome":"victory","characters":request.characters,"card_elite":options[3],"equipment_elite":options[3],"elapsed":150.0,"kills":60,"fast_clear":false}
		expect(state.complete_battle(result), "public victory transaction fixture " + chosen)
		expect(not state.complete_battle(result), "duplicate victory rejected " + chosen)
		if chosen == "B01": expect(not state.data.owned.has("F11") and not state.data.pending.is_empty(), "B01 reward precedes Emma")
		if chosen in CAMPAIGN.POST_BATTLE_STORIES:
			expect(state.data.pending.is_empty() and state.awaiting_battle_story(), "post-battle story precedes reward " + chosen)
			for id in CAMPAIGN.UNLOCKS[chosen]: expect(id not in state.data.pool, "story qualification remains locked before scene " + id)
			expect(state.start_battle().is_empty(), "won story-gated battle cannot replay")
			expect(state.save_slot("2") and state.load_slot("2") and state.awaiting_battle_story(), "deferred story survives reload " + chosen)
			expect(state.resolve_event(), "resolve victory story " + chosen)
			for id in CAMPAIGN.UNLOCKS[chosen]: expect(id in state.data.pool and not state.data.owned.has(id), "story opens pool without gifting " + id)
		if chosen == "B18":
			expect(state.data.current == "S14" and state.data.pending.is_empty(), "final reward waits for chapter conclusion")
		claim(state)
		expect(state.valid(state.data), "transaction campaign save stays valid " + chosen)
	expect(state.data.finished and "S14" in state.data.completed and "B18" in state.data.completed, "representative full transaction route completes chapter")
	print("CAMPAIGN_TRANSACTION_FIXTURE ", JSON.stringify({"options":options,"visited":visited,"finished":state.data.finished}))
