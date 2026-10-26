extends RefCounted


static func update_camera_shake(owner, delta: float) -> void:
	if owner.camera_node == null:
		return
	if preload("res://scripts/game_settings.gd").comfort_enabled("reduced_motion"):
		owner.camera_shake_time = 0.0
		owner.external_camera_shake_time = 0.0
		owner.camera_node.offset = owner.camera_base_offset
		return
	if owner.camera_shake_time <= 0.0 and owner.external_camera_shake_time <= 0.0:
		owner.camera_node.offset = owner.camera_base_offset
		return

	owner.camera_shake_time = max(0.0, owner.camera_shake_time - delta)
	owner.external_camera_shake_time = max(0.0, owner.external_camera_shake_time - delta)
	var active_strength: float = max(owner.camera_shake_strength, owner.external_camera_shake_strength if owner.external_camera_shake_time > 0.0 else 0.0)
	var shake_x: float = randf_range(-active_strength, active_strength)
	var shake_y: float = randf_range(-active_strength, active_strength)
	owner.camera_node.offset = owner.camera_base_offset + Vector2(shake_x, shake_y)
	owner.camera_shake_strength = lerpf(owner.camera_shake_strength, 0.0, min(1.0, delta * 14.0))
	if owner.external_camera_shake_time <= 0.0:
		owner.external_camera_shake_strength = 0.0
	if owner.camera_shake_time <= 0.0 and owner.external_camera_shake_time <= 0.0:
		owner.camera_node.offset = owner.camera_base_offset


static func queue_camera_shake(owner, strength: float, duration: float) -> void:
	owner.camera_shake_strength = max(owner.camera_shake_strength, strength)
	owner.camera_shake_time = max(owner.camera_shake_time, duration)


static func queue_external_camera_shake(owner, strength: float, duration: float) -> void:
	owner.external_camera_shake_strength = max(owner.external_camera_shake_strength, strength)
	owner.external_camera_shake_time = max(owner.external_camera_shake_time, duration)
