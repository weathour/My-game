extends RefCounted

const PLAYER_SKILL_COOLDOWN_SLOTS := preload("res://scripts/player/player_skill_cooldown_slots.gd")
const PLAYER_THEME_SKILL_FLOW := preload("res://scripts/player/player_theme_skill_flow.gd")


static func get_active_skill_cooldown_slots(owner, attack_interval: float) -> Array:
	var role_data: Dictionary = owner._get_active_role()
	var role_id: String = str(role_data.get("id", ""))
	var attack_remaining: float = 0.0
	if owner.fire_timer != null and not owner.fire_timer.is_stopped():
		attack_remaining = clamp(owner.fire_timer.time_left, 0.0, attack_interval)

	var extra_slots: Array = []

	extra_slots.append_array(PLAYER_THEME_SKILL_FLOW.get_passive_skill_slots(owner, role_id))
	_append_evolved_active_skill_slot(owner, role_id, extra_slots)

	return PLAYER_SKILL_COOLDOWN_SLOTS.build_slots(role_id, attack_remaining, attack_interval, extra_slots, owner)


static func _append_evolved_active_skill_slot(owner, role_id: String, extra_slots: Array) -> void:
	var ability = null
	match role_id:
		"swordsman":
			if owner.has_method("_has_swordsman_blade_storm_reward") and bool(owner._has_swordsman_blade_storm_reward()):
				ability = _get_owner_property(owner, "swordsman_blade_storm_ability")
		"gunner":
			if owner.has_method("_has_gunner_infinite_reload_reward") and bool(owner._has_gunner_infinite_reload_reward()):
				ability = _get_owner_property(owner, "gunner_infinite_reload_ability")
		"mage":
			if owner.has_method("_has_mage_tidal_surge_reward") and bool(owner._has_mage_tidal_surge_reward()):
				ability = _get_owner_property(owner, "mage_tidal_surge_ability")
	if ability == null or not ability.has_method("get_cooldown_slot"):
		return
	var slot: Dictionary = ability.get_cooldown_slot(owner)
	if slot.is_empty():
		return
	slot["slot_label"] = str(slot.get("slot_label", "荡阵进化"))
	extra_slots.append(slot)


static func _get_owner_property(owner, property_name: String):
	if owner == null or not is_instance_valid(owner):
		return null
	for property_info in owner.get_property_list():
		if property_info is Dictionary and str(property_info.get("name", "")) == property_name:
			return owner.get(property_name)
	return null
