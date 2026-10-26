extends RefCounted

const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const ENEMY_LIFECYCLE := preload("res://scripts/enemies/enemy_pool_lifecycle.gd")

var owner: Node
var enemy_refs: Array[WeakRef] = []
var enemy_ids: Array[int] = []
var enemy_generations: Array[int] = []
var damage_amounts: PackedFloat32Array = PackedFloat32Array()
var hit_counts: Array[int] = []
var source_role_ids: PackedStringArray = PackedStringArray()
var vulnerability_bonuses: PackedFloat32Array = PackedFloat32Array()
var vulnerability_durations: PackedFloat32Array = PackedFloat32Array()
var slow_multipliers: PackedFloat32Array = PackedFloat32Array()
var slow_source_ids: PackedStringArray = PackedStringArray()
var slow_durations: PackedFloat32Array = PackedFloat32Array()
var source_positions: Array = []
var kill_energy_bonuses: PackedFloat32Array = PackedFloat32Array()
var suppress_status_visuals: Array[bool] = []
var gunner_event_prepareds: Array[bool] = []
var damage_event_keys: PackedStringArray = PackedStringArray()
var damage_event_ids: PackedStringArray = PackedStringArray()
var indexes_by_enemy_id: Dictionary = {}
var hit_count: int = 0


func _init(source_owner: Node) -> void:
	owner = source_owner


func reset(source_owner: Node) -> void:
	owner = source_owner
	enemy_refs.clear()
	enemy_ids.clear()
	enemy_generations.clear()
	damage_amounts.clear()
	hit_counts.clear()
	source_role_ids.clear()
	vulnerability_bonuses.clear()
	vulnerability_durations.clear()
	slow_multipliers.clear()
	slow_durations.clear()
	slow_source_ids.clear()
	source_positions.clear()
	kill_energy_bonuses.clear()
	suppress_status_visuals.clear()
	gunner_event_prepareds.clear()
	damage_event_keys.clear()
	damage_event_ids.clear()
	indexes_by_enemy_id.clear()
	hit_count = 0


func add_enemy(enemy: Node, damage_amount: float, source_role_id: String, vulnerability_bonus: float = 0.0, vulnerability_duration: float = 2.0, slow_multiplier: float = 1.0, slow_duration: float = 0.0, source_position: Variant = null, kill_energy_bonus: float = 0.0, suppress_status_visual: bool = false, gunner_event_prepared: bool = false, damage_event_id: String = "", slow_source_id: String = "") -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var enemy_id: int = enemy.get_instance_id()
	var generation := ENEMY_LIFECYCLE.ensure_activation_generation(enemy)
	var damage_event_key := _damage_event_key(source_role_id, source_position, damage_event_id)
	var merge_key: String = "%s|%s|%s|%s|%s" % [enemy_id, generation, source_role_id, slow_source_id, damage_event_key]
	hit_count += 1
	if not indexes_by_enemy_id.has(merge_key):
		indexes_by_enemy_id[merge_key] = enemy_refs.size()
		enemy_refs.append(weakref(enemy))
		enemy_ids.append(enemy_id)
		enemy_generations.append(generation)
		damage_amounts.append(damage_amount)
		hit_counts.append(1)
		source_role_ids.append(source_role_id)
		vulnerability_bonuses.append(vulnerability_bonus)
		vulnerability_durations.append(vulnerability_duration)
		slow_multipliers.append(slow_multiplier)
		slow_durations.append(slow_duration)
		slow_source_ids.append(slow_source_id)
		source_positions.append(source_position)
		kill_energy_bonuses.append(kill_energy_bonus)
		suppress_status_visuals.append(suppress_status_visual)
		gunner_event_prepareds.append(gunner_event_prepared)
		damage_event_keys.append(damage_event_key)
		damage_event_ids.append(damage_event_id)
		return
	var existing_index: int = int(indexes_by_enemy_id[merge_key])
	damage_amounts[existing_index] = damage_amounts[existing_index] + damage_amount
	hit_counts[existing_index] = hit_counts[existing_index] + 1
	vulnerability_bonuses[existing_index] = max(vulnerability_bonuses[existing_index], vulnerability_bonus)
	vulnerability_durations[existing_index] = max(vulnerability_durations[existing_index], vulnerability_duration)
	slow_multipliers[existing_index] = min(slow_multipliers[existing_index], slow_multiplier)
	slow_durations[existing_index] = max(slow_durations[existing_index], slow_duration)
	kill_energy_bonuses[existing_index] = max(kill_energy_bonuses[existing_index], kill_energy_bonus)
	suppress_status_visuals[existing_index] = suppress_status_visuals[existing_index] or suppress_status_visual
	gunner_event_prepareds[existing_index] = gunner_event_prepareds[existing_index] or gunner_event_prepared


func flush() -> int:
	var result: int = hit_count
	var gunner_event_multipliers: Dictionary = {}
	var positive_gunner_events: Dictionary = {}
	for index in range(enemy_refs.size()):
		if not _is_current_activation(index):
			continue
		if not gunner_event_prepareds[index] and damage_amounts[index] > 0.0:
			positive_gunner_events[damage_event_keys[index]] = true
	for index in range(enemy_refs.size()):
		if not _is_current_activation(index):
			continue
		var source_role_id: String = source_role_ids[index]
		var gunner_event_prepared: bool = gunner_event_prepareds[index]
		if not gunner_event_prepared and PLAYER_DAMAGE_RESOLVER.is_gunner_talent_damage_source(source_role_id):
			var event_key: String = damage_event_keys[index]
			if not gunner_event_multipliers.has(event_key):
				gunner_event_multipliers[event_key] = PLAYER_DAMAGE_RESOLVER.snapshot_gunner_damage_event_multiplier(owner, source_role_id, bool(positive_gunner_events.get(event_key, false)), damage_event_ids[index])
			damage_amounts[index] *= float(gunner_event_multipliers[event_key])
			gunner_event_prepared = true
		PLAYER_DAMAGE_RESOLVER.apply_or_queue_damage_values(
			owner,
			enemy_refs[index],
			enemy_ids[index],
			damage_amounts[index],
			hit_counts[index],
			source_role_id,
			vulnerability_bonuses[index],
			vulnerability_durations[index],
			slow_multipliers[index],
			slow_durations[index],
			source_positions[index],
			kill_energy_bonuses[index],
			true,
			suppress_status_visuals[index],
			gunner_event_prepared,
			damage_event_ids[index],
			slow_source_ids[index]
		)
	reset(owner)
	return result


func _is_current_activation(index: int) -> bool:
	var enemy: Node = enemy_refs[index].get_ref() as Node
	return PLAYER_DAMAGE_RESOLVER._is_live_enemy(enemy) and int(enemy.get_meta(ENEMY_LIFECYCLE.ACTIVATION_GENERATION_META, -1)) == enemy_generations[index]


func _damage_event_key(source_role_id: String, source_position: Variant, damage_event_id: String) -> String:
	if not PLAYER_DAMAGE_RESOLVER.is_gunner_talent_damage_source(source_role_id):
		return ""
	if damage_event_id != "":
		return damage_event_id
	# ponytail: unlabeled legacy shapes fall back to source position; authored multi-frame attacks pass an explicit event ID.
	if source_position is Vector2:
		var position: Vector2 = source_position
		return "%s|%.3f|%.3f" % [source_role_id, position.x, position.y]
	return source_role_id
