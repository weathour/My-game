extends RefCounted

const SETTINGS_PATH := "user://settings.cfg"
const KEY_SECTION := "keybinds"
const DISPLAY_SECTION := "display"
const GAMEPLAY_SECTION := "gameplay"
const PERFORMANCE_TRACE_ENABLED_KEY := "performance_trace_enabled"
const HUD_LAYOUT_KEY := "hud_layout"

const WINDOW_MODE_WINDOWED := "windowed"
const WINDOW_MODE_FULLSCREEN := "fullscreen"
const WINDOW_SIZE_1280X720 := "1280x720"
const WINDOW_SIZE_1600X900 := "1600x900"
const WINDOW_SIZE_1920X1080 := "1920x1080"
const DEFAULT_WINDOW_MODE := WINDOW_MODE_WINDOWED
const DEFAULT_WINDOW_SIZE := WINDOW_SIZE_1280X720
const DEFAULT_PERFORMANCE_TRACE_ENABLED := false
const HUD_LAYOUT_LEGACY := "legacy"
const HUD_LAYOUT_TEAM_BAND := "team_band"
const DEFAULT_HUD_LAYOUT := HUD_LAYOUT_LEGACY
const ASPECT_WIDTH := 16
const ASPECT_HEIGHT := 9
const MIN_WINDOW_WIDTH := 960
const KEYBIND_SCHEMA_VERSION := 2

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
const ACTION_TOGGLE_PERFORMANCE_OVERLAY := "toggle_performance_overlay"
const ACTION_INTERACT := "interact"
const SKILL_SLOT_COUNT := 6
const ACTION_SKILL_SLOT_PREFIX := "skill_slot_"
const SKILL_MODE_SECTION := "skill_modes"
const SKILL_ORDER_SECTION := "skill_slot_order"

const ACTION_ORDER := [
	ACTION_MOVE_UP,
	ACTION_MOVE_DOWN,
	ACTION_MOVE_LEFT,
	ACTION_MOVE_RIGHT,
	ACTION_ULTIMATE,
	"skill_slot_1",
	"skill_slot_2",
	"skill_slot_3",
	"skill_slot_4",
	"skill_slot_5",
	"skill_slot_6",
	ACTION_SWITCH_PREV,
	ACTION_SWITCH_NEXT,
	ACTION_TOGGLE_ATTACK_MODE,
	ACTION_CHARACTER_PANEL,
	ACTION_TOGGLE_HURT_CORE,
	ACTION_TOGGLE_PERFORMANCE_OVERLAY,
	ACTION_INTERACT
]

const DEFAULT_KEYS := {
	"move_up": KEY_W,
	"move_down": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"ultimate": KEY_R,
	"skill_slot_1": KEY_1,
	"skill_slot_2": KEY_2,
	"skill_slot_3": KEY_3,
	"skill_slot_4": KEY_4,
	"skill_slot_5": KEY_5,
	"skill_slot_6": KEY_6,
	"switch_prev": KEY_Q,
	"switch_next": KEY_E,
	"toggle_attack_mode": KEY_TAB,
	"character_panel": KEY_C,
	"toggle_hurt_core": KEY_F1,
	"toggle_performance_overlay": KEY_F2,
	"interact": KEY_F
}

const WINDOW_SIZE_OPTIONS := {
	"1280x720": Vector2i(1280, 720),
	"1600x900": Vector2i(1600, 900),
	"1920x1080": Vector2i(1920, 1080)
}

static func load_keycode(action_id: String) -> int:
	var config := _get_config()
	var default_keycode: int = int(DEFAULT_KEYS.get(action_id, KEY_NONE))
	return int(config.get_value(KEY_SECTION, action_id, default_keycode))

static func save_keycode(action_id: String, keycode: int) -> void:
	var config := _get_config()
	config.set_value(KEY_SECTION, action_id, keycode)
	config.save(SETTINGS_PATH)

static func load_key_map() -> Dictionary:
	var key_map: Dictionary = {}
	for action_id in ACTION_ORDER:
		key_map[action_id] = load_keycode(action_id)
	return key_map

