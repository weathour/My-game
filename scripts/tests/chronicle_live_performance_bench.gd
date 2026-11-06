extends SceneTree
## Sustained, rendered combat benchmark. Uses the same per-frame view pipeline as
## BattleView._physics_process while timing each stage independently.
const VIEW := preload("res://scripts/ui/chronicle/battle_view.gd")
const COMBAT := preload("res://scripts/content/combat_catalog.gd")
const SETTINGS := preload("res://scripts/shared/settings.gd")
const STEP := 1.0 / 60.0
const WIDTH := 1280
const HEIGHT := 720
const TRACE := [Vector2.RIGHT, Vector2(0.7,0.7), Vector2.DOWN, Vector2(-0.7,0.7), Vector2.LEFT, Vector2(-0.7,-0.7), Vector2.UP, Vector2(0.7,-0.7)]
const SCENARIOS := [
	{"id":"B01", "frames":720, "seed":2026110501, "enemy_hp_factor":1.0, "members":["JIA","F11","N16"]},
	{"id":"B12", "frames":1500, "seed":2026110512, "enemy_hp_factor":8.0, "members":["JIA","F11","N16"]},
	{"id":"B18", "frames":720, "seed":2026110518, "enemy_hp_factor":1.0, "members":["JIA","M01","N16"]},
]
var out_dir := "design/performance-20261105/baseline"
var viewport: SubViewport
var container: SubViewportContainer
var view: Control
var definitions: Dictionary = {}
var opaque_bounds_available := false
var failures: Array[String] = []
var reports: Array[Dictionary] = []

func _init() -> void:
	# Keep the native GL test window from taking keyboard focus from a player's
	# existing game or editor. The visible desktop window remains 1280x720.
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DisplayServer.window_set_size(Vector2i(WIDTH,HEIGHT))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.trim_prefix("--out=")
		if arg == "--validate-only":
			print("CHRONICLE_LIVE_PERFORMANCE_BENCH PARSE_OK")
			quit(0)
			return
	call_deferred("run")

func _expect(value: bool, label: String) -> void:
	if not value: failures.append(label); push_error(label)

func _frames(count: int = 2) -> void:
	for i in count: await process_frame

func _request(stage_id: String, seed: int, members: Array) -> Dictionary:
	var records := {}
	for id in members: records[id] = COMBAT.record(str(id), 10)
	var stage: Dictionary = COMBAT.stage(stage_id)
	return {"attempt_id":"live-perf-%s-%d" % [stage_id,seed], "members":members.duplicate(), "characters":records,
		"equipment":{"weapon":"plain_blade", "armor":"cloth_armor", "accessory":"ember_seal"},
		"stage":stage, "seed":seed, "node":{"id":stage_id, "name":"性能基准 %s" % stage_id}}

func _prepare_view(stage_id: String, seed: int, members: Array) -> Dictionary:
	var setup_start := Time.get_ticks_usec()
	var request := _request(stage_id, seed, members)
	view = VIEW.new()
	view.setup(request, definitions)
	var setup_ms := float(Time.get_ticks_usec() - setup_start) / 1000.0
	var stage_config: Dictionary = view.battle.director.config.duplicate(true)
	if stage_id == "B12":
		# Keep the actual B12 spawn rate and 80-enemy cap while extending enemy
		# survival so the dense fixture sustains its intended population.
		view.battle.director.config.boss_time = 100000.0
		view.battle.director.config.boss_kills = 100000
	var mount_ready_start := Time.get_ticks_usec()
	viewport.add_child(view)
	var mount_ready_ms := float(Time.get_ticks_usec() - mount_ready_start) / 1000.0
	# BattleView creates its Canvas in _ready; turn tracing on synchronously now,
	# before the first rendered frame of this newly mounted view.
	view.canvas.performance_trace_enabled = true
	opaque_bounds_available = false
	for property: Dictionary in view.canvas.get_property_list():
		if str(property.get("name", "")) == "opaque_bounds": opaque_bounds_available = true
	var canvas_before_ready: Dictionary = view.canvas.performance_counters.duplicate(true)
	view.set_physics_process(false)
	var ready_frame_start := Time.get_ticks_usec()
	await _frames(2)
	var ready_draw_ms := float(Time.get_ticks_usec() - ready_frame_start) / 1000.0
	var canvas_after_ready: Dictionary = view.canvas.performance_counters.duplicate(true)
	return {"view_setup_ms":setup_ms,"view_add_child_ready_ms":mount_ready_ms,"mount_to_ready_draw_ms":ready_draw_ms,
		"canvas_counters_before_mount":canvas_before_ready,"canvas_counters_after_ready":canvas_after_ready,
		"ready_draw_us":int(canvas_after_ready.get("draw_us",0)),"ready_foreground_us":int(canvas_after_ready.get("foreground_us",0)),
		"ready_bounds_readbacks":int(canvas_after_ready.get("bounds_readbacks",0)),"ready_bounds_readback_us":int(canvas_after_ready.get("bounds_readback_us",0)),
		"stage_config":{"enemy_cap":int(stage_config.get("enemy_cap",0)),"boss_time":float(stage_config.get("boss_time",0)),"boss_kills":int(stage_config.get("boss_kills",0)),
			"spawn_interval":float(stage_config.get("spawn_interval",0)),"seed":seed}}

