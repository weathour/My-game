extends Node

const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")
const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")
const PLAYER_RUAN_STONE_FLOW := preload("res://scripts/player/player_ruan_stone_flow.gd")
const PLAYER_GUNNER_BASIC_TALENT_FLOW := preload("res://scripts/player/player_gunner_basic_talent_flow.gd")
const PLAYER_GUNNER_ENTRY_TALENT_FLOW := preload("res://scripts/player/player_gunner_entry_talent_flow.gd")
const PLAYER_MAGE_ENTRY_TALENT_FLOW := preload("res://scripts/player/player_mage_entry_talent_flow.gd")
const PLAYER_MAGE_ULTIMATE_TALENT_FLOW := preload("res://scripts/player/player_mage_ultimate_talent_flow.gd")
const PLAYER_SWORDSMAN_KING_BLADE_FLOW := preload("res://scripts/player/player_swordsman_king_blade_flow.gd")
const PLAYER_GUNNER_MAGIC_GRENADE_FLOW := preload("res://scripts/player/player_gunner_magic_grenade_flow.gd")
const PLAYER_MAGE_DARK_CONTRACT_FLOW := preload("res://scripts/player/player_mage_dark_contract_flow.gd")
const PLAYER_GUNNER_EXPLOSIVE_ROUND_FLOW := preload("res://scripts/player/player_gunner_explosive_round_flow.gd")

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
const GUNNER_NO_HUNT_SOURCE_ROLE_ID := "gunner_no_hunt"

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
var suppress_status_visuals: Array[bool] = []
var gunner_event_prepareds: Array[bool] = []
var damage_event_ids: PackedStringArray = PackedStringArray()
var job_cursor: int = 0
var pending_by_enemy_id: Dictionary = {}
var last_processed_render_frame: int = -1
var feedback_jobs_used_this_frame: int = 0
var attack_results_by_role: Dictionary = {}
var pending_kill_energy_by_lock_bypass: Dictionary = {}


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
		bool(job.get("prefer_silent_feedback", false)),
		bool(job.get("suppress_status_visual", false)),
		bool(job.get("gunner_event_prepared", false)),
		str(job.get("damage_event_id", ""))
	)


func enqueue_values(enemy_ref: WeakRef, enemy_id: int, damage_amount: float, hit_count: int, source_role_id: String, vulnerability_bonus: float = 0.0, vulnerability_duration: float = 2.0, slow_multiplier: float = 1.0, slow_duration: float = 0.0, source_position: Variant = null, kill_energy_bonus: float = 0.0, prefer_silent_feedback: bool = false, suppress_status_visual: bool = false, gunner_event_prepared: bool = false, damage_event_id: String = "") -> void:
	if enemy_ref == null:
		return
	if enemy_id != 0:
		var pending_index: int = int(pending_by_enemy_id.get(enemy_id, -1))
		if pending_index >= job_cursor and pending_index < enemy_refs.size() and str(source_role_ids[pending_index]) == source_role_id and (gunner_event_prepared or str(damage_event_ids[pending_index]) == damage_event_id):
			_merge_job_at_index(pending_index, damage_amount, hit_count, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, kill_energy_bonus, prefer_silent_feedback, suppress_status_visual, gunner_event_prepared)
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
	suppress_status_visuals.append(suppress_status_visual)
	gunner_event_prepareds.append(gunner_event_prepared)
	damage_event_ids.append(damage_event_id)
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
	pending_kill_energy_by_lock_bypass.clear()
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
	if not _is_enemy_damageable(enemy):
		return
	var damage_amount: float = damage_amounts[index]
	var source_role_id: String = source_role_ids[index]
	var resolved_source_role_id: String = _resolve_damage_source_role_id(source_role_id)
	var vulnerability_bonus: float = vulnerability_bonuses[index]
	var vulnerability_duration: float = vulnerability_durations[index]
	var slow_multiplier: float = slow_multipliers[index]
	var slow_duration: float = slow_durations[index]
	var source_position: Variant = source_positions[index]
	var kill_energy_bonus: float = kill_energy_bonuses[index]
	var suppress_status_visual: bool = suppress_status_visuals[index]
	var gunner_event_prepared: bool = gunner_event_prepareds[index]
	var killed := false
	if source_player.has_method("_deal_damage_to_enemy"):
		var prefer_silent: bool = prefer_silent_feedbacks[index]
		if (prefer_silent and enemy.has_method("take_batched_damage")) or gunner_event_prepared:
			killed = bool(_deal_batched_damage_to_enemy(enemy, damage_amount, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position, kill_energy_bonus, suppress_status_visual))
		else:
			killed = bool(source_player._deal_damage_to_enemy(enemy, damage_amount, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position, suppress_status_visual, kill_energy_bonus))
	elif enemy.has_method("take_damage"):
		killed = bool(_deal_batched_damage_to_enemy(enemy, damage_amount, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position, kill_energy_bonus, suppress_status_visual))
	_queue_attack_result(resolved_source_role_id, hit_counts[index], killed)


