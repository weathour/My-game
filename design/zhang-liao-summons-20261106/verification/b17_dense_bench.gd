extends "./live_performance_base.gd"
## Bounded extension of the existing measured BattleView pipeline. Both files
## run unchanged outside the project against the before and after PCKs.
## Controlled dense fixture, not a claim about naturally reached campaign state.
const FRAME_COUNT := 750
const SEED := 2026110617
var requested_form := 0
var requested_collaborator := 0
var case_name := ""
var event_digest := HashingContext.new()
var state_digest := HashingContext.new()
var event_frames := 0
var active_collaborators := {}
var boss_trace: Array = []
var recovery_observed := false
var boss_id := 0

func _prepare_view(stage_id: String, seed: int, members: Array) -> Dictionary:
	var lifecycle: Dictionary = await super._prepare_view(stage_id,seed,members)
	var b: RefCounted = view.battle
	# The actual director stops waves after boss admission. Seed an explicit
	# retained ordinary wave; do not mislabel a B12 scene as dense B17.
	b.director.boss_spawned=true
	b.position=Vector2(1024,768)
	var cycle: Array = b.director.config.waves[-1].cycle
	for index in int(b.director.config.enemy_cap):
		var angle: float=TAU*index/int(b.director.config.enemy_cap)
		var point: Vector2=b.position+Vector2(cos(angle),sin(angle))*(340.0+float(index%4)*75.0)
		var enemy: RefCounted=b.director.spawn(str(cycle[index%cycle.size()]),point)
		enemy.hp*=8.0;enemy.max_hp=enemy.hp;b.enemies.append(enemy)
	var boss: RefCounted=b.director.spawn("B17",b.position+Vector2(450,-80))
	if requested_form==1:
		boss.receive_damage(boss.hp)
		boss.advance_form(float(boss.params.get("transition_duration",1.0))+float(boss.params.get("phase_observation_duration",.65)))
	boss.configure_form_budget(boss.encounter_max_hp*100.0)
	# Start at the existing collaboration entry; retain the complete authored
	# action cycle afterward. A small input orbit permits the subsequent melee
	# action to complete rather than spending the sample chasing a distant actor.
	boss.attack_index=2;boss.cooldown=0.0
	boss.params.collaboration_index=requested_collaborator;boss_id=boss.id
	b.enemies.append(boss);b.spatial.rebuild(b.enemies)
	_expect(boss.form_index==requested_form,"fixture uses actual requested B17 form")
	event_digest.start(HashingContext.HASH_SHA256);state_digest.start(HashingContext.HASH_SHA256)
	event_frames=0;active_collaborators.clear();boss_trace.clear();recovery_observed=false
	view.canvas.presentation_events.connect(func(events: Array):
		event_digest.update(JSON.stringify(events).to_utf8_buffer());event_digest.update("\n".to_utf8_buffer());event_frames+=1
		for event: Dictionary in events:
			if int(event.get("id",0))==boss_id and str(event.get("geometry",{}).get("action_id",""))=="collaboration":boss_trace.append({"clock":b.director.elapsed,"kind":event.kind,"serial":event.get("action_serial",0),"geometry":event.geometry.duplicate(true)}))
	lifecycle.fixture={"stage":"B17","form":requested_form,"collaboration_index":requested_collaborator,"ordinary_count":int(b.director.config.enemy_cap),"ordinary_cycle":cycle.duplicate(),"ordinary_hp_multiplier":8,"boss_hp_multiplier":100,"boss_phase_selection":"actual receive_damage + advance_form for war only","initial_authored_action_index":2,"initial_boss_cooldown":0,"input_direction_segment_frames":12,"boss_admitted_without_waiting_for_gate":true,"director_waves_stop_after_boss":true,"seed":SEED}
	return lifecycle

func _input_for_frame(frame: int) -> Vector2:
	return TRACE[posmod(frame/12,TRACE.size())]

