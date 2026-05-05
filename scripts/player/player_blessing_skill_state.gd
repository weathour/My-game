extends RefCounted

const ROLE_BOUND := "role"
const SKILL_BOUND := "skill"
const TIER_ONE_EQUIVALENT_COUNT := 1
const TIER_TWO_EQUIVALENT_COUNT := 3

const SKILL_BLADE_STORM := "blade_storm"
const SKILL_INFINITE_RELOAD := "infinite_reload"
const SKILL_SURGING_WAVE := "surging_wave"
const SKILL_META_FIELD := "meta_field"
const SKILL_CRESCENT_WAVE := "crescent_wave"
const SKILL_SHRAPNEL_FIELD := "shrapnel_field"
const SKILL_SWORDSMAN_BASIC_ATTACK := "swordsman_basic_attack"
const SKILL_GUNNER_BASIC_ATTACK := "gunner_basic_attack"
const SKILL_MAGE_BASIC_ATTACK := "mage_basic_attack"
const SKILL_SWORDSMAN_ULTIMATE := "swordsman_ultimate"
const SKILL_GUNNER_ULTIMATE := "gunner_ultimate"
const SKILL_MAGE_ULTIMATE := "mage_ultimate"
const ACTIVE_SKILL_IDS := [
	SKILL_BLADE_STORM,
	SKILL_CRESCENT_WAVE,
	SKILL_INFINITE_RELOAD,
	SKILL_SHRAPNEL_FIELD,
	SKILL_SURGING_WAVE,
	SKILL_META_FIELD,
	SKILL_SWORDSMAN_ULTIMATE,
	SKILL_GUNNER_ULTIMATE,
	SKILL_MAGE_ULTIMATE
]
const BASIC_ATTACK_SKILL_IDS := {
	SKILL_SWORDSMAN_BASIC_ATTACK: true,
	SKILL_GUNNER_BASIC_ATTACK: true,
	SKILL_MAGE_BASIC_ATTACK: true
}
const ALWAYS_UNLOCKED_SKILL_IDS := {
	SKILL_SWORDSMAN_ULTIMATE: 1,
	SKILL_GUNNER_ULTIMATE: 1,
	SKILL_MAGE_ULTIMATE: 1
}
const SKILL_TAG_COMBO := "combo"
const SKILL_TAG_DURATION := "duration"
const SKILL_TAG_QUANTITY := "quantity"

const SKILL_TAGS := {
	SKILL_META_FIELD: {SKILL_TAG_DURATION: true},
	SKILL_CRESCENT_WAVE: {SKILL_TAG_COMBO: true, SKILL_TAG_QUANTITY: true},
	SKILL_SHRAPNEL_FIELD: {SKILL_TAG_DURATION: true, SKILL_TAG_QUANTITY: true},
	SKILL_BLADE_STORM: {SKILL_TAG_DURATION: true, SKILL_TAG_QUANTITY: true},
	SKILL_INFINITE_RELOAD: {SKILL_TAG_DURATION: true, SKILL_TAG_COMBO: true},
	SKILL_SURGING_WAVE: {SKILL_TAG_DURATION: true, SKILL_TAG_COMBO: true, SKILL_TAG_QUANTITY: true},
	SKILL_SWORDSMAN_BASIC_ATTACK: {SKILL_TAG_COMBO: true, SKILL_TAG_QUANTITY: true},
	SKILL_GUNNER_BASIC_ATTACK: {SKILL_TAG_COMBO: true, SKILL_TAG_QUANTITY: true},
	SKILL_MAGE_BASIC_ATTACK: {SKILL_TAG_COMBO: true, SKILL_TAG_QUANTITY: true},
	SKILL_SWORDSMAN_ULTIMATE: {SKILL_TAG_COMBO: true},
	SKILL_GUNNER_ULTIMATE: {SKILL_TAG_DURATION: true},
	SKILL_MAGE_ULTIMATE: {SKILL_TAG_COMBO: true}
}