func _merge_job_at_index(index: int, damage_amount: float, hit_count: int, vulnerability_bonus: float, vulnerability_duration: float, slow_multiplier: float, slow_duration: float, kill_energy_bonus: float, prefer_silent_feedback: bool, suppress_status_visual: bool, gunner_event_prepared: bool) -> void:
	damage_amounts[index] = damage_amounts[index] + damage_amount
	hit_counts[index] = hit_counts[index] + hit_count
	prefer_silent_feedbacks[index] = prefer_silent_feedbacks[index] or prefer_silent_feedback
	vulnerability_bonuses[index] = max(vulnerability_bonuses[index], vulnerability_bonus)
	vulnerability_durations[index] = max(vulnerability_durations[index], vulnerability_duration)
	slow_multipliers[index] = min(slow_multipliers[index], slow_multiplier)
	slow_durations[index] = max(slow_durations[index], slow_duration)
	kill_energy_bonuses[index] = max(kill_energy_bonuses[index], kill_energy_bonus)
	suppress_status_visuals[index] = suppress_status_visuals[index] or suppress_status_visual
	gunner_event_prepareds[index] = gunner_event_prepareds[index] or gunner_event_prepared


func _queue_attack_result(role_id: String, hit_count: int, killed: bool) -> void:
	if role_id == "" or hit_count <= 0:
		return
	if not attack_results_by_role.has(role_id):
		attack_results_by_role[role_id] = {
			"hit_count": 0,
			"killed": false,
			"kill_count": 0
		}
	var result: Dictionary = attack_results_by_role[role_id]
	result["hit_count"] = int(result.get("hit_count", 0)) + hit_count
	result["killed"] = bool(result.get("killed", false)) or killed
	if killed:
		result["kill_count"] = int(result.get("kill_count", 0)) + 1
	attack_results_by_role[role_id] = result


func _flush_attack_results() -> void:
	if attack_results_by_role.is_empty():
		return
	if source_player == null or not is_instance_valid(source_player) or not source_player.has_method("_register_attack_result"):
		attack_results_by_role.clear()
		return
	for role_id in attack_results_by_role.keys():
		var result: Dictionary = attack_results_by_role[role_id]
		source_player._register_attack_result(str(role_id), int(result.get("hit_count", 0)), bool(result.get("killed", false)), int(result.get("kill_count", 0)))
	attack_results_by_role.clear()


func _queue_kill_energy(amount: float, bypass_lock_role_id: String = "", source_role_id: String = "") -> void:
	if amount <= 0.0:
		return
	var key: String = "%s|%s" % [bypass_lock_role_id, source_role_id]
	pending_kill_energy_by_lock_bypass[key] = float(pending_kill_energy_by_lock_bypass.get(key, 0.0)) + amount


func _flush_pending_kill_energy() -> void:
	if pending_kill_energy_by_lock_bypass.is_empty():
		return
	if source_player != null and is_instance_valid(source_player) and source_player.has_method("_add_kill_energy"):
		for pending_key in pending_kill_energy_by_lock_bypass.keys():
			var key_parts: PackedStringArray = str(pending_key).split("|", true)
			var bypass_lock_role_id: String = key_parts[0] if key_parts.size() > 0 else ""
			var source_role_id: String = key_parts[1] if key_parts.size() > 1 else ""
			source_player._add_kill_energy(float(pending_kill_energy_by_lock_bypass.get(pending_key, 0.0)), bypass_lock_role_id, source_role_id)
	pending_kill_energy_by_lock_bypass.clear()


