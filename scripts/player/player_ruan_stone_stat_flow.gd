extends RefCounted

const SYSTEM := preload("res://scripts/player/ruan_stone_system.gd")

static func get_count(owner, stone_id: String) -> int:
	if owner == null or not owner.has_method("get_purchased_ruan_stones"):
		return 0
	var count := 0
	for purchased_id in owner.get_purchased_ruan_stones():
		if str(purchased_id) == stone_id:
			count += 1
	return count


static func has(owner, stone_id: String) -> bool:
	return get_count(owner, stone_id) > 0


static func _stacked_values(owner, stone_id: String) -> Dictionary:
	var count := get_count(owner, stone_id)
	if count <= 0:
		return {}
	return SYSTEM.get_stacked_effect_values(stone_id, count)


static func get_damage_bonus(owner) -> float:
	return float(_stacked_values(owner, "broken_sword").get("damage_bonus", 0.0))


static func get_attack_bonus(owner) -> float:
	return float(_stacked_values(owner, "broken_sword").get("attack_bonus", 0.0)) \
		+ float(_stacked_values(owner, "ground_branch").get("attack_bonus", 0.0))


static func get_speed_bonus(owner) -> float:
	return float(_stacked_values(owner, "tattered_cloak").get("speed_bonus", 0.0))


static func get_move_speed_percent_bonus(owner) -> float:
	return float(_stacked_values(owner, "failed_assassin_dagger").get("move_speed_percent", 0.0))


static func get_attack_speed_percent_bonus(owner) -> float:
	return float(_stacked_values(owner, "ground_branch").get("attack_speed_percent", 0.0)) \
		+ float(_stacked_values(owner, "failed_assassin_dagger").get("attack_speed_percent", 0.0))


static func get_dodge_miss_multiplier(owner) -> float:
	var count := get_count(owner, "tattered_cloak")
	var chance := clampf(float(SYSTEM.get_effect_values("tattered_cloak", 1).get("dodge_chance", 0.0)), 0.0, 1.0)
	return pow(1.0 - chance, count)


static func get_damage_reduction_rate(owner) -> float:
	return float(_stacked_values(owner, "broken_chestplate").get("damage_reduction_rate", 0.0))


static func get_max_health_bonus(owner) -> float:
	return float(_stacked_values(owner, "broken_chestplate").get("max_health_bonus", 0.0))


static func get_critical_chance_bonus(owner) -> float:
	return float(_stacked_values(owner, "rusted_dagger").get("critical_chance_bonus", 0.0))


static func get_critical_damage_bonus(owner) -> float:
	return float(_stacked_values(owner, "rusted_dagger").get("critical_damage_bonus", 0.0))
