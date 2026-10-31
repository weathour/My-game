extends SceneTree
## Real immediate-melee pipeline, PCM transient onset and bounded clutter fixtures.
const VIEW := preload("res://scripts/ui/chronicle/battle_view.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const ENEMY_ACTOR := preload("res://scripts/ui/chronicle/enemy_actor.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")
var checks := 0
var failures := 0
var baseline := false
var report_dir := ""
var observations: Array = []
var viewport: SubViewport
var view: Control
var input_usec := 0
var batch_usec := 0
var batches: Array = []
var live_input_armed := false
var live_batch_usec := 0

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--baseline": baseline = true
		if arg.begins_with("--report="): report_dir = arg.trim_prefix("--report=")
	call_deferred("run")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func received(events: Array) -> void:
	batch_usec = Time.get_ticks_usec()
	batches = events.duplicate(true)
	if live_input_armed and live_batch_usec == 0:
		for event in events:
			if event.kind == "cast" and event.ability == "jia_sweep": live_batch_usec = Time.get_ticks_usec()

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"),"isolated latency settings")
	if failures: quit(1); return
	if not report_dir.is_empty(): DirAccess.make_dir_recursive_absolute(report_dir)
	viewport = SubViewport.new(); viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var enemy_pose := ENEMY_ACTOR.new()
	enemy_pose.setup("E01")
	root.add_child(enemy_pose)
	enemy_pose.play_release({"action_id":"swipe"},1.1)
	if not baseline: expect(enemy_pose.sprite.frame == 2,"enemy release starts on exact declared contact frame despite floating-point subtraction")
	enemy_pose.free()
	var old_volume := SETTINGS.load_sfx_volume()
	SETTINGS.save_sfx_volume(.65)
	for count in [3,42]: await fixture(count)
	SETTINGS.save_sfx_volume(old_volume)
	viewport.free()
	await process_frame
	await create_timer(.16).timeout
	if not report_dir.is_empty():
		var file := FileAccess.open(report_dir.path_join("timing.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"baseline":baseline,"observations":observations},"  "))
	print("CHRONICLE_FEEDBACK_LATENCY_SMOKE ","PASS" if failures == 0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)

func fixture(count: int) -> void:
	var defs := {}
	for row in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")): defs[row.id] = row
	view = VIEW.new()
	view.setup({"attempt_id":"latency","members":["JIA"],"characters":{"JIA":C.record("JIA",1)},"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":""},"stage":C.stage("B01"),"seed":1701,"node":{"id":"B01","name":"白门楼·荒道"}},defs)
	viewport.add_child(view); view.set_physics_process(false)
	await process_frame
	var b: RefCounted = view.battle
	b.enemies.clear(); b.director.spawn_remaining = 10000; b.director.config.boss_time = 10000; b.director.config.boss_kills = 10000
	for i in count:
		var point: Vector2 = b.position + Vector2(cos(i * 2.39996),sin(i * 2.39996)) * (55 + (i % 5) * 16)
		var enemy: RefCounted = b.director.spawn("E01",point)
		enemy.speed = 0; enemy.cooldown = 10000; enemy.hp = 99999; enemy.max_hp = 99999
		b.enemies.append(enemy)
	view.canvas.refresh(false)
	view.canvas.presentation_events.connect(received)
	var f: Node = view.canvas.combat_feedback
	f.trace_enabled = true
	var event := InputEventAction.new(); event.action = "battle_skill_one"; event.pressed = true
	input_usec = Time.get_ticks_usec()
	view._unhandled_input(event)
	var tick_start := Time.get_ticks_usec()
	view._physics_process(1.0/60)
	var refresh_end := Time.get_ticks_usec()
	var first_batch_usec := batch_usec
	var sprite: AnimatedSprite2D = view.canvas.actor_visual.sprite
	var pose_frame := sprite.frame
	var marks_first: int = f.marks.size()
	var bars_first := 0
	for enemy in b.enemies:
		if view.canvas._health_bar_visible(enemy): bars_first += 1
	var hit_bodies := 0
	for entry in view.canvas.enemy_views.values():
		if entry.node.get("clip_name") == "hit": hit_bodies += 1
	var cast_time := -1.0; var damage_time := -2.0; var damage_total := 0.0; var damage_count := 0
	for row in batches:
		if row.kind == "cast" and row.ability == "jia_sweep": cast_time = row.time
		if row.kind == "damage_dealt" and row.ability == "jia_sweep": damage_time = row.time; damage_total += row.amount; damage_count += 1
	expect(cast_time == damage_time and damage_count == count,"manual successful cast and all damage settle same simulation tick")
	expect(pose_frame == 1 and marks_first > 0,"actor contact pose and confirmed marks exist before first draw")
	if not baseline:
		for effect in b.effects:
			if effect.get("source", "") == "JIA" and effect.kind in ["ring","slash"]:
				var key := "sweep" if effect.kind == "ring" else "thrust" if effect.get("narrow", false) else "slash"
				expect(view.canvas._jia_contact_texture(effect) == view.canvas.jia_effects.frames[key][1],"JIA VFX main contact frame exists on the settled tick")
	var render_usec := refresh_end
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		render_usec = Time.get_ticks_usec()
		if not report_dir.is_empty(): viewport.get_texture().get_image().save_png(report_dir.path_join("B01-%d-first-draw.png" % count))
	if not baseline:
		expect(hit_bodies == 0, "confirmed damage preserves readable enemy body pose")
		expect(marks_first <= 6, "two direct casts retain at most three contact marks each")
		expect(bars_first <= 7, "ordinary health bars follow primary contacts and current target")
	var audio: Array = []
	for trace in f.trace_records:
		if trace.kind == "audio_start":
			var stream: AudioStreamWAV = load(trace.path)
			var peak := 0.0
			for i in stream.data.size()/2: peak = maxf(peak,absf(float(stream.data.decode_s16(i*2))/32768))
			var first := 0
			for i in stream.data.size()/2:
				if absf(float(stream.data.decode_s16(i*2))/32768) >= peak * .5: first = i; break
			var onset_ms := float(first) * 1000 / stream.mix_rate
			audio.append({"category":trace.category,"path":trace.path,"schedule_after_input_ms":(trace.wall_usec-input_usec)/1000.0,"half_peak_onset_ms":onset_ms})
			if not baseline and trace.category in ["hit_light","hit_heavy","guard"]: expect(onset_ms <= 8,"contact PCM reaches half peak within 8ms")
	var timings: Array[float] = []
	# Let texture uploads, shader compilation and first glyph caching finish before profiling.
	for warm in 12:
		view._physics_process(1.0/60)
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	for frame in 90:
		var start := Time.get_ticks_usec()
		view._physics_process(1.0/60)
		timings.append((Time.get_ticks_usec()-start)/1000.0)
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	timings.sort()
	# Separate live engine scheduling from the controlled one-tick CPU fixture.
	b.current().cooldowns["jia_sweep"] = 0
	b.current().cooldowns["JIA_basic"] = 10000
	b.current().mp = b.current().stats.mp
	live_input_armed = true; live_batch_usec = 0
	var live_input_usec := Time.get_ticks_usec()
	view.set_physics_process(true)
	viewport.push_input(event)
	for attempt in 8:
		await physics_frame
		await process_frame
		if live_batch_usec > 0: break
	expect(live_batch_usec > 0, "viewport input reaches real physics cast processing")
	var live_refresh_usec := Time.get_ticks_usec()
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	var live_draw_usec := Time.get_ticks_usec()
	view.set_physics_process(false); live_input_armed = false
	observations.append({"enemies":count,"seed":1701,"live_input_to_batch_ms":(live_batch_usec-live_input_usec)/1000.0,"live_input_to_refresh_sample_ms":(live_refresh_usec-live_input_usec)/1000.0,"live_input_to_first_draw_ms":(live_draw_usec-live_input_usec)/1000.0,"input_to_batch_ms":(first_batch_usec-input_usec)/1000.0,"first_tick_cpu_ms":(refresh_end-tick_start)/1000.0,"input_to_refresh_ms":(refresh_end-input_usec)/1000.0,"input_to_first_draw_ms":(render_usec-input_usec)/1000.0,"actor_contact_frame":pose_frame,"jia_vfx_first_frame":1 if not baseline else 0,"cast_sim_time":cast_time,"damage_sim_time":damage_time,"damage_count":damage_count,"damage_total":damage_total,"marks_on_first_draw":marks_first,"ordinary_health_bars_first_draw":bars_first,"whole_body_hit_clips":hit_bodies,"audio":audio,"physics_p50_ms":timings[45],"physics_p95_ms":timings[85],"physics_max_ms":timings[-1],"pipeline_boundary":"Input handler to tick/refresh/draw. Dummy output is not measured acoustic device latency; PCM onset is measured relative to play scheduling."})
	view.free(); await process_frame