const SKILL_TITLES := {
	SKILL_META_FIELD: "\u6885\u5854\u9886\u57df",
	SKILL_CRESCENT_WAVE: "\u6708\u7259\u5251\u6c14",
	SKILL_SHRAPNEL_FIELD: "\u6563\u5f39",
	SKILL_BLADE_STORM: "剑刃风暴",
	SKILL_INFINITE_RELOAD: "无限装填",
	SKILL_SURGING_WAVE: "波涛汹涌",
	SKILL_SWORDSMAN_BASIC_ATTACK: "剑士普攻",
	SKILL_GUNNER_BASIC_ATTACK: "枪手普攻",
	SKILL_MAGE_BASIC_ATTACK: "术师普攻",
	SKILL_SWORDSMAN_ULTIMATE: "无敌斩",
	SKILL_GUNNER_ULTIMATE: "火箭弹幕",
	SKILL_MAGE_ULTIMATE: "奥数轰炸"
}

const SKILL_ROLE_IDS := {
	SKILL_META_FIELD: "mage",
	SKILL_CRESCENT_WAVE: "swordsman",
	SKILL_SHRAPNEL_FIELD: "gunner",
	SKILL_BLADE_STORM: "swordsman",
	SKILL_INFINITE_RELOAD: "gunner",
	SKILL_SURGING_WAVE: "mage",
	SKILL_SWORDSMAN_BASIC_ATTACK: "swordsman",
	SKILL_GUNNER_BASIC_ATTACK: "gunner",
	SKILL_MAGE_BASIC_ATTACK: "mage",
	SKILL_SWORDSMAN_ULTIMATE: "swordsman",
	SKILL_GUNNER_ULTIMATE: "gunner",
	SKILL_MAGE_ULTIMATE: "mage"
}

const UNLOCK_RECIPES := {
	SKILL_META_FIELD: {
		"role_exact": {"divine_grace": {1: 3}},
		"skill_exact": {"tide_rain": {1: 3}}
	},
	SKILL_CRESCENT_WAVE: {
		"role_exact": {},
		"skill_exact": {"trick": {1: 3}, "reprise": {1: 3}}
	},
	SKILL_SHRAPNEL_FIELD: {
		"role_exact": {"blazing_sun": {1: 3}},
		"skill_exact": {"tide_rain": {1: 3}}
	},
	SKILL_BLADE_STORM: {
		"role": {"formation_break": 3, "blazing_sun": 3},
		"skill": {}
	},
	SKILL_INFINITE_RELOAD: {
		"role": {},
		"skill": {"reprise": 3, "tide_rain": 3}
	},
	SKILL_SURGING_WAVE: {
		"role": {"formation_break": 3},
		"skill": {"tide_rain": 3}
	},
	SKILL_SWORDSMAN_BASIC_ATTACK: {
		"role_exact": {"greed": {1: 3}, "blazing_sun": {1: 3}},
		"skill_exact": {}
	},
	SKILL_GUNNER_BASIC_ATTACK: {
		"role_exact": {},
		"skill_exact": {"reprise": {1: 3}, "trick": {1: 3}}
	},
	SKILL_MAGE_BASIC_ATTACK: {
		"role_exact": {"formation_break": {1: 3}, "benediction": {1: 3}},
		"skill_exact": {}
	},
	SKILL_SWORDSMAN_ULTIMATE: {
		"always": true
	},
	SKILL_GUNNER_ULTIMATE: {
		"always": true
	},
	SKILL_MAGE_ULTIMATE: {
		"always": true
	}
}

