extends RefCounted

## 剑士主动技能「王者之剑」的永久成长数据流。
## 击杀计数存于 role_special_states["swordsman"]，随运行档持久化（本局内永久成长）。

const KILLS_STATE_KEY := "king_blade_permanent_kills"
const HEALTH_STATE_KEY := "king_blade_permanent_health_bonus"
const SOURCE_PREFIX := "swordsman_king_blade:"
const FLAT_ATTACK_PER_KILL := 0.01
const MAX_HEALTH_PER_KILL := 0.05
const SEARCH_RADIUS := 350.0
const SLASH_LENGTH := 350.0
const SLASH_WIDTH := 150.0
const DAMAGE_RATIO := 6.00
const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const PLAYER_TARGETING := preload("res://scripts/player/player_targeting.gd")


static func make_damage_source_id() -> String:
	return SOURCE_PREFIX + "1"


static func is_king_blade_source(source_role_id: String) -> bool:
	return source_role_id.begins_with(SOURCE_PREFIX)


static func resolve_cast(owner, origin: Vector2, facing: Vector2) -> Dictionary:
	var direction := facing.normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	var candidates := _collect_enemies_within_radius(owner, origin)
	var target_position: Vector2 = origin + direction * (SEARCH_RADIUS * 0.5)
	var boss_target: Node2D = PLAYER_TARGETING.get_priority_boss_target(candidates, origin)
	if boss_target != null:
		direction = origin.direction_to(boss_target.global_position)
		target_position = boss_target.global_position
	elif not candidates.is_empty():
		var cluster_center: Vector2 = PLAYER_TARGETING.get_enemy_cluster_center(candidates)
		if origin.distance_to(cluster_center) > 8.0:
			direction = origin.direction_to(cluster_center)
		target_position = cluster_center
	return {
		"direction": direction,
		"target_position": target_position,
		"center": origin + direction * (SLASH_LENGTH * 0.5)
	}


static func apply_slash(owner, origin: Vector2, direction: Vector2, damage_ratio: float = DAMAGE_RATIO) -> int:
	if owner == null or not is_instance_valid(owner):
		return 0
	var axis := direction.normalized()
	if axis.length_squared() <= 0.001:
		axis = Vector2.RIGHT
	var center: Vector2 = origin + axis * (SLASH_LENGTH * 0.5)
	var damage: float = float(owner._get_role_damage("swordsman")) * damage_ratio
	return int(owner._damage_enemies_in_oriented_rect(center, axis, SLASH_LENGTH, SLASH_WIDTH, damage, 0.0, 1.0, 0.0, make_damage_source_id()))


static func on_king_blade_killed(owner, source_role_id: String, resolved_source_role_id: String = "") -> void:
	if owner == null or not is_king_blade_source(source_role_id):
		return
	var state: Dictionary = owner._get_role_special_state("swordsman") if owner.has_method("_get_role_special_state") else {}
	state[KILLS_STATE_KEY] = max(0, int(state.get(KILLS_STATE_KEY, 0))) + 1
	if owner.has_method("_has_level_talent") and bool(owner._has_level_talent("swordsman_level_talent_king_blade_2")):
		state[HEALTH_STATE_KEY] = max(0.0, float(state.get(HEALTH_STATE_KEY, 0.0))) + MAX_HEALTH_PER_KILL
	if owner.get("role_special_states") is Dictionary:
		owner.role_special_states["swordsman"] = state
		if owner.has_method("_get_active_role") and str(owner._get_active_role().get("id", "")) == "swordsman" and owner.has_method("_sync_active_role_max_health"):
			owner._sync_active_role_max_health(false, false)


static func get_permanent_kill_count(owner) -> int:
	if owner == null or not owner.has_method("_get_role_special_state"):
		return 0
	var state: Dictionary = owner._get_role_special_state("swordsman")
	return max(0, int(state.get(KILLS_STATE_KEY, 0)))


static func get_flat_attack_bonus(owner) -> float:
	return float(get_permanent_kill_count(owner)) * FLAT_ATTACK_PER_KILL


static func get_permanent_health_bonus(owner) -> float:
	if owner == null or not owner.has_method("_get_role_special_state"):
		return 0.0
	var state: Dictionary = owner._get_role_special_state("swordsman")
	return max(0.0, float(state.get(HEALTH_STATE_KEY, 0.0)))


static func _collect_enemies_within_radius(owner, origin: Vector2) -> Array:
	var bounds := Rect2(origin - Vector2.ONE * SEARCH_RADIUS, Vector2.ONE * SEARCH_RADIUS * 2.0)
	var candidates: Array = PLAYER_DAMAGE_RESOLVER._get_candidate_enemies_for_bounds(owner, bounds)
	var nearby: Array = []
	var radius_squared: float = SEARCH_RADIUS * SEARCH_RADIUS
	for enemy in candidates:
		if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if origin.distance_squared_to(enemy.global_position) <= radius_squared:
			nearby.append(enemy)
	return nearby
