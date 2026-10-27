extends Control
## Presents a real BattleSession. All victory/failure signals originate in the simulation.
signal completed(result: Dictionary)
signal cancelled
signal failed
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const BATTLE := preload("res://scripts/battle/battle_session.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const INPUT := preload("res://scripts/battle/battle_input.gd")
const HUD := preload("res://scripts/ui/chronicle/battle_hud.gd")
const CANVAS := preload("res://scripts/ui/chronicle/battle_canvas.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")
var battle: RefCounted
var request: Dictionary
var definitions: Dictionary
var canvas: Control
var timing: Label
var feedback: Label
var boss_label: Label
var boss_bar: ProgressBar
var boss_row: HBoxContainer
var hud: Control
var overlay: Control
var sent := false
var message_time := 0.0

func setup(value: Dictionary, chars: Dictionary) -> void:
	request = value.duplicate(true)
	definitions = chars
	battle = BATTLE.new(value)

func _ready() -> void:
	INPUT.install()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("202925")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = CANVAS.new()
	canvas.battle = battle
	canvas.stage_id = request.node.id
	add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout := VBoxContainer.new()
	layout.z_index = 10
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	layout.add_theme_constant_override("separation", 0)
	var top := T.column(T.panel(layout, true, 6))
	top.add_theme_constant_override("separation", 3)
	var title_row := T.row(top)
	title_row.add_child(T.label(request.node.name, 22, T.LIGHT, true))
	timing = T.label("", 14, T.LIGHT)
	timing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(timing)
	var pause_button := T.button("Esc 暂停", toggle_pause)
	title_row.add_child(pause_button)
	T.compact_button(pause_button)
	boss_row = T.row(top)
	boss_label = T.label("荒道未静", 14, Color("c4cbb5"))
	boss_row.add_child(boss_label)
	boss_bar = T.bar(boss_row, 0, 100, T.RED)
	boss_bar.custom_minimum_size = Vector2(150, 8)
	boss_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feedback = T.label("", 15, T.LIGHT)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.add_theme_color_override("font_shadow_color", Color.BLACK)
	feedback.add_theme_constant_override("shadow_offset_x", 1)
	feedback.add_theme_constant_override("shadow_offset_y", 1)
	canvas.add_child(feedback)
	feedback.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	feedback.offset_top = -32
	feedback.offset_bottom = -8
	hud = HUD.new()
	hud.z_index = 10
	hud.battle = battle
	hud.definitions = definitions
	add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hud.minimum_size_changed.connect(_layout_hud)
	_layout_hud()
	refresh()

func _layout_hud() -> void:
	hud.offset_top = -hud.custom_minimum_size.y - 8
	hud.offset_bottom = -8
	feedback.offset_top = hud.offset_top - 32
	feedback.offset_bottom = hud.offset_top - 8

func _physics_process(delta: float) -> void:
	var direction := INPUT.movement()
	battle.tick(delta, direction)
	for event in battle.events:
		if event.kind == "message": feedback.text = event.text; message_time = 2
		if event.kind == "level": feedback.text = "%s  Lv.%d" % [definitions[event.id].name, event.level]; message_time = 3
	battle.events.clear()
	if not battle.paused:
		message_time -= delta
	canvas.refresh(direction.length_squared() > 0)
	refresh()
	if not battle.outcome.is_empty() and not sent:
		sent = true
		if battle.outcome == "failed": failed.emit()
		else:
			show_result()
			completed.emit(battle.result.duplicate(true))

func refresh() -> void:
	var seconds := int(battle.director.elapsed)
	timing.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	feedback.visible = message_time > 0
	boss_row.visible = battle.director.boss_spawned
	boss_bar.visible = battle.director.boss_spawned
	boss_label.text = battle.director.config.boss_name if battle.director.boss_spawned else "击破足够敌人可提前迎战首领"
	for enemy in battle.enemies:
		if enemy.kind == "boss": boss_bar.max_value = enemy.max_hp; boss_bar.value = enemy.hp
	hud.refresh()

func toggle_pause() -> void:
	if not battle.outcome.is_empty(): return
	battle.set_paused(not battle.paused)
	if is_instance_valid(overlay): overlay.queue_free(); overlay = null
	if battle.paused:
		var column := _modal("行军暂歇", "暂停不推进计时。离开本关会回到进关前状态。")
		var resume_button := T.button("继续战斗 · Esc", toggle_pause, true)
		column.add_child(resume_button)
		column.add_child(T.paragraph("WASD / 方向键移动 · Q / E 切人 · J / K 关键技能"))
		column.add_child(T.paragraph("击破%d名敌人或战斗达到%d秒时，首领出现。" % [battle.director.config.boss_kills, battle.director.config.boss_time]))
		column.add_child(T.paragraph("%d秒内击败首领可获得额外经验。" % battle.director.config.bonus_time))
		var choice := OptionButton.new()
		choice.name = "battle_hud_layout"
		for key in SETTINGS.get_hud_layout_options(): choice.add_item(SETTINGS.get_hud_layout_label(key))
		choice.select(SETTINGS.get_hud_layout_options().find(hud.layout_key))
		choice.item_selected.connect(func(index: int):
			var key: String = SETTINGS.get_hud_layout_options()[index]
			SETTINGS.save_hud_layout(key)
			hud.set_layout(key))
		column.add_child(choice)
		column.add_child(T.button("撤回进关前", func(): cancelled.emit()))
		resume_button.grab_focus()
	refresh()

func show_result() -> void:
	var column := _modal("首领已败", "正在保存本关战果；保存失败时可重新提交。")
	var retry := T.button("重试保存战果", func(): completed.emit(battle.result.duplicate(true)), true)
	column.add_child(retry)
	retry.grab_focus()

func _modal(title: String, detail: String) -> VBoxContainer:
	overlay = ColorRect.new()
	overlay.z_index = 20
	overlay.color = Color(0.07,0.09,0.07,0.8)
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := T.column(T.panel(center, false, 25))
	column.add_child(T.label(title, 30, T.INK, true))
	column.add_child(T.paragraph(detail))
	return column

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("battle_pause"): toggle_pause()
	elif event.is_action_pressed("battle_previous"): battle.request_switch(-1)
	elif event.is_action_pressed("battle_next"): battle.request_switch(1)
	elif event.is_action_pressed("battle_skill_one"): battle.request_skill(0)
	elif event.is_action_pressed("battle_skill_two"): battle.request_skill(1)
	else: return
	get_viewport().set_input_as_handled()
