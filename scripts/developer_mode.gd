extends RefCounted

class_name DeveloperMode

const FULL_XP_GEM_INTERVAL := 1.0
const FULL_XP_GEM_MIN_RADIUS := 72.0
const FULL_XP_GEM_MAX_RADIUS := 128.0

static var enabled: bool = false
static var ignore_damage_enabled: bool = false
static var no_cooldown_enabled: bool = false

static func activate() -> void:
	enabled = true
	ignore_damage_enabled = true
	no_cooldown_enabled = false

static func deactivate() -> void:
	enabled = false
	ignore_damage_enabled = false
	no_cooldown_enabled = false

static func is_enabled() -> bool:
	return enabled

static func should_spawn_only_bosses() -> bool:
	return enabled

static func should_ignore_damage() -> bool:
	return enabled and ignore_damage_enabled

static func set_ignore_damage_enabled(value: bool) -> void:
	ignore_damage_enabled = enabled and value

static func is_ignore_damage_enabled() -> bool:
	return enabled and ignore_damage_enabled

static func should_ignore_cooldowns() -> bool:
	return enabled and no_cooldown_enabled

static func set_no_cooldown_enabled(value: bool) -> void:
	no_cooldown_enabled = enabled and value

static func is_no_cooldown_enabled() -> bool:
	return enabled and no_cooldown_enabled

static func should_offer_all_blessings() -> bool:
	return enabled

static func should_disable_save() -> bool:
	return enabled

static func should_unlock_ultimate_freely() -> bool:
	return should_ignore_cooldowns()

static func get_full_exp_value(player: Node) -> int:
	if player == null:
		return 0
	var required_experience := int(player.get("experience_to_next_level"))
	var current_experience := int(player.get("experience"))
	return max(1, required_experience - current_experience)
