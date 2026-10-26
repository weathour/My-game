extends SceneTree

const SETTINGS := preload("res://scripts/game_settings.gd")
const MODAL := preload("res://scripts/ui/core/survivors_modal.gd")
const MENU := preload("res://scenes/main_menu.tscn")
var failures: Array[String] = []
var capture_dir := ""

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_dir = arg.trim_prefix("--capture=")
	call_deferred("_run")

func _run() -> void:
	var had_settings := FileAccess.file_exists(SETTINGS.SETTINGS_PATH)
	var saved_bytes := FileAccess.get_file_as_bytes(SETTINGS.SETTINGS_PATH) if had_settings else PackedByteArray()
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var modal := MODAL.new()
	modal.set_title("入树前标题")
	modal.set_hint("入树前提示")
	root.add_child(modal)
	_expect(modal.title_label.text == "入树前标题" and modal.hint_label.text == "入树前提示", "Modal must preserve text configured before ready")
	modal.set_title("")
	modal.set_hint("")
	_expect(not modal.title_label.visible and not modal.hint_label.visible, "Empty headings must not reserve space")
	modal.queue_free()
	await process_frame

	var menu := MENU.instantiate()
	root.add_child(menu)
	current_scene = menu
	await _settle()
	await _capture("main-menu")
	var continued: bool = menu.continue_button.visible
	menu.continue_button.show()
	for menu_size in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = menu_size
		root.content_scale_size = menu_size
		await _settle()
		_expect(menu.navigation.get_global_rect().end.y <= menu.utility_bar.get_global_rect().position.y, "Continue entry must not push navigation into utilities at %s" % menu_size)
		_expect(Rect2(Vector2.ZERO, Vector2(menu_size)).encloses(menu.utility_bar.get_global_rect()), "Menu utilities must remain inside the viewport at %s" % menu_size)
		await _capture("main-menu-%dx%d-continue" % [menu_size.x, menu_size.y])
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	menu.continue_button.visible = continued
	menu.music_button.grab_focus()
	menu.music_button.pressed.emit()
	await _settle()
	_expect(menu.music_room.visible and not menu.menu_content.visible, "Music entry must open an independent listening screen")
	_expect(menu.music_room._track_buttons.size() == 14, "Music room must expose every current track")
	await _capture("music-room")
	await _key(KEY_ESCAPE)
	_expect(not menu.music_room.visible and menu.menu_content.visible and menu.music_button.has_focus(), "Music room Escape must return to its menu entry")
	var panel = menu.settings_panel
	var opener := Button.new()
	menu.add_child(opener)
	opener.grab_focus()
	panel.open()
	await _settle()
	_expect(panel.category_buttons[0].has_focus(), "Settings must take keyboard focus")
	_expect(panel.mute_checkbox.text == "背景音乐静音", "Mute must have an accessible visible label")
	await _capture("settings-audio")
	panel._show_keybind_settings()
	await _settle()
	_expect(panel.category_buttons[2].button_pressed and not panel.category_buttons[0].button_pressed, "Only the visible settings category should be selected")
	_expect(panel.keybind_buttons.size() == SETTINGS.ACTION_ORDER.size(), "Every rebindable action must have a control")
	panel.keybind_buttons[SETTINGS.ACTION_INTERACT].grab_focus()
	await _settle()
	_expect(panel.page_scroll.scroll_vertical > 0, "Keyboard focus must scroll to the last keybind")
	_expect(panel.page_scroll.get_global_rect().grow(1).encloses(panel.keybind_buttons[SETTINGS.ACTION_INTERACT].get_global_rect()), "Last keybind must be visible, not clipped")
	_expect(panel.modal.panel.get_global_rect().encloses(panel.close_button.get_global_rect()), "Close must stay inside the modal")
	await _capture("settings-keybinds-bottom")
	for size_value in [Vector2i(960, 540), Vector2i(1920, 1080)]:
		root.size = size_value
		await _settle()
		_expect(panel.modal.panel.get_global_rect().encloses(panel.close_button.get_global_rect()), "Close must remain visible at %s" % size_value)
		_expect(panel.page_scroll.get_h_scroll_bar().max_value <= panel.page_scroll.size.x + 1, "Settings must not need horizontal scrolling at %s" % size_value)
		await _capture("settings-%dx%d" % [size_value.x, size_value.y])
	root.size = Vector2i(1280, 720)

	panel.close_button.grab_focus()
	await _key(KEY_TAB)
	_expect(panel.category_buttons[0].has_focus(), "Tab must wrap within settings")
	await _key(KEY_TAB, true)
	_expect(panel.close_button.has_focus(), "Shift Tab must wrap within settings")
	for page_index in range(3):
		panel._show_page(page_index)
		panel.category_buttons[0].grab_focus()
		for step in range(32):
			await _key(KEY_TAB)
			_expect(panel.is_ancestor_of(root.gui_get_focus_owner()), "Tab must not reach the menu behind settings")

	SETTINGS.reset_default_keybinds()
	panel._show_keybind_settings()
	var action := SETTINGS.ACTION_MOVE_UP
	for keycode in [KEY_TAB, KEY_ENTER, KEY_SPACE]:
		panel.keybind_buttons[action].grab_focus()
		panel.keybind_buttons[action].pressed.emit()
		await _key(keycode)
		_expect(SETTINGS.load_keycode(action) == keycode, "GUI navigation key must be captured as a binding: %s" % keycode)
		_expect(panel.waiting_for_key_action.is_empty(), "Rebinding must finish after a key")
		_expect(panel.keybind_buttons[action].has_focus(), "Rebinding must not navigate away")
	panel.keybind_buttons[action].pressed.emit()
	await _key(KEY_ESCAPE)
	_expect(panel.visible and panel.waiting_for_key_action.is_empty(), "First Escape must cancel rebinding without closing settings")
	_expect(SETTINGS.load_keycode(action) == KEY_SPACE, "Cancelling must preserve the binding")
	panel.keybind_buttons[action].pressed.emit()
	panel._show_display_settings()
	await _key(KEY_K)
	_expect(SETTINGS.load_keycode(action) == KEY_SPACE, "Changing pages must cancel the pending binding")
	await _capture("settings-display")
	await _key(KEY_ESCAPE)
	_expect(not panel.visible and opener.has_focus(), "Closing settings must restore the opener's focus")
	panel.open()
	_expect(panel.volume_page.visible and panel.waiting_for_key_action.is_empty(), "Reopening must start on audio without a pending binding")
	panel.close_panel()
	menu.queue_free()
	await process_frame

	var pause_menu = load("res://scenes/pause_menu.tscn").instantiate()
	root.add_child(pause_menu)
	paused = true
	pause_menu.set_endless_mode_enabled(true)
	pause_menu.show_ui()
	await _settle()
	_expect(pause_menu.modal.title_label.text == "暂停", "Pause title must survive pre-ready configuration")
	await _capture("pause-menu")
	pause_menu.queue_free()
	await process_frame
	paused = false
	var tier = load("res://scripts/ui/save/endless_tier_overlay.gd").new()
	root.add_child(tier)
	_expect(tier.modal.title_label.text == "选择无尽 N 层", "Tier selection title must survive pre-ready configuration")
	_expect(tier.modal.hint_label.text.contains("20 波") and tier.modal.hint_label.text.contains("第 20 波"), "Tier selection must describe the current 20-wave route")
	tier.queue_free()
	await process_frame

	if had_settings:
		var file := FileAccess.open(SETTINGS.SETTINGS_PATH, FileAccess.WRITE)
		file.store_buffer(saved_bytes)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS.SETTINGS_PATH))
	SETTINGS.cached_config = null
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("MENU_UI_SMOKE_OK")
	quit(0 if failures.is_empty() else 1)

func _key(keycode: int, shift: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.shift_pressed = shift
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await process_frame

func _settle() -> void:
	for frame in range(6):
		await process_frame

func _capture(label: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await _settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png"))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
