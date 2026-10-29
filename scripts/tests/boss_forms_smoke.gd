extends SceneTree
## Boundary tests use production runtime objects; no input driver implies play balance.
const B = preload("res://scripts/battle/battle_session.gd")
const C = preload("res://scripts/content/combat_catalog.gd")
const E = preload("res://scripts/content/enemy_catalog.gd")
const R = preload("res://scripts/battle/combat_resolver.gd")
const S = preload("res://scripts/battle/enemy_system.gd")
const G = preload("res://scripts/battle/enemy_geometry.gd")
const SPACE = preload("res://scripts/battle/battle_space.gd")
var checks := 0
var failures := 0
var authored_moves := 0
func _init() -> void: call_deferred("run")
func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func near(value: float, wanted: float, label: String) -> void:
	expect(absf(value - wanted) < 0.001, "%s %.3f / %.3f" % [label, value, wanted])
func context(amount: float) -> Dictionary:
	return {"source":"JIA", "ability":"fixture", "cast":1, "damage":amount, "direct":true, "secondary":true, "slow":0.0, "duration":0.0}
func fixture(id: String = "B18") -> RefCounted:
	var stage := C.stage(id)
	stage.boss_time = 0; stage.boss_kills = 0; stage.encounter_mode = "boss_duel"
	var b := B.new({"attempt_id":"forms-"+id,"members":["JIA"],"characters":{"JIA":C.record("JIA",10)},"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":""},"stage":stage,"seed":21})
	b.current().cooldowns[C.basic("JIA", b.equipment).id] = 10000
	for skill in C.definition("JIA").automatic: b.current().cooldowns[skill.id] = 10000
	return b
