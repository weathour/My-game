extends Control
## Presentation-only visual-novel reader. The owner commits progress before show_line().
signal advance_requested(line_id: String)
signal leave_requested
signal line_presented(line_id: String)

const STYLE := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const PORTRAITS := preload("res://scripts/ui/chronicle/chronicle_portraits.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")
const HISTORY := preload("res://scripts/ui/chronicle/chronicle_story_history.gd")
const CHARACTER_PATH := "res://assets/data/chronicle/characters.json"
const TYPE_SPEED := 42.0

var current_line_id: String = ""
var _event: Dictionary = {}
var _replay := false
var _lines: Array[Dictionary] = []
var _characters: Dictionary = {}
var _line_index := -1
var _built := false
var _busy := false
var _pending := false
var _revealed := 0.0
var _last_request_msec := -1000
var _background_path := ""
var _background_tween: Tween
var _background: TextureRect
var _background_previous: TextureRect
var _actor_layer: Control
var _actors: Dictionary = {}
var _actor_tweens: Dictionary = {}
var _location: Label
var _title: Label
var _header: Control
var _return_button: Button
var _skip_button: Button
var _dialogue: PanelContainer
var _name_panel: PanelContainer
var _speaker_name: Label
var _words: RichTextLabel
var _reading_scroll: ScrollContainer
var _reading: VBoxContainer
var _completion_hint: Label
var _error: Label
var _continue_button: Button
var _counter: Label
var _hint: Label
var _replay_hint: Label
var _body: VBoxContainer
var _history
var _history_button: Button
var _history_previous_focus := ""
var _restore_revision := 0
var _restoring_state := false

func setup(event: Dictionary, line_id: String = "") -> void:
	_event = event.duplicate(true)
	_replay = bool(_event.get("replay", false))
	_lines.clear()
	for value: Variant in _event.get("lines", []):
		if value is Dictionary:
			_lines.append(value)
	# Replay callers keep their current line in UI memory across reader rebuilds.
	current_line_id = line_id
	if current_line_id.is_empty() and not _lines.is_empty():
		current_line_id = str(_lines[0].get("id", ""))
	if _built:
		show_line(current_line_id)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = STYLE.make_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_load_names()
	_build()
	_built = true
	resized.connect(_layout)
	show_line(current_line_id)
	_layout.call_deferred()
	# Acquire focus once, only while this view is the visible reader.
	if is_visible_in_tree():
		_continue_button.grab_focus()

func _load_names() -> void:
	if not FileAccess.file_exists(CHARACTER_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHARACTER_PATH))
	if parsed is Array:
		for character: Variant in parsed:
			if character is Dictionary:
				_characters[str(character.get("id", ""))] = str(character.get("name", ""))

