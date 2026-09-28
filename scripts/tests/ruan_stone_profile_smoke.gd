extends SceneTree

const PROFILE_DEFAULTS := preload("res://scripts/save/save_profile_defaults.gd")
const RUAN_STONES := preload("res://scripts/player/ruan_stone_system.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile := PROFILE_DEFAULTS.ensure_endless_profile_defaults({
		"difficulty": "normal",
		"legacy_field": "kept",
		"bones": -4,
		"ruan_stone_levels": {"thunder": 2, "frost": -3, "unknown": 99},
		"equipped_ruan_stone": "frost"
	}, 2)
	_expect(profile.get("legacy_field") == "kept", "旧档案字段未保留。")
	_expect(not profile.has("difficulty"), "旧四难度字段仍被保留。")
	_expect(profile.get("highest_cleared_tier") == 0 and profile.get("selected_tier") == 1, "N 层进度默认值错误。")
	_expect(profile.get("bones") == 0, "骨头数量未归一化。")
	_expect(profile.get("equipped_ruan_stone") == "", "未拥有的石头仍被装备。")
	var levels: Dictionary = profile.get("ruan_stone_levels", {})
	_expect(levels.is_empty(), "旧石头等级字段应被清理（携带数量由已携带列表决定）。")
	_expect(RUAN_STONES.get_carry_limit(profile) == 1, "N1 的携带上限应为 1。")
	_expect(RUAN_STONES.get_next_cost(profile, "thunder") == 5, "购买费用应为固定 5 骨。")
	profile["bones"] = 4
	var denied := RUAN_STONES.purchase(profile, "thunder")
	_expect(not bool(denied.get("success", false)) and profile.get("bones") == 4, "骨头不足时仍完成了购买。")
	profile["bones"] = 10
	var purchased := RUAN_STONES.purchase(profile, "thunder")
	_expect(bool(purchased.get("success", false)) and RUAN_STONES.get_count(profile, "thunder") == 1, "购买未记录携带份数。")
	_expect(profile.get("bones") == 5 and RUAN_STONES.get_carried_count(profile) == 1, "购买未扣费或未占用携带位。")
	var blocked := RUAN_STONES.purchase(profile, "thunder")
	_expect(str(blocked.get("reason", "")) == "carry_limit_reached", "达到携带上限后仍可购买。")
	profile["highest_cleared_tier"] = 2
	_expect(RUAN_STONES.get_carry_limit(profile) == 3, "携带上限应等于档案最高解锁 N。")
	var purchased_again := RUAN_STONES.purchase(profile, "thunder")
	_expect(bool(purchased_again.get("success", false)) and RUAN_STONES.get_count(profile, "thunder") == 2, "重复购买未累计同一物件。")
	_expect(is_equal_approx(float(RUAN_STONES.get_stacked_effect_values("thunder", 2).get("damage_ratio", 0.0)), 0.60), "重复携带未按加法叠加。")
	_expect(RUAN_STONES.equip(profile, "thunder"), "拥有后无法装备。")
	_expect(not RUAN_STONES.equip(profile, "poison") and RUAN_STONES.get_equipped(profile) == "thunder", "未拥有石头可装备或失败装备覆盖当前选择。")
	_expect(RUAN_STONES.get_effect_text("flame", 1).contains("最大生命8%"), "炎石效果文本错误。")
	_expect(RUAN_STONES.get_effect_text("fury", 1).contains("护甲降低5点"), "烈石效果文本错误。")
	_expect(RUAN_STONES.get_definition("ground_branch").get("summary", "").contains("攻击速度 +5%") and RUAN_STONES.get_definition("ground_branch").get("summary", "").contains("攻击力 +2"), "地上的树枝文案错误。")
	_expect(is_equal_approx(float(RUAN_STONES.get_effect_values("ground_branch", 1).get("attack_speed_percent", 0.0)), 0.05) and is_equal_approx(float(RUAN_STONES.get_effect_values("ground_branch", 1).get("attack_bonus", 0.0)), 2.0), "地上的树枝数值错误。")
	_expect(RUAN_STONES.get_definition("broken_chestplate").get("summary", "").contains("减伤 +3%") and is_equal_approx(float(RUAN_STONES.get_effect_values("broken_chestplate", 1).get("damage_reduction_rate", 0.0)), 0.03), "残破胸甲数值或文案错误。")
	_expect(RUAN_STONES.STONE_IDS.has("failed_assassin_dagger"), "失败刺客的短匕未登记到阮狗商店。")
	_expect(RUAN_STONES.get_definition("failed_assassin_dagger").get("title", "") == "失败刺客的短匕", "失败刺客的短匕名称错误。")
	_expect(RUAN_STONES.get_effect_text("failed_assassin_dagger", 1).contains("移动速度 +2%") and RUAN_STONES.get_effect_text("failed_assassin_dagger", 1).contains("攻击速度 +3%"), "失败刺客的短匕效果文本错误。")
	var dagger_values := RUAN_STONES.get_stacked_effect_values("failed_assassin_dagger", 2)
	_expect(is_equal_approx(float(dagger_values.get("move_speed_percent", 0.0)), 0.04) and is_equal_approx(float(dagger_values.get("attack_speed_percent", 0.0)), 0.06), "失败刺客的短匕重复携带未按份数叠加。")
	# 取消购买（退款）：逐件移除并退还骨头，退到 0 后不再可退
	_expect(int(profile.get("bones", 0)) == 0, "退款前骨头数量不符合预期。")
	var refunded := RUAN_STONES.refund(profile, "thunder")
	_expect(bool(refunded.get("success", false)) and RUAN_STONES.get_count(profile, "thunder") == 1, "取消购买未移除一件携带。")
	_expect(int(refunded.get("refunded", 0)) == 5 and int(profile.get("bones", 0)) == 5, "取消购买未退还骨头。")
	var refund_again := RUAN_STONES.refund(profile, "thunder")
	_expect(bool(refund_again.get("success", false)) and RUAN_STONES.get_count(profile, "thunder") == 0, "重复取消购买未逐件移除。")
	_expect(int(profile.get("bones", 0)) == 10, "逐件退款未累计退还骨头。")
	_expect(not bool(RUAN_STONES.refund(profile, "thunder").get("success", false)), "未携带的物件仍可退款。")
	if failures.is_empty():
		print("RUAN_STONE_PROFILE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
