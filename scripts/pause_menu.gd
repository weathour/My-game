extends CanvasLayer

const SETTINGS_PANEL := preload("res://scripts/ui/main_menu/main_menu_settings_panel.gd")
const SURVIVORS_MODAL := preload("res://scripts/ui/core/survivors_modal.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")

signal resume_requested
signal restart_requested
signal main_menu_requested
signal end_run_requested
signal hud_layout_changed(layout_key: String)

var modal: Control
var settings_panel: Control
var end_run_button: Button
var end_run_confirm_dialog: ConfirmationDialog
var endless_mode_enabled: bool = false

func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	modal = SURVIVORS_MODAL.new()
	modal.configure(Vector2(460.0, 430.0), 0.42, 0.80, Vector2(280.0, 320.0))
	modal.set_title("暂停")
	modal.set_hint("")
	add_child(modal)
	_build_content()
	settings_panel = SETTINGS_PANEL.new()
	add_child(settings_panel)
	settings_panel.hud_layout_changed.connect(func(key: String): hud_layout_changed.emit(key))
	hide_ui()

func show_ui() -> void:
	visible = true
	if modal != null and modal.has_method("apply_layout"):
		modal.apply_layout()

func hide_ui() -> void:
	visible = false
	if settings_panel != null:
		settings_panel.close_panel()
	if end_run_confirm_dialog != null:
		end_run_confirm_dialog.hide()

func set_endless_mode_enabled(enabled: bool) -> void:
	endless_mode_enabled = enabled
	if end_run_button != null:
		end_run_button.visible = enabled

func _build_content() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal.set_body(scroll)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)

	content.add_child(_make_action_button("继续游戏", Callable(self, "_on_resume_pressed"), "primary"))
	content.add_child(_make_action_button("重新开始", Callable(self, "_on_restart_pressed")))
	end_run_button = _make_action_button("结束本轮并返回营地", Callable(self, "_on_end_run_pressed"))
	end_run_button.visible = endless_mode_enabled
	content.add_child(end_run_button)
	content.add_child(_make_action_button("返回主菜单", Callable(self, "_on_main_menu_pressed")))

	content.add_child(_make_action_button("设置与按键", func(): settings_panel.open()))

func _make_action_button(text_value: String, callback: Callable, kind: String = "normal") -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 20)
	SURVIVORS_THEME.apply_button_style(button, kind)
	button.pressed.connect(callback)
	return button

func _on_resume_pressed() -> void:
	resume_requested.emit()

func _on_restart_pressed() -> void:
	restart_requested.emit()

func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()

func _on_end_run_pressed() -> void:
	if not endless_mode_enabled:
		return
	if end_run_confirm_dialog == null:
		end_run_confirm_dialog = ConfirmationDialog.new()
		end_run_confirm_dialog.title = "结束本轮"
		end_run_confirm_dialog.dialog_text = "本关等级和局内装备将结束，永久进度与物品保留。确定结束并返营吗？"
		end_run_confirm_dialog.ok_button_text = "结束并返营"
		end_run_confirm_dialog.cancel_button_text = "继续战斗"
		end_run_confirm_dialog.confirmed.connect(func(): end_run_requested.emit())
		add_child(end_run_confirm_dialog)
	end_run_confirm_dialog.popup_centered(Vector2i(440, 190))
