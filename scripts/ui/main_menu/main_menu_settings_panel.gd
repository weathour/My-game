extends Control

signal hud_layout_changed(layout_key: String)

const BGM_PLAYER_SCRIPT := preload("res://scripts/bgm_player.gd")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const SURVIVORS_MODAL := preload("res://scripts/ui/core/survivors_modal.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")

const TEXT_SETTINGS := "\u8bbe\u7f6e"
const TEXT_VOLUME_SETTINGS := "\u97f3\u91cf\u8bbe\u7f6e"
const TEXT_DISPLAY_SETTINGS := "\u663e\u793a\u8bbe\u7f6e"
const TEXT_KEY_SETTINGS := "\u6309\u952e\u8bbe\u7f6e"
const TEXT_MUSIC_VOLUME := "\u80cc\u666f\u97f3\u4e50\u97f3\u91cf"
const TEXT_PERFORMANCE_TRACE := "\u8bb0\u5f55\u6027\u80fd\u65e5\u5fd7"
const TEXT_PERFORMANCE_TRACE_HINT := "临时记录卡顿信息，完成排查后关闭。"
const TEXT_CLOSE := "\u5173\u95ed"
const TEXT_RESET_DEFAULTS := "\u6062\u590d\u9ed8\u8ba4\u952e\u4f4d"
const TEXT_WINDOW_MODE := "\u7a97\u53e3\u6a21\u5f0f"
const TEXT_WINDOWED := "\u7a97\u53e3"
const TEXT_FULLSCREEN := "\u5168\u5c4f"
const TEXT_WINDOW_SIZE := "\u7a97\u53e3\u5927\u5c0f"
const TEXT_HUD_LAYOUT := "HUD \u5e03\u5c40"
const TEXT_HUD_LAYOUT_HINT := "底部技能栏聚焦当前角色；三行队伍状态带同时显示三名角色的生命、大招能量与技能冷却。"
const TEXT_ASPECT_LOCKED := "\u753b\u9762\u6bd4\u4f8b\u5df2\u56fa\u5b9a\u4e3a 16:9\uff1b\u7a97\u53e3\u62d6\u62fd\u8c03\u6574\u65f6\u4f1a\u81ea\u52a8\u6821\u6b63\u6bd4\u4f8b\u3002"
const TEXT_KEY_HELP := "\u70b9\u51fb\u53f3\u4fa7\u6309\u94ae\u540e\uff0c\u6309\u4e0b\u65b0\u6309\u952e\u3002"
const TEXT_WAITING_KEY := "\u6309\u4e0b\u65b0\u6309\u952e\uff0cESC \u53d6\u6d88"
const TEXT_KEY_CANCELLED := "\u5df2\u53d6\u6d88\u952e\u4f4d\u8bbe\u7f6e"
const TEXT_KEY_SAVED := "\u952e\u4f4d\u5df2\u4fdd\u5b58"

const KEYBIND_LABELS := {
	"move_up": "\u4e0a",
	"move_down": "\u4e0b",
	"move_left": "\u5de6",
	"move_right": "\u53f3",
	"ultimate": "\u5927\u62db",
	"skill_slot_1": "技能槽 1",
	"skill_slot_2": "技能槽 2",
	"skill_slot_3": "技能槽 3",
	"skill_slot_4": "技能槽 4",
	"skill_slot_5": "技能槽 5",
	"skill_slot_6": "技能槽 6",
	"switch_prev": "\u5207\u6362\u4e0a\u4e00\u4e2a\u4eba",
	"switch_next": "\u5207\u6362\u4e0b\u4e00\u4e2a\u4eba",
	"toggle_attack_mode": "\u5207\u6362\u653b\u51fb\u65b9\u5f0f",
	"character_panel": "\u89d2\u8272\u9762\u677f",
	"toggle_hurt_core": "\u663e\u793a/\u9690\u85cf\u5224\u5b9a\u5706",
	"toggle_performance_overlay": "\u663e\u793a/\u9690\u85cf\u5e27\u6570\u9762\u677f",
	"interact": "\u4ea4\u4e92"
}

