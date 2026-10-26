extends Node2D

const GAME_SCENE_PATH := "res://scenes/main.tscn"
const MOVEMENT_TUTORIAL_SCENE_PATH := "res://scenes/movement_tutorial.tscn"
const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const ROLES := preload("res://scripts/player/roles/role_database.gd")
const PRESENTER := preload("res://scripts/player/player_role_presenter.gd")
const UI := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const MODAL := preload("res://scripts/ui/core/survivors_modal.gd")
const OVERVIEW := preload("res://scripts/camp/camp_overview.gd")
const SHOP_PANEL := preload("res://scripts/camp/camp_shop_panel.gd")
const ROLE_PANEL := preload("res://scripts/camp/camp_role_panel.gd")
const ENDLESS_TIER_OVERLAY := preload("res://scripts/ui/save/endless_tier_overlay.gd")
const TEAM_SWAP_PANEL_SCENE := preload("res://scenes/UI/team_swap_panel.tscn")
const STAND_NAMES := {"swordsman": "Swordsman", "gunner": "Gunner", "mage": "Mage", "mechanic": "Mechanic"}
const INTERACTABLE_TEXT := {
	"blacksmith": {"name": "铁匠 · 装备", "prompt": "选购装备"},
	"ruan_dog": {"name": "阮狗 · 携带物品", "prompt": "查看携带物品"},
	"tutorial_entrance": {"name": "训练场", "prompt": "进入新手教学"},
	"endless_portal": {"name": "无尽传送门", "prompt": "选择 N 层 / 继续战局"},
	"prep_station": {"name": "整备台", "prompt": "调整队伍与顺序"}
}

@onready var camp_player: Node2D = $CampPlayer
@onready var characters_root: Node2D = $Characters
@onready var canvas: CanvasLayer = $CanvasLayer

var camp_role_id := "swordsman"
var focused_interactables: Array[Node] = []
var highlighted_interactable: Node
var prompt_label: Label
var message_label: Label
var overview: Control
var shop_panel: Control
var role_panel: Control
var tier_overlay: Control
var team_swap_panel: Control
var tutorial_prompt_panel: Control
var last_focus: WeakRef


func _ready() -> void:
	get_tree().paused = false
	_build_ui()
	_refresh_camp()
	for node in get_tree().get_nodes_in_group("camp_interactable"):
		node.focus_changed.connect(_on_interactable_focus_changed)
		node.interacted.connect(_on_interactable_interacted)
		var id := str(node.get("interactable_id"))
		var text: Dictionary = INTERACTABLE_TEXT.get(id, {})
		if not text.is_empty():
			node.set("display_name", text["name"])
			node.set("prompt_text", text["prompt"])
		var label := node.get_parent().get_node_or_null("NameLabel") as Label
		if label != null:
			label.add_theme_font_override("font", UI.get_reading_font())
			label.add_theme_font_size_override("font_size", 15)
			label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.88))
			label.add_theme_color_override("font_shadow_color", Color(0.03, 0.05, 0.04))
			label.add_theme_constant_override("shadow_offset_x", 1)
			label.add_theme_constant_override("shadow_offset_y", 2)
			if not text.is_empty():
				label.text = str(text["name"])
	_update_prompt()


