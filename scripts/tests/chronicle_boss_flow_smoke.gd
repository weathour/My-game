extends SceneTree
## Transaction/lifecycle fixtures, deliberately not combat-balance evidence.
const CAMPAIGN := preload("res://scripts/campaign/campaign_service.gd")
const BATTLE := preload("res://scripts/battle/battle_session.gd")
const RESOLVER := preload("res://scripts/battle/combat_resolver.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
var checks := 0
var failures := 0

func _init() -> void: call_deferred("run")

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func claim(state: RefCounted) -> void:
	if state.data.pending.is_empty(): return
	for id in state.data.pending.candidates:
		if state.data.pending.selected.size() == state.data.pending.picks: break
		expect(state.select_card(id), "fixture selects only persisted candidate")
	expect(state.claim_reward(), "fixture commits reward")

func final_checkpoint() -> RefCounted:
	var state := CAMPAIGN.new()
	state.directory = "user://boss_flow/" + str(Time.get_ticks_usec())
	state.data.reward_seed = 781103
	expect(state.begin_campaign(), "transaction fixture begins campaign")
	for step in 70:
		var chosen: String = state.data.current
		for preferred in ["B04", "B08", "B13"]:
			if preferred in state.data.available: chosen = preferred
		for pair in [["B06", "S05"], ["B10", "S06"], ["B12", "S10"]]:
			if pair[0] in state.data.available: chosen = pair[1]
		expect(state.choose_node(chosen), "fixture selects legal node " + chosen)
		if chosen == "B18": return state
		if state.event_available(chosen):
			expect(state.resolve_event(), "fixture resolves story")
			claim(state)
			continue
		var request: Dictionary = state.start_battle()
		expect(not request.is_empty(), "fixture starts legal encounter")
		if request.is_empty(): return state
		# Only earlier battles are synthetic: this test isolates final-stage saves.
		var result := {"attempt_id":request.attempt_id, "outcome":"victory", "characters":request.characters,
			"card_elite":false, "equipment_elite":false, "elapsed":150.0, "kills":60, "fast_clear":false}
		expect(state.complete_battle(result), "fixture prior-stage transaction")
		if state.awaiting_battle_story(): expect(state.resolve_event(), "fixture post-battle story")
		claim(state)
	return state

func burst(boss: RefCounted, amount: float) -> void:
	RESOLVER.hit_enemy(boss, {"damage":amount, "slow":0.0, "duration":0.0, "direct":true})

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated save directory")
	if failures: quit(1); return
	var state := final_checkpoint()
	expect(state.data.current == "B18" and state.valid(state.data), "valid final-stage transaction checkpoint")
	var entry: Dictionary = state.data.duplicate(true)
	var battle := BATTLE.new(state.start_battle())
	expect(battle.director.elapsed == 0 and battle.enemies.size() == 1, "production B18 first state is immediately one boss")
	var boss: RefCounted = battle.enemies[0]
	expect(boss.definition_id == "B18" and boss.visual_id == "B18_human" and boss.form_index == 0, "production B18 enters human form")
	var original_hp: float = boss.hp
	for index in 4:
		var members_before := {}
		for id in battle.members: members_before[id] = battle.characters[id].snapshot()
		expect(not battle.choose_field(index), "all duel field interactions are unavailable")
		for id in battle.members: expect(battle.characters[id].snapshot() == members_before[id], "disabled field cannot grant resources")
		battle.position = SPACE.FIELD_POSITIONS[index]
		battle.tick(0, Vector2.ZERO)
	expect(battle.director.field == -1 and battle.enemies.size() == 1, "walking over former field positions cannot create mobs")
	burst(boss, boss.hp)
	battle.tick(1.0 / 60, Vector2.ZERO)
	expect(boss.form_index == 1 and battle.outcome.is_empty(), "phase-one defeat is not final victory")
	expect(not state.complete_battle(battle.result) and state.data.pending.is_empty(), "phase-one cannot produce campaign rewards")
	state.abandon_battle()
	expect(state.data == entry, "abandon during transformation restores exact entry")
	battle = BATTLE.new(state.start_battle())
	boss = battle.enemies[0]
	expect(boss.form_index == 0 and boss.hp == original_hp and boss.phase_damage_bank == 0, "retry resets both forms and pending damage")
	RESOLVER.hit_character(battle.characters.JIA, 100000, battle.equipment)
	battle.tick(0, Vector2.ZERO)
	expect(battle.outcome == "failed" and not state.complete_battle(battle.result), "defeat cannot commit final victory")
	state.abandon_battle()
	expect(state.data == entry, "defeat retry preserves entry resources and progression")
	battle = BATTLE.new(state.start_battle())
	boss = battle.enemies[0]
	burst(boss, boss.remaining_health_budget() + 100000)
	for frame in 120:
		if not battle.outcome.is_empty(): break
		battle.tick(1.0 / 60, Vector2.ZERO)
	expect(battle.outcome == "victory" and battle.result.kills == 0, "only final form creates pure-duel victory")
	expect(not battle.result.card_elite and not battle.result.equipment_elite, "duel cannot manufacture elite rewards")
	expect(state.complete_battle(battle.result), "real two-form terminal result commits once")
	expect(not state.complete_battle(battle.result), "duplicate final victory rejected")
	expect(state.data.current == "S14" and state.data.pending.is_empty(), "final reward still follows chapter story")
	expect(state.resolve_event(), "chapter story creates final reward")
	expect(state.data.pending.candidates.size() == 7 and state.data.pending.picks == 3 and not state.data.pending.extra, "new duel grants base seven choose three")
	var important := 0
	for id in state.data.pending.candidates:
		if state.characters[id].kind == "重要人物": important += 1
	expect(important >= 2, "chapter reward preserves important-candidate guarantee")
	# A concrete pre-update extra pick remains valid and is never redrafted.
	state.data.pending.extra = true
	state.data.pending.picks = 4
	var legacy: Dictionary = state.data.pending.duplicate(true)
	expect(state.valid(state.data) and state.save_slot("2"), "existing extra-pick reward remains a valid save")
	var loaded := CAMPAIGN.new()
	loaded.directory = state.directory
	expect(loaded.load_slot("2") and loaded.data.pending == legacy, "old seven-choose-four candidates survive unchanged")
	claim(loaded)
	var claimed: Dictionary = loaded.data.duplicate(true)
	expect(not loaded.claim_reward() and loaded.data == claimed, "old earned extra pick can be claimed only once")
	print("CHRONICLE_BOSS_FLOW_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
