extends SceneTree
## Result provenance only. Fixtures never change production balance or save schemas.
const B := preload("res://scripts/battle/battle_session.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const A := preload("res://scripts/battle/ability_definition.gd")
const ENEMY := preload("res://scripts/battle/enemy_runtime.gd")
const EC := preload("res://scripts/content/enemy_catalog.gd")
const RESOLVER := preload("res://scripts/battle/combat_resolver.gd")
var checks := 0
var failures := 0

func _init() -> void: call_deferred("run")

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func rows(b: RefCounted, kind: String) -> Array:
	return b.events.filter(func(event: Dictionary) -> bool: return event.kind == kind)

func fixture(ids: Array = ["JIA"]) -> RefCounted:
	var records := {}
	for id in ids: records[id] = C.record(id, 10)
	var stage := C.stage("B01")
	stage.boss_time = 10000.0
	stage.boss_kills = 10000
	stage.spawn_interval = 10000.0
	var b := B.new({"attempt_id":"feedback", "members":ids, "characters":records, "equipment":{}, "stage":stage, "seed":47})
	b.director.spawn_remaining = 10000.0
	for id in ids:
		var actor: RefCounted = b.characters[id]
		actor.stats.regen = 0.0
		actor.cooldowns[str(C.basic(id, b.equipment).id)] = 10000.0
		for ability in C.definition(id).automatic: actor.cooldowns[str(ability.id)] = 10000.0
		var support: Resource = C.definition(id).support
		if support != null: actor.cooldowns[str(support.id)] = 10000.0
	return b

func enemy(b: RefCounted, kind: String = "melee", offset: Vector2 = Vector2(90, 0)) -> RefCounted:
	var e: RefCounted = b.director.spawn(kind, b.position + offset)
	e.speed = 0
	e.cooldown = 10000
	b.enemies.append(e)
	return e

func context(b: RefCounted, amount: float, source: String = "JIA", direct: bool = true) -> Dictionary:
	return b.delivery_context({"source":source, "ability":"feedback_test", "mechanic":"", "cast":41, "damage":amount,
		"enchant":"", "direct":direct, "secondary":not direct, "damage_type":A.DamageType.PHYSICAL,
		"slow":0.0, "duration":0.0, "impact_origin":b.position, "impact_direction":Vector2.RIGHT})

func incoming(b: RefCounted, amount: float) -> void:
	b.projectiles.append({"position":b.position, "velocity":Vector2.ZERO, "life":1.0, "hostile":true, "damage":amount, "source_id":88, "move_id":"probe"})

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "saves isolated in temporary XDG")
	if failures: quit(1); return
	lethal_and_removal()
	multi_target_and_followup()
	player_results()
	guard_and_phase_budget()
	pickups_and_levels()
	elite_results()
	print("CHRONICLE_COMBAT_FEEDBACK_EVENTS_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func lethal_and_removal() -> void:
	var b := fixture()
	var e := enemy(b, "melee", Vector2(70, 0))
	var point: Vector2 = e.position
	b.current().cooldowns.clear()
	b.current().stats.attack = 100000
	b.tick(0, Vector2.ZERO)
	var hits := rows(b, "damage_dealt")
	var kills := rows(b, "kill")
	expect(hits.size() == 1 and kills.size() == 1, "same-frame lethal has exactly one contact and kill")
	if hits.size() == 1 and kills.size() == 1:
		var hit: Dictionary = hits[0]
		var kill: Dictionary = kills[0]
		expect(hit.position == point and kill.position == point and b.enemies.is_empty(), "removed target keeps world impact and corpse position")
		expect(hit.lethal and hit.amount == e.max_hp, "contact reports only applied budget and immediate lethality")
		expect(hit.visual_id == e.visual_id and kill.body_height == e.body_height and kill.definition_id == e.definition_id, "first-frame death has static actor appearance")
		expect(hit.source == "JIA" and kill.source == hit.source and kill.cast == hit.cast and kill.delivery == hit.delivery, "kill retains actual causal cast and delivery")
		expect(b.events.find(hit) < b.events.find(kill), "contact precedes death")
		var cast: Dictionary = rows(b, "cast")[0]
		expect(cast.position == b.position and cast.direction == Vector2.RIGHT and cast.cast == hit.cast, "swing has launch position and causal identity")
	b.tick(0, Vector2.ZERO)
	expect(rows(b, "kill").is_empty(), "removed target cannot emit a second death")
	var canceled := enemy(b)
	canceled.dead = true
	canceled.death_reason = "source_cancel"
	b.tick(0, Vector2.ZERO)
	expect(rows(b, "kill").is_empty() and rows(b, "enemy_remove").size() == 1, "source cancellation has no kill feedback or reward")

func multi_target_and_followup() -> void:
	var b := fixture(["JIA", "F06"])
	var first := enemy(b)
	var second := enemy(b, "melee", Vector2(90, 20))
	for e in [first, second]: e.hp = 100000; e.max_hp = e.hp
	b.characters.F06.cooldowns.clear()
	var sweep := A.make("feedback_basic", "test", A.Kind.NOVA, 0.1, 150, 0)
	expect(b._cast(sweep, b.characters.JIA, true), "controlled multi-target cast activates")
	b._resolve_hits()
	var hits := rows(b, "damage_dealt")
	expect(hits.size() == 2 and hits[0].delivery == hits[1].delivery, "one shape produces one contact for each actual target")
	expect(b.projectiles.size() == 1 and b.mechanics.states.F06.ammo == 5, "feedback does not repeat reactive followup or ammo expense")
	if b.projectiles.size() == 1:
		var launch: Dictionary = b.projectiles[0].context
		b.events.clear()
		b._update_projectiles(0.25, [], [])
		b._resolve_hits()
		var followups := rows(b, "damage_dealt")
		expect(followups.size() == 1, "one projectile collision produces one contact")
		if followups.size() == 1:
			expect(followups[0].source == "F06" and followups[0].secondary and not followups[0].direct and followups[0].cast == launch.cast, "reactive projectile retains helper ownership")
	var shared := context(b, 5)
	b.events.clear()
	b._hits.append_array([{"target":first,"context":shared}, {"target":first,"context":shared}])
	b._resolve_hits()
	expect(rows(b, "damage_dealt").size() == 1, "duplicate receiver in one delivery has one contact")
	var proxy := enemy(b, "melee", Vector2(100, 50))
	proxy.hp_owner = first
	b.events.clear()
	b._hits.append_array([{"target":proxy,"context":shared}, {"target":first,"context":shared}])
	b._resolve_hits()
	var proxy_hits := rows(b, "damage_dealt")
	expect(proxy_hits.size() == 1 and proxy_hits[0].enemy_id == first.id and proxy_hits[0].target_id == proxy.id and proxy_hits[0].position == proxy.position, "shared HP deduplicates owner while retaining actual contact body")

func player_results() -> void:
	for shield in [100.0, 4.0, 0.0]:
		var b := fixture()
		b.current().stats.armor = 0.0
		b.current().shield = shield
		var hp: float = b.current().hp
		incoming(b, 10)
		b.tick(0, Vector2.ZERO)
		var hits := rows(b, "player_hit")
		expect(hits.size() == 1, "actual incoming hit emits one player result")
		if hits.size() == 1:
			expect(hits[0].health_loss == minf(10 - minf(shield, 10), hp) and hits[0].shield_absorbed == minf(shield, 10), "full and partial shield report true damage split")
			expect(hits[0].id == "JIA" and hits[0].enemy_id == 88 and hits[0].attack == "probe" and hits[0].position == b.position, "player result retains recipient and hostile source")
		expect(rows(b, "hurt").size() == (0 if shield >= 10 else 1), "legacy hurt telemetry unchanged")
		incoming(b, 10)
		b.tick(0, Vector2.ZERO)
		expect(rows(b, "player_hit").is_empty() and rows(b, "hurt").is_empty(), "hurt-lock skipped hit has no false result")
	var regen := fixture()
	regen.equipment.armor = "iron_armor"
	regen.current().stats.armor = 0
	regen.current().shield = 4
	incoming(regen, 10)
	regen.tick(0, Vector2.ZERO)
	expect(regen.current().shield == 6 and rows(regen, "player_hit")[0].shield_absorbed == 4, "armor regenerated shield cannot distort absorbed amount")
	var overkill := fixture()
	overkill.current().hp = 1
	incoming(overkill, 100000)
	overkill.tick(0, Vector2.ZERO)
	expect(rows(overkill, "player_hit")[0].health_loss == 1 and rows(overkill, "damage_taken")[0].amount > 1, "new HP loss excludes overkill while old telemetry stays unchanged")
	var guarded := fixture(["JIA", "F02"])
	guarded.mechanics.states.JIA.windows.guard = {"life":1.0, "charges":1, "owner":"F02", "attack":10.0, "reduction":0.5}
	guarded.current().stats.armor = 0
	guarded.current().shield = 100
	incoming(guarded, 20)
	guarded.tick(0, Vector2.ZERO)
	var guard_result: Dictionary = rows(guarded, "player_hit")[0]
	expect(guard_result.id == "JIA" and guard_result.guard_source == "F02" and guard_result.guarded and guard_result.shield_absorbed == 10, "protective guard provenance names beneficiary and helper without inventing helper damage")

func guard_and_phase_budget() -> void:
	var b := fixture()
	var shield := enemy(b, "E04")
	shield.aim = Vector2.LEFT
	var hp: float = shield.hp
	b._hits.append({"target":shield, "context":context(b, 10)})
	b._resolve_hits()
	expect(rows(b, "damage_dealt").size() == 1 and is_equal_approx(rows(b, "damage_dealt")[0].amount, hp - shield.hp) and hp - shield.hp < 10, "enemy directional guard reports reduced real budget only")
	var phased := fixture()
	var boss := enemy(phased, "B18")
	var budget: float = boss.remaining_health_budget()
	phased._hits.append({"target":boss, "context":context(phased, budget * 0.6)})
	phased._resolve_hits()
	var first: Dictionary = rows(phased, "damage_dealt")[0]
	expect(boss.form_index == 1 and first.phase == 0 and first.visual_id == "B18_human" and not first.lethal, "phase transition contact retains impacted form and does not claim death")
	var remaining: float = boss.remaining_health_budget()
	phased._hits.append({"target":boss, "context":context(phased, budget)})
	phased._resolve_hits()
	var last: Dictionary = rows(phased, "damage_dealt")[-1]
	expect(is_equal_approx(last.amount, remaining) and not last.lethal and boss.phase_damage_bank > 0, "bank contact counts only unspent encounter budget")
	phased._hits.append({"target":boss, "context":context(phased, budget)})
	phased._resolve_hits()
	expect(rows(phased, "damage_dealt").size() == 2, "exhausted bank produces no repeated damage contact")
	incoming(phased, 100)
	phased.tick(0, Vector2.ZERO)
	expect(rows(phased, "player_hit").is_empty(), "safe transformation skipped hostile hit has no player result")
	boss.advance_form(100)
	phased.tick(0, Vector2.ZERO)
	expect(rows(phased, "damage_dealt").is_empty() and rows(phased, "kill").size() == 1, "bank release emits final death without a second contact")
	if rows(phased, "kill").size() == 1:
		expect(rows(phased, "kill")[0].delivery == last.delivery and rows(phased, "kill")[0].visual_id == "B18", "delayed bank death retains causal delivery and final appearance")

func pickups_and_levels() -> void:
	var b := fixture(["JIA", "F11", "N16"])
	for actor in b.characters.values(): actor.xp = C.xp_required(actor.level) - 1
	var before: int = b.director.rng.state
	b.gems = [{"position":b.position + Vector2(10,0), "amount":3.0}, {"position":b.position + Vector2(100,0), "amount":6.0}]
	b.tick(0, Vector2.ZERO)
	var pickups := rows(b, "xp_pickup")
	expect(pickups.size() == 1 and pickups[0].amount == 3 and pickups[0].collection == "contact", "contact pickup event matches actual orb grant")
	expect(rows(b, "level").size() == 3 and b.characters.JIA.level == 11 and b.characters.F11.level == 11, "one pickup preserves every party level event")
	b.tick(0.2, Vector2.ZERO)
	expect(rows(b, "xp_pickup").is_empty() and b.gems.size() == 1 and b.gems[0].position.distance_to(b.position) < 100, "magnet motion alone does not claim collection")
	b.tick(0, Vector2.ZERO)
	# The pre-move gap remains above 35; exact original pickup timing is preserved.
	expect(b.gems.size() == 0 and rows(b, "xp_pickup").size() == 1 and b.characters.JIA.xp == 2, "magnet arrival grants original shared XP once")
	expect(b.director.rng.state == before, "feedback consumes no combat RNG")
	var sweep := fixture(["JIA", "F11"])
	var reference := fixture(["JIA", "F11"])
	for actor in sweep.characters.values(): actor.xp = C.xp_required(actor.level) - 1
	for actor in reference.characters.values(): actor.xp = C.xp_required(actor.level) - 1
	sweep.gems = [{"position":Vector2.ZERO,"amount":2.0}, {"position":Vector2.ONE,"amount":4.0}]
	var boss := enemy(sweep, "boss")
	boss.dead = true
	boss.xp = 6
	for amount in [2.0, 4.0, 6.0, 18.0]: reference.grant_experience(amount)
	sweep.tick(0, Vector2.ZERO)
	var swept := rows(sweep, "xp_pickup")
	expect(swept.size() == 1 and swept[0].count == 3 and swept[0].amount == 12 and swept[0].collection == "victory_sweep", "victory sweep coalesces existing and boss orbs, excluding bonus XP")
	for id in sweep.members: expect(sweep.characters[id].snapshot() == reference.characters[id].snapshot(), "sweep leaves XP/level/heal/cooldown result unchanged: " + id)
	expect(rows(sweep, "level") == rows(reference, "level"), "sweep retains per-orb party level event order")
	expect(sweep.result.keys().size() == 8 and not sweep.result.has("events"), "feedback provenance never enters persisted battle result")
	var frozen: Dictionary = sweep.result.duplicate(true)
	sweep.tick(100, Vector2.ONE)
	expect(sweep.result == frozen, "terminal events cannot mutate saved result")

func elite_results() -> void:
	for kind in ["card_elite", "equipment_elite"]:
		var b := fixture()
		var elite := enemy(b, kind)
		elite.dead = true
		b.tick(0, Vector2.ZERO)
		var rewards := rows(b, "elite_defeated")
		expect(rewards.size() == 1 and rewards[0].reward_kind == ("card" if kind == "card_elite" else "equipment"), "elite result follows director reward identity")
		if rewards.size() == 1: expect(rewards[0].provisional and rewards[0].requires_victory and b.outcome.is_empty(), "elite reward explicitly awaits successful stage settlement")
		var duplicate := enemy(b, kind)
		duplicate.dead = true
		b.tick(0, Vector2.ZERO)
		expect(rows(b, "kill").size() == 1 and rows(b, "elite_defeated").is_empty(), "another same-kind elite cannot grant a second reward flag")