const EVOLVE_RECIPES := {
	SKILL_META_FIELD: {
		"role_exact": {"formation_break": {2: 3}},
		"skill_exact": {"tide_rain": {2: 3}},
		"tier": 2
	},
	SKILL_CRESCENT_WAVE: {
		"role_exact": {},
		"skill_exact": {"trick": {2: 3}, "reprise": {2: 3}},
		"tier": 2
	},
	SKILL_SHRAPNEL_FIELD: {
		"role_exact": {},
		"skill_exact": {"tide_rain": {2: 3}, "trick": {2: 3}},
		"tier": 2
	},
	SKILL_BLADE_STORM: {
		"role": {},
		"skill": {"tide_rain": 3, "trick": 3},
		"tier": 2
	},
	SKILL_INFINITE_RELOAD: {
		"role": {"tailwind": 3},
		"skill": {"reprise": 3},
		"tier": 2
	},
	SKILL_SURGING_WAVE: {
		"role": {},
		"skill": {"reprise": 3, "trick": 3},
		"tier": 2
	},
	SKILL_SWORDSMAN_BASIC_ATTACK: {
		"role_exact": {"phantom": {2: 3}, "formation_break": {2: 3}},
		"skill_exact": {},
		"tier": 3
	},
	SKILL_GUNNER_BASIC_ATTACK: {
		"role_exact": {"prayer": {2: 3}},
		"skill_exact": {"trick": {2: 3}},
		"tier": 3
	},
	SKILL_MAGE_BASIC_ATTACK: {
		"role_exact": {},
		"skill_exact": {"trick": {2: 3}, "reprise": {2: 3}},
		"tier": 3
	},
	SKILL_SWORDSMAN_ULTIMATE: {
		"role_exact": {"blazing_sun": {1: 3}},
		"skill_exact": {"reprise": {1: 3}},
		"tier": 2
	},
	SKILL_GUNNER_ULTIMATE: {
		"role_exact": {"formation_break": {1: 3}},
		"skill_exact": {"tide_rain": {1: 3}},
		"tier": 2
	},
	SKILL_MAGE_ULTIMATE: {
		"role_exact": {"formation_break": {1: 3}, "benediction": {2: 3}, "blazing_sun": {2: 3}},
		"skill_exact": {"reprise": {1: 3}},
		"tier": 2
	}
}

static func build_empty_state() -> Dictionary:
	return {
		"unlocked": {},
		"tiers": {},
		"skill_blessing_bindings": {}
	}

static func normalize_state(value: Variant) -> Dictionary:
	var state := build_empty_state()
	if value is not Dictionary:
		return state
	var source := value as Dictionary
	if source.get("unlocked", {}) is Dictionary:
		for skill_id_value in (source.get("unlocked", {}) as Dictionary).keys():
			var skill_id := str(skill_id_value)
			if SKILL_TITLES.has(skill_id) and bool((source.get("unlocked", {}) as Dictionary).get(skill_id_value, false)):
				state["unlocked"][skill_id] = true
	if source.get("tiers", {}) is Dictionary:
		for skill_id_value in (source.get("tiers", {}) as Dictionary).keys():
			var skill_id := str(skill_id_value)
			if SKILL_TITLES.has(skill_id):
				state["tiers"][skill_id] = clamp(int((source.get("tiers", {}) as Dictionary).get(skill_id_value, 0)), 0, 3)
	if source.get("skill_blessing_bindings", {}) is Dictionary:
		for blessing_id_value in (source.get("skill_blessing_bindings", {}) as Dictionary).keys():
			var blessing_id := str(blessing_id_value)
			var skill_id := str((source.get("skill_blessing_bindings", {}) as Dictionary).get(blessing_id_value, ""))
			if SKILL_TITLES.has(skill_id):
				state["skill_blessing_bindings"][blessing_id] = skill_id
	return state

