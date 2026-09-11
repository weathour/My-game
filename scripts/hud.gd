extends CanvasLayer

const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const DEVELOPER_PANEL := preload("res://scripts/developer/developer_panel.gd")
const COMBAT_SKILL_BAR := preload("res://scripts/ui/hud/combat_skill_bar.gd")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const PERFORMANCE_MONITOR := preload("res://scripts/game/performance_monitor.gd")
const SURVIVORS_THEME := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
const ATTACK_MODE_HINT_VISIBLE_SECONDS := 10.0
const ATTACK_MODE_HINT_FADE_SECONDS := 0.65

signal developer_level_up_requested
signal developer_boss_spawn_requested(archetype_id: String)
signal developer_small_boss_spawn_requested(archetype_id: String)
signal developer_normal_enemy_batch_spawn_requested(archetype_id: String, count: int)
signal developer_enemy_spawn_requested(kind: String, archetype_id: String, count: int)
signal developer_skill_unlock_requested(skill_id: String, tier: int)
signal developer_skill_talent_grant_requested(talent_id: String)
signal developer_blessing_grant_requested(blessing_id: String, tier: int)
signal developer_all_blessings_grant_requested
signal developer_ruan_stone_action_requested(action_id: String)
signal developer_enemy_detail_display_toggled(enabled: bool)
signal developer_glutton_skill_test_requested(skill_id: String)
signal developer_endless_tier_test_requested(tier: int)
signal endless_speed_toggled(enabled: bool)

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
var current_endless_tier: int = 0
var boss_panel: Control
var boss_name_label: Label
var boss_health_bar: ProgressBar
var boss_shield_bar: ProgressBar
var boss_health_label: Label
var boss_status_label: Label
var boss_status_bar: ProgressBar
var small_boss_panel: Control
var small_boss_name_label: Label
var small_boss_health_bar: ProgressBar
var small_boss_health_label: Label
var team_panel: PanelContainer
var team_role_labels: Array[Label] = []
var switch_cd_label: Label
var switch_power_label: Label
var combat_skill_bar: Control
var developer_panel: PanelContainer
var performance_overlay_panel: PanelContainer
var performance_overlay_label: Label
var performance_overlay_visible: bool = false
var attack_mode_hint_panel: PanelContainer
var attack_mode_hint_label: Label
var attack_mode_hint_key_name: String = ""
var attack_mode_hint_tween: Tween
var ruan_stone_status_panel: PanelContainer
var ruan_stone_status_label: Label
var minimap_panel: PanelContainer
var minimap_view: Control
var minimap_bounds := Rect2(Vector2(-1600.0, -900.0), Vector2(3200.0, 1800.0))
var minimap_payload: Dictionary = {}
var endless_speed_button: Button

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
	var boss_health_fill := StyleBoxFlat.new()
	boss_health_fill.bg_color = Color(0.92, 0.08, 0.06, 0.96)
	boss_health_fill.set_corner_radius_all(6)
	boss_health_bar.add_theme_stylebox_override("fill", boss_health_fill)
	boss_health_bar.z_index = 0
	boss_panel.add_child(boss_health_bar)

	boss_shield_bar = ProgressBar.new()
	boss_shield_bar.anchor_left = 0.0
	boss_shield_bar.anchor_right = 1.0
	boss_shield_bar.offset_left = 0.0
	boss_shield_bar.offset_right = 0.0
	boss_shield_bar.offset_top = 32.0
	boss_shield_bar.offset_bottom = 44.0
	boss_shield_bar.show_percentage = false
	boss_shield_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var boss_shield_fill := StyleBoxFlat.new()
	boss_shield_fill.bg_color = Color(1.0, 0.68, 0.12, 1.0)
	boss_shield_fill.set_corner_radius_all(6)
	boss_shield_bar.add_theme_stylebox_override("fill", boss_shield_fill)
	var boss_shield_background := StyleBoxFlat.new()
	boss_shield_background.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	boss_shield_bar.add_theme_stylebox_override("background", boss_shield_background)
	boss_shield_bar.modulate.a = 1.0
	boss_shield_bar.z_index = 1
	boss_shield_bar.visible = false
	boss_panel.add_child(boss_shield_bar)

	boss_health_label = Label.new()
	boss_health_label.anchor_left = 0.0
	boss_health_label.anchor_right = 1.0
	boss_health_label.offset_top = 56.0
	boss_health_label.offset_bottom = 78.0
	boss_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_health_label.add_theme_font_size_override("font_size", 15)
	boss_health_label.text = "0 / 0"
	boss_panel.add_child(boss_health_label)

	boss_status_label = Label.new()
	boss_status_label.anchor_left = 0.0
	boss_status_label.anchor_right = 1.0
	boss_status_label.offset_top = 78.0
	boss_status_label.offset_bottom = 98.0
	boss_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_status_label.add_theme_font_size_override("font_size", 15)
	boss_status_label.modulate = Color(1.0, 0.68, 0.42, 1.0)
	boss_status_label.text = ""
	boss_status_label.visible = false
	boss_panel.add_child(boss_status_label)

	boss_status_bar = ProgressBar.new()
	boss_status_bar.anchor_left = 0.18
	boss_status_bar.anchor_right = 0.82
	boss_status_bar.offset_left = 0.0
	boss_status_bar.offset_right = 0.0
	boss_status_bar.offset_top = 99.0
	boss_status_bar.offset_bottom = 111.0
	boss_status_bar.show_percentage = false
	boss_status_bar.visible = false
	boss_panel.add_child(boss_status_bar)

	_build_skill_cooldown_panel(root)
	_build_ruan_stone_status(root)
	_build_endless_speed_toggle(root)
	_build_attack_mode_hint(root)
	_build_minimap(root)
	_build_small_boss_panel(root)
	if DEVELOPER_MODE.is_enabled():
		_build_developer_panel(root)
	set_performance_overlay_visible(performance_overlay_visible)

