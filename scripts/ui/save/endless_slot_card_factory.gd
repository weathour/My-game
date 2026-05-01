extends RefCounted

const SURVIVORS_SLOT_CARD := preload("res://scripts/ui/components/survivors_slot_card_factory.gd")

const TEXT_CREATE := "\u521b\u5efa\u5b58\u6863"
const TEXT_SURVIVED := "\u5df2\u575a\u6301%s"
const TEXT_DELETE_TITLE := "\u5220\u9664\u5B58\u6863"
const TEXT_DIFFICULTY_EASY := "\u7b80\u5355"
const TEXT_DIFFICULTY_NORMAL := "\u666e\u901a"
const TEXT_DIFFICULTY_HARD := "\u56f0\u96be"
const TEXT_DIFFICULTY_HELL := "\u5730\u72f1"

static func build_slot_card(slot_payload: Dictionary, slot_pressed_callback: Callable, delete_pressed_callback: Callable) -> Control:
	var slot_id: int = int(slot_payload.get("slot_id", 0))
	var has_profile: bool = bool(slot_payload.get("has_profile", false))
	var survival_time: float = float(slot_payload.get("survival_time", 0.0))
	var profile: Dictionary = slot_payload.get("profile", {})

	var root := Control.new()
	root.custom_minimum_size = Vector2(0, 172)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var detail_text := TEXT_CREATE
	if has_profile:
		var difficulty_name := get_difficulty_label(str(profile.get("difficulty", "normal")))
		var survived_text := TEXT_SURVIVED % format_survival_time(survival_time)
		detail_text = "%s\n%s" % [difficulty_name, survived_text]
	var action_text := TEXT_CREATE if not has_profile else ("\u7ee7\u7eed" if bool(slot_payload.get("has_run", false)) else "\u5f00\u59cb")

	var card_button := SURVIVORS_SLOT_CARD.build_card(
		"\u5b58\u6863 %d" % slot_id,
		detail_text,
		action_text,
		slot_pressed_callback.bind(slot_id, has_profile, bool(slot_payload.get("has_run", false))),
		172.0
	)
	card_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(card_button)

	if has_profile:
		root.add_child(_build_delete_button(slot_id, delete_pressed_callback))

	return root

static func format_survival_time(total_seconds: float) -> String:
	var seconds_int: int = max(0, int(floor(total_seconds)))
	var minutes: int = int(seconds_int / 60)
	var seconds: int = seconds_int % 60
	return "%d\u5206%d\u79d2" % [minutes, seconds]

static func get_difficulty_label(difficulty_id: String) -> String:
	match difficulty_id:
		"easy":
			return TEXT_DIFFICULTY_EASY
		"hard":
			return TEXT_DIFFICULTY_HARD
		"hell":
			return TEXT_DIFFICULTY_HELL
		_:
			return TEXT_DIFFICULTY_NORMAL

static func _build_delete_button(slot_id: int, delete_pressed_callback: Callable) -> Button:
	var delete_button := Button.new()
	delete_button.text = "\u00D7"
	delete_button.focus_mode = Control.FOCUS_NONE
	delete_button.tooltip_text = TEXT_DELETE_TITLE
	delete_button.mouse_filter = Control.MOUSE_FILTER_STOP
	delete_button.anchor_left = 1.0
	delete_button.anchor_top = 0.0
	delete_button.anchor_right = 1.0
	delete_button.anchor_bottom = 0.0
	delete_button.offset_left = -42.0
	delete_button.offset_top = 10.0
	delete_button.offset_right = -10.0
	delete_button.offset_bottom = 42.0
	delete_button.add_theme_font_size_override("font_size", 24)
	SURVIVORS_SLOT_CARD.apply_delete_button_style(delete_button)
	delete_button.pressed.connect(delete_pressed_callback.bind(slot_id))
	return delete_button
