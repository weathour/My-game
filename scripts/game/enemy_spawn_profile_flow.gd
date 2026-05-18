extends RefCounted

const ENEMY_DIRECTOR := preload("res://scripts/enemy/enemy_director.gd")
const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")


static func get_wave_profile(main: Node) -> Dictionary:
	var cycle_elapsed_time: float = get_cycle_elapsed_time(main)
	var profile: Dictionary = ENEMY_DIRECTOR.get_wave_profile(
		cycle_elapsed_time,
		ENEMY_DIRECTOR.get_default_elite_spawn_times(),
		get_player_growth_score(main),
		get_expected_growth_score(main)
	)
	if main.has_method("_apply_difficulty_to_wave_profile"):
		return main._apply_difficulty_to_wave_profile(profile)
	return profile


static func get_player_growth_score(main: Node) -> float:
	if main.player == null:
		return 0.0

	var summary: Dictionary = {}
	if main.player.has_method("get_stat_summary"):
		summary = main.player.get_stat_summary()

	return ENEMY_DIRECTOR.get_player_growth_score(
		int(main.player.level),
		summary,
		{},
		main.player.elite_relics_unlocked
	)


static func get_expected_growth_score(main: Node) -> float:
	return ENEMY_DIRECTOR.get_expected_growth_score(get_cycle_elapsed_time(main), ENEMY_DIRECTOR.get_default_boss_spawn_time())


static func get_cycle_elapsed_time(main: Node) -> float:
	if main != null and bool(main.get("endless_mode_active")):
		var cycle_duration: float = ENEMY_DIRECTOR.get_default_boss_spawn_time()
		var cycle_index: int = max(0, int(main.get("defeated_boss_count")))
		return max(0.0, float(main.get("survival_time")) - float(cycle_index) * cycle_duration)
	return float(main.get("survival_time")) if main != null else 0.0


static func get_cycle_spawn_count_multiplier(main: Node) -> float:
	if main == null or not bool(main.get("endless_mode_active")):
		return 1.0
	return ENEMY_DIRECTOR.get_endless_cycle_spawn_count_multiplier(int(main.get("defeated_boss_count")))


static func get_enemy_profile(main: Node, kind: String, archetype: String) -> Dictionary:
	var profile: Dictionary = ENEMY_ARCHETYPE_DATABASE.get_profile(kind, archetype)
	if main != null and main.has_method("_apply_difficulty_to_enemy_profile"):
		profile = main._apply_difficulty_to_enemy_profile(kind, profile)
	if main != null and bool(main.get("endless_mode_active")):
		profile = ENEMY_DIRECTOR.apply_endless_cycle_to_enemy_profile(kind, profile, int(main.get("defeated_boss_count")))
	return profile


static func has_active_special_enemy(main: Node, kind: String) -> bool:
	if main.boss_enemy == null or not is_instance_valid(main.boss_enemy):
		return false
	return str(main.boss_enemy.get("enemy_kind")) == kind
