extends RefCounted

const ROLE_DATABASE := preload("res://scripts/player/roles/role_database.gd")

const MAX_ATTRIBUTE_LEVEL := 18.0
const MIN_ATTRIBUTE_LEVEL := 0.0
const EVOLVED_TITLE_COLOR := Color(0.38, 1.0, 0.48, 1.0)

const ATTR_SWORDSMAN := "swordsman_trait"
const ATTR_GUNNER := "gunner_trait"
const ATTR_MAGE := "mage_trait"
const ATTRIBUTE_KEYS := [ATTR_SWORDSMAN, ATTR_GUNNER, ATTR_MAGE]

# Compatibility aliases for saves/code created while this system was named as
# three generic attributes. Canonical storage now uses hero-trait keys.
const ATTR_STRENGTH := ATTR_SWORDSMAN
const ATTR_AGILITY := ATTR_GUNNER
const ATTR_INTELLIGENCE := ATTR_MAGE

const ROLE_PRIMARY_ATTRIBUTES := {
	"swordsman": ATTR_SWORDSMAN,
	"gunner": ATTR_GUNNER,
	"mage": ATTR_MAGE
}

const SWORDSMAN_MAX_HEALTH_PER_POINT := 0.0
const PRIMARY_DAMAGE_PER_POINT := 0.0
const SWORDSMAN_LOW_HEALTH_THRESHOLD := 0.30
const SWORDSMAN_LOW_HEALTH_FLAT_HEAL_PER_POINT := 0.14
const SWORDSMAN_DODGE_PER_POINT := 0.006
const SWORDSMAN_MAX_DODGE := 0.16
const GUNNER_MOVE_SPEED_PER_POINT := 3.0
const GUNNER_DISTANCE_DAMAGE_PER_POINT := 0.018
const MAGE_SKILL_RANGE_PER_POINT := 0.018
const MAGE_KILL_ENERGY_PER_POINT := 0.025
const COMMON_PROSPERITY_SWITCH_COOLDOWN_FACTOR := 0.9

# Compatibility constant aliases.
const STRENGTH_MAX_HEALTH_PER_POINT := 0.0
const STRENGTH_REGEN_PER_POINT := 0.0
const AGILITY_MOVE_SPEED_PER_POINT := GUNNER_MOVE_SPEED_PER_POINT
const AGILITY_DODGE_PER_POINT := 0.0
const AGILITY_MAX_DODGE := 0.0
const INTELLIGENCE_MANA_REGEN_PER_POINT := 0.0
const INTELLIGENCE_PICKUP_RANGE_PER_POINT := 0.0


static func get_effective_level(level: float) -> float:
	return max(MIN_ATTRIBUTE_LEVEL, level)


static func is_attribute_evolved(level: float) -> bool:
	return level >= MAX_ATTRIBUTE_LEVEL


static func is_attribute_third_evolved(level: float) -> bool:
	return level >= MAX_ATTRIBUTE_LEVEL


static func get_attribute_keys() -> Array:
	var keys := get_trait_keys_for_roles()
	return keys if not keys.is_empty() else ATTRIBUTE_KEYS.duplicate()


static func get_primary_attribute_for_role(role_id: String) -> String:
	var declared_key := ROLE_DATABASE.get_role_trait_key(role_id)
	if declared_key != "":
		return declared_key
	return str(ROLE_PRIMARY_ATTRIBUTES.get(role_id, ""))


static func get_trait_definitions(role_order: Array = []) -> Array:
	return ROLE_DATABASE.get_role_trait_definitions(role_order)


static func get_trait_keys_for_roles(role_order: Array = []) -> Array:
	var result: Array = []
	for definition in get_trait_definitions(role_order):
		if definition is not Dictionary:
			continue
		var trait_key := str((definition as Dictionary).get("trait_key", ""))
		if trait_key != "" and not result.has(trait_key):
			result.append(trait_key)
	return result


static func get_swordsman_trait_max_health_bonus(_level: float) -> float:
	return 0.0


static func get_swordsman_trait_regen_per_second(_level: float) -> float:
	return 0.0


static func get_swordsman_trait_low_health_flat_heal(level: float) -> float:
	return get_effective_level(level) * SWORDSMAN_LOW_HEALTH_FLAT_HEAL_PER_POINT


static func get_swordsman_trait_dodge_chance(level: float) -> float:
	return min(SWORDSMAN_MAX_DODGE, get_effective_level(level) * SWORDSMAN_DODGE_PER_POINT)


static func get_gunner_trait_flat_move_speed_bonus(level: float) -> float:
	return get_effective_level(level) * GUNNER_MOVE_SPEED_PER_POINT


static func get_gunner_trait_dodge_chance(_level: float) -> float:
	return 0.0