var volume_page: VBoxContainer
var display_page: VBoxContainer
var keybind_page: VBoxContainer
var page_scroll: ScrollContainer
var category_buttons: Array[Button] = []
var close_button: Button
var previous_focus: Control
var volume_slider: HSlider
var volume_value_label: Label
var mute_checkbox: CheckBox
var performance_trace_checkbox: CheckBox
var window_mode_option: OptionButton
var window_size_option: OptionButton
var hud_layout_option: OptionButton
var keybind_buttons: Dictionary = {}
var keybind_status_label: Label
var waiting_for_key_action: String = ""
var modal: Control
var sfx_slider: HSlider
var sfx_value: Label
var comfort_checks: Dictionary = {}

func _ready() -> void:
	_fit_to_viewport()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_panel()
	visible = false
	_show_volume_settings()
	_refresh_audio_controls()
	_refresh_gameplay_controls()
	_refresh_display_controls()
	_refresh_keybind_controls()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_to_viewport()

func open() -> void:
	previous_focus = get_viewport().gui_get_focus_owner()
	waiting_for_key_action = ""
	_refresh_audio_controls()
	_refresh_gameplay_controls()
	_refresh_display_controls()
	_refresh_keybind_controls()
	_show_volume_settings()
	_fit_to_viewport()
	visible = true
	category_buttons[0].grab_focus()

func close_panel() -> void:
	waiting_for_key_action = ""
	visible = false
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or event is not InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if waiting_for_key_action.is_empty():
		if modal.cycle_keyboard_focus(event):
			return
		if key_event.keycode == KEY_ESCAPE:
			close_panel()
			get_viewport().set_input_as_handled()
		return
	if key_event.keycode == KEY_NONE:
		return
	# Capture before GUI navigation consumes Tab, Enter or Space during rebinding.
	if key_event.keycode == KEY_ESCAPE:
		keybind_status_label.text = TEXT_KEY_CANCELLED
	else:
		_save_keybind(waiting_for_key_action, key_event.keycode)
		keybind_status_label.text = TEXT_KEY_SAVED
	waiting_for_key_action = ""
	_refresh_keybind_controls()
	get_viewport().set_input_as_handled()

func _build_panel() -> void:
	modal = SURVIVORS_MODAL.new()
	modal.configure(Vector2(780.0, 520.0), 0.62, 0.72, Vector2(320.0, 260.0))
	add_child(modal)
	modal.set_title(TEXT_SETTINGS)
	modal.set_hint("")

	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	modal.set_body(content)

	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	content.add_child(body)

	var category_column := VBoxContainer.new()
	category_column.custom_minimum_size = Vector2(170, 0)
	category_column.add_theme_constant_override("separation", 10)
	body.add_child(category_column)

	for title in [TEXT_VOLUME_SETTINGS, TEXT_DISPLAY_SETTINGS, TEXT_KEY_SETTINGS]:
		var button := Button.new()
		button.text = title
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 48)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_show_page.bind(category_buttons.size()))
		category_column.add_child(button)
		category_buttons.append(button)

	page_scroll = ScrollContainer.new()
	page_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_scroll.follow_focus = true
	body.add_child(page_scroll)
	var page_root := VBoxContainer.new()
	page_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.add_child(page_root)

	volume_page = _build_volume_page()
	page_root.add_child(volume_page)

	display_page = _build_display_page()
	display_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_root.add_child(display_page)

	keybind_page = _build_keybind_page()
	page_root.add_child(keybind_page)
	close_button = modal.add_footer_button(TEXT_CLOSE, close_panel)
	close_button.focus_next = close_button.get_path_to(category_buttons[0])
	category_buttons[0].focus_previous = category_buttons[0].get_path_to(close_button)

	_fit_to_viewport()

func _fit_to_viewport() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	if modal != null:
		modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if modal.has_method("apply_layout"):
			modal.apply_layout()

