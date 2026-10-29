extends SceneTree
## Resource conservation and attribution tests, independent of art and campaign unlocks.
const B := preload("res://scripts/battle/battle_session.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const A := preload("res://scripts/battle/ability_definition.gd")
var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func near(actual: float, expected: float, message: String) -> void:
	expect(is_equal_approx(actual, expected), "%s actual=%.5f expected=%.5f" % [message, actual, expected])

func fixture(ids: Array = ["JIA", "F11", "F04"], level: int = 10, freeze_regen: bool = true) -> RefCounted:
	var records := {}
	for id in ids: records[id] = C.record(id, level)
	var stage := C.stage("B01")
	stage.boss_time = 10000.0
	stage.boss_kills = 10000
	stage.spawn_interval = 10000.0
	var b := B.new({"attempt_id":"mechanic_fixture", "members":ids, "characters":records,
		"equipment":{"weapon":"plain_blade", "armor":"cloth_armor", "accessory":"ember_seal"}, "stage":stage, "seed":47})
	b.director.spawn_remaining = 10000.0
	for id in ids:
		var actor: RefCounted = b.characters[id]
		if freeze_regen: actor.stats.regen = 0.0
		actor.cooldowns[str(C.basic(id, b.equipment).id)] = 10000.0
		for skill in C.definition(id).automatic: actor.cooldowns[str(skill.id)] = 10000.0
		var support: Resource = C.definition(id).support
		if support != null: actor.cooldowns[str(support.id)] = 10000.0
	return b

func dummy(b: RefCounted, offset: Vector2 = Vector2(90, 0)) -> RefCounted:
	var enemy: RefCounted = b.director.spawn("melee", b.position + offset)
	enemy.hp = 100000.0
	enemy.max_hp = enemy.hp
	enemy.cooldown = 10000
	enemy.speed = 0
	b.enemies.append(enemy)
	return enemy

func advance(b: RefCounted, delta: float) -> void:
	for actor in b.characters.values(): actor.tick(delta)
	b.mechanics.tick(delta)
	b._resolve_hits()

func skill(key: String, mechanic: String, params: Dictionary, kind: int = A.Kind.NOVA, power: float = 0.0, cost: float = 10.0) -> Resource:
	var value := A.make(key, key, kind, power, 300, 1, cost)
	value.mechanic = mechanic
	value.params = params
	return value

func paid(b: RefCounted, id: String, ability: Resource) -> bool:
	b.active = b.members.find(id)
	return b._cast(ability, b.characters[id], true, true)

func run() -> void:
	echo_and_extensions()
	payments_and_refunds()
	personal_shields_and_guard()
	ammo_and_trigger_limits()
	curse_conservation()
	temper_and_fields()
	lifecycle()
	ties_and_timed_loops()
	if checks < 99: failures += 1
	print("CHRONICLE_CHARACTER_MECHANICS_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func echo_and_extensions() -> void:
	var b := fixture()
	dummy(b)
	var frost: Resource = C.definition("F11").manual[0]
	var mp: float = b.characters.F11.mp
	expect(paid(b, "F11", frost), "Emma successfully casts real spell")
	near(b.characters.F11.mp, mp - frost.mana_cost, "record owner pays original cost")
	var status: Dictionary = b.mechanic_status("F11")
	expect(status.value == 2 and status.remaining == 12, "paid spell establishes two-charge twelve-second record")
	b._resolve_hits()
	var original_damage: float = b.mechanics.states.F11.echo.context.damage
	b.equipment.accessory = "frost_jade"
	var sweep: Resource = C.definition("JIA").manual[0]
	expect(paid(b, "JIA", sweep), "another caster pays for own skill")
	expect(b.mechanic_status("F11").value == 1, "one paid cast consumes exactly one record charge")
	var echo_count := 0
	for hit in b._hits:
		if hit.context.source == "F11":
			echo_count += 1
			expect(hit.context.secondary and not hit.context.direct and hit.context.enchant == "", "echo is source-owned secondary without current enchant")
			near(hit.context.damage, original_damage, "record damage snapshot is stable")
	expect(echo_count == 1, "one echo payload for one ally skill")
	near(b.characters.F11.mp, mp - frost.mana_cost, "echo does not debit original owner again")
	var payer: String = b.mechanics.last_payer
	var remaining: float = b.mechanic_status("F11").value
	b.characters.JIA.mp = 0
	expect(not paid(b, "JIA", sweep), "cooldown or MP failure is rejected")
	near(b.mechanic_status("F11").value, remaining, "failed input never consumes record")
	expect(b.mechanics.last_payer == payer, "failed input does not advance relay history")
	b._resolve_hits()
	b.mechanics.extend_windows("F04", 3, 4, ["echo", "temper"])
	b.mechanics.extend_windows("F04", 3, 4, ["echo", "temper"])
	near(b.mechanic_status("F11").remaining, 16, "same record extension is capped at four seconds")
	near(b.mechanic_status("F11").value, 1, "extension never adds charges")
	b.characters.JIA.cooldowns.clear()
	b.characters.JIA.mp = 100
	paid(b, "JIA", sweep)
	b.mechanics.extend_windows("F04", 3, 4, ["echo"])
	expect(b.mechanic_status("F11").value == 0, "extension cannot resurrect exhausted record")
	b.characters.F11.cooldowns.clear()
	paid(b, "F11", frost)
	expect(b.mechanic_status("F11").value == 2 and b.mechanic_status("F11").remaining == 12, "fresh paid spell replaces exhausted instance without old extension")
	b.characters.F11.dead = true
	b.characters.JIA.cooldowns.clear()
	paid(b, "JIA", sweep)
	expect(b.mechanic_status("F11").value == 2, "dead record owner emits no new background echo")

func payments_and_refunds() -> void:
	var b := fixture(["JIA", "F04", "F10"])
	dummy(b)
	var sweep: Resource = C.definition("JIA").manual[0]
	var command: Resource = C.definition("F10").manual[0]
	var actor: RefCounted = b.characters.JIA
	var initial: float = actor.mp
	paid(b, "JIA", sweep)
	near(initial - actor.mp, 22, "first cast receives no relay discount")
	near(b.mechanic_status("F04").value, 4.4, "refund ledger uses first actual debit")
	var commander: RefCounted = b.characters.F10
	var before: float = commander.mp
	paid(b, "F10", command)
	near(before - commander.mp, command.mana_cost * 0.8, "different actual caster pays discounted MP")
	near(b.mechanic_status("F04").value, (22 + command.mana_cost * 0.8) * 0.2, "refund uses discounted debit, not nominal price")
	commander.cooldowns.erase(str(command.id))
	before = commander.mp
	paid(b, "F10", command)
	near(before - commander.mp, command.mana_cost, "same caster repeated paid skill receives no relay discount")
	var balance: float = b.mechanic_status("F04").value
	var jia_before: float = actor.mp
	var command_before: float = commander.mp
	var settle: Resource = C.definition("F04").manual[0]
	var merchant_mp: float = b.characters.F04.mp
	paid(b, "F04", settle)
	near(actor.mp - jia_before, 4.4, "settle advances original payer's remaining balance")
	near(commander.mp - command_before, balance - 4.4, "settle never retargets ally refund to currently controlled merchant")
	near(b.mechanic_status("F04").value, 0, "settled accounts have no unpaid duplicate")
	expect(b.characters.F04.mp < merchant_mp, "settle still pays its own MP")
	var after_settle: float = actor.mp
	advance(b, 8)
	near(actor.mp, after_settle, "settled installments cannot pay again later")
	actor.cooldowns.clear()
	paid(b, "JIA", sweep)
	var outstanding: float = b.mechanic_status("F04").value
	b.characters.F04.dead = true
	before = actor.mp
	advance(b, 6)
	near(actor.mp - before, outstanding, "already-issued refund continues after merchant death")
	actor.cooldowns.clear()
	paid(b, "JIA", sweep)
	near(b.mechanic_status("F04").value, 0, "dead merchant does not create new refund accounts")
	var other := fixture(["JIA", "F04"])
	paid(other, "JIA", sweep)
	other.characters.JIA.dead = true
	other.characters.JIA.hp = 0
	var dead_mp: float = other.characters.JIA.mp
	advance(other, 7)
	expect(other.characters.JIA.dead and other.characters.JIA.hp == 0, "refund cannot revive dead recipient")
	near(other.characters.JIA.mp, dead_mp, "dead recipient receives no MP installment")

func personal_shields_and_guard() -> void:
	var b := fixture(["JIA", "F03", "F07"])
	dummy(b)
	b.characters.JIA.hp -= 10
	var heal: Resource = C.definition("F03").manual[0]
	paid(b, "F03", heal)
	near(b.characters.JIA.hp, b.characters.JIA.stats.hp, "party heal restores damaged member")
	expect(b.characters.JIA.shield > 0 and b.characters.F03.shield > 0 and b.characters.F07.shield > 0, "each living member gets personal overheal shield")
	for id in b.members: expect(b.characters[id].shield <= b.characters[id].stats.hp * 0.35, "personal shield is capped " + id)
	var jia_shield: float = b.characters.JIA.shield
	var bandit_shield: float = b.characters.F07.shield
	var bandit: RefCounted = b.characters.F07
	var thrust: Resource = C.definition("F07").manual[1]
	var mp: float = bandit.mp
	paid(b, "F07", thrust)
	near(bandit.shield, maxf(0, bandit_shield - 30), "bandit consumes only capped portion of own shield")
	near(b.characters.JIA.shield, jia_shield, "bandit cannot consume protagonist shield after switch")
	near(bandit.mp, mp - thrust.mana_cost, "shield payment does not replace MP payment")
	b._resolve_hits()
	bandit.cooldowns.clear()
	bandit.shield = 0
	expect(paid(b, "F07", thrust), "shield strike has usable ordinary version without healer")
	bandit.cooldowns.clear()
	bandit.shield = 20
	bandit.mp = 0
	expect(not paid(b, "F07", thrust), "MP failure rejects shield strike")
	near(bandit.shield, 20, "failed shield strike spends no shield")
	b.characters.F07.dead = true
	b.characters.F07.hp = 0
	b.characters.F03.cooldowns.clear()
	paid(b, "F03", heal)
	expect(b.characters.F07.dead and b.characters.F07.hp == 0, "party heal cannot revive dead auxiliary")

	var guard := fixture(["JIA", "F02"])
	var enemy := dummy(guard)
	paid(guard, "F02", C.definition("F02").manual[0])
	var actor: RefCounted = guard.characters.F02
	actor.shield = 50
	var hp: float = actor.hp
	near(guard.mechanics.receive_hit(actor, 20, guard.equipment), 0, "guard plus personal shield absorbs real incoming hit")
	near(actor.hp, hp, "guard does not move HP between bodies")
	expect(guard.mechanics.states.F02.windows.guard.charges == 0 and guard._hits.size() == 1, "actual shield absorption spends one guard and queues one counter")
	guard.mechanics.receive_hit(actor, 20, guard.equipment)
	expect(guard._hits.size() == 1, "hurt-lock reject emits no recursive or repeated counter")
	var health: float = enemy.hp
	guard._resolve_hits()
	expect(enemy.hp < health and guard._hits.is_empty(), "counter resolves as bounded secondary damage")

func ammo_and_trigger_limits() -> void:
	var b := fixture(["JIA", "F06"])
	var a := dummy(b)
	dummy(b, Vector2(90, 20))
	var support: Resource = C.definition("F06").support
	b.characters.F06.cooldowns.erase(str(support.id))
	var sweep := A.make("test_basic", "test", A.Kind.NOVA, 0.1, 150, 0)
	b._cast(sweep, b.characters.JIA, true)
	b._resolve_hits()
	expect(b.mechanic_status("F06").value == 5, "one multi-target foreground cast consumes at most one support arrow")
	expect(b.projectiles.size() == 1, "one actual hit event yields one projectile across multiple targets")
	var projectile: Dictionary = b.projectiles[0]
	expect(projectile.context.source == "F06" and not projectile.context.direct and projectile.context.enchant == "", "followup retains helper ownership and no current enchant")
	b.mechanics.states.F06.ammo = 0
	b.characters.F06.cooldowns.clear()
	b._cast(support, b.characters.F06, false)
	near(b.projectiles[-1].context.damage, b.characters.F06.stats.attack * support.damage_scale * 0.4, "empty ammo retains ordinary free support")
	near(b.mechanic_status("F06").value, 0, "ordinary support does not make ammo negative")
	paid(b, "JIA", C.definition("JIA").manual[0])
	near(b.mechanic_status("F06").value, 1, "other actual paid skill replenishes exactly one arrow")
	b.mechanics.states.F06.ammo = 6
	var volley: Resource = C.definition("F06").manual[0]
	paid(b, "F06", volley)
	near(b.mechanic_status("F06").value, 2, "own volley spends at most four and does not refill itself")
	var timer: float = b.mechanic_status("F06").remaining
	b.request_switch(-1)
	b._process_switch()
	near(b.mechanic_status("F06").remaining, timer, "switch does not reset ammo refill clock")
	b.characters.F06.cooldowns.clear()
	b.characters.F06.mp = 0
	expect(not paid(b, "F06", volley), "empty MP volley fails")
	near(b.mechanic_status("F06").value, 2, "failed volley spends no arrows")
	b.mechanics.states.F06.ammo = 0
	b.characters.F06.mp = 100
	expect(paid(b, "F06", volley), "zero-arrow volley retains ordinary independent attack")
	advance(b, 8)
	near(b.mechanic_status("F06").value, 2, "eight-second clock refills two arrows")
	b.characters.F06.dead = true
	advance(b, 8)
	near(b.mechanic_status("F06").value, 2, "dead helper neither refills nor fires")
	expect(a.hp > 0, "fixture retains enemy without XP-induced refills")

	var marks := fixture(["JIA", "N07"])
	dummy(marks)
	dummy(marks, Vector2(90, 10))
	var arrow: Resource = C.definition("N07").support
	marks.characters.N07.cooldowns.clear()
	var basic := A.make("fixture_basic", "basic", A.Kind.NOVA, 0.1, 150, 0)
	for i in 2:
		marks.characters.JIA.cooldowns.erase("fixture_basic")
		marks._cast(basic, marks.characters.JIA, true)
		marks._resolve_hits()
	expect(marks.mechanic_status("N07").value == 2 and marks.projectiles.is_empty(), "multi-target basics count once, no independent timed mark support")
	marks.characters.JIA.cooldowns.erase("fixture_basic")
	marks._cast(basic, marks.characters.JIA, true)
	marks._resolve_hits()
	expect(marks.projectiles.size() == 1 and marks.mechanic_status("N07").value == 0, "third real basic casts one helper payload")

func curse_conservation() -> void:
	var b := fixture(["JIA", "N15"])
	var enemy := dummy(b)
	var hp: float = enemy.hp
	b.mechanics.apply_curse(enemy.id, "JIA", 100, 5)
	advance(b, 1)
	near(hp - enemy.hp, 20, "finite curse first tick")
	var cash := skill("cash_half", "curse_cashout", {"fraction":0.5})
	paid(b, "N15", cash)
	b._resolve_hits()
	near(hp - enemy.hp, 60, "cashout pays half of remaining eighty immediately")
	advance(b, 4)
	near(hp - enemy.hp, 100, "cashout plus later ticks equals original damage budget exactly")
	expect(not b.mechanics.curses.has(enemy.id), "fully expired curse has no remaining account")
	advance(b, 20)
	near(hp - enemy.hp, 100, "expired curse never double settles")

	var spread := fixture(["JIA", "F05"])
	var donor := dummy(spread)
	for offset in [Vector2(110, 10), Vector2(130, 20), Vector2(140, 30), Vector2(150, 40), Vector2(170, 50)]: dummy(spread, offset)
	spread.mechanics.apply_curse(donor.id, "JIA", 100, 6)
	var spread_skill := skill("finite_spread", "curse", {"dot_scale":0.5, "duration":6, "spread_fraction":0.3, "spread_targets":2, "spread_radius":300})
	paid(spread, "F05", spread_skill)
	spread._resolve_hits()
	var copied := 0
	for id in spread.mechanics.curses:
		if int(id) == donor.id: continue
		for layer in spread.mechanics.curses[id]:
			if layer.source == "JIA": copied += 1
	expect(copied == 2, "one cast copies existing source curse to at most two neighbors without recursion")
	spread.characters.F05.cooldowns.clear()
	var pay_cash := skill("curse_actor_cash", "curse_cashout", {"fraction":1.0})
	paid(spread, "F05", pay_cash)
	spread._resolve_hits()
	for layers in spread.mechanics.curses.values():
		for layer in layers: near(layer.remaining, 0, "manual cashout by curse-trait caster does not silently reapply curse")

func temper_and_fields() -> void:
	var b := fixture(["JIA", "F08"])
	var enemy := dummy(b, Vector2(130, 0))
	var temper: Resource = C.definition("F08").support
	b.characters.F08.cooldowns.clear()
	b._cast(temper, b.characters.F08, false)
	var strike := A.make("shape_basic", "shape", A.Kind.THRUST, 1, 112, 0)
	expect(b._cast(strike, b.characters.JIA, true), "temper expanded range participates in target acquisition")
	expect(b._hits.size() == 1 and b._hits[0].context.has("spark_damage"), "real direct hit snapshots temper owner and spark")
	var hp: float = enemy.hp
	b._resolve_hits()
	expect(enemy.hp < hp and b._hits.is_empty(), "temper spark completes without creating another direct event")
	var other := A.make("helper", "helper", A.Kind.THRUST, 1, 112, 0)
	expect(not b._cast(other, b.characters.F08, false), "background helper does not inherit foreground reach bonus")

	var sparks := fixture(["JIA", "F08"])
	var nearby: Array = [dummy(sparks), dummy(sparks, Vector2(95, 10)), dummy(sparks, Vector2(100, 0))]
	sparks.characters.F08.cooldowns.clear()
	sparks._cast(C.definition("F08").support, sparks.characters.F08, false)
	var area := A.make("spark_fixture_basic", "area", A.Kind.NOVA, 1, 150, 0)
	sparks._cast(area, sparks.characters.JIA, true)
	var spark_amount: float = sparks._hits[0].context.spark_damage
	var expected_loss: float = sparks.characters.JIA.stats.attack * 1.15 + spark_amount
	sparks._resolve_hits()
	for recipient in nearby: near(100000.0 - recipient.hp, expected_loss, "one direct multi-hit cast yields at most one secondary spark area")

	var rallies := fixture(["JIA"])
	dummy(rallies)
	var strong := skill("strong", "rally", {"duration":2.0, "attack_multiplier":0.5}, A.Kind.WARD)
	var weak := skill("weak", "rally", {"duration":6.0, "attack_multiplier":0.1}, A.Kind.WARD)
	paid(rallies, "JIA", strong)
	paid(rallies, "JIA", weak)
	near(rallies.mechanics.states.JIA.windows.rally.attack_multiplier, 0.5, "weak rally never overwrites stronger active magnitude")
	var speed_buff := skill("speed_buff", "rally", {"duration":4.0, "speed_multiplier":0.5}, A.Kind.WARD)
	paid(rallies, "JIA", speed_buff)
	var normal := A.make("speed_fixture_basic", "basic", A.Kind.NOVA, 0, 150, 0)
	rallies._cast(normal, rallies.characters.JIA, true)
	near(rallies.characters.JIA.cooldowns.speed_fixture_basic, 1.0 / rallies.characters.JIA.stats.speed / 1.5, "rally speed changes only basic interval")
	var paid_attack := skill("unchanged_manual_cd", "", {}, A.Kind.NOVA)
	paid(rallies, "JIA", paid_attack)
	near(rallies.characters.JIA.cooldowns.unchanged_manual_cd, paid_attack.cooldown, "attack speed never shortens paid skill cooldown")
	var exposed: RefCounted = rallies.enemies[0]
	var expose_strong := skill("strong_expose", "expose", {"duration":2.0, "multiplier":0.5})
	var expose_weak := skill("weak_expose", "expose", {"duration":6.0, "multiplier":0.1})
	paid(rallies, "JIA", expose_strong)
	rallies._resolve_hits()
	paid(rallies, "JIA", expose_weak)
	rallies._resolve_hits()
	near(rallies.mechanics.exposures[exposed.id].multiplier, 0.5, "weak expose cannot overwrite strong expose")
	advance(rallies, 3)
	near(rallies.mechanics.states.JIA.windows.rally.attack_multiplier, 0.1, "strong rally expires on own clock, weak one remains")
	near(rallies.mechanics.exposures[exposed.id].multiplier, 0.1, "weak expose cannot prolong stronger magnitude beyond original lifetime")

	var field_battle := fixture(["JIA", "M03"])
	var target := dummy(field_battle)
	var field := skill("finite_field", "field", {"duration":2.0, "interval":1.0, "radius":180, "heal":5.0}, A.Kind.NOVA, 1)
	field.target_scope = "party"
	paid(field_battle, "M03", field)
	field_battle.characters.M03.dead = true
	field_battle.characters.M03.hp = 0
	field_battle.characters.JIA.hp -= 50
	hp = target.hp
	var damage: float = field_battle.characters.M03.stats.attack
	advance(field_battle, 1)
	advance(field_battle, 1)
	advance(field_battle, 1)
	near(hp - target.hp, damage * 2, "finite deployed field survives owner death and emits exactly two pulses, no terminal extra")
	near(field_battle.characters.JIA.hp, field_battle.characters.JIA.stats.hp - 40, "field heals only living assigned beneficiaries")
	expect(field_battle.characters.M03.dead and field_battle.mechanics.fields.is_empty(), "field cannot revive and expires")

func lifecycle() -> void:
	var b := fixture(["JIA", "F11", "F04"])
	dummy(b)
	paid(b, "F11", C.definition("F11").manual[0])
	b.characters.JIA.shield = 30
	b.set_paused(true)
	var state: Dictionary = b.mechanic_status("F11")
	var ledger: Dictionary = b.mechanic_status("F04")
	b.tick(100, Vector2.ONE)
	expect(b.mechanic_status("F11") == state and b.mechanic_status("F04") == ledger, "pause freezes windows and refund installments")
	b.set_paused(false)
	var snapshot: Dictionary = b.characters.F11.snapshot()
	expect(not snapshot.has("shield") and not snapshot.has("echo") and not snapshot.has("mechanics"), "persistent record excludes all temporary combat resources")
	b._finish("victory")
	expect(b.mechanics.states.is_empty() and b.mechanics.refunds.is_empty() and b.mechanics.curses.is_empty() and b.mechanics.fields.is_empty(), "finish clears every temporary inventory")
	near(b.characters.JIA.shield, 0, "finish clears all personal shields")
	var records: Dictionary = b.result.characters
	var next := B.new({"attempt_id":"next", "members":b.members, "characters":records, "equipment":b.equipment, "stage":C.stage("B01"), "seed":2})
	expect(next.mechanic_status("F11").value == 0 and next.mechanic_status("F04").value == 0 and next.characters.JIA.shield == 0, "next battle starts without prior record, refunds or shields")
	near(next.characters.F11.mp, records.F11.mp, "next battle persists paid MP")
	expect(next.characters.F11.cooldowns == records.F11.cooldowns, "next battle persists skill cooldowns")


func timed_fixture(ids: Array) -> RefCounted:
	var b := fixture(ids, 1, false)
	for actor in b.characters.values(): actor.cooldowns.clear()
	dummy(b, Vector2(80, 0))
	return b

func simulate(b: RefCounted, name: String, actions: Array, seconds: float) -> Array:
	var collected: Array = []
	var index := 0
	var last_ammo := -1.0
	for frame in int(ceil(seconds * 60)):
		var time := frame / 60.0
		while index < actions.size() and float(actions[index].time) <= time + 0.0001:
			var action: Dictionary = actions[index]
			index += 1
			if action.has("incoming"):
				b.projectiles.append({"position":b.position, "velocity":Vector2.ZERO, "life":0.1, "hostile":true, "damage":float(action.incoming), "source":1})
				continue
			var desired: int = b.members.find(action.id)
			if desired != b.active:
				var direction := 1 if posmod(b.active + 1, b.members.size()) == desired else -1
				b.request_switch(direction)
			if action.has("slot"): b.request_skill(int(action.slot))
		b.tick(1.0 / 60.0, Vector2.ZERO)
		for event in b.events:
			if event.kind == "cast" and event.manual:
				var row: Dictionary = event.duplicate(true)
				collected.append(row)
				print("LOOP ", name, " t=", snappedf(time, 0.01), " ", row.id, "/", row.ability, " paid=", snappedf(row.paid, 0.01), " shield_spent=", row.shield_spent, " ammo_spent=", row.ammo_spent)
			elif event.kind == "cast" and event.ability == "F06_support":
				print("LOOP ", name, " t=", snappedf(time, 0.01), " free_followup arrows_spent=", event.ammo_spent)
			elif event.kind == "mechanic" and event.mechanic == "refund":
				print("LOOP ", name, " t=", snappedf(time, 0.01), " refund to=", event.payer, " returned=", snappedf(event.amount, 0.01), " unpaid=", snappedf(event.balance, 0.01))
			elif event.kind == "mechanic" and event.mechanic == "echo":
				var row: Dictionary = event.duplicate(true)
				row.time = time
				collected.append(row)
				print("LOOP ", name, " t=", snappedf(time, 0.01), " echo owner=", row.id, " charges_left=", row.remaining)
		if "F06" in b.members:
			var status: Dictionary = b.mechanic_status("F06")
			if status.value != last_ammo:
				print("LOOP ", name, " t=", snappedf(time, 0.01), " arrows=", status.value, " next_refill=", snappedf(status.remaining, 0.01))
				last_ammo = status.value
	return collected

func ties_and_timed_loops() -> void:
	var tied := fixture(["JIA", "F03", "N13"])
	for actor in tied.characters.values():
		actor.hp = actor.stats.hp * 0.5
		actor.mp = actor.stats.mp * 0.5
	for active_index in [1, 2]:
		tied.active = active_index
		expect(tied.mechanics.receivers(tied.current(), "lowest_hp")[0] == tied.current(), "equal HP ratios prefer non-JIA current body")
		expect(tied.mechanics.receivers(tied.current(), "lowest_mp")[0] == tied.current(), "equal MP ratios prefer non-JIA current body")

	var echo := timed_fixture(["JIA", "F11", "F04"])
	var echo_rows := simulate(echo, "echo_refund", [{"time":0.0,"id":"F11","slot":0}, {"time":0.6,"id":"JIA","slot":0},
		{"time":3.0,"id":"F04","slot":0}, {"time":3.6,"id":"JIA"}, {"time":5.8,"id":"JIA","slot":0}], 7)
	var echoes := 0
	var actual_paid := 0.0
	for row in echo_rows:
		if row.kind == "mechanic": echoes += 1
		else: actual_paid += row.paid
	expect(echoes == 2, "real tick scheduler consumes exactly two echo charges, including paid merchant settlement")
	expect(actual_paid > 28 + 22 + 22, "actual loop contains separately paid merchant and original casts")
	expect(echo.mechanic_status("F11").value == 0, "later paid cast cannot obtain a third echo")
	expect(echo.mechanic_status("F04").value > 0, "later real paid cast creates a new bounded refund account")

	var relay := timed_fixture(["JIA", "F11", "F10"])
	var relay_rows := simulate(relay, "echo_relay", [{"time":0.0,"id":"F11","slot":0}, {"time":0.6,"id":"JIA","slot":0},
		{"time":5.8,"id":"JIA","slot":0}], 7)
	var paid_rows: Array = []
	for row in relay_rows:
		if row.kind == "cast": paid_rows.append(row)
	expect(paid_rows.size() == 3, "three scheduled real paid skills execute with their actual cooldowns")
	if paid_rows.size() == 3:
		near(paid_rows[0].paid, 28, "real scheduler original Emma cost")
		near(paid_rows[1].paid, 17.6, "real scheduler different payer discount")
		near(paid_rows[2].paid, 22, "real scheduler same payer does not discount again")

	var spend := timed_fixture(["JIA", "F03", "F07"])
	spend.characters.JIA.hp -= 20
	var spend_rows := simulate(spend, "shield_spend", [{"time":0.0,"id":"F03","slot":0}, {"time":0.6,"id":"F07","slot":1}, {"time":1.0,"incoming":70}], 2)
	var hold := timed_fixture(["JIA", "F03", "F07"])
	hold.characters.JIA.hp -= 20
	simulate(hold, "shield_hold", [{"time":0.0,"id":"F03","slot":0}, {"time":0.6,"id":"F07","slot":0}, {"time":1.0,"incoming":70}], 2)
	var spent := 0.0
	for row in spend_rows:
		if row.kind == "cast": spent += row.shield_spent
	near(spent, 30, "real tick shield conversion spends exactly thirty from bandit body")
	near(hold.characters.F07.hp - spend.characters.F07.hp, 30, "spending shield yields real later HP cost versus holding it")
	expect(spend.characters.JIA.shield > 0 and hold.characters.JIA.shield > 0, "other person's shield is unaffected by bandit conversion and incoming hit")
	print("LOOP shield_compare spend_hp=", snappedf(spend.characters.F07.hp, 0.01), " hold_hp=", snappedf(hold.characters.F07.hp, 0.01))

	var ammo := timed_fixture(["JIA", "F06", "F08"])
	var ammo_rows := simulate(ammo, "ammo_temper", [{"time":0.0,"id":"F08","slot":0}, {"time":0.6,"id":"JIA"},
		{"time":1.2,"id":"F06","slot":0}, {"time":1.8,"id":"JIA"}, {"time":2.5,"id":"JIA","slot":0},
		{"time":9.0,"id":"F06","slot":0}, {"time":11.5,"id":"F06","slot":0}], 12)
	var volleys := 0
	for row in ammo_rows:
		if row.kind == "cast" and row.ability == "F06_volley":
			volleys += 1
			near(row.paid, 30, "real volley always pays thirty MP")
			expect(row.ammo_spent >= 0 and row.ammo_spent <= 4, "real volley consumes bounded actual inventory")
	expect(volleys == 2, "nine-second premature input fails, real second volley executes after ten-second cooldown")
	expect(ammo.mechanic_status("F06").value >= 0 and ammo.mechanic_status("F06").value <= 6, "automatic followups, paid refills and timed refills remain bounded")

	var empty := fixture(["JIA", "F06", "F11"], 1)
	empty.characters.F11.cooldowns.clear()
	paid(empty, "F11", C.definition("F11").manual[0])
	empty.mechanics.states.F06.ammo = 0
	var no_actions := simulate(empty, "empty_switches", [{"time":0.0,"id":"JIA"}, {"time":0.6,"id":"F06"}, {"time":1.2,"id":"F11"},
		{"time":1.8,"id":"JIA"}, {"time":2.4,"id":"F06"}], 3)
	near(empty.mechanic_status("F06").value, 0, "empty rotations cannot manufacture arrows before natural refill")
	near(empty.mechanic_status("F11").value, 2, "switches and automatic actions cannot consume stored echo")
	expect(no_actions.is_empty(), "empty rotation generates no fake paid casts or echoes")
