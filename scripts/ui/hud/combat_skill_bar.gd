extends Control

const SkillCooldownIcon := preload("res://scripts/ui/hud/widgets/skill_cooldown_icon.gd")
const BuffStatusIcon := preload("res://scripts/ui/hud/widgets/buff_status_icon.gd")
const SwitchPortraitDisplay := preload("res://scripts/ui/hud/widgets/switch_portrait_display.gd")
const UltimateEnergyDisplay := preload("res://scripts/ui/hud/widgets/ultimate_energy_display.gd")
const TeamRoleStatusRow := preload("res://scripts/ui/hud/widgets/team_role_status_row.gd")

signal skill_mode_toggle_requested(skill_id: String)
signal skill_slot_swap_requested(role_id: String, from_slot: int, to_slot: int)
signal skill_point_requested(skill_id: String, role_id: String)

const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const SURVIVORS_HOVER_DETAIL := preload("res://scripts/ui/components/survivors_hover_detail.gd")
const SKILL_CD_SLOT_COUNT := TeamRoleStatusRow.SKILL_CD_SLOT_COUNT
const SKILL_CD_SLOT_SIZE := 52.0
const BUFF_SLOT_SIZE := SKILL_CD_SLOT_SIZE * 0.35
const BUFF_SLOT_GAP := 5
const ULTIMATE_WIDGET_SIZE := 108.0
const HOVER_DETAIL_DELAY := 1.5
const ULTIMATE_WIDGET_GAP := 18.0
const SWITCH_WIDGET_WIDTH := 176.0
const SWITCH_WIDGET_HEIGHT := 72.0
const SWITCH_WIDGET_GAP := 18.0
const SKILL_PANEL_WIDTH := 382.0
const TEAM_STACK_WIDTH := 1008.0
const TEAM_STACK_MIN_WIDTH := 680.0
const TEAM_STACK_HEIGHT := 154.0
const TEAM_STACK_ROW_ACTIVE_HEIGHT := 52.0
const TEAM_STACK_ROW_STANDBY_HEIGHT := 35.0
const TEAM_STACK_ROW_GAP := 4.0
const TEAM_STACK_ACTIVE_INDENT := 8.0
const TEAM_STACK_SLOT_SIZE_ACTIVE := TeamRoleStatusRow.TEAM_STACK_SLOT_SIZE_ACTIVE
const TEAM_STACK_SLOT_SIZE_STANDBY := TeamRoleStatusRow.TEAM_STACK_SLOT_SIZE_STANDBY
const TEAM_STACK_SLOT_GAP_ACTIVE := TeamRoleStatusRow.TEAM_STACK_SLOT_GAP_ACTIVE
const TEAM_STACK_SLOT_GAP_STANDBY := TeamRoleStatusRow.TEAM_STACK_SLOT_GAP_STANDBY
const BASIC_ATTACK_SLOT_EXTRA_GAP := 25.0
const SKILL_CD_SLOT_SEPARATION := 9
const TEAM_STACK_BASIC_ATTACK_GAP := 16.0
const SKILL_SLOT_KEY_LABEL_FONT_SIZE := 12
const SKILL_SLOT_MANUAL_COLOR := Color(1.0, 0.86, 0.42, 1.0)
const SKILL_SLOT_AUTO_COLOR := Color("#eee2c1")
const SKILL_SLOT_DRAG_THRESHOLD := 6.0
const SKILL_SLOT_SWAP_ANIMATION_DURATION := 0.26
const SKILL_SLOT_DRAG_GHOST_FONT_SIZE := 16
const TEAM_STACK_SLOT_COUNT := TeamRoleStatusRow.TEAM_STACK_SLOT_COUNT
const ENERGY_READY_RATIO_EPSILON := UltimateEnergyDisplay.ENERGY_READY_RATIO_EPSILON
const SWITCH_HEAD_SIZE_MULTIPLIER := 2.5
const SWITCH_PORTRAIT_ANIMATION_DURATION := 0.22
const SWITCH_ROLE_ORDER := ["swordsman", "gunner", "mage"]
const SWITCH_HEAD_SCENES := {
	"swordsman": preload("res://assets/UI/facility/swordchange.tscn"),
	"gunner": preload("res://assets/UI/facility/gunchange.tscn"),
	"mage": preload("res://assets/UI/facility/witchchange.tscn"),
	"mechanic": preload("res://assets/UI/facility/mechanicchange.tscn")
}

var switch_cd_left_key_label: Label
var switch_cd_right_key_label: Label
var skill_slot_drag_state: Dictionary = {}
var switch_cd_time_label: Label
var switch_cd_portraits: Dictionary = {}
var switch_cd_active_role_id: String = ""
var switch_cd_layout_initialized: bool = false
var switch_cd_layout_tween: Tween
var switch_cd_widget: Control
var switch_role_order: Array = []
var switch_cooldown_remaining_value: float = 0.0
var switch_cooldown_duration_value: float = 0.5
var team_stack_widget: Control
var team_role_rows: Array = []
var team_role_status_by_id: Dictionary = {}
var skill_cd_slots: Array = []
var buff_status_bar: HBoxContainer
var buff_status_slots: Array = []
var ultimate_energy_widget: UltimateEnergyDisplay
var ultimate_key_label: Label
var ultimate_current_energy: float = 0.0
var ultimate_required_energy: float = 100.0
var ultimate_display: Dictionary = {}
var experience_bar: ProgressBar
var experience_label: Label
var skill_point_count: int = 0
var hover_detail: Control
var hovered_skill_view: Control
var hovered_skill_id := ""
var hover_request_serial: int = 0
var action_key_labels_ready: bool = false
var hud_layout: String = GAME_SETTINGS.DEFAULT_HUD_LAYOUT

func _ready() -> void:
	hud_layout = GAME_SETTINGS.load_hud_layout()
	_apply_hud_layout_anchor()
	_build_widgets()
	hover_detail = SURVIVORS_HOVER_DETAIL.new()
	add_child(hover_detail)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and hud_layout == GAME_SETTINGS.HUD_LAYOUT_TEAM_BAND:
		_apply_hud_layout_anchor()
		_apply_team_stack_layout()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_cancel_skill_slot_drag()

func sync_hud_layout_from_settings() -> void:
	set_hud_layout(GAME_SETTINGS.load_hud_layout())

func set_hud_layout(layout_key: String) -> void:
	var normalized_layout := GAME_SETTINGS.normalize_hud_layout(layout_key)
	if normalized_layout == hud_layout:
		return
	hud_layout = normalized_layout
	_rebuild_widgets_for_layout()

func _rebuild_widgets_for_layout() -> void:
	if switch_cd_layout_tween != null and switch_cd_layout_tween.is_valid():
		switch_cd_layout_tween.kill()
	_clear_layout_widgets()
	_apply_hud_layout_anchor()
	_build_widgets()
	if hover_detail != null:
		move_child(hover_detail, get_child_count() - 1)

func _clear_layout_widgets() -> void:
	_cancel_skill_slot_drag()
	hovered_skill_view = null
	if hover_detail != null:
		hover_detail.hide_detail()
	for child in get_children():
		if child == hover_detail:
			continue
		remove_child(child)
		child.queue_free()
	switch_cd_left_key_label = null
	switch_cd_right_key_label = null
	switch_cd_time_label = null
	switch_cd_portraits.clear()
	switch_cd_active_role_id = ""
	switch_cd_layout_initialized = false
	switch_cd_layout_tween = null
	switch_cd_widget = null
	team_stack_widget = null
	team_role_rows.clear()
	team_role_status_by_id.clear()
	skill_cd_slots.clear()
	buff_status_bar = null
	buff_status_slots.clear()
	ultimate_energy_widget = null
	ultimate_key_label = null
	experience_bar = null
	experience_label = null
	action_key_labels_ready = false

func _apply_hud_layout_anchor() -> void:
	anchor_top = 1.0
	anchor_bottom = 1.0
	if hud_layout == GAME_SETTINGS.HUD_LAYOUT_TEAM_BAND:
		anchor_left = 0.0
		anchor_right = 1.0
		offset_left = 18.0
		offset_top = -190.0
		offset_right = -18.0
		offset_bottom = -36.0
		return
	anchor_left = 0.5
	anchor_right = 0.5
	var total_width := SWITCH_WIDGET_WIDTH + SWITCH_WIDGET_GAP + SKILL_PANEL_WIDTH + ULTIMATE_WIDGET_GAP + ULTIMATE_WIDGET_SIZE
	offset_left = -total_width * 0.5
	offset_top = -146.0
	offset_right = total_width * 0.5
	offset_bottom = -28.0

func update_experience(current_experience: int, required_experience: int) -> void:
	if experience_bar != null:
		var resolved_required: int = max(required_experience, 1)
		if int(experience_bar.max_value) != resolved_required:
			experience_bar.max_value = resolved_required
		if int(experience_bar.value) != current_experience:
			experience_bar.value = current_experience
	if experience_label != null:
		var next_text: String = "%d / %d XP" % [current_experience, required_experience]
		if experience_label.text != next_text:
			experience_label.text = next_text

func update_skill_points(points: int) -> void:
	skill_point_count = maxi(0, points)
	_refresh_skill_point_buttons()


