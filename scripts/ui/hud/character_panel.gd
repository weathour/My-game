extends CanvasLayer

signal close_requested

const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const PLAYER_EQUIPMENT_FLOW := preload("res://scripts/player/player_equipment_flow.gd")
const RUAN_STONE_SYSTEM := preload("res://scripts/player/ruan_stone_system.gd")
const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const ARCHIVE_ORNAMENT_LAYER := preload("res://scripts/ui/hud/archive_ornament_layer.gd")
const WHITE_KEY_SHADER := preload("res://shaders/white_key.gdshader")
const ARCHIVE_PORTRAIT_BACKDROP := preload("res://scripts/ui/hud/archive_portrait_backdrop.gd")

const GLOBAL_UNIT_MOVE_SPEED_SCALE := 0.7
const PANEL_MAX_SIZE := Vector2(1380.0, 780.0)
const PANEL_MIN_SIZE := Vector2(720.0, 430.0)
const PANEL_WIDTH_RATIO := 0.94
const PANEL_HEIGHT_RATIO := 0.96
const PANEL_EDGE_MARGIN := Vector2(14.0, 10.0)

const ROLE_TEXTURE_PATHS := {
	"swordsman": "人设草图/剑士草图.jpg",
	"gunner": "人设草图/枪手草图.jpg",
	"mage": "人设草图/术师草图.jpg",
	"mechanic": "人设草图/机械师草图.jpg"
}

const ROLE_PIXEL_TEXTURE_PATHS := {
	"swordsman": "res://assets/players/sword/剑-run.png",
	"gunner": "res://assets/players/gun/gun-run.png",
	"mage": "res://assets/players/wizard/wizard-run.png",
	"mechanic": "res://assets/players/mechanic/mechanic-run.png"
}

const ROLE_PIXEL_FRAME_RECTS := {
	"swordsman": Rect2(529.0, 21.0, 95.0, 89.0),
	"gunner": Rect2(542.0, 25.0, 69.0, 74.0),
	"mage": Rect2(314.0, 78.0, 133.0, 93.0),
	"mechanic": Rect2(57.0, 73.0, 135.0, 100.0)
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

var role_texture_rect: TextureRect
var role_title_label: Label
var role_subtitle_label: Label
var role_nav_list: VBoxContainer
var stats_label: RichTextLabel
var equipment_list: HBoxContainer
var blessing_list: VBoxContainer
var blessing_rows: Dictionary = {}
var blessing_role_group_header: Label
var blessing_skill_group_header: Label
var blessing_empty_label: Label
var skill_tree_selector_list: VBoxContainer
var skill_tree_detail: VBoxContainer
var blessing_scroll: ScrollContainer
var skill_tree_detail_scroll: ScrollContainer
var blessing_page: VBoxContainer
var skill_build_page: VBoxContainer
var blessing_tab_button: Button
var skill_build_tab_button: Button
var blessing_summary_label: Label
var skill_build_summary_label: Label
var panel_title_label: Label
var panel_role_pill_label: Label
var panel_status_label: Label
var ornament_layer: Control
var backdrop: ColorRect
var panel: Panel
var panel_margin: MarginContainer
var gift_popup: PopupMenu
var cached_player: Node
var viewed_role_index: int = 0
var pending_gift_equipment_id: String = ""
var pending_gift_from_role_id: String = ""
var gift_target_role_ids: Array[String] = []
var ui_white_key_material: ShaderMaterial
var role_pixel_texture_cache: Dictionary = {}
var archive_card_style_cache: Dictionary = {}
var selected_archive_tab := "build"
var selected_skill_tree_index := 0
var expanded_blessing_key := ""


func _archive_panel_style(
		bg_color: Color,
		border_color: Color = Color(0.82, 0.57, 0.22, 0.96),
		border_width: int = 1,
		corner_radius: int = 12,
		content_margin: float = 0.0,
		shadow_size: int = 8
) -> StyleBoxFlat:
	var style := SURVIVORS_THEME.panel_style(bg_color, border_color, border_width, corner_radius, content_margin)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0.0, 3.0)
	style.anti_aliasing = true
	return style

func _archive_card_style(selected: bool = false, accented: bool = false, disabled: bool = false) -> StyleBoxFlat:
	var cache_key := "normal:%s:%s:%s" % [selected, accented, disabled]
	if archive_card_style_cache.has(cache_key):
		return archive_card_style_cache[cache_key]
	var bg := Color(0.055, 0.073, 0.10, 0.96)
	var border := Color(0.43, 0.49, 0.60, 0.86)
	var border_width := 1
	if accented:
		bg = Color(0.055, 0.12, 0.075, 0.98)
		border = Color(0.42, 0.95, 0.50, 0.96)
		border_width = 2
	if selected:
		bg = Color(0.18, 0.12, 0.045, 0.98)
		border = Color(1.0, 0.78, 0.28, 1.0)
		border_width = 2
	if disabled:
		bg = bg.darkened(0.28)
		border = border.darkened(0.30)
	var style := _archive_panel_style(bg, border, border_width, 12, 8.0, 5)
	archive_card_style_cache[cache_key] = style
	return style

func _archive_card_hover_style(selected: bool = false, accented: bool = false) -> StyleBoxFlat:
	var cache_key := "hover:%s:%s" % [selected, accented]
	if archive_card_style_cache.has(cache_key):
		return archive_card_style_cache[cache_key]
	var style := _archive_card_style(selected, accented, false).duplicate() as StyleBoxFlat
	style.bg_color = style.bg_color.lightened(0.08)
	style.border_color = style.border_color.lightened(0.12)
	archive_card_style_cache[cache_key] = style
	return style

func _archive_card_pressed_style(selected: bool, accented: bool, disabled: bool) -> StyleBoxFlat:
	var cache_key := "pressed:%s:%s:%s" % [selected, accented, disabled]
	if archive_card_style_cache.has(cache_key):
		return archive_card_style_cache[cache_key]
	var style := _archive_card_style(selected, accented, disabled).duplicate() as StyleBoxFlat
	style.bg_color = style.bg_color.darkened(0.08)
	archive_card_style_cache[cache_key] = style
	return style

func _apply_archive_button_style(button: Button, selected: bool = false, accented: bool = false, disabled: bool = false) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", _archive_card_style(selected, accented, disabled))
	button.add_theme_stylebox_override("hover", _archive_card_hover_style(selected, accented))
	button.add_theme_stylebox_override("pressed", _archive_card_pressed_style(selected, accented, disabled))
	button.add_theme_stylebox_override("focus", _archive_card_hover_style(selected, accented))
	button.add_theme_stylebox_override("disabled", _archive_card_style(selected, accented, true))
	var font_color := SURVIVORS_THEME.COLOR_TEXT
	if accented:
		font_color = SURVIVORS_THEME.COLOR_TEXT_GOOD
	if selected:
		font_color = SURVIVORS_THEME.COLOR_TEXT_GOLD
	if disabled:
		font_color = Color(0.58, 0.62, 0.70, 0.8)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color.lightened(0.10))
	button.add_theme_color_override("font_pressed_color", font_color.darkened(0.08))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.64, 0.70))

