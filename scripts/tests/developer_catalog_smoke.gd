extends SceneTree

const TOOLS := preload("res://scripts/developer/developer_build_tools.gd")
const ACTIONS := preload("res://scripts/developer/developer_actions.gd")
const MODE := preload("res://scripts/developer_mode.gd")
const PANEL := preload("res://scripts/developer/developer_panel.gd")
const HUD := preload("res://scripts/hud.gd")
const PLAYER := preload("res://scenes/player.tscn")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var main := MainStub.new()
	scene.add_child(main)
	var player = PLAYER.instantiate()
	main.player = player
	main.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.auto_attack_enabled = false
	player.fire_timer.stop()
	var blessings := TOOLS.blessing_catalog(player)
	check(blessings.size() == 7, "only seven current blessings")
	var names: Array = []
	for entry in blessings:
		names.append(entry["title"])
	check(names == ["神赐", "支援", "贪婪", "乘风", "焰阳", "爆烈", "不屈"], "current blessing names")
	var request := {"kind": "blessing", "id": "blazing_sun", "tier": 3, "operation": "add", "amount": 2}
	check(not ACTIONS.apply_catalog_action(main, request), "normal mode rejects developer changes")
	MODE.activate()
	var base_attack: float = player._get_role_damage("swordsman")
	check(ACTIONS.apply_catalog_action(main, request), "grant blessing")
	check(player._get_role_damage("swordsman") > base_attack, "blessing changes actual damage")
	check(_count(player, "blazing_sun", 3) == 2, "grant exact tier quantity")
	request["operation"] = "remove"
	request["amount"] = 1
	ACTIONS.apply_catalog_action(main, request)
	check(_count(player, "blazing_sun", 3) == 1, "remove one")
	request["operation"] = "clear"
	ACTIONS.apply_catalog_action(main, request)
	check(is_equal_approx(player._get_role_damage("swordsman"), base_attack), "clear returns original damage")
	check(not ACTIONS.apply_catalog_action(main, {"kind": "blessing", "id": "prayer", "operation": "add"}), "legacy blessing rejected")
	var base_hp: float = player.max_health
	ACTIONS.apply_catalog_action(main, {"kind": "blessing", "id": "divine_grace", "tier": 4, "operation": "add"})
	check(player.max_health > base_hp, "health blessing refreshes max health")
	ACTIONS.apply_catalog_action(main, {"kind": "blessing", "id": "divine_grace", "tier": 4, "operation": "clear"})
	check(is_equal_approx(player.max_health, base_hp) and player.current_health <= base_hp, "health removal clamps correctly")
	ACTIONS.apply_catalog_action(main, {"kind": "all_blessings", "tier": 2, "operation": "add", "amount": 2})
	for entry in blessings:
		check(_count(player, entry["id"], 2) == 2, "bulk honors tier and quantity")
		ACTIONS.apply_catalog_action(main, {"kind": "blessing", "id": entry["id"], "tier": 2, "operation": "clear"})
	var base_speed: float = player._get_effective_attack_speed("swordsman")
	ACTIONS.apply_catalog_action(main, {"kind": "item", "id": "ground_branch", "operation": "add", "amount": 2})
	check(is_equal_approx(player._get_effective_attack_speed("swordsman"), base_speed + 0.10), "items immediately change speed")
	ACTIONS.apply_catalog_action(main, {"kind": "item", "id": "ground_branch", "operation": "clear"})
	check(is_equal_approx(player._get_effective_attack_speed("swordsman"), base_speed), "item clear restores speed")
	ACTIONS.apply_catalog_action(main, {"kind": "item", "id": "broken_chestplate", "operation": "add", "amount": 2})
	check(is_equal_approx(player.max_health, base_hp + 60.0), "chestplate refreshes max health")
	ACTIONS.apply_catalog_action(main, {"kind": "item", "id": "broken_chestplate", "operation": "clear"})
	check(is_equal_approx(player.max_health, base_hp), "chestplate removal restores max health")
	var items: Array = TOOLS.item_catalog(player)
	var poison_entry: Dictionary = {}
	for entry in items:
		if str(entry.get("id", "")) == "poison":
			poison_entry = entry
	check(items.size() == 17 and not poison_entry.is_empty(), "current item catalog includes all 17 stones, including poison")
	check(ACTIONS.apply_catalog_action(main, {"kind": "item", "id": "poison", "operation": "add", "amount": 2}), "formal poison stone can be granted")
	check(player.get_ruan_stone_level("poison") == 2, "poison grant applies exact quantity")
	check(not ACTIONS.apply_catalog_action(main, {"kind": "item", "id": "not_a_stone", "operation": "add"}), "unknown item remains rejected")
	ACTIONS.apply_catalog_action(main, {"kind": "item", "id": "poison", "operation": "clear"})
	check(player.get_ruan_stone_level("poison") == 0, "poison clear removes granted quantity")
	var skill := {"kind": "skill", "role_id": "swordsman", "id": "swordsman_basic"}
	ACTIONS.apply_catalog_action(main, skill.merged({"operation": "set", "amount": 9}))
	for entry in [[4, "heavy"], [8, "split"], [9, "brave"]]:
		check(ACTIONS.apply_catalog_action(main, skill.merged({"operation": "branch", "stage": entry[0], "choice": entry[1]})), "branch selection")
	check(is_equal_approx(player._get_effective_attack_speed("swordsman"), 0.2), "heavy brave speed matches the current basic-build contract")
	ACTIONS.apply_catalog_action(main, skill.merged({"operation": "branch", "stage": 4, "choice": "light"}))
	check(not TOOLS.BASIC.has_choice(player, "heavy") and TOOLS.BASIC.has_choice(player, "split"), "replacement preserves other stages")
	check(is_equal_approx(player._get_effective_attack_speed("swordsman"), 1.0), "light branch replacement removes heavy speed penalty")
	ACTIONS.apply_catalog_action(main, skill.merged({"operation": "set", "amount": 4}))
	check(TOOLS.BASIC.choices(player) == {"4": "light"}, "lower level clears higher stages")
	check(not ACTIONS.apply_catalog_action(main, skill.merged({"operation": "branch", "stage": 9, "choice": "guard"})), "underlevel branch rejected")
	ACTIONS.apply_catalog_action(main, skill.merged({"operation": "reset"}))
	check(TOOLS.BASIC.level(player) == 0 and TOOLS.BASIC.choices(player).is_empty(), "reset basic to LV0")
	ACTIONS.apply_catalog_action(main, skill.merged({"operation": "add"}))
	check(TOOLS.BASIC.level(player) == 1, "normal +1 path")
	var active := {"kind": "skill", "role_id": "swordsman", "id": "swordsman_blade_storm"}
	check(not ACTIONS.apply_catalog_action(main, active.merged({"operation": "set", "amount": 5})), "locked skill cannot upgrade")
	check(ACTIONS.apply_catalog_action(main, active.merged({"operation": "unlock"})), "unlock current active skill")
	ACTIONS.apply_catalog_action(main, active.merged({"operation": "set", "amount": 10}))
	check(TOOLS.LEVELS.get_skill_level(player, "swordsman", "swordsman_blade_storm") == 9, "storm uses LV9 cap")
	check(main.save_count == 0, "developer operations never write profile")
	await _check_ui(scene, main)
	scene.queue_free()
	await process_frame
	MODE.deactivate()
	if failures.is_empty():
		print("DEVELOPER_CATALOG_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _count(player, id: String, tier: int) -> int:
	for entry in TOOLS.blessing_catalog(player):
		if entry["id"] == id:
			for value in entry["tiers"]:
				if value["tier"] == tier:
					return int(value["count"])
	return 0

func _data(player) -> Dictionary:
	return {"blessing": TOOLS.blessing_catalog(player), "skill": TOOLS.skill_catalog(player), "item": TOOLS.item_catalog(player)}

func _button(parent: Node, title: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == title:
			return child
	return null

func _check_ui(scene: Node, main: Node) -> void:
	var hud := HUD.new()
	scene.add_child(hud)
	await process_frame
	var panel: Control = hud.developer_panel
	check(panel != null, "actual HUD contains developer panel")
	if panel == null:
		return
	hud.developer_catalog_action_requested.connect(func(request):
		ACTIONS.apply_catalog_action(main, request)
		hud.set_developer_catalog_data(_data(main.player))
	)
	hud.set_developer_catalog_data(_data(main.player))
	await process_frame
	check(panel.catalog_tabs.get_tab_count() == 4, "four categories")
	var blessing_page = panel.catalogs["blessing"]
	var first_id: int = blessing_page.list.get_child(0).get_instance_id()
	hud.set_developer_catalog_data(_data(main.player))
	check(blessing_page.list.get_child(0).get_instance_id() == first_id, "unchanged refresh retains nodes")
	blessing_page.search.text = "焰阳"
	blessing_page.search.text_changed.emit("焰阳")
	check(blessing_page.list.get_child_count() == 1, "search filters")
	blessing_page.amount.value = 3
	_button(blessing_page.details, "添加").pressed.emit()
	check(_count(main.player, "blazing_sun", 1) == 3, "actual UI signal adds selected count")
	check(blessing_page.search.text == "焰阳" and blessing_page.amount.value == 3, "refresh preserves selection and amount")
	_button(blessing_page.details, "减少").pressed.emit()
	check(_count(main.player, "blazing_sun", 1) == 0, "remove button is not add")
	var skill_page = panel.catalogs["skill"]
	panel.catalog_tabs.current_tab = 1
	skill_page.selected_id = "swordsman_basic"
	skill_page._rebuild_list()
	skill_page.amount.value = 9
	_button(skill_page.details, "设置为指定等级").pressed.emit()
	_button(skill_page.details, "守势").pressed.emit()
	check(TOOLS.BASIC.has_choice(main.player, "guard"), "UI branch action routed")
	_button(skill_page.details, "勇猛").pressed.emit()
	check(TOOLS.BASIC.has_choice(main.player, "brave") and not TOOLS.BASIC.has_choice(main.player, "guard"), "UI replaces branch")
	var item_page = panel.catalogs["item"]
	panel.catalog_tabs.current_tab = 2
	item_page.selected_id = "failed_assassin_dagger"
	item_page._rebuild_list()
	item_page.amount.value = 2
	_button(item_page.details, "添加").pressed.emit()
	check(main.player.get_ruan_stone_level("failed_assassin_dagger") == 2, "item button routes exact id")
	await process_frame
	await process_frame
	check(panel.get_global_rect().end.x <= 1280 and panel.get_global_rect().end.y <= 720, "panel fits 1280x720")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://developer_catalog.png")
		panel.catalog_tabs.current_tab = 1
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://developer_catalog_build.png")
	for viewport_size in [Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = viewport_size
		for tab in range(4):
			panel.catalog_tabs.current_tab = tab
			await process_frame
			await process_frame
			var logical_size: Vector2 = panel.get_viewport_rect().size
			check(panel.get_global_rect().end.y <= logical_size.y and panel.get_global_rect().position.y >= 0, "tab %d fits logical height %s" % [tab, logical_size])
			check(panel.get_global_rect().end.x <= logical_size.x and panel.get_global_rect().position.x >= 0, "tab %d fits logical width %s" % [tab, logical_size])
	panel.catalog_tabs.current_tab = 3
	panel.glutton_skill_list.show()
	panel._toggle_enemy_menu()
	await process_frame
	await process_frame
	check(panel.enemy_menu_popup.is_visible_in_tree(), "enemy submenu is open")
	check(not panel.enemy_menu_popup.get_global_rect().intersects(panel.collapse_button.get_global_rect()), "submenu cannot cover collapse button")
	await _click_control(panel.collapse_button)
	check(panel.collapsed and panel.collapse_button.text == "展开菜单", "mouse click collapses from nested submenu")
	check(not panel.menu_body.is_visible_in_tree() and not panel.menu_title.is_visible_in_tree(), "collapsed menu only keeps expand button")
	check(not panel.enemy_menu_popup.is_visible_in_tree(), "collapse hides submenu")
	check(panel.size.y <= 64 and panel.size.x <= 160, "collapsed menu has compact bounds")
	await _click_control(panel.collapse_button)
	check(not panel.collapsed and panel.catalog_tabs.current_tab == 3, "expand restores selected category")
	check(panel.menu_body.is_visible_in_tree() and not panel.enemy_menu_popup.visible, "expand restores body without covering submenu")
	check(blessing_page.search.text == "焰阳", "collapse preserves catalog search")

func _click_control(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
	await process_frame
	await process_frame

class MainStub:
	extends Node
	var player: Node
	var save_count := 0
	func _refresh_hud() -> void:
		pass
	func _save_run_state() -> void:
		save_count += 1