func _build_small_boss_panel(root: Control) -> void:
	small_boss_panel = Control.new()
	small_boss_panel.anchor_left = 0.0
	small_boss_panel.anchor_right = 1.0
	small_boss_panel.offset_left = 120.0
	small_boss_panel.offset_right = -120.0
	small_boss_panel.offset_top = 10.0
	small_boss_panel.offset_bottom = 82.0
	small_boss_panel.visible = false
	root.add_child(small_boss_panel)

	small_boss_name_label = Label.new()
	small_boss_name_label.anchor_left = 0.0
	small_boss_name_label.anchor_right = 1.0
	small_boss_name_label.offset_top = 0.0
	small_boss_name_label.offset_bottom = 28.0
	small_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small_boss_name_label.add_theme_font_size_override("font_size", 20)
	small_boss_name_label.text = "小 Boss"
	small_boss_panel.add_child(small_boss_name_label)

	small_boss_health_bar = ProgressBar.new()
	small_boss_health_bar.anchor_left = 0.0
	small_boss_health_bar.anchor_right = 1.0
	small_boss_health_bar.offset_left = 0.0
	small_boss_health_bar.offset_right = 0.0
	small_boss_health_bar.offset_top = 32.0
	small_boss_health_bar.offset_bottom = 56.0
	small_boss_health_bar.show_percentage = false
	var small_boss_fill := StyleBoxFlat.new()
	small_boss_fill.bg_color = Color(0.9, 0.28, 0.08, 0.96)
	small_boss_fill.set_corner_radius_all(6)
	small_boss_health_bar.add_theme_stylebox_override("fill", small_boss_fill)
	small_boss_panel.add_child(small_boss_health_bar)

	small_boss_health_label = Label.new()
	small_boss_health_label.anchor_left = 0.0
	small_boss_health_label.anchor_right = 1.0
	small_boss_health_label.offset_top = 56.0
	small_boss_health_label.offset_bottom = 78.0
	small_boss_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small_boss_health_label.add_theme_font_size_override("font_size", 15)
	small_boss_health_label.text = "0 / 0"
	small_boss_panel.add_child(small_boss_health_label)


func _layout_boss_panels() -> void:
	var has_small_boss := small_boss_panel != null and small_boss_panel.visible
	if small_boss_panel != null:
		small_boss_panel.offset_top = 10.0
		small_boss_panel.offset_bottom = 82.0
	if boss_panel != null:
		boss_panel.offset_top = 128.0 if has_small_boss else 10.0
		boss_panel.offset_bottom = 200.0 if has_small_boss else 82.0


func show_small_boss_ui(boss_name: String, current_health: float, max_health: float) -> void:
	if small_boss_panel != null:
		small_boss_panel.visible = true
	if time_label != null:
		time_label.visible = false
	_layout_boss_panels()
	update_small_boss_ui(boss_name, current_health, max_health)