func _create_slot_upgrade_button(slot_icon: Control) -> Button:
	var button := Button.new()
	button.text = "+"
	button.custom_minimum_size = Vector2(26.0, 22.0)
	button.size = Vector2(26.0, 22.0)
	button.anchor_left = 0.5
	button.anchor_right = 0.5
	button.offset_left = -13.0
	button.offset_right = 13.0
	button.offset_top = -26.0
	button.offset_bottom = -4.0
	button.focus_mode = Control.FOCUS_ALL
	button.z_index = 5
	button.add_theme_font_size_override("font_size", 22)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("#edcf72"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#49371a") if state == "hover" else Color("#241d13")
		style.border_color = Color("#d2ad55")
		style.set_border_width_all(2)
		style.set_corner_radius_all(0)
		button.add_theme_stylebox_override(state, style)
	button.tooltip_text = "消耗 1 个技能点"
	button.visible = false
	button.pressed.connect(_on_skill_slot_upgrade_pressed.bind(button))
	button.mouse_entered.connect(_cancel_hover_detail.bind(true))
	slot_icon.add_child(button)
	return button


func _set_slot_upgrade_state(slot_nodes: Dictionary, slot_data: Dictionary, role_active: bool) -> void:
	var button: Button = slot_nodes.get("upgrade_button", null) as Button
	if button == null:
		return
	if not slot_data.is_empty():
		slot_nodes["skill_id"] = str(slot_data.get("skill_id", ""))
		slot_nodes["role_id"] = str(slot_data.get("role_id", slot_nodes.get("role_id", "")))
		slot_nodes["can_upgrade"] = bool(slot_data.get("can_upgrade", false))
	var skill_id := str(slot_nodes.get("skill_id", ""))
	slot_nodes["role_active"] = role_active
	var eligible := bool(slot_nodes.get("can_learn", false)) if skill_id == "" else bool(slot_nodes.get("can_upgrade", false))
	var role_id := str(slot_nodes.get("role_id", ""))
	var points := skill_point_count if role_active else int(team_role_status_by_id.get(role_id, {}).get("skill_points", 0))
	var can_show := points > 0 and role_active and role_id != "" and eligible
	var slot_view: SkillCooldownIcon = slot_nodes.get("view") as SkillCooldownIcon
	if slot_view != null:
		slot_view.set_skill_point_highlighted(points > 0 and role_id != "")
	button.visible = can_show
	button.disabled = not can_show
	button.tooltip_text = "消耗 1 个技能点，升级%s" % str(slot_nodes.get("title", "技能")) if skill_id != "" else "消耗 1 个技能点，选择一个尚未拥有的技能"


func _refresh_skill_point_buttons() -> void:
	for slot_nodes_value in skill_cd_slots:
		var slot_nodes: Dictionary = slot_nodes_value
		_set_slot_upgrade_state(slot_nodes, {}, true)
	for row_entry_value in team_role_rows:
		var row_entry: Dictionary = row_entry_value
		var slots: Array = row_entry.get("slots", [])
		for slot_nodes_value in slots:
			var slot_nodes: Dictionary = slot_nodes_value
			_set_slot_upgrade_state(slot_nodes, {}, bool(row_entry.get("active", false)))


func _on_skill_slot_upgrade_pressed(button: Button) -> void:
	_cancel_hover_detail(true)
	if button == null or not button.visible or button.disabled or skill_point_count <= 0:
		return
	for slot_nodes_value in skill_cd_slots:
		var slot_nodes: Dictionary = slot_nodes_value
		if slot_nodes.get("upgrade_button") == button:
			skill_point_requested.emit(str(slot_nodes.get("skill_id", "")), str(slot_nodes.get("role_id", "")))
			return
	for row_entry_value in team_role_rows:
		var row_entry: Dictionary = row_entry_value
		for slot_nodes_value in row_entry.get("slots", []):
			var slot_nodes: Dictionary = slot_nodes_value
			if slot_nodes.get("upgrade_button") == button:
				if bool(row_entry.get("active", false)):
					skill_point_requested.emit(str(slot_nodes.get("skill_id", "")), str(slot_nodes.get("role_id", "")))
				return

func update_switch_cooldown(role_id: String, cooldown_remaining: float, cooldown_duration: float, switch_energy: float = 0.0, switch_energy_required: float = 100.0, switch_energy_by_role: Dictionary = {}) -> void:
	_refresh_switch_key_labels()
	switch_cooldown_remaining_value = max(0.0, cooldown_remaining)
	switch_cooldown_duration_value = max(0.01, cooldown_duration)
	var duration: float = max(cooldown_duration, 0.01)
	var ratio: float = clamp(cooldown_remaining / duration, 0.0, 1.0)
	var energy_values: Dictionary = switch_energy_by_role
	if energy_values.is_empty():
		energy_values = {role_id: switch_energy}
	if not switch_cd_portraits.is_empty():
		if switch_cd_active_role_id != role_id:
			_cancel_skill_slot_drag()
		_layout_switch_portraits(role_id, switch_cd_layout_initialized and switch_cd_active_role_id != role_id)
		switch_cd_active_role_id = role_id
		switch_cd_layout_initialized = true
		for switch_role_id in _get_switch_role_order():
			var switch_role_id_string: String = str(switch_role_id)
			var portrait: SwitchPortraitDisplay = switch_cd_portraits.get(switch_role_id_string, null) as SwitchPortraitDisplay
			if portrait == null:
				continue
			var role_energy: float = float(energy_values.get(switch_role_id_string, 0.0))
			var energy_ratio: float = clamp(max(role_energy, 0.0) / max(switch_energy_required, 1.0), 0.0, 1.0)
			if role_energy >= switch_energy_required or energy_ratio >= 1.0 - ENERGY_READY_RATIO_EPSILON:
				energy_ratio = 1.0
			portrait.set_state(ratio, energy_ratio, switch_role_id_string == role_id)
	for row_entry_value in team_role_rows:
		var row_entry: Dictionary = row_entry_value
		var portrait: SwitchPortraitDisplay = row_entry.get("portrait", null) as SwitchPortraitDisplay
		var status: Dictionary = row_entry.get("data", {})
		var row_role_id: String = str(status.get("role_id", ""))
		if portrait == null or row_role_id == "":
			continue
		var role_energy: float = float(energy_values.get(row_role_id, status.get("switch_energy", 0.0)))
		var required_energy: float = max(1.0, float(status.get("switch_energy_required", switch_energy_required)))
		portrait.set_state(ratio, role_energy / required_energy, row_role_id == role_id)
	if switch_cd_time_label != null:
		var next_text: String = "%.1f" % cooldown_remaining if cooldown_remaining > 0.05 else ""
		if switch_cd_time_label.text != next_text:
			switch_cd_time_label.text = next_text

func update_ultimate_energy(current_energy: float, required_energy: float, display_data: Dictionary = {}, force_ready: bool = false) -> void:
	_refresh_action_key_labels()
	ultimate_current_energy = max(current_energy, 0.0)
	ultimate_required_energy = max(required_energy, 1.0)
	ultimate_display = display_data.duplicate(true)
	if ultimate_energy_widget != null:
		ultimate_energy_widget.set_skill_name(str(ultimate_display.get("hud_name", ultimate_display.get("name", "大招"))))
		var energy_ratio: float = ultimate_current_energy / ultimate_required_energy
		if force_ready or ultimate_current_energy >= ultimate_required_energy or energy_ratio >= 1.0 - ENERGY_READY_RATIO_EPSILON:
			energy_ratio = 1.0
		ultimate_energy_widget.set_state(energy_ratio)

func update_skill_cooldown_slots(slot_data_list: Array) -> void:
	for index in range(skill_cd_slots.size()):
		var slot_nodes: Dictionary = skill_cd_slots[index]
		var slot_view: SkillCooldownIcon = slot_nodes["view"] as SkillCooldownIcon
		var label: Label = slot_nodes["label"] as Label
		var key_label: Label = slot_nodes.get("key_label", null) as Label
		if index >= slot_data_list.size():
			slot_nodes["can_learn"] = index > 0 and not slot_data_list.is_empty()
			if not slot_data_list.is_empty():
				slot_nodes["role_id"] = str(slot_data_list[0].get("role_id", slot_nodes.get("role_id", "")))
			else:
				slot_nodes["role_id"] = ""
			_clear_skill_detail(slot_nodes)
			slot_view.set_state(false, Color(0.12, 0.13, 0.16, 1.0), 0.0)
			slot_view.set_auto_mode(false)
			if slot_view.tooltip_text != "":
				slot_view.tooltip_text = ""
			if label.text != "":
				label.text = ""
			if key_label != null and key_label.text != "":
				key_label.text = ""
			if str(slot_nodes.get("skill_id", "")) != "":
				slot_nodes["skill_id"] = ""
			slot_nodes["can_upgrade"] = false
			if str(slot_nodes.get("title", "")) != "":
				slot_nodes["title"] = ""
			if str(slot_nodes.get("description", "")) != "":
				slot_nodes["description"] = ""
			if str(slot_nodes.get("slot_label", "")) != "":
				slot_nodes["slot_label"] = ""
			_set_slot_upgrade_state(slot_nodes, {}, true)
			continue

		var slot_data: Dictionary = slot_data_list[index]
		_set_slot_upgrade_state(slot_nodes, slot_data, true)
		var slot_color: Color = Color(1.0, 1.0, 1.0, 1.0)
		var color_value: Variant = slot_data.get("color", slot_color)
		if color_value is Color:
			slot_color = color_value
		var duration: float = max(float(slot_data.get("duration", 1.0)), 0.01)
		var remaining: float = clamp(float(slot_data.get("remaining", 0.0)), 0.0, duration)
		var ratio: float = remaining / duration
		slot_view.set_state(true, slot_color, ratio)
		var slot_name: String = str(slot_data.get("name", "OK"))
		var hud_name: String = str(slot_data.get("hud_name", slot_name))
		if label.text != hud_name:
			label.text = hud_name
		if slot_view.tooltip_text != "":
			slot_view.tooltip_text = ""
		if str(slot_nodes.get("title", "")) != slot_name:
			slot_nodes["title"] = slot_name
		var next_description: String = _build_slot_tooltip(slot_data, duration, remaining)
		if str(slot_nodes.get("description", "")) != next_description:
			slot_nodes["description"] = next_description
		var next_slot_label: String = str(slot_data.get("slot_label", "技能冷却"))
		if str(slot_nodes.get("slot_label", "")) != next_slot_label:
			slot_nodes["slot_label"] = next_slot_label
		slot_nodes["skill_id"] = str(slot_data.get("skill_id", ""))
		_apply_skill_slot_key_label(slot_nodes, index, str(slot_data.get("skill_id", "")), slot_data)
		_remember_skill_detail(slot_nodes, slot_data, duration, remaining)
	_refresh_skill_point_buttons()


func _apply_skill_slot_key_label(slot_nodes: Dictionary, slot_index: int, skill_id: String, slot_data: Dictionary) -> void:
	var key_label: Label = slot_nodes.get("key_label", null) as Label
	var slot_view: SkillCooldownIcon = slot_nodes.get("view", null) as SkillCooldownIcon
	if slot_view != null:
		slot_view.set_auto_mode(slot_index > 0 and skill_id != "" and not GAME_SETTINGS.is_skill_manual(skill_id) and not bool(slot_data.get("toggle_mode", false)))
	if key_label == null:
		return
	if slot_index == 0 or skill_id == "":
		if key_label.text != "":
			key_label.text = ""
		return
	var key_slot_index: int = int(slot_data.get("manual_slot_index", slot_index))
	if key_slot_index <= 0:
		key_slot_index = slot_index
	var action_id := GAME_SETTINGS.get_skill_slot_action_id(key_slot_index)
	var key_text := GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(action_id))
	var manual := GAME_SETTINGS.is_skill_manual(skill_id) or bool(slot_data.get("toggle_mode", false))
	var next_text := key_text
	var next_color := SKILL_SLOT_AUTO_COLOR
	if manual:
		next_text = "%s 手动" % key_text
		next_color = SKILL_SLOT_MANUAL_COLOR
	if bool(slot_data.get("toggle_mode", false)):
		next_text = "%s 开关" % key_text
	if key_label.text != next_text:
		key_label.text = next_text
	key_label.add_theme_color_override("font_color", next_color)


