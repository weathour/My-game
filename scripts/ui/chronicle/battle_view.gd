extends Control
const JIA_APPEARANCE := preload("res://scripts/ui/chronicle/jia_appearance.gd")
## Presents a real BattleSession. All victory/failure signals originate in the simulation.
signal completed(result: Dictionary)
signal cancelled
signal failed
signal music_duck(gain: float)
signal music_context_changed(node_id: String, form_index: int, paused: bool, outcome: String)
var _last_music_context := ""
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const BATTLE := preload("res://scripts/battle/battle_session.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const INPUT := preload("res://scripts/battle/battle_input.gd")
const HUD := preload("res://scripts/ui/chronicle/battle_hud.gd")
const CANVAS := preload("res://scripts/ui/chronicle/battle_canvas.gd")
const SETTINGS := preload("res://scripts/shared/settings.gd")
const AUDIO_SETTINGS := preload("res://scripts/ui/chronicle/audio_settings_panel.gd")
const SKILL_TOOLTIP := preload("res://scripts/ui/chronicle/battle_skill_tooltip.gd")
const SKILL_INSPECTOR := preload("res://scripts/ui/chronicle/battle_skill_inspector.gd")
const INFO := preload("res://scripts/content/skill_information.gd")
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
var pause_audio_open := false
var pause_skills_open := false
var skill_tooltip: Control
var sent := false
var message_time := 0.0

func setup(value: Dictionary, chars: Dictionary) -> void:
	request = value.duplicate(true)
	definitions = chars
	battle = BATTLE.new(value)

func _ready() -> void:
	INPUT.install()
	resized.connect(_layout_audio_settings)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("202925")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = CANVAS.new()
	canvas.battle = battle
	canvas.stage_id = request.node.id
	canvas.jia_appearance = JIA_APPEARANCE.for_battle(request)
	add_child(canvas)
	canvas.music_duck.connect(func(gain: float): music_duck.emit(gain))
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
	hud.jia_appearance = JIA_APPEARANCE.for_battle(request)
	add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hud.minimum_size_changed.connect(_layout_hud)
	_layout_hud()
	skill_tooltip = SKILL_TOOLTIP.new()
	skill_tooltip.name = "battle_skill_tooltip"
	skill_tooltip.z_index = 18
	skill_tooltip.battle = battle
	add_child(skill_tooltip)
	hud.skill_hovered.connect(skill_tooltip.show_for)
	hud.skill_unhovered.connect(skill_tooltip.leave)
	hud.layout_changed.connect(skill_tooltip.dismiss)
	refresh()

func _layout_hud() -> void:
	hud.offset_top = -hud.custom_minimum_size.y - 8
	hud.offset_bottom = -8
	feedback.offset_top = hud.offset_top - maxf(32, 24 * feedback.get_line_count() + 8)
	feedback.offset_bottom = hud.offset_top - 8
	canvas.safe_bottom = maxf(90, -hud.offset_top + 12)
	canvas.safe_top = 72
	_sync_camera_obstacles()

func _sync_camera_obstacles() -> void:
	if not is_instance_valid(canvas) or not is_instance_valid(hud) or not is_instance_valid(hud.presentation): return
	canvas.camera.hud_obstacles.clear()
	var presentation: Control = hud.presentation
	if presentation.get("band") == null or presentation.get("members") == null: return
	var band: Control = presentation.band
	if band.get_child_count() == 0 or not band.get_child(0) is Control: return
	var plate: Control = band.get_child(0)
	var plate_rect := Rect2(plate.get_global_rect().position - global_position, plate.get_global_rect().size)
	canvas.safe_bottom = maxf(90, size.y - plate_rect.position.y)
	canvas.camera.hud_obstacles.append(plate_rect)
	for member in presentation.members:
		if not member.root.visible: continue
		var portrait: Control = member.portrait
		var rect: Rect2 = portrait.get_global_rect()
		var radius: float = minf(rect.size.x, rect.size.y) * .5 * portrait.SWITCH_COOLDOWN_MASK_RADIUS_SCALE + 16
		canvas.camera.hud_obstacles.append(Rect2(rect.get_center() - global_position - Vector2.ONE * radius, Vector2.ONE * radius * 2))

func _physics_process(delta: float) -> void:
	var direction := INPUT.movement()
	battle.tick(delta, direction)
	_present_messages(battle.events)
	_publish_music_context()
	canvas.consume_events(battle.events)
	battle.events.clear()
	_sync_camera_obstacles()
	canvas.advance_presentation(delta)
	if not battle.paused:
		message_time -= delta
	canvas.refresh(direction.length_squared() > 0)
	refresh()
	if not battle.outcome.is_empty() and not sent and not canvas.victory_presentation_pending():
		sent = true
		if battle.outcome == "failed": failed.emit()
		else:
			show_result()
			completed.emit(battle.result.duplicate(true))

func _present_messages(events: Array) -> void:
	var leveled: Array[String] = []
	var rewards: Array[String] = []
	for event in events:
		if event.kind == "message": feedback.text = event.text; message_time = 2
		if event.kind == "level": leveled.append("%s  Lv.%d" % [definitions[event.id].name, event.level])
		if event.kind == "elite_defeated":
			rewards.append("精英已击败，胜利后多选 1 张卡" if event.get("reward_kind", "") == "card" else "精英已击败，胜利后获得装备奖励")
	if not rewards.is_empty(): feedback.text = "\n".join(rewards); message_time = 4
	if not leveled.is_empty():
		feedback.text = "  ·  ".join(leveled) + ("\n" + feedback.text if not rewards.is_empty() else "")
		message_time = maxf(message_time, 3)
	if not events.is_empty(): _layout_hud()

func refresh() -> void:
	var seconds := int(battle.director.elapsed)
	timing.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	feedback.visible = message_time > 0
	boss_row.visible = battle.director.boss_spawned
	boss_bar.visible = battle.director.boss_spawned
	var boss_text: String = battle.director.config.boss_name if battle.director.boss_spawned else "击破足够敌人可提前迎战首领"
	for enemy in battle.enemies:
		if enemy.rank == "boss" and enemy.hp_owner_id == enemy.id:
			boss_bar.max_value = enemy.max_hp
			boss_bar.value = enemy.hp
			if enemy.form_count > 1:
				var state_text := " · 变身中" if enemy.transition_remaining > 0 else ""
				boss_text = "%s · %s  %d/%d%s" % [battle.director.config.boss_name, "人形" if enemy.form_index == 0 else enemy.form_name, enemy.form_index + 1, enemy.form_count, state_text]
			break
	boss_label.text = boss_text
	hud.refresh()

func toggle_pause() -> void:
	if not battle.outcome.is_empty(): return
	pause_audio_open = false
	pause_skills_open = false
	skill_tooltip.dismiss()
	battle.set_paused(not battle.paused)
	_publish_music_context()
	_clear_overlay()
	if battle.paused:
		_show_pause_menu()
	refresh()

func _clear_overlay() -> void:
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
	overlay = null

func _show_pause_menu() -> void:
	var compact := size.y < 650
	var column := _modal("行军暂歇", "暂停不推进计时。离开本关会回到进关前状态。")
	var resume_button := T.button("继续战斗 · Esc", toggle_pause, true)
	resume_button.name = "battle_resume"
	if compact: T.compact_button(resume_button)
	column.add_child(resume_button)
	var skills_button := T.button(INFO.ui("skill_information"), open_skill_information)
	skills_button.name = "battle_skill_information"
	if compact: T.compact_button(skills_button)
	column.add_child(skills_button)
	var audio_button := T.button("声音设置", open_audio_settings)
	audio_button.name = "battle_audio_settings"
	if compact: T.compact_button(audio_button)
	column.add_child(audio_button)
	column.add_child(T.paragraph("WASD / 方向键移动 · Q / E 切人 · J / K 关键技能", T.MUTED, 14 if compact else 16))
	if battle.director.config.get("encounter_mode", "") == "boss_duel":
		column.add_child(T.paragraph("此战独对吕布。击败人形后迎战鬼神相，两阶段全部击破后通关。", T.MUTED, 14 if compact else 16))
	else:
		column.add_child(T.paragraph("击破%d名敌人或战斗达到%d秒时，首领出现。" % [battle.director.config.boss_kills, battle.director.config.boss_time], T.MUTED, 14 if compact else 16))
	column.add_child(T.paragraph("%d秒内击败首领可获得额外经验。" % battle.director.config.bonus_time, T.MUTED, 14 if compact else 16))
	var choice := OptionButton.new()
	choice.name = "battle_hud_layout"
	for key in SETTINGS.get_hud_layout_options(): choice.add_item(SETTINGS.get_hud_layout_label(key))
	choice.select(SETTINGS.get_hud_layout_options().find(hud.layout_key))
	choice.item_selected.connect(func(index: int):
		var key: String = SETTINGS.get_hud_layout_options()[index]
		SETTINGS.save_hud_layout(key)
		hud.set_layout(key))
	column.add_child(choice)
	var cancel_button := T.button("撤回进关前", func(): cancelled.emit())
	if compact: T.compact_button(cancel_button)
	column.add_child(cancel_button)
	resume_button.grab_focus()

func open_skill_information() -> void:
	if not battle.paused or not battle.outcome.is_empty(): return
	pause_skills_open = true
	skill_tooltip.dismiss()
	_clear_overlay()
	var inspector := SKILL_INSPECTOR.new()
	inspector.name = "battle_skill_inspector"
	inspector.z_index = 20
	inspector.battle = battle
	inspector.back_requested.connect(close_skill_information)
	inspector.resume_requested.connect(toggle_pause)
	overlay = inspector
	add_child(inspector)

func close_skill_information() -> void:
	if not pause_skills_open: return
	pause_skills_open = false
	_clear_overlay()
	if not battle.paused: return
	_show_pause_menu()
	var skills_button := overlay.find_child("battle_skill_information", true, false) as Button
	if skills_button != null: skills_button.grab_focus()

func open_audio_settings() -> void:
	if not battle.paused or not battle.outcome.is_empty(): return
	pause_audio_open = true
	_clear_overlay()
	var compact := size.y < 650
	overlay = ColorRect.new()
	overlay.name = "battle_audio_overlay"
	overlay.z_index = 20
	overlay.color = Color(0.07, 0.09, 0.07, 0.8)
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := T.panel(center, false, 16 if compact else 24)
	panel.name = "battle_audio_panel"
	panel.custom_minimum_size = _audio_panel_size()
	var column := T.column(panel)
	var header := T.row(column)
	header.add_child(T.label("声音设置", 24 if compact else 30, T.INK, true))
	T.space(header)
	var back := T.button("返回暂歇", close_audio_settings)
	back.name = "battle_audio_back"
	T.compact_button(back)
	header.add_child(back)
	column.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.name = "audio_channels_scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var audio_settings := AUDIO_SETTINGS.new()
	audio_settings.compact = compact
	scroll.add_child(audio_settings)
	column.add_child(HSeparator.new())
	var resume_button := T.button("继续战斗", toggle_pause, true)
	resume_button.name = "battle_resume"
	column.add_child(resume_button)
	back.grab_focus()

func _audio_panel_size() -> Vector2:
	return Vector2(minf(760, maxf(280, size.x - 48)), minf(680, maxf(240, size.y - 48)))

func _layout_audio_settings() -> void:
	if not pause_audio_open or not is_instance_valid(overlay): return
	var panel := overlay.find_child("battle_audio_panel", true, false) as Control
	if panel != null: panel.custom_minimum_size = _audio_panel_size()

func close_audio_settings() -> void:
	if not pause_audio_open: return
	pause_audio_open = false
	_clear_overlay()
	if not battle.paused: return
	_show_pause_menu()
	var audio_button := overlay.find_child("battle_audio_settings", true, false) as Button
	if audio_button != null: audio_button.grab_focus()

func show_result() -> void:
	var column := _modal("首领已败", "正在保存本关战果；保存失败时可重新提交。")
	var retry := T.button("重试保存战果", func(): completed.emit(battle.result.duplicate(true)), true)
	column.add_child(retry)
	retry.grab_focus()

func _modal(title: String, detail: String) -> VBoxContainer:
	var compact := size.y < 650
	overlay = ColorRect.new()
	overlay.z_index = 20
	overlay.color = Color(0.07,0.09,0.07,0.8)
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := T.panel(center, false, 16 if compact else 25)
	panel.custom_minimum_size.x = minf(460, maxf(280, size.x - 48))
	var column := T.column(panel)
	column.add_theme_constant_override("separation", 6 if compact else 10)
	column.add_child(T.label(title, 24 if compact else 30, T.INK, true))
	column.add_child(T.paragraph(detail, T.MUTED, 14 if compact else 16))
	return column

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("battle_pause"):
		if pause_skills_open: close_skill_information()
		elif pause_audio_open: close_audio_settings()
		else: toggle_pause()
	elif event.is_action_pressed("battle_previous"): battle.request_switch(-1)
	elif event.is_action_pressed("battle_next"): battle.request_switch(1)
	elif event.is_action_pressed("battle_skill_one"): battle.request_skill(0)
	elif event.is_action_pressed("battle_skill_two"): battle.request_skill(1)
	else: return
	get_viewport().set_input_as_handled()

func _publish_music_context() -> void:
	var form_index := 0
	for enemy in battle.enemies:
		if enemy.rank == "boss": form_index = maxi(form_index, int(enemy.form_index))
	var key := "%s:%d:%s:%s" % [request.node.id, form_index, battle.paused, battle.outcome]
	if key == _last_music_context: return
	_last_music_context = key
	music_context_changed.emit(str(request.node.id), form_index, bool(battle.paused), str(battle.outcome))
