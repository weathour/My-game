extends "res://scripts/tests/zhang_liao_summon_smoke.gd"
## Real GL draws for every 1/60-second simulation pose. Captured movies are
## Godot frame compositions, not an image-model animation output.
const FRAME_COUNT := 190
var capture_dir := ""
var only_case := ""
var case_reports: Array=[]
var normal_effect_alpha := {}

func _init() -> void:
	super()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):capture_dir=arg.trim_prefix("--capture=")
		if arg.begins_with("--case="):only_case=arg.trim_prefix("--case=")
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)

func press_escape() -> void:
	var key:=InputEventKey.new();key.keycode=KEY_ESCAPE;key.physical_keycode=KEY_ESCAPE;key.pressed=true
	viewport.push_input(key);await process_frame
	key=key.duplicate();key.pressed=false;viewport.push_input(key);await process_frame

func screenshot(name: String) -> void:
	if capture_dir.is_empty():return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	viewport.get_texture().get_image().save_png(capture_dir.path_join(name+".png"))

func screen_body(enemy: RefCounted,node: Node2D) -> Rect2:
	var world: Rect2=view.canvas._body_rect(node,enemy.position)
	return Rect2(view.canvas.global_position+view.canvas.origin+world.position*view.canvas.world_scale,world.size*view.canvas.world_scale)

