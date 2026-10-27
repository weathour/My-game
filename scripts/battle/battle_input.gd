extends RefCounted
const KEYS := {"battle_left":[KEY_A, KEY_LEFT], "battle_right":[KEY_D, KEY_RIGHT], "battle_up":[KEY_W, KEY_UP], "battle_down":[KEY_S, KEY_DOWN], "battle_previous":[KEY_Q], "battle_next":[KEY_E], "battle_skill_one":[KEY_J], "battle_skill_two":[KEY_K], "battle_pause":[KEY_ESCAPE]}

static func install() -> void:
	for action in KEYS:
		if InputMap.has_action(action): continue
		InputMap.add_action(action)
		for code in KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)

static func movement() -> Vector2:
	return Input.get_vector("battle_left", "battle_right", "battle_up", "battle_down")
