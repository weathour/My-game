extends SceneTree
## Binding completeness, real cast/result semantics, shared priority and lifetime isolation.
const CATALOG := preload("res://scripts/audio/skill_sound_catalog.gd")
const AUDIO := preload("res://scripts/audio/combat_audio.gd")
const FEEDBACK := preload("res://scripts/ui/chronicle/combat_feedback.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const BATTLE := preload("res://scripts/battle/battle_session.gd")
const ENEMIES := preload("res://scripts/battle/enemy_system.gd")
const SETTINGS := preload("res://scripts/shared/settings.gd")
const BGM := preload("res://scripts/audio/music_player.gd")
var checks := 0
var failures := 0
func _init() -> void: call_deferred("run")
func expect(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(message)
func request() -> Dictionary:
	return {"attempt_id":"skill-audio","members":["JIA","F11","F03"],"characters":{"JIA":C.record("JIA",20),"F11":C.record("F11",20),"F03":C.record("F03",20)},"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":""},"stage":C.stage("B01"),"seed":17371,"node":{"id":"B01","name":"audio"}}
func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"),"isolated sound settings")
	if failures: quit(1); return
	verify_bindings()
	if failures: finish(); return
	var old_sfx := SETTINGS.load_sfx_volume()
	SETTINGS.save_sfx_volume(.65)
	var feedback := FEEDBACK.new()
	root.add_child(feedback)
	feedback.trace_enabled=true
	var b := BATTLE.new(request())
	b.enemies.clear()
	expect(not b._cast(C.basic("JIA",b.equipment),b.current(),true) and b.events.is_empty(),"existing targetless basic gate remains unchanged and fabricates no cast")
	expect(b._cast(C.definition("JIA").manual[0],b.current(),true,true),"empty-space NOVA cast succeeds under existing gameplay rules")
	feedback.consume(b.events,b,Rect2())
	expect(feedback.audio.counters.started==1,"empty-space attack has exactly one cast sound")
	for trace in feedback.trace_records: expect(trace.stage=="cast","empty-space attack never invents impact audio")
	feedback.clear(); b.events.clear()
	var emma: Resource=C.definition("F11").manual[0]
	expect(b._cast(emma,b.characters.F11,false,true),"Emma spell cast succeeds")
	feedback.consume(b.events,b,Rect2())
	expect(feedback.audio.counters.started>=2,"Emma has her own spell launch even without a hit")
	feedback.clear(); b.events.clear()
	b.characters.JIA.hp-=30
	var ward: Resource=C.definition("F03").manual[1]
	var previous: float=b.characters.JIA.shield
	expect(b._cast(ward,b.characters.F03,false,true),"support ward cast succeeds")
	var actual:=false
	for event in b.events:
		if event.kind=="ability_effect": actual=actual or float(event.shield_delta)>0
	expect(actual and b.characters.JIA.shield>previous,"beneficial result event observes actual single shield settlement")
	feedback.consume(b.events,b,Rect2())
	var cast_sound:=false; var effect_sound:=false
	for record in feedback.audio.records:
		cast_sound=cast_sound or record.get("stage")=="cast"
		effect_sound=effect_sound or record.get("stage")=="impact"
	expect(cast_sound and effect_sound,"support launch and confirmed beneficial effect are distinct")
	feedback.clear()
	var enemy: RefCounted=b.director.spawn("E03",b.position+Vector2(100,0))
	enemy.cooldown=0
	b.enemies=[enemy]
	var hazards: Array=[]
	var first:=ENEMIES.step(b.enemies,b.position,.01,{"hazards":hazards,"config":b.director.config})
	feedback.consume(first.events,b,Rect2())
	var tell:=false
	for record in feedback.audio.records: tell=tell or record.get("stage")=="tell"
	expect(tell,"actual charge admission emits a mapped warning")
	var release:=ENEMIES.step(b.enemies,b.position,enemy.windup+.01,{"hazards":hazards,"config":b.director.config})
	feedback.consume(release.events,b,Rect2())
	var released:=false
	for record in feedback.audio.records:
		expect(record.get("stage")!="tell","release cancels its own warning tail")
		released=released or record.get("stage")=="release"
	expect(released,"actual charge release emits its launch, without requiring a hit")
	var release_count:int=feedback.audio.counters.started
	feedback.advance(.2,false,"")
	var repeated: Array=[]
	for event in release.events:
		if event.kind=="enemy_release":
			var delayed: Dictionary=event.duplicate(true);delayed.kind="enemy_hazard_release";repeated.append(delayed)
	feedback.consume(repeated,b,Rect2())
	expect(feedback.audio.counters.started==release_count,"delayed areas from the same action serial do not replay its release sound after cooldown")
	feedback.advance(3.2,false,"")
	feedback.consume(repeated,b,Rect2())
	expect(feedback.audio.counters.started==release_count,"same launch remains deduplicated beyond the mixer's short cache lifetime")
	var next_release: Array = repeated.duplicate(true)
	for event in next_release: event.action_serial = int(event.action_serial) + 1
	feedback.consume(next_release,b,Rect2())
	expect(feedback.audio.counters.started==release_count+1,"a later action serial can launch the same sound again")
	feedback.clear()
	feedback.consume(first.events+release.events,b,Rect2())
	for record in feedback.audio.records: expect(record.get("stage")!="tell","same-batch admission then release cannot resurrect warning")
	feedback.clear(); enemy.windup=1.0; enemy.dead=true
	feedback.consume(first.events+[{"kind":"kill","target_id":enemy.id,"position":enemy.position}],b,Rect2())
	for record in feedback.audio.records: expect(record.get("stage")!="tell","same-batch kill uses target ID and removes stale warning")
	verify_guard_result(feedback)
	verify_boss_results(feedback)
	expect(feedback.audio.counters.missing_bindings==0,"all actual cast/support/enemy/Boss events resolve without unknown bindings: "+JSON.stringify(feedback.audio.binding_diagnostics))
	verify_mixer(feedback.audio)
	await verify_music_duck(feedback.audio)
	await verify_mix_capture(feedback.audio)
	SETTINGS.save_sfx_volume(old_sfx)
	feedback.clear()
	feedback.queue_free()
	for _frame in 3: await process_frame
	await create_timer(.5).timeout
	call_deferred("finish")

func verify_bindings() -> void:
	var profiles:=CATALOG.profiles()
	var total:=0
	for owner in C.IDS:
		var kit:=C.definition(owner)
		var abilities: Array=[kit.basic]+kit.manual+kit.automatic
		if kit.support!=null: abilities.append(kit.support)
		for ability in abilities:
			total+=1
			var profile:=CATALOG.character(owner,str(ability.id),ability.kind)
			expect(not profile.is_empty(),"explicit character binding: %s/%s" % [owner,ability.id])
			for stage in ["cast","impact"]: verify_stage(profile,stage,"%s/%s" % [owner,ability.id])
	expect(total==137,"all 137 ability configurations covered")
	expect(CATALOG.character("JIA","JIA_basic",1).get("cast")=="thrust.cast","shared JIA basic ID honors spear kind override")
	var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://design/skill-audio-20261103/runtime/combat-content-baseline.json"))
	expect(baseline.attacks.size()==87,"all 87 authored enemy actions remain the coverage authority")
	var unique_moves := {}
	for row: Dictionary in baseline.attacks:
		unique_moves["%s/%s/%s" % [row.enemy_id,row.form_index,row.attack.id]]=true
		var profile:=CATALOG.enemy(row.enemy_id,int(row.form_index),str(row.attack.id))
		expect(not profile.is_empty(),"explicit enemy/form/move binding: %s/%s/%s" % [row.enemy_id,row.form_index,row.attack.id])
		for stage in ["tell","release","impact"]: verify_stage(profile,stage,str(row.enemy_id)+"/"+str(row.attack.id))
	expect(unique_moves.size()==81,"87 authored configurations resolve to 81 unique enemy/form/move keys")
	expect(profiles.get("trait_bindings",{}).size()==9,"all nine trait decisions explicitly documented")
	var bank: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CATALOG.BANK_PATH))
	expect(bank.cues.size()==104,"101 new phase cues and three retained utility cues")
	for id: String in bank.cues:
		var row: Dictionary=bank.cues[id]
		expect(not row.variants.is_empty(),"nonempty sound variant bank: "+id)
		for path: String in row.variants:
			var stream:=load(path) as AudioStreamWAV
			expect(stream!=null and stream.mix_rate==48000 and not stream.stereo and stream.format==AudioStreamWAV.FORMAT_16_BITS,"real mono PCM16 variant: "+path)
			if stream!=null: expect(stream.loop_mode==AudioStreamWAV.LOOP_DISABLED and stream.get_length()>.02,"bounded one-shot variant: "+path)
