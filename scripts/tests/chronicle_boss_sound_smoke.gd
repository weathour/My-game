extends SceneTree
## Bounded original PCM plus real player mute/pause/lifetime checks; no listening claim.
const SOUND := preload("res://scripts/ui/chronicle/boss_sound.gd")
const FEEDBACK := preload("res://scripts/ui/chronicle/boss_feedback.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")
var checks := 0
var failures := 0
var export_dir := ""
var measurements: Dictionary = {}

func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--export="): export_dir = argument.trim_prefix("--export=")
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated sound settings")
	if failures: quit(1); return
	if not export_dir.is_empty(): DirAccess.make_dir_recursive_absolute(export_dir)
	for cue in SOUND.DURATIONS:
		var stream: AudioStreamWAV = SOUND.create(cue)
		var count := stream.data.size() / 2
		var peak := 0.0
		var energy := 0.0
		var tail_energy := 0.0
		for index in count:
			var sample := float(stream.data.decode_s16(index * 2)) / 32768.0
			peak = maxf(peak, absf(sample))
			energy += sample * sample
			if index > count * .8: tail_energy += sample * sample
		var rms := sqrt(energy / count)
		var tail_rms := sqrt(tail_energy / maxf(1,count * .2))
		expect(absf(stream.get_length() - float(SOUND.DURATIONS[cue])) < 1.0 / SOUND.RATE, cue + " exact short duration")
		expect(stream.get_length() <= .5 and stream.mix_rate == SOUND.RATE and not stream.stereo, cue + " bounded mono PCM")
		expect(peak > .10 and peak < .90 and rms > .015, cue + " audible signal with unclipped headroom")
		expect(peak * FEEDBACK.MAX_VOICES * FEEDBACK.MAX_GAIN < .98, cue + " three-voice pool keeps full-volume PCM headroom")
		expect(stream.data.decode_s16(0) == 0 and abs(stream.data.decode_s16(stream.data.size() - 2)) < 100, cue + " click-free sample endpoints")
		expect(tail_rms < rms * .55, cue + " decays before its endpoint")
		measurements[cue] = {"seconds":stream.get_length(),"peak":peak,"rms":rms,"tail_rms":tail_rms,"sample_rate":stream.mix_rate,"original_synthesis":true,"listening_review":false,"max_voice_gain":FEEDBACK.MAX_GAIN,"three_voice_peak_bound":peak * FEEDBACK.MAX_VOICES * FEEDBACK.MAX_GAIN}
		if not export_dir.is_empty(): expect(stream.save_to_wav(export_dir.path_join(cue + ".wav")) == OK, cue + " WAV export")
	var feedback := FEEDBACK.new()
	root.add_child(feedback)
	await process_frame
	expect(feedback.voices.size() == 3, "audio voice pool is bounded at three")
	var old_volume := SETTINGS.load_sfx_volume()
	SETTINGS.save_sfx_volume(0)
	feedback.consume([{"kind":"boss_impact","position":Vector2.ZERO}])
	var playing := false
	for voice in feedback.voices: playing = playing or voice.playing
	expect(not playing, "mute setting starts no playback")
	if DisplayServer.get_name() != "headless":
		SETTINGS.save_sfx_volume(.65)
		feedback.consume([{"kind":"boss_phase","position":Vector2.ZERO}])
		playing = false
		for voice in feedback.voices: playing = playing or voice.playing
		expect(playing, "nonzero setting plays the actual combat stream")
		feedback.advance(0, true, "")
		var paused := true
		for voice in feedback.voices:
			if voice.stream != null: paused = paused and voice.stream_paused
		expect(paused, "pause suspends all attempt-owned voices")
	feedback.clear()
	playing = false
	for voice in feedback.voices: playing = playing or voice.playing or voice.stream != null
	expect(not playing and feedback.sounds.is_empty(), "terminal cleanup releases playing and cached streams")
	feedback.queue_free()
	await process_frame
	if DisplayServer.get_name() != "headless": await create_timer(.12).timeout
	SETTINGS.save_sfx_volume(old_volume)
	if not export_dir.is_empty():
		var file := FileAccess.open(export_dir.path_join("sound-measurements.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(measurements,"  "))
	print("CHRONICLE_BOSS_SOUND_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
