extends RefCounted
## Shared world geometry. Camera pixels and texture dimensions never define play bounds.
const SIZE := Vector2(3200, 1800)
const BOUNDS := Rect2(Vector2.ZERO, SIZE)
const CENTER := SIZE * 0.5
const PLAYER_MARGIN := Vector2(55, 65)
const FIELD_POSITIONS := [Vector2(440, 320), Vector2(2760, 320), Vector2(440, 1480), Vector2(2760, 1480)]

static func clamp_point(point: Vector2, margin: Vector2 = Vector2(30, 30)) -> Vector2:
	return point.clamp(margin, SIZE - margin)

static func reinforcement(actor: Vector2, rng: RandomNumberGenerator) -> Vector2:
	# Arrivals surround the current engagement, not the far edges of a larger map.
	# This ellipse lies outside the reference camera view, with a safe approach gap.
	for attempt in 20:
		var angle := rng.randf_range(0, TAU)
		var point := actor + Vector2(cos(angle) * 760, sin(angle) * 460) * rng.randf_range(1.0, 1.25)
		if BOUNDS.grow(-45).has_point(point): return point
	return clamp_point(actor + (CENTER - actor).normalized() * 600, Vector2(45, 45))

static func challenge_position(actor: Vector2) -> Vector2:
	# Bosses and field elites arrive within the ongoing fight, including near corners.
	return clamp_point(actor + Vector2(0, 300 if actor.y < 400 else -300), Vector2(100, 100))