func _build_ui() -> void:
	overview = OVERVIEW.new()
	overview.name = "CampOverview"
	canvas.add_child(overview)
	overview.shop_requested.connect(_open_ruan_stone_shop)
	overview.team_requested.connect(_open_team_swap_panel)
	overview.departure_requested.connect(_open_tier_overlay)
	overview.menu_requested.connect(_return_to_menu)
	shop_panel = SHOP_PANEL.new()
	shop_panel.name = "CampShopPanel"
	canvas.add_child(shop_panel)
	shop_panel.closed.connect(_on_panel_closed)
	shop_panel.profile_changed.connect(_refresh_camp)
	role_panel = ROLE_PANEL.new()
	role_panel.name = "CampRolePanel"
	canvas.add_child(role_panel)
	role_panel.closed.connect(_on_panel_closed)
	role_panel.prepare_requested.connect(_open_team_swap_panel)
	tier_overlay = ENDLESS_TIER_OVERLAY.new()
	tier_overlay.name = "EndlessTierOverlay"
	canvas.add_child(tier_overlay)
	tier_overlay.closed.connect(_on_panel_closed)
	tier_overlay.tier_selected.connect(_on_endless_tier_selected)
	team_swap_panel = TEAM_SWAP_PANEL_SCENE.instantiate()
	team_swap_panel.name = "TeamSwapPanel"
	canvas.add_child(team_swap_panel)
	team_swap_panel.closed.connect(_on_panel_closed)
	team_swap_panel.team_changed.connect(func(_team: Array): _refresh_camp())
	tutorial_prompt_panel = MODAL.new()
	tutorial_prompt_panel.name = "TutorialPromptPanel"
	canvas.add_child(tutorial_prompt_panel)
	tutorial_prompt_panel.configure(Vector2(560, 300), 0.5, 0.45, Vector2(360, 250))
	tutorial_prompt_panel.set_title("进入训练场")
	tutorial_prompt_panel.set_hint("练习移动、切换角色与基础战斗。教学结束后返回营地，携带物品与骨头保持不变。")
	tutorial_prompt_panel.add_footer_button("留在营地", _close_tutorial_prompt)
	tutorial_prompt_panel.add_footer_button("进入教学", _enter_movement_tutorial, "primary")
	tutorial_prompt_panel.hide()
	prompt_label = Label.new()
	prompt_label.name = "PromptLabel"
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(400, 560)
	prompt_label.size = Vector2(480, 40)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_override("font", UI.get_reading_bold_font())
	prompt_label.add_theme_font_size_override("font_size", 20)
	prompt_label.add_theme_color_override("font_color", UI.COLOR_TEXT_GOLD)
	prompt_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(prompt_label)
	message_label = Label.new()
	message_label.name = "MessageLabel"
	message_label.position = Vector2(220, 110)
	message_label.size = Vector2(840, 38)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_override("font", UI.get_reading_font())
	message_label.add_theme_font_size_override("font_size", 17)
	message_label.add_theme_color_override("font_color", UI.COLOR_TEXT_GOLD)
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(message_label)


func _refresh_camp() -> void:
	var profile := SAVE_MANAGER.get_current_endless_profile()
	var team: Array = team_swap_panel.get_team_ids(profile)
	var role_id := str(team[0])
	if camp_role_id != role_id or camp_player.role_visual == null:
		camp_role_id = role_id
		camp_player.set_role_visual(role_id)
	for id in STAND_NAMES:
		var stand: Node2D = characters_root.get_node(STAND_NAMES[id])
		stand.visible = id != camp_role_id
		var interactable: Node = stand.get_node("Interactable")
		interactable.set("enabled", stand.visible)
		interactable.set("display_name", PRESENTER.get_role_name(id))
		interactable.set("prompt_text", "了解" + PRESENTER.get_role_name(id))
		var label: Label = stand.get_node("NameLabel")
		label.text = PRESENTER.get_role_name(id) + (" · 队员" if team.has(id) else " · 候补")
	var moves: PackedStringArray = []
	for action in [GAME_SETTINGS.ACTION_MOVE_UP, GAME_SETTINGS.ACTION_MOVE_LEFT, GAME_SETTINGS.ACTION_MOVE_DOWN, GAME_SETTINGS.ACTION_MOVE_RIGHT]:
		moves.append(GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(action)))
	var key := GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_INTERACT))
	overview.refresh(profile, SAVE_MANAGER.load_run(-1, SAVE_MANAGER.MODE_ENDLESS), team, "%s 移动  ·  %s 交互  ·  Esc 返回" % ["/".join(moves), key])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _panel_open():
			_close_panels()
		else:
			_return_to_menu()
		get_viewport().set_input_as_handled()
	elif GAME_SETTINGS.event_matches_action(event, GAME_SETTINGS.ACTION_INTERACT):
		_handle_interact()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if focused_interactables.size() > 1 and camp_player.velocity.length_squared() > 0.01 and not _panel_open():
		_update_prompt()


func _panel_open() -> bool:
	for panel in [shop_panel, role_panel, tier_overlay, team_swap_panel, tutorial_prompt_panel]:
		if panel != null and panel.visible:
			return true
	return false


func _close_panels() -> void:
	for panel in [shop_panel, role_panel, tier_overlay, team_swap_panel]:
		if panel.visible:
			if panel == tier_overlay:
				panel.close_overlay()
			else:
				panel.close_panel()
	tutorial_prompt_panel.hide()
	_on_panel_closed()


func _begin_panel() -> void:
	_close_panels()
	var focus := get_viewport().gui_get_focus_owner()
	last_focus = weakref(focus) if focus != null else null
	message_label.text = ""


func _sync_modal_state() -> void:
	var locked := _panel_open()
	camp_player.set_physics_process(not locked)
	if locked:
		camp_player.stop_movement()
	overview.set_actions_enabled(not locked)
	_update_prompt()


func _on_panel_closed() -> void:
	_sync_modal_state()
	if not _panel_open() and last_focus != null:
		var focus: Control = last_focus.get_ref() as Control
		if focus != null and focus.is_visible_in_tree():
			focus.grab_focus()


func _handle_interact() -> void:
	if _panel_open():
		return
	var interactable := _get_best_interactable()
	if interactable != null:
		interactable.try_interact()


