extends CanvasLayer

signal upgrade_selected(option_id: String, attribute_option_id: String)
signal upgrade_refresh_requested

const SURVIVORS_MODAL := preload("res://scripts/ui/core/survivors_modal.gd")
const SURVIVORS_CARD_LIST := preload("res://scripts/ui/components/survivors_card_list.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const SURVIVORS_HOVER_DETAIL := preload("res://scripts/ui/components/survivors_hover_detail.gd")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")

const BLESSING_SLOT_ORDER := ["body", "combat", "skill"]
const SMALL_BOSS_SLOT_ORDER := ["equipment", "card"]
const BLESSING_UNIFIED_SECTION_TITLE := "祝福三选一"
const DEFAULT_SLOT_LABELS := {
	"body": "战斗",
	"combat": "连携",
	"skill": "技能",
	"equipment": "道具",
	"card": "技能奖励"
}

var modal: Control
var selection_label: Label
var card_list: Control
var hover_detail: Control

var current_mode: String = "direct"
var current_options: Array = []
var current_attribute_options: Array = []
var current_offer_context: Dictionary = {}
var option_groups: Dictionary = {}
var pending_blessing_option_id: String = ""
var pending_blessing_title: String = ""
var pending_attribute_option_id: String = ""
var pending_attribute_title: String = ""
var pending_equipment_option_id: String = ""
var pending_equipment_title: String = ""
var pending_card_option_id: String = ""
var pending_card_title: String = ""

func _ready() -> void:
	layer = 2
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	modal = SURVIVORS_MODAL.new()
	modal.configure(Vector2(680.0, 430.0), 0.54, 0.60, Vector2(320.0, 240.0))
	add_child(modal)

	selection_label = Label.new()
	selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	modal.content.add_child(selection_label)
	modal.content.move_child(selection_label, min(2, modal.content.get_child_count() - 1))

	card_list = SURVIVORS_CARD_LIST.new()
	card_list.item_selected.connect(_on_card_list_item_selected)
	card_list.item_hovered.connect(_on_card_item_hovered)
	card_list.item_unhovered.connect(_on_card_item_unhovered)
	modal.set_body(card_list)

	hover_detail = SURVIVORS_HOVER_DETAIL.new()
	add_child(hover_detail)

	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)

	hide_ui()

func _on_viewport_size_changed() -> void:
	if visible:
		_apply_responsive_state()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if GAME_SETTINGS.event_matches_action(event, GAME_SETTINGS.ACTION_CHARACTER_PANEL):
		var main := get_tree().current_scene
		if main != null and main.has_method("_toggle_character_panel"):
			main._toggle_character_panel()
			get_viewport().set_input_as_handled()

func show_options(options: Array, attribute_options: Array = [], offer_context: Dictionary = {}) -> void:
	current_mode = "blessing"
	current_options = options
	current_attribute_options = attribute_options
	current_offer_context = offer_context.duplicate(true)
	option_groups = _group_options(options, BLESSING_SLOT_ORDER)
	_reset_pending_selection()
	visible = true
	modal.configure(Vector2(680.0, 430.0), 0.54, 0.60, Vector2(320.0, 240.0))
	modal.set_title("升级选择")
	modal.set_hint("卡面显示简短摘要；鼠标移到卡片上查看完整说明。右侧滚动条始终可拖动。")
	selection_label.visible = true
	_prepare_modal_layout()
	_configure_level_up_footer()
	_rebuild_level_up_list()
	_update_selection_hint()

func show_menu(title: String, options: Array) -> void:
	current_mode = "direct"
	current_options = options
	current_attribute_options = []
	current_offer_context = {}
	option_groups = {}
	_reset_pending_selection()
	visible = true
	modal.configure(Vector2(640.0, 390.0), 0.50, 0.55, Vector2(300.0, 220.0))
	modal.set_title(title)
	modal.set_hint("卡面显示简短摘要；鼠标移到卡片上查看完整说明。")
	selection_label.visible = false
	_prepare_modal_layout()
	_clear_modal_footer()
	_rebuild_direct_list()

func show_small_boss_reward_menu(title: String, options: Array) -> void:
	current_mode = "small_boss_pair"
	current_options = options
	current_attribute_options = []
	current_offer_context = {}
	option_groups = _group_small_boss_reward_options(options)
	_reset_pending_selection()
	visible = true
	modal.configure(Vector2(660.0, 420.0), 0.52, 0.58, Vector2(320.0, 230.0))
	modal.set_title(title)
	modal.set_hint(_get_small_boss_reward_menu_hint())
	selection_label.visible = true
	_prepare_modal_layout()
	_clear_modal_footer()
	_rebuild_small_boss_list()
	_update_small_boss_reward_hint()

func hide_ui() -> void:
	visible = false
	_reset_pending_selection()
	if hover_detail != null and hover_detail.has_method("hide_detail"):
		hover_detail.hide_detail()
	if card_list != null and card_list.has_method("clear"):
		card_list.clear()
	_clear_modal_footer()

