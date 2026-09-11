extends CanvasLayer

signal upgrade_selected(option_id: String, attribute_option_id: String)
signal upgrade_refresh_requested
signal upgrade_card_refresh_requested(option_index: int)

const SURVIVORS_MODAL := preload("res://scripts/ui/core/survivors_modal.gd")
const SURVIVORS_CARD_LIST := preload("res://scripts/ui/components/survivors_card_list.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const SURVIVORS_HOVER_DETAIL := preload("res://scripts/ui/components/survivors_hover_detail.gd")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const BUILD_CARD_TEXTURE := preload("res://assets/UI/card/card.png")
const BUILD_CARD_SCENE := preload("res://assets/UI/card/card.tscn")
const BUILD_CARD_BLUE_SCENE := preload("res://assets/UI/card/bluecard.tscn")
const BUILD_CARD_PURPLE_SCENE := preload("res://assets/UI/card/purplecard.tscn")
const BUILD_CARD_GOLD_SCENE := preload("res://assets/UI/card/goldcard.tscn")
const MAGIC_STONE_BUILD_CARD_SCENE := preload("res://assets/UI/card/magicstone.tscn")
const MAGIC_STONE_BLESSING_CARD_SCENE := preload("res://assets/UI/card/stone.tscn")
const MAGIC_STONE_BUILD_CARD_BLUE_SCENE := preload("res://assets/UI/card/bluestonecard.tscn")
const MAGIC_STONE_BUILD_CARD_PURPLE_SCENE := preload("res://assets/UI/card/purplestonecard.tscn")
const MAGIC_STONE_BUILD_CARD_GOLD_SCENE := preload("res://assets/UI/card/goldstonecard.tscn")
const BUILD_REFRESH_TEXTURE := preload("res://assets/UI/循环.png")
const BUILD_CARD_OPTION_COUNT := 4
const TRAIT_HEAD_SCENES := {
	"level_trait_swordsman": preload("res://assets/UI/facility/swordhead.tscn"),
	"level_trait_gunner": preload("res://assets/UI/facility/gunhead.tscn"),
	"level_trait_mage": preload("res://assets/UI/facility/witchhead.tscn"),
	"level_trait_mechanic": preload("res://assets/UI/facility/mechanichead.tscn")
}
const LEVEL_TALENT_ROLE_SCENES := {
	"swordsman": preload("res://assets/UI/facility/swordchange.tscn"),
	"gunner": preload("res://assets/UI/facility/gunchange.tscn"),
	"mage": preload("res://assets/UI/facility/witchchange.tscn"),
	"mechanic": preload("res://assets/UI/facility/mechanicchange.tscn")
}
const LEVEL_TALENT_ROLE_BUTTON_SCALE := 2.5
const BUILD_CARD_DISPLAY_SCALE := 1.0
const BUILD_CARD_VISUAL_OFFSET := Vector2(52.0, 98.0)
const TRAIT_BUTTON_SCALE := 2.0
const OPENING_TRAIT_BUTTON_SCALE := TRAIT_BUTTON_SCALE * 2.0
const OPENING_TRAIT_IDLE_MODULATE := Color(0.58, 0.58, 0.58, 0.86)
const OPENING_TRAIT_HOVER_MODULATE := Color(1.24, 1.24, 1.24, 1.0)
const BUILD_DETAIL_HIDE_DELAY := 0.3
const BUILD_CARD_SELECT_ANIM_TIME := 0.32
const BUILD_CARD_SELECT_SHAKE_TIME := 0.10
const BUILD_CARD_REFRESH_BUTTON_SIZE := 46.0
const BUILD_CARD_REFRESH_BUTTON_GAP := 8.0
const BUILD_CARD_REFRESH_BUTTON_ROTATION_DEGREES := 90.0
const BUILD_CARD_REFRESH_BUTTON_ROTATION_TIME := 0.16
const BUILD_REFRESH_BUTTON_VISUAL_OFFSET := Vector2(-5.0, -43.0)
const TRAIT_BUTTON_VISUAL_OFFSETS := {
	"level_trait_mage": Vector2(0.0, -10.0)
}
const OPENING_TRAIT_BUTTON_VISUAL_OFFSETS := {
	"level_trait_swordsman": Vector2(80.0, 0.0),
	"level_trait_gunner": Vector2.ZERO,
	"level_trait_mage": Vector2(-80.0, -30.0)
}
const TRAIT_OPENING_DESCRIPTIONS := {
	"level_trait_swordsman": "剑士造成伤害时有5%概率回复自身最大生命值3%与已损失生命值3%的生命值，每秒触发1次，多目标最多同时触发2次。受到致命伤害时保留1点生命并进入1.5s骑士荣耀，之后进入80s CD。",
	"level_trait_gunner": "枪手基础闪避率15%，每级提供2闪避值。枪手拥有半径115的猎杀安全区，圈内敌人承受枪手伤害降至40%；未受伤时每2秒叠加1层瞬杀，最多10层，每层提升3%伤害、3%移速和4闪避值，受伤后清空并进入15秒冷却。",
	"level_trait_mage": "法师每击杀一个怪物都有15%概率获得1层奥数充能。每层提供2%法师自身大招回能效率，并将法师自身获得的大招能量的10%同步给另外两名角色。切人后，奥数充能不会立刻消失，而是由下一名登场角色继承法师当前层数，并持续同等秒数。释放登场技后会立刻进入5秒奥法盈余；释放大招则会在演出结束后进入5秒奥法盈余：全员大招回能效率+20%，切人回能效率+20%，伤害+10%；若状态自然结束时当前站场角色仍为法师，则额外获得3层奥数充能。"
}
const TRAIT_DETAIL_DESCRIPTIONS := {
	"level_trait_swordsman": "剑士造成伤害时有5%概率触发生命回复。",
	"level_trait_gunner": "提供2闪避值。",
	"level_trait_mage": "提供2%击杀获得奥数充能概率。"
}
const TRAIT_BUTTON_DESCRIPTION_GAP := 4.0
const OPENING_TRAIT_DESCRIPTION_OFFSETS := {
	"level_trait_swordsman": Vector2(0.0, -80.0),
	"level_trait_gunner": Vector2(0.0, -80.0),
	"level_trait_mage": Vector2(0.0, -50.0)
}
const BUILD_DETAIL_HOVER_DELAY := 1.5
const BUILD_REFRESH_ANIMATION_TIME := 0.5
const BUILD_REFRESH_COLLAPSE_RATIO := 0.42
const BUILD_REFRESH_COLLAPSED_SCALE := 0.72
const BUILD_REFRESH_COLLAPSED_ALPHA := 0.62
const BUILD_REFRESH_TEXT_HIDDEN_HOLD := 0.08
const BUILD_REFRESH_BUTTON_ROTATION_TIME := 0.3
const BUILD_REFRESH_BUTTON_ROTATION_DEGREES := 45.0
const BUILD_CARD_SUMMARY_CHARS_PER_LINE := 8
const BUILD_CARD_SUMMARY_MAX_LINES := 4
const TIER_FOUR_CARD_SHAKE_TIME := 0.16
const TIER_FOUR_CARD_SHAKE_DISTANCE := 8.0
const BLESSING_SLOT_ORDER := ["body", "combat", "skill"]
const SMALL_BOSS_SLOT_ORDER := ["equipment", "card"]
const BLESSING_UNIFIED_SECTION_TITLE := "构筑四选二"
const DEFAULT_SLOT_LABELS := {
	"body": "战斗",
	"combat": "连携",
	"skill": "技能",
	"equipment": "道具",
	"card": "技能奖励"
}

var modal: Control
var selection_label: Label
var card_list: Control
var hover_detail: Control
var build_root: Control
var build_dimmer: ColorRect
var build_card_layer: Control
var trait_button_layer: Control
var build_refresh_button: Button
var level_talent_back_button: Button
var opening_prompt_label: Label
var build_detail_hide_timer: Timer
var build_detail_hover_timer: Timer
var build_card_entries: Array = []
var trait_button_entries: Array = []
var level_talent_role_button_entries: Array = []
var level_talent_role_options: Array = []
var level_talent_selected_role_id := ""
var build_card_hover_tweens: Dictionary = {}
var build_refresh_button_rotation_tween: Tween
var active_build_detail_control: Control
var active_build_detail_option_id := ""
var pending_build_detail_control: Control
var pending_build_detail_item: Dictionary = {}
var build_selection_in_progress := false
var build_refresh_animation_in_progress := false
var build_refresh_expand_pending := false
var build_card_refresh_used_indices: Dictionary = {}

var current_mode: String = "direct"
var current_options: Array = []
var current_attribute_options: Array = []
var current_offer_context: Dictionary = {}
var option_groups: Dictionary = {}
var pending_blessing_option_id: String = ""
var pending_blessing_title: String = ""
var pending_blessing_option_ids: Array[String] = []
var pending_blessing_titles: Array[String] = []
var pending_attribute_option_id: String = ""
var pending_attribute_title: String = ""
var preferred_attribute_option_id: String = ""
var pending_equipment_option_id: String = ""
var pending_equipment_title: String = ""
var pending_card_option_id: String = ""
var pending_card_title: String = ""

func _ready() -> void:
	layer = 2
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	modal = SURVIVORS_MODAL.new()
	modal.configure(Vector2(680.0, 430.0), 0.54, 0.60, Vector2(320.0, 240.0))
	add_child(modal)

	selection_label = Label.new()
	selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	modal.content.add_child(selection_label)
	modal.content.move_child(selection_label, min(2, modal.content.get_child_count() - 1))

	card_list = SURVIVORS_CARD_LIST.new()
	card_list.item_selected.connect(_on_card_list_item_selected)
	card_list.item_hovered.connect(_on_card_item_hovered)
	card_list.item_unhovered.connect(_on_card_item_unhovered)
	modal.set_body(card_list)

	_ensure_build_overlay()

	hover_detail = SURVIVORS_HOVER_DETAIL.new()
	add_child(hover_detail)

	build_detail_hide_timer = Timer.new()
	build_detail_hide_timer.one_shot = true
	build_detail_hide_timer.wait_time = BUILD_DETAIL_HIDE_DELAY
	build_detail_hide_timer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	build_detail_hide_timer.timeout.connect(_on_build_detail_hide_timer_timeout)
	add_child(build_detail_hide_timer)

	build_detail_hover_timer = Timer.new()
	build_detail_hover_timer.one_shot = true
	build_detail_hover_timer.wait_time = BUILD_DETAIL_HOVER_DELAY
	build_detail_hover_timer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	build_detail_hover_timer.timeout.connect(_on_build_detail_hover_timer_timeout)
	add_child(build_detail_hover_timer)

	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)

	hide_ui()

func _on_viewport_size_changed() -> void:
	if visible:
		_apply_responsive_state()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _handle_level_talent_back_input(event):
		return
	if GAME_SETTINGS.event_matches_action(event, GAME_SETTINGS.ACTION_CHARACTER_PANEL):
		var main := get_tree().current_scene
		if main != null and main.has_method("_toggle_character_panel"):
			main._toggle_character_panel()
			get_viewport().set_input_as_handled()

func show_options(options: Array, attribute_options: Array = [], offer_context: Dictionary = {}) -> void:
	current_mode = "blessing"
	current_options = options
	current_attribute_options = attribute_options
	current_offer_context = offer_context.duplicate(true)
	option_groups = _group_options(options, BLESSING_SLOT_ORDER)
	_reset_pending_selection()
	if _offer_has_level_talent_role_entries(options):
		level_talent_role_options = _duplicate_option_array(options)
		current_options = _duplicate_option_array(level_talent_role_options)
		option_groups = _group_options(current_options, BLESSING_SLOT_ORDER)
	build_selection_in_progress = false
	visible = true
	if modal != null:
		modal.visible = false
	_clear_modal_footer()
	_ensure_build_overlay()
	_select_default_attribute_option()
	if current_mode == "blessing" and not build_refresh_expand_pending:
		build_refresh_expand_pending = true
	_rebuild_build_overlay()
	if build_refresh_expand_pending:
		build_refresh_expand_pending = false
		_play_build_refresh_expand_animation()

