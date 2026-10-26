extends Control

signal closed
signal progress_changed
const MODAL := preload("res://scripts/ui/core/survivors_modal.gd")
const STYLE := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const VISUALS := preload("res://scripts/ui/story/story_visuals.gd")
const FLOW := preload("res://scripts/story/dialogue_flow.gd")
const PROGRESS := preload("res://scripts/story/story_progress.gd")
const CONTENT := preload("res://scripts/story/story_content.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")
var modal: Control
var flow := FLOW.new()
var words: RichTextLabel
var narration: Label
var location: Label
var options: HBoxContainer
var error_label: Label
var opener: Control
var revealed := 0.0
var backdrop: TextureRect
var _scene := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	location = Label.new()
	STYLE.apply_label_font(location, 16, VISUALS.TEXT)
	add_child(location)
	modal = MODAL.new()
	modal.configure(Vector2(1140, 350), 0.94, 1.0, Vector2(400, 280))
	add_child(modal)
	get_viewport().size_changed.connect(_layout.call_deferred)
	hide()

func open(slot: int, conversation: String) -> bool:
	opener = get_viewport().gui_get_focus_owner()
	var response := flow.open(slot, conversation)
	if not response.ok:
		return false
	show()
	_render()
	return true

func _render() -> void:
	var node := flow.current_node()
	if node.is_empty():
		close()
		return
	var dialogue := CONTENT.find("dialogues", flow.profile.story.dialogue_checkpoint.conversation_id)
	var scene := str(dialogue.get("scene", "radio"))
	if backdrop == null or scene != _scene:
		if is_instance_valid(backdrop):
			remove_child(backdrop)
			backdrop.queue_free()
		backdrop = VISUALS.add_backdrop(self, scene)
		move_child(backdrop, 0)
		_scene = scene
	location.text = dialogue.get("location", "营地 / 通讯台")
	modal.set_title(CONTENT.find("speakers", node.speaker).get("name", ""))
	modal.set_hint("")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	modal.set_body(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	narration = Label.new()
	narration.text = node.get("narration", "")
	narration.visible = not narration.text.is_empty()
	narration.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	STYLE.apply_label_font(narration, SETTINGS.story_font_size(16), VISUALS.MUTED)
	body.add_child(narration)
	words = RichTextLabel.new()
	words.text = node.text
	words.bbcode_enabled = false
	words.fit_content = true
	words.scroll_active = false
	words.custom_minimum_size.y = 58
	words.add_theme_constant_override("line_separation", 7)
	words.add_theme_font_size_override("normal_font_size", SETTINGS.story_font_size(21))
	words.add_theme_font_override("normal_font", STYLE.get_reading_font())
	words.add_theme_color_override("default_color", VISUALS.TEXT)
	body.add_child(words)
	revealed = 0.0
	words.visible_characters = -1 if SETTINGS.comfort_enabled("reduced_motion") else 0
	options = HBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 8)
	body.add_child(options)
	for choice: Dictionary in node.get("choices", []):
		_add_option(choice.text, _choose.bind(choice.id), choice.has("command"))
	if not node.has("choices"):
		_add_option("结束交谈" if bool(node.get("end", false)) else "继续", _choose.bind(""), true)
	error_label = STYLE.make_hint_label("")
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.add_theme_color_override("font_color", Color("#ffb8a9"))
	error_label.hide()
	body.add_child(error_label)
	modal.clear_footer()
	var navigation := STYLE.make_hint_label("%s / Enter 确认 · Tab 选择 · Esc 稍后继续" % OS.get_keycode_string(SETTINGS.load_keycode(SETTINGS.ACTION_INTERACT)))
	navigation.add_theme_font_size_override("font_size", 12)
	navigation.add_theme_color_override("font_color", VISUALS.MUTED)
	navigation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	modal.footer.add_child(navigation)
	VISUALS.style_button(modal.add_footer_button("显示 / 跳过叙述", _skip), false, true)
	VISUALS.style_button(modal.add_footer_button("稍后继续", close), false, true)
	(options.get_child(0) as Control).grab_focus.call_deferred()
	_layout()

func _layout() -> void:
	if modal == null:
		return
	var height := 310 if flow.current_node().has("choices") else 290
	modal.configure(Vector2(1140, height), 0.94, 1.0, Vector2(400, 280))
	var viewport := STYLE.viewport_size(self)
	modal.panel.position.y = maxf(12, viewport.y - modal.panel.size.y - 20)
	modal.panel.add_theme_stylebox_override("panel", STYLE.panel_style(Color("#101923f7"), VISUALS.LINE, 1, 3))
	modal.dimmer.color = Color(0, 0, 0, 0.06)
	modal.title_label.add_theme_color_override("font_color", VISUALS.GOLD)
	modal.title_label.add_theme_font_size_override("font_size", 22)
	modal.title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	modal.hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	modal.hint_label.add_theme_color_override("font_color", VISUALS.MUTED)
	modal.hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.footer.alignment = BoxContainer.ALIGNMENT_END
	location.position = Vector2(modal.panel.position.x + 2, 28)

func _add_option(text: String, callback: Callable, primary: bool) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	VISUALS.style_button(button, primary)
	button.add_theme_font_size_override("font_size", SETTINGS.story_font_size(16))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := button.get_theme_stylebox(state)
		style.set_content_margin(SIDE_TOP, 8)
		style.set_content_margin(SIDE_BOTTOM, 8)
	button.pressed.connect(callback)
	options.add_child(button)

func _process(delta: float) -> void:
	if visible and is_instance_valid(words) and words.visible_characters >= 0:
		revealed += delta * 45.0
		words.visible_characters = int(revealed)
		if words.visible_characters >= words.get_total_character_count():
			words.visible_characters = -1

func _reveal() -> bool:
	if words.visible_characters >= 0:
		words.visible_characters = -1
		return true
	return false

func _choose(choice: String) -> void:
	if _reveal():
		return
	var response := flow.advance(choice)
	if not response.ok:
		_show_error(response.reason)
		preload("res://scripts/ui/ui_audio.gd").play("error")
		return
	if choice != "" and flow.profile.story.dialogue_checkpoint.get("node_id", "") in ["accepted", "delivered"]:
		preload("res://scripts/ui/ui_audio.gd").play("reward")
	progress_changed.emit()
	_render()

func _skip() -> void:
	if _reveal() or flow.current_node().has("choices"):
		return
	var response := flow.advance("", true)
	if response.ok:
		progress_changed.emit()
		_render()
	else:
		_show_error(response.reason)

func _show_error(reason: String) -> void:
	error_label.text = PROGRESS.message(reason)
	error_label.show()
	error_label.get_parent().get_parent().ensure_control_visible.call_deferred(error_label)

func close() -> void:
	hide()
	if is_instance_valid(opener) and opener.is_visible_in_tree():
		opener.grab_focus()
	closed.emit()

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed:
		return
	if event.echo:
		get_viewport().set_input_as_handled()
		return
	if modal.cycle_keyboard_focus(event):
		return
	if event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif SETTINGS.event_matches_action(event, SETTINGS.ACTION_INTERACT):
		if not _reveal():
			var focus := get_viewport().gui_get_focus_owner()
			if focus is Button and is_ancestor_of(focus):
				focus.pressed.emit()
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_ENTER, KEY_SPACE] and _reveal():
		get_viewport().set_input_as_handled()
