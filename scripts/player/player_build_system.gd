extends RefCounted

const ROLE_DATABASE := preload("res://scripts/player/roles/role_database.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")

const OPTION_PREFIX := "role_build:"
const CATEGORY_ROLE_BUILD := "role_build"
const BUILD_LEVELS_KEY := "build_levels"
const ROLE_SLOT_COUNT := 3
const SKILL_OPTION_TOTAL_WEIGHT := 0.35
const NON_SKILL_OPTION_TOTAL_WEIGHT := 0.65

const BUILD_DEFINITIONS := {
	"swordsman": [
		{"id": "trait_extra_roll", "title": "战意触发次数+2", "summary": "战意触发次数+2", "card_title": "剑士特性", "skill_progress_id": "swordsman_trait"},
		{"id": "trait_heal_bonus", "title": "战意触发时回复效果增加2％", "summary": "战意触发时回复效果增加2％", "card_title": "剑士特性", "skill_progress_id": "swordsman_trait"},
		{"id": "knight_glory_duration", "title": "骑士荣耀持续时间增加0.3s", "summary": "骑士荣耀持续时间增加0.3s", "card_title": "剑士特性", "skill_progress_id": "swordsman_trait"},
		{"id": "entry_damage", "title": "冲锋伤害倍率增加15％", "summary": "冲锋伤害倍率增加15％", "card_title": "冲锋", "skill_progress_id": "swordsman_entry"},
		{"id": "basic_attack_cooldown", "title": "剑士普通攻击冷却减少15％", "summary": "剑士普通攻击冷却减少15％", "card_title": "普通攻击", "skill_progress_id": "swordsman_basic"},
		{"id": "basic_attack_damage", "title": "剑士普通攻击伤害倍率增加15％", "summary": "剑士普通攻击伤害倍率增加15％", "card_title": "普通攻击", "skill_progress_id": "swordsman_basic"},
		{"id": "basic_attack_range", "title": "剑士普通攻击范围增加15％", "summary": "剑士普通攻击范围增加15％", "card_title": "普通攻击", "skill_progress_id": "swordsman_basic"},
		{"id": "blade_storm_damage", "title": "剑士剑刃风暴伤害倍率增加2.5％", "summary": "剑士剑刃风暴伤害倍率增加2.5％", "requires_skill": "blade_storm", "skill_progress_id": "swordsman_blade_storm"},
		{"id": "blade_storm_area", "title": "剑刃风暴范围增加15％", "summary": "剑刃风暴范围增加15％", "requires_skill": "blade_storm", "skill_progress_id": "swordsman_blade_storm"},
		{"id": "blade_storm_cooldown", "title": "剑刃风暴冷却时间减少8％", "summary": "剑刃风暴冷却时间减少8％", "requires_skill": "blade_storm", "skill_progress_id": "swordsman_blade_storm"},
		{"id": "crescent_wave_cooldown", "title": "月牙剑气冷却时间减少15％", "summary": "月牙剑气冷却时间减少15％", "requires_skill": "crescent_wave", "skill_progress_id": "swordsman_crescent_wave"},
		{"id": "crescent_wave_damage", "title": "月牙剑气伤害倍率增加15％", "summary": "月牙剑气伤害倍率增加15％", "requires_skill": "crescent_wave", "skill_progress_id": "swordsman_crescent_wave"},
		{"id": "crescent_wave_speed", "title": "月牙剑气飞行速度增加30", "summary": "月牙剑气飞行速度增加30", "requires_skill": "crescent_wave", "skill_progress_id": "swordsman_crescent_wave"},
		{"id": "ultimate_damage", "title": "无敌斩伤害倍率+8％", "summary": "无敌斩伤害倍率+8％", "card_title": "无敌斩", "skill_progress_id": "swordsman_ultimate"},
		{"id": "unlock_blade_storm", "title": "获得技能：剑刃风暴", "summary": "获得技能：剑刃风暴", "unlock_skill": "blade_storm", "skill_progress_id": "swordsman_blade_storm"},
		{"id": "unlock_crescent_wave", "title": "获得技能：月牙剑气", "summary": "获得技能：月牙剑气", "unlock_skill": "crescent_wave", "skill_progress_id": "swordsman_crescent_wave"},
		{"id": "unlock_knight_thrust", "title": "获得技能：骑士突", "summary": "获得技能：骑士突", "unlock_skill": "knight_thrust", "skill_progress_id": "swordsman_knight_thrust"},
		{"id": "unlock_king_blade", "title": "获得技能：王者之剑", "summary": "获得技能：王者之剑", "unlock_skill": "king_blade", "skill_progress_id": "swordsman_king_blade"},
		{"id": "unlock_judgement_sword", "title": "获得技能：审判之誓", "summary": "获得技能：审判之誓", "unlock_skill": "judgement_sword", "skill_progress_id": "swordsman_judgement_sword"}
	],
	"gunner": [
		{"id": "hunt_safe_radius", "title": "猎杀半径安全圈减少15", "summary": "猎杀半径安全圈减少15", "card_title": "枪手特性", "skill_progress_id": "gunner_trait"},
		{"id": "hunt_inside_damage", "title": "枪手伤害对猎杀圈内敌人增加20％", "summary": "枪手伤害对猎杀圈内敌人增加20％", "card_title": "枪手特性", "skill_progress_id": "gunner_trait"},
		{"id": "hunt_outside_damage", "title": "枪手伤害对猎杀圈外敌人增加8％", "summary": "枪手伤害对猎杀圈外敌人增加8％", "card_title": "枪手特性", "skill_progress_id": "gunner_trait"},
		{"id": "flash_stack_bonus", "title": "瞬杀每层提供伤害+0.75％，移速+0.75％，闪避值+30", "summary": "瞬杀每层提供伤害+0.75％，移速+0.75％，闪避值+30", "card_title": "枪手特性", "skill_progress_id": "gunner_trait"},
		{"id": "entry_damage", "title": "枪火典礼伤害倍率+15％", "summary": "枪火典礼伤害倍率+15％", "card_title": "枪火典礼", "skill_progress_id": "gunner_entry"},
		{"id": "basic_attack_damage", "title": "枪手普通攻击伤害倍率+15％", "summary": "枪手普通攻击伤害倍率+15％", "card_title": "普通攻击", "skill_progress_id": "gunner_basic"},
		{"id": "basic_attack_cooldown", "title": "枪手普通攻击冷却时间减少8％", "summary": "枪手普通攻击冷却时间减少8％", "card_title": "普通攻击", "skill_progress_id": "gunner_basic"},
		{"id": "basic_attack_range", "title": "枪手普通攻击距离+15", "summary": "枪手普通攻击距离+15", "card_title": "普通攻击", "skill_progress_id": "gunner_basic"},
		{"id": "shrapnel_cooldown", "title": "散弹冷却时间-15％", "summary": "散弹冷却时间-15％", "requires_skill": "shrapnel_field", "skill_progress_id": "gunner_shrapnel"},
		{"id": "shrapnel_damage", "title": "散弹伤害倍率+3％", "summary": "散弹伤害倍率+3％", "requires_skill": "shrapnel_field", "skill_progress_id": "gunner_shrapnel"},
		{"id": "shrapnel_radius", "title": "散弹范围半径+15", "summary": "散弹范围半径+15", "requires_skill": "shrapnel_field", "skill_progress_id": "gunner_shrapnel"},
		{"id": "infinite_reload_speed", "title": "无限装填期间移速+1.5％", "summary": "无限装填期间移速+1.5％", "requires_skill": "infinite_reload", "skill_progress_id": "gunner_infinite_reload"},
		{"id": "infinite_reload_damage", "title": "无限装填伤害倍率+1.5％", "summary": "无限装填伤害倍率+1.5％", "requires_skill": "infinite_reload", "skill_progress_id": "gunner_infinite_reload"},
		{"id": "infinite_reload_range", "title": "无限装填攻击距离增加15", "summary": "无限装填攻击距离增加15", "requires_skill": "infinite_reload", "skill_progress_id": "gunner_infinite_reload"},
		{"id": "infinite_reload_cooldown", "title": "无限装填CD-15％", "summary": "无限装填CD-15％", "requires_skill": "infinite_reload", "skill_progress_id": "gunner_infinite_reload"},
		{"id": "ultimate_wave_count", "title": "火箭弹幕波次+3", "summary": "火箭弹幕波次+3", "card_title": "火箭弹幕", "skill_progress_id": "gunner_ultimate"},
		{"id": "unlock_shrapnel_field", "title": "获得技能：散弹", "summary": "获得技能：散弹", "unlock_skill": "shrapnel_field", "skill_progress_id": "gunner_shrapnel"},
		{"id": "unlock_infinite_reload", "title": "获得技能：无限装填", "summary": "获得技能：无限装填", "unlock_skill": "infinite_reload", "skill_progress_id": "gunner_infinite_reload"},
		{"id": "unlock_explosive_round", "title": "获得技能：爆破弹", "summary": "获得技能：爆破弹", "unlock_skill": "explosive_round", "skill_progress_id": "gunner_explosive_round"},
		{"id": "unlock_magic_grenade", "title": "获得技能：魔法榴弹", "summary": "获得技能：魔法榴弹", "unlock_skill": "magic_grenade", "skill_progress_id": "gunner_magic_grenade"},
		{"id": "unlock_magic_eye", "title": "获得技能：魔眼聚合", "summary": "获得技能：魔眼聚合", "unlock_skill": "magic_eye", "skill_progress_id": "gunner_magic_eye"}
	],
	"mage": [
		{"id": "arcane_surplus_duration", "title": "密集雷群·奥法盈余持续时间+1.5s", "summary": "登场技触发的奥法盈余持续时间+1.5s", "card_title": "密集雷群", "skill_progress_id": "mage_entry"},
		{"id": "arcane_charge_chance", "title": "奥数充能获取概率+3％", "summary": "奥数充能获取概率+3％", "card_title": "法师特性", "skill_progress_id": "mage_trait"},
		{"id": "arcane_charge_energy", "title": "奥数充能每层提供的大招回能效率+1.5％", "summary": "奥数充能每层提供的大招回能效率+1.5％", "card_title": "法师特性", "skill_progress_id": "mage_trait"},
		{"id": "arcane_charge_share", "title": "奥数充能每层提供的大招能量同步增加8％", "summary": "奥数充能每层提供的大招能量同步增加8％", "card_title": "法师特性", "skill_progress_id": "mage_trait"},
		{"id": "basic_attack_damage", "title": "法师普通攻击伤害倍率+20％", "summary": "法师普通攻击伤害倍率+20％", "card_title": "普通攻击", "skill_progress_id": "mage_basic"},
		{"id": "basic_attack_range", "title": "法师普通攻击范围增加8％", "summary": "法师普通攻击范围增加8％", "card_title": "普通攻击", "skill_progress_id": "mage_basic"},
		{"id": "meta_field_slow", "title": "梅塔领域造成的减速+8％", "summary": "梅塔领域造成的减速+8％", "requires_skill": "meta_field", "skill_progress_id": "mage_meta_field"},
		{"id": "meta_field_reduction_value", "title": "梅塔领域提供的减伤值+15", "summary": "梅塔领域提供的减伤值+15", "requires_skill": "meta_field", "skill_progress_id": "mage_meta_field"},
		{"id": "meta_field_radius", "title": "梅塔领域范围+8％", "summary": "梅塔领域范围+8％", "requires_skill": "meta_field", "skill_progress_id": "mage_meta_field"},
		{"id": "meta_field_damage", "title": "梅塔领域伤害倍率+3％", "summary": "梅塔领域伤害倍率+3％", "requires_skill": "meta_field", "skill_progress_id": "mage_meta_field"},
		{"id": "surging_wave_cooldown", "title": "波涛汹涌冷却时间-15％", "summary": "波涛汹涌冷却时间-15％", "requires_skill": "surging_wave", "skill_progress_id": "mage_surging_wave"},
		{"id": "surging_wave_damage", "title": "波涛汹涌伤害倍率+15％", "summary": "波涛汹涌伤害倍率+15％", "requires_skill": "surging_wave", "skill_progress_id": "mage_surging_wave"},
		{"id": "surging_wave_duration", "title": "波涛汹涌持续时+0.75s", "summary": "波涛汹涌持续时+0.75s", "requires_skill": "surging_wave", "skill_progress_id": "mage_surging_wave"},
		{"id": "surging_wave_speed", "title": "波涛汹涌移动速度+8", "summary": "波涛汹涌移动速度+8", "requires_skill": "surging_wave", "skill_progress_id": "mage_surging_wave"},
		{"id": "ultimate_bombard_count", "title": "奥数轰炸次数+3", "summary": "奥数轰炸次数+3", "card_title": "奥数轰炸", "skill_progress_id": "mage_ultimate"},
		{"id": "unlock_meta_field", "title": "获得技能：梅塔领域", "summary": "获得技能：梅塔领域", "unlock_skill": "meta_field", "skill_progress_id": "mage_meta_field"},
		{"id": "unlock_surging_wave", "title": "获得技能：波涛汹涌", "summary": "获得技能：波涛汹涌", "unlock_skill": "surging_wave", "skill_progress_id": "mage_surging_wave"},
		{"id": "unlock_flame_path", "title": "获得技能：火焰之径", "summary": "获得技能：火焰之径", "unlock_skill": "flame_path", "skill_progress_id": "mage_flame_path"},
		{"id": "unlock_dark_contract", "title": "获得技能：黑暗契约", "summary": "获得技能：黑暗契约", "unlock_skill": "dark_contract", "skill_progress_id": "mage_dark_contract"},
		{"id": "unlock_fireball", "title": "获得技能：火球术", "summary": "获得技能：火球术", "unlock_skill": "fireball", "skill_progress_id": "mage_fireball"}
	],
	"mechanic": [
		{"id": "trait_part_interval", "title": "战场改装零件产出间隔-0.5s", "summary": "战场改装零件产出间隔-0.5s", "card_title": "机械师特性", "skill_progress_id": "mechanic_trait"},
		{"id": "trait_part_damage", "title": "每个零件提供的召唤物伤害+2％", "summary": "每个零件提供的召唤物伤害+2％", "card_title": "机械师特性", "skill_progress_id": "mechanic_trait"},
		{"id": "trait_part_max", "title": "战场改装零件上限+2", "summary": "战场改装零件上限+2", "card_title": "机械师特性", "skill_progress_id": "mechanic_trait"},
		{"id": "entry_damage", "title": "紧急部署炮塔伤害倍率+15％", "summary": "紧急部署炮塔伤害倍率+15％", "card_title": "紧急部署", "skill_progress_id": "mechanic_entry"},
		{"id": "basic_attack_damage", "title": "机械师普通攻击伤害倍率+15％", "summary": "机械师普通攻击伤害倍率+15％", "card_title": "普通攻击", "skill_progress_id": "mechanic_basic"},
		{"id": "basic_attack_cooldown", "title": "机械师普通攻击冷却时间减少8％", "summary": "机械师普通攻击冷却时间减少8％", "card_title": "普通攻击", "skill_progress_id": "mechanic_basic"},
		{"id": "basic_attack_range", "title": "机械师普通攻击距离增加8％", "summary": "机械师普通攻击距离增加8％", "card_title": "普通攻击", "skill_progress_id": "mechanic_basic"},
		{"id": "drone_damage", "title": "守卫机器人抵挡次数+1", "summary": "守卫机器人抵挡次数+1", "requires_skill": "drone", "skill_progress_id": "mechanic_drone"},
		{"id": "drone_duration", "title": "守卫机器人同时存在上限+1", "summary": "守卫机器人同时存在上限+1", "requires_skill": "drone", "skill_progress_id": "mechanic_drone"},
		{"id": "mine_damage", "title": "感应地雷伤害倍率+15％", "summary": "感应地雷伤害倍率+15％", "requires_skill": "mine", "skill_progress_id": "mechanic_mine"},
		{"id": "mine_count", "title": "感应地雷数量+1", "summary": "感应地雷数量+1", "requires_skill": "mine", "skill_progress_id": "mechanic_mine"},
		{"id": "emp_damage", "title": "磁滞力场伤害倍率+25％", "summary": "磁滞力场伤害倍率+25％", "requires_skill": "emp_burst", "skill_progress_id": "mechanic_emp_burst"},
		{"id": "emp_cooldown", "title": "磁滞力场冷却时间-2s", "summary": "磁滞力场冷却时间-2s", "requires_skill": "emp_burst", "skill_progress_id": "mechanic_emp_burst"},
		{"id": "turret_damage", "title": "定点机炮伤害倍率+20％", "summary": "定点机炮伤害倍率+20％", "requires_skill": "tulip_turret", "skill_progress_id": "mechanic_tulip_turret"},
		{"id": "turret_duration", "title": "定点机炮持续时间+1s", "summary": "定点机炮持续时间+1s", "requires_skill": "tulip_turret", "skill_progress_id": "mechanic_tulip_turret"},
		{"id": "missile_damage", "title": "重型炮台伤害倍率+20％", "summary": "重型炮台伤害倍率+20％", "requires_skill": "missile_volley", "skill_progress_id": "mechanic_missile_volley"},
		{"id": "missile_count", "title": "重型炮台持续时间+2s", "summary": "重型炮台持续时间+2s", "requires_skill": "missile_volley", "skill_progress_id": "mechanic_missile_volley"},
		{"id": "ultimate_salvo_count", "title": "机械全开·郁金香齐射轮次+1", "summary": "机械全开·郁金香齐射轮次+1", "card_title": "机械全开·郁金香齐射", "skill_progress_id": "mechanic_ultimate"},
		{"id": "unlock_drone", "title": "获得技能：守卫机器人", "summary": "获得技能：守卫机器人", "unlock_skill": "drone", "skill_progress_id": "mechanic_drone"},
		{"id": "unlock_mine", "title": "获得技能：感应地雷", "summary": "获得技能：感应地雷", "unlock_skill": "mine", "skill_progress_id": "mechanic_mine"},
		{"id": "unlock_emp_burst", "title": "获得技能：磁滞力场", "summary": "获得技能：磁滞力场", "unlock_skill": "emp_burst", "skill_progress_id": "mechanic_emp_burst"},
		{"id": "unlock_tulip_turret", "title": "获得技能：定点机炮", "summary": "获得技能：定点机炮", "unlock_skill": "tulip_turret", "skill_progress_id": "mechanic_tulip_turret"},
		{"id": "unlock_missile_volley", "title": "获得技能：重型炮台", "summary": "获得技能：重型炮台", "unlock_skill": "missile_volley", "skill_progress_id": "mechanic_missile_volley"}
	]
}