func update_small_boss_ui(boss_name: String, current_health: float, max_health: float) -> void:
	if small_boss_panel == null:
		return
	small_boss_panel.visible = true
	small_boss_name_label.text = boss_name
	var health_max_value: float = max(max_health, 1.0)
	small_boss_health_bar.max_value = health_max_value
	small_boss_health_bar.value = clamp(current_health, 0.0, health_max_value)
	small_boss_health_label.text = "%.0f / %.0f" % [clamp(current_health, 0.0, health_max_value), health_max_value]
	_layout_boss_panels()


func hide_small_boss_ui() -> void:
	if small_boss_panel != null:
		small_boss_panel.visible = false
	_layout_boss_panels()
	if boss_panel == null or not boss_panel.visible:
		if time_label != null:
			time_label.visible = true


func hide_final_boss_ui() -> void:
	if boss_panel != null:
		boss_panel.visible = false
	if boss_shield_bar != null:
		boss_shield_bar.visible = false
	_layout_boss_panels()
	if small_boss_panel == null or not small_boss_panel.visible:
		if time_label != null:
			time_label.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if GAME_SETTINGS.event_matches_action(event, GAME_SETTINGS.ACTION_TOGGLE_PERFORMANCE_OVERLAY):
		toggle_performance_overlay()
		get_viewport().set_input_as_handled()

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

	for role_name in ["剑士", "枪手", "法师"]:
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


func _build_skill_cooldown_panel(root: Control) -> void:
	combat_skill_bar = COMBAT_SKILL_BAR.new()
	root.add_child(combat_skill_bar)


func _build_ruan_stone_status(root: Control) -> void:
	ruan_stone_status_panel = PanelContainer.new()
	ruan_stone_status_panel.name = "RuanStoneHudPanel"
	ruan_stone_status_panel.anchor_left = 0.0
	ruan_stone_status_panel.anchor_right = 0.0
	ruan_stone_status_panel.offset_left = 18.0
	ruan_stone_status_panel.offset_top = 18.0
	ruan_stone_status_panel.offset_right = 258.0
	ruan_stone_status_panel.offset_bottom = 78.0
	ruan_stone_status_panel.add_theme_stylebox_override(
		"panel",
		SURVIVORS_THEME.panel_style(Color(0.055, 0.04, 0.018, 0.88), SURVIVORS_THEME.COLOR_BORDER_GOLD, 1, 9, 8.0)
	)
	root.add_child(ruan_stone_status_panel)

	ruan_stone_status_label = Label.new()
	ruan_stone_status_label.name = "RuanStoneHudLabel"
	ruan_stone_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ruan_stone_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ruan_stone_status_label.add_theme_font_size_override("font_size", 15)
	ruan_stone_status_label.add_theme_color_override("font_color", SURVIVORS_THEME.COLOR_TEXT_GOLD)
	ruan_stone_status_label.text = "骨头 0\n阮石 未装备"
	ruan_stone_status_panel.add_child(ruan_stone_status_label)

func _build_endless_speed_toggle(root: Control) -> void:
	endless_speed_button = Button.new()
	endless_speed_button.name = "EndlessSpeedToggle"
	endless_speed_button.offset_left = 18.0
	endless_speed_button.offset_top = 86.0
	endless_speed_button.offset_right = 138.0
	endless_speed_button.offset_bottom = 126.0
	endless_speed_button.toggle_mode = true
	endless_speed_button.text = "速度 ×1"
	endless_speed_button.tooltip_text = "仅无尽模式生效；切换整个战斗的运行速度。"
	endless_speed_button.add_theme_font_size_override("font_size", 16)
	SURVIVORS_THEME.apply_button_style(endless_speed_button)
	endless_speed_button.toggled.connect(_on_endless_speed_toggled)
	endless_speed_button.visible = false
	root.add_child(endless_speed_button)

func set_endless_mode_enabled(enabled: bool) -> void:
	if endless_speed_button == null:
		return
	endless_speed_button.visible = enabled
	if not enabled:
		set_endless_speed_active(false)

func set_endless_speed_active(enabled: bool) -> void:
	if endless_speed_button == null:
		return
	endless_speed_button.set_pressed_no_signal(enabled)
	endless_speed_button.text = "速度 ×2" if enabled else "速度 ×1"