func _build() -> void:
	var floor_color := ColorRect.new()
	floor_color.color = STYLE.DARK
	floor_color.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor_color)
	floor_color.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background_previous = _make_background()
	_background = _make_background()
	_background.name = "StoryBackground"
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.055, 0.04, 0.16)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_actor_layer = Control.new()
	_actor_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_actor_layer)
	_actor_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_header = Control.new()
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_header)
	var heading_panel := PanelContainer.new()
	heading_panel.name = "HeadingPanel"
	heading_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading_panel.add_theme_stylebox_override("panel", STYLE.box(Color("14241dde"), STYLE.BORDER, 12))
	_header.add_child(heading_panel)
	var headings := VBoxContainer.new()
	headings.add_theme_constant_override("separation", 3)
	heading_panel.add_child(headings)
	_location = STYLE.label("", 14, STYLE.GOLD)
	_location.name = "StoryLocation"
	_location.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	headings.add_child(_location)
	_title = STYLE.label("", 18, STYLE.LIGHT)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	headings.add_child(_title)
	_return_button = STYLE.button("返回路线", _request_leave)
	_return_button.name = "story_back"
	_header.add_child(_return_button)
	_skip_button = STYLE.button("跳过本段", _request_skip)
	_skip_button.name = "story_skip"
	_header.add_child(_skip_button)
	_name_panel = PanelContainer.new()
	_name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_panel.add_theme_stylebox_override("panel", STYLE.box(Color("25392bf5"), STYLE.GOLD, 10))
	add_child(_name_panel)
	_speaker_name = STYLE.label("", 20, STYLE.LIGHT)
	_speaker_name.name = "StorySpeaker"
	_name_panel.add_child(_speaker_name)
	_dialogue = PanelContainer.new()
	_dialogue.name = "StoryDialogue"
	_dialogue.add_theme_stylebox_override("panel", STYLE.box(Color("14241df5"), STYLE.BORDER, 18))
	_dialogue.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialogue.gui_input.connect(_dialogue_input)
	add_child(_dialogue)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	_body.mouse_filter = Control.MOUSE_FILTER_PASS
	_dialogue.add_child(_body)
	_reading_scroll = ScrollContainer.new()
	_reading_scroll.name = "StoryReadingScroll"
	_reading_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reading_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reading_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_reading_scroll.follow_focus = false
	_body.add_child(_reading_scroll)
	_reading = VBoxContainer.new()
	_reading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reading.add_theme_constant_override("separation", 12)
	_reading_scroll.add_child(_reading)
	_words = RichTextLabel.new()
	_words.name = "StoryWords"
	_words.bbcode_enabled = false
	_words.scroll_active = false
	_words.fit_content = true
	_words.custom_minimum_size.y = 48
	_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_words.mouse_filter = Control.MOUSE_FILTER_PASS
	_words.selection_enabled = false
	_words.focus_mode = Control.FOCUS_NONE
	_words.add_theme_font_override("normal_font", STYLE.FONT.get_reading_font())
	_words.add_theme_font_size_override("normal_font_size", SETTINGS.story_font_size(22))
	_words.add_theme_color_override("default_color", STYLE.INK)
	_words.add_theme_constant_override("line_separation", 7)
	_words.gui_input.connect(_dialogue_input)
	_reading.add_child(_words)
	_completion_hint = STYLE.paragraph("", STYLE.MUTED, SETTINGS.story_font_size(15))
	_completion_hint.name = "StoryCompletionHint"
	_completion_hint.hide()
	_reading.add_child(_completion_hint)
	_error = STYLE.paragraph("", Color("f4b6a1"), 14)
	_error.name = "StoryError"
	_error.hide()
	_reading.add_child(_error)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	footer.mouse_filter = Control.MOUSE_FILTER_PASS
	_body.add_child(footer)
	_counter = STYLE.label("", 14, STYLE.GOLD)
	footer.add_child(_counter)
	_replay_hint = STYLE.label("回顾不改变行军进度", 13, STYLE.MUTED)
	_replay_hint.name = "StoryReplayHint"
	_replay_hint.hide()
	footer.add_child(_replay_hint)
	_hint = STYLE.label("上滚 历史对白 · Enter / Space 继续", 13, STYLE.MUTED)
	footer.add_child(_hint)
	var footer_spacer := Control.new()
	footer_spacer.name = "StoryFooterSpacer"
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(footer_spacer)
	_history_button = STYLE.button("历史对白", _open_history)
	_history_button.name = "story_history"
	_history_button.tooltip_text = HISTORY.HELP
	_history_button.custom_minimum_size = Vector2(112, 42)
	footer.add_child(_history_button)
	_continue_button = STYLE.button("继续", _request_continue, true)
	_continue_button.name = "event_continue"
	_continue_button.custom_minimum_size = Vector2(144, 42)
	footer.add_child(_continue_button)
	var buttons: Array[Button] = [_return_button, _skip_button, _history_button, _continue_button]
	for index in buttons.size():
		buttons[index].focus_next = buttons[index].get_path_to(buttons[(index + 1) % buttons.size()])
		buttons[index].focus_previous = buttons[index].get_path_to(buttons[posmod(index - 1, buttons.size())])
	_history = HISTORY.new()
	add_child(_history)
	_history.close_requested.connect(_close_history)

