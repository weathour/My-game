extends RefCounted

const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")

var owner: Node
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
var indexes_by_enemy_id: Dictionary = {}
var hit_count: int = 0


func _init(source_owner: Node) -> void:
	owner = source_owner


func reset(source_owner: Node) -> void:
	owner = source_owner
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
	indexes_by_enemy_id.clear()
	hit_count = 0


func add_enemy(enemy: Node, damage_amount: float, source_role_id: String, vulnerability_bonus: float = 0.0, vulnerability_duration: float = 2.0, slow_multiplier: float = 1.0, slow_duration: float = 0.0, source_position: Variant = null, kill_energy_bonus: float = 0.0) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var enemy_id: int = enemy.get_instance_id()
	hit_count += 1
	if not indexes_by_enemy_id.has(enemy_id):
		indexes_by_enemy_id[enemy_id] = enemy_refs.size()
		enemy_refs.append(weakref(enemy))
		enemy_ids.append(enemy_id)
		damage_amounts.append(damage_amount)
		hit_counts.append(1)
		source_role_ids.append(source_role_id)
		vulnerability_bonuses.append(vulnerability_bonus)
		vulnerability_durations.append(vulnerability_duration)
		slow_multipliers.append(slow_multiplier)
		slow_durations.append(slow_duration)
		source_positions.append(source_position)
		kill_energy_bonuses.append(kill_energy_bonus)
		return
	var existing_index: int = int(indexes_by_enemy_id[enemy_id])
	damage_amounts[existing_index] = damage_amounts[existing_index] + damage_amount
	hit_counts[existing_index] = hit_counts[existing_index] + 1
	vulnerability_bonuses[existing_index] = max(vulnerability_bonuses[existing_index], vulnerability_bonus)
	vulnerability_durations[existing_index] = max(vulnerability_durations[existing_index], vulnerability_duration)
	slow_multipliers[existing_index] = min(slow_multipliers[existing_index], slow_multiplier)
	slow_durations[existing_index] = max(slow_durations[existing_index], slow_duration)
	kill_energy_bonuses[existing_index] = max(kill_energy_bonuses[existing_index], kill_energy_bonus)


func flush() -> int:
	var result: int = hit_count
	for index in range(enemy_refs.size()):
		PLAYER_DAMAGE_RESOLVER.apply_or_queue_damage_values(
			owner,
			enemy_refs[index],
			enemy_ids[index],
			damage_amounts[index],
			hit_counts[index],
			source_role_ids[index],
			vulnerability_bonuses[index],
			vulnerability_durations[index],
			slow_multipliers[index],
			slow_durations[index],
			source_positions[index],
			kill_energy_bonuses[index],
			true
		)
	reset(owner)
	return result
