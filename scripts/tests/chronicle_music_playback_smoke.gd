extends SceneTree
## Production BGM, graphics display and real Ogg playback with the Dummy audio driver.
## This proves decode/timeline/UI behavior, not acoustic listening or artistic acceptance.
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
const CATALOG := preload("res://scripts/audio/music_catalog.gd")
const BGM := preload("res://scripts/bgm_player.gd")
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
	expect(CATALOG.chapter_cues().size() == 70, "published 70-cue catalog required")
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
	expect(music.current_cue == "world_map" and music._active.playing and music._outgoing == null, "world page completes real bed crossfade")
	# Explicit audition of the published sync-safe phase pair, using the production BGM.
	music.restart_cue("boss_lubu")
	await settle()
	music._active.seek(9.0)
	await settle()
	var human_position: float = music.get_saved_playback_position()
	music.set_cue("boss_lubu_warform", 0.65)
	var war_position: float = music.stored_playback_position
	var outgoing_at_commit: float = music._outgoing.get_playback_position()
	expect(absf(war_position - outgoing_at_commit) < 0.12, "actual phase replacement starts on outgoing timeline within one Dummy mixer block")
	await settle(0.2)
	expect(music.get_saved_playback_position() > war_position + 0.08, "warform stream continues advancing after phase replacement")
	print("PLAYBACK phase human=", human_position, " outgoing_at_commit=", outgoing_at_commit, " war_start=", war_position, " war_later=", music.get_saved_playback_position())
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
	shell.play_track(shell.music_tracks.find("character_lingqi"))
	await settle(0.2)
	expect(shell.music_preview.playing and shell.music_preview.get_playback_position() > 0.05, "music room preview decodes and advances actual chapter Ogg")
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
	music.play_stinger("stinger_victory", "results_flow")
	await settle(0.1)
	expect(music._stinger.playing and music._duck_gain < 1.0, "real short overlay plays independently and ducks bed")
	music.pause_music()
	await settle(0.06)
	var overlay_position: float = music._stinger.get_playback_position()
	var overlay_remaining: float = music._stinger_remaining
	await settle(0.15)
	expect(music._stinger.stream_paused and absf(music._stinger.get_playback_position() - overlay_position) <= 0.025 and is_equal_approx(music._stinger_remaining, overlay_remaining), "pause freezes real overlay position and fade clock")
	music.resume_music()
	music._stinger.seek(music._stinger.stream.get_length() - 0.04)
	await settle(0.25)
	expect(music._stinger_cue.is_empty() and music._duck_gain == 1.0 and music.current_cue == "results_flow", "native short-overlay completion releases duck and starts results bed")
	BGM.save_music_muted(true)
	music.apply_saved_volume()
	expect(music._active.volume_db <= -80.0, "live settings mute actual playback")
	BGM.save_music_muted(muted)
	BGM.save_music_volume(volume)
	viewport.queue_free()
	await settle(0.15)
	print("CHRONICLE_MUSIC_PLAYBACK_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures, " display=", DisplayServer.get_name())
	quit(1 if failures else 0)

func wait_for_position(music: AudioStreamPlayer, threshold: float) -> void:
	# Dummy mixing and llvmpipe rendering share a loaded CI host. Require real
	# advancement, allowing at most 1.5s of wall-clock scheduling latency.
	var deadline := Time.get_ticks_msec() + 1500
	while music.get_saved_playback_position() <= threshold and Time.get_ticks_msec() < deadline:
		await settle(0.1)