func _make_background() -> TextureRect:
	var result := TextureRect.new()
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(result)
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return result

func show_line(line_id: String) -> void:
	current_line_id = line_id
	if not _built:
		return
	_restore_revision += 1
	_restoring_state = false
	if is_history_open():
		_close_history(false)
	_line_index = -1
	for index in _lines.size():
		if str(_lines[index].get("id", "")) == line_id:
			_line_index = index
			break
	_busy = false
	_pending = false
	_error.hide()
	var line: Dictionary = _lines[_line_index] if _line_index >= 0 else {}
	line_presented.emit(line_id)
	_title.text = str(_event.get("title", "剧情"))
	_location.text = str(line.get("location", _event.get("location", "")))
	if _replay:
		_location.text = "剧情回顾" + (" · " + _location.text if not _location.text.is_empty() else "")
	_return_button.text = str(_event.get("return_label", "返回路线"))
	_skip_button.text = "结束回顾" if _replay else "跳过本段"
	_replay_hint.visible = _replay
	_location.visible = not _location.text.is_empty()
	_set_background(_resolved_background())
	var speaker_label := _display_speaker(line)
	_speaker_name.text = speaker_label
	_name_panel.visible = not speaker_label.is_empty()
	_words.text = str(line.get("text", "暂无剧情。"))
	_reading_scroll.scroll_vertical = 0
	_completion_hint.text = "" if _replay else str(_event.get("completion_hint", ""))
	_completion_hint.visible = not _replay and _line_index >= 0 and _line_index == _lines.size() - 1 and not _completion_hint.text.is_empty()
	_revealed = 0.0
	_words.visible_characters = -1 if SETTINGS.comfort_enabled("reduced_motion") or line.is_empty() else 0
	_counter.text = "%02d / %02d" % [_line_index + 1, _lines.size()] if _line_index >= 0 else ""
	_refresh_controls()
	_layout()
	_set_actors(line)

func _resolved_background() -> String:
	var result := str(_event.get("background", ""))
	# Overrides persist when resuming directly into the middle of a scene.
	for index in range(_line_index + 1):
		var candidate := str(_lines[index].get("background", ""))
		if not candidate.is_empty():
			result = candidate
	return result

func _safe_texture(path: String) -> Texture2D:
	if not path.begins_with("res://") or ".." in path or path.get_extension().to_lower() not in ["png", "jpg", "jpeg", "webp", "svg"] or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _set_background(path: String) -> void:
	if path == _background_path:
		return
	if _background_tween and _background_tween.is_valid():
		_background_tween.kill()
	_background_previous.texture = _background.texture
	_background_previous.modulate.a = 1.0
	_background.texture = _safe_texture(path)
	_background_path = path
	_background.modulate.a = 1.0
	if not SETTINGS.comfort_enabled("reduced_motion"):
		_background.modulate.a = 0.0
		_background_tween = create_tween().set_parallel(true)
		_background_tween.tween_property(_background, "modulate:a", 1.0, 0.22)
		_background_tween.tween_property(_background_previous, "modulate:a", 0.0, 0.22)
	else:
		_background_previous.modulate.a = 0.0