func _on_endless_speed_toggled(enabled: bool) -> void:
	set_endless_speed_active(enabled)
	endless_speed_toggled.emit(enabled)

func set_hud_layout(layout_key: String) -> void:
	if combat_skill_bar != null and combat_skill_bar.has_method("set_hud_layout"):
		combat_skill_bar.set_hud_layout(layout_key)

func sync_hud_layout_from_settings() -> void:
	if combat_skill_bar != null and combat_skill_bar.has_method("sync_hud_layout_from_settings"):
		combat_skill_bar.sync_hud_layout_from_settings()

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
	attack_mode_hint_panel.modulate.a = 1.0
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
	minimap_payload = payload
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
	if attack_mode_hint_key_name == "":
		attack_mode_hint_key_name = GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.ACTION_TOGGLE_ATTACK_MODE))
	var mode_text := "自动攻击" if auto_attack else "鼠标跟随"
	var next_text := "%s切换攻击方式：目前攻击为%s" % [attack_mode_hint_key_name, mode_text]
	if attack_mode_hint_label.text == next_text:
		return
	attack_mode_hint_label.text = next_text
	_schedule_attack_mode_hint_fade()

func _schedule_attack_mode_hint_fade() -> void:
	if attack_mode_hint_panel == null:
		return
	attack_mode_hint_panel.visible = true
	attack_mode_hint_panel.modulate.a = 1.0
	if attack_mode_hint_tween != null:
		attack_mode_hint_tween.kill()
	attack_mode_hint_tween = create_tween()
	attack_mode_hint_tween.tween_interval(ATTACK_MODE_HINT_VISIBLE_SECONDS)
	attack_mode_hint_tween.tween_property(attack_mode_hint_panel, "modulate:a", 0.0, ATTACK_MODE_HINT_FADE_SECONDS)
	attack_mode_hint_tween.tween_callback(func() -> void:
		if attack_mode_hint_panel != null:
			attack_mode_hint_panel.visible = false
	)

func _build_developer_panel(root: Control) -> void:
	developer_panel = DEVELOPER_PANEL.new()
	root.add_child(developer_panel)
	developer_panel.level_up_requested.connect(func(): developer_level_up_requested.emit())
	developer_panel.boss_spawn_requested.connect(func(archetype_id: String): developer_boss_spawn_requested.emit(archetype_id))
	developer_panel.small_boss_spawn_requested.connect(func(archetype_id: String): developer_small_boss_spawn_requested.emit(archetype_id))
	developer_panel.normal_enemy_batch_spawn_requested.connect(func(archetype_id: String, count: int): developer_normal_enemy_batch_spawn_requested.emit(archetype_id, count))
	developer_panel.enemy_spawn_requested.connect(func(kind: String, archetype_id: String, count: int): developer_enemy_spawn_requested.emit(kind, archetype_id, count))
	developer_panel.skill_unlock_requested.connect(func(skill_id: String, tier: int): developer_skill_unlock_requested.emit(skill_id, tier))
	developer_panel.skill_talent_grant_requested.connect(func(talent_id: String): developer_skill_talent_grant_requested.emit(talent_id))
	developer_panel.blessing_grant_requested.connect(func(blessing_id: String, tier: int): developer_blessing_grant_requested.emit(blessing_id, tier))
	developer_panel.all_blessings_grant_requested.connect(func(): developer_all_blessings_grant_requested.emit())
	developer_panel.ruan_stone_action_requested.connect(func(action_id: String): developer_ruan_stone_action_requested.emit(action_id))
	developer_panel.enemy_detail_display_toggled.connect(func(enabled: bool): developer_enemy_detail_display_toggled.emit(enabled))
	developer_panel.glutton_skill_test_requested.connect(func(skill_id: String): developer_glutton_skill_test_requested.emit(skill_id))
	developer_panel.endless_tier_test_requested.connect(func(tier: int): developer_endless_tier_test_requested.emit(tier))

func set_developer_invincibility_enabled(enabled: bool) -> void:
	if developer_panel != null and developer_panel.has_method("set_invincibility_enabled"):
		developer_panel.set_invincibility_enabled(enabled)

func set_developer_enemy_detail_display_enabled(enabled: bool) -> void:
	if developer_panel != null and developer_panel.has_method("set_enemy_detail_display_enabled"):
		developer_panel.set_enemy_detail_display_enabled(enabled)

