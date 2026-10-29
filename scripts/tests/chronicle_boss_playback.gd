extends "res://scripts/tests/chronicle_enemy_sessions_smoke.gd"
## Capture: --fixed-fps 12 --rendering-method gl_compatibility --audio-driver Dummy
## --script scripts/tests/chronicle_boss_playback.gd -- --stage=B15,B16,B17,B18
## --route=explore --output=/path/to/evidence [--probe-seconds=2]
## Interactive: --max-fps 30 ... -- --interactive=/tmp/mygame-boss-interactive
## Recorded pixels are the real BattleView with automatic/agent inputs, not human acceptance.
const VIEW := preload("res://scripts/ui/chronicle/battle_view.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")
const INPUTS := preload("res://scripts/battle/battle_input.gd")
var source_path := "res://docs/implementation/evidence/2026-10-29/boss-depth/balance/campaign-r3.json"
var route_name := "explore"
var output_dir := "/tmp/my-game-boss-playback"
var frames_root := "/tmp/my-game-boss-playback-frames"
var interactive_dir := ""
var probe_seconds := -1.0
var max_seconds := 360.0
var dimensions := Vector2i(1280,720)
var video_enabled := true
var viewport: SubViewport
var view: Control
var definitions: Dictionary = {}
var metric: Dictionary = {}
var frame_events: Array = []
var completions := 0
var fail_signals := 0
var playback_reports: Array = []
var active_label := ""
var sample_index := 0
var key_marks: Dictionary = {}
var ordinary_frames := 0
var recording_frames := 0
var input_log: FileAccess
var observed_clock := -1.0