func _reset_view() -> void:
	if is_instance_valid(view):
		viewport.remove_child(view)
		view.free()
	view = null
	await _frames(1)

func _opaque_bounds_cache_entries() -> Variant:
	if not opaque_bounds_available or view == null or view.canvas == null: return null
	var bounds: Variant = view.canvas.get("opaque_bounds")
	return bounds.size() if bounds is Dictionary else null

func _rendering_method_label() -> String:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--renderer-label="): return str(arg).trim_prefix("--renderer-label=")
	return str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"))

func _input_for_frame(frame: int) -> Vector2:
	# A deterministic, inexpensive eight-direction movement trace. This avoids
	# running a benchmark-only path-finding or hazard-avoidance algorithm.
	return TRACE[posmod(frame / 45, TRACE.size())]

func _record_population(report: Dictionary) -> void:
	var battle: RefCounted = view.battle
	var current := {
		"enemies":battle.enemies.size(), "projectiles":battle.projectiles.size(),
		"effects":battle.effects.size(), "hazards":battle.hazards.size(),
		"telegraphs":battle.telegraphs.size(), "pending_patterns":battle.pending_patterns.size(),
		"gems":battle.gems.size(), "enemy_views":view.canvas.enemy_views.size(),
		"actor_nodes":view.canvas.actors.get_child_count(), "texture_bounds_cache_entries":_opaque_bounds_cache_entries(),
		"skill_transients":view.canvas.authored_effects.skill.transients.size(),
		"skill_states":view.canvas.authored_effects.skill.states.size(),
		"authored_transients":view.canvas.authored_effects.transients.size(),
	}
	report.population_samples.append({"frame":report.population_sample_frame,"counts":current,
		"skill_counters":view.canvas.authored_effects.skill.counters.duplicate(true)})
	_update_population_max(report)

func _update_population_max(report: Dictionary) -> void:
	var battle: RefCounted = view.battle
	var current := {"enemies":battle.enemies.size(),"projectiles":battle.projectiles.size(),"effects":battle.effects.size(),
		"hazards":battle.hazards.size(),"telegraphs":battle.telegraphs.size(),"pending_patterns":battle.pending_patterns.size(),
		"gems":battle.gems.size(),"enemy_views":view.canvas.enemy_views.size(),"texture_bounds_cache_entries":_opaque_bounds_cache_entries(),
		"skill_transients":view.canvas.authored_effects.skill.transients.size(),"skill_states":view.canvas.authored_effects.skill.states.size(),
		"authored_transients":view.canvas.authored_effects.transients.size()}
	for key in current:
		if current[key] == null: continue
		report.population_max[key] = maxi(int(report.population_max.get(key,0)), int(current[key]))

func _input_trace(frame: int, battle: RefCounted) -> Vector2:
	if frame > 0 and frame % 210 == 0: battle.request_switch(1)
	if frame % 84 == 0: battle.request_skill((frame / 84) % 2)
	if frame % 132 == 0: battle.request_skill(((frame / 132) + 1) % 2)
	return _input_for_frame(frame)

