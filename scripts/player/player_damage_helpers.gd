extends RefCounted

static func get_enemy_meta_int(enemy: Node, key: String) -> int:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_meta(key):
		return 0
	return int(enemy.get_meta(key))

static func get_enemy_meta_float(enemy: Node, key: String) -> float:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_meta(key):
		return 0.0
	return float(enemy.get_meta(key))

static func apply_role_damage_lifesteal(_owner, _source_role_id: String, _damage_amount: float) -> void:
	# Attribute training no longer grants swordsman lifesteal. Strength now provides
	# max health, passive regeneration, and swordsman primary damage.
	return

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