static func get_gunner_trait_distance_damage_bonus(level: float) -> float:
	return get_effective_level(level) * GUNNER_DISTANCE_DAMAGE_PER_POINT


static func get_mage_trait_mana_regen_per_second(_level: float) -> float:
	return 0.0


static func get_mage_trait_pickup_range_bonus(_level: float) -> float:
	return 0.0


static func get_mage_trait_skill_range_multiplier(level: float) -> float:
	return 1.0 + get_effective_level(level) * MAGE_SKILL_RANGE_PER_POINT


static func get_mage_trait_kill_energy_multiplier(level: float) -> float:
	return 1.0 + get_effective_level(level) * MAGE_KILL_ENERGY_PER_POINT


static func get_swordsman_trait_entry_damage_multiplier(_level: float) -> float:
	return 1.0


static func get_swordsman_trait_entry_distance_multiplier(_level: float) -> float:
	return 1.0


static func get_swordsman_trait_entry_invulnerability_bonus(_level: float) -> float:
	return 0.0


static func get_swordsman_trait_exit_lifesteal_bonus(_level: float) -> float:
	return 0.0


static func get_swordsman_trait_exit_lifesteal_duration_bonus(_level: float) -> float:
	return 0.0


static func get_gunner_trait_entry_bullet_damage_multiplier(_level: float) -> float:
	return 1.0


static func get_gunner_trait_entry_bullet_speed_bonus(_level: float) -> float:
	return 0.0


static func get_gunner_trait_entry_wave_count(_level: float) -> int:
	return 2


static func get_gunner_trait_exit_haste_interval_bonus(_level: float) -> float:
	return 0.0


static func get_gunner_trait_exit_move_speed_multiplier_bonus(_level: float) -> float:
	return 0.0


static func get_gunner_trait_exit_haste_duration_bonus(_level: float) -> float:
	return 0.0


static func get_mage_trait_entry_radius_multiplier(_level: float) -> float:
	return 1.0


static func get_mage_trait_entry_damage_multiplier(_level: float) -> float:
	return 1.0


static func get_mage_trait_entry_bombard_count(_level: float) -> int:
	return 2


static func get_mage_trait_exit_energy_bonus(_level: float) -> float:
	return 0.0


static func get_mage_trait_exit_slow_field_radius_bonus(_level: float) -> float:
	return 0.0


static func get_mage_trait_exit_slow_field_damage_ratio(_level: float) -> float:
	return 0.0


# Compatibility helpers retaining previous generic attribute function names.
static func get_strength_max_health_bonus(level: float) -> float:
	return get_swordsman_trait_max_health_bonus(level)


static func get_strength_regen_per_second(level: float) -> float:
	return get_swordsman_trait_regen_per_second(level)


static func get_agility_flat_move_speed_bonus(level: float) -> float:
	return get_gunner_trait_flat_move_speed_bonus(level)


static func get_agility_dodge_chance(level: float) -> float:
	return get_gunner_trait_dodge_chance(level)


static func get_intelligence_mana_regen_per_second(level: float) -> float:
	return get_mage_trait_mana_regen_per_second(level)


static func get_intelligence_pickup_range_bonus(level: float) -> float:
	return get_mage_trait_pickup_range_bonus(level)


static func get_primary_attribute_damage_bonus(_role_id: String, _attribute_levels: Dictionary) -> float:
	return 0.0


static func get_role_attribute_titles(_role_id: String = "", _levels: Dictionary = {}, role_order: Array = []) -> Dictionary:
	var titles := {}
	for definition in get_trait_definitions(role_order):
		if definition is not Dictionary:
			continue
		var trait_key := str((definition as Dictionary).get("trait_key", ""))
		if trait_key != "":
			titles[trait_key] = str((definition as Dictionary).get("trait_name", trait_key))
	return titles


