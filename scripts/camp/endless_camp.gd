extends Node2D

const GAME_SCENE_PATH := "res://scenes/main.tscn"
const MOVEMENT_TUTORIAL_SCENE_PATH := "res://scenes/movement_tutorial.tscn"
const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const RUAN_STONE_SYSTEM := preload("res://scripts/player/ruan_stone_system.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const ENDLESS_TIER_OVERLAY := preload("res://scripts/ui/save/endless_tier_overlay.gd")
const TEAM_SWAP_PANEL_SCENE := preload("res://scenes/UI/team_swap_panel.tscn")

const INTERACTABLE_TEXT := {
	"swordsman": {
		"name": "\u5251\u58eb",
		"prompt": "\u5251\u58eb\u6682\u672a\u5f00\u653e\u5bf9\u8bdd"
	},
	"gunner": {
		"name": "\u67aa\u624b",
		"prompt": "\u67aa\u624b\u6682\u672a\u5f00\u653e\u5bf9\u8bdd"
	},
	"mage": {
		"name": "\u672f\u5e08",
		"prompt": "\u672f\u5e08\u6682\u672a\u5f00\u653e\u5bf9\u8bdd"
	},
	"mechanic": {
		"name": "\u673a\u68b0\u5e08",
		"prompt": "\u673a\u68b0\u5e08\u6682\u672a\u5f00\u653e\u5bf9\u8bdd"
	},
	"blacksmith": {
		"name": "\u94c1\u5320",
		"prompt": "\u6253\u5f00\u94c1\u5320\u5546\u5e97"
	},
	"ruan_dog": {
		"name": "阮狗",
		"prompt": "和阮狗说话"
	},
	"tutorial_entrance": {
		"name": "新手教学入口",
		"prompt": "进入新手教学"
	},
	"endless_portal": {
		"name": "\u65e0\u5c3d\u4f20\u9001\u95e8",
		"prompt": "选择无尽 N 层"
	},
	"prep_station": {
		"name": "整备台",
		"prompt": "调整队伍"
	}
}
const DIALOGUE_LINES := {
	"ruan_dog": [
		"汪。骨头带来了吗？",
		"我收藏的石头都在这，挑一颗吧。"
	]
}

@onready var prompt_label: Label = $CanvasLayer/PromptLabel
@onready var message_label: Label = $CanvasLayer/MessageLabel
@onready var dialogue_panel: PanelContainer = $CanvasLayer/DialoguePanel
@onready var dialogue_title: Label = $CanvasLayer/DialoguePanel/MarginContainer/DialogueContent/TextContent/Title
@onready var dialogue_body: Label = $CanvasLayer/DialoguePanel/MarginContainer/DialogueContent/TextContent/Body
@onready var dialogue_hint: Label = $CanvasLayer/DialoguePanel/MarginContainer/DialogueContent/TextContent/Hint
@onready var shop_panel: PanelContainer = $CanvasLayer/ShopPanel
@onready var shop_title: Label = $CanvasLayer/ShopPanel/MarginContainer/ShopContent/Title
@onready var shop_body: Label = $CanvasLayer/ShopPanel/MarginContainer/ShopContent/Body
@onready var ruan_stone_panel: PanelContainer = $CanvasLayer/RuanStonePanel
@onready var ruan_stone_status: Label = $CanvasLayer/RuanStonePanel/MarginContainer/StoneContent/Status
@onready var ruan_stone_cards: HBoxContainer = $CanvasLayer/RuanStonePanel/MarginContainer/StoneContent/Cards
@onready var ruan_stone_feedback: Label = $CanvasLayer/RuanStonePanel/MarginContainer/StoneContent/Feedback
@onready var ruan_stone_close_button: Button = $CanvasLayer/RuanStonePanel/MarginContainer/StoneContent/CloseButton
@onready var tutorial_prompt_panel: PanelContainer = $CanvasLayer/TutorialPromptPanel
@onready var tutorial_prompt_title: Label = $CanvasLayer/TutorialPromptPanel/MarginContainer/TutorialPromptContent/Title
@onready var tutorial_prompt_body: Label = $CanvasLayer/TutorialPromptPanel/MarginContainer/TutorialPromptContent/Body
@onready var tutorial_yes_button: Button = $CanvasLayer/TutorialPromptPanel/MarginContainer/TutorialPromptContent/ButtonRow/YesButton
@onready var tutorial_no_button: Button = $CanvasLayer/TutorialPromptPanel/MarginContainer/TutorialPromptContent/ButtonRow/NoButton
@onready var camp_player: Node2D = $CampPlayer
@onready var characters_root: Node2D = $Characters

var focused_interactables: Array[Node] = []
var camp_role_id: String = "swordsman"
var active_dialogue_lines: Array[String] = []
var active_dialogue_index: int = 0
var active_dialogue_id: String = ""
var ruan_stone_profile: Dictionary = {}
var ruan_stone_purchase_buttons: Dictionary = {}
var ruan_stone_equip_buttons: Dictionary = {}
var tier_overlay: Control
var team_swap_panel: Control

func _ready() -> void:
	get_tree().paused = false
	camp_role_id = _resolve_camp_role_id()
	_apply_camp_player_role(camp_role_id)
	_apply_character_stand_visibility(camp_role_id)
	_setup_ui()
	_setup_tier_overlay()
	_setup_team_swap_panel()
	_apply_interactable_texts()
	_connect_interactables()
	_update_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if team_swap_panel != null and team_swap_panel.visible:
			team_swap_panel.close_panel()
		elif tier_overlay != null and tier_overlay.visible:
			tier_overlay.close_overlay()
		elif dialogue_panel.visible:
			_close_dialogue()
		elif tutorial_prompt_panel.visible:
			_close_tutorial_prompt()
		elif ruan_stone_panel.visible:
			_close_ruan_stone_shop()
		elif shop_panel.visible:
			_close_shop()
		else:
			get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
		_mark_input_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if GAME_SETTINGS.event_matches_action(event, GAME_SETTINGS.ACTION_INTERACT):
			_handle_interact()
			_mark_input_handled()
			return

func _setup_ui() -> void:
	prompt_label.text = ""
	prompt_label.visible = false
	message_label.text = ""
	message_label.visible = false
	dialogue_panel.visible = false
	dialogue_title.text = ""
	dialogue_body.text = ""
	dialogue_hint.text = ""
	dialogue_panel.add_theme_stylebox_override("panel", SURVIVORS_THEME.panel_style(SURVIVORS_THEME.COLOR_BG, SURVIVORS_THEME.COLOR_BORDER_GOLD, 2, 16, 16.0))
	shop_panel.visible = false
	shop_title.text = "\u94c1\u5320"
	shop_body.text = "\u5546\u5e97\u6682\u65e0\u5546\u54c1"
	shop_panel.add_theme_stylebox_override("panel", SURVIVORS_THEME.panel_style(SURVIVORS_THEME.COLOR_BG, SURVIVORS_THEME.COLOR_BORDER_GOLD, 2, 16, 16.0))
	ruan_stone_panel.visible = false
	ruan_stone_panel.add_theme_stylebox_override("panel", SURVIVORS_THEME.panel_style(SURVIVORS_THEME.COLOR_BG, SURVIVORS_THEME.COLOR_BORDER_GOLD, 2, 16, 16.0))
	SURVIVORS_THEME.apply_button_style(ruan_stone_close_button)
	ruan_stone_close_button.pressed.connect(_close_ruan_stone_shop)
	tutorial_prompt_panel.visible = false
	tutorial_prompt_title.text = "\u65b0\u624b\u6559\u5b66"
	tutorial_prompt_body.text = "\u662f\u5426\u8fdb\u5165\u65b0\u624b\u6559\u5b66\uff1f"
	tutorial_yes_button.pressed.connect(_enter_movement_tutorial)
	tutorial_no_button.pressed.connect(_close_tutorial_prompt)

func _setup_tier_overlay() -> void:
	tier_overlay = ENDLESS_TIER_OVERLAY.new()
	tier_overlay.name = "EndlessTierOverlay"
	tier_overlay.tier_selected.connect(_on_endless_tier_selected)
	tier_overlay.closed.connect(_on_tier_overlay_closed)
	$CanvasLayer.add_child(tier_overlay)

func _setup_team_swap_panel() -> void:
	team_swap_panel = TEAM_SWAP_PANEL_SCENE.instantiate()
	team_swap_panel.name = "TeamSwapPanel"
	team_swap_panel.closed.connect(_on_team_swap_closed)
	$CanvasLayer.add_child(team_swap_panel)

func _resolve_camp_role_id() -> String:
	var run_data: Dictionary = SAVE_MANAGER.load_run(-1, SAVE_MANAGER.MODE_ENDLESS)
	if run_data.is_empty():
		return "swordsman"
	var player_data: Dictionary = run_data.get("player", {}) if run_data.get("player", {}) is Dictionary else {}
	var roles: Array = player_data.get("roles", [])
	if roles.is_empty():
		return "swordsman"
	var active_role_index: int = clampi(int(player_data.get("active_role_index", 0)), 0, roles.size() - 1)
	var role_data: Variant = roles[active_role_index]
	if role_data is Dictionary:
		var role_id := str((role_data as Dictionary).get("id", "swordsman"))
		if INTERACTABLE_TEXT.has(role_id):
			return role_id
	return "swordsman"

func _apply_camp_player_role(role_id: String) -> void:
	if camp_player != null and camp_player.has_method("set_role_visual"):
		camp_player.set_role_visual(role_id)

func _apply_character_stand_visibility(role_id: String) -> void:
	var stand_name := _get_character_stand_name(role_id)
	if stand_name == "" or characters_root == null:
		return
	var stand := characters_root.get_node_or_null(stand_name) as Node2D
	if stand != null:
		stand.visible = false
		var interactable := stand.get_node_or_null("Interactable")
		if interactable != null:
			interactable.set("enabled", false)

func _get_character_stand_name(role_id: String) -> String:
	match role_id:
		"swordsman":
			return "Swordsman"
		"gunner":
			return "Gunner"
		"mage":
			return "Mage"
		_:
			return ""

func _apply_interactable_texts() -> void:
	for node in get_tree().get_nodes_in_group("camp_interactable"):
		var interactable_id := str(node.get("interactable_id"))
		var text_data: Dictionary = INTERACTABLE_TEXT.get(interactable_id, {})
		if text_data.is_empty():
			continue
		node.set("display_name", str(text_data.get("name", interactable_id)))
		node.set("prompt_text", str(text_data.get("prompt", "")))
		var label := node.get_parent().get_node_or_null("NameLabel") as Label
		if label != null:
			label.text = str(text_data.get("name", interactable_id))

func _connect_interactables() -> void:
	for node in get_tree().get_nodes_in_group("camp_interactable"):
		if not node.has_signal("focus_changed") or not node.has_signal("interacted"):
			continue
		if not node.is_connected("focus_changed", Callable(self, "_on_interactable_focus_changed")):
			node.connect("focus_changed", Callable(self, "_on_interactable_focus_changed"))
		if not node.is_connected("interacted", Callable(self, "_on_interactable_interacted")):
			node.connect("interacted", Callable(self, "_on_interactable_interacted"))

func _handle_interact() -> void:
	if team_swap_panel != null and team_swap_panel.visible:
		return
	if dialogue_panel.visible:
		_advance_dialogue()
		return
	if tutorial_prompt_panel.visible:
		return
	if ruan_stone_panel.visible:
		return
	if shop_panel.visible:
		_close_shop()
		return
	var interactable: Node = _get_best_interactable()
	if interactable == null or not interactable.has_method("try_interact"):
		return
	interactable.try_interact()

func _on_interactable_focus_changed(interactable: Node, focused: bool) -> void:
	if focused:
		if not focused_interactables.has(interactable):
			focused_interactables.append(interactable)
	else:
		focused_interactables.erase(interactable)
	_update_prompt()

func _on_interactable_interacted(interactable: Node) -> void:
	var kind := str(interactable.get("interaction_kind"))
	match kind:
		"portal":
			_open_tier_overlay()
		"team_swap":
			_open_team_swap_panel()
		"tutorial":
			_open_tutorial_prompt()
		"shop":
			_open_shop()
		"dialogue":
			_open_dialogue(interactable)
		_:
			_show_message("\u73b0\u5728\u8fd8\u4e0d\u80fd\u4ea4\u4e92")

func _get_best_interactable() -> Node:
	for index in range(focused_interactables.size() - 1, -1, -1):
		var interactable: Node = focused_interactables[index]
		if interactable == null or not is_instance_valid(interactable):
			focused_interactables.remove_at(index)
			continue
		if interactable.has_method("can_interact") and bool(interactable.can_interact()):
			return interactable
	return null

func _update_prompt() -> void:
	if dialogue_panel.visible or shop_panel.visible or ruan_stone_panel.visible or tutorial_prompt_panel.visible or (tier_overlay != null and tier_overlay.visible) or (team_swap_panel != null and team_swap_panel.visible):
		prompt_label.visible = false
		prompt_label.text = ""
		return
	var interactable: Node = _get_best_interactable()
	if interactable == null:
		prompt_label.visible = false
		prompt_label.text = ""
		return
	var key_name := GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_INTERACT))
	var text := str(interactable.get_prompt_text()) if interactable.has_method("get_prompt_text") else str(interactable.get("display_name"))
	prompt_label.text = "[%s] %s" % [key_name, text]
	prompt_label.visible = true

