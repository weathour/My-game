extends CanvasLayer

const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const DEVELOPER_PANEL := preload("res://scripts/developer/developer_panel.gd")
const COMBAT_SKILL_BAR := preload("res://scripts/ui/hud/combat_skill_bar.gd")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const PERFORMANCE_MONITOR := preload("res://scripts/game/performance_monitor.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")

signal developer_level_up_requested
signal developer_boss_spawn_requested(archetype_id: String)
signal developer_card_grant_requested(card_id: String)
signal developer_small_boss_spawn_requested(archetype_id: String)

var level_label: Label
var role_label: Label
var experience_bar: ProgressBar
var experience_label: Label
var health_bar: ProgressBar
var health_label: Label
var mana_bar: ProgressBar
var mana_label: Label
var ultimate_label: Label
var time_label: Label
var boss_panel: Control
var boss_name_label: Label
var boss_health_bar: ProgressBar
var boss_health_label: Label
var team_panel: PanelContainer
var team_role_labels: Array[Label] = []
var switch_cd_label: Label
var switch_power_label: Label
var relay_label: Label
var combat_skill_bar: Control
var developer_panel: PanelContainer
var performance_overlay_panel: PanelContainer
var performance_overlay_label: Label
var attack_mode_hint_panel: PanelContainer
var attack_mode_hint_label: Label
var minimap_panel: PanelContainer
var minimap_view: Control
var minimap_bounds := Rect2(Vector2(-1600.0, -900.0), Vector2(3200.0, 1800.0))
var minimap_payload: Dictionary = {}

func _ready() -> void:
	layer = 1

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	time_label = Label.new()
	time_label.anchor_left = 0.0
	time_label.anchor_right = 1.0
	time_label.offset_left = 0.0
	time_label.offset_right = 0.0
	time_label.offset_top = 12.0
	time_label.offset_bottom = 52.0
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 24)
	time_label.text = "时间 00:00"
	root.add_child(time_label)

	boss_panel = Control.new()
	boss_panel.anchor_left = 0.0
	boss_panel.anchor_right = 1.0
	boss_panel.offset_left = 120.0
	boss_panel.offset_right = -120.0
	boss_panel.offset_top = 10.0
	boss_panel.offset_bottom = 82.0
	boss_panel.visible = false
	root.add_child(boss_panel)

	boss_name_label = Label.new()
	boss_name_label.anchor_left = 0.0
	boss_name_label.anchor_right = 1.0
	boss_name_label.offset_top = 0.0
	boss_name_label.offset_bottom = 28.0
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 22)
	boss_name_label.text = "Boss"
	boss_panel.add_child(boss_name_label)

	boss_health_bar = ProgressBar.new()
	boss_health_bar.anchor_left = 0.0
	boss_health_bar.anchor_right = 1.0
	boss_health_bar.offset_left = 0.0
	boss_health_bar.offset_right = 0.0
	boss_health_bar.offset_top = 32.0
	boss_health_bar.offset_bottom = 56.0
	boss_health_bar.show_percentage = false
	boss_panel.add_child(boss_health_bar)

	boss_health_label = Label.new()
	boss_health_label.anchor_left = 0.0
	boss_health_label.anchor_right = 1.0
	boss_health_label.offset_top = 56.0
	boss_health_label.offset_bottom = 78.0
	boss_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_health_label.add_theme_font_size_override("font_size", 15)
	boss_health_label.text = "0 / 0"
	boss_panel.add_child(boss_health_label)

	_build_skill_cooldown_panel(root)
	_build_attack_mode_hint(root)
	_build_minimap(root)
	if DEVELOPER_MODE.is_enabled():
		_build_developer_panel(root)