func _actor_spriteframes_id() -> int:
	if view == null or view.canvas == null or view.canvas.actor_visual == null: return 0
	var sprite := view.canvas.actor_visual.get("sprite") as AnimatedSprite2D
	if sprite == null: sprite = view.canvas.actor_visual.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null: return 0
	return sprite.sprite_frames.get_instance_id()

func _actor_atlas_texture_ids() -> Array[int]:
	var ids: Array[int] = []
	if view == null or view.canvas == null or view.canvas.actor_visual == null: return ids
	var sprite := view.canvas.actor_visual.get("sprite") as AnimatedSprite2D
	if sprite == null: sprite = view.canvas.actor_visual.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null: return ids
	var seen := {}
	for animation in sprite.sprite_frames.get_animation_names():
		for index in sprite.sprite_frames.get_frame_count(animation):
			var texture := sprite.sprite_frames.get_frame_texture(animation,index)
			if texture is AtlasTexture and not seen.has(texture.get_instance_id()):
				seen[texture.get_instance_id()] = true
	for key in seen: ids.append(int(key))
	ids.sort()
	return ids

func _bench_frame(frame: int, report: Dictionary, boosted: Dictionary) -> void:
	var wall_start := Time.get_ticks_usec()
	var input_start := Time.get_ticks_usec()
	var direction := _input_trace(frame, view.battle)
	var input_ms := float(Time.get_ticks_usec() - input_start) / 1000.0
	var previous_actor := str(view.canvas.actor_kind)
	var bounds_before: Variant = _opaque_bounds_cache_entries()
	var battle: RefCounted = view.battle
	var start := Time.get_ticks_usec()
	battle.tick(STEP, direction)
	report.samples.battle_tick_ms.append(float(Time.get_ticks_usec() - start) / 1000.0)
	# Fixture durability adjustment applies only to newly spawned B12 ordinary
	# enemies. It changes no AI, spawn, collision, skill, or rendering code.
	if str(report.stage_id) == "B12":
		for enemy: RefCounted in battle.enemies:
			if not boosted.has(enemy.id):
				boosted[enemy.id] = true
				enemy.max_hp *= 8.0
				enemy.hp = enemy.max_hp
	var batch: Array = battle.events
	var manual_release_this_frame := false
	for event: Dictionary in batch:
		var kind := str(event.get("kind",""))
		report.event_counts[kind] = int(report.event_counts.get(kind,0)) + 1
		if kind == "ability_release" and bool(event.get("manual",false)): manual_release_this_frame = true
	start = Time.get_ticks_usec()
	view._present_messages(batch)
	report.samples.present_messages_ms.append(float(Time.get_ticks_usec() - start) / 1000.0)
	start = Time.get_ticks_usec()
	view._publish_music_context()
	report.samples.publish_music_context_ms.append(float(Time.get_ticks_usec() - start) / 1000.0)
	start = Time.get_ticks_usec()
	view.canvas.consume_events(batch)
	report.samples.canvas_consume_events_ms.append(float(Time.get_ticks_usec() - start) / 1000.0)
	battle.events.clear()
	start = Time.get_ticks_usec()
	view._sync_camera_obstacles()
	report.samples.sync_camera_obstacles_ms.append(float(Time.get_ticks_usec() - start) / 1000.0)
	start = Time.get_ticks_usec()
	view.canvas.advance_presentation(STEP)
	report.samples.advance_presentation_ms.append(float(Time.get_ticks_usec() - start) / 1000.0)
	if not battle.paused: view.message_time -= STEP
	start = Time.get_ticks_usec()
	view.canvas.refresh(direction.length_squared() > 0)
	var canvas_refresh_ms := float(Time.get_ticks_usec() - start) / 1000.0
	report.samples.canvas_refresh_ms.append(canvas_refresh_ms)
	var bounds_after: Variant = _opaque_bounds_cache_entries()
	if bounds_before is int and bounds_after is int:
		var bounds_entry_growth := maxi(0,int(bounds_after)-int(bounds_before))
		if bounds_entry_growth > 0:
			report.opaque_bounds_cache_entry_growth += bounds_entry_growth
			report.opaque_bounds_cache_entry_growth_frames.append({"frame":frame,"actor":str(view.canvas.actor_kind),"new_entries":bounds_entry_growth})
	else:
		report.opaque_bounds_entry_observation_available = false
		report.opaque_bounds_cache_entry_growth = null
	start = Time.get_ticks_usec()
	view.refresh()
	report.samples.hud_view_refresh_ms.append(float(Time.get_ticks_usec() - start) / 1000.0)
	var switched := previous_actor != str(view.canvas.actor_kind)
	var current_actor := str(view.canvas.actor_kind)
	var spriteframes_id := _actor_spriteframes_id()
	if switched:
		var atlas_ids := _actor_atlas_texture_ids()
		report.actor_switch_frames.append({"frame":frame,"from":previous_actor,"to":current_actor,"canvas_refresh_ms":canvas_refresh_ms,
			"spriteframes_id":spriteframes_id,"atlas_texture_ids":atlas_ids,"atlas_texture_count":atlas_ids.size()})
		var last_ids: Dictionary = report.get("last_spriteframes_id_by_actor",{})
		if last_ids.has(current_actor) and int(last_ids[current_actor]) != spriteframes_id:
			report.actor_spriteframes_recreated += 1
		last_ids[current_actor] = spriteframes_id
		report.last_spriteframes_id_by_actor = last_ids
		report.actor_spriteframes_resource_ids.append({"frame":frame,"actor":current_actor,"spriteframes_id":spriteframes_id})
	if current_actor in ["M01","M02","M03","M04","M05","M06"]:
		# battle_canvas.refresh calls ART.fit_actor once per frame; for these
		# six IDs that function rereads/parses a human-form manifest each time.
		report.human_actor_fit_actor_frames += 1
		report.human_actor_fit_actor_canvas_ms.append(canvas_refresh_ms)
	if frame == 0: report.first_tick_canvas_refresh_ms = canvas_refresh_ms
	if int(report.first_manual_skill_frame) < 0 and manual_release_this_frame:
		report.first_manual_skill_frame = frame
		report.first_manual_skill_tick_ms = report.samples.battle_tick_ms[-1]
		report.first_manual_skill_canvas_refresh_ms = canvas_refresh_ms
	if frame % 60 == 0:
		report.population_sample_frame = frame
		_record_population(report)
	var process_frame_before := Engine.get_process_frames()
	var physics_frame_before := Engine.get_physics_frames()
	var drawn_frame_before := Engine.get_frames_drawn()
	await RenderingServer.frame_post_draw
	var wall_ms := float(Time.get_ticks_usec() - wall_start) / 1000.0
	var process_delta := Engine.get_process_frames() - process_frame_before
	var physics_delta := Engine.get_physics_frames() - physics_frame_before
	var drawn_delta := Engine.get_frames_drawn() - drawn_frame_before
	report.process_frame_deltas.append(process_delta)
	report.physics_frame_deltas.append(physics_delta)
	report.frames_drawn_deltas.append(drawn_delta)
	report.engine_monitors.engine_time_process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	report.engine_monitors.engine_time_physics_process_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	report.engine_monitors.render_draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	report.engine_monitors.render_objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	report.engine_monitors.viewport_cpu_render_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid()))
	report.engine_monitors.viewport_gpu_render_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid()))
	report.engine_monitors.frame_setup_cpu_ms.append(RenderingServer.get_frame_setup_time_cpu())
	var current_canvas_counters: Dictionary = view.canvas.performance_counters.duplicate(true)
	var previous_canvas_counters: Dictionary = report.last_canvas_performance_counters
	var canvas_trace := {"frame":frame,"draw_ms":float(current_canvas_counters.get("draw_us",0))/1000.0,
		"foreground_ms":float(current_canvas_counters.get("foreground_us",0))/1000.0,
		"draw_calls_delta":int(current_canvas_counters.get("draw_calls",0))-int(previous_canvas_counters.get("draw_calls",0)),
		"foreground_calls_delta":int(current_canvas_counters.get("foreground_calls",0))-int(previous_canvas_counters.get("foreground_calls",0)),
		"bounds_readbacks_delta":int(current_canvas_counters.get("bounds_readbacks",0))-int(previous_canvas_counters.get("bounds_readbacks",0)),
		"bounds_readback_ms_delta":float(int(current_canvas_counters.get("bounds_readback_us",0))-int(previous_canvas_counters.get("bounds_readback_us",0)))/1000.0}
	report.canvas_trace_samples.append(canvas_trace)
	report.last_canvas_performance_counters = current_canvas_counters
	if not battle.outcome.is_empty(): report.terminal_frames += 1
	else: report.active_frames += 1
	if current_actor in ["M01","M02","M03","M04","M05","M06"]:
		report.human_actor_fit_actor_frame_wall_ms.append(wall_ms)
	if frame % 60 == 0:
		var ordinary_alive := 0
		var derivatives := 0
		var bosses := 0
		for enemy: RefCounted in battle.enemies:
			if enemy.dead: continue
			if enemy.rank == "boss": bosses += 1
			elif enemy.parent_id != 0: derivatives += 1
			elif enemy.rank in ["ordinary","heavy"]: ordinary_alive += 1
		report.wave_population_samples.append({"frame":frame,"ordinary_alive":ordinary_alive,"derivatives":derivatives,"bosses":bosses,
			"projectiles":battle.projectiles.size(),"effects":battle.effects.size()})
	report.samples.input_trace_ms.append(input_ms)
	report.samples.frame_wall_ms.append(wall_ms)
	_update_population_max(report)
	if int(report.first_manual_skill_frame) == frame and not report.has("first_manual_skill_frame_wall_ms"):
		report.first_manual_skill_frame_wall_ms = wall_ms
	if frame >= 120:
		report.warm_samples.input_trace_ms.append(input_ms)
		report.warm_samples.frame_wall_ms.append(wall_ms)
		report.warm_samples.battle_tick_ms.append(report.samples.battle_tick_ms[-1])
		report.warm_samples.present_messages_ms.append(report.samples.present_messages_ms[-1])
		report.warm_samples.publish_music_context_ms.append(report.samples.publish_music_context_ms[-1])
		report.warm_samples.canvas_consume_events_ms.append(report.samples.canvas_consume_events_ms[-1])
		report.warm_samples.sync_camera_obstacles_ms.append(report.samples.sync_camera_obstacles_ms[-1])
		report.warm_samples.advance_presentation_ms.append(report.samples.advance_presentation_ms[-1])
		report.warm_samples.canvas_refresh_ms.append(report.samples.canvas_refresh_ms[-1])
		report.warm_samples.hud_view_refresh_ms.append(report.samples.hud_view_refresh_ms[-1])
	if switched:
		var switch_row: Dictionary = report.actor_switch_frames[-1]
		switch_row["frame_wall_ms"] = wall_ms
		report.actor_switch_frames[-1] = switch_row
	if not battle.outcome.is_empty(): report.outcome_frame = frame

