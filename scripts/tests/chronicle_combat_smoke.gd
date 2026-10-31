extends SceneTree
## Behaviour contracts and real two-stage simulation; no demo victory controls.
const CAMPAIGN := preload("res://scripts/campaign/campaign_service.gd")
const BATTLE := preload("res://scripts/battle/battle_session.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const TARGET := preload("res://scripts/battle/targeting.gd")
const RESOLVER := preload("res://scripts/battle/combat_resolver.gd")
const REWARDS := preload("res://scripts/campaign/reward_rules.gd")
var failures := 0
var checks := 0

func _init() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func same_saved_state(actual: Variant, expected: Variant) -> bool:
	# JSON float parsing can differ by one ULP. Keep structure/order exact and
	# tolerate only sub-nanounit numeric drift, not a changed resource or cooldown.
	if actual is Dictionary and expected is Dictionary:
		if actual.size() != expected.size(): return false
		for key in expected:
			if not actual.has(key) or not same_saved_state(actual[key], expected[key]): return false
		return true
	if actual is Array and expected is Array:
		if actual.size() != expected.size(): return false
		for i in expected.size():
			if not same_saved_state(actual[i], expected[i]): return false
		return true
	if actual is float and expected is float: return absf(actual - expected) < 1e-10
	return actual == expected

func fixture(ids: Array = ["JIA", "F11", "N16"]) -> RefCounted:
	var records := {}
	for id in ids: records[id] = C.record(id)
	var stage := C.stage("B01")
	stage.boss_time = 1000.0
	stage.boss_kills = 1000
	stage.spawn_interval = 1000.0
	var b := BATTLE.new({"attempt_id":"fixture", "members":ids, "characters":records, "equipment":{"weapon":"plain_blade", "armor":"cloth_armor", "accessory":"ember_seal"}, "stage":stage, "seed":1})
	b.director.spawn_remaining = 1000
	return b

func run() -> void:
	resources_and_effects()
	stage_contracts()
	reward_contracts()
	campaign_lifecycle()
	var campaign := CAMPAIGN.new()
	campaign.directory = "user://chronicle_combat_tests/" + str(Time.get_ticks_usec())
	expect(campaign.begin_campaign() and campaign.resolve_event(), "new run starts alone at B01")
	var entry := campaign.data.duplicate(true)
	var request := campaign.start_battle()
	var failed_attempt := BATTLE.new(request)
	failed_attempt.grant_experience(160)
	failed_attempt.choose_field(3)
	campaign.abandon_battle()
	expect(campaign.data == entry, "failure rolls back XP, field and all attempt state")
	request = campaign.start_battle()
	var first := BATTLE.new(request)
	play(first)
	expect(first.outcome == "victory", "B01 wins through real attacks")
	if first.outcome != "victory": quit(1); return
	expect(campaign.complete_battle(first.result), "victory committed")
	expect(not campaign.complete_battle(first.result), "duplicate victory rejected")
	expect(campaign.data.current == "B01" and not campaign.data.pending.is_empty(), "first reward precedes Emma story")
	expect(not campaign.resolve_event() and not campaign.data.owned.has("F11") and "F11" not in campaign.data.pending.candidates, "Emma remains gated during first draft")
	expect(campaign.data.pending.candidates.size() == 5 and campaign.data.pending.picks == 2, "normal five choose two")
	var picks: Array = campaign.data.pending.candidates.duplicate()
	var first_pick: String = "N16" if "N16" in picks else str(picks[0])
	expect(campaign.select_card(first_pick), "persist selection")
	var saved := campaign.data.duplicate(true)
	var loaded := CAMPAIGN.new()
	loaded.directory = campaign.directory
	expect(loaded.load_slot("auto") and same_saved_state(loaded.data, saved), "pending candidates and selection restored unchanged")
	for id in picks:
		if id != first_pick and campaign.data.pending.selected.size() < 2: campaign.select_card(id)
	expect(campaign.claim_reward(), "claim first cards")
	var claimed := campaign.data.duplicate(true)
	expect(not campaign.claim_reward() and campaign.data == claimed, "claim idempotency")
	expect(campaign.data.current == "S02" and campaign.resolve_event(), "claimed first reward reaches Emma story")
	expect(campaign.data.owned.F11.level == 1 and campaign.data.owned.F11.xp == 0, "Emma does not inherit first-stage XP or consume a pick")
	var auxiliary: String = ""
	for id in campaign.data.owned:
		if id not in ["JIA", "F11"]: auxiliary = id; break
	expect(campaign.assign("F11", 0) and campaign.assign(auxiliary, 1), "configure both auxiliaries")
	# A separate unassigned reserve is a frozen record, even while equipped actors recover.
	var reserve_id: String = "N17" if auxiliary != "N17" else "N07"
	campaign.data.owned[reserve_id] = C.record(reserve_id)
	campaign.data.owned[reserve_id].mp = 2.0
	campaign.data.owned[reserve_id].cooldowns = {"reserve_test":9.0}
	var reserve: Dictionary = campaign.data.owned[reserve_id].duplicate(true)
	var second := BATTLE.new(campaign.start_battle())
	play(second)
	expect(second.outcome == "victory", "B02 wins with independent companions")
	expect(campaign.complete_battle(second.result), "second-stage result commits")
	expect(campaign.data.owned[reserve_id] == reserve, "unassigned reserve HP/MP/XP/CD frozen")
	expect(campaign.data.owned.F11.xp > 0 or campaign.data.owned.F11.level > 1, "configured Emma gains experience")
	expect(campaign.save_slot("1"), "manual checkpoint saved")
	var before_select := campaign.data.duplicate(true)
	campaign.select_card(campaign.data.pending.candidates[0])
	var restore := CAMPAIGN.new()
	restore.directory = campaign.directory
	expect(restore.load_slot("1") and same_saved_state(restore.data, before_select), "manual load is full rollback")
	var old_scope := before_select.duplicate(true)
	old_scope.scope = "ui_rehearsal"
	expect(not restore.valid(old_scope), "UI rehearsal saves rejected")
	var bad_hp := before_select.duplicate(true)
	bad_hp.owned.JIA.hp = 999999
	expect(not restore.valid(bad_hp), "invalid vitals rejected")
	# Write failure must preserve the pending draft and allow exact retry.
	var previous := campaign.data.duplicate(true)
	var real_dir := campaign.directory
	campaign.directory = "/proc/chronicle-combat-test-read-only"
	print("EXPECTED_FAULT_INJECTION: selection write rejected")
	expect(not campaign.select_card(campaign.data.pending.candidates[0]) and campaign.data == previous, "failed write rolls back selection")
	campaign.directory = real_dir
	# A malformed primary must not destroy the last known-good backup on recovery.
	var known_backup := campaign.read_slot("auto")
	expect(campaign.save_slot("auto"), "backup generation")
	var file := FileAccess.open(real_dir.path_join("auto.json"), FileAccess.WRITE)
	file.store_string("{}")
	file.close()
	expect(campaign.read_slot("auto") == known_backup, "backup recovers damaged primary")
	expect(campaign.save_slot("auto"), "recovered write")
	expect(same_saved_state(campaign.read_slot("auto"), campaign.data), "recovered state readable")
	print("CHRONICLE_COMBAT_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func resources_and_effects() -> void:
	var b := fixture()
	b.characters.F11.mp = 10
	b.characters.F11.cooldowns.emma_frost = 5.0
	b.request_switch(1)
	b.tick(0.1, Vector2.ZERO)
	expect(b.current().id == "F11" and b.characters.F11.mp < 12, "switch keeps independent mana")
	expect(is_equal_approx(b.characters.F11.cooldowns.emma_frost, 4.9), "switch does not reset cooldown")
	var health: float = b.current().hp
	RESOLVER.hit_character(b.current(), 20, b.equipment)
	expect(b.current().hp < health, "switch grants no invulnerability")
	b.set_paused(true)
	var paused: Dictionary = b.current().snapshot()
	b.tick(10, Vector2.ONE)
	expect(b.current().snapshot() == paused, "pause freezes resources")
	b.set_paused(false)
	# Projectile identity and enchant remain fixed after a foreground switch.
	b.characters.F11.mp = 100
	b.characters.F11.cooldowns.clear()
	b.enemies.append(b.director.spawn("melee", b.position + Vector2(300, 0)))
	b.tick(0.01, Vector2.ZERO)
	var projectile: Dictionary = b.projectiles[0]
	var attack: float = projectile.context.damage
	b.switch_cooldown = 0
	b.request_switch(-1)
	b.tick(0.01, Vector2.ZERO)
	expect(projectile.context.source == "F11" and projectile.context.damage == attack and projectile.context.enchant == "ember_seal", "launched attacks retain owner and enchant")
	# A living rear character cannot receive a direct enemy projectile.
	var rear_hp: float = b.characters.F11.hp
	b.projectiles.append({"position":b.position, "velocity":Vector2.ZERO, "life":1.0, "hostile":true, "damage":20.0, "source":1})
	b.tick(0.01, Vector2.ZERO)
	expect(b.characters.F11.hp == rear_hp, "direct damage only hits foreground")
	# Forced return bypasses shared switching cooldown; dead actors still receive XP.
	b.active = 1
	b.switch_cooldown = 10
	b.characters.F11.hurt_lock = 0
	b.characters.F11.hp = 1
	b.projectiles.append({"position":b.position, "velocity":Vector2.ZERO, "life":1.0, "hostile":true, "damage":999.0, "source":1})
	b.tick(0.01, Vector2.ZERO)
	expect(b.active == 0 and b.characters.F11.dead and b.outcome == "", "auxiliary death returns to living protagonist")
	var xp_before: float = b.characters.F11.xp
	b.grant_experience(9)
	expect(is_equal_approx(b.characters.F11.xp - xp_before, 3), "dead members retain equal XP share")
	b.grant_experience(120)
	expect(b.characters.F11.dead and b.characters.F11.hp == 0, "level-up never revives")
	expect(b.characters.JIA.hp == b.characters.JIA.stats.hp, "living level-up fully heals")
	var solo := fixture(["JIA"])
	solo.request_switch(1)
	solo.tick(0.1, Vector2.ZERO)
	expect(solo.switch_cooldown == 0, "empty auxiliary slots do not trigger cooldown")
	solo.grant_experience(9)
	expect(solo.current().xp == 9, "solo gets full XP")
	var pair := fixture(["JIA", "F11"])
	pair.grant_experience(9)
	expect(pair.characters.JIA.xp == 4.5 and pair.characters.F11.xp == 4.5, "two members split XP in half")
	var fractions := fixture()
	for i in 90: fractions.grant_experience(1)
	expect(fractions.characters.JIA.level == 2 and fractions.characters.JIA.xp == 0, "ninety thirds reach level threshold exactly")
	var mage := fixture(["JIA", "F11"])
	mage.active = 1
	mage.characters.F11.level = 2
	mage.characters.F11.mp = 12
	mage.enemies.append(mage.director.spawn("melee", mage.position + Vector2(300,0)))
	mage.tick(0.01, Vector2.ZERO)
	expect(mage.characters.F11.cooldowns.has("emma_ice") and mage.characters.F11.mp >= 12, "level-unlocked routine is automatic and costs no mana")
	var spear: Resource = C.basic("JIA", {"weapon":"long_spear"})
	expect(spear.kind != C.basic("JIA", {}).kind and C.basic("F11", {"weapon":"long_spear"}) == C.basic("F11", {}), "weapon form changes protagonist only")

func stage_contracts() -> void:
	var b := fixture()
	expect(b.choose_field(2) and not b.choose_field(0) and b.director.field == 2, "four fields mutually exclusive")
	var boss: RefCounted = b.director.spawn("boss", Vector2(40,40))
	boss.hp = 0
	boss.dead = true
	b.enemies.append(boss)
	b.tick(0.01, Vector2.ZERO)
	expect(b.outcome == "victory" and not b.result.card_elite, "boss ends stage, surviving extra elite forfeited")
	var result: Dictionary = b.result.duplicate(true)
	b.tick(100, Vector2.ZERO)
	expect(b.result == result, "terminal result immutable across further ticks")
	var simultaneous := fixture(["JIA"])
	var other: RefCounted = simultaneous.director.spawn("boss", Vector2(40,40))
	other.hp = 0; other.dead = true
	simultaneous.enemies.append(other)
	simultaneous.current().hp = 1
	simultaneous.projectiles.append({"position":simultaneous.position, "velocity":Vector2.ZERO, "life":1.0, "hostile":true, "damage":999.0, "source":1})
	simultaneous.tick(0.01, Vector2.ZERO)
	expect(simultaneous.outcome == "failed", "same batch protagonist death takes priority")
	var gate := fixture()
	gate.director.config.boss_time = 1
	gate.director.config.boss_kills = 1
	gate.director.kills = 1
	gate.tick(1, Vector2.ZERO)
	gate.tick(1, Vector2.ZERO)
	expect(gate.enemies.size() == 1 and gate.enemies[0].kind == "boss", "both boss gates fire once and stop ordinary spawns")
	var supply := fixture()
	supply.current().hp = 1
	supply.current().mp = 0
	expect(supply.choose_field(0) and supply.current().hp > 100 and supply.current().mp > 0, "supply changes actual resources")
	var study := fixture()
	study.choose_field(1)
	expect(study.characters.JIA.xp == 24 and study.characters.F11.xp == 0, "study field rewards only current actor")

func reward_contracts() -> void:
	var defs := {"a":{"kind":"重要人物"}, "b":{"kind":"重要人物"}, "c":{"kind":"军士"}, "d":{"kind":"军士"}, "e":{"kind":"军士"}, "f":{"kind":"军士"}, "g":{"kind":"军士"}, "h":{"kind":"军士"}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var draft := REWARDS.draft("B18", defs.keys(), defs, true, rng)
	expect(draft.candidates.size() == 7 and draft.picks == 4 and "a" in draft.candidates and "b" in draft.candidates, "chapter seven choose four with two important cards")
	var ordinary := REWARDS.draft("B02", defs.keys(), defs, true, rng)
	expect(ordinary.candidates.size() == 5 and ordinary.picks == 3, "card elite five choose three")
	expect(REWARDS.draft("B18", ["a","c","d","e","f","g","h"], defs, false, rng).is_empty(), "important guarantee never draws locked cards")
	var normal_final := REWARDS.draft("B18", defs.keys(), defs, false, rng)
	expect(normal_final.picks == 3, "chapter reward defaults to seven choose three")

func campaign_lifecycle() -> void:
	var state := CAMPAIGN.new()
	state.directory = "user://chronicle_lifecycle_tests/" + str(Time.get_ticks_usec())
	state.data.current = "B02"
	state.data.available = ["B02"]
	state.data.reward_seed = 781103
	for id in ["F11", "N16", "N17"]: state.data.owned[id] = C.record(id)
	state.data.pool.append("F11")
	state.assign("F11", 0)
	state.assign("N16", 1)
	var entry := state.data.duplicate(true)
	var request := state.start_battle()
	var records := {}
	for id in request.members: records[id] = request.characters[id].duplicate(true)
	records.F11.hp = 0.0
	records.F11.dead = true
	var result := {"attempt_id":request.attempt_id, "outcome":"victory", "characters":records}
	var wrong := result.duplicate(true)
	wrong.attempt_id = "previous-attempt"
	expect(not state.complete_battle(wrong) and state.data == entry, "foreign attempt result rejected")
	var real_directory := state.directory
	state.directory = "/proc/chronicle-combat-result-read-only"
	print("EXPECTED_FAULT_INJECTION: victory write rejected")
	expect(not state.complete_battle(result) and state.in_battle and state.data == entry, "failed victory save retains entry and retry authority")
	state.directory = real_directory
	expect(state.complete_battle(result), "same victory can retry successfully")
	expect(state.data.owned.F11.dead and state.data.party[0] == "", "dead auxiliary remains dead between stages")
	expect(not state.assign("F11", 0), "dead auxiliary cannot be assigned")
	expect(state.select_card("F11") and state.select_card("N16") and state.claim_reward(), "duplicate dead card claim")
	expect(state.data.owned.F11.level == 2 and state.data.owned.F11.dead and state.data.owned.F11.hp == 0, "duplicate levels but never revives dead actor")
	expect(state.data.owned.N16.level == 2 and state.data.owned.N16.hp == state.resource_max("N16", "hp"), "living duplicate upgrades and refills")
	state.data.current = "F01"
	state.data.available = ["F01"]
	state.data.owned.N17.hp = 10.0
	state.data.owned.N17.mp = 1.0
	state.data.owned.N17.cooldowns = {"reserve_test":7.0}
	expect(state.resolve_event() and not state.data.owned.F11.dead, "spring revives defeated auxiliary")
	expect(state.data.owned.N17.hp == state.resource_max("N17", "hp") and state.data.owned.N17.mp == state.resource_max("N17", "mp"), "spring heals unassigned reserves")
	expect(state.data.owned.N17.cooldowns.reserve_test == 7, "spring does not silently refresh skill cooldowns")
	expect(state.battle_available("B04") and state.battle_available("B07") and state.battle_available("B18"), "all completed chapter encounters are playable")

func play(b: RefCounted) -> void:
	var started := Time.get_ticks_usec()
	for frame in 18000:
		if not b.outcome.is_empty(): break
		var target := TARGET.nearest(b.enemies, b.position, 2000)
		var movement := Vector2.ZERO
		if target != null:
			var distance: float = b.position.distance_to(target.position)
			if distance > 75: movement = (target.position - b.position).normalized()
			if target.kind == "boss" and target.windup > 0: movement = target.aim.orthogonal()
		elif not b.gems.is_empty(): movement = (b.gems[0].position - b.position).normalized()
		if frame % 15 == 0: b.request_skill(0); b.request_skill(1)
		b.tick(1.0 / 60.0, movement)
	print("REAL_BATTLE outcome=", b.outcome, " time=", snappedf(b.director.elapsed, 0.1), " kills=", b.director.kills, " level=", b.characters.JIA.level, " cpu_ms=", (Time.get_ticks_usec() - started) / 1000)
