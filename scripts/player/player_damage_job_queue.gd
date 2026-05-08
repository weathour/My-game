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
var jobs: Array[Dictionary] = []
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
	var enemy_id := int(job.get("enemy_id", 0))
	if enemy_id != 0 and pending_by_enemy_id.has(enemy_id):
		_merge_job(pending_by_enemy_id[enemy_id], job)
		PERFORMANCE_COUNTERS.add("merged_damage_jobs", 1)
		return
	jobs.append(job)
	if enemy_id != 0:
		pending_by_enemy_id[enemy_id] = job
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
		jobs.clear()
		job_cursor = 0
		pending_by_enemy_id.clear()
		return
	var processed := 0
	var process_limit := _get_frame_process_limit(queue_size)
	var frame_start_usec := Time.get_ticks_usec()
	while processed < process_limit and job_cursor < jobs.size():
		if processed >= MIN_DAMAGE_APPLICATIONS_PER_RENDER_FRAME and Time.get_ticks_usec() - frame_start_usec >= _get_frame_time_budget_usec():
			break
		var job: Dictionary = jobs[job_cursor]
		job_cursor += 1
		var enemy_id := int(job.get("enemy_id", 0))
		if enemy_id != 0:
			pending_by_enemy_id.erase(enemy_id)
		_apply_job(job)
		processed += 1
	_flush_pending_kill_energy()
	_flush_attack_results()
	_compact_processed_jobs(false)
	PERFORMANCE_COUNTERS.add("applied_damage_jobs", processed)


func _apply_job(job: Dictionary) -> void:
	var enemy_ref: WeakRef = job.get("enemy_ref", null) as WeakRef
	if enemy_ref == null:
		return
	var enemy: Node = enemy_ref.get_ref() as Node
	if enemy == null or not is_instance_valid(enemy):
		return
	var damage_amount := float(job.get("damage_amount", 0.0))
	var source_role_id := str(job.get("source_role_id", ""))
	var vulnerability_bonus := float(job.get("vulnerability_bonus", 0.0))
	var vulnerability_duration := float(job.get("vulnerability_duration", 2.0))
	var slow_multiplier := float(job.get("slow_multiplier", 1.0))
	var slow_duration := float(job.get("slow_duration", 0.0))
	var source_position: Variant = job.get("source_position", null)
	var kill_energy_bonus := float(job.get("kill_energy_bonus", 0.0))
	var killed := false
	if source_player.has_method("_deal_damage_to_enemy"):
		var prefer_silent := bool(job.get("prefer_silent_feedback", false))
		if prefer_silent and enemy.has_method("take_batched_damage"):
			killed = bool(_deal_batched_damage_to_enemy(enemy, damage_amount, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position, kill_energy_bonus))
		else:
			killed = bool(source_player._deal_damage_to_enemy(enemy, damage_amount, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position))
			if killed and kill_energy_bonus > 0.0 and source_player.has_method("_add_kill_energy"):
				_queue_kill_energy(kill_energy_bonus)
	elif enemy.has_method("take_damage"):
		killed = bool(enemy.take_damage(damage_amount))
	_queue_attack_result(source_role_id, int(job.get("hit_count", 1)), killed)


func _merge_job(existing: Dictionary, incoming: Dictionary) -> void:
	existing["damage_amount"] = float(existing.get("damage_amount", 0.0)) + float(incoming.get("damage_amount", 0.0))
	existing["hit_count"] = int(existing.get("hit_count", 1)) + int(incoming.get("hit_count", 1))
	existing["prefer_silent_feedback"] = bool(existing.get("prefer_silent_feedback", false)) or bool(incoming.get("prefer_silent_feedback", false))
	existing["vulnerability_bonus"] = max(float(existing.get("vulnerability_bonus", 0.0)), float(incoming.get("vulnerability_bonus", 0.0)))
	existing["vulnerability_duration"] = max(float(existing.get("vulnerability_duration", 0.0)), float(incoming.get("vulnerability_duration", 0.0)))
	existing["slow_multiplier"] = min(float(existing.get("slow_multiplier", 1.0)), float(incoming.get("slow_multiplier", 1.0)))
	existing["slow_duration"] = max(float(existing.get("slow_duration", 0.0)), float(incoming.get("slow_duration", 0.0)))
	existing["kill_energy_bonus"] = max(float(existing.get("kill_energy_bonus", 0.0)), float(incoming.get("kill_energy_bonus", 0.0)))


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
	return max(0, jobs.size() - job_cursor)


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
	if force or job_cursor >= jobs.size() or job_cursor >= COMPACT_CURSOR_THRESHOLD:
		jobs = jobs.slice(job_cursor)
		job_cursor = 0
