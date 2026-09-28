extends RefCounted

const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")

const TALENT_BASIC_ATTACK_1 := "mage_level_talent_basic_attack_1"
const TALENT_BASIC_ATTACK_2 := "mage_level_talent_basic_attack_2"
const TALENT_FLAME_PATH_2 := "mage_level_talent_flame_path_2"
const BASIC_SOURCE_PREFIX := "mage_basic:"
const FLAME_PATH_SOURCE := "mage_flame_path"

const BASIC_ATTACK_1_FOLLOWUP_DELAY := 0.20
const BASIC_ATTACK_1_FOLLOWUP_DAMAGE_MULTIPLIER := 0.50
const BASIC_ATTACK_1_COOLDOWN_CUT := 0.10
const BASIC_ATTACK_2_KILL_ENERGY_BONUS := 0.50
const SECONDARY_LIGHTNING_MIN_DISTANCE := 32.0


static func has_level_talent(owner, talent_id: String) -> bool:
	if owner == null or talent_id == "":
		return false
	if owner.has_method("_has_level_talent"):
		return bool(owner._has_level_talent(talent_id))
	return PLAYER_SKILL_TALENT_SYSTEM.has_level_talent(owner, talent_id)


static func get_primary_context_count(owner) -> int:
	return 2 if has_level_talent(owner, TALENT_BASIC_ATTACK_2) else 1


static func get_basic_followup_delay(owner) -> float:
	if not has_level_talent(owner, TALENT_BASIC_ATTACK_1):
		return -1.0
	return BASIC_ATTACK_1_FOLLOWUP_DELAY


static func get_basic_followup_damage_multiplier(owner) -> float:
	if not has_level_talent(owner, TALENT_BASIC_ATTACK_1):
		return 0.0
	return BASIC_ATTACK_1_FOLLOWUP_DAMAGE_MULTIPLIER


static func get_kill_energy_bonus(owner, source_role_id: String, resolved_role_id: String = "") -> float:
	if source_role_id == FLAME_PATH_SOURCE:
		return 0.50 if has_level_talent(owner, TALENT_FLAME_PATH_2) else 0.0
	if not _is_mage_basic_source(source_role_id, resolved_role_id):
		return 0.0
	return BASIC_ATTACK_2_KILL_ENERGY_BONUS if has_level_talent(owner, TALENT_BASIC_ATTACK_2) else 0.0


static func on_basic_attack_killed(owner, source_role_id: String, resolved_role_id: String, final_damage: float) -> void:
	if owner == null or not _is_mage_basic_source(source_role_id, resolved_role_id):
		return
	if has_level_talent(owner, TALENT_BASIC_ATTACK_1):
		_apply_basic_attack_interval_cut(owner)
	if has_level_talent(owner, TALENT_BASIC_ATTACK_2) and final_damage > 0.0 and owner.has_method("_add_switch_energy_from_damage"):
		owner._add_switch_energy_from_damage(final_damage * BASIC_ATTACK_2_KILL_ENERGY_BONUS, "mage")


static func _apply_basic_attack_interval_cut(owner) -> void:
	var timer_value: Variant = owner.get("fire_timer") if owner != null else null
	if timer_value is Timer:
		var fire_timer := timer_value as Timer
		if not fire_timer.is_stopped():
			fire_timer.start(maxf(0.001, fire_timer.time_left - BASIC_ATTACK_1_COOLDOWN_CUT))


static func pick_secondary_lightning_center(owner, fallback_center: Vector2) -> Vector2:
	if owner == null:
		return fallback_center
	var candidates: Array[Vector2] = []
	if owner.has_method("_get_random_enemy_cluster_centers"):
		for center_value in owner._get_random_enemy_cluster_centers(3):
			if center_value is Vector2:
				candidates.append(center_value)
	elif owner.has_method("_get_enemy_cluster_center"):
		var cluster_center: Vector2 = owner._get_enemy_cluster_center()
		if cluster_center != Vector2.ZERO:
			candidates.append(cluster_center)
	for center in candidates:
		if center.distance_squared_to(fallback_center) >= SECONDARY_LIGHTNING_MIN_DISTANCE * SECONDARY_LIGHTNING_MIN_DISTANCE:
			return center
	if not candidates.is_empty():
		return candidates[0]
	return fallback_center


static func _is_mage_basic_source(source_role_id: String, _resolved_role_id: String = "") -> bool:
	return source_role_id.begins_with(BASIC_SOURCE_PREFIX)