func _percentile(sorted_values: Array, fraction: float) -> float:
	if sorted_values.is_empty(): return 0.0
	var index := clampi(int(ceil((sorted_values.size() - 1) * fraction)), 0, sorted_values.size() - 1)
	return sorted_values[index]

func _summarize(values: Array) -> Dictionary:
	if values.is_empty(): return {"samples":0,"p50_ms":0.0,"p95_ms":0.0,"p99_ms":0.0,"max_ms":0.0,"over_16_67ms":0,"over_33_33ms":0,"over_50ms":0}
	var sorted_values: Array = values.duplicate()
	sorted_values.sort()
	var over16 := 0; var over33 := 0; var over50 := 0
	for value in values:
		if value > 16.67: over16 += 1
		if value > 33.33: over33 += 1
		if value > 50.0: over50 += 1
	return {"samples":values.size(), "p50_ms":_percentile(sorted_values,.50), "p95_ms":_percentile(sorted_values,.95),
		"p99_ms":_percentile(sorted_values,.99), "max_ms":sorted_values[-1],
		"over_16_67ms":over16,"over_33_33ms":over33,"over_50ms":over50}

func _summaries(samples: Dictionary) -> Dictionary:
	var result := {}
	for key in samples: result[key] = _summarize(samples[key])
	return result

