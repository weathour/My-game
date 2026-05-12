extends Node

const GAME_SETTINGS := preload("res://scripts/game_settings.gd")

var _last_windowed_size := Vector2i.ZERO
var _enforcing := false

func _ready() -> void:
	get_tree().root.size_changed.connect(_on_root_size_changed)
	apply_saved_settings()

func apply_saved_settings() -> void:
	apply_display_settings(GAME_SETTINGS.load_window_mode(), GAME_SETTINGS.load_window_size_key(), false)

func apply_display_settings(mode: String, size_key: String = "", persist: bool = true) -> void:
	if mode not in [GAME_SETTINGS.WINDOW_MODE_WINDOWED, GAME_SETTINGS.WINDOW_MODE_FULLSCREEN]:
		mode = GAME_SETTINGS.DEFAULT_WINDOW_MODE
	if size_key == "":
		size_key = GAME_SETTINGS.load_window_size_key()
	var window_size := GAME_SETTINGS.get_window_size(size_key)

	if mode == GAME_SETTINGS.WINDOW_MODE_FULLSCREEN:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			_last_windowed_size = DisplayServer.window_get_size()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_set_windowed_size(window_size)

	if persist:
		GAME_SETTINGS.save_window_mode(mode)
		GAME_SETTINGS.save_window_size_key(size_key)

func apply_window_mode(mode: String) -> void:
	apply_display_settings(mode, GAME_SETTINGS.load_window_size_key(), true)

func apply_window_size(size_key: String) -> void:
	apply_display_settings(GAME_SETTINGS.load_window_mode(), size_key, true)

func get_current_window_mode() -> String:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		return GAME_SETTINGS.WINDOW_MODE_FULLSCREEN
	return GAME_SETTINGS.WINDOW_MODE_WINDOWED

func _set_windowed_size(size: Vector2i) -> void:
	var normalized := GAME_SETTINGS.normalize_16_9_size(size)
	_enforcing = true
	DisplayServer.window_set_size(normalized)
	_center_window(normalized)
	_enforcing = false

func _center_window(size: Vector2i) -> void:
	var screen := DisplayServer.window_get_current_screen()
	var screen_position := DisplayServer.screen_get_position(screen)
	var usable_rect := DisplayServer.screen_get_usable_rect(screen)
	var target_position := screen_position + Vector2i(
		maxi(0, int(float(usable_rect.size.x - size.x) / 2.0)),
		maxi(0, int(float(usable_rect.size.y - size.y) / 2.0))
	)
	DisplayServer.window_set_position(target_position)

func _on_root_size_changed() -> void:
	if _enforcing:
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var current_size := DisplayServer.window_get_size()
	var normalized := GAME_SETTINGS.normalize_16_9_size(current_size)
	if current_size == normalized:
		_last_windowed_size = current_size
		return
	_enforcing = true
	DisplayServer.window_set_size(normalized)
	_enforcing = false
	_last_windowed_size = normalized