func _set_actors(line: Dictionary) -> void:
	var desired: Dictionary = {}
	for raw_actor: Variant in line.get("actors", []):
		if not raw_actor is Dictionary:
			continue
		var actor: Dictionary = raw_actor
		var actor_id := str(actor.get("id", ""))
		var texture: Texture2D = _safe_texture(str(actor.get("texture", "")))
		if texture == null and _characters.has(actor_id):
			# Dialogue composition is independent of the full-body character detail image.
			texture = PORTRAITS.dialogue(actor_id)
		if texture == null:
			continue
		var slot := str(actor.get("slot", "center"))
		if slot not in ["left", "center", "right"]:
			slot = "center"
		desired[actor_id] = {"texture": texture, "slot": slot}
	for actor_id: String in _actors.keys():
		if desired.has(actor_id):
			continue
		var old: TextureRect = _actors[actor_id]
		old.name = "StoryActorLeaving_" + actor_id + "_" + str(old.get_instance_id())
		_kill_actor_tween(actor_id)
		_actors.erase(actor_id)
		if SETTINGS.comfort_enabled("reduced_motion"):
			old.queue_free()
		else:
			var exit_tween := create_tween().set_parallel(true)
			exit_tween.tween_property(old, "modulate:a", 0.0, 0.16)
			exit_tween.tween_property(old, "position:x", old.position.x + 14.0, 0.16)
			exit_tween.chain().tween_callback(old.queue_free)
	for actor_id: String in desired:
		var is_new := not _actors.has(actor_id)
		var portrait: TextureRect
		if is_new:
			portrait = TextureRect.new()
			portrait.name = "StoryActor_" + actor_id
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_actor_layer.add_child(portrait)
			_actors[actor_id] = portrait
		else:
			portrait = _actors[actor_id]
		_kill_actor_tween(actor_id)
		var changed: bool = portrait.texture != desired[actor_id].texture
		portrait.texture = desired[actor_id].texture
		portrait.set_meta("slot", desired[actor_id].slot)
		var speaker := str(line.get("speaker", ""))
		var tint := Color.WHITE if speaker == actor_id else Color(0.72, 0.76, 0.70)
		if speaker in ["", "narrator"]:
			tint = Color(0.88, 0.90, 0.84)
		portrait.set_meta("target_modulate", tint)
		if is_new:
			_layout_actor(portrait)
		if SETTINGS.comfort_enabled("reduced_motion"):
			portrait.modulate = tint
		else:
			if is_new or changed:
				portrait.modulate = Color(tint, 0.0)
				portrait.position.x += 14.0 if desired[actor_id].slot == "right" else -14.0
			var tween := create_tween().set_parallel(true)
			_actor_tweens[actor_id] = tween
			tween.tween_property(portrait, "modulate", tint, 0.20)
			tween.tween_property(portrait, "position", _actor_position(portrait), 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _kill_actor_tween(actor_id: String) -> void:
	if _actor_tweens.has(actor_id):
		var tween: Tween = _actor_tweens[actor_id]
		if tween and tween.is_valid():
			tween.kill()
		_actor_tweens.erase(actor_id)

func _actor_position(portrait: TextureRect) -> Vector2:
	var slot := str(portrait.get_meta("slot", "center"))
	var fraction := 0.5
	if slot == "left":
		fraction = 0.25
	elif slot == "right":
		fraction = 0.75
	return Vector2(size.x * fraction - portrait.size.x * 0.5, size.y - _dialogue.size.y * 0.37 - portrait.size.y)

func _actor_size() -> Vector2:
	var height := maxf(180.0, size.y - _dialogue.size.y * 0.37 - maxf(88.0, size.y * 0.11))
	return Vector2(minf(size.x * 0.45, height * 0.8), height)

func _layout_actor(portrait: TextureRect) -> void:
	portrait.size = _actor_size()
	portrait.position = _actor_position(portrait)

func _layout() -> void:
	if not _built:
		return
	var edge := clampf(size.x * 0.035, 22.0, 68.0)
	var width := minf(size.x - edge * 2.0, 1440.0)
	var left := (size.x - width) * 0.5
	var height := clampf(size.y * 0.29, 204.0, 310.0)
	_dialogue.position = Vector2(left, size.y - height - 20.0)
	_dialogue.size = Vector2(width, height)
	_name_panel.position = Vector2(left + 18.0, _dialogue.position.y - 43.0)
	_name_panel.size = Vector2(maxf(136.0, _speaker_name.get_minimum_size().x + 32.0), 43.0)
	_header.position = Vector2(edge, 20.0)
	_header.size = Vector2(size.x - edge * 2.0, 70.0)
	var heading_panel := _header.get_node("HeadingPanel") as PanelContainer
	heading_panel.position = Vector2.ZERO
	heading_panel.size = Vector2(minf(_header.size.x - 300.0, 300.0), 64.0)
	_return_button.position = Vector2(_header.size.x - 244.0, 0.0)
	_return_button.size = Vector2(116, 42)
	_skip_button.position = Vector2(_header.size.x - 116.0, 0.0)
	_skip_button.size = Vector2(116, 42)
	_hint.visible = size.x >= 1100.0
	_words.add_theme_font_size_override("normal_font_size", SETTINGS.story_font_size(20 if size.y < 650 else 22))
	for actor_id: String in _actors:
		var portrait: TextureRect = _actors[actor_id]
		# Layout owns the stage coordinates. Never retain a tween's stale destination
		# after first attachment, parent layout, or a viewport resize.
		var was_animating := _actor_tweens.has(actor_id) and (_actor_tweens[actor_id] as Tween).is_running()
		_kill_actor_tween(actor_id)
		_layout_actor(portrait)
		var target_tint: Color = portrait.get_meta("target_modulate", Color.WHITE)
		if was_animating and not SETTINGS.comfort_enabled("reduced_motion"):
			# Preserve only the visual fade; position has already been corrected.
			var fade := create_tween()
			_actor_tweens[actor_id] = fade
			fade.tween_property(portrait, "modulate", target_tint, 0.12)
		else:
			portrait.modulate = target_tint

func _process(delta: float) -> void:
	if not _built or not is_visible_in_tree() or is_history_open() or _restoring_state or _words.visible_characters < 0:
		return
	_revealed += delta * TYPE_SPEED
	_words.visible_characters = int(_revealed)
	if _words.visible_characters >= _words.get_total_character_count():
		reveal_current()

func reveal_current() -> void:
	if not _built or is_history_open():
		return
	_words.visible_characters = -1
	_refresh_controls()

func set_busy(value: bool) -> void:
	_busy = value
	_pending = value
	if _built:
		_refresh_controls()

func show_error(message: String) -> void:
	# A failed commit may be retried immediately; pending still guards each attempt.
	_last_request_msec = -1000
	set_busy(false)
	if not _built:
		return
	_error.text = message
	_error.visible = not message.is_empty()
	if _error.visible:
		_reading_scroll.ensure_control_visible.call_deferred(_error)

func _refresh_controls() -> void:
	var blocked := _busy or _pending
	var history_open := is_history_open()
	_return_button.disabled = blocked or history_open
	_skip_button.disabled = blocked or history_open or _line_index < 0
	_continue_button.disabled = blocked or history_open or _line_index < 0
	_history_button.disabled = blocked or history_open
	if blocked:
		_continue_button.text = "请稍候…" if _replay else "保存中…"
	elif _words.visible_characters >= 0:
		_continue_button.text = "显示整句"
	else:
		var finish := "结束回顾" if _replay else str(_event.get("finish_label", "完成剧情"))
		_continue_button.text = finish if _line_index == _lines.size() - 1 else "继续"

func _request_continue() -> void:
	if _busy or _pending or is_history_open() or _line_index < 0:
		return
	if _words.visible_characters >= 0:
		reveal_current()
		return
	var next_id := str(_lines[_line_index + 1].get("id", "")) if _line_index + 1 < _lines.size() else ""
	_request_advance(next_id)

func _request_skip() -> void:
	if _busy or _pending or is_history_open() or _line_index < 0:
		return
	_request_advance("")

func _request_advance(next_id: String) -> void:
	if _busy or _pending or is_history_open():
		return
	if Time.get_ticks_msec() - _last_request_msec < 150:
		return
	_last_request_msec = Time.get_ticks_msec()
	_pending = true
	_refresh_controls()
	advance_requested.emit(next_id)

func _request_leave() -> void:
	if _busy or _pending or is_history_open():
		return
	_pending = true
	_refresh_controls()
	leave_requested.emit()

func _dialogue_input(event: InputEvent) -> void:
	if is_history_open():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Commit handlers may synchronously detach this reader. Consume first.
		accept_event()
		if not event.double_click:
			_request_continue()

func _gui_input(event: InputEvent) -> void:
	_dialogue_input(event)

func _input(event: InputEvent) -> void:
	if not _built or not is_visible_in_tree():
		return
	# Keep the viewport while this reader is attached; signals may replace the tree.
	var viewport := get_viewport()
	if viewport == null:
		return
	if event is InputEventMouseButton:
		if not get_global_rect().has_point(event.position):
			return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			viewport.set_input_as_handled()
			if not event.pressed:
				return
			if not is_history_open():
				if event.button_index == MOUSE_BUTTON_WHEEL_UP:
					_open_history()
				else:
					_reading_scroll.scroll_vertical += 64
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and _history.is_at_bottom():
				_close_history()
			else:
				_history.scroll_by((-64 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 64) * maxi(1, int(event.factor)))
			return
		if is_history_open() and event.button_index == MOUSE_BUTTON_RIGHT:
			viewport.set_input_as_handled()
			if event.pressed:
				_close_history()
			return
	if not event is InputEventKey or not event.pressed:
		return
	if is_history_open():
		if event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] or SETTINGS.event_matches_action(event, SETTINGS.ACTION_INTERACT):
			viewport.set_input_as_handled()
			if not event.echo:
				_close_history()
		elif event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN, KEY_HOME, KEY_END]:
			viewport.set_input_as_handled()
			_history.page_key(event.keycode)
		elif event.keycode in [KEY_UP, KEY_DOWN]:
			viewport.set_input_as_handled()
			_history.scroll_by(-48 if event.keycode == KEY_UP else 48)
		return
	if event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_PAGEUP]:
			viewport.set_input_as_handled()
		return
	if event.keycode == KEY_PAGEUP:
		viewport.set_input_as_handled()
		_open_history()
	elif event.keycode in [KEY_PAGEDOWN, KEY_HOME, KEY_END]:
		viewport.set_input_as_handled()
		match event.keycode:
			KEY_PAGEDOWN:
				_reading_scroll.scroll_vertical += int(_reading_scroll.size.y * 0.8)
			KEY_HOME:
				_reading_scroll.scroll_vertical = 0
			KEY_END:
				_reading_scroll.scroll_vertical = int(_reading_scroll.get_v_scroll_bar().max_value)
	elif event.keycode == KEY_ESCAPE:
		viewport.set_input_as_handled()
		_request_leave()
	elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] or SETTINGS.event_matches_action(event, SETTINGS.ACTION_INTERACT):
		viewport.set_input_as_handled()
		var focus := viewport.gui_get_focus_owner()
		if focus is Button and is_ancestor_of(focus) and focus != _continue_button and (_words.visible_characters < 0 or focus == _history_button):
			if not focus.disabled:
				focus.pressed.emit()
		else:
			_request_continue()

