extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ROLE_DATABASE := preload("res://scripts/player/roles/role_database.gd")
const SAVE_PROFILE_DEFAULTS := preload("res://scripts/save/save_profile_defaults.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")
const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_roster_and_defaults()
	await _check_team_build_and_combat()
	if failures.is_empty():
		print("MECHANIC_ROSTER_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_roster_and_defaults() -> void:
	var role_ids: Array = ROLE_DATABASE.get_role_ids()
	if role_ids.size() != 4:
		failures.append("roster should contain 4 roles, got %d" % role_ids.size())
	if not role_ids.has("mechanic"):
		failures.append("roster should contain mechanic")
	if ROLE_DATABASE.DEFAULT_TEAM_IDS != ["swordsman", "gunner", "mage"]:
		failures.append("default team should be swordsman/gunner/mage, got %s" % str(ROLE_DATABASE.DEFAULT_TEAM_IDS))
	var mechanic_data: Dictionary = ROLE_DATABASE.get_role_data_by_id("mechanic")
	if str(mechanic_data.get("name", "")) != "机械师":
		failures.append("mechanic role data should be named 机械师")
	if not is_equal_approx(float(mechanic_data.get("base_health", 0.0)), 120.0):
		failures.append("mechanic base health should be 120")

	var story_profile: Dictionary = SAVE_PROFILE_DEFAULTS.ensure_story_profile_defaults({}, 1)
	var story_team: Array = story_profile.get("team_order", [])
	var story_unlocked: Array = story_profile.get("unlocked_role_ids", [])
	if story_team.size() != 3 or story_team.has("mechanic"):
		failures.append("story default team should be 3 roles without mechanic, got %s" % str(story_team))
	if story_unlocked.size() != 4 or not story_unlocked.has("mechanic"):
		failures.append("story unlocked roles should be 4 including mechanic, got %s" % str(story_unlocked))

	var endless_profile: Dictionary = SAVE_PROFILE_DEFAULTS.ensure_endless_profile_defaults({}, 2)
	var endless_team: Array = endless_profile.get("team_order", [])
	if endless_team.size() != 3 or endless_team.has("mechanic"):
		failures.append("endless default team should be 3 roles without mechanic, got %s" % str(endless_team))
	var custom_endless: Dictionary = SAVE_PROFILE_DEFAULTS.ensure_endless_profile_defaults({"team_order": ["mechanic", "gunner", "mage", "swordsman"]}, 2)
	var custom_team: Array = custom_endless.get("team_order", [])
	if custom_team.size() != 3 or str(custom_team[0]) != "mechanic":
		failures.append("endless custom team should keep 3 roles led by mechanic, got %s" % str(custom_team))

	if PLAYER_BUILD_SYSTEM.ROLE_SLOT_COUNT != 3:
		failures.append("ROLE_SLOT_COUNT must stay 3, got %d" % PLAYER_BUILD_SYSTEM.ROLE_SLOT_COUNT)
	if PLAYER_BLESSING_SYSTEM.OFFER_COUNT != 4:
		failures.append("OFFER_COUNT must stay 4, got %d" % PLAYER_BLESSING_SYSTEM.OFFER_COUNT)
	if PLAYER_SKILL_TALENT_SYSTEM.LEVEL_TALENT_ROLE_OPTION_COUNT != 3:
		failures.append("LEVEL_TALENT_ROLE_OPTION_COUNT must stay 3")


func _check_team_build_and_combat() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene

	var player = PLAYER_SCENE.instantiate()
	scene.add_child(player)
	await process_frame

	var default_ids := _role_ids_of(player.roles)
	if default_ids != ["swordsman", "gunner", "mage"]:
		failures.append("player default team should be swordsman/gunner/mage, got %s" % str(default_ids))

	player.configure_story_loadout(["swordsman", "gunner", "mechanic"])
	var team_ids := _role_ids_of(player.roles)
	if team_ids != ["swordsman", "gunner", "mechanic"]:
		failures.append("configured team should be swordsman/gunner/mechanic, got %s" % str(team_ids))
	var talent_order: Array = PLAYER_SKILL_TALENT_SYSTEM.get_level_talent_role_order(player)
	if talent_order != ["swordsman", "gunner", "mechanic"]:
		failures.append("level talent role order should follow current team, got %s" % str(talent_order))

	player.active_role_index = 2
	player._update_active_role_state()
	if str(player._get_active_role().get("id", "")) != "mechanic":
		failures.append("active role should be mechanic after index 2")

	player._perform_mechanic_attack()

	for skill_id in ["drone", "mine", "emp_burst", "tulip_turret", "missile_volley"]:
		if not PLAYER_BLESSING_SKILL_STATE.force_unlock_skill(player, skill_id, 1):
			failures.append("failed to unlock mechanic skill %s" % skill_id)

	if not player.mechanic_drone_ability.can_trigger(player, "mechanic"):
		failures.append("drone should be triggerable for active mechanic")
	elif not player.mechanic_drone_ability.try_trigger(player):
		failures.append("drone try_trigger should succeed")
	elif player.mechanic_drone_ability.cooldown_remaining <= 0.0:
		failures.append("drone cooldown should be running after trigger")

	player.mechanic_mine_ability.cooldown_remaining = 0.0
	if not player.mechanic_mine_ability.try_trigger(player):
		failures.append("mine try_trigger should succeed")
	player.mechanic_emp_burst_ability.cooldown_remaining = 0.0
	if not player.mechanic_emp_burst_ability.try_trigger(player):
		failures.append("emp_burst try_trigger should succeed")
	player.mechanic_tulip_turret_ability.cooldown_remaining = 0.0
	if not player.mechanic_tulip_turret_ability.try_trigger(player):
		failures.append("tulip_turret try_trigger should succeed")
	player.mechanic_missile_volley_ability.cooldown_remaining = 0.0
	if not player.mechanic_missile_volley_ability.try_trigger(player):
		failures.append("missile_volley try_trigger should succeed")

	if player.mechanic_role.perform_enter(player, "mechanic", 0, 1.0) != 0:
		failures.append("mechanic enter skill should report 0 hits without enemies")
	if player.mechanic_tulip_turret_ability.active_turrets.is_empty():
		failures.append("enter skill should deploy a tulip turret")

	player.mechanic_role.update_trait_state(player, 4.5)
	if player.mechanic_role.get_parts_count(player) < 1:
		failures.append("battlefield改装 trait should produce at least 1 part after 4.5s active")

	player.mechanic_role.perform_ultimate(player, {})

	var save_data: Dictionary = player.get_save_data()
	var saved_ids := _role_ids_of(save_data.get("roles", []))
	if saved_ids != ["swordsman", "gunner", "mechanic"]:
		failures.append("saved roles should keep the mechanic team, got %s" % str(saved_ids))
	var ability_runtime: Dictionary = save_data.get("ability_runtime", {})
	for runtime_key in ["drone", "mine", "emp_burst", "tulip_turret", "missile_volley"]:
		if not ability_runtime.has(runtime_key):
			failures.append("ability_runtime should contain %s" % runtime_key)
	var special_states: Dictionary = save_data.get("role_special_states", {})
	if not special_states.has("mechanic"):
		failures.append("role_special_states should contain mechanic")

	var target = PLAYER_SCENE.instantiate()
	scene.add_child(target)
	await process_frame
	target.apply_save_data(save_data)
	var restored_ids := _role_ids_of(target.roles)
	if restored_ids != ["swordsman", "gunner", "mechanic"]:
		failures.append("loaded team should be swordsman/gunner/mechanic, got %s" % str(restored_ids))
	if target.mechanic_drone_ability == null or target.mechanic_drone_ability.cooldown_remaining <= 0.0:
		failures.append("loaded drone cooldown should survive the roundtrip")

	var legacy_save: Dictionary = save_data.duplicate(true)
	legacy_save["roles"] = player._serialize_roles_for_save().slice(0, 2)
	var normalized: Array = target._normalize_loaded_roles(legacy_save["roles"])
	if normalized.size() != 3:
		failures.append("legacy 2-role save should pad to the 3-role default team, got %d" % normalized.size())
	if _role_ids_of(normalized).has("mechanic"):
		failures.append("legacy default-team save should not gain mechanic")

	scene.queue_free()
	await process_frame
	current_scene = null


func _role_ids_of(roles: Array) -> Array:
	var ids: Array = []
	for role_variant in roles:
		if role_variant is Dictionary:
			ids.append(str((role_variant as Dictionary).get("id", "")))
	return ids
