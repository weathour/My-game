extends SceneTree
## Runtime assertions use real catalog actions; combat fixtures are not balance evidence.
const B := preload("res://scripts/battle/battle_session.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const E := preload("res://scripts/content/enemy_catalog.gd")
const S := preload("res://scripts/battle/enemy_system.gd")
const G := preload("res://scripts/battle/enemy_geometry.gd")
const T := preload("res://scripts/battle/targeting.gd")
const R := preload("res://scripts/battle/combat_resolver.gd")
var checks := 0
var failures := 0
func _init() -> void: call_deferred("run")
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func near(value: float, wanted: float, message: String) -> void: expect(absf(value - wanted) < 0.001, "%s %.3f != %.3f" % [message, value, wanted])
func fixture(stage_id: String = "B01") -> RefCounted:
	var stage := C.stage(stage_id)
	stage.boss_time = 10000.0; stage.boss_kills = 10000; stage.spawn_interval = 10000.0
	var b := B.new({"attempt_id":"enemy_fixture", "members":["JIA"], "characters":{"JIA":C.record("JIA", 10)}, "equipment":{"weapon":"plain_blade", "armor":"cloth_armor", "accessory":""}, "stage":stage, "seed":19})
	b.director.spawn_remaining = 10000
	b.current().cooldowns[C.basic("JIA", b.equipment).id] = 10000
	for skill in C.definition("JIA").automatic: b.current().cooldowns[skill.id] = 10000
	return b
func add(b: RefCounted, id: String, offset: Vector2 = Vector2(-100, 0)) -> RefCounted:
	var enemy: RefCounted = b.director.spawn(id, b.position + offset)
	enemy.cooldown = 0; b.enemies.append(enemy)
	return enemy
func context(amount: float, direct: bool = false) -> Dictionary:
	return {"source":"JIA", "ability":"fixture", "cast":0, "damage":amount, "enchant":"", "direct":direct, "secondary":true, "slow":0.0, "duration":0.0}
func run() -> void:
	all_actions()
	geometries()
	charge_boundary_geometry()
	limits_and_shield()
	phase_and_team_sequences()
	impact_and_source_matrix()
	hazard_release_events()
	shared_health()
	lifecycle()
	print("BAIMEN_ENEMY_RUNTIME_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
func all_actions() -> void:
	for id in E.ordinary_ids() + ["L00"] + E.elite_ids() + E.boss_ids():
		var b := fixture()
		var enemy := add(b, id)
		var authored: Array = enemy.actions.duplicate(true)
		var follower := add(b, "E01", Vector2(-30, 60))
		follower.cooldown = 10000; follower.speed = 0
		for index in authored.size():
			enemy.actions = [authored[index]]
			enemy.attack_index = 0; enemy.cooldown = 0; enemy.windup = 0; enemy.position = b.position - Vector2(minf(80, float(authored[index].range) * 0.5), 0)
			var result: Dictionary = S.step(b.enemies, b.position, 0.01, {"hazards":b.hazards, "config":b.director.config})
			expect(enemy.windup > 0, id + " action enters actual warning " + str(index))
			if enemy.windup <= 0: continue
			if float(enemy.telegraph.damage) > 0:
				var safe_paths := 0
				var travel: float = 215 * enemy.windup * 0.92
				for direction_index in 32:
					var escape: Vector2 = b.position + Vector2.RIGHT.rotated(direction_index * TAU / 32) * travel
					if not G.contains(enemy.telegraph, escape): safe_paths += 1
				expect(safe_paths >= 2, id + " action has multiple reachable escape directions")
			var locked: Vector2 = enemy.telegraph.origin
			S.step(b.enemies, b.position + Vector2(0, 20), 0.1, {"hazards":b.hazards, "config":b.director.config})
			expect(enemy.telegraph.origin == locked, id + " warning stays locked")
			result = S.step(b.enemies, b.position, enemy.windup + 0.001, {"hazards":b.hazards, "config":b.director.config})
			if enemy.attack == "charge":
				var start: Vector2 = enemy.position
				expect(enemy.state == "active" and enemy.active_remaining > 0, id + " charge has active movement")
				S.step(b.enemies, b.position + Vector2(0, 100), enemy.active_total * 0.5, {"hazards":b.hazards, "config":b.director.config})
				expect(enemy.position.distance_to(start) > 10 and enemy.active_remaining > 0, id + " charge visibly traverses half route")
				S.step(b.enemies, b.position + Vector2(0, 100), enemy.active_remaining + 0.001, {"hazards":b.hazards, "config":b.director.config})
			expect(enemy.state == "recovery" and enemy.cooldown > 0 and enemy.telegraph.is_empty(), id + " releases and recovers")
			expect(not result.events.is_empty(), id + " action has a release event")
			if enemy.attack in ["shot", "fan"]: expect(not result.projectiles.is_empty(), id + " fires finite projectiles")
			enemy.cooldown = 10000
			S.step(b.enemies, b.position, 10, {"hazards":b.hazards, "config":b.director.config})
		b._finish("failed")
func geometries() -> void:
	var line := {"shape":"line", "origin":Vector2.ZERO, "direction":Vector2.RIGHT, "length":200, "half_width":20}
	expect(G.contains(line, Vector2(100, 35)), "line includes player radius")
	expect(not G.contains(line, Vector2(100, 50)), "line has a lateral escape")
	expect(not G.contains(line, Vector2(-50, 0)), "line has a rear escape")
	var ring := {"shape":"ring_gap", "origin":Vector2.ZERO, "radius":180, "gap_angle":0.0, "gap_width":1.4}
	expect(not G.contains(ring, Vector2(100, 0)), "ring opening is safe")
	expect(G.contains(ring, Vector2(-100, 0)), "ring body damages")
	expect(not G.contains(ring, Vector2(0, 220)), "ring has outside escape")
	var b := fixture()
	for id in ["E03", "E05", "E09", "B01"]: add(b, id)
	S.step(b.enemies, b.position, 0.01, {"config":b.director.config})
	var tells := 0
	for enemy in b.enemies:
		if enemy.windup > 0: tells += 1
	expect(tells == 1, "B01 shared major budget includes ordinary and boss")
	b._finish("failed")
func limits_and_shield() -> void:
	var b := fixture()
	var healer := add(b, "E08")
	var target := add(b, "E01", Vector2(-80, 0))
	target.hp = 1
	for i in 20: S._heal(healer, b.enemies, 230)
	near(target.healing_received, target.max_hp * 0.15, "all healer intake is capped")
	var old_position: Vector2 = healer.position
	S.step(b.enemies, b.position + Vector2(600, 0), 1, {"config":b.director.config})
	expect(healer.position == old_position, "healer cannot follow a kite")
	var shield := add(b, "E04")
	shield.state = "tell"; shield.aim = Vector2.RIGHT
	var hit := context(20, true); hit.impact_origin = shield.position + Vector2(100, 0)
	var hp: float = shield.hp; R.hit_enemy(shield, hit)
	near(hp - shield.hp, 12, "front direct shield reduction")
	hit.impact_origin = shield.position - Vector2(100, 0); hp = shield.hp; R.hit_enemy(shield, hit)
	near(hp - shield.hp, 20, "rear bypasses front shield")
	hp = shield.hp; R.hit_enemy(shield, context(20)); near(hp - shield.hp, 20, "DOT is not deleted by shield")
	shield.state = "recovery"; hp = shield.hp; hit.impact_origin = shield.position + Vector2(100, 0); R.hit_enemy(shield, hit)
	near(hp - shield.hp, 20, "recovery drops shield")
	var summoner := add(b, "E11")
	var result := {"spawns":[]}
	for i in 10: S._summon(summoner, {"spawn_id":"D05", "spawn_count":2, "limit":4}, [], result, b.director.config)
	expect(summoner.spawned_total == 4 and result.spawns.size() == 4, "spawn lifetime budget cannot renew")
	var ghost := add(b, "M03_WAR", Vector2(1, 0))
	expect(T.nearest([ghost, target], b.position, 500) == target, "apparition excluded from nearest")
	expect(not T.in_shape([ghost], b.position, Vector2.RIGHT, 500, false, true).has(ghost), "apparition excluded from shapes")
	b._finish("failed")
func shared_health() -> void:
	for reverse in [false, true]:
		var b := fixture("B10")
		var owner := add(b, "B10")
		var proxy: RefCounted = b.director.derivative({"definition_id":"B10_R", "position":owner.position + Vector2(0, 20), "parent_id":owner.id, "hp_owner_id":owner.id}, b.enemies)
		b.enemies.append(proxy)
		var hp: float = owner.hp
		var cast: Dictionary = b.delivery_context(context(10))
		for enemy in ([proxy, owner] if reverse else [owner, proxy]): b._hits.append({"target":enemy, "context":cast})
		b._resolve_hits(); near(hp - owner.hp, 10, "shared AoE once for either order")
		var pulse: Dictionary = b.delivery_context(context(7))
		for enemy in [owner, proxy]: b._hits.append({"target":enemy, "context":pulse})
		b._resolve_hits(); near(hp - owner.hp, 17, "next cast0 pulse remains independent")
		b.mechanics.apply_curse(proxy.damage_owner().id, "JIA", 12, 2, 1)
		b.mechanics.tick(1); b._resolve_hits()
		b.mechanics.tick(1); b._resolve_hits()
		near(hp - owner.hp, 29, "shared canonical DOT delivers later ticks")
		b.director.defeated(proxy); expect(b.director.kills == 0 and not b.director.card_elite, "proxy no threshold or reward")
		b._finish("failed")
func lifecycle() -> void:
	var b := fixture()
	var source := add(b, "L04")
	var egg: RefCounted = b.director.derivative({"definition_id":"D05", "position":source.position, "parent_id":source.id}, b.enemies)
	var soldier: RefCounted = b.director.derivative({"definition_id":"D01", "position":source.position, "parent_id":source.id}, b.enemies)
	b.enemies.append_array([egg, soldier])
	b.hazards.append({"owner_id":source.id, "phase":"tell", "remaining":2.0})
	source.dead = true; b._cleanup_sources()
	expect(egg.dead and egg.death_reason == "source_cancel" and not soldier.dead, "source death cancels eggs but living soldiers remain")
	expect(b.hazards.is_empty(), "source death removes ground threat immediately")
	var boss := add(b, "B18")
	boss.hp = boss.max_hp * 0.2
	S.step(b.enemies, b.position, 0.01, {"hazards":b.hazards, "config":b.director.config})
	expect(boss.phase == 2, "large hit crosses both boss thresholds without HP gate")
	var hp: float = boss.hp; R.hit_enemy(boss, context(hp + 1)); expect(boss.dead, "final phase has no immortality")
	b.set_paused(true); var time: float = b.director.elapsed; b.tick(1, Vector2.RIGHT); near(b.director.elapsed, time, "pause freezes enemy clock")
	b.set_paused(false)
	var living_elite := add(b, "card_elite")
	b.tick(0.01, Vector2.ZERO)
	expect(b.outcome == "victory" and not b.result.card_elite, "boss death ends immediately without awarding live field elite")
	expect(b.telegraphs.is_empty() and b.hazards.is_empty() and b.projectiles.is_empty(), "combat end clears all active threats")
	var tied := fixture()
	var tied_boss := add(tied, "B01"); tied_boss.dead = true; tied.current().dead = true
	tied.tick(0.01, Vector2.ZERO); expect(tied.outcome == "failed", "JIA death retains same-frame priority")

func phase_and_team_sequences() -> void:
	var b := fixture("B18")
	var boss := add(b, "B18", Vector2(-20, 0))
	var signatures: Array = []
	for phase in 3:
		boss.phase = phase
		var sequence: Array = []
		var size := 2 if phase == 0 else 4 if phase == 1 else 5
		for index in size:
			boss.attack_index = index
			var action: Dictionary = S._next_action(boss)
			sequence.append(action.action)
			if index == size - 1: expect(action.combo_final and float(action.recovery) >= 2.0, "phase ends with real shared recovery")
			else: expect(not action.combo_final and float(action.recovery) < 1.0, "phase intermediate beat retains short reset")
		signatures.append(str(sequence))
	expect(signatures[0] != signatures[1] and signatures[1] != signatures[2], "three phase combos have different actual sequences")
	var nova := {"shape":"disc", "origin":b.position, "radius":190, "remaining":1.5}
	expect(S._has_exit(nova, [], [], b.position, 215), "1.5-second pointblank slam has a reachable exit")
	expect(not S._has_exit(nova, [], [], b.position, 10), "movement speed really constrains admission")
	var commander := add(b, "E07", Vector2(-40, 0))
	boss.dead = true
	var release: Dictionary = S.step([commander], b.position, 0.01, {"config":b.director.config})
	expect(commander.attack == "swipe" and commander.telegraph.shape == "sector" and float(commander.telegraph.radius) < 100, "empty command becomes independently warned short swipe")
	commander.windup = 0; commander.cooldown = 0; commander.attack_index = 0
	var follower := add(b, "E01", Vector2(-60, 20)); follower.cooldown = 10000
	release = S.step([commander, follower], b.position, 0.01, {"config":b.director.config})
	expect(commander.attack == "command" and commander.telegraph.action_id == "command", "command with follower is a visible buff tell")
	release = S.step([commander, follower], b.position, commander.windup + 0.001, {"config":b.director.config})
	expect(release.hits.is_empty() and follower.command_remaining > 0, "command buffs without hidden circular damage")
	for phase in 3:
		var phase_battle := fixture("B18")
		var phase_boss := add(phase_battle, "B18", Vector2(-40, 0))
		phase_boss.hp = phase_boss.max_hp * (1.0 if phase == 0 else 0.6 if phase == 1 else 0.2)
		var releases: Array = []
		var beats := 2 if phase == 0 else 4 if phase == 1 else 5
		for frame in 5000:
			var actor: Vector2 = phase_boss.position + Vector2(40, 0)
			var output: Dictionary = S.step(phase_battle.enemies, actor, 0.02, {"config":phase_battle.director.config})
			for event in output.events:
				if event.kind == "enemy_release": releases.append(event.geometry.action_id)
			if releases.size() >= beats: break
		expect(releases.size() == beats, "phase %s actual timed combo releases all %s beats" % [phase, beats])
		expect(phase_boss.cooldown >= 2.0, "phase timed final beat commits full recovery")
		phase_battle._finish("failed")
	var cap_battle := fixture()
	var source := add(cap_battle, "L02")
	for i in 6:
		var child: RefCounted = cap_battle.director.derivative({"definition_id":"D01", "position":cap_battle.position + Vector2(0, i * 20), "parent_id":source.id}, cap_battle.enemies)
		cap_battle.enemies.append(child)
	var cap_result: Dictionary = S.step(cap_battle.enemies, cap_battle.position, 0.01, {"config":cap_battle.director.config})
	expect(cap_result.spawns.is_empty(), "initial anchors obey global derivative cap")
	var late_boss := add(cap_battle, "B12")
	cap_result = S.step(cap_battle.enemies, cap_battle.position, 0.01, {"config":cap_battle.director.config})
	expect(cap_result.spawns.is_empty(), "boss cap does not add more or erase already-live six")
	for child in cap_battle.enemies:
		if child.parent_id > 0: expect(not child.dead, "boss arrival preserves living derivative")
	cap_battle._finish("failed")
	b._finish("failed")
	var twins := fixture("B10")
	var left := add(twins, "B10", Vector2(-50, 0))
	left.initialized = true
	var right: RefCounted = twins.director.derivative({"definition_id":"B10_R", "position":twins.position + Vector2(0, 50), "parent_id":left.id, "hp_owner_id":left.id}, twins.enemies)
	twins.enemies.append(right)
	var order: Array = []
	var both_recover := false
	for i in 2000:
		var result: Dictionary = S.step(twins.enemies, twins.position, 0.02, {"config":twins.director.config})
		for event in result.events:
			if event.kind == "enemy_release":
				order.append(event.id)
				if left.cooldown > 0 and right.cooldown > 0: both_recover = true
		if order.size() >= 4: break
	expect(order.size() >= 4 and order[0] != order[1] and order[0] == order[2] and order[1] == order[3], "B10 bodies alternate real releases")
	expect(both_recover, "B10 releases impose shared recovery")
	twins._finish("failed")
	var team := fixture("B17")
	var leader := add(team, "B17", Vector2(-60, 0))
	var collaboration: Dictionary = leader.actions[1].duplicate(true)
	leader.actions = [collaboration]
	var gao: Dictionary = S.step(team.enemies, team.position, 0.01, {"config":team.director.config})
	expect(leader.telegraph.shape == "line" and gao.spawns[0].definition_id == "M03_WAR", "Gao collaboration has its own warned line and apparition")
	gao = S.step(team.enemies, team.position, leader.windup + 0.001, {"config":team.director.config})
	expect(gao.spawns.size() == 2 and gao.spawns[0].definition_id == "D01" and team.hazards.is_empty(), "Gao supplies finite targetable formation soldiers")
	leader.cooldown = 0
	var chen: Dictionary = S.step(team.enemies, team.position, 0.01, {"hazards":team.hazards, "config":team.director.config})
	expect(leader.telegraph.shape == "marker" and chen.spawns[0].definition_id == "M04_WAR", "Chen collaboration locks a distinct array marker")
	chen = S.step(team.enemies, team.position, leader.windup + 0.001, {"hazards":team.hazards, "config":team.director.config})
	expect(chen.hits.is_empty() and chen.spawns.is_empty() and team.hazards.size() == 1 and team.hazards[0].phase == "tell", "Chen adds new delayed tell instead of instant marker damage or soldiers")
	expect(leader.cooldown >= 2.5, "collaboration ends in common long recovery")
	team._finish("failed")

func impact_and_source_matrix() -> void:
	var b := fixture()
	var shield := add(b, "E04")
	shield.hp = 1000; shield.max_hp = 1000; shield.state = "tell"; shield.aim = Vector2.RIGHT
	var mixed := context(20, true); mixed.impact_origin = shield.position + Vector2(100, 0); mixed.curse_settled = 30
	R.hit_enemy(shield, mixed)
	near(shield.hp, 958, "front shield reduces fresh20 to12 but preserves settled curse30")
	var source := add(b, "L02")
	var anchor: RefCounted = b.director.derivative({"definition_id":"D03", "position":source.position, "parent_id":source.id}, b.enemies)
	b.enemies.append(anchor)
	var before: int = b.director.kills
	R.hit_enemy(anchor, context(anchor.hp + 1))
	b.tick(0.01, Vector2.ZERO)
	expect(b.director.kills == before and b.gems.is_empty(), "destroyed anchor gives neither threshold nor XP")
	var caster := add(b, "E02")
	var packet := {"position":b.position - Vector2(50, 0), "velocity":Vector2(100, 0), "life":1.0, "hostile":true, "damage":5, "source_id":caster.id, "source":caster.id, "visual_id":caster.visual_id, "hit_radius":5.0}
	b.projectiles.append(packet); caster.dead = true
	b.tick(0.01, Vector2.ZERO)
	expect(b.projectiles.size() == 1, "already-fired projectile survives source death with short TTL")
	b.set_paused(true); var p: Vector2 = b.projectiles[0].position; b.tick(1, Vector2.ZERO)
	expect(b.projectiles[0].position == p, "pause freezes already-fired projectiles")
	b.set_paused(false); b.tick(2, Vector2.ZERO)
	expect(b.projectiles.is_empty(), "source-orphaned projectile ends within original TTL")
	b._finish("failed")
	var twins := fixture("B10")
	var owner := add(twins, "B10", Vector2(-120, 0)); owner.initialized = true
	var proxy: RefCounted = twins.director.derivative({"definition_id":"B10_R", "position":twins.position - Vector2(60, 0), "parent_id":owner.id, "hp_owner_id":owner.id}, twins.enemies)
	twins.enemies.append(proxy)
	owner.cooldown = 10000; proxy.cooldown = 10000
	var hp: float = owner.hp
	twins.projectiles.append({"position":twins.position, "velocity":Vector2(-420, 0), "life":1.0, "hostile":false, "context":context(17)})
	var incoming: Array = []; twins._update_projectiles(0.2, incoming); twins._resolve_hits()
	near(hp - owner.hp, 17, "projectile hitting proxy contributes canonical owner damage")
	expect(twins.projectiles.is_empty(), "damage-contributing proxy consumes projectile normally")
	owner.dead = true; owner.hp = 0; twins.tick(0.01, Vector2.ZERO)
	expect(twins.outcome == "victory" and twins.director.kills == 0, "shared owner death yields victory once without proxy threshold")
	var charge_battle := fixture()
	var charger := add(charge_battle, "E03", Vector2(-150, 0))
	S.step(charge_battle.enemies, charge_battle.position, 0.01, {"config":charge_battle.director.config})
	S.step(charge_battle.enemies, charge_battle.position, charger.windup + 0.001, {"config":charge_battle.director.config})
	var hits := 0
	for i in 100:
		var output: Dictionary = S.step(charge_battle.enemies, charge_battle.position, 0.01, {"config":charge_battle.director.config})
		hits += output.hits.size()
	expect(hits == 1, "one committed moving charge hits controlled body at most once")
	charge_battle._finish("failed")

func charge_boundary_geometry() -> void:
	var origins := [Vector2(3000, 1000), Vector2(200, 1000), Vector2(1500, 200), Vector2(1500, 1600), Vector2(3000, 200), Vector2(200, 200), Vector2(3000, 1600), Vector2(200, 1600)]
	var actors := [Vector2(3145, 1100), Vector2(55, 1100), Vector2(1600, 65), Vector2(1600, 1735), Vector2(3145, 65), Vector2(55, 65), Vector2(3145, 1735), Vector2(55, 1735)]
	for body_radius in [11.0, 16.0, 46.0]:
		for index in origins.size():
			var b := fixture("B18")
			var boss: RefCounted = b.director.spawn("boss", origins[index])
			boss.radius = body_radius; boss.initialized = true; boss.cooldown = 0; boss.attack_index = 1
			var actor: Vector2 = actors[index]
			S.step([boss], actor, 0.01, {"config":b.director.config, "actor_speed":215.0})
			expect(boss.state == "tell" and boss.telegraph.action_id == "charge", "edge/corner charge really admits warning")
			if boss.telegraph.is_empty(): continue
			var g: Dictionary = boss.telegraph.duplicate(true)
			var endpoint: Vector2 = g.origin + g.direction * float(g.length)
			var lower: Vector2 = Vector2.ONE * body_radius
			var upper: Vector2 = Vector2(3200, 1800) - lower
			expect(endpoint.is_equal_approx(endpoint.clamp(lower, upper)), "warned endpoint respects body padding on all four edges")
			expect(absf((endpoint - Vector2(g.origin)).cross(g.direction)) < 0.001, "edge clipping preserves locked aim direction")
			expect(float(g.length) <= 390.001, "boundary clip never lengthens authored charge")
			var touched_boundary := minf(minf(absf(endpoint.x - lower.x), absf(endpoint.x - upper.x)), minf(absf(endpoint.y - lower.y), absf(endpoint.y - upper.y)))
			expect(touched_boundary < 0.001, "outward ray reaches its first inset boundary")
			var normal: Vector2 = Vector2(g.direction).orthogonal()
			var midpoint: Vector2 = Vector2(g.origin) + Vector2(g.direction) * float(g.length) * 0.5
			expect(G.contains(g, midpoint + normal * (float(g.half_width) + 15.5)), "collision padding matches clipped warned line")
			expect(not G.contains(g, midpoint + normal * (float(g.half_width) + 16.5)), "outside padded boundary remains safe")
			S.step([boss], actor, boss.windup + 0.001, {"config":b.director.config})
			var all_inside := true
			for frame in 100:
				if boss.active_remaining <= 0: break
				S.step([boss], actor, 0.01, {"config":b.director.config})
				if not boss.position.is_equal_approx(boss.position.clamp(lower, upper)): all_inside = false
			expect(all_inside, "every active charge sample respects padded battle bounds")
			expect(boss.position.distance_to(endpoint) < 0.001 and boss.state == "recovery", "actual moving charge ends exactly at warned clipped endpoint")
			b._finish("failed")
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		near(G.bounded_ray_length(Vector2(1600, 900), direction, 100, 46), 100, "axis-aligned inner charge retains requested length")

func hazard_release_events() -> void:
	for kind in ["echo", "collaboration_array"]:
		var b := fixture()
		var source := add(b, "L06")
		source.cooldown = 10000
		var hazard := {"kind":kind, "owner_id":source.id, "action_serial":19, "attack_step":2, "phase":"tell", "shape":"marker", "origin":b.position, "radius":55.0, "direction":Vector2.RIGHT, "remaining":0.1, "total":0.1, "damage":5.0}
		b.hazards.append(hazard)
		var early: Dictionary = S.step(b.enemies, b.position, 0.05, {"hazards":b.hazards, "config":b.director.config})
		var early_events := 0
		for event in early.events:
			if event.kind == "enemy_hazard_release": early_events += 1
		expect(early_events == 0 and early.hits.is_empty(), kind + " warning emits no premature release")
		var resolved: Dictionary = S.step(b.enemies, b.position, 0.06, {"hazards":b.hazards, "config":b.director.config})
		var release_events: Array = []
		for event in resolved.events:
			if event.kind == "enemy_hazard_release": release_events.append(event)
		expect(release_events.size() == 1 and resolved.hits.size() == 1 and b.hazards.is_empty(), kind + " hazard event coincides with one actual impact")
		if not release_events.is_empty():
			var event: Dictionary = release_events[0]
			expect(event.id == source.id and event.action_serial == 19 and event.geometry.attack_step == 2 and event.geometry.phase == "active", kind + " release carries source/step and active geometry")
			hazard.origin = Vector2.ZERO
			expect(event.geometry.origin == b.position, kind + " event geometry retains an independent snapshot")
		var later: Dictionary = S.step(b.enemies, b.position, 0.1, {"hazards":b.hazards, "config":b.director.config})
		var repeats := 0
		for event in later.events:
			if event.kind == "enemy_hazard_release": repeats += 1
		expect(repeats == 0 and later.hits.is_empty(), kind + " removed hazard cannot repeat release")
		b.hazards.append(hazard); source.dead = true
		var cancelled: Dictionary = S.step(b.enemies, b.position, 0.1, {"hazards":b.hazards, "config":b.director.config})
		expect(cancelled.events.is_empty() and cancelled.hits.is_empty(), kind + " source cancellation does not invent a release")
		b._finish("failed")
