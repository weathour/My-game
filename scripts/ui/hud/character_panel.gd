extends CanvasLayer

signal close_requested

const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const BUILD_DATABASE := preload("res://scripts/build/build_database.gd")
const PLAYER_EQUIPMENT_FLOW := preload("res://scripts/player/player_equipment_flow.gd")
const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")
const SURVIVORS_MODAL := preload("res://scripts/ui/core/survivors_modal.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")

const ROLE_TEXTURE_PATHS := {
	"swordsman": "人设草图/剑士草图.jpg",
	"gunner": "人设草图/枪手草图.jpg",
	"mage": "人设草图/术师草图.jpg"
}

var role_texture_rect: TextureRect
var role_title_label: Label
var role_button_row: HBoxContainer
var stats_label: RichTextLabel
var equipment_list: VBoxContainer
var blessing_list: VBoxContainer
var card_label: RichTextLabel
var gift_popup: PopupMenu
var blessing_popup: PopupMenu
var cached_player: Node
var viewed_role_index: int = 0
var pending_gift_equipment_id: String = ""
var pending_gift_from_role_id: String = ""
var gift_target_role_ids: Array[String] = []
var pending_compose_blessing_id: String = ""
var pending_compose_role_id: String = ""
var pending_compose_is_skill_bound: bool = false

func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	var modal := SURVIVORS_MODAL.new()
	modal.configure(Vector2(1100.0, 640.0), 0.86, 0.88, Vector2(360.0, 280.0))
	modal.set_title("角色面板")
	modal.set_hint("查看角色数值、祝福、Build 与道具。右键道具可赠与；右键 I Lv.3 祝福可合成 II Lv.1。")
	add_child(modal)

	var layout := HBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 16)
	modal.set_body(layout)

	var left_column := VBoxContainer.new()
	left_column.custom_minimum_size = Vector2(280.0, 0.0)
	left_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 10)
	layout.add_child(left_column)

	role_title_label = Label.new()
	role_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_title_label.add_theme_font_size_override("font_size", 24)
	role_title_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	left_column.add_child(role_title_label)

	var close_button := Button.new()
	close_button.text = "关闭 (%s)" % GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_CHARACTER_PANEL))
	close_button.custom_minimum_size = Vector2(0.0, 42.0)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SURVIVORS_THEME.apply_button_style(close_button, "primary")
	close_button.pressed.connect(func() -> void: close_requested.emit())
	left_column.add_child(close_button)

	role_texture_rect = TextureRect.new()
	role_texture_rect.custom_minimum_size = Vector2(260.0, 360.0)
	role_texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	role_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	role_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left_column.add_child(role_texture_rect)

	role_button_row = HBoxContainer.new()
	role_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	role_button_row.add_theme_constant_override("separation", 8)
	left_column.add_child(role_button_row)

	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 8)
	layout.add_child(right_column)

	stats_label = RichTextLabel.new()
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_label.custom_minimum_size = Vector2(0.0, 190.0)
	stats_label.bbcode_enabled = true
	stats_label.fit_content = false
	stats_label.scroll_active = true
	SURVIVORS_THEME.apply_rich_label_font(stats_label, 16)
	right_column.add_child(stats_label)

	var equipment_title := Label.new()
	equipment_title.text = "道具背包（右键道具可赠与）"
	equipment_title.add_theme_font_size_override("font_size", 20)
	equipment_title.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT)
	right_column.add_child(equipment_title)

	var equipment_scroll := ScrollContainer.new()
	equipment_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipment_scroll.custom_minimum_size = Vector2(0.0, 120.0)
	equipment_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	equipment_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_column.add_child(equipment_scroll)

	equipment_list = VBoxContainer.new()
	equipment_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_list.add_theme_constant_override("separation", 6)
	equipment_scroll.add_child(equipment_list)

	var blessing_title := Label.new()
	blessing_title.text = "已获祝福（三人共享；右键 I Lv.3 可合成）"
	blessing_title.add_theme_font_size_override("font_size", 20)
	blessing_title.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT)
	right_column.add_child(blessing_title)

	var blessing_scroll := ScrollContainer.new()
	blessing_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blessing_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	blessing_scroll.custom_minimum_size = Vector2(0.0, 116.0)
	blessing_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	blessing_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_column.add_child(blessing_scroll)

	blessing_list = VBoxContainer.new()
	blessing_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blessing_list.add_theme_constant_override("separation", 6)
	blessing_scroll.add_child(blessing_list)

	card_label = RichTextLabel.new()
	card_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_label.custom_minimum_size = Vector2(0.0, 120.0)
	card_label.bbcode_enabled = true
	card_label.fit_content = false
	card_label.scroll_active = true
	SURVIVORS_THEME.apply_rich_label_font(card_label, 16)
	right_column.add_child(card_label)

	gift_popup = PopupMenu.new()
	gift_popup.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	gift_popup.index_pressed.connect(_on_gift_popup_index_pressed)
	add_child(gift_popup)

	blessing_popup = PopupMenu.new()
	blessing_popup.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	blessing_popup.index_pressed.connect(_on_blessing_popup_index_pressed)
	add_child(blessing_popup)

	hide_panel()