func run() -> void:
	for id in ["B15", "B16", "B17", "B18"]:
		phase_accounting(id)
		all_geometry(id)
	slow_reachability()
	pause_and_safe_transition()
	status_and_projectile_carry()
	duel_lifecycle()
	collaborator_identity()
	print("BOSS_FORMS_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures, " authored_moves=", authored_moves)
	quit(0 if failures == 0 else 1)
func phase_accounting(id: String) -> void:
	var b := fixture(id)
	var boss: RefCounted = b.enemies[0]
	var budget: float = b.director.config.boss_hp
	expect(boss.form_count == 2 and boss.form_index == 0 and boss.visual_id == id + "_human", id + " begins human")
	near(boss.hp, budget * 0.4, id + " stage scales human budget once")
	R.hit_enemy(boss, context(boss.hp - 1))
	expect(boss.form_index == 0 and boss.hp == 1, id + " no percentage phase shortcut")
	R.hit_enemy(boss, context(51))
	expect(boss.form_index == 1 and not boss.dead and boss.visual_id == id, id + " empty HP transforms without kill")
	near(boss.hp, budget * 0.6, id + " war budget")
	near(boss.phase_damage_bank, 50, id + " overflow bank")
	R.hit_enemy(boss, context(75))
	near(boss.phase_damage_bank, 125, id + " transition output preserved")
	boss.advance_form(1.0)
	expect(boss.transition_remaining == 0 and boss.observation_remaining > 0, id + " observation follows safe transition")
	R.hit_enemy(boss, context(25))
	boss.advance_form(0.64)
	expect(not boss.dead and boss.hp == boss.max_hp, id + " second form is observable before bank settles")
	boss.advance_form(0.01)
	near(boss.hp, budget * 0.6 - 150, id + " full bank settles exactly once")
	near(boss.phase_damage_bank, 0, id + " bank fully spent")
	R.hit_enemy(boss, context(boss.hp + 100))
	expect(boss.dead, id + " no final form lock after observation")
	b.tick(0.01, Vector2.ZERO)
	expect(b.outcome == "victory", id + " final death wins")
	var deaths := 0
	for event in b.events:
		if event.kind == "boss_defeated": deaths += 1
	expect(deaths == 1, id + " one boss defeat event")
	b.tick(1, Vector2.ZERO)
	expect(b.result.attempt_id == "forms-"+id, id + " result remains stable")
func all_geometry(id: String) -> void:
	var b := fixture(id)
	var boss: RefCounted = b.enemies[0]
	var points := [SPACE.CENTER, Vector2(55,65),Vector2(3145,65),Vector2(55,1735),Vector2(3145,1735),Vector2(1600,65),Vector2(55,900),Vector2(3145,900),Vector2(1600,1735)]
	for form in 2:
		boss._apply_form(form)
		for action in boss.actions:
			authored_moves += 1
			var combo_beat: bool = id == "B18" and form == 1 and action.id != "demon_final_cleave"
			expect(action.windup >= 1.2 and action.recovery >= (0.65 if combo_beat else 1.7), id + " readable tell and authored reset " + str(action.id))
			for point in points:
				boss.position = SPACE.clamp_point(point + (SPACE.CENTER - point).normalized() * 150, Vector2.ONE * boss.radius)
				if boss.position == point: boss.position += Vector2(-150,0)
				var actual: Dictionary = action.duplicate(true)
				if actual.action == "collaboration": actual.shape = "line"
				var g: Dictionary = G.descriptor(boss, actual, point)
				var admitted: bool = S._has_exit(g, [], [], point, 180.0)
				expect(admitted, id + " form " + str(form) + " " + str(action.id) + " reachable at " + str(point))
				var origin: Vector2 = g.origin
				var direction: Vector2 = g.direction
				boss.current_action = actual; boss.telegraph = g; boss.windup = float(g.total); boss.aim = direction; boss.cooldown = 0
				S.step([boss], point + Vector2(30,0), 0.1, {"actor_speed":180})
				expect(boss.telegraph.origin == origin and boss.telegraph.direction == direction, id + " committed warning does not track")
				boss.windup = 0; boss.telegraph = {}; boss.active_remaining = 0
	b._finish("failed")
func pause_and_safe_transition() -> void:
	var b := fixture("B17")
	var boss: RefCounted = b.enemies[0]
	R.hit_enemy(boss, context(boss.hp + 5))
	boss.slow = 0.4; boss.slow_time = 0.5; boss.command_remaining = 0.5; boss.flash = 0.5
	var enemy: RefCounted = b.director.spawn("E01", b.position + Vector2(30,0))
	enemy.cooldown = 10000; b.enemies.append(enemy)
	b.projectiles.append({"position":b.position,"velocity":Vector2.ZERO,"life":3.0,"hostile":true,"source_id":enemy.id,"damage":9999.0})
	var hp: float = b.current().hp
	b.set_paused(true)
	var time: float = b.director.elapsed
	b.tick(0.6, Vector2.RIGHT)
	near(boss.transition_remaining, 1.0, "pause freezes transition")
	near(b.director.elapsed, time, "pause freezes battle clock")
	b.set_paused(false)
	var start: Vector2 = b.position
	b.tick(0.1, Vector2.RIGHT)
	near(b.current().hp, hp, "safe transition blocks attacks from unrelated troops")
	near(boss.slow_time, 0.4, "slow expires on battle clock during transform")
	near(boss.command_remaining, 0.4, "command expires on battle clock during transform")
	near(boss.flash, 0.4, "flash expires on battle clock during transform")
	expect(b.position.x > start.x, "movement stays usable during transition")
	expect(b.outcome.is_empty() and b.director.kills == 0, "transition never issues victory or kill rewards")
	var phase_events := 0
	for event in b.events:
		if event.kind == "boss_phase":
			phase_events += 1
			expect(event.enemy_id == boss.id and event.form_index == 1 and event.has("position"), "phase event exposes shared protocol")
	expect(phase_events == 1, "phase event emitted once")
	b.tick(0.1, Vector2.ZERO)
	for event in b.events: expect(event.kind != "boss_phase", "phase event is not repeated")
	b._finish("failed")
func status_and_projectile_carry() -> void:
	var b := fixture()
	var boss: RefCounted = b.enemies[0]
	b.mechanics.apply_curse(boss.id, "JIA", 200, 4.0, 1.0)
	b.mechanics.exposures[boss.id] = {"instances":[{"multiplier":0.2,"life":4.0}],"multiplier":0.2,"life":4.0}
	b.projectiles.append({"position":boss.position,"velocity":Vector2.ZERO,"life":3.0,"hostile":false,"context":context(20)})
	b.projectiles.append({"position":b.position+Vector2(30,0),"velocity":Vector2.ZERO,"life":3.0,"hostile":true,"source_id":boss.id,"damage":99.0})
	boss.current_action = boss.actions[0].duplicate(true); boss.telegraph = G.descriptor(boss,boss.current_action,b.position); boss.windup = 1.0
	b.hazards.append({"owner_id":boss.id,"shape":"disc","origin":b.position,"radius":100,"phase":"tell","remaining":0.01,"damage":9999.0})
	R.hit_enemy(boss, context(boss.hp + 10))
	var hp: float = b.current().hp
	b.tick(0.02, Vector2.ZERO)
	expect(b.mechanics.curses.has(boss.id) and b.mechanics.exposures.has(boss.id), "curse and marks retain canonical identity")
	expect(b.hazards.is_empty() and boss.windup == 0 and boss.telegraph.is_empty(), "old committed warning and hazard canceled")
	expect(b.projectiles.is_empty(), "old hostile shot canceled and friendly shot resolves")
	near(b.current().hp, hp, "canceled transition hazard cannot hurt")
	expect(boss.phase_damage_bank >= 34, "friendly in-flight projectile keeps amplified output across boundary")
	var attributed := false
	for event in b.events:
		if event.kind == "damage_dealt" and event.source == "JIA" and event.amount > 0: attributed = true
	expect(attributed, "banked output keeps damage attribution")
	b._finish("failed")
func duel_lifecycle() -> void:
	var b := fixture()
	expect(b.enemies.size() == 1 and b.enemies[0].definition_id == "B18", "duel exists in first rendered state")
	var boss: RefCounted = b.enemies[0]
	var output := {"spawns":[]}
	S._summon(boss,{"spawn_count":10,"limit":10},[boss],output,{"derivative_cap":99,"boss_derivative_cap":99})
	expect(output.spawns.is_empty(), "solo boss cannot summon even with permissive caller config")
	R.hit_enemy(boss, context(boss.remaining_health_budget() + 99999))
	for frame in 95: b.tick(1.0/60.0, Vector2.ZERO)
	expect(b.outcome.is_empty() and not boss.dead, "burst cannot skip observed second form")
	for frame in 10: b.tick(1.0/60.0, Vector2.ZERO)
	expect(b.outcome == "victory", "burst bank ends encounter after bounded observation")
	near(b.director.elapsed, 1.65, "burst does not create long HP gate")
	for event in b.events: expect(event.kind != "boss_phase", "terminal frame does not reissue transition")
func collaborator_identity() -> void:
	var b := fixture("B17")
	var boss: RefCounted = b.enemies[0]
	for form in 2:
		boss._apply_form(form)
		boss.actions = [boss.actions[2]]; boss.attack_index = 0; boss.cooldown = 0; boss.position = b.position - Vector2(100,0)
		for collaborator in 2:
			boss.params.collaboration_index = collaborator
			var output: Dictionary = S.step([boss],b.position,0.01,{})
			expect(output.spawns.size() == 1, "one collaboration source")
			if output.spawns.is_empty(): continue
			var proxy: RefCounted = b.director.derivative(output.spawns[0],[boss])
			var base := "M03" if collaborator == 0 else "M04"
			expect(proxy.visual_id == base + ("_human" if form == 0 else "_WAR"), "collaborator follows leader form")
			var expected_height := (128.0 if collaborator == 0 else 120.0) if form == 0 else (200.0 if collaborator == 0 else 190.0)
			near(proxy.body_height, expected_height, "collaborator body height follows leader form")
			expect(not proxy.targetable and proxy.xp == 0, "collaboration source has no separate target/reward")
			boss.windup = 0; boss.telegraph = {}; boss.cooldown = 0
	b._finish("failed")

func slow_reachability() -> void:
	var b := fixture()
	var boss: RefCounted = b.enemies[0]
	boss.actions = [boss.actions[2]]
	boss.cooldown = 0; boss.position = b.position - Vector2(250, 0)
	b.enemy_slow = 0.9; b.enemy_slow_remaining = 10
	var start: Vector2 = b.position
	var speed: float = b.current().stats.move * 0.1
	b.tick(0.01, Vector2.RIGHT)
	near(b.position.distance_to(start), speed * 0.01, "actual slowed movement uses effective speed")
	expect(boss.windup == 0, "unreachable locked marker waits while actor is slowed")
	b.enemy_slow = 0; b.enemy_slow_remaining = 0
	b.tick(0.01, Vector2.ZERO)
	expect(boss.windup > 0, "same authored marker admits after effective movement recovers")
	b._finish("failed")