func _emit_skill_mode_toggle(skill_id: String) -> void:
	if skill_id == "":
		return
	skill_mode_toggle_requested.emit(skill_id)


func _on_legacy_skill_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if slot_index < 0 or slot_index >= skill_cd_slots.size():
		return
	var slot_nodes: Dictionary = skill_cd_slots[slot_index]
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_emit_skill_mode_toggle(str(slot_nodes.get("skill_id", "")))
		accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_begin_skill_slot_drag(slot_index, "", str(slot_nodes.get("skill_id", "")), str(slot_nodes.get("title", "")))
		accept_event()

func update_buff_slots(buff_data_list: Array) -> void:
	if buff_status_bar == null:
		return
	buff_status_bar.visible = not buff_data_list.is_empty()
	for index in range(buff_status_slots.size()):
		var slot_nodes: Dictionary = buff_status_slots[index]
		var slot_view: BuffStatusIcon = slot_nodes["view"] as BuffStatusIcon
		if index >= buff_data_list.size():
			slot_view.visible = false
			slot_view.tooltip_text = ""
			slot_nodes["title"] = ""
			slot_nodes["description"] = ""
			continue
		var buff_data: Dictionary = buff_data_list[index]
		var duration: float = max(float(buff_data.get("duration", 1.0)), 0.001)
		var remaining: float = clamp(float(buff_data.get("remaining", duration)), 0.0, duration)
		var ratio: float = remaining / duration
		var slot_color: Color = Color(0.36, 0.76, 1.0, 0.92)
		var color_value: Variant = buff_data.get("color", slot_color)
		if color_value is Color:
			slot_color = color_value
		var icon_text: String = str(buff_data.get("text", ""))
		var stack_count: int = int(buff_data.get("stacks", 0))
		var cooldown_mode: bool = bool(buff_data.get("cooldown", false))
		var icon_id: String = str(buff_data.get("icon_id", ""))
		var base_color: Color = Color(0.62, 0.06, 0.05, 0.92)
		var base_color_value: Variant = buff_data.get("base_color", base_color)
		if base_color_value is Color:
			base_color = base_color_value
		slot_view.visible = true
		slot_view.set_state(ratio, slot_color, icon_text, stack_count, cooldown_mode, base_color, icon_id)
		slot_view.tooltip_text = ""
		slot_nodes["title"] = str(buff_data.get("name", "Buff"))
		var time_label: String = "\u51B7\u5374 %.1f / %.1f \u79D2" if cooldown_mode else "\u5269\u4F59 %.1f / %.1f \u79D2"
		slot_nodes["description"] = "%s\n%s" % [str(buff_data.get("description", "")), time_label % [remaining, duration]]

func _build_widgets() -> void:
	SURVIVORS_THEME.apply_campaign_frame(self, "panel")
	if hud_layout == GAME_SETTINGS.HUD_LAYOUT_TEAM_BAND:
		_build_team_band_widgets()
		return
	_build_legacy_widgets()

func _build_legacy_widgets() -> void:
	switch_cd_widget = Control.new()
	switch_cd_widget.position = Vector2(0.0, 0.0)
	switch_cd_widget.custom_minimum_size = Vector2(SWITCH_WIDGET_WIDTH, SWITCH_WIDGET_HEIGHT)
	switch_cd_widget.size = Vector2(SWITCH_WIDGET_WIDTH, SWITCH_WIDGET_HEIGHT)
	SURVIVORS_THEME.apply_campaign_frame(switch_cd_widget, "card")
	add_child(switch_cd_widget)

	var left_arrow_box := Control.new()
	left_arrow_box.position = Vector2(0.0, 0.0)
	left_arrow_box.custom_minimum_size = Vector2(38.0, SWITCH_WIDGET_HEIGHT)
	left_arrow_box.z_index = 3
	switch_cd_widget.add_child(left_arrow_box)

	var left_arrow_label := Label.new()
	left_arrow_label.text = "<"
	left_arrow_label.position = Vector2(0.0, 17.0)
	left_arrow_label.custom_minimum_size = Vector2(38.0, 32.0)
	left_arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_arrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left_arrow_label.add_theme_font_size_override("font_size", 28)
	left_arrow_label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98, 1.0))
	left_arrow_box.add_child(left_arrow_label)

	switch_cd_left_key_label = Label.new()
	switch_cd_left_key_label.position = Vector2(0.0, 47.0)
	switch_cd_left_key_label.custom_minimum_size = Vector2(38.0, 22.0)
	switch_cd_left_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	switch_cd_left_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	switch_cd_left_key_label.add_theme_font_size_override("font_size", 16)
	left_arrow_box.add_child(switch_cd_left_key_label)

	_build_switch_portraits()

	switch_cd_time_label = Label.new()
	switch_cd_time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	switch_cd_time_label.position = Vector2(22.0, 75.0)
	switch_cd_time_label.custom_minimum_size = Vector2(132.0, 40.0)
	switch_cd_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	switch_cd_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	switch_cd_time_label.add_theme_font_size_override("font_size", 15)
	switch_cd_time_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	switch_cd_time_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	switch_cd_time_label.add_theme_constant_override("shadow_offset_x", 1)
	switch_cd_time_label.add_theme_constant_override("shadow_offset_y", 1)
	switch_cd_time_label.text = ""
	switch_cd_widget.add_child(switch_cd_time_label)

	var right_arrow_box := Control.new()
	right_arrow_box.position = Vector2(SWITCH_WIDGET_WIDTH - 38.0, 0.0)
	right_arrow_box.custom_minimum_size = Vector2(38.0, SWITCH_WIDGET_HEIGHT)
	right_arrow_box.z_index = 3
	switch_cd_widget.add_child(right_arrow_box)

	var right_arrow_label := Label.new()
	right_arrow_label.text = ">"
	right_arrow_label.position = Vector2(0.0, 17.0)
	right_arrow_label.custom_minimum_size = Vector2(38.0, 32.0)
	right_arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_arrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right_arrow_label.add_theme_font_size_override("font_size", 28)
	right_arrow_label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98, 1.0))
	right_arrow_box.add_child(right_arrow_label)

	switch_cd_right_key_label = Label.new()
	switch_cd_right_key_label.position = Vector2(0.0, 47.0)
	switch_cd_right_key_label.custom_minimum_size = Vector2(38.0, 22.0)
	switch_cd_right_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	switch_cd_right_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	switch_cd_right_key_label.add_theme_font_size_override("font_size", 16)
	right_arrow_box.add_child(switch_cd_right_key_label)

	var skill_cd_panel := HBoxContainer.new()
	skill_cd_panel.position = Vector2(SWITCH_WIDGET_WIDTH + SWITCH_WIDGET_GAP, 10.0)
	skill_cd_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	skill_cd_panel.add_theme_constant_override("separation", SKILL_CD_SLOT_SEPARATION)
	SURVIVORS_THEME.apply_campaign_frame(skill_cd_panel, "panel")
	add_child(skill_cd_panel)

	buff_status_bar = HBoxContainer.new()
	buff_status_bar.position = skill_cd_panel.position + Vector2(0.0, -BUFF_SLOT_SIZE - 6.0)
	buff_status_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	buff_status_bar.add_theme_constant_override("separation", BUFF_SLOT_GAP)
	buff_status_bar.visible = false
	add_child(buff_status_bar)

	for index in range(SKILL_CD_SLOT_COUNT):
		var buff_icon: BuffStatusIcon = BuffStatusIcon.new()
		buff_icon.custom_minimum_size = Vector2(BUFF_SLOT_SIZE, BUFF_SLOT_SIZE)
		buff_icon.size = Vector2(BUFF_SLOT_SIZE, BUFF_SLOT_SIZE)
		buff_icon.visible = false
		buff_icon.mouse_entered.connect(_on_buff_slot_hovered.bind(buff_icon, index))
		buff_icon.mouse_exited.connect(_on_skill_slot_unhovered)
		buff_status_bar.add_child(buff_icon)
		buff_status_slots.append({
			"view": buff_icon,
			"title": "",
			"description": ""
		})

	for index in range(SKILL_CD_SLOT_COUNT):
		var slot_icon := SkillCooldownIcon.new()
		slot_icon.custom_minimum_size = Vector2(SKILL_CD_SLOT_SIZE, SKILL_CD_SLOT_SIZE)
		slot_icon.set_state(false, Color(0.12, 0.13, 0.16, 1.0), 0.0)
		slot_icon.tooltip_text = ""
		slot_icon.mouse_entered.connect(_on_skill_slot_hovered.bind(slot_icon, index))
		slot_icon.mouse_exited.connect(_on_skill_slot_unhovered)
		slot_icon.gui_input.connect(_on_legacy_skill_slot_gui_input.bind(index))
		skill_cd_panel.add_child(slot_icon)

		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.text = ""
		slot_icon.add_child(label)

		var key_label := Label.new()
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_label.position = Vector2(2.0, 1.0)
		key_label.custom_minimum_size = Vector2(SKILL_CD_SLOT_SIZE - 4.0, 16.0)
		key_label.size = Vector2(SKILL_CD_SLOT_SIZE - 4.0, 16.0)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		key_label.add_theme_font_size_override("font_size", SKILL_SLOT_KEY_LABEL_FONT_SIZE)
		key_label.add_theme_color_override("font_color", SKILL_SLOT_AUTO_COLOR)
		key_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
		key_label.add_theme_constant_override("shadow_offset_x", 1)
		key_label.add_theme_constant_override("shadow_offset_y", 1)
		key_label.text = ""
		slot_icon.add_child(key_label)

		var slot_nodes := {
			"view": slot_icon,
			"label": label,
			"key_label": key_label,
			"upgrade_button": _create_slot_upgrade_button(slot_icon),
			"title": "",
			"description": "",
			"skill_id": "",
			"slot_label": "",
			"role_id": ""
		}
		skill_cd_slots.append(slot_nodes)
		if index == 0:
			# 普攻槽与技能槽视觉分离
			var basic_attack_gap := Control.new()
			basic_attack_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			basic_attack_gap.custom_minimum_size = Vector2(BASIC_ATTACK_SLOT_EXTRA_GAP, 1.0)
			skill_cd_panel.add_child(basic_attack_gap)

	ultimate_energy_widget = UltimateEnergyDisplay.new()
	ultimate_energy_widget.position = Vector2(SWITCH_WIDGET_WIDTH + SWITCH_WIDGET_GAP + SKILL_PANEL_WIDTH + ULTIMATE_WIDGET_GAP, -18.0)
	ultimate_energy_widget.size = Vector2(ULTIMATE_WIDGET_SIZE, ULTIMATE_WIDGET_SIZE)
	ultimate_energy_widget.custom_minimum_size = Vector2(ULTIMATE_WIDGET_SIZE, ULTIMATE_WIDGET_SIZE)
	ultimate_energy_widget.set_state(0.0)
	ultimate_energy_widget.tooltip_text = ""
	ultimate_energy_widget.mouse_entered.connect(_on_ultimate_energy_hovered)
	ultimate_energy_widget.mouse_exited.connect(_on_skill_slot_unhovered)
	add_child(ultimate_energy_widget)

	ultimate_key_label = Label.new()
	ultimate_key_label.position = ultimate_energy_widget.position + Vector2(0.0, ULTIMATE_WIDGET_SIZE - 4.0)
	ultimate_key_label.custom_minimum_size = Vector2(ULTIMATE_WIDGET_SIZE, 24.0)
	ultimate_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ultimate_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ultimate_key_label.add_theme_font_size_override("font_size", 16)
	ultimate_key_label.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98, 1.0))
	ultimate_key_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	ultimate_key_label.add_theme_constant_override("shadow_offset_x", 1)
	ultimate_key_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(ultimate_key_label)

	experience_bar = ProgressBar.new()
	experience_bar.position = Vector2(SWITCH_WIDGET_WIDTH + SWITCH_WIDGET_GAP, 78.0)
	experience_bar.custom_minimum_size = Vector2(SKILL_PANEL_WIDTH, 14.0)
	experience_bar.show_percentage = false
	var exp_fill := StyleBoxFlat.new()
	exp_fill.bg_color = Color(1.0, 0.82, 0.16, 0.95)
	exp_fill.set_corner_radius_all(5)
	var exp_background := StyleBoxFlat.new()
	exp_background.bg_color = Color(0.12, 0.1, 0.04, 0.82)
	exp_background.border_color = Color(0.92, 0.72, 0.16, 0.9)
	exp_background.set_border_width_all(1)
	exp_background.set_corner_radius_all(5)
	experience_bar.add_theme_stylebox_override("fill", exp_fill)
	experience_bar.add_theme_stylebox_override("background", exp_background)
	add_child(experience_bar)

	experience_label = Label.new()
	experience_label.position = Vector2(SWITCH_WIDGET_WIDTH + SWITCH_WIDGET_GAP, 72.0)
	experience_label.custom_minimum_size = Vector2(SKILL_PANEL_WIDTH, 26.0)
	experience_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	experience_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	experience_label.add_theme_font_size_override("font_size", 13)
	experience_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.62, 1.0))
	experience_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	experience_label.add_theme_constant_override("shadow_offset_x", 1)
	experience_label.add_theme_constant_override("shadow_offset_y", 1)
	experience_label.text = "0 / 30 XP"
	add_child(experience_label)

	_refresh_action_key_labels()
	_layout_switch_portraits("gunner", false)


