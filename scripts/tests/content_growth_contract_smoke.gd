extends SceneTree

const PLAYER := preload("res://scenes/player.tscn")
const SKILLS := preload("res://scripts/player/player_blessing_skill_state.gd")
const LEVELS := preload("res://scripts/player/player_skill_level_system.gd")
const EFFECTS := preload("res://scripts/player/player_skill_level_effect_flow.gd")
const BUILDS := preload("res://scripts/player/player_build_system.gd")
const TALENTS := preload("res://scripts/player/player_skill_talent_system.gd")
const COOLDOWNS := preload("res://scripts/player/player_skill_cooldown_flow.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var player = PLAYER.instantiate()
	scene.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.fire_timer.stop()
	_check_skill_identities(player)
	_check_fireball(player)
	_check_current_and_legacy_growth(player)
	scene.queue_free()
	await process_frame
	print("CONTENT_GROWTH_CONTRACT_SMOKE_OK")
	quit(0)

func _check_skill_identities(player) -> void:
	var registered: Array = []
	for role_id in COOLDOWNS.ROLE_ACTIVE_SKILL_PROPERTIES:
		for skill_id in COOLDOWNS.ROLE_ACTIVE_SKILL_PROPERTIES[role_id]:
			assert(not registered.has(skill_id), "active skills have unique owners")
			registered.append(skill_id)
			assert(SKILLS.get_skill_role_id(skill_id) == role_id, "unlock and HUD ownership agree")
			assert(SKILLS.SKILL_TITLES.has(skill_id), "save normalization recognizes every active skill")
			assert(SKILLS.ACTIVE_SLOT_SKILL_IDS.has(skill_id), "registered skills participate in the slot contract")
			var progress_id := str(LEVELS.UNLOCKABLE_PROGRESS.find_key(skill_id))
			assert(LEVELS.ROLE_PROGRESS_ORDER[role_id].has(progress_id), "every active skill has a current growth line")
			assert(TALENTS.get_display_for_skill_id(player, skill_id).progress_id == progress_id, "display derives the same progress ID")
			var ability: Variant = player.get(COOLDOWNS.ROLE_ACTIVE_SKILL_PROPERTIES[role_id][skill_id])
			assert(ability != null and ability.has_method("try_trigger") and ability.has_method("get_save_data") and ability.has_method("apply_save_data"))
	assert(registered.size() == SKILLS.ACTIVE_SLOT_SKILL_IDS.size(), "no authored active skill is missing from the HUD/dispatch table")
	var expected_cooldowns := {}
	for skill_id in registered:
		var role_id := SKILLS.get_skill_role_id(skill_id)
		var ability: Variant = player.get(COOLDOWNS.ROLE_ACTIVE_SKILL_PROPERTIES[role_id][skill_id])
		ability.cooldown_remaining = 0.5 + 0.05 * expected_cooldowns.size()
		expected_cooldowns[skill_id] = ability.cooldown_remaining
	var saved: Dictionary = player.get_save_data()
	for skill_id in registered:
		assert(saved.ability_runtime.has(skill_id), "%s has a run-save entry" % skill_id)
		player.get(COOLDOWNS.ROLE_ACTIVE_SKILL_PROPERTIES[SKILLS.get_skill_role_id(skill_id)][skill_id]).cooldown_remaining = 0.0
	player.apply_save_data(saved)
	for skill_id in registered:
		var ability: Variant = player.get(COOLDOWNS.ROLE_ACTIVE_SKILL_PROPERTIES[SKILLS.get_skill_role_id(skill_id)][skill_id])
		assert(is_equal_approx(ability.cooldown_remaining, float(expected_cooldowns[skill_id])), "%s cooldown survives a real player roundtrip" % skill_id)

func _check_fireball(player) -> void:
	assert(SKILLS.force_unlock_skill(player, "fireball", 1))
	var ability = player.mage_fireball_ability
	for row in [[1, 6.0, 0.01, 6.0], [5, 6.8, 0.03, 7.0], [10, 7.8, 0.055, 9.0]]:
		player.role_special_states["mage"] = {"skill_levels": {"mage_fireball": row[0]}}
		assert(is_equal_approx(ability._get_blast_damage_ratio(player), row[1]), "fireball keeps authored damage")
		assert(is_equal_approx(ability._get_ground_burn_ratio(player), row[2]), "fireball keeps authored burn")
		assert(is_equal_approx(ability._get_ground_duration(player), row[3]), "fireball keeps authored duration")
		_assert_fireball_rows(player)
		var preview := EFFECTS.get_upgrade_preview_text(player, "mage", "mage_fireball")
		if row[0] == 10:
			assert(preview == "", "max level has no next upgrade")
		else:
			assert(preview.contains("伤害倍率 +%.0f%%" % (EFFECTS.FIREBALL_DAMAGE_RATIO_PER_LEVEL * 100.0)))
			assert(preview.contains("灼烧倍率 +%.1f%%" % (EFFECTS.FIREBALL_BURN_RATIO_PER_LEVEL * 100.0)))
		for talent in ["mage_level_talent_fireball_1", "mage_level_talent_fireball_2"]:
			player.role_special_states["mage"]["level_talents"] = [talent]
			_assert_fireball_rows(player)
			assert(TALENTS.get_selected_level_talents(player, "mage").has(talent), "saved role talents retain their independent display/query path")
			assert(TALENTS.has_level_talent(player, talent), "saved role talent runtime effects remain active")
			if talent.ends_with("_1"):
				assert(is_equal_approx(ability._get_blast_damage_ratio(player), float(row[1]) + 1.5))
				assert(is_equal_approx(ability._get_blast_radius(player), 275.0))
			else:
				assert(ability.get_cooldown_slot(player).effect_note.contains("8 处、每处 200%"))
	player.role_special_states["mage"] = {"skill_levels": {"mage_fireball": 2}}
	assert(EFFECTS.get_upgrade_preview_text(player, "mage", "mage_fireball").contains("灼烧地面持续时间 +%.0fs" % EFFECTS.FIREBALL_GROUND_DURATION_PER_MILESTONE))

func _assert_fireball_rows(player) -> void:
	var ability = player.mage_fireball_ability
	var info := COOLDOWNS.get_skill_info(player, "mage", "fireball")
	var rows := {}
	for row in info.effect_rows:
		rows[row.label] = row.value
	assert(rows["爆炸伤害倍率"] == "%.0f%%" % (ability._get_blast_damage_ratio(player) * 100.0))
	assert(rows["爆炸半径"] == "%.0f" % ability._get_blast_radius(player))
	assert(rows["灼烧持续时间"] == "%.1f 秒" % ability._get_ground_duration(player))
	assert(rows["每秒灼烧"] == "当前生命 %.1f%%" % (ability._get_ground_burn_ratio(player) * 100.0))

func _check_current_and_legacy_growth(player) -> void:
	for role_id in ["swordsman", "gunner", "mage", "mechanic"]:
		for option in BUILDS._build_role_options(player, role_id, 0):
			assert(str(option.get("unlock_skill", "")) != "" or str(option.get("build_id", "")).begins_with(BUILDS.SKILL_UPGRADE_BUILD_PREFIX), "current offers exclude legacy stat cards")
		for progress_id in LEVELS.get_role_progress_ids(role_id):
			assert(TALENTS.get_display(player, role_id, progress_id).stages.is_empty(), "inactive 108-node choices are absent from current projection")
	player.configure_story_loadout(["mechanic", "gunner", "mage"])
	player.role_special_states["mechanic"] = {"build_levels": {"turret_damage": 2, "turret_duration": 3}, "skill_talents": {"mechanic_basic": "old_node"}}
	var damage: float = player.mechanic_tulip_turret_ability._get_damage_ratio(player)
	var duration: float = player.mechanic_tulip_turret_ability._get_duration(player)
	var saved: Dictionary = player.get_save_data()
	assert(saved.role_special_states.mechanic.build_levels == {"turret_damage": 2, "turret_duration": 3}, "normalization preserves legacy build values")
	assert(saved.role_special_states.mechanic.skill_talents.is_empty(), "disabled nodes remain cleared")
	player.role_special_states.clear()
	player.apply_save_data(saved)
	assert(is_equal_approx(BUILDS.get_mechanic_turret_damage_multiplier(player), 1.4))
	assert(is_equal_approx(player.mechanic_tulip_turret_ability._get_damage_ratio(player), damage), "legacy damage survives a real player save roundtrip")
	assert(is_equal_approx(player.mechanic_tulip_turret_ability._get_duration(player), duration), "legacy duration survives a real player save roundtrip")
	assert(not TALENTS.has_talent(player, "old_node"), "old nodes never become runtime effects")
	for option in player.build_skill_point_offer().options:
		assert(str(option.get("unlock_skill", "")) != "", "skill points award only current unlocks")