func _build_team_panel(root: Control) -> void:
	team_panel = PanelContainer.new()
	team_panel.anchor_left = 1.0
	team_panel.anchor_top = 0.0
	team_panel.anchor_right = 1.0
	team_panel.anchor_bottom = 0.0
	team_panel.offset_left = -280.0
	team_panel.offset_top = 18.0
	team_panel.offset_right = -18.0
	team_panel.offset_bottom = 210.0

	team_panel.add_theme_stylebox_override("panel", SURVIVORS_THEME.panel_style(Color(0.08, 0.1, 0.14, 0.82), SURVIVORS_THEME.COLOR_BORDER_GOLD, 2, 10, 12.0))
	root.add_child(team_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	team_panel.add_child(content)

	var title := Label.new()
	title.text = "当前队伍"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	content.add_child(title)

	for role_name in ["剑士", "枪手", "术师"]:
		var label := Label.new()
		label.text = role_name
		label.add_theme_font_size_override("font_size", 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(label)
		team_role_labels.append(label)

	switch_cd_label = Label.new()
	switch_cd_label.text = "切人 CD 0.0 秒"
	switch_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	switch_cd_label.add_theme_font_size_override("font_size", 16)
	content.add_child(switch_cd_label)

	switch_power_label = Label.new()
	switch_power_label.text = "切换增益 无"
	switch_power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	switch_power_label.add_theme_font_size_override("font_size", 15)
	switch_power_label.modulate = Color(0.86, 0.9, 0.98, 0.92)
	content.add_child(switch_power_label)

	relay_label = Label.new()
	relay_label.text = "接力窗口 无"
	relay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	relay_label.add_theme_font_size_override("font_size", 15)
	relay_label.modulate = Color(0.8, 0.92, 1.0, 0.92)
	content.add_child(relay_label)

func _build_skill_cooldown_panel(root: Control) -> void:
	combat_skill_bar = COMBAT_SKILL_BAR.new()
	root.add_child(combat_skill_bar)

func _build_attack_mode_hint(root: Control) -> void:
	attack_mode_hint_panel = PanelContainer.new()
	attack_mode_hint_panel.anchor_left = 1.0
	attack_mode_hint_panel.anchor_top = 0.5
	attack_mode_hint_panel.anchor_right = 1.0
	attack_mode_hint_panel.anchor_bottom = 0.5
	attack_mode_hint_panel.offset_left = -292.0
	attack_mode_hint_panel.offset_top = -28.0
	attack_mode_hint_panel.offset_right = -16.0
	attack_mode_hint_panel.offset_bottom = 36.0

	attack_mode_hint_panel.add_theme_stylebox_override("panel", SURVIVORS_THEME.panel_style(Color(0.03, 0.05, 0.07, 0.72), Color(0.75, 0.88, 1.0, 0.58), 1, 10, 8.0))
	root.add_child(attack_mode_hint_panel)

	attack_mode_hint_label = Label.new()
	attack_mode_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	attack_mode_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attack_mode_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	attack_mode_hint_label.add_theme_font_size_override("font_size", 15)
	attack_mode_hint_label.modulate = Color(0.88, 0.96, 1.0, 0.96)
	attack_mode_hint_panel.add_child(attack_mode_hint_label)
	_update_attack_mode_hint(false)

func _build_minimap(root: Control) -> void:
	minimap_panel = PanelContainer.new()
	minimap_panel.anchor_left = 1.0
	minimap_panel.anchor_top = 1.0
	minimap_panel.anchor_right = 1.0
	minimap_panel.anchor_bottom = 1.0
	minimap_panel.offset_left = -236.0
	minimap_panel.offset_top = -172.0
	minimap_panel.offset_right = -18.0
	minimap_panel.offset_bottom = -18.0

	minimap_panel.add_theme_stylebox_override("panel", SURVIVORS_THEME.panel_style(Color(0.02, 0.04, 0.07, 0.72), Color(0.42, 0.78, 1.0, 0.76), 1, 10, 8.0))
	root.add_child(minimap_panel)

	minimap_view = Control.new()
	minimap_view.custom_minimum_size = Vector2(200.0, 138.0)
	minimap_view.draw.connect(_draw_minimap)
	minimap_panel.add_child(minimap_view)

func configure_minimap(bounds: Rect2) -> void:
	minimap_bounds = bounds
	if minimap_view != null:
		minimap_view.queue_redraw()

func update_minimap(payload: Dictionary) -> void:
	minimap_payload = payload.duplicate(true)
	var bounds = minimap_payload.get("bounds", minimap_bounds)
	if bounds is Rect2:
		minimap_bounds = bounds
	if minimap_view != null:
		minimap_view.queue_redraw()

func _draw_minimap() -> void:
	if minimap_view == null:
		return
	var rect := Rect2(Vector2.ZERO, minimap_view.size)
	minimap_view.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.24), true)
	minimap_view.draw_rect(rect, Color(0.42, 0.8, 1.0, 0.8), false, 1.0)
	_draw_minimap_points(rect)

