extends RefCounted

const ROLE_BOUND := "role"
const SKILL_BOUND := "skill"
const TIER_ONE_EQUIVALENT_COUNT := 1
const TIER_TWO_EQUIVALENT_COUNT := 3
const EXACT_TIER_ONE_KEYS := ["role_exact", "skill_exact"]
const EQUIVALENT_KEYS := ["role", "skill"]

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
const SKILL_ENTRY_RESCUE := "entry_rescue"
const SKILL_HERO_ENTRY := "hero_entry"
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
const ULTIMATE_SKILL_IDS := {
	SKILL_SWORDSMAN_ULTIMATE: true,
	SKILL_GUNNER_ULTIMATE: true,
	SKILL_MAGE_ULTIMATE: true,
	SKILL_ENTRY_RESCUE: true,
	SKILL_HERO_ENTRY: true
}
const INHERENT_SKILL_IDS := {
	SKILL_SWORDSMAN_BASIC_ATTACK: true,
	SKILL_GUNNER_BASIC_ATTACK: true,
	SKILL_MAGE_BASIC_ATTACK: true,
	SKILL_SWORDSMAN_ULTIMATE: true,
	SKILL_GUNNER_ULTIMATE: true,
	SKILL_MAGE_ULTIMATE: true
}
const SKILL_GRAPH_IDS := [
	SKILL_SWORDSMAN_BASIC_ATTACK,
	SKILL_BLADE_STORM,
	SKILL_CRESCENT_WAVE,
	SKILL_SWORDSMAN_ULTIMATE,
	SKILL_GUNNER_BASIC_ATTACK,
	SKILL_INFINITE_RELOAD,
	SKILL_SHRAPNEL_FIELD,
	SKILL_GUNNER_ULTIMATE,
	SKILL_MAGE_BASIC_ATTACK,
	SKILL_SURGING_WAVE,
	SKILL_META_FIELD,
	SKILL_MAGE_ULTIMATE,
	SKILL_ENTRY_RESCUE,
	SKILL_HERO_ENTRY
]
const ALWAYS_UNLOCKED_SKILL_IDS := {
	SKILL_SWORDSMAN_ULTIMATE: 1,
	SKILL_GUNNER_ULTIMATE: 1,
	SKILL_MAGE_ULTIMATE: 1
}
const SKILL_TAG_COMBO := "combo"
const SKILL_TAG_DURATION := "duration"
const SKILL_TAG_QUANTITY := "quantity"

const BLESSING_TITLES := {
	"divine_grace": "神赐",
	"prayer": "祷告",
	"formation_break": "破阵",
	"benediction": "恩典",
	"greed": "贪婪",
	"support": "支援",
	"tailwind": "乘风",
	"tide_rain": "潮雨",
	"blazing_sun": "焰阳",
	"reprise": "再演",
	"phantom": "幻影",
	"unyielding": "不屈",
	"trick": "戏法"
}

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
	SKILL_MAGE_ULTIMATE: {SKILL_TAG_COMBO: true},
	SKILL_ENTRY_RESCUE: {},
	SKILL_HERO_ENTRY: {}
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
	SKILL_MAGE_ULTIMATE: "mage",
	SKILL_ENTRY_RESCUE: "",
	SKILL_HERO_ENTRY: ""
}

const SHARED_ENTRY_SKILL_IDS := {
	SKILL_ENTRY_RESCUE: true,
	SKILL_HERO_ENTRY: true
}

const UNLOCK_RECIPES := {
	SKILL_META_FIELD: {
		"role_exact": {"divine_grace": {1: 1}},
		"skill_exact": {"tide_rain": {1: 1}}
	},
	SKILL_CRESCENT_WAVE: {
		"role_exact": {},
		"skill_exact": {"trick": {1: 1}, "reprise": {1: 1}}
	},
	SKILL_SHRAPNEL_FIELD: {
		"role_exact": {"blazing_sun": {1: 1}},
		"skill_exact": {"tide_rain": {1: 1}}
	},
	SKILL_BLADE_STORM: {
		"role": {"formation_break": 1, "blazing_sun": 1},
		"skill": {}
	},
	SKILL_INFINITE_RELOAD: {
		"role": {},
		"skill": {"reprise": 1, "tide_rain": 1}
	},
	SKILL_SURGING_WAVE: {
		"role": {"formation_break": 1},
		"skill": {"tide_rain": 1}
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
	},
	SKILL_ENTRY_RESCUE: {
		"role": {"support": 1, "divine_grace": 1},
		"skill": {}
	},
	SKILL_HERO_ENTRY: {
		"role": {"support": 1},
		"skill": {"reprise": 1}
	}
}

const EVOLVE_RECIPES := {
	SKILL_META_FIELD: {
		"role_exact": {"divine_grace": {1: 3}},
		"skill_exact": {"tide_rain": {1: 3}},
		"tier": 2
	},
	SKILL_CRESCENT_WAVE: {
		"role_exact": {},
		"skill_exact": {"trick": {1: 3}, "reprise": {1: 3}},
		"tier": 2
	},
	SKILL_SHRAPNEL_FIELD: {
		"role_exact": {"blazing_sun": {1: 3}},
		"skill_exact": {"tide_rain": {1: 3}},
		"tier": 2
	},
	SKILL_BLADE_STORM: {
		"role_exact": {"formation_break": {1: 3}, "blazing_sun": {1: 3}},
		"skill_exact": {},
		"tier": 2
	},
	SKILL_INFINITE_RELOAD: {
		"role_exact": {},
		"skill_exact": {"reprise": {1: 3}, "tide_rain": {1: 3}},
		"tier": 2
	},
	SKILL_SURGING_WAVE: {
		"role_exact": {"formation_break": {1: 3}},
		"skill_exact": {"tide_rain": {1: 3}},
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
		"role_exact": {"formation_break": {1: 3}},
		"skill_exact": {"reprise": {1: 3}},
		"tier": 2
	},
	SKILL_ENTRY_RESCUE: {
		"role_exact": {"support": {1: 3}, "divine_grace": {1: 3}},
		"skill_exact": {},
		"tier": 2
	},
	SKILL_HERO_ENTRY: {
		"role_exact": {"support": {1: 3}},
		"skill_exact": {"reprise": {1: 3}},
		"tier": 2
	}
}

