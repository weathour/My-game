extends RefCounted
const SPACE := preload("res://scripts/battle/battle_space.gd")
const GEOMETRY := preload("res://scripts/battle/enemy_geometry.gd")

static func step(enemies: Array, actor: Vector2, delta: float, world: Dictionary = {}) -> Dictionary:
	var result := {"hits":[], "projectiles":[], "effects":[], "spawns":[], "events":[], "hit_sources":[]}
	var hazards: Array = world.get("hazards", [])
	var config: Dictionary = world.get("config", {})
	var used := {"major":0, "melee":0}
	for enemy in enemies:
		if enemy.phase_change_pending:
			result.events.append(phase_event(enemy))
			enemy.phase_change_pending = false
			for i in range(hazards.size() - 1, -1, -1):
				if int(hazards[i].owner_id) == enemy.id: hazards.remove_at(i)
			for child in enemies:
				if child.parent_id == enemy.id and not child.targetable:
					child.dead = true; child.death_reason = "source_cancel"
	for hazard in hazards:
		if hazard.phase == "tell": used.major += 1
	for enemy in enemies:
		if not enemy.dead and (enemy.windup > 0 or enemy.active_remaining > 0): used[_budget(enemy.current_action)] += 1
	_update_hazards(hazards, enemies, actor, delta, result)
	for enemy in enemies:
		if enemy.dead: continue
		enemy.age += delta
		if enemy.behavior_id == "E04":
			var was_guarding: bool = enemy.guard_active
			enemy.guard_active = fmod(enemy.age, float(enemy.params.get("guard_duration", 2.6)) + 1.4) < float(enemy.params.get("guard_duration", 2.6))
			if enemy.guard_active and not was_guarding: enemy.aim = (actor - enemy.position).normalized()
		enemy.flash = maxf(0, enemy.flash - delta)
		enemy.slow_time = maxf(0, enemy.slow_time - delta)
		if enemy.slow_time <= 0: enemy.slow = 0
		enemy.command_remaining = maxf(0, enemy.command_remaining - delta)
		enemy.rule_cooldown = maxf(0, enemy.rule_cooldown - delta)
		enemy.protection_remaining = maxf(0, enemy.protection_remaining - delta)
		if enemy.protection_remaining > 0:
			var linked := false
			for child in enemies:
				if child.parent_id == enemy.id and not child.dead and child.definition_id == "D01" and child.position.distance_to(enemy.position) <= 220: linked = true
			if not linked: enemy.protection_remaining = 0
		if enemy.advance_form(delta): continue
		if not enemy.initialized:
			enemy.initialized = true
			_initialize(enemy, enemies, result, config)
		if enemy.definition_id == "D05":
			if enemy.age >= 2.0:
				enemy.dead = true; enemy.death_reason = "hatched"
				result.spawns.append({"definition_id":"D01", "position":enemy.position, "parent_id":enemy.parent_id})
			continue
		if not enemy.targetable and enemy.age >= float(enemy.params.get("lifetime", 1.6)):
			enemy.dead = true; enemy.death_reason = "expired"
		if enemy.rank == "object" or not enemy.targetable: continue
		if enemy.elite_rule_id == "L03" and enemy.rule_cooldown <= 0:
			for escort in enemies:
				if not escort.dead and escort.parent_id == enemy.id and escort.definition_id == "D01" and escort.position.distance_to(enemy.position) <= 220:
					enemy.protection_remaining = 5; enemy.rule_cooldown = 8; break
		if enemy.behavior_id == "J" and enemy.form_count == 1:
			var next_phase := 2 if enemy.hp <= enemy.max_hp * 0.35 else 1 if enemy.hp <= enemy.max_hp * 0.70 else 0
			if next_phase != enemy.phase:
				enemy.phase = next_phase
				result.events.append({"kind":"boss_phase", "id":enemy.id, "phase":next_phase})
		if enemy.active_remaining > 0:
			_advance_charge(enemy, actor, delta, enemies, result)
			continue
		# A committed warning never follows the controlled actor.
		if enemy.windup > 0:
			enemy.windup = maxf(0, enemy.windup - delta)
			if not enemy.telegraph.is_empty(): enemy.telegraph.remaining = enemy.windup
			if enemy.windup <= 0: _release(enemy, actor, enemies, hazards, result, config)
			continue
		enemy.cooldown = maxf(0, enemy.cooldown - delta)
		if enemy.cooldown > 0:
			enemy.state = "recovery"
			continue
		enemy.state = "approach"
		if enemy.definition_id in ["B10", "B10_R"]:
			var owner: RefCounted = enemy.damage_owner()
			if int(owner.params.get("turn_body", owner.id)) != enemy.id:
				_move(enemy, actor, enemies, delta, 100)
				continue
		var action := _next_action(enemy)
		if str(action.get("action", "")) == "collaboration":
			if int(enemy.params.get("collaboration_index", 0)) % 2 == 0:
				action.shape = "line"; action.length = float(action.get("length", 280.0)); action.half_width = float(action.get("half_width", 36.0)); action.collaborator = "M03_WAR"
			else: action.shape = "marker"; action.radius = float(action.get("radius", 90.0)); action.collaborator = "M04_WAR"
		var distance: float = enemy.position.distance_to(actor)
		if enemy.behavior_id == "E08" and distance > float(action.get("range", 70)):
			action = enemy.actions[0].duplicate(true)
		var range_value := float(action.get("range", 70))
		if str(action.get("action", "")) == "command" and _followers(enemy, enemies).is_empty():
			action = {"action":"swipe", "id":"command_fallback_swipe", "shape":"sector", "range":enemy.radius + 38, "radius":enemy.radius + 38, "spread":1.8, "windup":0.6, "recovery":1.6, "damage_scale":1.0, "major":false}
			range_value = float(action.range)
		var category := _budget(action)
		var budget: Dictionary = config.get("action_budget", {"major":1, "melee":2})
		if (distance <= range_value or str(action.get("action", "")) == "heal") and int(used[category]) < int(budget.get(category, 1 if category == "major" else 2)):
			if enemy.behavior_id == "F":
				var anchors := 0
				for child in enemies:
					if child.parent_id == enemy.id and child.definition_id == "D03" and not child.dead: anchors += 1
				action.gap_width = 1.4 + (2 - anchors) * 0.5
			var geometry := GEOMETRY.descriptor(enemy, action, actor)
			if category != "major" or str(action.get("action", "")) in ["command", "heal", "summon"] or _has_exit(geometry, enemies, hazards, actor, float(world.get("actor_speed", 215))):
				enemy.action_serial += 1
				geometry.action_serial = enemy.action_serial
				if str(action.get("action", "")) in ["heal", "command"]:
					geometry.beneficiaries = []
					var recipients: Array = _heal_targets(enemy, enemies, float(enemy.params.get("heal_radius", 230))) if str(action.get("action", "")) == "heal" else _followers(enemy, enemies)
					for follower in recipients: geometry.beneficiaries.append(follower.id)
				if str(action.get("action", "")) == "collaboration":
					var human_collaborator: bool = enemy.form_count > 1 and enemy.form_index == 0
					var collaborator_height := (128.0 if str(action.collaborator) == "M03_WAR" else 120.0) if human_collaborator else (200.0 if str(action.collaborator) == "M03_WAR" else 190.0)
					result.spawns.append({"definition_id":str(action.collaborator), "position":enemy.position + Vector2(80, -50), "parent_id":enemy.id, "lifetime":float(action.get("windup", 1.4)) + float(action.get("recovery", 2.5)),
						"visual_id":str(action.collaborator).replace("_WAR", "_human") if human_collaborator else str(action.collaborator), "body_height":collaborator_height})
				enemy.current_action = action
				enemy.telegraph = geometry
				enemy.aim = geometry.direction
				enemy.attack = str(action.get("action", action.get("id", "swipe")))
				enemy.windup = float(geometry.total)
				enemy.state = "tell"
				enemy.attack_index += 1
				used[category] += 1
				result.events.append({"kind":"enemy_tell", "id":enemy.id, "action_serial":enemy.action_serial})
				continue
		_move(enemy, actor, enemies, delta, range_value)
	return result

