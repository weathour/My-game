extends RefCounted

# A batch is synchronous. Target geometry can be shared until a hit invokes
# gameplay code, which may move, resize, switch or destroy the target.
var cached_target: Node2D
var cached := false
var position := Vector2.ZERO
var center := Vector2.ZERO
var radius := 0.0
var accepts_damage := false
var cached_physics_frame := -1


func prepare(target: Node2D) -> bool:
	if not is_instance_valid(target):
		invalidate()
		return false
	var frame := Engine.get_physics_frames()
	if cached and cached_target == target and cached_physics_frame == frame:
		return true
	cached_physics_frame = frame
	cached_target = target
	position = target.global_position
	center = target.get_hurtbox_center() if target.has_method("get_hurtbox_center") else position
	radius = float(target.get_hurtbox_radius()) if target.has_method("get_hurtbox_radius") else 0.0
	accepts_damage = target.has_method("take_damage")
	cached = true
	return true


func invalidate() -> void:
	cached = false
	cached_target = null
