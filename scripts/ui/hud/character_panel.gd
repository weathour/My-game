extends CanvasLayer

signal close_requested

const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const PLAYER_EQUIPMENT_FLOW := preload("res://scripts/player/player_equipment_flow.gd")
const RUAN_STONE_SYSTEM := preload("res://scripts/player/ruan_stone_system.gd")
const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")
const LEVELS := preload("res://scripts/player/player_skill_level_system.gd")
const TALENTS := preload("res://scripts/player/player_skill_talent_system.gd")
const SKILL_INFO := preload("res://scripts/player/player_skill_cooldown_flow.gd")
const SKILL_EFFECTS := preload("res://scripts/player/player_skill_level_effect_flow.gd")
const ULTIMATE := preload("res://scripts/player/player_ultimate_flow.gd")
const SHEET := preload("res://scripts/player/player_character_sheet.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const WHITE_KEY_SHADER := preload("res://shaders/white_key.gdshader")
const TAB_IDS := ["overview", "skills", "blessings", "equipment"]
const GOLD := Color("dfbd68")
const TEXT := Color("f3ead0")
const MUTED := Color("c5b99b")
const GREEN := Color("b5d39a")
const LINE := Color("786138")
const BG := Color("112018")
const ROLE_TEXTURE_PATHS := {
	"swordsman": "人设草图/剑士草图.jpg",
	"gunner": "人设草图/枪手草图.jpg",
	"mage": "人设草图/术师草图.jpg",
	"mechanic": "res://assets/players/mechanic/mechanic-standing.png"
}

const ROLE_PIXEL_TEXTURE_PATHS := {
	"swordsman": "res://assets/players/sword/剑-run.png",
	"gunner": "res://assets/players/gun/gun-run.png",
	"mage": "res://assets/players/wizard/wizard-run.png",
	"mechanic": "res://assets/players/mechanic/mechanic-idle.png"
}

const ROLE_PIXEL_FRAME_RECTS := {
	"swordsman": Rect2(529.0, 21.0, 95.0, 89.0),
	"gunner": Rect2(542.0, 25.0, 69.0, 74.0),
	"mage": Rect2(314.0, 78.0, 133.0, 93.0),
	"mechanic": Rect2(22.0, 8.0, 44.0, 80.0)
}

const ROLE_PIXEL_MODULATE := {
	"swordsman": Color(1.0, 0.88, 0.52, 1.0),
	"gunner": Color(1.0, 0.56, 0.44, 1.0),
	"mage": Color(0.72, 0.92, 1.0, 1.0),
	"mechanic": Color(1.0, 0.9, 0.65, 1.0)
}

const ROLE_PIXEL_INACTIVE_MODULATE := {
	"swordsman": Color(0.72, 0.58, 0.34, 0.84),
	"gunner": Color(0.70, 0.36, 0.30, 0.84),
	"mage": Color(0.42, 0.64, 0.76, 0.84),
	"mechanic": Color(0.62, 0.56, 0.42, 0.84)
}

const ROLE_TAGLINES := {
	"swordsman": "近战 · 均衡 · 连击",
	"gunner": "远程 · 爆发 · 弹幕",
	"mage": "奥术 · 范围 · 控场",
	"mechanic": "部署与阵地火力"
}

var cached_player: Node
var viewed_role_index := 0
var selected_tab := "overview"
var selected_items := {"overview": "attack", "skills": "", "blessings": "", "equipment": "stones"}
var records: Dictionary = {}
var item_buttons: Dictionary = {}
var role_buttons: Array[Button] = []
var tab_buttons: Dictionary = {}
var stat_rows: Array[Dictionary] = []
var panel: PanelContainer
var backdrop: ColorRect
var role_nav_list: VBoxContainer
var list_content: VBoxContainer
var list_scroll: ScrollContainer
var detail: VBoxContainer
var detail_scroll: ScrollContainer
var footer: Label
var identity_name: Label
var identity_state: Label
var identity_portrait: TextureRect
var gift_popup: PopupMenu
var pending_gift_equipment_id := ""
var pending_gift_from_role_id := ""
var gift_target_role_ids: Array[String] = []
var ui_white_key_material: ShaderMaterial
var role_pixel_texture_cache: Dictionary = {}


func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	backdrop = ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	panel = PanelContainer.new()
	panel.name = "CharacterSheet"
	panel.add_theme_stylebox_override("panel", SURVIVORS_THEME.panel_style(BG, GOLD, 2, 0, 22))
	var theme := Theme.new()
	theme.default_font = SURVIVORS_THEME.get_reading_font()
	theme.default_font_size = 16
	panel.theme = theme
	add_child(panel)
	SURVIVORS_THEME.apply_campaign_frame(panel, "panel")
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 10)
	panel.add_child(shell)
	var header := HBoxContainer.new()
	shell.add_child(header)
	var title := SURVIVORS_THEME.make_section_label("人物信息", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_label("已暂停", 15, GOLD))
	var close := _button("返回游戏   ×")
	close.pressed.connect(func(): close_requested.emit())
	header.add_child(close)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	for index in TAB_IDS.size():
		var button := _button(["总览", "技能", "祝福", "装备"][index])
		button.name = TAB_IDS[index].capitalize() + "Tab"
		button.custom_minimum_size = Vector2(112, 34)
		button.pressed.connect(_set_tab.bind(TAB_IDS[index]))
		tabs.add_child(button)
		tab_buttons[TAB_IDS[index]] = button
	shell.add_child(tabs)
	shell.add_child(_line())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(columns)
	role_nav_list = VBoxContainer.new()
	role_nav_list.name = "RoleRail"
	role_nav_list.custom_minimum_size.x = 128
	role_nav_list.add_theme_constant_override("separation", 10)
	columns.add_child(role_nav_list)
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.size_flags_stretch_ratio = 1.30
	middle.add_theme_constant_override("separation", 8)
	columns.add_child(middle)
	var identity := HBoxContainer.new()
	identity.custom_minimum_size.y = 66
	identity.add_theme_constant_override("separation", 16)
	middle.add_child(identity)
	identity_portrait = _portrait(Vector2(48, 64))
	identity.add_child(identity_portrait)
	var identity_text := VBoxContainer.new()
	identity_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_name = SURVIVORS_THEME.make_section_label("", 23)
	identity_name.name = "RoleIdentity"
	identity_state = _label("", 14, MUTED)
	identity_text.add_child(identity_name)
	identity_text.add_child(identity_state)
	identity.add_child(identity_text)
	list_scroll = _scroll("MainListScroll")
	middle.add_child(list_scroll)
	list_content = VBoxContainer.new()
	list_content.name = "MainList"
	list_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_content.add_theme_constant_override("separation", 2)
	list_scroll.add_child(list_content)
	var inspector := PanelContainer.new()
	inspector.name = "FixedInspector"
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.size_flags_stretch_ratio = 1.0
	inspector.add_theme_stylebox_override("panel", SURVIVORS_THEME.panel_style(Color("172b20"), LINE, 1, 0, 20))
	columns.add_child(inspector)
	SURVIVORS_THEME.apply_campaign_frame(inspector, "card")
	detail_scroll = _scroll("DetailScroll")
	inspector.add_child(detail_scroll)
	detail = VBoxContainer.new()
	detail.name = "DetailContent"
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 12)
	detail_scroll.add_child(detail)
	shell.add_child(_line())
	footer = _label("", 13, MUTED)
	shell.add_child(footer)
	gift_popup = PopupMenu.new()
	gift_popup.name = "GiftPopup"
	gift_popup.index_pressed.connect(_on_gift_popup_index_pressed)
	add_child(gift_popup)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _label(value: String, font_size: int = 16, color: Color = TEXT, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_stylebox_override("pressed", SURVIVORS_THEME.panel_style(Color("5a241c"), GOLD, 1, 0, 8))
	button.add_theme_stylebox_override("focus", SURVIVORS_THEME.panel_style(Color.TRANSPARENT, GOLD, 2, 0))
	_style_selection(button, false)
	return button


func _style_selection(button: Button, selected: bool) -> void:
	button.add_theme_stylebox_override("normal", SURVIVORS_THEME.panel_style(Color("55251e") if selected else Color("14251b"), GOLD if selected else Color.TRANSPARENT, 1, 0, 8))
	button.add_theme_stylebox_override("hover", SURVIVORS_THEME.panel_style(Color("6b3226") if selected else Color("213b29"), GOLD if selected else LINE.lightened(0.3), 1, 0, 8))


func _line() -> HSeparator:
	var line := HSeparator.new()
	line.add_theme_stylebox_override("separator", SURVIVORS_THEME.panel_style(LINE, LINE, 0, 0))
	line.custom_minimum_size.y = 1
	return line


func _scroll(node_name: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = node_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	return scroll


func _portrait(dimensions: Vector2) -> TextureRect:
	var texture := TextureRect.new()
	texture.custom_minimum_size = dimensions
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return texture


func _layout() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var scale_factor := minf(1.0, minf(viewport.x / 1280.0, viewport.y / 720.0))
	panel.scale = Vector2.ONE * scale_factor
	panel.size = Vector2(minf(1380, viewport.x / scale_factor - 48), minf(780, viewport.y / scale_factor - 36))
	panel.position = (viewport - panel.size * scale_factor) * 0.5


func show_for_player(player: Node) -> void:
	cached_player = player
	viewed_role_index = int(player.active_role_index)
	footer.text = "%s / Esc  返回    ·    Ctrl + Tab  切换栏目    ·    Tab / 方向键  浏览，Enter  选择" % GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_CHARACTER_PANEL))
	selected_tab = "overview"
	selected_items["overview"] = "attack"
	visible = true
	refresh()
	_layout()


