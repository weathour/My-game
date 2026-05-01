extends PanelContainer

const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const PERFORMANCE_MONITOR := preload("res://scripts/game/performance_monitor.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")

signal level_up_requested
signal boss_spawn_requested(archetype_id: String)
signal card_grant_requested(card_id: String)
signal small_boss_spawn_requested(archetype_id: String)

var level_button: Button
var invincibility_button: Button
var no_cooldown_button: Button
var boss_list: VBoxContainer
var dangzhen_build_list: VBoxContainer
var special_card_list: VBoxContainer
var performance_label: Label

func _ready() -> void:
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = -280.0
	offset_top = 180.0
	offset_right = -18.0
	offset_bottom = 720.0

	add_theme_stylebox_override("panel", SURVIVORS_THEME.panel_style(Color(0.16, 0.08, 0.08, 0.84), Color(1.0, 0.54, 0.42, 0.92), 2, 10, 12.0))

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	add_child(content)

	var title := Label.new()
	title.text = "开发者选项"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	content.add_child(title)

	level_button = Button.new()
	level_button.custom_minimum_size = Vector2(220, 40)
	level_button.add_theme_font_size_override("font_size", 16)
	level_button.text = "角色等级 +1"
	SURVIVORS_THEME.apply_button_style(level_button, "primary")
	level_button.pressed.connect(_on_level_button_pressed)
	content.add_child(level_button)

	invincibility_button = Button.new()
	invincibility_button.custom_minimum_size = Vector2(220, 40)
	invincibility_button.add_theme_font_size_override("font_size", 16)
	SURVIVORS_THEME.apply_button_style(invincibility_button)
	invincibility_button.pressed.connect(_on_invincibility_button_pressed)
	content.add_child(invincibility_button)

	no_cooldown_button = Button.new()
	no_cooldown_button.custom_minimum_size = Vector2(220, 40)
	no_cooldown_button.add_theme_font_size_override("font_size", 16)
	SURVIVORS_THEME.apply_button_style(no_cooldown_button)
	no_cooldown_button.pressed.connect(_on_no_cooldown_button_pressed)
	content.add_child(no_cooldown_button)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(230.0, 400.0)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	var menu_content := VBoxContainer.new()
	menu_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_content.add_theme_constant_override("separation", 8)
	scroll.add_child(menu_content)

	boss_list = _add_menu_section(menu_content, "Boss+1")
	dangzhen_build_list = _add_menu_section(menu_content, "荡阵 Build")
	special_card_list = _add_menu_section(menu_content, "强化卡牌")

	var small_boss_title := Label.new()
	small_boss_title.text = "小 Boss 生成"
	small_boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small_boss_title.add_theme_font_size_override("font_size", 16)
	menu_content.add_child(small_boss_title)

	var small_boss_row := HBoxContainer.new()
	small_boss_row.add_theme_constant_override("separation", 6)
	menu_content.add_child(small_boss_row)

	_add_small_boss_button(small_boss_row, "A", "smallboss_glutton")
	_add_small_boss_button(small_boss_row, "B", "smallboss_rebirth")
	_add_small_boss_button(small_boss_row, "C", "smallboss_turret")

	performance_label = Label.new()
	performance_label.text = "Performance: collecting..."
	performance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	performance_label.add_theme_font_size_override("font_size", 13)
	performance_label.modulate = Color(0.8, 0.95, 1.0, 0.95)
	menu_content.add_child(performance_label)

	refresh_mode_buttons()

func refresh_mode_buttons() -> void:
	if invincibility_button != null:
		invincibility_button.text = "停用无敌模式" if DEVELOPER_MODE.is_ignore_damage_enabled() else "启用无敌模式"
	if no_cooldown_button != null:
		no_cooldown_button.text = "关闭无 CD" if DEVELOPER_MODE.is_no_cooldown_enabled() else "开启无 CD"

func set_invincibility_enabled(enabled: bool) -> void:
	DEVELOPER_MODE.set_ignore_damage_enabled(enabled)
	refresh_mode_buttons()

