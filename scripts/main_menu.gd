extends Control

const GAME_SCENE_PATH := "res://scenes/main.tscn"
const SAVE_SELECT_SCENE_PATH := "res://scenes/save_select.tscn"
const ENDLESS_SAVE_SELECT_SCENE_PATH := "res://scenes/endless_save_select.tscn"
const BACKGROUND_TEXTURE := preload("res://assets/demo2.png")
const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const STORY_DATA := preload("res://scripts/story_data.gd")
const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const MAIN_MENU_SETTINGS_PANEL := preload("res://scripts/ui/main_menu/main_menu_settings_panel.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")

const TEXT_CONTINUE := "\u7ee7\u7eed\u6e38\u620f"
const TEXT_STORY := "\u4e3b\u7ebf\u6a21\u5f0f"
const TEXT_STORY_CLOSED := "\u4e3b\u7ebf\u6a21\u5f0f\uff08\u6682\u672a\u5f00\u653e\uff09"
const TEXT_CHALLENGE := "\u6311\u6218\u6a21\u5f0f"
const TEXT_ENDLESS := "\u65e0\u5c3d\u6a21\u5f0f"
const TEXT_DEVELOPER := "\u8fdb\u5165\u5f00\u53d1\u8005\u6a21\u5f0f"
const TEXT_SETTINGS := "\u8bbe\u7f6e"
const TEXT_QUIT := "\u9000\u51fa"

var background: TextureRect
var continue_button: Button
var settings_panel: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	background = TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = BACKGROUND_TEXTURE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var button_margin := PanelContainer.new()
	button_margin.anchor_left = 0.0
	button_margin.anchor_top = 1.0
	button_margin.anchor_right = 0.0
	button_margin.anchor_bottom = 1.0
	button_margin.offset_left = 24.0
	button_margin.offset_top = -430.0
	button_margin.offset_right = 316.0
	button_margin.offset_bottom = -24.0
	button_margin.add_theme_stylebox_override("panel", SURVIVORS_THEME.panel_style(SURVIVORS_THEME.COLOR_BG, SURVIVORS_THEME.COLOR_BORDER_GOLD, 2, 14, 14.0))
	add_child(button_margin)

	var button_column := VBoxContainer.new()
	button_column.alignment = BoxContainer.ALIGNMENT_END
	button_column.add_theme_constant_override("separation", 10)
	button_margin.add_child(button_column)

	continue_button = _make_main_button(TEXT_CONTINUE)
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.visible = SAVE_MANAGER.has_continue_target()
	button_column.add_child(continue_button)

	var start_button := _make_main_button(TEXT_STORY if STORY_DATA.is_story_mode_enabled() else TEXT_STORY_CLOSED)
	start_button.disabled = not STORY_DATA.is_story_mode_enabled()
	if STORY_DATA.is_story_mode_enabled():
		start_button.pressed.connect(_on_start_pressed)
	button_column.add_child(start_button)

	var challenge_button := _make_main_button(TEXT_CHALLENGE)
	challenge_button.disabled = true
	button_column.add_child(challenge_button)

	var endless_button := _make_main_button(TEXT_ENDLESS)
	endless_button.pressed.connect(_on_endless_pressed)
	button_column.add_child(endless_button)

	var developer_button := _make_main_button(TEXT_DEVELOPER)
	developer_button.pressed.connect(_on_developer_mode_pressed)
	button_column.add_child(developer_button)

	var settings_button := _make_main_button(TEXT_SETTINGS)
	settings_button.pressed.connect(_on_settings_pressed)
	button_column.add_child(settings_button)

	var quit_button := _make_main_button(TEXT_QUIT)
	quit_button.pressed.connect(_on_quit_pressed)
	button_column.add_child(quit_button)

	settings_panel = MAIN_MENU_SETTINGS_PANEL.new()
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(settings_panel)
	_fit_to_viewport()
	_apply_saved_music_volume()
	_start_menu_bgm()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and background != null:
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _exit_tree() -> void:
	var menu_bgm = get_node_or_null("MenuBGM")
	if menu_bgm != null and menu_bgm.has_method("stop"):
		menu_bgm.stop()
	if menu_bgm != null:
		menu_bgm.set("stream", null)

func _unhandled_input(event: InputEvent) -> void:
	if settings_panel != null and settings_panel.has_method("handle_unhandled_input"):
		settings_panel.handle_unhandled_input(event)

func _make_main_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(240, 52)
	button.add_theme_font_size_override("font_size", 22)
	SURVIVORS_THEME.apply_button_style(button)
	return button

func _fit_to_viewport() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if background != null:
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _apply_saved_music_volume() -> void:
	var menu_bgm = get_node_or_null("MenuBGM")
	if menu_bgm != null and menu_bgm.has_method("apply_saved_volume"):
		menu_bgm.apply_saved_volume()

func _start_menu_bgm() -> void:
	var menu_bgm = get_node_or_null("MenuBGM")
	if menu_bgm != null and menu_bgm.has_method("start_music"):
		menu_bgm.start_music()

func _on_continue_pressed() -> void:
	DEVELOPER_MODE.deactivate()
	var target_scene := SAVE_MANAGER.request_continue_to_last_target()
	if target_scene == "":
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(target_scene)

func _on_start_pressed() -> void:
	if not STORY_DATA.is_story_mode_enabled():
		return
	DEVELOPER_MODE.deactivate()
	get_tree().paused = false
	get_tree().change_scene_to_file(SAVE_SELECT_SCENE_PATH)

func _on_developer_mode_pressed() -> void:
	DEVELOPER_MODE.activate()
	SAVE_MANAGER.clear_save()
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_endless_pressed() -> void:
	DEVELOPER_MODE.deactivate()
	get_tree().paused = false
	get_tree().change_scene_to_file(ENDLESS_SAVE_SELECT_SCENE_PATH)

func _on_settings_pressed() -> void:
	if settings_panel != null and settings_panel.has_method("open"):
		settings_panel.open()

func _on_quit_pressed() -> void:
	get_tree().quit()
