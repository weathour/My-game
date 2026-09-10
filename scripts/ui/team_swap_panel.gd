extends Control

signal team_changed(team_order: Array)
signal closed

const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const ROLE_DATABASE := preload("res://scripts/player/roles/role_database.gd")
const ROLE_PRESENTER := preload("res://scripts/player/player_role_presenter.gd")
const SAVE_PROFILE_DEFAULTS := preload("res://scripts/save/save_profile_defaults.gd")
const SURVIVORS_MODAL := preload("res://scripts/ui/core/survivors_modal.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")

const TEAM_SIZE := 3

const TEXT_TITLE := "队伍整备"
const TEXT_HINT := "选择一名候补成员与一名上场队员进行替换。"
const TEXT_TEAM_SECTION := "当前队伍（3人）"
const TEXT_CANDIDATE_SECTION := "候补成员"
const TEXT_CANDIDATE_EMPTY := "暂无候补成员。\n新角色会随 roster 扩充加入，届时可在此调整队伍。"
const TEXT_SWAP := "替换"
const TEXT_CLOSE := "关闭"
const TEXT_SWAP_DONE := "已将%s替换为%s，新阵容将在下一局战斗生效。"
const TEXT_NEED_BOTH := "请先选择一名候补成员和一名要替换的队员。"
const TEXT_NOT_UNLOCKED := "该角色尚未解锁，无法加入队伍。"
const TEXT_ALREADY_IN_TEAM := "该角色已在队伍中。"
const TEXT_OUTSIDE_TEAM := "替换目标不在当前队伍中。"
const TEXT_TEAM_SIZE := "队伍必须恰好3人。"
const TEXT_TEAM_DUPLICATE := "队伍成员不能重复。"
const TEXT_UNKNOWN_ROLE := "未知角色，无法加入队伍。"
const TEXT_PROFILE_MISSING := "未找到当前存档，无法调整队伍。"
const TEXT_SAVE_FAILED := "存档写入失败，请重试。"
const TEXT_SELECTED := "已选中"

var mode := ""
var profile: Dictionary = {}
var selected_team_role := ""
var selected_candidate_role := ""
var modal: Control
var team_list: VBoxContainer
var candidate_list: VBoxContainer
var candidate_empty_label: Label
var feedback_label: Label
var swap_button: Button
var close_button: Button
var team_buttons: Dictionary = {}
var candidate_buttons: Dictionary = {}

static func get_team_ids(profile_data: Dictionary) -> Array:
	var result: Array = []
	var stored: Variant = profile_data.get("team_order", [])
	if stored is Array:
		for role_variant in stored:
			var role_id := str(role_variant)
			if role_id != "" and not result.has(role_id):
				result.append(role_id)
	if result.is_empty():
		result = ROLE_DATABASE.DEFAULT_TEAM_IDS.duplicate()
	return result

static func get_unlocked_ids(profile_data: Dictionary) -> Array:
	var stored: Variant = profile_data.get("unlocked_role_ids", SAVE_PROFILE_DEFAULTS.DEFAULT_ROLE_IDS)
	if not (stored is Array) or (stored as Array).is_empty():
		stored = SAVE_PROFILE_DEFAULTS.DEFAULT_ROLE_IDS
	var result: Array = []
	for role_variant in stored:
		var role_id := str(role_variant)
		if role_id in ROLE_DATABASE.ROLE_IDS and not result.has(role_id):
			result.append(role_id)
	if result.is_empty():
		result = SAVE_PROFILE_DEFAULTS.DEFAULT_ROLE_IDS.duplicate()
	return result

static func get_candidates(profile_data: Dictionary) -> Array:
	var team := get_team_ids(profile_data)
	var result: Array = []
	for role_id in get_unlocked_ids(profile_data):
		if not team.has(role_id):
			result.append(role_id)
	return result

static func validate_team(team_order: Array) -> Dictionary:
	if team_order.size() != TEAM_SIZE:
		return {"valid": false, "error": TEXT_TEAM_SIZE}
	var seen: Array = []
	for role_variant in team_order:
		var role_id := str(role_variant)
		if not (role_id in ROLE_DATABASE.ROLE_IDS):
			return {"valid": false, "error": TEXT_UNKNOWN_ROLE}
		if seen.has(role_id):
			return {"valid": false, "error": TEXT_TEAM_DUPLICATE}
		seen.append(role_id)
	return {"valid": true, "error": ""}

