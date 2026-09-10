extends SceneTree

const SAVE_FILE_STORE := preload("res://scripts/save/save_file_store.gd")
const SAVE_PROFILE_DEFAULTS := preload("res://scripts/save/save_profile_defaults.gd")
const ROLE_DATABASE := preload("res://scripts/player/roles/role_database.gd")
const TEAM_SWAP_PANEL := preload("res://scripts/ui/team_swap_panel.gd")
const TEAM_SWAP_PANEL_SCENE := preload("res://scenes/UI/team_swap_panel.tscn")

const TEST_PROFILE_PATH := "user://team_swap_smoke_profile.json"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_team_order_io()
	_check_swap_validation()
	await _check_panel_ui()
	await _check_camp_wiring()
	if failures.is_empty():
		print("TEAM_SWAP_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _check_team_order_io() -> void:
	var default_story: Dictionary = SAVE_PROFILE_DEFAULTS.ensure_story_profile_defaults({}, 1)
	_expect(default_story.get("team_order", []) == ROLE_DATABASE.DEFAULT_TEAM_IDS, "故事档缺省 team_order 应回退默认队伍。")

	SAVE_FILE_STORE.remove_if_exists(TEST_PROFILE_PATH)
	_expect(SAVE_FILE_STORE.write_json(TEST_PROFILE_PATH, {"team_order": ["swordsman", "gunner", "mechanic"], "unlocked_role_ids": ["swordsman", "gunner", "mage", "mechanic"]}) > 0, "team_order 测试存档写入失败。")
	var loaded: Variant = SAVE_FILE_STORE.read_json(TEST_PROFILE_PATH)
	_expect(loaded is Dictionary, "team_order 测试存档读回失败。")
	if loaded is Dictionary:
		var ensured := SAVE_PROFILE_DEFAULTS.ensure_story_profile_defaults(loaded, 1)
		_expect(ensured.get("team_order", []) == ["swordsman", "gunner", "mechanic"], "故事档 team_order 读写后应保持换人结果。")
	SAVE_FILE_STORE.remove_if_exists(TEST_PROFILE_PATH)

	var endless: Dictionary = SAVE_PROFILE_DEFAULTS.ensure_endless_profile_defaults({"team_order": ["mechanic", "gunner", "mage"]}, 1)
	var endless_team: Array = endless.get("team_order", [])
	_expect(endless_team == ["mechanic", "gunner", "mage"], "无尽档 team_order 应保持自定义顺序。")

	var duplicated: Dictionary = SAVE_PROFILE_DEFAULTS.ensure_story_profile_defaults({"team_order": ["mage", "mage"]}, 1)
	var fixed_team: Array = duplicated.get("team_order", [])
	_expect(fixed_team.size() == 3, "非法 team_order 归一化后必须恰好 3 人，实际 %d 人。" % fixed_team.size())
	var seen: Array = []
	var has_duplicate := false
	for role_variant in fixed_team:
		var role_id := str(role_variant)
		if seen.has(role_id):
			has_duplicate = true
		seen.append(role_id)
	_expect(not has_duplicate, "非法 team_order 归一化后不允许重复角色。")


func _check_swap_validation() -> void:
	var profile := {
		"team_order": ["swordsman", "gunner", "mage"],
		"unlocked_role_ids": ["swordsman", "gunner", "mage", "mechanic"]
	}
	_expect(TEAM_SWAP_PANEL.get_candidates(profile) == ["mechanic"], "候补列表应只包含未上场的已解锁角色 mechanic。")
	_expect(TEAM_SWAP_PANEL.get_candidates({"team_order": ["swordsman", "gunner", "mage"], "unlocked_role_ids": ["swordsman", "gunner", "mage"]}).is_empty(), "无候补时应返回空列表。")

	var team: Array = profile["team_order"]
	var unlocked: Array = profile["unlocked_role_ids"]
	var ok := TEAM_SWAP_PANEL.build_swapped_team(team, "mage", "mechanic", unlocked)
	_expect(bool(ok.get("success", false)), "合法替换应成功。")
	_expect(ok.get("team_order", []) == ["swordsman", "gunner", "mechanic"], "替换应保持槽位顺序，mage 位换成 mechanic。")
	_expect((ok.get("team_order", []) as Array).size() == 3, "替换后队伍必须恒为 3 人。")

	var missing_pick := TEAM_SWAP_PANEL.build_swapped_team(team, "", "mechanic", unlocked)
	_expect(not bool(missing_pick.get("success", false)) and str(missing_pick.get("error", "")) == TEAM_SWAP_PANEL.TEXT_NEED_BOTH, "未选齐候补与队员时必须拒绝并提示。")
	var locked := TEAM_SWAP_PANEL.build_swapped_team(team, "mage", "ghost", ["swordsman", "gunner", "mage"])
	_expect(not bool(locked.get("success", false)) and str(locked.get("error", "")) == TEAM_SWAP_PANEL.TEXT_NOT_UNLOCKED, "未解锁角色必须拒绝。")
	var duplicate := TEAM_SWAP_PANEL.build_swapped_team(team, "mage", "gunner", unlocked)
	_expect(not bool(duplicate.get("success", false)) and str(duplicate.get("error", "")) == TEAM_SWAP_PANEL.TEXT_ALREADY_IN_TEAM, "已在队伍中的角色必须拒绝。")
	var outsider := TEAM_SWAP_PANEL.build_swapped_team(team, "mechanic", "gunner", unlocked)
	_expect(not bool(outsider.get("success", false)) and str(outsider.get("error", "")) == TEAM_SWAP_PANEL.TEXT_OUTSIDE_TEAM, "替换目标不在队伍时必须拒绝。")

	_expect(not bool(TEAM_SWAP_PANEL.validate_team(["swordsman", "gunner"]).get("valid", true)), "2 人队伍必须判定非法。")
	_expect(not bool(TEAM_SWAP_PANEL.validate_team(["swordsman", "gunner", "mage", "mechanic"]).get("valid", true)), "4 人队伍必须判定非法。")
	_expect(not bool(TEAM_SWAP_PANEL.validate_team(["swordsman", "swordsman", "mage"]).get("valid", true)), "重复角色队伍必须判定非法。")
	_expect(not bool(TEAM_SWAP_PANEL.validate_team(["swordsman", "ghost", "mage"]).get("valid", true)), "未知角色队伍必须判定非法。")
	_expect(bool(TEAM_SWAP_PANEL.validate_team(["swordsman", "gunner", "mechanic"]).get("valid", false)), "3 人不重复队伍必须判定合法。")


func _check_panel_ui() -> void:
	var panel := TEAM_SWAP_PANEL_SCENE.instantiate()
	root.add_child(panel)
	await process_frame
	_expect(not panel.visible, "换人面板初始应保持隐藏。")

	var swap_events: Array = []
	panel.team_changed.connect(func(new_team: Array) -> void: swap_events.append(new_team))
	var close_events: Array = []
	panel.closed.connect(func() -> void: close_events.append(true))

	panel.set("mode", "test")
	panel.call("_open_with_profile", {
		"team_order": ["swordsman", "gunner", "mage"],
		"unlocked_role_ids": ["swordsman", "gunner", "mage", "mechanic"]
	})
	await process_frame
	_expect(panel.visible, "换人面板打开后应可见。")
	var team_list := panel.get("team_list") as VBoxContainer
	var candidate_list := panel.get("candidate_list") as VBoxContainer
	var candidate_empty := panel.get("candidate_empty_label") as Label
	var feedback := panel.get("feedback_label") as Label
	var swap_button := panel.get("swap_button") as Button
	_expect(team_list != null and team_list.get_child_count() == 3, "左侧应显示当前队伍 3 人。")
	_expect(candidate_list != null and candidate_list.get_child_count() == 1, "右侧应显示 1 名候补 mechanic。")
	_expect(candidate_empty != null and not candidate_empty.visible, "有候补时不应显示空状态教学。")
	_expect(swap_button != null and swap_button.disabled, "未选齐时替换按钮必须禁用。")

	panel.call("_on_candidate_entry_pressed", "mechanic")
	_expect(swap_button.disabled, "只选候补时替换按钮必须禁用。")
	panel.call("_on_swap_pressed")
	_expect(feedback.text == TEAM_SWAP_PANEL.TEXT_NEED_BOTH, "未选队员时替换必须拒绝并提示。")
	_expect((panel.get("profile") as Dictionary).get("team_order", []) == ["swordsman", "gunner", "mage"], "非法操作不得改动 team_order。")

	panel.call("_on_team_entry_pressed", "mage")
	_expect(not swap_button.disabled, "选齐候补与队员后替换按钮应可用。")
	panel.call("_on_swap_pressed")
	var new_team: Array = (panel.get("profile") as Dictionary).get("team_order", [])
	_expect(new_team == ["swordsman", "gunner", "mechanic"], "确认替换后 team_order 应更新。")
	_expect(new_team.size() == 3, "确认替换后队伍必须恒为 3 人。")
	_expect(feedback.text.contains("下一局战斗生效"), "替换成功后必须提示下一局战斗生效。")
	_expect(swap_events.size() == 1 and swap_events[0] == ["swordsman", "gunner", "mechanic"], "team_changed 信号应携带新阵容。")
	_expect(candidate_list.get_child_count() == 1, "替换后被换下的 mage 应进入候补列表。")
	_expect(not candidate_empty.visible, "仍有候补时不应显示空状态教学。")

	panel.call("_open_with_profile", {
		"team_order": ["swordsman", "gunner", "mage"],
		"unlocked_role_ids": ["swordsman", "gunner", "mage"]
	})
	await process_frame
	_expect(candidate_list.get_child_count() == 0, "无候补时候补列表应为空。")
	_expect(candidate_empty.visible and candidate_empty.text.contains("roster"), "无候补时必须显示 roster 扩充教学。")

	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	panel.call("_unhandled_input", escape_event)
	_expect(not panel.visible, "Esc 必须关闭换人面板。")
	_expect(close_events.size() == 1, "Esc 关闭必须发出 closed 信号。")

	panel.queue_free()
	await process_frame


func _check_camp_wiring() -> void:
	var camp_scene := load("res://scenes/endless_camp.tscn") as PackedScene
	if camp_scene == null:
		failures.append("无法加载无尽营地场景。")
		return
	var camp := camp_scene.instantiate()
	root.add_child(camp)
	await process_frame
	var station := camp.get_node_or_null("PrepStation/Interactable")
	_expect(station != null, "无尽营地缺少整备台交互点。")
	if station != null:
		_expect(str(station.get("interaction_kind")) == "team_swap", "整备台 interaction_kind 应为 team_swap。")
		_expect(str(station.get("display_name")) == "整备台", "整备台应显示中文名称。")
	var panel := camp.get_node_or_null("CanvasLayer/TeamSwapPanel") as Control
	_expect(panel != null, "无尽营地缺少换人面板实例。")
	var player := camp.get_node_or_null("CampPlayer")
	if station != null and panel != null and player != null:
		camp.call("_on_interactable_interacted", station)
		_expect(panel.visible, "整备台交互必须打开换人面板。")
		_expect(not player.is_physics_processing(), "换人面板打开时必须锁定营地移动。")
		var escape_event := InputEventKey.new()
		escape_event.keycode = KEY_ESCAPE
		escape_event.pressed = true
		camp.call("_unhandled_input", escape_event)
		_expect(not panel.visible, "Esc 必须关闭营地换人面板。")
		_expect(player.is_physics_processing(), "关闭换人面板后必须恢复营地移动。")
	camp.queue_free()
	await process_frame
