extends Control

signal closed

const CATALOG := preload("res://scripts/audio/music_catalog.gd")
const BGM := preload("res://scripts/bgm_player.gd")
const STYLE := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const CAMP_ART := preload("res://assets/story/communications_camp.png")
const GOLD := Color("#d8b65f")
const PALE_GOLD := Color("#f1dfad")
const GREEN := Color("#14251c")
const GREEN_LIGHT := Color("#203b2b")
const WINE := Color("#32171d")

var _menu_bgm: Node
var _menu_position := 0.0
var _focus_before_open: Control
var _preview: AudioStreamPlayer
var _track_buttons: Array[Button] = []
var _focus_order: Array[Control] = []
var _selected_index := 0
var _duration := 0.0
var _is_open := false
var _seeking := false

var _playlist: VBoxContainer
var _page_margin: MarginContainer
var _page_layout: VBoxContainer
var _body: HBoxContainer
var _archive_panel: PanelContainer
var _player_margin: MarginContainer
var _player_column: VBoxContainer
var _artwork: TextureRect
var _page_title: Label
var _track_title: Label
var _track_scene: Label
var _track_number: Label
var _track_kind: Label
var _mute_status: Label
var _elapsed: Label
var _remaining: Label
var _seek: HSlider
var _play_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_page()
	STYLE.apply_screen_frame(self)
	get_viewport().size_changed.connect(_fit_layout)
	_fit_layout()

func _process(_delta: float) -> void:
	if not _is_open or _preview == null or _preview.stream == null:
		return
	_apply_preview_volume()
	var position := _preview.get_playback_position() if _preview.playing or _preview.stream_paused else _seek.value
	if not _seeking:
		_seek.set_value_no_signal(clampf(position, 0.0, _duration))
	_elapsed.text = _format_time(position)
	_remaining.text = _format_time(maxf(0.0, _duration - position))
	_update_mute_status()

func open(menu_bgm: Node = null) -> void:
	if _is_open:
		return
	_is_open = true
	_seeking = false
	_menu_bgm = menu_bgm
	_focus_before_open = get_viewport().gui_get_focus_owner()
	if is_instance_valid(_menu_bgm):
		_menu_position = float(_menu_bgm.get_saved_playback_position())
		_menu_bgm.pause_music()
	visible = true
	_set_track(0, true)
	if not _track_buttons.is_empty():
		call_deferred("_focus_first_track")

func _focus_first_track() -> void:
	if _is_open and not _track_buttons.is_empty():
		_track_buttons[0].grab_focus()

func close_panel() -> void:
	if not _is_open:
		visible = false
		return
	_is_open = false
	if is_instance_valid(_preview):
		_preview.stop()
		_preview.stream = null
		_preview.queue_free()
	_preview = null
	visible = false
	if is_instance_valid(_menu_bgm):
		_menu_bgm.restore_playback_position(_menu_position)
		_menu_bgm.resume_music()
	_menu_bgm = null
	if is_instance_valid(_focus_before_open) and _focus_before_open.is_visible_in_tree():
		_focus_before_open.grab_focus()
	_focus_before_open = null
	closed.emit()