func _deal_batched_damage_to_enemy(enemy: Node, damage_amount: float, source_role_id: String, vulnerability_bonus: float, vulnerability_duration: float, slow_multiplier: float, slow_duration: float, source_position: Variant, kill_energy_bonus: float, suppress_status_visual: bool) -> bool:
	if not _is_enemy_damageable(enemy):
		return false
	var final_damage := damage_amount
	var resolved_source_role_id: String = _resolve_damage_source_role_id(source_role_id)
	var source_ultimate_energy_bonus: float = PLAYER_MAGE_ULTIMATE_TALENT_FLOW.get_ultimate_energy_bonus_multiplier(source_player, source_role_id, resolved_source_role_id)
	var source_critical_chance_bonus: float = PLAYER_GUNNER_MAGIC_GRENADE_FLOW.get_critical_chance_bonus(source_player, source_role_id)
	var was_critical := false
	if resolved_source_role_id != "" and source_player.has_method("_roll_critical_hit") and source_player.has_method("_get_critical_damage_multiplier"):
		was_critical = bool(source_player._roll_critical_hit(resolved_source_role_id, source_critical_chance_bonus))
		if was_critical:
			final_damage *= float(source_player._get_critical_damage_multiplier(resolved_source_role_id))
	var applies_gunner_target_talents := damage_amount > 0.0 and _should_apply_gunner_hunt_multiplier(source_role_id, resolved_source_role_id) and enemy is Node2D
	if applies_gunner_target_talents:
		if source_player.has_method("_get_gunner_distance_damage_multiplier"):
			var attack_origin: Vector2 = _get_gunner_damage_origin(enemy as Node2D)
			final_damage *= float(source_player._get_gunner_distance_damage_multiplier(attack_origin.distance_to((enemy as Node2D).global_position)))
	var target_position: Vector2 = (enemy as Node2D).global_position if enemy is Node2D else Vector2.ZERO
	var max_health_value: Variant = enemy.get("max_health")
	var target_max_health: float = max(0.0, float(max_health_value)) if max_health_value != null else 0.0
	var show_feedback := feedback_jobs_used_this_frame < _get_feedback_jobs_per_render_frame()
	feedback_jobs_used_this_frame += 1
	var killed := false
	var used_batched_damage := false
	var health_before := _get_enemy_current_health(enemy)
	if show_feedback and enemy.has_method("take_damage"):
		killed = bool(enemy.take_damage(final_damage, was_critical))
	elif enemy.has_method("take_batched_damage"):
		used_batched_damage = true
		killed = bool(_call_enemy_take_batched_damage(enemy, final_damage, was_critical))
	elif enemy.has_method("take_damage"):
		killed = bool(enemy.take_damage(final_damage, was_critical))
	if source_player.has_method("_record_swordsman_ultimate_followup_damage"):
		source_player._record_swordsman_ultimate_followup_damage(max(0.0, health_before - _get_enemy_current_health(enemy)))
	if used_batched_damage and not killed and _did_enemy_health_decrease(enemy, health_before) and enemy.has_method("_play_light_hit_feedback"):
		enemy._play_light_hit_feedback()
	if damage_amount > 0.0:
		PLAYER_GUNNER_BASIC_TALENT_FLOW.on_basic_attack_hit(source_player, enemy, source_role_id)
		PLAYER_GUNNER_ENTRY_TALENT_FLOW.on_entry_attack_hit(source_player, enemy, source_role_id)
	if source_player.has_method("_record_attack_result_instance"):
		source_player._record_attack_result_instance(resolved_source_role_id, was_critical, killed, target_position, source_role_id)
	if source_player.has_method("_add_switch_energy_from_damage"):
		source_player._add_switch_energy_from_damage(final_damage, resolved_source_role_id)
	if source_player.has_method("_apply_role_damage_lifesteal"):
		source_player._apply_role_damage_lifesteal(resolved_source_role_id, final_damage)
	if str(enemy.get("enemy_kind")) in ["boss", "small_boss"] and source_player.has_method("_get_boss_damage_energy") and source_player.has_method("_add_boss_damage_energy"):
		var boss_energy: float = source_player._get_boss_damage_energy(final_damage)
		source_player._add_boss_damage_energy(boss_energy)
		if source_ultimate_energy_bonus > 0.0:
			source_player._add_boss_damage_energy(boss_energy * source_ultimate_energy_bonus)
	if killed:
		PLAYER_MAGE_ENTRY_TALENT_FLOW.on_entry_lightning_killed(source_player, source_role_id, resolved_source_role_id)
		PLAYER_MAGE_ULTIMATE_TALENT_FLOW.on_ultimate_bombardment_killed(source_player, source_role_id, resolved_source_role_id)
		PLAYER_SWORDSMAN_KING_BLADE_FLOW.on_king_blade_killed(source_player, source_role_id, resolved_source_role_id)
		PLAYER_GUNNER_EXPLOSIVE_ROUND_FLOW.on_explosive_round_killed(source_player, source_role_id, resolved_source_role_id, enemy)
	if killed and source_player.has_method("_get_kill_energy_from_enemy"):
		var kill_energy: float = source_player._get_kill_energy_from_enemy(enemy)
		var bypass_lock_role_id: String = resolved_source_role_id if resolved_source_role_id == "mage" and kill_energy_bonus > 0.0 else ""
		_queue_kill_energy(kill_energy, bypass_lock_role_id, resolved_source_role_id)
		if source_player.has_method("_try_apply_mage_kill_energy_proc"):
			source_player._try_apply_mage_kill_energy_proc(resolved_source_role_id, kill_energy, bypass_lock_role_id)
		if kill_energy_bonus > 0.0:
			var bonus_energy: float = kill_energy * kill_energy_bonus
			_queue_kill_energy(bonus_energy, bypass_lock_role_id, resolved_source_role_id)
			if source_player.has_method("_try_apply_mage_kill_energy_proc"):
				source_player._try_apply_mage_kill_energy_proc(resolved_source_role_id, bonus_energy, bypass_lock_role_id)
		if source_ultimate_energy_bonus > 0.0:
			_queue_kill_energy(kill_energy * source_ultimate_energy_bonus, "", resolved_source_role_id)
	if applies_gunner_target_talents:
		_apply_gunner_damage_target_talents(enemy as Node2D, resolved_source_role_id, source_position)
	if vulnerability_bonus > 0.0 and enemy.has_method("apply_vulnerability"):
		enemy.apply_vulnerability(vulnerability_bonus, vulnerability_duration)
	if slow_duration > 0.0:
		if suppress_status_visual and enemy.has_method("apply_slow_silent"):
			enemy.apply_slow_silent(slow_multiplier, slow_duration)
		elif enemy.has_method("apply_slow"):
			enemy.apply_slow(slow_multiplier, slow_duration)
	if damage_amount > 0.0 and _is_basic_attack_damage_source(source_role_id):
		PLAYER_RUAN_STONE_FLOW.apply_basic_hit(source_player, enemy, final_damage, source_role_id, "", killed, target_position, target_max_health)
	return killed