func set_developer_boss_options(options: Array) -> void:
	if developer_panel != null and developer_panel.has_method("set_boss_options"):
		developer_panel.set_boss_options(options)

func set_developer_normal_enemy_options(options: Array) -> void:
	if developer_panel != null and developer_panel.has_method("set_normal_enemy_options"):
		developer_panel.set_normal_enemy_options(options)

func set_developer_enemy_options(options: Array) -> void:
	if developer_panel != null and developer_panel.has_method("set_enemy_options"):
		developer_panel.set_enemy_options(options)

func set_developer_skill_options(options: Array) -> void:
	if developer_panel != null and developer_panel.has_method("set_skill_options"):
		developer_panel.set_skill_options(options)

func set_developer_blessing_options(options: Array) -> void:
	if developer_panel != null and developer_panel.has_method("set_blessing_options"):
		developer_panel.set_blessing_options(options)

func set_developer_ruan_stone_options(options: Array) -> void:
	if developer_panel != null and developer_panel.has_method("set_ruan_stone_options"):
		developer_panel.set_ruan_stone_options(options)

func update_performance_metrics(metrics: Dictionary) -> void:
	if not performance_overlay_visible:
		return
	if developer_panel != null and developer_panel.has_method("update_performance_metrics"):
		developer_panel.update_performance_metrics(metrics)
		return
	_ensure_performance_overlay()
	if performance_overlay_label != null:
		performance_overlay_label.text = PERFORMANCE_MONITOR.format_metrics(metrics)

func toggle_performance_overlay() -> void:
	set_performance_overlay_visible(not performance_overlay_visible)

func set_performance_overlay_visible(visible: bool) -> void:
	performance_overlay_visible = visible
	if performance_overlay_panel != null:
		performance_overlay_panel.visible = visible
	if developer_panel != null:
		if developer_panel.has_method("set_performance_metrics_visible"):
			developer_panel.set_performance_metrics_visible(visible)

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
	performance_overlay_panel.visible = performance_overlay_visible

func update_display(level: int, current_experience: int, required_experience: int) -> void:
	_set_label_text(level_label, "绛夌骇 %d" % level)
	if experience_bar != null:
		var next_max: int = max(required_experience, 1)
		if int(experience_bar.max_value) != next_max:
			experience_bar.max_value = next_max
		if int(experience_bar.value) != current_experience:
			experience_bar.value = current_experience
	_set_label_text(experience_label, "%d / %d XP" % [current_experience, required_experience])
	if combat_skill_bar != null and combat_skill_bar.has_method("update_experience"):
		combat_skill_bar.update_experience(current_experience, required_experience)

func update_health(current_health: float, max_health: float) -> void:
	if health_bar != null:
		var next_max: float = max(max_health, 1.0)
		if health_bar.max_value != next_max:
			health_bar.max_value = next_max
		if health_bar.value != current_health:
			health_bar.value = current_health
	_set_label_text(health_label, "HP %.0f / %.0f" % [current_health, max_health])

func update_mana(current_mana: float, max_mana: float) -> void:
	if mana_bar != null:
		var next_max: float = max(max_mana, 1.0)
		if mana_bar.max_value != next_max:
			mana_bar.max_value = next_max
		if mana_bar.value != current_mana:
			mana_bar.value = current_mana
	_set_label_text(mana_label, "大招能量 %.0f / %.0f" % [current_mana, max_mana])