func _fit_layout() -> void:
	var compact := get_viewport_rect().size.x < 1100.0 or get_viewport_rect().size.y < 650.0
	var horizontal_margin := 32 if compact else 30
	var vertical_margin := 36 if compact else 28
	for side in ["left", "right"]:
		_page_margin.add_theme_constant_override("margin_" + side, horizontal_margin)
	_page_margin.add_theme_constant_override("margin_top", vertical_margin)
	_page_margin.add_theme_constant_override("margin_bottom", 40 if compact else vertical_margin)
	_page_layout.add_theme_constant_override("separation", 6 if compact else 12)
	_body.add_theme_constant_override("separation", 8 if compact else 16)
	_archive_panel.custom_minimum_size.x = 330 if compact else 365
	_player_margin.add_theme_constant_override("margin_left", 12 if compact else 20)
	_player_margin.add_theme_constant_override("margin_top", 8 if compact else 18)
	_player_margin.add_theme_constant_override("margin_right", 12 if compact else 20)
	_player_margin.add_theme_constant_override("margin_bottom", 8 if compact else 16)
	_player_column.add_theme_constant_override("separation", 6 if compact else 12)
	_artwork.custom_minimum_size.y = 140 if compact else 170
	_artwork.size_flags_vertical = Control.SIZE_FILL if compact else Control.SIZE_EXPAND_FILL
	_page_title.add_theme_font_size_override("font_size", 26 if compact else 30)
	_track_title.add_theme_font_size_override("font_size", 23 if compact else 27)
	_track_scene.add_theme_font_size_override("font_size", 14 if compact else 16)
	for button in _track_buttons:
		button.custom_minimum_size.y = 68 if compact else 56
		button.add_theme_font_size_override("font_size", 14 if compact else 15)
	for name in ["PreviousTrack", "NextTrack"]:
		var button: Button = find_child(name, true, false)
		button.custom_minimum_size = Vector2(112, 42) if compact else Vector2(132, 48)
	_play_button.custom_minimum_size = Vector2(136, 44) if compact else Vector2(156, 50)

func _build_page() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#080b08")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	_page_margin = MarginContainer.new()
	_page_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_page_margin)

	_page_layout = VBoxContainer.new()
	_page_layout.add_theme_constant_override("separation", 12)
	_page_margin.add_child(_page_layout)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	_page_layout.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_page_title = STYLE.make_section_label("音乐鉴赏", 30)
	_page_title.add_theme_color_override("font_color", PALE_GOLD)
	heading.add_child(_page_title)
	var close_button := _button("返回主菜单", false)
	close_button.name = "ReturnToMenu"
	close_button.custom_minimum_size = Vector2(148, 46)
	close_button.pressed.connect(close_panel)
	header.add_child(close_button)
	_focus_order.append(close_button)

	var divider := ColorRect.new()
	divider.color = Color(GOLD, 0.65)
	divider.custom_minimum_size.y = 2
	_page_layout.add_child(divider)

	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 16)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_layout.add_child(_body)
	_body.add_child(_build_playlist_panel())
	_body.add_child(_build_player_panel())

	var footer := HBoxContainer.new()
	footer.name = "MusicFooter"
	_page_layout.add_child(footer)
	var hint := STYLE.make_hint_label("曲目结束后自动播放下一首　·　Tab 切换控件　·　Esc 返回", 14)
	hint.name = "PlaybackHint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	footer.add_child(hint)
	_mute_status = STYLE.make_hint_label("", 14)
	_mute_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mute_status.add_theme_color_override("font_color", GOLD)
	footer.add_child(_mute_status)

