extends SceneTree
## Persistent audio controls, isolated category gain, and paused battle settings.
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
const SETTINGS := preload("res://scripts/shared/settings.gd")
const AUDIO := preload("res://scripts/audio/combat_audio.gd")
const MUSIC := preload("res://scripts/audio/music_player.gd")
const CAMPAIGN := preload("res://scripts/campaign/campaign_service.gd")
const CHANNELS := ["master", "music", "sfx", "player_attack", "player_skill", "enemy_attack", "boss", "hurt", "death", "pickup", "rewards"]
const CATEGORIES := ["player_attack", "player_skill", "enemy_attack", "boss", "hurt", "death", "pickup", "rewards"]
var viewport: SubViewport
var shell: Control
var checks := 0
var failures := 0
var capture_dir := ""

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
	call_deferred("run")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func frames(count: int = 4) -> void:
	for _i in count: await process_frame

func send_key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	viewport.push_input(event)
	await frames(2)
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event)
	await frames(2)

func capture(label: String) -> void:
	if capture_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var image := viewport.get_texture().get_image()
	expect(image.get_size() == viewport.size, "capture matches viewport " + str(viewport.size))
	expect(image.save_png(capture_dir.path_join(label + ".png")) == OK, "capture saved " + label)
	print("CAPTURE ", capture_dir.path_join(label + ".png"))

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "all settings and campaign writes use isolated temporary user data")
	if failures: finish(); return
	seed_legacy_settings()
	verify_settings_api()
	if failures: finish(); return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	shell = SHELL.instantiate()
	shell.session.directory = "user://audio_settings_smoke_" + str(Time.get_ticks_usec())
	viewport.add_child(shell)
	await frames(12)
	expect(shell.page == "home" and shell.bgm._active.playing, "real title starts with the saved music gain")
	await verify_audio_mixer()
	await verify_title_settings()
	await verify_battle_pause_settings()
	await verify_settings_reload()
	for dimensions in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		viewport.size = dimensions
		shell.open_page("settings")
		await frames(12)
		await verify_audio_panel(shell.frame, "settings_scroll", dimensions, false)
		await capture("audio-settings-title-%d" % dimensions.x)
		shell.open_page("home")
		await frames(6)
	viewport.queue_free()
	await create_timer(0.3).timeout
	print("CHRONICLE_AUDIO_SETTINGS_RENDER_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

func seed_legacy_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music_volume_linear", 0.7)
	config.set_value("audio", "sfx_volume", 0.65)
	config.set_value("audio", "music_muted", false)
	config.set_value("audio", "retired_mod_key", "keep-me")
	config.set_value("display", "window_mode", "fullscreen")
	config.set_value("keybinds", "interact", KEY_G)
	config.set_value("unknown_extension", "opaque_value", 31)
	expect(config.save(SETTINGS.SETTINGS_PATH) == OK, "seed legacy settings file")
	SETTINGS.cached_config = null

func verify_settings_api() -> void:
	expect(is_equal_approx(SETTINGS.load_audio_volume("master"), 1.0), "new master channel defaults to unity")
	expect(is_equal_approx(SETTINGS.load_audio_volume("music"), 0.7), "old music volume key supplies the compatible default")
	expect(is_equal_approx(SETTINGS.load_audio_volume("sfx"), 0.65), "old SFX volume key supplies the compatible default")
	for category in CATEGORIES:
		expect(is_equal_approx(SETTINGS.load_audio_volume(category), 1.0), "new category defaults to unity: " + category)
	expect(is_equal_approx(SETTINGS.load_sfx_volume(), 0.65), "legacy SFX API remains compatible")
	expect(is_equal_approx(SETTINGS.load_sfx_gain("player_attack"), 0.65), "legacy SFX gain preserves prior output level")
	expect(is_equal_approx(SETTINGS.load_music_gain(), 0.7), "music uses legacy level under unity master")
	expect(SETTINGS.load_window_mode() == SETTINGS.WINDOW_MODE_FULLSCREEN and SETTINGS.load_keycode(SETTINGS.ACTION_INTERACT) == KEY_G, "existing display and keybind settings still load")
	SETTINGS.save_audio_volume("master", 0.6)
	SETTINGS.save_audio_volume("master", NAN)
	SETTINGS.save_audio_volume("music", INF)
	SETTINGS.save_audio_volume("sfx", -INF)
	SETTINGS.save_audio_volume("unknown_channel", 0.2)
	expect(is_equal_approx(SETTINGS.load_audio_volume("master"), 0.6), "non-finite saves leave the existing value intact")
	SETTINGS.save_audio_volume("hurt", 4.0)
	SETTINGS.save_audio_volume("death", -3.0)
	expect(is_equal_approx(SETTINGS.load_audio_volume("hurt"), 1.0) and is_zero_approx(SETTINGS.load_audio_volume("death")), "finite out-of-range saves clamp to [0,1]")
	for index in CHANNELS.size(): SETTINGS.save_audio_volume(CHANNELS[index], 0.2 + float(index) * 0.05)
	SETTINGS.save_audio_muted(true)
	SETTINGS.save_music_muted(true)
	SETTINGS.cached_config = null
	for index in CHANNELS.size():
		expect(is_equal_approx(SETTINGS.load_audio_volume(CHANNELS[index]), 0.2 + float(index) * 0.05), "all eleven channel values survive a disk reload: " + CHANNELS[index])
	expect(SETTINGS.load_audio_muted() and SETTINGS.load_music_muted(), "both mute flags survive disk reload")
	var reloaded := ConfigFile.new()
	expect(reloaded.load(SETTINGS.SETTINGS_PATH) == OK, "settings file remains valid after all saves")
	expect(reloaded.get_value("audio", "retired_mod_key", "") == "keep-me" and int(reloaded.get_value("unknown_extension", "opaque_value", 0)) == 31, "unknown settings remain intact")
	expect(reloaded.get_value("display", "window_mode", "") == "fullscreen" and int(reloaded.get_value("keybinds", "interact", -1)) == KEY_G, "old configuration sections remain intact")
	expect(is_equal_approx(float(reloaded.get_value("audio", "sfx_volume", -1.0)), 0.3) and is_equal_approx(float(reloaded.get_value("audio", "music_volume_linear", -1.0)), 0.25), "legacy audio keys remain present and follow their compatible channels")
	for channel in ["master", "player_attack", "player_skill", "enemy_attack", "boss", "hurt", "death", "pickup", "rewards"]:
		expect(reloaded.has_section_key("audio", channel + "_volume"), "new channel saved under documented key: " + channel)

func verify_audio_mixer() -> void:
	for channel in CHANNELS: SETTINGS.save_audio_volume(channel, 1.0)
	SETTINGS.save_audio_muted(false)
	SETTINGS.save_music_muted(false)
	shell.bgm.apply_saved_volume()
	var audio := AUDIO.new()
	root.add_child(audio)
	audio.listener = Vector2.ZERO
	for category in CATEGORIES:
		expect(audio.play_cue("blade.cast", Vector2.ZERO, {"category":category,"priority":2,"stage":"cast"}), "real cue starts under category control: " + category)
		var slot := record_slot(audio, category)
		expect(slot >= 0 and audio.records[slot].category == category, "voice record stores selected category: " + category)
		if slot >= 0:
			var baseline_db: float = audio.voices[slot].volume_db
			SETTINGS.save_audio_volume(category, 0.5)
			audio._update_gains()
			expect(absf(audio.voices[slot].volume_db - (baseline_db + linear_to_db(0.5))) < 0.15, "live category gain updates the active voice: " + category)
			SETTINGS.save_audio_volume(category, 0.0)
			audio._update_gains()
			expect(audio.records[slot].is_empty() and not audio.voices[slot].playing, "muting category releases its active voice: " + category)
			expect(not audio.play_cue("blade.cast", Vector2.ZERO, {"category":category,"priority":2,"stage":"cast"}), "muted category blocks a new cue: " + category)
		SETTINGS.save_audio_volume(category, 1.0)
		audio.clear()
	SETTINGS.save_audio_volume("player_attack", 0.0)
	expect(not audio.play_cue("blade.cast", Vector2.ZERO, {"category":"player_attack"}), "player attack mute blocks its record")
	expect(audio.play_cue("blade.cast", Vector2.ZERO, {"category":"player_skill"}) and record_slot(audio, "player_skill") >= 0, "player attack mute leaves player skill audible")
	SETTINGS.save_audio_volume("player_attack", 1.0)
	SETTINGS.save_audio_volume("player_skill", 1.0)
	SETTINGS.save_audio_volume("boss", 0.0)
	var duck_before: float = shell.bgm.combat_mix_gain
	audio.music_duck.connect(shell.bgm.set_combat_mix_gain)
	expect(not audio.play_cue("boss_demon.phase", Vector2.ZERO, {"category":"boss","priority":6,"stage":"phase","critical":true}), "muted Boss category blocks its critical cue")
	expect(audio._duck_categories.is_empty() and is_equal_approx(shell.bgm.combat_mix_gain, duck_before), "muted Boss cue contributes no music duck")
	SETTINGS.save_audio_volume("boss", 1.0)
	expect(audio.play_cue("boss_demon.phase", Vector2.ZERO, {"category":"boss","priority":6,"stage":"phase","critical":true}), "audible Boss cue starts")
	expect(audio._duck_categories.has("boss") and shell.bgm.combat_mix_gain < duck_before, "audible Boss warning ducks BGM through its category")
	audio.advance(0.1, true)
	var paused_gain: float = audio.voices[record_slot(audio, "boss")].volume_db
	var paused_remaining: float = float(audio._duck_categories.boss.remaining)
	SETTINGS.save_audio_volume("boss", 0.5)
	audio._update_gains()
	expect(is_equal_approx(audio._duck_categories.boss.remaining, paused_remaining) and audio.voices[record_slot(audio, "boss")].volume_db < paused_gain, "paused mix gain refreshes without moving the pause/duck clocks")
	SETTINGS.save_audio_volume("master", 0.0)
	audio._update_gains()
	shell.bgm.apply_saved_volume()
	expect(is_zero_approx(SETTINGS.load_master_gain()) and shell.bgm._active.volume_db <= -80.0, "master setting covers combat SFX and scene music")
	expect(not audio.play_cue("blade.cast", Vector2.ZERO, {"category":"player_attack"}), "master mute blocks combat cue")
	SETTINGS.save_audio_volume("master", 1.0)
	SETTINGS.save_audio_volume("boss", 1.0)
	SETTINGS.save_music_muted(true)
	shell.bgm.apply_saved_volume()
	expect(shell.bgm._active.volume_db <= -80.0 and SETTINGS.load_sfx_gain("player_attack") > 0.0, "music mute leaves combat SFX enabled")
	SETTINGS.save_music_muted(false)
	SETTINGS.save_audio_muted(true)
	shell.bgm.apply_saved_volume()
	audio._update_gains()
	expect(is_zero_approx(SETTINGS.load_master_gain()) and shell.bgm._active.volume_db <= -80.0, "master mute overrides scene music")
	expect(not audio.play_cue("blade.cast", Vector2.ZERO, {"category":"player_attack"}), "master mute overrides combat SFX")
	SETTINGS.save_audio_muted(false)
	SETTINGS.save_audio_volume("master", 1.0)
	SETTINGS.save_audio_volume("boss", 1.0)
	SETTINGS.save_music_muted(false)
	shell.bgm.apply_saved_volume()
	audio.clear()
	audio.queue_free()
	await frames(3)

func record_slot(audio: Node, category: String) -> int:
	for index in audio.records.size():
		if not audio.records[index].is_empty() and str(audio.records[index].get("category", "")) == category: return index
	return -1

func find_button_text(node: Node, label: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		var button := child as Button
		if button.text == label: return button
	return null

func verify_title_settings() -> void:
	shell.open_page("settings")
	await frames(8)
	var panel := shell.find_child("audio_settings", true, false) as Control
	expect(panel != null, "title settings page uses the shared audio panel")
	if panel == null: return
	var music_slider := panel.find_child("music_volume", true, false) as HSlider
	var master_slider := panel.find_child("master_volume", true, false) as HSlider
	var sfx_slider := panel.find_child("sfx_volume", true, false) as HSlider
	expect(music_slider != null and master_slider != null and sfx_slider != null, "title panel exposes music/master/SFX sliders")
	if music_slider != null: music_slider.value = 0.42
	if master_slider != null: master_slider.value = 0.83
	if sfx_slider != null: sfx_slider.value = 0.61
	await frames(3)
	expect(is_equal_approx(SETTINGS.load_audio_volume("music"), 0.42) and is_equal_approx(SETTINGS.load_audio_volume("master"), 0.83) and is_equal_approx(SETTINGS.load_audio_volume("sfx"), 0.61), "title slider changes save immediately")
	expect(absf(shell.bgm._active.volume_db - linear_to_db(0.83 * 0.42)) < 0.15, "title background music gain changes live")
	var music_mute := panel.find_child("music_muted", true, false) as CheckButton
	var master_mute := panel.find_child("master_muted", true, false) as CheckButton
	expect(music_mute != null and master_mute != null, "title panel exposes music and master mute controls")
	if music_mute != null:
		music_mute.button_pressed = true
		await frames(3)
		expect(shell.bgm._active.volume_db <= -80.0, "title music mute acts immediately")
		music_mute.button_pressed = false
	if master_mute != null:
		master_mute.button_pressed = true
		await frames(3)
		expect(shell.bgm._active.volume_db <= -80.0, "title master mute covers background music")
		master_mute.button_pressed = false
	await frames(3)
	await capture("audio-settings-title-1280")
	shell.open_music()
	await frames(3)
	if shell.music_preview != null:
		shell.play_track(shell.music_tracks.find("midi_test_01"))
		await frames(8)
		expect(shell.music_preview.playing and absf(shell.music_preview.volume_linear - SETTINGS.load_music_gain()) < 0.02, "music room preview follows master/music gain")
		var before: float = shell.music_preview.get_playback_position()
		SETTINGS.save_audio_volume("master", 0.5)
		await frames(3)
		await create_timer(0.12).timeout
		expect(absf(shell.music_preview.volume_linear - SETTINGS.load_music_gain()) < 0.02, "master change applies to active music preview gain (actual %.3f expected %.3f)" % [shell.music_preview.volume_linear, SETTINGS.load_music_gain()])
		expect(shell.music_preview.get_playback_position() > before, "master change does not restart active music preview (%.3f -> %.3f)" % [before, shell.music_preview.get_playback_position()])
		SETTINGS.save_audio_volume("master", 0.83)
		SETTINGS.save_audio_muted(true)
		await frames(3)
		expect(is_zero_approx(shell.music_preview.volume_linear), "master mute covers music-room preview")
		SETTINGS.save_audio_muted(false)
		SETTINGS.save_music_muted(true)
		await frames(3)
		expect(is_zero_approx(shell.music_preview.volume_linear) and SETTINGS.load_sfx_gain("player_attack") > 0.0, "music mute covers preview without muting combat effects")
		SETTINGS.save_music_muted(false)
	shell.open_page("home")
	await frames(8)

func verify_battle_pause_settings() -> void:
	shell.session = CAMPAIGN.new()
	shell.session.directory = "user://audio_settings_battle_" + str(Time.get_ticks_usec())
	shell.session.data.reward_seed = 771209
	var began: bool = shell.session.begin_campaign()
	var resolved: bool = shell.session.resolve_event() if began else false
	expect(began and resolved, "real campaign fixture reaches the first battle")
	if not began or not resolved: return
	shell.start_battle()
	await frames(12)
	var view: Control = shell.battle_view
	expect(is_instance_valid(view) and view.battle != null and shell.page == "battle", "real B01 battle starts")
	if not is_instance_valid(view): return
	var combat_audio: Node = view.canvas.combat_feedback.audio
	combat_audio.clear()
	combat_audio.listener = view.battle.position
	var attack_started: bool = combat_audio.play_cue("blade.cast", view.battle.position, {"category":"player_attack","priority":2,"stage":"cast"})
	expect(attack_started, "real combat voice starts before pausing (enabled=%s paused=%s master=%.2f sfx=%.2f category=%.2f missing=%d limited=%d)" % [combat_audio.enabled, combat_audio.paused, SETTINGS.load_master_gain(), SETTINGS.load_audio_volume("sfx"), SETTINGS.load_audio_volume("player_attack"), combat_audio.counters.missing, combat_audio.counters.limited])
	view.toggle_pause()
	await frames(8)
	expect(view.battle.paused and not shell.frame.visible and not view.pause_audio_open and view.overlay != null, "pause menu freezes the live battle over the hidden shell frame")
	var audio_button := view.find_child("battle_audio_settings", true, false) as Button
	expect(audio_button != null and audio_button.is_visible_in_tree(), "pause menu exposes Sounds settings")
	if audio_button != null: audio_button.pressed.emit()
	await frames(8)
	expect(view.pause_audio_open and view.battle.paused and shell.page == "battle" and shell.battle_view == view, "opening audio subpage keeps the current paused battle")
	var attack_slot := record_slot(combat_audio, "player_attack")
	var attack_db_before: float = combat_audio.voices[attack_slot].volume_db if attack_slot >= 0 else 0.0
	var attack_gain_before: float = SETTINGS.load_audio_volume("player_attack")
	var frozen := battle_signature(view)
	for dimensions in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		viewport.size = dimensions
		await frames(14)
		await verify_audio_panel(view, "audio_channels_scroll", dimensions, true)
		var back := view.find_child("battle_audio_back", true, false) as Button
		var resume := view.find_child("battle_resume", true, false) as Button
		expect(back != null and resume != null and back.is_visible_in_tree() and resume.is_visible_in_tree(), "battle audio return and resume remain visible " + str(dimensions))
		if back != null: expect(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(back.get_global_rect()), "battle audio return fits viewport " + str(dimensions))
		if resume != null: expect(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(resume.get_global_rect()), "battle resume fits viewport " + str(dimensions))
		await capture("audio-settings-battle-%d" % dimensions.x)
		var slider := view.find_child("player_attack_volume", true, false) as HSlider
		if slider != null: slider.value = 0.54
		await frames(10)
		expect(battle_signature(view) == frozen, "editing sliders while paused leaves battle state and clocks frozen " + str(dimensions))
		if dimensions == Vector2i(960, 540) and attack_slot >= 0:
			expect(absf(combat_audio.voices[attack_slot].volume_db - (attack_db_before + linear_to_db(0.54 / attack_gain_before))) < 0.15, "paused combat voice gain follows category slider live")
	viewport.size = Vector2i(1280, 720)
	await frames(6)
	var slider := view.find_child("player_attack_volume", true, false) as HSlider
	if slider != null:
		var previous := slider.value
		slider.grab_focus()
		await send_key(KEY_RIGHT)
		expect(slider.value > previous and is_equal_approx(SETTINGS.load_audio_volume("player_attack"), slider.value), "focused audio slider responds to arrow keys and saves")
		expect(view.pause_audio_open and view.battle.paused and battle_signature(view) == frozen, "keyboard slider navigation does not resume or advance the battle")
	await send_key(KEY_ESCAPE)
	expect(not view.pause_audio_open and view.battle.paused and shell.page == "battle", "first Esc returns from audio settings to battle pause")
	await frames(4)
	frozen = battle_signature(view)
	var reopen := view.find_child("battle_audio_settings", true, false) as Button
	if reopen != null: reopen.pressed.emit()
	await frames(6)
	expect(view.pause_audio_open and view.battle.paused, "pause menu can reopen audio subpage")
	await send_key(KEY_ESCAPE)
	expect(not view.pause_audio_open and view.battle.paused, "Esc from the reopened audio page remains in pause menu")
	var continue_button := view.find_child("battle_resume", true, false) as Button
	if continue_button != null: continue_button.pressed.emit()
	await frames(8)
	expect(not view.battle.paused and not view.pause_audio_open and shell.page == "battle", "continue resumes the same battle only after leaving pause")
	var before_elapsed: float = view.battle.director.elapsed
	view.set_physics_process(true)
	await create_timer(0.12).timeout
	view.set_physics_process(false)
	expect(view.battle.director.elapsed > before_elapsed and shell.battle_view == view, "battle advances normally after explicit resume")
	view.toggle_pause()
	await frames(5)
	var leave := find_button_text(view.overlay, "撤回进关前")
	if leave != null: leave.pressed.emit()
	await frames(12)
	expect(shell.page != "battle" and not shell.session.in_battle, "leaving battle after audio edits retains the existing abandon/resume flow")

func verify_audio_panel(parent: Node, scroll_id: String, dimensions: Vector2i, fixed_footer: bool) -> void:
	var panel := parent.find_child("audio_settings", true, false) as Control
	expect(panel != null, "shared audio settings panel exists in " + str(parent))
	if panel == null: return
	var scroll := parent.find_child(scroll_id, true, false) as ScrollContainer
	expect(scroll != null, "audio settings controls are in the expected scroll area " + scroll_id)
	if scroll == null: return
	for channel in CHANNELS:
		var slider := panel.find_child(channel + "_volume", true, false) as HSlider
		expect(slider != null and slider.is_visible_in_tree(), "all eleven sliders exist and can be scrolled to: " + channel)
		if slider == null: continue
		scroll.ensure_control_visible(slider)
		await frames(2)
		var scroll_rect := scroll.get_global_rect()
		expect(slider.get_global_rect().intersects(scroll_rect), "slider scroll-reveals into the viewport: " + channel + " at " + str(dimensions))
	expect(panel.find_child("master_muted", true, false) is CheckButton and panel.find_child("music_muted", true, false) is CheckButton, "panel includes total and music mute controls")
	if fixed_footer:
		var back := parent.find_child("battle_audio_back", true, false) as Button
		var resume := parent.find_child("battle_resume", true, false) as Button
		expect(back != null and resume != null, "battle audio panel has fixed back and resume actions")

func battle_signature(view: Control) -> String:
	var battle: RefCounted = view.battle
	var enemies: Array = []
	for enemy in battle.enemies:
		enemies.append([enemy.id, enemy.hp, enemy.position, enemy.cooldown, enemy.windup, enemy.action_serial, enemy.form_index])
	var characters := {}
	for id in battle.characters:
		var person: RefCounted = battle.characters[id]
		characters[id] = [person.hp, person.mp, person.xp, person.level, person.cooldowns.duplicate(true), person.shield, person.haste]
	var voice_state: Array = []
	var feedback: Node = view.canvas.combat_feedback if view.canvas.get("combat_feedback") != null else null
	if feedback != null and is_instance_valid(feedback.audio):
		for record in feedback.audio.records:
			voice_state.append([record.get("cue", ""), record.get("category", ""), record.get("remaining", 0.0)])
	return JSON.stringify({"elapsed":battle.director.elapsed,"rng":battle.director.rng.state,"spawn_remaining":battle.director.spawn_remaining,"wave_cursor":battle.director.wave_cursor,"serial":battle.director.serial,"position":battle.position,"cast_serial":battle.cast_serial,"paused":battle.paused,"enemies":enemies,"characters":characters,"audio_clock":feedback.audio.clock if feedback != null else -1.0,"voices":voice_state})

func verify_settings_reload() -> void:
	shell.open_page("home")
	await frames(4)
	SETTINGS.cached_config = null
	shell.open_page("settings")
	await frames(6)
	var panel := shell.find_child("audio_settings", true, false) as Control
	if panel != null:
		for channel in CHANNELS:
			var slider := panel.find_child(channel + "_volume", true, false) as HSlider
			expect(slider != null and is_equal_approx(slider.value, SETTINGS.load_audio_volume(channel)), "reopened title page reloads saved slider value: " + channel)
	shell.open_page("home")
	await frames(6)

func finish() -> void:
	print("CHRONICLE_AUDIO_SETTINGS_RENDER_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