const THIRD_TIER_RECIPES := {
	SKILL_BLADE_STORM: {
		"role_exact": {},
		"skill_exact": {"tide_rain": {2: 3}, "trick": {2: 3}},
		"tier": 3
	},
	SKILL_CRESCENT_WAVE: {
		"role_exact": {},
		"skill_exact": {"trick": {2: 3}, "reprise": {2: 3}},
		"tier": 3
	},
	SKILL_INFINITE_RELOAD: {
		"role_exact": {"tailwind": {2: 3}},
		"skill_exact": {"trick": {2: 3}},
		"tier": 3
	},
	SKILL_SHRAPNEL_FIELD: {
		"role_exact": {},
		"skill_exact": {"tide_rain": {2: 3}, "trick": {2: 3}},
		"tier": 3
	},
	SKILL_SURGING_WAVE: {
		"role_exact": {},
		"skill_exact": {"reprise": {2: 3}, "trick": {2: 3}},
		"tier": 3
	},
	SKILL_META_FIELD: {
		"role_exact": {"formation_break": {2: 3}},
		"skill_exact": {"tide_rain": {2: 3}},
		"tier": 3
	},
	SKILL_SWORDSMAN_ULTIMATE: {
		"role_exact": {"blazing_sun": {2: 3}, "greed": {1: 3}},
		"skill_exact": {},
		"tier": 3
	},
	SKILL_GUNNER_ULTIMATE: {
		"role_exact": {"blazing_sun": {2: 3}, "formation_break": {2: 3}},
		"skill_exact": {},
		"tier": 3
	},
	SKILL_MAGE_ULTIMATE: {
		"role_exact": {"benediction": {2: 3}},
		"skill_exact": {"reprise": {2: 3}},
		"tier": 3
	},
	SKILL_ENTRY_RESCUE: {
		"role_exact": {"divine_grace": {2: 3}},
		"skill_exact": {"tide_rain": {2: 3}},
		"tier": 3
	},
	SKILL_HERO_ENTRY: {
		"role_exact": {"support": {2: 3}},
		"skill_exact": {"reprise": {2: 3}},
		"tier": 3
	}
}

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


static func _is_known_skill_id(skill_id: String) -> bool:
	return SKILL_TITLES.has(skill_id) or SHARED_ENTRY_SKILL_IDS.has(skill_id)


static func _get_recipe_skill_ids() -> Array:
	var ids: Array = []
	for skill_id_value in SKILL_TITLES.keys():
		ids.append(skill_id_value)
	for skill_id_value in SHARED_ENTRY_SKILL_IDS.keys():
		if not ids.has(skill_id_value):
			ids.append(skill_id_value)
	return ids

static func normalize_state(value: Variant) -> Dictionary:
	var state := build_empty_state()
	if value is not Dictionary:
		return state
	var source := value as Dictionary
	if source.get("unlocked", {}) is Dictionary:
		for skill_id_value in (source.get("unlocked", {}) as Dictionary).keys():
			var skill_id := str(skill_id_value)
			if _is_known_skill_id(skill_id) and bool((source.get("unlocked", {}) as Dictionary).get(skill_id_value, false)):
				state["unlocked"][skill_id] = true
	if source.get("tiers", {}) is Dictionary:
		for skill_id_value in (source.get("tiers", {}) as Dictionary).keys():
			var skill_id := str(skill_id_value)
			if _is_known_skill_id(skill_id):
				state["tiers"][skill_id] = clamp(int((source.get("tiers", {}) as Dictionary).get(skill_id_value, 0)), 0, 3)
	if source.get("skill_blessing_bindings", {}) is Dictionary:
		for blessing_id_value in (source.get("skill_blessing_bindings", {}) as Dictionary).keys():
			var blessing_id := str(blessing_id_value)
			var skill_id := str((source.get("skill_blessing_bindings", {}) as Dictionary).get(blessing_id_value, ""))
			if _is_known_skill_id(skill_id):
				state["skill_blessing_bindings"][blessing_id] = skill_id
	if source.get("skill_blessing_baselines", {}) is Dictionary:
		for skill_id_value in (source.get("skill_blessing_baselines", {}) as Dictionary).keys():
			var skill_id := str(skill_id_value)
			if not _is_known_skill_id(skill_id):
				continue
			var source_baselines: Variant = (source.get("skill_blessing_baselines", {}) as Dictionary).get(skill_id_value, {})
			if source_baselines is not Dictionary:
				continue
			var normalized_baselines: Dictionary = {}
			for blessing_id_value in (source_baselines as Dictionary).keys():
				var blessing_id := str(blessing_id_value)
				var source_levels: Variant = (source_baselines as Dictionary).get(blessing_id_value, {})
				if source_levels is not Dictionary:
					continue
				var normalized_levels: Dictionary = {}
				for tier_value in (source_levels as Dictionary).keys():
					var tier := int(tier_value)
					if tier < 1 or tier > 2:
						continue
					var amount: int = max(0, int((source_levels as Dictionary).get(tier_value, 0)))
					if amount > 0:
						normalized_levels[tier] = amount
				if not normalized_levels.is_empty():
					normalized_baselines[blessing_id] = normalized_levels
			if not normalized_baselines.is_empty():
				state["skill_blessing_baselines"][skill_id] = normalized_baselines
	if source.get("skill_blessing_bonus_credits", {}) is Dictionary:
		for skill_id_value in (source.get("skill_blessing_bonus_credits", {}) as Dictionary).keys():
			var skill_id := str(skill_id_value)
			if not _is_known_skill_id(skill_id):
				continue
			var source_credits: Variant = (source.get("skill_blessing_bonus_credits", {}) as Dictionary).get(skill_id_value, {})
			if source_credits is not Dictionary:
				continue
			var normalized_credits: Dictionary = {}
			for blessing_id_value in (source_credits as Dictionary).keys():
				var blessing_id := str(blessing_id_value)
				var source_levels: Variant = (source_credits as Dictionary).get(blessing_id_value, {})
				if source_levels is not Dictionary:
					continue
				var normalized_levels: Dictionary = {}
				for tier_value in (source_levels as Dictionary).keys():
					var tier := int(tier_value)
					if tier < 1 or tier > 2:
						continue
					var amount: int = max(0, int((source_levels as Dictionary).get(tier_value, 0)))
					if amount > 0:
						normalized_levels[tier] = amount
				if not normalized_levels.is_empty():
					normalized_credits[blessing_id] = normalized_levels
			if not normalized_credits.is_empty():
				state["skill_blessing_bonus_credits"][skill_id] = normalized_credits
	for lock_key in ["role_recipe_locks", "skill_recipe_locks"]:
		if source.get(lock_key, {}) is not Dictionary:
			continue
		var normalized_locks: Dictionary = {}
		for blessing_id_value in (source.get(lock_key, {}) as Dictionary).keys():
			var blessing_id := str(blessing_id_value)
			var source_levels: Variant = (source.get(lock_key, {}) as Dictionary).get(blessing_id_value, {})
			if source_levels is not Dictionary:
				continue
			var normalized_levels: Dictionary = {}
			for tier_value in (source_levels as Dictionary).keys():
				var tier := int(tier_value)
				if tier < 1 or tier > 2:
					continue
				var amount: int = max(0, int((source_levels as Dictionary).get(tier_value, 0)))
				if amount > 0:
					normalized_levels[tier] = amount
			if not normalized_levels.is_empty():
				normalized_locks[blessing_id] = normalized_levels
		state[lock_key] = normalized_locks
	return state

