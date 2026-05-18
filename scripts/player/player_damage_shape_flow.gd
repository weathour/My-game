extends RefCounted


static func is_enemy_inside_cone_edge(offset: Vector2, forward: Vector2, cone_range: float, half_angle: float, hit_radius: float) -> bool:
	var side: Vector2 = forward.orthogonal()
	var forward_distance: float = offset.dot(forward)
	if forward_distance < -hit_radius or forward_distance > cone_range + hit_radius:
		return false
	var allowed_side_distance: float = max(0.0, forward_distance) * tan(half_angle) + hit_radius
	return abs(offset.dot(side)) <= allowed_side_distance


static func get_shape_bounds(shape: Dictionary) -> Rect2:
	var shape_type: String = str(shape.get("type", "circle"))
	if shape_type == "line":
		var start_position: Vector2 = shape.get("start", Vector2.ZERO)
		var end_position: Vector2 = shape.get("end", start_position)
		var width: float = max(1.0, float(shape.get("width", 1.0)))
		var rect := Rect2(start_position, Vector2.ZERO).expand(end_position)
		return rect.grow(width + 48.0)
	if shape_type == "oriented_rect":
		var center: Vector2 = shape.get("center", Vector2.ZERO)
		var broad_size: float = float(shape.get("length", 1.0)) + float(shape.get("width", 1.0)) + 80.0
		return Rect2(center - Vector2.ONE * broad_size * 0.5, Vector2.ONE * broad_size)
	if shape_type == "cone":
		var origin: Vector2 = shape.get("origin", Vector2.ZERO)
		var direction: Vector2 = shape.get("direction", Vector2.RIGHT)
		if direction.length_squared() <= 0.001:
			direction = Vector2.RIGHT
		var cone_range: float = max(1.0, float(shape.get("range", 1.0)))
		var center: Vector2 = origin + direction.normalized() * cone_range * 0.5
		var broad_size: float = cone_range * 2.0
		return Rect2(center - Vector2.ONE * broad_size * 0.5, Vector2.ONE * broad_size)
	if shape_type == "ellipse":
		var ellipse_center: Vector2 = shape.get("center", Vector2.ZERO)
		var horizontal_radius: float = max(1.0, float(shape.get("horizontal_radius", 1.0)))
		var vertical_radius: float = max(1.0, float(shape.get("vertical_radius", 1.0)))
		return Rect2(ellipse_center - Vector2(horizontal_radius, vertical_radius), Vector2(horizontal_radius * 2.0, vertical_radius * 2.0)).grow(48.0)
	var circle_center: Vector2 = shape.get("center", Vector2.ZERO)
	var radius: float = max(1.0, float(shape.get("radius", 1.0)))
	return Rect2(circle_center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)


static func shape_hits_enemy(shape: Dictionary, enemy_position: Vector2, hit_radius: float) -> bool:
	var shape_type: String = str(shape.get("type", "circle"))
	if shape_type == "line":
		return line_hits_enemy(shape, enemy_position, hit_radius)
	if shape_type == "oriented_rect":
		return oriented_rect_hits_enemy(shape, enemy_position, hit_radius)
	if shape_type == "cone":
		return cone_hits_enemy(shape, enemy_position, hit_radius)
	if shape_type == "ellipse":
		return ellipse_hits_enemy(shape, enemy_position, hit_radius)
	var circle_center: Vector2 = shape.get("center", Vector2.ZERO)
	var total_radius: float = float(shape.get("radius", 1.0)) + hit_radius
	return circle_center.distance_squared_to(enemy_position) <= total_radius * total_radius


static func line_hits_enemy(shape: Dictionary, enemy_position: Vector2, hit_radius: float) -> bool:
	var start_position: Vector2 = shape.get("start", Vector2.ZERO)
	var end_position: Vector2 = shape.get("end", start_position)
	var axis: Vector2 = end_position - start_position
	var length: float = axis.length()
	if length <= 0.001:
		var fallback_radius: float = float(shape.get("width", 1.0)) + hit_radius
		return start_position.distance_squared_to(enemy_position) <= fallback_radius * fallback_radius
	var direction: Vector2 = axis / length
	var relative: Vector2 = enemy_position - start_position
	var along: float = clamp(relative.dot(direction), 0.0, length)
	var closest: Vector2 = start_position + direction * along
	var total_width: float = float(shape.get("width", 1.0)) + hit_radius
	return enemy_position.distance_squared_to(closest) <= total_width * total_width


static func oriented_rect_hits_enemy(shape: Dictionary, enemy_position: Vector2, hit_radius: float) -> bool:
	var rect_direction: Vector2 = shape.get("axis", Vector2.RIGHT)
	rect_direction = rect_direction.normalized()
	if rect_direction.length_squared() <= 0.001:
		rect_direction = Vector2.RIGHT
	var perpendicular: Vector2 = rect_direction.orthogonal()
	var relative_rect: Vector2 = enemy_position - Vector2(shape.get("center", Vector2.ZERO))
	return abs(relative_rect.dot(rect_direction)) <= float(shape.get("length", 1.0)) * 0.5 + hit_radius and abs(relative_rect.dot(perpendicular)) <= float(shape.get("width", 1.0)) * 0.5 + hit_radius


static func cone_hits_enemy(shape: Dictionary, enemy_position: Vector2, hit_radius: float) -> bool:
	var origin: Vector2 = shape.get("origin", Vector2.ZERO)
	var forward: Vector2 = shape.get("direction", Vector2.RIGHT)
	forward = forward.normalized()
	if forward.length_squared() <= 0.001:
		forward = Vector2.RIGHT
	var safe_range: float = max(1.0, float(shape.get("range", 1.0)))
	var half_angle: float = max(0.0, float(shape.get("angle", 0.0)) * 0.5)
	var enemy_offset: Vector2 = enemy_position - origin
	var distance: float = enemy_offset.length()
	if distance > safe_range + hit_radius:
		return false
	if distance <= hit_radius:
		return true
	var enemy_direction: Vector2 = enemy_offset / distance
	return enemy_direction.dot(forward) >= cos(half_angle) or is_enemy_inside_cone_edge(enemy_offset, forward, safe_range, half_angle, hit_radius)


static func ellipse_hits_enemy(shape: Dictionary, enemy_position: Vector2, hit_radius: float) -> bool:
	var ellipse_center: Vector2 = shape.get("center", Vector2.ZERO)
	var horizontal_radius: float = max(1.0, float(shape.get("horizontal_radius", 1.0)) + hit_radius)
	var vertical_radius: float = max(1.0, float(shape.get("vertical_radius", 1.0)) + hit_radius)
	var ellipse_relative: Vector2 = enemy_position - ellipse_center
	return pow(ellipse_relative.x / horizontal_radius, 2.0) + pow(ellipse_relative.y / vertical_radius, 2.0) <= 1.0