func is_history_open() -> bool:
	return is_instance_valid(_history) and _history.visible

func _display_speaker(line: Dictionary) -> String:
	var explicit_name := str(line.get("speaker_name", "")).strip_edges()
	if not explicit_name.is_empty(): return explicit_name
	var speaker := str(line.get("speaker", ""))
	return "" if speaker in ["", "narrator"] else str(_characters.get(speaker, speaker))

func history_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _built or _line_index < 0:
		return result
	for index in range(_line_index + 1):
		var line: Dictionary = _lines[index]
		var text := str(line.get("text", ""))
		if index == _line_index and _words.visible_characters >= 0:
			text = text.substr(0, _words.visible_characters)
		if text.is_empty():
			continue
		var speaker := str(line.get("speaker", ""))
		var display_name := _display_speaker(line)
		result.append({"id": str(line.get("id", "")), "speaker": speaker, "speaker_id": speaker, "speaker_name": display_name, "text": text})
	return result

func _focus_path() -> String:
	var focus := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return str(focus.name) if is_instance_valid(focus) and is_ancestor_of(focus) and str(focus.name) in ["event_continue", "story_back", "story_skip", "story_history", "story_history_close"] else ""

func _focus_control(control_name: String) -> Control:
	return find_child(control_name, true, false) as Control if not control_name.is_empty() else null