static func refresh_unlocks(owner) -> Array[Dictionary]:
	if owner == null:
		return []
	owner.blessing_skill_state = normalize_state(owner.blessing_skill_state)
	_ensure_always_unlocked(owner)
	var events: Array[Dictionary] = []
	for skill_id in SKILL_TITLES.keys():
		if not is_skill_unlocked(owner, str(skill_id)) and _can_apply_recipe(owner, str(skill_id), UNLOCK_RECIPES.get(skill_id, {})):
			_unlock_skill(owner, str(skill_id), 1)
			_bind_recipe_skill_blessings(owner, str(skill_id), UNLOCK_RECIPES.get(skill_id, {}))
			events.append({"skill_id": str(skill_id), "tier": 1, "title": str(SKILL_TITLES.get(skill_id, skill_id))})
		if is_skill_unlocked(owner, str(skill_id)):
			var recipe: Dictionary = EVOLVE_RECIPES.get(skill_id, {})
			var target_tier := int(recipe.get("tier", 2))
			if get_skill_tier(owner, str(skill_id)) < target_tier and _can_apply_recipe(owner, str(skill_id), recipe):
				_unlock_skill(owner, str(skill_id), target_tier)
				_bind_recipe_skill_blessings(owner, str(skill_id), recipe)
				events.append({"skill_id": str(skill_id), "tier": target_tier, "title": "%s%s" % [str(SKILL_TITLES.get(skill_id, skill_id)), _get_tier_suffix(target_tier)]})
	return events

static func is_skill_unlocked(owner, skill_id: String) -> bool:
	if ALWAYS_UNLOCKED_SKILL_IDS.has(skill_id):
		return true
	var state: Dictionary = normalize_state(owner.blessing_skill_state if owner != null else {})
	return bool((state.get("unlocked", {}) as Dictionary).get(skill_id, false))

static func get_skill_tier(owner, skill_id: String) -> int:
	if not is_skill_unlocked(owner, skill_id):
		return 0
	var state: Dictionary = normalize_state(owner.blessing_skill_state if owner != null else {})
	return max(int(ALWAYS_UNLOCKED_SKILL_IDS.get(skill_id, 1)), int((state.get("tiers", {}) as Dictionary).get(skill_id, 1)))

static func get_skill_title(skill_id: String) -> String:
	return str(SKILL_TITLES.get(skill_id, skill_id))

static func get_skill_role_id(skill_id: String) -> String:
	return str(SKILL_ROLE_IDS.get(skill_id, ""))

static func force_unlock_skill(owner, skill_id: String, tier: int) -> bool:
	if owner == null or not SKILL_TITLES.has(skill_id):
		return false
	_unlock_skill(owner, skill_id, clamp(tier, 1, 3))
	return true

static func get_blessing_unlock_detail(blessing_id: String, tier: int) -> String:
	var lines: Array[String] = []
	var unlock_lines := _collect_recipe_usage_lines(blessing_id, tier, UNLOCK_RECIPES, "可解锁")
	var evolve_lines := _collect_recipe_usage_lines(blessing_id, tier, EVOLVE_RECIPES, "可进化")
	lines.append_array(unlock_lines)
	lines.append_array(evolve_lines)
	if lines.is_empty():
		return "当前没有直接解锁技能；该祝福仍会提供自身数值加成。"
	return "\n".join(lines)

static func get_bound_skill_for_blessing(owner, blessing_id: String) -> String:
	var state: Dictionary = normalize_state(owner.blessing_skill_state if owner != null else {})
	return str((state.get("skill_blessing_bindings", {}) as Dictionary).get(blessing_id, ""))

static func get_skill_bound_blessing_level(owner, skill_id: String, blessing_id: String, tier: int = 0) -> int:
	if not _skill_can_read_blessing(skill_id, blessing_id):
		return 0
	var levels: Dictionary = owner.get_skill_blessing_levels() if owner != null and owner.has_method("get_skill_blessing_levels") else {}
	var blessing_levels: Dictionary = levels.get(blessing_id, {})
	if tier > 0:
		return int(blessing_levels.get(tier, 0))
	var total := 0
	for tier_value in blessing_levels.keys():
		total += int(blessing_levels.get(tier_value, 0))
	return total

static func get_quantity_extra_count(owner, skill_id: String) -> int:
	var level := get_skill_bound_blessing_level(owner, skill_id, "trick")
	return max(0, int(level))

static func get_combo_extra_scales(owner, skill_id: String) -> Array[float]:
	if not _skill_has_tag(skill_id, SKILL_TAG_COMBO):
		return []
	return _build_tier_scales(owner, "reprise", 0.5, 1.0)

