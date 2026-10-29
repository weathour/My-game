extends RefCounted
## This descriptor is the single source for warning drawing and player collision.
static func contains(g: Dictionary, point: Vector2, padding: float = 16.0) -> bool:
	var origin: Vector2 = g.get("origin", Vector2.ZERO)
	var direction: Vector2 = g.get("direction", Vector2.RIGHT)
	var offset := point - origin
	var radius := float(g.get("radius", 60))
	match str(g.get("shape", "disc")):
		"line":
			return Geometry2D.get_closest_point_to_segment(point, origin, origin + direction * float(g.get("length", 240))).distance_to(point) <= float(g.get("half_width", 18)) + padding
		"sector", "fan":
			if offset.length() > radius + padding: return false
			if offset.length() <= padding: return true
			return absf(wrapf(offset.angle() - direction.angle(), -PI, PI)) <= float(g.get("spread", 1.4)) * 0.5 + asin(minf(1, padding / offset.length()))
		"ring_gap":
			if offset.length() > radius + padding: return false
			if offset.length() < float(g.get("inner_radius", 0)) - padding: return false
			var half_gap := float(g.get("gap_width", 1.2)) * 0.5
			var clearance := asin(minf(1, padding / maxf(padding, offset.length())))
			return absf(wrapf(offset.angle() - float(g.get("gap_angle", direction.angle())), -PI, PI)) >= maxf(0, half_gap - clearance)
		_: return offset.length() <= radius + padding

static func descriptor(enemy: RefCounted, action: Dictionary, actor: Vector2) -> Dictionary:
	var direction: Vector2 = (actor - enemy.position).normalized()
	if direction == Vector2.ZERO: direction = Vector2.RIGHT
	var shape := str(action.get("shape", "sector"))
	var origin: Vector2 = actor if str(action.get("shape", "")) == "marker" or str(action.get("action", action.get("id", ""))) in ["pot", "marker"] else enemy.position
	var length := float(action.get("length", 240))
	# Clip along the locked ray. Clamping x/y independently changes its angle;
	# reusing that endpoint's distance with the original direction can overshoot.
	if shape == "line": length = bounded_ray_length(origin, direction, length, enemy.radius)
	return {"action_id":str(action.get("action", action.get("id", ""))), "owner_id":enemy.id, "action_serial":enemy.action_serial, "attack_step":enemy.attack_index, "phase":"tell", "shape":shape,
		"origin":origin, "direction":direction, "length":length, "radius":float(action.get("radius", action.get("range", 70))),
		"half_width":float(action.get("half_width", enemy.radius)), "spread":float(action.get("spread", 1.7)),
		"inner_radius":float(action.get("inner_radius", 0)), "gap_angle":direction.angle() + float(action.get("gap_angle", 0)),
		"gap_width":float(action.get("gap_width", 1.2)), "remaining":float(action.get("windup", 0.9)), "total":float(action.get("windup", 0.9)),
		"visual_id":enemy.visual_id, "damage":0.0 if str(action.get("action", "")) in ["heal", "command", "summon"] else enemy.damage * float(action.get("damage_scale", 1))}

static func bounded_ray_length(origin: Vector2, direction: Vector2, requested: float, body_radius: float) -> float:
	var space = preload("res://scripts/battle/battle_space.gd")
	var lower := Vector2.ONE * body_radius
	var upper: Vector2 = space.SIZE - lower
	var length := maxf(0, requested)
	for axis in 2:
		if absf(direction[axis]) <= 0.000001: continue
		var boundary: float = upper[axis] if direction[axis] > 0 else lower[axis]
		length = minf(length, maxf(0, (boundary - origin[axis]) / direction[axis]))
	return length
