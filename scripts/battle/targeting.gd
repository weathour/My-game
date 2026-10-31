extends RefCounted
## Bounded first-slice query. Does not know roles, input, or the current scene.
static func nearest(enemies: Array, origin: Vector2, reach: float, previous_id: int = -1) -> RefCounted:
	var selected: RefCounted
	var previous: RefCounted
	var distance := reach * reach
	for enemy in enemies:
		if enemy.dead or not enemy.targetable: continue
		var candidate: float = origin.distance_squared_to(enemy.position)
		if enemy.id == previous_id and candidate <= reach * reach: previous = enemy
		if candidate <= distance:
			distance = candidate
			selected = enemy
	if previous != null and (selected == null or distance >= origin.distance_squared_to(previous.position) * 0.49): return previous
	return selected

static func in_shape(enemies: Array, origin: Vector2, direction: Vector2, reach: float, narrow: bool, circle: bool) -> Array:
	var result: Array = []
	for enemy in enemies:
		if enemy.dead or not enemy.targetable: continue
		var offset: Vector2 = enemy.position - origin
		if offset.length() > reach + enemy.radius: continue
		if circle or (offset.dot(direction) >= -enemy.radius and (absf(offset.cross(direction)) < 22 + enemy.radius if narrow else offset.normalized().dot(direction) > 0.15)):
			result.append(enemy)
	return result
