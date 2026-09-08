extends RefCounted

const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const PLAYER_TARGETING := preload("res://scripts/player/player_targeting.gd")

## 枪手主动技能「魔法榴弹」的来源识别与专属暴击加成。

const SOURCE_PREFIX := "gunner_magic_grenade:"
const CRIT_CHANCE_BONUS := 0.20
const GRENADE_COUNT := 3
const DAMAGE_RATIO := 3.00
const BLAST_RADIUS := 75.0
const SEARCH_RADIUS := 540.0
const SEARCH_MIN_DISTANCE := 60.0

const TALENT_MAGIC_GRENADE_1 := "gunner_level_talent_magic_grenade_1"
const TALENT_MAGIC_GRENADE_2 := "gunner_level_talent_magic_grenade_2"

# 魔法榴弹 I 数值（绝对加法）：范围 +75、每枚伤害 +100%、暴击率额外 +20%。
const TALENT_1_DAMAGE_RATIO_BONUS := 1.00
const TALENT_1_BLAST_RADIUS_BONUS := 75.0
const TALENT_1_CRIT_BONUS := 0.20
# 魔法榴弹 II 数值：数量 +1。
const TALENT_2_GRENADE_BONUS := 1


static func make_damage_source_id() -> String:
	return SOURCE_PREFIX + "1"


static func is_magic_grenade_source(source_role_id: String) -> bool:
	return source_role_id.begins_with(SOURCE_PREFIX)


static func has_talent(owner, talent_id: String) -> bool:
	return owner != null and owner.has_method("_has_level_talent") and bool(owner._has_level_talent(talent_id))


static func get_grenade_count(owner) -> int:
	return GRENADE_COUNT + (TALENT_2_GRENADE_BONUS if has_talent(owner, TALENT_MAGIC_GRENADE_2) else 0)


static func get_damage_ratio(owner) -> float:
	return DAMAGE_RATIO + (TALENT_1_DAMAGE_RATIO_BONUS if has_talent(owner, TALENT_MAGIC_GRENADE_1) else 0.0)


static func get_blast_radius(owner) -> float:
	return BLAST_RADIUS + (TALENT_1_BLAST_RADIUS_BONUS if has_talent(owner, TALENT_MAGIC_GRENADE_1) else 0.0)


static func get_critical_chance_bonus(owner, source_role_id: String) -> float:
	if source_role_id == "" or not is_magic_grenade_source(source_role_id):
		return 0.0
	return CRIT_CHANCE_BONUS + (TALENT_1_CRIT_BONUS if has_talent(owner, TALENT_MAGIC_GRENADE_1) else 0.0)


static func collect_targets(owner, origin: Vector2, facing: Vector2) -> Array:
	var grenade_count: int = get_grenade_count(owner)
	var fallback_targets := _build_fallback_targets(owner, origin, facing)
	var bounds := Rect2(origin - Vector2.ONE * SEARCH_RADIUS, Vector2.ONE * SEARCH_RADIUS * 2.0)
	var candidates: Array = PLAYER_DAMAGE_RESOLVER._get_candidate_enemies_for_bounds(owner, bounds)
	if candidates.is_empty():
		return fallback_targets
	var front_enemies: Array = []
	var search_radius_squared: float = SEARCH_RADIUS * SEARCH_RADIUS
	var min_distance_squared: float = SEARCH_MIN_DISTANCE * SEARCH_MIN_DISTANCE
	for enemy in candidates:
		if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var offset: Vector2 = enemy.global_position - origin
		var distance_squared: float = offset.length_squared()
		if distance_squared < min_distance_squared or distance_squared > search_radius_squared:
			continue
		if facing.dot(offset.normalized()) < 0.12:
			continue
		front_enemies.append(enemy)
	if front_enemies.is_empty():
		return fallback_targets
	var centers: Array = PLAYER_TARGETING.get_random_enemy_cluster_centers(front_enemies, origin, grenade_count)
	var targets: Array = []
	for center in centers:
		if origin.distance_to(center) < SEARCH_MIN_DISTANCE:
			continue
		targets.append(center)
		if targets.size() >= grenade_count:
			break
	while targets.size() < grenade_count:
		targets.append(fallback_targets[targets.size()])
	return targets


static func apply_explosion(owner, center: Vector2) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var damage: float = float(owner._get_role_damage("gunner")) * get_damage_ratio(owner)
	owner._damage_enemies_in_radius(center, get_blast_radius(owner), damage, 0.0, 1.0, 0.0, make_damage_source_id())


static func _build_fallback_targets(owner, origin: Vector2, facing: Vector2) -> Array:
	var grenade_count: int = get_grenade_count(owner)
	var targets: Array = []
	var base_distance := 300.0
	for index in range(grenade_count):
		var lateral: float = (float(index) - float(grenade_count - 1) * 0.5) * 90.0
		var offset: Vector2 = facing * (base_distance + float(index) * 60.0) + Vector2.UP.rotated(facing.angle()) * lateral
		targets.append(origin + offset)
	return targets
