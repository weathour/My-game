extends Node

const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")
const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")

const MAX_DAMAGE_APPLICATIONS_PER_RENDER_FRAME := 24
const LARGE_QUEUE_DAMAGE_APPLICATIONS_PER_RENDER_FRAME := 56
const CRITICAL_QUEUE_DAMAGE_APPLICATIONS_PER_RENDER_FRAME := 96
const LARGE_QUEUE_SIZE := 96
const CRITICAL_QUEUE_SIZE := 220
const COMPACT_CURSOR_THRESHOLD := 64
const FEEDBACK_DAMAGE_JOBS_PER_RENDER_FRAME := 8
const LOW_FPS_FEEDBACK_DAMAGE_JOBS_PER_RENDER_FRAME := 4
const CRITICAL_FPS_FEEDBACK_DAMAGE_JOBS_PER_RENDER_FRAME := 2
const DAMAGE_QUEUE_TIME_BUDGET_USEC := 1100
const LOW_FPS_DAMAGE_QUEUE_TIME_BUDGET_USEC := 800
const CRITICAL_FPS_DAMAGE_QUEUE_TIME_BUDGET_USEC := 550
const MIN_DAMAGE_APPLICATIONS_PER_RENDER_FRAME := 8

var source_player: Node
var enemy_refs: Array[WeakRef] = []
var enemy_ids: Array[int] = []
var damage_amounts: PackedFloat32Array = PackedFloat32Array()
var hit_counts: Array[int] = []
var source_role_ids: PackedStringArray = PackedStringArray()
var vulnerability_bonuses: PackedFloat32Array = PackedFloat32Array()
var vulnerability_durations: PackedFloat32Array = PackedFloat32Array()
var slow_multipliers: PackedFloat32Array = PackedFloat32Array()
var slow_durations: PackedFloat32Array = PackedFloat32Array()
var source_positions: Array = []
var kill_energy_bonuses: PackedFloat32Array = PackedFloat32Array()
var prefer_silent_feedbacks: Array[bool] = []
var job_cursor: int = 0
var pending_by_enemy_id: Dictionary = {}
var last_processed_render_frame: int = -1
var feedback_jobs_used_this_frame: int = 0
var attack_results_by_role: Dictionary = {}
var pending_kill_energy: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func configure(owner: Node) -> void:
	source_player = owner


func enqueue(job: Dictionary) -> void:
	if not job.has("enemy_ref"):
		return
	enqueue_values(
		job.get("enemy_ref", null) as WeakRef,
		int(job.get("enemy_id", 0)),
		float(job.get("damage_amount", 0.0)),
		int(job.get("hit_count", 1)),
		str(job.get("source_role_id", "")),
		float(job.get("vulnerability_bonus", 0.0)),
		float(job.get("vulnerability_duration", 2.0)),
		float(job.get("slow_multiplier", 1.0)),
		float(job.get("slow_duration", 0.0)),
		job.get("source_position", null),
		float(job.get("kill_energy_bonus", 0.0)),
		bool(job.get("prefer_silent_feedback", false))
	)


func enqueue_values(enemy_ref: WeakRef, enemy_id: int, damage_amount: float, hit_count: int, source_role_id: String, vulnerability_bonus: float = 0.0, vulnerability_duration: float = 2.0, slow_multiplier: float = 1.0, slow_duration: float = 0.0, source_position: Variant = null, kill_energy_bonus: float = 0.0, prefer_silent_feedback: bool = false) -> void:
	if enemy_ref == null:
		return
	if enemy_id != 0:
		var pending_index: int = int(pending_by_enemy_id.get(enemy_id, -1))
		if pending_index >= job_cursor and pending_index < enemy_refs.size():
			_merge_job_at_index(pending_index, damage_amount, hit_count, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, kill_energy_bonus, prefer_silent_feedback)
			PERFORMANCE_COUNTERS.add("merged_damage_jobs", 1)
			return
	enemy_refs.append(enemy_ref)
	enemy_ids.append(enemy_id)
	damage_amounts.append(damage_amount)
	hit_counts.append(hit_count)
	source_role_ids.append(source_role_id)
	vulnerability_bonuses.append(vulnerability_bonus)
	vulnerability_durations.append(vulnerability_duration)
	slow_multipliers.append(slow_multiplier)
	slow_durations.append(slow_duration)
	source_positions.append(source_position)
	kill_energy_bonuses.append(kill_energy_bonus)
	prefer_silent_feedbacks.append(prefer_silent_feedback)
	if enemy_id != 0:
		pending_by_enemy_id[enemy_id] = enemy_refs.size() - 1
	PERFORMANCE_COUNTERS.add("queued_damage_jobs", 1)