static func _budget(action: Dictionary) -> String:
	return "major" if bool(action.get("major", str(action.get("action", "")) not in ["swipe", "strike", "shot"])) else "melee"

static func _next_action(enemy: RefCounted) -> Dictionary:
	if enemy.behavior_id == "J" and enemy.form_count == 1 and not enemy.actions.is_empty():
		var pattern: Array = [0, 1] if enemy.phase == 0 else [0, 1, 0, 2] if enemy.phase == 1 else [0, 1, 0, 1, 2]
		var step_index: int = enemy.attack_index % pattern.size()
		var action: Dictionary = enemy.actions[int(pattern[step_index]) % enemy.actions.size()].duplicate(true)
		action.combo_step = step_index
		action.combo_length = pattern.size()
		action.combo_final = step_index == pattern.size() - 1
		action.recovery = (2.0 + enemy.phase * 0.25) if action.combo_final else (0.9 - enemy.phase * 0.1)
		return action
	if not enemy.actions.is_empty():
		return enemy.actions[enemy.attack_index % enemy.actions.size()].duplicate(true)
	var legacy: String = enemy.attack_cycle[enemy.attack_index % enemy.attack_cycle.size()]
	return {"action":legacy, "shape":"line" if legacy == "charge" else "disc" if legacy == "nova" else "fan" if legacy in ["shot", "fan"] else "sector", "range":enemy.blast_radius + 20 if legacy == "nova" else enemy.attack_range, "radius":enemy.blast_radius if legacy == "nova" else enemy.radius + 28, "windup":1.15 if legacy == "nova" else enemy.attack_delay, "recovery":enemy.recovery, "count":5 if legacy == "fan" else 1, "spread":1.15, "length":240, "damage_scale":1.2 if legacy == "nova" else 1.0}

