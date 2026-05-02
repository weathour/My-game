extends RefCounted

const ROLE_ATTRIBUTE_RULES := preload("res://scripts/player/roles/role_attribute_rules.gd")

static func build_slot_progress_data() -> Dictionary:
	return {
		"body": 0,
		"combat": 0,
		"skill": 0
	}

static func build_attribute_training_data() -> Dictionary:
	var data := {
		"common_prosperity": 0
	}
	for trait_key in ROLE_ATTRIBUTE_RULES.get_trait_keys_for_roles():
		data[str(trait_key)] = 0.0
	return data

static func make_slot_resonance_key(slot_id: String, threshold: int) -> String:
	return "%s_%d" % [slot_id, threshold]

static func make_role_attribute_key(role_id: String, attribute_key: String) -> String:
	return "%s_%s" % [role_id, attribute_key]
