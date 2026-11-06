extends RefCounted
const PATTERNS := preload("res://scripts/battle/projectile_patterns.gd")
const SPATIAL := preload("res://scripts/battle/enemy_spatial_grid.gd")
const HURTBOX := preload("res://scripts/battle/player_hurtbox.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
const GEOMETRY := preload("res://scripts/battle/enemy_geometry.gd")

static func step(enemies: Array, actor: Vector2, delta: float, world: Dictionary = {}) -> Dictionary:
	var result := {"hits":[], "projectiles":[], "effects":[], "spawns":[], "events":[], "hit_sources":[], "configuration_errors":[]}
	var hazards: Array = world.get("hazards", [])
	var config: Dictionary = world.get("config", {})
	var pending: Array=world.get("patterns",[])
	var grid: RefCounted=world.get("spatial")
	if grid==null: grid=SPATIAL.new();grid.rebuild(enemies)
	var hostile_count:=0
	for projectile in world.get("projectiles",[]):
		if bool(projectile.get("hostile",false)): hostile_count+=1
	result.projectile_room=maxi(0,int(config.get("projectile_cap",1200))-hostile_count)
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
	var major_groups: Dictionary={}
	for hazard in hazards:
		if hazard.phase=="tell": major_groups[str(hazard.owner_id)+":"+str(hazard.get("action_serial",0))]=true
	for enemy in enemies:
		if not enemy.dead and (enemy.windup>0 or enemy.active_remaining>0):
			if _budget(enemy.current_action)=="major": major_groups[str(enemy.id)+":"+str(enemy.action_serial)]=true
			else: used.melee+=1
	used.major=major_groups.size()
	PATTERNS.advance(pending,enemies,HURTBOX.center(actor),delta,result)
	_update_hazards(hazards, enemies, actor, delta, result)
	for enemy in enemies:
		if enemy.dead: continue
		enemy.age += delta
		if enemy.behavior_id == "E04":
			var was_guarding: bool = enemy.guard_active
			enemy.guard_active = fmod(enemy.age, float(enemy.params.get("guard_duration", 2.6)) + 1.4) < float(enemy.params.get("guard_duration", 2.6))
			if enemy.guard_active and not was_guarding: enemy.aim = (actor - enemy.position).normalized()
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
		if enemy.active_remaining > 0:
			_advance_charge(enemy, actor, delta, enemies, result,world.get("actor_previous",actor))
			continue
		# A committed warning never follows the controlled actor.
		if enemy.windup > 0:
			enemy.windup = maxf(0, enemy.windup - delta)
			if not enemy.telegraph.is_empty(): enemy.telegraph.remaining = enemy.windup
			if enemy.windup <= 0: _release(enemy, actor, enemies, hazards, result, config,pending)
			continue
		enemy.cooldown = maxf(0, enemy.cooldown - delta)
		if enemy.cooldown > 0:
			enemy.state = "recovery"
			continue
		enemy.state = "approach"
		if enemy.definition_id in ["B10", "B10_R"]:
			var owner: RefCounted = enemy.damage_owner()
			if int(owner.params.get("turn_body", owner.id)) != enemy.id:
				_move(enemy, actor, enemies, delta, 100,grid)
				continue
		var action := _next_action(enemy)
		if action.is_empty():
			result.configuration_errors.append("Enemy %s has no authored attacks" % enemy.definition_id)
			continue
		if str(action.get("action", "")) == "collaboration":
			if int(enemy.params.get("collaboration_index", 0)) % 2 == 0:
				action.shape = "line"; action.length = float(action.get("length", 280.0)); action.half_width = float(action.get("half_width", 36.0)); action.collaborator = "M03_WAR"
			else: action.shape = "marker"; action.radius = float(action.get("radius", 90.0)); action.collaborator = "M04_WAR"
		var distance: float = enemy.position.distance_to(actor)
		if enemy.behavior_id == "E08" and distance > float(action.get("range", 70)):
			action = enemy.actions[0].duplicate(true)
		var range_value := float(action.get("range", 70))
		if str(action.get("action", "")) == "command" and _followers(enemy, enemies).is_empty():
			action.merge({"action":"swipe", "id":"command_fallback_swipe", "shape":"sector", "range":enemy.radius + 38, "radius":enemy.radius + 38, "spread":1.8, "windup":0.6, "recovery":1.6, "damage_scale":1.0, "major":false},true)
			range_value = float(action.range)
		var category := _budget(action)
		var budget: Dictionary = config.get("action_budget", {"major":1, "melee":2})
		if (distance <= range_value or str(action.get("action", "")) == "heal") and int(used[category]) < int(budget.get(category, 1 if category == "major" else 2)):
			if enemy.behavior_id == "F":
				var anchors := 0
				for child in enemies:
					if child.parent_id == enemy.id and child.definition_id == "D03" and not child.dead: anchors += 1
				action.gap_width = float(action.get("gap_width",1.4)) + (2-anchors)*0.5
			var geometry := GEOMETRY.descriptor(enemy, action, actor)
			geometry.sound_definition_id = enemy.definition_id
			geometry.sound_form_index = enemy.form_index
			geometry.sound_major = bool(action.get("major",false))
			geometry=_marker_series(geometry,action)
			if category != "major" or str(action.get("action", "")) in ["command", "heal", "summon"] or _has_exit(geometry, enemies, hazards, actor, float(world.get("actor_speed", 215)),world.get("projectiles",[])):
				enemy.action_serial += 1
				geometry.action_serial = enemy.action_serial
				for extra: Dictionary in geometry.get("extra_markers",[]):
					extra.action_serial=enemy.action_serial
					extra.owner_id=enemy.id
					hazards.append(extra)
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
				result.events.append(sound_event("enemy_tell",enemy,geometry))
				continue
		_move(enemy, actor, enemies, delta, range_value,grid,float(action.get("approach_speed",enemy.speed)))
	return result

static func _budget(action: Dictionary) -> String:
	return "major" if bool(action.get("major", str(action.get("action", "")) not in ["swipe", "strike", "shot"])) else "melee"

static func _next_action(enemy: RefCounted) -> Dictionary:
	if not enemy.actions.is_empty():
		return enemy.actions[enemy.attack_index % enemy.actions.size()].duplicate(true)
	return {}

static func _move(enemy: RefCounted, actor: Vector2, enemies: Array, delta: float, reach: float, grid: RefCounted = null, approach_speed: float = -1.0) -> void:
	if enemy.behavior_id == "E08": return # A shrine stays anchored; kiting breaks its coverage.
	var gap: Vector2 = actor - enemy.position
	if enemy.behavior_id in ["E02", "E05", "E06", "G"] and gap.length() < minf(220, reach * 0.75): return
	var movement := gap.normalized()
	var neighbors: Array=grid.nearby(enemy) if grid!=null else enemies
	for other in neighbors:
		if other == enemy or other.dead or not other.targetable: continue
		var offset: Vector2 = enemy.position - other.position
		if offset.length_squared() > 0.01 and offset.length_squared() < pow(enemy.radius + other.radius, 2): movement += offset.normalized() * 0.55
	var boost := 1.15 if enemy.command_remaining > 0 else 1.0
	var speed: float = enemy.speed if approach_speed < 0 else approach_speed
	enemy.position = SPACE.clamp_point(enemy.position + movement.limit_length(1) * speed * boost * (1 - enemy.slow) * delta, Vector2.ONE * enemy.radius)
	if grid!=null: grid.moved(enemy)

static func _has_exit(proposed: Dictionary, enemies: Array, hazards: Array, actor: Vector2, actor_speed: float = 215.0, projectiles: Array = []) -> bool:
	# Reachability is bounded by the actual tell duration and movement speed.
	# A player may leave the proposed warning during its tell; active hazards
	# must also be avoided along the route, rather than only at its endpoint.
	var travel := maxf(0, actor_speed) * maxf(0, float(proposed.get("remaining", 0.9))) * 0.92
	for ring in [0.0, 0.5, 0.8, 1.0]:
		for i in 32:
			var point: Vector2 = actor + Vector2.RIGHT.rotated(i * TAU / 32) * travel * float(ring)
			if SPACE.clamp_point(point, SPACE.PLAYER_MARGIN).distance_to(point) > 1: continue
			if not bool(proposed.get("projectile_only",false)) and GEOMETRY.contains_actor(proposed,point): continue
			var extra_blocked:=false
			for extra: Dictionary in proposed.get("extra_markers",[]):
				if GEOMETRY.contains_actor(extra,point): extra_blocked=true;break
			if extra_blocked: continue
			var safe := true
			for other in enemies:
				if other.dead or other.telegraph.is_empty() or other.state not in ["tell", "active"] or bool(other.telegraph.get("projectile_only",false)): continue
				if GEOMETRY.contains_actor(other.telegraph, point): safe = false; break
			if safe:
				for hazard in hazards:
					if str(hazard.get("kind", "")) == "slow_strip": continue
					for sample in range(1, 9):
						if GEOMETRY.contains_actor(hazard, actor.lerp(point, sample / 8.0)): safe = false; break
					if not safe: break
			if safe:
				var duration:=maxf(.001,float(proposed.get("remaining",.9)))
				for bullet: Dictionary in projectiles:
					if not bool(bullet.get("hostile",false)): continue
					var time:=minf(duration,float(bullet.get("life",0)))
					if HURTBOX.contains_swept(bullet.position,Vector2(bullet.position)+Vector2(bullet.velocity)*time,float(bullet.get("hit_radius",5)),actor,actor.lerp(point,time/duration)): safe=false;break
			if safe: return true
	return false

static func _initialize(enemy: RefCounted, enemies: Array, result: Dictionary, config: Dictionary) -> void:
	if enemy.elite_rule_id == "L02" or enemy.behavior_id == "F":
		for i in 2:
			if _derivative_room(enemies, result, config) > 0:
				result.spawns.append({"definition_id":"D03", "position":enemy.position + Vector2(0, -100 if i == 0 else 100), "parent_id":enemy.id})
	if enemy.elite_rule_id == "L03" and _derivative_room(enemies, result, config) > 0: result.spawns.append({"definition_id":"D01", "position":enemy.position + Vector2(75, 0), "parent_id":enemy.id})
	if enemy.definition_id == "B10": result.spawns.append({"definition_id":"B10_R", "position":enemy.position + Vector2(0, 150), "parent_id":enemy.id, "hp_owner_id":enemy.id})

static func _release(enemy: RefCounted, actor: Vector2, enemies: Array, hazards: Array, result: Dictionary, config: Dictionary, pending: Array = []) -> void:
	var action: Dictionary = enemy.current_action
	if action.is_empty() or enemy.telegraph.is_empty():
		result.configuration_errors.append("Enemy %s released without an authored action and warning" % enemy.definition_id)
		return
	var geometry: Dictionary = enemy.telegraph.duplicate(true)
	geometry.phase = "active"
	enemy.cooldown = float(action.get("recovery", 1.6))
	enemy.state = "recovery"
	enemy.telegraph = {}
	var kind := str(action.get("action", action.get("id", "swipe")))
	match kind:
		"shot", "fan":
			var pattern:=PATTERNS.primary(action)
			if enemy.elite_rule_id=="L02":
				var anchors:=0
				for child in enemies:
					if child.parent_id==enemy.id and child.definition_id=="D03" and not child.dead: anchors+=1
				pattern.count=maxi(1,roundi(float(pattern.get("count",5))*(1+anchors*2)/5.0))
			PATTERNS.launch(pattern,_pattern_context(enemy,action,geometry,pattern),pending,HURTBOX.center(actor),result)
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
			if GEOMETRY.contains_actor(geometry, actor): _record_hit(result, geometry)
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
				if GEOMETRY.contains_actor(geometry, actor): _record_hit(result, geometry)
			else:
				var array_tell: Dictionary = geometry.duplicate(true)
				array_tell.phase = "tell"; array_tell.warning_policy="area";array_tell.projectile_only=false;array_tell.kind = "collaboration_array"; array_tell.remaining = 0.9; array_tell.total = 0.9
				hazards.append(array_tell)

		_:
			if kind == "charge":
				enemy.active_total = clampf(float(geometry.length) / 780.0, 0.28, 0.65)
				enemy.active_remaining = enemy.active_total; enemy.active_hit = false
				geometry.remaining = enemy.active_total; geometry.total = enemy.active_total
				enemy.telegraph = geometry; enemy.state = "active"
			elif GEOMETRY.contains_actor(geometry, actor): _record_hit(result, geometry)
			if kind == "hook":
				geometry.kind = "slow_strip"; geometry.remaining = minf(2, float(action.get("duration", 1.5))); geometry.total = geometry.remaining; geometry.until = 0.0; geometry.interval = 0.3; geometry.slow = float(action.get("slow", 0.25)); geometry.phase = "active"
				hazards.append(geometry)
	var secondary:=PATTERNS.secondary(action)
	if not secondary.is_empty(): PATTERNS.launch(secondary,_pattern_context(enemy,action,geometry,secondary),pending,HURTBOX.center(actor),result)
	# Every delayed hit has a fresh warning; echo cannot recursively reproduce itself.
	if enemy.elite_rule_id in ["L05", "L06"]:
		var copies := 0
		for hazard in hazards:
			if hazard.owner_id == enemy.id and hazard.phase == "tell": copies += 1
		if copies < (2 if enemy.elite_rule_id == "L06" else 1):
			var echo: Dictionary = geometry.duplicate(true)
			if enemy.elite_rule_id == "L06": echo.shape = "marker"; echo.origin = HURTBOX.center(actor); echo.radius = 55.0
			echo.phase = "tell";echo.warning_policy="area";echo.projectile_only=false;echo.kind = "echo"; echo.remaining = maxf(0.8, float(enemy.params.get("echo_delay", enemy.params.get("marker_delay", 0.9)))); echo.total = echo.remaining; echo.one_shot = true
			hazards.append(echo)
	if enemy.rank == "boss" and kind not in ["heal", "command", "summon"]:
		result.events.append({"kind":"boss_impact", "id":enemy.id, "enemy_id":enemy.id, "position":geometry.origin, "phase":enemy.form_index, "form_index":enemy.form_index, "action_id":str(action.get("id", kind)), "action_serial":enemy.action_serial, "geometry":geometry.duplicate(true)})
	if kind != "charge": _shared_recovery(enemy, enemies)
	result.events.append(sound_event("enemy_release",enemy,geometry))
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
	var active_owners: Dictionary={}
	for source in enemies:
		if not source.dead: active_owners[source.id]=true
	for i in range(hazards.size() - 1, -1, -1):
		var hazard: Dictionary = hazards[i]
		if not active_owners.has(int(hazard.owner_id)): hazards.remove_at(i);continue
		hazard.remaining -= delta
		if hazard.phase == "tell":
			if hazard.remaining <= 0:
				if str(hazard.get("kind",""))!="pot_marker" and GEOMETRY.contains_actor(hazard,actor): _record_hit(result,hazard)
				var released_geometry: Dictionary = hazard.duplicate(true)
				released_geometry.phase = "active"
				result.events.append({"kind":"enemy_hazard_release", "id":int(hazard.owner_id), "enemy_id":int(hazard.owner_id), "definition_id":str(hazard.get("sound_definition_id","")), "form_index":int(hazard.get("sound_form_index",0)), "move_id":str(hazard.get("move_id","")), "position":hazard.origin, "major":bool(hazard.get("sound_major",false)), "action_serial":int(hazard.get("action_serial", 0)), "geometry":released_geometry})
				if str(hazard.get("kind",""))=="pot_marker":
					hazard.phase="active";hazard.kind="pot";hazard.remaining=float(hazard.get("pot_duration",3.0));hazard.total=hazard.remaining;hazard.until=.5;hazard.interval=.7
				else: hazards.remove_at(i)
		else:
			hazard.until -= delta
			if hazard.until <= 0 and hazard.remaining > 0:
				if GEOMETRY.contains_actor(hazard, actor):
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

static func _advance_charge(enemy: RefCounted, actor: Vector2, delta: float, enemies: Array, result: Dictionary, actor_previous: Vector2 = Vector2.INF) -> void:
	var start: Vector2 = enemy.position
	enemy.active_remaining = maxf(0, enemy.active_remaining - delta)
	var progress: float = 1 - enemy.active_remaining / maxf(0.001, enemy.active_total)
	var g: Dictionary = enemy.telegraph
	enemy.position = g.origin + g.direction * float(g.length) * progress
	g.remaining = enemy.active_remaining
	var swept := {"shape":"line", "origin":start, "direction":g.direction, "length":start.distance_to(enemy.position), "half_width":g.half_width}
	if actor_previous==Vector2.INF: actor_previous=actor
	if not enemy.active_hit and HURTBOX.contains_swept(start,enemy.position,float(g.half_width),actor_previous,actor):
		_record_hit(result, g); enemy.active_hit = true
	if enemy.active_remaining <= 0:
		enemy.telegraph = {}; enemy.state = "recovery"
		_shared_recovery(enemy, enemies)

static func phase_event(enemy: RefCounted) -> Dictionary:
	return {"kind":"boss_phase", "id":enemy.id, "enemy_id":enemy.id, "position":enemy.position, "phase":enemy.form_index,
		"form_index":enemy.form_index, "definition_id":enemy.definition_id, "form_count":enemy.form_count, "form_name":enemy.form_name, "transition_remaining":enemy.transition_remaining}

static func _record_hit(result: Dictionary, geometry: Dictionary) -> void:
	result.hits.append(float(geometry.damage))
	result.hit_sources.append({"enemy_id":int(geometry.get("owner_id", 0)), "attack":str(geometry.get("move_id", geometry.get("action_id", ""))), "move_id":str(geometry.get("move_id", "")), "definition_id":str(geometry.get("sound_definition_id","")), "form_index":int(geometry.get("sound_form_index",0)), "action_serial":int(geometry.get("action_serial",0)), "position":geometry.get("origin", Vector2.ZERO)})

static func sound_event(kind: String, enemy: RefCounted, geometry: Dictionary) -> Dictionary:
	return {"kind":kind,"id":enemy.id,"enemy_id":enemy.id,"definition_id":enemy.definition_id,"form_index":enemy.form_index,"rank":enemy.rank,"position":geometry.get("origin",enemy.position),"move_id":str(geometry.get("move_id",enemy.current_action.get("id",""))),"action_serial":enemy.action_serial,"major":bool(enemy.current_action.get("major",false)),"geometry":geometry.duplicate(true)}

static func _pattern_context(enemy: RefCounted, action: Dictionary, geometry: Dictionary, pattern: Dictionary) -> Dictionary:
	return {"origin":geometry.origin,"direction":geometry.direction,"source_id":enemy.id,"definition_id":enemy.definition_id,"form_index":enemy.form_index,
		"move_id":str(action.get("id",action.get("action",""))),"action_serial":enemy.action_serial,"visual_id":enemy.visual_id,
		"damage":enemy.damage*float(pattern.get("damage_scale",action.get("damage_scale",1.0)))}

static func _marker_series(geometry: Dictionary, action: Dictionary) -> Dictionary:
	var count:=clampi(int(action.get("marker_count",1)),1,5)
	if count<=1 or str(geometry.get("shape",""))!="marker" and str(action.get("action",""))!="pot": return geometry
	var source:=geometry.duplicate(true)
	var points: Array=[]
	for index in count:
		var marker:=source.duplicate(true)
		marker.origin=SPACE.clamp_point(Vector2(source.origin)+Vector2(source.direction).orthogonal()*(index-(count-1)*.5)*float(action.get("marker_spacing",180)),Vector2(35,35))
		marker.marker_index=index;marker.warning_policy="area";marker.projectile_only=false
		marker.remaining=float(source.remaining)+index*maxf(.12,float(action.get("marker_delay",.22)))
		marker.total=marker.remaining
		marker.one_shot=true;marker.kind="pot_marker" if str(action.get("action",""))=="pot" else "marker_series"
		if marker.kind=="pot_marker": marker.pot_duration=float(action.get("duration",3))
		if str(action.get("action",""))=="collaboration" and index>0: marker.remaining+=.9;marker.total=marker.remaining
		points.append(marker)
	var result: Dictionary=points[0]
	result.extra_markers=[]
	for index in range(1,points.size()): result.extra_markers.append(points[index])
	return result
