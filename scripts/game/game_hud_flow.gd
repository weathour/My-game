extends RefCounted

const DEVELOPER_OPTION_PROVIDER := preload("res://scripts/developer/developer_option_provider.gd")
const PERFORMANCE_MONITOR := preload("res://scripts/game/performance_monitor.gd")
const PERFORMANCE_RECORDER := preload("res://scripts/game/performance_recorder.gd")
const HUD_PRESENTATION_REFRESH_INTERVAL := 1.0 / 30.0
const FRAME_TIME_REFRESH_INTERVAL := HUD_PRESENTATION_REFRESH_INTERVAL
const FRAME_STATS_REFRESH_INTERVAL := HUD_PRESENTATION_REFRESH_INTERVAL
const LAST_FRAME_TIME_REFRESH_META := "last_frame_time_refresh_time"
const LAST_FRAME_STATS_REFRESH_META := "last_frame_stats_refresh_time"

# Handoff note:
# HUD projection lives here. main.gd should expose scene state and thin callback
# entry points; this flow decides how player/boss/performance state is rendered
# into HUD methods.

static func update_frame_hud(main: Node) -> void:
	if main.hud != null and main.hud.has_method("update_time") and _should_refresh_elapsed(main, LAST_FRAME_TIME_REFRESH_META, main.survival_time, FRAME_TIME_REFRESH_INTERVAL):
		PERFORMANCE_RECORDER.begin_scope("hud_time_label_ms")
		main.hud.update_time(main.survival_time)
		PERFORMANCE_RECORDER.end_scope("hud_time_label_ms")
	if main.hud != null and main.hud.has_method("update_stats") and main.player != null and main.player.has_method("get_stat_summary") and _should_refresh_elapsed(main, LAST_FRAME_STATS_REFRESH_META, main.survival_time, FRAME_STATS_REFRESH_INTERVAL):
		PERFORMANCE_RECORDER.begin_scope("hud_stats_payload_ms")
		var summary: Dictionary = main.player.get_frame_hud_summary() if main.player.has_method("get_frame_hud_summary") else main.player.get_stat_summary()
		PERFORMANCE_RECORDER.end_scope("hud_stats_payload_ms")
		PERFORMANCE_RECORDER.begin_scope("hud_update_stats_ms")
		main.hud.update_stats(summary)
		PERFORMANCE_RECORDER.end_scope("hud_update_stats_ms")
	PERFORMANCE_RECORDER.begin_scope("boss_hud_ms")
	update_boss_hud(main)
	PERFORMANCE_RECORDER.end_scope("boss_hud_ms")

static func refresh_hud(main: Node) -> void:
	if main.hud == null or main.player == null:
		return
	if main.hud.has_method("update_display"):
		main.hud.update_display(main.player.level, main.player.experience, main.player.experience_to_next_level)
	if main.hud.has_method("update_stats"):
		main.hud.update_stats(main.player.get_stat_summary())
	if main.hud.has_method("update_health"):
		main.hud.update_health(main.player.current_health, main.player.max_health)
	if main.hud.has_method("update_mana"):
		main.hud.update_mana(main.player.current_mana, main.player.max_mana)
	if main.hud.has_method("update_time"):
		main.hud.update_time(main.survival_time)
	if main.hud.has_method("set_developer_boss_options"):
		main.hud.set_developer_boss_options(main._get_developer_boss_options())
	if main.hud.has_method("set_developer_normal_enemy_options"):
		main.hud.set_developer_normal_enemy_options(main._get_developer_normal_enemy_options())
	if main.hud.has_method("set_developer_skill_options"):
		main.hud.set_developer_skill_options(main._get_developer_skill_options())
	if main.hud.has_method("set_developer_blessing_options"):
		main.hud.set_developer_blessing_options(main._get_developer_blessing_options())
	update_boss_hud(main)

static func update_boss_hud(main: Node) -> void:
	if main.hud == null:
		return

	if main.boss_enemy != null and not is_instance_valid(main.boss_enemy):
		main.boss_enemy = null
		main.boss_spawned = false

	if main.boss_enemy != null and is_instance_valid(main.boss_enemy):
		var boss_name := "Boss"
		var current_health := float(main.boss_enemy.get("current_health"))
		var max_health := float(main.boss_enemy.get("max_health"))
		if main.boss_enemy.has_method("get_boss_ui_payload"):
			var payload: Dictionary = main.boss_enemy.get_boss_ui_payload()
			boss_name = str(payload.get("name", boss_name))
			current_health = float(payload.get("current_health", current_health))
			max_health = float(payload.get("max_health", max_health))
		if main.hud.has_method("show_boss_ui"):
			main.hud.show_boss_ui(boss_name, current_health, max_health)
	else:
		hide_boss_ui(main)

static func update_performance_metrics(main: Node, delta: float) -> void:
	if not main._is_developer_mode() and not main.endless_mode_active:
		return
	if main.hud == null or not main.hud.has_method("update_performance_metrics"):
		return
	main.performance_sample_elapsed += delta
	if main.performance_sample_elapsed < PERFORMANCE_MONITOR.SAMPLE_INTERVAL:
		return
	main.performance_sample_elapsed = 0.0
	main.hud.update_performance_metrics(PERFORMANCE_MONITOR.collect_metrics(main))

static func hide_boss_ui(main: Node) -> void:
	if main.hud != null and main.hud.has_method("hide_boss_ui"):
		main.hud.hide_boss_ui()

static func on_player_experience_changed(main: Node, current_experience: int, required_experience: int, current_level: int) -> void:
	if main.hud != null and main.hud.has_method("update_display"):
		main.hud.update_display(current_level, current_experience, required_experience)

static func on_player_stats_changed(main: Node, summary: Dictionary) -> void:
	if main.hud != null and main.hud.has_method("update_stats"):
		main.hud.update_stats(summary)

static func on_player_health_changed(main: Node, current_health: float, max_health: float) -> void:
	if main.hud != null and main.hud.has_method("update_health"):
		main.hud.update_health(current_health, max_health)

static func on_player_mana_changed(main: Node, current_mana: float, max_mana: float) -> void:
	if main.hud != null and main.hud.has_method("update_mana"):
		main.hud.update_mana(current_mana, max_mana)
	if main.hud != null and main.hud.has_method("update_stats") and main.player != null and main.player.has_method("get_stat_summary") and _should_refresh_mana_stats(main):
		main.hud.update_stats(main.player.get_stat_summary())

static func _should_refresh_mana_stats(main: Node) -> bool:
	return _should_refresh_elapsed(main, LAST_FRAME_STATS_REFRESH_META, main.survival_time, FRAME_STATS_REFRESH_INTERVAL)

static func _should_refresh_elapsed(owner: Node, meta_key: String, current_time: float, interval: float) -> bool:
	if owner == null:
		return false
	if interval <= 0.0:
		return true
	var last_refresh_time := float(owner.get_meta(meta_key, -999999.0))
	if current_time - last_refresh_time < interval:
		return false
	owner.set_meta(meta_key, current_time)
	return true