static func _move(enemy: RefCounted, actor: Vector2, enemies: Array, delta: float, reach: float) -> void:
	if enemy.behavior_id == "E08": return # A shrine stays anchored; kiting breaks its coverage.
	var gap: Vector2 = actor - enemy.position
	if enemy.behavior_id in ["E02", "E05", "E06", "G"] and gap.length() < minf(220, reach * 0.75): return
	var movement := gap.normalized()
	for other in enemies:
		if other == enemy or other.dead or not other.targetable: continue
		var offset: Vector2 = enemy.position - other.position
		if offset.length_squared() > 0.01 and offset.length_squared() < pow(enemy.radius + other.radius, 2): movement += offset.normalized() * 0.55
	var boost := 1.15 if enemy.command_remaining > 0 else 1.0
	enemy.position = SPACE.clamp_point(enemy.position + movement.limit_length(1) * enemy.speed * boost * (1 - enemy.slow) * delta, Vector2.ONE * enemy.radius)

static func _has_exit(proposed: Dictionary, enemies: Array, hazards: Array, actor: Vector2, actor_speed: float = 215.0) -> bool:
	# Reachability is bounded by the actual tell duration and movement speed.
	# A player may leave the proposed warning during its tell; active hazards
	# must also be avoided along the route, rather than only at its endpoint.
	var travel := maxf(0, actor_speed) * maxf(0, float(proposed.get("remaining", 0.9))) * 0.92
	for ring in [0.0, 0.5, 0.8, 1.0]:
		for i in 32:
			var point: Vector2 = actor + Vector2.RIGHT.rotated(i * TAU / 32) * travel * float(ring)
			if SPACE.clamp_point(point, SPACE.PLAYER_MARGIN).distance_to(point) > 1: continue
			if GEOMETRY.contains(proposed, point): continue
			var safe := true
			for other in enemies:
				if other.dead or other.telegraph.is_empty() or other.state not in ["tell", "active"]: continue
				if GEOMETRY.contains(other.telegraph, point): safe = false; break
			if safe:
				for hazard in hazards:
					if str(hazard.get("kind", "")) == "slow_strip": continue
					for sample in range(1, 9):
						if GEOMETRY.contains(hazard, actor.lerp(point, sample / 8.0)): safe = false; break
					if not safe: break
			if safe: return true
	return false

static func _initialize(enemy: RefCounted, enemies: Array, result: Dictionary, config: Dictionary) -> void:
	if enemy.elite_rule_id == "L02" or enemy.behavior_id == "F":
		for i in 2:
			if _derivative_room(enemies, result, config) > 0:
				result.spawns.append({"definition_id":"D03", "position":enemy.position + Vector2(0, -100 if i == 0 else 100), "parent_id":enemy.id})
	if enemy.elite_rule_id == "L03" and _derivative_room(enemies, result, config) > 0: result.spawns.append({"definition_id":"D01", "position":enemy.position + Vector2(75, 0), "parent_id":enemy.id})
	if enemy.definition_id == "B10": result.spawns.append({"definition_id":"B10_R", "position":enemy.position + Vector2(0, 150), "parent_id":enemy.id, "hp_owner_id":enemy.id})

