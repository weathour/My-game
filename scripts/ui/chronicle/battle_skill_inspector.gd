extends Control
## Pause-only inspection. Reading a skill never calls the activation path.
signal back_requested
signal resume_requested
const C := preload("res://scripts/content/combat_catalog.gd")
const INFO := preload("res://scripts/content/skill_information.gd")
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const DETAILS := preload("res://scripts/ui/chronicle/character_detail_projection.gd")
var battle: RefCounted
var panel: PanelContainer
var member_choice: OptionButton
var ability_choice: OptionButton
var back_button: Button
var resume_button: Button
var overview: Label
var scroll: ScrollContainer
var body: VBoxContainer
var selected_member := 0
var entries: Array = []
var current_model: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color("08110de8")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = T.panel(self, false, 16)
	panel.name = "battle_skill_inspector_panel"
	var column := T.column(panel)
	column.add_theme_constant_override("separation", 8)
	var header := T.row(column)
	header.add_child(T.label(INFO.ui("skill_information"), 24, T.LIGHT, true))
	T.space(header)
	back_button = T.quiet_button(INFO.ui("back_to_pause"), func(): back_requested.emit())
	back_button.name = "battle_skill_back"
	header.add_child(back_button)
	var selectors := T.row(column)
	member_choice = OptionButton.new()
	member_choice.name = "battle_skill_member"
	member_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selectors.add_child(member_choice)
	ability_choice = OptionButton.new()
	ability_choice.name = "battle_skill_choice"
	ability_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selectors.add_child(ability_choice)
	for id in battle.members:
		member_choice.add_item(str(C.definition(id).name))
	selected_member = battle.active
	member_choice.select(selected_member)
	member_choice.item_selected.connect(func(index: int):
		selected_member = index
		_rebuild_choices())
	ability_choice.item_selected.connect(func(_index: int): _show_selected())
	overview = T.paragraph("", T.GOLD, 14)
	overview.name = "battle_skill_overview"
	column.add_child(overview)
	scroll = ScrollContainer.new()
	scroll.name = "battle_skill_scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.follow_focus = true
	scroll.mouse_force_pass_scroll_events = false
	column.add_child(scroll)
	body = T.column(scroll)
	body.add_theme_constant_override("separation", 8)
	resume_button = T.button(INFO.ui("resume"), func(): resume_requested.emit(), true)
	resume_button.name = "battle_skill_resume"
	T.compact_button(resume_button)
	column.add_child(resume_button)
	resized.connect(_layout)
	_layout()
	_rebuild_choices()
	member_choice.grab_focus()

func _layout() -> void:
	if not is_instance_valid(panel): return
	panel.size = Vector2(minf(900, maxf(280, size.x - 40)), minf(720, maxf(240, size.y - 40)))
	panel.position = (size - panel.size) * .5

func _rebuild_choices() -> void:
	var id := str(battle.members[selected_member])
	var kit: Dictionary = C.definition(id)
	entries.clear()
	ability_choice.clear()
	_add_choice("basic", str(C.basic(id, battle.equipment).title))
	for index in kit.automatic.size(): _add_choice("automatic", str(kit.automatic[index].title), index)
	for slot in 2:
		var key := "J" if slot == 0 else "K"
		var title := str(kit.manual[slot].title) if slot < kit.manual.size() else INFO.ui("not_equipped")
		_add_choice("manual_j" if slot == 0 else "manual_k", key + " · " + title)
	if not str(kit.trait).is_empty(): _add_choice("trait", INFO.ui("extra_mechanic"))
	_add_choice("support", INFO.ui("support"))
	_add_choice("owned", INFO.ui("owned"))
	var character: Dictionary = INFO.character(id)
	overview.text = str(character.get("overview", ""))
	# Start on J, the most frequently consulted entry, without activating it.
	for index in entries.size():
		if entries[index].slot == "manual_j":
			ability_choice.select(index)
			break
	_show_selected()

func _add_choice(slot: String, title: String, index: int = 0) -> void:
	entries.append({"slot":slot, "index":index})
	ability_choice.add_item(title)