static func build_swapped_team(team_order: Array, out_role_id: String, in_role_id: String, unlocked_ids: Array) -> Dictionary:
	if out_role_id == "" or in_role_id == "":
		return {"success": false, "error": TEXT_NEED_BOTH, "team_order": team_order.duplicate()}
	if not unlocked_ids.has(in_role_id):
		return {"success": false, "error": TEXT_NOT_UNLOCKED, "team_order": team_order.duplicate()}
	var slot_index := -1
	for index in range(team_order.size()):
		if str(team_order[index]) == out_role_id:
			slot_index = index
			break
	if slot_index < 0:
		return {"success": false, "error": TEXT_OUTSIDE_TEAM, "team_order": team_order.duplicate()}
	if team_order.has(in_role_id):
		return {"success": false, "error": TEXT_ALREADY_IN_TEAM, "team_order": team_order.duplicate()}
	var swapped := team_order.duplicate()
	swapped[slot_index] = in_role_id
	var validation := validate_team(swapped)
	if not bool(validation.get("valid", false)):
		return {"success": false, "error": str(validation.get("error", "")), "team_order": team_order.duplicate()}
	return {"success": true, "error": "", "team_order": swapped}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_panel()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()

func open(target_mode: String) -> void:
	mode = target_mode
	_open_with_profile(_load_profile())

func close_panel() -> void:
	if not visible:
		return
	visible = false
	selected_team_role = ""
	selected_candidate_role = ""
	closed.emit()

func _open_with_profile(loaded_profile: Dictionary) -> void:
	profile = loaded_profile
	selected_team_role = ""
	selected_candidate_role = ""
	feedback_label.text = "" if not profile.is_empty() else TEXT_PROFILE_MISSING
	_refresh_lists()
	visible = true
	if modal != null and modal.has_method("apply_layout"):
		modal.apply_layout()
	_grab_initial_focus()

func _load_profile() -> Dictionary:
	if mode == SAVE_MANAGER.MODE_ENDLESS:
		return SAVE_MANAGER.get_current_endless_profile()
	if mode == SAVE_MANAGER.MODE_STORY:
		return SAVE_MANAGER.load_story_profile()
	return {}

func _persist_profile() -> bool:
	if mode == SAVE_MANAGER.MODE_ENDLESS:
		return SAVE_MANAGER.save_endless_profile(profile) > 0
	if mode == SAVE_MANAGER.MODE_STORY:
		SAVE_MANAGER.save_story_profile(profile)
	return true

func _build_panel() -> void:
	modal = SURVIVORS_MODAL.new()
	add_child(modal)
	modal.configure(Vector2(920.0, 600.0), 0.68, 0.78, Vector2(520.0, 380.0))
	modal.set_title(TEXT_TITLE)
	modal.set_hint(TEXT_HINT)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	modal.set_body(body)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	body.add_child(columns)

	var team_column := VBoxContainer.new()
	team_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	team_column.add_theme_constant_override("separation", 10)
	columns.add_child(team_column)
	team_column.add_child(_make_section_label(TEXT_TEAM_SECTION))
	team_list = VBoxContainer.new()
	team_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	team_list.add_theme_constant_override("separation", 10)
	team_column.add_child(team_list)

	var candidate_column := VBoxContainer.new()
	candidate_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	candidate_column.add_theme_constant_override("separation", 10)
	columns.add_child(candidate_column)
	candidate_column.add_child(_make_section_label(TEXT_CANDIDATE_SECTION))
	candidate_list = VBoxContainer.new()
	candidate_list.add_theme_constant_override("separation", 10)
	candidate_column.add_child(candidate_list)
	candidate_empty_label = Label.new()
	candidate_empty_label.text = TEXT_CANDIDATE_EMPTY
	candidate_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	candidate_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	candidate_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	candidate_empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	candidate_empty_label.add_theme_font_size_override("font_size", 16)
	candidate_empty_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	candidate_column.add_child(candidate_empty_label)

	feedback_label = Label.new()
	feedback_label.custom_minimum_size = Vector2(0.0, 30.0)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_font_size_override("font_size", 16)
	feedback_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	body.add_child(feedback_label)

	modal.clear_footer()
	close_button = modal.add_footer_button(TEXT_CLOSE, Callable(self, "close_panel"), "normal")
	swap_button = modal.add_footer_button(TEXT_SWAP, Callable(self, "_on_swap_pressed"), "primary")

func _make_section_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	return label

func _refresh_lists() -> void:
	for child in team_list.get_children():
		team_list.remove_child(child)
		child.queue_free()
	for child in candidate_list.get_children():
		candidate_list.remove_child(child)
		child.queue_free()
	team_buttons.clear()
	candidate_buttons.clear()
	var role_colors := ROLE_DATABASE.get_role_data()
	var team_ids := get_team_ids(profile)
	for index in range(team_ids.size()):
		team_list.add_child(_build_role_entry(str(team_ids[index]), index, true, role_colors))
	var candidates := get_candidates(profile)
	for role_id in candidates:
		candidate_list.add_child(_build_role_entry(str(role_id), -1, false, role_colors))
	candidate_empty_label.visible = candidates.is_empty()
	_update_swap_state()