func hide_panel() -> void:
	gift_popup.hide()
	visible = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if GAME_SETTINGS.event_matches_action(event, GAME_SETTINGS.ACTION_CHARACTER_PANEL) or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		close_requested.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed and event.keycode == KEY_TAB:
		var step := -1 if event.shift_pressed else 1
		_set_tab(TAB_IDS[posmod(TAB_IDS.find(selected_tab) + step, TAB_IDS.size())])
		(tab_buttons[selected_tab] as Button).grab_focus()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	if not is_instance_valid(cached_player) or _get_roles().is_empty():
		return
	viewed_role_index = clampi(viewed_role_index, 0, _get_roles().size() - 1)
	var role: Dictionary = _get_roles()[viewed_role_index]
	var id := str(role.id)
	identity_name.text = "%s   ·   本局 Lv.%d" % [role.name, cached_player.level]
	identity_state.text = "%s  ·  %s" % ["当前站场" if viewed_role_index == cached_player.active_role_index else "候补角色", ROLE_TAGLINES.get(id, "")]
	_apply_role_texture(identity_portrait, id, true)
	_refresh_role_rail()
	stat_rows = SHEET.get_stats(cached_player, role)
	_rebuild_page()


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _refresh_role_rail() -> void:
	_clear(role_nav_list)
	role_buttons.clear()
	role_nav_list.add_child(_label("队伍", 14, GOLD))
	for index in _get_roles().size():
		var role: Dictionary = _get_roles()[index]
		var button := _button("")
		button.name = "Role_" + str(role.id)
		button.custom_minimum_size = Vector2(128, 112)
		_style_selection(button, index == viewed_role_index)
		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 8
		content.offset_right = -8
		content.offset_top = 6
		content.offset_bottom = -6
		content.add_theme_constant_override("separation", 1)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var picture := _portrait(Vector2(44, 54))
		_apply_role_texture(picture, str(role.id), index == viewed_role_index)
		content.add_child(picture)
		var label := _label(str(role.name), 16, TEXT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(label)
		var state := _label("● 当前站场" if index == cached_player.active_role_index else "候补", 12, GREEN if index == cached_player.active_role_index else MUTED)
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(state)
		button.add_child(content)
		SURVIVORS_THEME.apply_campaign_frame(button, "card")
		button.pressed.connect(_view_role.bind(index))
		role_nav_list.add_child(button)
		role_buttons.append(button)
	_add_build_links()


func _add_build_links() -> void:
	var role_id := str(_get_roles()[viewed_role_index].id)
	var skill_count := 0
	for progress_id in LEVELS.ROLE_PROGRESS_ORDER.get(role_id, []):
		if LEVELS.UNLOCKABLE_PROGRESS.has(progress_id) and LEVELS.get_skill_level(cached_player, role_id, progress_id) > 0:
			skill_count += 1
	var blessings := PLAYER_BLESSING_SYSTEM.get_blessing_level_summary(cached_player, role_id)
	var blessing_count := 0
	for group in blessings.values():
		for tiers in group.values():
			if SHEET.tier_counts(tiers) != "":
				blessing_count += 1
	var equipment_count := 0
	for count in cached_player._get_role_equipment_levels(role_id).values():
		equipment_count += int(count)
	var grid := GridContainer.new()
	grid.columns = 2
	role_nav_list.add_child(grid)
	var links := [["主动 %d" % skill_count, "skills"], ["祝福 %d" % blessing_count, "blessings"], ["道具 %d" % equipment_count, "equipment"], ["阮石 %d" % cached_player.get_ruan_stone_carried_count(), "equipment"]]
	for link in links:
		var button := _button(link[0])
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_set_tab.bind(link[1]))
		grid.add_child(button)