func _physics_process(_delta: float) -> void:
	var render_frame := Engine.get_process_frames()
	if last_processed_render_frame == render_frame:
		return
	last_processed_render_frame = render_frame
	feedback_jobs_used_this_frame = 0
	attack_results_by_role.clear()
	pending_kill_energy = 0.0
	var queue_size := _queue_size()
	if queue_size <= 0:
		_compact_processed_jobs(true)
		PERFORMANCE_COUNTERS.add("damage_queue_size", 0)
		return
	PERFORMANCE_COUNTERS.add("damage_queue_size", queue_size)
	if source_player == null or not is_instance_valid(source_player):
		_clear_jobs()
		job_cursor = 0
		pending_by_enemy_id.clear()
		return
	var processed := 0
	var process_limit := _get_frame_process_limit(queue_size)
	var frame_start_usec := Time.get_ticks_usec()
	while processed < process_limit and job_cursor < enemy_refs.size():
		if processed >= MIN_DAMAGE_APPLICATIONS_PER_RENDER_FRAME and Time.get_ticks_usec() - frame_start_usec >= _get_frame_time_budget_usec():
			break
		var current_index := job_cursor
		job_cursor += 1
		var enemy_id: int = enemy_ids[current_index]
		if enemy_id != 0:
			pending_by_enemy_id.erase(enemy_id)
		_apply_job_at_index(current_index)
		processed += 1
	_flush_pending_kill_energy()
	_flush_attack_results()
	_compact_processed_jobs(false)
	PERFORMANCE_COUNTERS.add("applied_damage_jobs", processed)


func _apply_job_at_index(index: int) -> void:
	var enemy_ref: WeakRef = enemy_refs[index]
	if enemy_ref == null:
		return
	var enemy: Node = enemy_ref.get_ref() as Node
	if enemy == null or not is_instance_valid(enemy):
		return
	var damage_amount: float = damage_amounts[index]
	var source_role_id: String = source_role_ids[index]
	var vulnerability_bonus: float = vulnerability_bonuses[index]
	var vulnerability_duration: float = vulnerability_durations[index]
	var slow_multiplier: float = slow_multipliers[index]
	var slow_duration: float = slow_durations[index]
	var source_position: Variant = source_positions[index]
	var kill_energy_bonus: float = kill_energy_bonuses[index]
	var killed := false
	if source_player.has_method("_deal_damage_to_enemy"):
		var prefer_silent: bool = prefer_silent_feedbacks[index]
		if prefer_silent and enemy.has_method("take_batched_damage"):
			killed = bool(_deal_batched_damage_to_enemy(enemy, damage_amount, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position, kill_energy_bonus))
		else:
			killed = bool(source_player._deal_damage_to_enemy(enemy, damage_amount, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position))
			if killed and kill_energy_bonus > 0.0 and source_player.has_method("_add_kill_energy"):
				_queue_kill_energy(kill_energy_bonus)
	elif enemy.has_method("take_damage"):
		killed = bool(enemy.take_damage(damage_amount))
	_queue_attack_result(source_role_id, hit_counts[index], killed)


