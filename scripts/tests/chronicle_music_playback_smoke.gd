extends SceneTree
## Production BGM, graphics display and real Ogg playback with the Dummy audio driver.
## This proves decode/timeline/UI behavior, not acoustic listening or artistic acceptance.
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
const CATALOG := preload("res://scripts/audio/music_catalog.gd")
const BGM := preload("res://scripts/audio/music_player.gd")
const FEEDBACK := preload("res://scripts/ui/chronicle/combat_feedback.gd")
const SETTINGS := preload("res://scripts/shared/settings.gd")
var checks := 0
var failures := 0
var capture_dir := ""

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
	call_deferred("run")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func settle(seconds: float = 0.15) -> void:
	await create_timer(seconds, true, false, true).timeout
	await process_frame

func capture(viewport: SubViewport, name: String) -> void:
	if capture_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var image := viewport.get_texture().get_image()
	expect(image.get_size() == viewport.size, "capture preserves requested viewport size")
	expect(image.save_png(capture_dir.path_join(name + ".png")) == OK, "capture saved: " + name)
	print("CAPTURE ", capture_dir.path_join(name + ".png"))

func run() -> void:
	expect(DisplayServer.get_name() != "headless", "requires a real graphics display; run under Xvfb")
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated user data required")
	expect(CATALOG.chapter_cues().size() == 16, "published 16-cue catalog required")
	for cue: String in CATALOG.chapter_cues(): expect(ResourceLoader.exists(CATALOG.path(cue)), "real Ogg imported: " + cue)
	if failures: quit(1); return
	var muted := BGM.load_music_muted()
	var volume := BGM.load_music_volume()
	BGM.save_music_muted(false)
	BGM.save_music_volume(0.25)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var shell := SHELL.instantiate()
	shell.session.directory = "user://chronicle_music_playback/" + str(Time.get_ticks_usec())
	viewport.add_child(shell)
	await settle(0.3)
	var music: AudioStreamPlayer = shell.bgm
	expect(not music._is_headless_runtime() and music._active.playing, "production title BGM actually starts its Ogg stream")
	var first: float = music.get_saved_playback_position()
	await wait_for_position(music, first + 0.08)
	var later: float = music.get_saved_playback_position()
	expect(later > first + 0.08, "production title playback advances")
	print("PLAYBACK title ", first, " -> ", later)
	shell.open_page("world")
	await settle(1.6)
	expect(music.current_cue == "midi_test_11" and music._active.playing and music._outgoing == null, "world page completes real bed crossfade")
	# Boss form signals use the same whole-song resource, preserving the active voice.
	music.restart_cue("midi_test_01")
	await settle()
	music._active.seek(9.0)
	await settle()
	var before_form: float = music.get_saved_playback_position()
	var active: AudioStreamPlayer = music._active
	music.set_cue("midi_test_01", 0.65)
	expect(music._active == active and music._outgoing == null, "same battle cue never replaces or crossfades its actual voice")
	await settle(0.2)
	expect(music.get_saved_playback_position() > before_form + 0.08, "same-song form transition continues actual playback")
	music.set_cue("midi_test_11", 0.65)
	await settle(0.1)
	music.pause_music()
	var paused_position: float = music.get_saved_playback_position()
	await settle(0.2)
	expect(music.paused_by_script and music._active.stream_paused and music._outgoing.stream_paused, "pause freezes both actual crossfade voices")
	expect(is_equal_approx(music.get_saved_playback_position(), paused_position), "pause preserves authoritative playback position")
	music.resume_music()
	await settle()
	expect(music.get_saved_playback_position() > paused_position + 0.05, "resume advances from paused position")
	music.context_id = "page:world"
	music.pause_music()
	var before_room: Dictionary = music.capture_snapshot()
	shell.open_music()
	for index in range(1, 13):
		var cue := "midi_test_%02d" % index
		shell.play_track(shell.music_tracks.find(cue))
		await wait_for_preview(shell.music_preview, cue)
		expect(shell.music_preview.stream is AudioStreamOggVorbis and shell.music_preview.playing and shell.music_preview.get_playback_position() > 0.04, "music room actually decodes and advances published D2 cue: " + cue)
		expect(not shell.music_preview.stream.loop, "music room D2 preview remains one-shot: " + cue)
	shell.play_track(shell.music_tracks.find("midi_test_08"))
	await settle(0.2)
	expect(shell.music_preview.playing and shell.music_preview.get_playback_position() > 0.05, "music room preview decodes and advances actual chapter Ogg")
	expect(is_equal_approx(shell.music_preview.volume_linear, 0.25), "preview honors saved music volume")
	var pause := shell.frame.find_child("music_pause", true, false) as Button
	pause.pressed.emit()
	await settle(0.1)
	var preview_paused: float = shell.music_preview.get_playback_position()
	await settle(0.15)
	expect(shell.music_preview.stream_paused and absf(shell.music_preview.get_playback_position() - preview_paused) <= 0.025, "music room pause freezes actual preview position")
	pause = shell.frame.find_child("music_pause", true, false) as Button
	pause.pressed.emit()
	await settle(0.15)
	expect(not shell.music_preview.stream_paused and shell.music_preview.get_playback_position() > preview_paused + 0.05, "music room resumes its preview from paused position (%.3f -> %.3f; paused=%s playing=%s)" % [preview_paused, shell.music_preview.get_playback_position(), shell.music_preview.stream_paused, shell.music_preview.playing])
	BGM.save_music_muted(true)
	shell._process(0.016)
	expect(is_zero_approx(shell.music_preview.volume_linear), "preview responds to music mute")
	BGM.save_music_muted(false)
	shell._process(0.016)

	var seek := shell.frame.find_child("music_seek", true, false) as HSlider
	seek.drag_started.emit()
	seek.value = 18.0
	shell._process(0.016)
	expect(is_equal_approx(seek.value, 18.0), "playback refresh does not pull the thumb while dragging")
	seek.drag_ended.emit(true)
	await settle(0.15)
	expect(absf(shell.music_preview.get_playback_position() - 18.15) < 0.2, "music room progress slider seeks the actual Ogg")
	await capture(viewport, "music-room-1280")
	viewport.size = Vector2i(960, 600)
	await settle(0.2)
	await capture(viewport, "music-room-960")
	shell.open_page("world")
	expect(music.capture_snapshot() == before_room, "leaving music room restores exact prior cue/position/paused/context")
	music.resume_music()
	await wait_for_position(music, float(before_room.position) + 0.05)
	expect(music.get_saved_playback_position() > float(before_room.position) + 0.05, "restored bed resumes from original timeline")
	# Full-song looping includes the ending; previews remain one-shot.
	music.restart_cue("midi_test_03")
	var length: float = music._active.stream.get_length()
	music._active.seek(length - 0.10)
	await settle(0.35)
	expect(music._active.playing and music.get_saved_playback_position() < 1.0 and music._active.stream.loop, "scene playback repeats whole song from zero after its real ending")
	music.restore_snapshot({"cue":"stinger_victory", "position":42.0, "started":true, "paused":false})
	await settle(0.1)
	expect(music.current_cue == "midi_test_11" and music.get_saved_playback_position() < 1.0 and music._active.playing, "obsolete snapshot decodes new fallback freshly")
	await verify_master_mix(music)
	BGM.save_music_muted(true)
	music.apply_saved_volume()
	expect(music._active.volume_db <= -80.0, "live settings mute actual playback")
	BGM.save_music_muted(muted)
	BGM.save_music_volume(volume)
	viewport.queue_free()
	await settle(0.15)
	print("CHRONICLE_MUSIC_PLAYBACK_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures, " display=", DisplayServer.get_name())
	quit(1 if failures else 0)

func wait_for_preview(preview: AudioStreamPlayer, cue: String) -> void:
	# SceneTreeTimer can consume a long process delta before the audio thread
	# advances. Require the same real playback evidence within a wall-clock bound.
	var started := Time.get_ticks_msec()
	var deadline := started + 1500
	while not (preview.stream is AudioStreamOggVorbis and preview.playing and preview.get_playback_position() > 0.04) and Time.get_ticks_msec() < deadline:
		await process_frame
	if not (preview.stream is AudioStreamOggVorbis and preview.playing and preview.get_playback_position() > 0.04):
		print("PREVIEW_WAIT_TIMEOUT ", JSON.stringify({"cue":cue, "elapsed_ms":Time.get_ticks_msec() - started, "stream_type":preview.stream.get_class() if preview.stream else "null", "playing":preview.playing, "position":preview.get_playback_position()}))

func wait_for_position(music: AudioStreamPlayer, threshold: float) -> void:
	# Dummy mixing and llvmpipe rendering share a loaded CI host. Require real
	# advancement, allowing at most 1.5s of wall-clock scheduling latency.
	var deadline := Time.get_ticks_msec() + 1500
	while music.get_saved_playback_position() <= threshold and Time.get_ticks_msec() < deadline:
		await settle(0.1)

func verify_master_mix(music: AudioStreamPlayer) -> void:
	var previous_sfx := SETTINGS.load_sfx_volume()
	var previous_music := BGM.load_music_volume()
	SETTINGS.save_sfx_volume(0.65)
	BGM.save_music_volume(BGM.DEFAULT_VOLUME_LINEAR)
	music.apply_saved_volume()
	music.restart_cue("midi_test_03")
	music._active.seek(12.0)
	var feedback := FEEDBACK.new()
	root.add_child(feedback)
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 2.0
	var effect_index := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, capture)
	var frames_captured := 0
	var peak := 0.0
	var square_sum := 0.0
	var finite := true
	for index in 12:
		feedback.advance(0.08, false, "")
		feedback._sound("cast_blade", 1, 1.0)
		feedback._sound("hit_light", 2, 1.0)
		feedback._sound("magic", 3, 1.0)
		await settle(0.08)
		var buffer := capture.get_buffer(capture.get_frames_available())
		frames_captured += buffer.size()
		for sample: Vector2 in buffer:
			finite = finite and is_finite(sample.x) and is_finite(sample.y)
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
			square_sum += sample.x * sample.x + sample.y * sample.y
	var rms := sqrt(square_sum / maxf(1.0, frames_captured * 2.0))
	expect(frames_captured > 4000 and rms > 0.0001, "Master capture contains real music and common SFX samples")
	expect(finite and peak < 1.0 and capture.get_discarded_frames() == 0, "default music0.7/SFX0.65 mix remains finite and unclipped without capture loss")
	print("MIX_CAPTURE ", JSON.stringify({"cue":"midi_test_03", "start_seconds":12.0, "music_gain":BGM.DEFAULT_VOLUME_LINEAR, "sfx_gain":0.65, "categories":["cast_blade", "hit_light", "magic"], "frames":frames_captured, "sample_peak":peak, "rms":rms, "finite":finite}))
	AudioServer.remove_bus_effect(0, effect_index)
	feedback.queue_free()
	SETTINGS.save_sfx_volume(previous_sfx)
	BGM.save_music_volume(previous_music)
	music.apply_saved_volume()
