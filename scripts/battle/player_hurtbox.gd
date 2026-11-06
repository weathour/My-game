extends RefCounted
## One shared world-space danger core. Attack reach, pickup and body spacing stay separate.
const SPACE := preload("res://scripts/battle/battle_space.gd")
const RADIUS := 4.0

# Actor positions remain ground/foot anchors; animation bounds never move the core.
static func center(actor_position: Vector2) -> Vector2:
	return actor_position + Vector2(0, -SPACE.ACTOR_BODY_HEIGHT * 0.5)

static func contains_swept(projectile_start: Vector2, projectile_end: Vector2, projectile_radius: float, actor_start: Vector2, actor_end: Vector2) -> bool:
	var relative_start := projectile_start-center(actor_start)
	var relative_end := projectile_end-center(actor_end)
	var nearest := Geometry2D.get_closest_point_to_segment(Vector2.ZERO,relative_start,relative_end)
	return nearest.length_squared()<=pow(RADIUS+maxf(0.0,projectile_radius),2)
