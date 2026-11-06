extends SceneTree

const VIEW := preload("res://scripts/ui/chronicle/battle_view.gd")
const COMBAT := preload("res://scripts/content/combat_catalog.gd")
const SETTINGS := preload("res://scripts/shared/settings.gd")
const STEP := 1.0 / 60.0
const WIDTH := 1280
const HEIGHT := 720
const TRACE := [Vector2.RIGHT, Vector2(0.7,0.7), Vector2.DOWN, Vector2(-0.7,0.7), Vector2.LEFT, Vector2(-0.7,-0.7), Vector2.UP, Vector2(0.7,-0.7)]
const SCENARIOS := [
	{"id":"B01", "frames":360, "seed":2026110511, "enemy_hp_factor":1.0},
	{"id":"B13", "frames":1500, "seed":2026110513, "enemy_hp_factor":8.0},
]

var viewport: SubViewport
var container: SubViewportContainer
var view: Control
var definitions: Dictionary = {}
var out_dir := ""
var renderer_label := "project-default"
var pack_path := ""
var pack_sha256 := ""
var failures: Array[String] = []
var reports: Array[Dictionary] = []

func _init() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DisplayServer.window_set_size(Vector2i(WIDTH, HEIGHT))
	for arg in OS.get_cmdline_user_args():
		var value := str(arg)
		if value.begins_with("--out="): out_dir = value.trim_prefix("--out=")
		elif value.begins_with("--renderer-label="): renderer_label = value.trim_prefix("--renderer-label=")
		elif value.begins_with("--pack="): pack_path = value.trim_prefix("--pack=")
		elif value.begins_with("--pack-sha256="): pack_sha256 = value.trim_prefix("--pack-sha256=")
	call_deferred("run")

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)

func _available_property(object: Object, key: String) -> bool:
	if object == null: return false
	for item: Dictionary in object.get_property_list():
		if str(item.get("name", "")) == key: return true
	return false

func _property_value(object: Object, key: String) -> Variant:
	return object.get(key) if _available_property(object, key) else null

func _rid_string(texture: Texture2D) -> String:
	return str(texture.get_rid()) if texture != null else ""

func _request(stage_id: String, seed: int, party: Array) -> Dictionary:
	var records := {}
	for id in party: records[str(id)] = COMBAT.record(str(id), 10)
	return {"attempt_id":"jia-lord-perf-%s-%d" % [stage_id, seed], "members":party.duplicate(), "characters":records,
		"equipment":{"weapon":"plain_blade", "armor":"cloth_armor", "accessory":"ember_seal"},
		"stage":COMBAT.stage(stage_id), "seed":seed, "node":{"id":stage_id,"name":str(COMBAT.stage(stage_id).get("boss_name", stage_id))}}

func _load_view(stage_id: String, seed: int, party: Array) -> Dictionary:
	var request := _request(stage_id, seed, party)
	var setup_start := Time.get_ticks_usec()
	view = VIEW.new()
	view.setup(request, definitions)
	var setup_ms := float(Time.get_ticks_usec() - setup_start) / 1000.0
	var config: Dictionary = view.battle.director.config.duplicate(true)
	if stage_id == "B13":
		view.battle.director.config.boss_time = 100000.0
		view.battle.director.config.boss_kills = 100000
	var mount_start := Time.get_ticks_usec()
	viewport.add_child(view)
	var add_child_ready_ms := float(Time.get_ticks_usec() - mount_start) / 1000.0
	view.set_physics_process(false)
	var motion_api_available := _available_property(view.canvas, "performance_trace_enabled")
	if motion_api_available: view.canvas.set("performance_trace_enabled", true)
	for member in view.battle.characters.values():
		member.hp = member.stats.hp * 10.0
		member.shield = 0.0
	var party_hp := {}
	for member in view.battle.characters.values(): party_hp[str(member.id)] = float(member.hp)
	for _i in 2: await process_frame
	return {"view_setup_ms":setup_ms,"view_add_child_ready_ms":add_child_ready_ms,
		"stage_config":{"enemy_cap":int(config.get("enemy_cap",0)),"spawn_interval":float(config.get("spawn_interval",0)),"boss_time":float(config.get("boss_time",0)),"boss_kills":int(config.get("boss_kills",0))},
		"party_hp_after_fixture":party_hp,"performance_trace_available":motion_api_available}