static func refresh_unlocks(owner, selected_blessing_id: String = "", selected_tier: int = 0, selected_binding: String = "", role_context: String = "") -> Array[Dictionary]:
	if owner == null:
		return []
	owner.blessing_skill_state = normalize_state(owner.blessing_skill_state)
	_ensure_always_unlocked(owner)
	var resolved_role_context := _resolve_role_context(owner, role_context)
	var events: Array[Dictionary] = []
	if selected_blessing_id != "" and selected_tier > 0:
		_auto_refresh_inherent_skills(owner, events, resolved_role_context)
		var candidates := get_recipe_candidates_for_blessing(owner, selected_blessing_id, selected_tier, selected_binding, resolved_role_context)
		if candidates.size() == 1:
			events.append_array(apply_recipe_candidate(owner, candidates[0]))
		elif candidates.size() > 1:
			events.append({
				"type": "binding_choice",
				"blessing_id": selected_blessing_id,
				"tier": selected_tier,
				"binding": selected_binding,
				"candidates": candidates
		})
		return events
	_auto_refresh_inherent_skills(owner, events, resolved_role_context)
	for skill_id in ALWAYS_UNLOCKED_SKILL_IDS.keys():
		_try_evolve_skill(owner, str(skill_id), events, resolved_role_context)
	for skill_id in _get_recipe_skill_ids():
		if ALWAYS_UNLOCKED_SKILL_IDS.has(str(skill_id)):
			continue
		if not is_skill_unlocked(owner, str(skill_id)) and _can_apply_recipe(owner, str(skill_id), UNLOCK_RECIPES.get(skill_id, {}), resolved_role_context):
			var unlock_recipe: Dictionary = UNLOCK_RECIPES.get(skill_id, {})
			_unlock_skill(owner, str(skill_id), 1)
			if not SHARED_ENTRY_SKILL_IDS.has(str(skill_id)):
				_lock_recipe_requirements(owner, str(skill_id), unlock_recipe)
				_snapshot_skill_blessing_baseline(owner, str(skill_id), [1, 2])
				_bind_recipe_skill_blessings(owner, str(skill_id), unlock_recipe)
			events.append({"skill_id": str(skill_id), "tier": 1, "title": get_skill_title(str(skill_id))})
		if is_skill_unlocked(owner, str(skill_id)):
			_try_evolve_skill(owner, str(skill_id), events, resolved_role_context)
	return events

static func get_recipe_candidates_for_blessing(owner, blessing_id: String, tier: int, binding: String, role_context: String = "") -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if owner == null or blessing_id == "" or tier <= 0:
		return candidates
	for skill_id_value in _get_recipe_skill_ids():
		var skill_id := str(skill_id_value)
		if INHERENT_SKILL_IDS.has(skill_id):
			continue
		if not is_skill_unlocked(owner, skill_id):
			var unlock_recipe: Dictionary = UNLOCK_RECIPES.get(skill_id, {})
			if _recipe_uses_blessing_tier(unlock_recipe, binding, blessing_id, tier) and _can_apply_recipe(owner, skill_id, unlock_recipe, role_context):
				candidates.append(_make_recipe_candidate(skill_id, 1, "unlock", unlock_recipe))
			continue
		var evolve_recipe: Dictionary = _get_next_evolve_recipe(owner, skill_id)
		if evolve_recipe.is_empty():
			continue
		var target_tier: int = int(evolve_recipe.get("tier", 2))
		if get_skill_tier(owner, skill_id) >= target_tier:
			continue
		if _recipe_uses_blessing_tier(evolve_recipe, binding, blessing_id, tier) and _can_apply_recipe(owner, skill_id, evolve_recipe, role_context):
			candidates.append(_make_recipe_candidate(skill_id, target_tier, "evolve", evolve_recipe))
	return candidates

