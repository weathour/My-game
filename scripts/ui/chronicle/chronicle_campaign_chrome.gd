extends RefCounted
## Campaign presentation regions. All values are projections of the existing save.
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const PORTRAITS := preload("res://scripts/ui/chronicle/chronicle_portraits.gd")
const SEGMENTS := ["城外来客", "夺寨聚众", "官印易主", "吕家风波", "协力守城", "白门终战"]
const PAPER_INK := Color("29271e")
const PAPER_MUTED := Color("514a37")
const PAPER := Color("ddd0ad")
const BASE := Vector2(1280, 720)

class StageSeal extends Control:
	var phase := 0
	var finished := false

	func _draw() -> void:
		var k := minf(size.x / 144.0, size.y / 152.0)
		var center := Vector2(size.x * .5, 60.0 * k)
		var rim := 52.0 * k
		draw_circle(center, rim + 5.0 * k, Color("151b15"))
		draw_arc(center, rim + 3.0 * k, 0, TAU, 72, Color("8d774e"), 2.0 * k, true)
		draw_arc(center, rim - 2.0 * k, 0, TAU, 72, Color("dfc187"), 1.0 * k, true)
		var heading := T.FONT.get_heading_font()
		draw_string(heading, Vector2(0, 26 * k), "阶段", HORIZONTAL_ALIGNMENT_CENTER, size.x, int(18 * k), T.LIGHT)
		draw_string(heading, Vector2(0, 85 * k), str(phase + 1), HORIZONTAL_ALIGNMENT_CENTER, size.x, int(52 * k), T.LIGHT)
		draw_string(T.FONT.get_reading_font(), Vector2(0, 126 * k), "战役告捷" if finished else SEGMENTS[phase], HORIZONTAL_ALIGNMENT_CENTER, size.x, maxi(12, int(14 * k)), T.GOLD)
		for i in 6:
			var at := Vector2((22 + i * 20) * k, 145 * k)
			var color := Color("bda66a") if i <= phase else Color("26332a")
			draw_circle(at, 5.0 * k, color)
			draw_arc(at, 6.0 * k, 0, TAU, 20, T.GOLD if i == phase else T.BORDER, 1.0, true)

static func build(shell: Control, parent: Control, mode: String) -> Dictionary:
	var root := Control.new()
	root.name = "CampaignCommandSurface"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var viewport: Vector2 = shell.size
	var shade := ColorRect.new()
	shade.color = Color("0e1a1360")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Maps are beneath the portrait, information paper and corner commands.
	var map := Control.new()
	map.name = "CampaignMapRegion"
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(map)
	place(map, Rect2(230, 118, 1030, 468) if mode == "route" else Rect2(230, 112, 1030, 484), viewport)
	var context_panel := _panel(root, Rect2(176, 14, 600, 96) if mode == "route" else Rect2(400, 12, 520, 88), viewport, Color("17271df5"), 12, "banner")
	context_panel.name = "campaign_context_panel"
	var context := T.column(context_panel)
	context.add_theme_constant_override("separation", 3)
	var current: Dictionary = shell.session.nodes.get(shell.session.data.current, {})
	var seal := StageSeal.new()
	seal.name = "campaign_stage_seal"
	seal.phase = clampi(int(current.get("segment", 0)), 0, 5)
	seal.finished = bool(shell.session.data.finished)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.tooltip_text = SEGMENTS[seal.phase]
	root.add_child(seal)
	place(seal, Rect2(12, 8, 144, 152), viewport)
	_build_presenter(shell, root, viewport)
	var detail_panel := _panel(root, Rect2(16, 456, 428, 184), viewport, PAPER, 14, "panel")
	detail_panel.name = "campaign_detail_paper"
	detail_panel.add_theme_color_override("font_color", PAPER_INK)
	var detail := T.column(detail_panel)
	detail.add_theme_constant_override("separation", 5)
	var choice_panel := _panel(root, Rect2(978, 136, 286, 390), viewport, Color("17291ef5"), 12, "panel")
	choice_panel.name = "campaign_choice_panel"
	var choices := T.column(choice_panel)
	choices.add_theme_constant_override("separation", 8)
	var actions := VBoxContainer.new()
	actions.name = "campaign_primary_action"
	root.add_child(actions)
	place(actions, Rect2(978, 540, 286, 56), viewport)
	var map_tools := HBoxContainer.new()
	map_tools.name = "campaign_map_tools"
	map_tools.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(map_tools)
	place(map_tools, Rect2(1158, 14, 106, 92), viewport)
	_build_party(shell, root, viewport)
	var menu := T.button("菜单", shell.open_menu)
	menu.name = "nav_settings"
	menu.tooltip_text = "存档、见闻、图鉴与设定"
	root.add_child(menu)
	place(menu, Rect2(16, 658, 104, 48), viewport)
	_style_command(menu, viewport)
	if mode == "route":
		var world := T.button("← 天下", func(): shell.open_page("world"))
		world.name = "nav_world"
		root.add_child(world)
		place(world, Rect2(128, 658, 112, 48), viewport)
		_style_command(world, viewport)
	var party := T.button("整备", func(): shell.open_page("roster"), true)
	party.name = "nav_party"
	party.tooltip_text = "调整编队与行装"
	root.add_child(party)
	place(party, Rect2(1110, 650, 154, 54), viewport)
	_style_command(party, viewport)
	return {"root":root, "map":map, "context":context, "detail":detail, "choices":choices,
		"actions":actions, "map_tools":map_tools, "choice_panel":choice_panel}

static func place(control: Control, bounds: Rect2, viewport: Vector2) -> void:
	control.position = bounds.position * viewport / BASE
	control.size = bounds.size * viewport / BASE

