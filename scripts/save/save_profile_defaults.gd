extends RefCounted

const STORY_DATA := preload("res://scripts/story_data.gd")
const DIFFICULTY_PROFILE := preload("res://scripts/game/difficulty_profile.gd")

const MODE_STORY := "story"
const MODE_ENDLESS := "endless"
const DEFAULT_ROLE_IDS := ["swordsman", "gunner", "mage"]

static func ensure_story_profile_defaults(profile: Dictionary, slot_id: int) -> Dictionary:
	var normalized := STORY_DATA.build_default_story_profile(slot_id)
	for key in profile.keys():
		normalized[key] = profile[key]
	if not normalized.has("unlocked_styles") or not (normalized["unlocked_styles"] is Dictionary):
		normalized["unlocked_styles"] = {}
	if not normalized.has("equipped_styles") or not (normalized["equipped_styles"] is Dictionary):
		normalized["equipped_styles"] = {}
	if not normalized.has("team_order") or not (normalized["team_order"] is Array):
		normalized["team_order"] = DEFAULT_ROLE_IDS.duplicate()
	if not normalized.has("unlocked_role_ids") or not (normalized["unlocked_role_ids"] is Array):
		normalized["unlocked_role_ids"] = DEFAULT_ROLE_IDS.duplicate()
	for role_id in DEFAULT_ROLE_IDS:
		if not normalized["unlocked_styles"].has(role_id):
			normalized["unlocked_styles"][role_id] = []
		if not normalized["equipped_styles"].has(role_id):
			normalized["equipped_styles"][role_id] = "default"
	normalized["team_order"] = _normalize_team_order(normalized["team_order"])
	normalized["slot_id"] = slot_id
	normalized["mode"] = MODE_STORY
	normalized["last_updated_unix"] = Time.get_unix_time_from_system()
	return normalized

static func build_default_endless_profile(slot_id: int, difficulty: String) -> Dictionary:
	var normalized_difficulty := DIFFICULTY_PROFILE.normalize_id(difficulty)
	return {
		"slot_id": slot_id,
		"mode": MODE_ENDLESS,
		"difficulty": normalized_difficulty,
		"created_unix": Time.get_unix_time_from_system(),
		"last_updated_unix": Time.get_unix_time_from_system()
	}

static func ensure_endless_profile_defaults(profile: Dictionary, slot_id: int) -> Dictionary:
	var normalized := build_default_endless_profile(slot_id, str(profile.get("difficulty", "normal")))
	for key in profile.keys():
		normalized[key] = profile[key]
	normalized["slot_id"] = slot_id
	normalized["mode"] = MODE_ENDLESS
	normalized["difficulty"] = DIFFICULTY_PROFILE.normalize_id(str(normalized.get("difficulty", DIFFICULTY_PROFILE.DEFAULT_DIFFICULTY_ID)))
	normalized["last_updated_unix"] = Time.get_unix_time_from_system()
	return normalized

static func _normalize_team_order(team_order: Array) -> Array:
	var ordered_roles: Array = []
	for role_variant in team_order:
		var role_id := str(role_variant)
		if role_id in DEFAULT_ROLE_IDS and not ordered_roles.has(role_id):
			ordered_roles.append(role_id)
	for fallback_role in DEFAULT_ROLE_IDS:
		if not ordered_roles.has(fallback_role):
			ordered_roles.append(fallback_role)
	return ordered_roles