func show_for_player(player: Node) -> void:
	cached_player = player
	if cached_player != null and is_instance_valid(cached_player):
		viewed_role_index = clamp(int(cached_player.get("active_role_index")), 0, max(0, _get_roles().size() - 1))
	refresh()
	visible = true

func hide_panel() -> void:
	visible = false
	if gift_popup != null:
		gift_popup.hide()
	if blessing_popup != null:
		blessing_popup.hide()

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
	role_title_label.text = "%s  Lv.%d%s" % [
		role_name,
		int(cached_player.get("level")),
		"（站场）" if viewed_role_index == int(cached_player.get("active_role_index")) else "（查看）"
	]
	role_texture_rect.texture = _load_role_texture(role_id)
	_refresh_role_buttons()
	stats_label.text = _build_stats_text(role_data)
	_refresh_equipment_list(role_id)
	_refresh_blessing_list(role_id)
	card_label.text = _build_card_text()

func _refresh_role_buttons() -> void:
	for child in role_button_row.get_children():
		role_button_row.remove_child(child)
		child.queue_free()
	var roles: Array = _get_roles()
	var active_index: int = int(cached_player.get("active_role_index"))
	for index in range(roles.size()):
		var role: Dictionary = roles[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(86.0, 36.0)
		SURVIVORS_THEME.apply_button_style(button, "primary" if index == active_index else "normal", index == viewed_role_index)
		button.text = "%s%s" % [str(role.get("name", "角色")), "*" if index == active_index else ""]
		button.disabled = index == viewed_role_index
		button.pressed.connect(_view_role.bind(index))
		role_button_row.add_child(button)

func _view_role(role_index: int) -> void:
	viewed_role_index = role_index
	refresh()

func _refresh_equipment_list(role_id: String) -> void:
	for child in equipment_list.get_children():
		equipment_list.remove_child(child)
		child.queue_free()
	var equipment_levels: Dictionary = cached_player._get_role_equipment_levels(role_id) if cached_player.has_method("_get_role_equipment_levels") else {}
	var has_any := false
	for equipment_id in PLAYER_EQUIPMENT_FLOW.EQUIPMENT_DEFINITIONS.keys():
		var count: int = int(equipment_levels.get(str(equipment_id), 0))
		if count <= 0:
			continue
		has_any = true
		var definition: Dictionary = PLAYER_EQUIPMENT_FLOW.EQUIPMENT_DEFINITIONS.get(str(equipment_id), {})
		for _copy_index in range(count):
			var button := Button.new()
			button.text = str(definition.get("title", equipment_id))
			button.tooltip_text = "%s\n当前角色持有 %d 个；右键可赠与其中 1 个。" % [
				str(definition.get("description", "")),
				count
			]
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size = Vector2(0.0, 34.0)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			SURVIVORS_THEME.apply_card_button_style(button)
			button.gui_input.connect(_on_equipment_gui_input.bind(str(equipment_id), role_id))
			equipment_list.add_child(button)
	if not has_any:
		var empty_label := Label.new()
		empty_label.text = "暂无道具"
		empty_label.custom_minimum_size = Vector2(0.0, 34.0)
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

func _refresh_blessing_list(role_id: String) -> void:
	for child in blessing_list.get_children():
		blessing_list.remove_child(child)
		child.queue_free()
	var role_levels: Dictionary = cached_player.get_role_blessing_levels(role_id) if cached_player.has_method("get_role_blessing_levels") else {}
	var skill_levels: Dictionary = cached_player.get_skill_blessing_levels() if cached_player.has_method("get_skill_blessing_levels") else {}
	var has_any := false
	for blessing_id in PLAYER_BLESSING_SYSTEM.DEFINITIONS.keys():
		var definition: Dictionary = PLAYER_BLESSING_SYSTEM.DEFINITIONS.get(str(blessing_id), {})
		if str(definition.get("binding", PLAYER_BLESSING_SYSTEM.ROLE_BOUND)) != PLAYER_BLESSING_SYSTEM.ROLE_BOUND:
			continue
		if _add_blessing_row(str(blessing_id), definition, role_levels, role_id, false):
			has_any = true
	var skill_header_added := false
	for blessing_id in PLAYER_BLESSING_SYSTEM.DEFINITIONS.keys():
		var definition: Dictionary = PLAYER_BLESSING_SYSTEM.DEFINITIONS.get(str(blessing_id), {})
		if str(definition.get("binding", PLAYER_BLESSING_SYSTEM.ROLE_BOUND)) != PLAYER_BLESSING_SYSTEM.SKILL_BOUND:
			continue
		if not _has_blessing_levels(skill_levels, str(blessing_id)):
			continue
		if not skill_header_added:
			var header := Label.new()
			header.text = "技能绑定祝福（暂未绑定具体技能）"
			header.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_MUTED)
			blessing_list.add_child(header)
			skill_header_added = true
		if _add_blessing_row(str(blessing_id), definition, skill_levels, "", true):
			has_any = true
	if not has_any:
		var empty_label := Label.new()
		empty_label.text = "暂无祝福"
		empty_label.custom_minimum_size = Vector2(0.0, 34.0)
		blessing_list.add_child(empty_label)