func _open_dialogue(interactable: Node) -> void:
	var interactable_id := str(interactable.get("interactable_id"))
	var lines_value: Variant = DIALOGUE_LINES.get(interactable_id, [])
	if not (lines_value is Array) or (lines_value as Array).is_empty():
		_show_message("\u73b0\u5728\u8fd8\u4e0d\u80fd\u4ea4\u4e92")
		return
	active_dialogue_lines.clear()
	for line in lines_value:
		active_dialogue_lines.append(str(line))
	active_dialogue_id = interactable_id
	active_dialogue_index = 0
	_close_shop()
	_close_ruan_stone_shop()
	_close_tutorial_prompt()
	_show_message("")
	dialogue_title.text = str(interactable.get("display_name"))
	dialogue_panel.visible = true
	_set_camp_player_movement_enabled(false)
	_show_dialogue_line()
	_update_prompt()

func _advance_dialogue() -> void:
	if not dialogue_panel.visible:
		return
	active_dialogue_index += 1
	if active_dialogue_index >= active_dialogue_lines.size():
		var completed_dialogue_id := active_dialogue_id
		_close_dialogue()
		if completed_dialogue_id == "ruan_dog":
			_open_ruan_stone_shop()
		return
	_show_dialogue_line()

func _show_dialogue_line() -> void:
	dialogue_body.text = active_dialogue_lines[active_dialogue_index]
	var key_name := GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_INTERACT))
	var action_text := "结束" if active_dialogue_index == active_dialogue_lines.size() - 1 else "下一句"
	dialogue_hint.text = "[%s] %s  ·  [Esc] 结束" % [key_name, action_text]