func _summarize_population(samples: Array, key: String) -> Dictionary:
	var values: Array = []
	for item: Dictionary in samples: values.append(float(item.get(key,0)))
	if values.is_empty(): return {"samples":0,"p50":0.0,"p90":0.0,"p95":0.0,"max":0.0}
	values.sort()
	return {"samples":values.size(),"p50":_percentile(values,.50),"p90":_percentile(values,.90),"p95":_percentile(values,.95),"max":values[-1]}

func _summarize_activity(samples: Array, key: String) -> Dictionary:
	var values: Array = []
	for item: Dictionary in samples:
		if int(item.frame) >= 120: values.append(float(item.get(key,0)))
	var total := 0.0
	for value in values: total += float(value)
	values.sort()
	return {"samples":values.size(),"total":total,"p50":_percentile(values,.50),"p95":_percentile(values,.95),"p99":_percentile(values,.99),"max":values[-1] if not values.is_empty() else 0.0}

func _count_histogram(values: Array) -> Dictionary:
	var counts := {}
	for raw_value in values:
		var value := int(raw_value)
		counts[str(value)] = int(counts.get(str(value),0)) + 1
	return counts

func _one_frame_per_sample_after_bootstrap(values: Array) -> bool:
	for index in values.size():
		if index == 0: continue
		if int(values[index]) != 1: return false
	return values.size() == 0 or int(values[0]) <= 1