func _build_volume_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)

	var title := Label.new()
	title.text = TEXT_VOLUME_SETTINGS
	title.add_theme_font_size_override("font_size", 24)
	page.add_child(title)

	var volume_label := Label.new()
	volume_label.text = TEXT_MUSIC_VOLUME
	volume_label.add_theme_font_size_override("font_size", 18)
	page.add_child(volume_label)

	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	volume_slider.custom_minimum_size = Vector2(0, 36)
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.value_changed.connect(_on_volume_changed)
	page.add_child(volume_slider)

	volume_value_label = Label.new()
	volume_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	volume_value_label.add_theme_font_size_override("font_size", 18)
	page.add_child(volume_value_label)

	mute_checkbox = CheckBox.new()
	mute_checkbox.text = "背景音乐静音"
	mute_checkbox.toggled.connect(_on_mute_toggled)
	page.add_child(mute_checkbox)
	page.add_child(SURVIVORS_THEME.make_hint_label("界面与结果音效 · 0% 为静音"))
	sfx_slider = HSlider.new()
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.01
	sfx_slider.custom_minimum_size.y = 36
	sfx_slider.value_changed.connect(func(value: float):
		GAME_SETTINGS.save_sfx_volume(value)
		sfx_value.text = "%d%%" % roundi(value * 100)
	)
	sfx_slider.drag_ended.connect(func(_changed): preload("res://scripts/ui/ui_audio.gd").play("reward"))
	page.add_child(sfx_slider)
	sfx_value = SURVIVORS_THEME.make_hint_label("")
	page.add_child(sfx_value)

	return page

func _build_display_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = TEXT_DISPLAY_SETTINGS
	title.add_theme_font_size_override("font_size", 24)
	page.add_child(title)

	var mode_label := Label.new()
	mode_label.text = TEXT_WINDOW_MODE
	mode_label.add_theme_font_size_override("font_size", 18)
	page.add_child(mode_label)

	window_mode_option = OptionButton.new()
	window_mode_option.custom_minimum_size = Vector2(260, 40)
	window_mode_option.add_item(TEXT_WINDOWED)
	window_mode_option.set_item_metadata(0, GAME_SETTINGS.WINDOW_MODE_WINDOWED)
	window_mode_option.add_item(TEXT_FULLSCREEN)
	window_mode_option.set_item_metadata(1, GAME_SETTINGS.WINDOW_MODE_FULLSCREEN)
	window_mode_option.item_selected.connect(_on_window_mode_selected)
	page.add_child(window_mode_option)

	var size_label := Label.new()
	size_label.text = TEXT_WINDOW_SIZE
	size_label.add_theme_font_size_override("font_size", 18)
	page.add_child(size_label)

	window_size_option = OptionButton.new()
	window_size_option.custom_minimum_size = Vector2(260, 40)
	for size_key in GAME_SETTINGS.get_window_size_labels():
		window_size_option.add_item(size_key)
		window_size_option.set_item_metadata(window_size_option.item_count - 1, size_key)
	window_size_option.item_selected.connect(_on_window_size_selected)
	page.add_child(window_size_option)

	var help_label := Label.new()
	help_label.text = TEXT_ASPECT_LOCKED
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.add_theme_font_size_override("font_size", 15)
	help_label.modulate = Color(0.82, 0.88, 0.95, 0.96)
	page.add_child(help_label)

	var hud_layout_label := Label.new()
	hud_layout_label.text = TEXT_HUD_LAYOUT
	hud_layout_label.add_theme_font_size_override("font_size", 18)
	page.add_child(hud_layout_label)

	hud_layout_option = OptionButton.new()
	hud_layout_option.custom_minimum_size = Vector2(300, 40)
	for layout_key in GAME_SETTINGS.get_hud_layout_options():
		hud_layout_option.add_item(GAME_SETTINGS.get_hud_layout_label(layout_key))
		hud_layout_option.set_item_metadata(hud_layout_option.item_count - 1, layout_key)
	hud_layout_option.item_selected.connect(_on_hud_layout_selected)
	page.add_child(hud_layout_option)

	var hud_layout_hint := Label.new()
	hud_layout_hint.text = TEXT_HUD_LAYOUT_HINT
	hud_layout_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_layout_hint.add_theme_font_size_override("font_size", 14)
	hud_layout_hint.modulate = Color(0.82, 0.88, 0.95, 0.96)
	page.add_child(hud_layout_hint)
	performance_trace_checkbox = CheckBox.new()
	performance_trace_checkbox.text = TEXT_PERFORMANCE_TRACE
	performance_trace_checkbox.toggled.connect(_on_performance_trace_toggled)
	page.add_child(performance_trace_checkbox)
	var performance_trace_hint := SURVIVORS_THEME.make_hint_label(TEXT_PERFORMANCE_TRACE_HINT)
	performance_trace_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	page.add_child(performance_trace_hint)
	var comfort_labels := {"reduced_motion": "减少震动与动画（镜头、奖励卡、对话）", "reduced_flash": "出怪预警改为常亮", "large_story_text": "放大剧情正文与记录文字"}
	for key: String in comfort_labels:
		var check := CheckBox.new()
		check.text = comfort_labels[key]
		check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		check.toggled.connect(func(enabled: bool): GAME_SETTINGS.save_comfort(key, enabled))
		page.add_child(check)
		comfort_checks[key] = check

	return page

