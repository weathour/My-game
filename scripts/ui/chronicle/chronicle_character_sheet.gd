extends Control
const JIA_APPEARANCE := preload("res://scripts/ui/chronicle/jia_appearance.gd")
## Read-only character sheet; shell owns its context, lifetime and opener restoration.
signal closed
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const DETAILS := preload("res://scripts/ui/chronicle/character_detail_projection.gd")
const CARD := preload("res://scripts/ui/chronicle/chronicle_card.gd")
const ART := preload("res://scripts/ui/chronicle/chronicle_portraits.gd")
const PROFILES := preload("res://scripts/content/character_profiles.gd")
const SETTINGS := preload("res://scripts/shared/settings.gd")
const SUMMARY := preload("res://scripts/campaign/party_summary.gd")
const COPY_PATH := "res://assets/data/chronicle/skill_presentation_copy.json"
const INFO := preload("res://scripts/content/skill_information.gd")
var state: RefCounted
var character_id := "JIA"
var appearance_context := ""
var active_tab := "abilities"
var return_label := "关闭"
var model: Dictionary = {}
var profile: Dictionary = {}
var panel: PanelContainer
var portrait: TextureRect
var title: Label
var identity: Label
var resources: Label
var level_status: Label
var scroll: ScrollContainer
var content: VBoxContainer
var art_column: VBoxContainer
var tabs: Dictionary = {}
var scroll_positions := {"abilities":0,"growth":0,"profile":0}
var _closing := false
var _transition: Tween
var _revision := 0
var presentation_copy: Dictionary = {}
var expanded_details: Dictionary = {}

class AttributeTable:
	extends GridContainer
	func _ready() -> void:
		sort_children.connect(queue_redraw)
		resized.connect(queue_redraw)
	func _draw() -> void:
		if get_child_count() < columns: return
		for index in range(0,get_child_count(),columns):
			var cell := get_child(index) as Control
			var y := cell.position.y + cell.size.y + 3
			draw_line(Vector2(0,y),Vector2(size.x,y),Color(.75,.66,.45,.25 if index == 0 else .09),1)

func setup(value: RefCounted, id: String, tab: String = "abilities", label: String = "关闭", appearance: String = "") -> void:
	state = value
	character_id = id
	active_tab = _tab_key(tab)
	return_label = label
	appearance_context = JIA_APPEARANCE.normalize_appearance(appearance) if not appearance.is_empty() else ""

func show_character(id: String, tab: String = "abilities") -> void:
	if state == null or not state.characters.has(id): return
	_save_scroll()
	if character_id != id:
		scroll_positions = {"abilities":0,"growth":0,"profile":0}
		expanded_details.clear()
	character_id = id
	active_tab = _tab_key(tab)
	if is_inside_tree(): _refresh()

static func _tab_key(value: String) -> String:
	return "growth" if value in ["growth","stats"] else value if value in ["abilities","profile"] else "abilities"

