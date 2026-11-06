extends RefCounted
## Read-only audio binding; missing bindings remain observable rather than generic fallback.
const BANK_PATH := "res://assets/sfx/skill-combat-20261103/catalog.json"
const PROFILES_PATH := "res://assets/data/audio/skill_sound_profiles.json"
static var _bank := {}
static var _profiles := {}
static var _loaded := false

static func _load_data() -> void:
	if _loaded: return
	_loaded = true
	if FileAccess.file_exists(BANK_PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(BANK_PATH))
		if data is Dictionary: _bank = data.get("cues", {})
	if FileAccess.file_exists(PROFILES_PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILES_PATH))
		if data is Dictionary: _profiles = data

static func cue(id: String) -> Dictionary:
	_load_data()
	return _bank.get(id, {}).duplicate(true)

static func profiles() -> Dictionary:
	_load_data()
	return _profiles.duplicate(true)

static func character(owner: String, ability: String, kind: int = -1) -> Dictionary:
	_load_data()
	var row: Dictionary = _profiles.get("character_abilities", {}).get(owner, {}).get(ability, {})
	if row.is_empty():
		var alias: Variant = _profiles.get("ability_aliases", {}).get(ability, {})
		if alias is String: row = _profiles.get("character_abilities", {}).get(owner, {}).get(alias, {})
		elif alias is Dictionary:
			if alias.has("cast") or alias.has("impact"): row = alias
			else: row = _profiles.get("character_abilities", {}).get(str(alias.get("owner", owner)), {}).get(str(alias.get("ability", ability)), {})
	row = row.duplicate(true)
	var names := ["SWEEP", "THRUST", "PROJECTILE", "NOVA", "HEAL", "MANA", "WARD"]
	if kind >= 0 and kind < names.size(): row.merge(row.get("kind_overrides", {}).get(names[kind], {}), true)
	return row

static func enemy(definition: String, form: int, move: String) -> Dictionary:
	_load_data()
	var row: Dictionary=_profiles.get("enemy_actions", {}).get(definition, {}).get(str(form), {}).get(move, {})
	if row.is_empty(): row=_profiles.get("enemy_action_aliases",{}).get(move,{})
	return row.duplicate(true)

static func boss(definition: String, form: int, event: String) -> String:
	_load_data()
	return str(_profiles.get("boss_events", {}).get(definition, {}).get(str(form), {}).get(event, ""))

static func global_cue(event: String) -> String:
	_load_data()
	return str(_profiles.get("global_cues", {}).get(event, ""))

static func boss_profile(definition: String, form: int) -> Dictionary:
	_load_data()
	return _profiles.get("boss_events",{}).get(definition,{}).get(str(form),{}).duplicate(true)