func show_refreshed_build_options(options: Array, offer_context: Dictionary, refreshed_option_index: int) -> void:
	if current_mode != "blessing":
		show_options(options, [], offer_context)
		return
	var refreshed_old_option_id := _get_current_build_option_id_at(refreshed_option_index)
	var refreshed_options := _duplicate_option_array(options)
	if _is_level_talent_role_detail_active():
		current_options = refreshed_options
		_set_level_talent_role_detail_options(level_talent_selected_role_id, refreshed_options)
	else:
		current_options = refreshed_options
		if _offer_has_level_talent_role_entries(current_options):
			level_talent_role_options = _duplicate_option_array(current_options)
			level_talent_selected_role_id = ""
	current_offer_context = offer_context.duplicate(true)
	option_groups = _group_options(current_options, BLESSING_SLOT_ORDER)
	_remove_pending_build_selection(refreshed_old_option_id)
	_prune_pending_build_selections()
	_sync_primary_build_selection()
	build_refresh_animation_in_progress = false
	visible = true
	if modal != null:
		modal.visible = false
	_ensure_build_overlay()
	_rebuild_build_overlay()
	_update_selection_hint()
	_refresh_selected_cards()
	_refresh_build_card_selected_outlines()
	_play_refreshed_build_card_feedback(refreshed_option_index)

func show_menu(title: String, options: Array) -> void:
	current_mode = "direct"
	current_options = options
	current_attribute_options = []
	current_offer_context = {}
	option_groups = {}
	_reset_pending_selection()
	build_selection_in_progress = false
	visible = true
	if build_root != null:
		build_root.visible = false
	if modal != null:
		modal.visible = true
	modal.configure(Vector2(640.0, 390.0), 0.50, 0.55, Vector2(300.0, 220.0))
	modal.set_title(title)
	modal.set_hint("卡面显示简短摘要；鼠标移到卡片上查看完整说明。")
	selection_label.visible = false
	_prepare_modal_layout()
	_clear_modal_footer()
	_rebuild_direct_list()

func show_small_boss_reward_menu(title: String, options: Array) -> void:
	current_mode = "small_boss_pair"
	current_options = options
	current_attribute_options = []
	current_offer_context = {}
	option_groups = _group_small_boss_reward_options(options)
	_reset_pending_selection()
	build_selection_in_progress = false
	visible = true
	if build_root != null:
		build_root.visible = false
	if modal != null:
		modal.visible = true
	modal.configure(Vector2(660.0, 420.0), 0.52, 0.58, Vector2(320.0, 230.0))
	modal.set_title(title)
	modal.set_hint(_get_small_boss_reward_menu_hint())
	selection_label.visible = true
	_prepare_modal_layout()
	_clear_modal_footer()
	_rebuild_small_boss_list()
	_update_small_boss_reward_hint()

func hide_ui() -> void:
	visible = false
	if build_root != null:
		build_root.visible = false
	if opening_prompt_label != null:
		opening_prompt_label.visible = false
	build_selection_in_progress = false
	_reset_pending_selection()
	if hover_detail != null and hover_detail.has_method("hide_detail"):
		hover_detail.hide_detail()
	_clear_active_build_detail()
	# Do not clear the card list while hiding. Reward chains can hide the current
	# panel and open the next panel in the same frame (for example consecutive
	# level-ups or multi-step skill rewards). Clearing a hidden ScrollContainer
	# immediately before repopulating it can leave Godot's internal scrollbar
	# range at 0, making the next panel impossible to scroll. Each show/rebuild
	# path clears and repopulates the list while visible, which keeps the
	# scrollbar range valid.
	_clear_modal_footer()

func _apply_responsive_state() -> void:
	if ["blessing", "opening_trait"].has(current_mode) and build_root != null and build_root.visible:
		_layout_build_overlay()
	_prepare_modal_layout()
	_refresh_selected_cards()

func _ensure_build_overlay() -> void:
	if build_root != null:
		return
	build_root = Control.new()
	build_root.name = "BuildUpgradeOverlay"
	build_root.visible = false
	build_root.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	build_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(build_root)

	build_dimmer = ColorRect.new()
	build_dimmer.color = Color(0.0, 0.0, 0.0, 0.62)
	build_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_fill_rect(build_dimmer)
	build_root.add_child(build_dimmer)

	build_card_layer = Control.new()
	build_card_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	_fill_rect(build_card_layer)
	build_root.add_child(build_card_layer)

	trait_button_layer = Control.new()
	trait_button_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	build_root.add_child(trait_button_layer)

	build_refresh_button = Button.new()
	build_refresh_button.text = ""
	build_refresh_button.tooltip_text = "刷新"
	build_refresh_button.focus_mode = Control.FOCUS_NONE
	build_refresh_button.pressed.connect(_on_refresh_pressed)
	var refresh_icon := TextureRect.new()
	refresh_icon.name = "RefreshIcon"
	refresh_icon.texture = BUILD_REFRESH_TEXTURE
	refresh_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	refresh_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	refresh_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	refresh_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	refresh_icon.offset_left = -5.0
	refresh_icon.offset_top = -4.0
	refresh_icon.offset_right = 3.0
	refresh_icon.offset_bottom = 4.0
	build_refresh_button.add_child(refresh_icon)
	build_root.add_child(build_refresh_button)
	_apply_refresh_button_style()

	level_talent_back_button = Button.new()
	level_talent_back_button.name = "LevelTalentBackButton"
	level_talent_back_button.text = "返回一级菜单"
	level_talent_back_button.tooltip_text = "返回角色天赋选择"
	level_talent_back_button.focus_mode = Control.FOCUS_NONE
	level_talent_back_button.mouse_filter = Control.MOUSE_FILTER_STOP
	level_talent_back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	level_talent_back_button.z_index = 100
	level_talent_back_button.visible = false
	level_talent_back_button.gui_input.connect(_on_level_talent_back_gui_input)
	level_talent_back_button.pressed.connect(_on_level_talent_back_pressed)
	build_root.add_child(level_talent_back_button)
	_apply_level_talent_back_button_style()

	opening_prompt_label = Label.new()
	opening_prompt_label.visible = false
	opening_prompt_label.text = "请选择你倾向的角色特性作为开局，可在后续升级中进行切换"
	opening_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opening_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	opening_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48, 1.0))
	opening_prompt_label.add_theme_font_size_override("font_size", 28)
	build_root.add_child(opening_prompt_label)

func _fill_rect(control: Control) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0

func _rebuild_build_overlay() -> void:
	if build_root == null:
		return
	build_root.visible = true
	if build_dimmer != null:
		build_dimmer.visible = true
	if build_card_layer != null:
		for child in build_card_layer.get_children():
			build_card_layer.remove_child(child)
			child.queue_free()
	if trait_button_layer != null:
		for child in trait_button_layer.get_children():
			trait_button_layer.remove_child(child)
			child.queue_free()
	build_card_entries = []
	trait_button_entries = []
	level_talent_role_button_entries = []

	if build_card_layer != null:
		build_card_layer.visible = current_mode != "opening_trait"
	if current_mode != "opening_trait":
		if _is_level_talent_role_select_active() and level_talent_selected_role_id == "":
			for raw_option in level_talent_role_options:
				if raw_option is not Dictionary:
					continue
				var role_option: Dictionary = raw_option
				var role_button := _make_level_talent_role_button(role_option)
				build_card_layer.add_child(role_button)
				level_talent_role_button_entries.append({
					"button": role_button,
					"option": role_option
				})
		else:
			var display_count := _get_build_card_display_count()
			var displayed_options := current_options.slice(0, min(display_count, current_options.size()))
			for option_index in range(displayed_options.size()):
				var raw_option = displayed_options[option_index]
				if raw_option is not Dictionary:
					continue
				var option: Dictionary = raw_option
				var button := _make_build_card_button(option)
				build_card_layer.add_child(button)
				var refresh_button: Button = null
				if _should_show_build_card_refresh_buttons():
					refresh_button = _make_build_card_refresh_button(option_index)
					build_card_layer.add_child(refresh_button)
				build_card_entries.append({
					"button": button,
					"refresh_button": refresh_button,
					"option": option,
					"option_index": option_index
				})
	for raw_trait_option in _get_trait_options():
		var option: Dictionary = _with_trait_display_overrides(raw_trait_option)
		var button := _make_trait_button(option)
		trait_button_layer.add_child(button)
		trait_button_entries.append({
			"button": button,
			"option": option
		})

	_update_trait_button_styles()
	_update_build_refresh_button()
	_layout_build_overlay()
	_set_build_overlay_input_enabled(not build_selection_in_progress and not build_refresh_animation_in_progress)
	_refresh_build_card_selected_outlines()
	if not build_refresh_expand_pending:
		_play_pending_tier_four_card_intro_effects()

func _make_build_card_button(option: Dictionary) -> TextureButton:
	var button := _get_build_card_scene(option).instantiate() as TextureButton
	if button == null:
		button = TextureButton.new()
		button.texture_normal = BUILD_CARD_TEXTURE
		button.texture_hover = BUILD_CARD_TEXTURE
		button.texture_pressed = BUILD_CARD_TEXTURE
	button.focus_mode = Control.FOCUS_NONE
	button.clip_contents = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(_on_build_card_mouse_entered.bind(button, option))
	button.mouse_exited.connect(_on_build_card_mouse_exited.bind(button))
	button.gui_input.connect(_on_build_item_gui_input.bind(button, option))
	button.pressed.connect(_on_build_card_pressed.bind(button, option))
	if button.get_node_or_null("HoverFrame") == null:
		button.add_child(_make_build_card_hover_frame())
	_apply_build_card_hover_frame_style(button.get_node_or_null("HoverFrame") as Panel)
	_ensure_build_card_selected_outline(button)
	button.set_meta("build_card_base_scale", button.scale)
	button.set_meta("build_card_intro_pending", int(option.get("blessing_tier", 0)) >= 4)
	_populate_build_card_scene(button, option)
	return button

func _make_build_card_refresh_button(option_index: int) -> Button:
	var button := Button.new()
	button.name = "CardRefreshButton%d" % option_index
	button.text = ""
	button.tooltip_text = "刷新这张构筑"
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.z_index = 42
	button.set_meta("build_card_option_index", option_index)
	button.pressed.connect(_on_build_card_refresh_pressed.bind(option_index))
	var icon := TextureRect.new()
	icon.name = "RefreshIcon"
	icon.texture = BUILD_REFRESH_TEXTURE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = -4.0
	icon.offset_top = -4.0
	icon.offset_right = 4.0
	icon.offset_bottom = 4.0
	icon.modulate = Color(0.78, 0.88, 0.92, 0.62)
	button.add_child(icon)
	_apply_card_refresh_button_style(button)
	_apply_build_card_refresh_button_state(button, option_index)
	return button

func _get_build_card_scene(option: Dictionary) -> PackedScene:
	var tier: int = clamp(int(option.get("blessing_tier", 1)), 1, 4)
	var option_category: String = str(option.get("option_category", option.get("blessing_category", "")))
	if option_category == "magic_stone":
		return MAGIC_STONE_BUILD_CARD_SCENE
	if option_category == "role_build":
		match str(option.get("build_card_scene", "")):
			"magicstone":
				return MAGIC_STONE_BUILD_CARD_SCENE
			"stone":
				return MAGIC_STONE_BLESSING_CARD_SCENE
		if str(option.get("unlock_skill", "")) != "":
			return MAGIC_STONE_BUILD_CARD_SCENE
	var is_magic_stone_blessing := str(option.get("blessing_category", "")) == "magic_stone_blessing"
	if is_magic_stone_blessing:
		match tier:
			2:
				return MAGIC_STONE_BUILD_CARD_BLUE_SCENE
			3:
				return MAGIC_STONE_BUILD_CARD_PURPLE_SCENE
			4:
				return MAGIC_STONE_BUILD_CARD_GOLD_SCENE
			_:
				return MAGIC_STONE_BLESSING_CARD_SCENE
	match tier:
		2:
			return BUILD_CARD_BLUE_SCENE
		3:
			return BUILD_CARD_PURPLE_SCENE
		4:
			return BUILD_CARD_GOLD_SCENE
		_:
			return BUILD_CARD_SCENE

