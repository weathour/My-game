extends CanvasLayer

signal restart_requested
signal return_to_camp_requested

const SURVIVORS_MODAL := preload("res://scripts/ui/core/survivors_modal.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")

var modal: Control
var title_label: Label
var message_label: Label
var restart_button: Button
var retry_button: Button
var return_to_camp_on_action: bool = false

func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	modal = SURVIVORS_MODAL.new()
	modal.configure(Vector2(620.0, 440.0), 0.55, 0.65, Vector2(320.0, 300.0))
	modal.set_title("")
	modal.set_hint("")
	add_child(modal)
	_build_content()
	hide_ui()

func show_game_over(survival_time: float, level: int, return_to_camp: bool = false) -> void:
	return_to_camp_on_action = return_to_camp
	restart_button.text = "返回营地" if return_to_camp else "重新开始"
	retry_button.visible = return_to_camp
	_update_message("本轮结束", survival_time, level)
	visible = true
	modal.apply_layout()
	restart_button.grab_focus()

func show_victory(survival_time: float, level: int) -> void:
	return_to_camp_on_action = false
	restart_button.text = "重新开始"
	retry_button.hide()
	_update_message("挑战成功", survival_time, level)
	visible = true
	modal.apply_layout()
	restart_button.grab_focus()

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
	title_label.text = "本轮结束"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SURVIVORS_THEME.apply_label_font(title_label, 30, SURVIVORS_THEME.COLOR_TEXT_GOLD)
	content.add_child(title_label)

	message_label = Label.new()
	message_label.text = "生存时间 00:00"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SURVIVORS_THEME.apply_label_font(message_label, 18, SURVIVORS_THEME.COLOR_TEXT)
	content.add_child(message_label)

	restart_button = Button.new()
	restart_button.text = "重新开始"
	restart_button.custom_minimum_size = Vector2(180, 46)
	restart_button.add_theme_font_size_override("font_size", 18)
	SURVIVORS_THEME.apply_button_style(restart_button, "primary")
	restart_button.pressed.connect(_on_restart_pressed)
	content.add_child(restart_button)
	retry_button = Button.new()
	retry_button.text = "重新挑战本关"
	retry_button.custom_minimum_size.y = 44
	SURVIVORS_THEME.apply_button_style(retry_button)
	retry_button.pressed.connect(func(): restart_requested.emit())
	content.add_child(retry_button)

func set_run_summary(summary: Dictionary, saved: bool) -> void:
	message_label.text = preload("res://scripts/game/run_outcome.gd").describe(summary)
	modal.set_hint("永久进度保留；重试从本关初始构筑开始。" if saved else "保存未成功，原战局仍保留。点击返营或重试会再次尝试保存。")

func _update_message(title_text: String, survival_time: float, level: int) -> void:
	var total_seconds := int(floor(survival_time))
	var minutes := int(total_seconds / 60.0)
	var seconds := total_seconds % 60
	title_label.text = title_text
	message_label.text = "生存时间 %02d:%02d\n本局等级 %d" % [minutes, seconds, level]

func _on_restart_pressed() -> void:
	if return_to_camp_on_action:
		return_to_camp_requested.emit()
	else:
		restart_requested.emit()