func _view_role(index: int) -> void:
	if index < 0 or index >= _get_roles().size():
		return
	viewed_role_index = index
	refresh()
	role_buttons[index].grab_focus()


func _set_tab(id: String) -> void:
	if not TAB_IDS.has(id):
		return
	selected_tab = id
	_rebuild_page()


func _rebuild_page() -> void:
	_clear(list_content)
	records.clear()
	item_buttons.clear()
	for id in tab_buttons:
		_style_selection(tab_buttons[id], id == selected_tab)
	var role_id := str(_get_roles()[viewed_role_index].id)
	match selected_tab:
		"overview": _build_overview()
		"skills": _build_skills(role_id)
		"blessings": _build_blessings(role_id)
		"equipment": _build_equipment(role_id)
	list_scroll.scroll_vertical = 0
	var selection := str(selected_items[selected_tab])
	if not records.has(selection):
		selection = str(records.keys()[0]) if not records.is_empty() else ""
	_select_item(selection)
	_reveal_selected_item.call_deferred()


func _reveal_selected_item() -> void:
	# New containers receive their final row positions on the next layout frame.
	await get_tree().process_frame
	var id := str(selected_items[selected_tab])
	if item_buttons.has(id):
		list_scroll.ensure_control_visible(item_buttons[id])