func _build_team_band_widgets() -> void:
	team_stack_widget = Control.new()
	team_stack_widget.position = Vector2.ZERO
	team_stack_widget.custom_minimum_size = Vector2(TEAM_STACK_WIDTH, TEAM_STACK_HEIGHT)
	team_stack_widget.size = Vector2(TEAM_STACK_WIDTH, TEAM_STACK_HEIGHT)
	add_child(team_stack_widget)

	_build_team_role_rows()
	_build_buff_bar()
	_build_experience_strip()

	_refresh_action_key_labels(true)
	_apply_team_stack_layout()
	_apply_empty_team_statuses()

func _build_team_role_rows() -> void:
	team_role_rows.clear()
	var row_specs := [
		{"key": "Q", "state": "PREV", "active": false, "position": Vector2(0.0, 0.0), "size": Vector2(TEAM_STACK_WIDTH - 36.0, TEAM_STACK_ROW_STANDBY_HEIGHT)},
		{"key": "当前", "state": "ON FIELD", "active": true, "position": Vector2(TEAM_STACK_ACTIVE_INDENT, TEAM_STACK_ROW_STANDBY_HEIGHT + TEAM_STACK_ROW_GAP), "size": Vector2(TEAM_STACK_WIDTH - 24.0, TEAM_STACK_ROW_ACTIVE_HEIGHT)},
		{"key": "E", "state": "NEXT", "active": false, "position": Vector2(0.0, TEAM_STACK_ROW_STANDBY_HEIGHT + TEAM_STACK_ROW_GAP + TEAM_STACK_ROW_ACTIVE_HEIGHT + TEAM_STACK_ROW_GAP), "size": Vector2(TEAM_STACK_WIDTH - 36.0, TEAM_STACK_ROW_STANDBY_HEIGHT)}
	]
	for row_index in range(row_specs.size()):
		var spec: Dictionary = row_specs[row_index]
		var row := TeamRoleStatusRow.new()
		row.position = spec["position"]
		row.size = spec["size"]
		row.custom_minimum_size = spec["size"]
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_entered.connect(_on_team_role_row_hovered.bind(row_index))
		row.mouse_exited.connect(_on_skill_slot_unhovered)
		team_stack_widget.add_child(row)
		var portrait := SwitchPortraitDisplay.new()
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.z_index = 2
		row.add_child(portrait)
		var slot_nodes: Array = []
		for slot_index in range(TEAM_STACK_SLOT_COUNT):
			var slot_icon := SkillCooldownIcon.new()
			slot_icon.set_state(false, Color(0.12, 0.13, 0.16, 1.0), 0.0)
			slot_icon.tooltip_text = ""
			slot_icon.mouse_entered.connect(_on_team_role_skill_slot_hovered.bind(row_index, slot_index, slot_icon))
			slot_icon.mouse_exited.connect(_on_skill_slot_unhovered)
			slot_icon.gui_input.connect(_on_team_skill_slot_gui_input.bind(row_index, slot_index))
			row.add_child(slot_icon)

			var label := Label.new()
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.set_anchors_preset(Control.PRESET_FULL_RECT)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 12 if not bool(spec["active"]) else 14)
			label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
			label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
			label.add_theme_constant_override("shadow_offset_x", 1)
			label.add_theme_constant_override("shadow_offset_y", 1)
			label.text = ""
			slot_icon.add_child(label)

			var key_label := Label.new()
			key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			key_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			key_label.add_theme_font_size_override("font_size", 11 if bool(spec["active"]) else 10)
			key_label.add_theme_color_override("font_color", SKILL_SLOT_AUTO_COLOR)
			key_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
			key_label.add_theme_constant_override("shadow_offset_x", 1)
			key_label.add_theme_constant_override("shadow_offset_y", 1)
			key_label.text = ""
			slot_icon.add_child(key_label)

			var slot_entry := {
				"view": slot_icon,
				"label": label,
				"key_label": key_label,
				"upgrade_button": _create_slot_upgrade_button(slot_icon),
				"title": "",
				"description": "",
				"base_description": "",
				"skill_id": "",
				"slot_label": "",
				"role_id": ""
			}
			slot_nodes.append(slot_entry)
		team_role_rows.append({
			"row": row,
			"portrait": portrait,
			"slots": slot_nodes,
			"data": {},
			"key": str(spec["key"]),
			"state": str(spec["state"]),
			"active": bool(spec["active"])
		})
		_layout_team_role_slots(row_index)