func _draw_minimap_points(rect: Rect2) -> void:
	var player_position = minimap_payload.get("player_position", null)
	if player_position is Vector2:
		minimap_view.draw_circle(_map_to_minimap(player_position, rect), 4.5, Color(0.42, 0.95, 1.0, 1.0))
		minimap_view.draw_circle(_map_to_minimap(player_position, rect), 8.0, Color(0.42, 0.95, 1.0, 0.18))

	var boss_position = minimap_payload.get("boss_position", null)
	if boss_position is Vector2:
		minimap_view.draw_circle(_map_to_minimap(boss_position, rect), 5.2, Color(1.0, 0.32, 0.28, 1.0))

	for entry in minimap_payload.get("enemies", []):
		if entry is not Dictionary:
			continue
		var position = entry.get("position", null)
		if position is not Vector2:
			continue
		var kind := str(entry.get("kind", "normal"))
		var color := Color(1.0, 0.42, 0.34, 0.78)
		var radius := 2.3
		if kind == "elite":
			color = Color(1.0, 0.78, 0.25, 0.95)
			radius = 3.0
		elif kind == "small_boss":
			color = Color(1.0, 0.46, 0.8, 0.95)
			radius = 3.6
		elif kind == "boss":
			color = Color(1.0, 0.2, 0.2, 1.0)
			radius = 4.8
		minimap_view.draw_circle(_map_to_minimap(position, rect), radius, color)

	for entry in minimap_payload.get("gems", []):
		if entry is Dictionary and entry.get("position", null) is Vector2:
			minimap_view.draw_circle(_map_to_minimap(entry["position"], rect), 1.6, Color(0.3, 1.0, 0.55, 0.58))

	for entry in minimap_payload.get("hearts", []):
		if entry is Dictionary and entry.get("position", null) is Vector2:
			minimap_view.draw_circle(_map_to_minimap(entry["position"], rect), 2.2, Color(1.0, 0.34, 0.5, 0.85))

func _map_to_minimap(world_position: Vector2, rect: Rect2) -> Vector2:
	var bounds := minimap_bounds
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return rect.get_center()
	var normalized := Vector2(
		(world_position.x - bounds.position.x) / bounds.size.x,
		(world_position.y - bounds.position.y) / bounds.size.y
	)
	normalized.x = clamp(normalized.x, 0.0, 1.0)
	normalized.y = clamp(normalized.y, 0.0, 1.0)
	return rect.position + Vector2(normalized.x * rect.size.x, normalized.y * rect.size.y)

func _update_attack_mode_hint(auto_attack: bool) -> void:
	if attack_mode_hint_label == null:
		return
	var key_name := GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_TOGGLE_ATTACK_MODE))
	var mode_text := "自动攻击" if auto_attack else "鼠标跟随"
	attack_mode_hint_label.text = "%s切换攻击方式：目前攻击为%s" % [key_name, mode_text]

func _build_developer_panel(root: Control) -> void:
	developer_panel = DEVELOPER_PANEL.new()
	root.add_child(developer_panel)
	developer_panel.level_up_requested.connect(func(): developer_level_up_requested.emit())
	developer_panel.boss_spawn_requested.connect(func(archetype_id: String): developer_boss_spawn_requested.emit(archetype_id))
	developer_panel.card_grant_requested.connect(func(card_id: String): developer_card_grant_requested.emit(card_id))
	developer_panel.small_boss_spawn_requested.connect(func(archetype_id: String): developer_small_boss_spawn_requested.emit(archetype_id))

func set_developer_invincibility_enabled(enabled: bool) -> void:
	if developer_panel != null and developer_panel.has_method("set_invincibility_enabled"):
		developer_panel.set_invincibility_enabled(enabled)

func set_developer_boss_options(options: Array) -> void:
	if developer_panel != null and developer_panel.has_method("set_boss_options"):
		developer_panel.set_boss_options(options)

func set_developer_dangzhen_build_options(options: Array) -> void:
	if developer_panel != null and developer_panel.has_method("set_dangzhen_build_options"):
		developer_panel.set_dangzhen_build_options(options)

