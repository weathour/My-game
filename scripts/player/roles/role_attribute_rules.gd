extends RefCounted

const ROLE_DATABASE := preload("res://scripts/player/roles/role_database.gd")

const MAX_ATTRIBUTE_LEVEL := 18.0
const MIN_ATTRIBUTE_LEVEL := 0.0
const EVOLVED_TITLE_COLOR := Color(0.38, 1.0, 0.48, 1.0)

const ATTR_SWORDSMAN := "swordsman_trait"
const ATTR_GUNNER := "gunner_trait"
const ATTR_MAGE := "mage_trait"
const ATTR_MECHANIC := "mechanic_trait"
const ATTRIBUTE_KEYS := [ATTR_SWORDSMAN, ATTR_GUNNER, ATTR_MAGE, ATTR_MECHANIC]

const ROLE_PRIMARY_ATTRIBUTES := {
	"swordsman": ATTR_SWORDSMAN,
	"gunner": ATTR_GUNNER,
	"mage": ATTR_MAGE,
	"mechanic": ATTR_MECHANIC
}

const SWORDSMAN_TRAIT_HEAL_BASE_PROC_CHANCE := 0.05
const SWORDSMAN_TRAIT_HEAL_PROC_CHANCE_PER_LEVEL := 0.0
const SWORDSMAN_TRAIT_HEAL_RATIO := 0.03
const SWORDSMAN_TRAIT_MISSING_HEAL_RATIO := 0.03
const SWORDSMAN_TRAIT_HEAL_COOLDOWN := 1.0
const SWORDSMAN_TRAIT_MAX_ROLL_HITS := 2
const SWORDSMAN_BASE_DODGE_CHANCE := 0.03
const GUNNER_BASE_DODGE_CHANCE := 0.15
const MAGE_BASE_DODGE_CHANCE := 0.03
const MECHANIC_BASE_DODGE_CHANCE := 0.03
const SWORDSMAN_BASE_DAMAGE_REDUCTION_VALUE := 20.0
const GUNNER_BASE_DAMAGE_REDUCTION_VALUE := -40.0
const MAGE_BASE_DAMAGE_REDUCTION_VALUE := 0.0
const MECHANIC_BASE_DAMAGE_REDUCTION_VALUE := 0.0
const GUNNER_TRAIT_DODGE_VALUE_PER_LEVEL := 2.0
const MAGE_TRAIT_KILL_ENERGY_BASE_CHANCE := 0.10
const MAGE_TRAIT_KILL_ENERGY_CHANCE_PER_LEVEL := 0.02
const MAGE_TRAIT_KILL_ENERGY_MULTIPLIER := 3.0
const COMMON_PROSPERITY_SWITCH_COOLDOWN_FACTOR := 0.9


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


static func get_swordsman_trait_heal_amount(level: float) -> float:
	return SWORDSMAN_TRAIT_HEAL_RATIO


static func get_swordsman_trait_heal_proc_chance(level: float) -> float:
	return clamp(SWORDSMAN_TRAIT_HEAL_BASE_PROC_CHANCE + get_effective_level(level) * SWORDSMAN_TRAIT_HEAL_PROC_CHANCE_PER_LEVEL, 0.0, 1.0)


static func get_role_base_dodge_chance(role_id: String) -> float:
	match role_id:
		"swordsman":
			return SWORDSMAN_BASE_DODGE_CHANCE
		"gunner":
			return GUNNER_BASE_DODGE_CHANCE
		"mage":
			return MAGE_BASE_DODGE_CHANCE
		"mechanic":
			return MECHANIC_BASE_DODGE_CHANCE
	return 0.0


static func get_role_base_damage_reduction_value(role_id: String) -> float:
	match role_id:
		"swordsman":
			return SWORDSMAN_BASE_DAMAGE_REDUCTION_VALUE
		"gunner":
			return GUNNER_BASE_DAMAGE_REDUCTION_VALUE
		"mage":
			return MAGE_BASE_DAMAGE_REDUCTION_VALUE
		"mechanic":
			return MECHANIC_BASE_DAMAGE_REDUCTION_VALUE
	return 0.0


static func get_gunner_trait_dodge_value(level: float) -> float:
	return max(0.0, get_effective_level(level) * GUNNER_TRAIT_DODGE_VALUE_PER_LEVEL)


static func get_mage_trait_mana_regen_per_second(_level: float) -> float:
	return 0.0


