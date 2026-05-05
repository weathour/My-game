extends RefCounted

const DEFAULT_DIFFICULTY_ID := "normal"
const DIFFICULTY_ORDER := ["easy", "normal", "hard", "hell"]

const PROFILES := {
	"easy": {
		"id": "easy",
		"label": "简单",
		"available": true,
		"description": "学习和试卡难度：敌人更慢、更脆，危险组合更少。",
		"risk_band": [0.35, 0.50],
		"spawn_interval_scale": 1.12,
		"minimum_spawn_interval_scale": 1.08,
		"enemy_health_scale": 0.85,
		"special_health_scale": 0.90,
		"boss_health_scale": 0.90,
		"enemy_damage_scale": 0.80,
		"enemy_speed_scale": 0.95,
		"dangerous_weight_scale": 0.85,
		"ranged_weight_scale": 0.86,
		"burst_weight_scale": 0.84,
		"density_pack_scale": 0.92,
		"special_attack_interval_scale": 1.12,
		"special_projectile_count_scale": 0.88,
		"boss_attack_pressure_scale": 0.90,
		"recovery_margin_scale": 1.15,
		"active_enemy_limit": 260,
		"enemy_projectile_limit": 180,
		"temporary_effect_limit": 260,
		"autosave_interval": 3.0
	},
	"normal": {
		"id": "normal",
		"label": "普通",
		"available": true,
		"description": "标准幸存者割草体验，作为祝福和敌人压力的基准盘。",
		"risk_band": [0.50, 0.63],
		"spawn_interval_scale": 1.00,
		"minimum_spawn_interval_scale": 1.00,
		"enemy_health_scale": 1.00,
		"special_health_scale": 1.00,
		"boss_health_scale": 1.00,
		"enemy_damage_scale": 1.00,
		"enemy_speed_scale": 1.00,
		"dangerous_weight_scale": 1.00,
		"ranged_weight_scale": 1.00,
		"burst_weight_scale": 1.00,
		"density_pack_scale": 1.00,
		"special_attack_interval_scale": 1.00,
		"special_projectile_count_scale": 1.00,
		"boss_attack_pressure_scale": 1.00,
		"recovery_margin_scale": 1.00,
		"active_enemy_limit": 320,
		"enemy_projectile_limit": 240,
		"temporary_effect_limit": 340,
		"autosave_interval": 3.0
	},
	"hard": {
		"id": "hard",
		"label": "困难",
		"available": true,
		"description": "要求主轴更连贯：密度、危险怪和精英压力都会提高。",
		"risk_band": [0.63, 0.76],
		"spawn_interval_scale": 0.90,
		"minimum_spawn_interval_scale": 0.90,
		"enemy_health_scale": 1.15,
		"special_health_scale": 1.18,
		"boss_health_scale": 1.10,
		"enemy_damage_scale": 1.10,
		"enemy_speed_scale": 1.04,
		"dangerous_weight_scale": 1.15,
		"ranged_weight_scale": 1.12,
		"burst_weight_scale": 1.12,
		"density_pack_scale": 1.08,
		"special_attack_interval_scale": 0.92,
		"special_projectile_count_scale": 1.08,
		"boss_attack_pressure_scale": 1.10,
		"recovery_margin_scale": 0.95,
		"active_enemy_limit": 380,
		"enemy_projectile_limit": 280,
		"temporary_effect_limit": 400,
		"autosave_interval": 4.0
	},
	"hell": {
		"id": "hell",
		"label": "地狱",
		"available": true,
		"description": "高压挑战：更高密度、更快爆发、更痛远程和更强 Boss 同时压上来。",
		"risk_band": [0.86, 1.04],
		"spawn_interval_scale": 0.62,
		"minimum_spawn_interval_scale": 0.62,
		"enemy_health_scale": 1.62,
		"special_health_scale": 1.82,
		"boss_health_scale": 1.55,
		"enemy_damage_scale": 1.48,
		"enemy_speed_scale": 1.16,
		"dangerous_weight_scale": 1.72,
		"ranged_weight_scale": 1.55,
		"burst_weight_scale": 1.68,
		"density_pack_scale": 1.34,
		"special_attack_interval_scale": 0.68,
		"special_projectile_count_scale": 1.42,
		"boss_attack_pressure_scale": 1.65,
		"recovery_margin_scale": 0.78,
		"active_enemy_limit": 520,
		"enemy_projectile_limit": 430,
		"temporary_effect_limit": 560,
		"autosave_interval": 4.5
	}
}

static func normalize_id(difficulty_id: String) -> String:
	var normalized := difficulty_id.strip_edges().to_lower()
	if PROFILES.has(normalized):
		return normalized
	return DEFAULT_DIFFICULTY_ID

static func get_profile(difficulty_id: String = DEFAULT_DIFFICULTY_ID) -> Dictionary:
	return (PROFILES.get(normalize_id(difficulty_id), PROFILES[DEFAULT_DIFFICULTY_ID]) as Dictionary).duplicate(true)

static func get_ordered_profiles() -> Array:
	var profiles: Array = []
	for difficulty_id in DIFFICULTY_ORDER:
		profiles.append(get_profile(difficulty_id))
	return profiles