func update_stats(summary: Dictionary) -> void:
	sync_hud_layout_from_settings()
	_update_attack_mode_hint(bool(summary.get("auto_attack_enabled", false)))
	_update_ruan_stone_status(summary)
	_set_label_text(role_label, "角色 %s" % str(summary.get("role_name", "剑士")))
	var active_role_index := int(summary.get("active_role_index", 0))
	var team_roles: Array = summary.get("team_roles", ["剑士", "枪手", "法师"])
	for index in range(team_role_labels.size()):
		var label := team_role_labels[index]
		var role_name := str(team_roles[index]) if index < team_roles.size() else "-"
		if index == active_role_index:
			_set_label_text(label, "> %s <" % role_name)
			_set_label_modulate(label, Color(1.0, 0.92, 0.45, 1.0))
		else:
			_set_label_text(label, role_name)
			_set_label_modulate(label, Color(0.86, 0.86, 0.86, 1.0))

	var switch_cooldown := float(summary.get("switch_cooldown", 0.0))
	if switch_cd_label != null:
		if switch_cooldown > 0.0:
			_set_label_text(switch_cd_label, "切人 CD %.1f 秒" % switch_cooldown)
		else:
			_set_label_text(switch_cd_label, "切人 CD 就绪")
	if combat_skill_bar != null and combat_skill_bar.has_method("update_switch_cooldown"):
		var switch_energy_by_role_value: Variant = summary.get("switch_energy_by_role", {})
		var switch_energy_by_role: Dictionary = switch_energy_by_role_value if switch_energy_by_role_value is Dictionary else {}
		combat_skill_bar.update_switch_cooldown(
			str(summary.get("role_id", "swordsman")),
			switch_cooldown,
			float(summary.get("switch_cooldown_base", 0.5)),
			float(summary.get("switch_energy", 0.0)),
			float(summary.get("switch_energy_required", 100.0)),
			switch_energy_by_role
		)
	if combat_skill_bar != null and combat_skill_bar.has_method("update_team_role_statuses"):
		var team_role_statuses_value: Variant = summary.get("team_role_statuses", [])
		var team_role_statuses: Array = team_role_statuses_value if team_role_statuses_value is Array else []
		combat_skill_bar.update_team_role_statuses(
			team_role_statuses,
			str(summary.get("role_id", "swordsman")),
			int(summary.get("active_role_index", 0))
		)

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
			_set_label_text(switch_power_label, "切换增益 %s" % " / ".join(switch_buff_parts))
			_set_label_modulate(switch_power_label, Color(1.0, 0.9, 0.5, 0.98))
		else:
			_set_label_text(switch_power_label, "切换增益 无")
			_set_label_modulate(switch_power_label, Color(0.86, 0.9, 0.98, 0.92))

	var current_energy: float = float(summary.get("current_mana", 0.0))
	var required_energy: float = float(summary.get("ultimate_energy_cost", 100.0))
	var ultimate_ready: bool = bool(summary.get("ultimate_ready", false))
	if ultimate_label != null:
		if ultimate_ready:
			_set_label_text(ultimate_label, "大招能量 %.0f / %.0f | 大招就绪" % [current_energy, required_energy])
			_set_label_modulate(ultimate_label, Color(1.0, 0.9, 0.5, 1.0))
		else:
			_set_label_text(ultimate_label, "大招能量 %.0f / %.0f | 大招未就绪" % [current_energy, required_energy])
			_set_label_modulate(ultimate_label, Color(0.88, 0.92, 0.98, 0.96))
	var max_energy: float = max(float(summary.get("max_mana", 1.0)), 1.0)
	if mana_bar != null and mana_bar.max_value != max_energy:
		mana_bar.max_value = max_energy
	if mana_bar != null and mana_bar.value != current_energy:
		mana_bar.value = current_energy
	if combat_skill_bar != null and combat_skill_bar.has_method("update_ultimate_energy"):
		combat_skill_bar.update_ultimate_energy(current_energy, required_energy, summary.get("ultimate_display", {}), ultimate_ready)
	var cooldown_slots: Array = summary.get("skill_cooldown_slots", [])
	if combat_skill_bar != null and combat_skill_bar.has_method("update_skill_cooldown_slots"):
		combat_skill_bar.update_skill_cooldown_slots(cooldown_slots)
	if combat_skill_bar != null and combat_skill_bar.has_method("update_buff_slots"):
		var buff_slots: Array = []
		if switch_power_remaining > 0.0 and switch_power_name != "":
			buff_slots.append({
				"name": switch_power_name,
				"description": "切换增益",
				"remaining": switch_power_remaining,
				"duration": max(switch_power_remaining, 1.0),
				"color": Color(0.36, 0.76, 1.0, 0.92)
			})
		if entry_blessing_remaining > 0.0 and entry_blessing_name != "":
			buff_slots.append({
				"name": entry_blessing_name,
				"description": "入场祝福",
				"remaining": entry_blessing_remaining,
				"duration": max(entry_blessing_remaining, 1.0),
				"color": Color(0.88, 0.64, 1.0, 0.92)
			})
		var status_buff_slots_value: Variant = summary.get("buff_status_slots", [])
		if status_buff_slots_value is Array:
			for status_buff_value in status_buff_slots_value:
				if status_buff_value is Dictionary:
					buff_slots.append(status_buff_value)
		combat_skill_bar.update_buff_slots(buff_slots)