static func get_skill_effect_scales(owner, skill_id: String, stat: String) -> Array[float]:
	match stat:
		"combo_skill_extra":
			if _skill_has_tag(skill_id, SKILL_TAG_COMBO):
				return _build_tier_scales(owner, "reprise", 0.5, 1.0)
		"quantity_skill_count":
			if _skill_has_tag(skill_id, SKILL_TAG_QUANTITY):
				return _build_tier_scales(owner, "trick", 0.5, 1.0)
	return []

static func get_duration_multiplier(owner, skill_id: String) -> float:
	if not _skill_has_tag(skill_id, SKILL_TAG_DURATION):
		return 1.0
	var levels: Dictionary = owner.get_skill_blessing_levels() if owner != null and owner.has_method("get_skill_blessing_levels") else {}
	var blessing_levels: Dictionary = levels.get("tide_rain", {})
	return 1.0 + float(blessing_levels.get(1, 0)) * 0.20 + float(blessing_levels.get(2, 0)) * 0.40

static func get_basic_attack_range_multiplier(owner, skill_id: String) -> float:
	var tier := get_skill_tier(owner, skill_id)
	if tier >= 3:
		return 1.21
	if tier >= 2:
		return 1.1
	return 1.0

static func get_basic_attack_projectile_speed_multiplier(owner, skill_id: String) -> float:
	var tier := get_skill_tier(owner, skill_id)
	if skill_id != SKILL_GUNNER_BASIC_ATTACK:
		return 1.0
	if tier >= 3:
		return 1.69
	if tier >= 2:
		return 1.3
	return 1.0

static func _get_quantity_extra_scales(owner, skill_id: String) -> Array[float]:
	if not _skill_has_tag(skill_id, SKILL_TAG_QUANTITY):
		return []
	return _build_tier_scales(owner, "trick", 0.5, 1.0)

static func _can_read_blessing_for_skill(_owner, skill_id: String, blessing_id: String) -> bool:
	return _skill_can_read_blessing(skill_id, blessing_id)

static func _skill_can_read_blessing(skill_id: String, blessing_id: String) -> bool:
	match blessing_id:
		"reprise":
			return _skill_has_tag(skill_id, SKILL_TAG_COMBO)
		"tide_rain":
			return _skill_has_tag(skill_id, SKILL_TAG_DURATION)
		"trick":
			return _skill_has_tag(skill_id, SKILL_TAG_QUANTITY)
	return false

static func _skill_has_tag(skill_id: String, tag: String) -> bool:
	var tags: Dictionary = SKILL_TAGS.get(skill_id, {})
	return bool(tags.get(tag, false))

static func _build_tier_scales(owner, blessing_id: String, tier_one_scale: float, tier_two_scale: float) -> Array[float]:
	var levels: Dictionary = owner.get_skill_blessing_levels() if owner != null and owner.has_method("get_skill_blessing_levels") else {}
	var blessing_levels: Dictionary = levels.get(blessing_id, {})
	var result: Array[float] = []
	for _index in range(max(0, int(blessing_levels.get(1, 0)))):
		result.append(tier_one_scale)
	for _index in range(max(0, int(blessing_levels.get(2, 0)))):
		result.append(tier_two_scale)
	return result

static func _unlock_skill(owner, skill_id: String, tier: int) -> void:
	var state: Dictionary = normalize_state(owner.blessing_skill_state)
	(state["unlocked"] as Dictionary)[skill_id] = true
	(state["tiers"] as Dictionary)[skill_id] = max(int((state["tiers"] as Dictionary).get(skill_id, 0)), tier)
	owner.blessing_skill_state = state

static func _ensure_always_unlocked(owner) -> void:
	var state: Dictionary = normalize_state(owner.blessing_skill_state)
	for skill_id in ALWAYS_UNLOCKED_SKILL_IDS.keys():
		(state["unlocked"] as Dictionary)[skill_id] = true
		(state["tiers"] as Dictionary)[skill_id] = max(
			int(ALWAYS_UNLOCKED_SKILL_IDS.get(skill_id, 1)),
			int((state["tiers"] as Dictionary).get(skill_id, 0))
		)
	owner.blessing_skill_state = state

