extends RefCounted

const SURVIVORS_SLOT_CARD := preload("res://scripts/ui/components/survivors_slot_card_factory.gd")

const TEXT_CREATE := "\u521b\u5efa\u5b58\u6863"
const TEXT_DELETE_TITLE := "\u5220\u9664\u5B58\u6863"

static func build_slot_card(slot_payload: Dictionary, slot_pressed_callback: Callable, delete_pressed_callback: Callable) -> Control:
	var slot_id: int = int(slot_payload.get("slot_id", 0))
	var has_profile: bool = bool(slot_payload.get("has_profile", false))
	var profile: Dictionary = slot_payload.get("profile", {})

	var root := Control.new()
	root.custom_minimum_size = Vector2(0, 172)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var detail_text := TEXT_CREATE
	if has_profile:
		var highest: int = maxi(0, int(profile.get("highest_cleared_tier", 0)))
		var run_tier: int = int(slot_payload.get("run_tier", 0))
		var target_text := "N%d 进行中" % run_tier if run_tier > 0 else "下个目标 N%d" % (highest + 1)
		var highest_text := "尚未通关" if highest == 0 else "最高通关 N%d" % highest
		detail_text = "%s\n%s" % [highest_text, target_text]
	var action_text := TEXT_CREATE if not has_profile else "进入营地"
	var health := str(slot_payload.get("health", "ok" if has_profile else "missing"))
	if health == "recoverable":
		detail_text += "\n主档损坏，有可用备份"
		action_text = "恢复备份并进入"
	elif health in ["corrupt", "incompatible"]:
		detail_text = "档案无法读取，原文件已保留。"
		action_text = "查看恢复说明"

	var card_button := SURVIVORS_SLOT_CARD.build_card(
		"\u5b58\u6863 %d" % slot_id,
		detail_text,
		action_text,
		slot_pressed_callback.bind(slot_id, has_profile, bool(slot_payload.get("has_run", false))),
		172.0
	)
	card_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(card_button)

	if has_profile or health != "missing":
		root.add_child(_build_delete_button(slot_id, delete_pressed_callback))

	return root

static func _build_delete_button(slot_id: int, delete_pressed_callback: Callable) -> Button:
	var delete_button := Button.new()
	delete_button.text = "\u00D7"
	delete_button.focus_mode = Control.FOCUS_ALL
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