func _open_history(position: int = -1, take_focus: bool = true) -> void:
	if not _built or _busy or _pending or is_history_open():
		return
	_history_previous_focus = _focus_path()
	_history.present(history_entries(), position)
	_refresh_controls()
	if take_focus:
		_history.close_button.grab_focus()

func _close_history(restore_focus: bool = true) -> void:
	if not is_history_open():
		return
	_history.dismiss()
	_refresh_controls()
	if restore_focus and is_inside_tree() and is_visible_in_tree():
		var focus := _focus_control(_history_previous_focus)
		if is_instance_valid(focus) and focus.is_visible_in_tree() and not (focus is Button and focus.disabled):
			focus.grab_focus()
		else:
			_history_button.grab_focus()

func reading_state() -> Dictionary:
	if not _built:
		return {}
	return {
		"event_id": str(_event.get("id", "")), "line_id": current_line_id, "replay": _replay,
		"visible_characters": _words.visible_characters, "revealed": _revealed,
		"reading_scroll": _reading_scroll.scroll_vertical,
		"history_open": is_history_open(), "history_scroll": _history.scroll_position() if is_history_open() else 0,
		"history_scroll_delta": _history.pending_scroll_delta() if is_history_open() else 0,
		"error_text": _error.text, "error_visible": _error.visible,
		"focus_path": _focus_path(), "previous_focus_path": _history_previous_focus
	}