func _input_for_frame(frame: int) -> Vector2:
	if frame > 0 and frame % 210 == 0: view.battle.request_switch(1)
	if frame % 84 == 0: view.battle.request_skill((frame / 84) % 2)
	if frame % 132 == 0: view.battle.request_skill(((frame / 132) + 1) % 2)
	return TRACE[posmod(frame / 45, TRACE.size())]

func _actor_textures() -> Dictionary:
	var result := {"script_path":"","appearance":null,"last_clip":null,"spriteframes_instance_id":0,
		"atlas_texture_instance_ids":[],"source_texture_instance_ids":[],"source_texture_rids":[],"source_texture_resource_paths":[]}
	if view == null or view.canvas == null: return result
	var visual: Node = view.canvas.get("actor_visual") as Node
	if visual == null: return result
	var script := visual.get_script() as Script
	if script != null: result.script_path = script.resource_path
	result.appearance = _property_value(view.canvas, "jia_appearance")
	if visual.has_method("presentation_snapshot"):
		var snapshot: Variant = visual.call("presentation_snapshot")
		if snapshot is Dictionary: result.last_clip = snapshot.get("last_clip")
	var atlas_ids := {}
	var source_ids := {}
	var source_rids := {}
	var source_paths := {}
	var animated: Array = visual.find_children("*", "AnimatedSprite2D", true, false)
	for item in animated:
		var sprite := item as AnimatedSprite2D
		if sprite == null or sprite.sprite_frames == null: continue
		result.spriteframes_instance_id = sprite.sprite_frames.get_instance_id()
		for animation in sprite.sprite_frames.get_animation_names():
			for index in sprite.sprite_frames.get_frame_count(animation):
				var texture := sprite.sprite_frames.get_frame_texture(animation, index)
				if texture is AtlasTexture:
					atlas_ids[str(texture.get_instance_id())] = texture.get_instance_id()
					if texture.atlas != null:
						source_ids[str(texture.atlas.get_instance_id())] = texture.atlas.get_instance_id()
						source_rids[_rid_string(texture.atlas)] = true
						source_paths[texture.atlas.resource_path] = true
				elif texture != null:
					source_ids[str(texture.get_instance_id())] = texture.get_instance_id()
					source_rids[_rid_string(texture)] = true
					source_paths[texture.resource_path] = true
	var sprites: Array = visual.find_children("*", "Sprite2D", true, false)
	for item in sprites:
		var sprite := item as Sprite2D
		if sprite != null and sprite.texture != null:
			source_ids[str(sprite.texture.get_instance_id())] = sprite.texture.get_instance_id()
			source_rids[_rid_string(sprite.texture)] = true
			source_paths[sprite.texture.resource_path] = true
	for key in atlas_ids: result.atlas_texture_instance_ids.append(int(atlas_ids[key]))
	for key in source_ids: result.source_texture_instance_ids.append(int(source_ids[key]))
	for key in source_rids: result.source_texture_rids.append(str(key))
	for key in source_paths: result.source_texture_resource_paths.append(str(key))
	result.atlas_texture_instance_ids.sort()
	result.source_texture_instance_ids.sort()
	result.source_texture_rids.sort()
	result.source_texture_resource_paths.sort()
	return result

func _canvas_counters() -> Dictionary:
	var value: Variant = _property_value(view.canvas, "performance_counters")
	return value.duplicate(true) if value is Dictionary else {}

func _opaque_bounds_entries() -> Variant:
	var value: Variant = _property_value(view.canvas, "opaque_bounds")
	return value.size() if value is Dictionary else null