static func apply_recipe_candidate(owner, candidate: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if owner == null:
		return events
	var skill_id := str(candidate.get("skill_id", ""))
	if not _is_known_skill_id(skill_id):
		return events
	var recipe: Dictionary = candidate.get("recipe", {})
	if recipe.is_empty() or not _can_apply_recipe(owner, skill_id, recipe):
		return events
	var target_tier: int = max(1, int(candidate.get("tier", 1)))
	_unlock_skill(owner, skill_id, target_tier)
	if not INHERENT_SKILL_IDS.has(skill_id) and not SHARED_ENTRY_SKILL_IDS.has(skill_id):
		_lock_recipe_requirements(owner, skill_id, recipe)
		if target_tier <= 1:
			_snapshot_skill_blessing_baseline(owner, skill_id, [1, 2])
		elif target_tier >= 2:
			_snapshot_skill_blessing_baseline(owner, skill_id, [2])
	if not INHERENT_SKILL_IDS.has(skill_id) and not SHARED_ENTRY_SKILL_IDS.has(skill_id):
		_bind_recipe_skill_blessings(owner, skill_id, recipe)
	events.append({"skill_id": skill_id, "tier": target_tier, "title": "%s%s" % [get_skill_title(skill_id), _get_tier_suffix(target_tier)]})
	return events

static func lock_one_blessing_material(owner, binding: String, blessing_id: String, tier: int) -> void:
	if owner == null or blessing_id == "" or tier <= 0:
		return
	var state: Dictionary = normalize_state(owner.blessing_skill_state)
	var lock_key := "skill_recipe_locks" if binding == SKILL_BOUND else "role_recipe_locks"
	var locks: Dictionary = (state.get(lock_key, {}) as Dictionary).duplicate(true)
	var lock_levels: Dictionary = (locks.get(blessing_id, {}) as Dictionary).duplicate(true)
	lock_levels[tier] = int(lock_levels.get(tier, 0)) + 1
	locks[blessing_id] = lock_levels
	state[lock_key] = locks
	owner.blessing_skill_state = state

static func _auto_refresh_inherent_skills(owner, events: Array[Dictionary], role_context: String = "") -> void:
	for skill_id_value in INHERENT_SKILL_IDS.keys():
		var skill_id := str(skill_id_value)
		if not is_skill_unlocked(owner, skill_id) and _can_apply_recipe(owner, skill_id, UNLOCK_RECIPES.get(skill_id, {}), role_context):
			events.append_array(apply_recipe_candidate(owner, _make_recipe_candidate(skill_id, 1, "unlock", UNLOCK_RECIPES.get(skill_id, {}))))
		if is_skill_unlocked(owner, skill_id):
			var recipe: Dictionary = _get_next_evolve_recipe(owner, skill_id)
			var target_tier: int = int(recipe.get("tier", 2))
			if not recipe.is_empty() and get_skill_tier(owner, skill_id) < target_tier and _can_apply_recipe(owner, skill_id, recipe, role_context):
				events.append_array(apply_recipe_candidate(owner, _make_recipe_candidate(skill_id, target_tier, "evolve", recipe)))

static func _make_recipe_candidate(skill_id: String, tier: int, action: String, recipe: Dictionary) -> Dictionary:
	return {
		"skill_id": skill_id,
		"tier": tier,
		"action": action,
		"recipe": recipe.duplicate(true),
		"title": get_skill_title(skill_id),
		"role_id": str(SKILL_ROLE_IDS.get(skill_id, ""))
	}

static func _try_evolve_skill(owner, skill_id: String, events: Array[Dictionary], role_context: String = "") -> void:
	if owner == null or not is_skill_unlocked(owner, skill_id):
		return
	var recipe: Dictionary = _get_next_evolve_recipe(owner, skill_id)
	if recipe.is_empty():
		return
	var target_tier: int = int(recipe.get("tier", 2))
	if get_skill_tier(owner, skill_id) >= target_tier:
		return
	if not _can_apply_recipe(owner, skill_id, recipe, role_context):
		return
	_unlock_skill(owner, skill_id, target_tier)
	if not INHERENT_SKILL_IDS.has(skill_id) and not SHARED_ENTRY_SKILL_IDS.has(skill_id):
		_lock_recipe_requirements(owner, skill_id, recipe)
		if target_tier >= 2:
			_snapshot_skill_blessing_baseline(owner, skill_id, [2])
	if not INHERENT_SKILL_IDS.has(skill_id) and not SHARED_ENTRY_SKILL_IDS.has(skill_id):
		_bind_recipe_skill_blessings(owner, skill_id, recipe)
	events.append({"skill_id": skill_id, "tier": target_tier, "title": "%s%s" % [get_skill_title(skill_id), _get_tier_suffix(target_tier)]})

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


static func _get_next_evolve_recipe(owner, skill_id: String) -> Dictionary:
	var current_tier: int = get_skill_tier(owner, skill_id)
	var second_tier_recipe: Dictionary = EVOLVE_RECIPES.get(skill_id, {})
	if not second_tier_recipe.is_empty() and current_tier < int(second_tier_recipe.get("tier", 2)):
		return second_tier_recipe
	var third_tier_recipe: Dictionary = THIRD_TIER_RECIPES.get(skill_id, {})
	if not third_tier_recipe.is_empty() and current_tier < int(third_tier_recipe.get("tier", 3)):
		return third_tier_recipe
	return {}

static func get_skill_title(skill_id: String) -> String:
	match skill_id:
		SKILL_ENTRY_RESCUE:
			return "协同救援"
		SKILL_HERO_ENTRY:
			return "英雄登场"
	return str(SKILL_TITLES.get(skill_id, skill_id))

static func get_skill_role_id(skill_id: String) -> String:
	return str(SKILL_ROLE_IDS.get(skill_id, ""))

static func get_skill_graph_entries(owner, role_context: String = "") -> Array[Dictionary]:
	if owner != null:
		refresh_unlocks(owner, "", 0, "", role_context)
	var entries: Array[Dictionary] = []
	for skill_id_value in SKILL_GRAPH_IDS:
		var skill_id := str(skill_id_value)
		var current_tier: int = get_skill_tier(owner, skill_id)
		var target_tier: int = 0
		var action := "complete"
		var recipe: Dictionary = {}
		if current_tier <= 0:
			action = "unlock"
			target_tier = 1
			recipe = UNLOCK_RECIPES.get(skill_id, {})
		else:
			var evolve_recipe: Dictionary = _get_next_evolve_recipe(owner, skill_id)
			var evolve_tier: int = int(evolve_recipe.get("tier", 0))
			if not evolve_recipe.is_empty() and current_tier < evolve_tier:
				action = "evolve"
				target_tier = evolve_tier
				recipe = evolve_recipe
			else:
				target_tier = current_tier
		entries.append({
			"skill_id": skill_id,
			"title": get_skill_title(skill_id),
			"role_id": get_skill_role_id(skill_id),
			"current_tier": current_tier,
			"target_tier": target_tier,
			"action": action,
			"tags": _get_skill_tag_labels(skill_id),
			"requirements": _build_recipe_progress(owner, skill_id, recipe),
			"enhancements": _build_skill_enhancement_progress(owner, skill_id)
		})
	return entries

static func get_skill_graph_text(owner, role_id_filter: String = "") -> String:
	var lines: Array[String] = []
	for entry in get_skill_graph_entries(owner, role_id_filter):
		var role_id := str(entry.get("role_id", ""))
		if role_id_filter != "" and role_id != role_id_filter:
			continue
		var current_tier: int = int(entry.get("current_tier", 0))
		var action := str(entry.get("action", "complete"))
		var status := "已完成" if action == "complete" else ("待解锁" if action == "unlock" else "待进化")
		if current_tier > 0 and action != "complete":
			status = "I -> II" if int(entry.get("target_tier", 0)) == 2 else "II -> III"
		elif current_tier > 0:
			status = "已获得 %s" % _get_tier_suffix(current_tier)
		lines.append("[color=%s][b]%s[/b][/color]  %s  %s" % [
			"#74f0a7" if current_tier > 0 else "#f3d35a",
			str(entry.get("title", "")),
			status,
			str(entry.get("tags", ""))
		])
		var requirements: Array = entry.get("requirements", [])
		if requirements.is_empty():
			var enhancements: Array = entry.get("enhancements", [])
			if enhancements.is_empty():
				lines.append("  需求：无")
			else:
				lines.append("  后续强化：")
				for enhancement in enhancements:
					lines.append("  %s" % str(enhancement))
		else:
			for requirement in requirements:
				lines.append("  %s" % str(requirement))
		lines.append("")
	if lines.is_empty():
		return "暂无技能图谱信息。"
	return "\n".join(lines)

static func force_unlock_skill(owner, skill_id: String, tier: int) -> bool:
	if owner == null or not _is_known_skill_id(skill_id):
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

static func get_available_blessing_count(owner, binding: String, blessing_id: String, tier: int) -> int:
	if owner == null:
		return 0
	var lock_key := "skill_recipe_locks" if binding == SKILL_BOUND else "role_recipe_locks"
	var state: Dictionary = normalize_state(owner.blessing_skill_state)
	var locks: Dictionary = state.get(lock_key, {})
	var levels: Dictionary = {}
	if binding == SKILL_BOUND:
		levels = owner.get_skill_blessing_levels() if owner.has_method("get_skill_blessing_levels") else {}
	else:
		var role_id := ""
		if owner.has_method("_get_active_role"):
			role_id = str(owner._get_active_role().get("id", ""))
		levels = owner.get_role_blessing_levels(role_id) if owner.has_method("get_role_blessing_levels") else {}
	var blessing_levels: Dictionary = levels.get(blessing_id, {})
	var lock_levels: Dictionary = locks.get(blessing_id, {})
	return max(0, int(blessing_levels.get(tier, 0)) - int(lock_levels.get(tier, 0)))

static func get_bound_skill_for_blessing(owner, blessing_id: String) -> String:
	var state: Dictionary = normalize_state(owner.blessing_skill_state if owner != null else {})
	return str((state.get("skill_blessing_bindings", {}) as Dictionary).get(blessing_id, ""))

static func get_skill_bound_blessing_level(owner, skill_id: String, blessing_id: String, tier: int = 0) -> int:
	if not _skill_can_read_blessing(skill_id, blessing_id):
		return 0
	var blessing_levels: Dictionary = _get_effective_skill_blessing_levels(owner, skill_id, blessing_id)
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
	return _build_tier_scales(owner, skill_id, "reprise", 0.5, 1.0)

static func get_skill_effect_scales(owner, skill_id: String, stat: String) -> Array[float]:
	match stat:
		"combo_skill_extra":
			if _skill_has_tag(skill_id, SKILL_TAG_COMBO):
				return _build_tier_scales(owner, skill_id, "reprise", 0.5, 1.0)
		"quantity_skill_count":
			if _skill_has_tag(skill_id, SKILL_TAG_QUANTITY):
				return _build_tier_scales(owner, skill_id, "trick", 0.5, 1.0)
	return []

static func get_duration_multiplier(owner, skill_id: String) -> float:
	if not _skill_has_tag(skill_id, SKILL_TAG_DURATION):
		return 1.0
	var blessing_levels: Dictionary = _get_effective_skill_blessing_levels(owner, skill_id, "tide_rain")
	return pow(1.12, float(blessing_levels.get(1, 0))) * pow(1.20, float(blessing_levels.get(2, 0)))

static func get_basic_attack_range_multiplier(owner, skill_id: String) -> float:
	var tier := get_skill_tier(owner, skill_id)
	if skill_id == SKILL_SWORDSMAN_BASIC_ATTACK:
		if tier >= 3:
			return 1.41
		if tier >= 2:
			return 1.3
		return 1.2
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
	return _build_tier_scales(owner, skill_id, "trick", 0.5, 1.0)

static func _can_read_blessing_for_skill(_owner, skill_id: String, blessing_id: String) -> bool:
	return _skill_can_read_blessing(skill_id, blessing_id)

static func _skill_can_read_blessing(skill_id: String, blessing_id: String) -> bool:
	if SHARED_ENTRY_SKILL_IDS.has(skill_id):
		return true
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

static func _build_tier_scales(owner, skill_id: String, blessing_id: String, tier_one_scale: float, tier_two_scale: float) -> Array[float]:
	var blessing_levels: Dictionary = _get_effective_skill_blessing_levels(owner, skill_id, blessing_id)
	var result: Array[float] = []
	for _index in range(max(0, int(blessing_levels.get(1, 0)))):
		result.append(tier_one_scale)
	for _index in range(max(0, int(blessing_levels.get(2, 0)))):
		result.append(tier_two_scale)
	return result

static func _get_effective_skill_blessing_levels(owner, skill_id: String, blessing_id: String) -> Dictionary:
	var result: Dictionary = {}
	if owner == null or not owner.has_method("get_skill_blessing_levels"):
		return result
	var levels: Dictionary = owner.get_skill_blessing_levels()
	var blessing_levels: Dictionary = levels.get(blessing_id, {})
	if INHERENT_SKILL_IDS.has(skill_id):
		return blessing_levels.duplicate(true)
	var baseline_levels: Dictionary = _get_skill_blessing_baseline(owner, skill_id, blessing_id)
	for tier in [1, 2]:
		var amount: int = max(0, int(blessing_levels.get(tier, 0)) - int(baseline_levels.get(tier, 0)))
		if amount > 0:
			result[tier] = amount
	var bonus_credit_levels: Dictionary = _get_skill_blessing_bonus_credit(owner, skill_id, blessing_id)
	for tier in [1, 2]:
		var credit_amount: int = int(bonus_credit_levels.get(tier, 0))
		if credit_amount > 0:
			result[tier] = int(result.get(tier, 0)) + credit_amount
	return result

static func _get_skill_blessing_baseline(owner, skill_id: String, blessing_id: String) -> Dictionary:
	if owner == null or skill_id == "":
		return {}
	var state: Dictionary = normalize_state(owner.blessing_skill_state)
	var skill_baselines: Dictionary = (state.get("skill_blessing_baselines", {}) as Dictionary).get(skill_id, {})
	return (skill_baselines.get(blessing_id, {}) as Dictionary).duplicate(true)


static func _get_skill_blessing_bonus_credit(owner, skill_id: String, blessing_id: String) -> Dictionary:
	if owner == null or skill_id == "":
		return {}
	var state: Dictionary = normalize_state(owner.blessing_skill_state)
	var skill_credits: Dictionary = (state.get("skill_blessing_bonus_credits", {}) as Dictionary).get(skill_id, {})
	return (skill_credits.get(blessing_id, {}) as Dictionary).duplicate(true)

static func _snapshot_skill_blessing_baseline(owner, skill_id: String, tiers: Array) -> void:
	if owner == null or not owner.has_method("get_skill_blessing_levels") or skill_id == "":
		return
	var state: Dictionary = normalize_state(owner.blessing_skill_state)
	var levels: Dictionary = owner.get_skill_blessing_levels()
	var baselines: Dictionary = (state.get("skill_blessing_baselines", {}) as Dictionary).duplicate(true)
	var skill_baselines: Dictionary = (baselines.get(skill_id, {}) as Dictionary).duplicate(true)
	for blessing_id_value in levels.keys():
		var blessing_id := str(blessing_id_value)
		if not _skill_can_read_blessing(skill_id, blessing_id):
			continue
		var source_levels: Dictionary = levels.get(blessing_id_value, {})
		var baseline_levels: Dictionary = (skill_baselines.get(blessing_id, {}) as Dictionary).duplicate(true)
		for tier_value in tiers:
			var tier := int(tier_value)
			var amount := int(source_levels.get(tier, 0))
			if amount > 0:
				baseline_levels[tier] = max(int(baseline_levels.get(tier, 0)), amount)
		if not baseline_levels.is_empty():
			skill_baselines[blessing_id] = baseline_levels
	if not skill_baselines.is_empty():
		baselines[skill_id] = skill_baselines
	state["skill_blessing_baselines"] = baselines
	owner.blessing_skill_state = state


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


static func get_entry_rescue_regen_per_second(owner) -> float:
	match get_skill_tier(owner, SKILL_ENTRY_RESCUE):
		1:
			return 0.525
		2:
			return 0.975
		3:
			return 1.5
	return 0.0


static func get_hero_entry_effect(owner) -> Dictionary:
	match get_skill_tier(owner, SKILL_HERO_ENTRY):
		1:
			return {"extra_count": 1, "effect_scale": 0.2}
		2:
			return {"extra_count": 1, "effect_scale": 0.5}
		3:
			return {"extra_count": 2, "effect_scale": 0.8}
	return {"extra_count": 0, "effect_scale": 0.0}

static func _can_apply_recipe(owner, skill_id: String, recipe: Dictionary, role_context: String = "") -> bool:
	if bool(recipe.get("always", false)):
		return true
	if not _skill_matches_role_context(skill_id, _resolve_role_context(owner, role_context)):
		return false
	var subtract_locks := not INHERENT_SKILL_IDS.has(skill_id) and not SHARED_ENTRY_SKILL_IDS.has(skill_id)
	var role_requirements: Dictionary = recipe.get("role", {})
	for blessing_id in role_requirements.keys():
		if not _meets_role_requirement(owner, skill_id, str(blessing_id), role_requirements.get(blessing_id, 0), subtract_locks):
			return false
	var skill_requirements: Dictionary = recipe.get("skill", {})
	for blessing_id in skill_requirements.keys():
		if not _skill_can_read_blessing(skill_id, str(blessing_id)):
			return false
		if not _meets_skill_requirement(owner, str(blessing_id), skill_requirements.get(blessing_id, 0), subtract_locks):
			return false
	var exact_role_requirements: Dictionary = recipe.get("role_exact", {})
	for blessing_id in exact_role_requirements.keys():
		if not _meets_exact_role_requirement(owner, skill_id, str(blessing_id), exact_role_requirements.get(blessing_id, {}), subtract_locks):
			return false
	var exact_skill_requirements: Dictionary = recipe.get("skill_exact", {})
	for blessing_id in exact_skill_requirements.keys():
		if not _skill_can_read_blessing(skill_id, str(blessing_id)):
			return false
		if not _meets_exact_skill_requirement(owner, str(blessing_id), exact_skill_requirements.get(blessing_id, {}), subtract_locks):
			return false
	return true

static func _resolve_role_context(owner, role_context: String) -> String:
	if role_context != "":
		return role_context
	if owner != null and owner.has_method("_get_active_role"):
		return str(owner._get_active_role().get("id", ""))
	return ""

static func _skill_matches_role_context(skill_id: String, role_context: String) -> bool:
	if role_context == "":
		return true
	var skill_role_id := get_skill_role_id(skill_id)
	return skill_role_id == "" or skill_role_id == role_context

static func _skill_matches_active_role(owner, skill_id: String) -> bool:
	if owner == null or not owner.has_method("_get_active_role"):
		return true
	var skill_role_id := get_skill_role_id(skill_id)
	if skill_role_id == "":
		return true
	return str(owner._get_active_role().get("id", "")) == skill_role_id

static func _recipe_uses_blessing_tier(recipe: Dictionary, binding: String, blessing_id: String, tier: int) -> bool:
	if recipe.is_empty() or blessing_id == "":
		return false
	var equivalent_key := "skill" if binding == SKILL_BOUND else "role"
	var exact_key := "skill_exact" if binding == SKILL_BOUND else "role_exact"
	var equivalent_requirements: Dictionary = recipe.get(equivalent_key, {})
	if equivalent_requirements.has(blessing_id):
		return true
	var exact_requirements: Dictionary = recipe.get(exact_key, {})
	if exact_requirements.has(blessing_id):
		var tier_requirements: Dictionary = exact_requirements.get(blessing_id, {})
		if int(tier_requirements.get(tier, 0)) > 0:
			return true
		if tier >= 2 and int(tier_requirements.get(1, 0)) > 0:
			return true
	return false

static func _bind_recipe_skill_blessings(owner, _skill_id: String, _recipe: Dictionary) -> void:
	owner.blessing_skill_state = normalize_state(owner.blessing_skill_state)

static func _lock_recipe_requirements(owner, skill_id: String, recipe: Dictionary) -> void:
	if owner == null or bool(recipe.get("always", false)):
		return
	var state: Dictionary = normalize_state(owner.blessing_skill_state)
	var role_locks: Dictionary = (state.get("role_recipe_locks", {}) as Dictionary).duplicate(true)
	var skill_locks: Dictionary = (state.get("skill_recipe_locks", {}) as Dictionary).duplicate(true)
	var bonus_credits: Dictionary = (state.get("skill_blessing_bonus_credits", {}) as Dictionary).duplicate(true)
	var skill_bonus_credits: Dictionary = (bonus_credits.get(skill_id, {}) as Dictionary).duplicate(true)
	_add_equivalent_requirement_locks(owner, skill_id, role_locks, "role", recipe.get("role", {}))
	_add_equivalent_requirement_locks(owner, skill_id, skill_locks, "skill", recipe.get("skill", {}))
	_add_exact_requirement_locks(owner, skill_id, role_locks, "role", recipe.get("role_exact", {}), skill_bonus_credits)
	_add_exact_requirement_locks(owner, skill_id, skill_locks, "skill", recipe.get("skill_exact", {}), skill_bonus_credits)
	if not skill_bonus_credits.is_empty():
		bonus_credits[skill_id] = skill_bonus_credits
		state["skill_blessing_bonus_credits"] = bonus_credits
	state["role_recipe_locks"] = role_locks
	state["skill_recipe_locks"] = skill_locks
	owner.blessing_skill_state = state

static func _add_equivalent_requirement_locks(owner, skill_id: String, target_locks: Dictionary, source_kind: String, requirements: Variant) -> void:
	if requirements is not Dictionary:
		return
	for blessing_id_value in (requirements as Dictionary).keys():
		var blessing_id := str(blessing_id_value)
		var required_count: int = max(0, int((requirements as Dictionary).get(blessing_id_value, 0)))
		if required_count <= 0:
			continue
		var available_levels: Dictionary = _get_available_recipe_levels(owner, skill_id, target_locks, source_kind, blessing_id)
		var allocated_levels: Dictionary = _allocate_equivalent_requirement(available_levels, required_count)
		var lock_levels: Dictionary = (target_locks.get(blessing_id, {}) as Dictionary).duplicate(true)
		for tier_value in allocated_levels.keys():
			var tier: int = int(tier_value)
			lock_levels[tier] = int(lock_levels.get(tier, 0)) + int(allocated_levels.get(tier_value, 0))
		target_locks[blessing_id] = lock_levels

static func _add_exact_requirement_locks(owner, skill_id: String, target_locks: Dictionary, source_kind: String, requirements: Variant, skill_bonus_credits: Dictionary) -> void:
	if requirements is not Dictionary:
		return
	for blessing_id_value in (requirements as Dictionary).keys():
		var blessing_id := str(blessing_id_value)
		var tier_requirements: Variant = (requirements as Dictionary).get(blessing_id_value, {})
		if tier_requirements is not Dictionary:
			continue
		var lock_levels: Dictionary = (target_locks.get(blessing_id, {}) as Dictionary).duplicate(true)
		for tier_value in (tier_requirements as Dictionary).keys():
			var tier := int(tier_value)
			var required_count: int = max(0, int((tier_requirements as Dictionary).get(tier_value, 0)))
			if tier < 1 or tier > 2 or required_count <= 0:
				continue
			if tier <= 1:
				var available_levels: Dictionary = _get_available_recipe_levels(owner, skill_id, target_locks, source_kind, blessing_id)
				var allocated_levels: Dictionary = _allocate_equivalent_requirement(available_levels, required_count)
				for allocated_tier_value in allocated_levels.keys():
					var allocated_tier: int = int(allocated_tier_value)
					var allocated_count: int = int(allocated_levels.get(allocated_tier_value, 0))
					lock_levels[allocated_tier] = int(lock_levels.get(allocated_tier, 0)) + allocated_count
					if allocated_tier >= 2:
						_add_skill_bonus_credit_from_tier_two_exact_requirement(owner, skill_id, blessing_id, allocated_count, required_count, skill_bonus_credits)
			else:
				var available_levels: Dictionary = _get_available_recipe_levels(owner, skill_id, target_locks, source_kind, blessing_id)
				var tier_two_count: int = min(int(available_levels.get(2, 0)), required_count)
				if tier_two_count > 0:
					lock_levels[tier] = int(lock_levels.get(tier, 0)) + tier_two_count
		if not lock_levels.is_empty():
			target_locks[blessing_id] = lock_levels

static func _get_available_recipe_levels(owner, skill_id: String, current_locks: Dictionary, source_kind: String, blessing_id: String) -> Dictionary:
	var levels: Dictionary = {}
	if source_kind == "role":
		var role_id := str(get_skill_role_id(skill_id))
		if owner != null and owner.has_method("_get_active_role"):
			if role_id == "":
				role_id = str(owner._get_active_role().get("id", ""))
		levels = owner.get_role_blessing_levels(role_id) if owner != null and owner.has_method("get_role_blessing_levels") else {}
	else:
		levels = owner.get_skill_blessing_levels() if owner != null and owner.has_method("get_skill_blessing_levels") else {}
	var blessing_levels: Dictionary = (levels.get(blessing_id, {}) as Dictionary).duplicate(true)
	var lock_levels: Dictionary = current_locks.get(blessing_id, {})
	for tier_value in lock_levels.keys():
		var tier: int = int(tier_value)
		var amount: int = max(0, int(blessing_levels.get(tier, 0)) - int(lock_levels.get(tier_value, 0)))
		if amount > 0:
			blessing_levels[tier] = amount
		else:
			blessing_levels.erase(tier)
	return blessing_levels

static func _allocate_equivalent_requirement(available_levels: Dictionary, required_equivalent_count: int) -> Dictionary:
	var remaining: int = max(0, required_equivalent_count)
	var allocation: Dictionary = {}
	var tier_one_count: int = min(int(available_levels.get(1, 0)), remaining)
	if tier_one_count > 0:
		allocation[1] = tier_one_count
		remaining -= tier_one_count
	if remaining > 0:
		var tier_two_needed: int = int(ceil(float(remaining) / float(TIER_TWO_EQUIVALENT_COUNT)))
		var tier_two_count: int = min(int(available_levels.get(2, 0)), tier_two_needed)
		if tier_two_count > 0:
			allocation[2] = tier_two_count
	return allocation


static func _add_skill_bonus_credit_from_tier_two_exact_requirement(owner, skill_id: String, blessing_id: String, tier_two_count: int, required_tier_one_count: int, skill_bonus_credits: Dictionary) -> void:
	if tier_two_count <= 0 or required_tier_one_count != 1:
		return
	if not _skill_can_read_blessing(skill_id, blessing_id):
		return
	var credit_levels: Dictionary = (skill_bonus_credits.get(blessing_id, {}) as Dictionary).duplicate(true)
	credit_levels[2] = int(credit_levels.get(2, 0)) + tier_two_count * (TIER_TWO_EQUIVALENT_COUNT - 1)
	skill_bonus_credits[blessing_id] = credit_levels

static func _get_recipe_locks(owner, key: String) -> Dictionary:
	if owner == null:
		return {}
	var state: Dictionary = normalize_state(owner.blessing_skill_state)
	return (state.get(key, {}) as Dictionary).duplicate(true)

static func _subtract_level_locks(levels: Dictionary, locks: Dictionary) -> Dictionary:
	var result: Dictionary = levels.duplicate(true)
	for blessing_id_value in locks.keys():
		var blessing_id := str(blessing_id_value)
		var source_levels: Dictionary = (result.get(blessing_id, {}) as Dictionary).duplicate(true)
		var lock_levels: Dictionary = locks.get(blessing_id_value, {})
		for tier_value in lock_levels.keys():
			var tier := int(tier_value)
			var amount: int = max(0, int(source_levels.get(tier, 0)) - int(lock_levels.get(tier_value, 0)))
			if amount > 0:
				source_levels[tier] = amount
			else:
				source_levels.erase(tier)
		if source_levels.is_empty():
			result.erase(blessing_id)
		else:
			result[blessing_id] = source_levels
	return result

static func _meets_role_requirement(owner, skill_id: String, blessing_id: String, requirement: Variant, subtract_locks: bool = false) -> bool:
	var role_id := str(get_skill_role_id(skill_id))
	if role_id == "" and owner != null and owner.has_method("_get_active_role"):
		role_id = str(owner._get_active_role().get("id", ""))
	var levels: Dictionary = owner.get_role_blessing_levels(role_id) if owner != null and owner.has_method("get_role_blessing_levels") else {}
	if subtract_locks:
		levels = _subtract_level_locks(levels, _get_recipe_locks(owner, "role_recipe_locks"))
	return _meets_level_requirement(levels.get(blessing_id, {}), requirement)

static func _meets_skill_requirement(owner, blessing_id: String, requirement: Variant, subtract_locks: bool = false) -> bool:
	var levels: Dictionary = owner.get_skill_blessing_levels() if owner != null and owner.has_method("get_skill_blessing_levels") else {}
	if subtract_locks:
		levels = _subtract_level_locks(levels, _get_recipe_locks(owner, "skill_recipe_locks"))
	return _meets_level_requirement(levels.get(blessing_id, {}), requirement)

static func _meets_exact_role_requirement(owner, skill_id: String, blessing_id: String, requirement: Variant, subtract_locks: bool = false) -> bool:
	var role_id := str(get_skill_role_id(skill_id))
	if role_id == "" and owner != null and owner.has_method("_get_active_role"):
		role_id = str(owner._get_active_role().get("id", ""))
	var levels: Dictionary = owner.get_role_blessing_levels(role_id) if owner != null and owner.has_method("get_role_blessing_levels") else {}
	if subtract_locks:
		levels = _subtract_level_locks(levels, _get_recipe_locks(owner, "role_recipe_locks"))
	return _meets_exact_tier_requirement(levels.get(blessing_id, {}), requirement)

static func _meets_exact_skill_requirement(owner, blessing_id: String, requirement: Variant, subtract_locks: bool = false) -> bool:
	var levels: Dictionary = owner.get_skill_blessing_levels() if owner != null and owner.has_method("get_skill_blessing_levels") else {}
	if subtract_locks:
		levels = _subtract_level_locks(levels, _get_recipe_locks(owner, "skill_recipe_locks"))
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

static func _build_recipe_progress(owner, skill_id: String, recipe: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if recipe.is_empty() or bool(recipe.get("always", false)):
		return result
	_append_equivalent_recipe_progress(result, owner, skill_id, recipe.get("role", {}), ROLE_BOUND)
	_append_equivalent_recipe_progress(result, owner, skill_id, recipe.get("skill", {}), SKILL_BOUND)
	_append_exact_recipe_progress(result, owner, skill_id, recipe.get("role_exact", {}), ROLE_BOUND)
	_append_exact_recipe_progress(result, owner, skill_id, recipe.get("skill_exact", {}), SKILL_BOUND)
	return result

static func _build_skill_enhancement_progress(owner, skill_id: String) -> Array[String]:
	var result: Array[String] = []
	if _skill_has_tag(skill_id, SKILL_TAG_DURATION):
		var duration_multiplier := get_duration_multiplier(owner, skill_id)
		var levels: Dictionary = _get_effective_skill_blessing_levels(owner, skill_id, "tide_rain")
		result.append("%s：持续时间 x%.2f（当前强化 %s）" % [
			_get_blessing_title("tide_rain"),
			duration_multiplier,
			_format_skill_enhancement_levels(levels)
		])
	if _skill_has_tag(skill_id, SKILL_TAG_COMBO):
		var combo_scales := get_combo_extra_scales(owner, skill_id)
		var levels: Dictionary = _get_effective_skill_blessing_levels(owner, skill_id, "reprise")
		result.append("%s：额外连段 %d 次（当前强化 %s）" % [
			_get_blessing_title("reprise"),
			combo_scales.size(),
			_format_skill_enhancement_levels(levels)
		])
	if _skill_has_tag(skill_id, SKILL_TAG_QUANTITY):
		var quantity_count := get_quantity_extra_count(owner, skill_id)
		var levels: Dictionary = _get_effective_skill_blessing_levels(owner, skill_id, "trick")
		result.append("%s：额外数量 %d（当前强化 %s）" % [
			_get_blessing_title("trick"),
			quantity_count,
			_format_skill_enhancement_levels(levels)
		])
	return result

static func _append_equivalent_recipe_progress(result: Array[String], owner, skill_id: String, requirements: Variant, binding: String) -> void:
	if requirements is not Dictionary:
		return
	for blessing_id_value in (requirements as Dictionary).keys():
		var blessing_id := str(blessing_id_value)
		var required_count: int = max(0, int((requirements as Dictionary).get(blessing_id_value, 0)))
		if required_count <= 0:
			continue
		var available_levels: Dictionary = _get_available_progress_levels(owner, skill_id, binding, blessing_id)
		var owned_equivalent: int = _get_equivalent_count(available_levels)
		result.append("%s：%s %d/%d" % [
			_get_binding_label(binding),
			_get_blessing_title(blessing_id),
			min(owned_equivalent, required_count),
			required_count
		])

static func _append_exact_recipe_progress(result: Array[String], owner, skill_id: String, requirements: Variant, binding: String) -> void:
	if requirements is not Dictionary:
		return
	for blessing_id_value in (requirements as Dictionary).keys():
		var blessing_id := str(blessing_id_value)
		var tier_requirements: Variant = (requirements as Dictionary).get(blessing_id_value, {})
		if tier_requirements is not Dictionary:
			continue
		var available_levels: Dictionary = _get_available_progress_levels(owner, skill_id, binding, blessing_id)
		for tier_value in (tier_requirements as Dictionary).keys():
			var tier: int = int(tier_value)
			var required_count: int = max(0, int((tier_requirements as Dictionary).get(tier_value, 0)))
			if required_count <= 0:
				continue
			var owned_count: int = int(available_levels.get(tier, 0))
			if tier <= 1 and owned_count < required_count:
				owned_count += int(available_levels.get(2, 0)) * TIER_TWO_EQUIVALENT_COUNT
			result.append("%s：%s%s %d/%d" % [
				_get_binding_label(binding),
				_get_blessing_title(blessing_id),
				_get_graph_blessing_tier_label(tier),
				min(owned_count, required_count),
				required_count
			])

static func _get_available_progress_levels(owner, skill_id: String, binding: String, blessing_id: String) -> Dictionary:
	var levels: Dictionary = {}
	var lock_key := "skill_recipe_locks" if binding == SKILL_BOUND else "role_recipe_locks"
	if binding == SKILL_BOUND:
		levels = owner.get_skill_blessing_levels() if owner != null and owner.has_method("get_skill_blessing_levels") else {}
	else:
		var role_id := str(get_skill_role_id(skill_id))
		if owner != null and owner.has_method("_get_active_role"):
			if role_id == "":
				role_id = str(owner._get_active_role().get("id", ""))
		levels = owner.get_role_blessing_levels(role_id) if owner != null and owner.has_method("get_role_blessing_levels") else {}
	return _subtract_level_locks(levels, _get_recipe_locks(owner, lock_key)).get(blessing_id, {})

static func _get_skill_tag_labels(skill_id: String) -> String:
	var labels: Array[String] = []
	if _skill_has_tag(skill_id, SKILL_TAG_DURATION):
		labels.append("持续")
	if _skill_has_tag(skill_id, SKILL_TAG_COMBO):
		labels.append("连段")
	if _skill_has_tag(skill_id, SKILL_TAG_QUANTITY):
		labels.append("数量")
	return " / ".join(labels)

static func _get_binding_label(binding: String) -> String:
	return "技能材料" if binding == SKILL_BOUND else "角色材料"

static func _get_blessing_title(blessing_id: String) -> String:
	return str(BLESSING_TITLES.get(blessing_id, blessing_id))

static func _get_graph_blessing_tier_label(tier: int) -> String:
	return "II" if tier >= 2 else "I"

static func _format_skill_enhancement_levels(levels: Dictionary) -> String:
	var parts: Array[String] = []
	var tier_one_count := int(levels.get(1, 0))
	var tier_two_count := int(levels.get(2, 0))
	if tier_one_count > 0:
		parts.append("I x%d" % tier_one_count)
	if tier_two_count > 0:
		parts.append("II x%d" % tier_two_count)
	if parts.is_empty():
		return "未绑定新增祝福"
	return "，".join(parts)

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
	for skill_id_value in _get_recipe_skill_ids():
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
