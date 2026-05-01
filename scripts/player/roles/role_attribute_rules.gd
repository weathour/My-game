extends RefCounted

const MAX_ATTRIBUTE_LEVEL := 18.0
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

const SWORDSMAN_MAX_HEALTH_PER_POINT := 8.0
const SWORDSMAN_REGEN_PER_POINT := 0.18
const GUNNER_MOVE_SPEED_PER_POINT := 4.0
const GUNNER_DODGE_PER_POINT := 0.015
const GUNNER_MAX_DODGE := 0.45
const MAGE_MANA_REGEN_PER_POINT := 0.22
const MAGE_PICKUP_RANGE_PER_POINT := 4.0
const PRIMARY_DAMAGE_PER_POINT := 1.0
const COMMON_PROSPERITY_SWITCH_COOLDOWN_FACTOR := 0.9

# Compatibility constant aliases.
const STRENGTH_MAX_HEALTH_PER_POINT := SWORDSMAN_MAX_HEALTH_PER_POINT
const STRENGTH_REGEN_PER_POINT := SWORDSMAN_REGEN_PER_POINT
const AGILITY_MOVE_SPEED_PER_POINT := GUNNER_MOVE_SPEED_PER_POINT
const AGILITY_DODGE_PER_POINT := GUNNER_DODGE_PER_POINT
const AGILITY_MAX_DODGE := GUNNER_MAX_DODGE
const INTELLIGENCE_MANA_REGEN_PER_POINT := MAGE_MANA_REGEN_PER_POINT
const INTELLIGENCE_PICKUP_RANGE_PER_POINT := MAGE_PICKUP_RANGE_PER_POINT


static func get_effective_level(level: float) -> float:
	return clamp(level, 0.0, MAX_ATTRIBUTE_LEVEL)


static func is_attribute_evolved(level: float) -> bool:
	return level >= MAX_ATTRIBUTE_LEVEL


static func is_attribute_third_evolved(level: float) -> bool:
	return level >= MAX_ATTRIBUTE_LEVEL


static func get_attribute_keys() -> Array:
	return ATTRIBUTE_KEYS.duplicate()


static func get_primary_attribute_for_role(role_id: String) -> String:
	return str(ROLE_PRIMARY_ATTRIBUTES.get(role_id, ""))


static func get_swordsman_trait_max_health_bonus(level: float) -> float:
	return get_effective_level(level) * SWORDSMAN_MAX_HEALTH_PER_POINT


static func get_swordsman_trait_regen_per_second(level: float) -> float:
	return get_effective_level(level) * SWORDSMAN_REGEN_PER_POINT


static func get_gunner_trait_flat_move_speed_bonus(level: float) -> float:
	return get_effective_level(level) * GUNNER_MOVE_SPEED_PER_POINT


static func get_gunner_trait_dodge_chance(level: float) -> float:
	return min(GUNNER_MAX_DODGE, get_effective_level(level) * GUNNER_DODGE_PER_POINT)


static func get_mage_trait_mana_regen_per_second(level: float) -> float:
	return get_effective_level(level) * MAGE_MANA_REGEN_PER_POINT


static func get_mage_trait_pickup_range_bonus(level: float) -> float:
	return get_effective_level(level) * MAGE_PICKUP_RANGE_PER_POINT


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


static func get_primary_attribute_damage_bonus(role_id: String, attribute_levels: Dictionary) -> float:
	var attribute_key := get_primary_attribute_for_role(role_id)
	if attribute_key == "":
		return 0.0
	return get_effective_level(float(attribute_levels.get(attribute_key, 0.0))) * PRIMARY_DAMAGE_PER_POINT


static func get_role_attribute_titles(_role_id: String = "", _levels: Dictionary = {}) -> Dictionary:
	return {
		ATTR_SWORDSMAN: "剑士特性",
		ATTR_GUNNER: "枪手特性",
		ATTR_MAGE: "术师特性"
	}


static func get_role_attribute_description(_role_id: String, attribute_key: String, next_level: float) -> String:
	var level := get_effective_level(next_level)
	match attribute_key:
		ATTR_SWORDSMAN:
			return "剑士特性提升到 Lv.%s：最大生命累计 +%.0f（本次 +%.0f），生命自动恢复 %.2f/s；剑士普攻伤害 +%.1f。" % [
				_format_level(level),
				get_swordsman_trait_max_health_bonus(level),
				SWORDSMAN_MAX_HEALTH_PER_POINT,
				get_swordsman_trait_regen_per_second(level),
				level * PRIMARY_DAMAGE_PER_POINT
			]
		ATTR_GUNNER:
			return "枪手特性提升到 Lv.%s：移动速度累计 +%.1f，闪避率 %.1f%%；枪手普攻伤害 +%.1f。" % [
				_format_level(level),
				get_gunner_trait_flat_move_speed_bonus(level),
				get_gunner_trait_dodge_chance(level) * 100.0,
				level * PRIMARY_DAMAGE_PER_POINT
			]
		ATTR_MAGE:
			return "术师特性提升到 Lv.%s：大招能量自动恢复 %.2f/s，吸取范围累计 +%.1f；术师普攻伤害 +%.1f。" % [
				_format_level(level),
				get_mage_trait_mana_regen_per_second(level),
				get_mage_trait_pickup_range_bonus(level),
				level * PRIMARY_DAMAGE_PER_POINT
			]
		_:
			return ""


static func get_balanced_attribute_description(current_levels: Dictionary, added_amount: float) -> String:
	var swordsman := get_effective_level(float(current_levels.get(ATTR_SWORDSMAN, 0.0)) + added_amount)
	var gunner := get_effective_level(float(current_levels.get(ATTR_GUNNER, 0.0)) + added_amount)
	var mage := get_effective_level(float(current_levels.get(ATTR_MAGE, 0.0)) + added_amount)
	return "共同致富：三名英雄特性都 +%.2f，且切换英雄冷却 ×%.0f%%（乘算叠加）。本次后：剑士特性 Lv.%s，枪手特性 Lv.%s，术师特性 Lv.%s。" % [
		added_amount,
		COMMON_PROSPERITY_SWITCH_COOLDOWN_FACTOR * 100.0,
		_format_level(swordsman),
		_format_level(gunner),
		_format_level(mage)
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
