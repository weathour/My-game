extends SceneTree

const CHARACTER_PANEL := preload("res://scripts/ui/hud/character_panel.gd")
const PLAYER_STAT_PAYLOAD := preload("res://scripts/player/player_stat_payload.gd")
const SHEET := preload("res://scripts/player/player_character_sheet.gd")

var failures: Array[String] = []


class StoneOwner:
	extends Node

	func get_ruan_bone_count() -> int:
		return 17

	func get_ruan_stone_carried_count() -> int:
		return 3

	func get_ruan_stone_carry_limit() -> int:
		return 5

	func get_ruan_stone_carry_summary() -> String:
		return "雷石×3"

	func get_ruan_stone_level(stone_id: String) -> int:
		return 3 if stone_id == "thunder" else 0

	func get_equipped_ruan_stone() -> String:
		return "thunder"

	func _get_role_equipment_levels(_role_id: String) -> Dictionary:
		return {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner := StoneOwner.new()
	root.add_child(owner)
	var projection := PLAYER_STAT_PAYLOAD._build_ruan_stone_summary(owner)
	_expect(projection.get("ruan_bone_count") == 17, "统计投影未包含骨头数量。")
	_expect(projection.get("ruan_stone_carried_count") == 3 and projection.get("ruan_stone_carry_limit") == 5, "统计投影未包含携带数量与上限。")
	_expect(projection.get("ruan_stone_summary") == "雷石×3", "统计投影未解析携带摘要。")

	var player := preload("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.ruan_stone_purchased = ["thunder", "thunder", "thunder"]
	player.ruan_stone_carry_limit = 5
	var character_panel := CHARACTER_PANEL.new()
	root.add_child(character_panel)
	character_panel.show_for_player(player)
	character_panel._set_tab("equipment")
	_expect(character_panel.records.has("stones"), "人物页装备栏目缺少全队阮石记录。")
	_expect(character_panel.records.keys()[0] == "stones", "阮石应是装备页第一项。")
	var text := _collect_text(character_panel.detail)
	_expect(text.contains("全队共享") and text.contains("3 / 5") and text.contains("雷石 × 3"), "阮石详情未显示共享范围、数量与携带明细。")
	_expect(text.contains("不可赠与") and text.contains("上限"), "阮石详情未明确不可赠与及上限规则。")
	player.ruan_stone_purchased = []
	var before_crit: float = player._get_critical_damage_multiplier("swordsman")
	player.ruan_stone_purchased = ["rusted_dagger"]
	_expect(is_equal_approx(player._get_critical_damage_multiplier("swordsman"), before_crit + 0.08), "匕首的暴伤必须进入实际战斗计算。")
	for row in SHEET.get_stats(player, player.roles[0]):
		if row.id == "crit_damage":
			_expect(is_equal_approx(row.value, before_crit + 0.08), "人物页暴伤应与战斗一致。")
			var found_source := false
			for source in row.sources:
				if str(source.label).contains("生锈的匕首") and is_equal_approx(source.value, 0.08):
					found_source = true
			_expect(found_source, "人物页应标明匕首暴伤的具体来源。")
	character_panel._set_tab("equipment")
	text = _collect_text(character_panel.detail)
	_expect(text.contains("暴击率 +8%") and text.contains("暴击伤害 +8%"), "阮石详情应包含实际进入战斗计算的暴伤加成。")
	character_panel.free()
	player.free()
	root.remove_child(owner)
	owner.free()
	await process_frame
	if failures.is_empty():
		print("RUAN_STONE_UI_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _collect_text(node: Node) -> String:
	var parts: PackedStringArray = []
	if node is Label or node is Button:
		parts.append(str(node.text))
	for child in node.get_children():
		parts.append(_collect_text(child))
	return "\n".join(parts)