func _show_selected() -> void:
	if entries.is_empty(): return
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	var id := str(battle.members[selected_member])
	var actor: RefCounted = battle.characters[id]
	var entry: Dictionary = entries[ability_choice.selected]
	var slot := str(entry.slot)
	var info: Dictionary
	var title := ""
	if slot in ["manual_j", "manual_k"]:
		info = INFO.manual_model(battle, id, 0 if slot == "manual_j" else 1)
		title = "%s · %s" % [info.get("key", ""), info.get("title", "")]
	elif slot == "trait":
		info = INFO.describe({}, "trait", id)
		title = INFO.ui("extra_mechanic")
	elif slot == "owned":
		info = {"summary": DETAILS.precise_owned_text(id)}
		title = INFO.ui("owned")
	else:
		var view: Dictionary = INFO.runtime_view(battle, id, slot, int(entry.index))
		info = INFO.describe(view, slot, id)
		title = str(view.get("title", INFO.ui("not_equipped"))) if slot != "support" or not view.is_empty() else INFO.ui("support")
		if view.is_empty(): info = {"summary": INFO.ui("not_equipped")}
		if actor.dead: info["state_text"] = INFO.text("state.dead")
	current_model = info
	_line(title, "battle_skill_title", 21, T.LIGHT)
	var category := str(info.get("category", ""))
	if not category.is_empty(): _line(category, "battle_skill_category", 12, T.MUTED)
	_line(str(info.get("summary", "")), "battle_skill_summary", 16, T.LIGHT)
	var trigger := str(info.get("trigger", ""))
	if not trigger.is_empty(): _line(trigger, "battle_skill_trigger", 13, T.MUTED)
	var conditions := "\n".join(info.get("conditions", []))
	if not conditions.is_empty(): _line(conditions, "battle_skill_conditions", 14, T.LIGHT)
	var facts := "\n".join(info.get("facts", []))
	if not facts.is_empty(): _line(facts, "battle_skill_facts", 14, T.GOLD)
	var state_text := str(info.get("state_text", ""))
	if not state_text.is_empty(): _line(state_text, "battle_skill_state", 14, T.GOLD)
	var details: Array = info.get("details", [])
	if not details.is_empty():
		var details_label := T.paragraph("\n".join(details), T.MUTED, 14)
		details_label.name = "battle_skill_details"
		details_label.focus_mode = Control.FOCUS_ALL
		details_label.hide()
		var expand := T.quiet_button(INFO.ui("expand_details"), func():
			details_label.visible = not details_label.visible
			var button := body.get_node("battle_skill_expand") as Button
			button.text = INFO.ui("collapse_details" if details_label.visible else "expand_details")
			_sync_focus())
		expand.name = "battle_skill_expand"
		body.add_child(expand)
		body.add_child(details_label)
	scroll.scroll_vertical = 0
	_sync_focus()

func _line(value: String, node_name: String, font_size: int, color: Color) -> void:
	var label := T.paragraph(value, color, font_size)
	label.name = node_name
	body.add_child(label)

func _sync_focus() -> void:
	var controls: Array[Control] = [back_button, member_choice, ability_choice, scroll]
	for child in body.get_children():
		if child is Control and child.focus_mode != Control.FOCUS_NONE and child.visible: controls.append(child)
	controls.append(resume_button)
	for index in controls.size():
		var control: Control = controls[index]
		control.focus_previous = control.get_path_to(controls[posmod(index - 1, controls.size())])
		control.focus_next = control.get_path_to(controls[(index + 1) % controls.size()])
		control.focus_neighbor_top = control.focus_previous
		control.focus_neighbor_bottom = control.focus_next

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	# Let an open selector handle its own navigation and dismissal first.
	if member_choice.get_popup().visible or ability_choice.get_popup().visible: return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		back_requested.emit()
		return
	if event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN, KEY_HOME, KEY_END]:
		if event.keycode == KEY_HOME: scroll.scroll_vertical = 0
		elif event.keycode == KEY_END: scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		else: scroll.scroll_vertical += int(scroll.size.y * .85) * (-1 if event.keycode == KEY_PAGEUP else 1)
		get_viewport().set_input_as_handled()

func _unhandled_key_input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