func _ready() -> void:
	var copy = JSON.parse_string(FileAccess.get_file_as_string(COPY_PATH))
	if copy is Dictionary: presentation_copy = copy
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color("08110dd1")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.mouse_force_pass_scroll_events = false
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.name = "character_sheet_panel"
	panel.add_theme_stylebox_override("panel", T.box(Color("182a21"), Color("8c7955"), 18))
	panel.mouse_force_pass_scroll_events = false
	add_child(panel)
	T.FONT.apply_campaign_frame(panel,"panel")
	var row := T.row(panel)
	row.add_theme_constant_override("separation", 24)
	art_column = T.column(row)
	art_column.size_flags_horizontal = Control.SIZE_FILL
	portrait = TextureRect.new()
	portrait.name = "CharacterStanding"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_column.add_child(portrait)
	level_status = T.paragraph("",T.GOLD,14)
	level_status.name = "character_sheet_status"
	level_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_column.add_child(level_status)
	var column := T.column(row)
	column.name = "character_detail_panel"
	column.add_theme_constant_override("separation", 9)
	var heading := T.row(column)
	title = T.label("",30,T.LIGHT,true)
	title.name = "CharacterName"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close := T.quiet_button(return_label,_close)
	close.name = "character_back"
	heading.add_child(close)
	identity = T.paragraph("",T.GOLD,14)
	identity.name = "CharacterTitle"
	column.add_child(identity)
	resources = T.paragraph("",T.INK,14)
	resources.name = "character_current_resources"
	column.add_child(resources)
	var tab_row := T.row(column)
	tab_row.add_theme_constant_override("separation", 5)
	for key in ["abilities","growth","profile"]:
		var tab: String = key
		var button := T.quiet_button(str({"abilities":"能力","growth":"属性·成长","profile":"人物"}[key]),func(): select_tab(tab))
		button.name = "character_stats" if key == "growth" else "character_tab_" + key
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_row.add_child(button)
		tabs[key] = button
	scroll = ScrollContainer.new()
	scroll.name = "character_detail_scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.mouse_force_pass_scroll_events = false
	column.add_child(scroll)
	content = T.column(scroll)
	content.add_theme_constant_override("separation", 10)
	resized.connect(_layout)
	_layout()
	_refresh()
	(tabs[active_tab] as Button).grab_focus()
	if not SETTINGS.comfort_enabled("reduced_motion"):
		panel.modulate.a = 0
		_transition = create_tween()
		_transition.tween_property(panel,"modulate:a",1.0,.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _layout() -> void:
	if panel == null: return
	_save_scroll()
	var target := Vector2(minf(1320,maxf(896,size.x - 160)),minf(880,maxf(488,size.y - 96)))
	target = target.min(size - Vector2(32,32))
	panel.position = (size - target) * .5
	panel.size = target
	art_column.custom_minimum_size.x = target.x * .265
	var table := find_child("character_attribute_table",true,false) as GridContainer
	if table != null: table.add_theme_constant_override("v_separation",4 if target.y < 560 else 11)

func _refresh() -> void:
	_revision += 1
	model = DETAILS.build(state.data,state.characters,character_id)
	profile = PROFILES.find(character_id)
	var person: Dictionary = state.characters[character_id]
	title.text = str(person.name)
	identity.text = _identity_text(person,profile)
	portrait.texture = ART.standing(character_id, appearance_context if not appearance_context.is_empty() else JIA_APPEARANCE.for_campaign(state.data))
	level_status.name = "character_sheet_status" if model.owned else "character_preview"
	if model.owned:
		resources.text = "Lv.%d   生命 %s / %s   魔法 %s / %s%s" % [model.level,_number(model.resources.hp),_number(model.resources.max_hp),_number(model.resources.mp),_number(model.resources.max_mp)," · 阵亡" if model.dead else ""]
		level_status.text = "阵亡" if model.dead else "已配置" if model.configured else "主角" if character_id == "JIA" else "未上阵"
	else:
		resources.text = "生命上限 %s   魔法上限 %s" % [_number(model.stats.hp),_number(model.stats.mp)]
		level_status.text = "能力预览 · 入手等级 Lv.%d" % model.level
		level_status.name = "character_preview"
	for key in tabs:
		var selected: bool = key == active_tab
		var style := T.box(Color("3e4230") if selected else Color.TRANSPARENT,T.GOLD if selected else Color.TRANSPARENT,9)
		style.set_border_width_all(0)
		if selected: style.border_width_bottom = 2
		(tabs[key] as Button).add_theme_stylebox_override("normal",style)
	for child in content.get_children(): content.remove_child(child);child.queue_free()
	if active_tab == "growth": _build_stats()
	elif active_tab == "profile": _build_profile()
	else: _build_abilities()
	_restore_scroll.call_deferred(active_tab,_revision,int(scroll_positions.get(active_tab,0)))
	_sync_focus()

func _restore_scroll(tab: String, revision: int, position: int) -> void:
	if not is_inside_tree(): return
	var tree := get_tree()
	await tree.process_frame
	if not is_inside_tree(): return
	await tree.process_frame
	if _closing or not is_inside_tree() or revision != _revision or tab != active_tab: return
	scroll.scroll_vertical = position

func select_tab(tab: String) -> void:
	_save_scroll()
	active_tab = _tab_key(tab)
	_refresh()
	(tabs[active_tab] as Button).grab_focus()

func _save_scroll() -> void:
	if scroll != null: scroll_positions[active_tab] = scroll.scroll_vertical

func _section(value: String) -> void:
	content.add_child(T.label(value,18,T.GOLD,true))

func _words(value: String, node_name: String, color: Color = T.LIGHT, font_size: int = 14) -> Label:
	var label := T.paragraph(value,color,font_size)
	label.name = node_name
	label.add_theme_constant_override("line_spacing",4)
	content.add_child(label)
	return label

func _ability(ability: Dictionary, information: Dictionary, category: String, key: String) -> void:
	if ability.is_empty(): return
	var unlocked: bool = ability.unlocked
	var block := T.column(content)
	block.name = "character_ability_block_" + key
	block.add_theme_constant_override("separation", 5)
	var heading := category if key == "basic" and str(ability.title) == "普攻" else category + " · " + str(ability.title)
	var heading_row := T.row(block)
	heading_row.name = "character_ability_heading_" + key
	var heading_label := T.paragraph(heading,T.LIGHT if unlocked else T.MUTED,16)
	heading_label.name = "character_ability_" + key
	heading_row.add_child(heading_label)
	var status := "入手尚未解锁" if model.preview else "当前等级不足"
	var state_line := T.label(status,12,T.MUTED)
	state_line.name = "character_ability_meta_" + key
	state_line.visible = not unlocked
	state_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading_row.add_child(state_line)
	_information(block,information,key,T.LIGHT if unlocked else T.MUTED,heading_row)

func _information(parent: VBoxContainer, information: Dictionary, key: String, color: Color = T.LIGHT, actions: HBoxContainer = null) -> void:
	var summary := T.paragraph(str(information.get("summary", "")),color,14)
	summary.name = "character_ability_description_" + key
	summary.add_theme_constant_override("line_spacing",3)
	parent.add_child(summary)
	var trigger := str(information.get("trigger", ""))
	if not trigger.is_empty():
		var trigger_label := T.paragraph(trigger,T.INK,12)
		trigger_label.name = "character_ability_trigger_" + key
		trigger_label.visible = key in ["support","trait"]
		parent.add_child(trigger_label)
	var conditions: Array = information.get("conditions", [])
	if not conditions.is_empty():
		var condition := T.paragraph("\n".join(conditions),T.INK,12)
		condition.name = "character_ability_conditions_" + key
		parent.add_child(condition)
	var facts: Array = information.get("facts", [])
	if not facts.is_empty():
		var numbers := T.paragraph(" · ".join(facts),T.GOLD,12)
		numbers.name = "character_ability_facts_" + key
		parent.add_child(numbers)
	var details: Array = information.get("details", [])
	if details.is_empty(): return
	var toggle := T.quiet_button(_ui("expand_details","展开细节"),func(): pass)
	toggle.name = "character_ability_expand_" + key
	toggle.toggle_mode = true
	var initially_expanded: bool = bool(expanded_details.get(key,false))
	toggle.set_pressed_no_signal(initially_expanded)
	if initially_expanded: toggle.text = _ui("collapse_details","收起细节")
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	T.compact_button(toggle)
	if actions != null: actions.add_child(toggle)
	else: parent.add_child(toggle)
	var detail_body := T.column(parent)
	detail_body.name = "character_ability_details_" + key
	detail_body.visible = initially_expanded
	detail_body.focus_mode = Control.FOCUS_ALL
	detail_body.set_meta("character_detail_focus",true)
	detail_body.add_theme_constant_override("separation",5)
	for index in details.size():
		var line := T.paragraph(str(details[index]),T.INK,13)
		line.name = "character_ability_detail_%s_%d" % [key,index]
		line.add_theme_constant_override("line_spacing",3)
		detail_body.add_child(line)
	toggle.toggled.connect(func(expanded: bool):
		expanded_details[key] = expanded
		detail_body.visible = expanded
		toggle.text = _ui("collapse_details","收起细节") if expanded else _ui("expand_details","展开细节")
		_sync_focus()
	)

func _build_abilities() -> void:
	_words(str(model.overview),"character_playstyle_summary",T.LIGHT,15)
	_tags(content,model.tags,"character_playstyle_tags")
	_section(_ui("foreground","出场作战"))
	_ability(model.basic,model.basic_info,"自动普攻", "basic")
	for index in model.automatic.size(): _ability(model.automatic[index],model.automatic_info[index],"常规自动","automatic_%d" % index)
	for index in model.manual.size(): _ability(model.manual[index],model.manual_info[index],"J" if index == 0 else "K","manual_%d" % index)
	if model.manual.size() < 2: _words("K · " + _ui("not_equipped","未配备"),"character_ability_manual_1",T.MUTED,14)
	if not model.trait_info.is_empty():
		_section(_ui("mechanics","额外机制"))
		var trait_block := T.column(content)
		trait_block.name = "character_trait_block"
		trait_block.add_theme_constant_override("separation",5)
		_information(trait_block,model.trait_info,"trait")
	_section(_ui("background_and_owned","后台与持有"))
	_words("后台支援","character_support_heading",T.GOLD,15)
	_words(str(model.support_state),"character_support_state",T.GOLD,12)
	if not model.support.is_empty(): _ability(model.support,model.support_info,"后台支援","support")
	_words("持有加成","character_owned_heading",T.GOLD,15)
	_words(str(model.owned_text),"character_owned_summary")
	_build_owned_rows()

static func _ui(key: String, fallback: String) -> String:
	return str(INFO.ui(key, fallback))

static func _tags(parent: Node, values: Array, node_name: String) -> void:
	if values.is_empty(): return
	var tags := HFlowContainer.new()
	tags.name = node_name
	tags.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tags.add_theme_constant_override("h_separation",6)
	tags.add_theme_constant_override("v_separation",4)
	parent.add_child(tags)
	for index in values.size():
		var tag := T.label(str(values[index]),12,T.GOLD)
		tag.name = node_name + "_" + str(index)
		tag.add_theme_stylebox_override("normal",T.box(Color("26382b"),Color.TRANSPARENT,5))
		tags.add_child(tag)

func _build_owned_rows() -> void:
	var words: Dictionary = presentation_copy.get("owned_bonus", {})
	for index in model.owned_rows.size():
		var bonus: Dictionary = model.owned_rows[index]
		var block := T.column(T.panel(content, true, 10, false))
		block.name = "character_owned_bonus_" + str(bonus.key)
		block.add_theme_constant_override("separation", 5)
		block.add_child(T.label(str(bonus.title),15,T.GOLD,true))
		var source := T.paragraph("%s · Lv.%d  %s" % [words.get("card_raw", ""), bonus.level, SUMMARY.amount_text(bonus.key, bonus.card_raw)],T.LIGHT,13)
		source.name = "character_owned_source_%d" % index
		source.tooltip_text = str(model.owned_lines[index])
		block.add_child(source)
		var total := T.paragraph("%s  %s / %s" % [words.get("global_actual_cap", ""), SUMMARY.amount_text(bonus.key, bonus.actual), SUMMARY.amount_text(bonus.key, bonus.cap)],T.MUTED,12)
		total.name = "character_owned_total_" + str(bonus.key)
		block.add_child(total)
		var bar := T.bar(block, float(bonus.actual), float(bonus.cap), T.GOLD if bonus.capped else T.OLIVE.lightened(.30))
		bar.step = .000001
		bar.max_value = float(bonus.cap)
		bar.value = float(bonus.actual)
		bar.name = "character_owned_cap_" + str(bonus.key)
		bar.custom_minimum_size.y = 5
		var key := "next_effective_delta" if bonus.owned else "next_preview_delta"
		var next := T.paragraph("%s  %s" % [words.get(key, ""), SUMMARY.amount_text(bonus.key, bonus.next_delta)],T.MUTED if is_zero_approx(bonus.next_delta) else T.LIGHT,12)
		next.name = "character_owned_next_" + str(bonus.key)
		block.add_child(next)
		if bonus.capped: block.add_child(T.paragraph(str(words.get("global_capped", "")),T.GOLD,12))
		if not bonus.owned: block.add_child(T.paragraph(str(words.get("preview_not_owned", "")),T.MUTED,12))

func _build_stats() -> void:
	var experience := T.row(content)
	var xp_text := "经验 %s / %s" % [_number(model.experience.value),_number(model.experience.required)] if model.experience.available else "经验 —"
	var xp := T.label(xp_text,14,T.GOLD);xp.name = "character_experience";experience.add_child(xp)
	if model.experience.available:
		var bar := T.bar(experience,float(model.experience.value),float(model.experience.required),T.GOLD)
		bar.name = "character_experience_bar"
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var next_text := "下次解锁：Lv.%d · %s" % [model.next_unlock.level,model.next_unlock.title] if not model.next_unlock.is_empty() else "无待解锁技能"
	_words(next_text,"character_next_unlock",T.INK,14)
	var table := AttributeTable.new()
	table.name = "character_attribute_table"
	table.columns = 6
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.add_theme_constant_override("h_separation",8)
	table.add_theme_constant_override("v_separation",4 if panel.size.y < 560 else 11)
	content.add_child(table)
	for caption in ["属性","当前","Lv.1基础","累计成长","持有","行装"]:
		var label := T.label(caption,12,T.MUTED)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		table.add_child(label)
	for row in model.attribute_rows:
		var values := [row.title,_number(row.current),_number(row.base),DETAILS.signed(row.growth),DETAILS.signed(row.owned),DETAILS.signed(row.equipment)]
		var keys := ["title","current","base","growth","owned","equipment"]
		for index in values.size():
			var label := T.label(str(values[index]),14,T.GOLD if index == 1 else T.LIGHT)
			label.name = "character_stat_%s_%s" % [row.key,keys[index]]
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			table.add_child(label)
	_words("持有栏显示全队封顶后的加成；行装栏显示当前共享行装带来的属性变化。","character_stat_note",T.MUTED,12)
	if model.preview: _words("预览已应用当前持有加成与行装；该人物尚未计入持有总额。","character_preview_note",T.MUTED,12)

func _build_profile() -> void:
	_words("“%s”" % str(profile.get("quote","")),"CharacterQuote",T.GOLD,18)
	_words(str(profile.get("biography","")),"CharacterBiography",T.LIGHT,15)
	_section("获取条件")
	_words(str(model.gate),"character_acquisition",T.MUTED)
	_section("同行关系")
	_words(str(profile.get("relationship","")),"CharacterRelationship",T.MUTED,14)

static func _identity_text(person: Dictionary, authored: Dictionary) -> String:
	var rarity: String = CARD.RARITY.style(person.get("rarity","common")).label
	var role := str(authored.get("title",person.get("title",person.get("role",""))))
	return rarity if role.is_empty() or role == rarity else rarity + " · " + role

static func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value,roundf(value)) else String.num(value,3)