func _build_keybind_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = TEXT_KEY_SETTINGS
	title.add_theme_font_size_override("font_size", 24)
	page.add_child(title)

	var help_label := Label.new()
	help_label.text = TEXT_KEY_HELP
	help_label.add_theme_font_size_override("font_size", 15)
	page.add_child(help_label)

	for action_id in GAME_SETTINGS.ACTION_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		page.add_child(row)

		var label := Label.new()
		label.text = str(KEYBIND_LABELS.get(action_id, action_id))
		label.custom_minimum_size = Vector2(210, 34)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 17)
		row.add_child(label)

		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 34)
		button.add_theme_font_size_override("font_size", 17)
		SURVIVORS_THEME.apply_button_style(button)
		button.pressed.connect(_on_keybind_button_pressed.bind(action_id))
		row.add_child(button)
		keybind_buttons[action_id] = button

	var reset_button := Button.new()
	reset_button.text = TEXT_RESET_DEFAULTS
	reset_button.custom_minimum_size = Vector2(180, 38)
	SURVIVORS_THEME.apply_button_style(reset_button)
	reset_button.pressed.connect(_on_reset_keybinds_pressed)
	page.add_child(reset_button)

	keybind_status_label = Label.new()
	keybind_status_label.text = ""
	keybind_status_label.add_theme_font_size_override("font_size", 15)
	page.add_child(keybind_status_label)

	return page

func _show_volume_settings() -> void:
	_show_page(0)

func _show_display_settings() -> void:
	_show_page(1)

func _show_keybind_settings() -> void:
	_show_page(2)

func _show_page(index: int) -> void:
	waiting_for_key_action = ""
	keybind_status_label.text = ""
	var pages := [volume_page, display_page, keybind_page]
	for page_index in range(pages.size()):
		pages[page_index].visible = page_index == index
		category_buttons[page_index].set_pressed_no_signal(page_index == index)
		SURVIVORS_THEME.apply_button_style(category_buttons[page_index], "normal", page_index == index)
	page_scroll.scroll_vertical = 0
	_refresh_display_controls()
	_refresh_keybind_controls()

func _refresh_display_controls() -> void:
	if window_mode_option != null:
		_select_option_by_metadata(window_mode_option, GAME_SETTINGS.load_window_mode())
	if window_size_option != null:
		_select_option_by_metadata(window_size_option, GAME_SETTINGS.load_window_size_key())
	if hud_layout_option != null:
		_select_option_by_metadata(hud_layout_option, GAME_SETTINGS.load_hud_layout())

func _refresh_audio_controls() -> void:
	if sfx_slider != null:
		sfx_slider.set_value_no_signal(GAME_SETTINGS.load_sfx_volume())
		sfx_value.text = "%d%%" % roundi(sfx_slider.value * 100)
	if volume_slider != null:
		volume_slider.set_value_no_signal(BGM_PLAYER_SCRIPT.load_music_volume())
	if volume_value_label != null:
		volume_value_label.text = "%d%%" % int(round(BGM_PLAYER_SCRIPT.load_music_volume() * 100.0))
	if mute_checkbox != null:
		mute_checkbox.set_pressed_no_signal(BGM_PLAYER_SCRIPT.load_music_muted())