func _populate_build_card_scene(button: TextureButton, option: Dictionary) -> void:
	var tier_color: Color = option.get("tier_text_font_color", Color(0.0, 0.0, 0.0, 1.0))
	var title_label := button.get_node_or_null("Margin/Content/TitleLabel") as Label
	if title_label != null:
		var hide_title := bool(option.get("hide_card_title", false))
		title_label.visible = not hide_title
		title_label.text = "" if hide_title else str(option.get("card_title", option.get("title", option.get("name", "选项"))))
		if not hide_title:
			title_label.add_theme_color_override("font_color", tier_color)
			title_label.add_theme_constant_override("outline_size", int(option.get("tier_text_outline_size", 0)))
			title_label.add_theme_color_override("font_outline_color", option.get("tier_text_outline_color", Color(0.0, 0.0, 0.0, 0.0)))
	var summary_label := button.get_node_or_null("Margin/Content/SummaryLabel") as Label
	if summary_label != null:
		summary_label.add_theme_color_override("font_color", option.get("tier_description_color", tier_color))
		summary_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		summary_label.clip_text = true
		summary_label.max_lines_visible = BUILD_CARD_SUMMARY_MAX_LINES
		summary_label.text = _get_card_summary_text(option)

func _make_build_card_hover_frame() -> Panel:
	var panel := Panel.new()
	panel.name = "HoverFrame"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_rect(panel)
	_apply_build_card_hover_frame_style(panel)
	return panel

func _apply_build_card_hover_frame_style(panel: Panel) -> void:
	if panel == null:
		return
	panel.visible = false
	panel.z_index = 30
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.90, 0.36, 0.16)
	style.border_color = Color(1.0, 0.82, 0.18, 1.0)
	style.set_border_width_all(5)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

func _ensure_build_card_selected_outline(card: TextureButton) -> TextureRect:
	if card == null:
		return null
	var existing := card.get_node_or_null("SelectedOutline") as TextureRect
	if existing != null:
		return existing
	var outline := TextureRect.new()
	outline.name = "SelectedOutline"
	outline.visible = false
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.texture = card.texture_normal
	outline.modulate = Color(1.0, 1.0, 1.0, 1.0)
	outline.stretch_mode = TextureRect.STRETCH_SCALE
	outline.z_index = 35
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec2 texel_size = vec2(0.00390625, 0.00390625);
uniform float outline_width = 4.0;
uniform vec4 outline_color : source_color = vec4(1.0, 0.78, 0.08, 1.0);

void fragment() {
	float center = texture(TEXTURE, UV).a;
	vec2 step_size = texel_size * outline_width;
	float a_left = texture(TEXTURE, UV + vec2(-step_size.x, 0.0)).a;
	float a_right = texture(TEXTURE, UV + vec2(step_size.x, 0.0)).a;
	float a_up = texture(TEXTURE, UV + vec2(0.0, -step_size.y)).a;
	float a_down = texture(TEXTURE, UV + vec2(0.0, step_size.y)).a;
	float a_up_left = texture(TEXTURE, UV + vec2(-step_size.x, -step_size.y)).a;
	float a_up_right = texture(TEXTURE, UV + vec2(step_size.x, -step_size.y)).a;
	float a_down_left = texture(TEXTURE, UV + vec2(-step_size.x, step_size.y)).a;
	float a_down_right = texture(TEXTURE, UV + vec2(step_size.x, step_size.y)).a;
	float max_neighbor = max(max(max(a_left, a_right), max(a_up, a_down)), max(max(a_up_left, a_up_right), max(a_down_left, a_down_right)));
	float min_neighbor = min(min(min(a_left, a_right), min(a_up, a_down)), min(min(a_up_left, a_up_right), min(a_down_left, a_down_right)));
	float outer_edge = max(max_neighbor - center, 0.0);
	float inner_edge = max(center - min_neighbor, 0.0);
	float edge = clamp(max(outer_edge, inner_edge) * 2.8, 0.0, 1.0);
	COLOR = vec4(outline_color.rgb, outline_color.a * edge);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var texture_size := card.texture_normal.get_size() if card.texture_normal != null else Vector2(256.0, 256.0)
	material.set_shader_parameter("texel_size", Vector2(1.0 / max(1.0, texture_size.x), 1.0 / max(1.0, texture_size.y)))
	outline.material = material
	_fill_rect(outline)
	card.add_child(outline)
	return outline

func _make_trait_button(option: Dictionary) -> Button:
	var option_id := str(option.get("id", ""))
	var button := Button.new()
	button.text = ""
	button.tooltip_text = str(option.get("title", option.get("name", "特性")))
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.clip_contents = false
	var head_scene: PackedScene = TRAIT_HEAD_SCENES.get(option_id)
	if head_scene != null:
		var head := head_scene.instantiate() as Node2D
		if head != null:
			head.name = "TraitHead"
			head.set_meta("base_scale", head.scale)
			button.add_child(head)
	var description := Label.new()
	description.name = "OpeningDescription"
	description.visible = false
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", Color(0.92, 0.90, 0.82, 0.95))
	description.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	description.add_theme_constant_override("shadow_offset_x", 1)
	description.add_theme_constant_override("shadow_offset_y", 1)
	description.add_theme_font_size_override("font_size", 18)
	button.add_child(description)
	button.mouse_entered.connect(_on_trait_button_mouse_entered.bind(button, option))
	button.mouse_exited.connect(_on_trait_button_mouse_exited.bind(button, option))
	button.gui_input.connect(_on_build_item_gui_input.bind(button, option))
	button.pressed.connect(_on_trait_button_pressed.bind(button, option))
	return button

func _make_level_talent_role_button(option: Dictionary) -> Button:
	var role_id := str(option.get("role_id", ""))
	var button := Button.new()
	button.name = "LevelTalentRoleButton_%s" % role_id
	button.text = ""
	button.tooltip_text = str(option.get("title", option.get("card_title", "??")))
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.clip_contents = false
	_apply_level_talent_role_button_style(button)
	var role_scene: PackedScene = LEVEL_TALENT_ROLE_SCENES.get(role_id)
	if role_scene != null:
		var visual := role_scene.instantiate() as Node2D
		if visual != null:
			visual.name = "LevelTalentRoleVisual"
			visual.set_meta("base_scale", visual.scale)
			button.add_child(visual)
	button.mouse_entered.connect(_on_level_talent_role_button_mouse_entered.bind(button))
	button.mouse_exited.connect(_on_level_talent_role_button_mouse_exited.bind(button))
	button.gui_input.connect(_on_build_item_gui_input.bind(button, option))
	button.pressed.connect(_on_level_talent_role_button_pressed.bind(button, option))
	return button

func _layout_build_overlay() -> void:
	if build_root == null:
		return
	var viewport := SURVIVORS_THEME.viewport_size(self)
	var card_count := build_card_entries.size()
	var base_card_y: float = clamp(viewport.y * 0.055, 42.0, 64.0)
	var card_y: float = base_card_y + BUILD_CARD_VISUAL_OFFSET.y
	if opening_prompt_label != null:
		opening_prompt_label.visible = current_mode == "opening_trait"
		opening_prompt_label.position = Vector2(0.0, viewport.y * 0.18)
		opening_prompt_label.size = Vector2(viewport.x, 48.0)
	if card_count > 0:
		var fit_scale := _get_build_card_fit_scale(viewport, card_y)
		for entry in build_card_entries:
			var button := (entry as Dictionary).get("button") as Control
			if button != null:
				button.scale = _get_build_card_base_scale(button) * BUILD_CARD_DISPLAY_SCALE * fit_scale

		var card_sizes: Array[Vector2] = []
		var total_card_width := 0.0
		for entry in build_card_entries:
			var button := (entry as Dictionary).get("button") as Control
			var card_size := _get_build_card_visual_size(button)
			card_sizes.append(card_size)
			total_card_width += card_size.x
		var card_gap: float = clamp(viewport.x * 0.030, 26.0, 56.0)
		var max_gap: float = (viewport.x - 40.0 - total_card_width) / float(max(1, card_count - 1))
		if card_count > 1:
			card_gap = clamp(min(card_gap, max_gap), 12.0, 56.0)
		var total_width := total_card_width + card_gap * float(max(0, card_count - 1))
		var x := (viewport.x - total_width) * 0.5 + BUILD_CARD_VISUAL_OFFSET.x
		for index in range(card_count):
			var entry: Dictionary = build_card_entries[index]
			var button := entry.get("button") as Control
			if button == null:
				continue
			var card_size: Vector2 = card_sizes[index]
			button.position = Vector2(x, card_y)
			if button.size.x <= 0.0 or button.size.y <= 0.0:
				button.size = _get_build_card_base_size(button)
			button.pivot_offset = button.size * 0.5
			button.set_meta("build_card_layout_position", button.position)
			button.set_meta("build_card_layout_scale", button.scale)
			var refresh_button := entry.get("refresh_button") as Button
			_layout_build_card_refresh_button(refresh_button, button)
			x += card_size.x + card_gap

	var role_count := level_talent_role_button_entries.size()
	if role_count > 0:
		var role_size: float = clamp(viewport.y * 0.24, 150.0, 210.0)
		var role_gap: float = clamp(viewport.x * 0.055, 34.0, 78.0)
		var total_role_width: float = role_size * float(role_count) + role_gap * float(max(0, role_count - 1))
		var role_x: float = (viewport.x - total_role_width) * 0.5
		var role_y: float = viewport.y * 0.34
		for entry in level_talent_role_button_entries:
			var role_button := (entry as Dictionary).get("button") as Button
			if role_button == null:
				continue
			role_button.size = Vector2(role_size, role_size)
			role_button.custom_minimum_size = role_button.size
			role_button.position = Vector2(role_x, role_y)
			role_button.pivot_offset = role_button.size * 0.5
			role_button.set_meta("level_talent_role_layout_position", role_button.position)
			_layout_level_talent_role_visual(role_button)
			role_x += role_size + role_gap

	var trait_count := trait_button_entries.size()
	var trait_scale: float = OPENING_TRAIT_BUTTON_SCALE if current_mode == "opening_trait" else TRAIT_BUTTON_SCALE
	var icon_size: float = clamp(viewport.y * 0.115, 92.0, 122.0) * trait_scale
	var icon_gap: float = clamp(viewport.x * 0.035, 36.0, 54.0) * trait_scale
	var description_height: float = 0.0
	if current_mode == "opening_trait":
		description_height = clamp(viewport.y * 0.13, 92.0, 132.0)
	var middle_trait_center_x := viewport.x * 0.5
	if trait_button_layer != null:
		trait_button_layer.visible = trait_count > 0
		var trait_sizes: Array[Vector2] = []
		var trait_width := 0.0
		var trait_height := 0.0
		for entry in trait_button_entries:
			var button := (entry as Dictionary).get("button") as Button
			var trait_size := _get_trait_button_size(button, icon_size)
			trait_sizes.append(trait_size)
			trait_width += trait_size.x
			trait_height = max(trait_height, trait_size.y + description_height)
		trait_width += icon_gap * float(max(0, trait_count - 1))
		var cards_bottom := base_card_y + _get_cards_height()
		var trait_y: float = viewport.y * 0.5 - trait_height * 0.5
		if current_mode != "opening_trait":
			trait_y = cards_bottom + clamp(viewport.y * 0.045, 38.0, 56.0)
		trait_button_layer.position = Vector2((viewport.x - trait_width) * 0.5, trait_y)
		trait_button_layer.size = Vector2(trait_width, trait_height)
		var trait_x := 0.0
		for index in range(trait_count):
			var entry: Dictionary = trait_button_entries[index]
			var button := entry.get("button") as Button
			if button == null:
				continue
			var trait_size: Vector2 = trait_sizes[index]
			var option: Dictionary = entry.get("option", {})
			var option_id := str(option.get("id", ""))
			var visual_offset: Vector2 = _get_trait_button_visual_offset(option_id)
			var trait_button_y := 0.0 if current_mode == "opening_trait" else (trait_height - trait_size.y) * 0.5
			button.position = Vector2(trait_x, trait_button_y) + visual_offset
			button.custom_minimum_size = trait_size
			button.size = trait_size
			button.set_meta("build_card_layout_position", button.position)
			button.set_meta("trait_option_id", option_id)
			_layout_trait_head(button, option_id == pending_attribute_option_id)
			_layout_opening_trait_description(button, option_id, trait_size, description_height)
			if index == int(trait_count / 2):
				middle_trait_center_x = trait_button_layer.position.x + button.position.x + trait_size.x * 0.5
			trait_x += trait_size.x + icon_gap

	if level_talent_back_button != null:
		level_talent_back_button.visible = _is_level_talent_role_detail_active()
		if level_talent_back_button.visible:
			level_talent_back_button.size = Vector2(144.0, 42.0)
			level_talent_back_button.custom_minimum_size = level_talent_back_button.size
			level_talent_back_button.position = Vector2(
				max(16.0, viewport.x - level_talent_back_button.size.x - 24.0),
				max(16.0, viewport.y * 0.04)
			)
			_raise_level_talent_back_button()

	if build_refresh_button != null:
		if current_mode == "opening_trait":
			build_refresh_button.visible = false
			return
		var refresh_size: float = clamp(viewport.y * 0.055, 50.0, 62.0)
		var trait_bottom := trait_button_layer.position.y + trait_button_layer.size.y if trait_button_layer != null and trait_button_layer.visible else base_card_y + _get_cards_height()
		var refresh_y: float = min(viewport.y - refresh_size - 28.0, trait_bottom + clamp(viewport.y * 0.060, 48.0, 66.0))
		build_refresh_button.position = Vector2(middle_trait_center_x - refresh_size * 0.5, refresh_y) + BUILD_REFRESH_BUTTON_VISUAL_OFFSET
		build_refresh_button.size = Vector2(refresh_size, refresh_size)
		build_refresh_button.custom_minimum_size = Vector2(refresh_size, refresh_size)
		build_refresh_button.pivot_offset = build_refresh_button.size * 0.5

func _get_cards_bottom() -> float:
	var bottom := 0.0
	for entry in build_card_entries:
		var button := (entry as Dictionary).get("button") as Control
		if button != null:
			bottom = max(bottom, button.position.y + _get_build_card_visual_size(button).y)
	return bottom

func _get_cards_height() -> float:
	var height := 0.0
	for entry in build_card_entries:
		var button := (entry as Dictionary).get("button") as Control
		height = max(height, _get_build_card_visual_size(button).y)
	return height

func _get_build_card_visual_size(button: Control) -> Vector2:
	var base_size := _get_build_card_base_size(button)
	if button == null:
		return base_size
	return Vector2(base_size.x * absf(button.scale.x), base_size.y * absf(button.scale.y))

func _get_build_card_design_visual_size(button: Control) -> Vector2:
	var base_size := _get_build_card_base_size(button)
	if button == null:
		return base_size
	var base_scale := _get_build_card_base_scale(button)
	return Vector2(base_size.x * absf(base_scale.x) * BUILD_CARD_DISPLAY_SCALE, base_size.y * absf(base_scale.y) * BUILD_CARD_DISPLAY_SCALE)

func _get_build_card_base_scale(button: Control) -> Vector2:
	if button != null and button.has_meta("build_card_base_scale"):
		var value: Variant = button.get_meta("build_card_base_scale")
		if value is Vector2:
			return value
	return button.scale if button != null else Vector2.ONE

func _get_build_card_fit_scale(viewport: Vector2, card_y: float) -> float:
	var card_count := build_card_entries.size()
	if card_count <= 0:
		return 1.0
	var total_width := 0.0
	for entry in build_card_entries:
		var button := (entry as Dictionary).get("button") as Control
		var visual_size := _get_build_card_design_visual_size(button)
		total_width += visual_size.x
	var gap: float = clamp(viewport.x * 0.030, 26.0, 56.0)
	var design_width: float = total_width + gap * float(max(0, card_count - 1))
	var available_width: float = max(1.0, viewport.x - 40.0)
	var fit_x: float = min(1.0, available_width / max(1.0, design_width))
	return clamp(fit_x, 0.45, 1.0)

func _get_build_card_base_size(button: Control) -> Vector2:
	if button == null:
		return BUILD_CARD_TEXTURE.get_size()
	if button.size.x > 0.0 and button.size.y > 0.0:
		return button.size
	if button.custom_minimum_size.x > 0.0 and button.custom_minimum_size.y > 0.0:
		return button.custom_minimum_size
	if button is TextureButton:
		var texture_button := button as TextureButton
		if texture_button.texture_normal != null:
			return texture_button.texture_normal.get_size()
	return BUILD_CARD_TEXTURE.get_size()

func _layout_build_card_refresh_button(refresh_button: Button, card: Control) -> void:
	if refresh_button == null or card == null:
		return
	refresh_button.visible = _should_show_build_card_refresh_buttons()
	var card_rect := _get_build_card_scaled_rect(card, _get_build_card_layout_position(card), _get_build_card_layout_scale(card))
	var refresh_size := BUILD_CARD_REFRESH_BUTTON_SIZE
	refresh_button.size = Vector2(refresh_size, refresh_size)
	refresh_button.custom_minimum_size = refresh_button.size
	refresh_button.position = Vector2(
		card_rect.get_center().x - refresh_size * 0.5,
		card_rect.end.y + BUILD_CARD_REFRESH_BUTTON_GAP
	)
	refresh_button.pivot_offset = refresh_button.size * 0.5
	refresh_button.set_meta("build_card_layout_position", refresh_button.position)
	_apply_build_card_refresh_button_state(refresh_button, int(refresh_button.get_meta("build_card_option_index", -1)))

func _get_refresh_button_for_card(card: Control) -> Button:
	for entry in build_card_entries:
		if entry is not Dictionary:
			continue
		if (entry as Dictionary).get("button") == card:
			return (entry as Dictionary).get("refresh_button") as Button
	return null

func _get_refresh_button_layout_position(refresh_button: Control) -> Vector2:
	if refresh_button != null and refresh_button.has_meta("build_card_layout_position"):
		var value: Variant = refresh_button.get_meta("build_card_layout_position")
		if value is Vector2:
			return value
	return refresh_button.position if refresh_button != null else Vector2.ZERO

func _apply_refresh_button_style() -> void:
	if build_refresh_button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.52, 1.0, 0.30)
	normal.border_color = Color(0.08, 0.52, 1.0, 0.0)
	normal.set_border_width_all(0)
	normal.set_corner_radius_all(64)
	build_refresh_button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.15, 0.62, 1.0, 0.38)
	build_refresh_button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.05, 0.42, 0.90, 0.30)
	build_refresh_button.add_theme_stylebox_override("pressed", pressed)
	var focus := StyleBoxEmpty.new()
	build_refresh_button.add_theme_stylebox_override("focus", focus)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.08, 0.24, 0.38, 0.30)
	build_refresh_button.add_theme_stylebox_override("disabled", disabled)
	build_refresh_button.add_theme_color_override("font_color", Color(0.66, 1.0, 1.0, 1.0))
	build_refresh_button.add_theme_color_override("font_hover_color", Color(0.82, 1.0, 1.0, 1.0))
	build_refresh_button.add_theme_color_override("font_pressed_color", Color(0.45, 0.86, 0.92, 1.0))
	build_refresh_button.add_theme_color_override("font_disabled_color", Color(0.45, 0.52, 0.56, 0.76))