static func build_offer_for_owner(owner, general_options: Array) -> Dictionary:
	var options: Array = []
	for slot_index in range(ROLE_SLOT_COUNT):
		var role_id := _get_role_id_at_slot(owner, slot_index)
		options.append(_pick_role_option(owner, role_id, slot_index))
	options.append(_pick_general_option(general_options))
	return {
		"options": options,
		"context": {
			"offer_mode": "build",
			"role_build_offer": true,
			"selection_count": 2,
			"refresh_limit": 0,
			"refresh_remaining": 0,
			"refresh_unlimited": false,
			"refresh_button_label": "",
			"summary": "从四张构筑中选择两张。"
		}
	}


static func pick_replacement_option(owner, current_options: Array, general_options: Array, option_index: int) -> Dictionary:
	var safe_index: int = max(0, option_index)
	var excluded_keys: Dictionary = _collect_offer_keys(current_options)
	if safe_index < ROLE_SLOT_COUNT:
		var role_id: String = _get_role_id_at_slot(owner, safe_index)
		return _pick_role_option_excluding(owner, role_id, safe_index, excluded_keys)
	return _pick_general_option_excluding(general_options, excluded_keys)


static func is_role_build_option_id(option_id: String) -> bool:
	return option_id.begins_with(OPTION_PREFIX)


