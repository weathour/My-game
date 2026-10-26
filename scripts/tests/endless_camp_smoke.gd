extends SceneTree

const SAVE := preload("res://scripts/save_manager.gd")
const STORE := preload("res://scripts/save/save_file_store.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")
const ITEMS := preload("res://scripts/player/ruan_stone_system.gd")
const SESSION := preload("res://scripts/game/game_session_flow.gd")
const CAMP := preload("res://scenes/endless_camp.tscn")
const SLOT := 9

var failures: Array[String] = []
var originals: Dictionary = {}
var capture_dir := ""


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_dir = arg.trim_prefix("--capture=")
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	for path in [STORE.META_PATH, STORE.endless_profile_path(SLOT), STORE.endless_run_path(SLOT), STORE.endless_run_backup_path(SLOT)]:
		originals[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	SAVE.create_or_load_endless_profile(SLOT)
	SAVE.clear_save(SLOT, SAVE.MODE_ENDLESS)
	var profile := SAVE.get_current_endless_profile()
	profile.merge({"bones": 50, "highest_cleared_tier": 3, "selected_tier": 1, "team_order": ["gunner", "mage", "mechanic"], "ruan_stone_purchased": ["thunder"]}, true)
	_expect(SAVE.save_endless_profile(profile) > 0, "测试档案写入失败。")
	var camp := CAMP.instantiate()
	root.add_child(camp)
	current_scene = camp
	await _settle()
	_expect(camp.camp_role_id == "gunner", "营地形象必须使用已存阵容首位。")
	_expect(camp.get_node("Characters/Mechanic").visible, "机械师应拥有可见的驻营实体。")
	_expect(not camp.get_node("Characters/Gunner").visible, "玩家形象与同角色驻营实体不应重复。")
	_expect(camp.overview.status_label.text.contains("骨头 50") and camp.overview.team_label.text.contains("机械师"), "营地概览应显示档案、骨头和阵容。")
	await _capture("01-camp")
	await _check_shop(camp)
	await _check_world_interactions(camp)
	await _check_team(camp)
	await _check_layouts(camp)
	await _check_return(camp)
	_restore_files()
	if failures.is_empty():
		print("ENDLESS_CAMP_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_shop(camp: Node) -> void:
	var player: CharacterBody2D = camp.camp_player
	var dog: Area2D = camp.get_node("RuanDog/Interactable")
	player.global_position = dog.global_position
	await _physics_settle()
	_expect(dog.can_interact() and camp.prompt_label.visible and dog.highlighted, "接近商人必须出现交互提示与高亮。")
	camp._unhandled_input(_key(SETTINGS.load_keycode(SETTINGS.ACTION_INTERACT)))
	var shop: Control = camp.shop_panel
	_expect(shop.visible and not player.is_physics_processing() and player.velocity == Vector2.ZERO, "阮狗应直接打开商店并停止移动。")
	_expect(shop.item_list.item_count == 17 and shop.filtered_ids.has("poison"), "商店应完整提供 5 阮石与 12 装备。")
	shop.selected_id = "thunder"
	shop._refresh()
	shop.buy_button.pressed.emit()
	shop.buy_button.pressed.emit()
	_expect(ITEMS.get_count(SAVE.get_current_endless_profile(), "thunder") == 3, "商店必须允许连续购买同一物品。")
	_expect(int(SAVE.get_current_endless_profile().bones) == 40, "两次购买应扣 10 骨。")
	shop.refund_button.pressed.emit()
	_expect(ITEMS.get_count(SAVE.get_current_endless_profile(), "thunder") == 2 and int(shop.profile.bones) == 45, "单独退还应只移除一份并返还 5 骨。")
	var original_profile: Dictionary = shop.profile.duplicate(true)
	var blocked_path := ProjectSettings.globalize_path(STORE.endless_profile_path(SLOT) + ".tmp")
	DirAccess.make_dir_recursive_absolute(blocked_path)
	shop.buy_button.pressed.emit()
	_expect(shop.profile == original_profile and shop.feedback_label.text.contains("写入失败"), "存档失败时界面不得发布未保存的交易。")
	_expect(SAVE.get_current_endless_profile().bones == 45 and ITEMS.get_count(SAVE.get_current_endless_profile(), "thunder") == 2, "存档失败不得扣骨或增加物品。")
	DirAccess.remove_absolute(blocked_path)
	await _capture("02-shop-save-error")
	shop._set_filter("stones")
	_expect(shop.item_list.item_count == 5, "阮石分类应有 5 种。")
	shop._set_filter("equipment")
	_expect(shop.item_list.item_count == 12, "装备分类应有 12 种。")
	shop._set_filter("owned")
	_expect(shop.item_list.item_count == 1, "已携带分类应去除未持有物品。")
	shop._set_filter("all")
	shop.selected_id = "rusted_dagger"
	shop._refresh()
	shop.buy_button.pressed.emit()
	await _settle()
	_expect(shop.current_label.text.contains("暴击伤害 +8%") and shop.next_label.text.contains("暴击伤害 +16%"), "详情必须展示当前与再购一份的累计效果。")
	await _capture("03-shop-details")
	shop.buy_button.pressed.emit()
	_expect(shop.buy_button.disabled and not shop.refund_button.disabled, "携带满时应禁用购买，仍允许退还。")
	_expect(root.gui_get_focus_owner() != null, "购买禁用时仍需保留键盘入口。")
	camp._unhandled_input(_key(KEY_ESCAPE))
	_expect(not shop.visible and player.is_physics_processing(), "关闭商店必须恢复移动。")

func _check_world_interactions(camp: Node) -> void:
	for data in [["Blacksmith/Interactable", "shop_panel"], ["TutorialEntrance/Interactable", "tutorial_prompt_panel"], ["Characters/Mechanic/Interactable", "role_panel"], ["Portal/Interactable", "tier_overlay"]]:
		camp._on_interactable_interacted(camp.get_node(data[0]))
		var panel: Control = camp.get(data[1])
		_expect(panel.visible and not camp.camp_player.is_physics_processing(), "所有营地面板打开时都应锁定移动：%s" % data[0])
		if data[1] == "shop_panel":
			_expect(panel.current_filter == "equipment", "铁匠应复用商店的装备分类。")
		elif data[1] == "role_panel":
			var text := _text(panel)
			_expect(text.contains("机械师") and text.contains("郁金香") and text.contains("天赋") and not text.contains("暂未开放"), "机械师介绍必须接入真实技能与整备入口。")
			await _capture("04-mechanic-resident")
		elif data[1] == "tier_overlay":
			panel._change_tier(1)
			camp._handle_interact()
			_expect(panel.selected_tier == 2, "F 不得重开并重置已经打开的选层面板。")
			_expect(panel.preparation_label.text.contains("机械师") and panel.preparation_label.text.contains("生锈"), "出击确认必须包含阵容与携带物品。")
			await _capture("05-departure")
			var blocked_path := ProjectSettings.globalize_path(STORE.endless_profile_path(SLOT) + ".tmp")
			DirAccess.make_dir_recursive_absolute(blocked_path)
			camp._on_endless_tier_selected(2, false)
			_expect(panel.visible and panel.description_label.text.contains("未保存") and SAVE.get_current_endless_profile().selected_tier == 1, "选层写盘失败应留在当前面板并清楚提示。")
			DirAccess.remove_absolute(blocked_path)
		camp._unhandled_input(_key(KEY_ESCAPE))
		_expect(not panel.visible and camp.camp_player.is_physics_processing(), "Esc 应关闭当前面板并恢复移动。")
	# Continuing preserves the saved combat roster, while camp edits configure the next new run.
	SAVE.save_run({"run_id": "camp-smoke-run", "run_tier": 1, "player": {}}, SLOT, SAVE.MODE_ENDLESS)
	camp._refresh_camp()
	camp._open_tier_overlay()
	_expect(camp.tier_overlay.run_tier == 1 and camp.tier_overlay.plus_button.disabled and camp.tier_overlay.minus_button.disabled, "已有战局时只允许继续当前 N 层。")
	_expect(camp.tier_overlay.description_label.text.contains("原阵容") and camp.overview.result_label.text.contains("下一局"), "继续战局时必须说明阵容调整的生效边界。")
	camp._close_panels()
	SAVE.clear_save(SLOT, SAVE.MODE_ENDLESS)

func _check_team(camp: Node) -> void:
	camp.overview.action_buttons[1].pressed.emit()
	var panel: Control = camp.team_swap_panel
	_expect(panel.visible, "概览的整备按钮必须打开队伍整备。")
	panel._on_team_entry_pressed("mechanic")
	panel.move_up_button.pressed.emit()
	panel.move_up_button.pressed.emit()
	_expect(SAVE.get_current_endless_profile().team_order == ["mechanic", "gunner", "mage"], "队伍前移应保存顺序并允许机械师首发。")
	_expect(camp.camp_role_id == "mechanic" and not camp.get_node("Characters/Mechanic").visible and camp.get_node("Characters/Gunner").visible, "重排后营地形象与驻营成员应同步刷新。")
	_expect(panel.move_up_button.disabled and not panel.move_down_button.disabled, "首位前移应禁用，后移仍可用。")
	var blocked_path := ProjectSettings.globalize_path(STORE.endless_profile_path(SLOT) + ".tmp")
	DirAccess.make_dir_recursive_absolute(blocked_path)
	panel.move_down_button.pressed.emit()
	_expect(panel.profile.team_order == ["mechanic", "gunner", "mage"] and panel.feedback_label.text.contains("写入失败"), "重排保存失败应回滚内存与界面。")
	DirAccess.remove_absolute(blocked_path)
	await _capture("06-team-order")
	panel.close_panel()
	camp._refresh_camp()
	await _capture("07-mechanic-leading")

func _check_layouts(camp: Node) -> void:
	for size_value in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = size_value
		root.content_scale_size = size_value
		await _settle()
		await _capture("camp-%dx%d" % [size_value.x, size_value.y])
		for button in camp.overview.action_buttons:
			_expect(Rect2(Vector2.ZERO, Vector2(size_value)).encloses(button.get_global_rect()), "概览操作必须在视口内。")
		for action in ["_open_ruan_stone_shop", "_open_team_swap_panel", "_open_tier_overlay", "_open_tutorial_prompt"]:
			camp.call(action)
			await _settle()
			var panel: Control = camp.shop_panel if camp.shop_panel.visible else (camp.team_swap_panel if camp.team_swap_panel.visible else camp.tier_overlay)
			var modal: Control = camp.tutorial_prompt_panel if camp.tutorial_prompt_panel.visible else panel.modal
			var bounds: Rect2 = modal.panel.get_global_rect()
			_expect(Rect2(Vector2.ZERO, Vector2(size_value)).encloses(bounds), "面板必须在视口内：%s %s" % [action, size_value])
			for child in modal.footer.get_children():
				_expect(bounds.encloses(child.get_global_rect()), "底部按钮不得溢出：%s %s" % [action, size_value])
			if panel == camp.shop_panel and panel.visible:
				_expect(bounds.encloses(panel.item_list.get_global_rect()), "商品列表不得溢出面板。")
				await _capture("08-shop-%dx%d" % [size_value.x, size_value.y])
			elif panel == camp.team_swap_panel and panel.visible:
				for button in panel.team_buttons.values():
					_expect(bounds.encloses(button.get_global_rect()), "队员按钮不得溢出面板。")
				await _capture("09-team-%dx%d" % [size_value.x, size_value.y])
			camp._close_panels()
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	await _settle()

func _check_return(camp: Node) -> void:
	var before := SAVE.get_current_endless_profile()
	var host := preload("res://scenes/main.tscn").instantiate()
	root.add_child(host)
	current_scene = host
	camp.queue_free()
	await process_frame
	host._save_run_state()
	SESSION.return_to_endless_camp(host)
	await _settle()
	var after := SAVE.get_current_endless_profile()
	_expect(after.ruan_stone_purchased == before.ruan_stone_purchased and after.bones == before.bones, "真实返营流程必须保留永久物品与骨头。")
	_expect(SAVE.load_run(SLOT, SAVE.MODE_ENDLESS).is_empty(), "返营必须清除局内战局。")
	_expect(current_scene != null and current_scene.scene_file_path == "res://scenes/endless_camp.tscn", "真实返营流程应进入营地。")
	if current_scene != null:
		current_scene.queue_free()
	await process_frame

func _restore_files() -> void:
	for path in originals:
		if originals[path] == null:
			STORE.remove_if_exists(path)
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(originals[path])

func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

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

func _physics_settle() -> void:
	for _frame in range(4):
		await physics_frame
		await process_frame

func _settle() -> void:
	for _frame in range(5):
		await process_frame

func _capture(name_value: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await _settle()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	root.get_texture().get_image().save_png(capture_dir.path_join(name_value + ".png"))