func _apply_level_talent_back_button_style() -> void:
	if level_talent_back_button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.12, 0.16, 0.82)
	normal.border_color = Color(0.56, 0.72, 0.82, 0.62)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	level_talent_back_button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.28, 0.36, 0.94)
	hover.border_color = Color(0.78, 0.90, 0.96, 0.82)
	level_talent_back_button.add_theme_stylebox_override("hover", hover)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.10, 0.22, 0.30, 0.98)
	level_talent_back_button.add_theme_stylebox_override("pressed", pressed)
	level_talent_back_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	level_talent_back_button.add_theme_color_override("font_color", Color(0.86, 0.94, 0.98, 1.0))
	level_talent_back_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	level_talent_back_button.add_theme_color_override("font_pressed_color", Color(0.76, 0.88, 0.94, 1.0))
	level_talent_back_button.add_theme_font_size_override("font_size", 18)

func _raise_level_talent_back_button() -> void:
	if build_root == null or level_talent_back_button == null:
		return
	if level_talent_back_button.get_parent() != build_root:
		return
	build_root.move_child(level_talent_back_button, build_root.get_child_count() - 1)

func _apply_card_refresh_button_style(button: Button) -> void:
	if button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.30, 0.46, 0.34)
	normal.border_color = Color(0.56, 0.72, 0.82, 0.46)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(64)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.18, 0.38, 0.56, 0.46)
	hover.border_color = Color(0.68, 0.82, 0.90, 0.58)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.10, 0.24, 0.40, 0.54)
	button.add_theme_stylebox_override("pressed", pressed)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.08, 0.12, 0.16, 0.22)
	disabled.border_color = Color(0.32, 0.40, 0.44, 0.28)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _update_build_refresh_button() -> void:
	if build_refresh_button == null:
		return
	build_refresh_button.visible = false
	build_refresh_button.disabled = true
	build_refresh_button.tooltip_text = ""

func _is_upgrade_refresh_unlimited() -> bool:
	return bool(current_offer_context.get("refresh_unlimited", false))

func _can_refresh_current_offer() -> bool:
	return false

func _should_show_build_card_refresh_buttons() -> bool:
	return _is_build_multi_select_offer() or (_is_level_talent_offer() and not _is_level_talent_role_select_active())

func _get_build_card_display_count() -> int:
	return 3 if _is_level_talent_role_detail_active() else BUILD_CARD_OPTION_COUNT

func _is_build_card_refresh_used(option_index: int) -> bool:
	return bool(build_card_refresh_used_indices.get(_get_build_card_refresh_key(option_index), false))

func _apply_build_card_refresh_button_state(button: Button, option_index: int) -> void:
	if button == null:
		return
	var used := _is_build_card_refresh_used(option_index)
	button.disabled = used or build_refresh_animation_in_progress or build_selection_in_progress
	var available_tip := "刷新这张天赋" if _is_level_talent_offer() else "刷新这张构筑"
	var used_tip := "本次天赋已刷新" if _is_level_talent_offer() else "本次升级已刷新"
	button.tooltip_text = used_tip if used else available_tip
	var icon := button.get_node_or_null("RefreshIcon") as TextureRect
	if icon != null:
		icon.modulate = Color(0.78, 0.88, 0.92, 0.24) if used else Color(0.78, 0.88, 0.92, 0.62)

func _with_trait_display_overrides(raw_option: Dictionary) -> Dictionary:
	var option := raw_option.duplicate(true)
	var option_id := str(option.get("id", ""))
	if TRAIT_DETAIL_DESCRIPTIONS.has(option_id):
		option["description"] = str(TRAIT_DETAIL_DESCRIPTIONS.get(option_id, ""))
		option["preview_description"] = str(TRAIT_DETAIL_DESCRIPTIONS.get(option_id, ""))
		option["exact_description"] = str(TRAIT_DETAIL_DESCRIPTIONS.get(option_id, ""))
	return option

