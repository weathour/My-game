extends SceneTree
## Independent owner cases, real authored ordinary AI, and real poison path veto.
const CAMERA := preload("res://scripts/ui/chronicle/boss_camera.gd")
const BATTLE := preload("res://scripts/battle/battle_session.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const E := preload("res://scripts/battle/enemy_system.gd")
const GEOMETRY := preload("res://scripts/battle/enemy_geometry.gd")
const HURTBOX := preload("res://scripts/battle/player_hurtbox.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
const DT := 1.0 / 60.0
var checks := 0
var failures := 0
var measured_frames := 0
var evidence: Array = []

func _init() -> void: call_deferred("run")

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func battle() -> RefCounted:
	return BATTLE.new({"attempt_id":"camera-mob-framing", "members":["JIA"], "characters":{"JIA":C.record("JIA")}, "equipment":{"weapon":"plain_blade", "armor":"cloth_armor", "accessory":"ember_seal"}, "stage":C.stage("B17"), "seed":1717, "node":{"id":"B17"}})

func spawn(b: RefCounted, id: String, offset: Vector2 = Vector2.ZERO) -> RefCounted:
	var enemy: RefCounted = b.director.spawn(id, SPACE.CENTER + offset)
	b.enemies.append(enemy)
	return enemy

func source_map(b: RefCounted) -> Dictionary:
	var result := {}
	for enemy in b.enemies: result[enemy.id] = enemy
	return result

func disc(owner: int, origin: Vector2, radius: float = 80.0) -> Dictionary:
	return {"owner_id":owner, "shape":"disc", "origin":origin, "radius":radius, "remaining":1.1, "total":1.1, "phase":"tell", "damage":20.0, "warning_policy":"area"}

func readonly_state(b: RefCounted) -> PackedByteArray:
	var bodies: Array = []
	for enemy in b.enemies:
		var fields := {}
		for property in enemy.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				var value: Variant = enemy.get(property.name)
				fields[property.name] = value.get_instance_id() if value is Object and value != null else value
		bodies.append(fields)
	return var_to_bytes([b.position, bodies, b.telegraphs, b.hazards, b.projectiles, b.pending_patterns, b.events, b.director.elapsed, b.director.rng.state, b.director.config, b.current().hp, b.current().mp, b.current().cooldowns, b._skill_intents, b._switch_intent, b.cast_serial, b.enemy_slow])

func check_owners() -> void:
	var b := battle()
	var boss := spawn(b, "B10")
	var elite := spawn(b, "L03")
	for id in ["E03", "E10", "E12", "D01", "D03", "D05"]:
		var ordinary := spawn(b, id)
		ordinary.parent_id = boss.id
		expect(CAMERA.framing_owner({"owner_id":ordinary.id}, source_map(b)) == 0, "ordinary/heavy/object cannot inherit Boss parent: " + id)
	for root_source in [boss, elite]:
		expect(CAMERA.framing_owner({"owner_id":root_source.id}, source_map(b)) == root_source.id, "live elite/Boss qualifies")
	var shared: RefCounted = b.director.derivative({"definition_id":"B10_R", "position":boss.position + Vector2(0,150), "parent_id":boss.id, "hp_owner_id":boss.id}, b.enemies)
	b.enemies.append(shared)
	expect(shared.rank == "proxy" and shared.hp_owner == boss and shared.hp_owner_id == boss.id, "fixture uses real shared HP derivative")
	expect(CAMERA.framing_owner({"owner_id":shared.id}, source_map(b)) == boss.id, "real B10_R resolves to Boss")
	var p := spawn(b, "M03_WAR")
	p.parent_id = elite.id
	expect(CAMERA.framing_owner({"owner_id":p.id}, source_map(b)) == elite.id, "proxy attached to elite qualifies")
	p.parent_id = 0
	p.hp_owner_id = boss.id
	p.hp_owner = elite
	expect(CAMERA.framing_owner({"owner_id":p.id}, source_map(b)) == 0, "unmatched shared HP reference does not confer qualification")
	p.hp_owner = null
	var other := spawn(b, "M04_WAR")
	p.parent_id = other.id
	other.parent_id = p.id
	expect(CAMERA.framing_owner({"owner_id":p.id}, source_map(b)) == 0, "cyclic proxy chain rejected")
	other.parent_id = boss.id
	expect(CAMERA.framing_owner({"owner_id":p.id}, source_map(b)) == boss.id, "finite proxy chain reaches actual source")
	p.dead = true
	expect(CAMERA.framing_owner({"owner_id":p.id}, source_map(b)) == 0, "dead proxy rejected")
	boss.dead = true
	expect(CAMERA.framing_owner({"owner_id":shared.id}, source_map(b)) == 0, "dead shared source rejected")
	for descriptor in [{}, {"owner_id":0}, {"owner_id":-1}, {"owner_id":999999}]:
		expect(CAMERA.framing_owner(descriptor, source_map(b)) == 0, "unknown/missing source fails closed")
	# Break the intentionally cyclic fixture references before retirement.
	p.hp_owner = null
	shared.hp_owner = null

func check_envelopes() -> void:
	var b := battle()
	var elite := spawn(b, "L03")
	var ordinary := spawn(b, "E03")
	var tell := disc(elite.id, HURTBOX.center(b.position))
	var wide := disc(ordinary.id, HURTBOX.center(b.position), 700)
	for dimensions in [Vector2(960,540), Vector2(1280,720), Vector2(1920,1080)]:
		for comfort in [false, true]:
			b.telegraphs = [tell]
			var reference := CAMERA.new()
			reference.update(b, dimensions, DT, comfort)
			expect(reference.mode == "warning" and reference.escape_valid, "elite area retains functional warning/escape")
			var plain := reference.snapshot()
			b.telegraphs = [tell, wide]
			var mixed := CAMERA.new()
			var before := readonly_state(b)
			mixed.update(b, dimensions, DT, comfort)
			expect(mixed.snapshot() == plain, "ordinary huge outline cannot expand mixed elite envelope")
			expect(readonly_state(b) == before, "framing query is read only")
			var old_exit: Vector2 = reference.safe_route[1]
			var poison := disc(ordinary.id, HURTBOX.center(old_exit), 30)
			poison.phase = "active"
			poison.kind = "pot"
			b.hazards = [poison]
			var blocked := CAMERA.new()
			blocked.update(b, dimensions, DT, comfort)
			expect(blocked.mode == "warning" and blocked.escape_needed, "eligible tell still drives mixed poison avoidance")
			expect(blocked._escape_active.size() == 1 and blocked._escape_dangers.size() == 1, "ordinary poison is only a blocker, never framing danger")
			expect(not blocked.escape_valid or not blocked.safe_route[1].is_equal_approx(old_exit), "real poison vetoes the formerly selected route")
			if blocked.escape_valid:
				for step in range(1,7):
					expect(not GEOMETRY.contains_actor(poison, b.position.lerp(blocked.safe_route[1], step / 6.0), HURTBOX.RADIUS), "framed path never crosses actual active poison")
			b.telegraphs.clear()
			var alone := CAMERA.new()
			alone.update(b, dimensions, DT, comfort)
			expect(alone.mode == "follow" and alone.zoom == 1 and alone.safe_route.is_empty(), "ordinary active poison alone never drives framing")
			b.hazards.clear()
			var active_elite := tell.duplicate(true)
			active_elite.phase = "active"
			b.hazards = [active_elite]
			var active_camera := CAMERA.new()
			active_camera.update(b, dimensions, DT, comfort)
			expect(active_camera.mode == "warning" and active_camera.escape_needed, "elite active area still drives framing")
			b.hazards.clear()
			var zero := tell.duplicate(true)
			zero.damage = 0
			b.telegraphs = [zero]
			var harmless := CAMERA.new()
			harmless.update(b, dimensions, DT, comfort)
			expect(harmless.mode == "follow" and harmless.zoom == 1, "zero-damage eligible descriptor remains harmless")

func check_real_ai(id: String, count: int, radius: float, moving: bool) -> void:
	var b := battle()
	var empty := battle()
	for index in count:
		spawn(b, id, Vector2.from_angle(TAU * index / count + .21) * radius)
	var camera := CAMERA.new()
	var follow := CAMERA.new()
	var tells := 0
	var releases := 0
	var pots := 0
	var max_difference := 0.0
	for frame in 600:
		var time := (frame + 1) * DT
		b.position = SPACE.CENTER + Vector2(sin(time * .65) * 180, 0) if moving else SPACE.CENTER
		b.director.elapsed = time
		b._actor_previous_position = b.position
		b.enemy_slow_remaining = maxf(0, b.enemy_slow_remaining - DT)
		if b.enemy_slow_remaining <= 0: b.enemy_slow = 0
		b.spatial.rebuild(b.enemies)
		var hostile: Dictionary = E.step(b.enemies, b.position, DT, {"hazards":b.hazards, "patterns":b.pending_patterns, "spatial":b.spatial, "projectiles":b.projectiles, "actor_previous":b._actor_previous_position, "config":b.director.config, "actor_speed":float(b.current().stats.move) * (1-b.enemy_slow)})
		for derivative in hostile.spawns: b.enemies.append(b.director.derivative(derivative, b.enemies))
		b.projectiles.append_array(hostile.projectiles)
		b._update_projectiles(DT, [], [])
		for event in hostile.events:
			if event.kind == "enemy_tell": tells += 1
			if event.kind in ["enemy_release", "enemy_hazard_release"]: releases += 1
			if event.kind == "enemy_slow": b.enemy_slow = float(event.slow); b.enemy_slow_remaining = float(event.duration)
		for index in range(b.enemies.size()-1,-1,-1):
			if b.enemies[index].dead: b.enemies.remove_at(index)
		b._refresh_telegraphs()
		for hazard in b.hazards:
			if hazard.get("kind", "") == "pot": pots += 1
		var before := readonly_state(b)
		camera.consume(hostile.events)
		camera.update(b, Vector2(1280,720), DT, false, 72, 188)
		camera.update(b, Vector2(1280,720), 0, false, 72, 188)
		empty.position = b.position
		follow.update(empty, Vector2(1280,720), DT, false, 72, 188)
		follow.update(empty, Vector2(1280,720), 0, false, 72, 188)
		expect(camera.snapshot() == follow.snapshot(), id + " actual AI camera equals no-enemy follow frame" + str(frame))
		expect(readonly_state(b) == before, id + " query preserves enemy AI/state/projectiles/events/RNG frame" + str(frame))
		expect(camera.mode == "follow" and camera.zoom == 1 and not camera.escape_needed and camera.safe_route.is_empty(), id + " ordinary follow/zoom1 frame" + str(frame))
		max_difference = maxf(max_difference, camera.origin.distance_to(follow.origin))
		measured_frames += 1
	expect(tells > 0 and releases > 0, id + " fixture actually executes authored tells and releases")
	if id == "E06": expect(pots > 0, "actual ordinary pot persists without camera framing")
	var row := {"id":id, "moving":moving, "frames":600, "tells":tells, "releases":releases, "pot_frames":pots, "max_follow_difference":max_difference}
	evidence.append(row)
	print("ORDINARY_CAMERA_CASE ", JSON.stringify(row))

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated user data")
	check_owners()
	check_envelopes()
	for spec in [["E03",8,350.0],["E10",4,420.0],["E12",4,200.0],["E06",7,420.0],["E02",7,420.0],["E05",7,420.0]]:
		for moving in [false,true]: check_real_ai(spec[0], spec[1], spec[2], moving)
	print("CHRONICLE_CAMERA_MOB_FRAMING_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=",checks," failures=",failures," cases=",evidence.size()," frames=",measured_frames)
	quit(0 if failures == 0 else 1)