func _apply_responsive_state() -> void:
	_prepare_modal_layout()
	_refresh_selected_cards()

func _prepare_modal_layout() -> void:
	if modal != null and modal.has_method("apply_layout"):
		modal.apply_layout()
	var compact := false
	if modal != null:
		compact = bool(modal.get("compact"))
	if selection_label != null:
		selection_label.add_theme_font_size_override("font_size", 11 if compact else 13)
	if card_list != null and card_list.has_method("set_compact"):
		card_list.set_compact(compact)

func _configure_level_up_footer() -> void:
	_clear_modal_footer()
	if modal == null or not modal.has_method("add_footer_button"):
		return
	var refresh_limit := int(current_offer_context.get("refresh_limit", 0))
	if refresh_limit <= 0:
		return
	var refresh_remaining := int(current_offer_context.get("refresh_remaining", 0))
	var label := str(current_offer_context.get("refresh_button_label", ""))
	if label == "":
		label = "刷新祝福 %d/%d" % [refresh_remaining, refresh_limit] if refresh_remaining > 0 else "刷新已用完"
	var button: Button = modal.add_footer_button(label, Callable(self, "_on_refresh_pressed"), "normal")
	button.disabled = refresh_remaining <= 0

func _clear_modal_footer() -> void:
	if modal != null and modal.has_method("clear_footer"):
		modal.clear_footer()

func _on_refresh_pressed() -> void:
	if current_mode != "blessing":
		return
	if int(current_offer_context.get("refresh_remaining", 0)) <= 0:
		return
	upgrade_refresh_requested.emit()

func _rebuild_level_up_list() -> void:
	card_list.clear()
	_add_unified_blessing_options()
	if not current_attribute_options.is_empty():
		card_list.add_section("英雄特性训练")
		card_list.columns = 2
		card_list.add_card_grid(current_attribute_options, 2)
	_refresh_selected_cards()
	if card_list.has_method("reset_scroll_to_top"):
		card_list.reset_scroll_to_top()

func _rebuild_small_boss_list() -> void:
	card_list.clear()
	_add_option_sections(SMALL_BOSS_SLOT_ORDER)
	_refresh_selected_cards()

func _rebuild_direct_list() -> void:
	card_list.clear()
	for raw_option in current_options:
		if raw_option is not Dictionary:
			continue
		card_list.add_card(raw_option)
	_refresh_selected_cards()

func _add_option_sections(slot_order: Array) -> void:
	for slot_id_value in slot_order:
		var slot_id := str(slot_id_value)
		var grouped_options: Array = option_groups.get(slot_id, [])
		if grouped_options.is_empty():
			continue
		var label := str(grouped_options[0].get("slot_label", DEFAULT_SLOT_LABELS.get(slot_id, slot_id)))
		card_list.add_section(label)
		for raw_option in grouped_options:
			if raw_option is not Dictionary:
				continue
			var option: Dictionary = raw_option
			card_list.add_card(option, false, bool(option.get("evolved", false)))

func _add_unified_blessing_options() -> void:
	if current_options.is_empty():
		return
	card_list.add_section(BLESSING_UNIFIED_SECTION_TITLE)
	for raw_option in current_options:
		if raw_option is not Dictionary:
			continue
		var option: Dictionary = raw_option
		card_list.add_card(option, false, bool(option.get("evolved", false)))

func _on_card_item_hovered(item: Dictionary, anchor_rect: Rect2) -> void:
	if hover_detail != null and hover_detail.has_method("show_item"):
		hover_detail.show_item(item, get_viewport().get_mouse_position(), anchor_rect)

func _on_card_item_unhovered() -> void:
	if hover_detail != null:
		if hover_detail.has_method("request_hide"):
			hover_detail.request_hide()
		elif hover_detail.has_method("hide_detail"):
			hover_detail.hide_detail()

func _on_card_list_item_selected(option_id: String, option: Dictionary) -> void:
	if current_mode == "direct":
		upgrade_selected.emit(option_id, "")
		return
	if current_mode == "small_boss_pair":
		_select_small_boss_reward_option(option)
		return
	var slot_id := str(option.get("slot", ""))
	if slot_id == "" or _is_attribute_option(option_id):
		_select_attribute_option(option)
	else:
		_select_blessing_option(option)

func _is_attribute_option(option_id: String) -> bool:
	for raw_option in current_attribute_options:
		if raw_option is Dictionary and str((raw_option as Dictionary).get("id", "")) == option_id:
			return true
	return false

func _select_attribute_option(option: Dictionary) -> void:
	pending_attribute_option_id = str(option.get("id", ""))
	pending_attribute_title = str(option.get("title", "英雄特性"))
	_update_selection_hint()
	_refresh_selected_cards()
	_try_emit_combined_selection()