func _build_buff_bar() -> void:
	buff_status_bar = HBoxContainer.new()
	buff_status_bar.position = Vector2(6.0, -BUFF_SLOT_SIZE - 7.0)
	buff_status_bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	buff_status_bar.add_theme_constant_override("separation", BUFF_SLOT_GAP)
	buff_status_bar.visible = false
	add_child(buff_status_bar)
	for index in range(SKILL_CD_SLOT_COUNT):
		var buff_icon: BuffStatusIcon = BuffStatusIcon.new()
		buff_icon.custom_minimum_size = Vector2(BUFF_SLOT_SIZE, BUFF_SLOT_SIZE)
		buff_icon.size = Vector2(BUFF_SLOT_SIZE, BUFF_SLOT_SIZE)
		buff_icon.visible = false
		buff_icon.mouse_entered.connect(_on_buff_slot_hovered.bind(buff_icon, index))
		buff_icon.mouse_exited.connect(_on_skill_slot_unhovered)
		buff_status_bar.add_child(buff_icon)
		buff_status_slots.append({
			"view": buff_icon,
			"title": "",
			"description": ""
		})

func _build_experience_strip() -> void:
	experience_bar = ProgressBar.new()
	experience_bar.position = Vector2(0.0, TEAM_STACK_HEIGHT - 15.0)
	experience_bar.custom_minimum_size = Vector2(TEAM_STACK_WIDTH - 36.0, 12.0)
	experience_bar.size = Vector2(TEAM_STACK_WIDTH - 36.0, 12.0)
	experience_bar.show_percentage = false
	var exp_fill := StyleBoxFlat.new()
	exp_fill.bg_color = Color(1.0, 0.82, 0.16, 0.72)
	exp_fill.set_corner_radius_all(5)
	var exp_background := StyleBoxFlat.new()
	exp_background.bg_color = Color(0.12, 0.1, 0.04, 0.38)
	exp_background.border_color = Color(0.92, 0.72, 0.16, 0.46)
	exp_background.set_border_width_all(1)
	exp_background.set_corner_radius_all(5)
	experience_bar.add_theme_stylebox_override("fill", exp_fill)
	experience_bar.add_theme_stylebox_override("background", exp_background)
	team_stack_widget.add_child(experience_bar)

	experience_label = Label.new()
	experience_label.position = Vector2(0.0, TEAM_STACK_HEIGHT - 22.0)
	experience_label.custom_minimum_size = Vector2(TEAM_STACK_WIDTH - 36.0, 22.0)
	experience_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	experience_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	experience_label.add_theme_font_size_override("font_size", 11)
	experience_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.62, 0.76))
	experience_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	experience_label.add_theme_constant_override("shadow_offset_x", 1)
	experience_label.add_theme_constant_override("shadow_offset_y", 1)
	experience_label.text = "0 / 30 XP"
	team_stack_widget.add_child(experience_label)

func _apply_team_stack_layout() -> void:
	if team_stack_widget == null:
		return
	var stack_width: float = _get_team_stack_width()
	team_stack_widget.position = Vector2.ZERO
	var viewport_width := get_viewport_rect().size.x
	var stack_scale := clampf((viewport_width - 36.0) / TEAM_STACK_WIDTH, 0.72, 1.0)
	team_stack_widget.scale = Vector2.ONE * stack_scale
	team_stack_widget.size = Vector2(stack_width, TEAM_STACK_HEIGHT)
	team_stack_widget.custom_minimum_size = Vector2(stack_width, TEAM_STACK_HEIGHT)
	for row_index in range(team_role_rows.size()):
		var row_entry: Dictionary = team_role_rows[row_index]
		var row: TeamRoleStatusRow = row_entry["row"] as TeamRoleStatusRow
		if row == null:
			continue
		var row_active: bool = bool(row_entry.get("active", row_index == 1))
		var row_height: float = TEAM_STACK_ROW_ACTIVE_HEIGHT if row_active else TEAM_STACK_ROW_STANDBY_HEIGHT
		var row_y: float = 0.0
		if row_index == 1:
			row_y = TEAM_STACK_ROW_STANDBY_HEIGHT + TEAM_STACK_ROW_GAP
		elif row_index == 2:
			row_y = TEAM_STACK_ROW_STANDBY_HEIGHT + TEAM_STACK_ROW_GAP + TEAM_STACK_ROW_ACTIVE_HEIGHT + TEAM_STACK_ROW_GAP
		row.position = Vector2(TEAM_STACK_ACTIVE_INDENT if row_active else 0.0, row_y)
		row.size = Vector2(stack_width - (24.0 if row_active else 36.0), row_height)
		row.custom_minimum_size = row.size
		_layout_team_role_slots(row_index)
	if experience_bar != null:
		experience_bar.position = Vector2(0.0, TEAM_STACK_HEIGHT - 9.0)
		experience_bar.size = Vector2(stack_width - 36.0, 7.0)
		experience_bar.custom_minimum_size = experience_bar.size
	if experience_label != null:
		experience_label.position = Vector2(0.0, TEAM_STACK_HEIGHT - 18.0)
		experience_label.custom_minimum_size = Vector2(stack_width - 36.0, 18.0)
		experience_label.size = Vector2(stack_width - 36.0, 18.0)

func _get_team_stack_width() -> float:
	return TEAM_STACK_WIDTH

func update_team_role_statuses(statuses: Array, active_role_id: String, active_role_index: int = 0) -> void:
	team_role_status_by_id.clear()
	var role_ids: Array[String] = []
	for status_value in statuses:
		if status_value is not Dictionary:
			continue
		var status: Dictionary = status_value
		var role_id: String = str(status.get("role_id", ""))
		if role_id == "":
			continue
		role_ids.append(role_id)
		team_role_status_by_id[role_id] = status
	if not role_ids.is_empty():
		set_switch_role_order(role_ids)
	if team_role_rows.is_empty():
		return
	if role_ids.is_empty():
		_apply_empty_team_statuses()
		return
	var resolved_active_index: int = active_role_index
	if resolved_active_index < 0 or resolved_active_index >= role_ids.size() or role_ids[resolved_active_index] != active_role_id:
		resolved_active_index = role_ids.find(active_role_id)
	if resolved_active_index < 0:
		resolved_active_index = 0
	var count: int = role_ids.size()
	var ordered_role_ids: Array[String] = [
		role_ids[(resolved_active_index + count - 1) % count],
		role_ids[resolved_active_index],
		role_ids[(resolved_active_index + 1) % count]
	]
	var key_texts: Array[String] = [_get_switch_prev_key_text(), "当前", _get_switch_next_key_text()]
	var state_texts: Array[String] = [
		_get_switch_target_state_text("上一位"),
		"站场",
		_get_switch_target_state_text("下一位")
	]
	for row_index in range(team_role_rows.size()):
		var row_entry: Dictionary = team_role_rows[row_index]
		var role_id: String = ordered_role_ids[row_index] if row_index < ordered_role_ids.size() else ""
		var status: Dictionary = team_role_status_by_id.get(role_id, {})
		var row_active: bool = row_index == 1
		status = status.duplicate(true)
		status["is_active"] = row_active
		row_entry["data"] = status
		row_entry["key"] = key_texts[row_index]
		row_entry["state"] = state_texts[row_index]
		row_entry["active"] = row_active
		var row: TeamRoleStatusRow = row_entry["row"] as TeamRoleStatusRow
		if row != null:
			row.set_status(status, key_texts[row_index], state_texts[row_index], row_active)
		var portrait: SwitchPortraitDisplay = row_entry.get("portrait", null) as SwitchPortraitDisplay
		var scene_value: Variant = SWITCH_HEAD_SCENES.get(role_id, null)
		if portrait != null and scene_value is PackedScene:
			portrait.set_role_scene(role_id, scene_value)
			var role_energy: float = float(status.get("switch_energy", 0.0))
			var required_energy: float = max(1.0, float(status.get("switch_energy_required", 100.0)))
			portrait.set_state(
				switch_cooldown_remaining_value / switch_cooldown_duration_value,
				role_energy / required_energy,
				row_active
			)
		_update_team_role_slots(row_index, status.get("cooldown_slots", []))

func _apply_empty_team_statuses() -> void:
	var defaults := [
		{"role_id": "swordsman", "role_name": "剑士", "color": Color(1.0, 0.66, 0.35, 1.0), "current_health": 100.0, "max_health": 100.0, "current_mana": 0.0, "max_mana": 100.0, "cooldown_slots": []},
		{"role_id": "gunner", "role_name": "枪手", "color": Color(1.0, 0.35, 0.32, 1.0), "current_health": 50.0, "max_health": 50.0, "current_mana": 0.0, "max_mana": 100.0, "cooldown_slots": []},
		{"role_id": "mage", "role_name": "法师", "color": Color(0.44, 0.86, 1.0, 1.0), "current_health": 50.0, "max_health": 50.0, "current_mana": 0.0, "max_mana": 100.0, "cooldown_slots": []}
	]
	update_team_role_statuses(defaults, "gunner", 1)

func _get_switch_target_state_text(default_text: String) -> String:
	if switch_cooldown_remaining_value > 0.05:
		return "CD %.1fs" % switch_cooldown_remaining_value
	return default_text

