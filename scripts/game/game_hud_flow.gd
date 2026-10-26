extends RefCounted

const DEVELOPER_OPTION_PROVIDER := preload("res://scripts/developer/developer_option_provider.gd")
const PERFORMANCE_MONITOR := preload("res://scripts/game/performance_monitor.gd")
const PERFORMANCE_RECORDER := preload("res://scripts/game/performance_recorder.gd")
const STATE := preload("res://scripts/game/session_state.gd")
const HUD_PRESENTATION_REFRESH_INTERVAL := 1.0 / 30.0
const FRAME_TIME_REFRESH_INTERVAL := HUD_PRESENTATION_REFRESH_INTERVAL
const FRAME_STATS_REFRESH_INTERVAL := HUD_PRESENTATION_REFRESH_INTERVAL
const LAST_FRAME_TIME_REFRESH_META := "last_frame_time_refresh_time"
const LAST_FRAME_STATS_REFRESH_META := "last_frame_stats_refresh_time"
const DEVELOPER_BUILD_TOOLS := preload("res://scripts/developer/developer_build_tools.gd")

# Handoff note:
# HUD projection lives here. main.gd should expose scene state and thin callback
# entry points; this flow decides how player/boss/performance state is rendered
# into HUD methods.

static func update_frame_hud(main: Node) -> void:
	if main.hud != null and main.hud.has_method("update_time") and _should_refresh_elapsed(main, LAST_FRAME_TIME_REFRESH_META, main.survival_time, FRAME_TIME_REFRESH_INTERVAL):
		PERFORMANCE_RECORDER.begin_scope("hud_time_label_ms")
		_update_time(main)
		PERFORMANCE_RECORDER.end_scope("hud_time_label_ms")
	if main.hud != null and main.hud.has_method("update_stats") and main.player != null and main.player.has_method("get_stat_summary") and _should_refresh_elapsed(main, LAST_FRAME_STATS_REFRESH_META, main.survival_time, FRAME_STATS_REFRESH_INTERVAL):
		PERFORMANCE_RECORDER.begin_scope("hud_stats_payload_ms")
		var summary: Dictionary = main.player.get_frame_hud_summary() if main.player.has_method("get_frame_hud_summary") else main.player.get_stat_summary()
		PERFORMANCE_RECORDER.end_scope("hud_stats_payload_ms")
		PERFORMANCE_RECORDER.begin_scope("hud_update_stats_ms")
		main.hud.update_stats(summary)
		PERFORMANCE_RECORDER.end_scope("hud_update_stats_ms")
		if main.hud.has_method("set_save_status"):
			main.hud.set_save_status(bool(main.get_meta("last_run_save_ok", true)) and not bool(main.player.get_meta("bone_save_failed", false)))
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
		if main.hud.has_method("set_endless_tier"):
			main.hud.set_endless_tier(main.endless_tier if STATE.presentation(main).mode in ["endless", "developer"] else 0)
		_update_time(main)
	if main.hud.has_method("set_developer_boss_options"):
		main.hud.set_developer_boss_options(main._get_developer_boss_options())
	if main.hud.has_method("set_developer_normal_enemy_options"):
		main.hud.set_developer_normal_enemy_options(main._get_developer_normal_enemy_options())
	if main.hud.has_method("set_developer_enemy_options"):
		main.hud.set_developer_enemy_options(main._get_developer_enemy_options())
	if main._is_developer_mode() and main.hud.has_method("set_developer_catalog_data"):
		main.hud.set_developer_catalog_data({
			"skill": DEVELOPER_BUILD_TOOLS.skill_catalog(main.player),
			"blessing": DEVELOPER_BUILD_TOOLS.blessing_catalog(main.player),
			"item": DEVELOPER_BUILD_TOOLS.item_catalog(main.player)
		})