func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.012, 0.018, 0.80)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	panel = Panel.new()
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	panel_margin = MarginContainer.new()
	panel_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_margin.add_theme_constant_override("margin_left", 16)
	panel_margin.add_theme_constant_override("margin_top", 12)
	panel_margin.add_theme_constant_override("margin_right", 16)
	panel_margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(panel_margin)

	ornament_layer = ARCHIVE_ORNAMENT_LAYER.new()
	ornament_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	ornament_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(ornament_layer)

	var root_layout := VBoxContainer.new()
	root_layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_layout.add_theme_constant_override("separation", 10)
	panel_margin.add_child(root_layout)

	_build_archive_header(root_layout)

	var content_layout := HBoxContainer.new()
	content_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_layout.add_theme_constant_override("separation", 10)
	root_layout.add_child(content_layout)

	_build_role_sidebar(content_layout)
	_build_role_detail_column(content_layout)
	_build_build_detail_column(content_layout)
	_build_archive_footer(root_layout)

	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	_layout_panel.call_deferred()

	gift_popup = PopupMenu.new()
	gift_popup.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	gift_popup.index_pressed.connect(_on_gift_popup_index_pressed)
	add_child(gift_popup)

	hide_panel()

func _build_archive_header(root_layout: VBoxContainer) -> void:
	var header := PanelContainer.new()
	header.custom_minimum_size = Vector2(0.0, 52.0)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_stylebox_override("panel", _archive_panel_style(Color(0.025, 0.035, 0.055, 0.98), Color(0.95, 0.68, 0.24, 1.0), 2, 12, 10.0, 10))
	root_layout.add_child(header)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	header.add_child(row)

	var archive_label := Label.new()
	archive_label.text = "构筑档案"
	archive_label.custom_minimum_size = Vector2(170.0, 0.0)
	archive_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	archive_label.add_theme_font_size_override("font_size", 22)
	archive_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	row.add_child(archive_label)

	panel_title_label = Label.new()
	panel_title_label.text = "角色构筑"
	panel_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel_title_label.add_theme_font_size_override("font_size", 28)
	panel_title_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	row.add_child(panel_title_label)

	panel_role_pill_label = Label.new()
	panel_role_pill_label.custom_minimum_size = Vector2(190.0, 0.0)
	panel_role_pill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_role_pill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel_role_pill_label.add_theme_font_size_override("font_size", 18)
	panel_role_pill_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOOD)
	row.add_child(panel_role_pill_label)

	panel_status_label = Label.new()
	panel_status_label.custom_minimum_size = Vector2(160.0, 0.0)
	panel_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel_status_label.add_theme_font_size_override("font_size", 16)
	panel_status_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	row.add_child(panel_status_label)

	var close_button := Button.new()
	close_button.text = "C 关闭"
	close_button.custom_minimum_size = Vector2(86.0, 34.0)
	SURVIVORS_THEME.apply_button_style(close_button, "normal", false)
	close_button.pressed.connect(_request_close)
	row.add_child(close_button)

func _build_role_sidebar(content_layout: HBoxContainer) -> void:
	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size = Vector2(150.0, 0.0)
	sidebar.size_flags_horizontal = Control.SIZE_FILL
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_stylebox_override("panel", _archive_panel_style(Color(0.018, 0.030, 0.046, 0.98), Color(0.84, 0.58, 0.22, 0.96), 2, 12, 8.0, 9))
	content_layout.add_child(sidebar)

	var side_box := VBoxContainer.new()
	side_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_box.add_theme_constant_override("separation", 8)
	sidebar.add_child(side_box)

	var title := Label.new()
	title.text = "队伍"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	side_box.add_child(title)

	role_nav_list = VBoxContainer.new()
	role_nav_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_nav_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	role_nav_list.add_theme_constant_override("separation", 10)
	side_box.add_child(role_nav_list)
	var initial_role_count: int = max(_get_roles().size(), 3)
	for index in range(initial_role_count):
		role_nav_list.add_child(_make_role_card(index))

func _build_role_detail_column(content_layout: HBoxContainer) -> void:
	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(410.0, 0.0)
	detail_panel.size_flags_horizontal = Control.SIZE_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _archive_panel_style(Color(0.035, 0.048, 0.067, 0.97), Color(0.86, 0.62, 0.27, 0.96), 2, 14, 10.0, 10))
	content_layout.add_child(detail_panel)

	var detail_box := VBoxContainer.new()
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_box.add_theme_constant_override("separation", 8)
	detail_panel.add_child(detail_box)

	var hero_frame := PanelContainer.new()
	hero_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero_frame.custom_minimum_size = Vector2(0.0, 178.0)
	hero_frame.add_theme_stylebox_override("panel", _archive_panel_style(Color(0.025, 0.035, 0.052, 0.94), Color(0.76, 0.52, 0.20, 0.92), 1, 12, 8.0, 7))
	detail_box.add_child(hero_frame)

	var portrait_backdrop := ARCHIVE_PORTRAIT_BACKDROP.new()
	portrait_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_frame.add_child(portrait_backdrop)

	var hero_box := VBoxContainer.new()
	hero_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero_box.add_theme_constant_override("separation", 3)
	hero_frame.add_child(hero_box)

	role_texture_rect = TextureRect.new()
	role_texture_rect.custom_minimum_size = Vector2(0.0, 116.0)
	role_texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	role_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	role_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_box.add_child(role_texture_rect)

	role_title_label = Label.new()
	role_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_title_label.add_theme_font_size_override("font_size", 23)
	role_title_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	hero_box.add_child(role_title_label)

	role_subtitle_label = Label.new()
	role_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_subtitle_label.add_theme_font_size_override("font_size", 14)
	role_subtitle_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	hero_box.add_child(role_subtitle_label)

	var stats_section := _make_panel_section("核心属性")
	stats_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_section.custom_minimum_size = Vector2(0.0, 176.0)
	detail_box.add_child(stats_section)

	var stats_body := _get_section_body(stats_section)
	stats_label = RichTextLabel.new()
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_label.custom_minimum_size = Vector2(0.0, 118.0)
	stats_label.bbcode_enabled = true
	stats_label.fit_content = false
	stats_label.scroll_active = true
	SURVIVORS_THEME.apply_rich_label_font(stats_label, 15)
	stats_body.add_child(stats_label)

	var equipment_section := _make_panel_section("装备")
	equipment_section.size_flags_vertical = Control.SIZE_FILL
	equipment_section.custom_minimum_size = Vector2(0.0, 104.0)
	detail_box.add_child(equipment_section)

	var equipment_body := _get_section_body(equipment_section)
	var equipment_hint := Label.new()
	equipment_hint.text = "阮石全队共享 · 右键普通道具可赠与其他角色"
	equipment_hint.add_theme_font_size_override("font_size", 12)
	equipment_hint.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	equipment_body.add_child(equipment_hint)

	var equipment_scroll := ScrollContainer.new()
	equipment_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipment_scroll.custom_minimum_size = Vector2(0.0, 58.0)
	equipment_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	equipment_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	equipment_body.add_child(equipment_scroll)

	equipment_list = HBoxContainer.new()
	equipment_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_list.add_theme_constant_override("separation", 8)
	equipment_scroll.add_child(equipment_list)