static func is_available(difficulty_id: String) -> bool:
	return bool(get_profile(difficulty_id).get("available", false))

static func get_label(difficulty_id: String) -> String:
	return str(get_profile(difficulty_id).get("label", "普通"))

static func get_description(difficulty_id: String) -> String:
	return str(get_profile(difficulty_id).get("description", "标准幸存者割草体验。"))

static func get_scale(profile: Dictionary, key: String, fallback: float = 1.0) -> float:
	return float(profile.get(key, fallback))

static func get_limit(profile: Dictionary, key: String, fallback: int) -> int:
	return max(1, int(profile.get(key, fallback)))

static func get_health_scale_for_kind(kind: String, profile: Dictionary) -> float:
	match kind:
		"boss":
			return get_scale(profile, "boss_health_scale", get_scale(profile, "enemy_health_scale", 1.0))
		"elite", "small_boss":
			return get_scale(profile, "special_health_scale", get_scale(profile, "enemy_health_scale", 1.0))
		_:
			return get_scale(profile, "enemy_health_scale", 1.0)

static func apply_to_wave_profile(wave_profile: Dictionary, profile: Dictionary) -> Dictionary:
	var adjusted: Dictionary = wave_profile.duplicate(true)
	var density_pack_scale := get_scale(profile, "density_pack_scale", 1.0)
	adjusted["pack_chance"] = clamp(float(adjusted.get("pack_chance", 0.0)) * density_pack_scale, 0.02, 0.72)
	adjusted["pack_bonus_max"] = max(1, int(round(float(adjusted.get("pack_bonus_max", 2)) * density_pack_scale)))
	adjusted["swarm_min"] = max(4, int(round(float(adjusted.get("swarm_min", 8)) * density_pack_scale)))
	adjusted["swarm_max"] = max(int(adjusted.get("swarm_min", 4)), int(round(float(adjusted.get("swarm_max", 14)) * density_pack_scale)))

	var weights: Dictionary = adjusted.get("weights", {}).duplicate(true)
	if not weights.is_empty():
		_tune_weight(weights, "brute", get_scale(profile, "dangerous_weight_scale", 1.0))
		_tune_weight(weights, "shooter", get_scale(profile, "ranged_weight_scale", get_scale(profile, "dangerous_weight_scale", 1.0)))
		_tune_weight(weights, "shotgunner", get_scale(profile, "ranged_weight_scale", 1.0) * get_scale(profile, "burst_weight_scale", 1.0))
		_tune_weight(weights, "dasher", get_scale(profile, "burst_weight_scale", get_scale(profile, "dangerous_weight_scale", 1.0)))
		_tune_weight(weights, "swarm", max(0.75, density_pack_scale))
		if get_scale(profile, "dangerous_weight_scale", 1.0) < 1.0:
			_tune_weight(weights, "chaser", 1.08)
	adjusted["weights"] = weights
	return adjusted

static func apply_to_enemy_profile(kind: String, enemy_profile: Dictionary, profile: Dictionary) -> Dictionary:
	var adjusted: Dictionary = enemy_profile.duplicate(true)
	var attack_interval_scale := get_scale(profile, "special_attack_interval_scale", 1.0)
	var projectile_count_scale := get_scale(profile, "special_projectile_count_scale", 1.0)
	var behavior := str(adjusted.get("behavior", ""))
	var secondary_behavior := str(adjusted.get("secondary_behavior", ""))
	var is_special := kind in ["elite", "small_boss", "boss"]
	if behavior == "shooter" or secondary_behavior == "shooter" or is_special:
		_adjust_interval(adjusted, "shot_interval", attack_interval_scale, 0.55)
		_adjust_projectile_count(adjusted, "projectile_count", projectile_count_scale, 1, 8)
		_adjust_projectile_count(adjusted, "projectile_split_count", projectile_count_scale, 0, 6)
	if behavior == "dash" or is_special:
		_adjust_interval(adjusted, "dash_interval", attack_interval_scale, 0.7)
	if behavior == "turret" or secondary_behavior == "turret" or is_special:
		_adjust_interval(adjusted, "turret_bombard_interval", attack_interval_scale, 0.9)
		_adjust_projectile_count(adjusted, "turret_bombard_projectiles", projectile_count_scale, 6, 14)
	adjusted["boss_attack_pressure_scale"] = get_scale(profile, "boss_attack_pressure_scale", 1.0) if kind == "boss" else 1.0
	return adjusted

static func _adjust_interval(target: Dictionary, key: String, scale: float, minimum: float) -> void:
	if not target.has(key):
		return
	target[key] = max(minimum, float(target.get(key, minimum)) * max(0.2, scale))

static func _adjust_projectile_count(target: Dictionary, key: String, scale: float, minimum: int, maximum: int) -> void:
	if not target.has(key):
		return
	var value := int(round(float(target.get(key, minimum)) * max(0.0, scale)))
	target[key] = clamp(value, minimum, maximum)

static func _tune_weight(weights: Dictionary, archetype: String, multiplier: float) -> void:
	if weights.has(archetype):
		weights[archetype] = max(0.01, float(weights.get(archetype, 0.0)) * max(0.0, multiplier))