static func _can_apply_recipe(owner, skill_id: String, recipe: Dictionary) -> bool:
	if bool(recipe.get("always", false)):
		return true
	var role_requirements: Dictionary = recipe.get("role", {})
	for blessing_id in role_requirements.keys():
		if not _meets_role_requirement(owner, str(blessing_id), role_requirements.get(blessing_id, 0)):
			return false
	var skill_requirements: Dictionary = recipe.get("skill", {})
	for blessing_id in skill_requirements.keys():
		if not _skill_can_read_blessing(skill_id, str(blessing_id)):
			return false
		if not _meets_skill_requirement(owner, str(blessing_id), skill_requirements.get(blessing_id, 0)):
			return false
	var exact_role_requirements: Dictionary = recipe.get("role_exact", {})
	for blessing_id in exact_role_requirements.keys():
		if not _meets_exact_role_requirement(owner, str(blessing_id), exact_role_requirements.get(blessing_id, {})):
			return false
	var exact_skill_requirements: Dictionary = recipe.get("skill_exact", {})
	for blessing_id in exact_skill_requirements.keys():
		if not _skill_can_read_blessing(skill_id, str(blessing_id)):
			return false
		if not _meets_exact_skill_requirement(owner, str(blessing_id), exact_skill_requirements.get(blessing_id, {})):
			return false
	return true

static func _bind_recipe_skill_blessings(owner, _skill_id: String, _recipe: Dictionary) -> void:
	owner.blessing_skill_state = normalize_state(owner.blessing_skill_state)

static func _meets_role_requirement(owner, blessing_id: String, requirement: Variant) -> bool:
	var role_id := ""
	if owner != null and owner.has_method("_get_active_role"):
		role_id = str(owner._get_active_role().get("id", ""))
	var levels: Dictionary = owner.get_role_blessing_levels(role_id) if owner != null and owner.has_method("get_role_blessing_levels") else {}
	return _meets_level_requirement(levels.get(blessing_id, {}), requirement)

static func _meets_skill_requirement(owner, blessing_id: String, requirement: Variant) -> bool:
	var levels: Dictionary = owner.get_skill_blessing_levels() if owner != null and owner.has_method("get_skill_blessing_levels") else {}
	return _meets_level_requirement(levels.get(blessing_id, {}), requirement)

static func _meets_exact_role_requirement(owner, blessing_id: String, requirement: Variant) -> bool:
	var role_id := ""
	if owner != null and owner.has_method("_get_active_role"):
		role_id = str(owner._get_active_role().get("id", ""))
	var levels: Dictionary = owner.get_role_blessing_levels(role_id) if owner != null and owner.has_method("get_role_blessing_levels") else {}
	return _meets_exact_tier_requirement(levels.get(blessing_id, {}), requirement)

static func _meets_exact_skill_requirement(owner, blessing_id: String, requirement: Variant) -> bool:
	var levels: Dictionary = owner.get_skill_blessing_levels() if owner != null and owner.has_method("get_skill_blessing_levels") else {}
	return _meets_exact_tier_requirement(levels.get(blessing_id, {}), requirement)

static func _meets_level_requirement(levels_value: Variant, requirement: Variant) -> bool:
	if requirement is Dictionary:
		if levels_value is not Dictionary:
			return false
		var required_equivalent_count := 0
		for tier_value in (requirement as Dictionary).keys():
			var tier := int(tier_value)
			required_equivalent_count += _get_tier_equivalent_count(tier) * int((requirement as Dictionary).get(tier_value, 0))
		return _get_equivalent_count(levels_value) >= required_equivalent_count
	return _get_equivalent_count(levels_value) >= int(requirement)

