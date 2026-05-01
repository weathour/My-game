extends RefCounted


static func get_priority_target_bonus(owner, enemy: Node) -> float:
	var hunt_level: int = owner._get_card_level("battle_hunt")
	if hunt_level <= 0 or enemy == null or not is_instance_valid(enemy):
		hunt_level = 0

	var multiplier: float = 1.0
	if enemy != null and is_instance_valid(enemy):
		var enemy_kind: String = str(enemy.get("enemy_kind"))
		if enemy_kind == "elite" or enemy_kind == "boss":
			multiplier += 0.14 * float(hunt_level)
			if owner._has_elite_relic("elite_execution_pact"):
				multiplier += 0.14
		var max_hp: float = float(enemy.get("max_health"))
		if max_hp > 0.0:
			var hp_ratio: float = float(enemy.get("current_health")) / max_hp
			if hp_ratio <= 0.45:
				multiplier += 0.1 * float(hunt_level)
				if owner._has_elite_relic("elite_execution_pact"):
					multiplier += 0.08
	return multiplier


static func is_last_stand_active(owner) -> bool:
	if not owner._has_elite_relic("elite_last_stand"):
		return false
	if owner.max_health <= 0.0:
		return false
	return owner.current_health / owner.max_health <= 0.4


static func get_effective_damage_taken_multiplier(owner) -> float:
	var multiplier: float = owner.damage_taken_multiplier
	var blood_shield_level: int = max(0, int(owner._get_card_level("battle_blood_shield")))
	if blood_shield_level > 0:
		multiplier *= max(0.78, 1.0 - 0.035 * float(blood_shield_level))
	if is_last_stand_active(owner):
		multiplier *= 0.82
	multiplier *= owner._get_equipment_low_health_damage_taken_multiplier()
	if owner.guard_cover_remaining > 0.0:
		multiplier *= owner.guard_cover_damage_multiplier
	if owner.ultimate_guard_remaining > 0.0:
		multiplier *= owner.ultimate_guard_damage_multiplier
	return multiplier