static func save_key_map(key_map: Dictionary) -> void:
	var config := _get_config()
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

static func get_skill_slot_action_id(slot_index: int) -> String:
	return "%s%d" % [ACTION_SKILL_SLOT_PREFIX, slot_index]


static func get_skill_slot_index_for_event(event: InputEvent) -> int:
	if event is not InputEventKey:
		return 0
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return 0
	for slot_index in range(1, SKILL_SLOT_COUNT + 1):
		if key_event.keycode == load_keycode(get_skill_slot_action_id(slot_index)):
			return slot_index
	return 0


static func is_skill_manual(skill_id: String) -> bool:
	if skill_id == "":
		return false
	var config := _get_config()
	return bool(config.get_value(SKILL_MODE_SECTION, skill_id, false))


static func set_skill_manual(skill_id: String, manual: bool) -> void:
	if skill_id == "":
		return
	var config := _get_config()
	config.set_value(SKILL_MODE_SECTION, skill_id, manual)
	config.save(SETTINGS_PATH)


static func toggle_skill_manual(skill_id: String) -> bool:
	var next_value := not is_skill_manual(skill_id)
	set_skill_manual(skill_id, next_value)
	return next_value


static func get_skill_slot_order(role_id: String) -> Array[String]:
	var result: Array[String] = []
	if role_id == "":
		return result
	var config := _get_config()
	var raw_value: Variant = config.get_value(SKILL_ORDER_SECTION, role_id, [])
	if raw_value is Array:
		for skill_id_value in raw_value:
			var skill_id := str(skill_id_value)
			if skill_id != "" and not result.has(skill_id):
				result.append(skill_id)
	return result


static func set_skill_slot_order(role_id: String, order: Array) -> void:
	if role_id == "":
		return
	var normalized: Array[String] = []
	for skill_id_value in order:
		var skill_id := str(skill_id_value)
		if skill_id != "" and not normalized.has(skill_id):
			normalized.append(skill_id)
	var config := _get_config()
	config.set_value(SKILL_ORDER_SECTION, role_id, normalized)
	config.save(SETTINGS_PATH)


static func get_key_display_name(keycode: int) -> String:
	if keycode == KEY_NONE:
		return "-"
	var display_name: String = OS.get_keycode_string(keycode)
	if display_name == "":
		return str(keycode)
	return display_name

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

static func load_performance_trace_enabled() -> bool:
	var config := _get_config()
	return bool(config.get_value(GAMEPLAY_SECTION, PERFORMANCE_TRACE_ENABLED_KEY, DEFAULT_PERFORMANCE_TRACE_ENABLED))

static func save_performance_trace_enabled(enabled: bool) -> void:
	var config := _get_config()
	config.set_value(GAMEPLAY_SECTION, PERFORMANCE_TRACE_ENABLED_KEY, enabled)
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
	return HUD_LAYOUT_LEGACY

static func get_hud_layout_options() -> Array[String]:
	return [HUD_LAYOUT_LEGACY, HUD_LAYOUT_TEAM_BAND]

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
		_migrate_keybinds(cached_config)
	return cached_config

static func _migrate_keybinds(config: ConfigFile) -> void:
	var schema_version := int(config.get_value(KEY_SECTION, "schema_version", 1))
	if schema_version >= KEYBIND_SCHEMA_VERSION:
		return
	if int(config.get_value(KEY_SECTION, ACTION_TOGGLE_HURT_CORE, KEY_1)) == KEY_1:
		config.set_value(KEY_SECTION, ACTION_TOGGLE_HURT_CORE, KEY_F1)
	if not config.has_section_key(KEY_SECTION, ACTION_TOGGLE_PERFORMANCE_OVERLAY):
		config.set_value(KEY_SECTION, ACTION_TOGGLE_PERFORMANCE_OVERLAY, KEY_F2)
	config.set_value(KEY_SECTION, "schema_version", KEYBIND_SCHEMA_VERSION)
	config.save(SETTINGS_PATH)
