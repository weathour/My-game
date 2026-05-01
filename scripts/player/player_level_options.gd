extends RefCounted

static func build_attribute_upgrade_options(
	swordsman_next_level: float,
	gunner_next_level: float,
	mage_next_level: float,
	swordsman_description: String,
	gunner_description: String,
	mage_description: String,
	team_description: String,
	swordsman_evolved: bool = false,
	gunner_evolved: bool = false,
	mage_evolved: bool = false,
	team_evolved: bool = false,
	evolved_color: Color = Color(0.38, 1.0, 0.48, 1.0)
) -> Array:
	return [
		{
			"id": "level_trait_swordsman",
			"title": "剑士特性 Lv.%s" % _format_level(swordsman_next_level),
			"description": swordsman_description,
			"evolved": swordsman_evolved,
			"title_color": evolved_color
		},
		{
			"id": "level_trait_gunner",
			"title": "枪手特性 Lv.%s" % _format_level(gunner_next_level),
			"description": gunner_description,
			"evolved": gunner_evolved,
			"title_color": evolved_color
		},
		{
			"id": "level_trait_mage",
			"title": "术师特性 Lv.%s" % _format_level(mage_next_level),
			"description": mage_description,
			"evolved": mage_evolved,
			"title_color": evolved_color
		},
		{
			"id": "level_trait_team",
			"title": "共同致富",
			"description": team_description,
			"evolved": team_evolved,
			"title_color": evolved_color
		}
	]

static func get_final_core_options() -> Array:
	return [
		{
			"id": "final_blank_upgrade",
			"title": "结束本局",
			"description": "最终 Boss 已击败。确认后进入胜利结算。",
			"preview_description": "确认胜利并完成本局。",
			"exact_description": "这是结算确认选项，不提供额外战斗加成。"
		}
	]

static func _format_level(level: float) -> String:
	if is_equal_approx(level, roundf(level)):
		return str(int(roundf(level)))
	return "%.1f" % level