func _close_dialogue() -> void:
	if not dialogue_panel.visible:
		return
	dialogue_panel.visible = false
	active_dialogue_lines.clear()
	active_dialogue_index = 0
	active_dialogue_id = ""
	dialogue_title.text = ""
	dialogue_body.text = ""
	dialogue_hint.text = ""
	_set_camp_player_movement_enabled(true)
	_update_prompt()

func _set_camp_player_movement_enabled(enabled: bool) -> void:
	if camp_player == null:
		return
	camp_player.set_physics_process(enabled)
	if not enabled and camp_player.has_method("stop_movement"):
		camp_player.stop_movement()

func _open_shop() -> void:
	_close_ruan_stone_shop()
	shop_panel.visible = true
	_show_message("")
	_update_prompt()

func _close_shop() -> void:
	shop_panel.visible = false
	_update_prompt()

func _open_ruan_stone_shop() -> void:
	_close_shop()
	_close_tutorial_prompt()
	ruan_stone_feedback.text = ""
	ruan_stone_profile = RUAN_STONE_SYSTEM.normalize_profile(SAVE_MANAGER.get_current_endless_profile())
	_rebuild_ruan_stone_cards()
	ruan_stone_panel.visible = true
	_set_camp_player_movement_enabled(false)
	var first_stone_id := str(RUAN_STONE_SYSTEM.STONE_IDS[0])
	var first_button := ruan_stone_purchase_buttons.get(first_stone_id) as Button
	if first_button != null:
		first_button.grab_focus()
	_update_prompt()

