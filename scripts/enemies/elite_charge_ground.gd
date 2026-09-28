extends Node2D

const DURATION := 3.0
const DAMAGE_RATIO := 0.01
const SLOW_MULTIPLIER := 0.7
const SOURCES_META := "elite_charge_ground_sources"
const DEFAULT_SIZE := Vector2(200.0, 80.0)

var size := DEFAULT_SIZE
var elapsed: float = 0.0
var bodies: Dictionary = {}


func _ready() -> void:
	z_index = 11
	var half := size * 0.5
	var corners := PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y)
	])
	var fill := Polygon2D.new()
	fill.polygon = corners
	fill.color = Color(0.92, 0.16, 0.1, 0.28)
	add_child(fill)
	var outline := Line2D.new()
	corners.append(corners[0])
	outline.points = corners
	outline.width = 3.0
	outline.default_color = Color(1.0, 0.38, 0.22, 0.82)
	add_child(outline)
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	add_child(area)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	area.add_child(collision)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if elapsed >= DURATION or bodies.has(body) or not body.has_method("take_damage") or body.get("max_health") == null:
		return
	bodies[body] = elapsed + 1.0
	var sources: Dictionary = body.get_meta(SOURCES_META, {})
	sources[get_instance_id()] = weakref(self)
	body.set_meta(SOURCES_META, sources)
	_damage(body)


func _on_body_exited(body) -> void:
	bodies.erase(body)
	if not is_instance_valid(body):
		return
	var sources: Dictionary = body.get_meta(SOURCES_META, {})
	sources.erase(get_instance_id())
	if sources.is_empty():
		body.remove_meta(SOURCES_META)
	else:
		body.set_meta(SOURCES_META, sources)


func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		for body in bodies.keys():
			_on_body_exited(body)
		queue_free()
		return
	for body in bodies.keys():
		if not is_instance_valid(body):
			bodies.erase(body)
			continue
		if elapsed >= float(bodies[body]):
			bodies[body] = float(bodies[body]) + 1.0
			_damage(body)


func _exit_tree() -> void:
	for body in bodies.keys():
		_on_body_exited(body)


func _damage(body: Node) -> void:
	body.take_damage(maxf(0.0, float(body.get("max_health"))) * DAMAGE_RATIO)


static func get_slow_multiplier(body: Object) -> float:
	if body.has_method("_is_status_immune") and body._is_status_immune():
		return 1.0
	var sources: Dictionary = body.get_meta(SOURCES_META, {})
	for source in sources.values():
		var area = source.get_ref()
		if area != null and is_instance_valid(area) and not area.is_queued_for_deletion() and area.elapsed < DURATION:
			return SLOW_MULTIPLIER
	return 1.0