func set_developer_special_card_options(options: Array) -> void:
	if developer_panel != null and developer_panel.has_method("set_special_card_options"):
		developer_panel.set_special_card_options(options)

func update_performance_metrics(metrics: Dictionary) -> void:
	if developer_panel != null and developer_panel.has_method("update_performance_metrics"):
		developer_panel.update_performance_metrics(metrics)
		return
	_ensure_performance_overlay()
	if performance_overlay_label != null:
		performance_overlay_label.text = PERFORMANCE_MONITOR.format_metrics(metrics)

func _ensure_performance_overlay() -> void:
	if performance_overlay_panel != null:
		return
	performance_overlay_panel = PanelContainer.new()
	performance_overlay_panel.anchor_left = 1.0
	performance_overlay_panel.anchor_top = 0.0
	performance_overlay_panel.anchor_right = 1.0
	performance_overlay_panel.anchor_bottom = 0.0
	performance_overlay_panel.offset_left = -360.0
	performance_overlay_panel.offset_top = 92.0
	performance_overlay_panel.offset_right = -16.0
	performance_overlay_panel.offset_bottom = 158.0

	performance_overlay_panel.add_theme_stylebox_override("panel", SURVIVORS_THEME.panel_style(Color(0.02, 0.04, 0.06, 0.68), Color(0.45, 0.78, 1.0, 0.72), 1, 8, 8.0))

	performance_overlay_label = Label.new()
	performance_overlay_label.text = "Performance: collecting..."
	performance_overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	performance_overlay_label.add_theme_font_size_override("font_size", 13)
	performance_overlay_label.modulate = Color(0.82, 0.95, 1.0, 0.96)
	performance_overlay_panel.add_child(performance_overlay_label)
	add_child(performance_overlay_panel)

func update_display(level: int, current_experience: int, required_experience: int) -> void:
	if level_label != null:
		level_label.text = "等级 %d" % level
	if experience_bar != null:
		experience_bar.max_value = max(required_experience, 1)
		experience_bar.value = current_experience
	if experience_label != null:
		experience_label.text = "%d / %d XP" % [current_experience, required_experience]
	if combat_skill_bar != null and combat_skill_bar.has_method("update_experience"):
		combat_skill_bar.update_experience(current_experience, required_experience)

func update_health(current_health: float, max_health: float) -> void:
	if health_bar != null:
		health_bar.max_value = max(max_health, 1.0)
		health_bar.value = current_health
	if health_label != null:
		health_label.text = "HP %.0f / %.0f" % [current_health, max_health]

func update_mana(current_mana: float, max_mana: float) -> void:
	if mana_bar != null:
		mana_bar.max_value = max(max_mana, 1.0)
		mana_bar.value = current_mana
	if mana_label != null:
		mana_label.text = "大招能量 %.0f / %.0f" % [current_mana, max_mana]

