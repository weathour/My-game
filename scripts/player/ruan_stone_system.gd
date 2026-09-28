extends RefCounted

const STONE_THUNDER := "thunder"
const STONE_FROST := "frost"
const STONE_POISON := "poison"
const STONE_FLAME := "flame"
const STONE_FURY := "fury"
const FAILED_ASSASSIN_DAGGER := "failed_assassin_dagger"
const STONE_IDS := [STONE_THUNDER, STONE_FROST, STONE_FURY, STONE_FLAME, "useless_pendant", "broken_sword", "keen_fragment", "tattered_cloak", "ground_branch", "guild_token", "broken_magic_stone", "rusted_dagger", "used_potion", "broken_chestplate", "unknown_spellbook", FAILED_ASSASSIN_DAGGER]

const DEFINITIONS := {
	STONE_THUNDER: {"title": "雷石", "summary": "普攻触发电流连锁。"},
	STONE_FROST: {"title": "冰石", "summary": "普攻大幅减速敌人。"},
	STONE_POISON: {"title": "毒石", "summary": "普攻附加持续毒伤。"},
	STONE_FLAME: {"title": "炎石", "summary": "普攻击杀敌人时引爆尸骸。"},
	STONE_FURY: {"title": "烈石", "summary": "普攻使目标护甲降低5点，持续2秒；重复命中刷新时间。"}
	,"broken_sword": {"title": "冒险者破剑", "summary": "攻击力 +2，增伤 +2%。"}
	,"keen_fragment": {"title": "基恩碎片", "summary": "远程攻击距离 +25，近战攻击范围 +25%。"}
	,"tattered_cloak": {"title": "残破披风", "summary": "移动速度 +10，闪避率 +10%（每件独立计算）。"}
	,"ground_branch": {"title": "地上的树枝", "summary": "攻击速度 +5%，攻击力 +2。"}
	,"guild_token": {"title": "工会令牌碎片", "summary": "每 10 秒回复 20 点生命。"}
	,"broken_magic_stone": {"title": "残破的魔石", "summary": "经验获取效率 +10%。"}
	,"rusted_dagger": {"title": "生锈的匕首", "summary": "暴击率 +8%，暴击伤害 +8%。"}
	,"used_potion": {"title": "喝过的魔瓶", "summary": "每秒恢复 1 点生命和 1 点大招能量。"}
	,"broken_chestplate": {"title": "残破胸甲", "summary": "生命 +30，减伤 +3%。"}
	,"unknown_spellbook": {"title": "不知名魔法书残页", "summary": "大招伤害 +20%，其他技能冷却减少 5%。"}
	,"useless_pendant": {"title": "无用挂件", "summary": "每秒回复1点大招能量，大招伤害增加10%。"}
	,FAILED_ASSASSIN_DAGGER: {"title": "失败刺客的短匕", "summary": "移动速度 +2%，攻击速度 +3%。"}
}


static func normalize_profile(profile: Dictionary) -> Dictionary:
	profile["bones"] = _non_negative_int(profile.get("bones", 0))
	var source_purchased: Variant = profile.get("ruan_stone_purchased", [])
	var purchased: Array = source_purchased.duplicate() if source_purchased is Array else []
	var normalized_purchased: Array = []
	for stone_id in purchased:
		# 允许重复购买：同一个物件可以携带多份，效果按数量加法叠加
		if STONE_IDS.has(str(stone_id)):
			normalized_purchased.append(str(stone_id))
	profile["ruan_stone_purchased"] = normalized_purchased
	profile["ruan_stone_levels"] = {}
	# 保留仍然有效的装备展示字段；未拥有或不存在的装备被清空
	var equipped := str(profile.get("equipped_ruan_stone", ""))
	profile["equipped_ruan_stone"] = equipped if (STONE_IDS.has(equipped) and normalized_purchased.has(equipped)) else ""
	return profile


static func get_carry_limit(profile: Dictionary) -> int:
	# 携带上限 = 档案最高解锁 N（初始 N1 带 1 件，通关 N1 解锁 N2 后可带 2 件，以此类推）
	return max(1, int(profile.get("highest_cleared_tier", 0)) + 1)


static func get_carried_count(profile: Dictionary) -> int:
	var purchased: Variant = profile.get("ruan_stone_purchased", [])
	return (purchased as Array).size() if purchased is Array else 0


static func get_count(profile: Dictionary, stone_id: String) -> int:
	if not STONE_IDS.has(stone_id):
		return 0
	var purchased: Variant = profile.get("ruan_stone_purchased", [])
	if not (purchased is Array):
		return 0
	var count := 0
	for stone_value in purchased as Array:
		if str(stone_value) == stone_id:
			count += 1
	return count


static func get_definition(stone_id: String) -> Dictionary:
	return (DEFINITIONS.get(stone_id, {}) as Dictionary).duplicate(true)


