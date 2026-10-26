extends SceneTree

const ROOM := preload("res://scripts/ui/main_menu/music_room.gd")
const CATALOG := preload("res://scripts/audio/music_catalog.gd")
const BGM := preload("res://scripts/bgm_player.gd")

class AudibleBgm:
	extends "res://scripts/bgm_player.gd"
	func _is_headless_runtime() -> bool:
		return false

var failures := 0
var closed_count := 0

func _init() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func frames(count: int = 3) -> void:
	for _i in count:
		await process_frame

func run() -> void:
	check(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "music room smoke needs isolated XDG data")
	if failures > 0:
		quit(1)
		return
	BGM.save_music_muted(false)
	BGM.save_music_volume(0.25)
	var opener := Button.new()
	opener.text = "音乐鉴赏"
	root.add_child(opener)
	opener.grab_focus()
	var host := Node.new()
	root.add_child(host)
	var menu_music := AudioStreamPlayer.new()
	menu_music.name = "MenuBGM"
	menu_music.set_script(AudibleBgm)
	host.add_child(menu_music)
	await frames()
	menu_music.start_music(41.0)
	await frames()
	var original_position: float = menu_music.get_saved_playback_position()
	var room := ROOM.new()
	root.add_child(room)
	await frames()
	room.open(menu_music)
	await frames()
	check(room.visible and menu_music.paused_by_script, "opening pauses menu BGM before preview")
	check(room._track_buttons.size() == 14, "all 14 cues are listed")
	check(room._track_title.text == CATALOG.TRACK_INFO.camp_signal.title and room._track_scene.text.contains("主菜单"), "selected track shows title and Chinese scene")
	check(room._preview.playing and not menu_music._active.playing, "preview starts without overlapping menu BGM")
	for index in CATALOG.CUES.size():
		room._set_track(index, true)
		check(room._preview.stream != null and room._preview.playing, "cue plays: " + str(CATALOG.CUES[index]))
		check(not (room._preview.stream as AudioStreamOggVorbis).loop, "audition cue ends instead of repeating: " + str(CATALOG.CUES[index]))
	room._toggle_playback()
	check(room._preview.stream_paused, "pause control pauses preview")
	room._toggle_playback()
	check(not room._preview.stream_paused, "play control resumes preview")
	room._set_track(0, true)
	room._preview.stream_paused = true
	room._seek.grab_focus()
	room._seek.value = 5.0
	check(absf(room._preview.get_playback_position() - 5.0) < 0.5, "progress slider seeks within the selected cue")
	room._seeking = true
	room._seek.value = 9.0
	room._process(0.016)
	check(is_equal_approx(room._seek.value, 9.0), "playback updates do not pull the thumb away while dragging")
	room._on_seek_drag_ended(true)
	room._preview.stream_paused = false
	room._next()
	check(room._selected_index == 1 and room._track_title.text == CATALOG.TRACK_INFO.stage_frontpost.title, "next advances the catalog")
	room._previous()
	check(room._selected_index == 0, "previous returns to the preceding cue")
	room._set_track(CATALOG.CUES.size() - 1, true)
	room._on_track_finished()
	check(room._selected_index == 0, "a finished cue continues at the first track")
	BGM.save_music_muted(true)
	room._apply_preview_volume()
	room._update_mute_status()
	check(room._mute_status.text == "静音已开启" and room._preview.volume_db == BGM.MUTED_VOLUME_DB, "existing mute setting remains visible and respected")
	room.closed.connect(func(): closed_count += 1)
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	room._unhandled_key_input(escape)
	await frames()
	check(closed_count == 1 and not room.visible and room._preview == null, "Escape closes and releases preview")
	check(not menu_music.paused_by_script and menu_music._active.playing, "closing resumes home music")
	check(absf(menu_music.get_saved_playback_position() - original_position) < 1.0, "closing restores the original menu position")
	check(BGM.load_music_muted(), "music room does not clear the user's mute setting")
	check(root.gui_get_focus_owner() == opener, "closing restores menu focus")
	menu_music.stop()
	room.queue_free()
	host.queue_free()
	opener.queue_free()
	await frames(20)
	print("MUSIC_ROOM_SMOKE_OK" if failures == 0 else "MUSIC_ROOM_SMOKE_FAILED")
	quit(0 if failures == 0 else 1)
