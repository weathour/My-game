extends RefCounted
## One disposable attempt. No UI, disk access, role talents, or global scene lookups.
const C := preload("res://scripts/content/combat_catalog.gd")
const CHARACTER := preload("res://scripts/battle/character_runtime.gd")
const DIRECTOR := preload("res://scripts/battle/stage_director.gd")
const ABILITIES := preload("res://scripts/battle/ability_system.gd")
const A := preload("res://scripts/battle/ability_definition.gd")
const TARGETS := preload("res://scripts/battle/targeting.gd")
const RESOLVER := preload("res://scripts/battle/combat_resolver.gd")
const ENEMIES := preload("res://scripts/battle/enemy_system.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
const MECHANICS := preload("res://scripts/battle/combat_mechanics.gd")

var attempt_id: String
var members: Array
var characters: Dictionary = {}
var roster: Dictionary
var equipment: Dictionary
var director: RefCounted
var position := SPACE.CENTER
var facing := Vector2.RIGHT
var active := 0
var switch_cooldown := 0.0
var enemies: Array = []
var projectiles: Array = []
var gems: Array = []
var effects: Array = []
var hazards: Array = []
var telegraphs: Array = []
var delivery_serial := 0
var target_hold := 0.0
var enemy_slow := 0.0
var enemy_slow_remaining := 0.0
var events: Array = []
var outcome := ""
var result: Dictionary = {}
var paused := false
var target_id := -1
var cast_serial := 0
var _switch_intent := 0
var _skill_intents: Array[int] = []
var _hits: Array = []
var mechanics: RefCounted

func _init(request: Dictionary) -> void:
	attempt_id = request.attempt_id
	members = request.members.duplicate()
	roster = request.characters.duplicate(true)
	equipment = request.equipment.duplicate(true)
	director = DIRECTOR.new(request.stage, int(request.seed))
	var bonuses := C.owned_bonuses(roster)
	for id in members: characters[id] = CHARACTER.new(id, roster[id], C.attributes(id, int(roster[id].level), bonuses, equipment))
	mechanics = MECHANICS.new(self)

func current() -> RefCounted:
	return characters[members[active]]

func request_switch(direction: int) -> void:
	if not paused and outcome.is_empty(): _switch_intent = signi(direction)

func request_skill(slot: int) -> void:
	if not paused and outcome.is_empty() and slot in [0, 1] and slot not in _skill_intents: _skill_intents.append(slot)

func set_paused(value: bool) -> void:
	paused = value
	_switch_intent = 0
	_skill_intents.clear()

func tick(delta: float, movement: Vector2) -> void:
	if paused or not outcome.is_empty(): return
	events.clear()
	_hits.clear()
	switch_cooldown = maxf(0, switch_cooldown - delta)
	for character in characters.values(): character.tick(delta)
	mechanics.tick(delta)
	_process_switch()
	var actor := current()
	enemy_slow_remaining = maxf(0, enemy_slow_remaining - delta)
	if enemy_slow_remaining <= 0: enemy_slow = 0
	position += movement.limit_length(1) * (1 - enemy_slow) * actor.stats.move * (1.25 if actor.haste > 0 else 1.0) * delta
	position = SPACE.clamp_point(position, SPACE.PLAYER_MARGIN)
	var ordinary_count := 0
	for enemy in enemies:
		if not enemy.dead and enemy.parent_id == 0 and enemy.rank in ["ordinary", "heavy"]: ordinary_count += 1
	enemies.append_array(director.tick(delta, ordinary_count, position, enemies))
	target_hold = maxf(0, target_hold - delta)
	var target := TARGETS.nearest(enemies, position, 580, target_id)
	if target != null:
		if target.id != target_id and target_hold <= 0: target_id = target.id; target_hold = 0.25
		for locked in enemies:
			if locked.id == target_id and not locked.dead: facing = (locked.position - position).normalized(); break
	elif movement.length_squared() > 0.01: facing = movement.normalized()
	for slot in _skill_intents:
		var manuals: Array = C.definition(actor.id).manual
		if slot < manuals.size(): _cast(manuals[slot], actor, true, true)
	_skill_intents.clear()
	_cast(C.basic(actor.id, equipment), actor, true)
	for ability in C.definition(actor.id).automatic: _cast(ability, actor, true)
	for id in members:
		if id == actor.id or characters[id].dead: continue
		var support: Resource = C.definition(id).support
		if support != null and not mechanics.support_is_reactive(id, support): _cast(support, characters[id], false)
	var hostile := ENEMIES.step(enemies, position, delta, {"hazards":hazards, "config":director.config, "actor_speed":float(actor.stats.move)})
	for spawn_descriptor in hostile.spawns:
		enemies.append(director.derivative(spawn_descriptor, enemies))
	events.append_array(hostile.events)
	for event in hostile.events:
		if event.kind == "enemy_slow": enemy_slow = float(event.slow); enemy_slow_remaining = float(event.duration)
	_refresh_telegraphs()
	projectiles.append_array(hostile.projectiles)
	effects.append_array(hostile.effects)
	var incoming: Array = hostile.hits
	_update_projectiles(delta, incoming)
	# All already-issued impacts resolve before terminal state. Rendering never budgets damage.
	_resolve_hits()
	for amount in incoming:
		var loss: float = mechanics.receive_hit(actor, float(amount), equipment)
		if loss > 0: events.append({"kind":"hurt", "amount":loss, "id":actor.id})
	_resolve_hits()
	_cleanup_sources()
	var boss_dead := false
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: RefCounted = enemies[i]
		if not enemy.dead: continue
		var killed: bool = enemy.death_reason in ["", "killed"]
		if killed:
			director.defeated(enemy)
			boss_dead = boss_dead or (enemy.kind == "boss" and enemy.hp_owner == null)
			if enemy.xp > 0: gems.append({"position":enemy.position, "amount":enemy.xp})
			events.append({"kind":"kill", "position":enemy.position, "id":enemy.id, "living":enemy.rank != "object"})
		else: events.append({"kind":"enemy_remove", "id":enemy.id, "reason":enemy.death_reason})
		enemies.remove_at(i)
	if characters.JIA.dead:
		_finish("failed")
		return
	if actor.dead:
		active = 0
		target_id = -1
		events.append({"kind":"message", "text":"%s阵亡，贾苇索接战。" % actor.id})
	if boss_dead:
		for gem in gems: grant_experience(gem.amount)
		gems.clear()
		if director.elapsed <= director.config.bonus_time: grant_experience(18.0)
		_finish("victory")
		return
	_update_gems(delta)
	if director.field == -1:
		for i in 4:
			if position.distance_to(DIRECTOR.FIELD_POSITIONS[i]) < 38: choose_field(i); break
	for i in range(effects.size() - 1, -1, -1):
		effects[i].life -= delta
		if effects[i].life <= 0: effects.remove_at(i)

func _process_switch() -> void:
	var direction := _switch_intent
	_switch_intent = 0
	if direction == 0 or switch_cooldown > 0: return
	for offset in range(1, members.size()):
		var next := posmod(active + direction * offset, members.size())
		if not characters[members[next]].dead:
			active = next
			switch_cooldown = 0.5
			target_id = -1
			return

func manual_cost(ability: Resource, id: String = "") -> float:
	var key: String = current().id if id.is_empty() else id
	if not characters.has(key) or not outcome.is_empty(): return ability.mana_cost
	return mechanics.cost(ability, characters[key], true)

func mechanic_status(id: String) -> Dictionary:
	if outcome.is_empty(): return mechanics.status(id)
	if not characters.has(id): return {}
	return {"id":id, "dead":characters[id].dead, "shield":0.0, "core":"", "label":"", "value":0.0, "max":0.0, "remaining":0.0, "detail":"", "support_available":false, "windows":[]}

func _resolve_hits() -> void:
	var deliveries := {}
	var index := 0
	while index < _hits.size():
		var hit: Dictionary = _hits[index]
		index += 1
		var receiver: RefCounted = hit.target.damage_owner()
		var group := str(hit.context.get("delivery", -index)) + ":" + str(receiver.id)
		if deliveries.has(group): continue
		deliveries[group] = true
		mechanics.resolve_hit(hit.target, hit.context)
	_hits.clear()

func _cast(ability: Resource, source: RefCounted, direct: bool, manual: bool = false) -> bool:
	if not manual and source.cooldowns.get(ability.id, 0.0) > 0: return false
	if not mechanics.can_cast(ability, source): return false
	var query_reach: float = mechanics.query_reach(ability, source, direct)
	var target := TARGETS.nearest(enemies, position, query_reach, target_id)
	cast_serial += 1
	var cast := ABILITIES.activate(ability, source, position, target, facing, equipment, direct, cast_serial, mechanics.cost(ability, source, manual), manual)
	if cast.has("error"):
		if manual: events.append({"kind":"message", "text":cast.error})
		return false
	cast = mechanics.prepare(cast)
	events.append({"kind":"cast", "id":source.id, "ability":str(ability.id), "paid":float(cast.context.paid), "manual":manual, "direct":direct,
		"shield_spent":float(cast.context.get("shield_spent", 0)), "ammo_spent":int(cast.context.get("ammo_spent", 0)), "time":director.elapsed})
	if manual: events.append({"kind":"message", "text":ability.title})
	_execute_payload(cast)
	mechanics.on_paid(cast)
	return true

func _execute_payload(cast: Dictionary) -> void:
	var ability: Resource = cast.ability
	var context: Dictionary = delivery_context(cast.context)
	context.impact_origin = cast.origin
	context.impact_direction = cast.direction
	cast = cast.duplicate()
	cast.context = context
	var source: RefCounted = characters[context.source]
	var targets: Array = mechanics.receivers(source, ability.target_scope)
	if not mechanics.special(cast):
		match ability.kind:
			A.Kind.HEAL:
				for receiver in targets: receiver.hp = minf(receiver.stats.hp, receiver.hp + ability.damage_scale + source.level * 1.5)
			A.Kind.MANA:
				for receiver in targets: receiver.mp = minf(receiver.stats.mp, receiver.mp + ability.damage_scale)
			A.Kind.WARD:
				for receiver in targets: mechanics.add_shield(receiver, ability.damage_scale, float(ability.params.get("shield_cap_ratio", 0.35)))
			A.Kind.PROJECTILE:
				projectiles.append({"position":cast.origin, "velocity":cast.direction * 420, "life":cast.reach / 420 + 0.2, "hostile":false, "context":context})
			_:
				for enemy in TARGETS.in_shape(enemies, cast.origin, cast.direction, cast.reach, ability.kind == A.Kind.THRUST, ability.kind == A.Kind.NOVA):
					_hits.append({"target":enemy, "context":context})
	var direct: bool = context.direct
	var manual: bool = bool(context.get("manual", false))
	var color := "support" if not direct else "manual" if manual else "basic"
	var beneficiary := ""
	var beneficiaries: Array = []
	if ability.kind in [A.Kind.HEAL, A.Kind.MANA, A.Kind.WARD]:
		for receiver in targets: beneficiaries.append(receiver.id)
		if not targets.is_empty(): beneficiary = targets[0].id
	effects.append({"kind":"ring" if ability.kind == A.Kind.NOVA else "slash" if ability.kind in [A.Kind.SWEEP, A.Kind.THRUST] else "cast", "origin":cast.origin,
		"direction":cast.direction, "radius":cast.reach if ability.kind in [A.Kind.NOVA, A.Kind.SWEEP, A.Kind.THRUST] else 25, "life":0.22, "color":color, "narrow":ability.kind == A.Kind.THRUST,
		"source":source.id, "ability":str(ability.id), "cast":context.cast, "direct":direct,
		"visual_time":director.elapsed, "beneficiary":beneficiary, "beneficiaries":beneficiaries})

func _update_projectiles(delta: float, incoming: Array) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p: Dictionary = projectiles[i]
		var start: Vector2 = p.position
		p.position += p.velocity * delta
		p.life -= delta
		var hit := false
		if p.hostile:
			if Geometry2D.get_closest_point_to_segment(position, start, p.position).distance_to(position) < 16 + float(p.get("hit_radius", 4)):
				incoming.append(p.damage)
				hit = true
		else:
			var first: RefCounted
			var best := INF
			for enemy in enemies:
				if enemy.dead or not enemy.targetable: continue
				if Geometry2D.get_closest_point_to_segment(enemy.position, start, p.position).distance_to(enemy.position) <= enemy.radius + 5:
					var distance: float = start.distance_squared_to(enemy.position)
					if distance < best: first = enemy; best = distance
			if first != null:
				var impact: Dictionary = delivery_context(p.context)
				impact.impact_origin = start
				impact.impact_direction = p.velocity.normalized()
				_hits.append({"target":first, "context":impact})
				if float(p.context.get("splash_radius", 0)) > 0:
					for other in TARGETS.in_shape(enemies, first.position, Vector2.RIGHT, float(p.context.splash_radius), false, true):
						if other != first: _hits.append({"target":other, "context":impact})
				# Pure presentation descriptor: the immutable launch context supplies
				# identity even when a different party member is now controlled.
				effects.append({"kind":"impact", "origin":first.position, "direction":p.velocity.normalized(), "radius":26.0,
					"life":0.22, "color":"basic" if p.context.direct else "support", "source":p.context.source,
					"ability":p.context.ability, "cast":p.context.cast, "direct":p.context.direct, "visual_time":director.elapsed})
				hit = true
		if hit or p.life <= 0: projectiles.remove_at(i)

func _update_gems(delta: float) -> void:
	for i in range(gems.size() - 1, -1, -1):
		var gap: Vector2 = position - gems[i].position
		if gap.length() < 125: gems[i].position += gap.normalized() * 330 * delta
		if gap.length() < 35:
			grant_experience(gems[i].amount)
			gems.remove_at(i)

func grant_experience(amount: float, only_id: String = "") -> void:
	var recipients: Array = members if only_id.is_empty() else [only_id]
	var leveled: Array = []
	for id in recipients:
		var character: RefCounted = characters[id]
		character.xp += amount / recipients.size()
		while character.xp >= C.xp_required(character.level):
			character.xp -= C.xp_required(character.level)
			character.level += 1
			if id not in leveled: leveled.append(id)
		roster[id] = character.snapshot()
	if leveled.is_empty(): return
	var bonuses := C.owned_bonuses(roster)
	for id in members:
		var character: RefCounted = characters[id]
		character.stats = C.attributes(id, character.level, bonuses, equipment)
		if id in leveled and not character.dead: character.hp = character.stats.hp; character.mp = character.stats.mp
	for id in leveled: events.append({"kind":"level", "id":id, "level":characters[id].level})

func choose_field(index: int) -> bool:
	if paused or not outcome.is_empty() or not director.choose_field(index): return false
	var actor := current()
	match index:
		0:
			var bonuses := C.owned_bonuses(roster)
			actor.hp = minf(actor.stats.hp, actor.hp + actor.stats.hp * (0.6 + bonuses.get("supply_hp", 0.0)))
			actor.mp = minf(actor.stats.mp, actor.mp + actor.stats.mp * (0.6 + bonuses.get("supply_mp", 0.0)))
		1: grant_experience(24.0, actor.id)
		2, 3: enemies.append(director.spawn("card_elite" if index == 2 else "equipment_elite", SPACE.challenge_position(position)))
	events.append({"kind":"message", "text":["补给已使用", "当前人物获得修习经验", "额外选卡精英已出现", "装备精英已出现"][index]})
	return true

func _finish(value: String) -> void:
	if not outcome.is_empty(): return
	outcome = value
	var records := {}
	for id in members: records[id] = characters[id].snapshot()
	result = {"attempt_id":attempt_id, "outcome":outcome, "characters":records,
		"card_elite":director.card_elite, "equipment_elite":director.equipment_elite,
		"elapsed":director.elapsed, "kills":director.kills, "fast_clear":director.elapsed <= director.config.bonus_time}
	projectiles.clear()
	hazards.clear()
	telegraphs.clear()
	for enemy in enemies:
		enemy.telegraph.clear(); enemy.windup = 0; enemy.active_remaining = 0; enemy.state = "removed"; enemy.death_reason = "combat_end"
	effects.clear()
	_hits.clear()
	mechanics.clear()
	for actor in characters.values(): actor.clear_temporary()

func delivery_context(original: Dictionary) -> Dictionary:
	delivery_serial += 1
	var copy := original.duplicate()
	copy.delivery = delivery_serial
	return copy

func _refresh_telegraphs() -> void:
	telegraphs.clear()
	for enemy in enemies:
		if not enemy.dead and not enemy.telegraph.is_empty(): telegraphs.append(enemy.telegraph)
	for hazard in hazards:
		if hazard.phase == "tell": telegraphs.append(hazard)

func _cleanup_sources() -> void:
	var dead_ids := {}
	for enemy in enemies:
		if enemy.dead: dead_ids[enemy.id] = true
	for enemy in enemies:
		if enemy.hp_owner != null:
			enemy.hp = enemy.hp_owner.hp
			if enemy.hp_owner.dead: enemy.dead = true; enemy.death_reason = "source_cancel"
		if dead_ids.has(enemy.parent_id) and enemy.definition_id in ["D03", "D05"]:
			enemy.dead = true; enemy.death_reason = "source_cancel"
	for i in range(hazards.size() - 1, -1, -1):
		if dead_ids.has(int(hazards[i].owner_id)): hazards.remove_at(i)
	_refresh_telegraphs()