func _close_ruan_stone_shop() -> void:
	if not ruan_stone_panel.visible:
		return
	ruan_stone_panel.visible = false
	_set_camp_player_movement_enabled(true)
	_update_prompt()

func _rebuild_ruan_stone_cards() -> void:
	for child in ruan_stone_cards.get_children():
		ruan_stone_cards.remove_child(child)
		child.queue_free()
	ruan_stone_purchase_buttons.clear()
	ruan_stone_equip_buttons.clear()
	var equipped_id := RUAN_STONE_SYSTEM.get_equipped(ruan_stone_profile)
	var equipped_name := "无"
	if equipped_id != "":
		equipped_name = str(RUAN_STONE_SYSTEM.get_definition(equipped_id).get("title", equipped_id))
	ruan_stone_status.text = "骨头：%d    当前装备：%s" % [int(ruan_stone_profile.get("bones", 0)), equipped_name]
	for stone_id_value in RUAN_STONE_SYSTEM.STONE_IDS:
		_add_ruan_stone_card(str(stone_id_value), equipped_id)

func _add_ruan_stone_card(stone_id: String, equipped_id: String) -> void:
	var definition := RUAN_STONE_SYSTEM.get_definition(stone_id)
	var level := RUAN_STONE_SYSTEM.get_level(ruan_stone_profile, stone_id)
	var cost := RUAN_STONE_SYSTEM.get_next_cost(ruan_stone_profile, stone_id)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(198.0, 330.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", SURVIVORS_THEME.card_style(stone_id == equipped_id))
	ruan_stone_cards.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	card.add_child(content)
	content.add_child(_make_stone_label(str(definition.get("title", stone_id)), 24, SURVIVORS_THEME.COLOR_TEXT_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	content.add_child(_make_stone_label("Lv.%d" % level, 18, SURVIVORS_THEME.COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	content.add_child(_make_stone_label(str(definition.get("summary", "")), 15, SURVIVORS_THEME.COLOR_TEXT_MUTED))
	var current_text := "当前：%s" % RUAN_STONE_SYSTEM.get_effect_text(stone_id, level)
	content.add_child(_make_stone_label(current_text, 15, SURVIVORS_THEME.COLOR_TEXT))
	var next_text := "下级：%s\n费用：%d 骨" % [RUAN_STONE_SYSTEM.get_next_effect_text(ruan_stone_profile, stone_id), cost]
	var next_label := _make_stone_label(next_text, 15, SURVIVORS_THEME.COLOR_TEXT_MUTED)
	next_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(next_label)
	var purchase_button := Button.new()
	purchase_button.custom_minimum_size = Vector2(0.0, 42.0)
	purchase_button.text = ("%s · %d 骨" % ["获取" if level == 0 else "升级", cost])
	purchase_button.focus_mode = Control.FOCUS_ALL
	SURVIVORS_THEME.apply_button_style(purchase_button, "primary")
	purchase_button.pressed.connect(_on_ruan_stone_purchase.bind(stone_id))
	content.add_child(purchase_button)
	ruan_stone_purchase_buttons[stone_id] = purchase_button
	var equip_button := Button.new()
	equip_button.custom_minimum_size = Vector2(0.0, 40.0)
	equip_button.text = "已装备" if stone_id == equipped_id else "装备"
	equip_button.disabled = level <= 0 or stone_id == equipped_id
	equip_button.focus_mode = Control.FOCUS_ALL
	SURVIVORS_THEME.apply_button_style(equip_button, "normal", stone_id == equipped_id)
	equip_button.pressed.connect(_on_ruan_stone_equip.bind(stone_id))
	content.add_child(equip_button)
	ruan_stone_equip_buttons[stone_id] = equip_button

func _make_stone_label(text_value: String, font_size: int, color: Color, alignment: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = alignment
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _on_ruan_stone_purchase(stone_id: String) -> void:
	var result := RUAN_STONE_SYSTEM.purchase(ruan_stone_profile, stone_id)
	var definition := RUAN_STONE_SYSTEM.get_definition(stone_id)
	var stone_name := str(definition.get("title", stone_id))
	if not bool(result.get("success", false)):
		ruan_stone_feedback.text = "骨头不足：%s需要 %d 骨，当前只有 %d 骨。" % [
			stone_name,
			int(result.get("cost", 0)),
			int(result.get("bones", ruan_stone_profile.get("bones", 0)))
		]
		return
	SAVE_MANAGER.save_endless_profile(ruan_stone_profile)
	ruan_stone_feedback.text = "%s已提升至 Lv.%d。" % [stone_name, int(result.get("level", 0))]
	_rebuild_ruan_stone_cards()
	var purchase_button := ruan_stone_purchase_buttons.get(stone_id) as Button
	if purchase_button != null:
		purchase_button.grab_focus()

func _on_ruan_stone_equip(stone_id: String) -> void:
	if not RUAN_STONE_SYSTEM.equip(ruan_stone_profile, stone_id):
		ruan_stone_feedback.text = "需要先获取这颗石头。"
		return
	SAVE_MANAGER.save_endless_profile(ruan_stone_profile)
	var stone_name := str(RUAN_STONE_SYSTEM.get_definition(stone_id).get("title", stone_id))
	ruan_stone_feedback.text = "已装备%s，全队普攻生效。" % stone_name
	_rebuild_ruan_stone_cards()
	var equip_button := ruan_stone_equip_buttons.get(stone_id) as Button
	if equip_button != null and not equip_button.disabled:
		equip_button.grab_focus()
	else:
		var purchase_button := ruan_stone_purchase_buttons.get(stone_id) as Button
		if purchase_button != null:
			purchase_button.grab_focus()

func _open_tutorial_prompt() -> void:
	_close_shop()
	_close_ruan_stone_shop()
	_show_message("")
	tutorial_prompt_panel.visible = true
	tutorial_yes_button.grab_focus()
	_update_prompt()

func _close_tutorial_prompt() -> void:
	tutorial_prompt_panel.visible = false
	_update_prompt()

func _enter_movement_tutorial() -> void:
	_close_tutorial_prompt()
	get_tree().paused = false
	get_tree().change_scene_to_file(MOVEMENT_TUTORIAL_SCENE_PATH)

func _show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = text != ""

func _mark_input_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()

func _open_tier_overlay() -> void:
	_close_tutorial_prompt()
	_close_shop()
	_close_ruan_stone_shop()
	var profile := SAVE_MANAGER.get_current_endless_profile()
	if profile.is_empty():
		_show_message("未找到当前无尽存档。")
		return
	var run_data := SAVE_MANAGER.load_run(-1, SAVE_MANAGER.MODE_ENDLESS)
	if run_data.is_empty() and SAVE_MANAGER.has_unarchived_legacy_endless_run():
		_show_message("旧无尽战局归档失败，请释放存储空间后重试。")
		return
	tier_overlay.open(profile, run_data)
	_set_camp_player_movement_enabled(false)
	_update_prompt()

func _on_endless_tier_selected(tier: int, continue_existing: bool) -> void:
	if continue_existing:
		SAVE_MANAGER.request_continue()
	elif not SAVE_MANAGER.select_current_endless_tier(tier):
		_show_message("该 N 层尚未解锁。")
		return
	tier_overlay.close_overlay()
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_tier_overlay_closed() -> void:
	_set_camp_player_movement_enabled(true)
	_update_prompt()

func _open_team_swap_panel() -> void:
	_close_dialogue()
	_close_shop()
	_close_ruan_stone_shop()
	_close_tutorial_prompt()
	_show_message("")
	team_swap_panel.open(SAVE_MANAGER.MODE_ENDLESS)
	_set_camp_player_movement_enabled(false)
	_update_prompt()

func _on_team_swap_closed() -> void:
	_set_camp_player_movement_enabled(true)
	_update_prompt()