func _select_blessing_option(option: Dictionary) -> void:
	pending_blessing_option_id = str(option.get("id", ""))
	pending_blessing_title = str(option.get("title", "绁濈"))
	_update_selection_hint()
	_refresh_selected_cards()
	_try_emit_combined_selection()

func _select_small_boss_reward_option(option: Dictionary) -> void:
	var slot_id := str(option.get("slot", ""))
	if slot_id == "equipment":
		pending_equipment_option_id = str(option.get("id", ""))
		pending_equipment_title = str(option.get("title", "道具"))
	elif slot_id == "card":
		pending_card_option_id = str(option.get("id", ""))
		pending_card_title = str(option.get("title", "技能奖励"))
	_update_small_boss_reward_hint()
	_refresh_selected_cards()
	if _is_small_boss_reward_selection_complete():
		upgrade_selected.emit(pending_equipment_option_id, pending_card_option_id)

func _try_emit_combined_selection() -> void:
	if pending_blessing_option_id == "":
		return
	if not current_attribute_options.is_empty() and pending_attribute_option_id == "":
		return
	upgrade_selected.emit(pending_blessing_option_id, pending_attribute_option_id)

func _update_selection_hint() -> void:
	if current_mode != "blessing":
		return
	var attribute_text := pending_attribute_title if pending_attribute_title != "" else "未选英雄特性"
	var blessing_text := pending_blessing_title if pending_blessing_title != "" else "未选祝福"
	selection_label.text = "当前：%s | %s" % [attribute_text, blessing_text]

func _update_small_boss_reward_hint() -> void:
	if current_mode != "small_boss_pair":
		return
	var parts: Array[String] = []
	if _small_boss_reward_slot_required("equipment"):
		parts.append(pending_equipment_title if pending_equipment_title != "" else "未选道具")
	if _small_boss_reward_slot_required("card"):
		parts.append(pending_card_title if pending_card_title != "" else "未选技能奖励")
	if parts.is_empty():
		selection_label.text = "当前：无可选奖励"
	else:
		selection_label.text = "当前：%s" % " | ".join(parts)

func _refresh_selected_cards() -> void:
	if card_list == null:
		return
	var ids: Array[String] = []
	if pending_attribute_option_id != "":
		ids.append(pending_attribute_option_id)
	if pending_blessing_option_id != "":
		ids.append(pending_blessing_option_id)
	if pending_equipment_option_id != "":
		ids.append(pending_equipment_option_id)
	if pending_card_option_id != "":
		ids.append(pending_card_option_id)
	card_list.set_selected_ids(ids)

func _group_options(options: Array, slot_order: Array) -> Dictionary:
	var groups := {}
	for slot_id_value in slot_order:
		groups[str(slot_id_value)] = []
	for raw_option in options:
		if raw_option is not Dictionary:
			continue
		var option: Dictionary = raw_option
		var slot_id := str(option.get("slot", ""))
		if not groups.has(slot_id):
			groups[slot_id] = []
		groups[slot_id].append(option)
	return groups

func _group_small_boss_reward_options(options: Array) -> Dictionary:
	var groups := {
		"equipment": [],
		"card": []
	}
	for raw_option in options:
		if raw_option is not Dictionary:
			continue
		var option: Dictionary = raw_option.duplicate(true)
		if str(option.get("slot", "")) == "equipment":
			option["slot"] = "equipment"
			option["slot_label"] = "閬撳叿"
			groups["equipment"].append(option)
		else:
			option["slot"] = "card"
			option["slot_label"] = "技能奖励"
			groups["card"].append(option)
	return groups

func _get_small_boss_reward_menu_hint() -> String:
	var labels: Array[String] = []
	if _small_boss_reward_slot_required("equipment"):
		labels.append("道具选 1 个")
	if _small_boss_reward_slot_required("card"):
		labels.append("技能奖励选 1 个")
	if labels.is_empty():
		return "当前没有可选奖励；鼠标移到卡片上查看完整说明。"
	return "%s；鼠标移到卡片上查看完整说明。" % "，".join(labels)

func _small_boss_reward_slot_required(slot_id: String) -> bool:
	return not (option_groups.get(slot_id, []) as Array).is_empty()

func _is_small_boss_reward_selection_complete() -> bool:
	if _small_boss_reward_slot_required("equipment") and pending_equipment_option_id == "":
		return false
	if _small_boss_reward_slot_required("card") and pending_card_option_id == "":
		return false
	return _small_boss_reward_slot_required("equipment") or _small_boss_reward_slot_required("card")

func _reset_pending_selection() -> void:
	pending_blessing_option_id = ""
	pending_blessing_title = ""
	pending_attribute_option_id = ""
	pending_attribute_title = ""
	pending_equipment_option_id = ""
	pending_equipment_title = ""
	pending_card_option_id = ""
	pending_card_title = ""
