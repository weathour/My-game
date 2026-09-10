extends RefCounted

const STORY_DATA := preload("res://scripts/story_data.gd")
const RUAN_STONE_SYSTEM := preload("res://scripts/player/ruan_stone_system.gd")
const ROLE_DATABASE := preload("res://scripts/player/roles/role_database.gd")

const MODE_STORY := "story"
const MODE_ENDLESS := "endless"
const DEFAULT_ROLE_IDS := ["swordsman", "gunner", "mage", "mechanic"]
const STORY_PROFILE_COPY_KEYS := [
	"chapter_index",
	"current_stage_index",
	"boss_core_fragments",
	"unlocked_role_ids",
	"team_order",
	"created_unix"
]

static func ensure_story_profile_defaults(profile: Dictionary, slot_id: int) -> Dictionary:
	var normalized := STORY_DATA.build_default_story_profile(slot_id)
	for key in STORY_PROFILE_COPY_KEYS:
		if profile.has(key):
			normalized[key] = profile[key]
	if not normalized.has("team_order") or not (normalized["team_order"] is Array):
		normalized["team_order"] = ROLE_DATABASE.DEFAULT_TEAM_IDS.duplicate()
	if not normalized.has("unlocked_role_ids") or not (normalized["unlocked_role_ids"] is Array):
		normalized["unlocked_role_ids"] = DEFAULT_ROLE_IDS.duplicate()
	normalized["team_order"] = _normalize_team_order(normalized["team_order"], normalized["unlocked_role_ids"])
	normalized["slot_id"] = slot_id
	normalized["mode"] = MODE_STORY
	normalized["last_updated_unix"] = Time.get_unix_time_from_system()
	return normalized

static func build_default_endless_profile(slot_id: int) -> Dictionary:
	return RUAN_STONE_SYSTEM.normalize_profile({
		"slot_id": slot_id,
		"mode": MODE_ENDLESS,
		"highest_cleared_tier": 0,
		"selected_tier": 1,
		"last_rewarded_run_id": "",
		"created_unix": Time.get_unix_time_from_system(),
		"last_updated_unix": Time.get_unix_time_from_system()
	})

static func ensure_endless_profile_defaults(profile: Dictionary, slot_id: int) -> Dictionary:
	var normalized := build_default_endless_profile(slot_id)
	for key in profile.keys():
		normalized[key] = profile[key]
	normalized["slot_id"] = slot_id
	normalized["mode"] = MODE_ENDLESS
	normalized.erase("difficulty")
	normalized["highest_cleared_tier"] = max(0, int(normalized.get("highest_cleared_tier", 0)))
	normalized["selected_tier"] = clampi(
		max(1, int(normalized.get("selected_tier", 1))),
		1,
		int(normalized["highest_cleared_tier"]) + 1
	)
	normalized["last_rewarded_run_id"] = str(normalized.get("last_rewarded_run_id", ""))
	var endless_team: Variant = normalized.get("team_order", ROLE_DATABASE.DEFAULT_TEAM_IDS.duplicate())
	if not (endless_team is Array):
		endless_team = ROLE_DATABASE.DEFAULT_TEAM_IDS.duplicate()
	normalized["team_order"] = _normalize_team_order(endless_team, DEFAULT_ROLE_IDS)
	normalized["last_updated_unix"] = Time.get_unix_time_from_system()
	return RUAN_STONE_SYSTEM.normalize_profile(normalized)

static func _normalize_team_order(team_order: Array, unlocked_ids: Array = []) -> Array:
	var allowed_ids: Array = []
	for role_variant in unlocked_ids:
		var unlocked_id := str(role_variant)
		if unlocked_id in DEFAULT_ROLE_IDS and not allowed_ids.has(unlocked_id):
			allowed_ids.append(unlocked_id)
	if allowed_ids.is_empty():
		allowed_ids = DEFAULT_ROLE_IDS.duplicate()
	var team_size: int = ROLE_DATABASE.DEFAULT_TEAM_IDS.size()
	var ordered_roles: Array = []
	for role_variant in team_order:
		var role_id := str(role_variant)
		if role_id in allowed_ids and not ordered_roles.has(role_id):
			ordered_roles.append(role_id)
		if ordered_roles.size() >= team_size:
			break
	for fallback_role in ROLE_DATABASE.DEFAULT_TEAM_IDS:
		if ordered_roles.size() >= team_size:
			break
		if not ordered_roles.has(fallback_role):
			ordered_roles.append(fallback_role)
	return ordered_roles
