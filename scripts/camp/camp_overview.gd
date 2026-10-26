extends Control

signal shop_requested
signal team_requested
signal departure_requested
signal menu_requested

const UI := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const ITEMS := preload("res://scripts/player/ruan_stone_system.gd")
const ROLES := preload("res://scripts/player/player_role_presenter.gd")

var status_label: Label
var team_label: Label
var carried_label: Label
var result_label: Label
var departure_button: Button
var action_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Theme.new()
	theme.default_font = UI.get_reading_font()
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 16
	top.add_theme_stylebox_override("panel", UI.panel_style(UI.COLOR_BG, UI.COLOR_BORDER, 1, 0, 14))
	add_child(top)
	UI.apply_campaign_frame(top, "banner")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	top.add_child(row)
	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_column)
	title_column.add_child(UI.make_section_label("无尽营地", 25))
	status_label = _label("", 15)
	title_column.add_child(status_label)
	for data in [["携带物品", shop_requested], ["队伍整备", team_requested], ["出击", departure_requested], ["主菜单", menu_requested]]:
		var button := Button.new()
		button.text = data[0]
		button.custom_minimum_size = Vector2(112, 42)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(func(): (data[1] as Signal).emit())
		UI.apply_button_style(button, "primary" if data[0] == "出击" else "normal")
		row.add_child(button)
		action_buttons.append(button)
	departure_button = action_buttons[2]
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 20
	bottom.offset_right = -20
	bottom.offset_top = -104
	bottom.offset_bottom = -16
	bottom.add_theme_stylebox_override("panel", UI.panel_style(UI.COLOR_BG, UI.COLOR_BORDER, 1, 0, 12))
	add_child(bottom)
	UI.apply_campaign_frame(bottom, "banner")
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	bottom.add_child(column)
	team_label = _label("", 17, UI.COLOR_TEXT_GOLD)
	carried_label = _label("", 14)
	carried_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	result_label = _label("", 14, UI.COLOR_TEXT_MUTED)
	result_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(team_label)
	column.add_child(carried_label)
	column.add_child(result_label)


func _label(value: String, font_size: int, color: Color = UI.COLOR_TEXT) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func refresh(profile: Dictionary, run: Dictionary, team: Array, movement_hint: String) -> void:
	status_label.text = "档案 %d    骨头 %d    已解锁至 N%d" % [int(profile.get("slot_id", 1)), int(profile.get("bones", 0)), int(profile.get("highest_cleared_tier", 0)) + 1]
	var names: PackedStringArray = []
	for index in range(team.size()):
		names.append("%d %s" % [index + 1, ROLES.get_role_name(str(team[index]))])
	team_label.text = "下一局阵容：" + " → ".join(names) + "    ·    1 号位首发"
	carried_label.text = "携带 %d/%d：%s    ·    返营永久保留" % [ITEMS.get_carried_count(profile), ITEMS.get_carry_limit(profile), ITEMS.get_carried_summary_text(profile.get("ruan_stone_purchased", []))]
	carried_label.tooltip_text = carried_label.text
	var result: Variant = profile.get("last_clear_summary", {})
	var recent := "首次出击：击败敌人和通关可获得骨头。"
	if result is Dictionary and not result.is_empty():
		recent = "最近通关 N%d，结算 +%d 骨。" % [maxi(1, int(result.get("tier", 1))), maxi(0, int(result.get("bones", 0)))]
	elif int(profile.get("highest_cleared_tier", 0)) > 0:
		recent = "最高已通关 N%d。" % int(profile["highest_cleared_tier"])
	var last_run: Variant = profile.get("last_run_summary", {})
	if last_run is Dictionary and not last_run.is_empty():
		var outcome: String = {"victory": "通关", "failed": "失败", "abandoned": "主动结束"}.get(last_run.get("outcome", ""), "结束")
		recent = "最近一局：N%d 第%d波%s，Lv%d。" % [int(last_run.get("tier", 1)), int(last_run.get("wave", 1)), outcome, int(last_run.get("level", 1))]
	var run_tier := int(run.get("run_tier", 0))
	departure_button.text = "继续 N%d" % run_tier if run_tier > 0 else "选择 N 层"
	result_label.text = ("进行中 N%d：阵容调整用于下一局，携带修改在继续时生效。" % run_tier if run_tier > 0 else recent) + "    " + movement_hint
	result_label.tooltip_text = result_label.text


func set_actions_enabled(enabled: bool) -> void:
	for button in action_buttons:
		button.disabled = not enabled