static func _release(enemy: RefCounted, actor: Vector2, enemies: Array, hazards: Array, result: Dictionary, config: Dictionary) -> void:
	var action: Dictionary = enemy.current_action
	if action.is_empty():
		# Preserve the public legacy-fixture seam without replacing authored actions.
		action = {"action":enemy.attack, "shape":"line" if enemy.attack == "charge" else "disc", "range":enemy.attack_range, "radius":enemy.blast_radius if enemy.attack == "nova" else enemy.radius + 28, "length":240, "windup":enemy.attack_delay, "recovery":enemy.recovery, "damage_scale":1.2 if enemy.attack == "nova" else 1.0}
		if enemy.telegraph.is_empty(): enemy.telegraph = GEOMETRY.descriptor(enemy, action, enemy.position + enemy.aim * 100)
	var geometry: Dictionary = enemy.telegraph.duplicate(true)
	geometry.phase = "active"
	enemy.cooldown = float(action.get("recovery", 1.6))
	enemy.state = "recovery"
	enemy.telegraph = {}
	var kind := str(action.get("action", action.get("id", "swipe")))
	match kind:
		"shot", "fan":
			var count := int(action.get("count", 5 if kind == "fan" else 1))
			var spread := float(action.get("spread", 1.15))
			if enemy.elite_rule_id == "L02":
				var anchors := 0
				for child in enemies:
					if child.parent_id == enemy.id and child.definition_id == "D03" and not child.dead: anchors += 1
				count = 1 + anchors * 2
			for i in count:
				var angle := (float(i) / maxf(1, count - 1) - 0.5) * spread if count > 1 else 0.0
				var direction: Vector2 = enemy.aim.rotated(angle)
				result.projectiles.append({"position":geometry.origin, "velocity":direction * float(action.get("speed", 225)), "life":minf(float(action.get("range", 400)) / float(action.get("speed", 225)), minf(3, float(action.get("life", 2.5)))), "hostile":true, "move_id":str(action.get("id", kind)), "damage":geometry.damage, "source":enemy.id, "source_id":enemy.id, "visual_id":enemy.visual_id, "hit_radius":5.0})
		"heal": _heal(enemy, enemies, float(enemy.params.get("heal_radius", 230)), geometry.get("beneficiaries", []))
		"command":
			var count := 0
			for follower in _followers(enemy, enemies):
				if count >= 3: break
				if not follower.id in geometry.get("beneficiaries", []): continue
				if follower == enemy or follower.dead or follower.rank not in ["ordinary", "heavy"] or follower.parent_id > 0: continue
				if follower.position.distance_to(enemy.position) > 300: continue
				follower.command_remaining = 4; follower.cooldown = minf(follower.cooldown, 0.4); count += 1
			# No command ever deals area damage. Empty rosters use a new short-swipe tell.
		"summon": _summon(enemy, action, enemies, result, config)
		"anchor":
			# Anchors alter the pulse opening but never grant immunity.
			var anchors := 0
			for child in enemies:
				if not child.dead and child.parent_id == enemy.id and child.definition_id == "D03": anchors += 1
			geometry.shape = "ring_gap" # The opening was frozen at warning admission.
			if GEOMETRY.contains(geometry, actor): _record_hit(result, geometry)
		"pot":
			for i in range(hazards.size() - 1, -1, -1):
				if hazards[i].owner_id == enemy.id and str(hazards[i].get("kind", "")) == "pot": hazards.remove_at(i)
			geometry.kind = "pot"; geometry.remaining = float(action.get("duration", 3)); geometry.total = geometry.remaining; geometry.until = 0.5; geometry.interval = 0.7; geometry.phase = "active"
			hazards.append(geometry)
		"collaboration":
			var visual := str(action.get("collaborator", "M03_WAR"))
			enemy.params.collaboration_index = int(enemy.params.get("collaboration_index", 0)) + 1
			result.events.append({"kind":"collaboration", "id":enemy.id, "visual_id":visual, "origin":geometry.origin, "duration":1.6})
			if visual == "M03_WAR":
				if GEOMETRY.contains(geometry, actor): _record_hit(result, geometry)
				if enemy.form_count == 1: _summon(enemy, {"spawn_id":"D01", "spawn_count":2, "limit":4}, enemies, result, config)
			else:
				var array_tell: Dictionary = geometry.duplicate(true)
				array_tell.phase = "tell"; array_tell.kind = "collaboration_array"; array_tell.remaining = 0.9; array_tell.total = 0.9
				hazards.append(array_tell)

		_:
			if kind == "charge":
				enemy.active_total = clampf(float(geometry.length) / 780.0, 0.28, 0.65)
				enemy.active_remaining = enemy.active_total; enemy.active_hit = false
				geometry.remaining = enemy.active_total; geometry.total = enemy.active_total
				enemy.telegraph = geometry; enemy.state = "active"
			elif GEOMETRY.contains(geometry, actor): _record_hit(result, geometry)
			if kind == "hook":
				geometry.kind = "slow_strip"; geometry.remaining = minf(2, float(action.get("duration", 1.5))); geometry.total = geometry.remaining; geometry.until = 0.0; geometry.interval = 0.3; geometry.slow = float(action.get("slow", 0.25)); geometry.phase = "active"
				hazards.append(geometry)
	# Every delayed hit has a fresh warning; echo cannot recursively reproduce itself.
	if enemy.elite_rule_id in ["L05", "L06"]:
		var copies := 0
		for hazard in hazards:
			if hazard.owner_id == enemy.id and hazard.phase == "tell": copies += 1
		if copies < (2 if enemy.elite_rule_id == "L06" else 1):
			var echo: Dictionary = geometry.duplicate(true)
			if enemy.elite_rule_id == "L06": echo.shape = "marker"; echo.origin = actor; echo.radius = 55.0
			echo.phase = "tell"; echo.kind = "echo"; echo.remaining = maxf(0.8, float(enemy.params.get("echo_delay", enemy.params.get("marker_delay", 0.9)))); echo.total = echo.remaining; echo.one_shot = true
			hazards.append(echo)
	if enemy.rank == "boss" and kind not in ["heal", "command", "summon"]:
		result.events.append({"kind":"boss_impact", "id":enemy.id, "enemy_id":enemy.id, "position":geometry.origin, "phase":enemy.form_index, "form_index":enemy.form_index, "action_id":str(action.get("id", kind)), "action_serial":enemy.action_serial, "geometry":geometry.duplicate(true)})
	if kind != "charge": _shared_recovery(enemy, enemies)
	result.events.append({"kind":"enemy_release", "id":enemy.id, "action_serial":enemy.action_serial, "geometry":geometry.duplicate(true)})
	result.effects.append({"kind":"enemy_buff" if kind in ["heal", "command", "summon"] else "line" if geometry.shape == "line" else "ring", "origin":geometry.origin, "end":geometry.origin + geometry.direction * float(geometry.length), "radius":geometry.radius, "life":0.3, "hostile":kind not in ["heal", "command", "summon"], "visual_id":enemy.visual_id})

