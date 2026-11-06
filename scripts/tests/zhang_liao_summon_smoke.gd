extends SceneTree
## Real B17 admission/release/hazard batches; presentation is compared with an
## independent simulation-only attempt, never used as the damage oracle.
const VIEW := preload("res://scripts/ui/chronicle/battle_view.gd")
const BATTLE := preload("res://scripts/battle/battle_session.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
const SETTINGS := preload("res://scripts/shared/settings.gd")
const STEP := 1.0/60.0
var checks := 0
var failures := 0
var viewport: SubViewport
var view: Control
var definitions := {}

func _init() -> void:call_deferred("run")
func expect(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func request() -> Dictionary:
	return {"attempt_id":"liao-summon-contract","members":["JIA"],"characters":{"JIA":C.record("JIA",10)},"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":"ember_seal"},"stage":C.stage("B17"),"seed":2026110617,"node":{"id":"B17","name":"张辽协同独立验证"}}

static func prepare(b: RefCounted,form: int,collaborator: int) -> RefCounted:
	b.director.boss_spawned=true;b.position=SPACE.CENTER
	var boss: RefCounted=b.director.spawn("B17",SPACE.CENTER+Vector2(-500 if form==0 else 500,0))
	if form==1:
		boss.receive_damage(boss.hp)
		boss.advance_form(float(boss.params.transition_duration)+float(boss.params.phase_observation_duration))
	boss.attack_index=2;boss.cooldown=0;boss.params.collaboration_index=collaborator
	b.enemies.append(boss);b.spatial.rebuild(b.enemies)
	return boss

static func simulation(b: RefCounted) -> Dictionary:
	var actors := {};var enemies: Array=[]
	for id in b.characters:actors[id]={"record":b.characters[id].snapshot(),"stats":b.characters[id].stats.duplicate(true),"shield":b.characters[id].shield}
	for enemy in b.enemies:enemies.append({"id":enemy.id,"definition":enemy.definition_id,"visual":enemy.visual_id,"hp":enemy.hp,"max_hp":enemy.max_hp,"position":enemy.position,"form":enemy.form_index,"dead":enemy.dead,"targetable":enemy.targetable,"parent":enemy.parent_id,"age":enemy.age,"state":enemy.state,"action":enemy.current_action.duplicate(true),"serial":enemy.action_serial,"windup":enemy.windup,"cooldown":enemy.cooldown,"params":enemy.params.duplicate(true)})
	return {"actors":actors,"enemies":enemies,"position":b.position,"facing":b.facing,"active":b.active,"target":b.target_id,"hold":b.target_hold,"clock":b.director.elapsed,"rng":b.director.rng.state,"serial":b.director.serial,"skills":b._skill_intents.duplicate(),"switch":b._switch_intent,"cast":b.cast_serial,"delivery":b.delivery_serial,"projectiles":b.projectiles.duplicate(true),"hazards":b.hazards.duplicate(true),"telegraphs":b.telegraphs.duplicate(true),"patterns":b.pending_patterns.duplicate(true),"effects":b.effects.duplicate(true),"gems":b.gems.duplicate(true),"outcome":b.outcome}

func advance(b: RefCounted,control: RefCounted,movement: Vector2=Vector2.ZERO) -> Array:
	b.tick(STEP,movement);control.tick(STEP,movement)
	var events: Array=b.events.duplicate(true)
	view._present_messages(events);view._publish_music_context()
	view.canvas.consume_events(b.events);b.events.clear();control.events.clear()
	view._sync_camera_obstacles()
	view.canvas.advance_presentation(STEP)
	if not b.paused:view.message_time-=STEP
	view.canvas.refresh(movement.length_squared()>0)
	view.refresh()
	expect(simulation(b)==simulation(control),"visual pipeline preserves the exact simulation-only state")
	return events

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"),"isolated settings and saves")
	if failures:quit(1);return
	SETTINGS.save_comfort("reduced_motion",true);SETTINGS.save_comfort("reduced_flash",true)
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")):definitions[person.id]=person
	viewport=SubViewport.new();viewport.size=Vector2i(1280,720);root.add_child(viewport)
	for form in [0,1]:
		for collaborator in [0,1]:await check_case(form,collaborator)
	await check_qualification_and_cleanup()
	viewport.queue_free();await process_frame;await process_frame
	# Audio/render servers release stopped attempt resources asynchronously.
	await create_timer(.3).timeout
	print("ZHANG_LIAO_SUMMON_SMOKE ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)

func check_case(form: int,collaborator: int) -> void:
	view=VIEW.new();view.setup(request(),definitions);viewport.add_child(view);view.set_physics_process(false)
	await process_frame;await process_frame
	view.canvas.performance_trace_enabled=true
	var b: RefCounted=view.battle
	var control: RefCounted=BATTLE.new(request())
	var boss: RefCounted=prepare(b,form,collaborator)
	prepare(control,form,collaborator)
	var presenter: RefCounted=view.canvas.zhang_liao_summons
	var expected: String=("M03" if collaborator==0 else "M04")+("_human" if form==0 else "_WAR")
	var batch: Array=advance(b,control)
	var initial_batch: Array=batch.duplicate(true)
	var initial: Dictionary=presenter.snapshot()
	expect(initial.active_count==1 and initial.entries.size()==1,"actual admission creates one bounded presentation "+expected)
	if initial.entries.is_empty():view.queue_free();await process_frame;return
	var entry: Dictionary=initial.entries[0]
	expect(entry.owner_id==boss.id and entry.form_index==form and entry.action_serial==boss.action_serial,"presentation identity uses actual owner/form/action serial")
	expect(entry.collaborator==("M03_WAR" if collaborator==0 else "M04_WAR") and is_equal_approx(entry.total_duration,2.9),"collaborator and2.9-second lifetime use the original battle contract")
	expect(not entry.missing_clip and initial.resource_count==10,"all eight actor and two FX strips are packaged and compiled")
	var proxy: RefCounted
	for enemy in b.enemies:
		if enemy.parent_id==boss.id and not enemy.targetable:proxy=enemy
	expect(proxy!=null and proxy.visual_id==expected and proxy.rank=="proxy" and proxy.xp==0 and not proxy.counts_for_threshold,"only the existing non-targetable/no-reward proxy is admitted")
	if proxy==null:view.queue_free();await process_frame;return
	expect(b.enemies.size()==2,"collaboration creates no additional troops")
	var source_node: Node2D=view.canvas.enemy_views[boss.id].node
	var proxy_node: Node2D=view.canvas.enemy_views[proxy.id].node
	expect(is_equal_approx(source_node.scale.x*source_node.sprite.scale.x*224.0,boss.body_height),"224-pixel command calibration preserves original boss world body height")
	expect(is_equal_approx(proxy_node.scale.x*proxy_node.sprite.scale.x*224.0,proxy.body_height),"224-pixel body calibration preserves original world body height")
	var geometry: Dictionary=boss.telegraph.duplicate(true)
	var direction: Vector2=(b.position+Vector2(0,-36)-boss.position).normalized()
	expect(Vector2(geometry.direction).is_equal_approx(direction),"cooperation direction is locked to the actual player core")
	expect(source_node.sprite.flip_h==(direction.x<0) and proxy_node.sprite.flip_h==(direction.x<0),"authored bodies face the real cooperation direction in both orientations")
	expect(geometry.shape==("line" if collaborator==0 else "marker") and is_equal_approx(geometry.total,1.4),"original warning shape and1.4-second windup remain authoritative")
	expect(is_equal_approx(geometry.damage,boss.damage*(1.0 if form==0 else 1.15)),"unchanged human/war damage scale")
	if collaborator==0:expect(is_equal_approx(geometry.half_width,80.0) and is_equal_approx(geometry.length,1100.0),"Gaoshun warning retains1100-by160 line")
	else:
		var center: Vector2=b.position+Vector2(0,-36)
		var markers: Array=[geometry]+geometry.extra_markers
		expect(markers.size()==3,"Chen preserves the three committed marker sites")
		for index in markers.size():
			var point: Vector2=(center+direction.orthogonal()*float(index-1)*320.0).clamp(Vector2(35,35),SPACE.SIZE-Vector2(35,35))
			expect(is_equal_approx(markers[index].radius,225.0) and Vector2(markers[index].origin).is_equal_approx(point),"Chen225-radius marker retains target-locked320 spacing")
	var readonly: Dictionary=simulation(b)
	for duplicate in 100:presenter.consume(batch,b);presenter.sync(b)
	expect(presenter.snapshot()==initial and simulation(b)==readonly,"real phase+tell batch replay100 times is idempotent and read-only")
	initial.entries[0].phase="test-corruption"
	expect(presenter.snapshot().entries[0].phase=="order","snapshot is detached from presenter state")
	var stable_texture: int=proxy_node.sprite.texture.get_instance_id()
	var source_texture: int=source_node.sprite.texture.get_instance_id()
	var phases := {};var source_frames := {};var proxy_frames := {}
	var first_release := -1.0;var first_impact := -1.0;var impacts := 0
	for frame in 190:
		batch=advance(b,control)
		var state: Dictionary=presenter.snapshot()
		if state.active_count>0:
			entry=state.entries[0];phases[entry.phase]=true;source_frames[entry.source_frame]=true;proxy_frames[entry.proxy_frame]=true
			expect(state.active_count<=4 and state.seen_count<=256 and entry.pulse_count<=4,"effect and dedup budgets remain bounded")
			expect(source_node.sprite.texture.get_instance_id()==source_texture and proxy_node.sprite.texture.get_instance_id()==stable_texture and state.resource_count==initial.resource_count,"warm actor refresh reuses the strip resources")
			for effect: Dictionary in entry.effect_frames:
				if entry.release_time<0:expect(effect.frame<=3,"FX remains in its authored pre-impact0–3 poses during windup")
				elif collaborator==1 and effect.impact_time<0:expect(effect.frame==4,"unfired Chen marker holds its charging frame4")
				else:expect(effect.frame>=(4 if collaborator==0 else 5),"released FX never restarts its warning sequence")
		for event: Dictionary in batch:
			if int(event.get("id",0))!=boss.id or str(event.get("geometry",{}).get("action_id",""))!="collaboration":continue
			if event.kind=="enemy_release":
				first_release=b.director.elapsed
				expect(entry.source_frame==3 and entry.proxy_frame==(4 if collaborator==0 else 5),"actual release selects authored command/collaborator release contact")
				for effect: Dictionary in entry.effect_frames:expect(effect.frame==4,"actual boss release selects the authored FX release4")
			if event.kind=="enemy_hazard_release":
				impacts+=1
				if first_impact<0:first_impact=b.director.elapsed
				expect(entry.proxy_frame==7,"actual delayed marker impact selects Chen contact7 without restarting")
				for effect: Dictionary in entry.effect_frames:
					if effect.marker==int(event.geometry.get("marker_index",0)):expect(effect.frame==5 and is_equal_approx(effect.impact_time,b.director.elapsed),"only the actually released Chen marker selects FX contact5 now")
		if frame==25:
			b.set_paused(true);control.set_paused(true)
			var paused: Dictionary=presenter.snapshot();var body_frame: int=proxy_node.sprite.frame
			for refresh in 40:
				b.tick(.1,Vector2.RIGHT);view.canvas.advance_presentation(.1);view.canvas.refresh(false)
				expect(presenter.snapshot()==paused and proxy_node.sprite.frame==body_frame,"pause freezes sim-clock phases and native sprite pose")
			b.set_paused(false);control.set_paused(false)
	expect(first_release>0 and absf(first_release-float(initial.entries[0].start)-1.4)<=STEP*1.1,"release remains within one simulation tick of its authored windup")
	if collaborator==1:expect(impacts==3 and absf(first_impact-first_release-.9)<=STEP*1.1,"Chen retains three actual markers and original0.9-second delayed first impact")
	else:expect(impacts==0,"Gaoshun creates no additional delayed damage markers")
	for phase in (["manifest","advance","impact","recover","vanish"] if collaborator==0 else ["manifest","unfurl","array_tell","impact","recover","vanish"]):expect(phases.has(phase),"real sim clock traverses distinct phase "+phase)
	expect(source_frames.size()==6 and proxy_frames.size()==(8 if collaborator==0 else 10),"all independent source and collaborator poses are reached")
	expect(presenter.snapshot().active_count==0 and b.enemies.size()==1,"presentation and proxy expire while the real boss survives")
	expect(view.canvas.summon_camera_envelopes.is_empty(),"expired collaboration releases its additional camera envelope")
	expect(view.canvas.performance_counters.bounds_readbacks==0,"known source/proxy frames use offline metadata without runtime alpha readbacks")
	# A late duplicate cannot resurrect an expired collaboration.
	presenter.consume(initial_batch,b);presenter.sync(b)
	expect(presenter.snapshot().active_count==0,"expired collaboration is not resurrected by stale events")
	presenter.clear(true)
	expect(presenter.snapshot().active_count==0 and presenter.snapshot().seen_count==0 and presenter.snapshot().hidden_count==0,"explicit battle teardown clears entries/dedup/proxy references")
	view.queue_free();await process_frame;await process_frame;view=null

func check_qualification_and_cleanup() -> void:
	for reason in ["qualification","phase","death","terminal","capacity"]:
		view=VIEW.new();view.setup(request(),definitions);viewport.add_child(view);view.set_physics_process(false)
		await process_frame;await process_frame
		var b: RefCounted=view.battle
		var boss: RefCounted=prepare(b,1 if reason=="death" else 0,0)
		b.tick(STEP,Vector2.ZERO)
		var first: Array=b.events.duplicate(true)
		view.canvas.consume_events(b.events);b.events.clear();view.canvas.refresh(false)
		var presenter: RefCounted=view.canvas.zhang_liao_summons
		expect(presenter.snapshot().active_count==1,"cleanup fixture admits a real collaboration "+reason)
		var proxy: RefCounted
		for enemy in b.enemies:
			if enemy.parent_id==boss.id and not enemy.targetable:proxy=enemy
		if proxy==null:expect(false,"cleanup fixture has its genuine proxy");view.queue_free();await process_frame;continue
		if reason=="qualification":
			var hp: float=proxy.hp
			b.position=proxy.position
			b.tick(STEP,Vector2.RIGHT)
			expect(b.position.is_equal_approx(proxy.position+Vector2.RIGHT*b.current().stats.move*STEP),"controlled actor passes through the apparition without body collision")
			expect(b.target_id!=proxy.id,"actual nearest-target selection never locks the proxy")
			b._cast(C.definition("JIA").manual[0],b.current(),true,true);b._resolve_hits()
			expect(proxy.hp==hp and not proxy.dead,"actual player basic/manual damage excludes the proxy")
		elif reason in ["phase","death"]:
			boss.receive_damage(boss.hp)
			b.tick(STEP,Vector2.ZERO);view.canvas.consume_events(b.events);view.canvas.refresh(false)
			expect(presenter.snapshot().active_count==0,"real phase/death removes the collaboration immediately "+reason)
		elif reason=="terminal":
			b._finish("failed");view.canvas.consume_events(b.events);view.canvas.refresh(false)
			expect(presenter.snapshot().active_count==0 and presenter.snapshot().seen_count==0,"terminal battle clears collaboration and dedup state")
		else:
			var event: Dictionary={}
			for candidate: Dictionary in first:
				if candidate.kind=="enemy_tell" and str(candidate.get("geometry",{}).get("action_id",""))=="collaboration":event=candidate.duplicate(true)
			expect(not event.is_empty(),"budget fixture starts with an actual collaboration tell")
			if not event.is_empty():
				for serial in range(2,302):
					boss.action_serial=serial;event.action_serial=serial;event.geometry.action_serial=serial
					var before: Dictionary=simulation(b)
					presenter.consume([event],b)
					expect(simulation(b)==before,"capacity stress remains strictly visual")
				expect(presenter.snapshot().active_count==4 and presenter.snapshot().seen_count==256,"distinct serial pressure enforces exact entry/seen caps")
				var bounded: Dictionary=presenter.snapshot();presenter.consume(first,b)
				expect(presenter.snapshot()==bounded,"an old serial cannot resurrect an evicted action")
		presenter.clear(true)
		expect(presenter.snapshot().active_count==0 and presenter.snapshot().seen_count==0 and presenter.snapshot().hidden_count==0,"teardown resets references before reentry "+reason)
		view.queue_free();await process_frame;await process_frame;view=null