func _on_interactable_focus_changed(interactable: Node, focused: bool) -> void:
	if focused and not focused_interactables.has(interactable):
		focused_interactables.append(interactable)
	elif not focused:
		focused_interactables.erase(interactable)
	_update_prompt()


func _get_best_interactable() -> Node:
	var best: Node
	var closest := INF
	for index in range(focused_interactables.size() - 1, -1, -1):
		var interactable: Node = focused_interactables[index]
		if not is_instance_valid(interactable):
			focused_interactables.remove_at(index)
		elif interactable.can_interact():
			var distance: float = camp_player.global_position.distance_squared_to(interactable.global_position)
			if distance < closest:
				closest = distance
				best = interactable
	return best


func _update_prompt() -> void:
	if prompt_label == null:
		return
	if is_instance_valid(highlighted_interactable):
		highlighted_interactable.set_highlighted(false)
	highlighted_interactable = null if _panel_open() else _get_best_interactable()
	prompt_label.visible = highlighted_interactable != null
	if highlighted_interactable != null:
		highlighted_interactable.set_highlighted(true)
		var key := GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_INTERACT))
		prompt_label.text = "[%s] %s" % [key, highlighted_interactable.get_prompt_text()]


func _on_interactable_interacted(interactable: Node) -> void:
	if _panel_open():
		return
	match str(interactable.get("interaction_kind")):
		"portal": _open_tier_overlay()
		"team_swap": _open_team_swap_panel()
		"tutorial": _open_tutorial_prompt()
		"shop": _open_shop()
		"dialogue":
			var id := str(interactable.get("interactable_id"))
			if id == "ruan_dog":
				_open_ruan_stone_shop()
			elif ROLES.ROLE_IDS.has(id):
				_begin_panel()
				role_panel.open(id, team_swap_panel.get_team_ids(SAVE_MANAGER.get_current_endless_profile()))
				_sync_modal_state()


func _open_shop() -> void:
	_begin_panel()
	shop_panel.open("equipment")
	_sync_modal_state()


func _open_ruan_stone_shop() -> void:
	_begin_panel()
	shop_panel.open("all")
	_sync_modal_state()


func _open_team_swap_panel() -> void:
	_begin_panel()
	team_swap_panel.open(SAVE_MANAGER.MODE_ENDLESS)
	_sync_modal_state()


func _open_tutorial_prompt() -> void:
	_begin_panel()
	tutorial_prompt_panel.show()
	tutorial_prompt_panel.apply_layout()
	tutorial_prompt_panel.footer.get_child(0).grab_focus()
	_sync_modal_state()


func _close_tutorial_prompt() -> void:
	tutorial_prompt_panel.hide()
	_on_panel_closed()


func _enter_movement_tutorial() -> void:
	_close_tutorial_prompt()
	get_tree().change_scene_to_file(MOVEMENT_TUTORIAL_SCENE_PATH)


func _open_tier_overlay() -> void:
	_begin_panel()
	var profile := SAVE_MANAGER.get_current_endless_profile()
	if profile.is_empty():
		message_label.text = "未找到当前无尽档案，请从无尽存档入口进入营地。"
		return
	var run := SAVE_MANAGER.load_run(-1, SAVE_MANAGER.MODE_ENDLESS)
	if run.is_empty() and SAVE_MANAGER.has_unarchived_legacy_endless_run():
		var dialog := ConfirmationDialog.new()
		dialog.title = "当前战局无法恢复"
		dialog.dialog_text = "战局主档与备份均不可用。可保留原件退出，或保存诊断副本并放弃本层构筑。永久骨头、携带物与N进度保留。"
		dialog.ok_button_text = "放弃本层并重新选层"
		dialog.cancel_button_text = "保留并返回"
		add_child(dialog)
		dialog.confirmed.connect(func():
			if SAVE_MANAGER.clear_save(-1, SAVE_MANAGER.MODE_ENDLESS):
				tier_overlay.open(profile, {})
			else:
				message_label.text = "诊断文件未能保存，原战局已保留。请检查存储空间。"
			_sync_modal_state()
			dialog.queue_free()
		)
		dialog.canceled.connect(func():
			dialog.queue_free()
			_on_panel_closed()
		)
		dialog.popup_centered(Vector2i(560, 240))
		return
	tier_overlay.open(profile, run)
	_sync_modal_state()


func _on_endless_tier_selected(tier: int, continue_existing: bool) -> void:
	if continue_existing:
		SAVE_MANAGER.request_continue()
	elif not SAVE_MANAGER.select_current_endless_tier(tier):
		tier_overlay.show_error("选层未保存，请检查存储空间或档案状态后重试。")
		return
	tier_overlay.close_overlay()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _return_to_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
