extends RefCounted

const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")


static func get_boss_options() -> Array:
	return ENEMY_ARCHETYPE_DATABASE.get_boss_options()

static func get_skill_options(player) -> Array:
	var options: Array = []
	for skill_id_value in PLAYER_BLESSING_SKILL_STATE.ACTIVE_SKILL_IDS:
		var skill_id := str(skill_id_value)
		var title := PLAYER_BLESSING_SKILL_STATE.get_skill_title(skill_id)
		var role_id := PLAYER_BLESSING_SKILL_STATE.get_skill_role_id(skill_id)
		var current_tier := PLAYER_BLESSING_SKILL_STATE.get_skill_tier(player, skill_id) if player != null else 0
		for tier in [1, 2]:
			options.append({
				"id": "%s:%d" % [skill_id, tier],
				"skill_id": skill_id,
				"tier": tier,
				"title": "%s %s" % [title, _get_tier_suffix(tier)],
				"description": "开发者模式：解锁或升到%s。归属角色：%s；当前阶级：%s。" % [_get_tier_suffix(tier), role_id, _get_tier_suffix(current_tier)],
				"enabled": true
			})
	return options

static func _get_tier_suffix(tier: int) -> String:
	match tier:
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
	return "-"
