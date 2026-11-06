extends SceneTree
## Direct runtime contracts; independent comprehensive visual acceptance lives elsewhere.
const B := preload("res://scripts/battle/battle_session.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const P := preload("res://scripts/ui/chronicle/skill_presentation_profiles.gd")
const V := preload("res://scripts/ui/chronicle/skill_presentation.gd")
class DrawProbe:
	extends Node2D
	var battle: RefCounted
	var visual: RefCounted
	var draws:=0
	var caption: String=""
	func _draw() -> void:
		if battle==null or visual==null:return
		if not caption.is_empty():
			draw_rect(Rect2(0,0,1280,720),Color("111e19"))
			for point in [Vector2(600,300),Vector2(675,300)]:
				draw_line(point-Vector2(10,0),point+Vector2(10,0),Color("5c6a62"),1)
				draw_line(point-Vector2(0,8),point+Vector2(0,8),Color("5c6a62"),1)
			draw_string(ThemeDB.fallback_font,Vector2(24,32),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("eee5ce"))
			draw_string(ThemeDB.fallback_font,Vector2(24,58),"Current production universal VFX layer; cross guides = fixture foot anchors; static successful payload",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("bcbba7"))
		visual.draw(self,battle,Vector2(-1000,-600),1.0,ThemeDB.fallback_font,false,false)
		for projectile in battle.projectiles:visual.draw_projectile(self,projectile,Vector2(-1000,-600),1.0)
		draws+=1
class SheetProbe:
	extends Node2D
	var items: Array[Dictionary]=[]
	func _draw() -> void:
		draw_rect(Rect2(0,0,1440,1560),Color("111e19"))
		for i in items.size():
			var item: Dictionary=items[i]
			var at:=Vector2((i%3)*480,(i/3)*390)
			draw_rect(Rect2(at,Vector2(480,390)),Color("1d3229"),false,1)
			draw_string(ThemeDB.fallback_font,at+Vector2(9,22),str(item.caption),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("eee5ce"))
			# Source rectangles are recorded in index.json; original full frames remain intact.
			draw_texture_rect_region(item.texture,Rect2(at+Vector2(0,30),Vector2(480,270)),Rect2(200,65,880,560))
			var facts: Array=item.get("benefits",[])
			if facts.is_empty():
				draw_string(ThemeDB.fallback_font,at+Vector2(9,323),"FACT: no positive receiver delta in this frame",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("a4ad9e"))
			for row in mini(3,facts.size()):
				var fact: Dictionary=facts[row]
				var parts: Array[String]=[]
				for pair in [["hp_delta","HP"],["mp_delta","MP"],["shield_delta","shield"]]:
					if float(fact.get(pair[0],0))>0:parts.append("%s+%s" % [pair[1],String.num(float(fact[pair[0]]),1).trim_suffix(".0")])
				var label: String="FACT recipient=%s  %s" % [str(fact.get("recipient",""))," ".join(parts)]
				draw_string(ThemeDB.fallback_font,at+Vector2(9,323+row*19),label,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("b9d8c0"))
var capture_dir: String=""
var sheets_only:=false
var captures: Array[Dictionary]=[]
var sheets: Array[Dictionary]=[]
var checks:=0
var failures:=0
func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir=arg.trim_prefix("--capture=")
		if arg=="--sheets-only": sheets_only=true
	call_deferred("run")
func expect(value: bool,label: String) -> void:
	checks+=1
	if not value: failures+=1;push_error(label)
func fixture(id: String) -> RefCounted:
	var members: Array=["JIA"] if id=="JIA" else ["JIA",id]
	var records: Dictionary={}
	for member in members: records[member]=C.record(member,20)
	var b:=B.new({"attempt_id":"presentation-unit","members":members,"characters":records,"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":""},"stage":C.stage("B01"),"seed":971})
	b.enemies.clear();b.director.spawn_remaining=100000;b.director.config.boss_time=100000;b.director.config.boss_kills=100000
	var enemy: RefCounted=b.director.spawn("E01",b.position+Vector2(75,0));enemy.hp=100000;enemy.max_hp=100000;enemy.cooldown=100000;b.enemies=[enemy]
	for actor in b.characters.values(): actor.hp-=60;actor.mp=actor.stats.mp-30
	return b
func runtime_snapshot(b: RefCounted) -> String:
	var actors: Dictionary={}
	for id in b.characters: actors[id]=b.characters[id].snapshot()
	var enemies: Array=[]
	for enemy in b.enemies: enemies.append([enemy.id,enemy.hp,enemy.position,enemy.slow,enemy.slow_time])
	return var_to_str([actors,enemies,b.position,b.cast_serial,b.delivery_serial,b.projectiles,b._hits,b.mechanics.states,b.mechanics.curses,b.mechanics.exposures,b.mechanics.refunds,b.mechanics.fields,b.effects,b.events])