func _group(title: String) -> void:
	var label := _label(title, 13, GOLD)
	label.custom_minimum_size.y = 22
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	list_content.add_child(label)


func _add_item(id: String, title: String, value: String, record: Dictionary, subtitle: String = "") -> Button:
	records[id] = record
	var button := _button("")
	button.name = "Item_" + id
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Use labels for both columns so values stay aligned and long titles can wrap.
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 2 if subtitle == "" else 6)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := _label(title, 16, TEXT, true)
	row.add_child(name_label)
	var value_label := _label(value, 16, GREEN if selected_tab == "overview" else GOLD)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	column.add_child(row)
	if subtitle != "":
		column.add_child(_label(subtitle, 13, MUTED, true))
	margin.add_child(column)
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.custom_minimum_size.y = 28 if subtitle == "" else 66
	margin.minimum_size_changed.connect(func(): button.custom_minimum_size.y = maxf(28 if subtitle == "" else 66, margin.get_combined_minimum_size().y))
	button.pressed.connect(_select_item.bind(id))
	button.focus_entered.connect(_select_item.bind(id))
	list_content.add_child(button)
	item_buttons[id] = button
	return button


func _build_overview() -> void:
	var last_group := ""
	for row in stat_rows:
		if row.group != last_group:
			_group(str(row.group))
			last_group = str(row.group)
		_add_item(str(row.id), str(row.title), str(row.formatted), row)


func _select_item(id: String) -> void:
	if item_buttons.has(id):
		var button: Button = item_buttons[id]
		if button.is_visible_in_tree() and not button.has_focus():
			button.grab_focus()
			return
	selected_items[selected_tab] = id
	for key in item_buttons:
		_style_selection(item_buttons[key], key == id)
	_clear(detail)
	detail_scroll.scroll_vertical = 0
	if not records.has(id):
		detail.add_child(_label("暂无" + {"blessings": "祝福", "equipment": "道具"}.get(selected_tab, "记录"), 24, TEXT))
		detail.add_child(_label("在本局获得后，可在这里查看效果与来源。", 16, MUTED, true))
		return
	var record: Dictionary = records[id]
	match selected_tab:
		"overview": _show_stat(record)
		"skills": _show_skill(record)
		"blessings": _show_blessing(record)
		"equipment": _show_equipment(record)