func _resolve_damage_source_role_id(source_role_id: String) -> String:
	if source_role_id == GUNNER_NO_HUNT_SOURCE_ROLE_ID:
		return "gunner"
	if PLAYER_GUNNER_ENTRY_TALENT_FLOW.is_entry_source(source_role_id):
		return "gunner"
	if PLAYER_MAGE_ENTRY_TALENT_FLOW.is_entry_lightning_source(source_role_id):
		return "mage"
	if PLAYER_MAGE_ULTIMATE_TALENT_FLOW.is_ultimate_source(source_role_id):
		return "mage"
	if PLAYER_SWORDSMAN_KING_BLADE_FLOW.is_king_blade_source(source_role_id):
		return "swordsman"
	if PLAYER_GUNNER_MAGIC_GRENADE_FLOW.is_magic_grenade_source(source_role_id):
		return "gunner"
	if PLAYER_MAGE_DARK_CONTRACT_FLOW.is_dark_contract_source(source_role_id):
		return "mage"
	if PLAYER_GUNNER_EXPLOSIVE_ROUND_FLOW.is_explosive_round_source(source_role_id):
		return "gunner"
	if PLAYER_GUNNER_EXPLOSIVE_ROUND_FLOW.is_explosive_round_killblast_source(source_role_id):
		return "gunner"
	for role_id in ["swordsman", "gunner", "mage"]:
		if source_role_id.begins_with("%s_basic:" % role_id):
			return role_id
	return source_role_id