func _merge_job_at_index(index: int, damage_amount: float, hit_count: int, vulnerability_bonus: float, vulnerability_duration: float, slow_multiplier: float, slow_duration: float, kill_energy_bonus: float, prefer_silent_feedback: bool) -> void:
	damage_amounts[index] = damage_amounts[index] + damage_amount
	hit_counts[index] = hit_counts[index] + hit_count
	prefer_silent_feedbacks[index] = prefer_silent_feedbacks[index] or prefer_silent_feedback
	vulnerability_bonuses[index] = max(vulnerability_bonuses[index], vulnerability_bonus)
	vulnerability_durations[index] = max(vulnerability_durations[index], vulnerability_duration)
	slow_multipliers[index] = min(slow_multipliers[index], slow_multiplier)
	slow_durations[index] = max(slow_durations[index], slow_duration)
	kill_energy_bonuses[index] = max(kill_energy_bonuses[index], kill_energy_bonus)


func _queue_attack_result(role_id: String, hit_count: int, killed: bool) -> void:
	if role_id == "" or hit_count <= 0:
		return
	if not attack_results_by_role.has(role_id):
		attack_results_by_role[role_id] = {
			"hit_count": 0,
			"killed": false
		}
	var result: Dictionary = attack_results_by_role[role_id]
	result["hit_count"] = int(result.get("hit_count", 0)) + hit_count
	result["killed"] = bool(result.get("killed", false)) or killed
	attack_results_by_role[role_id] = result


func _flush_attack_results() -> void:
	if attack_results_by_role.is_empty():
		return
	if source_player == null or not is_instance_valid(source_player) or not source_player.has_method("_register_attack_result"):
		attack_results_by_role.clear()
		return
	for role_id in attack_results_by_role.keys():
		var result: Dictionary = attack_results_by_role[role_id]
		source_player._register_attack_result(str(role_id), int(result.get("hit_count", 0)), bool(result.get("killed", false)))
	attack_results_by_role.clear()


func _queue_kill_energy(amount: float) -> void:
	if amount <= 0.0:
		return
	pending_kill_energy += amount


func _flush_pending_kill_energy() -> void:
	if pending_kill_energy <= 0.0:
		return
	if source_player != null and is_instance_valid(source_player) and source_player.has_method("_add_kill_energy"):
		source_player._add_kill_energy(pending_kill_energy)
	pending_kill_energy = 0.0


func _deal_batched_damage_to_enemy(enemy: Node, damage_amount: float, source_role_id: String, vulnerability_bonus: float, vulnerability_duration: float, slow_multiplier: float, slow_duration: float, source_position: Variant, kill_energy_bonus: float) -> bool:
	var final_damage := damage_amount
	if source_role_id == "gunner" and source_player.has_method("_get_gunner_distance_damage_multiplier"):
		var attack_origin: Vector2 = source_player.global_position
		if source_position is Vector2:
			attack_origin = source_position
		if enemy is Node2D:
			final_damage *= float(source_player._get_gunner_distance_damage_multiplier(attack_origin.distance_to((enemy as Node2D).global_position)))
	var show_feedback := feedback_jobs_used_this_frame < _get_feedback_jobs_per_render_frame()
	feedback_jobs_used_this_frame += 1
	var killed := false
	if show_feedback and enemy.has_method("take_damage"):
		killed = bool(enemy.take_damage(final_damage))
	elif enemy.has_method("take_batched_damage"):
		killed = bool(enemy.take_batched_damage(final_damage))
	elif enemy.has_method("take_damage"):
		killed = bool(enemy.take_damage(final_damage))
	if source_player.has_method("_apply_role_damage_lifesteal"):
		source_player._apply_role_damage_lifesteal(source_role_id, final_damage)
	if str(enemy.get("enemy_kind")) == "boss" and source_player.has_method("_get_boss_damage_energy"):
		_queue_kill_energy(source_player._get_boss_damage_energy(final_damage))
	if killed and source_player.has_method("_get_kill_energy_from_enemy"):
		_queue_kill_energy(source_player._get_kill_energy_from_enemy(enemy))
		if kill_energy_bonus > 0.0:
			_queue_kill_energy(kill_energy_bonus)
	if vulnerability_bonus > 0.0 and enemy.has_method("apply_vulnerability"):
		enemy.apply_vulnerability(vulnerability_bonus, vulnerability_duration)
	if slow_duration > 0.0 and enemy.has_method("apply_slow"):
		enemy.apply_slow(slow_multiplier, slow_duration)
	return killed