func run() -> void:
	expect(DisplayServer.get_name()!="headless","native actual-render surface is required")
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"),"isolated render settings and saves")
	if failures:quit(1);return
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")):definitions[person.id]=person
	viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		viewport.size=dimensions
		for comfort in ([false,true] if dimensions.x==960 else [false]):
			SETTINGS.save_comfort("reduced_motion",comfort);SETTINGS.save_comfort("reduced_flash",comfort)
			for form in [0,1]:
				for collaborator in [0,1]:await render_case(form,collaborator,dimensions,comfort)
	viewport.size=Vector2i(960,540)
	SETTINGS.save_comfort("reduced_motion",false);SETTINGS.save_comfort("reduced_flash",false)
	await render_case(1,1,Vector2i(960,540),false,true)
	var expected_cases: int=17 if only_case.is_empty() else 2 if only_case.ends_with("-comfort") else 1
	expect(case_reports.size()==expected_cases,"all explicitly requested native cases completed")
	viewport.queue_free();await process_frame;await process_frame;await create_timer(.3).timeout
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
		var file:=FileAccess.open(capture_dir.path_join("render-report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"cases":case_reports,"frames":FRAME_COUNT*case_reports.size(),"source":"actual Godot GL frame capture","image_model_direct_animation":false,"simulation_step":STEP,"native_pause_hold_frames_omitted_from_movies":12,"checks":checks,"failures":failures},"\t"));file.close()
	print("ZHANG_LIAO_SUMMON_RENDER_SMOKE ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures," cases=",case_reports.size()," frames=",FRAME_COUNT*case_reports.size())
	quit(0 if failures==0 else 1)

func render_case(form: int,collaborator: int,dimensions: Vector2i,comfort: bool,edge_close: bool=false) -> void:
	var label: String="%d-%s-%s-%s"%[dimensions.x,"human" if form==0 else "war","gaoshun" if collaborator==0 else "chengong","comfort" if comfort else "normal"]
	if edge_close:label+="-edge-close"
	# A manual targeted run remains explicit in its cases/frames report. The
	# normal companion is retained for a selected comfort case's alpha oracle.
	if not only_case.is_empty() and label!=only_case and not (only_case.ends_with("-comfort") and label==only_case.trim_suffix("comfort")+"normal"):return
	var case_started := Time.get_ticks_usec()
	view=VIEW.new();view.setup(request(),definitions);viewport.add_child(view);view.set_physics_process(false)
	await process_frame;await process_frame
	view.canvas.performance_trace_enabled=true
	var b: RefCounted=view.battle
	var control: RefCounted=BATTLE.new(request())
	var boss: RefCounted=prepare(b,form,collaborator)
	var control_boss: RefCounted=prepare(control,form,collaborator)
	if edge_close:
		b.position=SPACE.SIZE-Vector2(350,300);control.position=b.position
		boss.position=SPACE.SIZE-Vector2(200,270);boss.anchor_position=boss.position
		control_boss.position=boss.position;control_boss.anchor_position=boss.position
		# Keep this close-range visual fixture alive through every authored pose;
		# all actual incoming damage still resolves identically in the control.
		b.current().hp=b.current().stats.hp*10.0;control.current().hp=control.current().stats.hp*10.0
	view.canvas.zhang_liao_summons.trace_draws=true
	var locked_direction: Vector2=(b.position+Vector2(0,-36)-boss.position).normalized()
	var marker_points: Array=[]
	for index in 3:marker_points.append((b.position+Vector2(0,-36)+locked_direction.orthogonal()*float(index-1)*320.0).clamp(Vector2(35,35),SPACE.SIZE-Vector2(35,35)))
	var phases := {};var captured_phases := {};var source_frames := {};var proxy_frames := {};var drawn_frames := 0
	var poses_fit := true;var frame_trace: Array=[]
	var effect_textures := {};var effect_draw_count := 0;var effect_contacts: Array=[]
	var movie_dir := ""
	if dimensions.x==1280 and not comfort and not capture_dir.is_empty():
		movie_dir=capture_dir.path_join("movie-frames").path_join(label);DirAccess.make_dir_recursive_absolute(movie_dir)
	for frame in FRAME_COUNT:
		var batch: Array=advance(b,control)
		await RenderingServer.frame_post_draw
		drawn_frames+=1
		var snapshot: Dictionary=view.canvas.zhang_liao_summons.snapshot()
		for effect: Dictionary in snapshot.last_drawn_effects:
			effect_draw_count+=1
			expect(Vector2(effect.world_size)==Vector2(260,260),"actual native FX footprint remains square260")
			# RefCounted ObjectIDs use the signed integer's high bit on this engine.
			var actual_texture := instance_from_id(int(effect.texture_id)) as Texture2D
			expect(actual_texture!=null and actual_texture.resource_path==str(effect.path) and str(effect.path).begins_with("res://assets/enemies/baimen/zhang_liao_summons/"),"actual draw uses the live imported FX texture recorded by its ObjectID")
			if effect_textures.has(effect.role):expect(effect_textures[effect.role]==effect.texture_id,"every native FX frame reuses its compiled texture")
			effect_textures[effect.role]=effect.texture_id
			if collaborator==1:expect(Vector2(effect.position).is_equal_approx(marker_points[int(effect.marker)]),"actual seal draw stays at its original committed danger marker")
			if dimensions.x==960 and not edge_close:
				var alpha_key: String="%d:%d:%d:%d"%[form,collaborator,frame,effect.marker]
				if comfort:expect(normal_effect_alpha.has(alpha_key) and is_equal_approx(float(effect.alpha)*2,float(normal_effect_alpha.get(alpha_key,-1))),"reduced-flash actual draw alpha is half at the same sim frame/marker")
				else:normal_effect_alpha[alpha_key]=effect.alpha
		for event: Dictionary in batch:
			if int(event.get("id",0))!=boss.id or str(event.get("geometry",{}).get("action_id",""))!="collaboration":continue
			if event.kind not in ["enemy_release","enemy_hazard_release"]:continue
			var contacts: Array=[]
			for effect: Dictionary in snapshot.last_drawn_effects:
				if event.kind=="enemy_release" or int(effect.marker)==int(event.geometry.get("marker_index",0)):contacts.append(effect)
			expect(contacts.size()==(3 if collaborator==1 and event.kind=="enemy_release" else 1),"real release/hazard has its actual painter contact commands")
			for effect: Dictionary in contacts:
				expect(effect.frame==(4 if event.kind=="enemy_release" else 5) and is_equal_approx(effect.clock,b.director.elapsed),"actual painter selects the correct FX contact in the damage event frame")
				effect_contacts.append(effect.duplicate(true))
		if snapshot.entries.size()==1:
			var entry: Dictionary=snapshot.entries[0]
			expect(not entry.missing_clip,"actual GL uses the authored clip "+label)
			var proxy: RefCounted
			for enemy in b.enemies:
				if enemy.id==entry.proxy_id:proxy=enemy
			expect(proxy!=null,"active native choreography retains the real proxy")
			if proxy!=null:
				var source_node: Node2D=view.canvas.enemy_views[boss.id].node
				var proxy_node: Node2D=view.canvas.enemy_views[proxy.id].node
				if collaborator==0:
					var foot: Vector2=proxy.position+proxy_node.scale*(proxy_node.sprite.position+proxy_node.sprite.scale*Vector2(0,288))
					for effect: Dictionary in snapshot.last_drawn_effects:expect(Vector2(effect.position).is_equal_approx(foot),"actual entry FX follows the visible foot anchor without moving the simulation proxy")
				var source_rect:=screen_body(boss,source_node);var proxy_rect:=screen_body(proxy,proxy_node)
				var safe:=Rect2(Vector2(0,view.canvas.safe_top),Vector2(dimensions.x,dimensions.y-view.canvas.safe_top-view.canvas.safe_bottom))
				if not safe.encloses(source_rect) or proxy_node.sprite.modulate.a>.05 and not safe.encloses(proxy_rect):
					if poses_fit:
						print("SUMMON_NATIVE_BOUNDS ",{"case":label,"frame":frame,"phase":entry.phase,"source":source_rect,"proxy":proxy_rect,"safe":safe,"camera":view.canvas.camera_state()})
						screenshot(label+"-bounds-failure")
					poses_fit=false
				frame_trace.append({"frame":frame,"clock":b.director.elapsed,"phase":entry.phase,"source_frame":entry.source_frame,"proxy_frame":entry.proxy_frame,"source_screen":str(source_rect),"proxy_screen":str(proxy_rect),"scale":view.canvas.world_scale})
			if not captured_phases.has(entry.phase) and (entry.phase!="manifest" or float(entry.proxy_alpha)>=.6):
				screenshot(label+"-"+str(entry.phase));captured_phases[entry.phase]={"frame":frame,"clock":b.director.elapsed}
			phases[entry.phase]=true;source_frames[entry.source_frame]=true;proxy_frames[entry.proxy_frame]=true
		elif frame==FRAME_COUNT-1:screenshot(label+"-finished")
		if not movie_dir.is_empty():viewport.get_texture().get_image().save_jpg(movie_dir.path_join("%04d.jpg"%frame),.96)
		if dimensions.x==960 and not comfort and form==0 and collaborator==0 and frame==30:
			await press_escape();expect(b.paused,"real Esc pauses native summon presentation")
			control.set_paused(true)
			var frozen: Dictionary=view.canvas.zhang_liao_summons.snapshot()
			for hold in 12:
				b.tick(STEP,Vector2.RIGHT);view.canvas.advance_presentation(STEP);view.canvas.refresh(false)
				await RenderingServer.frame_post_draw
				expect(view.canvas.zhang_liao_summons.snapshot()==frozen,"actual pause holds every painted summon phase/frame")
			screenshot(label+"-paused")
			await press_escape();control.set_paused(false);expect(not b.paused,"real Esc resumes the native sequence")
	expect(drawn_frames==FRAME_COUNT,"every requested simulation step was actually rendered "+label)
	expect(poses_fit,"full authored bodies and weapons stay outside the HUD crop "+label)
	expect(source_frames.size()==6 and proxy_frames.size()==(8 if collaborator==0 else 10),"complete authored motion was rendered "+label)
	expect(phases.has("manifest") and phases.has("impact") and phases.has("recover") and phases.has("vanish"),"full multistage native sequence completes "+label)
	expect(effect_draw_count>0 and not effect_contacts.is_empty(),"actual authored FX texture commands were drawn, including event contact "+label)
	expect(view.canvas.zhang_liao_summons.snapshot().active_count==0,"native sequence finishes and releases its presentation "+label)
	expect(view.canvas.summon_camera_envelopes.is_empty(),"native sequence removes its extra framing envelope "+label)
	expect(view.canvas.performance_counters.bounds_readbacks==0,"native source/proxy alpha bounds never read back at runtime "+label)
	case_reports.append({"case":label,"dimensions":[dimensions.x,dimensions.y],"comfort":comfort,"edge_close":edge_close,"fixture_party_hp_multiplier":10 if edge_close else 1,"frames":drawn_frames,"phases":phases.keys(),"phase_images":captured_phases,"source_frames":source_frames.keys(),"proxy_frames":proxy_frames.keys(),"poses_fit":poses_fit,"trace":frame_trace,"effect_draw_count":effect_draw_count,"effect_contacts":effect_contacts,"effect_texture_ids":effect_textures,"runtime_alpha_readbacks":view.canvas.performance_counters.bounds_readbacks,"movie_frames":movie_dir})
	print("ZHANG_LIAO_SUMMON_RENDER_CASE case=",label," completed=",case_reports.size()," frames=",drawn_frames," total_frames=",FRAME_COUNT*case_reports.size()," checks=",checks," failures=",failures," elapsed_ms=",(Time.get_ticks_usec()-case_started)/1000.0)
	view.queue_free();await process_frame;await process_frame;view=null