func _detail_header(kicker: String, title: String, value: String = "") -> void:
	detail.add_child(_label(kicker, 13, GOLD, true))
	detail.add_child(_label(title, 25, TEXT, true))
	if value != "":
		detail.add_child(_label(value, 30, GREEN, true))
	detail.add_child(_line())


func _detail_text(value: String, color: Color = MUTED) -> void:
	if value != "":
		detail.add_child(_label(value, 16, color, true))


func _detail_pair(title: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_label(title, 15, TEXT, true))
	row.add_child(_label(value, 16, GREEN))
	detail.add_child(row)


func _show_stat(record: Dictionary) -> void:
	_detail_header("当前属性 · 来源", str(record.title), str(record.formatted))
	_detail_text("计算来源", GOLD)
	for source in record.sources:
		if SHEET.visible_source(source):
			_detail_pair(str(source.label), SHEET.format_source(source, bool(record.percent)))
	detail.add_child(_line())
	_detail_text(str(record.note))
	if record.id == "attack":
		_detail_text("攻击力用于技能的基础伤害计算。技能专属增幅见「技能」。")


func _build_skills(role_id: String) -> void:
	var last_group := ""
	for progress_id in LEVELS.ROLE_PROGRESS_ORDER.get(role_id, []):
		var is_ultimate: bool = str(progress_id).ends_with("_ultimate")
		var is_active := LEVELS.UNLOCKABLE_PROGRESS.has(progress_id)
		var group := "终结技" if is_ultimate else ("主动技能" if is_active else "固有能力")
		if group != last_group:
			_group(group)
			last_group = group
		var level := LEVELS.get_skill_level(cached_player, role_id, progress_id)
		var custom: bool = LEVELS.is_custom_basic(progress_id)
		var unlocked: bool = not is_active or cached_player._is_blessing_skill_unlocked(LEVELS.UNLOCKABLE_PROGRESS[progress_id])
		var state := "终结技" if is_ultimate else ("未获得" if not unlocked else "Lv.%d / %d" % [level, 9 if custom else LEVELS.MAX_SKILL_LEVEL])
		var info := _skill_info(role_id, progress_id)
		var summary := str(info.get("effect_summary", info.get("description", ""))).split("\n")[0]
		if not unlocked and not is_ultimate:
			summary = "获得技能卡后解锁"
		_add_item(progress_id, str(LEVELS.PROGRESS_TITLES.get(progress_id, progress_id)), state, {"id": progress_id, "role_id": role_id, "level": level, "info": info, "ultimate": is_ultimate, "unlocked": unlocked}, summary)
	var selected: Array = TALENTS.get_selected_level_talents(cached_player, role_id)
	if not selected.is_empty():
		_group("已获得强化")
		for talent_id in selected:
			var definition: Dictionary = TALENTS._get_level_talent_definition_for_role(role_id, talent_id)
			_add_item(talent_id, str(definition.get("title", talent_id)), "已获得", {"id": talent_id, "talent": definition}, "查看强化效果")


func _skill_info(role_id: String, progress_id: String) -> Dictionary:
	if LEVELS.is_custom_basic(progress_id):
		return {"effect_summary": LEVELS.basic_build(progress_id).description(cached_player)}
	if LEVELS.UNLOCKABLE_PROGRESS.has(progress_id):
		return SKILL_INFO.get_skill_info(cached_player, role_id, LEVELS.UNLOCKABLE_PROGRESS[progress_id])
	if progress_id.ends_with("_ultimate"):
		return ULTIMATE.get_ultimate_display(cached_player, role_id)
	return SHEET.get_innate_skill_info(cached_player, role_id, progress_id)