static func _get_equivalent_count(value: Variant) -> int:
	if value is not Dictionary:
		return 0
	var total := 0
	for tier_value in (value as Dictionary).keys():
		var tier := int(tier_value)
		total += _get_tier_equivalent_count(tier) * int((value as Dictionary).get(tier_value, 0))
	return total

static func _get_tier_equivalent_count(tier: int) -> int:
	return TIER_TWO_EQUIVALENT_COUNT if tier >= 2 else TIER_ONE_EQUIVALENT_COUNT

static func _meets_exact_tier_requirement(levels_value: Variant, requirement: Variant) -> bool:
	if levels_value is not Dictionary or requirement is not Dictionary:
		return false
	for tier_value in (requirement as Dictionary).keys():
		var tier := int(tier_value)
		var required_count := int((requirement as Dictionary).get(tier_value, 0))
		if tier <= 1:
			if _get_equivalent_count_for_tier_one_unlock(levels_value) < required_count:
				return false
		elif int((levels_value as Dictionary).get(tier, 0)) < required_count:
			return false
	return true

static func _get_equivalent_count_for_tier_one_unlock(value: Variant) -> int:
	if value is not Dictionary:
		return 0
	return int((value as Dictionary).get(1, 0)) + int((value as Dictionary).get(2, 0)) * TIER_TWO_EQUIVALENT_COUNT

static func _get_tier_suffix(tier: int) -> String:
	match tier:
		2:
			return "II"
		3:
			return "III"
	return ""

static func _sum_level_dict(value: Variant) -> int:
	if value is not Dictionary:
		return 0
	var total := 0
	for tier_value in (value as Dictionary).keys():
		total += int((value as Dictionary).get(tier_value, 0))
	return total

static func _collect_recipe_usage_lines(blessing_id: String, tier: int, recipes: Dictionary, action_label: String) -> Array[String]:
	var lines: Array[String] = []
	for skill_id_value in SKILL_TITLES.keys():
		var skill_id := str(skill_id_value)
		var recipe: Dictionary = recipes.get(skill_id, {})
		if recipe.is_empty() or bool(recipe.get("always", false)):
			continue
		var requirement_text := _get_recipe_blessing_requirement_text(recipe, blessing_id, tier)
		if requirement_text == "":
			continue
		lines.append("%s：%s（需要 %s）" % [action_label, str(SKILL_TITLES.get(skill_id, skill_id)), requirement_text])
	return lines

static func _get_recipe_blessing_requirement_text(recipe: Dictionary, blessing_id: String, tier: int) -> String:
	for key in ["role_exact", "skill_exact"]:
		var exact_requirements: Dictionary = recipe.get(key, {})
		if exact_requirements.has(blessing_id):
			var tier_requirements: Dictionary = exact_requirements.get(blessing_id, {})
			var required_count := int(tier_requirements.get(tier, 0))
			if required_count > 0:
				return "%s x%d" % [_get_blessing_tier_label(blessing_id, tier), required_count]
			var tier_one_required_count := int(tier_requirements.get(1, 0))
			if tier >= 2 and tier_one_required_count > 0:
				return "%s x1（等效 %s x%d）" % [
					_get_blessing_tier_label(blessing_id, tier),
					_get_blessing_tier_label(blessing_id, 1),
					TIER_TWO_EQUIVALENT_COUNT
				]
	for key in ["role", "skill"]:
		var requirements: Dictionary = recipe.get(key, {})
		if requirements.has(blessing_id):
			var required_equivalent_count := int(requirements.get(blessing_id, 0))
			if required_equivalent_count <= 0:
				continue
			if tier >= 2:
				return "%s x1（等效 %d 张 I）" % [_get_blessing_tier_label(blessing_id, tier), TIER_TWO_EQUIVALENT_COUNT]
			return "%s x%d" % [_get_blessing_tier_label(blessing_id, tier), required_equivalent_count]
	return ""

static func _get_blessing_tier_label(blessing_id: String, tier: int) -> String:
	var suffix := "II" if tier >= 2 else "I"
	return "%s%s" % [blessing_id, suffix]
