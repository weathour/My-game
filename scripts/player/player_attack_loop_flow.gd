extends RefCounted


static func update_background_effects(owner, delta: float) -> void:
	return


static func trigger_background_effect(owner, role_index: int) -> void:
	var role_id: String = owner.roles[role_index]["id"]
	match role_id:
		"swordsman":
			if owner.swordsman_role != null:
				owner.swordsman_role.perform_background(owner)
		"gunner":
			if owner.gunner_role != null:
				owner.gunner_role.perform_background(owner)
		"mage":
			if owner.mage_role != null:
				owner.mage_role.perform_background(owner)
		"mechanic":
			if owner.mechanic_role != null:
				owner.mechanic_role.perform_background(owner)


static func perform_active_attack(owner) -> void:
	if owner.is_dead:
		return
	if owner.has_method("_is_player_action_locked") and owner._is_player_action_locked():
		return
	if owner.has_method("is_gunner_infinite_reload_blocking_actions") and owner.is_gunner_infinite_reload_blocking_actions():
		return

	var role_id: String = owner._get_active_role()["id"]
	match role_id:
		"swordsman":
			owner._perform_swordsman_attack()
		"gunner":
			owner._perform_gunner_attack()
		"mage":
			owner._perform_mage_attack()
		"mechanic":
			owner._perform_mechanic_attack()