func _build_playlist_panel() -> Control:
	_archive_panel = PanelContainer.new()
	_archive_panel.name = "TrackArchive"
	_archive_panel.custom_minimum_size.x = 365
	_archive_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_archive_panel.add_theme_stylebox_override("panel", _box(GREEN, Color("#8b7441"), 1, 4, 12))
	STYLE.apply_campaign_frame(_archive_panel, "panel")
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_archive_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var archive_title := STYLE.make_section_label("曲目目录", 20)
	archive_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	archive_title.add_theme_color_override("font_color", PALE_GOLD)
	heading.add_child(archive_title)
	var count := STYLE.make_hint_label("14 首", 14)
	count.add_theme_color_override("font_color", GOLD)
	heading.add_child(count)
	var scroll := ScrollContainer.new()
	scroll.name = "TrackScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	column.add_child(scroll)
	_playlist = VBoxContainer.new()
	_playlist.add_theme_constant_override("separation", 5)
	_playlist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_playlist)
	for index in CATALOG.CUES.size():
		var cue: String = CATALOG.CUES[index]
		var info: Dictionary = CATALOG.TRACK_INFO[cue]
		var button := _button("%02d   %s\n       %s" % [index + 1, info.title, info.scene], false)
		button.name = "Track_" + cue
		button.custom_minimum_size = Vector2(0, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(_set_track.bind(index, true))
		_track_buttons.append(button)
		_focus_order.append(button)
		_playlist.add_child(button)
	return _archive_panel

func _build_player_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "ListeningRoom"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(WINE, Color("#9c7c48"), 1, 4, 16))
	STYLE.apply_campaign_frame(panel, "panel")
	_player_margin = MarginContainer.new()
	panel.add_child(_player_margin)
	_player_column = VBoxContainer.new()
	_player_column.add_theme_constant_override("separation", 12)
	_player_margin.add_child(_player_column)
	var track_header := HBoxContainer.new()
	_player_column.add_child(track_header)
	_track_number = STYLE.make_hint_label("", 14)
	_track_number.add_theme_color_override("font_color", GOLD)
	_track_number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_header.add_child(_track_number)
	_track_kind = STYLE.make_hint_label("", 14)
	_track_kind.add_theme_color_override("font_color", PALE_GOLD)
	track_header.add_child(_track_kind)
	_artwork = TextureRect.new()
	_artwork.name = "AlbumArt"
	_artwork.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_artwork.texture = CAMP_ART
	_artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_column.add_child(_artwork)
	_track_title = STYLE.make_title_label("", 27)
	_track_title.add_theme_color_override("font_color", PALE_GOLD)
	_track_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_player_column.add_child(_track_title)
	_track_scene = STYLE.make_hint_label("", 16)
	_track_scene.add_theme_color_override("font_color", Color("#d6caa9"))
	_player_column.add_child(_track_scene)
	var seek_row := HBoxContainer.new()
	_player_column.add_child(seek_row)
	_elapsed = STYLE.make_hint_label("0:00", 13)
	_elapsed.custom_minimum_size.x = 48
	seek_row.add_child(_elapsed)
	_seek = HSlider.new()
	_seek.name = "TrackPosition"
	_seek.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seek.custom_minimum_size.y = 24
	_seek.min_value = 0.0
	_seek.step = 0.1
	_seek.value_changed.connect(_on_seek_changed)
	_seek.drag_started.connect(func(): _seeking = true)
	_seek.drag_ended.connect(_on_seek_drag_ended)
	seek_row.add_child(_seek)
	_focus_order.append(_seek)
	_remaining = STYLE.make_hint_label("0:00", 13)
	_remaining.custom_minimum_size.x = 48
	_remaining.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	seek_row.add_child(_remaining)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 12)
	_player_column.add_child(controls)
	var previous := _button("◀  上一首", false)
	previous.name = "PreviousTrack"
	previous.custom_minimum_size = Vector2(132, 48)
	previous.pressed.connect(_previous)
	controls.add_child(previous)
	_focus_order.append(previous)
	_play_button = _button("Ⅱ  暂停", true)
	_play_button.name = "TogglePlayback"
	_play_button.custom_minimum_size = Vector2(156, 50)
	_play_button.pressed.connect(_toggle_playback)
	controls.add_child(_play_button)
	_focus_order.append(_play_button)
	var next := _button("下一首  ▶", false)
	next.name = "NextTrack"
	next.custom_minimum_size = Vector2(132, 48)
	next.pressed.connect(_next)
	controls.add_child(next)
	_focus_order.append(next)
	return panel

func _set_track(index: int, start_playback: bool) -> void:
	if index < 0 or index >= CATALOG.CUES.size():
		return
	_selected_index = index
	var cue: String = CATALOG.CUES[index]
	var info: Dictionary = CATALOG.TRACK_INFO[cue]
	_track_number.text = "曲目 %02d / %02d" % [index + 1, CATALOG.CUES.size()]
	_track_title.text = info.title
	_track_scene.text = info.scene
	_track_kind.text = info.kind
	_duration = 0.0
	if _preview == null:
		_preview = AudioStreamPlayer.new()
		_preview.name = "MusicRoomPreview"
		_preview.bus = str(_menu_bgm.get("bus")) if is_instance_valid(_menu_bgm) else "Master"
		_preview.finished.connect(_on_track_finished)
		add_child(_preview)
	_preview.stop()
	_preview.stream = null
	var source := load(CATALOG.path(cue)) as AudioStream
	if source == null:
		_play_button.text = "无法读取"
		return
	var audition := source.duplicate() as AudioStream
	if audition is AudioStreamOggVorbis:
		audition.loop = false
	_preview.stream = audition
	_duration = audition.get_length()
	_seek.max_value = _duration
	_seek.set_value_no_signal(0.0)
	_elapsed.text = "0:00"
	_remaining.text = _format_time(_duration)
	if start_playback:
		_preview.stream_paused = false
		_preview.play()
		_play_button.text = "Ⅱ  暂停"
	else:
		_play_button.text = "▶  播放"
	_apply_preview_volume()
	_update_mute_status()
	_update_track_selection()