func verify_stage(profile: Dictionary, stage: String, context: String) -> void:
	expect(profile.has(stage),"authored stage decision: "+context+"/"+stage)
	var cue:=str(profile.get(stage,""))
	expect(not CATALOG.cue(cue).is_empty() if not cue.is_empty() else not str(profile.get(stage+"_silence_reason",profile.get("silence_reason",""))).is_empty(),"stage resolves or explains silence: "+context+"/"+stage)

func verify_mixer(audio: Node) -> void:
	audio.clear(); audio.listener=Vector2.ZERO
	expect(audio.play_cue("blade.cast",Vector2(-100,0),{"priority":1,"stage":"cast"}),"ordinary family cue starts")
	audio.advance(.09,false)
	expect(audio.play_cue("blade.cast",Vector2.ZERO,{"priority":1,"stage":"cast"}),"ordinary same-family instances fill authored cue ceiling")
	expect(audio.play_cue("blade.cast",Vector2(100,0),{"priority":5,"stage":"cast","gain_db":-2}),"critical same-family cue bypasses ordinary throttle bucket")
	var count:=0
	for record in audio.records:
		if record.get("cue")=="blade.cast": count+=1
	expect(count<=int(CATALOG.cue("blade.cast").max_instances),"importance override retains same-cue instance ceiling")
	audio.clear()
	for family in ["blade","heavy_blade","thrust","blunt","bow","dash","earth","fire","ice","lightning","wind","water"]:
		expect(audio.play_cue(family+".cast",Vector2.ZERO,{"priority":1,"stage":"cast"}),"ordinary congestion fixture: "+family)
	for index in audio.RESERVED_WARNINGS: expect(audio.records[index].is_empty(),"ordinary sounds never occupy warning reserve")
	expect(audio.play_cue("boss_demon.tell",Vector2.ZERO,{"priority":5,"stage":"tell","owner":"enemy:10","serial":3}),"warning starts despite ordinary congestion")
	var remaining:=0.0
	for record in audio.records:
		if record.get("stage")=="tell": remaining=float(record.remaining)
	audio.advance(.2,true)
	var paused_remaining:=0.0
	for record in audio.records:
		if record.get("stage")=="tell": paused_remaining=float(record.remaining)
	expect(is_equal_approx(remaining,paused_remaining),"pause freezes warning lifetime")
	audio.advance(0,false)
	audio.cancel_owner("enemy:10",3,"tell")
	for record in audio.records: expect(record.get("owner")!="enemy:10","owner/serial cancellation removes only its matching warning")
	audio.clear()
	audio.play_cue("blade.cast",Vector2(-300,0),{"gain_db":-3,"priority":1})
	var index: int=audio.RESERVED_WARNINGS
	var before: float=audio.voices[index].volume_db
	expect(audio._panners[index].pan<0,"left world source pans left")
	SETTINGS.save_sfx_volume(.325); audio._update_gains()
	expect(absf(audio.voices[index].volume_db-before-linear_to_db(.5))<.001,"volume refresh preserves original per-event/profile gain")
	SETTINGS.save_sfx_volume(.65)
	audio.clear()

