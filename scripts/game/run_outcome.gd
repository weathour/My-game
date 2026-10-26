extends RefCounted

const ROLES := preload("res://scripts/player/player_role_presenter.gd")

static func capture(main: Node, outcome: String) -> Dictionary:
	var team: Array = []
	for role: Dictionary in main.player.roles:
		team.append(str(role.id))
	var equipment_count := 0
	for equipped: Dictionary in main.player.role_equipment_levels.values():
		for level in equipped.values():
			if int(level) > 0:
				equipment_count += 1
	var points := 0
	for value in main.player.get_team_skill_points().values():
		points += int(value)
	var wave = main.get("wave_flow")
	return {"outcome": outcome, "run_id": main.endless_run_id, "tier": main.endless_tier if main.endless_mode_active else 0,
		"wave": wave.wave if is_instance_valid(wave) else 0, "stage_id": main.story_stage.get("id", ""),
		"seconds": main.survival_time, "level": main.player.level, "team": team,
		"equipment_count": equipment_count, "unspent_points": points}

static func describe(summary: Dictionary) -> String:
	if summary.is_empty():
		return ""
	var seconds := int(summary.get("seconds", 0))
	var names := PackedStringArray()
	for role in summary.get("team", []):
		names.append(ROLES.get_role_name(str(role)))
	var wave := "第%d波 · " % int(summary.wave) if int(summary.get("wave", 0)) > 0 else ""
	return "%s%02d:%02d · 本局等级 %d\n队伍：%s\n角色装备 %d 件 · 未分配技能点合计 %d" % [wave, seconds / 60, seconds % 60, int(summary.get("level", 1)), " / ".join(names), int(summary.get("equipment_count", 0)), int(summary.get("unspent_points", 0))]