static func get_mage_trait_pickup_range_bonus(_level: float) -> float:
	return 0.0


static func get_mage_trait_kill_energy_proc_chance(level: float) -> float:
	return clamp(MAGE_TRAIT_KILL_ENERGY_BASE_CHANCE + get_effective_level(level) * MAGE_TRAIT_KILL_ENERGY_CHANCE_PER_LEVEL, 0.0, 1.0)


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
			return "剑士特性提升到 Lv.%s：剑士造成伤害时有 %.0f%% 概率回复自身最大生命值 %.0f%% 与已损失生命值 %.0f%% 的生命值，每秒最多触发 1 次，多目标最多同时触发 %d 次；受到致命伤时保留 1 点生命并进入 1.5s 战意，之后进入 80s CD。" % [
				_format_level(level),
				get_swordsman_trait_heal_proc_chance(level) * 100.0,
				get_swordsman_trait_heal_amount(level) * 100.0,
				SWORDSMAN_TRAIT_MISSING_HEAL_RATIO * 100.0,
				SWORDSMAN_TRAIT_MAX_ROLL_HITS
			]
		ATTR_GUNNER:
			return "枪手特性提升到 Lv.%s：枪手基础闪避率 %.0f%%，每级提供 %.0f 闪避值；枪手拥有半径115的猎杀安全区，圈内敌人承受枪手伤害降至40%%。未受伤时每2秒叠加1层瞬杀，最多10层，每层提升3%%伤害、3%%移速和4闪避值，受伤后清空并进入15s CD。当前特性提供：%.0f 闪避值。" % [
				_format_level(level),
				get_role_base_dodge_chance("gunner") * 100.0,
				GUNNER_TRAIT_DODGE_VALUE_PER_LEVEL,
				get_gunner_trait_dodge_value(level)
			]
		ATTR_MAGE:
			return "法师特性提升到 Lv.%s：每次击杀有 %.1f%% 概率获得 1 层奥数充能。奥数充能每层提供 2%% 法师自身大招回能效率，并将法师自身获得的大招能量的 10%% 同步给另外两名角色，最多 10 层；切人后，奥数充能不会立刻消失，而是由下一名登场角色继承法师当前层数，并持续同等秒数。法师释放登场技后会立刻进入 5s 奥法盈余，释放大招则会在演出结束后进入 5s 奥法盈余：全员大招回能效率 +20%%、切人回能效率 +20%%；若自然结束时当前站场角色仍为法师，则额外获得 3 层奥数充能。本次提升：击杀获得奥数充能概率 +%.1f%%。" % [
				_format_level(level),
				get_mage_trait_kill_energy_proc_chance(level) * 100.0,
				MAGE_TRAIT_KILL_ENERGY_CHANCE_PER_LEVEL * 100.0
			]
		ATTR_MECHANIC:
			return "机械师特性提升到 Lv.%s：战场改装——机械师登场期间每 4 秒产出 1 个零件，最多 10 个；每个零件使机械师的召唤物与力场（定点机炮、感应地雷、磁滞力场、重型炮台）与机械全开齐射伤害提升 4%%。" % [
				_format_level(level)
			]
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
	var target_text := "所选英雄特性"
	if trait_definitions.size() == 3:
		target_text = "三名英雄特性"
	elif trait_definitions.size() == 4:
		target_text = "四名英雄特性"
	return "共同致富：%s都 +%.2f，且切换英雄冷却 x%.0f%%。本次后：%s。" % [
		target_text,
		added_amount,
		COMMON_PROSPERITY_SWITCH_COOLDOWN_FACTOR * 100.0,
		"，".join(parts)
	]


static func _format_level(level: float) -> String:
	if is_equal_approx(level, round(level)):
		return str(int(round(level)))
	return "%.1f" % level


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


static func get_swordsman_dodge_chance(_level: float) -> float:
	return get_role_base_dodge_chance("swordsman")


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


static func get_gunner_footwork_flat_speed_bonus(_level: float) -> float:
	return 0.0


static func get_mage_arcane_focus_range_multiplier(_level: float) -> float:
	return 1.0


static func get_mage_surplus_energy_multiplier(_level: float, _role_id: String = "") -> float:
	return 1.0


static func get_mage_surplus_passive_energy_per_second(level: float) -> float:
	return get_mage_trait_mana_regen_per_second(level)