func _add_blessing_row(blessing_id: String, definition: Dictionary, levels: Dictionary, role_id: String, skill_bound: bool) -> bool:
	if not _has_blessing_levels(levels, blessing_id):
		return false
	var blessing_levels: Dictionary = levels.get(blessing_id, {})
	var tier_one_level: int = int(blessing_levels.get(1, 0))
	var tier_two_level: int = int(blessing_levels.get(2, 0))
	var can_compose := false
	if cached_player != null:
		if skill_bound and cached_player.has_method("can_compose_skill_blessing"):
			can_compose = bool(cached_player.can_compose_skill_blessing(blessing_id))
		elif not skill_bound and cached_player.has_method("can_compose_role_blessing"):
			can_compose = bool(cached_player.can_compose_role_blessing(role_id, blessing_id))
	var button := Button.new()
	button.text = "%s    I Lv.%d / 3    II Lv.%d / 3%s" % [
		str(definition.get("title", blessing_id)),
		tier_one_level,
		tier_two_level,
		"    可合成" if can_compose else ""
	]
	button.tooltip_text = "%s\nI Lv.3 可手动合成 II Lv.1；升级发牌里的 II 级从 Lv.7 后按概率独立出现。" % str(definition.get("description", ""))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0.0, 34.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SURVIVORS_THEME.apply_card_button_style(button)
	button.disabled = not can_compose
	button.gui_input.connect(_on_blessing_gui_input.bind(blessing_id, role_id, skill_bound))
	blessing_list.add_child(button)
	return true

func _has_blessing_levels(levels: Dictionary, blessing_id: String) -> bool:
	var blessing_levels: Dictionary = levels.get(blessing_id, {})
	return int(blessing_levels.get(1, 0)) > 0 or int(blessing_levels.get(2, 0)) > 0

func _on_blessing_gui_input(event: InputEvent, blessing_id: String, role_id: String, skill_bound: bool) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_show_blessing_compose_popup(blessing_id, role_id, skill_bound)