static func _heal_targets(enemy: RefCounted, enemies: Array, reach: float) -> Array:
	var result: Array = []
	for target in enemies:
		if result.size() >= 2: break
		if target.dead or target.rank not in ["ordinary", "heavy"] or target.behavior_id == "E08" or target.parent_id > 0: continue
		if target.position.distance_to(enemy.anchor_position) > reach: continue
		if target.hp >= target.max_hp or target.healing_received >= target.max_hp * 0.15: continue
		result.append(target)
	return result

static func _heal(enemy: RefCounted, enemies: Array, reach: float, locked_ids: Array = []) -> void:
	for target in _heal_targets(enemy, enemies, reach):
		if not locked_ids.is_empty() and target.id not in locked_ids: continue
		var amount := minf(target.max_hp * 0.04, minf(target.max_hp - target.hp, target.max_hp * 0.15 - target.healing_received))
		if amount <= 0: continue
		target.hp += amount; target.healing_received += amount

static func _summon(enemy: RefCounted, action: Dictionary, enemies: Array, result: Dictionary, config: Dictionary) -> void:
	if bool(enemy.params.get("solo", false)): return
	var room := _derivative_room(enemies, result, config)
	var limit := int(action.get("limit", 4))
	var count := mini(int(action.get("spawn_count", 2)), mini(limit - enemy.spawned_total, room))
	for i in maxi(0, count):
		var spawn_id := str(action.get("spawn_id", "D05" if enemy.behavior_id == "E11" or enemy.elite_rule_id == "L04" else "D01"))
		result.spawns.append({"definition_id":spawn_id, "position":SPACE.clamp_point(enemy.position + Vector2.RIGHT.rotated((enemy.spawned_total + i) * 2.4) * 70, Vector2(30, 30)), "parent_id":enemy.id})
		enemy.spawned_total += 1

