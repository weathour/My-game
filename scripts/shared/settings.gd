extends RefCounted

const SETTINGS_PATH := "user://settings.cfg"
const DISPLAY_SECTION := "display"
const GAMEPLAY_SECTION := "gameplay"
const HUD_LAYOUT_KEY := "hud_layout"

const WINDOW_MODE_WINDOWED := "windowed"
const WINDOW_MODE_FULLSCREEN := "fullscreen"
const WINDOW_SIZE_1280X720 := "1280x720"
const WINDOW_SIZE_1600X900 := "1600x900"
const WINDOW_SIZE_1920X1080 := "1920x1080"
const DEFAULT_WINDOW_MODE := WINDOW_MODE_WINDOWED
const DEFAULT_WINDOW_SIZE := WINDOW_SIZE_1280X720
const HUD_LAYOUT_SIMPLE := "legacy" # Retain existing settings.cfg values.
const HUD_LAYOUT_TEAM_BAND := "team_band"
const DEFAULT_HUD_LAYOUT := HUD_LAYOUT_SIMPLE
const ASPECT_WIDTH := 16
const ASPECT_HEIGHT := 9
const MIN_WINDOW_WIDTH := 960

# The story reader accepts the existing saved interact key as an alternate continue key.
const KEY_SECTION := "keybinds"
const ACTION_INTERACT := "interact"

static var cached_config: ConfigFile

const COMFORT_DEFAULTS := {"reduced_motion": false, "reduced_flash": false, "large_story_text": false}

static func comfort_enabled(key: String) -> bool:
	return bool(_get_config().get_value("comfort", key, COMFORT_DEFAULTS.get(key, false)))

static func save_comfort(key: String, enabled: bool) -> void:
	if not COMFORT_DEFAULTS.has(key):
		return
	var config := _get_config()
	config.set_value("comfort", key, enabled)
	config.save(SETTINGS_PATH)

static func story_font_size(base: int) -> int:
	return int(round(base * 1.2)) if comfort_enabled("large_story_text") else base

static func load_sfx_volume() -> float:
	return clampf(float(_get_config().get_value("audio", "sfx_volume", 0.65)), 0.0, 1.0)

static func save_sfx_volume(value: float) -> void:
	var config := _get_config()
	config.set_value("audio", "sfx_volume", clampf(value, 0.0, 1.0))
	config.save(SETTINGS_PATH)

const WINDOW_SIZE_OPTIONS := {
	"1280x720": Vector2i(1280, 720),
	"1600x900": Vector2i(1600, 900),
	"1920x1080": Vector2i(1920, 1080)
}

static func load_keycode(action_id: String) -> int:
	if action_id != ACTION_INTERACT: return KEY_NONE
	return int(_get_config().get_value(KEY_SECTION, action_id, KEY_F))

static func save_keycode(action_id: String, keycode: int) -> void:
	if action_id != ACTION_INTERACT: return
	var config := _get_config()
	config.set_value(KEY_SECTION, action_id, keycode)
	config.save(SETTINGS_PATH)

static func event_matches_action(event: InputEvent, action_id: String) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == load_keycode(action_id)

static func load_window_mode() -> String:
	var config := _get_config()
	var mode := str(config.get_value(DISPLAY_SECTION, "window_mode", DEFAULT_WINDOW_MODE))
	if mode not in [WINDOW_MODE_WINDOWED, WINDOW_MODE_FULLSCREEN]:
		return DEFAULT_WINDOW_MODE
	return mode

static func save_window_mode(mode: String) -> void:
	if mode not in [WINDOW_MODE_WINDOWED, WINDOW_MODE_FULLSCREEN]:
		mode = DEFAULT_WINDOW_MODE
	var config := _get_config()
	config.set_value(DISPLAY_SECTION, "window_mode", mode)
	config.save(SETTINGS_PATH)

static func load_window_size_key() -> String:
	var config := _get_config()
	var size_key := str(config.get_value(DISPLAY_SECTION, "window_size", DEFAULT_WINDOW_SIZE))
	if not WINDOW_SIZE_OPTIONS.has(size_key):
		return DEFAULT_WINDOW_SIZE
	return size_key

static func save_window_size_key(size_key: String) -> void:
	if not WINDOW_SIZE_OPTIONS.has(size_key):
		size_key = DEFAULT_WINDOW_SIZE
	var config := _get_config()
	config.set_value(DISPLAY_SECTION, "window_size", size_key)
	config.save(SETTINGS_PATH)

static func load_hud_layout() -> String:
	var config := _get_config()
	return normalize_hud_layout(str(config.get_value(GAMEPLAY_SECTION, HUD_LAYOUT_KEY, DEFAULT_HUD_LAYOUT)))

static func save_hud_layout(layout_key: String) -> void:
	var config := _get_config()
	config.set_value(GAMEPLAY_SECTION, HUD_LAYOUT_KEY, normalize_hud_layout(layout_key))
	config.save(SETTINGS_PATH)

static func normalize_hud_layout(layout_key: String) -> String:
	if layout_key == HUD_LAYOUT_TEAM_BAND:
		return HUD_LAYOUT_TEAM_BAND
	return HUD_LAYOUT_SIMPLE

static func get_hud_layout_options() -> Array[String]:
	return [HUD_LAYOUT_SIMPLE, HUD_LAYOUT_TEAM_BAND]

static func get_hud_layout_label(layout_key: String) -> String:
	match normalize_hud_layout(layout_key):
		HUD_LAYOUT_TEAM_BAND:
			return "三行队伍状态带"
		_:
			return "底部技能栏"

static func get_window_size(size_key: String = "") -> Vector2i:
	var resolved_key := size_key if size_key != "" else load_window_size_key()
	return WINDOW_SIZE_OPTIONS.get(resolved_key, WINDOW_SIZE_OPTIONS[DEFAULT_WINDOW_SIZE])

static func get_window_size_labels() -> Array[String]:
	return [WINDOW_SIZE_1280X720, WINDOW_SIZE_1600X900, WINDOW_SIZE_1920X1080]

static func normalize_16_9_size(size: Vector2i) -> Vector2i:
	var width := maxi(MIN_WINDOW_WIDTH, size.x)
	var height := int(round(float(width) * float(ASPECT_HEIGHT) / float(ASPECT_WIDTH)))
	return Vector2i(width, height)

static func _get_config() -> ConfigFile:
	if cached_config == null:
		cached_config = ConfigFile.new()
		cached_config.load(SETTINGS_PATH)
	return cached_config