func _count_population(report: Dictionary, frame: int) -> void:
	var battle: RefCounted = view.battle
	var ordinary := 0
	var derivatives := 0
	var bosses := 0
	for enemy: RefCounted in battle.enemies:
		if enemy.dead: continue
		if enemy.rank == "boss": bosses += 1
		elif enemy.parent_id != 0: derivatives += 1
		elif enemy.rank in ["ordinary", "heavy"]: ordinary += 1
	report.wave_population_samples.append({"frame":frame,"ordinary_alive":ordinary,"derivatives":derivatives,"bosses":bosses,
		"enemies":battle.enemies.size(),"projectiles":battle.projectiles.size(),"effects":battle.effects.size(),"enemy_views":view.canvas.enemy_views.size()})

func _capture(stage_id: String) -> String:
	var path := out_dir.path_join(stage_id + ".png")
	var image := viewport.get_texture().get_image()
	image.save_png(path)
	return path

func _scenario(stage_id: String, frames: int, seed: int, party: Array, enemy_hp_factor: float) -> void:
	if is_instance_valid(view): viewport.remove_child(view); view.free()
	view = null
	for _i in 1: await process_frame
	var lifecycle := await _load_view(stage_id, seed, party)
	var report := {"stage_id":stage_id,"frames_requested":frames,"seed":seed,"party":party.duplicate(),"lifecycle":lifecycle,
		"fixture_adjustments":[{"type":"party_hp_multiplier","factor":10.0,"purpose":"avoid terminal frames while real damage/AI remains enabled"}],
		"active_frames":0,"terminal_frames":0,"event_counts":{},"samples":{"battle_tick_ms":[],"canvas_refresh_ms":[],"hud_view_refresh_ms":[],"frame_wall_ms":[],"sync_camera_obstacles_ms":[]},
		"actor_switches":[],"wave_population_samples":[],"population_max":{},"first_appearance":null,"performance_trace_samples":[],"appearance_available":_available_property(view.canvas,"jia_appearance"),
		"appearance_method_available":false,"opaque_bounds_entry_growth_available":_opaque_bounds_entries() is int,"opaque_bounds_entry_growth":0,"opaque_bounds_entry_growth_frames":[],
		"player_hp_samples":[],"frame_process_deltas":[],"frame_draw_deltas":[]}
	if stage_id == "B13":
		report.fixture_adjustments.append({"type":"ordinary_enemy_hp_multiplier","factor":enemy_hp_factor,"purpose":"hold the real B13 wave near its authored cap during the 25-second sample"})
		report.fixture_adjustments.append({"type":"boss_gate_deferred","boss_time":100000.0,"boss_kills":100000,"purpose":"keep the B13 sample in its real dense ordinary wave"})
	var boosted := {}
	var previous_counters := _canvas_counters()
	for frame in frames:
		var wall_start := Time.get_ticks_usec()
		var direction := _input_for_frame(frame)
		var actor_before := str(view.canvas.actor_kind)
		var bounds_before: Variant = _opaque_bounds_entries()
		var start := Time.get_ticks_usec()
		view.battle.tick(STEP, direction)
		report.samples.battle_tick_ms.append(float(Time.get_ticks_usec()-start)/1000.0)
		if stage_id == "B13":
			for enemy: RefCounted in view.battle.enemies:
				if not boosted.has(enemy.id):
					boosted[enemy.id]=true; enemy.max_hp*=enemy_hp_factor; enemy.hp=enemy.max_hp
		var events: Array = view.battle.events.duplicate(true)
		for event: Dictionary in events:
			var kind:=str(event.get("kind",""));report.event_counts[kind]=int(report.event_counts.get(kind,0))+1
		start=Time.get_ticks_usec();view._present_messages(events)
		start=Time.get_ticks_usec();view._publish_music_context()
		start=Time.get_ticks_usec();view.canvas.consume_events(events)
		view.battle.events.clear()
		start=Time.get_ticks_usec();view._sync_camera_obstacles()
		report.samples.sync_camera_obstacles_ms.append(float(Time.get_ticks_usec()-start)/1000.0)
		view.canvas.advance_presentation(STEP)
		start=Time.get_ticks_usec();view.canvas.refresh(direction.length_squared()>0)
		report.samples.canvas_refresh_ms.append(float(Time.get_ticks_usec()-start)/1000.0)
		var bounds_after: Variant = _opaque_bounds_entries()
		if bounds_before is int and bounds_after is int:
			var entry_growth := maxi(0,int(bounds_after)-int(bounds_before))
			if entry_growth > 0:
				report.opaque_bounds_entry_growth += entry_growth
				report.opaque_bounds_entry_growth_frames.append({"frame":frame,"actor":str(view.canvas.actor_kind),"new_entries":entry_growth})
		else:
			report.opaque_bounds_entry_growth_available = false
			report.opaque_bounds_entry_growth = null
		start=Time.get_ticks_usec();view.refresh()
		report.samples.hud_view_refresh_ms.append(float(Time.get_ticks_usec()-start)/1000.0)
		var actor_now:=str(view.canvas.actor_kind)
		if actor_now != actor_before:
			var snapshot:=_actor_textures()
			if actor_now == "JIA" and snapshot.get("appearance") != null: report.appearance_method_available = true
			report.actor_switches.append({"frame":frame,"from":actor_before,"to":actor_now,"canvas_refresh_ms":report.samples.canvas_refresh_ms[-1],"actor":snapshot})
		if actor_now == "JIA" and report.first_appearance == null:
			report.first_appearance={"frame":frame,"appearance":_property_value(view.canvas,"jia_appearance"),"actor":_actor_textures()}
		if frame % 60 == 0: _count_population(report,frame)
		var before_process:=Engine.get_process_frames();var before_drawn:=Engine.get_frames_drawn()
		await RenderingServer.frame_post_draw
		var wall_ms:=float(Time.get_ticks_usec()-wall_start)/1000.0
		report.samples.frame_wall_ms.append(wall_ms)
		var current:=_canvas_counters()
		if not current.is_empty():
			report.performance_trace_samples.append({"frame":frame,"draw_us":current.get("draw_us",0),"foreground_us":current.get("foreground_us",0),
				"bounds_readbacks":int(current.get("bounds_readbacks",0))-int(previous_counters.get("bounds_readbacks",0)),
				"bounds_readback_us":int(current.get("bounds_readback_us",0))-int(previous_counters.get("bounds_readback_us",0)),
				"process_frame_delta":Engine.get_process_frames()-before_process,"drawn_frame_delta":Engine.get_frames_drawn()-before_drawn})
		previous_counters=current
		if view.battle.outcome.is_empty(): report.active_frames+=1
		else: report.terminal_frames+=1
		var counts={"enemies":view.battle.enemies.size(),"projectiles":view.battle.projectiles.size(),"enemy_views":view.canvas.enemy_views.size(),"effects":view.battle.effects.size(),"hazards":view.battle.hazards.size()}
		for key in counts: report.population_max[key]=maxi(int(report.population_max.get(key,0)),int(counts[key]))
		if frame % 120 == 0:
			var player_hp={}
			for id in party: player_hp[str(id)]=float(view.battle.characters[str(id)].hp)
			report.player_hp_samples.append({"frame":frame,"hp":player_hp})
		report.frame_process_deltas.append(Engine.get_process_frames()-before_process)
		report.frame_draw_deltas.append(Engine.get_frames_drawn()-before_drawn)
		if not view.battle.outcome.is_empty(): report.outcome_frame=frame
	report.final_counts={"enemies":view.battle.enemies.size(),"projectiles":view.battle.projectiles.size(),"enemy_views":view.canvas.enemy_views.size(),"effects":view.battle.effects.size(),"hazards":view.battle.hazards.size(),"outcome":view.battle.outcome}
	report.final_actor=_actor_textures()
	report.capture=_capture(stage_id)
	_expect(report.active_frames==frames and report.terminal_frames==0,"%s stayed active throughout" % stage_id)
	_expect(report.event_counts.get("ability_release",0)>0,"%s executed real manual abilities" % stage_id)
	_expect(report.population_max.get("enemies",0)>0,"%s spawned actual enemies" % stage_id)
	report.frame_process_histogram=_histogram(report.frame_process_deltas)
	report.frame_draw_histogram=_histogram(report.frame_draw_deltas)
	report.summaries={}
	for key in report.samples:
		var sorted:Array=report.samples[key].duplicate();sorted.sort()
		report.summaries[key]={"samples":sorted.size(),"p50_ms":_pct(sorted,.5),"p95_ms":_pct(sorted,.95),"p99_ms":_pct(sorted,.99),"max_ms":sorted[-1] if not sorted.is_empty() else 0.0}
	reports.append(report)
	print("PCK_COMBAT_STAGE ",JSON.stringify({"stage":stage_id,"active":report.active_frames,"terminal":report.terminal_frames,"wave":_wave_summary(report.wave_population_samples)}))

