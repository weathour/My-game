extends SceneTree

const CATALOG := preload("res://scripts/audio/music_catalog.gd")
const STATE := preload("res://scripts/game/session_state.gd")
const BGM := preload("res://scripts/bgm_player.gd")
var failures: Array[String] = []

class Battle:
	extends Node
	var game_over := false
	var stage_cleared := false
	var reward_context := ""
	var story_mode_active := true
	var story_stage := {"id": "chapter1_stage1"}
	var wave_flow: Node
	func get_session_presentation() -> Dictionary:
		return STATE.presentation(self)

class Wave:
	extends Node
	var wave := 1
	var phase := "combat"
	var elapsed := 0.0
	var remaining := 30.0
	var ending_final := false

class Encounter:
	extends Node
	signal defeated(kind: String)
	signal runtime_configured
	var runtime_configuration_complete := true
	var archetype_id := ""
	var current_health := 100.0
	var rebirth_timer := 0.0
	var boss_phase := 1
	var pooled_inactive := false

class AudibleMusic:
	extends "res://scripts/bgm_player.gd"
	# Exercise the real audio engine with Godot's Dummy driver, without speakers.
	func _is_headless_runtime() -> bool:
		return false

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func run() -> void:
	check(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated settings required")
	if not failures.is_empty():
		finish()
		return
	for scene in ["main", "main_menu", "save_select", "endless_save_select", "story_prep", "endless_camp"]:
		var source := FileAccess.get_file_as_string("res://scenes/%s.tscn" % scene)
		check(not source.contains("assets/game_bgm.") and not source.contains("assets/menu_bgm."), "runtime scene no longer references placeholder music: " + scene)
	var battle := Battle.new()
	root.add_child(battle)
	current_scene = battle
	var wave := Wave.new()
	battle.add_child(wave)
	for stage in CATALOG.STAGES:
		battle.story_stage.id = stage
		check(CATALOG.battle_cue(STATE.presentation(battle), []) == CATALOG.STAGES[stage], "all story stages have distinct base cues: " + stage)
	battle.story_mode_active = false
	battle.wave_flow = wave
	var expected := ["stage_frontpost", "stage_frontpost", "stage_frontpost", "stage_frontpost", "stage_frontpost", "stage_frontpost", "stage_frontpost", "stage_rift", "stage_rift", "stage_rift", "stage_rift", "stage_frontpost", "stage_rift", "stage_rift", "stage_rift", "stage_rift", "stage_frontpost", "stage_core", "stage_core", "stage_core"]
	for index in range(20):
		wave.wave = index + 1
		check(CATALOG.battle_cue(STATE.presentation(battle), []) == expected[index], "wave base cue %d" % wave.wave)
	var inventory: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/design-reviews/evidence/2026-10-25/level-audit/music-encounters.json"))
	for entry in inventory.special_encounters:
		check(CATALOG.ENCOUNTERS.has(entry.enemy_id), "audited encounter has music: " + str(entry.enemy_id))
	var ram := Encounter.new()
	ram.archetype_id = "elite_ram_trail"
	battle.add_child(ram)
	var split := Encounter.new()
	split.archetype_id = "elite_splitshot"
	battle.add_child(split)
	check(CATALOG.battle_cue(STATE.presentation(battle), [split, ram]) == "elite_ram", "dual elites use stable priority independent of order")
	ram.current_health = 0.0
	check(CATALOG.battle_cue(STATE.presentation(battle), [ram, split]) == "elite_splitshot", "second elite music waits for first actual death")
	var boss := Encounter.new()
	battle.add_child(boss)
	for id in CATALOG.ENCOUNTERS:
		boss.archetype_id = id
		check(CATALOG.battle_cue(STATE.presentation(battle), [boss]) == CATALOG.ENCOUNTERS[id], "all actual encounter identities select their cue: " + id)
	boss.archetype_id = "smallboss_rebirth"
	boss.current_health = 0.0
	boss.rebirth_timer = 5.0
	check(CATALOG.battle_cue(STATE.presentation(battle), [boss]) == "boss_rebirth", "fake death keeps rebirth encounter, never victory")
	boss.current_health = 100.0
	boss.rebirth_timer = 0.0
	boss.archetype_id = "boss_spellcore"
	for phase in range(1, 4):
		boss.boss_phase = phase
		check(CATALOG.battle_cue(STATE.presentation(battle), [split, boss]) == "boss_spellcore_%d" % phase, "boss priority and actual phase %d" % phase)
	wave.phase = "clearing"
	check(CATALOG.battle_cue(STATE.presentation(battle), [boss]) == "camp_signal", "ordinary wave ending is not victory")
	wave.ending_final = true
	check(CATALOG.battle_cue(STATE.presentation(battle), [boss]) == "victory", "final actual wave completion plays victory")
	wave.phase = "combat"
	battle.game_over = true
	check(CATALOG.battle_cue(STATE.presentation(battle), [boss]) == "defeat", "actual defeat overrides living encounters")
	battle.reward_context = "endless_tier_clear"
	check(CATALOG.battle_cue(STATE.presentation(battle), []) == "victory", "endless settlement is victory despite game_over")
	battle.reward_context = ""
	battle.game_over = false
	var edge_music := BGM.new()
	edge_music.follow_battle_context = true
	battle.add_child(edge_music)
	var transient := Encounter.new()
	transient.archetype_id = "elite_ram_trail"
	battle.add_child(transient)
	transient.free()
	var detached := Encounter.new()
	detached.archetype_id = "elite_splitshot"
	battle.add_child(detached)
	battle.remove_child(detached)
	await process_frame
	edge_music.refresh_context()
	check(detached not in edge_music._encounters, "configured tracking removes freed or detached encounters")
	edge_music.free()
	detached.free()
	for cue in CATALOG.CUES:
		var resource: AudioStream = load(CATALOG.path(cue)) if ResourceLoader.exists(CATALOG.path(cue)) else null
		check(resource is AudioStreamOggVorbis and resource.get_length() > 0.0, "delivered Ogg cue loads: " + cue)
	if failures.is_empty():
		var phase_length: float = load(CATALOG.path("boss_spellcore_1")).get_length()
		for phase in [2, 3]:
			check(is_equal_approx(load(CATALOG.path("boss_spellcore_%d" % phase)).get_length(), phase_length), "phase arrangements share the same loop length")
	check(BGM.normalize_position(125.0, 60.0, true) == 5.0, "legacy music_position wraps safely into new loop")
	check(BGM.normalize_position(-5.0, 60.0, true) == 0.0 and BGM.normalize_position(INF, 60.0, true) == 0.0, "invalid old positions do not reach the audio engine")
	check(BGM.normalize_position(125.0, 10.0, false) == 10.0, "finished one shot never wraps")
	if failures.is_empty():
		await check_player(battle, boss)
	battle.free()
	await process_frame
	if failures.is_empty():
		await check_real_scene()
		await check_camp_scene_handoff()
		await check_native_playback()
	finish()

func check_player(battle: Battle, boss: Encounter) -> void:
	var music := BGM.new()
	music.follow_battle_context = true
	music.name = "GameBGM"
	battle.add_child(music)
	music.start_music()
	music.set_process(false)
	music.refresh_context()
	check(music.current_cue == "boss_spellcore_3", "existing and restored children enter the encounter cache")
	check(not music.playing and not music._other.playing, "normal headless runtime disables both audio players")
	music.restore_playback_position(17.25)
	check(music.paused_by_script and is_equal_approx(music.get_saved_playback_position(), 17.25), "continue preserves old music_position while paused")
	await music.resume_music()
	boss.boss_phase = 2
	music.refresh_context()
	check(music.current_cue == "boss_spellcore_2" and is_equal_approx(music.stored_playback_position, 17.25), "boss phase crossfade preserves timeline position")
	check(music._phase_fade, "same-source phase fade is linear")
	music._process(0.4)
	check(is_equal_approx(music._active_gain + music._outgoing_gain, 1.0), "phase transition has complementary gains")
	var request_id: int = music.resume_request_id
	var active: AudioStreamPlayer = music._active
	music.refresh_context()
	check(music.resume_request_id == request_id and music._active == active, "duplicate context does not replay or reload")
	music.set_cue("missing_cue")
	check(music.resume_request_id == request_id and music._active == active and music.current_cue == "boss_spellcore_2", "failed cue lookup leaves the loaded voice and identity intact")
	music.pause_music()
	var fade_elapsed: float = music._fade_elapsed
	music._process(0.2)
	check(music.paused_by_script and music._fade_elapsed == fade_elapsed, "headless pause freezes the crossfade without starting either voice")
	music.resume_music(0.04)
	music.pause_music()
	await create_timer(0.06, true, false, true).timeout
	check(music.paused_by_script, "later pause cancels delayed resume")
	await music.resume_music()
	BGM.save_music_volume(0.25)
	BGM.save_music_muted(true)
	music.apply_saved_volume()
	check(music.volume_db == BGM.MUTED_VOLUME_DB and music._other.volume_db == BGM.MUTED_VOLUME_DB, "mute reaches both players during a fade")
	BGM.save_music_muted(false)
	music.apply_saved_volume()
	check(is_equal_approx(db_to_linear(music._active.volume_db), 0.25 * music._active_gain), "volume keeps the current fade gain")
	await music.resume_music()
	battle.game_over = true
	music.pause_music()
	check(music.current_cue == "defeat" and not music.paused_by_script, "death's existing pause call allows the result cue")
	check(not music._active.stream.loop, "result cue disables native looping")
	music._on_finished(music._active)
	music.refresh_context()
	check(not music._started and music.current_cue == "defeat", "finished result is not restarted by context refresh")
	var second_voice_id: int = music._other.get_instance_id()
	music.resume_music(0.04)
	music.free()
	await create_timer(0.06, true, false, true).timeout
	check(not is_instance_id_valid(second_voice_id) and battle.get_node_or_null("GameBGM") == null, "exit frees the second voice and cancels pending resume")
	CATALOG.arrival_cue = "victory"
	var camp := BGM.new()
	battle.add_child(camp)
	camp.set_process(false)
	check(camp.current_cue == "victory" and CATALOG.arrival_cue == "", "successful story return consumes arrival victory once")
	camp._on_finished(camp._active)
	check(camp.current_cue == "camp_signal" and camp._active.stream.loop, "story result completes once, then native camp loop starts")
	camp.free()

func check_real_scene() -> void:
	var mode := preload("res://scripts/developer_mode.gd")
	mode.activate()
	var game = preload("res://scenes/main.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	current_scene = game
	var music = game.get_node("GameBGM")
	for id in CATALOG.ENCOUNTERS:
		var kind := "boss" if id == "boss_spellcore" else "small_boss" if str(id).begins_with("smallboss_") else "elite"
		var enemy = game.ENEMY_SPAWN_FLOW.spawn_special_enemy_with_archetype(game, kind, id)
		check(is_instance_valid(enemy), "actual enemy scene/profile spawns: " + id)
		await process_frame
		music.refresh_context()
		check(music.current_cue == CATALOG.ENCOUNTERS[id], "real scene spawn selects music: " + id)
		var saved: Dictionary = enemy.get_save_data()
		enemy.free()
		if id == "boss_spellcore":
			preload("res://scripts/game/run_save_runtime_flow.gd").restore_enemies(game, [saved])
			music.restore_playback_position(11.5)
			check(music.current_cue == "boss_spellcore_1" and is_equal_approx(music.get_saved_playback_position(), 11.5), "real restore derives cue before applying old music_position")
	game.suppress_exit_save = true
	game.free()
	current_scene = null
	mode.deactivate()
	await process_frame

func check_native_playback() -> void:
	var host := Node.new()
	root.add_child(host)
	var music := AudibleMusic.new()
	host.add_child(music)
	await create_timer(0.15, true, false, true).timeout
	check(music._active.playing and music.get_saved_playback_position() > 0.0, "Dummy audio engine advances the delivered music")
	music.set_cue("boss_spellcore_1", 0.0)
	music._active.seek(9.0)
	await create_timer(0.1, true, false, true).timeout
	music.set_cue("boss_spellcore_2", 0.8)
	check(absf(music.stored_playback_position - music._outgoing.get_playback_position()) < 0.08 and music._active.playing, "actual phase voice starts at the current audio timeline after loading")
	music.pause_music()
	var paused_position: float = music.get_saved_playback_position()
	check(music._active.stream_paused and music._outgoing.stream_paused, "native pause freezes both crossfade voices")
	await create_timer(0.1, true, false, true).timeout
	check(is_equal_approx(music.get_saved_playback_position(), paused_position), "actual audio pause preserves position")
	await music.resume_music()
	music.set_cue("camp_signal", 0.0)
	music._active.seek(music._active.stream.get_length() - 0.04)
	await create_timer(0.25, true, false, true).timeout
	check(music._active.playing and music.get_saved_playback_position() < 0.5, "native Ogg loop continues across its end")
	music.set_cue("defeat", 0.0)
	music._active.seek(music._active.stream.get_length() - 0.04)
	await create_timer(0.25, true, false, true).timeout
	check(not music._active.playing and not music._started, "native result stream stops once at its end")
	host.free()
	await process_frame

func check_camp_scene_handoff() -> void:
	BGM.camp_handoff_ready = false
	BGM.save_music_muted(false)
	BGM.save_music_volume(0.25)
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	menu.get_node("MenuBGM").set_script(AudibleMusic)
	root.add_child(menu)
	current_scene = menu
	var first = menu.get_node("MenuBGM")
	first._active.seek(4.0)
	await create_timer(0.15, true, false, true).timeout
	var position: float = first.get_saved_playback_position()
	BGM.save_music_muted(true)
	first.apply_saved_volume()
	menu.free()
	var select = load("res://scenes/save_select.tscn").instantiate()
	select.get_node("MenuBGM").set_script(AudibleMusic)
	root.add_child(select)
	current_scene = select
	var second = select.get_node("MenuBGM")
	check(position >= 4.0 and absf(second.stored_playback_position - position) < 0.08, "real menu to save-select handoff resumes camp instead of zero")
	check(second._active_gain == 0.0 and second._fade_duration == 0.35, "resumed camp enters with a short fade")
	check(second._active.volume_db == BGM.MUTED_VOLUME_DB and is_equal_approx(BGM.load_music_volume(), 0.25), "camp handoff keeps volume and mute settings")
	var resumed_voice: AudioStreamPlayer = second._active
	var resumed_position: float = second.stored_playback_position
	var resumed_request: int = second.resume_request_id
	check(await wait_for_fade(second), "camp entry fade completes within its scheduling deadline")
	BGM.save_music_muted(false)
	second.apply_saved_volume()
	check(second._active == resumed_voice and second.resume_request_id == resumed_request and second._active.playing and second.get_saved_playback_position() > resumed_position and is_equal_approx(db_to_linear(second._active.volume_db), 0.25), "camp advances across real scene rebuild and unmutes at the saved volume")
	select.free()
	current_scene = null
	await process_frame

func wait_for_fade(music) -> bool:
	# Wall-clock timers may fire before the engine has accumulated its fade delta.
	var deadline := Time.get_ticks_msec() + 2000
	while music._fade_duration > 0.0 and Time.get_ticks_msec() < deadline:
		await process_frame
	return music._fade_duration == 0.0

func finish() -> void:
	for message in failures:
		push_error(message)
	print("MUSIC_CONTEXT_SMOKE_OK" if failures.is_empty() else "MUSIC_CONTEXT_SMOKE_FAILED")
	quit(0 if failures.is_empty() else 1)
