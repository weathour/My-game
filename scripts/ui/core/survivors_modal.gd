extends Control

const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")

const DEFAULT_WIDTH_RATIO := 0.62
const DEFAULT_HEIGHT_RATIO := 0.70
const DEFAULT_MARGIN := Vector2(24.0, 24.0)

var dimmer: ColorRect
var panel: Panel
var margin: MarginContainer
var content: VBoxContainer
var title_label: Label
var hint_label: Label
var body_host: Control
var footer: HBoxContainer
var max_size := SURVIVORS_THEME.MODAL_DEFAULT_MAX_SIZE
var min_size := SURVIVORS_THEME.MODAL_MIN_SIZE
var width_ratio := DEFAULT_WIDTH_RATIO
var height_ratio := DEFAULT_HEIGHT_RATIO
var edge_margin := DEFAULT_MARGIN
var compact := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	dimmer = ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = SURVIVORS_THEME.COLOR_BACKDROP
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	panel = Panel.new()
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)

	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	title_label = SURVIVORS_THEME.make_title_label("")
	content.add_child(title_label)

	hint_label = SURVIVORS_THEME.make_hint_label("")
	content.add_child(hint_label)

	body_host = Control.new()
	body_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body_host)

	footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 10)
	content.add_child(footer)

	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	apply_layout()

func configure(target_max_size: Vector2, target_width_ratio: float = DEFAULT_WIDTH_RATIO, target_height_ratio: float = DEFAULT_HEIGHT_RATIO, target_min_size: Vector2 = SURVIVORS_THEME.MODAL_MIN_SIZE) -> void:
	max_size = target_max_size
	width_ratio = target_width_ratio
	height_ratio = target_height_ratio
	min_size = target_min_size
	apply_layout()

func set_title(text_value: String) -> void:
	if title_label != null:
		title_label.text = text_value

func set_hint(text_value: String) -> void:
	if hint_label != null:
		hint_label.text = text_value
		hint_label.visible = text_value != ""

func set_body(control: Control) -> void:
	clear_body()
	if control == null or body_host == null:
		return
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_host.add_child(control)
	apply_layout()

func clear_body() -> void:
	if body_host == null:
		return
	for child in body_host.get_children():
		body_host.remove_child(child)
		child.queue_free()

func clear_footer() -> void:
	if footer == null:
		return
	for child in footer.get_children():
		footer.remove_child(child)
		child.queue_free()

func add_footer_button(text_value: String, pressed_callback: Callable, kind: String = "normal") -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(150.0, SURVIVORS_THEME.BUTTON_HEIGHT_COMPACT if compact else SURVIVORS_THEME.BUTTON_HEIGHT)
	button.add_theme_font_size_override("font_size", 15 if compact else 17)
	SURVIVORS_THEME.apply_button_style(button, kind)
	if pressed_callback.is_valid():
		button.pressed.connect(pressed_callback)
	footer.add_child(button)
	return button

func apply_layout() -> void:
	if panel == null:
		return
	var viewport_size := SURVIVORS_THEME.viewport_size(self)
	var available := Vector2(max(1.0, viewport_size.x - edge_margin.x * 2.0), max(1.0, viewport_size.y - edge_margin.y * 2.0))
	var target_size := Vector2(
		clamp(viewport_size.x * width_ratio, min(min_size.x, available.x), min(max_size.x, available.x)),
		clamp(viewport_size.y * height_ratio, min(min_size.y, available.y), min(max_size.y, available.y))
	)
	panel.size = target_size
	panel.position = ((viewport_size - target_size) * 0.5).max(Vector2.ZERO).floor()
	compact = SURVIVORS_THEME.is_compact_size(target_size)
	_apply_current_style(viewport_size)

func _apply_current_style(viewport_size: Vector2) -> void:
	var margin_value := 10 if compact else 18
	panel.add_theme_stylebox_override("panel", SURVIVORS_THEME.panel_style(SURVIVORS_THEME.COLOR_BG, SURVIVORS_THEME.COLOR_BORDER_GOLD, 2, 16))
	margin.add_theme_constant_override("margin_left", margin_value)
	margin.add_theme_constant_override("margin_top", int(float(margin_value) * 0.75))
	margin.add_theme_constant_override("margin_right", margin_value)
	margin.add_theme_constant_override("margin_bottom", int(float(margin_value) * 0.75))
	content.add_theme_constant_override("separation", 7 if compact else 10)
	SURVIVORS_THEME.apply_label_font(title_label, SURVIVORS_THEME.scaled_font(24, viewport_size, -3), SURVIVORS_THEME.COLOR_TEXT)
	SURVIVORS_THEME.apply_label_font(hint_label, SURVIVORS_THEME.scaled_font(14, viewport_size, -2), SURVIVORS_THEME.COLOR_TEXT_MUTED)
	for child in footer.get_children():
		if child is Button:
			(child as Button).custom_minimum_size.y = SURVIVORS_THEME.BUTTON_HEIGHT_COMPACT if compact else SURVIVORS_THEME.BUTTON_HEIGHT
			(child as Button).add_theme_font_size_override("font_size", 15 if compact else 17)

func _on_viewport_size_changed() -> void:
	apply_layout()