func _show_blessing_compose_popup(blessing_id: String, role_id: String, skill_bound: bool) -> void:
	pending_compose_blessing_id = blessing_id
	pending_compose_role_id = role_id
	pending_compose_is_skill_bound = skill_bound
	blessing_popup.clear()
	var can_compose := false
	if cached_player != null:
		if skill_bound and cached_player.has_method("can_compose_skill_blessing"):
			can_compose = bool(cached_player.can_compose_skill_blessing(blessing_id))
		elif not skill_bound and cached_player.has_method("can_compose_role_blessing"):
			can_compose = bool(cached_player.can_compose_role_blessing(role_id, blessing_id))
	blessing_popup.add_item("合成 II Lv.1")
	blessing_popup.set_item_disabled(0, not can_compose)
	blessing_popup.position = Vector2i(get_viewport().get_mouse_position())
	blessing_popup.popup()

func _on_blessing_popup_index_pressed(index: int) -> void:
	if cached_player == null or not is_instance_valid(cached_player) or index != 0:
		return
	if pending_compose_is_skill_bound:
		if cached_player.has_method("compose_skill_blessing"):
			cached_player.compose_skill_blessing(pending_compose_blessing_id)
	else:
		if cached_player.has_method("compose_role_blessing"):
			cached_player.compose_role_blessing(pending_compose_role_id, pending_compose_blessing_id)
	refresh()

func _build_stats_text(role_data: Dictionary) -> String:
	var role_id: String = str(role_data.get("id", ""))
	var bonus: Dictionary = cached_player._get_role_equipment_bonus_summary(role_id) if cached_player.has_method("_get_role_equipment_bonus_summary") else {}
	var active_bonus: Dictionary = cached_player._get_role_equipment_bonus_summary(str(cached_player._get_active_role().get("id", ""))) if cached_player.has_method("_get_role_equipment_bonus_summary") else {}
	var damage: float = float(cached_player._get_role_damage(role_id)) if cached_player.has_method("_get_role_damage") else float(role_data.get("damage", 0.0))
	var base_speed: float = float(cached_player.get("speed")) - float(active_bonus.get("speed_bonus", 0.0))
	var move_speed: float = (base_speed + float(bonus.get("speed_bonus", 0.0))) * float(role_data.get("speed_scale", 1.0))
	if cached_player.has_method("_get_role_attribute_move_speed_multiplier"):
		move_speed *= float(cached_player._get_role_attribute_move_speed_multiplier(role_id))
	if cached_player.has_method("_get_role_attribute_flat_move_speed_bonus"):
		move_speed += float(cached_player._get_role_attribute_flat_move_speed_bonus(role_id))
	var max_health: float = float(cached_player.get("max_health")) - float(active_bonus.get("max_health_bonus", 0.0)) + float(bonus.get("max_health_bonus", 0.0))
	var current_health_text := "%.0f / %.0f" % [float(cached_player.get("current_health")), max_health]
	if viewed_role_index != int(cached_player.get("active_role_index")):
		current_health_text = "- / %.0f" % max_health
	var base_energy: float = float(cached_player.get("energy_gain_multiplier")) - float(active_bonus.get("energy_gain_bonus", 0.0))
	var energy_gain: float = base_energy + float(bonus.get("energy_gain_bonus", 0.0))
	var pickup_radius: float = float(cached_player.get("pickup_radius"))
	if cached_player.has_method("_get_attribute_pickup_range_bonus"):
		pickup_radius += float(cached_player._get_attribute_pickup_range_bonus())
	var attribute_dodge: float = float(cached_player._get_attribute_dodge_chance()) if cached_player.has_method("_get_attribute_dodge_chance") else 0.0
	var dodge_chance: float = 1.0 - (1.0 - float(bonus.get("dodge_chance", 0.0))) * (1.0 - attribute_dodge)
	var health_regen: float = float(bonus.get("regen_per_second", 0.0))
	if cached_player.has_method("_get_attribute_health_regen_per_second"):
		health_regen += float(cached_player._get_attribute_health_regen_per_second())
	var mana_regen: float = float(cached_player._get_attribute_mana_regen_per_second()) if cached_player.has_method("_get_attribute_mana_regen_per_second") else 0.0
	var swordsman_trait_level: float = float(cached_player._get_attribute_level("swordsman_trait")) if cached_player.has_method("_get_attribute_level") else 0.0
	var gunner_trait_level: float = float(cached_player._get_attribute_level("gunner_trait")) if cached_player.has_method("_get_attribute_level") else 0.0
	var mage_trait_level: float = float(cached_player._get_attribute_level("mage_trait")) if cached_player.has_method("_get_attribute_level") else 0.0
	var lines: Array[String] = []
	lines.append("[font_size=22][b]核心数值[/b][/font_size]")
	lines.append("生命 %s    大招能量 %.0f / %.0f" % [
		current_health_text,
		float(cached_player._get_role_mana(role_id)) if cached_player.has_method("_get_role_mana") else 0.0,
		float(cached_player.get("max_mana"))
	])
	lines.append("伤害 %.1f    攻击间隔 %.2fs    移速 %.1f    吸取范围 %.1f" % [
		damage,
		float(cached_player._get_effective_attack_interval(role_id)) if cached_player.has_method("_get_effective_attack_interval") else 0.0,
		move_speed,
		pickup_radius
	])
	lines.append("能量获取 x%.2f    回能 %.2f/s    技能范围 x%.2f    CD x%.2f    闪避 %.1f%%    回血 %.1f/s" % [
		energy_gain,
		mana_regen,
		float(bonus.get("skill_range_multiplier", 1.0)),
		float(bonus.get("cooldown_multiplier", 1.0)),
		dodge_chance * 100.0,
		health_regen
	])
	lines.append("")
	lines.append("[font_size=22][b]属性训练[/b][/font_size]")
	lines.append("剑士特性 Lv.%s    枪手特性 Lv.%s    术师特性 Lv.%s" % [
		_format_panel_attribute_level(swordsman_trait_level),
		_format_panel_attribute_level(gunner_trait_level),
		_format_panel_attribute_level(mage_trait_level)
	])
	lines.append("每点英雄特性 +1 对应英雄普攻伤害；剑士特性偏生存，枪手特性偏机动，术师特性偏回能/拾取。")
	return "\n".join(lines)