func _pct(sorted: Array, q: float) -> float:
	return 0.0 if sorted.is_empty() else float(sorted[clampi(int(ceil((sorted.size()-1)*q)),0,sorted.size()-1)])

func _histogram(values: Array) -> Dictionary:
	var result:Dictionary={}
	for value in values: result[str(value)]=int(result.get(str(value),0))+1
	return result

func _wave_summary(samples: Array) -> Dictionary:
	var result:Dictionary={}
	for key in ["ordinary_alive","derivatives","bosses","projectiles"]:
		var values:Array=[]
		for item:Dictionary in samples: values.append(float(item.get(key,0)))
		values.sort()
		result[key]={"p50":_pct(values,.5),"p90":_pct(values,.9),"p95":_pct(values,.95),"max":values[-1] if not values.is_empty() else 0.0}
	return result

func run() -> void:
	if out_dir.is_empty(): failures.append("missing --out absolute directory");push_error("missing --out absolute directory");quit(1);return
	DirAccess.make_dir_recursive_absolute(out_dir)
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")):
		definitions[str(person.id)]=person
	viewport=SubViewport.new();viewport.size=Vector2i(WIDTH,HEIGHT);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	container=SubViewportContainer.new();container.size=Vector2(WIDTH,HEIGHT);container.stretch=false
	container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);root.add_child(container);container.add_child(viewport)
	SETTINGS.save_comfort("reduced_motion",false);SETTINGS.save_comfort("reduced_flash",false)
	for category in ["master","music","sfx","player_attack","player_skill","enemy_attack","boss","hurt","death","pickup","rewards"]:
		SETTINGS.save_audio_volume(category,1.0 if category=="master" or category in ["player_attack","player_skill","enemy_attack","boss","hurt","death","pickup","rewards"] else .7 if category=="music" else .65)
	SETTINGS.save_audio_muted(false)
	SETTINGS.save_music_muted(false)
	for item:Dictionary in SCENARIOS: await _scenario(str(item.id),int(item.frames),int(item.seed),["JIA","F11","N16"],float(item.enemy_hp_factor))
	if is_instance_valid(view): viewport.remove_child(view);view.free()
	var report={"schema_version":1,"status":"PASS" if failures.is_empty() else "FAIL","engine":Engine.get_version_info(),
		"renderer":{"display_server":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"method_label":renderer_label,"project_default_method":ProjectSettings.get_setting("rendering/renderer/rendering_method","unknown"),"window_position":DisplayServer.window_get_position(),"window_no_focus":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS)},
		"source_free":true,"main_pack":{"path":pack_path,"sha256":pack_sha256,"command_line":OS.get_cmdline_args()},"cwd_files_after":DirAccess.get_files_at("."),"audio_driver":"Dummy","resolution":[WIDTH,HEIGHT],
		"fixture":{"party":["JIA","F11","N16"],"level":10,"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":"ember_seal"},"input":"fixed movement 8-way direction changes every45 frames; switch every210; skill requests 84/132; real automatic/manual combat and enemy AI","party_hp_multiplier":10.0,"B13_enemy_hp_multiplier":8.0,"B13_boss_gate_deferred":true},
		"scenarios":reports,"failures":failures}
	var file:=FileAccess.open(out_dir.path_join("results.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PCK_COMBAT_BENCH_REPORT ",out_dir.path_join("results.json"))
	print("PCK_COMBAT_BENCH ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
