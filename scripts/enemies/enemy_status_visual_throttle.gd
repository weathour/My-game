extends RefCounted


static func should_update_status_visual_frame(enemy) -> bool:
	var interval := get_status_visual_refresh_interval(enemy)
	if interval <= 1:
		enemy.status_visual_refresh_frame = -1
		return true
	var current_frame := Engine.get_physics_frames()
	if int(enemy.status_visual_refresh_frame) < 0:
		enemy.status_visual_refresh_frame = current_frame + int(enemy.get_instance_id() % interval)
	if current_frame < int(enemy.status_visual_refresh_frame):
		return false
	enemy.status_visual_refresh_frame = current_frame + interval
	return true


static func get_status_visual_refresh_interval(enemy) -> int:
	if str(enemy.enemy_kind) != "normal" or str(enemy.secondary_behavior_id) != "" or enemy.boss_visual_instance != null or bool(enemy._is_dasher):
		return 1
	if float(enemy.hit_flash_remaining) > 0.0:
		return 2
	return 3


static func has_status_visual_pressure(enemy) -> bool:
	if str(enemy.enemy_kind) != "normal" or str(enemy.secondary_behavior_id) != "" or bool(enemy._is_dasher) or enemy.boss_visual_instance != null:
		return true
	if enemy.status_root == null and bool(enemy._is_scene_under_enemy_pressure()):
		return false
	return float(enemy.slow_timer) > 0.0 or float(enemy.vulnerability_timer) > 0.0