func _get_trait_options() -> Array:
	var trait_options: Array = []
	for raw_option in current_attribute_options:
		if raw_option is not Dictionary:
			continue
		var option: Dictionary = _with_trait_display_overrides(raw_option)
		if TRAIT_HEAD_SCENES.has(str(option.get("id", ""))):
			trait_options.append(option)
	return trait_options

func _select_default_attribute_option() -> void:
	var trait_options := _get_trait_options()
	if trait_options.is_empty():
		pending_attribute_option_id = ""
		pending_attribute_title = ""
		return
	var selected_option: Dictionary = trait_options[0]
	for raw_option in trait_options:
		var option: Dictionary = raw_option
		if str(option.get("id", "")) == preferred_attribute_option_id:
			selected_option = option
			break
	_set_attribute_selection(selected_option, preferred_attribute_option_id == "")

func _set_attribute_selection(option: Dictionary, persist: bool = true) -> void:
	pending_attribute_option_id = str(option.get("id", ""))
	pending_attribute_title = str(option.get("title", "英雄特性"))
	if persist:
		preferred_attribute_option_id = pending_attribute_option_id
	_update_trait_button_styles()

func _update_trait_button_styles() -> void:
	for entry in trait_button_entries:
		if entry is not Dictionary:
			continue
		var button := entry.get("button") as Button
		var option: Dictionary = entry.get("option", {})
		if button == null:
			continue
		var selected := str(option.get("id", "")) == pending_attribute_option_id
		_apply_trait_button_style(button, selected)

func _apply_trait_button_style(button: Button, selected: bool) -> void:
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.add_theme_stylebox_override("disabled", empty)
	if current_mode == "opening_trait":
		button.modulate = OPENING_TRAIT_IDLE_MODULATE
	else:
		button.modulate = Color(1.0, 1.0, 1.0, 1.0) if selected else Color(0.72, 0.76, 0.80, 0.88)
	_layout_trait_head(button, selected)

func _layout_trait_head(button: Button, selected: bool) -> void:
	var head := button.get_node_or_null("TraitHead") as Node2D
	if head == null:
		return
	var sprite := head.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.texture == null:
		head.position = button.size * 0.5
		return
	var target_diameter: float = max(1.0, min(button.size.x, button.size.y))
	var texture_size := sprite.texture.get_size()
	var fit_scale: float = target_diameter / max(1.0, max(texture_size.x, texture_size.y))
	var base_scale: Vector2 = Vector2.ONE
	if head.has_meta("base_scale"):
		var value: Variant = head.get_meta("base_scale")
		if value is Vector2:
			base_scale = value
	head.position = button.size * 0.5
	head.scale = base_scale * fit_scale

func _layout_level_talent_role_visual(button: Button) -> void:
	if button == null:
		return
	var visual := button.get_node_or_null("LevelTalentRoleVisual") as Node2D
	if visual == null:
		return
	var base_scale := Vector2.ONE
	var base_scale_value: Variant = visual.get_meta("base_scale", Vector2.ONE)
	if base_scale_value is Vector2:
		base_scale = base_scale_value
	var target_size: float = min(button.size.x, button.size.y) * LEVEL_TALENT_ROLE_BUTTON_SCALE / 4.0
	var visual_scale: float = target_size / 40.0
	visual.scale = base_scale * visual_scale
	visual.position = button.size * 0.5 - Vector2(20.0, 20.0) * visual.scale

func _apply_level_talent_role_button_style(button: Button) -> void:
	if button == null:
		return
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.add_theme_stylebox_override("disabled", empty)

func _get_trait_button_visual_offset(option_id: String) -> Vector2:
	if current_mode == "opening_trait":
		return OPENING_TRAIT_BUTTON_VISUAL_OFFSETS.get(option_id, Vector2.ZERO)
	return TRAIT_BUTTON_VISUAL_OFFSETS.get(option_id, Vector2.ZERO)

func _layout_opening_trait_description(button: Button, option_id: String, trait_size: Vector2, description_height: float) -> void:
	var description := button.get_node_or_null("OpeningDescription") as Label
	if description == null:
		return
	description.visible = current_mode == "opening_trait"
	if not description.visible:
		return
	description.text = str(TRAIT_OPENING_DESCRIPTIONS.get(option_id, ""))
	var description_width := trait_size.x * 0.86
	description.position = Vector2((trait_size.x - description_width) * 0.5, trait_size.y + TRAIT_BUTTON_DESCRIPTION_GAP) + OPENING_TRAIT_DESCRIPTION_OFFSETS.get(option_id, Vector2.ZERO)
	description.size = Vector2(description_width, description_height)

func _get_trait_button_size(button: Button, fallback_size: float) -> Vector2:
	return Vector2(fallback_size, fallback_size)

func _on_build_card_pressed(card: TextureButton, option: Dictionary) -> void:
	if build_selection_in_progress:
		return
	var option_id := str(option.get("id", ""))
	var option_title := str(option.get("title", "祝福"))
	if _is_build_multi_select_offer():
		if pending_blessing_option_ids.has(option_id):
			var selected_index := pending_blessing_option_ids.find(option_id)
			pending_blessing_option_ids.remove_at(selected_index)
			if selected_index >= 0 and selected_index < pending_blessing_titles.size():
				pending_blessing_titles.remove_at(selected_index)
			_sync_primary_build_selection()
			_mark_build_card_selected(card, false)
			card.disabled = false
			_hide_build_item_detail()
			_update_selection_hint()
			_refresh_selected_cards()
			return
		pending_blessing_option_ids.append(option_id)
		pending_blessing_titles.append(option_title)
		_sync_primary_build_selection()
		_mark_build_card_selected(card, true)
		_hide_build_item_detail()
		_update_selection_hint()
		_refresh_selected_cards()
		if pending_blessing_option_ids.size() < _get_build_selection_count():
			return
		build_selection_in_progress = true
		_set_build_overlay_input_enabled(false, card)
		await _play_build_card_select_animation(card)
		var first_option_id: String = pending_blessing_option_ids[0]
		var second_option_id: String = pending_blessing_option_ids[1] if pending_blessing_option_ids.size() > 1 else ""
		upgrade_selected.emit(first_option_id, second_option_id)
		return
	build_selection_in_progress = true
	pending_blessing_option_id = option_id
	pending_blessing_title = option_title
	_hide_build_item_detail()
	_set_build_overlay_input_enabled(false, card)
	await _play_build_card_select_animation(card)
	upgrade_selected.emit(pending_blessing_option_id, pending_attribute_option_id)

func _on_build_card_refresh_pressed(option_index: int) -> void:
	if current_mode != "blessing":
		return
	if build_selection_in_progress or build_refresh_animation_in_progress:
		return
	if not _should_show_build_card_refresh_buttons():
		return
	if _is_build_card_refresh_used(option_index):
		return
	var old_option_id := _get_current_build_option_id_at(option_index)
	if old_option_id != "":
		_remove_pending_build_selection(old_option_id)
		_sync_primary_build_selection()
		_update_selection_hint()
		_refresh_selected_cards()
		_refresh_build_card_selected_outlines()
	build_refresh_animation_in_progress = true
	_hide_build_item_detail()
	build_card_refresh_used_indices[_get_build_card_refresh_key(option_index)] = true
	_apply_build_card_refresh_button_state(_get_refresh_button_for_option_index(option_index), option_index)
	_set_build_overlay_input_enabled(false)
	var refresh_button := _get_refresh_button_for_option_index(option_index)
	await _play_card_refresh_button_click_animation(refresh_button)
	upgrade_card_refresh_requested.emit(option_index)

func _on_trait_button_pressed(button: Button, option: Dictionary) -> void:
	if build_selection_in_progress:
		return
	if current_mode == "opening_trait":
		build_selection_in_progress = true
		_hide_build_item_detail()
		_set_build_overlay_input_enabled(false, button)
		await _play_trait_button_select_animation(button)
		_set_attribute_selection(option, true)
		upgrade_selected.emit("", str(option.get("id", "")))
		return
	_set_attribute_selection(option, true)

func _on_trait_button_mouse_entered(button: Button, item: Dictionary) -> void:
	_animate_trait_button_hover(button, true)
	_on_build_item_mouse_entered(button, item)

func _on_trait_button_mouse_exited(button: Button, item: Dictionary) -> void:
	_animate_trait_button_hover(button, false)
	_on_build_item_mouse_exited(button, item)

func _on_level_talent_role_button_mouse_entered(button: Button) -> void:
	if button == null or build_selection_in_progress or build_refresh_animation_in_progress:
		return
	button.modulate = Color(1.16, 1.16, 1.16, 1.0)

func _on_level_talent_role_button_mouse_exited(button: Button) -> void:
	if button == null:
		return
	button.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_level_talent_role_button_pressed(button: Button, option: Dictionary) -> void:
	if button == null or build_selection_in_progress or build_refresh_animation_in_progress:
		return
	var role_id := str(option.get("role_id", ""))
	var raw_options: Variant = option.get("level_talent_options", [])
	if role_id == "" or raw_options is not Array:
		return
	var nested_options := _duplicate_option_array(raw_options as Array)
	level_talent_selected_role_id = role_id
	current_options = nested_options
	option_groups = _group_options(current_options, BLESSING_SLOT_ORDER)
	pending_blessing_option_id = ""
	pending_blessing_title = ""
	pending_blessing_option_ids.clear()
	pending_blessing_titles.clear()
	_hide_build_item_detail()
	_rebuild_build_overlay()

func _on_level_talent_back_pressed() -> void:
	if build_selection_in_progress or build_refresh_animation_in_progress:
		return
	if not _is_level_talent_role_detail_active():
		return
	level_talent_selected_role_id = ""
	current_options = _duplicate_option_array(level_talent_role_options)
	option_groups = _group_options(current_options, BLESSING_SLOT_ORDER)
	pending_blessing_option_id = ""
	pending_blessing_title = ""
	pending_blessing_option_ids.clear()
	pending_blessing_titles.clear()
	_hide_build_item_detail()
	_rebuild_build_overlay()

func _on_level_talent_back_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or mouse_event.pressed:
		return
	_on_level_talent_back_pressed()
	get_viewport().set_input_as_handled()

func _handle_level_talent_back_input(event: InputEvent) -> bool:
	if level_talent_back_button == null or not level_talent_back_button.visible or level_talent_back_button.disabled:
		return false
	if not _is_level_talent_role_detail_active():
		return false
	if not (event is InputEventMouseButton):
		return false
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or mouse_event.pressed:
		return false
	if not level_talent_back_button.get_global_rect().has_point(mouse_event.position):
		return false
	_on_level_talent_back_pressed()
	get_viewport().set_input_as_handled()
	return true

func _on_build_card_mouse_entered(card: TextureButton, item: Dictionary) -> void:
	_animate_build_card_hover(card, true)
	_on_build_item_mouse_entered(card, item)

func _on_build_card_mouse_exited(card: TextureButton) -> void:
	_animate_build_card_hover(card, false)
	_on_build_item_mouse_exited(card, {})

func _is_build_multi_select_offer() -> bool:
	return current_mode == "blessing" and bool(current_offer_context.get("role_build_offer", false))

func _is_level_talent_offer() -> bool:
	return current_mode == "blessing" and bool(current_offer_context.get("level_talent_offer", false))

func _is_level_talent_role_select_active() -> bool:
	return _is_level_talent_offer() and level_talent_selected_role_id == "" and not level_talent_role_options.is_empty()

func _is_level_talent_role_detail_active() -> bool:
	return _is_level_talent_offer() and level_talent_selected_role_id != ""

func _offer_has_level_talent_role_entries(options: Array) -> bool:
	for option_value in options:
		if option_value is Dictionary and bool((option_value as Dictionary).get("level_talent_role_entry", false)):
			return true
	return false

func _set_level_talent_role_detail_options(role_id: String, options: Array) -> void:
	if role_id == "":
		return
	var nested_options := _duplicate_option_array(options)
	for index in range(level_talent_role_options.size()):
		var option_value: Variant = level_talent_role_options[index]
		if option_value is not Dictionary:
			continue
		var option: Dictionary = option_value
		if str(option.get("role_id", "")) == role_id:
			option["level_talent_options"] = nested_options
			level_talent_role_options[index] = option
			return