func _refresh_gameplay_controls() -> void:
	for key in comfort_checks:
		comfort_checks[key].set_pressed_no_signal(GAME_SETTINGS.comfort_enabled(key))
	if performance_trace_checkbox != null:
		performance_trace_checkbox.set_pressed_no_signal(GAME_SETTINGS.load_performance_trace_enabled())

func _refresh_keybind_controls() -> void:
	for action_id in GAME_SETTINGS.ACTION_ORDER:
		var button := keybind_buttons.get(action_id) as Button
		if button == null:
			continue
		if waiting_for_key_action == action_id:
			button.text = "等待按键…"
		else:
			button.text = GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(action_id))

func _save_keybind(action_id: String, new_keycode: int) -> void:
	var key_map: Dictionary = GAME_SETTINGS.load_key_map()
	var old_keycode: int = int(key_map.get(action_id, GAME_SETTINGS.DEFAULT_KEYS.get(action_id, KEY_NONE)))
	for other_action in GAME_SETTINGS.ACTION_ORDER:
		if other_action == action_id:
			continue
		if int(key_map.get(other_action, KEY_NONE)) == new_keycode:
			key_map[other_action] = old_keycode
	key_map[action_id] = new_keycode
	GAME_SETTINGS.save_key_map(key_map)

func _apply_saved_music_volume() -> void:
	var scene := get_tree().current_scene
	if scene != null:
		for name in ["MenuBGM", "GameBGM"]:
			var music := scene.get_node_or_null(name)
			if music != null and music.has_method("apply_saved_volume"):
				music.apply_saved_volume()

func _select_option_by_metadata(option: OptionButton, metadata: String) -> void:
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == metadata:
			option.select(index)
			return

func _on_keybind_button_pressed(action_id: String) -> void:
	waiting_for_key_action = action_id
	if keybind_status_label != null:
		keybind_status_label.text = TEXT_WAITING_KEY
	_refresh_keybind_controls()

func _on_reset_keybinds_pressed() -> void:
	waiting_for_key_action = ""
	GAME_SETTINGS.reset_default_keybinds()
	if keybind_status_label != null:
		keybind_status_label.text = TEXT_KEY_SAVED
	_refresh_keybind_controls()

func _on_volume_changed(value: float) -> void:
	BGM_PLAYER_SCRIPT.save_music_volume(value)
	if volume_value_label != null:
		volume_value_label.text = "%d%%" % int(round(value * 100.0))
	_apply_saved_music_volume()

func _on_mute_toggled(toggled_on: bool) -> void:
	BGM_PLAYER_SCRIPT.save_music_muted(toggled_on)
	_apply_saved_music_volume()

func _on_performance_trace_toggled(toggled_on: bool) -> void:
	GAME_SETTINGS.save_performance_trace_enabled(toggled_on)

func _on_window_mode_selected(index: int) -> void:
	if window_mode_option == null:
		return
	var mode := str(window_mode_option.get_item_metadata(index))
	var manager := get_node_or_null("/root/WindowDisplayManager")
	if manager != null and manager.has_method("apply_window_mode"):
		manager.apply_window_mode(mode)
	else:
		GAME_SETTINGS.save_window_mode(mode)
	_refresh_display_controls()

func _on_window_size_selected(index: int) -> void:
	if window_size_option == null:
		return
	var size_key := str(window_size_option.get_item_metadata(index))
	var manager := get_node_or_null("/root/WindowDisplayManager")
	if manager != null and manager.has_method("apply_window_size"):
		manager.apply_window_size(size_key)
	else:
		GAME_SETTINGS.save_window_size_key(size_key)
	_refresh_display_controls()

func _on_hud_layout_selected(index: int) -> void:
	if hud_layout_option == null:
		return
	GAME_SETTINGS.save_hud_layout(str(hud_layout_option.get_item_metadata(index)))
	hud_layout_changed.emit(GAME_SETTINGS.load_hud_layout())
	_refresh_display_controls()
