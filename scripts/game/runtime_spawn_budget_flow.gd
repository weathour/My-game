extends RefCounted


static func can_spawn_runtime_group(main: Node, group_name: String, fallback_limit: int) -> bool:
	reset_runtime_spawn_budget_if_needed(main)
	if not has_runtime_spawn_frame_budget(main, group_name):
		return false
	var reserved_count: int = int(main.runtime_spawn_counts.get(group_name, 0))
	var can_spawn: bool = bool(main.PERFORMANCE_GUARD.can_spawn_in_group_with_reserved(main, group_name, get_runtime_group_limit(main, group_name, fallback_limit), reserved_count))
	if can_spawn:
		main.runtime_spawn_counts[group_name] = reserved_count + 1
	return can_spawn


static func trim_spawn_count_for_group(main: Node, group_name: String, requested_count: int, fallback_limit: int) -> int:
	reset_runtime_spawn_budget_if_needed(main)
	var reserved_count: int = int(main.runtime_spawn_counts.get(group_name, 0))
	var allowed_count: int = int(main.PERFORMANCE_GUARD.trim_requested_count_with_reserved(main, group_name, requested_count, get_runtime_group_limit(main, group_name, fallback_limit), reserved_count))
	if allowed_count > 0:
		main.runtime_spawn_counts[group_name] = reserved_count + allowed_count
	return allowed_count


static func get_runtime_group_limit(main: Node, group_name: String, fallback_limit: int) -> int:
	var base_limit: int = int(main._get_difficulty_limit(limit_key_for_group(group_name), fallback_limit))
	return main.PERFORMANCE_GUARD.get_dynamic_limit(main, group_name, base_limit)


static func reset_runtime_spawn_budget_if_needed(main: Node) -> void:
	var current_frame := Engine.get_process_frames()
	if main.runtime_spawn_budget_frame == current_frame:
		return
	main.runtime_spawn_budget_frame = current_frame
	main.runtime_spawn_counts.clear()


static func has_runtime_spawn_frame_budget(main: Node, group_name: String) -> bool:
	var limit := get_runtime_spawn_frame_limit(main, group_name)
	if limit <= 0:
		return true
	return int(main.runtime_spawn_counts.get(group_name, 0)) < limit


static func get_runtime_spawn_frame_limit(main: Node, group_name: String) -> int:
	match group_name:
		"temporary_effects":
			var fps := Engine.get_frames_per_second()
			if fps > 0 and fps < main.PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
				return 8
			if fps > 0 and fps < main.PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
				return 14
			return 24
		"player_projectiles":
			return 36
		"enemy_projectiles":
			return 28
		_:
			return 0


static func limit_key_for_group(group_name: String) -> String:
	match group_name:
		"enemies":
			return "active_enemy_limit"
		"enemy_projectiles":
			return "enemy_projectile_limit"
		"player_projectiles":
			return "player_projectile_limit"
		"temporary_effects":
			return "temporary_effect_limit"
		_:
			return ""