func get_level_talent_selected_role_id() -> String:
	return level_talent_selected_role_id

func _get_build_selection_count() -> int:
	if not _is_build_multi_select_offer():
		return 1
	return max(1, int(current_offer_context.get("selection_count", 2)))

func _get_current_build_option_id_at(option_index: int) -> String:
	if option_index < 0 or option_index >= current_options.size():
		return ""
	var option = current_options[option_index]
	if option is Dictionary:
		return str((option as Dictionary).get("id", ""))
	return ""

func _get_build_card_refresh_key(option_index: int) -> String:
	var scope := "build"
	if _is_level_talent_role_detail_active():
		scope = "level_talent:%s" % level_talent_selected_role_id
	return "%s:%d" % [scope, option_index]

func _get_refresh_button_for_option_index(option_index: int) -> Button:
	for entry in build_card_entries:
		if entry is not Dictionary:
			continue
		if int((entry as Dictionary).get("option_index", -1)) == option_index:
			return (entry as Dictionary).get("refresh_button") as Button
	return null

func _sync_primary_build_selection() -> void:
	if pending_blessing_option_ids.is_empty():
		pending_blessing_option_id = ""
		pending_blessing_title = ""
		return
	pending_blessing_option_id = pending_blessing_option_ids[0]
	pending_blessing_title = pending_blessing_titles[0] if pending_blessing_titles.size() > 0 else ""

func _remove_pending_build_selection(option_id: String) -> void:
	if option_id == "":
		return
	var selected_index := pending_blessing_option_ids.find(option_id)
	while selected_index >= 0:
		pending_blessing_option_ids.remove_at(selected_index)
		if selected_index >= 0 and selected_index < pending_blessing_titles.size():
			pending_blessing_titles.remove_at(selected_index)
		selected_index = pending_blessing_option_ids.find(option_id)
	if pending_blessing_option_id == option_id:
		pending_blessing_option_id = ""
		pending_blessing_title = ""

func _prune_pending_build_selections() -> void:
	var current_ids := {}
	for option in current_options:
		if option is Dictionary:
			var option_id := str((option as Dictionary).get("id", ""))
			if option_id != "":
				current_ids[option_id] = true
	var index := pending_blessing_option_ids.size() - 1
	while index >= 0:
		var option_id := pending_blessing_option_ids[index]
		if not current_ids.has(option_id):
			pending_blessing_option_ids.remove_at(index)
			if index < pending_blessing_titles.size():
				pending_blessing_titles.remove_at(index)
		index -= 1
	if pending_blessing_option_id != "" and not current_ids.has(pending_blessing_option_id):
		pending_blessing_option_id = ""
		pending_blessing_title = ""

func _mark_build_card_selected(card: TextureButton, selected: bool) -> void:
	if card == null:
		return
	var hover_frame := card.get_node_or_null("HoverFrame") as Control
	if hover_frame != null:
		hover_frame.visible = false
	var selected_outline := _ensure_build_card_selected_outline(card)
	if selected_outline != null:
		selected_outline.visible = selected

func _refresh_build_card_selected_outlines() -> void:
	for entry in build_card_entries:
		if entry is not Dictionary:
			continue
		var card := (entry as Dictionary).get("button") as TextureButton
		var option: Dictionary = (entry as Dictionary).get("option", {})
		var option_id := str(option.get("id", ""))
		_mark_build_card_selected(card, pending_blessing_option_ids.has(option_id) or pending_blessing_option_id == option_id)

func _animate_build_card_hover(card: TextureButton, hovered: bool) -> void:
	if card == null:
		return
	if build_selection_in_progress or build_refresh_animation_in_progress:
		return
	var key := card.get_instance_id()
	var old_tween := build_card_hover_tweens.get(key) as Tween
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	var layout_position: Vector2 = card.position
	if card.has_meta("build_card_layout_position"):
		var position_value: Variant = card.get_meta("build_card_layout_position")
		if position_value is Vector2:
			layout_position = position_value
	var layout_scale: Vector2 = card.scale
	if card.has_meta("build_card_layout_scale"):
		var scale_value: Variant = card.get_meta("build_card_layout_scale")
		if scale_value is Vector2:
			layout_scale = scale_value
	card.z_index = 20 if hovered else 0
	var target_position := layout_position + Vector2(0.0, -10.0) if hovered else layout_position
	var target_scale := layout_scale
	var target_modulate := Color(1.08, 1.08, 1.08, 1.0) if hovered else Color(1.0, 1.0, 1.0, 1.0)
	var refresh_button := _get_refresh_button_for_card(card)
	var refresh_layout_position := _get_refresh_button_layout_position(refresh_button)
	var refresh_target_position := refresh_layout_position + Vector2(0.0, -10.0) if hovered else refresh_layout_position
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position", target_position, 0.12)
	tween.tween_property(card, "scale", target_scale, 0.12)
	tween.tween_property(card, "modulate", target_modulate, 0.12)
	if refresh_button != null:
		tween.tween_property(refresh_button, "position", refresh_target_position, 0.12)
	build_card_hover_tweens[key] = tween

func _play_build_refresh_collapse_animation() -> void:
	var cards := _get_visible_build_cards()
	if cards.is_empty():
		return
	var center := _get_build_cards_layout_center(cards)
	var duration := BUILD_REFRESH_ANIMATION_TIME * BUILD_REFRESH_COLLAPSE_RATIO
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	for card in cards:
		_kill_build_card_tween(card)
		var layout_position := _get_build_card_layout_position(card)
		var layout_scale := _get_build_card_layout_scale(card)
		var collapsed_position := _get_build_card_position_for_center(card, center)
		card.z_index = 10
		card.modulate = Color(1.0, 1.0, 1.0, 1.0)
		tween.tween_property(card, "position", collapsed_position, duration)
		tween.tween_property(card, "modulate", Color(1.0, 1.0, 1.0, BUILD_REFRESH_COLLAPSED_ALPHA), duration)
		tween.tween_property(card, "scale", layout_scale * BUILD_REFRESH_COLLAPSED_SCALE, duration)
	await tween.finished
	for card in cards:
		_set_build_card_text_visible(card, false)
	var hold_timer := get_tree().create_timer(BUILD_REFRESH_TEXT_HIDDEN_HOLD, true)
	await hold_timer.timeout

func _play_build_refresh_expand_animation() -> void:
	var cards := _get_visible_build_cards()
	if cards.is_empty():
		build_refresh_animation_in_progress = false
		_update_build_refresh_button()
		return
	build_refresh_animation_in_progress = true
	_set_build_overlay_input_enabled(false)
	var center := _get_build_cards_layout_center(cards)
	var duration := BUILD_REFRESH_ANIMATION_TIME * (1.0 - BUILD_REFRESH_COLLAPSE_RATIO)
	for card in cards:
		_kill_build_card_tween(card)
		_set_build_card_text_visible(card, false)
		card.position = _get_build_card_position_for_center(card, center)
		card.scale = _get_build_card_layout_scale(card) * BUILD_REFRESH_COLLAPSED_SCALE
		card.modulate = Color(1.0, 1.0, 1.0, BUILD_REFRESH_COLLAPSED_ALPHA)
		card.z_index = 10
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	for card in cards:
		tween.tween_property(card, "position", _get_build_card_layout_position(card), duration)
		tween.tween_property(card, "scale", _get_build_card_layout_scale(card), duration)
		tween.tween_property(card, "modulate", Color(1.0, 1.0, 1.0, 1.0), duration)
	await tween.finished
	for card in cards:
		if card != null and is_instance_valid(card):
			card.z_index = 0
			_set_build_card_text_visible(card, true)
	build_refresh_animation_in_progress = false
	_set_build_overlay_input_enabled(true)
	_update_build_refresh_button()
	_play_pending_tier_four_card_intro_effects()

func _play_pending_tier_four_card_intro_effects() -> void:
	for entry in build_card_entries:
		if entry is not Dictionary:
			continue
		var card := entry.get("button") as TextureButton
		if card == null or not is_instance_valid(card):
			continue
		if not bool(card.get_meta("build_card_intro_pending", false)):
			continue
		card.set_meta("build_card_intro_pending", false)
		_play_tier_four_card_intro_effect(card)

func _play_tier_four_card_intro_effect(card: TextureButton) -> void:
	if card == null or not is_instance_valid(card):
		return
	_kill_build_card_tween(card)
	var layout_position := _get_build_card_layout_position(card)
	var key := card.get_instance_id()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	var shake_motion_time: float = TIER_FOUR_CARD_SHAKE_TIME * 0.75
	var return_time: float = TIER_FOUR_CARD_SHAKE_TIME * 0.25
	var shake_step: float = shake_motion_time / 4.0
	tween.tween_property(card, "position", layout_position + Vector2(TIER_FOUR_CARD_SHAKE_DISTANCE, 0.0), shake_step)
	tween.tween_property(card, "position", layout_position + Vector2(0.0, -TIER_FOUR_CARD_SHAKE_DISTANCE), shake_step)
	tween.tween_property(card, "position", layout_position + Vector2(-TIER_FOUR_CARD_SHAKE_DISTANCE, 0.0), shake_step)
	tween.tween_property(card, "position", layout_position + Vector2(0.0, TIER_FOUR_CARD_SHAKE_DISTANCE), shake_step)
	tween.tween_property(card, "position", layout_position, return_time)
	build_card_hover_tweens[key] = tween

func _play_build_refresh_button_click_animation() -> void:
	if build_refresh_button == null:
		return
	if build_refresh_button_rotation_tween != null and build_refresh_button_rotation_tween.is_valid():
		build_refresh_button_rotation_tween.kill()
	build_refresh_button.rotation = 0.0
	build_refresh_button.pivot_offset = build_refresh_button.size * 0.5
	build_refresh_button_rotation_tween = create_tween()
	build_refresh_button_rotation_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	build_refresh_button_rotation_tween.set_trans(Tween.TRANS_QUAD)
	build_refresh_button_rotation_tween.set_ease(Tween.EASE_OUT)
	build_refresh_button_rotation_tween.tween_property(
		build_refresh_button,
		"rotation",
		deg_to_rad(BUILD_REFRESH_BUTTON_ROTATION_DEGREES),
		BUILD_REFRESH_BUTTON_ROTATION_TIME
	)
	build_refresh_button_rotation_tween.tween_callback(Callable(self, "_reset_build_refresh_button_rotation"))

func _reset_build_refresh_button_rotation() -> void:
	if build_refresh_button != null:
		build_refresh_button.rotation = 0.0

func _play_card_refresh_button_click_animation(refresh_button: Button) -> void:
	if refresh_button == null or not is_instance_valid(refresh_button):
		return
	refresh_button.rotation = 0.0
	refresh_button.pivot_offset = refresh_button.size * 0.5
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		refresh_button,
		"rotation",
		deg_to_rad(BUILD_CARD_REFRESH_BUTTON_ROTATION_DEGREES),
		BUILD_CARD_REFRESH_BUTTON_ROTATION_TIME
	)
	await tween.finished
	if refresh_button != null and is_instance_valid(refresh_button):
		refresh_button.rotation = 0.0

func _play_refreshed_build_card_feedback(option_index: int) -> void:
	if option_index < 0:
		return
	for entry in build_card_entries:
		if entry is not Dictionary:
			continue
		if int((entry as Dictionary).get("option_index", -1)) != option_index:
			continue
		var card := (entry as Dictionary).get("button") as TextureButton
		if card == null or not is_instance_valid(card):
			return
		var key := card.get_instance_id()
		var old_tween := build_card_hover_tweens.get(key) as Tween
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()
		card.modulate = Color(1.25, 1.25, 1.25, 1.0)
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18)
		build_card_hover_tweens[key] = tween
		return