func restore_reading_state(value: Dictionary) -> void:
	if not _built or not is_inside_tree() or not _state_matches(value):
		return
	_restore_revision += 1
	_restoring_state = true
	_words.visible_characters = clampi(int(value.get("visible_characters", -1)), -1, _words.get_total_character_count())
	_revealed = maxf(0.0, float(value.get("revealed", 0.0)))
	_error.text = str(value.get("error_text", ""))
	_error.visible = bool(value.get("error_visible", false)) and not _error.text.is_empty()
	if is_history_open():
		_close_history(false)
	if bool(value.get("history_open", false)):
		_open_history(int(value.get("history_scroll", -1)), false)
		_history.restore_scroll(int(value.get("history_scroll", -1)), int(value.get("history_scroll_delta", 0)))
	_history_previous_focus = str(value.get("previous_focus_path", ""))
	_refresh_controls()
	_restore_geometry.call_deferred(value.duplicate(true), _restore_revision)

func _state_matches(value: Dictionary) -> bool:
	return value.has("event_id") and value.has("line_id") and str(value.event_id) == str(_event.get("id", "")) and str(value.line_id) == current_line_id and bool(value.get("replay", false)) == _replay

func _restore_geometry(value: Dictionary, revision: int) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	for index in 3:
		await tree.process_frame
		if not is_inside_tree() or revision != _restore_revision or not _state_matches(value):
			return
	_reading_scroll.scroll_vertical = int(value.get("reading_scroll", 0))
	if is_history_open():
		_history.restore_scroll(int(value.get("history_scroll", -1)), int(value.get("history_scroll_delta", 0)))
	var focus_path := str(value.get("focus_path", ""))
	var focus := _focus_control(focus_path)
	if is_instance_valid(focus) and focus.is_visible_in_tree() and not (focus is Button and focus.disabled):
		focus.grab_focus()
	elif is_history_open():
		_history.close_button.grab_focus()
	_restoring_state = false
