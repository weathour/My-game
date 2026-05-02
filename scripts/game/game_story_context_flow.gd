extends RefCounted

const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const ENEMY_DIRECTOR := preload("res://scripts/enemy/enemy_director.gd")
const DIFFICULTY_PROFILE := preload("res://scripts/game/difficulty_profile.gd")

# Handoff note:
# This flow owns the story/endless context consumed by battle spawning and stage
# rewards. Keep main.gd as the caller/holder of current scene state, but add new
# story/endless derivation rules here instead of scattering SAVE_MANAGER and
# ENEMY_DIRECTOR calls across the combat scene.

static func load_story_stage_context(main: Node) -> void:
	main.story_stage = SAVE_MANAGER.get_current_story_stage()
	main.story_mode_active = not main.story_stage.is_empty()
	main.endless_mode_active = not main.story_mode_active and SAVE_MANAGER.is_endless_mode_active()
	main.difficulty_profile = _load_difficulty_profile(main)
	main.difficulty_id = str(main.difficulty_profile.get("id", DIFFICULTY_PROFILE.DEFAULT_DIFFICULTY_ID))
	main.autosave_interval = float(main.difficulty_profile.get("autosave_interval", main.autosave_interval))

static func apply_story_loadout(main: Node) -> void:
	if not main.story_mode_active or main.player == null or not main.player.has_method("configure_story_loadout"):
		return
	var profile := SAVE_MANAGER.load_story_profile()
	main.player.configure_story_loadout(
		profile.get("team_order", ["swordsman", "gunner", "mage"]),
		profile.get("equipped_styles", {})
	)

static func get_effective_boss_spawn_time(main: Node) -> float:
	return ENEMY_DIRECTOR.get_effective_boss_spawn_time(
		main.story_stage,
		main.story_mode_active,
		main.endless_mode_active,
		main.defeated_boss_count
	)

static func get_effective_stage_curve_time(main: Node) -> float:
	return ENEMY_DIRECTOR.get_effective_stage_curve_time(main.story_stage, main.story_mode_active)

static func get_story_spawn_interval_multiplier(main: Node) -> float:
	return ENEMY_DIRECTOR.get_story_spawn_interval_multiplier(main.story_stage, main.story_mode_active)

static func get_story_enemy_health_multiplier(main: Node) -> float:
	return ENEMY_DIRECTOR.get_story_enemy_health_multiplier(main.story_stage, main.story_mode_active)

static func get_story_enemy_speed_multiplier(main: Node) -> float:
	return ENEMY_DIRECTOR.get_story_enemy_speed_multiplier(main.story_stage, main.story_mode_active)

static func get_difficulty_profile(main: Node) -> Dictionary:
	if main.difficulty_profile is Dictionary and not main.difficulty_profile.is_empty():
		return (main.difficulty_profile as Dictionary).duplicate(true)
	return _load_difficulty_profile(main)

static func get_difficulty_spawn_interval_multiplier(main: Node) -> float:
	return DIFFICULTY_PROFILE.get_scale(get_difficulty_profile(main), "spawn_interval_scale", 1.0)

static func get_difficulty_minimum_spawn_interval_multiplier(main: Node) -> float:
	return DIFFICULTY_PROFILE.get_scale(get_difficulty_profile(main), "minimum_spawn_interval_scale", 1.0)

static func get_difficulty_enemy_health_multiplier(main: Node, kind: String = "normal") -> float:
	return DIFFICULTY_PROFILE.get_health_scale_for_kind(kind, get_difficulty_profile(main))

static func get_difficulty_enemy_speed_multiplier(main: Node) -> float:
	return DIFFICULTY_PROFILE.get_scale(get_difficulty_profile(main), "enemy_speed_scale", 1.0)

static func get_difficulty_enemy_damage_multiplier(main: Node) -> float:
	return DIFFICULTY_PROFILE.get_scale(get_difficulty_profile(main), "enemy_damage_scale", 1.0)

static func get_difficulty_limit(main: Node, key: String, fallback: int) -> int:
	return DIFFICULTY_PROFILE.get_limit(get_difficulty_profile(main), key, fallback)

static func apply_difficulty_to_wave_profile(main: Node, wave_profile: Dictionary) -> Dictionary:
	return DIFFICULTY_PROFILE.apply_to_wave_profile(wave_profile, get_difficulty_profile(main))

static func apply_difficulty_to_enemy_profile(main: Node, kind: String, enemy_profile: Dictionary) -> Dictionary:
	return DIFFICULTY_PROFILE.apply_to_enemy_profile(kind, enemy_profile, get_difficulty_profile(main))

static func _load_difficulty_profile(main: Node) -> Dictionary:
	if main != null and bool(main.get("story_mode_active")):
		return DIFFICULTY_PROFILE.get_profile(DIFFICULTY_PROFILE.DEFAULT_DIFFICULTY_ID)
	if SAVE_MANAGER.is_endless_mode_active():
		var profile := SAVE_MANAGER.get_current_endless_profile()
		return DIFFICULTY_PROFILE.get_profile(str(profile.get("difficulty", DIFFICULTY_PROFILE.DEFAULT_DIFFICULTY_ID)))
	return DIFFICULTY_PROFILE.get_profile(DIFFICULTY_PROFILE.DEFAULT_DIFFICULTY_ID)
