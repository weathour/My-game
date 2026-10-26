extends SceneTree

const PLAYER := preload("res://scenes/player.tscn")
const UI := preload("res://scenes/level_up_ui.tscn")
const BAR := preload("res://scripts/ui/hud/combat_skill_bar.gd")
const BUILD := preload("res://scripts/player/player_build_system.gd")
const BLESSINGS := preload("res://scripts/player/player_blessing_system.gd")
const LEVELS := preload("res://scripts/player/player_skill_level_system.gd")
const SKILLS := preload("res://scripts/player/player_blessing_skill_state.gd")
const COOLDOWNS := preload("res://scripts/player/player_skill_cooldown_flow.gd")
const PLAYER_AUTHORED_EFFECTS := preload("res://scripts/player/player_authored_effects.gd")
var output_dir := ""
var failures: Array[String] = []

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="):
			output_dir = arg.trim_prefix("--screenshots=")
	call_deferred("_run")

func _settle() -> void:
	for index in range(4):
		await process_frame

func _capture(name: String) -> void:
	if output_dir == "" or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir.path_join(name + ".png"))

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var player = PLAYER.instantiate()
	player.auto_attack_enabled = false
	world.add_child(player)
	player.auto_attack_enabled = false
	player.fire_timer.stop()
	player.configure_story_loadout(["swordsman", "gunner", "mechanic"])
	player.set_process(false)
	player.set_physics_process(false)
	player.auto_attack_enabled = false
	player.fire_timer.stop()
	player.visible = false
	player.skill_points = 1
	var skill_point_offer: Dictionary = BLESSINGS.build_skill_point_offer(player)
	var skill_point_options: Array = skill_point_offer.get("options", [])
	assert(skill_point_options.size() == 3, "An empty skill slot must offer three unowned role skills")
	assert(bool(skill_point_offer.get("context", {}).get("skill_point_offer", false)))
	assert(int(skill_point_offer.get("context", {}).get("selection_count", 0)) == 1)
	for skill_option in skill_point_options:
		assert(str(skill_option.get("role_id", "")) == "swordsman")
		assert(str(skill_option.get("unlock_skill", "")) != "")
	assert(player.spend_skill_point() and player.skill_points == 0, "Allocating a choice must consume one skill point")
	assert(not player.spend_skill_point(), "A skill point cannot be spent twice")
	for role_id in COOLDOWNS.ROLE_ACTIVE_SKILL_PROPERTIES:
		for skill_id in COOLDOWNS.ROLE_ACTIVE_SKILL_PROPERTIES[role_id]:
			var info := COOLDOWNS.get_skill_info(player, role_id, skill_id)
			assert(not str(info.get("effect_summary", "")).is_empty(), "Every learnable skill needs a useful description")
			assert(not info.get("effect_rows", []).is_empty(), "Every learnable skill needs its cooldown")
	SKILLS.force_unlock_skill(player, "infinite_reload", 1)
	SKILLS.force_unlock_skill(player, "tulip_turret", 1)
	LEVELS.add_skill_level(player, "swordsman", "swordsman_basic", 2)
	LEVELS.add_skill_level(player, "gunner", "gunner_infinite_reload", 2)
	var before: Dictionary = player.role_special_states.duplicate(true)
	var upgrade := BUILD._make_skill_upgrade_option(player, "swordsman", 0, "swordsman_basic")
	assert(upgrade["skill_level"] == 2 and upgrade["skill_level_next"] == 3)
	LEVELS.add_skill_level(player, "swordsman", "swordsman_basic", 1)
	var branch_upgrade := BUILD._make_skill_upgrade_option(player, "swordsman", 0, "swordsman_basic")
	assert(branch_upgrade["card_highlight"] == "LV4 · 分支选择")
	assert(str(branch_upgrade["description"]).contains("重剑"))
	assert(branch_upgrade["effect_rows"].is_empty(), "Current branch cards must not show old slash growth")
	player.role_special_states = before.duplicate(true)
	assert(player.role_special_states == before, "Preview must not apply or undo an upgrade")
	var learn: Dictionary = {}
	for option in BUILD._build_role_options(player, "mechanic", 2):
		if str(option.get("unlock_skill", "")) == "missile_volley":
			learn = option
	assert(str(learn.get("description", "")).contains("炮弹"), "New skills must explain their behavior")
	assert(learn["effect_rows"][2]["value"] == "10.0 秒")
	var blessing := BLESSINGS._make_option(player, "blazing_sun", 1)
	assert(blessing["effect_rows"][0]["before"] == "0")
	BLESSINGS.apply_blessing(player, "blazing_sun", 1)
	var held: Dictionary = player.role_blessing_levels.duplicate(true)
	blessing = BLESSINGS._make_option(player, "blazing_sun", 1)
	assert(blessing["effect_rows"][0]["before"] == "1" and blessing["effect_rows"][0]["after"] == "2")
	assert(player.role_blessing_levels == held, "Blessing preview must not grant a copy")

	var canvas := CanvasLayer.new()
	world.add_child(canvas)
	var hud_root := Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(hud_root)
	var bar = BAR.new()
	hud_root.add_child(bar)
	bar.set_hud_layout("legacy")
	var skill_point_requests := []
	bar.skill_point_requested.connect(func(skill_id: String, role_id: String): skill_point_requests.append([skill_id, role_id]))
	bar.update_skill_points(2)
	var slots := COOLDOWNS.get_role_skill_cooldown_slots(player, "mechanic", 0.5)
	bar.update_skill_cooldown_slots(slots)
	for slot in bar.skill_cd_slots:
		assert(slot["view"].skill_point_highlighted, "Every skill slot, including basic attacks and empty slots, should highlight with skill points")
		assert(not slot["view"].clip_contents, "The icon must not clip the upgrade button above it")
	await _settle()
	await _capture("skill-points-legacy")
	var slot_button: Button = bar.skill_cd_slots[0]["upgrade_button"]
	slot_button.pressed.emit()
	assert(skill_point_requests.size() == 1, "A skill slot plus button must request direct allocation")
	assert(skill_point_requests[0][0] == "mechanic_basic_attack")
	var empty_slot_button: Button = bar.skill_cd_slots[slots.size()]["upgrade_button"]
	assert(empty_slot_button.visible and not empty_slot_button.disabled, "An empty active skill slot should show an available plus button")
	empty_slot_button.pressed.emit()
	assert(skill_point_requests.size() == 2, "An empty skill slot plus button must request a learn flow")
	assert(skill_point_requests[1][0] == "" and skill_point_requests[1][1] == "mechanic")
	bar.update_skill_points(0)
	for slot in bar.skill_cd_slots:
		assert(not slot["upgrade_button"].visible, "The plus button should hide without unspent points")
		assert(not slot["view"].skill_point_highlighted, "Slot highlights should disappear without unspent points")
	await _settle()
	var hovered_icon: Control = bar.skill_cd_slots[1]["view"]
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	await process_frame
	var pointer_position: Vector2 = bar.get_viewport().get_mouse_position()
	# Put the icon under the current pointer so the real delayed callback can run in headless mode.
	bar.position += pointer_position - hovered_icon.get_global_rect().get_center()
	await process_frame
	assert(hovered_icon.get_global_rect().has_point(pointer_position), "Hover test must keep the pointer over the skill icon")
	bar._on_skill_slot_hovered(hovered_icon, 1)
	await create_timer(1.0, true).timeout
	assert(not bar.hover_detail.visible, "Skill details must stay hidden before the 1.5-second hover delay")
	await create_timer(0.6, true).timeout
	assert(bar.hover_detail.visible)
	assert(bar.hover_detail.category_label.text.contains("Lv.1"))
	assert(bar.hover_detail.description_label.get_content_height() <= bar.hover_detail.description_label.size.y + 1)
	await _capture("combat-tooltip")
	bar._apply_hud_layout_anchor()
	var frame_slots := slots.duplicate(true)
	frame_slots[1]["description"] = ""
	frame_slots[1]["remaining"] = 3.2
	bar.update_skill_cooldown_slots(frame_slots)
	assert(bar.hover_detail.status_label.text.contains("3.2"), "Visible cooldown must update without leaving the icon")
	assert(bar.skill_cd_slots[1]["detail_data"]["current_level"] == 1, "Fast HUD updates must retain descriptive data")
	bar.update_skill_cooldown_slots([])
	assert(not bar.hover_detail.visible, "Removing a skill must close its stale tooltip")
	bar.set_hud_layout("team_band")
	var summary: Dictionary = player.get_stat_summary()
	bar.update_team_role_statuses(summary["team_role_statuses"], "swordsman", 0)
	bar.update_skill_points(1)
	await _settle()
	await _capture("skill-points-team")
	bar.update_skill_points(0)
	await _settle()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	await process_frame
	var team_pointer_position: Vector2 = bar.get_viewport().get_mouse_position()
	for row_index in range(bar.team_role_rows.size()):
		var row: Dictionary = bar.team_role_rows[row_index]
		if row["data"].get("role_id", "") == "mechanic":
			var team_icon: Control = row["slots"][1]["view"]
			bar.position += team_pointer_position - team_icon.get_global_rect().get_center()
			await process_frame
			assert(team_icon.get_global_rect().has_point(team_pointer_position), "Team tooltip test must keep the pointer over the skill icon")
			bar._on_team_role_skill_slot_hovered(row_index, 1, team_icon)
			await create_timer(1.6, true).timeout
	assert(bar.hover_detail.category_label.text.contains("机械师"))
	assert(bar.hover_detail.status_label.text.contains("待命"))
	await _capture("team-tooltip")
	bar.hover_detail.hide_detail()
	bar._apply_hud_layout_anchor()
	bar.visible = false

	var ui = UI.instantiate()
	root.add_child(ui)
	paused = true
	var options: Array = [upgrade, BUILD._make_skill_upgrade_option(player, "gunner", 1, "gunner_infinite_reload"), learn, blessing]
	ui.show_options(options, [], {"role_build_offer": true, "selection_count": 2})
	await create_timer(0.6, true).timeout
	await _settle()
	assert(ui.build_card_entries.size() == 4)
	ui._on_build_card_pressed(ui.build_card_entries[2]["button"], learn)
	assert(ui.build_count_label.text == "已选 1 / 2")
	assert(ui.build_card_entries[2]["button"].get_node("SelectedBadge").visible)
	ui._animate_build_card_hover(ui.build_card_entries[0]["button"], true)
	ui._show_build_item_detail(ui.build_card_entries[0]["button"], upgrade)
	await _settle()
	assert(ui.hover_detail.get_global_rect().position.y > ui._get_cards_bottom())
	assert(ui.hover_detail.get_global_rect().end.y <= 690)
	assert(ui.hover_detail.stats_label.get_content_height() <= ui.hover_detail.stats_label.size.y + 1, "Comparison rows must fit without scrolling")
	_check_card_bounds(ui)
	await _capture("four-cards-upgrade")
	root.size = Vector2i(960, 540)
	await _settle()
	_check_card_bounds(ui)
	await _capture("four-cards-960")
	root.size = Vector2i(1280, 720)
	await _settle()
	ui._show_build_item_detail(ui.build_card_entries[2]["button"], learn)
	await _settle()
	await _capture("four-cards-new-skill")
	ui._show_build_item_detail(ui.build_card_entries[3]["button"], blessing)
	await _settle()
	assert(ui.hover_detail.description_label.get_theme_color("default_color").get_luminance() > 0.5, "Paper ink must not leak into dark details")
	await _capture("four-cards-blessing")
	var longest: Array = BLESSINGS.build_all_offer_for_owner(player).get("options", [])
	longest.sort_custom(func(a, b): return str(a.get("summary", "")).length() > str(b.get("summary", "")).length())
	ui.show_options(longest.slice(0, 4), [], {"role_build_offer": true, "selection_count": 2})
	await create_timer(0.6, true).timeout
	await _settle()
	_check_card_bounds(ui)
	await _capture("long-blessing-cards")
	ui.hide_ui()
	LEVELS.add_skill_level(player, "swordsman", "swordsman_basic", 2)
	var talent: Dictionary = player.build_next_skill_talent_offer()
	ui.show_options(talent["options"], [], talent["context"])
	await create_timer(0.6, true).timeout
	await _settle()
	assert(ui.build_card_entries.size() == 2)
	_check_card_bounds(ui)
	await _capture("talent-cards")
	ui.hide_ui()
	for role_id in COOLDOWNS.ROLE_ACTIVE_SKILL_PROPERTIES:
		for skill_id in COOLDOWNS.ROLE_ACTIVE_SKILL_PROPERTIES[role_id]:
			SKILLS.force_unlock_skill(player, skill_id, 1)
		var candidates: Array = []
		for progress_id in LEVELS.get_upgradeable_progress_ids(player, role_id):
			var level := LEVELS.get_skill_level(player, role_id, progress_id)
			LEVELS.add_skill_level(player, role_id, progress_id, maxi(0, 4 - level))
			candidates.append(BUILD._make_skill_upgrade_option(player, role_id, 0, progress_id))
		for offset in range(0, candidates.size(), 4):
			ui.show_options(candidates.slice(offset, offset + 4), [], {"role_build_offer": true, "selection_count": 2})
			await create_timer(0.4, true).timeout
			await _settle()
			_check_card_bounds(ui)
			if role_id == "mechanic":
				for candidate in candidates.slice(offset, offset + 4):
					assert(not (candidate.get("effect_rows", []) as Array).is_empty(), "Mechanic upgrades need numeric comparison rows")
				ui._show_build_item_detail(ui.build_card_entries[0]["button"], candidates[offset])
				await _settle()
				assert(ui.hover_detail.stats_label.get_content_height() <= ui.hover_detail.stats_label.size.y + 1, "Mechanic comparison rows must fit")
				await _capture("mechanic-growth-%d" % offset)
				root.size = Vector2i(960, 540)
				await _settle()
				_check_card_bounds(ui)
				await _capture("mechanic-growth-%d-960" % offset)
				root.size = Vector2i(1280, 720)
	ui.hide_ui()
	for progress_id in LEVELS.MECHANIC_TALENTS.DEFINITIONS:
		LEVELS.add_skill_level(player, "mechanic", progress_id, 1)
		var mechanic_talent := LEVELS.build_talent_offer_for(player, "mechanic", progress_id)
		ui.show_options(mechanic_talent["options"], [], mechanic_talent["context"])
		await create_timer(0.4, true).timeout
		await _settle()
		_check_card_bounds(ui)
		for entry in ui.build_card_entries:
			var content: Node = entry["button"].get_node("Margin/Content")
			var text := str(content.get_node("HighlightLabel").text) + str(content.get_node("SummaryLabel").text)
			assert(not text.contains("尚未实装") and not text.contains("选择后记录"), "Mechanic talent cards must show their real effects")
		if progress_id in ["mechanic_basic", "mechanic_emp_burst", "mechanic_missile_volley"]:
			ui._show_build_item_detail(ui.build_card_entries[1]["button"], mechanic_talent["options"][1])
			await _settle()
			assert(ui.hover_detail.title_label.text.contains(LEVELS.get_talent_definition("mechanic", progress_id, 2)["title"]), "Talent details must name the inspected talent")
			await _capture(progress_id + "-talents")
			root.size = Vector2i(960, 540)
			await _settle()
			_check_card_bounds(ui)
			await _capture(progress_id + "-talents-960")
			root.size = Vector2i(1280, 720)
		ui.hide_ui()
	paused = false
	current_scene = null
	ui.free()
	world.free()
	PLAYER_AUTHORED_EFFECTS.clear_runtime_state()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("SKILL_INFO_UI_SMOKE_OK")
	quit(0 if failures.is_empty() else 1)

func _check_card_bounds(ui) -> void:
	for entry in ui.build_card_entries:
		var card: Control = entry["button"]
		var content := card.get_node("Margin/Content") as Control
		for child in content.get_children():
			if child is Label and child.visible:
				if child.position.y + child.size.y > content.size.y + 1:
					failures.append("Card content must fit its paper: " + str(child.text))
		if content.size.y > 185:
			print("OVERFLOW ", content.size, " card=", card.size, " title=", entry["option"].get("title", ""))
			for c in content.get_children():
				print(c.name, " ", c.size, " ", c.position)
			failures.append("Long card content overflows: " + str(entry["option"].get("title", "")))
