extends RefCounted

const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")

const TALENT_FLAME_PATH_1 := "mage_level_talent_flame_path_1"
const FLAME_PATH_SOURCE := "mage_flame_path"
const SHRED_VALUE := 20.0


static func is_active(owner) -> bool:
	if owner == null or not is_instance_valid(owner):
		return false
	var ability: Variant = owner.get("mage_flame_path_ability")
	return ability != null and ability.has_method("is_active") and bool(ability.is_active())


static func apply_damage_tick(owner, points: Array[Vector2], path_width: float, damage_per_second: float, interval: float) -> void:
	if owner == null or not is_instance_valid(owner) or points.size() < 2:
		return
	var hit_registry: Dictionary = {}
	for index in range(points.size() - 1):
		var start: Vector2 = points[index]
		var end: Vector2 = points[index + 1]
		var axis: Vector2 = end - start
		var length: float = axis.length()
		if length <= 0.001:
			continue
		var direction: Vector2 = axis / length
		if owner.has_method("_damage_enemies_in_oriented_rect_unique"):
			owner._damage_enemies_in_oriented_rect_unique(
				(start + end) * 0.5,
				direction,
				length + path_width,
				path_width,
				damage_per_second * interval,
				0.0,
				1.0,
				0.0,
				hit_registry,
				FLAME_PATH_SOURCE
			)
	# 火焰之径I：被灼烧的敌人减20减伤值
	if has_level_talent(owner, TALENT_FLAME_PATH_1):
		_apply_defense_shred(owner, hit_registry)


static func _apply_defense_shred(owner, hit_registry: Dictionary) -> void:
	for enemy_id in hit_registry.keys():
		var enemy = instance_from_id(enemy_id)
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.get("damage_reduction_value") == null:
			continue
		enemy.damage_reduction_value = float(enemy.damage_reduction_value) - SHRED_VALUE


static func has_level_talent(owner, talent_id: String) -> bool:
	if owner == null or talent_id == "":
		return false
	if owner.has_method("_has_level_talent"):
		return bool(owner._has_level_talent(talent_id))
	return PLAYER_SKILL_TALENT_SYSTEM.has_level_talent(owner, talent_id)


static func is_flame_path_source(source_role_id: String) -> bool:
	return source_role_id == FLAME_PATH_SOURCE
