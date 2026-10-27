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
var events: Array = []
var outcome := ""
var result: Dictionary = {}
var paused := false
var target_id := -1
var cast_serial := 0
var _switch_intent := 0
var _skill_intents: Array[int] = []
var _hits: Array = []

func _init(request: Dictionary) -> void:
	attempt_id = request.attempt_id
	members = request.members.duplicate()
	roster = request.characters.duplicate(true)
	equipment = request.equipment.duplicate(true)
	director = DIRECTOR.new(request.stage, int(request.seed))
	var bonuses := C.owned_bonuses(roster)
	for id in members: characters[id] = CHARACTER.new(id, roster[id], C.attributes(id, int(roster[id].level), bonuses, equipment))

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
	_process_switch()
	var actor := current()
	position += movement.limit_length(1) * actor.stats.move * (1.25 if actor.haste > 0 else 1.0) * delta
	position = SPACE.clamp_point(position, SPACE.PLAYER_MARGIN)
	enemies.append_array(director.tick(delta, enemies.size(), position))
	var target := TARGETS.nearest(enemies, position, 580, target_id)
	if target != null: target_id = target.id; facing = (target.position - position).normalized()
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
		if support != null: _cast(support, characters[id], false)
	var hostile := ENEMIES.step(enemies, position, delta)
	projectiles.append_array(hostile.projectiles)
	effects.append_array(hostile.effects)
	var incoming: Array = hostile.hits
	_update_projectiles(delta, incoming)
	# All already-issued impacts resolve before terminal state. Rendering never budgets damage.
	for hit in _hits:
		RESOLVER.hit_enemy(hit.target, hit.context)
	for amount in incoming:
		var loss := RESOLVER.hit_character(actor, float(amount), equipment)
		if loss > 0: events.append({"kind":"hurt", "amount":loss, "id":actor.id})
	var boss_dead := false
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: RefCounted = enemies[i]
		if not enemy.dead: continue
		director.defeated(enemy)
		boss_dead = boss_dead or enemy.kind == "boss"
		gems.append({"position":enemy.position, "amount":enemy.xp})
		events.append({"kind":"kill", "position":enemy.position})
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

func _cast(ability: Resource, source: RefCounted, direct: bool, manual: bool = false) -> void:
	if not manual and source.cooldowns.get(ability.id, 0.0) > 0: return
	var target := TARGETS.nearest(enemies, position, ability.reach, target_id)
	cast_serial += 1
	var cast := ABILITIES.activate(ability, source, position, target, facing, equipment, direct, cast_serial)
	if cast.has("error"):
		if manual: events.append({"kind":"message", "text":cast.error})
		return
	if manual: events.append({"kind":"message", "text":ability.title})
	var receiver := current()
	match ability.kind:
		A.Kind.HEAL: receiver.hp = minf(receiver.stats.hp, receiver.hp + ability.damage_scale + source.level * 1.5)
		A.Kind.MANA: receiver.mp = minf(receiver.stats.mp, receiver.mp + ability.damage_scale)
		A.Kind.WARD: receiver.shield = maxf(receiver.shield, ability.damage_scale)
		A.Kind.PROJECTILE:
			projectiles.append({"position":position, "velocity":cast.direction * 420, "life":ability.reach / 420 + 0.2, "hostile":false, "context":cast.context})
		_:
			for enemy in TARGETS.in_shape(enemies, position, cast.direction, ability.reach, ability.kind == A.Kind.THRUST, ability.kind == A.Kind.NOVA):
				_hits.append({"target":enemy, "context":cast.context})
	var color := "support" if not direct else "manual" if manual else "basic"
	effects.append({"kind":"ring" if ability.kind == A.Kind.NOVA else "slash" if ability.kind in [A.Kind.SWEEP, A.Kind.THRUST] else "cast", "origin":position,
		"direction":cast.direction, "radius":ability.reach if ability.kind in [A.Kind.NOVA, A.Kind.SWEEP, A.Kind.THRUST] else 25, "life":0.22, "color":color, "narrow":ability.kind == A.Kind.THRUST,
		"source":source.id, "ability":str(ability.id), "cast":cast_serial, "direct":direct})

func _update_projectiles(delta: float, incoming: Array) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p: Dictionary = projectiles[i]
		var start: Vector2 = p.position
		p.position += p.velocity * delta
		p.life -= delta
		var hit := false
		if p.hostile:
			if Geometry2D.get_closest_point_to_segment(position, start, p.position).distance_to(position) < 20:
				incoming.append(p.damage)
				hit = true
		else:
			var first: RefCounted
			var best := INF
			for enemy in enemies:
				if enemy.dead: continue
				if Geometry2D.get_closest_point_to_segment(enemy.position, start, p.position).distance_to(enemy.position) <= enemy.radius + 5:
					var distance: float = start.distance_squared_to(enemy.position)
					if distance < best: first = enemy; best = distance
			if first != null:
				_hits.append({"target":first, "context":p.context})
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
	effects.clear()
