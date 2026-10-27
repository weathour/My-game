extends Control
## Keyboard-only HUD rehearsal. This does not instantiate enemies or award combat XP.
signal completed(result: Dictionary)
signal cancelled
signal failed
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const TERRAIN := preload("res://assets/ui/chronicle/baimen-terrain.png")
const FIELDS := ["补给\n恢复生命与魔法", "修习\n当前人物经验", "挑战\n额外选卡精英", "寻宝\n装备精英"]

var request: Dictionary
var definitions: Dictionary
var records: Dictionary
var members: Array
var active := 0
var switch_cooldown := 0.0
var elapsed := 0.0
var kills := 0
var boss_present := false
var field := -1
var elite_defeated := false
var actor := Vector2.ZERO
var paused := false
var pause_layer: Control
var actor_label: Label
var timing: Label
var switch_label: Label
var field_label: Label
var feedback: Label
var hp_bars: Array[ProgressBar] = []
var mp_bars: Array[ProgressBar] = []
var member_labels: Array[Label] = []
var skills: Array[Button] = []
var field_buttons: Array[Button] = []
var party_band: HBoxContainer
var skill_band: HBoxContainer

func setup(value: Dictionary, chars: Dictionary) -> void:
	request = value.duplicate(true)
	definitions = chars
	records = request.characters.duplicate(true)
	members = request.members.duplicate()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := TextureRect.new()
	background.texture = TERRAIN
	background.show_behind_parent = true
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color("4e5b50")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top := T.panel(self, true, 14)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var row := T.row(top)
	row.add_child(T.label(request.node.name, 25, T.LIGHT, true))
	timing = T.label("", 16, T.LIGHT)
	timing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(timing)
	row.add_child(T.label("战斗 HUD 演练 · 无敌人模拟", 13, Color("c4cbb6")))
	var pause_button := T.button("Esc 暂停", toggle_pause)
	row.add_child(pause_button)
	for index in 4:
		var button := T.button(FIELDS[index], func(): pass)
		button.disabled = true
		button.custom_minimum_size = Vector2(190, 62)
		button.add_theme_font_size_override("font_size", 15)
		add_child(button)
		field_buttons.append(button)
	actor_label = T.label("", 21, T.LIGHT, true)
	add_child(actor_label)
	feedback = T.label("走近四角场域即可选择；也可以全部绕开。", 16, T.LIGHT)
	add_child(feedback)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	field_label = T.label("四处场域 · 尚未选择", 15, Color("e1d7b7"))
	add_child(field_label)
	var bottom := T.panel(self, true, 15)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -133
	var column := T.column(bottom)
	party_band = T.row(column)
	for id in members:
		var member := T.column(party_band)
		member.custom_minimum_size.x = 180
		var label := T.label("", 16, T.LIGHT)
		member.add_child(label)
		member_labels.append(label)
		hp_bars.append(T.bar(member, records[id].hp, 100, T.RED))
		mp_bars.append(T.bar(member, records[id].mp, 100, T.BLUE))
	T.space(party_band)
	skill_band = T.row(party_band)
	for i in 2:
		var index := i
		var skill := T.button("", func(): use_skill(index))
		skill.custom_minimum_size = Vector2(160, 64)
		skill.add_theme_font_size_override("font_size", 15)
		skill_band.add_child(skill)
		skills.append(skill)
	switch_label = T.label("", 14, Color("bec6b1"))
	column.add_child(switch_label)
	resized.connect(fit)
	fit.call_deferred()
	update_hud()

func fit() -> void:
	actor = size * Vector2(.5,.48)
	for i in 4:
		field_buttons[i].position = field_position(i) - Vector2(95, 31)
	feedback.position = Vector2(0, size.y * .62)
	feedback.size.x = size.x
	field_label.position = Vector2(24, size.y - 160)
	queue_redraw()

func field_position(index: int) -> Vector2:
	return Vector2(130 if index % 2 == 0 else size.x - 130, 135 if index < 2 else size.y - 215)

func _process(delta: float) -> void:
	if paused: return
	elapsed += delta
	if elapsed >= 90 or kills >= 60: boss_present = true
	switch_cooldown = maxf(0, switch_cooldown - delta)
	for id in members:
		if records[id].dead: continue
		records[id].mp = minf(100, records[id].mp + delta * 2)
		for i in 2: records[id].cooldowns[i] = maxf(0, records[id].cooldowns[i] - delta)
	var direction := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	actor += direction.normalized() * 210 * delta
	actor = actor.clamp(Vector2(60, 95), Vector2(size.x - 60, size.y - 180))
	if field == -1:
		for index in 4:
			if actor.distance_to(field_position(index)) < 65: choose_field(index)
	actor_label.position = actor + Vector2(-55, 28)
	update_hud()
	queue_redraw()

func _draw() -> void:
	draw_circle(actor, 20, Color("d8d6b6"))
	draw_circle(actor, 15, T.OLIVE)
	draw_arc(actor, 25, 0, TAU, 40, Color("f1e8c9"), 2, true)
	for i in 4:
		if field == -1 or field == i: draw_arc(field_position(i), 66, 0, TAU, 48, Color("aebd89"), 1, true)

