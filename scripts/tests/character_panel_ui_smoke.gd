extends SceneTree

const PANEL := preload("res://scripts/ui/hud/character_panel.gd")
const PLAYER := preload("res://scenes/player.tscn")
const SHEET := preload("res://scripts/player/player_character_sheet.gd")
const BLESSINGS := preload("res://scripts/player/player_blessing_system.gd")
const SKILLS := preload("res://scripts/player/player_blessing_skill_state.gd")
const LEVELS := preload("res://scripts/player/player_skill_level_system.gd")
class PanelHost:
	extends Node
	var character_panel: Node
	var player: Node
	var level_up_ui: Control
	var pause_menu: Control
	var game_over := false

var failures: Array[String] = []
var capture_dir := ""

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_dir = arg.trim_prefix("--capture=")
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var player := PLAYER.instantiate()
	world.add_child(player)
	player.configure_story_loadout(["swordsman", "gunner", "mechanic"])
	player.visible = false
	await process_frame
	paused = true
	var panel := PANEL.new()
	root.add_child(panel)
	panel.show_for_player(player)
	await _settle()
	_expect(panel.selected_tab == "overview" and panel.selected_items.overview == "attack", "Opening should select overview / attack")
	_expect(panel.records.size() == 14, "Overview should retain all 14 current stats")
	for stat_id in ["base_attack_speed", "damage_bonus", "status_resistance"]:
		_expect(panel.records.has(stat_id), "Overview must retain %s" % stat_id)
	await _capture("01-starting-overview")
	_check_stats(player)
	panel._set_tab("blessings")
	_expect(panel.records.is_empty() and _text(panel.detail).contains("暂无祝福"), "Empty blessings should have a useful empty state")
	panel._set_tab("overview")

	BLESSINGS.apply_blessing(player, "blazing_sun", 1)
	BLESSINGS.apply_blessing(player, "blazing_sun", 1)
	BLESSINGS.apply_blessing(player, "divine_grace", 1)
	BLESSINGS.apply_blessing(player, "divine_grace", 2)
	BLESSINGS.apply_blessing(player, "divine_grace", 2)
	BLESSINGS.apply_blessing(player, "tailwind", 1)
	BLESSINGS.apply_blessing(player, "unyielding", 1)
	SKILLS.force_unlock_skill(player, "tulip_turret", 1)
	SKILLS.force_unlock_skill(player, "missile_volley", 1)
	LEVELS.add_skill_level(player, "swordsman", "swordsman_basic", 8)
	player.switch_power_remaining = 3.0
	player.switch_power_role_id = "gunner"
	player.switch_power_damage_multiplier = 1.25
	player.frenzy_remaining = 3.0
	player.frenzy_stacks = 4
	_check_stats(player)
	player.switch_power_remaining = 0.0
	player.frenzy_remaining = 0.0
	var active: int = player.active_role_index
	panel._view_role(2)
	await _settle()
	_expect(player.active_role_index == active, "Viewing another role must not change combat role")
	_expect(is_equal_approx(float(panel.records.attack.value), 27.0), "Mechanic attack should be 23 + 2 + 2 = 27")
	_expect(_text(panel.detail).contains("焰阳") and _text(panel.detail).contains("×2"), "Attack must identify owned blessing quantities")
	await _capture("02-mechanic-sources")

	var special_before: Dictionary = player.role_special_states.duplicate(true)
	var equipment_before: Dictionary = player.role_equipment_levels.duplicate(true)
	for tab in PANEL.TAB_IDS:
		panel._set_tab(tab)
		await _settle()
		for id in panel.records.keys():
			panel._select_item(id)
	if player.role_special_states != special_before:
		print("STATE_BEFORE ", JSON.stringify(special_before))
		print("STATE_AFTER ", JSON.stringify(player.role_special_states))
	_expect(player.role_special_states == special_before, "Browsing details must not mutate role state")
	_expect(player.role_equipment_levels == equipment_before, "Browsing details must not mutate equipment")
	_expect(player.active_role_index == active, "All pages must preserve active role")

	panel._set_tab("overview")
	panel._select_item("dodge")
	panel._view_role(1)
	_expect(panel.selected_items.overview == "dodge", "Role changes should retain selected stat")
	panel._set_tab("skills")
	panel._view_role(0)
	panel._select_item("swordsman_basic")
	_expect(_text(panel.detail).contains("/ 9") and not _text(panel.detail).contains("天赋位"), "Custom basic must use current LV0-9 branches")
	var base_state: Dictionary = player.role_special_states.duplicate(true)
	player.role_special_states.swordsman.skill_levels["swordsman_basic"] = 0
	panel.refresh()
	panel._select_item("swordsman_basic")
	_expect(_text(panel.detail).contains("Lv.0 / 9") and not _text(panel.detail).contains("解锁方式"), "Innate LV0 basic must remain usable")
	player.role_special_states = base_state
	panel._view_role(1)
	_expect(panel.records.size() == LEVELS.ROLE_PROGRESS_ORDER.gunner.size(), "Gunner must retain the independent hunt record")
	panel._view_role(2)
	panel._select_item("mechanic_tulip_turret")
	var skill_text := _text(panel.detail)
	_expect(skill_text.contains("当前效果") and skill_text.contains("冷却时间"), "Owned active skill must show actual effect and cooldown")
	_expect(not skill_text.contains("进化需求"), "Character sheet must not suggest obsolete recipe unlocks")
	await _settle()
	await _capture("03-mechanic-skill")
	LEVELS.add_skill_level(player, "mechanic", "mechanic_tulip_turret", 4)
	var talent_offer := LEVELS.build_talent_offer_for(player, "mechanic", "mechanic_tulip_turret")
	LEVELS.apply_option_with_result(player, talent_offer["options"][0]["id"], talent_offer)
	panel._set_tab("skills")
	panel._select_item("mechanic_tulip_turret")
	var talent_before: Dictionary = player.role_special_states.duplicate(true)
	_expect(_text(panel.detail).contains("双联供弹   已生效") and _text(panel.detail).contains("超频枪架   待选择"), "Mechanic detail must distinguish granted and pending dedicated talents")
	panel._select_item("mechanic_tulip_turret")
	_expect(player.role_special_states == talent_before, "Reading dedicated talents must not grant or replay them")
	await _settle()
	await _capture("03b-mechanic-talents")
	panel.detail_scroll.scroll_vertical = int(panel.detail_scroll.get_v_scroll_bar().max_value)
	await _settle()
	await _capture("03c-mechanic-talent-details")
	panel._select_item("mechanic_drone")
	_expect(_text(panel.detail).contains("获得技能") and not _text(panel.detail).contains("进化需求"), "Locked skills should explain acquisition cards")
	panel._select_item("mechanic_ultimate")
	_expect(not _text(panel.detail).contains("Lv.") and not _text(panel.detail).contains("天赋位"), "Ultimate must not show invented leveling progress")

	panel._set_tab("blessings")
	_expect(SHEET.blessing_total("blazing_sun", {1: 2}).contains("固定攻击 +4.00"), "Blessing totals must include extra stats such as flat attack")
	panel._select_item("role:divine_grace")
	_expect(_text(panel.detail).contains("55.0%"), "Mixed blessing tiers should show +55% health in total")
	_expect(_text(panel.detail).contains("每份效果") and _text(panel.detail).contains("× 2"), "Per-copy text must be distinguished from aggregate")
	await _settle()
	await _capture("04-blessing-tiers")

	var item := "small_boss_equipment_ocean_amulet"
	player.role_equipment_levels.mechanic[item] = 2
	panel._set_tab("equipment")
	panel._select_item(item)
	_expect(_text(panel.detail).contains("44") and _text(panel.detail).contains("1.80"), "Equipment should show cumulative effects")
	_expect(panel.find_child("GiftButton", true, false) != null, "Gift action must be visible")
	await _settle()
	await _capture("05-equipment-gift")
	panel._show_gift_popup(item, "mechanic")
	panel._on_gift_popup_index_pressed(0)
	panel.gift_popup.hide()
	_expect(int(player.role_equipment_levels.mechanic.get(item, 0)) == 1, "Gifting must transfer exactly one item")
	_expect(int(player.role_equipment_levels.swordsman.get(item, 0)) == 1, "Gift recipient must receive exactly one item")
	player.role_equipment_levels.swordsman[item] = 3
	panel._show_gift_popup(item, "mechanic")
	_expect(panel.gift_popup.is_item_disabled(0), "Recipient at item cap should be disabled")
	panel.gift_popup.hide()

	var key := InputEventKey.new()
	key.keycode = KEY_TAB
	key.ctrl_pressed = true
	key.pressed = true
	panel._input(key)
	_expect(panel.selected_tab == "overview", "Ctrl Tab should cycle through all four tabs")
	panel._set_tab("skills")
	await _settle()
	var last: Button = panel.item_buttons["mechanic_ultimate"]
	last.grab_focus()
	await _settle()
	_expect(panel.selected_items.skills == "mechanic_ultimate", "Keyboard focus should update stable details")
	if panel.list_scroll.scroll_vertical <= 0:
		print("FOCUS_GEOMETRY ", last.has_focus(), " ", last.get_global_rect(), " / ", panel.list_scroll.get_global_rect(), " content ", panel.list_content.size)
	_expect(panel.list_scroll.scroll_vertical > 0, "Keyboard focus should scroll the list to the selected skill")

	player.role_special_states.mechanic["level_talents"] = ["mechanic_level_talent_trait_1"]
	panel._set_tab("skills")
	_expect(panel.records.has("mechanic_level_talent_trait_1"), "Saved level talents must be visible")
	panel._select_item("mechanic_level_talent_trait_1")
	_expect(_text(panel.detail).contains("已生效强化") and not _text(panel.detail).contains("mechanic_level_talent"), "Talent details must resolve authored title and effect")
	await _settle()
	await _capture("07-owned-talent")
	for id in BLESSINGS.DEFINITIONS:
		if BLESSINGS.DEFINITIONS[id].get("binding", "") == BLESSINGS.ROLE_BOUND:
			BLESSINGS.apply_blessing(player, id, 1, false)
	panel._set_tab("blessings")
	await _settle()
	var first_id: String = panel.records.keys()[0]
	panel._select_item(first_id)
	var selected_before: String = panel.selected_items.blessings
	panel.list_scroll.scroll_vertical = 10000
	await _settle()
	_expect(panel.list_scroll.scroll_vertical > 0 and panel.selected_items.blessings == selected_before, "Scrolling long lists should retain fixed details")
	await _capture("08-long-blessings")
	player.configure_story_loadout(["swordsman", "gunner", "mage"])
	player.ruan_stone_purchased = ["broken_sword", "ground_branch", "tattered_cloak", "tattered_cloak", "broken_chestplate", "rusted_dagger", "failed_assassin_dagger"]
	player.role_equipment_levels.mage["small_boss_equipment_spell_prism"] = 3
	player.role_equipment_levels.mage["small_boss_equipment_ocean_amulet"] = 2
	_check_stats(player)
	panel._view_role(2)
	for tab in PANEL.TAB_IDS:
		panel._set_tab(tab)
		for id in panel.records.keys():
			panel._select_item(id)
	panel._set_tab("overview")
	root.size = Vector2i(960, 540)
	await _settle()
	var last_stat: Button = panel.item_buttons.cooldown
	panel.list_scroll.ensure_control_visible(last_stat)
	await _settle()
	_expect(last_stat.get_global_rect().end.y <= panel.list_scroll.get_global_rect().end.y + 1, "All retained stats must be reachable by scrolling at minimum window size")
	await _capture("06-minimum-window")
	var host := PanelHost.new()
	root.add_child(host)
	host.character_panel = panel
	host.player = player
	host.level_up_ui = Control.new()
	host.pause_menu = Control.new()
	host.add_child(host.level_up_ui)
	host.add_child(host.pause_menu)
	host.pause_menu.hide()
	host.level_up_ui.show()
	preload("res://scripts/game/session_state.gd").set_pause_reason(host, "reward", true)
	var flow := preload("res://scripts/game/game_character_panel_flow.gd")
	panel.close_requested.connect(func(): flow.hide_character_panel(host))
	flow.show_character_panel(host)
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	panel._input(escape)
	_expect(paused and not panel.visible, "Esc close over a reward offer must keep the game paused")
	host.level_up_ui.hide()
	preload("res://scripts/game/session_state.gd").set_pause_reason(host, "reward", false)
	flow.show_character_panel(host)
	_expect(paused and panel.visible, "Opening from combat must pause")
	flow.hide_character_panel(host)
	_expect(not paused, "Closing from combat must resume")
	host.queue_free()
	_expect(not panel.visible and not panel.gift_popup.visible, "Closing sheet should hide child popup")
	panel.queue_free()
	world.queue_free()
	await process_frame
	paused = false
	if failures.is_empty():
		print("CHARACTER_PANEL_UI_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_stats(player: Node) -> void:
	for role in player.roles:
		for row in SHEET.get_stats(player, role):
			var value := 0.0
			var complement := 1.0
			for source in row.sources:
				match str(source.op):
					"=": value = float(source.value)
					"+": value += float(source.value)
					"*": value *= float(source.value)
					"chance": complement *= 1.0 - float(source.value)
			if row.id in ["dodge", "reduction"]:
				value = 1.0 - complement
			elif row.id == "cooldown":
				value = 1.0 - value
			elif row.id == "crit":
				value = clampf(value, 0.0, 1.0)
			_expect(is_equal_approx(value, float(row.value)), "%s %s sources should reproduce combat result: %s != %s" % [role.id, row.id, value, row.value])

func _settle() -> void:
	for _frame in range(5):
		await process_frame

func _capture(file_name: String) -> void:
	if capture_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(file_name + ".png"))

func _text(node: Node) -> String:
	var parts: PackedStringArray = []
	if node is Label or node is Button:
		parts.append(str(node.text))
	for child in node.get_children():
		parts.append(_text(child))
	return "\n".join(parts)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
