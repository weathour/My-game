extends CanvasLayer

signal upgrade_selected(option_id: String, attribute_option_id: String)

const SURVIVORS_MODAL := preload("res://scripts/ui/core/survivors_modal.gd")
const SURVIVORS_CARD_LIST := preload("res://scripts/ui/components/survivors_card_list.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const SURVIVORS_HOVER_DETAIL := preload("res://scripts/ui/components/survivors_hover_detail.gd")

const BUILD_SLOT_ORDER := ["body", "combat", "skill"]
const SMALL_BOSS_SLOT_ORDER := ["equipment", "card"]
const DEFAULT_SLOT_LABELS := {
	"body": "战斗",
	"combat": "连携",
	"skill": "大招",
	"equipment": "道具",
	"card": "卡牌"
}

var modal: Control
var selection_label: Label
var card_list: Control
var hover_detail: Control

var current_mode: String = "direct"
var current_options: Array = []
var current_attribute_options: Array = []
var build_groups: Dictionary = {}
var pending_build_option_id: String = ""
var pending_build_title: String = ""
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

func show_options(options: Array, attribute_options: Array = []) -> void:
	current_mode = "build"
	current_options = options
	current_attribute_options = attribute_options
	build_groups = _group_options(options, BUILD_SLOT_ORDER)
	_reset_pending_selection()
	visible = true
	modal.configure(Vector2(680.0, 430.0), 0.54, 0.60, Vector2(320.0, 240.0))
	modal.set_title("升级选择")
	modal.set_hint("卡面显示简短摘要；鼠标移到卡片上查看完整说明。右侧滚动条始终可拖动。")
	selection_label.visible = true
	_prepare_modal_layout()
	_rebuild_level_up_list()
	_update_selection_hint()

func show_menu(title: String, options: Array) -> void:
	current_mode = "direct"
	current_options = options
	current_attribute_options = []
	build_groups = {}
	_reset_pending_selection()
	visible = true
	modal.configure(Vector2(640.0, 390.0), 0.50, 0.55, Vector2(300.0, 220.0))
	modal.set_title(title)
	modal.set_hint("卡面显示简短摘要；鼠标移到卡片上查看完整说明。")
	selection_label.visible = false
	_prepare_modal_layout()
	_rebuild_direct_list()

func show_small_boss_reward_menu(title: String, options: Array) -> void:
	current_mode = "small_boss_pair"
	current_options = options
	current_attribute_options = []
	build_groups = _group_small_boss_reward_options(options)
	_reset_pending_selection()
	visible = true
	modal.configure(Vector2(660.0, 420.0), 0.52, 0.58, Vector2(320.0, 230.0))
	modal.set_title(title)
	modal.set_hint("道具和卡牌各选 1 个；鼠标移到卡片上查看完整说明。")
	selection_label.visible = true
	_prepare_modal_layout()
	_rebuild_small_boss_list()
	_update_small_boss_reward_hint()

func hide_ui() -> void:
	visible = false
	_reset_pending_selection()
	if hover_detail != null and hover_detail.has_method("hide_detail"):
		hover_detail.hide_detail()
	if card_list != null and card_list.has_method("clear"):
		card_list.clear()

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

func _rebuild_level_up_list() -> void:
	card_list.clear()
	if not current_attribute_options.is_empty():
		card_list.add_section("英雄特性训练")
		card_list.columns = 2
		card_list.add_card_grid(current_attribute_options, 2)
	_add_build_sections(BUILD_SLOT_ORDER)
	_refresh_selected_cards()

func _rebuild_small_boss_list() -> void:
	card_list.clear()
	_add_build_sections(SMALL_BOSS_SLOT_ORDER)
	_refresh_selected_cards()

func _rebuild_direct_list() -> void:
	card_list.clear()
	for raw_option in current_options:
		if raw_option is not Dictionary:
			continue
		card_list.add_card(raw_option)
	_refresh_selected_cards()

func _add_build_sections(slot_order: Array) -> void:
	for slot_id_value in slot_order:
		var slot_id := str(slot_id_value)
		var grouped_options: Array = build_groups.get(slot_id, [])
		if grouped_options.is_empty():
			continue
		var label := str(grouped_options[0].get("slot_label", DEFAULT_SLOT_LABELS.get(slot_id, slot_id)))
		card_list.add_section(label)
		for raw_option in grouped_options:
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
		_select_build_option(option)

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

func _select_build_option(option: Dictionary) -> void:
	pending_build_option_id = str(option.get("id", ""))
	pending_build_title = str(option.get("title", "Build"))
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
		pending_card_title = str(option.get("title", "卡牌"))
	_update_small_boss_reward_hint()
	_refresh_selected_cards()
	if pending_equipment_option_id != "" and pending_card_option_id != "":
		upgrade_selected.emit(pending_equipment_option_id, pending_card_option_id)

func _try_emit_combined_selection() -> void:
	if pending_build_option_id == "":
		return
	if not current_attribute_options.is_empty() and pending_attribute_option_id == "":
		return
	upgrade_selected.emit(pending_build_option_id, pending_attribute_option_id)

func _update_selection_hint() -> void:
	if current_mode != "build":
		return
	var attribute_text := pending_attribute_title if pending_attribute_title != "" else "未选英雄特性"
	var build_text := pending_build_title if pending_build_title != "" else "未选 Build"
	selection_label.text = "当前：%s | %s" % [attribute_text, build_text]

func _update_small_boss_reward_hint() -> void:
	if current_mode != "small_boss_pair":
		return
	var equipment_text := pending_equipment_title if pending_equipment_title != "" else "未选道具"
	var card_text := pending_card_title if pending_card_title != "" else "未选卡牌"
	selection_label.text = "当前：%s | %s" % [equipment_text, card_text]

func _refresh_selected_cards() -> void:
	if card_list == null:
		return
	var ids: Array[String] = []
	if pending_attribute_option_id != "":
		ids.append(pending_attribute_option_id)
	if pending_build_option_id != "":
		ids.append(pending_build_option_id)
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
			option["slot_label"] = "道具"
			groups["equipment"].append(option)
		else:
			option["slot"] = "card"
			option["slot_label"] = "卡牌"
			groups["card"].append(option)
	return groups

func _reset_pending_selection() -> void:
	pending_build_option_id = ""
	pending_build_title = ""
	pending_attribute_option_id = ""
	pending_attribute_title = ""
	pending_equipment_option_id = ""
	pending_equipment_title = ""
	pending_card_option_id = ""
	pending_card_title = ""
