extends RefCounted

const PLAYER_SKILL_COOLDOWN_SLOTS := preload("res://scripts/player/player_skill_cooldown_slots.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")

const ROLE_ACTIVE_SKILL_PROPERTIES := {
	"swordsman": {
		"blade_storm": "swordsman_blade_storm_ability",
		"crescent_wave": "swordsman_crescent_wave_ability",
		"knight_thrust": "swordsman_knight_thrust_ability",
		"king_blade": "swordsman_king_blade_ability",
		"judgement_sword": "swordsman_judgement_sword_ability"
	},
	"gunner": {
		"infinite_reload": "gunner_infinite_reload_ability",
		"shrapnel_field": "gunner_shrapnel_field_ability",
		"explosive_round": "gunner_explosive_round_ability",
		"magic_grenade": "gunner_magic_grenade_ability",
		"magic_eye": "gunner_magic_eye_ability"
	},
	"mage": {
		"surging_wave": "mage_tidal_surge_ability",
		"meta_field": "mage_meta_field_ability",
		"flame_path": "mage_flame_path_ability",
		"dark_contract": "mage_dark_contract_ability",
		"fireball": "mage_fireball_ability"
	},
	"mechanic": {
		"tulip_turret": "mechanic_tulip_turret_ability",
		"mine": "mechanic_mine_ability",
		"emp_burst": "mechanic_emp_burst_ability",
		"drone": "mechanic_drone_ability",
		"missile_volley": "mechanic_missile_volley_ability"
	}
}


static func get_active_skill_cooldown_slots(owner, attack_interval: float, include_descriptions: bool = true) -> Array:
	var role_data: Dictionary = owner._get_active_role()
	var role_id: String = str(role_data.get("id", ""))
	return get_role_skill_cooldown_slots(owner, role_id, attack_interval, include_descriptions)


static func get_role_skill_cooldown_slots(owner, role_id: String, attack_interval: float, include_descriptions: bool = true) -> Array:
	var attack_remaining: float = 0.0
	var active_role_id: String = str(owner._get_active_role().get("id", ""))
	if role_id == active_role_id and owner.fire_timer != null and not owner.fire_timer.is_stopped():
		attack_remaining = clamp(owner.fire_timer.time_left, 0.0, attack_interval)

	var extra_slots: Array = []
	_append_blessing_active_skill_slot(owner, role_id, extra_slots)

	var slots: Array = PLAYER_SKILL_COOLDOWN_SLOTS.build_slots(role_id, attack_remaining, attack_interval, extra_slots, owner)
	_project_talent_displays(owner, slots, include_descriptions)
	if include_descriptions:
		_append_requirement_text(owner, slots)
	else:
		_strip_frame_only_slot_text(slots)
	return slots


static func _project_talent_displays(owner, slots: Array, include_descriptions: bool) -> void:
	if owner == null or not owner.has_method("_project_skill_talent_payload"):
		return
	for index in range(slots.size()):
		if slots[index] is not Dictionary:
			continue
		var slot: Dictionary = slots[index]
		var skill_id := str(slot.get("skill_id", ""))
		if skill_id != "":
			slots[index] = owner._project_skill_talent_payload(skill_id, slot, include_descriptions)


static func apply_switch_lock_to_role_skills(owner, role_id: String, duration: float) -> void:
	if owner == null or not is_instance_valid(owner) or duration <= 0.0:
		return
	for property_name in _get_role_skill_property_names(role_id):
		var ability: Variant = _get_owner_property(owner, property_name)
		if ability == null:
			continue
		if ability.get("cooldown_remaining") == null:
			continue
		ability.cooldown_remaining = max(float(ability.cooldown_remaining), duration)


static func advance_active_role_skill_cooldowns(owner, progress_ratio: float) -> int:
	if owner == null or not is_instance_valid(owner) or progress_ratio <= 0.0:
		return 0
	var role_id := ""
	if owner.has_method("_get_active_role_id"):
		role_id = str(owner._get_active_role_id())
	return advance_role_skill_cooldowns(owner, role_id, progress_ratio)


