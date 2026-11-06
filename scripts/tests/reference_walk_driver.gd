extends RefCounted
## Test input only: follow real targets, avoid actual areas and visible projectiles.
const H := preload("res://scripts/battle/player_hurtbox.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const TARGET := preload("res://scripts/battle/targeting.gd")
const G := preload("res://scripts/battle/enemy_geometry.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
static func drive(battle: RefCounted) -> Vector2:
	var target: RefCounted = TARGET.nearest(battle.enemies,battle.position,4000)
	var objective: Vector2 = battle.position
	if target != null:
		var ranged: bool = C.definition(battle.current().id).basic.reach > 300
		var wanted := 245.0 if ranged else 64.0
		objective = target.position + (battle.position - target.position).normalized() * wanted
	elif not battle.gems.is_empty(): objective = battle.gems[0].position
	var desired: Vector2 = (objective - battle.position).normalized()
	var best: Vector2 = desired
	var best_score := -INF
	for index in 17:
		var direction := Vector2.ZERO if index == 16 else Vector2.RIGHT.rotated(index * TAU / 16)
		var point: Vector2 = SPACE.clamp_point(battle.position + direction * 100.0, SPACE.PLAYER_MARGIN)
		var score: float = -point.distance_to(objective) * .015
		for warning in battle.telegraphs:
			if bool(warning.get("projectile_only",false)): continue
			if G.contains_actor(warning, point): score -= 30.0
		for hazard in battle.hazards:
			if G.contains_actor(hazard, point): score -= 30.0
		for projectile in battle.projectiles:
			if not projectile.get("hostile",false): continue
			var end: Vector2 = projectile.position + projectile.velocity * .45
			if H.contains_swept(projectile.position,end,float(projectile.get("hit_radius",5))+2.0,battle.position,point): score -= 10.0
		if point.distance_to(battle.position + direction * 100.0) > 5: score -= 10.0
		if score > best_score: best_score = score; best = direction
	return best