func _init() -> void:
	super()
	# The inherited constructor schedules the overridden run() exactly once.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--route="): route_name = argument.trim_prefix("--route=")
		if argument.begins_with("--output="): output_dir = argument.trim_prefix("--output=")
		if argument.begins_with("--frames="): frames_root = argument.trim_prefix("--frames=")
		if argument.begins_with("--source="): source_path = argument.trim_prefix("--source=")
		if argument.begins_with("--interactive="): interactive_dir = argument.trim_prefix("--interactive=")
		if argument.begins_with("--probe-seconds="): probe_seconds = float(argument.trim_prefix("--probe-seconds="))
		if argument.begins_with("--max-seconds="): max_seconds = float(argument.trim_prefix("--max-seconds="))
		if argument.begins_with("--width="):
			dimensions.x = int(argument.trim_prefix("--width=")); dimensions.y = dimensions.x * 9 / 16
		if argument == "--no-video": video_enabled = false

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "playback settings and saves must be isolated")
	var source = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	expect(source is Array, "campaign evidence contains route list")
	if failures: quit(1); return
	var selected: Dictionary = {}
	for route in source:
		if str(route.get("route", "")) == route_name: selected = route
	expect(not selected.is_empty(), "requested route exists")
	if failures: quit(1); return
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")): definitions[person.id] = person
	INPUTS.install()
	viewport = SubViewport.new()
	viewport.size = dimensions
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	if not interactive_dir.is_empty():
		for record in selected.battles:
			if str(record.stage) == "B18":
				await _interactive(record)
				return
		expect(false, "interactive route includes true B18 entry")
		quit(1); return
	DirAccess.make_dir_recursive_absolute(output_dir)
	for record in selected.battles:
		var id := str(record.stage)
		if id not in ["B15","B16","B17","B18"]: continue
		if not only_stage.is_empty() and id not in only_stage.split(","): continue
		await _play(record)
	var report := {"mode":"automated_inputs_real_BattleView", "human_acceptance":false, "source":source_path, "source_sha256":FileAccess.get_sha256(source_path), "route":route_name, "current_stage_config":true, "fps":12, "simulation_dt":1.0/60, "dimensions":str(dimensions), "audio_track":false, "driver":DRIVER_REVISION, "checks":checks, "failures":failures, "playbacks":playback_reports}
	_write_json(output_dir.path_join("playback-report.json"), report)
	viewport.queue_free()
	await process_frame
	if DisplayServer.get_name() != "headless": await create_timer(.12).timeout
	print("CHRONICLE_BOSS_PLAYBACK ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures, " stages=", playback_reports.size())
	quit(0 if failures == 0 else 1)

func _new_view(record: Dictionary) -> void:
	var request: Dictionary = record.request.duplicate(true)
	# The QA request is the authority for obtained people, levels and carried HP/MP.
	# Only refresh production stage rules, never characters/resources/equipment/seed.
	request.stage = C.stage(str(record.stage))
	view = VIEW.new()
	view.setup(request, definitions)
	viewport.add_child(view)
	view.set_physics_process(false)
	metric = begin_metrics(view.battle)
	frame_events.clear()
	observed_clock = -1.0
	completions = 0; fail_signals = 0
	view.completed.connect(func(_result: Dictionary): completions += 1)
	view.failed.connect(func(): fail_signals += 1)
	view.canvas.presentation_events.connect(func(events: Array):
		frame_events = events
		if view.battle.director.elapsed > observed_clock:
			observe_metrics(view.battle, metric)
			observed_clock = view.battle.director.elapsed)

func _play(record: Dictionary) -> void:
	active_label = route_name + "-" + str(record.stage)
	sample_index = 0; recording_frames = 0; ordinary_frames = 0
	key_marks.clear()
	_new_view(record)
	await process_frame
	view._layout_hud()
	var battle: RefCounted = view.battle
	var jpg_dir := frames_root.path_join(active_label)
	DirAccess.make_dir_recursive_absolute(jpg_dir)
	for stale in DirAccess.get_files_at(jpg_dir):
		if stale.ends_with(".jpg"): DirAccess.remove_absolute(jpg_dir.path_join(stale))
	input_log = FileAccess.open(output_dir.path_join(active_label + "-inputs.jsonl"), FileAccess.WRITE)
	var pause_checked := false
	var saw_boss := false
	var phase_seen := {}
	var sampled_view: Dictionary = {}
	var probe := false
	for frame in int(max_seconds * 60):
		if completions > 0 or fail_signals > 0: break
		var movement := Vector2.ZERO
		if battle.outcome.is_empty():
			if not battle.director.boss_spawned and bool(battle.director.config.get("fields_enabled", true)) and battle.director.field == -1 and int(record.field) >= 0:
				movement = (SPACE.FIELD_POSITIONS[int(record.field)] - battle.position).normalized()
			else: movement = drive(battle)
		_set_movement(movement)
		var commands := {"step":frame, "move":[movement.x,movement.y]}
		if frame % 30 == 0 and battle.outcome.is_empty():
			_key(KEY_J); _key(KEY_K); commands.skills = [0,1]
		if battle.outcome.is_empty() and battle.current().hp < battle.current().stats.hp * .25:
			for slot in battle.members.size():
				var candidate: RefCounted = battle.characters[battle.members[slot]]
				if not candidate.dead and candidate.hp > candidate.stats.hp * .55:
					var direction := signi(slot - battle.active)
					_key(KEY_Q if direction < 0 else KEY_E)
					commands.switch = direction
					commands.switch_reason = "controlled_hp_below_25_candidate_above_55"
					break
		input_log.store_line(JSON.stringify(commands))
		view._physics_process(1.0 / 60.0)
		if battle.director.boss_spawned:
			saw_boss = true
			recording_frames += 1
			for enemy in battle.enemies:
				if enemy.rank == "boss": phase_seen[str(enemy.form_index)] = true
			if not pause_checked and str(record.stage) == "B18" and recording_frames >= 90 and battle.outcome.is_empty():
				await _check_pause(jpg_dir)
				pause_checked = true
			if recording_frames % 5 == 0:
				await _capture_step(jpg_dir)
				var state: Dictionary = view.canvas.camera_state()
				sampled_view = {"zoom":state.zoom, "viewport":str(state.bounds), "escape_valid":state.escape_valid, "escape_needed":state.escape_needed}
			for event in frame_events:
				var kind := str(event.get("kind", ""))
				if kind in ["boss_phase", "boss_defeated"]:
					await _png(active_label + "-" + kind)
				elif kind == "boss_impact" and not key_marks.has("impact-" + str(event.get("form_index",event.get("phase",0)))):
					var key := "impact-" + str(event.get("form_index",event.get("phase",0)))
					key_marks[key] = true
					await _png(active_label + "-" + key)
			if recording_frames == 5: await _png(active_label + "-human-entry")
		else:
			ordinary_frames += 1
			if frame % 120 == 0: await process_frame
		if probe_seconds >= 0 and recording_frames >= int(probe_seconds * 60): probe = true; break
	_release_inputs()
	input_log.flush(); input_log = null
	var result: Dictionary = end_metrics(battle, metric)
	result.stage = str(record.stage)
	result.source_request = record.request.duplicate(true)
	result.entry_request = view.request.duplicate(true)
	result.recording = {"mode":"automatic_input_real_renderer" if DisplayServer.get_name() != "headless" else "automatic_input_headless_probe", "render_backend":DisplayServer.get_name(), "human_acceptance":false, "probe_incomplete":probe, "captured_frames":sample_index, "preboss_simulated_steps":ordinary_frames, "recorded_steps":recording_frames, "completed_signals":completions, "failed_signals":fail_signals, "phase_seen":phase_seen.keys(), "pause_input_checked":pause_checked, "last_camera":sampled_view}
	if not probe:
		expect(saw_boss and phase_seen.has("0") and phase_seen.has("1"), active_label + " captured both real forms")
		expect(battle.outcome == "victory" and completions == 1 and fail_signals == 0, active_label + " completed via real BattleView signal")
		await _png(active_label + "-terminal")
	if video_enabled and sample_index > 0 and DisplayServer.get_name() != "headless":
		result.recording.video = _encode(jpg_dir, output_dir.path_join(active_label + ".mp4"))
	playback_reports.append(result)
	print("BOSS_PLAYBACK ", active_label, " outcome=", result.outcome, " seconds=", snappedf(battle.director.elapsed,.01), " frames=",sample_index," forms=",phase_seen.keys()," probe=",probe)
	view.queue_free()
	view = null
	await process_frame

func _check_pause(jpg_dir: String) -> void:
	_release_inputs()
	var before: float = view.battle.director.elapsed
	var hp: float = view.battle.current().hp
	var camera_clock: float = view.canvas.camera.clock
	_key(KEY_ESCAPE)
	expect(view.battle.paused, "Esc input pauses the real BattleView")
	for i in 30:
		view._physics_process(1.0 / 60)
		if i % 5 == 0: await _capture_step(jpg_dir)
	expect(view.battle.director.elapsed == before and view.battle.current().hp == hp and view.canvas.camera.clock == camera_clock, "paused input does not advance fight or camera")
	await _png(active_label + "-paused")
	_key(KEY_ESCAPE)
	expect(not view.battle.paused, "Esc input resumes the real BattleView")
	input_log.store_line(JSON.stringify({"kind":"pause_input_check", "seconds":before, "paused_steps":30, "frozen":view.battle.director.elapsed == before}))

func _set_movement(value: Vector2) -> void:
	for action in ["battle_left","battle_right","battle_up","battle_down"]: Input.action_release(action)
	if value.x < 0: Input.action_press("battle_left", -value.x)
	if value.x > 0: Input.action_press("battle_right", value.x)
	if value.y < 0: Input.action_press("battle_up", -value.y)
	if value.y > 0: Input.action_press("battle_down", value.y)

func _release_inputs() -> void:
	_set_movement(Vector2.ZERO)
	for action in ["battle_previous","battle_next","battle_skill_one","battle_skill_two","battle_pause"]: Input.action_release(action)

func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code; event.physical_keycode = code; event.pressed = true
	Input.parse_input_event(event)
	viewport.push_input(event)
	event = event.duplicate(); event.pressed = false
	Input.parse_input_event(event)
	viewport.push_input(event)

func _capture_step(directory: String) -> void:
	await process_frame
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_jpg(directory.path_join("%06d.jpg" % sample_index), .87)
	sample_index += 1

func _png(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output_dir.path_join(label + ".png"))

func _encode(directory: String, target: String) -> Dictionary:
	var output: Array = []
	var status := OS.execute("ffmpeg", ["-y","-loglevel","error","-framerate","12","-i",directory.path_join("%06d.jpg"),"-c:v","libx264","-preset","veryfast","-crf","28","-pix_fmt","yuv420p","-movflags","+faststart",target], output, true)
	if status == 0:
		for filename in DirAccess.get_files_at(directory):
			if filename.ends_with(".jpg"): DirAccess.remove_absolute(directory.path_join(filename))
	else: expect(false, "ffmpeg encoding " + target)
	return {"path":target,"exit":status,"silent":true,"frames":sample_index,"fps":12,"errors":output}

func _interactive(record: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(interactive_dir)
	output_dir = interactive_dir
	_new_view(record)
	await process_frame
	view._layout_hud()
	_release_inputs()
	view._physics_process(1.0/60)
	view.canvas.refresh(false)
	view.canvas.actors.process_mode = Node.PROCESS_MODE_DISABLED
	var sequence := 0
	_write_json(interactive_dir.path_join("entry-request.json"), view.request)
	_write_json(interactive_dir.path_join("session.json"), {"mode":"agent_screenshot_control", "human_acceptance":false,"source":source_path,"route":route_name,"stage":"B18","dt":1.0/60,"commands":"seq, move:[x,y], frames:0..600, skills:[0,1], switch:-1/1, pause:boolean, quit:boolean", "simulation_frozen_between_commands":true})
	input_log = FileAccess.open(interactive_dir.path_join("commands-and-results.jsonl"), FileAccess.WRITE)
	await _write_interactive(sequence)
	print("BOSS_INTERACTIVE_READY ", interactive_dir)
	while is_instance_valid(view):
		await create_timer(.1).timeout
		var path := interactive_dir.path_join("command.json")
		if not FileAccess.file_exists(path): continue
		var command = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not command is Dictionary or int(command.get("seq",0)) <= sequence: continue
		sequence = int(command.seq)
		if command.get("quit", false):
			var state := await _write_interactive(sequence)
			input_log.store_line(JSON.stringify({"command":command,"visible_result":state}))
			input_log.flush()
			break
		var values: Array = command.get("move", [0,0])
		var movement := Vector2(float(values[0]),float(values[1])).limit_length(1) if values.size() == 2 else Vector2.ZERO
		_set_movement(movement)
		if command.has("pause") and bool(command.pause) != view.battle.paused: _key(KEY_ESCAPE)
		if int(command.get("switch",0)) != 0: _key(KEY_Q if int(command.switch) < 0 else KEY_E)
		for slot in command.get("skills",[]):
			if int(slot) in [0,1]: _key(KEY_J if int(slot) == 0 else KEY_K)
		var count := clampi(int(command.get("frames",60)),0,600)
		for step in count:
			view._physics_process(1.0/60)
			if step % 5 == 0: await process_frame
		_release_inputs()
		view.canvas.refresh(movement.length_squared() > 0)
		view.refresh()
		view.canvas.actors.process_mode = Node.PROCESS_MODE_DISABLED
		var state := await _write_interactive(sequence)
		input_log.store_line(JSON.stringify({"command":command, "visible_result":state}))
		input_log.flush()
		if not view.battle.outcome.is_empty(): print("BOSS_INTERACTIVE_OUTCOME ", view.battle.outcome)
	_release_inputs()
	input_log = null
	view.queue_free(); viewport.queue_free()
	await process_frame
	if DisplayServer.get_name() != "headless": await create_timer(.12).timeout
	quit(0)

func _write_interactive(sequence: int) -> Dictionary:
	var battle: RefCounted = view.battle
	var visible_members := []
	for id in battle.members:
		var character: RefCounted = battle.characters[id]
		visible_members.append({"id":id,"name":definitions[id].name,"hp":character.hp,"max_hp":character.stats.hp,"mp":character.mp,"max_mp":character.stats.mp,"dead":character.dead})
	var state := {"seq":sequence,"elapsed":battle.director.elapsed,"clock_label":view.timing.text,"active":battle.current().id,"members":visible_members,"boss_label":view.boss_label.text,"boss_health_ratio":view.boss_bar.value/maxf(1,view.boss_bar.max_value),"outcome":battle.outcome,"paused":battle.paused,"message":view.feedback.text if view.feedback.visible else "","completed_signals":completions,"failed_signals":fail_signals,"simulation_frozen_between_commands":true}
	var plate: Control = view.hud.presentation
	if plate.get("skills") != null:
		state.skills = []
		for skill in plate.skills: state.skills.append({"key":skill.key.text,"title":skill.title.text,"state":skill.state.text})
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.save_png(interactive_dir.path_join("frame.png"))
		image.save_png(interactive_dir.path_join("frame-%04d.png" % sequence))
	_write_json(interactive_dir.path_join("state.json"), state)
	return state

func _write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(value,"  "))
