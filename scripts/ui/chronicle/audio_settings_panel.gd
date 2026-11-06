extends VBoxContainer
## The title settings and paused battle share the same persistent audio controls.
const SETTINGS := preload("res://scripts/shared/settings.gd")
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const CHANNELS := [
	["master", "总音量"],
	["music", "背景音乐"],
	["sfx", "音效总音量"],
	["player_attack", "角色普攻"],
	["player_skill", "角色技能与支援"],
	["enemy_attack", "怪物攻击"],
	["boss", "Boss 技能与提示"],
	["hurt", "角色受击与护盾"],
	["death", "敌人死亡"],
	["pickup", "经验拾取"],
	["rewards", "升级与奖励"],
]
var compact := false

func _ready() -> void:
	name = "audio_settings"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6 if compact else 10)
	add_child(T.paragraph("更改后自动保存", T.MUTED, 13 if compact else 14))
	for index in CHANNELS.size():
		if index == 3:
			_add_mute_controls()
			add_child(HSeparator.new())
		_add_volume(str(CHANNELS[index][0]), str(CHANNELS[index][1]))
	add_child(T.paragraph("Boss 提示包含预警、形态变化和击败音；敌人死亡不含 Boss。", T.MUTED, 13))

func _add_volume(channel: String, caption: String) -> void:
	var row := T.row(self)
	row.add_theme_constant_override("separation", 10 if compact else 16)
	row.custom_minimum_size.y = 34 if compact else 40
	var label := T.label(caption, 15 if compact else 17)
	label.custom_minimum_size.x = 142 if compact else 174
	row.add_child(label)
	var slider := HSlider.new()
	slider.name = channel + "_volume"
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(100, 30)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.scrollable = false
	slider.value = SETTINGS.load_audio_volume(channel)
	slider.tooltip_text = caption
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var focus := T.box(Color.TRANSPARENT, T.GOLD, 0)
	focus.set_border_width_all(2)
	slider.add_theme_stylebox_override("focus", focus)
	row.add_child(slider)
	var amount := T.label("%d%%" % roundi(slider.value * 100.0), 15 if compact else 16)
	amount.name = channel + "_amount"
	amount.custom_minimum_size.x = 48 if compact else 58
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(amount)
	slider.value_changed.connect(func(value: float):
		SETTINGS.save_audio_volume(channel, value)
		amount.text = "%d%%" % roundi(value * 100.0))

func _add_mute_controls() -> void:
	var row := T.row(self)
	for channel in ["master", "music"]:
		var is_master: bool = channel == "master"
		var muted := CheckButton.new()
		muted.name = channel + "_muted"
		muted.text = "总静音" if is_master else "音乐静音"
		muted.custom_minimum_size.y = 34
		muted.button_pressed = SETTINGS.load_audio_muted() if is_master else SETTINGS.load_music_muted()
		muted.toggled.connect(func(value: bool):
			if is_master: SETTINGS.save_audio_muted(value)
			else: SETTINGS.save_music_muted(value))
		row.add_child(muted)
