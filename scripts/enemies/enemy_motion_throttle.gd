extends RefCounted

const CACHE_FRAME_KEY := "__enemy_pressure_frame"
const CACHE_VALUE_KEY := "__enemy_pressure_value"
const ENEMY_PRESSURE_THRESHOLD := 110


static func should_skip_motion_frame(enemy, delta: float) -> bool:
	var interval := get_motion_refresh_interval(enemy)
	if interval <= 1:
		enemy.throttled_motion_delta = 0.0
		return false
	var current_frame := Engine.get_physics_frames()
	if int(enemy.motion_refresh_frame) < 0:
		enemy.motion_refresh_frame = current_frame + int(enemy.get_instance_id() % interval)
	if current_frame < int(enemy.motion_refresh_frame):
		enemy.throttled_motion_delta += delta
		return true
	enemy.motion_refresh_frame = current_frame + interval
	return false


static func get_motion_refresh_interval(enemy) -> int:
	if str(enemy.enemy_kind) != "normal" or str(enemy.secondary_behavior_id) != "" or bool(enemy._has_timed_behavior_traits()):
		return 1
	# Status effects are common in late-game area skills. Do not let slow/vulnerability/bleed
	# disable movement throttling for every normal enemy that was touched by a large skill.
	if float(enemy.hit_flash_remaining) > 0.0 and not is_scene_under_enemy_pressure(enemy):
		return 1
	if is_scene_under_enemy_pressure(enemy):
		if float(enemy._cached_distance_to_target) > 760.0:
			return 4
		if float(enemy._cached_distance_to_target) > 420.0:
			return 2
	if float(enemy._cached_distance_to_target) > 1200.0:
		return 3
	if float(enemy._cached_distance_to_target) > 820.0:
		return 2
	return 1


static func is_scene_under_enemy_pressure(enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return false
	var current_frame := Engine.get_physics_frames()
	var scene: Node = enemy.get_tree().current_scene if enemy.get_tree() != null else null
	if scene == null or not scene.has_method("get_runtime_enemies"):
		return false
	if int(scene.get_meta(CACHE_FRAME_KEY, -1)) == current_frame:
		return bool(scene.get_meta(CACHE_VALUE_KEY, false))
	var pressure_active: bool = (scene.get_runtime_enemies() as Array).size() >= ENEMY_PRESSURE_THRESHOLD
	scene.set_meta(CACHE_FRAME_KEY, current_frame)
	scene.set_meta(CACHE_VALUE_KEY, pressure_active)
	return pressure_active