func verify_music_duck(audio: Node) -> void:
	var music:=BGM.new(); root.add_child(music)
	audio.music_duck.connect(music.set_combat_mix_gain)
	music.restore_playback_position(8.0)
	var cue:=music.current_cue
	audio.play_cue("blade.cast",Vector2.ZERO,{"priority":2,"stage":"cast"})
	expect(is_equal_approx(music.combat_mix_gain,1.0),"ordinary attacks never duck BGM")
	audio.play_cue("boss_demon.phase",Vector2.ZERO,{"priority":6,"stage":"phase"})
	expect(music.combat_mix_gain<1.0 and music.current_cue==cue and is_equal_approx(music.stored_playback_position,8.0),"critical duck changes gain only, preserving cue and position")
	var previous:=music.combat_mix_gain
	audio.advance(.2,true)
	expect(is_equal_approx(music.combat_mix_gain,previous),"pause freezes music duck envelope")
	var muted:=BGM.load_music_muted()
	BGM.save_music_muted(true); audio.clear()
	expect(is_equal_approx(music.combat_mix_gain,1.0) and music._active.volume_db<=-80,"duck release restores multiplier without overriding player mute")
	BGM.save_music_muted(muted)
	SETTINGS.save_sfx_volume(0)
	expect(not audio.play_cue("boss_demon.phase",Vector2.ZERO,{"priority":6,"stage":"phase"}) and is_equal_approx(music.combat_mix_gain,1.0),"muted SFX cannot cause silent music duck")
	SETTINGS.save_sfx_volume(.65)
	audio.clear(); music.queue_free(); await process_frame
