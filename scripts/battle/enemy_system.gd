extends RefCounted
const SPACE := preload("res://scripts/battle/battle_space.gd")

static func step(enemies: Array, actor: Vector2, delta: float) -> Dictionary:
	var result := {"hits":[], "projectiles":[], "effects":[]}
	for enemy in enemies:
		if enemy.dead: continue
		enemy.flash = maxf(0, enemy.flash - delta)
		enemy.slow_time = maxf(0, enemy.slow_time - delta)
		if enemy.slow_time <= 0: enemy.slow = 0
		enemy.cooldown = maxf(0, enemy.cooldown - delta)
		var offset: Vector2 = actor - enemy.position
		if enemy.windup > 0:
			enemy.windup -= delta
			if enemy.windup <= 0: _release(enemy, actor, result)
			continue
		var ranged: bool = enemy.kind == "ranged"
		var distance: float = offset.length()
		var next_attack: String = enemy.attack_cycle[enemy.attack_index % enemy.attack_cycle.size()]
		var attack_range: float = enemy.blast_radius + 20 if next_attack == "nova" else enemy.attack_range
		if enemy.cooldown <= 0 and distance < attack_range:
			enemy.aim = offset.normalized()
			enemy.windup = 1.15 if next_attack == "nova" else enemy.attack_delay
			enemy.attack = next_attack
			enemy.attack_index += 1
			continue
		if not ranged or distance > 230:
			var movement: Vector2 = offset.normalized()
			# Modest local separation; fixed population limit keeps this slice bounded.
			for other in enemies:
				if other == enemy or other.dead: continue
				var gap: Vector2 = enemy.position - other.position
				if gap.length_squared() > 0.01 and gap.length_squared() < pow(enemy.radius + other.radius, 2): movement += gap.normalized() * 0.55
			enemy.position = SPACE.clamp_point(enemy.position + movement.limit_length(1) * enemy.speed * (1 - enemy.slow) * delta, Vector2.ONE * enemy.radius)
	return result

static func _release(enemy: RefCounted, actor: Vector2, result: Dictionary) -> void:
	enemy.cooldown = enemy.recovery
	if enemy.kind == "boss" and enemy.hp < enemy.max_hp * 0.5: enemy.cooldown = 1.65
	match enemy.attack:
		"nova":
			if enemy.position.distance_to(actor) < enemy.blast_radius + 16: result.hits.append(enemy.damage * 1.2)
			result.effects.append({"kind":"ring", "origin":enemy.position, "radius":enemy.blast_radius, "life":0.35, "hostile":true})
		"shot", "fan":
			var count := (7 if enemy.hp < enemy.max_hp * 0.5 else 5) if enemy.attack == "fan" else 1
			for i in count:
				var direction: Vector2 = enemy.aim.rotated((i - (count - 1) * 0.5) * 0.23)
				result.projectiles.append({"position":enemy.position, "velocity":direction * 225, "life":5.0, "hostile":true, "damage":enemy.damage, "source":enemy.id})
		"charge":
			var start: Vector2 = enemy.position
			var end := SPACE.clamp_point(start + enemy.aim * 240, Vector2.ONE * enemy.radius)
			if Geometry2D.get_closest_point_to_segment(actor, start, end).distance_to(actor) < enemy.radius + 16:
				result.hits.append(enemy.damage)
			enemy.position = end
			result.effects.append({"kind":"line", "origin":start, "end":end, "life":0.3, "hostile":true})
		"strike":
			if enemy.position.distance_to(actor) < enemy.radius + 40: result.hits.append(enemy.damage)
			result.effects.append({"kind":"ring", "origin":enemy.position, "radius":enemy.radius + 28, "life":0.2, "hostile":true})