func choose_field(index: int) -> void:
	if field != -1 or index < 0 or index > 3: return
	field = index
	if index == 0:
		records[members[active]].hp = 100
		records[members[active]].mp = 100
	feedback.text = ["补给已使用。", "已选择修习场域。", "额外选卡精英出现，击败后多选一张。", "装备精英出现，击败后获得装备。"][index]
	for i in 4:
		field_buttons[i].text = "已选 · " + FIELDS[i] if i == field else "已失效"
	field_label.text = "已选择 " + FIELDS[index].split("\n")[0] + " · 其余三处失效"

func switch_actor(direction: int) -> void:
	if paused or switch_cooldown > 0: return
	for offset in range(1, members.size() + 1):
		var index := posmod(active + direction * offset, members.size())
		if index != active and not records[members[index]].dead:
			active = index
			switch_cooldown = .6
			update_hud()
			return

func use_skill(index: int) -> void:
	if paused or index >= definitions[members[active]].skills.size(): return
	var record: Dictionary = records[members[active]]
	var cost := 25 if index == 0 else 40
	if record.cooldowns[index] > 0 or record.mp < cost: return
	record.mp -= cost
	record.cooldowns[index] = 4.0 if index == 0 else 8.0
	feedback.text = "%s · %s" % [definitions[members[active]].name, definitions[members[active]].skills[index]]
	update_hud()

func update_hud() -> void:
	timing.text = "首领已出现 · 普通刷怪停止" if boss_present else "首领 %02d:%02d / 01:30  ·  击破 %d / 60" % [int(elapsed) / 60, int(elapsed) % 60, kills]
	actor_label.text = definitions[members[active]].name
	for index in members.size():
		var id: String = members[index]
		var record: Dictionary = records[id]
		member_labels[index].text = "%s%s  %d / %d" % ["▶ " if index == active else "", definitions[id].name, record.hp, record.mp]
		if record.dead: member_labels[index].text = definitions[id].name + " · 阵亡"
		hp_bars[index].value = record.hp
		mp_bars[index].value = record.mp
	for index in 2:
		var character: Dictionary = definitions[members[active]]
		var record: Dictionary = records[members[active]]
		if index >= character.skills.size():
			skills[index].text = "无第二关键技能"
			skills[index].disabled = true
			continue
		var cost := 25 if index == 0 else 40
		var availability := "%d 魔法" % cost
		if record.cooldowns[index] > 0: availability = "冷却 %.1f 秒" % record.cooldowns[index]
		elif record.mp < cost: availability = "魔法不足 · 需要 %d" % cost
		skills[index].text = "%s  %s\n%s" % ["J" if index == 0 else "K", character.skills[index], availability]
		skills[index].disabled = record.mp < cost or record.cooldowns[index] > 0
	switch_label.text = "WASD / 方向键 移动    Q / E 切换    J / K 关键技能    普攻、常规技能与朝向自动"
	if switch_cooldown > 0: switch_label.text += "    切换 %.1fs" % switch_cooldown

func toggle_pause() -> void:
	paused = not paused
	if not paused:
		if is_instance_valid(pause_layer): pause_layer.queue_free()
		return
	pause_layer = ColorRect.new()
	pause_layer.color = Color(0.05, .07, .05, .82)
	add_child(pause_layer)
	pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	pause_layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := T.panel(center)
	panel.custom_minimum_size.x = 480
	var column := T.column(panel)
	column.add_child(T.label("暂停 · 界面演练", 28, T.INK, true))
	column.add_child(T.paragraph("下列结果用于检查界面状态，不代表实际战斗胜负。"))
	var resume_button := T.button("继续演练  Esc", toggle_pause)
	column.add_child(resume_button)
	column.add_child(T.button("演练：击破数达到首领门槛", func(): kills = 60; boss_present = true; toggle_pause()))
	column.add_child(T.button("演练：当前人物承伤 40", func(): apply_preview_damage(40)))
	if field >= 2:
		var elite := CheckButton.new()
		elite.text = "演练：额外精英已击败"
		elite.button_pressed = elite_defeated
		elite.toggled.connect(func(value: bool): elite_defeated = value)
		column.add_child(elite)
	column.add_child(T.button("演练：击败首领，查看结算", func():
		completed.emit({"characters":records, "card_elite":field == 2 and elite_defeated,
			"equipment_elite":field == 3 and elite_defeated}), true))
	column.add_child(T.button("结束演练 · 回到进关前", func(): cancelled.emit()))
	var buttons := column.find_children("*", "Button", true, false)
	for i in buttons.size():
		buttons[i].focus_next = buttons[(i + 1) % buttons.size()].get_path()
		buttons[i].focus_previous = buttons[posmod(i - 1, buttons.size())].get_path()
	resume_button.grab_focus.call_deferred()

func apply_preview_damage(amount: float) -> void:
	records[members[active]].hp = maxf(0, records[members[active]].hp - amount)
	if records[members[active]].hp <= 0:
		records[members[active]].dead = true
		if active == 0:
			failed.emit()
			return
		active = 0
	if paused: toggle_pause()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_ESCAPE: toggle_pause()
		KEY_Q: switch_actor(-1)
		KEY_E: switch_actor(1)
		KEY_J: use_skill(0)
		KEY_K: use_skill(1)
		_: return
	get_viewport().set_input_as_handled()
