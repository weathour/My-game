extends RefCounted

const STORY_DATA := preload("res://scripts/story_data.gd")
const RUAN_STONE_SYSTEM := preload("res://scripts/player/ruan_stone_system.gd")
const ROLE_DATABASE := preload("res://scripts/player/roles/role_database.gd")
const STORY_STATE := preload("res://scripts/story/story_state.gd")

const MODE_STORY := "story"
const MODE_ENDLESS := "endless"
const DEFAULT_ROLE_IDS := ["swordsman", "gunner", "mage", "mechanic"]

static func ensure_story_profile_defaults(profile: Dictionary, slot_id: int) -> Dictionary:
	var normalized := STORY_DATA.build_default_story_profile(slot_id)
	normalized.merge(profile.duplicate(true), true)
	if not normalized.has("team_order") or not (normalized["team_order"] is Array):
		normalized["team_order"] = ROLE_DATABASE.DEFAULT_TEAM_IDS.duplicate()
	if not normalized.has("unlocked_role_ids") or not (normalized["unlocked_role_ids"] is Array):
		normalized["unlocked_role_ids"] = DEFAULT_ROLE_IDS.duplicate()
	normalized["team_order"] = _normalize_team_order(normalized["team_order"], normalized["unlocked_role_ids"])
	normalized["slot_id"] = slot_id
	normalized["mode"] = MODE_STORY
	normalized["last_updated_unix"] = Time.get_unix_time_from_system()
	return STORY_STATE.migrate(normalized)

static func profile_error(profile: Variant, slot_id: int, mode: String) -> String:
	if not profile is Dictionary or profile.is_empty():
		return "invalid_state"
	if profile.has("mode") and profile.mode != mode:
		return "invalid_state"
	if profile.has("slot_id") and (not STORY_STATE.whole_number(profile.slot_id, 1) or int(profile.slot_id) != slot_id):
		return "invalid_state"
	if mode == MODE_STORY:
		if not STORY_STATE.whole_number(profile.get("boss_core_fragments", 0)):
			return "invalid_state"
		return STORY_STATE.error(profile)
	if not profile.has("bones") or not STORY_STATE.whole_number(profile.bones):
		return "invalid_state"
	if profile.has("bone_pickup_receipts"):
		var receipts: Variant = profile.bone_pickup_receipts
		if not receipts is Dictionary or not receipts.get("run_id") is String or not receipts.get("ids") is Array:
			return "invalid_state"
		for id in receipts.ids:
			if not id is String or id == "":
				return "invalid_state"
	if not STORY_STATE.whole_number(profile.get("highest_cleared_tier", 0)) or not STORY_STATE.whole_number(profile.get("selected_tier", 1), 1):
		return "invalid_state"
	if int(profile.get("selected_tier", 1)) > int(profile.get("highest_cleared_tier", 0)) + 1:
		return "invalid_state"
	return ""

static func build_default_endless_profile(slot_id: int) -> Dictionary:
	return RUAN_STONE_SYSTEM.normalize_profile({
		"slot_id": slot_id,
		"mode": MODE_ENDLESS,
		"highest_cleared_tier": 0,
		"selected_tier": 1,
		"last_rewarded_run_id": "",
		"last_clear_summary": {},
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
	var last_clear: Variant = normalized.get("last_clear_summary", {})
	normalized["last_clear_summary"] = {}
	if last_clear is Dictionary and RUAN_STONE_SYSTEM._non_negative_int(last_clear.get("tier", 0)) > 0:
		normalized["last_clear_summary"] = {
			"tier": RUAN_STONE_SYSTEM._non_negative_int(last_clear["tier"]),
			"bones": RUAN_STONE_SYSTEM._non_negative_int(last_clear.get("bones", 0)),
			"first_clear": bool(last_clear.get("first_clear", false))
		}
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
