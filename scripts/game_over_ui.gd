extends CanvasLayer

signal restart_requested

const SURVIVORS_MODAL := preload("res://scripts/ui/core/survivors_modal.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")

var modal: Control
var title_label: Label
var message_label: Label
var restart_button: Button

func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	modal = SURVIVORS_MODAL.new()
	modal.configure(Vector2(420.0, 260.0), 0.36, 0.36, Vector2(280.0, 200.0))
	modal.set_title("")
	modal.set_hint("")
	add_child(modal)
	_build_content()
	hide_ui()

func show_game_over(survival_time: float, level: int) -> void:
	_update_message("Game Over", survival_time, level)
	visible = true
	modal.apply_layout()

func show_victory(survival_time: float, level: int) -> void:
	_update_message("Victory", survival_time, level)
	visible = true
	modal.apply_layout()

func hide_ui() -> void:
	visible = false

func _build_content() -> void:
	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	modal.set_body(content)

	title_label = Label.new()
	title_label.text = "Game Over"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SURVIVORS_THEME.apply_label_font(title_label, 30, SURVIVORS_THEME.COLOR_TEXT_GOLD)
	content.add_child(title_label)

	message_label = Label.new()
	message_label.text = "You survived 00:00"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SURVIVORS_THEME.apply_label_font(message_label, 18, SURVIVORS_THEME.COLOR_TEXT)
	content.add_child(message_label)

	restart_button = Button.new()
	restart_button.text = "Restart"
	restart_button.custom_minimum_size = Vector2(180, 46)
	restart_button.add_theme_font_size_override("font_size", 18)
	SURVIVORS_THEME.apply_button_style(restart_button, "primary")
	restart_button.pressed.connect(_on_restart_pressed)
	content.add_child(restart_button)

func _update_message(title_text: String, survival_time: float, level: int) -> void:
	var total_seconds := int(floor(survival_time))
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	title_label.text = title_text
	message_label.text = "You survived %02d:%02d\nReached Level %d" % [minutes, seconds, level]

func _on_restart_pressed() -> void:
	restart_requested.emit()
