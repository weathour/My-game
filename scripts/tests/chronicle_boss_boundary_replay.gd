extends "res://scripts/tests/chronicle_boss_playback.gd"
## Replays screenshot-directed commands through Input/BattleView; never calls drive().
var all_commands := false
var commands_path := "/tmp/mygame-boss-boundary-commands.json"

func _init() -> void:
	super()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--commands="): commands_path = argument.trim_prefix("--commands=")
		if argument == "--all-commands": all_commands = true

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated command replay")
	var routes: Array = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	var entry: Dictionary = {}
	for route in routes:
		if route.route != route_name: continue
		for record in route.battles:
			if record.stage == "B18": entry = record
	var commands: Array = JSON.parse_string(FileAccess.get_file_as_string(commands_path))
	expect(not entry.is_empty() and commands.size() >= 8, "real B18 entry and eight logged commands")
	if failures: quit(1); return
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")): definitions[person.id] = person
	viewport = SubViewport.new()
	viewport.size = dimensions
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	DirAccess.make_dir_recursive_absolute(output_dir)
	_new_view(entry)
	await process_frame
	view._layout_hud()
	_release_inputs()
	view._physics_process(1.0/60)
	await _png("boundary-seq-0000")
	var phases := {}
	var samples: Array = []
	var command_count := commands.size() if all_commands else 8
	for index in command_count:
		var command: Dictionary = commands[index]
		if command.get("quit", false): break
		var before_command: float = view.battle.director.elapsed
		var movement: Array = command.get("move",[0,0])
		_set_movement(Vector2(float(movement[0]),float(movement[1])).limit_length(1))
		if command.has("pause") and bool(command.pause) != view.battle.paused: _key(KEY_ESCAPE)
		if int(command.get("switch",0)) != 0: _key(KEY_Q if int(command.switch) < 0 else KEY_E)
		for slot in command.get("skills",[]): _key(KEY_J if int(slot) == 0 else KEY_K)
		var clipped_frames := 0
		for frame in int(command.get("frames",60)):
			view._physics_process(1.0/60)
			var state: Dictionary = view.canvas.camera_state()
			for enemy in view.battle.enemies:
				if enemy.rank != "boss" or not view.canvas.enemy_views.has(enemy.id): continue
				phases[str(enemy.form_index)] = true
				var rect: Rect2 = view.canvas._body_rect(view.canvas.enemy_views[enemy.id].node, enemy.position)
				if not state.safe_screen.grow(1).encloses(Rect2(state.base_origin + rect.position * state.scale, rect.size * state.scale)): clipped_frames += 1
			if frame % 5 == 0: await process_frame
		_release_inputs()
		view.canvas.refresh(false)
		await _png("boundary-seq-%04d" % int(command.seq))
		if view.battle.paused: expect(view.battle.director.elapsed == before_command, "logged pause freezes simulation time")
		samples.append({"command":command,"elapsed":view.battle.director.elapsed,"boss_label":view.boss_label.text,"outcome":view.battle.outcome,"active":view.battle.current().id,"clipped_frames":clipped_frames,"camera":view.canvas.camera_state()})
		expect(clipped_frames == 0, "boss body remains visible throughout command " + str(command.seq))
	if all_commands:
		expect(view.battle.outcome == "victory" and completions == 1 and fail_signals == 0, "full command replay completes once through real BattleView")
		expect(phases.has("0") and phases.has("1"), "full command replay traverses both real forms")
	_write_json(output_dir.path_join("boundary-replay.json"), {"mode":"replayed_agent_screenshot_commands", "human_acceptance":false, "drive_called":false,"source_request":entry.request,"commands":commands.slice(0,command_count),"samples":samples,"phase_seen":phases.keys(),"completed_signals":completions,"failed_signals":fail_signals,"metrics":end_metrics(view.battle,metric),"checks":checks,"failures":failures})
	view.queue_free(); viewport.queue_free()
	await process_frame
	if DisplayServer.get_name() != "headless": await create_timer(.12).timeout
	print("CHRONICLE_BOSS_BOUNDARY_REPLAY ", "PASS" if failures == 0 else "FAIL", " checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
