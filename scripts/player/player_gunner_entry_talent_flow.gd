extends RefCounted

const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")
const PLAYER_GUNNER_BASIC_TALENT_FLOW := preload("res://scripts/player/player_gunner_basic_talent_flow.gd")

const TALENT_GUNFIRE_CEREMONY_1 := "gunner_level_talent_gunfire_ceremony_1"
const TALENT_GUNFIRE_CEREMONY_2 := "gunner_level_talent_gunfire_ceremony_2"
const ENTRY_SOURCE_ID := "gunner_entry"

const ENTRY_DAMAGE_RATIO_BONUS := 0.50
const KILL_DAMAGE_BONUS_PER_STACK := 0.01
const KILL_DAMAGE_BONUS_DURATION := 5.0
const ENTRY_ARMOR_SHRED_VALUE := 50.0
const ENTRY_ARMOR_SHRED_DURATION := 10.0

const RUNTIME_KEY := "talent_runtime"
const STATE_GUNFIRE_DAMAGE_STACKS := "gunfire_ceremony_damage_stack_durations"


static func tick(owner, delta: float) -> void:
	if owner == null or delta <= 0.0:
		return
	var runtime := _get_runtime_state(owner)
	var stacks: Array = runtime.get(STATE_GUNFIRE_DAMAGE_STACKS, [])
	if stacks.is_empty():
		return
	var remaining_stacks: Array = []
	for stack_value in stacks:
		var remaining: float = max(0.0, float(stack_value) - delta)
		if remaining > 0.0:
			remaining_stacks.append(remaining)
	runtime[STATE_GUNFIRE_DAMAGE_STACKS] = remaining_stacks


static func get_entry_damage_ratio_bonus(owner) -> float:
	return ENTRY_DAMAGE_RATIO_BONUS if has_level_talent(owner, TALENT_GUNFIRE_CEREMONY_1) else 0.0


static func get_gunner_damage_multiplier(owner, role_id: String) -> float:
	if owner == null or role_id != "gunner" or not has_level_talent(owner, TALENT_GUNFIRE_CEREMONY_1):
		return 1.0
	return 1.0 + float(_get_active_damage_stack_count(owner)) * KILL_DAMAGE_BONUS_PER_STACK


static func on_enemy_killed(owner, source_role_id: String, raw_source_role_id: String = "") -> void:
	if owner == null or source_role_id != "gunner" or not _is_entry_source(raw_source_role_id):
		return
	if not has_level_talent(owner, TALENT_GUNFIRE_CEREMONY_1):
		return
	var runtime := _get_runtime_state(owner)
	var stacks: Array = runtime.get(STATE_GUNFIRE_DAMAGE_STACKS, [])
	stacks.append(KILL_DAMAGE_BONUS_DURATION)
	runtime[STATE_GUNFIRE_DAMAGE_STACKS] = stacks


static func on_entry_attack_hit(owner, enemy: Node, raw_source_role_id: String) -> void:
	if owner == null or enemy == null or not is_instance_valid(enemy):
		return
	if not _is_entry_source(raw_source_role_id) or not has_level_talent(owner, TALENT_GUNFIRE_CEREMONY_2):
		return
	PLAYER_GUNNER_BASIC_TALENT_FLOW.apply_timed_armor_shred(enemy, ENTRY_ARMOR_SHRED_VALUE, ENTRY_ARMOR_SHRED_DURATION)


static func is_entry_source(source_role_id: String) -> bool:
	return _is_entry_source(source_role_id)


static func has_level_talent(owner, talent_id: String) -> bool:
	if owner == null or talent_id == "":
		return false
	if owner.has_method("_has_level_talent"):
		return bool(owner._has_level_talent(talent_id))
	return PLAYER_SKILL_TALENT_SYSTEM.has_level_talent(owner, talent_id)


static func _get_active_damage_stack_count(owner) -> int:
	var stacks: Array = _get_runtime_state(owner).get(STATE_GUNFIRE_DAMAGE_STACKS, [])
	var count := 0
	for stack_value in stacks:
		if float(stack_value) > 0.0:
			count += 1
	return count


static func _is_entry_source(source_role_id: String) -> bool:
	return source_role_id == ENTRY_SOURCE_ID or source_role_id.begins_with("%s:" % ENTRY_SOURCE_ID)


static func _get_runtime_state(owner) -> Dictionary:
	if owner == null or not owner.has_method("_get_role_special_state"):
		return {}
	var role_state: Dictionary = owner._get_role_special_state("gunner")
	if not role_state.has(RUNTIME_KEY) or role_state[RUNTIME_KEY] is not Dictionary:
		role_state[RUNTIME_KEY] = {}
	return role_state[RUNTIME_KEY]
