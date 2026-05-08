extends RefCounted

const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")
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

static func get_blessing_options(player) -> Array:
	var options: Array = []
	for blessing_id_value in PLAYER_BLESSING_SYSTEM.DEFINITIONS.keys():
		var blessing_id := str(blessing_id_value)
		var definition: Dictionary = PLAYER_BLESSING_SYSTEM.DEFINITIONS.get(blessing_id, {})
		for tier in [1, 2]:
			var current_count: int = _get_blessing_count(player, blessing_id, tier, str(definition.get("binding", PLAYER_BLESSING_SYSTEM.ROLE_BOUND)))
			var max_count: int = PLAYER_BLESSING_SYSTEM.MAX_BLESSING_COUNT_PER_TIER
			options.append({
				"id": "%s:%d" % [blessing_id, tier],
				"blessing_id": blessing_id,
				"tier": tier,
				"title": "%s %s  %d/%d" % [str(definition.get("title", blessing_id)), _get_tier_suffix(tier), current_count, max_count],
				"description": "开发者模式：直接获得一次该祝福。\n%s\n绑定：%s\n当前：%d/%d" % [
					str(definition.get("description", "")),
					"技能" if str(definition.get("binding", PLAYER_BLESSING_SYSTEM.ROLE_BOUND)) == PLAYER_BLESSING_SYSTEM.SKILL_BOUND else "三人共享角色数值",
					current_count,
					max_count
				],
				"enabled": current_count < max_count
			})
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_tier := int(a.get("tier", 1))
		var b_tier := int(b.get("tier", 1))
		if a_tier != b_tier:
			return a_tier < b_tier
		return str(a.get("title", "")) < str(b.get("title", ""))
	)
	return options

static func _get_blessing_count(player, blessing_id: String, tier: int, binding: String) -> int:
	if player == null:
		return 0
	return PLAYER_BLESSING_SKILL_STATE.get_available_blessing_count(player, binding, blessing_id, tier)

static func _get_tier_suffix(tier: int) -> String:
	match tier:
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
	return "-"