func _get_visible_build_cards() -> Array[Control]:
	var cards: Array[Control] = []
	for entry in build_card_entries:
		if entry is not Dictionary:
			continue
		var card := entry.get("button") as Control
		if card != null and is_instance_valid(card) and card.visible:
			cards.append(card)
	return cards

func _get_build_cards_layout_center(cards: Array[Control]) -> Vector2:
	var bounds := Rect2()
	var has_bounds := false
	for card in cards:
		var rect := _get_build_card_scaled_rect(card, _get_build_card_layout_position(card), _get_build_card_layout_scale(card))
		if has_bounds:
			bounds = bounds.merge(rect)
		else:
			bounds = rect
			has_bounds = true
	return bounds.get_center() if has_bounds else Vector2.ZERO

func _get_build_card_position_for_center(card: Control, center: Vector2) -> Vector2:
	if card == null:
		return center
	return center - card.pivot_offset

func _get_build_card_layout_position(card: Control) -> Vector2:
	if card != null and card.has_meta("build_card_layout_position"):
		var value: Variant = card.get_meta("build_card_layout_position")
		if value is Vector2:
			return value
	return card.position if card != null else Vector2.ZERO

func _get_build_card_layout_scale(card: Control) -> Vector2:
	if card != null and card.has_meta("build_card_layout_scale"):
		var value: Variant = card.get_meta("build_card_layout_scale")
		if value is Vector2:
			return value
	return card.scale if card != null else Vector2.ONE

func _kill_build_card_tween(card: Control) -> void:
	if card == null:
		return
	var key := card.get_instance_id()
	var old_tween := build_card_hover_tweens.get(key) as Tween
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	build_card_hover_tweens.erase(key)

func _set_build_card_text_visible(card: Control, text_visible: bool) -> void:
	if card == null:
		return
	var content := card.get_node_or_null("Margin/Content") as Control
	if content != null:
		content.visible = text_visible
	for child in card.get_children():
		_set_label_subtree_visible(child, text_visible)

func _set_label_subtree_visible(node: Node, text_visible: bool) -> void:
	if node is Label:
		(node as Label).visible = text_visible
	for child in node.get_children():
		_set_label_subtree_visible(child, text_visible)

func _animate_trait_button_hover(button: Button, hovered: bool) -> void:
	if button == null:
		return
	if build_selection_in_progress:
		return
	var key := button.get_instance_id()
	var old_tween := build_card_hover_tweens.get(key) as Tween
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	var layout_position: Vector2 = button.position
	if button.has_meta("build_card_layout_position"):
		var position_value: Variant = button.get_meta("build_card_layout_position")
		if position_value is Vector2:
			layout_position = position_value
	button.z_index = 20 if hovered else 0
	var target_position := layout_position + Vector2(0.0, -10.0) if hovered else layout_position
	var selected := str(button.get_meta("trait_option_id", "")) == pending_attribute_option_id
	var base_modulate := Color(1.0, 1.0, 1.0, 1.0) if selected else Color(0.72, 0.76, 0.80, 0.88)
	if current_mode == "opening_trait":
		base_modulate = OPENING_TRAIT_IDLE_MODULATE
	var target_modulate := OPENING_TRAIT_HOVER_MODULATE if current_mode == "opening_trait" and hovered else (Color(1.08, 1.08, 1.08, 1.0) if hovered else base_modulate)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "position", target_position, 0.12)
	tween.tween_property(button, "modulate", target_modulate, 0.12)
	build_card_hover_tweens[key] = tween

func _play_trait_button_select_animation(button: Button) -> void:
	if button == null or not is_instance_valid(button):
		return
	var key := button.get_instance_id()
	var old_tween := build_card_hover_tweens.get(key) as Tween
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	var layout_position: Vector2 = button.position
	if button.has_meta("build_card_layout_position"):
		var position_value: Variant = button.get_meta("build_card_layout_position")
		if position_value is Vector2:
			layout_position = position_value
	button.position = layout_position
	button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	button.z_index = 50
	_hide_unselected_trait_overlay_parts(button)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	var shake_step := BUILD_CARD_SELECT_SHAKE_TIME / 4.0
	tween.tween_property(button, "position", layout_position + Vector2(6.0, 0.0), shake_step)
	tween.tween_property(button, "position", layout_position + Vector2(-6.0, 0.0), shake_step)
	tween.tween_property(button, "position", layout_position + Vector2(3.0, 0.0), shake_step)
	tween.tween_property(button, "position", layout_position, shake_step)
	tween.tween_property(button, "modulate", Color(1.0, 1.0, 1.0, 0.0), BUILD_CARD_SELECT_ANIM_TIME)
	var hold_timer := get_tree().create_timer(BUILD_CARD_SELECT_SHAKE_TIME + BUILD_CARD_SELECT_ANIM_TIME, true)
	await hold_timer.timeout

func _play_build_card_select_animation(card: TextureButton) -> void:
	if card == null or not is_instance_valid(card):
		return
	var key := card.get_instance_id()
	var old_tween := build_card_hover_tweens.get(key) as Tween
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	var layout_position: Vector2 = card.position
	if card.has_meta("build_card_layout_position"):
		var position_value: Variant = card.get_meta("build_card_layout_position")
		if position_value is Vector2:
			layout_position = position_value
	var layout_scale: Vector2 = card.scale
	if card.has_meta("build_card_layout_scale"):
		var scale_value: Variant = card.get_meta("build_card_layout_scale")
		if scale_value is Vector2:
			layout_scale = scale_value
	card.position = layout_position
	card.scale = layout_scale
	card.modulate = Color(1.0, 1.0, 1.0, 1.0)
	card.z_index = 50
	_hide_unselected_build_overlay_parts(card)
	var card_tween := create_tween()
	card_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	card_tween.set_trans(Tween.TRANS_SINE)
	card_tween.set_ease(Tween.EASE_OUT)
	var shake_step := BUILD_CARD_SELECT_SHAKE_TIME / 4.0
	card_tween.tween_property(card, "position", layout_position + Vector2(6.0, 0.0), shake_step)
	card_tween.tween_property(card, "position", layout_position + Vector2(-6.0, 0.0), shake_step)
	card_tween.tween_property(card, "position", layout_position + Vector2(3.0, 0.0), shake_step)
	card_tween.tween_property(card, "position", layout_position, shake_step)
	card_tween.tween_property(card, "modulate", Color(1.0, 1.0, 1.0, 0.0), BUILD_CARD_SELECT_ANIM_TIME)
	var hold_timer := get_tree().create_timer(BUILD_CARD_SELECT_SHAKE_TIME + BUILD_CARD_SELECT_ANIM_TIME, true)
	await hold_timer.timeout

func _hide_unselected_build_overlay_parts(selected_card: Control) -> void:
	if build_dimmer != null:
		build_dimmer.visible = false
	if trait_button_layer != null:
		trait_button_layer.visible = false
	if build_refresh_button != null:
		build_refresh_button.visible = false
	if level_talent_back_button != null:
		level_talent_back_button.visible = false
	for entry in level_talent_role_button_entries:
		if entry is not Dictionary:
			continue
		var role_button := entry.get("button") as Control
		if role_button != null:
			role_button.visible = false
	for entry in build_card_entries:
		if entry is not Dictionary:
			continue
		var card := entry.get("button") as Control
		if card != null and card != selected_card:
			card.visible = false
		var refresh_button := entry.get("refresh_button") as Control
		if refresh_button != null:
			refresh_button.visible = false

func _hide_unselected_trait_overlay_parts(selected_button: Control) -> void:
	if build_dimmer != null:
		build_dimmer.visible = false
	if opening_prompt_label != null:
		opening_prompt_label.visible = false
	if build_refresh_button != null:
		build_refresh_button.visible = false
	for entry in build_card_entries:
		if entry is not Dictionary:
			continue
		var card := entry.get("button") as Control
		if card != null:
			card.visible = false
		var refresh_button := entry.get("refresh_button") as Control
		if refresh_button != null:
			refresh_button.visible = false
	if trait_button_layer != null:
		trait_button_layer.visible = true
	for entry in trait_button_entries:
		if entry is not Dictionary:
			continue
		var button := entry.get("button") as Control
		if button != null and button != selected_button:
			button.visible = false

func _get_build_card_scaled_rect(card: Control, card_position: Vector2, card_scale: Vector2) -> Rect2:
	var base_size := _get_build_card_base_size(card)
	var pivot := card.pivot_offset
	var visual_size := Vector2(base_size.x * absf(card_scale.x), base_size.y * absf(card_scale.y))
	var visual_position := card_position + pivot - Vector2(pivot.x * card_scale.x, pivot.y * card_scale.y)
	return Rect2(visual_position, visual_size)

func _set_build_overlay_input_enabled(enabled: bool, selected_card: BaseButton = null) -> void:
	for entry in build_card_entries:
		if entry is not Dictionary:
			continue
		var card := entry.get("button") as BaseButton
		if card != null:
			card.disabled = not enabled and card != selected_card
		var refresh_button := entry.get("refresh_button") as BaseButton
		if refresh_button != null:
			var option_index := int((entry as Dictionary).get("option_index", -1))
			refresh_button.disabled = not enabled or _is_build_card_refresh_used(option_index)
	for entry in trait_button_entries:
		if entry is not Dictionary:
			continue
		var button := entry.get("button") as BaseButton
		if button != null:
			button.disabled = not enabled
	for entry in level_talent_role_button_entries:
		if entry is not Dictionary:
			continue
		var role_button := entry.get("button") as BaseButton
		if role_button != null:
			role_button.disabled = not enabled
	if level_talent_back_button != null:
		level_talent_back_button.disabled = not enabled
	if build_refresh_button != null:
		build_refresh_button.disabled = not enabled or not _can_refresh_current_offer()

func _on_build_item_mouse_entered(control: Control, item: Dictionary) -> void:
	if control == active_build_detail_control:
		_cancel_build_detail_hide()
	pending_build_detail_control = control
	pending_build_detail_item = item.duplicate(true)
	if build_detail_hover_timer != null:
		build_detail_hover_timer.start(BUILD_DETAIL_HOVER_DELAY)

func _on_build_item_mouse_exited(control: Control, item: Dictionary) -> void:
	if control == pending_build_detail_control:
		pending_build_detail_control = null
		pending_build_detail_item = {}
		if build_detail_hover_timer != null:
			build_detail_hover_timer.stop()
	if control == active_build_detail_control:
		_schedule_build_detail_hide()

func _on_build_item_gui_input(event: InputEvent, control: Control, item: Dictionary) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_toggle_build_item_detail(control, item)
			get_viewport().set_input_as_handled()

func _toggle_build_item_detail(control: Control, item: Dictionary) -> void:
	var option_id := str(item.get("id", ""))
	if hover_detail != null and hover_detail.visible and control == active_build_detail_control and option_id == active_build_detail_option_id:
		_hide_build_item_detail()
		return
	_show_build_item_detail(control, item)

func _show_build_item_detail(control: Control, item: Dictionary) -> void:
	active_build_detail_control = control
	active_build_detail_option_id = str(item.get("id", ""))
	pending_build_detail_control = null
	pending_build_detail_item = {}
	if build_detail_hover_timer != null:
		build_detail_hover_timer.stop()
	_cancel_build_detail_hide()
	if hover_detail != null and hover_detail.has_method("show_item"):
		hover_detail.show_item(item, get_viewport().get_mouse_position(), Rect2(control.global_position, control.size))

func _hide_build_item_detail() -> void:
	if hover_detail != null and hover_detail.has_method("hide_detail"):
		hover_detail.hide_detail()
	_clear_active_build_detail()

func _clear_active_build_detail() -> void:
	active_build_detail_control = null
	active_build_detail_option_id = ""
	pending_build_detail_control = null
	pending_build_detail_item = {}
	_cancel_build_detail_hide()
	if build_detail_hover_timer != null:
		build_detail_hover_timer.stop()

func _schedule_build_detail_hide() -> void:
	if build_detail_hide_timer == null:
		return
	build_detail_hide_timer.start(BUILD_DETAIL_HIDE_DELAY)