func update_stats(summary: Dictionary) -> void:
	_update_attack_mode_hint(bool(summary.get("auto_attack_enabled", false)))
	if role_label != null:
		role_label.text = "角色 %s" % summary.get("role_name", "剑士")
	var active_role_index := int(summary.get("active_role_index", 0))
	var team_roles: Array = summary.get("team_roles", ["剑士", "枪手", "术师"])
	for index in range(team_role_labels.size()):
		var label := team_role_labels[index]
		var role_name := str(team_roles[index]) if index < team_roles.size() else "-"
		if index == active_role_index:
			label.text = "> %s <" % role_name
			label.modulate = Color(1.0, 0.92, 0.45, 1.0)
		else:
			label.text = role_name
			label.modulate = Color(0.86, 0.86, 0.86, 1.0)

	var switch_cooldown := float(summary.get("switch_cooldown", 0.0))
	if switch_cd_label != null:
		if switch_cooldown > 0.0:
			switch_cd_label.text = "切人 CD %.1f 秒" % switch_cooldown
		else:
			switch_cd_label.text = "切人 CD 就绪"
	if combat_skill_bar != null and combat_skill_bar.has_method("update_switch_cooldown"):
		combat_skill_bar.update_switch_cooldown(str(summary.get("role_id", "swordsman")), switch_cooldown, float(summary.get("switch_cooldown_base", 8.0)))

	var switch_power_name := str(summary.get("switch_power_label", ""))
	var switch_power_remaining := float(summary.get("switch_power_remaining", 0.0))
	var entry_blessing_name := str(summary.get("entry_blessing_label", ""))
	var entry_blessing_remaining := float(summary.get("entry_blessing_remaining", 0.0))
	var switch_buff_parts: Array[String] = []
	if switch_power_remaining > 0.0 and switch_power_name != "":
		switch_buff_parts.append("%s %.1f 秒" % [switch_power_name, switch_power_remaining])
	if entry_blessing_remaining > 0.0 and entry_blessing_name != "":
		switch_buff_parts.append("%s %.1f 秒" % [entry_blessing_name, entry_blessing_remaining])
	if switch_power_label != null:
		if not switch_buff_parts.is_empty():
			switch_power_label.text = "切换增益 %s" % " / ".join(switch_buff_parts)
			switch_power_label.modulate = Color(1.0, 0.9, 0.5, 0.98)
		else:
			switch_power_label.text = "切换增益 无"
			switch_power_label.modulate = Color(0.86, 0.9, 0.98, 0.92)

	var relay_window := float(summary.get("relay_window_remaining", 0.0))
	var relay_name := str(summary.get("relay_label", ""))
	var relay_pending := bool(summary.get("relay_bonus_pending", false))
	if relay_label != null:
		if relay_pending and relay_window > 0.0 and relay_name != "":
			relay_label.text = "接力窗口 %s %.1f 秒" % [relay_name, relay_window]
			relay_label.modulate = Color(1.0, 0.92, 0.56, 0.98)
		else:
			relay_label.text = "接力窗口 无"
			relay_label.modulate = Color(0.8, 0.92, 1.0, 0.92)

	var current_energy: float = float(summary.get("current_mana", 0.0))
	var required_energy: float = float(summary.get("ultimate_energy_cost", 100.0))
	var ultimate_ready: bool = bool(summary.get("ultimate_ready", false))
	if ultimate_label != null:
		if ultimate_ready:
			ultimate_label.text = "大招能量 %.0f / %.0f | 大招就绪" % [current_energy, required_energy]
			ultimate_label.modulate = Color(1.0, 0.9, 0.5, 1.0)
		else:
			ultimate_label.text = "大招能量 %.0f / %.0f | 大招未就绪" % [current_energy, required_energy]
			ultimate_label.modulate = Color(0.88, 0.92, 0.98, 0.96)
	var max_energy: float = max(float(summary.get("max_mana", 1.0)), 1.0)
	if mana_bar != null and mana_bar.max_value != max_energy:
		mana_bar.max_value = max_energy
	if mana_bar != null and mana_bar.value != current_energy:
		mana_bar.value = current_energy
	if combat_skill_bar != null and combat_skill_bar.has_method("update_ultimate_energy"):
		combat_skill_bar.update_ultimate_energy(current_energy, required_energy, summary.get("ultimate_display", {}))
	var cooldown_slots: Array = summary.get("skill_cooldown_slots", [])
	if combat_skill_bar != null and combat_skill_bar.has_method("update_skill_cooldown_slots"):
		combat_skill_bar.update_skill_cooldown_slots(cooldown_slots)

func update_time(seconds_elapsed: float) -> void:
	var total_seconds: int = int(floor(seconds_elapsed))
	var minutes: int = int(total_seconds / 60)
	var seconds: int = total_seconds % 60
	time_label.text = "时间 %02d:%02d" % [minutes, seconds]

func show_boss_ui(boss_name: String, current_health: float, max_health: float) -> void:
	if boss_panel != null:
		boss_panel.visible = true
	if time_label != null:
		time_label.visible = false
	update_boss_ui(boss_name, current_health, max_health)

func update_boss_ui(boss_name: String, current_health: float, max_health: float) -> void:
	if boss_panel == null:
		return
	boss_name_label.text = boss_name
	boss_health_bar.max_value = max(max_health, 1.0)
	boss_health_bar.value = clamp(current_health, 0.0, boss_health_bar.max_value)
	boss_health_label.text = "%.0f / %.0f" % [max(current_health, 0.0), max_health]

func hide_boss_ui() -> void:
	if boss_panel != null:
		boss_panel.visible = false
	if time_label != null:
		time_label.visible = true
