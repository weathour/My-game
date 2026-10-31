extends RefCounted
## Small, strict, shared predicate language. No player state mutations.
const KEYS := ["owned_all", "alive_all", "completed_all", "event_read_all"]

static func validate(value: Variant, characters: Dictionary, nodes: Dictionary, optional: Dictionary, battle: bool = false) -> Array[String]:
	var errors: Array[String] = []
	if not value is Dictionary: return ["Conditions must be a dictionary"]
	for key in value:
		if key not in KEYS and not (battle and key == "battle_members_all"):
			errors.append("Unknown condition: " + str(key)); continue
		if not value[key] is Array:
			errors.append("Condition must be an array: " + str(key)); continue
		var domain: Dictionary = nodes if key == "completed_all" else optional if key == "event_read_all" else characters
		for id in value[key]:
			if not id is String or not domain.has(id): errors.append("Unknown condition ID: " + str(key) + "/" + str(id))
	return errors

static func matches(conditions: Dictionary, snapshot: Dictionary, battle_id: String = "") -> bool:
	for key in conditions:
		if key not in KEYS and key != "battle_members_all": return false
		if not conditions[key] is Array: return false
		for id in conditions[key]:
			match key:
				"owned_all":
					if not snapshot.get("owned", {}).has(id): return false
				"alive_all":
					if not snapshot.get("owned", {}).has(id) or snapshot.owned[id].get("dead", true): return false
				"completed_all":
					if id not in snapshot.get("completed", []): return false
				"event_read_all":
					if id not in snapshot.get("optional_story_read", []): return false
				"battle_members_all":
					if battle_id.is_empty() or id not in snapshot.get("battle_story_contexts", {}).get(battle_id, []): return false
	return true
