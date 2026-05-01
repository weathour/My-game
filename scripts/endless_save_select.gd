extends Control

const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const GAME_SCENE_PATH := "res://scenes/main.tscn"
const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const ENDLESS_DIFFICULTY_OVERLAY := preload("res://scripts/ui/save/endless_difficulty_overlay.gd")
const ENDLESS_SLOT_CARD_FACTORY := preload("res://scripts/ui/save/endless_slot_card_factory.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")

const TEXT_TITLE := "\u65e0\u5c3d\u6a21\u5f0f"
const TEXT_SUBTITLE := "\u9009\u62e9\u4e00\u4e2a\u5b58\u6863\u4f4d\u8fdb\u5165\u65e0\u5c3d\u6218\u6597"
const TEXT_BACK := "\u8fd4\u56de\u4e3b\u83dc\u5355"
const TEXT_CLOSE := "\u5173\u95ed"
const TEXT_DELETE_CONFIRM := "\u786E\u5B9A\u8981\u5220\u9664\u8FD9\u4E2A\u5B58\u6863\u5417"
const TEXT_DELETE_TITLE := "\u5220\u9664\u5B58\u6863"

var difficulty_overlay: Control
var delete_confirm_dialog: ConfirmationDialog
var pending_slot_id: int = -1
var pending_delete_slot_id: int = -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	delete_confirm_dialog = null

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.05, 0.07, 0.12, 1.0)
	add_child(background)

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 36)
	root_margin.add_theme_constant_override("margin_top", 28)
	root_margin.add_theme_constant_override("margin_right", 36)
	root_margin.add_theme_constant_override("margin_bottom", 28)
	add_child(root_margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	root_margin.add_child(page)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	page.add_child(header)

	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_column)

	var title := Label.new()
	title.text = TEXT_TITLE
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT)
	title_column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = TEXT_SUBTITLE
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	title_column.add_child(subtitle)

	var back_button := Button.new()
	back_button.text = TEXT_BACK
	back_button.custom_minimum_size = Vector2(160.0, 44.0)
	SURVIVORS_THEME.apply_button_style(back_button)
	back_button.pressed.connect(_on_back_pressed)
	header.add_child(back_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(grid)

	for slot_payload in SAVE_MANAGER.list_endless_slots():
		grid.add_child(ENDLESS_SLOT_CARD_FACTORY.build_slot_card(
			slot_payload,
			Callable(self, "_on_slot_pressed"),
			Callable(self, "_on_delete_pressed")
		))

	difficulty_overlay = ENDLESS_DIFFICULTY_OVERLAY.new()
	difficulty_overlay.difficulty_selected.connect(_on_difficulty_selected)
	difficulty_overlay.closed.connect(_on_difficulty_overlay_closed)
	add_child(difficulty_overlay)

func _ensure_delete_confirm_dialog() -> void:
	if delete_confirm_dialog != null and is_instance_valid(delete_confirm_dialog):
		return
	delete_confirm_dialog = ConfirmationDialog.new()
	delete_confirm_dialog.title = TEXT_DELETE_TITLE
	delete_confirm_dialog.dialog_text = TEXT_DELETE_CONFIRM
	delete_confirm_dialog.ok_button_text = TEXT_DELETE_TITLE
	delete_confirm_dialog.cancel_button_text = TEXT_CLOSE
	delete_confirm_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(delete_confirm_dialog)

func _on_slot_pressed(slot_id: int, has_profile: bool, has_run: bool) -> void:
	if not has_profile:
		pending_slot_id = slot_id
		if difficulty_overlay != null and difficulty_overlay.has_method("open"):
			difficulty_overlay.open()
		return

	SAVE_MANAGER.set_active_endless_slot(slot_id)
	if has_run:
		SAVE_MANAGER.request_continue()
	else:
		SAVE_MANAGER.clear_save(slot_id, SAVE_MANAGER.MODE_ENDLESS)
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_delete_pressed(slot_id: int) -> void:
	pending_delete_slot_id = slot_id
	_ensure_delete_confirm_dialog()
	if delete_confirm_dialog != null:
		delete_confirm_dialog.popup_centered(Vector2i(420, 180))

func _on_delete_confirmed() -> void:
	if pending_delete_slot_id < 1:
		return
	SAVE_MANAGER.delete_endless_profile(pending_delete_slot_id)
	pending_delete_slot_id = -1
	_hide_difficulty_overlay()
	_build_ui()

func _on_difficulty_selected(difficulty_id: String) -> void:
	if pending_slot_id < 1:
		return
	SAVE_MANAGER.create_or_load_endless_profile(pending_slot_id, difficulty_id)
	SAVE_MANAGER.clear_save(pending_slot_id, SAVE_MANAGER.MODE_ENDLESS)
	_hide_difficulty_overlay()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _hide_difficulty_overlay() -> void:
	pending_slot_id = -1
	if difficulty_overlay != null and difficulty_overlay.has_method("close_overlay"):
		difficulty_overlay.close_overlay()

func _on_difficulty_overlay_closed() -> void:
	pending_slot_id = -1

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
