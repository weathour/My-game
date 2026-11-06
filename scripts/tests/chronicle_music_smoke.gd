extends SceneTree
## Frozen first-chapter allocation, real battle signals, and reversible scene playback.
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
const CATALOG := preload("res://scripts/audio/music_catalog.gd")
const ROUTING := preload("res://scripts/audio/chronicle_music.gd")
const BGM := preload("res://scripts/audio/music_player.gd")
const STORIES := preload("res://scripts/content/story_catalog.gd")
const RESOLVER := preload("res://scripts/battle/combat_resolver.gd")
const MAP_PATH := "res://design/music-20261103-midi-test/chapter-music-map.json"
var failures := 0
var checks := 0
var complete_routes := 0
var minimum_battles := 100
var maximum_battles := 0
var route_nodes := {}
var story_events := {}

func _init() -> void: call_deferred("run")
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func frames(count: int = 3) -> void:
	for i in count: await process_frame

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated user data required")
	if failures: quit(1); return
	var allocation_only := "--allocation-only" in OS.get_cmdline_user_args()
	verify_allocation(allocation_only)
	if allocation_only:
		print("CHRONICLE_MUSIC_ALLOCATION ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
		quit(1 if failures else 0)
		return
	if failures: quit(1); return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var shell := SHELL.instantiate()
	shell.session.directory = "user://chronicle_music/" + str(Time.get_ticks_usec())
	viewport.add_child(shell)
	await frames()
	expect(shell.bgm.current_cue == "midi_test_01", "title plays The Beautiful People")
	shell.open_page("world")
	expect(shell.bgm.current_cue == "midi_test_11", "world plays Minute of Decay")
	shell.session.data.current = "B04"
	shell.open_page("route")
	expect(shell.bgm.current_cue == "midi_test_10", "route follows actual current-node segment")
	shell.bgm.restore_playback_position(17.25)
	shell.selected_node = "B18"
	shell.render()
	expect(shell.bgm.current_cue == "midi_test_10" and is_equal_approx(shell.bgm.get_saved_playback_position(), 17.25), "inspection and render preserve actual route music and position")
	for utility in ["menu", "settings", "saves", "help", "about"]:
		shell.open_page(utility)
		expect(shell.bgm.current_cue == "midi_test_10" and is_equal_approx(shell.bgm.get_saved_playback_position(), 17.25), "utility inherits owning scene: " + utility)
	shell.open_page("route")
	var snapshot: Dictionary = shell.bgm.capture_snapshot()
	shell.open_music()
	expect(shell.music_tracks.size() == 16 and shell.bgm.paused_by_script, "music room lists exactly 12 new and 4 retained tracks and freezes base")
	for cue: String in shell.music_tracks:
		shell.play_track(shell.music_tracks.find(cue))
		expect(shell.music_preview.stream != null and not shell.music_preview.stream.loop, "each preview plays a complete song once: " + cue)
	expect(shell.bgm._active.stream.loop, "preview does not mutate scene loop resource")
	shell.music_preview.seek(5.0)
	shell.render()
	shell.open_page("route")
	expect(shell.bgm.capture_snapshot() == snapshot, "music room restores exact cue/position/paused/context snapshot")
	shell.open_music()
	shell.open_page("world")
	expect(shell.bgm.current_cue == "midi_test_11" and not shell.bgm.paused_by_script, "another destination discards preview snapshot and resumes its music")
	shell.session.data.completed = ["S01"]
	shell.session.data.current = "B01"
	shell.session.data.available = ["B01"]
	shell.open_page("route")
	shell.bgm.restore_playback_position(12.25)
	snapshot = shell.bgm.capture_snapshot()
	var before := JSON.stringify(shell.session.data)
	expect(shell.open_story_replay("S01"), "completed story replay opens")
	expect(shell.bgm.current_cue == "hero_daily" and not shell.bgm.paused_by_script, "replay opening uses retained daily music")
	shell.bgm.restore_playback_position(6.5)
	shell._advance_story_replay("s01_04")
	expect(shell.bgm.current_cue == "hero_daily" and shell.bgm._stinger_cue.is_empty() and is_equal_approx(shell.bgm.stored_playback_position, 6.5), "S01 authored line keeps full-song position with retired departure stinger removed")
	shell.close_story_replay()
	expect(JSON.stringify(shell.session.data) == before, "replay remains read-only")
	expect(shell.bgm.capture_snapshot() == snapshot, "replay closes with exact snapshot")
	shell.open_story_replay("S01")
	shell.session.data.current = "B18"
	shell.close_story_replay()
	expect(shell.bgm.current_cue == "midi_test_05", "changed campaign invalidates replay snapshot")
	for id in ["B15", "B16", "B17", "B18"]: verify_boss_phase(shell, id)
	shell.session.data.current = "B01"
	shell.session.data.available = ["B01"]
	shell.start_battle()
	shell.battle_view.set_physics_process(false)
	expect(shell.bgm.current_cue == "midi_test_03" and is_zero_approx(shell.bgm.stored_playback_position), "each battle starts selected full song at zero")
	shell.bgm.restore_playback_position(23.5)
	shell.battle_view.battle._finish("victory")
	shell.battle_view._publish_music_context()
	shell.battle_view.completed.emit(shell.battle_view.battle.result.duplicate(true))
	expect(shell.page == "reward" and shell.bgm.current_cue == "midi_test_03" and is_equal_approx(shell.bgm.stored_playback_position, 23.5) and shell.bgm._stinger_cue.is_empty(), "victory result continues battle cue and position without fanfare")
	shell.session.data.pending = {}
	shell.session.data.available = ["B01"]
	shell.start_battle()
	shell.battle_view.set_physics_process(false)
	shell.battle_view.battle.outcome = "failed"
	shell.battle_view._publish_music_context()
	shell.battle_view.failed.emit()
	expect(shell.page == "failure" and shell.bgm.current_cue == "midi_test_08" and shell.bgm._stinger_cue.is_empty(), "failure immediately selects Man That You Fear with no retired defeat tail")
	shell.session.data.available = ["B01"]
	shell.start_battle()
	shell.battle_view.set_physics_process(false)
	expect(shell.bgm.current_cue == "midi_test_03" and is_zero_approx(shell.bgm.stored_playback_position), "retry restarts battle song at zero")
	shell.battle_view.cancelled.emit()
	expect(not shell.bgm.play_stinger("stinger_victory", "results_flow") and shell.bgm._stinger_cue.is_empty(), "obsolete stinger requests cannot recover retired music or result fallback")
	shell.bgm.set_cue("retired-or-unknown")
	expect(shell.bgm.current_cue == "midi_test_11", "unknown cue falls back to Minute of Decay")
	shell.bgm.restore_snapshot({"cue":"boss_lubu_warform", "position":42.0, "paused":false, "started":true})
	expect(shell.bgm.current_cue == "midi_test_11" and is_zero_approx(shell.bgm.stored_playback_position), "retired snapshot falls back freshly without recovering old timeline")
	for id in ["B06", "B15", "B16", "B17"]:
		var event: Dictionary = story_events[id]
		shell._on_story_music_line(str(event.lines[0].id), event, false)
		expect(shell.bgm.current_cue == event.music, "independent postbattle story selects authored new cue: " + id)
	shell._on_story_music_line(str(story_events.B15.lines[0].id), story_events.B15, false)
	shell.bgm.restore_playback_position(8.5)
	shell._on_story_music_line(str(story_events.B16.lines[0].id), story_events.B16, false)
	expect(is_equal_approx(shell.bgm.stored_playback_position, 8.5), "same cue across adjacent story contexts keeps position")
	viewport.queue_free()
	await frames()
	await create_timer(0.12).timeout
	print("CHRONICLE_MUSIC_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

func verify_allocation(allocation_only: bool = false) -> void:
	var allocation: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	var experiment: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://design/music-20261103-midi-test/experiment-manifest.json"))
	var routes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/route.json"))
	story_events = STORIES.events()
	if not allocation_only: expect(CATALOG.chapter_cues().size() == 16, "all 16 published assets exist")
	expect(routes.size() == 36 and ROUTING.NODE_CUES.size() == 36, "all 36 route nodes explicitly mapped")
	for expected: Dictionary in allocation.nodes:
		expect(ROUTING.node_cue(expected.id) == expected.cue_id, "frozen node allocation: " + str(expected.id))
		expect(CATALOG.has_cue(ROUTING.node_cue(expected.id)), "allowed node cue: " + str(expected.id))
		for form in [0, 1, 2]: expect(ROUTING.battle_cue(expected.id, form) == expected.cue_id, "all forms use one full song: " + str(expected.id))
	for node: Dictionary in routes:
		route_nodes[node.id] = node
		expect(ROUTING.page_cue("route", node.id) == allocation.pages.route.by_segment[int(node.segment)].cue_id, "route uses authoritative segment: " + str(node.id))
	for entry: Dictionary in allocation.story_events:
		expect(story_events[entry.event_id].music == entry.cue_id, "story allocation: " + str(entry.event_id))
	for entry: Dictionary in allocation.line_music_overrides:
		var event: Dictionary = story_events[entry.event_id]
		expect(ROUTING.story_cue(event, entry.line_id) == entry.cue_id and ROUTING.line_stinger(event, entry.line_id).is_empty(), "all nine line overrides applied without stinger: " + str(entry.line_id))
	var characters: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/character_events.json"))
	for entry: Dictionary in allocation.character_events:
		var event: Dictionary = characters[entry.event_id]
		expect(event.music == entry.cue_id, "character event allocation: " + str(entry.event_id))
		for line: Dictionary in event.lines: expect(ROUTING.story_cue(event, line.id) == entry.cue_id and ROUTING.line_stinger(event, line.id).is_empty(), "character line inherits its event: " + str(line.id))
	for event: Dictionary in story_events.values():
		for line: Dictionary in event.lines: expect(CATALOG.has_cue(ROUTING.story_cue(event, line.id)) and ROUTING.line_stinger(event, line.id).is_empty(), "every story line resolves to retained or new music: " + str(line.id))
	for entry: Dictionary in allocation.new_test_cues + allocation.retained_warm_cues:
		var cue := str(entry.cue_id)
		expect(CATALOG.has_cue(cue) and not CATALOG.is_one_shot(cue), "catalog full-song loop: " + cue)
		if not allocation_only: expect(ResourceLoader.exists(CATALOG.path(cue)), "published full-song asset: " + cue)
		expect(not CATALOG.info(cue).has("phase_family"), "no cross-file phase arrangement: " + cue)
	for entry: Dictionary in allocation.new_test_cues:
		var metadata := CATALOG.info(entry.cue_id)
		expect(metadata.source_midi_sha256 == entry.midi_sha256 and not metadata.has("bpm"), "frozen MIDI provenance without a fabricated constant tempo: " + str(entry.cue_id))
		expect(metadata.arrangement_variant == "D2" and metadata.source_audio_variant == "D2", "published catalog explicitly selects the approved D2 arrangement: " + str(entry.cue_id))
		for field in ["arrangement_midi_sha256", "arrangement_plan_sha256", "source_audio_sha256", "render_sha256"]:
			expect(str(metadata.get(field, "")).length() == 64, "published D2 provenance hash " + str(field) + ": " + str(entry.cue_id))
		expect(metadata.has("integrated_lufs") and metadata.has("true_peak_dbtp"), "published game-level loudness metadata: " + str(entry.cue_id))
	for entry: Dictionary in experiment.old_music.retire_from_test_runtime_and_music_room:
		expect(not CATALOG.has_cue(entry.id), "retired cue absent from selectable catalog: " + str(entry.id))
		if not allocation_only: expect(not ResourceLoader.exists("res://assets/music/chronicle/" + str(entry.id) + ".ogg"), "retired Ogg removed from source resources: " + str(entry.id))
	for page in ["home", "world", "preparation", "failure", "journal", "camp"]:
		expect(ROUTING.page_cue(page, "B01") == allocation.pages[page].cue_id, "page allocation: " + page)
	for page in allocation.pages.utilities.pages:
		expect(ROUTING.page_cue(page, "B01").is_empty(), "utility inherits scene music: " + str(page))
	for page in ["roster", "equipment"]:
		expect(ROUTING.page_cue(page, "B01", "preparation") == "midi_test_05" and ROUTING.page_cue(page, "B01", "route") == "camp_home", "party context: " + page)
	expect(ROUTING.node_cue("unknown") == "midi_test_11" and ROUTING.route_cue("unknown") == "midi_test_11" and ROUTING.page_cue("unknown", "unknown") == "midi_test_11", "routing unknown fallback is new cue")
	expect(STORIES.for_node({"id":"unknown"}).music == "midi_test_11", "unproduced story fallback is new cue")
	expect(STORIES.validate().is_empty(), "story and authored music metadata validate")
	walk_route("S01", {}, 0)
	expect(complete_routes == 64 and minimum_battles == 12 and maximum_battles == 15, "all 64 real routes preserve 12–15 battles and invoke all 12 new songs")

func walk_route(id: String, invoked: Dictionary, battles: int) -> void:
	var songs := invoked.duplicate()
	var node: Dictionary = route_nodes[id]
	songs[ROUTING.node_cue(id)] = true
	songs[ROUTING.route_cue(id)] = true
	if node.kind in ["battle", "elite", "boss"]: battles += 1
	if story_events.has(id):
		for line: Dictionary in story_events[id].lines: songs[ROUTING.story_cue(story_events[id], line.id)] = true
	if node.next.is_empty():
		complete_routes += 1
		minimum_battles = mini(minimum_battles, battles)
		maximum_battles = maxi(maximum_battles, battles)
		for index in range(1, 13): expect(songs.has("midi_test_%02d" % index), "full route %d invokes new song %02d" % [complete_routes, index])
	else:
		for next: String in node.next: walk_route(next, songs, battles)

func verify_boss_phase(shell: Control, id: String) -> void:
	shell.session.data.current = id
	shell.session.data.available = [id]
	shell.start_battle()
	var view: Control = shell.battle_view
	view.set_physics_process(false)
	view.toggle_pause()
	expect(shell.bgm.paused_by_script, "real battle pause freezes music: " + id)
	view.toggle_pause()
	expect(not shell.bgm.paused_by_script, "real battle resumes music: " + id)
	view.battle.director.elapsed = float(view.battle.director.config.boss_time)
	view.battle.tick(0.0, Vector2.ZERO)
	var found := false
	for enemy in view.battle.enemies:
		if enemy.rank == "boss":
			RESOLVER.hit_enemy(enemy, {"damage":enemy.hp, "slow":0.0, "duration":0.0, "direct":true})
			found = true
	view.battle.tick(1.0 / 60.0, Vector2.ZERO)
	shell.bgm.restore_playback_position(9.0)
	shell.bgm.resume_music()
	var active: AudioStreamPlayer = shell.bgm._active
	view._publish_music_context()
	expect(found and shell.bgm.current_cue == ROUTING.node_cue(id), "actual boss depletion keeps selected song: " + id)
	expect(shell.bgm._active == active and absf(shell.bgm.stored_playback_position - 9.0) < 0.25 and shell.bgm._stinger_cue.is_empty(), "form transition retains same player and timeline without transform overlay: " + id)
	view.battle.outcome = "victory"
	view._publish_music_context()
	expect(shell.bgm.current_cue == ROUTING.node_cue(id) and shell.bgm._stinger_cue.is_empty() and shell.bgm._duck_gain == 1.0, "boss victory continues full song without fanfare: " + id)
	view.cancelled.emit()