func _build_role_entry(role_id: String, slot_index: int, is_team: bool, role_colors: Array) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	var strip := ColorRect.new()
	strip.color = ROLE_PRESENTER.get_role_theme_color(role_colors, role_id)
	strip.custom_minimum_size = Vector2(8.0, 0.0)
	strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(strip)

	var name_text := ROLE_PRESENTER.get_role_name(role_id)
	var title_text := "%d号位 · %s" % [slot_index + 1, name_text] if is_team else name_text
	var info_parts: Array[String] = []
	var detail := ROLE_PRESENTER.get_role_detail_summary(role_id, {})
	if detail != "":
		info_parts.append(detail)
	var core := ROLE_PRESENTER.get_role_core_summary(role_id)
	if core != "":
		info_parts.append(core)

	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0.0, 76.0)
	button.add_theme_font_size_override("font_size", 17)
	button.set_meta("base_title", title_text)
	button.set_meta("info_text", " · ".join(info_parts))
	if is_team:
		button.pressed.connect(_on_team_entry_pressed.bind(role_id))
		team_buttons[role_id] = button
	else:
		button.pressed.connect(_on_candidate_entry_pressed.bind(role_id))
		candidate_buttons[role_id] = button
	_apply_entry_visual(button, role_id == (selected_team_role if is_team else selected_candidate_role))
	row.add_child(button)
	return row

func _apply_entry_visual(button: Button, selected: bool) -> void:
	var title_text := str(button.get_meta("base_title", ""))
	if selected:
		title_text += "（%s）" % TEXT_SELECTED
	var info_text := str(button.get_meta("info_text", ""))
	button.text = title_text if info_text == "" else "%s\n%s" % [title_text, info_text]
	SURVIVORS_THEME.apply_card_button_style(button, selected)

func _refresh_selection_styles() -> void:
	for role_id in team_buttons.keys():
		_apply_entry_visual(team_buttons[role_id], str(role_id) == selected_team_role)
	for role_id in candidate_buttons.keys():
		_apply_entry_visual(candidate_buttons[role_id], str(role_id) == selected_candidate_role)
	_update_swap_state()

func _update_swap_state() -> void:
	if swap_button != null:
		swap_button.disabled = profile.is_empty() or selected_team_role == "" or selected_candidate_role == ""

func _on_team_entry_pressed(role_id: String) -> void:
	if selected_team_role == role_id:
		return
	selected_team_role = role_id
	feedback_label.text = ""
	_refresh_selection_styles()

func _on_candidate_entry_pressed(role_id: String) -> void:
	if selected_candidate_role == role_id:
		return
	selected_candidate_role = role_id
	feedback_label.text = ""
	_refresh_selection_styles()

func _on_swap_pressed() -> void:
	if profile.is_empty():
		feedback_label.text = TEXT_PROFILE_MISSING
		return
	var previous_team := get_team_ids(profile)
	var result := build_swapped_team(previous_team, selected_team_role, selected_candidate_role, get_unlocked_ids(profile))
	if not bool(result.get("success", false)):
		feedback_label.text = str(result.get("error", ""))
		return
	var new_team: Array = (result.get("team_order", []) as Array).duplicate()
	var out_name := ROLE_PRESENTER.get_role_name(selected_team_role)
	var in_name := ROLE_PRESENTER.get_role_name(selected_candidate_role)
	profile["team_order"] = new_team
	if not _persist_profile():
		profile["team_order"] = previous_team
		feedback_label.text = TEXT_SAVE_FAILED
		return
	feedback_label.text = TEXT_SWAP_DONE % [out_name, in_name]
	selected_team_role = ""
	selected_candidate_role = ""
	_refresh_lists()
	team_changed.emit(new_team)
	_grab_initial_focus()

func _grab_initial_focus() -> void:
	var candidate_button := _first_entry_button(candidate_list)
	if candidate_button != null:
		candidate_button.grab_focus()
		return
	var team_button := _first_entry_button(team_list)
	if team_button != null:
		team_button.grab_focus()
		return
	if close_button != null:
		close_button.grab_focus()

func _first_entry_button(container: VBoxContainer) -> Button:
	for row in container.get_children():
		if not (row is HBoxContainer):
			continue
		for child in row.get_children():
			if child is Button:
				return child
	return null
