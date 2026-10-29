extends RefCounted
## Attempt-local character rules. Payloads retain immutable launch ownership.
const C := preload("res://scripts/content/combat_catalog.gd")
const A := preload("res://scripts/battle/ability_definition.gd")
const TARGETS := preload("res://scripts/battle/targeting.gd")
const RESOLVER := preload("res://scripts/battle/combat_resolver.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
var _battle: WeakRef
var states: Dictionary = {}
var curses: Dictionary = {}
var exposures: Dictionary = {}
var refunds: Array = []
var fields: Array = []
var spread_targets: Dictionary = {}
var spark_casts: Dictionary = {}
var last_payer := ""

func _init(battle: RefCounted) -> void:
	_battle = weakref(battle)
	for id in battle.members:
		var definition: Dictionary = C.definition(id)
		var p: Dictionary = definition.get("trait_params", {})
		states[id] = {"trait":str(definition.get("trait", "")), "params":p.duplicate(true), "windows":{}, "rallies":[], "echo":{},
			"ammo":int(p.get("initial", 6)), "refill":float(p.get("refill_interval", 8)), "mark":0, "last_hit_cast":-1}

func battle() -> RefCounted:
	return _battle.get_ref()

func receivers(source: RefCounted, scope: String) -> Array:
	var b := battle()
	var result: Array = []
	if scope == "self":
		if not source.dead: result.append(source)
	elif scope in ["party", "lowest_hp", "lowest_mp"]:
		for id in b.members:
			if not b.characters[id].dead: result.append(b.characters[id])
		if scope != "party" and not result.is_empty():
			var resource := "hp" if scope == "lowest_hp" else "mp"
			var chosen: RefCounted = b.current() if b.current() in result else result[0]
			for actor in result:
				if float(actor.get(resource)) / maxf(1, actor.stats[resource]) < float(chosen.get(resource)) / maxf(1, chosen.stats[resource]): chosen = actor
			result = [chosen]
	else:
		if not b.current().dead: result.append(b.current())
	return result

func cost(ability: Resource, source: RefCounted, manual: bool) -> float:
	if not manual: return 0.0
	var value: float = ability.mana_cost
	if value <= 0 or last_payer.is_empty() or last_payer == source.id: return value
	var b := battle()
	var fraction := 0.0
	var minimum := 1.0
	for id in b.members:
		if b.characters[id].dead or states[id].trait != "relay": continue
		var p: Dictionary = states[id].params
		fraction = maxf(fraction, clampf(float(p.get("fraction", 0.2)), 0, 0.8))
		minimum = maxf(minimum, float(p.get("min_cost", 1)))
	return minf(value, maxf(minimum, value * (1 - fraction)))

func support_is_reactive(id: String, ability: Resource) -> bool:
	return states[id].trait in ["mark", "ammo"] or ability.mechanic == "ammo_followup"

func can_cast(ability: Resource, source: RefCounted) -> bool:
	return true

func query_reach(ability: Resource, source: RefCounted, direct: bool) -> float:
	var reach: float = ability.reach
	if ability.mechanic == "shield_strike":
		var cap := maxf(0.01, float(ability.params.get("shield_max", 30)))
		reach += float(ability.params.get("reach_bonus", 80)) * minf(source.shield, cap) / cap
	if direct and states[source.id].windows.has("temper"): reach += float(states[source.id].windows.temper.get("reach_bonus", 50))
	return reach

func prepare(cast: Dictionary) -> Dictionary:
	# Called only after activation has paid and committed cooldowns.
	var b := battle()
	var ability: Resource = cast.ability
	var source: RefCounted = b.characters[cast.context.source]
	var context: Dictionary = cast.context.duplicate()
	var p: Dictionary = ability.params
	if ability.mechanic == "shield_strike":
		var cap := maxf(0.01, float(p.get("shield_max", 30)))
		var spent := minf(source.shield, cap)
		source.shield -= spent
		context.damage *= 1 + spent * float(p.get("shield_ratio", 0.06))
		cast.reach += float(p.get("reach_bonus", 80)) * spent / cap
		context.shield_spent = spent
	elif ability.mechanic == "ammo_volley":
		var spent := mini(int(states[source.id].ammo), int(p.get("max_spend", 4)))
		states[source.id].ammo -= spent
		context.damage *= 1 + spent * float(p.get("bonus_per_arrow", 0.35))
		context.ammo_spent = spent
	elif ability.mechanic == "ammo_followup":
		if int(states[source.id].ammo) > 0:
			states[source.id].ammo -= 1
			context.ammo_spent = 1
		else:
			context.ammo_spent = 0
			context.damage *= float(p.get("normal_multiplier", 0.4))
		context.secondary = true
		context.enchant = ""
	if bool(context.direct):
		var windows: Dictionary = states[source.id].windows
		if windows.has("rally"):
			context.damage *= 1 + float(windows.rally.get("attack_multiplier", 0.15))
			var speed := float(windows.rally.get("speed_multiplier", 0))
			if speed > 0 and bool(context.basic): source.cooldowns[str(ability.id)] /= 1 + speed
		if windows.has("temper") and ability.kind in [A.Kind.SWEEP, A.Kind.THRUST, A.Kind.PROJECTILE, A.Kind.NOVA]:
			var temper: Dictionary = windows.temper
			cast.reach += float(temper.get("reach_bonus", 50))
			context.splash_radius = float(temper.get("splash_radius", 45))
			context.temper_source = temper.owner
			context.spark_damage = float(temper.attack) * float(temper.get("spark_scale", 0.25))
			# A launch snapshots permission; swapping or a later expiry cannot retag it.
	context.make_read_only()
	cast.context = context
	return cast

func special(cast: Dictionary) -> bool:
	var b := battle()
	var ability: Resource = cast.ability
	var source: RefCounted = b.characters[cast.context.source]
	var p: Dictionary = ability.params
	var targets := receivers(source, ability.target_scope)
	match ability.mechanic:
		"party_heal":
			for actor in receivers(source, "party"):
				var amount: float = ability.damage_scale + source.level * 1.5
				var needed: float = maxf(0, actor.stats.hp - actor.hp)
				actor.hp = minf(actor.stats.hp, actor.hp + amount)
				add_shield(actor, maxf(0, amount - needed), float(p.get("shield_cap_ratio", 0.35)))
			return true
		"guard", "temper", "rally":
			for actor in targets:
				var window: Dictionary = p.duplicate(true)
				window.life = float(p.get("duration", 5))
				window.extended = 0.0
				window.owner = source.id
				window.attack = float(source.stats.attack)
				window.charges = int(p.get("charges", 1))
				if ability.mechanic == "rally":
					states[actor.id].rallies.append(window)
					_refresh_rally(states[actor.id])
				else: states[actor.id].windows[ability.mechanic] = window
			return true
		"refund_settle":
			for account in refunds:
				if account.owner == source.id: _refund_payment(account, account.balance)
			return true
		"extend":
			extend_windows(source.id, float(p.get("seconds", 2)), float(p.get("max_extension", 4)), p.get("allowed", ["echo", "temper"]))
			return true
		"field":
			var context := secondary(cast.context)
			context.make_read_only()
			fields.append({"source":source.id, "context":context, "position":cast.origin, "life":float(p.get("duration", 6)),
				"interval":maxf(0.2, float(p.get("interval", 1))), "until":0.0, "radius":float(p.get("radius", ability.reach)),
				"heal":float(p.get("heal", 0)), "mana":float(p.get("mana", 0)), "follow":bool(p.get("follow", false)), "scope":ability.target_scope})
			return true
		"dash":
			if cast.context.direct: b.position = SPACE.clamp_point(b.position + cast.direction * float(p.get("distance", 100)), SPACE.PLAYER_MARGIN)
	return false

func on_paid(cast: Dictionary) -> void:
	var context: Dictionary = cast.context
	if float(context.paid) <= 0 or not context.manual or context.secondary: return
	var b := battle()
	var payer: String = context.source
	last_payer = payer
	for id in b.members:
		if b.characters[id].dead or id == payer: continue
		var state: Dictionary = states[id]
		var p: Dictionary = state.params
		match state.trait:
			"ammo": state.ammo = mini(int(p.get("capacity", 6)), int(state.ammo) + int(p.get("cast_refill", 1)))
			"refund":
				var fraction := clampf(float(p.get("fraction", 0.2)), 0, 0.8)
				var amount: float = context.paid * fraction
				var duration := maxf(0.1, float(p.get("duration", 6)))
				var ticks := maxi(1, int(p.get("ticks", 3)))
				refunds.append({"owner":id, "payer":payer, "balance":amount, "portion":amount / ticks, "interval":duration / ticks, "until":duration / ticks, "life":duration})
			"echo":
				if id != b.current().id and not state.echo.is_empty() and state.echo.life > 0 and state.echo.remaining > 0:
					state.echo.remaining -= 1
					_emit_echo(state.echo)
	if cast.ability.mechanic == "echo_record":
		var p: Dictionary = states[payer].params.duplicate(true)
		p.merge(cast.ability.params, true)
		var context_copy: Dictionary = secondary(context)
		context_copy.damage *= float(p.get("damage_multiplier", 0.45))
		context_copy.slow *= float(p.get("slow_multiplier", 0.5))
		context_copy.duration *= float(p.get("slow_multiplier", 0.5))
		context_copy.make_read_only()
		states[payer].echo = {"context":context_copy, "ability":cast.ability, "reach":cast.reach,
			"remaining":int(p.get("charges", 2)), "capacity":int(p.get("charges", 2)), "life":float(p.get("duration", 12)), "extended":0.0}

func _emit_echo(record: Dictionary) -> void:
	var b := battle()
	var target := TARGETS.nearest(b.enemies, b.position, float(record.reach), b.target_id)
	var direction: Vector2 = b.facing if target == null else (target.position - b.position).normalized()
	b._execute_payload({"ability":record.ability, "context":record.context, "origin":b.position, "direction":direction, "reach":record.reach})
	b.events.append({"kind":"mechanic", "id":record.context.source, "mechanic":"echo", "remaining":record.remaining})

func extend_windows(excluding: String, seconds: float, cap: float, allowed: Array) -> void:
	var b := battle()
	for id in b.members:
		if id == excluding or b.characters[id].dead: continue
		var state: Dictionary = states[id]
		if "echo" in allowed and not state.echo.is_empty() and state.echo.life > 0 and state.echo.remaining > 0: _extend(state.echo, seconds, cap)
		for key in state.windows:
			if key in allowed and state.windows[key].life > 0: _extend(state.windows[key], seconds, cap)

func _refresh_exposure(exposure: Dictionary) -> void:
	exposure.multiplier = 0.0
	exposure.life = 0.0
	for instance in exposure.instances:
		exposure.multiplier = maxf(float(exposure.multiplier), float(instance.multiplier))
		exposure.life = maxf(float(exposure.life), float(instance.life))

func _refresh_rally(state: Dictionary) -> void:
	if state.rallies.is_empty():
		state.windows.erase("rally")
		return
	var effective := {"life":0.0, "attack_multiplier":0.0, "speed_multiplier":0.0}
	for instance in state.rallies:
		effective.life = maxf(float(effective.life), float(instance.life))
		effective.attack_multiplier = maxf(float(effective.attack_multiplier), float(instance.get("attack_multiplier", 0)))
		effective.speed_multiplier = maxf(float(effective.speed_multiplier), float(instance.get("speed_multiplier", 0)))
	state.windows.rally = effective

func _extend(window: Dictionary, seconds: float, cap: float) -> void:
	var amount := minf(maxf(0, seconds), maxf(0, cap - float(window.extended)))
	window.life += amount
	window.extended += amount

func secondary(context: Dictionary) -> Dictionary:
	var copy: Dictionary = context.duplicate()
	copy.direct = false
	copy.enchant = ""
	copy.secondary = true
	copy.manual = false
	copy.basic = false
	copy.paid = 0.0
	copy.mechanic = ""
	copy.params = {}
	copy.erase("spark_damage")
	copy.erase("temper_source")
	copy.erase("splash_radius")
	return copy

func resolve_hit(enemy: RefCounted, original: Dictionary) -> void:
	if enemy.dead or not enemy.targetable: return
	enemy = enemy.damage_owner()
	if enemy.dead: return
	var context: Dictionary = original.duplicate()
	if exposures.has(enemy.id): context.vulnerability = float(exposures[enemy.id].multiplier)
	var params: Dictionary = context.get("params", {})
	var previous: Array = curses.get(enemy.id, []).duplicate(true)
	if context.get("mechanic", "") == "curse_cashout":
		context.curse_settled = cashout(enemy.id, clampf(float(params.get("fraction", 0.5)), 0, 1))
	RESOLVER.hit_enemy(enemy, context)
	if bool(context.get("secondary", false)): return
	var b := battle()
	if context.get("mechanic", "") == "curse":
		if not enemy.dead: apply_curse(enemy.id, str(context.source), float(context.get("attack", context.damage)) * float(params.get("dot_scale", 1)), float(params.get("duration", 6)), float(params.get("tick_interval", 1)))
		if not previous.is_empty() and int(params.get("spread_targets", 0)) > 0:
			var cast_key := int(context.cast)
			if not spread_targets.has(cast_key): spread_targets[cast_key] = []
			var used: Array = spread_targets[cast_key]
			for neighbor in b.enemies:
				if used.size() >= int(params.get("spread_targets", 0)): break
				if neighbor.id in used or neighbor.dead or not neighbor.targetable or neighbor.hp_owner != null or neighbor == enemy or neighbor.position.distance_to(enemy.position) > float(params.get("spread_radius", 160)): continue
				for layer in previous:
					apply_curse(neighbor.id, layer.source, float(layer.remaining) * clampf(float(params.get("spread_fraction", 0.35)), 0, 1), float(layer.life), float(layer.interval))
				used.append(neighbor.id)
			if spread_targets.size() > 256: spread_targets.erase(spread_targets.keys()[0])
	elif context.get("mechanic", "") == "expose" and not enemy.dead:
		if not exposures.has(enemy.id): exposures[enemy.id] = {"instances":[], "multiplier":0.0, "life":0.0}
		exposures[enemy.id].instances.append({"multiplier":float(params.get("multiplier", 0.15)), "life":float(params.get("duration", 4))})
		_refresh_exposure(exposures[enemy.id])
	if not bool(context.direct): return
	var source: String = context.source
	if states[source].trait == "curse" and not bool(context.get("manual", false)) and context.get("mechanic", "") != "curse" and not enemy.dead and b.characters[source].cooldowns.get("trait_curse", 0.0) <= 0:
		var p: Dictionary = states[source].params
		apply_curse(enemy.id, source, float(context.get("attack", context.damage)) * float(p.get("dot_scale", 0.3)), float(p.get("duration", 5)), 1)
		b.characters[source].cooldowns.trait_curse = float(p.get("interval", 2))
	if context.has("spark_damage") and not spark_casts.has(int(context.cast)):
		spark_casts[int(context.cast)] = true
		if spark_casts.size() > 256: spark_casts.erase(spark_casts.keys()[0])
		var spark := secondary(context)
		spark.source = context.temper_source
		spark.damage = float(context.spark_damage)
		spark.damage_type = A.DamageType.MAGIC
		spark.slow = 0.0
		spark.duration = 0.0
		spark.make_read_only()
		spark = b.delivery_context(spark)
		for recipient in TARGETS.in_shape(b.enemies, enemy.position, Vector2.RIGHT, float(context.get("splash_radius", 45)), false, true):
			b._hits.append({"target":recipient, "context":spark})
	# Each direct cast counts once, even when its shape hits many enemies.
	for id in b.members:
		if id == b.current().id or b.characters[id].dead: continue
		var state: Dictionary = states[id]
		if state.last_hit_cast == int(context.cast): continue
		var support: Resource = C.definition(id).support
		if support == null: continue
		if state.trait == "ammo" or support.mechanic == "ammo_followup":
			state.last_hit_cast = int(context.cast)
			b._cast(support, b.characters[id], false)
		elif state.trait == "mark" and bool(context.get("basic", false)):
			state.last_hit_cast = int(context.cast)
			state.mark = mini(int(state.params.get("hits", 3)), int(state.mark) + 1)
			if int(state.mark) >= int(state.params.get("hits", 3)) and b._cast(support, b.characters[id], false): state.mark = 0

func apply_curse(enemy_id: int, source: String, amount: float, duration: float, interval: float = 1.0) -> void:
	if amount <= 0 or duration <= 0: return
	if not curses.has(enemy_id): curses[enemy_id] = []
	var layers: Array = curses[enemy_id]
	for layer in layers:
		if layer.source != source: continue
		# Refresh replaces the same source's finite pool; already accrued damage is not duplicated.
		layer.remaining = maxf(float(layer.remaining), amount)
		layer.life = maxf(float(layer.life), duration)
		layer.rate = float(layer.remaining) / maxf(0.001, float(layer.life))
		layer.accrued = 0.0
		return
	layers.append({"source":source, "remaining":amount, "life":duration, "rate":amount / duration, "interval":maxf(0.2, interval), "until":maxf(0.2, interval), "accrued":0.0})

func cashout(enemy_id: int, fraction: float) -> float:
	var amount := 0.0
	for layer in curses.get(enemy_id, []):
		var part: float = layer.remaining * fraction
		amount += part
		layer.remaining -= part
		layer.rate *= 1 - fraction
		layer.accrued *= 1 - fraction
	return amount

func receive_hit(actor: RefCounted, raw: float, equipment: Dictionary) -> float:
	var b := battle()
	if actor.dead or actor.hurt_lock > 0: return 0
	var window: Dictionary = states[actor.id].windows.get("guard", {})
	var guarded: bool = not window.is_empty() and window.life > 0 and window.charges > 0 and raw > 0
	if guarded:
		raw *= 1 - clampf(float(window.get("reduction", 0.5)), 0, 0.9)
		window.charges -= 1
	var loss := RESOLVER.hit_character(actor, raw, equipment)
	if guarded:
		var context := {"source":str(window.owner), "ability":"guard_counter", "cast":b.cast_serial, "damage":float(window.attack) * float(window.get("counter_scale", 1.5)),
			"attack":float(window.attack), "enchant":"", "direct":false, "secondary":true, "damage_type":A.DamageType.PHYSICAL, "slow":0.0, "duration":0.0}
		context.make_read_only()
		context = b.delivery_context(context)
		for enemy in TARGETS.in_shape(b.enemies, b.position, b.facing, float(window.get("radius", 150)), false, true): b._hits.append({"target":enemy, "context":context})
		b.effects.append({"kind":"ring", "origin":b.position, "direction":b.facing, "radius":float(window.get("radius", 150)), "life":0.25, "color":"support",
			"source":str(window.owner), "ability":"guard_counter", "cast":b.cast_serial, "direct":false, "visual_time":b.director.elapsed})
	return loss

func add_shield(actor: RefCounted, amount: float, cap_ratio: float = 0.35) -> void:
	actor.shield = minf(actor.stats.hp * clampf(cap_ratio, 0, 1), actor.shield + maxf(0, amount))

func tick(delta: float) -> void:
	var b := battle()
	for id in states:
		var state: Dictionary = states[id]
		if not state.echo.is_empty():
			state.echo.life = maxf(0, float(state.echo.life) - delta)
			if state.echo.life <= 0: state.echo.clear()
		for i in range(state.rallies.size() - 1, -1, -1):
			state.rallies[i].life -= delta
			if state.rallies[i].life <= 0: state.rallies.remove_at(i)
		_refresh_rally(state)
		for key in state.windows.keys():
			if key == "rally": continue
			state.windows[key].life -= delta
			if state.windows[key].life <= 0: state.windows.erase(key)
		if state.trait == "ammo" and not b.characters[id].dead:
			state.refill -= delta
			var interval := maxf(0.1, float(state.params.get("refill_interval", 8)))
			while state.refill <= 0:
				state.refill += interval
				state.ammo = mini(int(state.params.get("capacity", 6)), int(state.ammo) + int(state.params.get("refill_amount", 2)))
	for i in range(refunds.size() - 1, -1, -1):
		var account: Dictionary = refunds[i]
		account.life -= delta
		account.until -= delta
		while account.until <= 0 and account.balance > 0.00001:
			_refund_payment(account, minf(float(account.balance), float(account.portion)))
			account.until += account.interval
		if account.life <= 0:
			_refund_payment(account, account.balance)
		if account.balance <= 0.00001: refunds.remove_at(i)
	for enemy_id in exposures.keys():
		var exposure: Dictionary = exposures[enemy_id]
		for i in range(exposure.instances.size() - 1, -1, -1):
			exposure.instances[i].life -= delta
			if exposure.instances[i].life <= 0: exposure.instances.remove_at(i)
		if exposure.instances.is_empty(): exposures.erase(enemy_id)
		else: _refresh_exposure(exposure)
	for enemy_id in curses.keys():
		var enemy := _enemy(enemy_id)
		if enemy == null or enemy.dead:
			curses.erase(enemy_id)
			continue
		var layers: Array = curses[enemy_id]
		for i in range(layers.size() - 1, -1, -1):
			var layer: Dictionary = layers[i]
			layer.accrued += float(layer.rate) * minf(delta, maxf(0, layer.life))
			layer.life -= delta
			layer.until -= delta
			if layer.until <= 0 or layer.life <= 0:
				var amount := minf(float(layer.remaining), float(layer.accrued))
				if layer.life <= 0: amount = layer.remaining
				_queue_dot(enemy, str(layer.source), amount)
				layer.remaining -= amount
				layer.accrued = 0.0
				layer.until = float(layer.interval)
			if layer.life <= 0 or layer.remaining <= 0.00001: layers.remove_at(i)
		if layers.is_empty(): curses.erase(enemy_id)
	for i in range(fields.size() - 1, -1, -1):
		var field: Dictionary = fields[i]
		field.until -= delta
		var alive_time := maxf(0, float(field.life))
		field.life -= delta
		if field.follow: field.position = b.position
		# Pulse only within the finite lifetime, including time zero. No extra terminal pulse.
		var overshoot := maxf(0, delta - alive_time)
		while field.until < -overshoot:
			_pulse_field(field)
			field.until += field.interval
		if field.life <= 0: fields.remove_at(i)

func _refund_payment(account: Dictionary, amount: float) -> void:
	var b := battle()
	amount = minf(maxf(0, amount), float(account.balance))
	account.balance -= amount
	var actor: RefCounted = b.characters.get(account.payer)
	if actor != null and not actor.dead:
		var previous: float = actor.mp
		actor.mp = minf(actor.stats.mp, actor.mp + amount)
		if amount > 0:
			b.events.append({"kind":"mechanic", "mechanic":"refund", "id":str(account.owner), "payer":str(account.payer), "amount":actor.mp - previous, "balance":float(account.balance)})

func _enemy(id: int) -> RefCounted:
	for enemy in battle().enemies:
		if enemy.id == id: return enemy
	return null

func _queue_dot(enemy: RefCounted, owner: String, amount: float) -> void:
	if amount <= 0: return
	var context := {"source":owner, "ability":"curse_dot", "cast":0, "damage":amount, "enchant":"", "direct":false, "secondary":true,
		"damage_type":A.DamageType.MAGIC, "slow":0.0, "duration":0.0}
	context.make_read_only()
	battle()._hits.append({"target":enemy, "context":context})

func _pulse_field(field: Dictionary) -> void:
	var b := battle()
	var pulse: Dictionary = b.delivery_context(field.context)
	for enemy in TARGETS.in_shape(b.enemies, field.position, Vector2.RIGHT, field.radius, false, true): b._hits.append({"target":enemy, "context":pulse})
	for actor in receivers(b.characters[field.source], field.scope):
		# Shared controlled-body position is intentional; inactive bodies have no separate world positions.
		if b.position.distance_to(field.position) <= field.radius:
			actor.hp = minf(actor.stats.hp, actor.hp + field.heal)
			actor.mp = minf(actor.stats.mp, actor.mp + field.mana)
	b.effects.append({"kind":"ring", "origin":field.position, "radius":field.radius, "life":0.3, "color":"support", "direction":Vector2.RIGHT,
		"source":field.source, "ability":field.context.ability, "cast":field.context.cast, "direct":false, "visual_time":b.director.elapsed})

func status(id: String) -> Dictionary:
	var b := battle()
	if not states.has(id): return {}
	var actor: RefCounted = b.characters[id]
	var state: Dictionary = states[id]
	var result := {"id":id, "dead":actor.dead, "shield":actor.shield, "core":str(state.trait), "label":"", "value":0.0, "max":0.0, "remaining":0.0,
		"detail":"", "support_available":not actor.dead and C.definition(id).support != null}
	var core: String = state.trait
	if core.is_empty():
		if state.windows.has("guard"): core = "guard"
		elif state.windows.has("temper"): core = "temper"
		elif actor.shield > 0: core = "shield"
	result.core = core
	match core:
		"echo":
			result.label = "法术记录"
			if not state.echo.is_empty(): result.value = float(state.echo.remaining); result.max = float(state.echo.capacity); result.remaining = float(state.echo.life)
		"ammo":
			result.label = "箭"
			result.value = float(state.ammo)
			result.max = float(state.params.get("capacity", 6))
			result.remaining = float(state.refill)
		"refund":
			result.label = "未返魔法"
			for account in refunds:
				if account.owner == id:
					result.value += float(account.balance)
					result.remaining = maxf(result.remaining, float(account.life))
		"relay": result.label = "接续"; result.detail = last_payer
		"mark": result.label = "追击准备"; result.value = float(state.mark); result.max = float(state.params.get("hits", 3))
		"guard", "temper":
			result.label = "护势" if core == "guard" else "淬刃"
			var window: Dictionary = state.windows.get(core, {})
			if not window.is_empty(): result.remaining = float(window.life); result.value = float(window.charges) if core == "guard" else float(window.life)
		"shield": result.label = "护盾"; result.value = actor.shield; result.max = actor.stats.hp * 0.35
		"curse": result.label = "咒伤"; result.detail = "命中施咒"
	result.windows = []
	for key in state.windows:
		var window: Dictionary = state.windows[key]
		result.windows.append({"key":key, "remaining":float(window.life), "charges":int(window.get("charges", 0))})
	return result

func clear() -> void:
	states.clear()
	curses.clear()
	exposures.clear()
	refunds.clear()
	fields.clear()
	spread_targets.clear()
	spark_casts.clear()
	last_payer = ""
