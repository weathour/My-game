extends RefCounted
## Bounded, fact-driven skill rendering. It never invokes combat, timers, audio, or RNG.
const PROFILES := preload("res://scripts/ui/chronicle/skill_presentation_profiles.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const SETTINGS := preload("res://scripts/shared/settings.gd")
const SLOW_COLOR := Color("a6dce9",.65)
const EXPOSE_COLOR := Color("e8bd88",.6)
const TEMPER_COLOR := Color("e4b57b",.65)
const GUARD_SHAPE := [Vector2(-24,-20),Vector2(24,-20),Vector2(27,5),Vector2(0,31),Vector2(-27,5),Vector2(-24,-20)]
const MAX_TRANSIENTS := 112
const MAX_STATE_DRAWS := 64
var clock := 0.0
var transients: Array[Dictionary] = []
var seen: Dictionary = {}
var states: Dictionary = {}
var counters := {"releases":0,"contacts":0,"benefits":0,"state_starts":0,"state_pulses":0,"state_ends":0,"peak":0}

static func effect_key(effect: Dictionary) -> String:
	if effect.has("presentation_id"): return "fact:%d" % int(effect.presentation_id)
	return "%s:%s:%s:%s:%s:%s:%s" % [effect.get("source",""),effect.get("cast",0),effect.get("delivery",0),effect.get("kind",""),effect.get("visual_time",0),effect.get("origin",Vector2.ZERO),effect.get("target_id",0)]

static func decorated(effect: Dictionary) -> Dictionary:
	var result := effect.duplicate(false)
	var profile := PROFILES.render_profile(str(effect.get("source","")),str(effect.get("ability","")),int(effect.get("ability_kind",-1)))
	if result.has("beneficiaries"): result.beneficiaries=result.beneficiaries.duplicate()
	result.profile = profile
	result.action = profile.motion
	result.manual = bool(effect.get("manual",str(effect.get("color","")) == "manual"))
	return result

func _add(entry: Dictionary, duration: float) -> void:
	entry.started = clock
	entry.duration = duration
	if str(entry.get("phase","")) in ["benefit","transfer"]: entry._benefit_label=_benefit_label(entry)
	transients.append(entry)
	if transients.size() > MAX_TRANSIENTS:
		var remove := 0
		for i in transients.size():
			if not bool(transients[i].get("manual",false)) and str(transients[i].get("phase","")) != "benefit": remove=i;break
		transients.remove_at(remove)
	counters.peak = maxi(counters.peak,transients.size())

func clear() -> void:
	transients.clear();seen.clear();states.clear()

func sync(battle: RefCounted) -> void:
	clock = battle.director.elapsed
	if not battle.outcome.is_empty(): clear();return
	for effect: Dictionary in battle.effects:
		if str(effect.get("source","")) == "" or str(effect.get("kind","")) == "impact": continue
		var key := "release:"+effect_key(effect)
		if seen.has(key): continue
		seen[key]=clock
		var entry := decorated(effect)
		entry.phase="release"
		_add(entry,float(entry.profile.release_duration))
		counters.releases+=1
	var next: Dictionary={}
	for snapshot: Dictionary in battle.presentation_states():
		var key: String=snapshot.key
		var entry:=snapshot
		if states.has(key) and str(states[key].get("source",""))==str(snapshot.get("source","")) and str(states[key].get("ability",""))==str(snapshot.get("ability","")):
			entry.profile=states[key].profile
		else: entry.profile=_state_profile(snapshot)
		entry.initial=maxf(float(snapshot.get("remaining",0)),float(states.get(key,{}).get("initial",0)))
		next[key]=entry
		var changed := not states.has(key)
		if states.has(key):
			changed = float(snapshot.get("remaining",0))>float(states[key].get("remaining",0))+.05 or float(snapshot.get("value",0))!=float(states[key].get("value",0))
		if changed and (float(snapshot.get("value",0))>0 or float(snapshot.get("remaining",0))>0):
			var start:=entry.duplicate(false)
			start.phase="state_start" if not states.has(key) else "state_pulse"
			_add(start,.34)
			if start.phase=="state_start": counters.state_starts+=1
			else: counters.state_pulses+=1
	for key in states:
		if next.has(key): continue
		var ending: Dictionary=states[key].duplicate(false)
		ending.phase="state_end";_add(ending,.30);counters.state_ends+=1
	states=next
	for i in range(transients.size()-1,-1,-1):
		if clock-float(transients[i].started)>=float(transients[i].duration): transients.remove_at(i)
	for key in seen.keys():
		if clock-float(seen[key])>4: seen.erase(key)

func _state_profile(state: Dictionary) -> Dictionary:
	var source:=str(state.get("source",""))
	var ability:=str(state.get("ability",""))
	if ability.is_empty() and not C.definition(source).is_empty(): ability=str(C.definition(source).basic.id)
	return PROFILES.render_profile(source,ability)

func consume(events: Array, battle: RefCounted) -> void:
	clock=battle.director.elapsed
	if battle.paused or not battle.outcome.is_empty(): return
	var contact_counts: Dictionary = {}
	var settled_receivers: Dictionary = {}
	for fact: Dictionary in events:
		if str(fact.get("kind","")) == "ability_effect" and float(fact.get("mp_delta",0))>0:
			var profile:=PROFILES.render_profile(str(fact.get("source","")),str(fact.get("ability","")))
			if str(profile.motion)=="refund_settle": settled_receivers[str(fact.get("source",""))+":"+str(fact.get("recipient",""))]=true
	for fact: Dictionary in events:
		var kind:=str(fact.get("kind",""))
		if kind not in ["ability_release","damage_dealt","ability_effect","mechanic"]: continue
		if kind=="ability_release":
			var release_key: String="release:"+effect_key(fact)
			if seen.has(release_key): continue
			seen[release_key]=clock
			var release:=decorated(fact)
			release.kind=str(fact.effect_kind);release.phase="release"
			_add(release,float(release.profile.release_duration));counters.releases+=1
			continue
		if kind=="mechanic" and str(fact.get("mechanic","")) not in ["refund","echo"]: continue
		# Settlement already supplies one exact aggregate receiver delta; do not display the same transfer twice.
		if kind=="mechanic" and str(fact.get("mechanic",""))=="refund" and settled_receivers.has(str(fact.get("id",""))+":"+str(fact.get("payer",""))): continue
		var key: String
		if kind=="damage_dealt":
			key="contact:%s:%s:%s:%s:%s" % [fact.get("source",""),fact.get("cast",0),fact.get("delivery",0),fact.get("target_id",0),fact.get("time",clock)]
			var group: String="%s:%s" % [fact.get("source",""),fact.get("delivery",0)]
			var maximum:=1 if bool(fact.get("secondary",false)) else 3
			if int(contact_counts.get(group,0))>=maximum: continue
			contact_counts[group]=int(contact_counts.get(group,0))+1
		elif kind=="ability_effect":
			key="benefit:%s:%s:%s:%s:%s:%s" % [fact.get("source",""),fact.get("cast",0),fact.get("delivery",0),fact.get("recipient",""),fact.get("presentation_id",0),clock]
		else: key="mechanic:%s:%s:%s:%s:%s" % [fact.get("mechanic",""),fact.get("id",""),fact.get("payer",""),fact.get("presentation_id",fact.get("cast",0)),clock]
		if seen.has(key): continue
		seen[key]=clock
		var entry:=fact.duplicate(false)
		entry.source=str(fact.get("source",fact.get("id","")))
		entry.origin=fact.get("position",battle.position)
		entry.profile=PROFILES.render_profile(entry.source,str(fact.get("ability","")),int(fact.get("ability_kind",-1)))
		entry.manual=bool(fact.get("manual",false))
		if kind=="damage_dealt":
			entry.phase="contact";_add(entry,float(entry.profile.contact_duration));counters.contacts+=1
		elif kind=="ability_effect":
			if float(fact.get("hp_delta",0))+float(fact.get("mp_delta",0))+float(fact.get("shield_delta",0))<=0: continue
			entry.phase="benefit";_add(entry,.78);counters.benefits+=1
		else:
			entry.phase="transfer"
			if str(fact.get("mechanic",""))=="refund":
				if float(fact.get("amount",0))<=0: continue
				entry.recipient=str(fact.get("payer",""));entry.mp_delta=float(fact.amount)
			_add(entry,.55)

func draw_projectile(painter: Node2D, projectile: Dictionary, origin: Vector2, scale: float, body: bool = true, cached_profile: Dictionary = {}) -> bool:
	if projectile.get("hostile",false): return false
	var profile: Dictionary=cached_profile if not cached_profile.is_empty() else PROFILES.render_profile(str(projectile.context.source),str(projectile.context.ability))
	var color:=Color(profile._palette_color)
	var point: Vector2=projectile.position+Vector2(0,-32)
	var direction: Vector2=Vector2(projectile.velocity).normalized()
	painter.draw_set_transform(origin+point*scale,Vector2(projectile.velocity).angle(),Vector2.ONE*scale)
	painter.draw_line(Vector2(-27,0),Vector2(-4,0),Color(color,.34),2,true)
	painter.draw_line(Vector2(-16,3),Vector2(-5,1),Color(profile._accent_color),1,true)
	if not body: return true
	var weapon:=str(profile.weapon)
	if weapon in ["bow","crossbow","spear","lance"]:
		painter.draw_line(Vector2(-13,0),Vector2(10,0),color,2,true)
		painter.draw_colored_polygon(PackedVector2Array([Vector2(15,0),Vector2(6,-4),Vector2(8,0),Vector2(6,4)]),color)
		for side in [-1,1]: painter.draw_line(Vector2(-12,0),Vector2(-17,side*4),Color(profile._accent_color),2,true)
	elif weapon=="medicine":
		painter.draw_circle(Vector2.ZERO,5,Color(color,.25))
		painter.draw_line(Vector2(-6,0),Vector2(6,0),color,2,true);painter.draw_line(Vector2(0,-6),Vector2(0,6),color,2,true)
	elif weapon=="ledger":
		painter.draw_rect(Rect2(-6,-7,12,14),Color(color,.24));painter.draw_rect(Rect2(-6,-7,12,14),color,false,1)
		painter.draw_line(Vector2(-3,-2),Vector2(3,-2),color,1);painter.draw_line(Vector2(-3,2),Vector2(2,2),color,1)
	else:
		var radius:=6.0 if str(profile.material)=="curse" else 5.0
		painter.draw_circle(Vector2.ZERO,radius,Color(color,.22))
		_glyph(painter,Vector2.ZERO,radius+2,profile,1.0,0.0 if SETTINGS.comfort_enabled("reduced_motion") else clock*2)
		painter.draw_circle(Vector2.ZERO,2,color)
	return true

func _glyph(painter: Node2D, point: Vector2, radius: float, profile: Dictionary, alpha: float, turn: float = 0.0) -> void:
	var color:=Color(profile._palette_color,alpha)
	var points:=PackedVector2Array()
	if turn==0.0:
		for unit: Vector2 in profile._glyph_outline: points.append(point+unit*radius)
	else:
		for angle: float in profile._glyph_angles: points.append(point+Vector2.from_angle(turn+angle)*radius)
	painter.draw_polyline(points,color,1.3,true)
	if turn==0.0:
		for unit: Vector2 in profile._glyph_marks:
			painter.draw_line(point+unit*radius*.35,point+unit*radius*.75,color,1.2,true)
	else:
		for angle: float in profile._glyph_mark_angles:
			var unit:=Vector2.from_angle(turn+angle)
			painter.draw_line(point+unit*radius*.35,point+unit*radius*.75,color,1.2,true)

func draw(painter: Node2D, battle: RefCounted, origin: Vector2, scale: float, font: Font, reduced_motion: bool, reduced_flash: bool, visible_world: Rect2 = Rect2()) -> void:
	var visible:=visible_world if visible_world.has_area() else world_view(painter,origin,scale)
	var state_draws:=0
	for key in states:
		var state: Dictionary=states[key]
		if state_draws>=MAX_STATE_DRAWS: break
		if state.has("recipient") and str(state.recipient)!=str(battle.current().id): continue
		if str(state.kind) in ["ammo","mark","relay"] and float(state.get("value",0))<=0: continue
		if not effect_visible(state,visible): continue
		_draw_state(painter,state,origin,scale,reduced_motion)
		state_draws+=1
	var text_row:=0
	for entry: Dictionary in transients:
		if not effect_visible(entry,visible): continue
		var age:=clampf((clock-float(entry.started))/float(entry.duration),0,1)
		var alpha: float=(1-age)*(.55 if reduced_flash else .85)
		match str(entry.phase):
			"release": _draw_release(painter,entry,origin,scale,age,alpha,reduced_motion)
			"contact": _draw_contact(painter,entry,origin,scale,age,alpha,reduced_motion)
			"benefit","transfer":
				if text_row<6:
					_draw_benefit(painter,entry,battle,origin,scale,font,age,alpha,text_row)
					text_row+=1
			"state_start","state_pulse","state_end":
				if entry.has("recipient") and str(entry.recipient)!=str(battle.current().id): continue
				var point: Vector2=entry.get("position",battle.position)+Vector2(0,-36)
				painter.draw_set_transform(origin+point*scale,0,Vector2.ONE*scale)
				_glyph(painter,Vector2.ZERO,22.0 if reduced_motion else (16+age*10 if entry.phase=="state_end" else 28-age*10),entry.profile,alpha*.6)

func _draw_release(painter: Node2D, entry: Dictionary, origin: Vector2, scale: float, age: float, alpha: float, reduced: bool) -> void:
	if reduced: age=0.0 # Cosmetic geometry stays fixed; alpha and actual transport remain live.
	var profile: Dictionary=entry.profile
	var color:=Color(profile._palette_color,alpha*float(profile.strength))
	var accent:=Color(profile._accent_color,alpha*.7)
	var ground: Vector2=entry.get("origin",Vector2.ZERO)
	var direction: Vector2=entry.get("direction",Vector2.RIGHT)
	var radius:=maxf(16,float(entry.get("footprint_radius",entry.get("radius",25))))
	var angle:=direction.angle()
	var kind:=str(entry.get("kind","cast"))
	painter.draw_set_transform(origin+ground*scale,0,Vector2.ONE*scale)
	if kind=="ring":
		var r:=radius*(.94 if reduced else .82+age*.18)
		painter.draw_arc(Vector2.ZERO,r,0,TAU,48,Color(color,color.a*.45),1.8,true)
		var count:=6+int(profile.signature)%5
		for i in count:
			var pos:=Vector2.from_angle(TAU*i/count)*r
			painter.draw_line(pos*.90,pos,accent,2,true)
	elif kind=="slash":
		painter.draw_set_transform(origin+(ground+Vector2(0,-30))*scale,angle,Vector2.ONE*scale)
		if bool(entry.get("narrow",false)) and str(profile.weapon) in ["bow","crossbow"]:
			var lanes:=1+mini(4,int(entry.get("ammo_spent",0)))
			for i in lanes:
				var y: float=(i-(lanes-1)*.5)*6
				painter.draw_line(Vector2(0,y),Vector2(radius,y),Color(color,color.a*(1.0-i*.1)),2,true)
				painter.draw_line(Vector2(radius-8,y-3),Vector2(radius,y),color,1.3,true)
		elif bool(entry.get("narrow",false)):
			var tail:=radius*(.75 if reduced else 1.0-age*.22)
			var points:=PackedVector2Array([Vector2(0,-3),Vector2(tail-13,-6),Vector2(tail+5,0),Vector2(tail-13,6),Vector2(0,3)])
			painter.draw_colored_polygon(points,Color(color,color.a*.16));painter.draw_polyline(points,color,2,true)
			painter.draw_line(Vector2(7,0),Vector2(tail,0),color,2,true)
		else:
			var center:=Vector2(radius*.25,0)
			var start: float=-1.15+age*.20
			painter.draw_arc(center,radius*.64,start,1.1+age*.20,24,color,3,true)
			painter.draw_arc(center,radius*.56,start+.12,1.0+age*.15,24,accent,1.5,true)
	else:
		painter.draw_set_transform(origin+(ground+Vector2(0,-36))*scale,0,Vector2.ONE*scale)
		var motion:=str(profile.motion)
		if motion in ["ward","guard"]:
			var shape:=PackedVector2Array([Vector2(-19,-20),Vector2(19,-20),Vector2(23,3),Vector2(0,27),Vector2(-23,3),Vector2(-19,-20)])
			painter.draw_polyline(shape,color,2.2,true)
		elif motion=="temper":
			painter.draw_line(Vector2(-15,20),Vector2(18,-22),color,4,true)
			for i in 4:
				var pos:=Vector2.from_angle(i*TAU/4+age)*17
				painter.draw_line(Vector2(7,-6)+pos*.5,Vector2(7,-6)+pos,accent,2,true)
		elif motion=="rally":
			for side in [-1,1]:
				painter.draw_polyline(PackedVector2Array([Vector2(side*22,17),Vector2(side*22,-17),Vector2(side*14,-9)]),color,2.5,true)
		elif motion=="extend":
			painter.draw_arc(Vector2(-10,0),18,-PI*.7,PI*.7,20,color,2,true)
			painter.draw_arc(Vector2(10,0),18,PI*.3,PI*1.7,20,accent,2,true)
		elif motion in ["mana","refund_settle"]:
			for i in 3:
				var p:=Vector2((i-1)*13,-age*14-i*4)
				painter.draw_polyline(PackedVector2Array([p+Vector2(0,-6),p+Vector2(4,0),p+Vector2(0,6),p+Vector2(-4,0),p+Vector2(0,-6)]),color,1.8,true)
		elif motion=="heal":
			for i in 3:
				var p:=Vector2((i-1)*14,-age*16-i*5)
				painter.draw_line(p-Vector2(4,0),p+Vector2(4,0),color,2,true)
				painter.draw_line(p-Vector2(0,4),p+Vector2(0,4),color,2,true)
		else: _glyph(painter,direction*22,10+age*8,profile,color.a,angle)
	if float(entry.get("shield_spent",0))>0:
		painter.draw_set_transform(origin+(ground+Vector2(0,-30))*scale,angle,Vector2.ONE*scale)
		for side in [-1,1]:painter.draw_line(Vector2(0,side*22*(1-age)),Vector2(23+age*18,side*3),accent,2.5,true)
	_weapon_release(painter,profile,ground,direction,origin,scale,age,alpha,kind,reduced)
	if str(profile.motion)=="dash" and bool(entry.get("direct",false)):
		var end: Vector2=entry.get("position_after",ground)
		painter.draw_set_transform(origin,0,Vector2.ONE*scale)
		painter.draw_line(ground+Vector2(0,-30),end+Vector2(0,-30),Color(color,color.a*.3),3,true)
	if not bool(entry.get("direct",true)):
		painter.draw_set_transform(origin+(ground+Vector2(0,-66))*scale,0,Vector2.ONE*scale)
		_glyph(painter,Vector2.ZERO,8,profile,alpha*.65)

func _weapon_release(painter: Node2D, profile: Dictionary, ground: Vector2, direction: Vector2, origin: Vector2, scale: float, age: float, alpha: float, kind: String, reduced: bool) -> void:
	if reduced: age=0.0
	var weapon:=str(profile.weapon)
	var color:=Color(profile._palette_color,alpha*.65)
	var accent:=Color(profile._accent_color,alpha*.55)
	painter.draw_set_transform(origin+(ground+Vector2(0,-30)+direction*14)*scale,direction.angle(),Vector2.ONE*scale)
	if weapon in ["bow","crossbow"] and kind=="cast":
		if weapon=="bow":
			painter.draw_arc(Vector2(-5,0),17,-PI*.43,PI*.43,14,color,2,true)
			painter.draw_polyline(PackedVector2Array([Vector2(-1,-16),Vector2(7-age*6,0),Vector2(-1,16)]),accent,1.4,true)
		else:
			painter.draw_polyline(PackedVector2Array([Vector2(-2,-15),Vector2(5,0),Vector2(-2,15)]),color,2,true)
			painter.draw_line(Vector2(-12,0),Vector2(13,0),color,2.5,true)
		for side in [-1,1]:painter.draw_line(Vector2(17,0),Vector2(25,side*4),Color(color,alpha*.4),1,true)
	elif weapon=="halberd" and kind=="slash":
		painter.draw_arc(Vector2(12,0),24,-1.25,1.25,15,color,2,true)
		painter.draw_line(Vector2(25,-22),Vector2(39,-22),color,2,true)
	elif weapon in ["spear","lance","glaive","shield_spear"] and kind=="slash":
		painter.draw_line(Vector2(-17,1),Vector2(29,0),accent,2,true)
		painter.draw_colored_polygon(PackedVector2Array([Vector2(34,0),Vector2(22,-4),Vector2(25,0),Vector2(22,4)]),color)
	elif weapon=="medicine":
		for i in 3:
			var point:=Vector2((i-1)*10,-12-age*13-i*4)
			painter.draw_arc(point,4,.2,PI*.85,8,color,1.5,true)
	elif weapon=="ledger":
		for i in 3:
			var point:=Vector2(i*9-13,-8-i*4-age*8)
			painter.draw_rect(Rect2(point,Vector2(7,10)),accent,false,1)
			painter.draw_line(point+Vector2(2,3),point+Vector2(5,3),color,1,true)
	elif weapon=="cook":
		for i in 3:painter.draw_arc(Vector2(i*9-9,-age*18-i*6),5,-PI*.5,PI*.5,8,color,1.5,true)
	elif weapon=="voice":
		for i in 3:painter.draw_arc(Vector2.ZERO,12+i*8+age*5,-1.3,1.3,16,Color(color,alpha*(.6-i*.12)),1.5,true)
	elif weapon in ["talisman","spell"]:
		_glyph(painter,Vector2(12,-2),9+age*5,profile,alpha*.55,age*.3)
		if str(profile.material)=="ice":
			for i in 3:
				var point:=Vector2(4+i*9,-10+i*7)
				painter.draw_colored_polygon(PackedVector2Array([point,point+Vector2(3,7),point+Vector2(-3,7)]),accent)

func _draw_contact(painter: Node2D, entry: Dictionary, origin: Vector2, scale: float, age: float, alpha: float, reduced: bool) -> void:
	if reduced: age=0.0
	var profile: Dictionary=entry.profile
	var point: Vector2=entry.origin+Vector2(0,-clampf(float(entry.get("body_height",64))*.45,24,96))
	var secondary:=bool(entry.get("secondary",false))
	var material:=str(profile.material)
	var color:=Color(profile._palette_color,alpha*(.45 if secondary else .9))
	painter.draw_set_transform(origin+point*scale,Vector2(entry.get("direction",Vector2.RIGHT)).angle(),Vector2.ONE*scale)
	var directions: Array=profile._contact_secondary if secondary else profile._contact_primary
	var distance:=9.0 if reduced else 7+age*22
	for direction: Vector2 in directions:
		var pos:=direction*distance
		if material in ["steel","wood"]:
			painter.draw_line(pos*.4,pos,color,2.2,true)
		elif material=="ice":
			painter.draw_colored_polygon(PackedVector2Array([pos,pos+Vector2(3,5),pos+Vector2(-2,8)]),color)
		elif material in ["herb","warmth"]:
			painter.draw_arc(pos,3,0,PI,8,color,1.5,true)
		else: _glyph(painter,pos,3,profile,color.a)
	if str(entry.get("mechanic",""))=="curse_cashout":
		for i in 3:painter.draw_arc(Vector2.ZERO,8+(1-age)*(10+i*5),i*TAU/3,i*TAU/3+1.25,12,color,2,true)
	if not secondary:
		painter.draw_line(Vector2(-8,-9),Vector2(9,8),Color(1,.96,.82,alpha*.65),2,true)
		painter.draw_line(Vector2(-6,9),Vector2(7,-8),color,2,true)

func _draw_state(painter: Node2D, state: Dictionary, origin: Vector2, scale: float, reduced: bool) -> void:
	var profile: Dictionary=state.profile
	var kind:=str(state.kind)
	var point: Vector2=state.position
	var color:=Color(profile._palette_color,.5)
	painter.draw_set_transform(origin+point*scale,0,Vector2.ONE*scale)
	if kind=="field":
		var radius:=float(state.radius)
		for i in 12: painter.draw_arc(Vector2.ZERO,radius,i*TAU/12,i*TAU/12+.30,8,Color(color,.33),1.8,true)
		_glyph(painter,Vector2.ZERO,18,profile,.26)
		return
	point+=Vector2(0,-40 if state.has("target_id") else -36)
	painter.draw_set_transform(origin+point*scale,0,Vector2.ONE*scale)
	match kind:
		"shield","guard":
			var shield:=PackedVector2Array(GUARD_SHAPE)
			painter.draw_polyline(shield,Color(color,.45),1.8,true)
		"slow":
			for i in 3: painter.draw_line(Vector2((i-1)*9,-20),Vector2((i-1)*9,-9),SLOW_COLOR,1.6,true)
		"expose":
			for side in [-1,1]: painter.draw_polyline(PackedVector2Array([Vector2(side*17,-13),Vector2(side*24,-13),Vector2(side*24,12),Vector2(side*17,12)]),EXPOSE_COLOR,2,true)
		"curse": _glyph(painter,Vector2(0,-19),9,profile,.65,0 if reduced else clock*.7)
		"temper":
			painter.draw_line(Vector2(20,-24),Vector2(29,16),TEMPER_COLOR,3,true)
			_glyph(painter,Vector2(24,-10),5,profile,.6)
		"rally":
			for side in [-1,1]: painter.draw_polyline(PackedVector2Array([Vector2(side*27,12),Vector2(side*27,-7),Vector2(side*23,-2)]),color,2,true)
		"echo":
			for i in int(state.value): _glyph(painter,Vector2((i-.5)*17,-29),6,profile,.6)
		"ammo","mark","relay","refund": _glyph(painter,Vector2(27,-22),7,profile,.55)
	var remaining:=float(state.get("remaining",0))
	if remaining>0 and float(state.get("initial",0))>0:
		painter.draw_arc(Vector2.ZERO,31,-PI*.5,-PI*.5+TAU*clampf(remaining/float(state.initial),0,1),24,Color(color,.24),1.2,true)

func _draw_benefit(painter: Node2D, entry: Dictionary, battle: RefCounted, origin: Vector2, scale: float, font: Font, age: float, alpha: float, row: int) -> void:
	var recipient:=str(entry.get("recipient",battle.current().id))
	var point: Vector2=battle.position+Vector2(0,-64)
	painter.draw_set_transform(origin+point*scale,0,Vector2.ONE*scale)
	var color:=Color(entry.profile._palette_color,alpha)
	if recipient==str(battle.current().id):
		painter.draw_line(Vector2(-7,0),Vector2(7,0),color,2,true);painter.draw_line(Vector2(0,-7),Vector2(0,7),color,2,true)
	if font==null: return
	var label: String=entry.get("_benefit_label","")
	if label.is_empty(): return
	painter.draw_set_transform(Vector2.ZERO)
	painter.draw_string_outline(font,Vector2(24,128+row*21),label,HORIZONTAL_ALIGNMENT_LEFT,-1,13,3,Color(.06,.10,.08,alpha))
	painter.draw_string(font,Vector2(24,128+row*21),label,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(color,alpha))

func _benefit_label(entry: Dictionary) -> String:
	var parts: Array[String]=[]
	for pair in [["hp_delta","HP"],["mp_delta","MP"],["shield_delta","盾"]]:
		var value:=float(entry.get(pair[0],0))
		if value>0: parts.append("+%s%s" % [String.num(value,1).trim_suffix(".0"),pair[1]])
	if parts.is_empty(): return ""
	var source:=str(entry.get("source",""))
	var recipient:=str(entry.get("recipient",""))
	return str(C.definition(source).get("name",source))+" → "+str(C.definition(recipient).get("name",recipient))+" "+" ".join(parts)

# Conservative painter-local viewport mapping, including parent Control transforms.
# Margins cover the body-height lift, rims, chips, and source glyphs. Large areas
# are tested by their whole footprint, never only by their center.
static func world_view(painter: Node2D, origin: Vector2, scale: float) -> Rect2:
	if scale<=.00001: return Rect2()
	var local: Rect2=painter.get_global_transform_with_canvas().affine_inverse()*painter.get_viewport_rect()
	return Rect2((local.position-origin)/scale,local.size/scale).grow(96.0/scale)

static func effect_visible(entry: Dictionary, visible: Rect2) -> bool:
	if not visible.has_area(): return true
	if str(entry.get("phase","")) in ["benefit","transfer"]: return true # Receiver text is screen-space UI.
	var point: Vector2=entry.get("origin",entry.get("position",Vector2.ZERO))
	var radius: float=maxf(0,maxf(float(entry.get("footprint_radius",0)),float(entry.get("radius",0))))*1.5+160
	var bounds:=Rect2(point-Vector2.ONE*radius,Vector2.ONE*radius*2)
	if entry.has("position_after"): bounds=bounds.expand(Vector2(entry.position_after)).grow(32)
	return visible.intersects(bounds,true)