func _previous() -> void:
	_set_track(posmod(_selected_index - 1, CATALOG.CUES.size()), true)

func _next() -> void:
	_set_track(posmod(_selected_index + 1, CATALOG.CUES.size()), true)

func _on_track_finished() -> void:
	if _is_open:
		_next()

func _toggle_playback() -> void:
	if _preview == null or _preview.stream == null:
		return
	if _preview.stream_paused:
		_preview.stream_paused = false
		_play_button.text = "Ⅱ  暂停"
	elif _preview.playing:
		_preview.stream_paused = true
		_play_button.text = "▶  播放"
	else:
		_preview.play(_seek.value)
		_play_button.text = "Ⅱ  暂停"

func _on_seek_changed(value: float) -> void:
	if is_instance_valid(_preview) and _preview.stream != null and (_preview.playing or _preview.stream_paused) and _seek.has_focus():
		var was_paused := _preview.stream_paused
		_preview.stream_paused = false
		_preview.seek(value)
		_preview.stream_paused = was_paused

func _on_seek_drag_ended(_value_changed: bool) -> void:
	_seeking = false

func _apply_preview_volume() -> void:
	if not is_instance_valid(_preview):
		return
	var volume := clampf(BGM.load_music_volume(), 0.0, 1.0)
	_preview.volume_db = BGM.MUTED_VOLUME_DB if BGM.load_music_muted() or volume <= 0.0 else linear_to_db(volume)

func _update_mute_status() -> void:
	var muted := BGM.load_music_muted()
	var volume := int(round(BGM.load_music_volume() * 100.0))
	_mute_status.text = "静音已开启" if muted else "音乐音量 %d%%" % volume
	_mute_status.add_theme_color_override("font_color", Color("#ef7e79") if muted else GOLD)

func _update_track_selection() -> void:
	for index in _track_buttons.size():
		var selected := index == _selected_index
		var button := _track_buttons[index]
		button.add_theme_stylebox_override("normal", _box(GREEN_LIGHT if selected else GREEN, GOLD if selected else Color("#514535"), 2 if selected else 1, 3, 9))
		button.add_theme_color_override("font_color", PALE_GOLD if selected else Color("#d4ceb9"))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, GOLD, 2, 3, 8))

func _button(text_value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 42
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	STYLE.apply_button_style(button, "primary" if primary else "normal")
	button.add_theme_stylebox_override("normal", _box(WINE if primary else GREEN, GOLD if primary else Color("#746344"), 2 if primary else 1, 3, 8))
	button.add_theme_color_override("font_color", PALE_GOLD)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, GOLD, 2, 3, 8))
	return button

func _box(fill: Color, border: Color, width: int, radius: int, inset: float) -> StyleBoxFlat:
	var style := STYLE.panel_style(fill, border, width, radius, inset)
	style.set_corner_radius_all(radius)
	return style

func _format_time(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	return "%d:%02d" % [total / 60, total % 60]

func _unhandled_key_input(event: InputEvent) -> void:
	if _is_open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_panel()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not _is_open or not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_TAB or _focus_order.is_empty():
		return
	var current := _focus_order.find(get_viewport().gui_get_focus_owner())
	var step := -1 if event.shift_pressed else 1
	var start := current if current >= 0 else (0 if step > 0 else _focus_order.size() - 1)
	_focus_order[posmod(start + step, _focus_order.size())].grab_focus()
	get_viewport().set_input_as_handled()