func run() -> void:
	if sheets_only:
		if capture_dir.is_empty() or DisplayServer.get_name()=="headless": push_error("sheets-only requires native rendering and existing capture directory");quit(1);return
		var index_path:=capture_dir.path_join("index.json")
		var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(index_path))
		for row: Dictionary in report.get("captures",[]):captures.append(row)
		await save_sheets()
		report.sheets=sheets
		report.sheet_source_regions={"effect":[200,65,880,560]}
		report.sheet_benefit_labels="QA FACT rows from original index benefit_facts, not a second runtime image; no-delta labels describe only this captured frame"
		report.sheet_generator_sha256=FileAccess.get_sha256("res://scripts/tests/skill_presentation_unit.gd")
		report.sheet_relayout_checks=checks
		var file:=FileAccess.open(index_path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
		print("SKILL_PRESENTATION_SHEETS ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures," captures=",captures.size()," pages=",sheets.size())
		quit(1 if failures else 0);return
	expect(P.all_profiles().size()==137,"explicit profile for every current ability")
	var capture_native:=not capture_dir.is_empty() and DisplayServer.get_name()!="headless"
	if capture_native: expect(DirAccess.make_dir_recursive_absolute(capture_dir)==OK,"capture output directory available")
	var covered:=0
	var viewport:=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var probe:=DrawProbe.new();viewport.add_child(probe)
	for id in C.IDS:
		var kit:=C.definition(id)
		for slot in ["basic","manual","automatic","support"]:
			var abilities: Array=kit[slot] if slot in ["manual","automatic"] else [kit[slot]] if kit[slot]!=null else []
			for ability: Resource in abilities:
				var b:=fixture(id)
				if id!="JIA":b.active=1
				var profile:=P.profile(id,str(ability.id),int(ability.kind))
				expect(profile.get("ability","")==str(ability.id) and not str(profile.get("weapon","")).is_empty(),"owned identity profile "+str(ability.id))
				expect(b._cast(ability,b.characters[id],slot!="support",slot=="manual"),"real ability activation "+str(ability.id))
				var releases: Array=[]
				for fact in b.events:
					if fact.kind=="ability_release":releases.append(fact)
				expect(releases.size()==1 and int(releases[0].presentation_id)>0 and int(releases[0].delivery)>0,"unique payload release "+str(ability.id))
				b._resolve_hits()
				var incoming: Array=[];b._update_projectiles(.25,incoming);b._resolve_hits()
				var truth_before:=runtime_snapshot(b)
				var v:=V.new();v.consume(b.events,b);v.sync(b)
				expect(runtime_snapshot(b)==truth_before,"presentation cannot mutate runtime "+str(ability.id))
				expect(v.counters.releases==1,"renderer receives one launch "+str(ability.id))
				var count: int=v.transients.size();v.consume(b.events,b);v.sync(b)
				expect(v.transients.size()==count,"refresh never duplicates facts "+str(ability.id))
				if capture_native:probe.caption="%s / %s / %s" % [id,slot,str(ability.id)]
				probe.battle=b;probe.visual=v;probe.queue_redraw();await process_frame
				if capture_native:
					await RenderingServer.frame_post_draw
					var image:=viewport.get_texture().get_image()
					var path:=capture_dir.path_join(str(ability.id)+".png")
					expect(image.get_size()==Vector2i(1280,720) and image.save_png(path)==OK,"real current ability capture "+str(ability.id))
					var benefits: Array=[]
					for fact in b.events:
						if fact.kind=="ability_effect":benefits.append(fact.duplicate(true))
					captures.append({"source":id,"slot":slot,"ability_id":str(ability.id),"path":path,"caption":probe.caption,"sha256":FileAccess.get_sha256(path),"weapon":profile.weapon,"material":profile.material,"motion":profile.motion,"phases":v.counters.duplicate(true),"benefit_facts":benefits,"simulation_time":b.director.elapsed,"renderer":"scripts/ui/chronicle/skill_presentation.gd","frame_size":[1280,720]})
				b._finish("failed");v.sync(b)
				expect(v.states.is_empty() and v.transients.is_empty(),"terminal cleanup "+str(ability.id))
				covered+=1
	var b:=fixture("F11")
	var frost: Resource=C.definition("F11").manual[0]
	b.active=1;b._cast(frost,b.characters.F11,true,true);b._resolve_hits()
	var v:=V.new();v.consume(b.events,b);v.sync(b)
	var before: int=v.counters.releases
	b.events.clear();b.active=0;b._cast(C.definition("JIA").manual[0],b.characters.JIA,true,true);b._resolve_hits();v.consume(b.events,b);v.sync(b)
	b.events.clear();b._cast(C.definition("JIA").manual[1],b.characters.JIA,true,true);b._resolve_hits();v.consume(b.events,b);v.sync(b)
	expect(v.counters.releases==before+4,"two original-cast echoes remain separate from two paid releases")
	var ids: Dictionary={}
	for effect in b.effects:
		expect(not ids.has(effect.presentation_id),"no presentation identity reused across echo deliveries");ids[effect.presentation_id]=true
	b.events.clear();b.characters.JIA.mp=0;b.characters.JIA.cooldowns.clear()
	var serial: int=b.presentation_serial
	expect(not b._cast(C.definition("JIA").manual[0],b.characters.JIA,true,true),"MP failure stays failure")
	expect(b.presentation_serial==serial,"failed request emits no successful release")
	var refund:=fixture("F04")
	refund._cast(C.definition("JIA").manual[0],refund.characters.JIA,true,true)
	refund.events.clear();refund.active=1;refund._cast(C.definition("F04").manual[0],refund.characters.F04,true,true)
	var rv:=V.new();rv.consume(refund.events,refund);rv.sync(refund)
	var payment_labels:=0
	for transient in rv.transients:
		if transient.phase in ["transfer","benefit"] and str(transient.get("recipient",""))=="JIA" and float(transient.get("mp_delta",0))>0:payment_labels+=1
	expect(payment_labels==1,"settlement never displays its actual payment twice")
	var guard:=fixture("F02");guard.active=1;guard._cast(C.definition("F02").manual[0],guard.characters.F02,true,true)
	var states: Array=guard.presentation_states()
	expect(not states.is_empty(),"actual guard status snapshot")
	var original: float=guard.mechanics.states.F02.windows.guard.life
	for state in states:state.remaining=999
	expect(guard.mechanics.states.F02.windows.guard.life==original,"state snapshot cannot mutate gameplay")
	var sv:=V.new();sv.sync(guard);var count: int=sv.transients.size();guard.set_paused(true);guard.tick(20,Vector2.ONE);sv.sync(guard)
	expect(sv.transients.size()==count and sv.clock==guard.director.elapsed,"pause holds visual and simulation state")
	guard.set_paused(false);guard.tick(20,Vector2.ZERO);sv.sync(guard)
	expect(sv.counters.state_ends>0,"actual finite window expiry produces an ending tail")
	var draw_count: int=probe.draws
	expect(draw_count==covered,"all ability paths issue real canvas drawing callbacks")
	probe.battle=null;probe.visual=null;viewport.free()
	if capture_native:
		await save_sheets()
		var report:={"scope":"Current single-frame coverage of the production universal skill VFX helper after 137 real successful ability payloads; no actor models, ground, legacy Jia strips or 13 legacy authored base layers. Full scene/lifecycle/pressure are separate acceptance.","renderer_sha256":FileAccess.get_sha256("res://scripts/ui/chronicle/skill_presentation.gd"),"profile_sha256":FileAccess.get_sha256("res://assets/data/chronicle/skill_presentation_profiles.json"),"captures":captures,"sheets":sheets,"sheet_source_regions":{"effect":[200,65,880,560]},"sheet_benefit_labels":"QA FACT rows from original index benefit_facts, not a second runtime image","display_server":DisplayServer.get_name(),"rendering_method":RenderingServer.get_current_rendering_method(),"checks":checks,"failures":failures}
		var file:=FileAccess.open(capture_dir.path_join("index.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("SKILL_PRESENTATION_DRAW_CALLS ",draw_count)
	print("SKILL_PRESENTATION_UNIT ","PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures," abilities=",covered)
	quit(1 if failures else 0)

func save_sheets() -> void:
	for first in range(0,captures.size(),12):
		var viewport:=SubViewport.new();viewport.size=Vector2i(1440,1560);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
		var page:=SheetProbe.new();viewport.add_child(page)
		var ids: Array[String]=[]
		for i in range(first,mini(first+12,captures.size())):
			var row: Dictionary=captures[i]
			var image:=Image.load_from_file(str(row.path))
			page.items.append({"texture":ImageTexture.create_from_image(image),"caption":str(row.caption),"benefits":row.get("benefit_facts",[])})
			ids.append(str(row.ability_id))
		page.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
		var path:=capture_dir.path_join("sheet-%02d.png" % (first/12+1))
		expect(viewport.get_texture().get_image().save_png(path)==OK,"native Godot current VFX contact sheet")
		sheets.append({"path":path,"ability_ids":ids,"sha256":FileAccess.get_sha256(path)})
		viewport.free()
