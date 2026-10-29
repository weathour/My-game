extends Control
## Read-only current-event transcript. The reader owns input and story transitions.
signal close_requested

const STYLE := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")
const HELP := "滚轮浏览；滚到底后继续下滚返回。Esc、右键或 Enter / Space 返回；PageUp / PageDown / Home / End 翻阅。"
var scroll: ScrollContainer
var entries: VBoxContainer
var close_button: Button
var _panel: PanelContainer
var _scroll_revision := 0
var _wanted_scroll := 0
var _scroll_pending := false
var _pending_delta := 0

func _ready() -> void:
	name = "StoryHistory"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = STYLE.make_theme()
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.045, 0.035, 0.63)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.name = "StoryHistoryPanel"
	_panel.add_theme_stylebox_override("panel", STYLE.box(Color("14241df2"), STYLE.BORDER, 24))
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	_panel.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	column.add_child(header)
	var title := STYLE.label("历史对白", 22, STYLE.LIGHT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	close_button = STYLE.button("返回对话", _request_close)
	close_button.name = "story_history_close"
	close_button.custom_minimum_size.x = 128
	header.add_child(close_button)
	close_button.focus_next = NodePath(".")
	close_button.focus_previous = NodePath(".")
	scroll = ScrollContainer.new()
	scroll.name = "StoryHistoryScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = false
	column.add_child(scroll)
	entries = VBoxContainer.new()
	entries.name = "StoryHistoryEntries"
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation", 26)
	scroll.add_child(entries)
	var hint := STYLE.label("滚轮浏览 · 到底再下滚返回", 14, STYLE.MUTED)
	hint.name = "StoryHistoryHelp"
	hint.mouse_filter = Control.MOUSE_FILTER_STOP
	hint.tooltip_text = HELP
	column.add_child(hint)
	resized.connect(_layout)
	_layout()
	hide()

func present(records: Array[Dictionary], position: int = -1) -> void:
	for child in entries.get_children():
		entries.remove_child(child)
		child.queue_free()
	if records.is_empty():
		var empty := STYLE.paragraph("还没有可回看的对白。", STYLE.MUTED, SETTINGS.story_font_size(19))
		empty.name = "StoryHistoryEmpty"
		entries.add_child(empty)
	for record: Dictionary in records:
		var entry := VBoxContainer.new()
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.add_theme_constant_override("separation", 7)
		entries.add_child(entry)
		var speaker := STYLE.label(str(record.get("speaker_name", "")), SETTINGS.story_font_size(16), STYLE.GOLD)
		speaker.name = "StoryHistorySpeaker_" + str(record.id)
		speaker.visible = not speaker.text.is_empty()
		entry.add_child(speaker)
		var words := RichTextLabel.new()
		words.name = "StoryHistoryText_" + str(record.id)
		words.text = str(record.get("text", ""))
		words.bbcode_enabled = false
		words.fit_content = true
		words.scroll_active = false
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_font_override("normal_font", STYLE.FONT.get_reading_font())
		words.add_theme_font_size_override("normal_font_size", SETTINGS.story_font_size(21))
		words.add_theme_color_override("default_color", STYLE.INK if speaker.visible else STYLE.MUTED)
		words.add_theme_constant_override("line_separation", 7)
		entry.add_child(words)
	show()
	_layout()
	restore_scroll(position)

func restore_scroll(value: int, delta: int = 0) -> void:
	_scroll_revision += 1
	_wanted_scroll = value
	_pending_delta = delta
	_scroll_pending = true
	_apply_scroll.call_deferred(_scroll_revision)

func _apply_scroll(revision: int) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	# Reopening recreates RichTextLabels before their final width is assigned.
	# Their initial tall minimum can outlive the first container sort. Wait for
	# content and range to agree and remain stable, rather than consuming the
	# queued wheel delta against a transient maximum that later clamps away.
	var previous := Vector4(-1, -1, -1, -1)
	var stable_frames := 0
	while true:
		await tree.process_frame
		if not is_inside_tree() or revision != _scroll_revision or not visible:
			return
		var range_bar := scroll.get_v_scroll_bar()
		var geometry := Vector4(range_bar.max_value, range_bar.page, entries.size.x, entries.size.y)
		var coherent := absf(entries.size.y - entries.get_combined_minimum_size().y) <= 1.0 and absf(range_bar.max_value - entries.size.y) <= 1.0
		stable_frames = stable_frames + 1 if coherent and geometry.is_equal_approx(previous) else 0
		previous = geometry
		if not coherent:
			# A reused scroll container can retain its hidden children's old extent.
			entries.queue_sort()
			scroll.queue_sort()
		if stable_frames >= 2:
			break
	var bar := scroll.get_v_scroll_bar()
	var target := int(maxf(0.0, bar.max_value - bar.page)) if _wanted_scroll < 0 else _wanted_scroll
	scroll.scroll_vertical = target + _pending_delta
	_pending_delta = 0
	_scroll_pending = false

func scroll_position() -> int:
	return _wanted_scroll if _scroll_pending else scroll.scroll_vertical

func pending_scroll_delta() -> int:
	return _pending_delta if _scroll_pending else 0

func scroll_by(amount: int) -> void:
	if _scroll_pending:
		# Wheel bursts may arrive before the first layout has reached the latest row.
		_pending_delta += amount
		return
	scroll.scroll_vertical += amount

func is_at_bottom() -> bool:
	if _scroll_pending:
		return _wanted_scroll < 0 and _pending_delta >= 0
	var bar := scroll.get_v_scroll_bar()
	return scroll.scroll_vertical >= maxf(0.0, bar.max_value - bar.page) - 1.0

func page_key(keycode: int) -> void:
	match keycode:
		KEY_PAGEUP:
			scroll_by(-int(scroll.size.y * 0.8))
		KEY_PAGEDOWN:
			scroll_by(int(scroll.size.y * 0.8))
		KEY_HOME:
			_scroll_revision += 1
			_scroll_pending = false
			scroll.scroll_vertical = 0
		KEY_END:
			if _scroll_pending:
				restore_scroll(-1)
			else:
				scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)

func dismiss() -> void:
	_scroll_revision += 1
	_scroll_pending = false
	hide()

func _layout() -> void:
	if _panel == null:
		return
	var edge := clampf(size.x * 0.025, 20.0, 40.0)
	var width := minf(1120.0, maxf(0.0, size.x - edge * 2.0))
	_panel.position = Vector2((size.x - width) * 0.5, edge)
	_panel.size = Vector2(width, maxf(0.0, size.y - edge * 2.0))

func _request_close() -> void:
	close_requested.emit()