func set_boss_options(options: Array) -> void:
	_populate_option_list(boss_list, options, "暂无 Boss 选项", Callable(self, "_on_boss_button_pressed"))

func set_dangzhen_build_options(options: Array) -> void:
	_populate_option_list(dangzhen_build_list, options, "暂无荡阵 Build", Callable(self, "_on_card_button_pressed"))

func set_special_card_options(options: Array) -> void:
	_populate_option_list(special_card_list, options, "暂无强化卡牌", Callable(self, "_on_card_button_pressed"))

func update_performance_metrics(metrics: Dictionary) -> void:
	if performance_label != null:
		performance_label.text = PERFORMANCE_MONITOR.format_metrics(metrics)

func _on_level_button_pressed() -> void:
	level_up_requested.emit()

func _on_invincibility_button_pressed() -> void:
	DEVELOPER_MODE.set_ignore_damage_enabled(not DEVELOPER_MODE.is_ignore_damage_enabled())
	refresh_mode_buttons()

func _on_no_cooldown_button_pressed() -> void:
	DEVELOPER_MODE.set_no_cooldown_enabled(not DEVELOPER_MODE.is_no_cooldown_enabled())
	refresh_mode_buttons()

func _add_small_boss_button(parent: Control, label: String, archetype_id: String) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(68, 36)
	button.text = label
	button.tooltip_text = archetype_id
	button.add_theme_font_size_override("font_size", 15)
	SURVIVORS_THEME.apply_button_style(button)
	button.pressed.connect(_on_small_boss_button_pressed.bind(archetype_id))
	parent.add_child(button)

func _on_small_boss_button_pressed(archetype_id: String) -> void:
	small_boss_spawn_requested.emit(archetype_id)

func _add_menu_section(parent: Control, title: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 6)
	parent.add_child(section)

	var toggle_button := Button.new()
	toggle_button.custom_minimum_size = Vector2(220.0, 36.0)
	toggle_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle_button.add_theme_font_size_override("font_size", 15)
	toggle_button.text = "%s  >" % title
	SURVIVORS_THEME.apply_button_style(toggle_button)
	section.add_child(toggle_button)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	list.visible = false
	section.add_child(list)
	toggle_button.pressed.connect(_toggle_section.bind(list, toggle_button, title))
	return list

func _toggle_section(list: VBoxContainer, toggle_button: Button, title: String) -> void:
	list.visible = not list.visible
	toggle_button.text = "%s  %s" % [title, "v" if list.visible else ">"]

func _populate_option_list(list: VBoxContainer, options: Array, empty_text: String, callback: Callable) -> void:
	if list == null:
		return
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()

	for option_data in options:
		if not (option_data is Dictionary):
			continue
		var option: Dictionary = option_data
		var button := Button.new()
		button.custom_minimum_size = Vector2(220.0, 58.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 14)
		var title: String = str(option.get("title", option.get("id", "未命名卡牌")))
		var card_id: String = str(option.get("id", ""))
		var current_level: int = int(option.get("current_level", 0))
		var max_level: int = int(option.get("max_level", 1))
		var level_text := ""
		if max_level > 1:
			level_text = "  Lv.%d/%d" % [current_level, max_level]
		elif current_level > 0:
			level_text = "  已获得"
		button.text = "%s%s\n%s" % [title, level_text, card_id]
		button.tooltip_text = str(option.get("description", ""))
		button.disabled = not bool(option.get("enabled", true))
		SURVIVORS_THEME.apply_card_button_style(button, false, false, button.disabled)
		button.pressed.connect(callback.bind(card_id))
		list.add_child(button)

	if list.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = empty_text
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(empty_label)

func _on_boss_button_pressed(archetype_id: String) -> void:
	if archetype_id != "":
		boss_spawn_requested.emit(archetype_id)

func _on_card_button_pressed(card_id: String) -> void:
	if card_id != "":
		card_grant_requested.emit(card_id)