func _capture(name: String) -> String:
	var directory := ProjectSettings.globalize_path("res://" + out_dir.trim_prefix("res://"))
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join(name + ".png")
	var image := viewport.get_texture().get_image()
	image.save_png(path)
	image = null
	return path.trim_prefix(root_dir() + "/")

func root_dir() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/")

func _scenario(stage_id: String, frame_count: int, seed: int, enemy_hp_factor: float, members: Array) -> void:
	await _reset_view()
	var scenario_wall_start := Time.get_ticks_usec()
	var lifecycle := await _prepare_view(stage_id, seed, members)
	var report := {"stage_id":stage_id,"frames_requested":frame_count,"seed":seed,"resolution":[WIDTH,HEIGHT],
		"members":members.duplicate(),"fixture_adjustments":[],"lifecycle":lifecycle,"samples":{},"warm_samples":{},"population_max":{},"population_samples":[],
		"event_counts":{},"actor_switch_frames":[],"actor_spriteframes_resource_ids":[],"actor_spriteframes_recreated":0,"last_spriteframes_id_by_actor":{},
		"human_actor_fit_actor_frames":0,"human_actor_fit_actor_canvas_ms":[],"opaque_bounds_entry_observation_available":_opaque_bounds_cache_entries() is int,
		"opaque_bounds_cache_entry_growth":0,"opaque_bounds_cache_entry_growth_frames":[],
		"human_actor_fit_actor_frame_wall_ms":[],"wave_population_samples":[],"process_frame_deltas":[],"physics_frame_deltas":[],"frames_drawn_deltas":[],"engine_monitors":{},"canvas_trace_samples":[],
		"active_frames":0,"terminal_frames":0,
		"first_tick_canvas_refresh_ms":0.0,"first_manual_skill_frame":-1,"outcome_frame":-1}
	var keys := ["input_trace_ms","battle_tick_ms","present_messages_ms","publish_music_context_ms","canvas_consume_events_ms",
		"sync_camera_obstacles_ms","advance_presentation_ms","canvas_refresh_ms","hud_view_refresh_ms","frame_wall_ms"]
	for key in keys: report.samples[key] = []
	for key in keys: report.warm_samples[key] = []
	for key in ["engine_time_process_ms","engine_time_physics_process_ms","render_draw_calls","render_objects","viewport_cpu_render_ms","viewport_gpu_render_ms","frame_setup_cpu_ms"]:
		report.engine_monitors[key] = []
	report.last_canvas_performance_counters = view.canvas.performance_counters.duplicate(true)
	var ordinary_hp_before := {}
	for member in view.battle.characters.values():
		ordinary_hp_before[member.id] = member.stats.hp
		member.hp = member.stats.hp * 10.0
		member.shield = 0.0
	report.fixture_adjustments.append({"type":"party_hp_multiplier","factor":10.0,"base_hp_by_character":ordinary_hp_before,"purpose":"prevent premature fixture termination; regular enemy damage and AI remain active"})
	if stage_id == "B12": report.fixture_adjustments.append({"type":"ordinary_enemy_hp_multiplier","factor":enemy_hp_factor,"purpose":"sustain actual stage wave spawns near the authored 80-enemy cap during the fixed 25-second sample"})
	if stage_id == "B12": report.fixture_adjustments.append({"type":"boss_gate_deferred","boss_time":100000.0,"boss_kills":100000,"purpose":"keep the sample on the dense ordinary-enemy phase"})
	var boosted := {}
	for frame in frame_count: await _bench_frame(frame, report, boosted)
	report.frames_measured = report.samples.frame_wall_ms.size()
	report.warm_frames = report.warm_samples.frame_wall_ms.size()
	report.summaries = _summaries(report.samples)
	report.warm_summaries = _summaries(report.warm_samples)
	var canvas_trace_timings := {"draw_ms":[],"foreground_ms":[],"bounds_readback_ms_delta":[]}
	for item: Dictionary in report.canvas_trace_samples:
		if int(item.frame) < 120: continue
		for key in canvas_trace_timings: canvas_trace_timings[key].append(float(item[key]))
	report.warm_canvas_trace_timing_summaries = _summaries(canvas_trace_timings)
	report.warm_canvas_trace_activity = {}
	for key in ["draw_calls_delta","foreground_calls_delta","bounds_readbacks_delta"]:
		report.warm_canvas_trace_activity[key] = _summarize_activity(report.canvas_trace_samples,key)
	report.engine_monitor_summaries = _summaries(report.engine_monitors)
	report.wave_population_summary = {"ordinary_alive":_summarize_population(report.wave_population_samples,"ordinary_alive"),
		"derivatives":_summarize_population(report.wave_population_samples,"derivatives"),"bosses":_summarize_population(report.wave_population_samples,"bosses"),
		"projectiles":_summarize_population(report.wave_population_samples,"projectiles"),"effects":_summarize_population(report.wave_population_samples,"effects")}
	report.process_frame_delta_histogram = _count_histogram(report.process_frame_deltas)
	report.physics_frame_delta_histogram = _count_histogram(report.physics_frame_deltas)
	report.frames_drawn_delta_histogram = _count_histogram(report.frames_drawn_deltas)
	var render_timing_nonzero := false
	for value in report.engine_monitors.viewport_cpu_render_ms:
		if float(value) > 0.0: render_timing_nonzero = true
	for value in report.engine_monitors.viewport_gpu_render_ms:
		if float(value) > 0.0: render_timing_nonzero = true
	report.render_measurement_available = render_timing_nonzero
	report.scenario_wall_ms = float(Time.get_ticks_usec() - scenario_wall_start) / 1000.0
	report.final_counts = {"enemies":view.battle.enemies.size(),"projectiles":view.battle.projectiles.size(),"effects":view.battle.effects.size(),
		"hazards":view.battle.hazards.size(),"telegraphs":view.battle.telegraphs.size(),"pending_patterns":view.battle.pending_patterns.size(),
		"enemy_views":view.canvas.enemy_views.size(),"opaque_bounds_cache_entries":_opaque_bounds_cache_entries(),"outcome":view.battle.outcome}
	if view.battle.outcome.is_empty() or stage_id == "B18":
		var capture_path := _capture(stage_id)
		report.capture = capture_path
	_expect(report.frames_measured == frame_count, "%s collected every requested frame" % stage_id)
	_expect(report.outcome_frame == -1, "%s did not terminate the sustained sample" % stage_id)
	_expect(report.active_frames == frame_count and report.terminal_frames == 0, "%s remained active for every measured frame" % stage_id)
	_expect(_one_frame_per_sample_after_bootstrap(report.process_frame_deltas), "%s samples one process/render frame each after the bootstrap sample" % stage_id)
	_expect(_one_frame_per_sample_after_bootstrap(report.frames_drawn_deltas), "%s samples one drawn frame each after the bootstrap sample" % stage_id)
	if stage_id == "B12":
		_expect(float(report.wave_population_summary.ordinary_alive.max) >= 80.0, "B12 reached the authored ordinary-enemy cap")
	if stage_id == "B18":
		var bosses := 0
		for enemy: RefCounted in view.battle.enemies:
			if enemy.rank == "boss": bosses += 1
		report.boss_count_final = bosses
		_expect(bosses == 1, "B18 fixture retains exactly one live stage-authored boss")
	reports.append(report)
	print("LIVE_PERF_STAGE ", JSON.stringify({"stage":stage_id,"frames":frame_count,"wall":report["summaries"]["frame_wall_ms"],
		"tick":report["warm_summaries"]["battle_tick_ms"],"canvas":report["warm_summaries"]["canvas_refresh_ms"],"population_max":report.population_max}))