func _sync_focus() -> void:
	var controls: Array[Control] = []
	for button in find_children("*","BaseButton",true,false):
		if content.is_ancestor_of(button): continue
		if button is Control and button.is_visible_in_tree() and not button.disabled: controls.append(button)
	controls.append(scroll)
	for control in content.find_children("*","Control",true,false):
		if not control.is_visible_in_tree(): continue
		if control is BaseButton and not control.disabled: controls.append(control)
		elif control.has_meta("character_detail_focus"): controls.append(control)
	for index in controls.size():
		var button: Control = controls[index]
		button.focus_previous = button.get_path_to(controls[posmod(index - 1,controls.size())])
		button.focus_next = button.get_path_to(controls[(index + 1) % controls.size()])
		button.focus_neighbor_left = button.focus_previous;button.focus_neighbor_top = button.focus_previous
		button.focus_neighbor_right = button.focus_next;button.focus_neighbor_bottom = button.focus_next

func _close() -> void:
	get_viewport().set_input_as_handled()
	if _closing: return
	_closing = true
	closed.emit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE: _close();return
		var focus := get_viewport().gui_get_focus_owner()
		if focus == null or not is_ancestor_of(focus): (tabs[active_tab] as Button).grab_focus()
		if event.keycode in [KEY_PAGEDOWN,KEY_PAGEUP,KEY_HOME,KEY_END]:
			var bar := scroll.get_v_scroll_bar()
			if event.keycode == KEY_HOME: scroll.scroll_vertical = 0
			elif event.keycode == KEY_END: scroll.scroll_vertical = int(bar.max_value)
			else: scroll.scroll_vertical += int(scroll.size.y * .85) * (1 if event.keycode == KEY_PAGEDOWN else -1)
			get_viewport().set_input_as_handled()

