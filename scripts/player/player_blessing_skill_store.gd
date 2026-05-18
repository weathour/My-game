extends RefCounted


static func build_empty_state() -> Dictionary:
	return {
		"unlocked": {},
		"tiers": {},
		"skill_blessing_bindings": {},
		"skill_blessing_baselines": {},
		"skill_blessing_bonus_credits": {},
		"role_recipe_locks": {},
		"skill_recipe_locks": {}
	}


static func normalize_state(value: Variant, known_skill_ids: Dictionary) -> Dictionary:
	var state := build_empty_state()
	if value is not Dictionary:
		return state
	var source := value as Dictionary
	if source.get("unlocked", {}) is Dictionary:
		for skill_id_value in (source.get("unlocked", {}) as Dictionary).keys():
			var skill_id := str(skill_id_value)
			if _is_known_skill_id(skill_id, known_skill_ids) and bool((source.get("unlocked", {}) as Dictionary).get(skill_id_value, false)):
				state["unlocked"][skill_id] = true
	if source.get("tiers", {}) is Dictionary:
		for skill_id_value in (source.get("tiers", {}) as Dictionary).keys():
			var skill_id := str(skill_id_value)
			if _is_known_skill_id(skill_id, known_skill_ids):
				state["tiers"][skill_id] = clamp(int((source.get("tiers", {}) as Dictionary).get(skill_id_value, 0)), 0, 3)
	if source.get("skill_blessing_bindings", {}) is Dictionary:
		for blessing_id_value in (source.get("skill_blessing_bindings", {}) as Dictionary).keys():
			var blessing_id := str(blessing_id_value)
			var skill_id := str((source.get("skill_blessing_bindings", {}) as Dictionary).get(blessing_id_value, ""))
			if _is_known_skill_id(skill_id, known_skill_ids):
				state["skill_blessing_bindings"][blessing_id] = skill_id
	_normalize_nested_skill_levels(source, state, known_skill_ids, "skill_blessing_baselines")
	_normalize_nested_skill_levels(source, state, known_skill_ids, "skill_blessing_bonus_credits")
	_normalize_recipe_locks(source, state, "role_recipe_locks")
	_normalize_recipe_locks(source, state, "skill_recipe_locks")
	return state


static func _normalize_nested_skill_levels(source: Dictionary, state: Dictionary, known_skill_ids: Dictionary, key: String) -> void:
	if source.get(key, {}) is not Dictionary:
		return
	for skill_id_value in (source.get(key, {}) as Dictionary).keys():
		var skill_id := str(skill_id_value)
		if not _is_known_skill_id(skill_id, known_skill_ids):
			continue
		var source_levels_by_blessing: Variant = (source.get(key, {}) as Dictionary).get(skill_id_value, {})
		if source_levels_by_blessing is not Dictionary:
			continue
		var normalized_levels_by_blessing: Dictionary = {}
		for blessing_id_value in (source_levels_by_blessing as Dictionary).keys():
			var blessing_id := str(blessing_id_value)
			var normalized_levels := _normalize_tier_levels((source_levels_by_blessing as Dictionary).get(blessing_id_value, {}))
			if not normalized_levels.is_empty():
				normalized_levels_by_blessing[blessing_id] = normalized_levels
		if not normalized_levels_by_blessing.is_empty():
			state[key][skill_id] = normalized_levels_by_blessing


static func _normalize_recipe_locks(source: Dictionary, state: Dictionary, key: String) -> void:
	if source.get(key, {}) is not Dictionary:
		return
	var normalized_locks: Dictionary = {}
	for blessing_id_value in (source.get(key, {}) as Dictionary).keys():
		var blessing_id := str(blessing_id_value)
		var normalized_levels := _normalize_tier_levels((source.get(key, {}) as Dictionary).get(blessing_id_value, {}))
		if not normalized_levels.is_empty():
			normalized_locks[blessing_id] = normalized_levels
	state[key] = normalized_locks


static func _normalize_tier_levels(value: Variant) -> Dictionary:
	var normalized_levels: Dictionary = {}
	if value is not Dictionary:
		return normalized_levels
	for tier_value in (value as Dictionary).keys():
		var tier := int(tier_value)
		if tier < 1 or tier > 2:
			continue
		var amount: int = max(0, int((value as Dictionary).get(tier_value, 0)))
		if amount > 0:
			normalized_levels[tier] = amount
	return normalized_levels


static func _is_known_skill_id(skill_id: String, known_skill_ids: Dictionary) -> bool:
	return known_skill_ids.has(skill_id)