func _is_basic_attack_damage_source(source_role_id: String) -> bool:
	return source_role_id.begins_with("swordsman_basic:") or source_role_id.begins_with("gunner_basic:") or source_role_id.begins_with("mage_basic:")

func _is_enemy_damageable(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy.is_queued_for_deletion():
		return false
	var pooled_inactive_value: Variant = enemy.get("pooled_inactive")
	if pooled_inactive_value != null and bool(pooled_inactive_value):
		return false
	var rebirth_timer_value: Variant = enemy.get("rebirth_timer")
	if rebirth_timer_value != null and float(rebirth_timer_value) > 0.0:
		return false
	var current_health_value: Variant = enemy.get("current_health")
	if current_health_value != null and float(current_health_value) <= 0.0:
		return false
	return true

func _should_apply_gunner_hunt_multiplier(source_role_id: String, resolved_source_role_id: String) -> bool:
	return resolved_source_role_id == "gunner" and source_role_id != GUNNER_NO_HUNT_SOURCE_ROLE_ID

func _apply_gunner_damage_target_talents(enemy: Node2D, resolved_source_role_id: String, source_position: Variant) -> void:
	var gunner_role = source_player.get("gunner_role") if source_player != null else null
	if gunner_role != null and gunner_role.has_method("apply_damage_target_talents"):
		gunner_role.apply_damage_target_talents(source_player, enemy, resolved_source_role_id, source_position)

func _get_gunner_damage_origin(enemy: Node2D) -> Vector2:
	if source_player != null and source_player is Node2D:
		return (source_player as Node2D).global_position
	return enemy.global_position if enemy != null else Vector2.ZERO

func _call_enemy_take_batched_damage(enemy: Node, amount: float, is_critical: bool) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("take_batched_damage"):
		return false
	if _method_accepts_argument_count(enemy, "take_batched_damage", 2):
		return bool(enemy.take_batched_damage(amount, is_critical))
	return bool(enemy.take_batched_damage(amount))

func _method_accepts_argument_count(target: Object, method_name: String, argument_count: int) -> bool:
	for method in target.get_method_list():
		if method is not Dictionary:
			continue
		var method_data: Dictionary = method
		if str(method_data.get("name", "")) != method_name:
			continue
		var args: Array = method_data.get("args", [])
		var default_args: Array = method_data.get("default_args", [])
		var max_args: int = args.size()
		var min_args: int = max(0, max_args - default_args.size())
		return argument_count >= min_args and argument_count <= max_args
	return false

func _get_enemy_current_health(enemy: Node) -> float:
	if enemy == null or not is_instance_valid(enemy):
		return INF
	var health_value: Variant = enemy.get("current_health")
	if health_value == null:
		return INF
	return float(health_value)

func _did_enemy_health_decrease(enemy: Node, health_before: float) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not is_finite(health_before):
		return false
	var health_value: Variant = enemy.get("current_health")
	if health_value == null:
		return false
	return float(health_value) < health_before - 0.001


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
			suppress_status_visuals[write_index] = suppress_status_visuals[read_index]
			gunner_event_prepareds[write_index] = gunner_event_prepareds[read_index]
			damage_event_ids[write_index] = damage_event_ids[read_index]
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
		suppress_status_visuals.resize(remaining_size)
		gunner_event_prepareds.resize(remaining_size)
		damage_event_ids.resize(remaining_size)
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
	suppress_status_visuals.clear()
	gunner_event_prepareds.clear()
	damage_event_ids.clear()


func _rebuild_pending_index() -> void:
	pending_by_enemy_id.clear()
	for index in range(job_cursor, enemy_ids.size()):
		var enemy_id: int = enemy_ids[index]
		if enemy_id != 0:
			pending_by_enemy_id[enemy_id] = index