static func get_level(profile: Dictionary, stone_id: String) -> int:
	# 兼容旧调用：等级即“已携带份数”
	return get_count(profile, stone_id)


static func get_next_cost(profile: Dictionary, stone_id: String) -> int:
	if not STONE_IDS.has(stone_id):
		return 0
	return 5


static func purchase(profile: Dictionary, stone_id: String) -> Dictionary:
	normalize_profile(profile)
	if not STONE_IDS.has(stone_id):
		return {"success": false, "reason": "invalid_stone"}
	var purchased: Array = profile.get("ruan_stone_purchased", [])
	var carry_limit := get_carry_limit(profile)
	var cost := get_next_cost(profile, stone_id)
	var bones := int(profile.get("bones", 0))
	if purchased.size() >= carry_limit:
		return {
			"success": false,
			"reason": "carry_limit_reached",
			"cost": cost,
			"bones": bones,
			"carry_limit": carry_limit,
			"carried": purchased.size()
		}
	if bones < cost:
		return {"success": false, "reason": "not_enough_bones", "cost": cost, "bones": bones}
	profile["bones"] = bones - cost
	purchased.append(stone_id)
	profile["ruan_stone_purchased"] = purchased
	return {
		"success": true,
		"stone_id": stone_id,
		"cost": cost,
		"count": get_count(profile, stone_id),
		"carried": purchased.size(),
		"carry_limit": carry_limit,
		"bones": int(profile["bones"])
	}


static func refund(profile: Dictionary, stone_id: String) -> Dictionary:
	normalize_profile(profile)
	if not STONE_IDS.has(stone_id):
		return {"success": false, "reason": "invalid_stone"}
	var purchased: Array = profile.get("ruan_stone_purchased", [])
	if get_count(profile, stone_id) <= 0:
		return {"success": false, "reason": "not_carried", "bones": int(profile.get("bones", 0))}
	for index in range(purchased.size() - 1, -1, -1):
		if str(purchased[index]) == stone_id:
			purchased.remove_at(index)
			break
	var cost := get_next_cost(profile, stone_id)
	profile["bones"] = int(profile.get("bones", 0)) + cost
	if get_count(profile, stone_id) <= 0 and str(profile.get("equipped_ruan_stone", "")) == stone_id:
		profile["equipped_ruan_stone"] = ""
	return {
		"success": true,
		"stone_id": stone_id,
		"refunded": cost,
		"count": get_count(profile, stone_id),
		"carried": purchased.size(),
		"carry_limit": get_carry_limit(profile),
		"bones": int(profile["bones"])
	}


static func equip(profile: Dictionary, stone_id: String) -> bool:
	normalize_profile(profile)
	if get_level(profile, stone_id) <= 0:
		return false
	profile["equipped_ruan_stone"] = stone_id
	return true


static func get_equipped(profile: Dictionary) -> String:
	var equipped := str(profile.get("equipped_ruan_stone", ""))
	return equipped if STONE_IDS.has(equipped) and get_level(profile, equipped) > 0 else ""


static func get_stacked_effect_values(stone_id: String, count: int) -> Dictionary:
	var base := get_effect_values(stone_id, 1)
	if count <= 1 or base.is_empty():
		return base
	return _scale_effect_values(stone_id, base, count)


static func _scale_effect_values(stone_id: String, base: Dictionary, count: int) -> Dictionary:
	var scaled: Dictionary = base.duplicate(true)
	match stone_id:
		STONE_THUNDER:
			scaled["damage_ratio"] = float(base.get("damage_ratio", 0.0)) * float(count)
			scaled["jump_count"] = min(5, int(base.get("jump_count", 1)) * count)
		STONE_FROST:
			scaled["slow_ratio"] = min(0.75, float(base.get("slow_ratio", 0.0)) * float(count))
		STONE_POISON:
			scaled["total_damage_ratio"] = float(base.get("total_damage_ratio", 0.0)) * float(count)
		STONE_FLAME:
			scaled["damage_ratio"] = float(base.get("damage_ratio", 0.0)) * float(count)
		STONE_FURY:
			scaled["armor_shred"] = float(base.get("armor_shred", 0.0)) * float(count)
		_:
			# 属性/百分比类物件：所有增量按数量线性相加
			for key_value in base.keys():
				var key := str(key_value)
				var value: Variant = base[key_value]
				if not (value is float or value is int):
					continue
				var number := float(value)
				if key == "cooldown_multiplier":
					scaled[key] = max(0.05, 1.0 - (1.0 - number) * float(count))
				elif key.ends_with("_multiplier"):
					scaled[key] = 1.0 + (number - 1.0) * float(count)
				else:
					scaled[key] = number * float(count)
	return scaled


