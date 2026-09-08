extends RefCounted

const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")

const IMPACT_DAMAGE_RATIO := 2.80
const BLAST_DAMAGE_RATIO := 1.60
const BLAST_CONE_RADIUS := 375.0
const BLAST_CONE_ANGLE := deg_to_rad(60.0)
const SOURCE_ROLE_ID := "gunner"

# 爆破弹伤害专属来源前缀（用于识别“被爆破弹击杀”，与普攻/其他枪手来源区分）。
const SOURCE_PREFIX := "gunner_explosive_round:"
# 击杀尸爆使用独立前缀：尸爆造成的击杀不再连锁触发尸爆。
const KILL_BLAST_SOURCE_PREFIX := "gunner_explosive_round_killblast:"

const TALENT_EXPLOSIVE_ROUND_1 := "gunner_level_talent_explosive_round_1"
const TALENT_EXPLOSIVE_ROUND_2 := "gunner_level_talent_explosive_round_2"

# 爆破弹 I 数值（伤害加成按线性/加性：ratio 直接相加，不做乘法）。
const TALENT_1_IMPACT_RADIUS := 100.0
const TALENT_1_IMPACT_RATIO_BONUS := 0.50
const TALENT_1_BLAST_RATIO_BONUS := 0.50
const TALENT_1_CONE_RADIUS_BONUS := 100.0
const KILL_BLAST_RADIUS := 75.0
const KILL_BLAST_DAMAGE_RATIO := 1.50


static func make_damage_source_id() -> String:
	return SOURCE_PREFIX + "1"


static func make_kill_blast_source_id() -> String:
	return KILL_BLAST_SOURCE_PREFIX + "1"


static func is_explosive_round_source(source_role_id: String) -> bool:
	return source_role_id.begins_with(SOURCE_PREFIX)


static func is_explosive_round_killblast_source(source_role_id: String) -> bool:
	return source_role_id.begins_with(KILL_BLAST_SOURCE_PREFIX)


static func has_talent(owner, talent_id: String) -> bool:
	return owner != null and owner.has_method("_has_level_talent") and bool(owner._has_level_talent(talent_id))


static func get_blast_cone_radius(owner) -> float:
	return BLAST_CONE_RADIUS + (TALENT_1_CONE_RADIUS_BONUS if has_talent(owner, TALENT_EXPLOSIVE_ROUND_1) else 0.0)


static func find_enemy_between(owner, start: Vector2, end: Vector2):
	if owner == null or not is_instance_valid(owner) or not owner.has_method("_get_live_enemies"):
		return null
	var axis := end - start
	var length: float = axis.length()
	if length <= 0.001:
		return null
	var direction: Vector2 = axis / length
	var closest: Node2D = null
	var closest_distance: float = INF
	for enemy in owner._get_live_enemies():
		if not bool(PLAYER_DAMAGE_RESOLVER._is_live_enemy(enemy)) or not (enemy is Node2D):
			continue
		var relative: Vector2 = enemy.global_position - start
		var along: float = clampf(relative.dot(direction), 0.0, length)
		var distance: float = enemy.global_position.distance_to(start + direction * along)
		var contact_radius: float = float(enemy.get("contact_radius")) if enemy.get("contact_radius") != null else 0.0
		if distance <= 28.0 + contact_radius and along < closest_distance:
			closest = enemy
			closest_distance = along
	return closest


static func apply_explosion(owner, center: Vector2, direction: Vector2, hit_enemy: Node2D) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var talent_1: bool = has_talent(owner, TALENT_EXPLOSIVE_ROUND_1)
	var damage: float = float(owner._get_role_damage(SOURCE_ROLE_ID))
	if hit_enemy != null and is_instance_valid(hit_enemy):
		if talent_1:
			# 爆破弹 I：命中伤害提升 50%（线性 +0.5）并变为半径 100 的范围伤害（命中目标也在圈内）。
			var impact_ratio: float = IMPACT_DAMAGE_RATIO + TALENT_1_IMPACT_RATIO_BONUS
			owner._damage_enemies_in_ellipse(center, TALENT_1_IMPACT_RADIUS, TALENT_1_IMPACT_RADIUS, damage * impact_ratio, 0.0, 1.0, 0.0, make_damage_source_id())
		else:
			owner._deal_damage_to_enemy(hit_enemy, damage * IMPACT_DAMAGE_RATIO, SOURCE_ROLE_ID, 0.0, 2.0, 1.0, 0.0, center)
	var cone_radius: float = BLAST_CONE_RADIUS + (TALENT_1_CONE_RADIUS_BONUS if talent_1 else 0.0)
	var cone_ratio: float = BLAST_DAMAGE_RATIO + (TALENT_1_BLAST_RATIO_BONUS if talent_1 else 0.0)
	owner._damage_enemies_in_cone(center, direction, cone_radius, BLAST_CONE_ANGLE, damage * cone_ratio, 0.0, 1.0, 0.0, make_damage_source_id())


# 被爆破弹直接命中/扇形炸死的敌人触发尸爆（入队，由 ability 在下一帧结算，避免结算重入）。
# 尸爆本身使用独立来源前缀，其造成的击杀不会再触发新的尸爆。
static func on_explosive_round_killed(owner, source_role_id: String, resolved_source_role_id: String, enemy) -> void:
	if owner == null or not is_instance_valid(owner) or not is_explosive_round_source(source_role_id):
		return
	if not has_talent(owner, TALENT_EXPLOSIVE_ROUND_1):
		return
	if enemy == null or not is_instance_valid(enemy):
		return
	var center: Vector2 = enemy.global_position
	var damage: float = float(owner._get_role_damage(SOURCE_ROLE_ID)) * KILL_BLAST_DAMAGE_RATIO
	var ability: Variant = owner.get("gunner_explosive_round_ability")
	if ability != null and ability.has_method("enqueue_kill_blast"):
		ability.enqueue_kill_blast(center, damage)
