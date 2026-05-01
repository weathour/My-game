extends RefCounted

static func build_slot_progress_data() -> Dictionary:
	return {
		"body": 0,
		"combat": 0,
		"skill": 0
	}

static func build_attribute_training_data() -> Dictionary:
	return {
		"swordsman_trait": 0.0,
		"gunner_trait": 0.0,
		"mage_trait": 0.0,
		"common_prosperity": 0
	}

static func make_slot_resonance_key(slot_id: String, threshold: int) -> String:
	return "%s_%d" % [slot_id, threshold]

static func make_role_attribute_key(role_id: String, attribute_key: String) -> String:
	return "%s_%s" % [role_id, attribute_key]
