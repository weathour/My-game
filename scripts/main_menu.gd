extends Control

const GAME_SCENE_PATH := "res://scenes/main.tscn"
const SAVE_SELECT_SCENE_PATH := "res://scenes/save_select.tscn"
const ENDLESS_SAVE_SELECT_SCENE_PATH := "res://scenes/endless_save_select.tscn"
const BACKGROUND_TEXTURE := preload("res://assets/ui/campaign/four_heroes_menu.png")
const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const STORY_DATA := preload("res://scripts/story_data.gd")
const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const MAIN_MENU_SETTINGS_PANEL := preload("res://scripts/ui/main_menu/main_menu_settings_panel.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const MUSIC_ROOM := preload("res://scripts/ui/main_menu/music_room.gd")
const MUSIC_CATALOG := preload("res://scripts/audio/music_catalog.gd")

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
var music_room: Control
var music_button: Button
var menu_content: Control
var navigation: PanelContainer
var menu_title: Label
var menu_subtitle: Label
var utility_bar: HBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Theme.new()
	theme.default_font = SURVIVORS_THEME.get_reading_font()
	theme.default_font_size = 16

	background = TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = BACKGROUND_TEXTURE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.set_color(0, Color("0c170fe8"))
	gradient.set_color(1, Color("0c170f00"))
	gradient.add_point(0.46, Color("0c170f88"))
	var wash := GradientTexture2D.new()
	wash.gradient = gradient
	wash.fill_from = Vector2.ZERO
	wash.fill_to = Vector2(0.76, 0)
	shade.texture = wash
	add_child(shade)
	SURVIVORS_THEME.apply_screen_frame(self)
	menu_content = Control.new()
	menu_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu_content)
	var chronicle_button := _make_main_button("返回新战役界面")
	chronicle_button.name = "ChronicleReturn"
	menu_content.add_child(chronicle_button)
	chronicle_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	chronicle_button.offset_left = -265
	chronicle_button.offset_right = -25
	chronicle_button.offset_top = 18
	chronicle_button.offset_bottom = 66
	chronicle_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/chronicle/chronicle_shell.tscn"))

	menu_title = SURVIVORS_THEME.make_section_label("幸存者", 58)
	menu_title.add_theme_constant_override("outline_size", 6)
	menu_title.add_theme_color_override("font_outline_color", Color("172016"))
	menu_content.add_child(menu_title)
	menu_subtitle = SURVIVORS_THEME.make_hint_label("第一章  ·  等一声回答", 17)
	menu_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	menu_subtitle.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	menu_content.add_child(menu_subtitle)

	navigation = PanelContainer.new()
	navigation.add_theme_stylebox_override("panel", SURVIVORS_THEME.panel_style(Color("14241be8"), SURVIVORS_THEME.COLOR_BORDER, 1, 2, 22.0))
	menu_content.add_child(navigation)
	SURVIVORS_THEME.apply_campaign_frame(navigation)

	var button_column := VBoxContainer.new()
	button_column.name = "MainActions"
	button_column.alignment = BoxContainer.ALIGNMENT_CENTER
	button_column.add_theme_constant_override("separation", 8)
	navigation.add_child(button_column)

	continue_button = _make_main_button(TEXT_CONTINUE)
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.visible = SAVE_MANAGER.has_continue_target()
	button_column.add_child(continue_button)

	var start_button := _make_main_button(TEXT_STORY if STORY_DATA.is_story_mode_enabled() else TEXT_STORY_CLOSED)
	SURVIVORS_THEME.apply_button_style(start_button, "primary")
	start_button.disabled = not STORY_DATA.is_story_mode_enabled()
	if STORY_DATA.is_story_mode_enabled():
		start_button.pressed.connect(_on_start_pressed)
	button_column.add_child(start_button)

	var endless_button := _make_main_button(TEXT_ENDLESS)
	endless_button.pressed.connect(_on_endless_pressed)
	button_column.add_child(endless_button)

	var challenge_button := _make_main_button(TEXT_CHALLENGE)
	challenge_button.disabled = true
	challenge_button.tooltip_text = "挑战模式尚未开放"
	button_column.add_child(challenge_button)

	var music_label := SURVIVORS_THEME.make_hint_label("收录全部 %d 首原创配乐" % MUSIC_CATALOG.CUES.size(), 13)
	music_label.custom_minimum_size.y = 25
	button_column.add_child(music_label)
	music_button = _make_main_button("音乐鉴赏")
	music_button.name = "MusicRoomButton"
	SURVIVORS_THEME.apply_button_style(music_button, "danger")
	music_button.pressed.connect(_on_music_pressed)
	button_column.add_child(music_button)

	utility_bar = HBoxContainer.new()
	utility_bar.add_theme_constant_override("separation", 10)
	menu_content.add_child(utility_bar)

	var settings_button := _make_main_button(TEXT_SETTINGS)
	settings_button.pressed.connect(_on_settings_pressed)
	utility_bar.add_child(settings_button)
	var developer_button := _make_main_button("开发者模式")
	developer_button.pressed.connect(_on_developer_mode_pressed)
	utility_bar.add_child(developer_button)

	var quit_button := _make_main_button(TEXT_QUIT)
	quit_button.pressed.connect(_on_quit_pressed)
	utility_bar.add_child(quit_button)
	for button in utility_bar.get_children():
		button.custom_minimum_size = Vector2(92, 40)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 15)

	settings_panel = MAIN_MENU_SETTINGS_PANEL.new()
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(settings_panel)
	music_room = MUSIC_ROOM.new()
	music_room.name = "MusicRoom"
	add_child(music_room)
	music_room.closed.connect(_on_music_closed)
	_fit_to_viewport()
	_fit_to_viewport.call_deferred()
	_apply_saved_music_volume()
	_start_menu_bgm()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_instance_valid(navigation):
		_fit_to_viewport()

func _exit_tree() -> void:
	var menu_bgm = get_node_or_null("MenuBGM")
	if menu_bgm != null and menu_bgm.has_method("stop"):
		menu_bgm.stop()
	if menu_bgm != null:
		menu_bgm.set("stream", null)

func _make_main_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(240, 48)
	button.add_theme_font_size_override("font_size", 20)
	SURVIVORS_THEME.apply_button_style(button)
	return button

func _fit_to_viewport() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if background != null:
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if navigation == null:
		return
	var view := get_viewport_rect().size
	var left := maxf(30.0, view.x * 0.048)
	var width := clampf(view.x * 0.265, 290.0, 370.0)
	var compact := view.y < 650.0
	menu_title.position = Vector2(left + 14, 38 if compact else 65)
	menu_title.add_theme_font_size_override("font_size", 44 if compact else 58)
	menu_subtitle.position = Vector2(left + 16, 99 if compact else 146)
	menu_subtitle.size.x = width
	navigation.position = Vector2(left, 130 if compact else 211)
	navigation.get_node("MainActions").add_theme_constant_override("separation", 6 if compact else 8)
	for button in navigation.find_children("*", "Button", true, false):
		button.custom_minimum_size.y = 34 if compact else 48
		button.add_theme_font_size_override("font_size", 17 if compact else 20)
	navigation.size = Vector2(width, 0)
	utility_bar.position = Vector2(left, view.y - 73)
	utility_bar.size = Vector2(width, 40)

func _on_music_pressed() -> void:
	menu_content.hide()
	music_room.open(get_node_or_null("MenuBGM"))

func _on_music_closed() -> void:
	menu_content.show()
	music_button.grab_focus()

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