func _show_skill(record: Dictionary) -> void:
	if record.has("talent"):
		_detail_header("已记录 · 效果尚未实装" if bool(record.talent.get("placeholder", false)) else "已生效强化", str(record.talent.get("title", record.id)))
		_detail_text(str(record.talent.get("summary", "")), TEXT)
		return
	var progress_id := str(record.id)
	var level := int(record.level)
	var info: Dictionary = record.info
	var is_ultimate := bool(record.ultimate)
	var custom: bool = LEVELS.is_custom_basic(progress_id)
	var maximum: int = 9 if custom else LEVELS.MAX_SKILL_LEVEL
	var unlocked: bool = bool(record.get("unlocked", level > 0))
	_detail_header("技能详情", str(LEVELS.PROGRESS_TITLES.get(progress_id, progress_id)), "终结技" if is_ultimate else ("未获得" if not unlocked else "Lv.%d / %d" % [level, maximum]))
	if not unlocked and not is_ultimate:
		_detail_text("解锁方式：升级时选择对应的「获得技能」卡。", GOLD)
		_detail_text("获得后技能进入升级卡池。以下为解锁效果预览。")
	else:
		_detail_text("当前效果", GOLD)
	var description := str(info.get("effect_summary", info.get("description", "")))
	_detail_text(description, TEXT)
	for row in info.get("effect_rows", []):
		_detail_pair(str(row.get("label", "")), str(row.get("value", "")))
	_detail_text(str(info.get("effect_note", "")))
	if is_ultimate:
		_detail_text("消耗大招能量释放；不参与普通技能等级升级。")
		return
	if not unlocked:
		return
	detail.add_child(_line())
	if level < maximum:
		_detail_text("下一级 · Lv.%d → %d" % [level, level + 1], GOLD)
		var preview := SKILL_EFFECTS.get_upgrade_preview_text(cached_player, str(record.role_id), progress_id)
		_detail_text(preview if preview != "" else "技能等级 +1；具体数值成长说明暂缺。", TEXT)
	else:
		_detail_text("已满级", GOLD)
	if custom:
		return
	_detail_text("天赋位", GOLD)
	var granted := LEVELS.get_granted_talent_slots(cached_player, str(record.role_id), progress_id)
	for slot in [1, 2]:
		var definition := LEVELS.get_talent_definition(str(record.role_id), progress_id, slot)
		var state := ("已生效" if not definition.is_empty() else "已获得 · 效果尚未实装") if granted.has(slot) else ("待选择 / 10 级补齐" if level >= 5 else "5 级开放选择")
		_detail_text("%s   %s   %s" % ["I" if slot == 1 else "II", str(definition.get("title", "")), state], GOLD if granted.has(slot) else MUTED)
		if not definition.is_empty():
			_detail_text(str(definition["description"]), TEXT)


func _build_blessings(role_id: String) -> void:
	var summary := PLAYER_BLESSING_SYSTEM.get_blessing_level_summary(cached_player, role_id)
	for binding in ["role", "skill"]:
		var levels: Dictionary = summary.get(binding, {})
		var header_added := false
		for id in PLAYER_BLESSING_SYSTEM.DEFINITIONS:
			var tiers: Dictionary = levels.get(id, {})
			if SHEET.tier_counts(tiers) == "":
				continue
			if not header_added:
				_group("全队共享" if binding == "role" else "匹配技能生效")
				header_added = true
			var definition: Dictionary = PLAYER_BLESSING_SYSTEM.DEFINITIONS[id]
			var title := str(definition.get("display_title", definition.get("title", id)))
			_add_item(binding + ":" + id, title, SHEET.tier_counts(tiers), {"id": id, "definition": definition, "tiers": tiers, "binding": binding, "title": title}, SHEET.blessing_total(id, tiers))
	if records.is_empty():
		list_content.add_child(_label("本局尚未获得祝福", 18, MUTED, true))


func _show_blessing(record: Dictionary) -> void:
	_detail_header("祝福 · " + ("全队共享" if record.binding == "role" else "匹配技能生效"), str(record.title), SHEET.tier_counts(record.tiers))
	_detail_text(SHEET.blessing_total(str(record.id), record.tiers), GOLD)
	if record.binding == "skill":
		_detail_text(_blessing_scope(str(record.id), record.definition))
	_detail_text("持有明细 · 下列为每份效果", GOLD)
	for tier in range(1, PLAYER_BLESSING_SYSTEM.MAX_BLESSING_TIER + 1):
		var count := int(record.tiers.get(tier, record.tiers.get(str(tier), 0)))
		if count <= 0:
			continue
		_detail_text("%s × %d" % [PLAYER_BLESSING_SYSTEM._tier_label(tier), count], TEXT)
		_detail_text(PLAYER_BLESSING_SYSTEM._get_tier_description(record.definition, tier))