static func advance_role_skill_cooldowns(owner, role_id: String, progress_ratio: float) -> int:
	if owner == null or not is_instance_valid(owner) or role_id == "" or progress_ratio <= 0.0:
		return 0
	var advanced_count := 0
	for property_name in _get_role_skill_property_names(role_id):
		var ability: Variant = _get_owner_property(owner, property_name)
		if ability == null or ability.get("cooldown_remaining") == null:
			continue
		var previous_remaining: float = max(0.0, float(ability.cooldown_remaining))
		if previous_remaining <= 0.0:
			continue
		var duration: float = _get_ability_cooldown_duration(owner, ability)
		var advance_amount: float = max(previous_remaining, duration) * progress_ratio
		ability.cooldown_remaining = max(0.0, previous_remaining - advance_amount)
		if float(ability.cooldown_remaining) < previous_remaining:
			advanced_count += 1
	return advanced_count


static func _get_ability_cooldown_duration(owner, ability) -> float:
	if ability != null and ability.has_method("get_cooldown_slot"):
		var slot: Dictionary = ability.get_cooldown_slot(owner)
		return max(0.0, float(slot.get("duration", 0.0)))
	if ability != null and ability.get("cooldown_remaining") != null:
		return max(0.0, float(ability.cooldown_remaining))
	return 0.0


static func _append_blessing_active_skill_slot(owner, role_id: String, extra_slots: Array) -> void:
	for skill_id in get_role_active_skill_ids(owner, role_id):
		var property_name := str((ROLE_ACTIVE_SKILL_PROPERTIES.get(role_id, {}) as Dictionary).get(skill_id, ""))
		if property_name == "":
			continue
		_append_ability_slot_if_unlocked(owner, extra_slots, skill_id, property_name)


static func get_role_active_skill_ids(owner, role_id: String) -> Array[String]:
	var ordered_ids: Array[String] = PLAYER_BLESSING_SKILL_STATE.get_unlocked_active_skill_order(owner, role_id)
	if not ordered_ids.is_empty():
		return ordered_ids
	var result: Array[String] = []
	var role_properties: Dictionary = ROLE_ACTIVE_SKILL_PROPERTIES.get(role_id, {})
	for skill_id_value in role_properties.keys():
		var skill_id := str(skill_id_value)
		if owner.has_method("_is_blessing_skill_unlocked") and bool(owner._is_blessing_skill_unlocked(skill_id)):
			result.append(skill_id)
	return result


static func _get_role_skill_property_names(role_id: String) -> Array[String]:
	var result: Array[String] = []
	var role_properties: Dictionary = ROLE_ACTIVE_SKILL_PROPERTIES.get(role_id, {})
	for property_name in role_properties.values():
		result.append(str(property_name))
	return result


static func _append_ability_slot_if_unlocked(owner, extra_slots: Array, skill_id: String, property_name: String) -> void:
	if not owner.has_method("_is_blessing_skill_unlocked") or not bool(owner._is_blessing_skill_unlocked(skill_id)):
		return
	var ability: Variant = _get_owner_property(owner, property_name)
	if ability == null or not ability.has_method("get_cooldown_slot"):
		return
	var slot: Dictionary = ability.get_cooldown_slot(owner)
	if slot.is_empty():
		return
	slot["skill_id"] = skill_id
	slot["slot_label"] = str(slot.get("slot_label", "祝福技能"))
	slot["manual_slot_index"] = extra_slots.size() + 1
	extra_slots.append(slot)


static func _append_requirement_text(owner, slots: Array) -> void:
	if owner == null or not owner.has_method("get_skill_next_requirement_text"):
		return
	for slot in slots:
		if slot is not Dictionary:
			continue
		var slot_dict: Dictionary = slot
		var skill_id := str(slot_dict.get("skill_id", ""))
		if skill_id == "":
			continue
		var requirement_text := str(owner.get_skill_next_requirement_text(skill_id))
		if requirement_text == "":
			continue
		slot_dict["next_requirement"] = requirement_text
		var description := str(slot_dict.get("description", ""))
		slot_dict["description"] = "%s\n\n进化需求：\n%s" % [description, requirement_text] if description != "" else "进化需求：\n%s" % requirement_text

static func _strip_frame_only_slot_text(slots: Array) -> void:
	for slot in slots:
		if slot is not Dictionary:
			continue
		var slot_dict: Dictionary = slot
		slot_dict["description"] = ""
		slot_dict.erase("next_requirement")


static func _get_owner_property(owner, property_name: String):
	if owner == null or not is_instance_valid(owner):
		return null
	return owner.get(property_name)
