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

static func draw(painter: CanvasItem, g: Dictionary, active: bool = false) -> void:
	var points := outline(g)
	if points.size() < 3: return
	var phase := str(g.get("phase", "active" if active else "tell"))
	var amount := clampf(1 - float(g.get("remaining", 0)) / maxf(.001, float(g.get("total", 1))), 0, 1)
	var supportive: bool = str(g.get("action_id", "")) in ["heal", "command", "summon"]
	var color := Color("9dccb4") if supportive else Color("ffb76f") if phase == "tell" else Color("ff694f")
	# The body may cross this area; top-layer boundary remains visible above it.
	painter.draw_colored_polygon(points, Color(color, .10 + .11 * amount if phase == "tell" else .24))
	var closed := points.duplicate()
	closed.append(points[0])
	painter.draw_polyline(closed, Color(color, .9), 2.0, true)
	var center: Vector2 = g.get("origin", Vector2.ZERO)
	if phase == "tell":
		painter.draw_arc(center, 9, -PI / 2, -PI / 2 + TAU * amount, 20, color, 2, true)
