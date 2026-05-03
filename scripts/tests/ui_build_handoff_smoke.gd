extends SceneTree

const BuildSystem := preload("res://scripts/build/build_system.gd")
const RoleAttributeRules := preload("res://scripts/player/roles/role_attribute_rules.gd")
const PlayerAttributeFlow := preload("res://scripts/player/player_attribute_flow.gd")
const PlayerLevelFlow := preload("res://scripts/player/player_level_flow.gd")
const MainMenu := preload("res://scripts/main_menu.gd")
const SettingsPanel := preload("res://scripts/ui/main_menu/main_menu_settings_panel.gd")
const LevelUpUI := preload("res://scripts/level_up_ui.gd")
const CombatSkillBar := preload("res://scripts/ui/hud/combat_skill_bar.gd")
const BuildSkillGraphModel := preload("res://scripts/build/build_skill_graph_model.gd")
const BuildSkillGraphPanel := preload("res://scripts/ui/build_graph/build_skill_graph_panel.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_build_theme_contract()
	_check_dynamic_team_trait_contract()
	await _check_settings_panel_layout()
	await _check_level_up_hover_contract()
	await _check_combat_skill_bar_contract()
	await _check_build_skill_graph_contract()
	if failures.is_empty():
		print("UI_BUILD_HANDOFF_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_build_theme_contract() -> void:
	var initial_themes: Array = BuildSystem.get_unlocked_theme_ids({}, {})
	if initial_themes != ["theme_threefold_tide"]:
		failures.append("initial theme set mismatch: %s" % str(initial_themes))

	var branch_levels := {
		"battle_dangzhen_qichao": 2,
		"battle_dangzhen_dielang": 1
	}
	if not BuildSystem.is_theme_unlocked(branch_levels, {}, "branch_omni_edge"):
		failures.append("branch_omni_edge should unlock from 起潮2 + 叠浪1")
	var branch_pool: Array = BuildSystem.get_upgrade_pool("body", branch_levels, {}, "mage")
	var branch_ids: Array[String] = []
	for option in branch_pool:
		if option is Dictionary:
			branch_ids.append(str((option as Dictionary).get("id", "")))
	if not branch_ids.has("battle_omni_pierce"):
		failures.append("unlocked branch pool missing battle_omni_pierce: %s" % str(branch_ids))

	var mage_config: Dictionary = BuildSystem.get_core_card_config("battle_omni_pierce", "mage")
	if str(mage_config.get("title", "")) != "火雷贯链":
		failures.append("role-specific card title not applied for mage: %s" % str(mage_config.get("title", "")))
	var role_effects: Array = mage_config.get("role_effects", [])
	if role_effects.size() != 3:
		failures.append("role effect payload should include three hero effects")
	var two_role_effects: Array = BuildSystem.get_role_effect_payload("battle_omni_pierce", ["mage", "swordsman"])
	if two_role_effects.size() != 2 or str(two_role_effects[0].get("role_id", "")) != "mage" or str(two_role_effects[1].get("role_id", "")) != "swordsman":
		failures.append("role effect payload should follow current team order: %s" % str(two_role_effects))
	if not BuildSystem.has_independent_skill_cooldown("battle_blood_reflux"):
		failures.append("battle_blood_reflux should remain an independent cooldown passive")
	if not is_equal_approx(RoleAttributeRules.COMMON_PROSPERITY_SWITCH_COOLDOWN_FACTOR, 0.9):
		failures.append("common prosperity cooldown factor should be 0.9")


func _check_dynamic_team_trait_contract() -> void:
	var owner := _TraitOwnerStub.new()
	owner.roles = [
		{"id": "mage", "name": "术师", "trait_key": "mage_trait", "trait_option_id": "level_trait_mage", "trait_name": "术师特性"},
		{"id": "swordsman", "name": "剑士", "trait_key": "swordsman_trait", "trait_option_id": "level_trait_swordsman", "trait_name": "剑士特性"}
	]
	owner.attribute_training_levels = PlayerAttributeFlow.normalize_attribute_training_data({})
	var options: Array = PlayerLevelFlow.get_attribute_upgrade_options(owner)
	var ids: Array[String] = []
	for option in options:
		if option is Dictionary:
			ids.append(str((option as Dictionary).get("id", "")))
	if ids != ["level_trait_mage", "level_trait_swordsman", "level_trait_team"]:
		failures.append("trait upgrade options should follow selected team, got %s" % str(ids))
	PlayerLevelFlow.apply_attribute_upgrade(owner, "level_trait_mage")
	if not is_equal_approx(float(owner.attribute_training_levels.get("mage_trait", 0.0)), 1.0):
		failures.append("mage trait option did not increase mage_trait: %s" % str(owner.attribute_training_levels))
	PlayerLevelFlow.apply_attribute_upgrade(owner, "level_trait_team")
	if not is_equal_approx(float(owner.attribute_training_levels.get("mage_trait", 0.0)), 1.35):
		failures.append("team trait should increase selected mage trait by common prosperity gain")
	if not is_equal_approx(float(owner.attribute_training_levels.get("swordsman_trait", 0.0)), 0.35):
		failures.append("team trait should increase selected swordsman trait by common prosperity gain")
	if not is_equal_approx(float(owner.attribute_training_levels.get("gunner_trait", 0.0)), 0.0):
		failures.append("team trait should not increase unselected gunner trait: %s" % str(owner.attribute_training_levels))
	var mage_description := RoleAttributeRules.get_role_attribute_description("mage", "mage_trait", 6.0)
	if not mage_description.contains("入场轰炸") or not mage_description.contains("离场"):
		failures.append("mage trait description should include entry/exit bonuses: %s" % mage_description)
	var gunner_levels := PlayerAttributeFlow.normalize_attribute_training_data({"gunner_trait": 6.0})
	owner.attribute_training_levels = gunner_levels
	if PlayerAttributeFlow.get_gunner_entry_wave_count(owner) != 3:
		failures.append("gunner trait level 6 should add a third entry wave")
	var mage_levels := PlayerAttributeFlow.normalize_attribute_training_data({"mage_trait": 6.0})
	owner.attribute_training_levels = mage_levels
	if PlayerAttributeFlow.get_mage_entry_bombard_count(owner) != 3:
		failures.append("mage trait level 6 should add a third entry bombardment")
	if PlayerAttributeFlow.get_mage_exit_energy_bonus(owner) <= 0.0:
		failures.append("mage trait should grant exit energy bonus")
	var swordsman_levels := PlayerAttributeFlow.normalize_attribute_training_data({"swordsman_trait": 4.0})
	owner.attribute_training_levels = swordsman_levels
	if PlayerAttributeFlow.get_swordsman_exit_lifesteal_bonus(owner) <= 0.0:
		failures.append("swordsman trait should grant exit lifesteal bonus")

func _check_settings_panel_layout() -> void:
	var settings := SettingsPanel.new()
	root.add_child(settings)
	await process_frame
	settings.open()
	await process_frame
	var viewport_size := root.get_viewport().get_visible_rect().size
	_assert_overlay_rect(settings, viewport_size, "direct settings overlay")
	_assert_modal_centered(settings, viewport_size, "direct settings modal")
	settings.queue_free()
	await process_frame

	var menu := MainMenu.new()
	root.add_child(menu)
	await process_frame
	menu._on_settings_pressed()
	await process_frame
	if menu.settings_panel == null:
		failures.append("main menu settings_panel missing")
	else:
		if not menu.settings_panel.visible:
			failures.append("main menu settings panel not visible after settings click")
		_assert_overlay_rect(menu.settings_panel, viewport_size, "main menu settings overlay")
		_assert_modal_centered(menu.settings_panel, viewport_size, "main menu settings modal")
	menu.queue_free()
	await process_frame

func _check_level_up_hover_contract() -> void:
	var ui := LevelUpUI.new()
	root.add_child(ui)
	await process_frame
	var attrs := [
		{"id": "level_trait_swordsman", "title": "剑士特性", "description": "剑士特性 +1"},
		{"id": "level_trait_team", "title": "共同致富", "description": "三名英雄特性都 +0.35"}
	]
	var role_effects := BuildSystem.get_role_effect_payload("battle_omni_pierce")
	var options := [
		{
			"id": "battle_omni_pierce",
			"slot": "body",
			"slot_label": "战斗",
			"title": "万向锋路｜火雷贯链 Lv.1",
			"preview_description": "解锁被动技能。",
			"detail_description": "卡牌详情。\n\n三英雄对应效果 / 数值\n已有一份。",
			"role_effects": role_effects
		},
		{
			"id": "ui_link_resonance",
			"slot": "combat",
			"slot_label": "联动共鸣",
			"title": "联动共鸣｜护火穿线 Lv.1",
			"preview_description": "入场与离场触发队伍联动。",
			"detail_description": "联动卡详情。",
			"role_effects": []
		},
		{
			"id": "ui_pivot_support",
			"slot": "skill",
			"slot_label": "转向补强",
			"title": "转向补强｜短阵支援 Lv.1",
			"preview_description": "允许当前路线中期转向。",
			"detail_description": "转向卡详情。",
			"role_effects": []
		}
	]
	ui.show_options(options, attrs)
	await process_frame
	if ui.modal == null or ui.card_list == null or ui.hover_detail == null:
		failures.append("level up ui missing modal/card list/hover detail")
	elif ui.card_list.scroll_area.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_SHOW_ALWAYS:
		failures.append("level up card list scrollbar should always be visible")
	var section_titles: Array[String] = []
	for child in ui.card_list.content.get_children():
		if child is Label:
			section_titles.append(str((child as Label).text))
	if section_titles.has("战斗") or section_titles.has("连携") or section_titles.has("大招"):
		failures.append("normal level-up Build choices should be a unified three-pick section, got %s" % str(section_titles))
	if not section_titles.has("祝福三选一"):
		failures.append("normal level-up blessing choices should expose unified section title, got %s" % str(section_titles))
	elif section_titles[0] != "祝福三选一":
		failures.append("blessing three-pick section should render first to avoid being hidden below traits, got %s" % str(section_titles))
	var expected_build_ids: Array[String] = ["battle_omni_pierce", "ui_link_resonance", "ui_pivot_support"]
	var rendered_build_ids := {}
	for entry in ui.card_list.button_entries:
		if entry is not Dictionary:
			continue
		var item: Dictionary = (entry as Dictionary).get("item", {})
		var item_id := str(item.get("id", ""))
		if expected_build_ids.has(item_id):
			rendered_build_ids[item_id] = true
	if rendered_build_ids.size() != expected_build_ids.size():
		failures.append("level up UI should render all three Build options, got %s" % str(rendered_build_ids.keys()))
	ui.card_list.scroll_area.scroll_vertical = 999
	ui.show_options(options, attrs)
	await process_frame
	if ui.card_list.scroll_area.scroll_vertical != 0:
		failures.append("level up card list should reset stale scroll after rebuild, got %d" % ui.card_list.scroll_area.scroll_vertical)
	ui.hover_detail.show_item(options[0], Vector2(360.0, 240.0), Rect2(Vector2(100.0, 100.0), Vector2(160.0, 80.0)))
	var detail_text := str(ui.hover_detail.description_label.text)
	if _count_occurrences(detail_text, "三英雄对应效果 / 数值") != 1:
		failures.append("hover detail should not duplicate role effects section: %s" % detail_text)
	if ui.hover_detail.size.x < 260.0 or ui.hover_detail.size.y < 132.0:
		failures.append("hover detail autosize below minimum: %s" % str(ui.hover_detail.size))
	ui.queue_free()
	await process_frame

func _check_combat_skill_bar_contract() -> void:
	var bar := CombatSkillBar.new()
	root.add_child(bar)
	await process_frame
	bar.update_skill_cooldown_slots([
		{"name": "普攻", "remaining": 0.2, "duration": 1.0, "description": "普攻说明"},
		{"name": "退潮", "remaining": 0.1, "duration": 0.65, "description": "独立冷却被动"}
	])
	var first_label := ""
	if bar.skill_cd_slots.size() > 0:
		first_label = str((bar.skill_cd_slots[0] as Dictionary).get("label").text)
	if first_label != "普攻":
		failures.append("skill slot label should show skill name, not cooldown text: %s" % first_label)
	bar.update_ultimate_energy(50.0, 100.0, {"name": "破锋连斩", "description": "剑士大招说明"})
	if bar.ultimate_energy_widget.skill_name != "破锋连斩":
		failures.append("ultimate widget should show current hero ultimate name")
	bar.queue_free()
	await process_frame

func _check_build_skill_graph_contract() -> void:
	var graph := BuildSkillGraphModel.build_graph()
	var nodes: Array = graph.get("nodes", [])
	var edges: Array = graph.get("edges", [])
	if nodes.size() < 35:
		failures.append("build skill graph should include all first-batch offer/mastery nodes, got %d" % nodes.size())
	if edges.is_empty():
		failures.append("build skill graph should include logic edges")
	var node_ids := {}
	var has_level_25_node := false
	for raw_node in nodes:
		if raw_node is not Dictionary:
			continue
		var node: Dictionary = raw_node
		node_ids[str(node.get("id", ""))] = true
		if int(node.get("team_level_min", 0)) >= 25:
			has_level_25_node = true
		if str(node.get("description", "")) == "":
			failures.append("build graph node should have hover description: %s" % str(node))
	if not has_level_25_node:
		failures.append("build skill graph should expose level-25 mastery nodes")
	var has_progression := false
	var has_investment := false
	var has_state_logic := false
	for raw_edge in edges:
		if raw_edge is not Dictionary:
			continue
		var edge: Dictionary = raw_edge
		if not node_ids.has(str(edge.get("from", ""))) or not node_ids.has(str(edge.get("to", ""))):
			failures.append("build graph edge references missing node: %s" % str(edge))
		match str(edge.get("type", "")):
			"progression":
				has_progression = true
			"investment":
				has_investment = true
			"state_logic":
				has_state_logic = true
	if not has_progression or not has_investment or not has_state_logic:
		failures.append("build graph should include progression/investment/state logic edges, got progression=%s investment=%s state=%s" % [has_progression, has_investment, has_state_logic])
	var panel := BuildSkillGraphPanel.new()
	root.add_child(panel)
	await process_frame
	panel.show_panel(false)
	await process_frame
	if not panel.visible:
		failures.append("build graph panel should open")
	if panel.graph_view == null or not panel.graph_view.has_method("set_graph"):
		failures.append("build graph panel missing graph view")
	elif panel.graph_view.has_method("get_node_count") and panel.graph_view.get_node_count() < nodes.size():
		failures.append("build graph view should cache/draw all nodes, got %d for %d nodes" % [panel.graph_view.get_node_count(), nodes.size()])
	elif panel.graph_view.has_method("set_only_edge_type"):
		if panel.graph_view.has_method("get_node_size") and panel.graph_view.get_node_size().x > 48.0:
			failures.append("build graph nodes should be compact glyph icons, got %s" % str(panel.graph_view.get_node_size()))
		if panel.graph_view.has_method("get_layer_row_count"):
			var row_count: int = panel.graph_view.get_layer_row_count()
			var layer_count: int = (graph.get("layers", []) as Array).size()
			if row_count != layer_count:
				failures.append("build graph should keep one visual row per layer, got rows=%d layers=%d" % [row_count, layer_count])
		if panel.graph_view.has_method("get_edge_view_mode") and panel.graph_view.get_edge_view_mode() != "overview":
			failures.append("build graph should default to overview route mode, got %s" % str(panel.graph_view.get_edge_view_mode()))
		if panel.graph_view.has_method("get_edge_counts"):
			var initial_counts: Dictionary = panel.graph_view.get_edge_counts()
			if int(initial_counts.get("visible", 0)) >= int(initial_counts.get("total", 0)):
				failures.append("build graph overview mode should reduce default line density: %s" % str(initial_counts))
		panel.graph_view.set_only_edge_type("investment")
		var visible_edges: Array = panel.graph_view.get_visible_edges()
		if visible_edges.is_empty():
			failures.append("build graph investment filter should leave visible edges")
		for raw_edge in visible_edges:
			if raw_edge is Dictionary and str((raw_edge as Dictionary).get("type", "")) != "investment":
				failures.append("build graph investment filter leaked edge: %s" % str(raw_edge))
				break
		panel.graph_view.show_all_edge_types()
		if panel.graph_view.get_visible_edges().size() <= visible_edges.size():
			failures.append("build graph show all should restore more edges than single-type filter")
		if panel.graph_view.has_method("set_search_text"):
			var matches: Array = panel.graph_view.set_search_text("剑士")
			if matches.is_empty():
				failures.append("build graph search should match swordsman nodes")
			elif panel.graph_view.has_method("focus_first_search_match"):
				if not panel.graph_view.focus_first_search_match():
					failures.append("build graph should focus first search match")
				elif panel.graph_view.has_method("get_locked_focus_id") and str(panel.graph_view.get_locked_focus_id()) == "":
					failures.append("build graph focus should lock a node")
				if panel.graph_view.has_method("get_edge_counts"):
					var focused_counts: Dictionary = panel.graph_view.get_edge_counts()
					if int(focused_counts.get("highlighted", 0)) <= 0:
						failures.append("build graph focused node should expose local relation count: %s" % str(focused_counts))
				if panel.graph_view.has_method("clear_locked_focus"):
					panel.graph_view.clear_locked_focus()
					if panel.graph_view.has_method("get_locked_focus_id") and str(panel.graph_view.get_locked_focus_id()) != "":
						failures.append("build graph clear focus should unlock node")
	else:
		failures.append("build graph view missing edge filter API")
	if panel.filter_buttons.is_empty():
		failures.append("build graph panel should expose relation filter buttons")
	if panel.route_buttons.is_empty():
		failures.append("build graph panel should expose route mode buttons")
	if panel.search_box == null:
		failures.append("build graph panel should expose search box")
	panel.hide_panel()
	await process_frame
	if panel.visible:
		failures.append("build graph panel should close")
	panel.queue_free()
	await process_frame

func _assert_overlay_rect(control: Control, viewport_size: Vector2, label: String) -> void:
	var rect := control.get_global_rect()
	if rect.position.distance_to(Vector2.ZERO) > 1.0:
		failures.append("%s position is not full-screen origin: %s" % [label, rect.position])
	if absf(rect.size.x - viewport_size.x) > 1.0 or absf(rect.size.y - viewport_size.y) > 1.0:
		failures.append("%s size is not viewport-sized: %s vs %s" % [label, rect.size, viewport_size])

func _assert_modal_centered(settings: Control, viewport_size: Vector2, label: String) -> void:
	var modal := settings.get("modal") as Control
	if modal == null:
		failures.append("%s missing modal")
		return
	var panel := modal.get("panel") as Control
	if panel == null:
		failures.append("%s missing modal panel")
		return
	var expected_position := ((viewport_size - panel.size) * 0.5).max(Vector2.ZERO).floor()
	if panel.position.distance_to(expected_position) > 2.0:
		failures.append("%s not centered: pos=%s expected=%s" % [label, panel.position, expected_position])
	if panel.position.x <= 4.0 or panel.position.y <= 4.0:
		failures.append("%s still appears near corner: pos=%s" % [label, panel.position])

func _count_occurrences(text: String, needle: String) -> int:
	var count := 0
	var offset := 0
	while true:
		var index := text.find(needle, offset)
		if index < 0:
			return count
		count += 1
		offset = index + needle.length()
	return count


class _TraitOwnerStub:
	var roles: Array = []
	var attribute_training_levels: Dictionary = {}
	var stats_changed := _SignalStub.new()
	var health_changed := _SignalStub.new()
	var current_health := 100.0
	var max_health := 100.0

	func _sync_swordsman_trait_health_bonus() -> void:
		pass

	func _get_max_attribute_level() -> float:
		return RoleAttributeRules.MAX_ATTRIBUTE_LEVEL

	func _get_attribute_level(attribute_key: String) -> float:
		return PlayerAttributeFlow.get_attribute_level(self, attribute_key)

	func _get_role_attribute_description(role_id: String, attribute_key: String, next_level: float) -> String:
		return RoleAttributeRules.get_role_attribute_description(role_id, attribute_key, next_level)

	func _get_balanced_attribute_description(added_amount: float) -> String:
		return PlayerAttributeFlow.get_balanced_attribute_description(self, added_amount)

	func _is_attribute_evolved(level: float) -> bool:
		return RoleAttributeRules.is_attribute_evolved(level)

	func _get_attribute_evolved_title_color() -> Color:
		return RoleAttributeRules.EVOLVED_TITLE_COLOR

	func _add_common_prosperity() -> Dictionary:
		return PlayerAttributeFlow.add_common_prosperity(self)

	func _add_attribute_levels(deltas: Dictionary) -> Dictionary:
		return PlayerAttributeFlow.add_attribute_levels(self, deltas)

	func _update_fire_timer() -> void:
		pass

	func get_stat_summary() -> Dictionary:
		return {}


class _SignalStub:
	func emit(_a = null, _b = null, _c = null, _d = null) -> void:
		pass