func _build_build_detail_column(content_layout: HBoxContainer) -> void:
	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_layout.add_child(right_column)

	var archive_section := _make_panel_section("战斗档案")
	archive_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	archive_section.custom_minimum_size = Vector2(0.0, 470.0)
	right_column.add_child(archive_section)
	var archive_body := _get_section_body(archive_section)

	var tab_row := HBoxContainer.new()
	tab_row.name = "ArchiveTabRow"
	tab_row.custom_minimum_size = Vector2(0.0, 42.0)
	tab_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_row.add_theme_constant_override("separation", 8)
	archive_body.add_child(tab_row)

	skill_build_tab_button = Button.new()
	skill_build_tab_button.name = "BuildTabButton"
	skill_build_tab_button.text = "技能构筑  6"
	skill_build_tab_button.toggle_mode = true
	skill_build_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_build_tab_button.custom_minimum_size = Vector2(0.0, 42.0)
	skill_build_tab_button.pressed.connect(_set_archive_tab.bind("build"))
	_apply_archive_button_style(skill_build_tab_button)
	skill_build_tab_button.add_theme_stylebox_override("pressed", _archive_card_style(true))
	skill_build_tab_button.add_theme_color_override("font_pressed_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	tab_row.add_child(skill_build_tab_button)

	blessing_tab_button = Button.new()
	blessing_tab_button.name = "BlessingTabButton"
	blessing_tab_button.text = "祝福账本  0"
	blessing_tab_button.toggle_mode = true
	blessing_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blessing_tab_button.custom_minimum_size = Vector2(0.0, 42.0)
	blessing_tab_button.pressed.connect(_set_archive_tab.bind("blessing"))
	_apply_archive_button_style(blessing_tab_button)
	blessing_tab_button.add_theme_stylebox_override("pressed", _archive_card_style(true))
	blessing_tab_button.add_theme_color_override("font_pressed_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	tab_row.add_child(blessing_tab_button)

	skill_build_page = VBoxContainer.new()
	skill_build_page.name = "SkillBuildPage"
	skill_build_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_build_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skill_build_page.add_theme_constant_override("separation", 8)
	archive_body.add_child(skill_build_page)

	skill_build_summary_label = Label.new()
	skill_build_summary_label.text = "6 个技能构筑 · 查看普通构筑等级和强化"
	skill_build_summary_label.add_theme_font_size_override("font_size", 14)
	skill_build_summary_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	skill_build_page.add_child(skill_build_summary_label)

	var skill_tree_workspace := HBoxContainer.new()
	skill_tree_workspace.name = "SkillTreeWorkspace"
	skill_tree_workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_tree_workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skill_tree_workspace.add_theme_constant_override("separation", 8)
	skill_build_page.add_child(skill_tree_workspace)

	var selector_scroll := ScrollContainer.new()
	selector_scroll.name = "SkillTreeSelectorScroll"
	selector_scroll.custom_minimum_size = Vector2(150.0, 0.0)
	selector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selector_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	selector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	skill_tree_workspace.add_child(selector_scroll)

	skill_tree_selector_list = VBoxContainer.new()
	skill_tree_selector_list.name = "SkillTreeSelectorList"
	skill_tree_selector_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_tree_selector_list.add_theme_constant_override("separation", 6)
	selector_scroll.add_child(skill_tree_selector_list)
	_build_skill_tree_selectors()

	skill_tree_detail_scroll = ScrollContainer.new()
	skill_tree_detail_scroll.name = "SkillTreeDetailScroll"
	skill_tree_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_tree_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skill_tree_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	skill_tree_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	skill_tree_workspace.add_child(skill_tree_detail_scroll)

	skill_tree_detail = VBoxContainer.new()
	skill_tree_detail.name = "SkillTreeDetail"
	skill_tree_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_tree_detail.add_theme_constant_override("separation", 7)
	skill_tree_detail_scroll.add_child(skill_tree_detail)
	_build_skill_tree_detail_shell()

	blessing_page = VBoxContainer.new()
	blessing_page.name = "BlessingPage"
	blessing_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blessing_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	blessing_page.add_theme_constant_override("separation", 8)
	archive_body.add_child(blessing_page)

	blessing_summary_label = Label.new()
	blessing_summary_label.text = "0 项祝福 · 各阶独立持有，不提供合成"
	blessing_summary_label.add_theme_font_size_override("font_size", 14)
	blessing_summary_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	blessing_page.add_child(blessing_summary_label)

	blessing_scroll = ScrollContainer.new()
	blessing_scroll.name = "BlessingScroll"
	blessing_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blessing_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	blessing_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	blessing_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	blessing_page.add_child(blessing_scroll)

	blessing_list = VBoxContainer.new()
	blessing_list.name = "BlessingList"
	blessing_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blessing_list.add_theme_constant_override("separation", 8)
	blessing_scroll.add_child(blessing_list)
	_build_blessing_list_shell()

	_set_archive_tab("build")

func _build_archive_footer(root_layout: VBoxContainer) -> void:
	var footer := HBoxContainer.new()
	footer.custom_minimum_size = Vector2(0.0, 22.0)
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_layout.add_child(footer)

	var hint := Label.new()
	hint.text = "Ctrl+Tab 切换技能与祝福 · 指向技能查看天赋树 · 装备行右键赠与"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	footer.add_child(hint)


func _set_archive_tab(tab_id: String) -> void:
	selected_archive_tab = "blessing" if tab_id == "blessing" else "build"
	if skill_build_page != null:
		skill_build_page.visible = selected_archive_tab == "build"
	if blessing_page != null:
		blessing_page.visible = selected_archive_tab == "blessing"
	if skill_build_tab_button != null:
		skill_build_tab_button.button_pressed = selected_archive_tab == "build"
	if blessing_tab_button != null:
		blessing_tab_button.button_pressed = selected_archive_tab == "blessing"


func _reset_archive_scrolls() -> void:
	if skill_tree_detail_scroll != null:
		skill_tree_detail_scroll.scroll_vertical = 0
	if blessing_scroll != null:
		blessing_scroll.scroll_vertical = 0


func show_for_player(player: Node) -> void:
	cached_player = player
	if cached_player != null and is_instance_valid(cached_player):
		viewed_role_index = clamp(int(cached_player.get("active_role_index")), 0, max(0, _get_roles().size() - 1))
	refresh()
	visible = true
	_layout_panel.call_deferred()

func hide_panel() -> void:
	visible = false
	if gift_popup != null:
		gift_popup.hide()

func _request_close() -> void:
	close_requested.emit()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if GAME_SETTINGS.event_matches_action(event, GAME_SETTINGS.ACTION_CHARACTER_PANEL):
		close_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.ctrl_pressed and key_event.keycode == KEY_TAB:
			var next_tab := "blessing" if selected_archive_tab == "build" else "build"
			_set_archive_tab(next_tab)
			(blessing_tab_button if next_tab == "blessing" else skill_build_tab_button).grab_focus()
			get_viewport().set_input_as_handled()

func refresh() -> void:
	if cached_player == null or not is_instance_valid(cached_player):
		return
	var roles: Array = _get_roles()
	if roles.is_empty():
		return
	viewed_role_index = clamp(viewed_role_index, 0, roles.size() - 1)
	var role_data: Dictionary = roles[viewed_role_index]
	var role_id: String = str(role_data.get("id", "swordsman"))
	var role_name: String = str(role_data.get("name", "角色"))
	var is_active := viewed_role_index == int(cached_player.get("active_role_index"))
	role_title_label.text = "%s  Lv.%d" % [role_name, int(cached_player.get("level"))]
	role_subtitle_label.text = "%s%s" % [str(ROLE_TAGLINES.get(role_id, "构筑角色")), " · 当前站场" if is_active else " · 查看中"]
	_apply_role_texture(role_texture_rect, role_id, true)
	panel_role_pill_label.text = "%s · %s" % [role_name, "当前" if is_active else "查看"]
	panel_status_label.text = "战斗暂停中"
	_refresh_role_cards()
	stats_label.text = _build_stats_text(role_data)
	_refresh_equipment_list(role_id)
	_refresh_skill_build_list(role_id)
	_refresh_blessing_list(role_id)

func _make_panel_section(title: String) -> PanelContainer:
	var section := PanelContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_stylebox_override("panel", _archive_panel_style(Color(0.040, 0.055, 0.078, 0.96), Color(0.48, 0.55, 0.66, 0.86), 1, 10, 10.0, 6))
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	section.add_child(box)
	var title_label := Label.new()
	title_label.text = "◇ %s" % title
	title_label.add_theme_font_size_override("font_size", 21)
	title_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	box.add_child(title_label)
	return section

func _get_section_body(section: PanelContainer) -> VBoxContainer:
	return section.get_child(0) as VBoxContainer

func _on_viewport_size_changed() -> void:
	_layout_panel.call_deferred()

func _layout_panel() -> void:
	if panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var available := Vector2(
		max(1.0, viewport_size.x - PANEL_EDGE_MARGIN.x * 2.0),
		max(1.0, viewport_size.y - PANEL_EDGE_MARGIN.y * 2.0)
	)
	var target_size := Vector2(
		clamp(viewport_size.x * PANEL_WIDTH_RATIO, min(PANEL_MIN_SIZE.x, available.x), min(PANEL_MAX_SIZE.x, available.x)),
		clamp(viewport_size.y * PANEL_HEIGHT_RATIO, min(PANEL_MIN_SIZE.y, available.y), min(PANEL_MAX_SIZE.y, available.y))
	)
	panel.size = target_size
	panel.position = Vector2(
		floor((viewport_size.x - target_size.x) * 0.5),
		max(PANEL_EDGE_MARGIN.y, floor((viewport_size.y - target_size.y) * 0.5))
	)
	panel.add_theme_stylebox_override("panel", _archive_panel_style(Color(0.014, 0.024, 0.038, 0.98), Color(0.95, 0.68, 0.23, 1.0), 2, 16, 0.0, 14))

func _refresh_role_cards() -> void:
	if role_nav_list == null:
		return
	var roles: Array = _get_roles()
	if role_nav_list.get_child_count() != roles.size():
		for child in role_nav_list.get_children():
			role_nav_list.remove_child(child)
			child.queue_free()
		for index in range(roles.size()):
			role_nav_list.add_child(_make_role_card(index))
	var active_index: int = int(cached_player.get("active_role_index"))
	for index in range(roles.size()):
		var role: Dictionary = roles[index]
		_update_role_card(role_nav_list.get_child(index) as PanelContainer, role, index, active_index)

func _make_role_card(index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "RoleCard%d" % index
	card.custom_minimum_size = Vector2(0.0, 124.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _archive_card_style())
	card.gui_input.connect(_on_role_card_gui_input.bind(index))

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	var texture_rect := TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(0.0, 60.0)
	texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(texture_rect)

	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 19)
	box.add_child(name_label)

	var status_label := Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	box.add_child(status_label)
	return card

func _update_role_card(card: PanelContainer, role: Dictionary, index: int, active_index: int) -> void:
	var role_id := str(role.get("id", "swordsman"))
	var selected := index == viewed_role_index
	var active := index == active_index
	var box := card.get_child(0) as VBoxContainer
	var texture_rect := box.get_child(0) as TextureRect
	var name_label := box.get_child(1) as Label
	var status_label := box.get_child(2) as Label
	card.name = "RoleCard_%s" % role_id
	card.tooltip_text = "点击查看 %s 构筑" % str(role.get("name", role_id))
	name_label.text = str(role.get("name", role_id))
	var visual_state := "%s:%s:%s" % [role_id, selected, active]
	if str(card.get_meta("visual_state", "")) == visual_state:
		return
	card.set_meta("visual_state", visual_state)
	card.add_theme_stylebox_override("panel", _archive_card_style(selected, active, false))
	_apply_role_texture(texture_rect, role_id, active or selected)
	name_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD if selected else SURVIVORS_THEME.COLOR_TEXT)
	status_label.text = "当前" if active else "待命"
	status_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOOD if active else SURVIVORS_THEME.COLOR_TEXT_MUTED)