func _update_ruan_stone_status(summary: Dictionary) -> void:
	var bone_count: int = max(0, int(summary.get("ruan_bone_count", 0)))
	var stone_id: String = str(summary.get("equipped_ruan_stone", ""))
	var stone_level: int = max(0, int(summary.get("equipped_ruan_stone_level", 0)))
	var stone_title: String = str(summary.get("equipped_ruan_stone_title", ""))
	if stone_id == "" or stone_level <= 0:
		stone_title = "未装备"
		stone_level = 0
	var stone_text: String = stone_title if stone_level <= 0 else "%s Lv.%d" % [stone_title, stone_level]
	_set_label_text(ruan_stone_status_label, "骨头 %d\n阮石 %s" % [bone_count, stone_text])


func update_time(seconds_elapsed: float) -> void:
	var total_seconds: int = int(floor(seconds_elapsed))
	var minutes: int = int(total_seconds / 60.0)
	var seconds: int = total_seconds % 60
	var prefix := "N%d · " % current_endless_tier if current_endless_tier > 0 else ""
	_set_label_text(time_label, "%s时间 %02d:%02d" % [prefix, minutes, seconds])

func set_endless_tier(tier: int) -> void:
	current_endless_tier = max(0, tier)

func _set_label_text(label: Label, next_text: String) -> void:
	if label == null or label.text == next_text:
		return
	label.text = next_text

func _set_label_modulate(label: Label, next_color: Color) -> void:
	if label == null or label.modulate == next_color:
		return
	label.modulate = next_color

func show_boss_ui(boss_name: String, current_health: float, max_health: float, status_payload: Dictionary = {}, boss_ui_payload: Dictionary = {}) -> void:
	if boss_panel != null:
		boss_panel.visible = true
	if time_label != null:
		time_label.visible = false
	_layout_boss_panels()
	update_boss_ui(boss_name, current_health, max_health, status_payload, boss_ui_payload)

func update_boss_ui(boss_name: String, current_health: float, max_health: float, status_payload: Dictionary = {}, boss_ui_payload: Dictionary = {}) -> void:
	if boss_panel == null:
		return
	boss_name_label.text = boss_name
	var health_max_value: float = max(max_health, 1.0)
	var display_health: float = clamp(current_health, 0.0, health_max_value)
	var shield_max_health: float = max(0.0, float(boss_ui_payload.get("shield_max_health", 0.0)))
	var shield_health: float = clamp(float(boss_ui_payload.get("shield_health", 0.0)), 0.0, shield_max_health)
	var has_shield: bool = shield_max_health > 0.0 and shield_health > 0.0
	boss_health_bar.max_value = health_max_value
	boss_health_bar.value = display_health
	boss_health_bar.offset_top = 44.0 if has_shield else 32.0
	boss_health_bar.offset_bottom = 56.0
	if boss_shield_bar != null:
		boss_shield_bar.max_value = max(shield_max_health, 1.0)
		boss_shield_bar.value = shield_health
		boss_shield_bar.visible = has_shield
	if has_shield:
		boss_health_label.text = "%.0f / %.0f  护盾 %.0f" % [health_max_value, health_max_value, shield_health]
	else:
		boss_health_label.text = "%.0f / %.0f" % [display_health, health_max_value]
	_update_boss_status_ui(status_payload)

func hide_boss_ui() -> void:
	hide_final_boss_ui()
	hide_small_boss_ui()
	if time_label != null:
		time_label.visible = true

func _update_boss_status_ui(status_payload: Dictionary) -> void:
	var remaining: float = float(status_payload.get("remaining", 0.0))
	var duration: float = max(0.001, float(status_payload.get("duration", 0.0)))
	if remaining <= 0.0:
		if boss_status_label != null:
			boss_status_label.visible = false
		if boss_status_bar != null:
			boss_status_bar.visible = false
		return
	if boss_status_label != null:
		boss_status_label.text = "%s %.1fs" % [str(status_payload.get("label", "状态")), remaining]
		boss_status_label.visible = true
	if boss_status_bar != null:
		boss_status_bar.max_value = duration
		boss_status_bar.value = clamp(remaining, 0.0, duration)
		boss_status_bar.visible = true