func _layout_team_role_slots(row_index: int) -> void:
	if row_index < 0 or row_index >= team_role_rows.size():
		return
	var row_entry: Dictionary = team_role_rows[row_index]
	var row: TeamRoleStatusRow = row_entry["row"] as TeamRoleStatusRow
	if row == null:
		return
	var row_active: bool = bool(row_entry.get("active", row_index == 1))
	var portrait: SwitchPortraitDisplay = row_entry.get("portrait", null) as SwitchPortraitDisplay
	if portrait != null:
		var portrait_size := Vector2.ONE * (100.0 if row_active else 74.0)
		var emblem_center := Vector2(117.0 if row_active else 96.5, row.size.y * 0.5)
		portrait.position = emblem_center - portrait_size * 0.5
		portrait.size = portrait_size
		portrait.custom_minimum_size = portrait_size
	var slot_size: float = TEAM_STACK_SLOT_SIZE_ACTIVE if row_active else TEAM_STACK_SLOT_SIZE_STANDBY
	var slot_gap: float = TEAM_STACK_SLOT_GAP_ACTIVE if row_active else TEAM_STACK_SLOT_GAP_STANDBY
	var slots: Array = row_entry["slots"]
	var basic_attack_gap: float = TEAM_STACK_BASIC_ATTACK_GAP if slots.size() > 1 else 0.0
	var slot_area_width: float = float(slots.size()) * slot_size + max(0.0, float(slots.size() - 1)) * slot_gap + basic_attack_gap
	var start_x: float = row.size.x - slot_area_width - 18.0
	var start_y: float = (row.size.y - slot_size) * 0.5
	for slot_index in range(slots.size()):
		var slot_nodes: Dictionary = slots[slot_index]
		var slot_view: SkillCooldownIcon = slot_nodes["view"] as SkillCooldownIcon
		var label: Label = slot_nodes["label"] as Label
		var key_label: Label = slot_nodes.get("key_label", null) as Label
		if slot_view != null:
			slot_view.position = Vector2(start_x + float(slot_index) * (slot_size + slot_gap) + (basic_attack_gap if slot_index > 0 else 0.0), start_y)
			slot_view.size = Vector2(slot_size, slot_size)
			slot_view.custom_minimum_size = Vector2(slot_size, slot_size)
		if label != null:
			label.add_theme_font_size_override("font_size", 14 if row_active else 12)
		if key_label != null:
			key_label.position = Vector2(0.0, 0.0)
			key_label.size = Vector2(slot_size, 14.0)
			key_label.custom_minimum_size = Vector2(slot_size, 14.0)

func _update_team_role_slots(row_index: int, slot_data_list: Array) -> void:
	if row_index < 0 or row_index >= team_role_rows.size():
		return
	_layout_team_role_slots(row_index)
	var row_entry: Dictionary = team_role_rows[row_index]
	var slots: Array = row_entry["slots"]
	var row_active: bool = bool(row_entry.get("active", row_index == 1))
	for slot_index in range(slots.size()):
		var slot_nodes: Dictionary = slots[slot_index]
		var slot_view: SkillCooldownIcon = slot_nodes["view"] as SkillCooldownIcon
		var label: Label = slot_nodes["label"] as Label
		if slot_index >= slot_data_list.size():
			slot_nodes["role_id"] = str((row_entry.get("data", {}) as Dictionary).get("role_id", ""))
			slot_nodes["skill_id"] = ""
			slot_nodes["can_upgrade"] = false
			slot_nodes["can_learn"] = slot_index > 0 and not slot_data_list.is_empty()
			_set_slot_upgrade_state(slot_nodes, {}, row_active)
			_clear_skill_detail(slot_nodes)
			slot_view.set_state(false, Color(0.12, 0.13, 0.16, 1.0), 0.0)
			slot_view.set_auto_mode(false)
			if label.text != "":
				label.text = ""
			var empty_key_label: Label = slot_nodes.get("key_label", null) as Label
			if empty_key_label != null and empty_key_label.text != "":
				empty_key_label.text = ""
			slot_nodes["title"] = "空技能槽"
			slot_nodes["description"] = "该位置保留给此角色后续解锁的技能。"
			slot_nodes["base_description"] = ""
			slot_nodes["skill_id"] = ""
			slot_nodes["slot_label"] = "预留槽"
			continue

		var slot_data: Dictionary = slot_data_list[slot_index]
		slot_nodes["role_id"] = str(slot_data.get("role_id", (row_entry.get("data", {}) as Dictionary).get("role_id", "")))
		_set_slot_upgrade_state(slot_nodes, slot_data, row_active)
		var slot_color: Color = Color(1.0, 1.0, 1.0, 1.0)
		var color_value: Variant = slot_data.get("color", slot_color)
		if color_value is Color:
			slot_color = color_value
		if not row_active:
			slot_color = Color(slot_color.r * 0.72, slot_color.g * 0.72, slot_color.b * 0.72, 0.88)
		var duration: float = max(float(slot_data.get("duration", 1.0)), 0.01)
		var remaining: float = clamp(float(slot_data.get("remaining", 0.0)), 0.0, duration)
		var ratio: float = remaining / duration
		slot_view.set_state(true, slot_color, ratio)
		var slot_name: String = str(slot_data.get("name", "技能"))
		var display_text: String = _get_slot_display_text(str(slot_data.get("hud_name", slot_name)), row_active)
		if label.text != display_text:
			label.text = display_text
		slot_view.tooltip_text = ""
		slot_nodes["title"] = slot_name
		var skill_id: String = str(slot_data.get("skill_id", ""))
		var base_description: String = str(slot_data.get("description", ""))
		if base_description == "" and str(slot_nodes.get("skill_id", "")) == skill_id:
			base_description = str(slot_nodes.get("base_description", ""))
		elif base_description != "":
			slot_nodes["base_description"] = base_description
		slot_nodes["skill_id"] = skill_id
		var tooltip_data := slot_data.duplicate(true)
		tooltip_data["description"] = base_description
		slot_nodes["description"] = _build_slot_tooltip(tooltip_data, duration, remaining)
		slot_nodes["slot_label"] = str(slot_data.get("slot_label", "技能冷却"))
		_apply_team_slot_key_label(slot_nodes, slot_index, skill_id, slot_data)
		slot_nodes["role_active"] = row_active
		_remember_skill_detail(slot_nodes, slot_data, duration, remaining)
	_refresh_skill_point_buttons()

func _apply_team_slot_key_label(slot_nodes: Dictionary, slot_index: int, skill_id: String, slot_data: Dictionary) -> void:
	var key_label: Label = slot_nodes.get("key_label", null) as Label
	var slot_view: SkillCooldownIcon = slot_nodes.get("view", null) as SkillCooldownIcon
	if slot_view != null:
		slot_view.set_auto_mode(slot_index > 0 and skill_id != "" and not GAME_SETTINGS.is_skill_manual(skill_id) and not bool(slot_data.get("toggle_mode", false)))
	if key_label == null:
		return
	if slot_index == 0 or skill_id == "":
		if key_label.text != "":
			key_label.text = ""
		return
	var key_slot_index: int = int(slot_data.get("manual_slot_index", slot_index))
	if key_slot_index <= 0:
		key_slot_index = slot_index
	var action_id := GAME_SETTINGS.get_skill_slot_action_id(key_slot_index)
	var key_text := GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(action_id))
	if key_label.text != key_text:
		key_label.text = key_text
	key_label.add_theme_color_override("font_color", SKILL_SLOT_MANUAL_COLOR if GAME_SETTINGS.is_skill_manual(skill_id) or bool(slot_data.get("toggle_mode", false)) else SKILL_SLOT_AUTO_COLOR)

func _on_team_skill_slot_gui_input(event: InputEvent, row_index: int, slot_index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if row_index < 0 or row_index >= team_role_rows.size():
		return
	var row_entry: Dictionary = team_role_rows[row_index]
	var slots: Array = row_entry.get("slots", [])
	if slot_index < 0 or slot_index >= slots.size():
		return
	var slot_nodes: Dictionary = slots[slot_index]
	var skill_id := str(slot_nodes.get("skill_id", ""))
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_emit_skill_mode_toggle(skill_id)
		accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
		var role_id := str((row_entry.get("data", {}) as Dictionary).get("role_id", ""))
		_begin_skill_slot_drag(slot_index, role_id, skill_id, str(slot_nodes.get("title", "")))
		accept_event()


func _begin_skill_slot_drag(slot_index: int, role_id: String, skill_id: String, title: String) -> void:
	hovered_skill_view = null
	hover_detail.hide_detail()
	if slot_index < 1 or skill_id == "":
		return
	var key_slot_index := slot_index
	var key_text := GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.get_skill_slot_action_id(key_slot_index)))
	var display_title := title if title != "" else skill_id
	skill_slot_drag_state = {
		"armed": true,
		"active": false,
		"from_slot": slot_index,
		"role_id": role_id,
		"skill_id": skill_id,
		"origin": get_global_mouse_position(),
		"ghost": null,
		"ghost_text": "%s  %s" % [display_title, key_text]
	}


func _input(event: InputEvent) -> void:
	if not bool(skill_slot_drag_state.get("armed", false)):
		return
	if event is InputEventMouseMotion:
		var mouse_position := get_global_mouse_position()
		if not bool(skill_slot_drag_state.get("active", false)):
			var origin: Vector2 = skill_slot_drag_state.get("origin", mouse_position)
			if origin.distance_to(mouse_position) < SKILL_SLOT_DRAG_THRESHOLD:
				return
			skill_slot_drag_state["active"] = true
			_create_skill_slot_drag_ghost()
		_update_skill_slot_drag_ghost(mouse_position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			if bool(skill_slot_drag_state.get("active", false)):
				_finish_skill_slot_drag()
			else:
				_cancel_skill_slot_drag()


func _create_skill_slot_drag_ghost() -> void:
	var ghost := PanelContainer.new()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.z_index = 200
	ghost.modulate = Color(1.0, 1.0, 1.0, 0.94)
	SURVIVORS_THEME.apply_campaign_frame(ghost, "card")
	var label := Label.new()
	label.text = str(skill_slot_drag_state.get("ghost_text", ""))
	label.add_theme_font_size_override("font_size", SKILL_SLOT_DRAG_GHOST_FONT_SIZE)
	label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78, 1.0))
	ghost.add_child(label)
	add_child(ghost)
	ghost.reset_size()
	ghost.pivot_offset = ghost.size * 0.5
	skill_slot_drag_state["ghost"] = ghost
	_update_skill_slot_drag_ghost(get_global_mouse_position())


func _update_skill_slot_drag_ghost(mouse_position: Vector2) -> void:
	var ghost: Control = skill_slot_drag_state.get("ghost", null) as Control
	if ghost == null or not is_instance_valid(ghost):
		return
	ghost.global_position = mouse_position - ghost.size * 0.5