func _unhandled_key_input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()

static func build_preview(shell: Control, parent: Node) -> void:
	var id: String = shell.selected_character
	var value := DETAILS.build(shell.session.data,shell.session.characters,id)
	var person: Dictionary = shell.session.characters[id]
	var profile := PROFILES.find(id)
	var panel := T.panel(parent,false,12)
	panel.name = "character_preview_panel"
	panel.custom_minimum_size.x = 320
	panel.size_flags_horizontal = Control.SIZE_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := T.column(panel)
	column.add_theme_constant_override("separation",5)
	var heading := T.row(column)
	heading.name = "character_preview_heading"
	var name_label := T.label(str(person.name),24,T.LIGHT,true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.name = "character_preview_name";heading.add_child(name_label)
	var details := T.quiet_button("详情",func(): shell.inspect_character(id,"abilities"))
	details.name = "character_preview_expand";heading.add_child(details)
	var title_label := T.paragraph(_identity_text(person,profile),T.GOLD,13)
	title_label.name = "character_preview_title";column.add_child(title_label)
	column.add_child(T.label("Lv.%d" % value.level if value.owned else "能力预览 · 入手等级 Lv.%d" % value.level,12,T.MUTED))
	var middle := ScrollContainer.new()
	middle.name = "character_preview_summary_scroll"
	middle.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_force_pass_scroll_events = false
	column.add_child(middle)
	var summaries := T.column(middle)
	summaries.add_theme_constant_override("separation",6)
	var overview := T.paragraph(str(value.overview),T.LIGHT,14)
	overview.name = "character_preview_playstyle"
	overview.add_theme_constant_override("line_spacing",3)
	summaries.add_child(overview)
	_tags(summaries,value.tags,"character_preview_tags")
	var support_state := T.paragraph(str(value.support_state),T.GOLD,12)
	support_state.name = "character_preview_support_state"
	summaries.add_child(support_state)
	for entry in [["后台支援",str(value.support_info.get("summary", value.support_state))],["持有加成",str(value.owned_text)]]:
		var summary := T.paragraph(str(entry[0]) + "  " + str(entry[1]),T.INK,13)
		summary.name = "character_preview_support" if entry[0] == "后台支援" else "character_preview_owned"
		summaries.add_child(summary)