func _blessing_scope(id: String, definition: Dictionary) -> String:
	var categories := {"reprise": "所有连段技能", "tide_rain": "所有持续技能", "trick": "所有数量技能"}
	if categories.has(id):
		return "作用范围：" + categories[id]
	var stone := str(definition.get("magic_stone", ""))
	return "作用范围：" + str({PLAYER_BLESSING_SYSTEM.MAGIC_STONE_KINGDOM: "所有角色普攻", PLAYER_BLESSING_SYSTEM.MAGIC_STONE_KING: "所有角色终结技", PLAYER_BLESSING_SYSTEM.MAGIC_STONE_KEBIRU: "所有克比鲁魔法", PLAYER_BLESSING_SYSTEM.MAGIC_STONE_INVOKER: "所有因沃克魔法"}.get(stone, "符合该祝福条件的技能"))


func _build_equipment(role_id: String) -> void:
	_group("全队共享")
	_add_item("stones", "阮石携带", "%d / %d" % [cached_player.get_ruan_stone_carried_count(), cached_player.get_ruan_stone_carry_limit()], {"id": "stones"}, cached_player.get_ruan_stone_carry_summary())
	_group("当前角色持有 · 可赠与队友")
	var equipment: Dictionary = cached_player._get_role_equipment_levels(role_id)
	var owned := false
	for id in PLAYER_EQUIPMENT_FLOW.EQUIPMENT_DEFINITIONS:
		var count := int(equipment.get(id, 0))
		if count <= 0:
			continue
		owned = true
		var definition: Dictionary = PLAYER_EQUIPMENT_FLOW.EQUIPMENT_DEFINITIONS[id]
		var button := _add_item(id, str(definition.title), "× %d" % count, {"id": id, "role_id": role_id, "count": count, "definition": definition}, SHEET.equipment_effect_text(id, count))
		button.gui_input.connect(_on_equipment_gui_input.bind(id, role_id))
	if not owned:
		list_content.add_child(_label("该角色暂无普通道具", 16, MUTED, true))


func _show_equipment(record: Dictionary) -> void:
	if record.id == "stones":
		_detail_header("全队共享 · 不可赠与", "阮石", "%d / %d" % [cached_player.get_ruan_stone_carried_count(), cached_player.get_ruan_stone_carry_limit()])
		_detail_text("携带上限由档案解锁的最高难度决定。购买后全队生效。")
		var counts := {}
		for id in cached_player.get_purchased_ruan_stones():
			counts[id] = int(counts.get(id, 0)) + 1
		for id in counts:
			_detail_text("%s × %d" % [RUAN_STONE_SYSTEM.get_definition(id).get("title", id), counts[id]], TEXT)
			_detail_text("累计：" + RUAN_STONE_SYSTEM.get_effect_text(id, int(counts[id])))
		if counts.is_empty():
			_detail_text("尚未携带阮石。")
		return
	_detail_header("角色道具", str(record.definition.title), "持有 × %d" % record.count)
	_detail_text(SHEET.equipment_effect_text(str(record.id), int(record.count)), TEXT)
	_detail_text("只计入持有角色；可赠与其中 1 个，目标持有上限为 %d。" % PLAYER_EQUIPMENT_FLOW.EQUIPMENT_MAX_LEVEL)
	var gift := _button("赠与队友…")
	gift.name = "GiftButton"
	gift.custom_minimum_size.y = 42
	gift.pressed.connect(_show_gift_popup.bind(str(record.id), str(record.role_id)))
	detail.add_child(gift)
	_detail_text("也可右键点击左侧道具。")
func _on_equipment_gui_input(event: InputEvent, equipment_id: String, from_role_id: String) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_show_gift_popup(equipment_id, from_role_id)