func _find_skill_slot_at(mouse_position: Vector2) -> Dictionary:
	for index in range(1, skill_cd_slots.size()):
		var nodes: Dictionary = skill_cd_slots[index]
		var view: SkillCooldownIcon = nodes.get("view", null) as SkillCooldownIcon
		if view == null or not view.is_visible_in_tree() or str(nodes.get("skill_id", "")) == "":
			continue
		if view.get_global_rect().has_point(mouse_position):
			return {"slot_index": index, "role_id": "", "center": view.get_global_rect().get_center(), "view": view}
	var drag_role_id := str(skill_slot_drag_state.get("role_id", ""))
	for row_index in range(team_role_rows.size()):
		var row_entry: Dictionary = team_role_rows[row_index]
		var role_id := str((row_entry.get("data", {}) as Dictionary).get("role_id", ""))
		if drag_role_id != "" and role_id != drag_role_id:
			continue
		var slots: Array = row_entry.get("slots", [])
		for slot_index in range(1, slots.size()):
			var nodes: Dictionary = slots[slot_index]
			var view: SkillCooldownIcon = nodes.get("view", null) as SkillCooldownIcon
			if view == null or not view.is_visible_in_tree() or str(nodes.get("skill_id", "")) == "":
				continue
			if view.get_global_rect().has_point(mouse_position):
				return {"slot_index": slot_index, "role_id": role_id, "center": view.get_global_rect().get_center(), "view": view}
	return {}


func _get_skill_slot_view(slot_index: int, role_id: String) -> SkillCooldownIcon:
	if role_id == "":
		if slot_index >= 0 and slot_index < skill_cd_slots.size():
			return (skill_cd_slots[slot_index] as Dictionary).get("view", null) as SkillCooldownIcon
		return null
	for row_entry_value in team_role_rows:
		var row_entry: Dictionary = row_entry_value
		var row_role_id := str((row_entry.get("data", {}) as Dictionary).get("role_id", ""))
		if row_role_id != role_id:
			continue
		var slots: Array = row_entry.get("slots", [])
		if slot_index >= 0 and slot_index < slots.size():
			return (slots[slot_index] as Dictionary).get("view", null) as SkillCooldownIcon
	return null


func _finish_skill_slot_drag() -> void:
	var mouse_position := get_global_mouse_position()
	var target := _find_skill_slot_at(mouse_position)
	var from_slot := int(skill_slot_drag_state.get("from_slot", 0))
	var drag_role_id := str(skill_slot_drag_state.get("role_id", ""))
	var ghost: Control = skill_slot_drag_state.get("ghost", null) as Control
	var source_view := _get_skill_slot_view(from_slot, drag_role_id)
	if not target.is_empty() and int(target.get("slot_index", 0)) != from_slot:
		var target_slot := int(target.get("slot_index", 0))
		var target_view: SkillCooldownIcon = target.get("view", null) as SkillCooldownIcon
		var target_center: Vector2 = target.get("center", mouse_position)
		_play_skill_slot_swap_animation(ghost, source_view, target_view, target_center)
		skill_slot_swap_requested.emit(drag_role_id, from_slot, target_slot)
	else:
		_dispose_skill_slot_drag_ghost(ghost)
	skill_slot_drag_state = {}


func _cancel_skill_slot_drag() -> void:
	_dispose_skill_slot_drag_ghost(skill_slot_drag_state.get("ghost", null) as Control)
	skill_slot_drag_state = {}


func _dispose_skill_slot_drag_ghost(ghost: Control) -> void:
	if ghost != null and is_instance_valid(ghost):
		ghost.queue_free()


func _play_skill_slot_swap_animation(ghost: Control, source_view: Control, target_view: Control, target_center: Vector2) -> void:
	if ghost != null and is_instance_valid(ghost):
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(ghost, "global_position", target_center - ghost.size * 0.5, SKILL_SLOT_SWAP_ANIMATION_DURATION)
		tween.tween_property(ghost, "scale", Vector2(0.55, 0.55), SKILL_SLOT_SWAP_ANIMATION_DURATION)
		tween.tween_property(ghost, "modulate:a", 0.0, SKILL_SLOT_SWAP_ANIMATION_DURATION)
		tween.chain().tween_callback(ghost.queue_free)
	_pulse_skill_slot_view(source_view)
	_pulse_skill_slot_view(target_view)


func _pulse_skill_slot_view(view: Control) -> void:
	if view == null or not is_instance_valid(view):
		return
	view.pivot_offset = view.size * 0.5
	var tween := create_tween()
	tween.tween_property(view, "scale", Vector2(1.14, 1.14), 0.1)
	tween.tween_property(view, "scale", Vector2.ONE, 0.16)

func _get_slot_display_text(slot_name: String, _row_active: bool) -> String:
	var max_length: int = 2
	if slot_name.length() <= max_length:
		return slot_name
	return slot_name.substr(0, max_length)

func set_switch_widget_visible(visible_value: bool) -> void:
	if team_stack_widget != null:
		team_stack_widget.visible = visible_value
	if switch_cd_widget != null:
		switch_cd_widget.visible = visible_value

func _get_switch_role_order() -> Array:
	return switch_role_order if not switch_role_order.is_empty() else SWITCH_ROLE_ORDER


func set_switch_role_order(role_ids: Array) -> void:
	var normalized: Array = []
	for role_value in role_ids:
		var role_id := str(role_value)
		if role_id != "" and SWITCH_HEAD_SCENES.has(role_id) and not normalized.has(role_id):
			normalized.append(role_id)
	if normalized.is_empty() or normalized == switch_role_order:
		return
	switch_role_order = normalized
	if switch_cd_widget != null:
		_rebuild_switch_portraits()


func _build_switch_portraits() -> void:
	for switch_role_id in _get_switch_role_order():
		var switch_role_id_string: String = str(switch_role_id)
		var portrait := SwitchPortraitDisplay.new()
		portrait.size = Vector2(56.0, 56.0) * SWITCH_HEAD_SIZE_MULTIPLIER
		portrait.custom_minimum_size = Vector2(56.0, 56.0) * SWITCH_HEAD_SIZE_MULTIPLIER
		var scene_value: Variant = SWITCH_HEAD_SCENES.get(switch_role_id_string, null)
		if scene_value is PackedScene:
			portrait.set_role_scene(switch_role_id_string, scene_value)
		switch_cd_widget.add_child(portrait)
		switch_cd_portraits[switch_role_id_string] = portrait


func _rebuild_switch_portraits() -> void:
	for portrait_value in switch_cd_portraits.values():
		var portrait := portrait_value as SwitchPortraitDisplay
		if portrait != null and is_instance_valid(portrait):
			switch_cd_widget.remove_child(portrait)
			portrait.queue_free()
	switch_cd_portraits.clear()
	_build_switch_portraits()
	if not _get_switch_role_order().has(switch_cd_active_role_id):
		switch_cd_active_role_id = str(_get_switch_role_order()[0])
	_layout_switch_portraits(switch_cd_active_role_id, false)
	switch_cd_layout_initialized = true


func _layout_switch_portraits(active_role_id: String, animate: bool) -> void:
	var role_order := _get_switch_role_order()
	var active_index: int = role_order.find(active_role_id)
	if active_index < 0:
		active_index = 1
	var role_count: int = role_order.size()
	var left_role_id: String = str(role_order[(active_index + role_count - 1) % role_count])
	var top_role_id: String = str(role_order[active_index])
	var right_role_id: String = str(role_order[(active_index + 1) % role_count])
	if switch_cd_layout_tween != null and switch_cd_layout_tween.is_valid():
		switch_cd_layout_tween.kill()
	switch_cd_layout_tween = create_tween() if animate else null
	if switch_cd_layout_tween != null:
		switch_cd_layout_tween.set_parallel(true)
		switch_cd_layout_tween.set_trans(Tween.TRANS_CUBIC)
		switch_cd_layout_tween.set_ease(Tween.EASE_OUT)
	_place_switch_portrait(left_role_id, Vector2(-44.0, -24.0), Vector2(54.0, 54.0) * SWITCH_HEAD_SIZE_MULTIPLIER, 0, animate)
	_place_switch_portrait(top_role_id, Vector2(-2.0, -52.0), Vector2(72.0, 72.0) * SWITCH_HEAD_SIZE_MULTIPLIER, 1, animate)
	_place_switch_portrait(right_role_id, Vector2(85.0, -24.0), Vector2(54.0, 54.0) * SWITCH_HEAD_SIZE_MULTIPLIER, 0, animate)

func _place_switch_portrait(role_id: String, next_position: Vector2, next_size: Vector2, z_index_value: int, animate: bool) -> void:
	var portrait: SwitchPortraitDisplay = switch_cd_portraits.get(role_id, null) as SwitchPortraitDisplay
	if portrait == null:
		return
	portrait.custom_minimum_size = next_size
	portrait.z_index = z_index_value
	if animate and switch_cd_layout_tween != null:
		switch_cd_layout_tween.tween_property(portrait, "position", next_position, SWITCH_PORTRAIT_ANIMATION_DURATION)
		switch_cd_layout_tween.tween_property(portrait, "size", next_size, SWITCH_PORTRAIT_ANIMATION_DURATION)
		switch_cd_layout_tween.tween_callback(Callable(portrait, "_fit_head_node")).set_delay(SWITCH_PORTRAIT_ANIMATION_DURATION)
		return
	portrait.position = next_position
	portrait.size = next_size
	portrait._fit_head_node()

func _build_slot_tooltip(slot_data: Dictionary, duration: float, remaining: float) -> String:
	var description := str(slot_data.get("description", ""))
	var status := "剩余 %.1f / %.1f 秒" % [remaining, duration] if remaining > 0.05 else "冷却就绪"
	if description == "":
		description = status
	else:
		description = "%s\n%s" % [description, status]
	return description