func _queue_size() -> int:
	return max(0, enemy_refs.size() - job_cursor)


func _get_frame_process_limit(queue_size: int) -> int:
	if queue_size >= CRITICAL_QUEUE_SIZE:
		return CRITICAL_QUEUE_DAMAGE_APPLICATIONS_PER_RENDER_FRAME
	if queue_size >= LARGE_QUEUE_SIZE:
		return LARGE_QUEUE_DAMAGE_APPLICATIONS_PER_RENDER_FRAME
	return MAX_DAMAGE_APPLICATIONS_PER_RENDER_FRAME


func _get_feedback_jobs_per_render_frame() -> int:
	var fps := Engine.get_frames_per_second()
	if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return CRITICAL_FPS_FEEDBACK_DAMAGE_JOBS_PER_RENDER_FRAME
	if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return LOW_FPS_FEEDBACK_DAMAGE_JOBS_PER_RENDER_FRAME
	return FEEDBACK_DAMAGE_JOBS_PER_RENDER_FRAME


func _get_frame_time_budget_usec() -> int:
	var fps := Engine.get_frames_per_second()
	if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return CRITICAL_FPS_DAMAGE_QUEUE_TIME_BUDGET_USEC
	if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return LOW_FPS_DAMAGE_QUEUE_TIME_BUDGET_USEC
	return DAMAGE_QUEUE_TIME_BUDGET_USEC


func _compact_processed_jobs(force: bool) -> void:
	if job_cursor <= 0:
		return
	if force or job_cursor >= enemy_refs.size() or job_cursor >= COMPACT_CURSOR_THRESHOLD:
		var old_size: int = enemy_refs.size()
		var remaining_size: int = old_size - job_cursor
		if remaining_size <= 0:
			_clear_jobs()
			job_cursor = 0
			pending_by_enemy_id.clear()
			return
		for write_index in range(remaining_size):
			var read_index: int = write_index + job_cursor
			enemy_refs[write_index] = enemy_refs[read_index]
			enemy_ids[write_index] = enemy_ids[read_index]
			damage_amounts[write_index] = damage_amounts[read_index]
			hit_counts[write_index] = hit_counts[read_index]
			source_role_ids[write_index] = source_role_ids[read_index]
			vulnerability_bonuses[write_index] = vulnerability_bonuses[read_index]
			vulnerability_durations[write_index] = vulnerability_durations[read_index]
			slow_multipliers[write_index] = slow_multipliers[read_index]
			slow_durations[write_index] = slow_durations[read_index]
			source_positions[write_index] = source_positions[read_index]
			kill_energy_bonuses[write_index] = kill_energy_bonuses[read_index]
			prefer_silent_feedbacks[write_index] = prefer_silent_feedbacks[read_index]
		enemy_refs.resize(remaining_size)
		enemy_ids.resize(remaining_size)
		damage_amounts.resize(remaining_size)
		hit_counts.resize(remaining_size)
		source_role_ids.resize(remaining_size)
		vulnerability_bonuses.resize(remaining_size)
		vulnerability_durations.resize(remaining_size)
		slow_multipliers.resize(remaining_size)
		slow_durations.resize(remaining_size)
		source_positions.resize(remaining_size)
		kill_energy_bonuses.resize(remaining_size)
		prefer_silent_feedbacks.resize(remaining_size)
		job_cursor = 0
		_rebuild_pending_index()


func _clear_jobs() -> void:
	enemy_refs.clear()
	enemy_ids.clear()
	damage_amounts.clear()
	hit_counts.clear()
	source_role_ids.clear()
	vulnerability_bonuses.clear()
	vulnerability_durations.clear()
	slow_multipliers.clear()
	slow_durations.clear()
	source_positions.clear()
	kill_energy_bonuses.clear()
	prefer_silent_feedbacks.clear()


func _rebuild_pending_index() -> void:
	pending_by_enemy_id.clear()
	for index in range(job_cursor, enemy_ids.size()):
		var enemy_id: int = enemy_ids[index]
		if enemy_id != 0:
			pending_by_enemy_id[enemy_id] = index