func _cancel_build_detail_hide() -> void:
	if build_detail_hide_timer != null:
		build_detail_hide_timer.stop()

func _on_build_detail_hide_timer_timeout() -> void:
	if active_build_detail_control == null:
		return
	var viewport := get_viewport()
	if viewport != null and active_build_detail_control.get_global_rect().has_point(viewport.get_mouse_position()):
		return
	_hide_build_item_detail()

func _on_build_detail_hover_timer_timeout() -> void:
	if pending_build_detail_control == null or not is_instance_valid(pending_build_detail_control):
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	if not pending_build_detail_control.get_global_rect().has_point(viewport.get_mouse_position()):
		pending_build_detail_control = null
		pending_build_detail_item = {}
		return
	_show_build_item_detail(pending_build_detail_control, pending_build_detail_item)

func _get_summary_text(item: Dictionary) -> String:
	for key in ["summary", "short_description", "preview_description"]:
		var value := str(item.get(key, ""))
		if value != "":
			return _first_line(value)
	return _first_line(str(item.get("description", "")))

func _get_card_summary_text(item: Dictionary) -> String:
	return _wrap_card_text(_get_summary_text(item), BUILD_CARD_SUMMARY_CHARS_PER_LINE, BUILD_CARD_SUMMARY_MAX_LINES)

func _first_line(text_value: String) -> String:
	var normalized := text_value.replace("\r", "")
	var newline_index := normalized.find("\n")
	if newline_index >= 0:
		return normalized.substr(0, newline_index)
	return normalized

func _wrap_card_text(text_value: String, max_chars_per_line: int, max_lines: int) -> String:
	var normalized := text_value.replace("\r", "").replace("\n", "")
	var lines: Array[String] = []
	var current := ""
	for index in range(normalized.length()):
		var next_char := normalized.substr(index, 1)
		current += next_char
		if current.length() >= max_chars_per_line:
			lines.append(current)
			current = ""
			if lines.size() >= max_lines:
				break
	if lines.size() < max_lines and current != "":
		lines.append(current)
	return "\n".join(lines)

func _prepare_modal_layout() -> void:
	if modal != null and modal.has_method("apply_layout"):
		modal.apply_layout()
	var compact := false
	if modal != null:
		compact = bool(modal.get("compact"))
	if selection_label != null:
		selection_label.add_theme_font_size_override("font_size", 11 if compact else 13)
	if card_list != null and card_list.has_method("set_compact"):
		card_list.set_compact(compact)

func _configure_level_up_footer() -> void:
	_clear_modal_footer()

func _clear_modal_footer() -> void:
	if modal != null and modal.has_method("clear_footer"):
		modal.clear_footer()

func _on_refresh_pressed() -> void:
	if current_mode != "blessing":
		return
	if build_refresh_animation_in_progress or build_selection_in_progress:
		return
	if not _can_refresh_current_offer():
		return
	build_refresh_animation_in_progress = true
	_hide_build_item_detail()
	_play_build_refresh_button_click_animation()
	_set_build_overlay_input_enabled(false)
	await _play_build_refresh_collapse_animation()
	if not _is_upgrade_refresh_unlimited():
		current_offer_context["refresh_remaining"] = 0
	_configure_level_up_footer()
	_update_build_refresh_button()
	build_refresh_expand_pending = true
	upgrade_refresh_requested.emit()

func _rebuild_level_up_list() -> void:
	card_list.clear()
	_add_unified_blessing_options()
	if not current_attribute_options.is_empty():
		card_list.add_section("英雄特性")
		card_list.columns = 2
		card_list.add_card_grid(current_attribute_options, 2)
	_refresh_selected_cards()
	if card_list.has_method("reset_scroll_to_top"):
		card_list.reset_scroll_to_top()

func _rebuild_small_boss_list() -> void:
	card_list.clear()
	_add_option_sections(SMALL_BOSS_SLOT_ORDER)
	_refresh_selected_cards()

func _rebuild_direct_list() -> void:
	card_list.clear()
	for raw_option in current_options:
		if raw_option is not Dictionary:
			continue
		card_list.add_card(raw_option)
	_refresh_selected_cards()

func _add_option_sections(slot_order: Array) -> void:
	for slot_id_value in slot_order:
		var slot_id := str(slot_id_value)
		var grouped_options: Array = option_groups.get(slot_id, [])
		if grouped_options.is_empty():
			continue
		var label := str(grouped_options[0].get("slot_label", DEFAULT_SLOT_LABELS.get(slot_id, slot_id)))
		card_list.add_section(label)
		for raw_option in grouped_options:
			if raw_option is not Dictionary:
				continue
			var option: Dictionary = raw_option
			card_list.add_card(option, false, bool(option.get("evolved", false)))

func _add_unified_blessing_options() -> void:
	if current_options.is_empty():
		return
	card_list.add_section(BLESSING_UNIFIED_SECTION_TITLE)
	for raw_option in current_options:
		if raw_option is not Dictionary:
			continue
		var option: Dictionary = raw_option
		card_list.add_card(option, false, bool(option.get("evolved", false)))

func _on_card_item_hovered(item: Dictionary, anchor_rect: Rect2) -> void:
	if hover_detail != null and hover_detail.has_method("show_item"):
		hover_detail.show_item(item, get_viewport().get_mouse_position(), anchor_rect)

func _on_card_item_unhovered() -> void:
	if hover_detail != null:
		if hover_detail.has_method("request_hide"):
			hover_detail.request_hide()
		elif hover_detail.has_method("hide_detail"):
			hover_detail.hide_detail()

func _on_card_list_item_selected(option_id: String, option: Dictionary) -> void:
	if current_mode == "direct":
		upgrade_selected.emit(option_id, "")
		return
	if current_mode == "small_boss_pair":
		_select_small_boss_reward_option(option)
		return
	var slot_id := str(option.get("slot", ""))
	if slot_id == "" or _is_attribute_option(option_id):
		_select_attribute_option(option)
	else:
		_select_blessing_option(option)

func _is_attribute_option(option_id: String) -> bool:
	for raw_option in current_attribute_options:
		if raw_option is Dictionary and str((raw_option as Dictionary).get("id", "")) == option_id:
			return true
	return false

func _select_attribute_option(option: Dictionary) -> void:
	_set_attribute_selection(option, true)
	_update_selection_hint()
	_refresh_selected_cards()

func _select_blessing_option(option: Dictionary) -> void:
	pending_blessing_option_id = str(option.get("id", ""))
	pending_blessing_title = str(option.get("title", "祝福"))
	_update_selection_hint()
	_refresh_selected_cards()
	upgrade_selected.emit(pending_blessing_option_id, pending_attribute_option_id)

func _select_small_boss_reward_option(option: Dictionary) -> void:
	var slot_id := str(option.get("slot", ""))
	if slot_id == "equipment":
		pending_equipment_option_id = str(option.get("id", ""))
		pending_equipment_title = str(option.get("title", "道具"))
	elif slot_id == "card":
		pending_card_option_id = str(option.get("id", ""))
		pending_card_title = str(option.get("title", "技能奖励"))
	_update_small_boss_reward_hint()
	_refresh_selected_cards()
	if _is_small_boss_reward_selection_complete():
		upgrade_selected.emit(pending_equipment_option_id, pending_card_option_id)

func _try_emit_combined_selection() -> void:
	if pending_blessing_option_id == "":
		return
	if not current_attribute_options.is_empty() and pending_attribute_option_id == "":
		return
	upgrade_selected.emit(pending_blessing_option_id, pending_attribute_option_id)

func _update_selection_hint() -> void:
	if current_mode != "blessing":
		return
	if _is_build_multi_select_offer():
		selection_label.text = "已选：%d/%d" % [pending_blessing_option_ids.size(), _get_build_selection_count()]
		return
	var attribute_text := pending_attribute_title if pending_attribute_title != "" else "未选英雄特性"
	var blessing_text := pending_blessing_title if pending_blessing_title != "" else "未选祝福"
	selection_label.text = "当前：%s | %s" % [attribute_text, blessing_text]

func _update_small_boss_reward_hint() -> void:
	if current_mode != "small_boss_pair":
		return
	var parts: Array[String] = []
	if _small_boss_reward_slot_required("equipment"):
		parts.append(pending_equipment_title if pending_equipment_title != "" else "未选道具")
	if _small_boss_reward_slot_required("card"):
		parts.append(pending_card_title if pending_card_title != "" else "未选技能奖励")
	if parts.is_empty():
		selection_label.text = "当前：无可选奖励"
	else:
		selection_label.text = "当前：%s" % " | ".join(parts)

func _refresh_selected_cards() -> void:
	if card_list == null:
		return
	var ids: Array[String] = []
	if pending_attribute_option_id != "":
		ids.append(pending_attribute_option_id)
	for selected_option_id in pending_blessing_option_ids:
		if selected_option_id != "" and not ids.has(selected_option_id):
			ids.append(selected_option_id)
	if pending_blessing_option_id != "" and not ids.has(pending_blessing_option_id):
		ids.append(pending_blessing_option_id)
	if pending_equipment_option_id != "":
		ids.append(pending_equipment_option_id)
	if pending_card_option_id != "":
		ids.append(pending_card_option_id)
	card_list.set_selected_ids(ids)
	_refresh_build_card_selected_outlines()

func _group_options(options: Array, slot_order: Array) -> Dictionary:
	var groups := {}
	for slot_id_value in slot_order:
		groups[str(slot_id_value)] = []
	for raw_option in options:
		if raw_option is not Dictionary:
			continue
		var option: Dictionary = raw_option
		var slot_id := str(option.get("slot", ""))
		if not groups.has(slot_id):
			groups[slot_id] = []
		groups[slot_id].append(option)
	return groups

func _group_small_boss_reward_options(options: Array) -> Dictionary:
	var groups := {
		"equipment": [],
		"card": []
	}
	for raw_option in options:
		if raw_option is not Dictionary:
			continue
		var option: Dictionary = raw_option.duplicate(true)
		if str(option.get("slot", "")) == "equipment":
			option["slot"] = "equipment"
			option["slot_label"] = "道具"
			groups["equipment"].append(option)
		else:
			option["slot"] = "card"
			option["slot_label"] = "技能奖励"
			groups["card"].append(option)
	return groups

func _duplicate_option_array(options: Array) -> Array:
	var result: Array = []
	for option in options:
		if option is Dictionary:
			result.append((option as Dictionary).duplicate(true))
		else:
			result.append(option)
	return result

func _get_small_boss_reward_menu_hint() -> String:
	var labels: Array[String] = []
	if _small_boss_reward_slot_required("equipment"):
		labels.append("道具选 1 个")
	if _small_boss_reward_slot_required("card"):
		labels.append("技能奖励选 1 个")
	if labels.is_empty():
		return "当前没有可选奖励；鼠标移到卡片上查看完整说明。"
	return "%s；鼠标移到卡片上查看完整说明。" % "；".join(labels)

func _small_boss_reward_slot_required(slot_id: String) -> bool:
	return not (option_groups.get(slot_id, []) as Array).is_empty()

func _is_small_boss_reward_selection_complete() -> bool:
	if _small_boss_reward_slot_required("equipment") and pending_equipment_option_id == "":
		return false
	if _small_boss_reward_slot_required("card") and pending_card_option_id == "":
		return false
	return _small_boss_reward_slot_required("equipment") or _small_boss_reward_slot_required("card")

func _reset_pending_selection() -> void:
	pending_blessing_option_id = ""
	pending_blessing_title = ""
	pending_blessing_option_ids.clear()
	pending_blessing_titles.clear()
	build_card_refresh_used_indices.clear()
	pending_attribute_option_id = ""
	pending_attribute_title = ""
	pending_equipment_option_id = ""
	pending_equipment_title = ""
	pending_card_option_id = ""
	level_talent_role_button_entries.clear()
	level_talent_role_options.clear()
	level_talent_selected_role_id = ""
	pending_card_title = ""
