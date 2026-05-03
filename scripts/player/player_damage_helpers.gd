extends RefCounted

static func get_enemy_meta_int(enemy: Node, key: String) -> int:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_meta(key):
		return 0
	return int(enemy.get_meta(key))

static func get_enemy_meta_float(enemy: Node, key: String) -> float:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_meta(key):
		return 0.0
	return float(enemy.get_meta(key))

static func apply_role_damage_lifesteal(owner, source_role_id: String, damage_amount: float) -> void:
	if owner == null or source_role_id == "" or damage_amount <= 0.0:
		return
	if not owner.has_method("_get_role_blessing_stat_bonus") or not owner.has_method("_heal"):
		return
	var lifesteal_ratio: float = max(0.0, float(owner._get_role_blessing_stat_bonus(source_role_id, "lifesteal")))
	if lifesteal_ratio <= 0.0:
		return
	owner._heal(min(10.0, damage_amount * lifesteal_ratio))

static func get_gunner_distance_damage_multiplier(distance: float) -> float:
	var safe_distance: float = max(0.0, distance)
	var multiplier: float = 0.30 + 0.70 * sqrt(safe_distance / 160.0)
	return clamp(multiplier, 0.60, 1.65)

static func get_enemy_hit_radius(enemy: Node) -> float:
	if enemy == null or not is_instance_valid(enemy):
		return 12.0
	var enemy_contact_radius: Variant = enemy.get("contact_radius")
	if enemy_contact_radius == null:
		return 12.0
	return clamp(float(enemy_contact_radius) * 0.42, 10.0, 28.0)