static func apply_option(owner, option_id: String) -> bool:
	return not apply_option_with_result(owner, option_id).is_empty()


static func apply_option_with_result(owner, option_id: String) -> Dictionary:
	if owner == null or not is_role_build_option_id(option_id):
		return {}
	var payload := option_id.trim_prefix(OPTION_PREFIX).split(":")
	if payload.size() < 2:
		return {}
	var role_id := str(payload[0])
	var build_id := str(payload[1])
	var definition := get_definition(role_id, build_id)
	if definition.is_empty():
		return {}
	var unlock_skill := str(definition.get("unlock_skill", ""))
	if unlock_skill != "":
		if not PLAYER_BLESSING_SKILL_STATE.force_unlock_skill(owner, unlock_skill, 1):
			return {}
	else:
		_increment_build_count(owner, role_id, build_id)
	var display_data := _project_role_option(owner, {
		"role_id": role_id,
		"build_id": build_id,
		"skill_progress_id": str(definition.get("skill_progress_id", "")),
		"title": str(definition.get("title", build_id)),
		"summary": str(definition.get("summary", definition.get("title", build_id)))
	})
	var display_title := str(display_data.get("title", definition.get("title", build_id)))
	if owner.has_method("_spawn_combat_tag"):
		owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -62.0), display_title, Color(0.80, 0.92, 1.0, 1.0))
	return {
		"type": CATEGORY_ROLE_BUILD,
		"role_id": role_id,
		"build_id": build_id,
		"title": display_title,
		"unlock_skill": unlock_skill
	}


