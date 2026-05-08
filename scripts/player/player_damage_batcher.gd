extends RefCounted

const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")

var owner: Node
var jobs_by_enemy_id: Dictionary = {}
var hit_count: int = 0


func _init(source_owner: Node) -> void:
	owner = source_owner


func reset(source_owner: Node) -> void:
	owner = source_owner
	jobs_by_enemy_id.clear()
	hit_count = 0


func add_enemy(enemy: Node, damage_amount: float, source_role_id: String, vulnerability_bonus: float = 0.0, vulnerability_duration: float = 2.0, slow_multiplier: float = 1.0, slow_duration: float = 0.0, source_position: Variant = null, kill_energy_bonus: float = 0.0) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var enemy_id := enemy.get_instance_id()
	hit_count += 1
	if not jobs_by_enemy_id.has(enemy_id):
		jobs_by_enemy_id[enemy_id] = {
			"enemy_ref": weakref(enemy),
			"enemy_id": enemy_id,
			"damage_amount": damage_amount,
			"hit_count": 1,
			"source_role_id": source_role_id,
			"vulnerability_bonus": vulnerability_bonus,
			"vulnerability_duration": vulnerability_duration,
			"slow_multiplier": slow_multiplier,
			"slow_duration": slow_duration,
			"source_position": source_position,
			"kill_energy_bonus": kill_energy_bonus,
			"prefer_silent_feedback": true
		}
		return
	var existing: Dictionary = jobs_by_enemy_id[enemy_id]
	existing["damage_amount"] = float(existing.get("damage_amount", 0.0)) + damage_amount
	existing["hit_count"] = int(existing.get("hit_count", 1)) + 1
	existing["vulnerability_bonus"] = max(float(existing.get("vulnerability_bonus", 0.0)), vulnerability_bonus)
	existing["vulnerability_duration"] = max(float(existing.get("vulnerability_duration", 0.0)), vulnerability_duration)
	existing["slow_multiplier"] = min(float(existing.get("slow_multiplier", 1.0)), slow_multiplier)
	existing["slow_duration"] = max(float(existing.get("slow_duration", 0.0)), slow_duration)
	existing["kill_energy_bonus"] = max(float(existing.get("kill_energy_bonus", 0.0)), kill_energy_bonus)
	jobs_by_enemy_id[enemy_id] = existing


func flush() -> int:
	for job in jobs_by_enemy_id.values():
		PLAYER_DAMAGE_RESOLVER.apply_or_queue_damage_job(owner, job)
	jobs_by_enemy_id.clear()
	var result := hit_count
	hit_count = 0
	return result