static func get_role_attribute_description(_role_id: String, attribute_key: String, next_level: float) -> String:
	var level := get_effective_level(next_level)
	match attribute_key:
		ATTR_SWORDSMAN:
			return "剑士特性训练提升到 Lv.%s：生命低于 %.0f%% 时，剑士每次攻击命中固定回复 %.1f 生命；闪避 %.1f%%。本次提升：濒死回复 +%.1f，闪避 +%.1f%%。" % [
				_format_level(level),
				SWORDSMAN_LOW_HEALTH_THRESHOLD * 100.0,
				get_swordsman_trait_low_health_flat_heal(level),
				get_swordsman_trait_dodge_chance(level) * 100.0,
				SWORDSMAN_LOW_HEALTH_FLAT_HEAL_PER_POINT,
				SWORDSMAN_DODGE_PER_POINT * 100.0
			]
		ATTR_GUNNER:
			return "枪手特性训练提升到 Lv.%s：射手天赋强化，距离增伤额外 +%.1f%%；移动速度 +%.1f。本次提升：射手天赋 +%.1f%%，移速 +%.1f。" % [
				_format_level(level),
				get_gunner_trait_distance_damage_bonus(level) * 100.0,
				get_gunner_trait_flat_move_speed_bonus(level),
				GUNNER_DISTANCE_DAMAGE_PER_POINT * 100.0,
				GUNNER_MOVE_SPEED_PER_POINT
			]
		ATTR_MAGE:
			return "术师特性训练提升到 Lv.%s：奥法扩能，术师所有技能范围 x%.3f；击杀能量回复 x%.3f。本次提升：范围 +%.1f%%，击杀能量 +%.1f%%。" % [
				_format_level(level),
				get_mage_trait_skill_range_multiplier(level),
				get_mage_trait_kill_energy_multiplier(level),
				MAGE_SKILL_RANGE_PER_POINT * 100.0,
				MAGE_KILL_ENERGY_PER_POINT * 100.0
			]
	if attribute_key == ATTR_SWORDSMAN:
		return "剑士特性训练提升到 Lv.%s：生命低于 %.0f%% 时，每次剑士攻击固定回复 %.1f 生命；闪避 %.1f%%。本次提升：濒死回复 +%.1f，闪避 +%.1f%%。" % [
			_format_level(level),
			SWORDSMAN_LOW_HEALTH_THRESHOLD * 100.0,
			get_swordsman_trait_low_health_flat_heal(level),
			get_swordsman_trait_dodge_chance(level) * 100.0,
			SWORDSMAN_LOW_HEALTH_FLAT_HEAL_PER_POINT,
			SWORDSMAN_DODGE_PER_POINT * 100.0
		]
	if attribute_key == ATTR_GUNNER:
		return "枪手特性训练提升到 Lv.%s：射手天赋强化，距离增伤额外 +%.1f%%；移动速度 +%.1f。本次提升：射手天赋 +%.1f%%，移速 +%.1f。" % [
			_format_level(level),
			get_gunner_trait_distance_damage_bonus(level) * 100.0,
			get_gunner_trait_flat_move_speed_bonus(level),
			GUNNER_DISTANCE_DAMAGE_PER_POINT * 100.0,
			GUNNER_MOVE_SPEED_PER_POINT
		]
	if attribute_key == ATTR_MAGE:
		return "术师特性训练提升到 Lv.%s：奥法扩能，术师所有技能范围 x%.3f；击杀能量回复 x%.3f。本次提升：范围 +%.1f%%，击杀能量 +%.1f%%。" % [
			_format_level(level),
			get_mage_trait_skill_range_multiplier(level),
			get_mage_trait_kill_energy_multiplier(level),
			MAGE_SKILL_RANGE_PER_POINT * 100.0,
			MAGE_KILL_ENERGY_PER_POINT * 100.0
		]
	return ""
	match attribute_key:
		ATTR_SWORDSMAN:
			return "剑士特性提升到 Lv.%s：最大生命累计 +%.0f（本次 +%.0f），生命自动恢复 %.2f/s；剑士普攻伤害 +%.1f。入场破阵伤害 ×%.0f%%、突进距离 ×%.0f%%、无敌 +%.2fs；离场传承吸血 +%.1f%%、持续 +%.1fs。" % [
				_format_level(level),
				get_swordsman_trait_max_health_bonus(level),
				SWORDSMAN_MAX_HEALTH_PER_POINT,
				get_swordsman_trait_regen_per_second(level),
				level * PRIMARY_DAMAGE_PER_POINT,
				get_swordsman_trait_entry_damage_multiplier(level) * 100.0,
				get_swordsman_trait_entry_distance_multiplier(level) * 100.0,
				get_swordsman_trait_entry_invulnerability_bonus(level),
				get_swordsman_trait_exit_lifesteal_bonus(level) * 100.0,
				get_swordsman_trait_exit_lifesteal_duration_bonus(level)
			]
		ATTR_GUNNER:
			return "枪手特性提升到 Lv.%s：移动速度累计 +%.1f，闪避率 %.1f%%；枪手普攻伤害 +%.1f。入场弹幕伤害 ×%.0f%%、子弹速度 +%.0f、弹幕波数 %d；离场过载攻速 +%.1f%%、移速 +%.1f%%、持续 +%.1fs。" % [
				_format_level(level),
				get_gunner_trait_flat_move_speed_bonus(level),
				get_gunner_trait_dodge_chance(level) * 100.0,
				level * PRIMARY_DAMAGE_PER_POINT,
				get_gunner_trait_entry_bullet_damage_multiplier(level) * 100.0,
				get_gunner_trait_entry_bullet_speed_bonus(level),
				get_gunner_trait_entry_wave_count(level),
				get_gunner_trait_exit_haste_interval_bonus(level) * 100.0,
				get_gunner_trait_exit_move_speed_multiplier_bonus(level) * 100.0,
				get_gunner_trait_exit_haste_duration_bonus(level)
			]
		ATTR_MAGE:
			return "术师特性提升到 Lv.%s：大招能量自动恢复 %.2f/s，吸取范围累计 +%.1f；术师普攻伤害 +%.1f。入场轰炸伤害 ×%.0f%%、范围 ×%.0f%%、落点数 %d；离场立刻回能 +%.1f，并留下半径 +%.1f 的减速领域。" % [
				_format_level(level),
				get_mage_trait_mana_regen_per_second(level),
				get_mage_trait_pickup_range_bonus(level),
				level * PRIMARY_DAMAGE_PER_POINT,
				get_mage_trait_entry_damage_multiplier(level) * 100.0,
				get_mage_trait_entry_radius_multiplier(level) * 100.0,
				get_mage_trait_entry_bombard_count(level),
				get_mage_trait_exit_energy_bonus(level),
				get_mage_trait_exit_slow_field_radius_bonus(level)
			]
		_:
			return ""