static func get_effect_values(stone_id: String, level: int) -> Dictionary:
	var safe_level: int = max(1, level)
	var upgrades: int = safe_level - 1
	match stone_id:
		STONE_THUNDER:
			return {
				"damage_ratio": 0.30 + 0.03 * upgrades,
				"jump_count": min(5, 1 + floori(float(safe_level) / 5.0))
			}
		STONE_FROST:
			return {
				"slow_ratio": min(0.75, 0.45 + 0.015 * upgrades),
				"duration": 1.2 + 0.08 * upgrades
			}
		STONE_POISON:
			return {
				"total_damage_ratio": 0.45 + 0.07 * upgrades,
				"duration": 3.0,
				"max_stacks": 3
			}
		STONE_FLAME:
			return {
				"damage_ratio": 0.08 + 0.005 * upgrades,
				"radius": 260.0
			}
		STONE_FURY:
			return {
				"armor_shred": 5.0,
				"duration": 2.0
			}
		"broken_sword": return {"attack_bonus": 2.0, "damage_bonus": 0.02}
		"keen_fragment": return {"range_bonus": 25.0, "melee_range_multiplier": 1.25}
		"tattered_cloak": return {"speed_bonus": 10.0, "dodge_chance": 0.10}
		"ground_branch": return {"attack_speed_percent": 0.05, "attack_bonus": 2.0}
		"guild_token": return {"heal_interval": 10.0, "heal_amount": 20.0}
		"broken_magic_stone": return {"experience_multiplier": 1.10}
		"rusted_dagger": return {"critical_chance_bonus": 0.08, "critical_damage_bonus": 0.08}
		"used_potion": return {"heal_per_second": 1.0, "energy_per_second": 1.0}
		"broken_chestplate": return {"max_health_bonus": 30.0, "damage_reduction_rate": 0.03}
		"unknown_spellbook": return {"ultimate_damage_bonus": 0.20, "cooldown_multiplier": 0.95}
		"useless_pendant": return {"energy_per_second": 1.0, "ultimate_damage_bonus": 0.10}
		FAILED_ASSASSIN_DAGGER: return {"move_speed_percent": 0.02, "attack_speed_percent": 0.03}
	return {}


static func get_carried_summary_text(purchased: Array) -> String:
	var counts: Dictionary = {}
	for stone_value in purchased:
		var stone_id := str(stone_value)
		if not STONE_IDS.has(stone_id):
			continue
		counts[stone_id] = int(counts.get(stone_id, 0)) + 1
	if counts.is_empty():
		return "未携带"
	var parts: Array[String] = []
	for stone_id_value in STONE_IDS:
		var stone_id := str(stone_id_value)
		if not counts.has(stone_id):
			continue
		var title := str((DEFINITIONS.get(stone_id, {}) as Dictionary).get("title", stone_id))
		parts.append("%s×%d" % [title, int(counts[stone_id])])
	return "、".join(parts)


static func get_effect_text(stone_id: String, level: int) -> String:
	if level <= 0 or not STONE_IDS.has(stone_id):
		return "未拥有"
	var values := get_stacked_effect_values(stone_id, level)
	match stone_id:
		STONE_THUNDER:
			return "连锁%d个目标，造成%s%%伤害" % [int(values["jump_count"]), _percent(values["damage_ratio"])]
		STONE_FROST:
			return "减速%s%%，持续%s秒" % [_percent(values["slow_ratio"]), _decimal(values["duration"])]
		STONE_POISON:
			return "3秒造成%s%%毒伤，最多3层" % _percent(values["total_damage_ratio"])
		STONE_FLAME:
			return "普攻击杀爆炸：%d范围，造成死者最大生命%s%%伤害" % [int(values["radius"]), _percent(values["damage_ratio"])]
		STONE_FURY:
			return "普攻使目标护甲降低%s点，持续%s秒；重复命中刷新时间" % [_number(values["armor_shred"]), _decimal(values["duration"])]
		FAILED_ASSASSIN_DAGGER:
			return "移动速度 +%s%%，攻击速度 +%s%%" % [_percent(values["move_speed_percent"]), _percent(values["attack_speed_percent"])]
	return ""


static func get_next_effect_text(profile: Dictionary, stone_id: String) -> String:
	if not STONE_IDS.has(stone_id):
		return ""
	return get_effect_text(stone_id, get_level(profile, stone_id) + 1)


static func _non_negative_int(value: Variant) -> int:
	if value is int or value is float or value is bool or value is String:
		return max(0, int(value))
	return 0


static func _percent(ratio: float) -> String:
	return _number(ratio * 100.0)


static func _decimal(value: float) -> String:
	return _number(value)


static func _number(value: float) -> String:
	var rounded := snappedf(value, 0.01)
	if is_equal_approx(rounded, roundf(rounded)):
		return str(int(roundf(rounded)))
	return ("%.2f" % rounded).trim_suffix("0")