func _format_panel_attribute_level(level: float) -> String:
	if cached_player != null and cached_player.has_method("_format_attribute_level"):
		return str(cached_player._format_attribute_level(level))
	if is_equal_approx(level, roundf(level)):
		return str(int(roundf(level)))
	return "%.1f" % level

func _build_card_text() -> String:
	var lines: Array[String] = []
	lines.append("[font_size=22][b]已有码牌 / Build[/b][/font_size]")
	var parts: Array[String] = []
	var card_levels: Dictionary = cached_player.get("card_pick_levels")
	for card_id in card_levels.keys():
		var level: int = int(card_levels.get(card_id, 0))
		if level <= 0:
			continue
		var config: Dictionary = BUILD_DATABASE.get_core_card(str(card_id))
		parts.append("%s Lv.%d" % [str(config.get("title", card_id)), level])
	var reward_levels: Dictionary = cached_player.get("special_reward_levels")
	for reward_id in reward_levels.keys():
		var level: int = int(reward_levels.get(reward_id, 0))
		if level <= 0:
			continue
		var reward: Dictionary = BUILD_DATABASE.get_small_boss_reward(str(reward_id))
		parts.append("%s Lv.%d" % [str(reward.get("title", reward_id)), level])
	lines.append("\n".join(parts) if not parts.is_empty() else "暂无 Build 卡牌")
	return "\n".join(lines)

func _load_role_texture(role_id: String) -> Texture2D:
	if cached_player != null and cached_player.has_method("_get_cached_runtime_texture"):
		var texture: Texture2D = cached_player._get_cached_runtime_texture(str(ROLE_TEXTURE_PATHS.get(role_id, ROLE_TEXTURE_PATHS["swordsman"])))
		if texture != null:
			return texture
	return null

func _get_roles() -> Array:
	if cached_player == null or not is_instance_valid(cached_player):
		return []
	var roles_variant: Variant = cached_player.get("roles")
	if roles_variant is Array:
		return roles_variant
	return []
