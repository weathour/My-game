extends SceneTree
## State-only production-event check. No fake art and no visual-completion claim.
const C=preload("res://scripts/content/combat_catalog.gd")
const B=preload("res://scripts/battle/battle_session.gd")
const S=preload("res://scripts/battle/enemy_system.gd")
const P=preload("res://scripts/ui/chronicle/zhang_liao_summon_presentation.gd")
var checks:=0
var failures:=0
func _init():call_deferred("run")
func expect(value:bool,label:String):
	checks+=1
	if not value:failures+=1;push_error(label)
func advance(b:RefCounted,p:RefCounted,delta:float)->Array:
	b.director.elapsed+=delta
	var output:Dictionary=S.step(b.enemies,b.position,delta,{"hazards":b.hazards,"patterns":b.pending_patterns,"projectiles":b.projectiles,"config":b.director.config})
	for spawn:Dictionary in output.spawns:b.enemies.append(b.director.derivative(spawn,b.enemies))
	b.projectiles.append_array(output.projectiles)
	var before:=var_to_str([b.position,b.target_id,b.director.rng.state,b.hazards,b.pending_patterns,b.projectiles,b.enemies[0].position,b.enemies[0].hp,b.enemies[0].current_action,b.enemies[0].cooldown,b.enemies[0].windup])
	p.consume(output.events,b);p.sync(b)
	expect(before==var_to_str([b.position,b.target_id,b.director.rng.state,b.hazards,b.pending_patterns,b.projectiles,b.enemies[0].position,b.enemies[0].hp,b.enemies[0].current_action,b.enemies[0].cooldown,b.enemies[0].windup]),"presentation does not mutate battle")
	return output.events
func run():
	for form in 2:
		for collaborator in 2:
			var b:=B.new({"attempt_id":"liao-state","members":["JIA"],"characters":{"JIA":C.record("JIA",10)},"equipment":{},"stage":C.stage("B17"),"seed":13})
			b.enemies.clear()
			var boss:RefCounted=b.director.spawn("B17",b.position+Vector2(-180,0));b.enemies.append(boss)
			boss._apply_form(form);boss.cooldown=0;boss.observation_remaining=0;boss.transition_remaining=0;boss.params.collaboration_index=collaborator
			var selected:Dictionary={}
			for action:Dictionary in boss.actions:
				if action.action=="collaboration":selected=action.duplicate(true)
			boss.actions=[selected]
			var p:=P.new()
			var events:=advance(b,p,0)
			if form==1:
				events.insert(0,S.phase_event(boss))
				p.consume(events,b);p.sync(b)
			expect(p.snapshot().active_count==1,"real admission tracked")
			if p.entries.is_empty():continue
			var entry:Dictionary=p.entries.values()[0]
			expect(entry.collaborator==("M03_WAR" if collaborator==0 else "M04_WAR"),"real branch")
			expect(is_equal_approx(entry.lifetime,2.9),"authored lifetime")
			var initial:=var_to_str(p.snapshot())
			for duplicate in 100:p.consume(events,b);p.sync(b)
			expect(initial==var_to_str(p.snapshot()),"repeat batch deduplicates")
			for index in 90:
				events=advance(b,p,1.0/60.0)
				if entry.release_time>=0:break
			expect(entry.release_time>=0,"real release observed")
			var clip:Dictionary={"frames":8 if collaborator==0 else 10,"contact_frame":4 if collaborator==0 else 7,"release_frame":4 if collaborator==0 else 5}
			if collaborator==0:
				expect(p._effect_snapshot(entry)[0].frame==4,"Gao FX contact locks actual release")
				expect(p._pose_frame(entry,clip,false)==4,"Gao contact frame at real release")
			else:
				for effect: Dictionary in p._effect_snapshot(entry): expect(effect.frame==4,"Chen FX holds preparation until its actual impact")
				expect(entry.impact_time<0 and p._pose_frame(entry,clip,false)==5,"Chen release sends array, not contact")
				for index in 60:
					advance(b,p,1.0/60.0)
					if entry.impact_time>=0:break
				expect(entry.impact_time>entry.release_time+.89,"Chen real delayed contact")
				expect(p._pose_frame(entry,clip,false)==7,"Chen contact frame at actual marker")
				var fx_states: Array=p._effect_snapshot(entry)
				expect(fx_states[0].frame==5 and fx_states[1].frame==4 and fx_states[2].frame==4,"independent marker FX contact, no early later stamp")
				for index in 29:
					var marker_events: Array=advance(b,p,1.0/60.0)
					for event: Dictionary in marker_events:
						if event.kind=="enemy_hazard_release":
							for effect: Dictionary in p._effect_snapshot(entry):
								if int(effect.marker)==int(event.geometry.get("marker_index",0)): expect(effect.frame==5,"each actual marker starts FX at contact")
			b.set_paused(true)
			var paused:=var_to_str(p.snapshot())
			for index in 20:p.sync(b)
			expect(paused==var_to_str(p.snapshot()),"same battle clock freezes presentation")
			boss.dead=true;p.sync(b)
			expect(p.snapshot().active_count==0,"source death cleanup")
			p.clear(true)
			expect(p.snapshot().seen_count==0 and p.snapshot().hidden_count==0,"explicit full reset")
	print("LIAO_SUMMON_STATECHECK ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures," scope=events_only")
	quit(0 if failures==0 else 1)
