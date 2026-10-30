extends SceneTree
## Use --legacy-fixture only while composers are rendering: the substitute exists in memory only.
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
const CATALOG := preload("res://scripts/audio/music_catalog.gd")
const ROUTING := preload("res://scripts/audio/chronicle_music.gd")
const BGM := preload("res://scripts/bgm_player.gd")
const STORIES := preload("res://scripts/content/story_catalog.gd")
const RESOLVER := preload("res://scripts/battle/combat_resolver.gd")
var failures := 0
var checks := 0
var fixture := false

class AudibleMusic extends "res://scripts/bgm_player.gd":
	func _is_headless_runtime() -> bool: return false

func _init() -> void: call_deferred("run")
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func frames(count: int = 3) -> void:
	for i in count: await process_frame

func install_fixture() -> void:
	var ids: Array[String] = []
	for cue: String in ROUTING.NODE_CUES.values():
		if cue not in ids: ids.append(cue)
	for cue: String in ROUTING.WARFORMS.values(): ids.append(cue)
	for cue in ["title_overture", "region_baimen_road", "world_map", "camp_home", "preparation", "results_flow", "archive_memories", "story_solitude", "story_comedy", "story_banter", "story_travel", "journey_departure", "story_confrontation", "story_aftermath", "stinger_departure", "stinger_transform", "stinger_victory", "stinger_important_victory", "stinger_defeat"]:
		if cue not in ids: ids.append(cue)
	CATALOG._loaded = true
	CATALOG._chapter.clear()
	for cue in ids:
		CATALOG._chapter[cue] = {"id":cue, "title":cue, "kind":"Fixture", "category":"stinger" if cue.begins_with("stinger_") else "bed", "loop":not cue.begins_with("stinger_"), "path":"res://assets/music/camp_signal.ogg", "bpm":120, "beats":128}
	for id: String in ROUTING.WARFORMS:
		var family := "fixture:" + id
		CATALOG._chapter[ROUTING.node_cue(id)].phase_family = family
		CATALOG._chapter[ROUTING.WARFORMS[id]].phase_family = family

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated user data required")
	if failures: quit(1); return
	fixture = "--legacy-fixture" in OS.get_cmdline_user_args()
	if fixture: install_fixture()
	else: expect(CATALOG.chapter_cues().size() == 70, "published chapter manifest contains 70 assets")
	var routes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/route.json"))
	expect(routes.size() == 36 and ROUTING.NODE_CUES.size() == 36, "all 36 route nodes explicitly mapped")
	for id in ["S03", "S04", "S05", "B03", "B04", "B05", "B06", "F01"]:
		expect(ROUTING.page_cue("route", id) == "region_ghost_market", "route region retains ghost-market section: " + id)
	expect(ROUTING.page_cue("route", "B01") == "region_baimen_road" and ROUTING.page_cue("route", "B18") == "region_old_city", "route outside market selects road/old-city region")
	for node: Dictionary in routes:
		expect(ROUTING.NODE_CUES.has(node.id), "node music mapping: " + str(node.id))
		expect(CATALOG.has_cue(ROUTING.node_cue(node.id)), "catalog node cue: " + str(node.id))
	for cue: String in CATALOG.chapter_cues():
		expect(ResourceLoader.exists(CATALOG.path(cue)), "published playable asset: " + cue)
	expect(STORIES.validate().is_empty(), "story and authored line music metadata valid")
	if failures: quit(1); return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var shell := SHELL.instantiate()
	shell.session.directory = "user://chronicle_music/" + str(Time.get_ticks_usec())
	viewport.add_child(shell)
	await frames()
	expect(shell.bgm.current_cue == "title_overture" and not shell.bgm.follow_battle_context, "chapter title owns isolated local BGM")
	shell.open_page("world")
	expect(shell.bgm.current_cue == "world_map", "world map music")
	shell.session.data.current = "S03"
	shell.open_page("route")
	expect(shell.bgm.current_cue == "region_ghost_market", "route follows actual current node")
	shell.bgm.restore_playback_position(17.25)
	shell.selected_node = "B18"
	shell.render()
	expect(shell.bgm.current_cue == "region_ghost_market" and is_equal_approx(shell.bgm.get_saved_playback_position(), 17.25), "hover selection/re-render retains music and position")
	var snapshot: Dictionary = shell.bgm.capture_snapshot()
	shell.open_music()
	expect(shell.music_tracks.size() == CATALOG.chapter_cues().size() and shell.bgm.paused_by_script, "music room displays chapter catalog and freezes base")
	shell.play_track(shell.music_tracks.find("region_ghost_market"))
	expect(not shell.music_preview.stream.loop and shell.bgm._active.stream.loop, "preview loop flag does not mutate scene resource")
	shell.music_preview.seek(5.0)
	shell.render()
	shell.open_page("route")
	expect(shell.bgm.capture_snapshot() == snapshot, "music room restores exact cue/position/paused/context snapshot")
	shell.open_music()
	shell.open_page("world")
	expect(shell.bgm.current_cue == "world_map" and not shell.bgm.paused_by_script, "leaving preview for another page discards snapshot and resumes destination")
	shell.session.data.completed = ["S01"]
	shell.session.data.current = "B01"
	shell.session.data.available = ["B01"]
	shell.open_page("route")
	shell.bgm.restore_playback_position(12.25)
	snapshot = shell.bgm.capture_snapshot()
	var before := JSON.stringify(shell.session.data)
	expect(shell.open_story_replay("S01"), "completed story replay opens")
	expect(shell.bgm.current_cue == "hero_daily" and not shell.bgm.paused_by_script, "replay authored opening music plays while preserving paused return snapshot")
	shell._advance_story_replay("s01_04")
	expect(shell.bgm.current_cue == "journey_departure" and shell.bgm._stinger_cue == "stinger_departure", "authored line changes bed and overlays stinger")
	shell.render()
	expect(shell.bgm._stinger_cue == "stinger_departure", "reader re-render retains active stinger")
	shell.close_story_replay()
	expect(JSON.stringify(shell.session.data) == before, "replay remains read-only")
	expect(shell.bgm.capture_snapshot() == snapshot and shell.bgm._stinger_cue.is_empty(), "replay closes with exact snapshot and no queued stinger")
	shell.open_story_replay("S01")
	shell.session.data.current = "B18"
	shell.close_story_replay()
	expect(shell.bgm.current_cue == "region_old_city", "changed campaign invalidates replay snapshot")
	# Real BattleView emits directly from simulation form state and pause ownership.
	shell.session.data.current = "B18"
	shell.session.data.available = ["B18"]
	shell.start_battle()
	expect(shell.bgm.current_cue == "boss_lubu" and is_zero_approx(shell.bgm.stored_playback_position), "retry begins battle music freshly")
	var view: Control = shell.battle_view
	view.set_physics_process(false)
	view.toggle_pause()
	expect(shell.bgm.paused_by_script, "real battle pause freezes music")
	view.toggle_pause()
	expect(not shell.bgm.paused_by_script, "real battle resumes music")
	var found := false
	for enemy in view.battle.enemies:
		if enemy.rank == "boss":
			RESOLVER.hit_enemy(enemy, {"damage":enemy.hp, "slow":0.0, "duration":0.0, "direct":true})
			found = true
	view.battle.tick(1.0 / 60.0, Vector2.ZERO)
	expect(found, "final duel has actual boss entity")
	shell.bgm.restore_playback_position(9.0)
	shell.bgm.resume_music()
	view._publish_music_context()
	expect(shell.bgm.current_cue == "boss_lubu_warform" and shell.bgm._stinger_cue == "stinger_transform", "real boss form drives warform and transform overlay")
	expect(is_equal_approx(shell.bgm.stored_playback_position, 9.0), "same timeline phase retains position")
	view.battle.outcome = "failed"
	view._publish_music_context()
	expect(shell.bgm._stinger_cue == "stinger_defeat", "actual loss replaces transform stinger")
	view.failed.emit()
	expect(shell.page == "failure" and shell.bgm._stinger_cue == "stinger_defeat", "failure screen preserves defeat tail")
	shell.bgm.cancel_stinger(true)
	expect(shell.bgm.current_cue == "story_solitude" and shell.bgm._duck_gain == 1.0, "defeat completion selects quiet bed and releases duck")
	shell.session.data.available = ["B18"]
	shell.start_battle()
	shell.battle_view.set_physics_process(false)
	expect(shell.bgm.current_cue == "boss_lubu" and is_zero_approx(shell.bgm.stored_playback_position), "retry discards defeated music timeline")
	shell.battle_view.cancelled.emit()
	expect(shell.page != "battle" and shell.bgm._stinger_cue.is_empty(), "battle cancellation clears transient music")
	for id: String in ROUTING.WARFORMS:
		if id != "B18": verify_boss_phase(shell, id)
		if CATALOG.same_phase_family(ROUTING.node_cue(id), ROUTING.WARFORMS[id]):
			var a := load(CATALOG.path(ROUTING.node_cue(id))) as AudioStream
			var b := load(CATALOG.path(ROUTING.WARFORMS[id])) as AudioStream
			expect(absf(a.get_length() - b.get_length()) < 0.06, "declared sync family streams have matching timelines: " + id)
		else:
			expect(id == "B15", "only CaoXiu uses the published different-tempo phase transition")
	shell.session.data.current = "B01"
	shell.session.data.available = ["B01"]
	shell.start_battle()
	shell.battle_view.set_physics_process(false)
	shell.battle_view.battle.outcome = "victory" # Presentation routing fixture; campaign rewards are not submitted.
	shell.battle_view._publish_music_context()
	expect(shell.bgm._stinger_cue == "stinger_victory", "ordinary actual outcome context plays brief victory overlay")
	shell.bgm.cancel_stinger(true)
	expect(shell.bgm.current_cue == "results_flow", "victory overlay completion proceeds to result bed")
	shell.battle_view.cancelled.emit()
	await verify_overlay_audio()
	viewport.queue_free()
	await frames()
	await create_timer(0.12).timeout # Drain the Dummy audio mixer after freeing players.
	print("CHRONICLE_MUSIC_SMOKE_", "FIXTURE_" if fixture else "", "OK" if failures == 0 else "FAILED", " checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

func verify_overlay_audio() -> void:
	var music := AudibleMusic.new()
	music.initial_cue = "battle_road"
	root.add_child(music)
	music.play_stinger("stinger_victory", "results_flow")
	await create_timer(0.06).timeout
	music.pause_music()
	var remaining: float = music._stinger_remaining
	await create_timer(0.04).timeout # AudioServer applies the pause on its next mixing block.
	var position: float = music._stinger.get_playback_position()
	await create_timer(0.08).timeout
	expect(music._stinger.stream_paused and is_equal_approx(music._stinger_remaining, remaining), "native stinger playback and timer both freeze")
	expect(absf(music._stinger.get_playback_position() - position) <= 0.025, "native stinger position freezes within one mixer block (%.5f -> %.5f)" % [position, music._stinger.get_playback_position()])
	var muted := BGM.load_music_muted()
	BGM.save_music_muted(true)
	music.apply_saved_volume()
	expect(music._active.volume_db <= -80 and music._stinger.volume_db <= -80, "settings mute both bed and overlay")
	BGM.save_music_muted(muted)
	music.cancel_stinger()
	music.cancel_stinger()
	expect(music._duck_gain == 1.0 and music._stinger_after.is_empty(), "interrupt cancellation releases duck once and removes delayed destination")
	music.resume_music()
	music.set_cue("nonexistent-score-id")
	expect(music.current_cue == "battle_road", "unknown cue retains valid bed safely")
	music.play_stinger("stinger_victory", "results_flow")
	music._stinger.seek(music._stinger.stream.get_length() - 0.04)
	await create_timer(0.25).timeout
	expect(music.current_cue == "results_flow" and music._stinger_cue.is_empty() and music._duck_gain == 1.0, "native one-shot completion releases duck and commits result bed")
	music.queue_free()
	await frames()

func verify_boss_phase(shell: Control, id: String) -> void:
	shell.session.data.current = id
	shell.session.data.available = [id]
	shell.start_battle()
	var view: Control = shell.battle_view
	view.set_physics_process(false)
	view.battle.director.elapsed = float(view.battle.director.config.boss_time)
	view.battle.tick(0.0, Vector2.ZERO)
	expect(shell.bgm.current_cue == ROUTING.node_cue(id), "human boss music: " + id)
	var found := false
	for enemy in view.battle.enemies:
		if enemy.rank == "boss":
			RESOLVER.hit_enemy(enemy, {"damage":enemy.hp, "slow":0.0, "duration":0.0, "direct":true})
			found = true
	view.battle.tick(1.0 / 60.0, Vector2.ZERO)
	shell.bgm.restore_playback_position(9.0)
	shell.bgm.resume_music()
	view._publish_music_context()
	var sync_safe := CATALOG.same_phase_family(ROUTING.node_cue(id), ROUTING.WARFORMS[id])
	expect(is_equal_approx(shell.bgm.stored_playback_position, 9.0 if sync_safe else 0.0), "phase timeline follows declared synchronization contract: " + id)
	expect(found and shell.bgm.current_cue == ROUTING.WARFORMS[id] and shell.bgm._stinger_cue == "stinger_transform", "production phase-one depletion drives warform: " + id)
	view.battle.outcome = "victory" # Isolate serious-result routing from reward transactions.
	view._publish_music_context()
	expect(shell.bgm._stinger_cue.is_empty() and shell.bgm._duck_gain == 1.0, "serious postbattle clears transform and suppresses fanfare: " + id)
	view.cancelled.emit()
