extends SceneTree

const BuildSystem := preload("res://scripts/build/build_system.gd")
const RoleAttributeRules := preload("res://scripts/player/roles/role_attribute_rules.gd")
const MainMenu := preload("res://scripts/main_menu.gd")
const SettingsPanel := preload("res://scripts/ui/main_menu/main_menu_settings_panel.gd")
const LevelUpUI := preload("res://scripts/level_up_ui.gd")
const CombatSkillBar := preload("res://scripts/ui/hud/combat_skill_bar.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_build_theme_contract()
	await _check_settings_panel_layout()
	await _check_level_up_hover_contract()
	await _check_combat_skill_bar_contract()
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
	if not BuildSystem.has_independent_skill_cooldown("battle_blood_reflux"):
		failures.append("battle_blood_reflux should remain an independent cooldown passive")
	if not is_equal_approx(RoleAttributeRules.COMMON_PROSPERITY_SWITCH_COOLDOWN_FACTOR, 0.9):
		failures.append("common prosperity cooldown factor should be 0.9")

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
		}
	]
	ui.show_options(options, attrs)
	if ui.modal == null or ui.card_list == null or ui.hover_detail == null:
		failures.append("level up ui missing modal/card list/hover detail")
	elif ui.card_list.scroll_area.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_SHOW_ALWAYS:
		failures.append("level up card list scrollbar should always be visible")
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