func _show_gift_popup(equipment_id: String, from_role_id: String) -> void:
	pending_gift_equipment_id = equipment_id
	pending_gift_from_role_id = from_role_id
	gift_target_role_ids.clear()
	gift_popup.clear()
	var roles: Array = _get_roles()
	for role_data in roles:
		var target_role_id: String = str(role_data.get("id", ""))
		if target_role_id == "" or target_role_id == from_role_id:
			continue
		var target_levels: Dictionary = cached_player._get_role_equipment_levels(target_role_id) if cached_player.has_method("_get_role_equipment_levels") else {}
		var item_index: int = gift_popup.item_count
		gift_target_role_ids.append(target_role_id)
		gift_popup.add_item("赠与 %s" % str(role_data.get("name", target_role_id)))
		if int(target_levels.get(equipment_id, 0)) >= PLAYER_EQUIPMENT_FLOW.EQUIPMENT_MAX_LEVEL:
			gift_popup.set_item_disabled(item_index, true)
	if gift_popup.item_count <= 0:
		return
	gift_popup.position = Vector2i(get_viewport().get_mouse_position())
	gift_popup.popup()

func _on_gift_popup_index_pressed(index: int) -> void:
	if cached_player == null or not is_instance_valid(cached_player):
		return
	if index < 0 or index >= gift_target_role_ids.size():
		return
	var target_role_id: String = gift_target_role_ids[index]
	if cached_player.has_method("transfer_role_equipment_item"):
		cached_player.transfer_role_equipment_item(pending_gift_equipment_id, pending_gift_from_role_id, target_role_id)
	refresh()

func _apply_role_texture(target: TextureRect, role_id: String, highlighted: bool) -> void:
	if target == null:
		return
	var texture := _load_role_texture(role_id)
	target.texture = texture
	target.material = null if texture is AtlasTexture else (_get_ui_white_key_material() if texture != null else null)
	target.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if highlighted:
		target.modulate = ROLE_PIXEL_MODULATE.get(role_id, Color.WHITE)
	else:
		target.modulate = ROLE_PIXEL_INACTIVE_MODULATE.get(role_id, Color(0.56, 0.66, 0.78, 0.80))

func _get_ui_white_key_material() -> ShaderMaterial:
	if ui_white_key_material != null:
		return ui_white_key_material
	if cached_player != null and cached_player.has_method("_create_white_key_material"):
		var player_material: ShaderMaterial = cached_player._create_white_key_material(0.93, 0.12, 0.04)
		if player_material != null:
			ui_white_key_material = player_material
			return ui_white_key_material
	var material := ShaderMaterial.new()
	material.shader = WHITE_KEY_SHADER
	material.set_shader_parameter("value_threshold", 0.93)
	material.set_shader_parameter("saturation_threshold", 0.12)
	material.set_shader_parameter("edge_softness", 0.04)
	ui_white_key_material = material
	return ui_white_key_material

func _load_role_texture(role_id: String) -> Texture2D:
	var pixel_texture := _load_role_pixel_frame(role_id)
	if pixel_texture != null:
		return pixel_texture
	if cached_player != null and cached_player.has_method("_get_cached_runtime_texture"):
		var texture: Texture2D = cached_player._get_cached_runtime_texture(str(ROLE_TEXTURE_PATHS.get(role_id, ROLE_TEXTURE_PATHS["swordsman"])))
		if texture != null:
			return texture
	return null

func _load_role_pixel_frame(role_id: String) -> Texture2D:
	if role_pixel_texture_cache.has(role_id):
		return role_pixel_texture_cache[role_id] as Texture2D
	var path := str(ROLE_PIXEL_TEXTURE_PATHS.get(role_id, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var atlas_source := load(path) as Texture2D
	if atlas_source == null:
		return null
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = atlas_source
	atlas_texture.region = ROLE_PIXEL_FRAME_RECTS.get(role_id, Rect2(Vector2.ZERO, atlas_source.get_size()))
	role_pixel_texture_cache[role_id] = atlas_texture
	return atlas_texture

func _get_roles() -> Array:
	if cached_player == null or not is_instance_valid(cached_player):
		return []
	var roles_variant: Variant = cached_player.get("roles")
	if roles_variant is Array:
		return roles_variant
	return []