func run() -> void:
	SETTINGS.save_comfort("reduced_motion", false)
	SETTINGS.save_comfort("reduced_flash", false)
	SETTINGS.save_audio_volume("master",1.0)
	SETTINGS.save_audio_volume("music",0.7)
	SETTINGS.save_audio_volume("sfx",0.65)
	for category in SETTINGS.AUDIO_CATEGORIES: SETTINGS.save_audio_volume(str(category),1.0)
	SETTINGS.save_audio_muted(false)
	SETTINGS.save_music_muted(false)
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")):
		definitions[str(person.id)] = person
	viewport = SubViewport.new()
	viewport.size = Vector2i(WIDTH,HEIGHT)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container = SubViewportContainer.new()
	container.size = Vector2(WIDTH,HEIGHT)
	container.stretch = false
	container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	root.add_child(container)
	container.add_child(viewport)
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	var startup_started := Time.get_ticks_usec()
	await _scenario("B01",720,2026110501,1.0,SCENARIOS[0].members)
	var first_scenario_ms := float(Time.get_ticks_usec() - startup_started) / 1000.0
	for item in SCENARIOS.slice(1): await _scenario(str(item.id),int(item.frames),int(item.seed),float(item.enemy_hp_factor),item.members)
	await _reset_view()
	_expect(reports.size() == SCENARIOS.size(), "all requested scenarios completed")
	var report := {"schema_version":1,"engine":Engine.get_version_info(),"renderer":{"display_server":DisplayServer.get_name(),
		"adapter":RenderingServer.get_video_adapter_name(),"method":_rendering_method_label(),"audio_driver":"Dummy",
		"window_position":DisplayServer.window_get_position(),"window_no_focus":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS)},
		"fixture":{"resolution":[WIDTH,HEIGHT],"step_seconds":STEP,"party_by_stage":{"B01":["JIA","F11","N16"],"B12":["JIA","F11","N16"],"B18":["JIA","M01","N16"]},"level":10,"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":"ember_seal"},
			"input_trace":"8-way deterministic movement direction changes every 45 frames; switch every 210; manual skill requests every 84/132 frames; standard battle auto-attack and enemy AI remain enabled",
			"settings":{"reduced_motion":false,"reduced_flash":false,"master":1.0,"music":0.7,"sfx":0.65,"category_volumes":1.0,"master_muted":false,"music_muted":false},
			"measurement":"per-frame manual equivalent of BattleView._physics_process with timed battle/UI segments, then wait for RenderingServer.frame_post_draw; view physics process disabled to prevent double stepping"},
		"first_stage_scenario_wall_ms":first_scenario_ms,"scenario_count":reports.size(),"scenarios":reports,"failures":failures}
	var absolute_dir := ProjectSettings.globalize_path("res://" + out_dir.trim_prefix("res://"))
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var output_path := absolute_dir.path_join("results.json")
	var file := FileAccess.open(output_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("LIVE_PERF_BENCH_REPORT ",output_path)
	var total_frames := 0
	for item in reports: total_frames += int(item.frames_measured)
	if failures.is_empty() and reports.size() == SCENARIOS.size(): print("CHRONICLE_LIVE_PERFORMANCE_BENCH PASS stages=%d frames=%d" % [reports.size(),total_frames])
	else: print("CHRONICLE_LIVE_PERFORMANCE_BENCH FAIL failures=%d" % failures.size())
	quit(0 if failures.is_empty() else 1)
