extends RefCounted

const SETTINGS_PATH := "user://settings.cfg"
const KEY_SECTION := "keybinds"
const DISPLAY_SECTION := "display"

const WINDOW_MODE_WINDOWED := "windowed"
const WINDOW_MODE_FULLSCREEN := "fullscreen"
const WINDOW_SIZE_1280X720 := "1280x720"
const WINDOW_SIZE_1600X900 := "1600x900"
const WINDOW_SIZE_1920X1080 := "1920x1080"
const DEFAULT_WINDOW_MODE := WINDOW_MODE_WINDOWED
const DEFAULT_WINDOW_SIZE := WINDOW_SIZE_1280X720
const ASPECT_WIDTH := 16
const ASPECT_HEIGHT := 9
const MIN_WINDOW_WIDTH := 960

const ACTION_MOVE_UP := "move_up"
const ACTION_MOVE_DOWN := "move_down"
const ACTION_MOVE_LEFT := "move_left"
const ACTION_MOVE_RIGHT := "move_right"
const ACTION_ULTIMATE := "ultimate"
const ACTION_SWITCH_PREV := "switch_prev"
const ACTION_SWITCH_NEXT := "switch_next"
const ACTION_TOGGLE_ATTACK_MODE := "toggle_attack_mode"
const ACTION_CHARACTER_PANEL := "character_panel"
const ACTION_TOGGLE_HURT_CORE := "toggle_hurt_core"

const ACTION_ORDER := [
	ACTION_MOVE_UP,
	ACTION_MOVE_DOWN,
	ACTION_MOVE_LEFT,
	ACTION_MOVE_RIGHT,
	ACTION_ULTIMATE,
	ACTION_SWITCH_PREV,
	ACTION_SWITCH_NEXT,
	ACTION_TOGGLE_ATTACK_MODE,
	ACTION_CHARACTER_PANEL,
	ACTION_TOGGLE_HURT_CORE
]

const DEFAULT_KEYS := {
	"move_up": KEY_W,
	"move_down": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"ultimate": KEY_R,
	"switch_prev": KEY_Q,
	"switch_next": KEY_E,
	"toggle_attack_mode": KEY_TAB,
	"character_panel": KEY_C,
	"toggle_hurt_core": KEY_1
}

const WINDOW_SIZE_OPTIONS := {
	"1280x720": Vector2i(1280, 720),
	"1600x900": Vector2i(1600, 900),
	"1920x1080": Vector2i(1920, 1080)
}

static func load_keycode(action_id: String) -> int:
	var config := ConfigFile.new()
	var load_result: Error = config.load(SETTINGS_PATH)
	var default_keycode: int = int(DEFAULT_KEYS.get(action_id, KEY_NONE))
	if load_result != OK:
		return default_keycode
	return int(config.get_value(KEY_SECTION, action_id, default_keycode))

static func save_keycode(action_id: String, keycode: int) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(KEY_SECTION, action_id, keycode)
	config.save(SETTINGS_PATH)

static func load_key_map() -> Dictionary:
	var key_map: Dictionary = {}
	for action_id in ACTION_ORDER:
		key_map[action_id] = load_keycode(action_id)
	return key_map

static func save_key_map(key_map: Dictionary) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	for action_id in ACTION_ORDER:
		config.set_value(KEY_SECTION, action_id, int(key_map.get(action_id, DEFAULT_KEYS.get(action_id, KEY_NONE))))
	config.save(SETTINGS_PATH)

static func reset_default_keybinds() -> void:
	save_key_map(DEFAULT_KEYS.duplicate())

static func is_action_pressed(action_id: String) -> bool:
	var keycode: int = load_keycode(action_id)
	return keycode != KEY_NONE and Input.is_key_pressed(keycode)

static func event_matches_action(event: InputEvent, action_id: String) -> bool:
	if event is not InputEventKey:
		return false
	var key_event := event as InputEventKey
	return key_event.pressed and not key_event.echo and key_event.keycode == load_keycode(action_id)

static func get_key_display_name(keycode: int) -> String:
	if keycode == KEY_NONE:
		return "-"
	var display_name: String = OS.get_keycode_string(keycode)
	if display_name == "":
		return str(keycode)
	return display_name

static func load_window_mode() -> String:
	var config := ConfigFile.new()
	var load_result: Error = config.load(SETTINGS_PATH)
	if load_result != OK:
		return DEFAULT_WINDOW_MODE
	var mode := str(config.get_value(DISPLAY_SECTION, "window_mode", DEFAULT_WINDOW_MODE))
	if mode not in [WINDOW_MODE_WINDOWED, WINDOW_MODE_FULLSCREEN]:
		return DEFAULT_WINDOW_MODE
	return mode

static func save_window_mode(mode: String) -> void:
	if mode not in [WINDOW_MODE_WINDOWED, WINDOW_MODE_FULLSCREEN]:
		mode = DEFAULT_WINDOW_MODE
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(DISPLAY_SECTION, "window_mode", mode)
	config.save(SETTINGS_PATH)

static func load_window_size_key() -> String:
	var config := ConfigFile.new()
	var load_result: Error = config.load(SETTINGS_PATH)
	if load_result != OK:
		return DEFAULT_WINDOW_SIZE
	var size_key := str(config.get_value(DISPLAY_SECTION, "window_size", DEFAULT_WINDOW_SIZE))
	if not WINDOW_SIZE_OPTIONS.has(size_key):
		return DEFAULT_WINDOW_SIZE
	return size_key

static func save_window_size_key(size_key: String) -> void:
	if not WINDOW_SIZE_OPTIONS.has(size_key):
		size_key = DEFAULT_WINDOW_SIZE
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(DISPLAY_SECTION, "window_size", size_key)
	config.save(SETTINGS_PATH)

static func get_window_size(size_key: String = "") -> Vector2i:
	var resolved_key := size_key if size_key != "" else load_window_size_key()
	return WINDOW_SIZE_OPTIONS.get(resolved_key, WINDOW_SIZE_OPTIONS[DEFAULT_WINDOW_SIZE])

static func get_window_size_labels() -> Array[String]:
	return [WINDOW_SIZE_1280X720, WINDOW_SIZE_1600X900, WINDOW_SIZE_1920X1080]

static func normalize_16_9_size(size: Vector2i) -> Vector2i:
	var width := maxi(MIN_WINDOW_WIDTH, size.x)
	var height := int(round(float(width) * float(ASPECT_HEIGHT) / float(ASPECT_WIDTH)))
	return Vector2i(width, height)