func finish() -> void:
	print("CHRONICLE_SKILL_AUDIO_SMOKE ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
	quit(1 if failures else 0)

func verify_boss_results(feedback: Node) -> void:
	var contexts:=0
	for index in range(1,19):
		var stage:="B%02d" % index
		var spec:=request(); spec.stage=C.stage(stage); spec.node.id=stage
		var battle:=BATTLE.new(spec)
		battle.enemies.clear();battle.director.boss_spawned=true
		var boss: RefCounted=battle.director.spawn("boss",battle.position+Vector2(120,0))
		battle.enemies=[boss]
		for form in boss.form_count:
			contexts+=1
			expect(not CATALOG.boss(boss.definition_id,form,"defeated").is_empty(),"explicit Boss result context: %s/%d" % [stage,form])
		feedback.clear()
		if boss.form_count>1:
			boss.receive_damage(boss.hp)
			battle.tick(0,Vector2.ZERO)
			feedback.consume(battle.events,battle,Rect2())
			var phase:=false
			for record in feedback.audio.records: phase=phase or record.get("stage")=="phase"
			expect(phase,"real Boss form depletion emits identity transition: "+stage)
			battle.events.clear();feedback.clear()
			boss.advance_form(boss.transition_remaining+boss.observation_remaining+.01)
		boss.receive_damage(boss.hp+1)
		battle.tick(0,Vector2.ZERO)
		var finished:=false
		for event in battle.events: finished=finished or event.kind=="boss_defeated"
		feedback.consume(battle.events,battle,Rect2())
		var sounded:=false
		for record in feedback.audio.records: sounded=sounded or record.get("stage")=="defeated"
		expect(finished and sounded,"actual final defeat retains audible result for every Boss: "+stage)
		var cue:=CATALOG.boss(boss.definition_id,boss.form_index,"defeated")
		for path: String in CATALOG.cue(cue).get("variants",[]):
			var stream:=load(path) as AudioStreamWAV
			expect(stream!=null and stream.get_length()<=.43+1.0/48000,"defeat audio fits unchanged .48s result window: "+stage)
	expect(contexts==22,"18 Bosses expose all 22 identity/form result contexts")
	feedback.clear()

func verify_mix_capture(audio: Node) -> void:
	var windows: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://design/music-20261104-chinese-12/runtime/dense-music-test-windows.json"))
	var music_catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/audio/music_catalog.json"))
	var cues_by_id: Dictionary={}
	var window_items: Array=windows.get("items",[])
	for cue: Dictionary in music_catalog.get("cues",[]): cues_by_id[cue.id]=cue
	expect(windows.get("status","")=="PASS" and window_items.size()==12,"dense mix fixtures cover all twelve D2 game renders")
	for index in range(1,13):
		var cue_id: String="midi_test_%02d" % index
		var window: Dictionary=window_items[index-1] if window_items.size()>=index else {}
		expect(window.get("cue_id","")==cue_id and str(window.get("sha256",""))==str(cues_by_id.get(cue_id,{}).get("render_sha256","")),"dense mix fixture matches current D2 render hash: "+cue_id)
	if DisplayServer.get_name()=="headless": return
	var old_volume:=BGM.load_music_volume(); var old_mute:=BGM.load_music_muted()
	BGM.save_music_volume(.7);BGM.save_music_muted(false)
	var music:=BGM.new();root.add_child(music)
	audio.music_duck.connect(music.set_combat_mix_gain)
	var capture:=AudioEffectCapture.new();capture.buffer_length=2.0
	var effect_index:=AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0,capture)
	var measurements: Array=[]
	for index in range(0,13):
		audio.clear()
		if index==0: music.pause_music()
		else:
			music.restart_cue("midi_test_%02d" % index)
			music._active.seek(float(windows.items[index-1].start_seconds)+2.0)
		await create_timer(.1).timeout
		capture.clear_buffer()
		var peak:=0.0;var energy:=0.0;var samples:=0;var finite:=true
		for step in 7:
			audio.advance(.07,false)
			for family in ["blade","arcane","bone","fire"]:
				audio.play_cue(family+".cast",Vector2((step%3-1)*180,0),{"priority":2,"stage":"cast"})
				audio.play_cue(family+".impact",Vector2((step%3-1)*180,0),{"priority":1,"stage":"impact"})
			if step==3: audio.play_cue("boss_demon.tell",Vector2(120,0),{"priority":5,"stage":"tell","critical":true})
			await create_timer(.07).timeout
			var buffer:=capture.get_buffer(capture.get_frames_available())
			samples+=buffer.size()
			for frame: Vector2 in buffer:
				finite=finite and is_finite(frame.x) and is_finite(frame.y)
				peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
				energy+=frame.x*frame.x+frame.y*frame.y
		expect(finite and samples>4000 and peak>0.001 and peak<1.0 and capture.get_discarded_frames()==0,"dense shared mix remains real, finite, unclipped and lossless: BGM %02d" % index)
		measurements.append({"music":"none" if index==0 else "midi_test_%02d" % index,"start_seconds":0.0 if index==0 else float(windows.items[index-1].start_seconds)+2.0,"peak":peak,"rms":sqrt(energy/maxf(1,samples*2)),"frames":samples,"finite":finite})
	print("SKILL_AUDIO_MIX ",JSON.stringify(measurements))
	audio.clear();AudioServer.remove_bus_effect(0,effect_index)
	music.queue_free();await process_frame
	BGM.save_music_volume(old_volume);BGM.save_music_muted(old_mute)

