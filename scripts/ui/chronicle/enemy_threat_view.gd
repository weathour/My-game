extends RefCounted
## Uses the simulation descriptor exactly. Radius never derives from body art or rank.
static func outline(g: Dictionary) -> PackedVector2Array:
	var points := PackedVector2Array()
	var center: Vector2 = g.get("origin", Vector2.ZERO)
	var direction: Vector2 = g.get("direction", Vector2.RIGHT)
	var radius := float(g.get("radius", 60))
	var angle := direction.angle()
	match str(g.get("shape", "disc")):
		"line":
			# Collision is a capsule, including round ends.
			var width := float(g.get("half_width", 18))
			var end := center + direction * float(g.get("length", 240))
			for i in 17: points.append(end + Vector2.from_angle(angle - PI / 2 + PI * i / 16) * width)
			for i in 17: points.append(center + Vector2.from_angle(angle + PI / 2 + PI * i / 16) * width)
		"sector", "fan":
			points.append(center)
			var spread := float(g.get("spread", 1.4))
			for i in 49: points.append(center + Vector2.from_angle(angle - spread * .5 + spread * i / 48) * radius)
		"ring_gap":
			var gap := float(g.get("gap_width", 1.2))
			var start := float(g.get("gap_angle", angle)) + gap * .5
			var sweep := TAU - gap
			for i in 65: points.append(center + Vector2.from_angle(start + sweep * i / 64) * radius)
			var inner := float(g.get("inner_radius", 0))
			if inner > 0:
				for i in 65: points.append(center + Vector2.from_angle(start + sweep * (64 - i) / 64) * inner)
			else: points.append(center)
		_:
			for i in 64: points.append(center + Vector2.from_angle(TAU * i / 64) * radius)
	return points

## Ordinary visible bullets describe their danger with their own cores. Only a
## deliberately aimed fast shot asks for a line; ground and melee areas stay exact.
static func warning_policy(g: Dictionary) -> String:
	var configured := str(g.get("warning_policy", ""))
	if configured in ["area", "aim", "none"]: return configured
	return "none" if str(g.get("action_id", "")) in ["shot", "fan"] else "area"

static func is_area_impact(g: Dictionary) -> bool:
	return not g.is_empty() and not bool(g.get("projectile_only", false)) and warning_policy(g) == "area" and float(g.get("damage", 1)) > 0

static func impact_outline(g: Dictionary) -> PackedVector2Array:
	return outline(g) if is_area_impact(g) else PackedVector2Array()

static func visible(g: Dictionary) -> bool:
	return warning_policy(g) != "none"

static func draw(painter: CanvasItem, g: Dictionary, active: bool = false, world_scale: float = 1.0) -> void:
	var policy := warning_policy(g)
	if policy == "none": return
	var phase := str(g.get("phase", "active" if active else "tell"))
	var amount := clampf(1 - float(g.get("remaining", 0)) / maxf(.001, float(g.get("total", 1))), 0, 1)
	var supportive: bool = str(g.get("action_id", "")) in ["heal", "command", "summon"]
	var color := Color("9dccb4") if supportive else Color("ffc075") if phase == "tell" else Color("ff7759")
	var center: Vector2 = g.get("origin", Vector2.ZERO)
	var stroke := 1.5 / maxf(.25, world_scale)
	if policy == "aim":
		if phase != "tell": return
		var direction: Vector2 = g.get("direction", Vector2.RIGHT)
		var reach := float(g.get("length", 0)) if str(g.get("shape", "")) == "line" else float(g.get("radius", 400))
		var end := center + direction * reach
		painter.draw_line(center, end, Color("1c1313", .75), stroke * 2.4, true)
		painter.draw_line(center, end, Color(color, .72), stroke, true)
		var tip := center + direction * minf(reach, 34.0)
		painter.draw_polyline(PackedVector2Array([tip - direction.rotated(-.55) * 11, tip, tip - direction.rotated(.55) * 11]), color, stroke, true)
		return
	var points := outline(g)
	if points.size() < 3: return
	# Danger edges outrank decoration. Low-opacity interiors leave overlapping
	# patterns, the controlled dot and solid projectiles readable at high density.
	painter.draw_colored_polygon(points, Color(color, .035 + .035 * amount if phase == "tell" else .09))
	var closed := points.duplicate()
	closed.append(points[0])
	painter.draw_polyline(closed, Color("21181b", .70), stroke * 2.5, true)
	painter.draw_polyline(closed, Color(color, .92), stroke, true)
	if phase == "tell":
		painter.draw_arc(center, 9, -PI / 2, -PI / 2 + TAU * amount, 20, color, stroke, true)
