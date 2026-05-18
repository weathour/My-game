extends RefCounted


static func sync_trait_flags(enemy) -> void:
	enemy._is_shooter = (enemy.behavior_id == "shooter" or enemy.secondary_behavior_id == "shooter")
	enemy._is_dasher = (enemy.behavior_id == "dash" or enemy.secondary_behavior_id == "dash")
	enemy._is_accelerator = (enemy.behavior_id == "accelerator" or enemy.secondary_behavior_id == "accelerator")
	enemy._is_turret = (enemy.behavior_id == "turret" or enemy.secondary_behavior_id == "turret")
	enemy._is_glutton = (enemy.behavior_id == "glutton" or enemy.secondary_behavior_id == "glutton")
	enemy._is_swarm = (enemy.behavior_id == "swarm" or enemy.secondary_behavior_id == "swarm")
	enemy._is_boss = (enemy.behavior_id == "boss" or enemy.secondary_behavior_id == "boss")
	enemy._is_rebirth = (enemy.behavior_id == "rebirth" or enemy.secondary_behavior_id == "rebirth")


static func has_trait(enemy, trait_id: String) -> bool:
	match trait_id:
		"shooter":
			return bool(enemy._is_shooter)
		"dash":
			return bool(enemy._is_dasher)
		"accelerator":
			return bool(enemy._is_accelerator)
		"turret":
			return bool(enemy._is_turret)
		"glutton":
			return bool(enemy._is_glutton)
		"swarm":
			return bool(enemy._is_swarm)
		"boss":
			return bool(enemy._is_boss)
		"rebirth":
			return bool(enemy._is_rebirth)
		_:
			return enemy.behavior_id == trait_id or enemy.secondary_behavior_id == trait_id


static func has_timed_behavior_traits(enemy) -> bool:
	return bool(enemy._is_shooter) or bool(enemy._is_accelerator) or bool(enemy._is_dasher) or bool(enemy._is_glutton) or bool(enemy._is_turret) or bool(enemy._is_boss) or bool(enemy._is_rebirth)