func _on_team_role_row_hovered(row_index: int) -> void:
	hovered_skill_view = null
	if row_index < 0 or row_index >= team_role_rows.size():
		return
	var row_entry: Dictionary = team_role_rows[row_index]
	var row: Control = row_entry["row"] as Control
	var data: Dictionary = row_entry.get("data", {})
	if data.is_empty() or row == null:
		return
	var role_name: String = str(data.get("role_name", "角色"))
	var current_health: float = float(data.get("current_health", 0.0))
	var max_health: float = max(1.0, float(data.get("max_health", 1.0)))
	var current_mana: float = float(data.get("current_mana", 0.0))
	var max_mana: float = max(1.0, float(data.get("max_mana", 1.0)))
	var switch_energy: float = float(data.get("switch_energy", 0.0))
	var switch_energy_required: float = max(1.0, float(data.get("switch_energy_required", 100.0)))
	var key_text: String = str(row_entry.get("key", ""))
	var slot_label: String = "当前站场" if bool(row_entry.get("active", false)) else "%s 切换目标" % key_text
	var item := {
		"title": role_name,
		"slot_label": slot_label,
		"description": "HP %.0f / %.0f\nMP %.0f / %.0f\n切换能量 %.0f / %.0f\n切换冷却 %s\n\n上方为上一位，下方为下一位；当前站场角色固定在中间并高亮。" % [
			current_health,
			max_health,
			current_mana,
			max_mana,
			switch_energy,
			switch_energy_required,
			("%.1f 秒" % switch_cooldown_remaining_value) if switch_cooldown_remaining_value > 0.05 else "就绪"
		]
	}
	_request_hover_detail(item, Rect2(row.global_position, row.size))

func _clear_skill_detail(nodes: Dictionary) -> void:
	nodes.erase("detail_data")
	if is_instance_valid(hovered_skill_view) and hovered_skill_view == nodes.get("view"):
		hover_detail.hide_detail()
		hovered_skill_view = null

func _remember_skill_detail(nodes: Dictionary, data: Dictionary, duration: float, remaining: float) -> void:
	var previous: Dictionary = nodes.get("detail_data", {})
	var changed := str(previous.get("skill_id", "")) != str(data.get("skill_id", ""))
	var info_changed: bool = str(data.get("description", "")) != "" and (previous.get("effect_rows", []) != data.get("effect_rows", []) or previous.get("current_level", 0) != data.get("current_level", 0))
	if changed or str(data.get("description", "")) != "":
		nodes["detail_data"] = data.duplicate(true)
	var detail: Dictionary = nodes.get("detail_data", {})
	detail["duration"] = duration
	detail["remaining"] = remaining
	detail["role_active"] = bool(nodes.get("role_active", true))
	if not is_instance_valid(hovered_skill_view):
		hovered_skill_view = null
	if hovered_skill_view == nodes.get("view") and hover_detail.visible:
		if changed or hovered_skill_id != str(data.get("skill_id", "")):
			hover_detail.hide_detail()
			hovered_skill_view = null
		else:
			var mode_changed: bool = not bool(detail.get("toggle_mode", false)) and not hovered_skill_id.ends_with("_basic_attack") and hover_detail.category_label.text.contains("手动释放") != GAME_SETTINGS.is_skill_manual(hovered_skill_id)
			if info_changed or mode_changed:
				_show_skill_detail(nodes, hovered_skill_view, int(detail.get("manual_slot_index", 0)))
			else:
				hover_detail.update_status(_skill_status(detail), remaining <= 0.05 and bool(detail.get("role_active", true)))

func _skill_status(data: Dictionary) -> String:
	var remaining := float(data.get("remaining", 0.0))
	var status := "冷却中 · 还需 %.1f 秒" % remaining if remaining > 0.05 else "冷却就绪"
	return status if bool(data.get("role_active", true)) else "待命角色 · " + status

func _show_skill_detail(nodes: Dictionary, view: Control, slot_index: int, role_name: String = "") -> void:
	hover_request_serial += 1
	var request_serial := hover_request_serial
	await get_tree().create_timer(HOVER_DETAIL_DELAY, true).timeout
	if request_serial != hover_request_serial or view == null or not is_instance_valid(view):
		return
	if not view.get_global_rect().has_point(get_viewport().get_mouse_position()):
		return
	_show_skill_detail_now(nodes, view, slot_index, role_name)

func _show_skill_detail_now(nodes: Dictionary, view: Control, slot_index: int, role_name: String = "") -> void:
	var data: Dictionary = (nodes.get("detail_data", {}) as Dictionary).duplicate(true)
	if data.is_empty():
		if str(nodes.get("description", "")) != "":
			hovered_skill_view = null
			hover_detail.show_item({"title": nodes.get("title", "技能"), "description": nodes["description"]}, get_viewport().get_mouse_position(), view.get_global_rect())
		return
	var skill_id := str(data.get("skill_id", ""))
	data["title"] = str(nodes.get("title", "技能"))
	data["description"] = str(data.get("description", "")).split("\n\n进化需求：")[0]
	if role_name != "":
		data["role_name"] = role_name
	data["slot_label"] = "普通攻击" if slot_index == 0 else ("手动释放" if GAME_SETTINGS.is_skill_manual(skill_id) else "自动释放")
	if bool(data.get("toggle_mode", false)):
		data["slot_label"] = "开关技能"
	data["status_text"] = _skill_status(data)
	data["status_ready"] = float(data.get("remaining", 0.0)) <= 0.05 and bool(data.get("role_active", true))
	var key := GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_CHARACTER_PANEL))
	var hint := "%s 查看角色面板" % key
	if slot_index > 0:
		var skill_key := GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.get_skill_slot_action_id(int(data.get("manual_slot_index", slot_index)))))
		hint = "手动时按 %s 释放 · 右键切换模式 · %s 角色面板" % [skill_key, key]
		if bool(data.get("toggle_mode", false)):
			hint = "按 %s 开启或关闭 · %s 角色面板" % [skill_key, key]
	data["effect_note"] = str(data.get("effect_note", "")) + ("\n" if str(data.get("effect_note", "")) != "" else "") + hint
	hovered_skill_view = view
	hovered_skill_id = skill_id
	var anchor_rect := view.get_global_rect()
	anchor_rect.position.y = minf(anchor_rect.position.y, global_position.y)
	hover_detail.show_item(data, get_viewport().get_mouse_position(), anchor_rect)

func _on_team_role_skill_slot_hovered(row_index: int, slot_index: int, slot_icon: Control) -> void:
	if row_index < 0 or row_index >= team_role_rows.size():
		return
	var entry: Dictionary = team_role_rows[row_index]
	var slots: Array = entry.get("slots", [])
	if slot_index >= 0 and slot_index < slots.size():
		_show_skill_detail(slots[slot_index], slot_icon, slot_index, str((entry.get("data", {}) as Dictionary).get("role_name", "")))

func _on_skill_slot_hovered(slot_icon: Control, index: int) -> void:
	if index >= 0 and index < skill_cd_slots.size():
		_show_skill_detail(skill_cd_slots[index], slot_icon, index)

func _on_buff_slot_hovered(slot_icon: Control, index: int) -> void:
	hovered_skill_view = null
	if index < 0 or index >= buff_status_slots.size():
		return
	var slot_nodes: Dictionary = buff_status_slots[index]
	var title := str(slot_nodes.get("title", ""))
	var description := str(slot_nodes.get("description", ""))
	if title == "" or description == "":
		return
	var item := {
		"title": title,
		"slot_label": "Buff",
		"description": description
	}
	_request_hover_detail(item, Rect2(slot_icon.global_position, slot_icon.size))

func _on_ultimate_energy_hovered() -> void:
	hovered_skill_view = null
	if ultimate_energy_widget == null:
		return
	var ultimate_key := ""
	if ultimate_key_label != null:
		ultimate_key = ultimate_key_label.text
	if ultimate_key == "":
		ultimate_key = GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_ULTIMATE))
	var status := "已充满，可以按 %s 释放大招。" % ultimate_key if ultimate_current_energy >= ultimate_required_energy else "还需 %.0f 点能量。" % max(0.0, ultimate_required_energy - ultimate_current_energy)
	var ultimate_name := str(ultimate_display.get("name", "大招"))
	var ultimate_description := str(ultimate_display.get("description", "当前英雄的大招。"))
	var item := {
		"title": ultimate_name,
		"slot_label": "大招 / 能量",
		"description": "%s\n\n能量 %.0f / %.0f。\n%s\n攻击命中与战斗节奏会积累大招能量，充满后释放当前角色的大招。" % [
			ultimate_description,
			ultimate_current_energy,
			ultimate_required_energy,
			status
		]
	}
	_request_hover_detail(item, Rect2(ultimate_energy_widget.global_position, ultimate_energy_widget.size))

func _on_skill_slot_unhovered() -> void:
	_cancel_hover_detail()
	if hover_detail != null:
		if hover_detail.has_method("request_hide"):
			hover_detail.request_hide()
		elif hover_detail.has_method("hide_detail"):
			hover_detail.hide_detail()

func _request_hover_detail(item: Dictionary, anchor_rect: Rect2) -> void:
	hover_request_serial += 1
	var request_serial := hover_request_serial
	await get_tree().create_timer(HOVER_DETAIL_DELAY, true).timeout
	if request_serial != hover_request_serial:
		return
	if not anchor_rect.has_point(get_viewport().get_mouse_position()):
		return
	if hover_detail != null and hover_detail.has_method("show_item"):
		hover_detail.show_item(item, get_viewport().get_mouse_position(), anchor_rect)


func _cancel_hover_detail(hide_visible: bool = false) -> void:
	hover_request_serial += 1
	if hide_visible and hover_detail != null:
		hover_detail.hide_detail()

func _refresh_switch_key_labels() -> void:
	_refresh_action_key_labels()

func _get_switch_prev_key_text() -> String:
	return GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_SWITCH_PREV))

func _get_switch_next_key_text() -> String:
	return GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_SWITCH_NEXT))

func _refresh_action_key_labels(force: bool = false) -> void:
	if action_key_labels_ready and not force:
		return
	if switch_cd_left_key_label != null:
		switch_cd_left_key_label.text = _get_switch_prev_key_text()
	if switch_cd_right_key_label != null:
		switch_cd_right_key_label.text = _get_switch_next_key_text()
	if ultimate_key_label != null:
		ultimate_key_label.text = GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_ULTIMATE))
	action_key_labels_ready = true