static func get_definition(role_id: String, build_id: String) -> Dictionary:
	for definition in _get_role_build_definitions(role_id):
		if str((definition as Dictionary).get("id", "")) == build_id:
			return (definition as Dictionary).duplicate(true)
	return {}


static func get_count(owner, role_id: String, build_id: String) -> int:
	var levels := _get_build_levels(owner, role_id)
	return max(0, int(levels.get(build_id, 0)))


static func get_progress_build_entries(owner, role_id: String, progress_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition_value in BUILD_DEFINITIONS.get(role_id, []):
		if definition_value is not Dictionary:
			continue
		var definition: Dictionary = definition_value
		if str(definition.get("skill_progress_id", "")) != progress_id or str(definition.get("unlock_skill", "")) != "":
			continue
		var build_id := str(definition.get("id", ""))
		var count := get_count(owner, role_id, build_id)
		if build_id == "" or count <= 0:
			continue
		var entry := definition.duplicate(true)
		entry["build_id"] = build_id
		entry["role_id"] = role_id
		entry["count"] = count
		result.append(entry)
	return result


static func get_basic_attack_damage_multiplier(owner, role_id: String) -> float:
	match role_id:
		"swordsman":
			return 1.0 + 0.15 * float(get_count(owner, role_id, "basic_attack_damage"))
		"gunner":
			return 1.0 + 0.15 * float(get_count(owner, role_id, "basic_attack_damage"))
		"mage":
			return 1.0 + 0.20 * float(get_count(owner, role_id, "basic_attack_damage"))
		"mechanic":
			return 1.0 + 0.15 * float(get_count(owner, role_id, "basic_attack_damage"))
	return 1.0


static func get_basic_attack_cooldown_multiplier(owner, role_id: String) -> float:
	match role_id:
		"swordsman":
			return _percent_reduction_multiplier(get_count(owner, role_id, "basic_attack_cooldown"), 0.15, 0.18)
		"gunner":
			return _percent_reduction_multiplier(get_count(owner, role_id, "basic_attack_cooldown"), 0.08, 0.18)
		"mechanic":
			return _percent_reduction_multiplier(get_count(owner, role_id, "basic_attack_cooldown"), 0.08, 0.18)
	return 1.0


static func get_basic_attack_range_multiplier(owner, role_id: String) -> float:
	match role_id:
		"swordsman":
			return 1.0 + 0.15 * float(get_count(owner, role_id, "basic_attack_range"))
		"mage":
			return 1.0 + 0.08 * float(get_count(owner, role_id, "basic_attack_range"))
		"mechanic":
			return 1.0 + 0.08 * float(get_count(owner, role_id, "basic_attack_range"))
	return 1.0


static func get_basic_attack_range_flat_bonus(owner, role_id: String) -> float:
	if role_id == "gunner":
		return 15.0 * float(get_count(owner, role_id, "basic_attack_range"))
	return 0.0


static func get_entry_damage_multiplier(owner, role_id: String) -> float:
	match role_id:
		"swordsman", "gunner":
			return 1.0 + 0.15 * float(get_count(owner, role_id, "entry_damage"))
		"mechanic":
			return 1.0 + 0.15 * float(get_count(owner, role_id, "entry_damage"))
	return 1.0


static func get_swordsman_trait_extra_rolls(owner) -> int:
	return 2 * get_count(owner, "swordsman", "trait_extra_roll")


static func get_swordsman_trait_heal_bonus(owner) -> float:
	return 0.02 * float(get_count(owner, "swordsman", "trait_heal_bonus"))


static func get_swordsman_knight_glory_duration_bonus(owner) -> float:
	return 0.3 * float(get_count(owner, "swordsman", "knight_glory_duration"))


static func get_swordsman_ultimate_damage_multiplier(owner) -> float:
	return 1.0 + 0.08 * float(get_count(owner, "swordsman", "ultimate_damage"))


static func get_blade_storm_damage_ratio_bonus(owner) -> float:
	return 0.025 * float(get_count(owner, "swordsman", "blade_storm_damage"))


static func get_blade_storm_radius_multiplier(owner) -> float:
	var area_bonus := 0.15 * float(get_count(owner, "swordsman", "blade_storm_area"))
	return sqrt(max(0.01, 1.0 + area_bonus))


static func get_blade_storm_cooldown_multiplier(owner) -> float:
	return _percent_reduction_multiplier(get_count(owner, "swordsman", "blade_storm_cooldown"), 0.08, 0.18)


static func get_crescent_wave_cooldown_multiplier(owner) -> float:
	return _percent_reduction_multiplier(get_count(owner, "swordsman", "crescent_wave_cooldown"), 0.15, 0.18)


static func get_crescent_wave_damage_ratio_bonus(owner) -> float:
	return 0.15 * float(get_count(owner, "swordsman", "crescent_wave_damage"))


static func get_crescent_wave_speed_bonus(owner) -> float:
	return 30.0 * float(get_count(owner, "swordsman", "crescent_wave_speed"))


static func get_gunner_hunt_safe_radius_bonus(owner) -> float:
	return -15.0 * float(get_count(owner, "gunner", "hunt_safe_radius"))


static func get_gunner_hunt_inside_damage_bonus(owner) -> float:
	return 0.20 * float(get_count(owner, "gunner", "hunt_inside_damage"))


static func get_gunner_hunt_outside_damage_bonus(owner) -> float:
	return 0.08 * float(get_count(owner, "gunner", "hunt_outside_damage"))


static func get_gunner_flash_damage_bonus_per_stack(owner) -> float:
	return 0.0075 * float(get_count(owner, "gunner", "flash_stack_bonus"))


static func get_gunner_flash_speed_bonus_per_stack(owner) -> float:
	return 0.0075 * float(get_count(owner, "gunner", "flash_stack_bonus"))


static func get_gunner_flash_dodge_bonus_per_stack(owner) -> float:
	return 30.0 * float(get_count(owner, "gunner", "flash_stack_bonus"))


static func get_shrapnel_cooldown_multiplier(owner) -> float:
	return _percent_reduction_multiplier(get_count(owner, "gunner", "shrapnel_cooldown"), 0.15, 0.18)


static func get_shrapnel_damage_ratio_bonus(owner) -> float:
	return 0.03 * float(get_count(owner, "gunner", "shrapnel_damage"))


static func get_shrapnel_radius_bonus(owner) -> float:
	return 15.0 * float(get_count(owner, "gunner", "shrapnel_radius"))


static func get_infinite_reload_move_speed_multiplier_bonus(owner) -> float:
	return 0.015 * float(get_count(owner, "gunner", "infinite_reload_speed"))


static func get_infinite_reload_damage_multiplier_bonus(owner) -> float:
	return 0.015 * float(get_count(owner, "gunner", "infinite_reload_damage"))


static func get_infinite_reload_range_bonus(owner) -> float:
	return 15.0 * float(get_count(owner, "gunner", "infinite_reload_range"))


static func get_infinite_reload_cooldown_multiplier(owner) -> float:
	return _percent_reduction_multiplier(get_count(owner, "gunner", "infinite_reload_cooldown"), 0.15, 0.18)


static func get_gunner_ultimate_wave_bonus(owner) -> int:
	return 3 * get_count(owner, "gunner", "ultimate_wave_count")


static func get_mage_arcane_surplus_duration_bonus(owner) -> float:
	return 1.5 * float(get_count(owner, "mage", "arcane_surplus_duration"))


static func get_mage_arcane_charge_proc_chance_bonus(owner) -> float:
	return 0.03 * float(get_count(owner, "mage", "arcane_charge_chance"))


static func get_mage_arcane_charge_energy_bonus_per_stack(owner) -> float:
	return 0.015 * float(get_count(owner, "mage", "arcane_charge_energy"))


static func get_mage_arcane_charge_share_bonus_per_stack(owner) -> float:
	return 0.08 * float(get_count(owner, "mage", "arcane_charge_share"))


static func get_mage_ultimate_bombard_count_bonus(owner) -> int:
	return 3 * get_count(owner, "mage", "ultimate_bombard_count")


static func get_meta_field_slow_bonus(owner) -> float:
	return 0.08 * float(get_count(owner, "mage", "meta_field_slow"))


static func get_meta_field_damage_reduction_value_bonus(owner) -> float:
	return 15.0 * float(get_count(owner, "mage", "meta_field_reduction_value"))


static func get_meta_field_radius_multiplier(owner) -> float:
	return 1.0 + 0.08 * float(get_count(owner, "mage", "meta_field_radius"))


static func get_meta_field_damage_ratio_bonus(owner) -> float:
	return 0.03 * float(get_count(owner, "mage", "meta_field_damage"))


static func get_surging_wave_cooldown_multiplier(owner) -> float:
	return _percent_reduction_multiplier(get_count(owner, "mage", "surging_wave_cooldown"), 0.15, 0.18)


static func get_surging_wave_damage_multiplier_bonus(owner) -> float:
	return 0.15 * float(get_count(owner, "mage", "surging_wave_damage"))


static func get_surging_wave_duration_bonus(owner) -> float:
	return 0.75 * float(get_count(owner, "mage", "surging_wave_duration"))


static func get_surging_wave_speed_bonus(owner) -> float:
	return 8.0 * float(get_count(owner, "mage", "surging_wave_speed"))


static func get_mechanic_part_interval_reduction(owner) -> float:
	return 0.5 * float(get_count(owner, "mechanic", "trait_part_interval"))


static func get_mechanic_part_damage_bonus(owner) -> float:
	return 0.02 * float(get_count(owner, "mechanic", "trait_part_damage"))


static func get_mechanic_part_max_bonus(owner) -> int:
	return 2 * get_count(owner, "mechanic", "trait_part_max")


static func get_mechanic_ultimate_salvo_bonus(owner) -> int:
	return get_count(owner, "mechanic", "ultimate_salvo_count")


static func get_mechanic_turret_damage_multiplier(owner) -> float:
	return 1.0 + 0.2 * float(get_count(owner, "mechanic", "turret_damage"))


static func get_mechanic_turret_duration_bonus(owner) -> float:
	return 1.0 * float(get_count(owner, "mechanic", "turret_duration"))


static func get_mechanic_mine_damage_multiplier(owner) -> float:
	return 1.0 + 0.15 * float(get_count(owner, "mechanic", "mine_damage"))


static func get_mechanic_mine_count_bonus(owner) -> int:
	return get_count(owner, "mechanic", "mine_count")


static func get_mechanic_field_damage_bonus_count(owner) -> int:
	return get_count(owner, "mechanic", "emp_damage")


static func get_mechanic_field_cooldown_reduction(owner) -> float:
	return 2.0 * float(get_count(owner, "mechanic", "emp_cooldown"))


static func get_mechanic_guard_block_bonus(owner) -> int:
	return get_count(owner, "mechanic", "drone_damage")


static func get_mechanic_guard_cap_bonus(owner) -> int:
	return get_count(owner, "mechanic", "drone_duration")


static func get_mechanic_cannon_damage_bonus_count(owner) -> int:
	return get_count(owner, "mechanic", "missile_damage")


static func get_mechanic_cannon_duration_bonus(owner) -> float:
	return 2.0 * float(get_count(owner, "mechanic", "missile_count"))


static func _pick_role_option(owner, role_id: String, role_slot_index: int) -> Dictionary:
	return _pick_role_option_excluding(owner, role_id, role_slot_index, {})


static func _pick_role_option_excluding(owner, role_id: String, role_slot_index: int, excluded_keys: Dictionary) -> Dictionary:
	var candidates := _build_role_options(owner, role_id, role_slot_index)
	if candidates.is_empty():
		return _make_blank_role_option(role_id, role_slot_index)
	var filtered: Array = _filter_options_by_excluded_keys(candidates, excluded_keys)
	var pool: Array = filtered if not filtered.is_empty() else candidates
	return _pick_weighted_role_option(pool)


static func _pick_weighted_role_option(options: Array) -> Dictionary:
	var skill_options: Array = []
	var non_skill_options: Array = []
	for option_value in options:
		if not option_value is Dictionary:
			continue
		var option: Dictionary = option_value
		if str(option.get("unlock_skill", "")) != "":
			skill_options.append(option)
		else:
			non_skill_options.append(option)

	if skill_options.is_empty():
		non_skill_options.shuffle()
		return non_skill_options[0]
	if non_skill_options.is_empty():
		skill_options.shuffle()
		return skill_options[0]

	if randf() < SKILL_OPTION_TOTAL_WEIGHT:
		skill_options.shuffle()
		return skill_options[0]
	non_skill_options.shuffle()
	return non_skill_options[0]


static func _build_role_options(owner, role_id: String, role_slot_index: int) -> Array:
	var options: Array = []
	for definition in _get_role_build_definitions(role_id):
		if not _is_definition_offerable(owner, definition):
			continue
		options.append(_make_role_option(owner, role_id, role_slot_index, definition))
	return options


static func _make_role_option(owner, role_id: String, role_slot_index: int, definition: Dictionary) -> Dictionary:
	var role_name := _get_role_name(owner, role_id)
	var build_id := str(definition.get("id", ""))
	var description := str(definition.get("description", definition.get("summary", "")))
	var unlock_skill := str(definition.get("unlock_skill", ""))
	var skill_id := _get_definition_skill_id(definition)
	var card_title := str(definition.get("card_title", ""))
	if card_title == "" and skill_id != "":
		card_title = PLAYER_BLESSING_SKILL_STATE.get_skill_title(skill_id)
	var build_card_scene := _get_definition_card_scene(build_id, definition, card_title)
	var shows_card_title := card_title != ""
	var option := {
		"id": "%s%s:%s" % [OPTION_PREFIX, role_id, build_id],
		"offer_key": "%s:%s" % [role_id, build_id],
		"option_category": CATEGORY_ROLE_BUILD,
		"slot": "role_slot_%d" % (role_slot_index + 1),
		"slot_label": role_name,
		"role_slot_index": role_slot_index,
		"role_id": role_id,
		"role_name": role_name,
		"build_id": build_id,
		"skill_progress_id": str(definition.get("skill_progress_id", "")),
		"title": str(definition.get("title", build_id)),
		"summary": str(definition.get("summary", description)),
		"short_description": str(definition.get("summary", description)),
		"description": description,
		"preview_description": description,
		"detail_description": description,
		"exact_description": description,
		"card_title": card_title,
		"hide_card_title": not shows_card_title,
		"unlock_skill": unlock_skill,
		"build_card_scene": build_card_scene,
		"blessing_tier": 1,
		"evolved": false
	}
	return _project_role_option(owner, option)


static func _project_role_option(owner, option: Dictionary) -> Dictionary:
	if owner != null and owner.has_method("_project_skill_talent_build_option"):
		return owner._project_skill_talent_build_option(option)
	return option


static func _pick_general_option(general_options: Array) -> Dictionary:
	return _pick_general_option_excluding(general_options, {})


static func _pick_general_option_excluding(general_options: Array, excluded_keys: Dictionary) -> Dictionary:
	var options: Array = []
	for raw_option in general_options:
		if raw_option is Dictionary:
			options.append((raw_option as Dictionary).duplicate(true))
	if options.is_empty():
		return _make_blank_general_option()
	var filtered: Array = _filter_options_by_excluded_keys(options, excluded_keys)
	var pool: Array = filtered if not filtered.is_empty() else options
	pool.shuffle()
	var option: Dictionary = pool[0]
	option["slot"] = "general"
	option["slot_label"] = "通用"
	return option


static func _make_blank_role_option(role_id: String, role_slot_index: int) -> Dictionary:
	var role_name := _get_role_name(null, role_id)
	return {
		"id": "role_build_blank:%s:%d" % [role_id, role_slot_index],
		"option_category": CATEGORY_ROLE_BUILD,
		"slot": "role_slot_%d" % (role_slot_index + 1),
		"slot_label": role_name,
		"role_slot_index": role_slot_index,
		"role_id": role_id,
		"title": "%s暂无可选构筑" % role_name,
		"summary": "继续战斗",
		"short_description": "继续战斗",
		"description": "当前没有可选构筑。",
		"preview_description": "当前没有可选构筑。",
		"detail_description": "当前没有可选构筑。",
		"exact_description": "当前没有可选构筑。",
		"hide_card_title": true,
		"blessing_tier": 1
	}


static func _make_blank_general_option() -> Dictionary:
	return {
		"id": "role_build_blank_general",
		"slot": "general",
		"slot_label": "通用",
		"title": "暂无通用构筑",
		"summary": "继续战斗",
		"short_description": "继续战斗",
		"description": "当前没有可选通用构筑。",
		"preview_description": "当前没有可选通用构筑。",
		"detail_description": "当前没有可选通用构筑。",
		"exact_description": "当前没有可选通用构筑。",
		"blessing_tier": 1
	}


static func _is_definition_offerable(owner, definition: Dictionary) -> bool:
	var unlock_skill := str(definition.get("unlock_skill", ""))
	if unlock_skill != "":
		return not _is_skill_unlocked(owner, unlock_skill)
	var required_skill := str(definition.get("requires_skill", ""))
	if required_skill != "" and not _is_skill_unlocked(owner, required_skill):
		return false
	return true


static func _get_definition_skill_id(definition: Dictionary) -> String:
	var unlock_skill := str(definition.get("unlock_skill", ""))
	if unlock_skill != "":
		return unlock_skill
	return str(definition.get("requires_skill", ""))


static func _filter_options_by_excluded_keys(options: Array, excluded_keys: Dictionary) -> Array:
	var filtered: Array = []
	for option in options:
		if option is not Dictionary:
			continue
		var option_key: String = _get_option_offer_key(option)
		if option_key == "" or excluded_keys.has(option_key):
			continue
		filtered.append(option)
	return filtered


static func _collect_offer_keys(options: Array) -> Dictionary:
	var result := {}
	for option in options:
		if option is not Dictionary:
			continue
		var option_key: String = _get_option_offer_key(option)
		if option_key != "":
			result[option_key] = true
	return result


static func _get_option_offer_key(option: Dictionary) -> String:
	return str(option.get("offer_key", option.get("id", "")))


static func _get_definition_card_scene(build_id: String, definition: Dictionary, card_title: String) -> String:
	if str(definition.get("unlock_skill", "")) != "":
		return "magicstone"
	if str(definition.get("requires_skill", "")) != "":
		return "stone"
	if build_id == "entry_damage":
		return "stone"
	if build_id == "ultimate_damage" or build_id.begins_with("ultimate_"):
		return "stone"
	if card_title.ends_with("特性"):
		return "stone"
	return ""


static func _is_skill_unlocked(owner, skill_id: String) -> bool:
	return PLAYER_BLESSING_SKILL_STATE.is_skill_unlocked(owner, skill_id)


static func _get_role_build_definitions(role_id: String) -> Array:
	var definitions: Array = BUILD_DEFINITIONS.get(role_id, [])
	var result: Array = []
	for definition in definitions:
		if definition is Dictionary:
			result.append((definition as Dictionary).duplicate(true))
	return result


static func _get_role_id_at_slot(owner, slot_index: int) -> String:
	if owner != null and owner.get("roles") is Array:
		var roles: Array = owner.get("roles")
		if slot_index >= 0 and slot_index < roles.size() and roles[slot_index] is Dictionary:
			return str((roles[slot_index] as Dictionary).get("id", ""))
	var fallback_ids := ROLE_DATABASE.get_role_ids()
	if slot_index >= 0 and slot_index < fallback_ids.size():
		return str(fallback_ids[slot_index])
	return ""


static func _get_role_name(owner, role_id: String) -> String:
	if owner != null and owner.get("roles") is Array:
		for role_data in owner.get("roles"):
			if role_data is Dictionary and str((role_data as Dictionary).get("id", "")) == role_id:
				return str((role_data as Dictionary).get("name", role_id))
	var database_role := ROLE_DATABASE.get_role_data_by_id(role_id)
	return str(database_role.get("name", role_id))


static func _get_build_levels(owner, role_id: String) -> Dictionary:
	if owner == null or role_id == "":
		return {}
	if not _owner_has_property(owner, "role_special_states"):
		return {}
	_ensure_role_special_state(owner, role_id)
	var special_data: Dictionary = owner.role_special_states[role_id]
	if not special_data.has(BUILD_LEVELS_KEY) or special_data.get(BUILD_LEVELS_KEY) is not Dictionary:
		special_data[BUILD_LEVELS_KEY] = {}
		owner.role_special_states[role_id] = special_data
	return special_data[BUILD_LEVELS_KEY]


static func _increment_build_count(owner, role_id: String, build_id: String) -> void:
	if owner == null or not _owner_has_property(owner, "role_special_states"):
		return
	var levels := _get_build_levels(owner, role_id)
	levels[build_id] = int(levels.get(build_id, 0)) + 1
	var special_data: Dictionary = owner.role_special_states[role_id]
	special_data[BUILD_LEVELS_KEY] = levels
	owner.role_special_states[role_id] = special_data


static func _ensure_role_special_state(owner, role_id: String) -> void:
	if owner == null:
		return
	if not _owner_has_property(owner, "role_special_states"):
		return
	if owner.get("role_special_states") is not Dictionary:
		owner.role_special_states = {}
	if not owner.role_special_states.has(role_id) or owner.role_special_states[role_id] is not Dictionary:
		owner.role_special_states[role_id] = {}


static func _owner_has_property(owner, property_name: String) -> bool:
	if owner == null:
		return false
	for property in owner.get_property_list():
		if property is Dictionary and str((property as Dictionary).get("name", "")) == property_name:
			return true
	return false


static func _percent_reduction_multiplier(count: int, per_stack: float, minimum: float) -> float:
	return max(minimum, 1.0 - max(0.0, float(count)) * per_stack)