func verify_guard_result(feedback: Node) -> void:
	feedback.clear()
	var spec:=request();spec.members=["JIA","F02"];spec.characters={"JIA":C.record("JIA",20),"F02":C.record("F02",20)}
	var battle:=BATTLE.new(spec)
	var enemy: RefCounted=battle.director.spawn("E01",battle.position+Vector2(50,0))
	enemy.hp=10000;enemy.max_hp=10000;battle.enemies=[enemy]
	expect(battle._cast(C.definition("F02").support,battle.characters.F02,false),"actual support guard window starts")
	var result:={}
	battle.mechanics.receive_hit(battle.current(),50,battle.equipment,result)
	expect(bool(result.get("guarded",false)) and float(result.get("health_loss",0))>0,"actual guard can reduce damage while still losing HP")
	var hit: Dictionary=result.duplicate(true)
	hit.merge({"kind":"player_hit","id":"JIA","enemy_id":enemy.id,"definition_id":"E01","form_index":0,"move_id":"swipe","position":battle.position},true)
	battle.events.append(hit)
	battle._resolve_hits()
	feedback.consume(battle.events,battle,Rect2())
	var guarded:=false;var countered:=false
	for record in feedback.audio.records:
		guarded=guarded or record.get("cue")=="feedback.guard"
		countered=countered or record.get("cue")=="blunt.impact"
	expect(guarded and countered,"real reduced-HP guard retains guard accent and actual delivery-grouped counter impact")
	feedback.clear()