static func font_size(base: int, viewport: Vector2, minimum: int = 13) -> int:
	return maxi(minimum, int(round(base * clampf(minf(viewport.x / BASE.x, viewport.y / BASE.y), .78, 1.35))))

static func _panel(parent: Control, bounds: Rect2, viewport: Vector2, color: Color, padding: int, variant: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var inset := maxf(6.0, padding * minf(viewport.x / BASE.x, viewport.y / BASE.y))
	panel.add_theme_stylebox_override("panel", T.box(color, T.BORDER, inset))
	parent.add_child(panel)
	place(panel, bounds, viewport)
	T.FONT.apply_campaign_frame(panel, variant)
	return panel

static func _style_command(button: Button, viewport: Vector2) -> void:
	button.custom_minimum_size = Vector2.ZERO
	button.add_theme_font_size_override("font_size", font_size(18, viewport, 14))
	T.FONT.apply_campaign_frame(button, "button")

static func presenter_id(shell: Control) -> String:
	for id in shell.session.data.party:
		if str(id).begins_with("F") and shell.session.data.owned.has(id) and not bool(shell.session.data.owned[id].dead):
			return str(id)
	return "JIA"

static func _build_presenter(shell: Control, parent: Control, viewport: Vector2) -> void:
	var id := presenter_id(shell)
	var art := TextureRect.new()
	art.name = "campaign_presenter"
	art.texture = PORTRAITS.dialogue(id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(art)
	place(art, Rect2(-22, 154, 338, 550), viewport)
	var name_tag := T.label(str(shell.session.characters[id].name), font_size(18, viewport), T.LIGHT, true)
	name_tag.name = "campaign_presenter_name"
	name_tag.add_theme_color_override("font_outline_color", T.DARK)
	name_tag.add_theme_constant_override("outline_size", 4)
	parent.add_child(name_tag)
	place(name_tag, Rect2(26, 174, 200, 28), viewport)

static func _build_party(shell: Control, parent: Control, viewport: Vector2) -> void:
	var panel := _panel(parent, Rect2(464, 604, 620, 110), viewport, Color("121f19f5"), 8, "banner")
	panel.name = "campaign_party_status"
	var column := T.column(panel)
	column.add_theme_constant_override("separation", 3)
	var row := T.row(column)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 5)
	var ids: Array = ["JIA"]
	for id in shell.session.data.party: ids.append(str(id))
	while ids.size() < 3: ids.append("")
	var summary: Dictionary = shell.session.party_summary()
	for index in 3: _party_member(shell, row, str(ids[index]), index, viewport, summary)
	var equipment: Array[String] = []
	for item in summary.get("equipment", []): equipment.append(str(item.name))
	var gear := T.label("行装  " + " · ".join(equipment), font_size(12, viewport, 11), T.MUTED)
	gear.name = "campaign_equipment_summary"
	gear.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	gear.tooltip_text = " · ".join(equipment)
	column.add_child(gear)

static func _party_member(shell: Control, parent: Control, id: String, index: int, viewport: Vector2, summary: Dictionary) -> void:
	var tile := Button.new()
	tile.name = "campaign_member_" + str(index)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled"]:
		var surface := T.box(Color("2d382b") if state == "hover" else Color("18271f"), Color("7c7150"), 4)
		tile.add_theme_stylebox_override(state, surface)
	parent.add_child(tile)
	var owned: bool = not id.is_empty() and shell.session.data.owned.has(id)
	if not owned:
		tile.text = "辅助空位"
		tile.add_theme_font_size_override("font_size", font_size(14, viewport))
		tile.pressed.connect(func(): shell.open_page("roster"))
		return
	var record: Dictionary = shell.session.data.owned[id]
	var person: Dictionary = shell.session.characters[id]
	tile.pressed.connect(func():
		shell.inspect_character(id))
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 4)
	var row := T.row(margin)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 5)
	var portrait := TextureRect.new()
	portrait.texture = PORTRAITS.texture(id)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.custom_minimum_size.x = 44 * clampf(viewport.x / BASE.x, .75, 1.5)
	portrait.clip_contents = true
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.modulate = Color("8c8980") if bool(record.dead) else PORTRAITS.tint(id)
	row.add_child(portrait)
	var info := T.column(row)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 1)
	var title := T.label("%s  %s" % [person.name, "阵亡" if bool(record.dead) else "Lv.%d" % int(record.level)], font_size(13, viewport, 12), T.LIGHT)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(title)
	_resource(info, "生命", float(record.hp), float(shell.session.resource_max(id, "hp")), Color("94b486"), viewport)
	_resource(info, "魔法", float(record.mp), float(shell.session.resource_max(id, "mp")), Color("77acbf"), viewport)
	var tooltip := "%s · Lv.%d\n生命 %d / %d\n魔法 %d / %d" % [person.name, record.level, record.hp, shell.session.resource_max(id,"hp"), record.mp, shell.session.resource_max(id,"mp")]
	for support in summary.get("supports", []):
		if str(support.id) == id: tooltip += "\n" + str(support.title) + "\n" + str(support.text)
	tile.tooltip_text = tooltip

static func _resource(parent: Control, title: String, current: float, maximum: float, color: Color, viewport: Vector2) -> void:
	var bar := T.bar(parent, current, maximum, color.darkened(.6))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, font_size(16, viewport, 14))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := T.label("%s %d/%d" % [title, int(current), int(maximum)], font_size(11, viewport, 11), T.LIGHT)
	text.name = "campaign_hp_value" if title == "生命" else "campaign_mp_value"
	text.add_theme_color_override("font_outline_color", T.DARK)
	text.add_theme_constant_override("outline_size", 1)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(text)
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