func _bench_frame(frame: int, report: Dictionary, boosted: Dictionary) -> void:
	await super._bench_frame(frame,report,boosted)
	# Audit serialization is outside the inherited measured frame wall interval.
	var b: RefCounted=view.battle
	var actors := {};var enemies: Array=[]
	for id in b.characters:actors[id]=b.characters[id].snapshot()
	for enemy in b.enemies:
		enemies.append({"id":enemy.id,"definition":enemy.definition_id,"visual":enemy.visual_id,"form":enemy.form_index,"position":enemy.position,"hp":enemy.hp,"dead":enemy.dead,"targetable":enemy.targetable,"parent":enemy.parent_id,"age":enemy.age,"state":enemy.state,"action":enemy.current_action,"serial":enemy.action_serial,"windup":enemy.windup,"cooldown":enemy.cooldown,"params":enemy.params})
		if not enemy.targetable and not enemy.dead:active_collaborators[enemy.visual_id]=true
		if enemy.id==boss_id and enemy.state=="recovery" and str(enemy.current_action.get("action",""))=="collaboration":recovery_observed=true
	var state := {"frame":frame,"clock":b.director.elapsed,"rng":b.director.rng.state,"serial":b.director.serial,"kills":b.director.kills,"actors":actors,"enemies":enemies,"position":b.position,"active":b.active,"target":b.target_id,"projectiles":b.projectiles,"hazards":b.hazards,"telegraphs":b.telegraphs,"patterns":b.pending_patterns,"effects":b.effects,"outcome":b.outcome}
	var serialized := JSON.stringify(state)
	if not report.has("logic_frame_sha256"):report.logic_frame_sha256=[]
	report.logic_frame_sha256.append(serialized.sha256_text())
	state_digest.update(serialized.to_utf8_buffer());state_digest.update("\n".to_utf8_buffer())

func _capture(_name: String) -> String:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path:=out_dir.path_join(case_name+".png")
	viewport.get_texture().get_image().save_png(path)
	return path

func run() -> void:
	_expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"),"isolated benchmark storage")
	SETTINGS.save_comfort("reduced_motion",false);SETTINGS.save_comfort("reduced_flash",false)
	SETTINGS.save_audio_volume("master",1.0);SETTINGS.save_audio_volume("music",.7);SETTINGS.save_audio_volume("sfx",.65)
	for category in SETTINGS.AUDIO_CATEGORIES:SETTINGS.save_audio_volume(str(category),1.0)
	SETTINGS.save_audio_muted(false);SETTINGS.save_music_muted(false)
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")):definitions[str(person.id)]=person
	viewport=SubViewport.new();viewport.size=Vector2i(WIDTH,HEIGHT);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	container=SubViewportContainer.new();container.size=Vector2(WIDTH,HEIGHT);container.stretch=false;root.add_child(container);container.add_child(viewport)
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
	for form in [0,1]:
		for collaborator in [0,1]:
			requested_form=form;requested_collaborator=collaborator
			case_name="B17-%s-%s-dense"%["human" if form==0 else "war","gaoshun" if collaborator==0 else "chengong"]
			await _scenario("B17",FRAME_COUNT,SEED,8.0,["JIA","F11","N16"])
			var report: Dictionary=reports[-1]
			report.case_name=case_name;report.logic_event_sha256=event_digest.finish().hex_encode();report.logic_state_sha256=state_digest.finish().hex_encode();report.event_frames=event_frames;report.collaborator_visuals_seen=active_collaborators.keys();report.boss_collaboration_trace=boss_trace.duplicate(true);report.collaboration_recovery_observed=recovery_observed
			var expected: String=("M03" if collaborator==0 else "M04")+("_human" if form==0 else "_WAR")
			_expect(active_collaborators.has(expected),"dense sample contains actual collaboration "+expected)
			var kinds: Array=boss_trace.map(func(event: Dictionary):return event.kind)
			_expect("enemy_tell" in kinds and "enemy_release" in kinds and recovery_observed,"actual collaboration tell/release/recovery complete "+expected)
			if collaborator==1:_expect("enemy_hazard_release" in kinds,"actual delayed array impact occurs "+expected)
			reports[-1]=report
	await _reset_view();container.queue_free();await _frames(3)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var file:=FileAccess.open(out_dir.path_join("results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"engine":Engine.get_version_info(),"renderer":{"adapter":RenderingServer.get_video_adapter_name(),"method":_rendering_method_label(),"display":DisplayServer.get_name()},"fixture_kind":"controlled dense B17 two-form two-collaborator same-input comparison","step":STEP,"frames_per_case":FRAME_COUNT,"frames_per_form":2*FRAME_COUNT,"seed":SEED,"scenarios":reports,"failures":failures},"\t"));file.close()
	print("B17_DENSE_BENCH ","PASS" if failures.is_empty() else "FAIL"," cases=",reports.size()," frames=",FRAME_COUNT*reports.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