static func _update_hazards(hazards: Array, enemies: Array, actor: Vector2, delta: float, result: Dictionary) -> void:
	for i in range(hazards.size() - 1, -1, -1):
		var hazard: Dictionary = hazards[i]
		var alive := false
		for source in enemies:
			if source.id == int(hazard.owner_id) and not source.dead: alive = true; break
		if not alive: hazards.remove_at(i); continue
		hazard.remaining -= delta
		if hazard.phase == "tell":
			if hazard.remaining <= 0:
				if GEOMETRY.contains(hazard, actor): _record_hit(result, hazard)
				var released_geometry: Dictionary = hazard.duplicate(true)
				released_geometry.phase = "active"
				result.events.append({"kind":"enemy_hazard_release", "id":int(hazard.owner_id), "action_serial":int(hazard.get("action_serial", 0)), "geometry":released_geometry})
				hazards.remove_at(i)
		else:
			hazard.until -= delta
			if hazard.until <= 0 and hazard.remaining > 0:
				if GEOMETRY.contains(hazard, actor):
					if str(hazard.get("kind", "")) == "slow_strip": result.events.append({"kind":"enemy_slow", "duration":0.4, "slow":float(hazard.get("slow", 0.25))})
					else: _record_hit(result, hazard)
				hazard.until += hazard.interval
			if hazard.remaining <= 0: hazards.remove_at(i)

static func _followers(enemy: RefCounted, enemies: Array) -> Array:
	var result: Array = []
	for follower in enemies:
		if follower == enemy or follower.dead or follower.rank not in ["ordinary", "heavy"] or follower.parent_id > 0: continue
		if follower.position.distance_to(enemy.position) <= 300: result.append(follower)
		if result.size() >= 3: break
	return result

static func _derivative_room(enemies: Array, result: Dictionary, config: Dictionary) -> int:
	var live := 0
	var boss_present := false
	for child in enemies:
		if not child.dead and child.parent_id > 0 and child.targetable and child.rank != "proxy": live += 1
		if not child.dead and child.rank == "boss": boss_present = true
	for pending in result.spawns:
		if str(pending.definition_id) in ["D01", "D03", "D05"]: live += 1
	return maxi(0, int(config.get("boss_derivative_cap", 4) if boss_present else config.get("derivative_cap", 6)) - live)

static func _shared_recovery(enemy: RefCounted, enemies: Array) -> void:
	if enemy.definition_id not in ["B10", "B10_R"]: return
	var owner: RefCounted = enemy.damage_owner()
	var next_id: int = owner.id if enemy.id != owner.id else int(owner.params.get("partner_body", owner.id))
	owner.params.turn_body = next_id
	for body in enemies:
		if body.damage_owner() == owner:
			body.cooldown = enemy.cooldown
			body.state = "recovery"

static func _advance_charge(enemy: RefCounted, actor: Vector2, delta: float, enemies: Array, result: Dictionary) -> void:
	var start: Vector2 = enemy.position
	enemy.active_remaining = maxf(0, enemy.active_remaining - delta)
	var progress: float = 1 - enemy.active_remaining / maxf(0.001, enemy.active_total)
	var g: Dictionary = enemy.telegraph
	enemy.position = g.origin + g.direction * float(g.length) * progress
	g.remaining = enemy.active_remaining
	var swept := {"shape":"line", "origin":start, "direction":g.direction, "length":start.distance_to(enemy.position), "half_width":g.half_width}
	if not enemy.active_hit and GEOMETRY.contains(swept, actor):
		_record_hit(result, g); enemy.active_hit = true
	if enemy.active_remaining <= 0:
		enemy.telegraph = {}; enemy.state = "recovery"
		_shared_recovery(enemy, enemies)

static func phase_event(enemy: RefCounted) -> Dictionary:
	return {"kind":"boss_phase", "id":enemy.id, "enemy_id":enemy.id, "position":enemy.position, "phase":enemy.form_index,
		"form_index":enemy.form_index, "form_count":enemy.form_count, "form_name":enemy.form_name, "transition_remaining":enemy.transition_remaining}

static func _record_hit(result: Dictionary, geometry: Dictionary) -> void:
	result.hits.append(float(geometry.damage))
	result.hit_sources.append({"enemy_id":int(geometry.get("owner_id", 0)), "attack":str(geometry.get("move_id", geometry.get("action_id", ""))), "position":geometry.get("origin", Vector2.ZERO)})