static func _update_time(main: Node) -> void:
	var view := STATE.presentation(main)
	var caption := "本关剩余" if view.mode == "story" else "波次剩余" if view.wave > 0 else "已生存"
	var value: float = view.remaining_seconds if view.mode == "story" or view.wave > 0 else view.elapsed_seconds
	if view.phase == "preparation":
		caption = "整备剩余"
	elif view.phase == "result":
		caption = "本局用时"
		value = view.elapsed_seconds
	elif view.target_kind == "defeat_boss":
		caption = "讨伐用时"
		value = view.elapsed_seconds
	if main.hud.has_method("set_time_caption"):
		main.hud.set_time_caption(caption)
	main.hud.update_time(value)

static func _get_boss_ui_data(enemy, default_name: String) -> Dictionary:
	var current_health := float(enemy.get("current_health"))
	var max_health := float(enemy.get("max_health"))
	var boss_name := default_name
	var status_payload: Dictionary = {}
	var boss_ui_payload: Dictionary = {
		"enemy_kind": str(enemy.get("enemy_kind")),
		"shield_health": 0.0,
		"shield_max_health": 0.0
	}
	var hide_health := false
	if enemy.has_method("get_boss_ui_payload"):
		var payload: Dictionary = enemy.get_boss_ui_payload()
		boss_name = str(payload.get("name", boss_name))
		current_health = float(payload.get("current_health", current_health))
		max_health = float(payload.get("max_health", max_health))
		status_payload = payload.get("status", {}) as Dictionary
		boss_ui_payload = {
			"enemy_kind": str(payload.get("enemy_kind", boss_ui_payload.get("enemy_kind", "boss"))),
			"shield_health": max(0.0, float(payload.get("shield_health", 0.0))),
			"shield_max_health": max(0.0, float(payload.get("shield_max_health", 0.0)))
		}
		hide_health = bool(payload.get("hide_health", false))
	return {
		"name": boss_name,
		"current_health": current_health,
		"max_health": max_health,
		"status": status_payload,
		"ui": boss_ui_payload,
		"hide_health": hide_health
	}


static func update_boss_hud(main: Node) -> void:
	if main.hud == null:
		return

	var small_boss = main.small_boss_enemy
	if small_boss != null and not is_instance_valid(small_boss):
		main.small_boss_enemy = null
		small_boss = null
	var final_boss = main.boss_enemy
	if final_boss != null and not is_instance_valid(final_boss):
		main.boss_enemy = null
		main.boss_spawned = false
		final_boss = null

	var has_small_boss := small_boss != null and is_instance_valid(small_boss)
	var has_final_boss := final_boss != null and is_instance_valid(final_boss)
	if has_small_boss:
		var small_data: Dictionary = _get_boss_ui_data(small_boss, "小 Boss")
		if not bool(small_data.get("hide_health", false)) and main.hud.has_method("show_small_boss_ui"):
			main.hud.show_small_boss_ui(str(small_data.get("name", "小 Boss")), float(small_data.get("current_health", 0.0)), float(small_data.get("max_health", 1.0)))
		else:
			has_small_boss = false
	if not has_small_boss and main.hud.has_method("hide_small_boss_ui"):
		main.hud.hide_small_boss_ui()

	if has_final_boss:
		var final_data: Dictionary = _get_boss_ui_data(final_boss, "Boss")
		if not bool(final_data.get("hide_health", false)) and main.hud.has_method("show_boss_ui"):
			var final_name := str(final_data.get("name", "Boss"))
			if STATE.presentation(main).mode in ["endless", "developer"]:
				final_name = "N%d · %s" % [main.endless_tier, final_name]
			main.hud.show_boss_ui(final_name, float(final_data.get("current_health", 0.0)), float(final_data.get("max_health", 1.0)), final_data.get("status", {}) as Dictionary, final_data.get("ui", {}) as Dictionary)
		else:
			has_final_boss = false
	if not has_final_boss and main.hud.has_method("hide_final_boss_ui"):
		main.hud.hide_final_boss_ui()
	if not has_small_boss and not has_final_boss:
		hide_boss_ui(main)

static func update_performance_metrics(main: Node, delta: float) -> void:
	if STATE.presentation(main).mode not in ["developer", "endless"]:
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
		var summary: Dictionary = main.player.get_frame_hud_summary() if main.player.has_method("get_frame_hud_summary") else main.player.get_stat_summary()
		main.hud.update_stats(summary)

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