static func get_balanced_attribute_description(current_levels: Dictionary, added_amount: float) -> String:
	return get_balanced_attribute_description_for_roles(current_levels, added_amount, get_trait_definitions())


static func get_balanced_attribute_description_for_roles(current_levels: Dictionary, added_amount: float, trait_definitions: Array) -> String:
	var parts: Array[String] = []
	for definition in trait_definitions:
		if definition is not Dictionary:
			continue
		var trait_key := str((definition as Dictionary).get("trait_key", ""))
		if trait_key == "":
			continue
		var next_level := get_effective_level(float(current_levels.get(trait_key, 0.0)) + added_amount)
		parts.append("%s Lv.%s" % [str((definition as Dictionary).get("trait_name", trait_key)), _format_level(next_level)])
	var target_text := "所选英雄特性" if trait_definitions.size() != 3 else "三名英雄特性"
	return "共同致富：%s都 +%.2f，且切换英雄冷却 ×%.0f%%（乘算叠加）。本次后：%s。" % [
		target_text,
		added_amount,
		COMMON_PROSPERITY_SWITCH_COOLDOWN_FACTOR * 100.0,
		"，".join(parts)
	]


static func _format_level(level: float) -> String:
	if is_equal_approx(level, round(level)):
		return str(int(round(level)))
	return "%.1f" % level


# Compatibility shims for old role-specific attribute hooks. The new training
# system is hero-trait based: swordsman = health/regen, gunner = speed/dodge,
# mage = mana regen/pickup range. Legacy combat-shape bonuses return neutral
# values so old callers keep working without hidden extra effects.
static func get_swordsman_heart_interval_multiplier(_level: float) -> float:
	return 1.0

static func get_swordsman_heart_range_multiplier(_level: float) -> float:
	return 1.0

static func get_swordsman_normal_attack_scale(_level: float) -> float:
	return 1.0

static func get_swordsman_normal_attack_width_scale(_level: float) -> float:
	return 1.0

static func get_swordsman_bloodthirst_ratio(_level: float) -> float:
	return 0.0

static func get_swordsman_bloodthirst_heal_cap(_level: float) -> float:
	return 0.0

static func get_swordsman_dodge_chance(level: float) -> float:
	return get_gunner_trait_dodge_chance(level)

static func get_gunner_barrage_speed_multiplier(_level: float) -> float:
	return 1.0

static func get_gunner_barrage_interval_reduction(_level: float) -> float:
	return 0.0

static func get_gunner_barrage_bounce_count(_level: float) -> int:
	return 0

static func get_gunner_barrage_shotgun_wave_count(_level: float) -> int:
	return 0

static func get_gunner_barrage_shotgun_pellet_count(_level: float) -> int:
	return 0

static func get_gunner_barrage_split_count(_level: float) -> int:
	return 0

static func get_gunner_footwork_range_multiplier(_level: float) -> float:
	return 1.0

static func get_gunner_footwork_move_multiplier(_level: float) -> float:
	return 1.0

static func get_gunner_footwork_flat_speed_bonus(level: float) -> float:
	return get_gunner_trait_flat_move_speed_bonus(level)

static func get_mage_arcane_focus_range_multiplier(_level: float) -> float:
	return 1.0

static func get_mage_surplus_energy_multiplier(_level: float, _role_id: String = "") -> float:
	return 1.0

static func get_mage_surplus_passive_energy_per_second(level: float) -> float:
	return get_mage_trait_mana_regen_per_second(level)