func _on_role_card_gui_input(event: InputEvent, role_index: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_view_role(role_index)

func _view_role(role_index: int) -> void:
	viewed_role_index = role_index
	expanded_blessing_key = ""
	refresh()
	_reset_archive_scrolls.call_deferred()

func _refresh_equipment_list(role_id: String) -> void:
	for child in equipment_list.get_children():
		equipment_list.remove_child(child)
		child.queue_free()
	var stone_id: String = str(cached_player.get_equipped_ruan_stone()) if cached_player.has_method("get_equipped_ruan_stone") else ""
	var stone_level: int = int(cached_player.get_ruan_stone_level(stone_id)) if stone_id != "" and cached_player.has_method("get_ruan_stone_level") else 0
	var stone_definition: Dictionary = RUAN_STONE_SYSTEM.get_definition(stone_id)
	var stone_title: String = str(stone_definition.get("title", "未装备"))
	var stone_effect: String = RUAN_STONE_SYSTEM.get_effect_text(stone_id, stone_level) if stone_level > 0 else "在阮狗处装备已拥有的石头"
	var stone_button := Button.new()
	stone_button.name = "RuanStoneSlot"
	stone_button.text = "全队 · 阮石槽\n%s%s\n%s" % [
		stone_title,
		" Lv.%d" % stone_level if stone_level > 0 else "",
		stone_effect
	]
	stone_button.tooltip_text = "全队共享，不可赠与\n骨头：%d\n%s" % [
		cached_player.get_ruan_bone_count() if cached_player.has_method("get_ruan_bone_count") else 0,
		stone_effect
	]
	stone_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	stone_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stone_button.custom_minimum_size = Vector2(210.0, 58.0)
	stone_button.focus_mode = Control.FOCUS_NONE
	_apply_archive_button_style(stone_button, stone_level > 0, false, false)
	equipment_list.add_child(stone_button)
	var equipment_levels: Dictionary = cached_player._get_role_equipment_levels(role_id) if cached_player.has_method("_get_role_equipment_levels") else {}
	var has_any := false
	for equipment_id in PLAYER_EQUIPMENT_FLOW.EQUIPMENT_DEFINITIONS.keys():
		var count: int = int(equipment_levels.get(str(equipment_id), 0))
		if count <= 0:
			continue
		has_any = true
		var definition: Dictionary = PLAYER_EQUIPMENT_FLOW.EQUIPMENT_DEFINITIONS.get(str(equipment_id), {})
		var button := Button.new()
		button.text = "%s\nLv.%d" % [str(definition.get("title", equipment_id)), count]
		button.tooltip_text = "%s\n当前角色持有 %d 个；右键可赠与其中 1 个。" % [
			str(definition.get("description", "")),
			count
		]
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.custom_minimum_size = Vector2(74.0, 42.0)
		button.size_flags_horizontal = Control.SIZE_FILL
		_apply_archive_button_style(button, false, count >= PLAYER_EQUIPMENT_FLOW.EQUIPMENT_MAX_LEVEL, false)
		button.gui_input.connect(_on_equipment_gui_input.bind(str(equipment_id), role_id))
		equipment_list.add_child(button)
	if not has_any:
		var empty_label := Label.new()
		empty_label.text = "当前角色暂无普通道具"
		empty_label.custom_minimum_size = Vector2(0.0, 58.0)
		empty_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
		equipment_list.add_child(empty_label)

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

func _build_skill_tree_selectors() -> void:
	var selector_count := 0
	for progress_order_value in PLAYER_SKILL_TALENT_SYSTEM.ROLE_PROGRESS_ORDER.values():
		if progress_order_value is Array:
			selector_count = maxi(selector_count, progress_order_value.size())
	for index in range(selector_count):
		var button := Button.new()
		button.name = "SkillTreeSelector%d" % index
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(142.0, 62.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
		_apply_archive_button_style(button)
		button.add_theme_stylebox_override("pressed", _archive_card_style(true))
		button.add_theme_color_override("font_pressed_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
		button.pressed.connect(_select_skill_tree.bind(index))
		button.mouse_entered.connect(_select_skill_tree.bind(index))
		button.focus_entered.connect(_select_skill_tree.bind(index))
		skill_tree_selector_list.add_child(button)

func _refresh_skill_build_list(role_id: String) -> void:
	var progress_ids: Array = PLAYER_SKILL_TALENT_SYSTEM.ROLE_PROGRESS_ORDER.get(role_id, [])
	if progress_ids.is_empty():
		return
	selected_skill_tree_index = clamp(selected_skill_tree_index, 0, progress_ids.size() - 1)
	for index in range(skill_tree_selector_list.get_child_count()):
		var button := skill_tree_selector_list.get_child(index) as Button
		if button == null:
			continue
		button.visible = index < progress_ids.size()
		if index >= progress_ids.size():
			button.button_pressed = false
	for index in range(progress_ids.size()):
		var progress_id_value: Variant = progress_ids[index]
		var progress_id := str(progress_id_value)
		var display := PLAYER_SKILL_TALENT_SYSTEM.get_display(cached_player, role_id, progress_id)
		var level := PLAYER_SKILL_TALENT_SYSTEM.get_skill_progress_level(cached_player, role_id, progress_id)
		var button := skill_tree_selector_list.get_child(index) as Button
		button.name = "SkillTreeSelector_%s" % progress_id
		button.text = "%s\n%s\n%s" % [
			_get_skill_slot_label(progress_id, index),
			str(display.get("name", PLAYER_SKILL_TALENT_SYSTEM.PROGRESS_TITLES.get(progress_id, progress_id))),
			"尚未解锁" if level <= 0 else "构筑 Lv.%d" % level
		]
		button.tooltip_text = button.text
		button.button_pressed = index == selected_skill_tree_index
		button.modulate = Color(0.70, 0.72, 0.78, 0.72) if level <= 0 else Color.WHITE
	skill_build_summary_label.text = "%d 个技能构筑 · 普通构筑等级与强化列表" % progress_ids.size()
	skill_build_tab_button.text = "技能构筑  %d" % progress_ids.size()
	_refresh_skill_tree_detail(role_id, str(progress_ids[selected_skill_tree_index]))

func _select_skill_tree(index: int) -> void:
	var role_id := _get_viewed_role_id()
	var progress_ids: Array = PLAYER_SKILL_TALENT_SYSTEM.ROLE_PROGRESS_ORDER.get(role_id, [])
	if index < 0 or index >= progress_ids.size():
		return
	var selected_button := skill_tree_selector_list.get_child(index) as Button
	if index == selected_skill_tree_index:
		selected_button.button_pressed = true
		return
	var previous_index := selected_skill_tree_index
	selected_skill_tree_index = index
	(skill_tree_selector_list.get_child(previous_index) as Button).button_pressed = false
	selected_button.button_pressed = true
	_refresh_skill_tree_detail(role_id, str(progress_ids[selected_skill_tree_index]))
	skill_tree_detail_scroll.scroll_vertical = 0

func _build_skill_tree_detail_shell() -> void:
	var header := PanelContainer.new()
	header.name = "SkillTreeHeader"
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_stylebox_override("panel", _archive_card_style(true))
	skill_tree_detail.add_child(header)
	var header_box := VBoxContainer.new()
	header_box.name = "Content"
	header_box.add_theme_constant_override("separation", 3)
	header.add_child(header_box)
	var title_label := Label.new()
	title_label.name = "Title"
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 19)
	title_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	header_box.add_child(title_label)
	var state_label := Label.new()
	state_label.name = "SkillTreePathLabel"
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state_label.add_theme_font_size_override("font_size", 13)
	state_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	header_box.add_child(state_label)

	var build_panel := PanelContainer.new()
	build_panel.name = "SkillTreeBuildDetails"
	build_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_panel.add_theme_stylebox_override("panel", _archive_card_style())
	skill_tree_detail.add_child(build_panel)
	var build_box := VBoxContainer.new()
	build_box.name = "Content"
	build_box.add_theme_constant_override("separation", 5)
	build_panel.add_child(build_box)
	var build_title := Label.new()
	build_title.text = "普通构筑（与天赋节点分离）"
	build_title.add_theme_font_size_override("font_size", 15)
	build_title.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	build_box.add_child(build_title)
	var requirement_label := Label.new()
	requirement_label.name = "Requirement"
	requirement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	requirement_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	requirement_label.visible = false
	build_box.add_child(requirement_label)
	var build_entries_label := Label.new()
	build_entries_label.name = "Entries"
	build_entries_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_entries_label.add_theme_font_size_override("font_size", 13)
	build_entries_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT)
	build_box.add_child(build_entries_label)
	var upgrade_note := Label.new()
	upgrade_note.name = "SkillTreeUpgradeNote"
	upgrade_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrade_note.add_theme_font_size_override("font_size", 13)
	build_box.add_child(upgrade_note)

func _refresh_skill_tree_detail(role_id: String, progress_id: String) -> void:
	var display := PLAYER_SKILL_TALENT_SYSTEM.get_display(cached_player, role_id, progress_id)
	var level := PLAYER_SKILL_TALENT_SYSTEM.get_skill_progress_level(cached_player, role_id, progress_id)
	var build_entries := _get_projected_build_entries(role_id, progress_id)

	var header := skill_tree_detail.get_node("SkillTreeHeader") as PanelContainer
	var title_label := header.get_node("Content/Title") as Label
	var state_label := header.get_node("Content/SkillTreePathLabel") as Label
	header.modulate = Color(0.72, 0.75, 0.82, 0.78) if level <= 0 else Color.WHITE
	title_label.text = "[%s]  %s" % [
		_get_skill_slot_label(progress_id, selected_skill_tree_index),
		str(display.get("name", PLAYER_SKILL_TALENT_SYSTEM.PROGRESS_TITLES.get(progress_id, progress_id)))
	]
	state_label.text = "尚未解锁 · 普通构筑未生效" if level <= 0 else "构筑 Lv.%d · 普通构筑强化" % level

	var build_panel := skill_tree_detail.get_node("SkillTreeBuildDetails") as PanelContainer
	var requirement_label := build_panel.get_node("Content/Requirement") as Label
	var build_entries_label := build_panel.get_node("Content/Entries") as Label
	var upgrade_note := build_panel.get_node("Content/SkillTreeUpgradeNote") as Label
	build_panel.modulate = Color(0.72, 0.75, 0.82, 0.78) if level <= 0 else Color.WHITE
	requirement_label.text = "解锁条件：%s" % _get_skill_unlock_requirement(progress_id) if level <= 0 else ""
	requirement_label.visible = requirement_label.text != ""
	var build_lines: Array[String] = []
	if build_entries.is_empty():
		build_lines.append("暂无普通构筑强化。天赋选择不计入此列表。")
	else:
		for entry in build_entries:
			var title := str(entry.get("title", entry.get("build_id", "")))
			var summary := _get_projected_build_summary(entry, str(display.get("upgrade_note", "")))
			build_lines.append("• %s ×%d" % [title, int(entry.get("count", 0))])
			if summary != "" and summary != title:
				build_lines.append("  %s" % summary)
	build_entries_label.text = "\n".join(build_lines)
	build_entries_label.custom_minimum_size.y = 54.0 if build_entries.is_empty() else 0.0
	if level <= 0:
		upgrade_note.text = "先解锁该技能；解锁后获得的普通构筑才会推进其构筑等级。"
		upgrade_note.modulate = SURVIVORS_THEME.COLOR_TEXT_MUTED
	elif build_entries.is_empty():
		upgrade_note.text = "继续获得该技能的普通构筑会在这里累计显示。"
		upgrade_note.modulate = SURVIVORS_THEME.COLOR_TEXT_MUTED
	else:
		upgrade_note.text = "等级天赋已从旧技能路径迁移；这里仅显示普通构筑。"
		upgrade_note.modulate = SURVIVORS_THEME.COLOR_TEXT_MUTED

func _get_projected_build_entries(role_id: String, progress_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in PLAYER_BUILD_SYSTEM.get_progress_build_entries(cached_player, role_id, progress_id):
		var projected := PLAYER_SKILL_TALENT_SYSTEM.project_build_option(cached_player, entry)
		projected["count"] = int(entry.get("count", 0))
		result.append(projected)
	return result

func _get_projected_build_summary(entry: Dictionary, upgrade_note: String) -> String:
	var summary := str(entry.get("summary", entry.get("title", "")))
	var suffix := "；%s" % upgrade_note
	if upgrade_note != "" and summary.ends_with(suffix):
		summary = summary.trim_suffix(suffix)
	return summary

func _get_stage_roman(stage_number: int) -> String:
	return ["I", "II", "III"][clampi(stage_number, 1, 3) - 1]

func _get_skill_slot_label(progress_id: String, slot_index: int = -1) -> String:
	if progress_id.ends_with("_trait"):
		return "特性"
	if progress_id.ends_with("_entry"):
		return "入场"
	if progress_id.ends_with("_basic"):
		return "普攻"
	if progress_id.ends_with("_ultimate"):
		return "终结"
	if slot_index == 3:
		return "主动一"
	if slot_index == 4:
		return "主动二"
	return "技能"

func _get_skill_unlock_requirement(progress_id: String) -> String:
	var skill_id := str(PLAYER_SKILL_TALENT_SYSTEM.UNLOCKABLE_PROGRESS.get(progress_id, ""))
	if skill_id != "" and cached_player.has_method("get_skill_next_requirement_text"):
		return str(cached_player.get_skill_next_requirement_text(skill_id))
	return "该技能尚未解锁。"

func _build_blessing_list_shell() -> void:
	blessing_role_group_header = _make_blessing_group_header("", 0)
	blessing_role_group_header.name = "BlessingRoleGroupHeader"
	blessing_role_group_header.visible = false
	blessing_list.add_child(blessing_role_group_header)
	for blessing_id in PLAYER_BLESSING_SYSTEM.DEFINITIONS.keys():
		var definition: Dictionary = PLAYER_BLESSING_SYSTEM.DEFINITIONS.get(str(blessing_id), {})
		if str(definition.get("binding", PLAYER_BLESSING_SYSTEM.ROLE_BOUND)) == PLAYER_BLESSING_SYSTEM.ROLE_BOUND:
			_add_blessing_row_shell(str(blessing_id), PLAYER_BLESSING_SYSTEM.ROLE_BOUND)
	blessing_skill_group_header = _make_blessing_group_header("", 0)
	blessing_skill_group_header.name = "BlessingSkillGroupHeader"
	blessing_skill_group_header.visible = false
	blessing_list.add_child(blessing_skill_group_header)
	for blessing_id in PLAYER_BLESSING_SYSTEM.DEFINITIONS.keys():
		var definition: Dictionary = PLAYER_BLESSING_SYSTEM.DEFINITIONS.get(str(blessing_id), {})
		if str(definition.get("binding", PLAYER_BLESSING_SYSTEM.ROLE_BOUND)) == PLAYER_BLESSING_SYSTEM.SKILL_BOUND:
			_add_blessing_row_shell(str(blessing_id), PLAYER_BLESSING_SYSTEM.SKILL_BOUND)
	blessing_empty_label = _make_archive_empty_label("")
	blessing_empty_label.name = "BlessingEmptyLabel"
	blessing_empty_label.visible = false
	blessing_list.add_child(blessing_empty_label)

func _add_blessing_row_shell(blessing_id: String, binding: String) -> void:
	var expanded_key := "%s:%s" % [binding, blessing_id]
	var button := Button.new()
	button.name = "BlessingRow_%s" % blessing_id
	button.toggle_mode = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(0.0, 68.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)
	_apply_archive_button_style(button)
	button.add_theme_stylebox_override("pressed", _archive_card_style(true))
	button.add_theme_color_override("font_pressed_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	button.pressed.connect(_toggle_blessing_row.bind(expanded_key))
	button.visible = false
	blessing_rows[blessing_id] = button
	blessing_list.add_child(button)

func _refresh_blessing_list(role_id: String) -> void:
	var role_levels: Dictionary = cached_player.get_role_blessing_levels(role_id) if cached_player.has_method("get_role_blessing_levels") else {}
	var skill_levels: Dictionary = cached_player.get_skill_blessing_levels() if cached_player.has_method("get_skill_blessing_levels") else {}
	var role_count := _count_owned_blessings(role_levels, PLAYER_BLESSING_SYSTEM.ROLE_BOUND)
	var skill_count := _count_owned_blessings(skill_levels, PLAYER_BLESSING_SYSTEM.SKILL_BOUND)
	blessing_role_group_header.text = "团队共享 · 角色祝福（三角色生效） · %d 项" % role_count if role_count > 0 else ""
	blessing_role_group_header.visible = role_count > 0
	for blessing_id in PLAYER_BLESSING_SYSTEM.DEFINITIONS.keys():
		var definition: Dictionary = PLAYER_BLESSING_SYSTEM.DEFINITIONS.get(str(blessing_id), {})
		if str(definition.get("binding", PLAYER_BLESSING_SYSTEM.ROLE_BOUND)) != PLAYER_BLESSING_SYSTEM.ROLE_BOUND:
			continue
		_update_blessing_row(str(blessing_id), definition, role_levels, PLAYER_BLESSING_SYSTEM.ROLE_BOUND)
	blessing_skill_group_header.text = "技能绑定祝福 · 按技能类型生效 · %d 项" % skill_count if skill_count > 0 else ""
	blessing_skill_group_header.visible = skill_count > 0
	for blessing_id in PLAYER_BLESSING_SYSTEM.DEFINITIONS.keys():
		var definition: Dictionary = PLAYER_BLESSING_SYSTEM.DEFINITIONS.get(str(blessing_id), {})
		if str(definition.get("binding", PLAYER_BLESSING_SYSTEM.ROLE_BOUND)) != PLAYER_BLESSING_SYSTEM.SKILL_BOUND:
			continue
		_update_blessing_row(str(blessing_id), definition, skill_levels, PLAYER_BLESSING_SYSTEM.SKILL_BOUND)
	var total_count := role_count + skill_count
	blessing_empty_label.text = "暂无祝福。通用祝福会在升级奖励中出现。" if total_count <= 0 else ""
	blessing_empty_label.visible = total_count <= 0
	blessing_summary_label.text = "%d 项祝福 · 各阶独立持有，不提供合成" % total_count
	blessing_tab_button.text = "祝福账本  %d" % total_count

func _update_blessing_row(blessing_id: String, definition: Dictionary, levels: Dictionary, binding: String) -> bool:
	var button := blessing_rows.get(blessing_id) as Button
	var owned := _has_blessing_levels(levels, blessing_id)
	button.visible = owned
	if not owned:
		button.text = ""
		button.tooltip_text = ""
		button.button_pressed = false
		return false
	var expanded_key := "%s:%s" % [binding, blessing_id]
	var expanded := expanded_blessing_key == expanded_key
	button.text = _build_blessing_row_text(blessing_id, definition, levels, binding, expanded)
	button.tooltip_text = _build_blessing_row_text(blessing_id, definition, levels, binding, true)
	button.custom_minimum_size = Vector2(0.0, 146.0 if expanded else 68.0)
	button.button_pressed = expanded
	return true

func _build_blessing_row_text(
		blessing_id: String,
		definition: Dictionary,
		levels: Dictionary,
		binding: String,
		expanded: bool
) -> String:
	var title := str(definition.get("display_title", definition.get("title", blessing_id)))
	var highest_tier := _get_highest_owned_blessing_tier(levels, blessing_id)
	var lines: Array[String] = []
	lines.append("%s    %s" % [title, _format_owned_blessing_tiers(levels, blessing_id)])
	lines.append("%s · %s×%d 当前：%s" % [
		_get_blessing_scope_text(blessing_id, definition, binding),
		_get_tier_roman(highest_tier),
		_get_blessing_tier_count(levels, blessing_id, highest_tier),
		_get_blessing_description(definition, highest_tier, true)
	])
	if not expanded:
		return "\n".join(lines)
	lines.append("")
	lines.append("已持有各阶效果")
	for tier in range(1, PLAYER_BLESSING_SYSTEM.MAX_BLESSING_TIER + 1):
		var count := _get_blessing_tier_count(levels, blessing_id, tier)
		if count > 0:
			lines.append("• %s ×%d：%s" % [_get_tier_roman(tier), count, _get_blessing_description(definition, tier)])
	var recipe_tier := 2 if _get_blessing_tier_count(levels, blessing_id, 2) > 0 else (1 if _get_blessing_tier_count(levels, blessing_id, 1) > 0 else 0)
	var relation_text := PLAYER_BLESSING_SKILL_STATE.get_blessing_unlock_detail(blessing_id, recipe_tier) if recipe_tier > 0 else ""
	if relation_text != "":
		lines.append("")
		lines.append("技能关联：%s" % relation_text)
	return "\n".join(lines)

func _get_blessing_scope_text(blessing_id: String, definition: Dictionary, binding: String) -> String:
	if binding == PLAYER_BLESSING_SYSTEM.ROLE_BOUND:
		return "作用域：三角色共享"
	match blessing_id:
		"reprise":
			return "技能范围：所有连段技能"
		"tide_rain":
			return "技能范围：所有持续技能"
		"trick":
			return "技能范围：所有数量技能"
	var magic_stone_id := str(definition.get("magic_stone", ""))
	match magic_stone_id:
		PLAYER_BLESSING_SYSTEM.MAGIC_STONE_KINGDOM:
			return "技能绑定：所有角色普攻"
		PLAYER_BLESSING_SYSTEM.MAGIC_STONE_KING:
			return "技能绑定：所有角色终结技"
		PLAYER_BLESSING_SYSTEM.MAGIC_STONE_KEBIRU:
			return "技能绑定：所有克比鲁魔法"
		PLAYER_BLESSING_SYSTEM.MAGIC_STONE_INVOKER:
			return "技能绑定：所有因沃克魔法"
	return "技能绑定：未指定技能"

func _make_blessing_group_header(title: String, count: int) -> Label:
	var label := Label.new()
	label.text = "%s · %d 项" % [title, count]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	return label

func _make_archive_empty_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.custom_minimum_size = Vector2(0.0, 54.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
	return label

func _count_owned_blessings(levels: Dictionary, binding: String) -> int:
	var count := 0
	for blessing_id in PLAYER_BLESSING_SYSTEM.DEFINITIONS.keys():
		var definition: Dictionary = PLAYER_BLESSING_SYSTEM.DEFINITIONS.get(str(blessing_id), {})
		if str(definition.get("binding", PLAYER_BLESSING_SYSTEM.ROLE_BOUND)) == binding and _has_blessing_levels(levels, str(blessing_id)):
			count += 1
	return count

func _has_blessing_levels(levels: Dictionary, blessing_id: String) -> bool:
	for tier in range(1, PLAYER_BLESSING_SYSTEM.MAX_BLESSING_TIER + 1):
		if _get_blessing_tier_count(levels, blessing_id, tier) > 0:
			return true
	return false

func _get_blessing_tier_count(levels: Dictionary, blessing_id: String, tier: int) -> int:
	var blessing_levels: Variant = levels.get(blessing_id, {})
	if blessing_levels is not Dictionary:
		return 0
	return max(0, int((blessing_levels as Dictionary).get(tier, (blessing_levels as Dictionary).get(str(tier), 0))))

func _get_highest_owned_blessing_tier(levels: Dictionary, blessing_id: String) -> int:
	for tier in range(PLAYER_BLESSING_SYSTEM.MAX_BLESSING_TIER, 0, -1):
		if _get_blessing_tier_count(levels, blessing_id, tier) > 0:
			return tier
	return 1

func _format_owned_blessing_tiers(levels: Dictionary, blessing_id: String) -> String:
	var parts: Array[String] = []
	for tier in range(1, PLAYER_BLESSING_SYSTEM.MAX_BLESSING_TIER + 1):
		var count := _get_blessing_tier_count(levels, blessing_id, tier)
		if count > 0:
			parts.append("%s×%d" % [_get_tier_roman(tier), count])
	return " · ".join(parts)

func _get_blessing_description(definition: Dictionary, tier: int, compact: bool = false) -> String:
	var keys := ["display_card_summaries", "card_summaries", "display_descriptions", "descriptions"] if compact else ["display_descriptions", "descriptions", "display_card_summaries", "card_summaries"]
	for key in keys:
		var values: Variant = definition.get(key, {})
		if values is Dictionary:
			var value := str((values as Dictionary).get(tier, (values as Dictionary).get(str(tier), "")))
			if value != "":
				return value
	return str(definition.get("description", "提供对应祝福效果。"))

func _get_tier_roman(tier: int) -> String:
	return ["", "I", "II", "III", "IV"][clamp(tier, 0, PLAYER_BLESSING_SYSTEM.MAX_BLESSING_TIER)]

func _toggle_blessing_row(expanded_key: String) -> void:
	expanded_blessing_key = "" if expanded_blessing_key == expanded_key else expanded_key
	_refresh_blessing_list(_get_viewed_role_id())

func _get_viewed_role_id() -> String:
	var roles := _get_roles()
	if viewed_role_index >= 0 and viewed_role_index < roles.size() and roles[viewed_role_index] is Dictionary:
		return str((roles[viewed_role_index] as Dictionary).get("id", ""))
	return ""

func _build_stats_text(role_data: Dictionary) -> String:
	var role_id: String = str(role_data.get("id", ""))
	var bonus: Dictionary = cached_player._get_role_equipment_bonus_summary(role_id) if cached_player.has_method("_get_role_equipment_bonus_summary") else {}
	var active_bonus: Dictionary = cached_player._get_role_equipment_bonus_summary(str(cached_player._get_active_role().get("id", ""))) if cached_player.has_method("_get_role_equipment_bonus_summary") else {}
	var damage: float = float(cached_player._get_role_damage(role_id)) if cached_player.has_method("_get_role_damage") else float(role_data.get("damage", 0.0))
	var base_speed: float = float(cached_player.get("speed")) - float(active_bonus.get("speed_bonus", 0.0))
	var move_speed: float = float(role_data.get("move_speed", (base_speed + float(bonus.get("speed_bonus", 0.0))) * float(role_data.get("speed_scale", 1.0))))
	if cached_player.has_method("_get_role_move_speed"):
		move_speed = float(cached_player._get_role_move_speed(role_id))
	elif role_data.has("move_speed"):
		move_speed += float(bonus.get("speed_bonus", 0.0))
		if cached_player.has_method("_get_role_blessing_stat_bonus"):
			move_speed += float(cached_player._get_role_blessing_stat_bonus(role_id, "move_speed"))
			move_speed *= max(0.01, 1.0 + float(cached_player._get_role_blessing_stat_bonus(role_id, "move_speed_percent")))
	if not cached_player.has_method("_get_role_move_speed") and cached_player.has_method("_get_role_attribute_move_speed_multiplier"):
		move_speed *= float(cached_player._get_role_attribute_move_speed_multiplier(role_id))
	if not cached_player.has_method("_get_role_move_speed") and not role_data.has("move_speed"):
		if cached_player.has_method("_get_role_blessing_stat_bonus"):
			move_speed += float(cached_player._get_role_blessing_stat_bonus(role_id, "move_speed"))
			move_speed *= max(0.01, 1.0 + float(cached_player._get_role_blessing_stat_bonus(role_id, "move_speed_percent")))
		move_speed *= GLOBAL_UNIT_MOVE_SPEED_SCALE
	var max_health: float = float(cached_player._get_role_max_health(role_id)) if cached_player.has_method("_get_role_max_health") else float(cached_player.get("max_health")) - float(active_bonus.get("max_health_bonus", 0.0)) + float(bonus.get("max_health_bonus", 0.0))
	var current_health: float = float(cached_player._get_role_current_health(role_id)) if cached_player.has_method("_get_role_current_health") else float(cached_player.get("current_health"))
	var current_health_text := "%.0f / %.0f" % [current_health, max_health]
	var energy_gain: float = 1.0
	if cached_player.has_method("_get_role_total_ultimate_energy_gain_multiplier"):
		energy_gain = float(cached_player._get_role_total_ultimate_energy_gain_multiplier(role_id))
	var pickup_radius: float = float(cached_player.get("pickup_radius"))
	if cached_player.has_method("_get_attribute_pickup_range_bonus"):
		pickup_radius += float(cached_player._get_attribute_pickup_range_bonus())
	var dodge_chance: float = float(cached_player._get_role_dodge_chance(role_id)) if cached_player.has_method("_get_role_dodge_chance") else 0.0
	var health_regen: float = float(bonus.get("regen_per_second", 0.0))
	if cached_player.has_method("_get_attribute_health_regen_per_second"):
		health_regen += float(cached_player._get_attribute_health_regen_per_second())
	var mana_regen: float = float(cached_player._get_attribute_mana_regen_per_second()) if cached_player.has_method("_get_attribute_mana_regen_per_second") else 0.0
	var damage_reduction_rate: float = float(cached_player._get_role_damage_reduction_rate(role_id)) if cached_player.has_method("_get_role_damage_reduction_rate") else 0.0
	var damage_reduction_label: String = "\u51cf\u4f24" if damage_reduction_rate >= 0.0 else "\u6613\u4f24"
	var damage_reduction_color: String = "#74f0a7" if damage_reduction_rate >= 0.0 else "#ff9b74"
	var swordsman_trait_level: float = float(cached_player._get_attribute_level("swordsman_trait")) if cached_player.has_method("_get_attribute_level") else 0.0
	var gunner_trait_level: float = float(cached_player._get_attribute_level("gunner_trait")) if cached_player.has_method("_get_attribute_level") else 0.0
	var mage_trait_level: float = float(cached_player._get_attribute_level("mage_trait")) if cached_player.has_method("_get_attribute_level") else 0.0
	var lines: Array[String] = []
	lines.append("[color=#f3d35a][b]核心属性[/b][/color]")
	lines.append("生命        [color=#ffffff]%s[/color]" % current_health_text)
	lines.append("大招能量    [color=#ffffff]%.0f / %.0f[/color]    回能 [color=#74f0a7]x%.2f +%.2f/s[/color]" % [
		float(cached_player._get_role_mana(role_id)) if cached_player.has_method("_get_role_mana") else 0.0,
		float(cached_player.get("max_mana")),
		energy_gain,
		mana_regen
	])
	lines.append("攻击力      [color=#ffffff]%.1f[/color]    普攻间隔 [color=#ffffff]%.2fs[/color]" % [
		damage,
		float(cached_player._get_effective_attack_interval(role_id)) if cached_player.has_method("_get_effective_attack_interval") else 0.0
	])
	lines.append("移动速度    [color=#ffffff]%.1f[/color]    拾取范围 [color=#ffffff]%.1f[/color]" % [move_speed, pickup_radius])
	lines.append("范围倍率    [color=#74f0a7]x%.2f[/color]    冷却倍率 [color=#74f0a7]x%.2f[/color]" % [
		float(bonus.get("skill_range_multiplier", 1.0)),
		float(bonus.get("cooldown_multiplier", 1.0))
	])
	lines.append("\u95ea\u907f        [color=#74f0a7]%.1f%%[/color]    \u56de\u8840 [color=#74f0a7]%.1f/s[/color]    %s [color=%s]%.1f%%[/color]" % [
		dodge_chance * 100.0,
		health_regen,
		damage_reduction_label,
		damage_reduction_color,
		abs(damage_reduction_rate) * 100.0
	])
	lines.append("")
	lines.append("[color=#f3d35a][b]英雄特性[/b][/color]")
	lines.append("剑士 Lv.%s    枪手 Lv.%s    法师 Lv.%s" % [
		_format_panel_attribute_level(swordsman_trait_level),
		_format_panel_attribute_level(gunner_trait_level),
		_format_panel_attribute_level(mage_trait_level)
	])
	lines.append("[color=#bfc8dc]特性影响对应英雄的核心机制与定位加成。[/color]")
	return "\n".join(lines)

func _format_panel_attribute_level(level: float) -> String:
	if cached_player != null and cached_player.has_method("_format_attribute_level"):
		return str(cached_player._format_attribute_level(level))
	if is_equal_approx(level, roundf(level)):
		return str(int(roundf(level)))
	return "%.1f" % level

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
