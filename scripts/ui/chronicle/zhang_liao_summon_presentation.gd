extends RefCounted
## Only B17's two collaboration presentations. All harm and warning shapes stay in battle.
const BOUNDS := preload("res://scripts/ui/chronicle/battle_sprite_bounds.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
const SETTINGS := preload("res://scripts/shared/settings.gd")
const MANIFEST_PATH := "res://assets/enemies/baimen/zhang_liao_summons/manifest.json"
const ROOT := "res://assets/enemies/baimen/zhang_liao_summons/"
const MAX_ENTRIES := 4
const MAX_SEEN := 256
const MAX_PULSES := 4
const MAX_MARKERS := 5
const BRONZE := Color(.77,.55,.31)
const INK := Color(.33,.64,.66)
var entries: Dictionary = {}
var seen: Dictionary = {}
var hidden_proxies: Dictionary = {}
var clips: Dictionary = {}
var art_loaded := false
var trace_draws := false
var last_drawn_effects: Array[Dictionary] = []
var clock := 0.0
var shared_fx: RefCounted

func _init(fx: RefCounted = null) -> void:
	shared_fx = fx

func warmup() -> void:
	if art_loaded: return
	art_loaded = true
	if not FileAccess.file_exists(MANIFEST_PATH): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary: return
	for key in parsed.get("clips", {}):
		var spec: Dictionary = parsed.clips[key]
		var path := ROOT + str(spec.get("file", ""))
		if not ResourceLoader.exists(path): continue
		var texture := load(path) as Texture2D
		if texture == null: continue
		var clip := spec.duplicate(true)
		clip.id = str(key)
		clip.texture = texture
		var identity := "FX" if str(spec.get("kind","actor")) == "effect" else str(spec.get("visual_id", ""))
		if identity!="FX":
			# Offline alpha-table lookups once at warmup, never GPU pixel scans.
			var dimensions: Array=clip.get("frame_size",[768,640])
			var anchor: Array=clip.get("anchor_px",[384,608])
			var opaque:=Rect2()
			for index in int(clip.get("frames",1)):
				var used:=BOUNDS.used_rect(texture,Rect2i(index*int(dimensions[0]),0,int(dimensions[0]),int(dimensions[1])))
				var relative:=Rect2(Vector2(used.position)-Vector2(float(anchor[0]),float(anchor[1])),Vector2(used.size))
				opaque=opaque.merge(relative) if opaque.has_area() else relative
			opaque=opaque.merge(Rect2(Vector2(-opaque.end.x,opaque.position.y),opaque.size))
			clip.opaque_foot_bounds=opaque
		clips[identity+":"+str(spec.get("role", ""))] = clip

func _key(owner: int, form: int, serial: int) -> String:
	return "%d:%d:%d" % [owner,form,serial]

func _remember(key: String) -> bool:
	if seen.has(key): return false
	seen[key] = true
	while seen.size() > MAX_SEEN: seen.erase(seen.keys()[0])
	return true

func _source(battle: RefCounted, owner: int) -> RefCounted:
	for enemy in battle.enemies:
		if enemy.id == owner: return enemy
	return null

func _remove(key: String) -> void:
	if not entries.has(key): return
	var removed: Dictionary=entries[key]
	for index in range(last_drawn_effects.size()-1,-1,-1):
		var record: Dictionary=last_drawn_effects[index]
		if record.owner_id==removed.owner_id and record.form_index==removed.form_index and record.action_serial==removed.action_serial: last_drawn_effects.remove_at(index)
	var proxy: RefCounted = entries[key].proxy.get_ref() if entries[key].proxy != null else null
	if proxy != null:
		hidden_proxies[proxy.id] = weakref(proxy)
		while hidden_proxies.size() > 32: hidden_proxies.erase(hidden_proxies.keys()[0])
	entries.erase(key)

func clear(reset_hidden: bool = false) -> void:
	for key in entries.keys(): _remove(str(key))
	seen.clear()
	last_drawn_effects.clear()
	clock = 0.0
	if reset_hidden: hidden_proxies.clear()

func consume(events: Array, battle: RefCounted) -> void:
	if not battle.outcome.is_empty(): clear(); return
	clock = battle.director.elapsed
	for event: Dictionary in events:
		var kind := str(event.get("kind", ""))
		var owner := int(event.get("id", 0))
		if kind == "boss_phase":
			var phase := int(event.get("form_index",event.get("phase",0)))
			var source: RefCounted = _source(battle,owner)
			if source != null and source.form_index != phase: continue
			# A repeated phase+tell batch must retain that phase's new action.
			for key in entries.keys():
				if int(entries[key].owner_id)==owner and int(entries[key].form_index)!=phase: _remove(str(key))
			continue
		if kind in ["kill", "enemy_remove"]:
			for key in entries.keys():
				if int(entries[key].owner_id) == owner or int(entries[key].proxy_id) == owner: _remove(str(key))
			continue
		if kind not in ["enemy_tell", "enemy_release", "enemy_hazard_release"]: continue
		var g: Dictionary = event.get("geometry", {})
		if str(g.get("action_id", "")) != "collaboration": continue
		var source: RefCounted = _source(battle,owner)
		if source == null or source.dead or source.definition_id != "B17": continue
		var form := int(event.get("form_index",0))
		var serial := int(event.get("action_serial",0))
		if source.form_index != form or source.action_serial != serial: continue
		var key := _key(owner,form,serial)
		var marker := int(g.get("marker_index",0)) if kind=="enemy_hazard_release" else 0
		if not _remember(key+":"+kind+":"+str(marker)): continue
		if kind == "enemy_tell":
			warmup()
			var role := "gaoshun" if str(g.get("shape","")) == "line" else "chengong"
			var collaborator := "M03_WAR" if role == "gaoshun" else "M04_WAR"
			var proxy: RefCounted
			for child in battle.enemies:
				if child.dead or child.targetable or child.parent_id!=owner or child.definition_id!=collaborator: continue
				if proxy==null or child.age<proxy.age or (is_equal_approx(child.age,proxy.age) and child.id>proxy.id): proxy=child
			if entries.size() >= MAX_ENTRIES: _remove(str(entries.keys()[0]))
			var windup := float(g.get("total",1.4))
			var lifetime := windup + float(source.current_action.get("recovery",1.5))
			var last_marker := clock + windup + .9
			for extra: Dictionary in g.get("extra_markers",[]): last_marker=maxf(last_marker,clock+float(extra.get("total",windup)))
			entries[key] = {"owner_id":owner,"form_index":form,"action_serial":serial,"collaborator":collaborator,"role":role,"source_position":source.position,"stage_point":_chen_stage_point(source,proxy,Vector2(g.direction),battle.position) if role=="chengong" else Vector2.ZERO,"source":weakref(source),"proxy":weakref(proxy) if proxy!=null else null,"proxy_id":proxy.id if proxy!=null else 0,
				"markers":_markers(g),"start":clock,"windup":windup,"lifetime":lifetime,"geometry":g.duplicate(true),"release_time":-1.0,"impact_time":-1.0,"last_impact":-1.0,"last_marker":last_marker,"pulses":[],"phase":"order","source_frame":0,"proxy_frame":0,"proxy_alpha":0.0,"missing_clip":false}
		elif entries.has(key):
			var entry: Dictionary = entries[key]
			if kind == "enemy_release":
				entry.release_time=clock
				if entry.role == "gaoshun": _pulse(entry,g,clock)
			elif kind == "enemy_hazard_release": _pulse(entry,g,clock)

func _markers(geometry: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for descriptor: Dictionary in [geometry]+geometry.get("extra_markers",[]):
		if result.size()>=MAX_MARKERS: break
		result.append({"index":int(descriptor.get("marker_index",0)),"origin":descriptor.get("origin",Vector2.ZERO),"radius":float(descriptor.get("radius",0)),"impact_time":-1.0})
	return result

func _pulse(entry: Dictionary, geometry: Dictionary, at: float) -> void:
	if float(entry.impact_time)<0: entry.impact_time=at
	entry.last_impact=at
	for marker: Dictionary in entry.markers:
		if int(marker.index)==int(geometry.get("marker_index",0)): marker.impact_time=at
	entry.pulses.append({"start":at,"origin":geometry.get("origin",Vector2.ZERO),"radius":float(geometry.get("radius",0)),"marker":int(geometry.get("marker_index",0))})
	while entry.pulses.size()>MAX_PULSES: entry.pulses.pop_front()

func owns_event(event: Dictionary) -> bool:
	var key := _key(int(event.get("id",0)),int(event.get("form_index",0)),int(event.get("action_serial",0)))
	return entries.has(key) and str(event.get("geometry",{}).get("action_id",""))=="collaboration"

func sync(battle: RefCounted) -> void:
	if not battle.outcome.is_empty(): clear(); return
	clock=battle.director.elapsed
	for key in entries.keys():
		var entry: Dictionary=entries[key]
		var source: RefCounted=entry.source.get_ref()
		if source==null or source.dead or source.form_index!=entry.form_index or clock-entry.start>=float(entry.lifetime): _remove(str(key)); continue
		var age: float=maxf(0,clock-entry.start)
		if entry.release_time<0:
			entry.phase="order" if age<entry.windup*.25 else "manifest" if age<entry.windup*.55 else "advance" if entry.role=="gaoshun" else "unfurl"
		elif entry.impact_time<0: entry.phase="array_tell"
		elif clock-entry.last_impact<.14: entry.phase="impact"
		elif age>=entry.lifetime-.28 and (entry.role=="gaoshun" or clock>=entry.last_marker): entry.phase="vanish"
		else: entry.phase="recover"
		for index in range(entry.pulses.size()-1,-1,-1):
			if clock-float(entry.pulses[index].start)>.28: entry.pulses.remove_at(index)

func _clip(visual: String, role: String) -> Dictionary:
	return clips.get(visual+":"+role,{})

func _pose_frame(entry: Dictionary, clip: Dictionary, boss: bool) -> int:
	var frames := maxi(1,int(clip.get("frames",1)))
	var contact := clampi(int(clip.get("contact_frame",3 if boss else 4 if entry.role=="gaoshun" else 7)),0,frames-1)
	var release := clampi(int(clip.get("release_frame",contact if boss or entry.role=="gaoshun" else 5)),0,contact)
	if entry.release_time<0:
		var reveal: float=0.0 if boss else entry.windup*.25
		var fraction: float=clampf((clock-entry.start-reveal)/maxf(.001,entry.windup-reveal),0,1)
		return mini(maxi(0,release-1),int(floor(fraction*release)))
	if not boss and entry.role=="chengong" and entry.impact_time<0:
		var fraction: float=clampf((clock-entry.release_time)/.9,0,1)
		return mini(maxi(release,contact-1),release+int(floor(fraction*maxi(1,contact-release))))
	if not boss and entry.role=="chengong" and entry.last_impact>=0 and clock-entry.last_impact<.14: return contact
	var start: float=entry.release_time if boss or entry.role=="gaoshun" else entry.impact_time
	var end: float=entry.start+entry.lifetime
	return mini(frames-1,contact+int(floor(clampf((clock-start)/maxf(.001,end-start),0,1)*(frames-contact))))

func _chen_stage_point(source: RefCounted, proxy: RefCounted, direction: Vector2, player: Vector2) -> Vector2:
	var clip: Dictionary=_clip(str(proxy.visual_id),"chengong") if proxy!=null else {}
	var ratio: float=(float(proxy.body_height) if proxy!=null else 190.0)/maxf(1,float(clip.get("body_height_px",224)))
	var local: Rect2=clip.get("opaque_foot_bounds",Rect2(-130,-280,260,290))
	var body:=Rect2(local.position*ratio,local.size*ratio)
	var side:=1.0 if direction.x>=0 else -1.0
	if source.position.distance_to(player)<280: side=-side
	var lower: Vector2=-body.position
	var upper: Vector2=SPACE.SIZE-body.end
	var desired: Vector2=(source.position+Vector2(side*200,60)).clamp(lower,upper)
	var alternate: Vector2=(source.position+Vector2(-side*200,60)).clamp(lower,upper)
	var player_body:=Rect2(player+Vector2(-24,-84),Vector2(48,108))
	var desired_body:=Rect2(desired+body.position,body.size)
	var alternate_body:=Rect2(alternate+body.position,body.size)
	if desired_body.intersects(player_body) and not alternate_body.intersects(player_body): return alternate
	if desired_body.intersects(player_body) and alternate_body.intersects(player_body):
		var left: Vector2=Vector2(player_body.position.x-body.end.x-24,desired.y).clamp(lower,upper)
		var right: Vector2=Vector2(player_body.end.x-body.position.x+24,desired.y).clamp(lower,upper)
		var left_clear: bool=not Rect2(left+body.position,body.size).intersects(player_body)
		var right_clear: bool=not Rect2(right+body.position,body.size).intersects(player_body)
		if left_clear and (not right_clear or left.distance_squared_to(source.position)<right.distance_squared_to(source.position)): return left
		if right_clear: return right
	if absf(desired.x-source.position.x)<160 and absf(alternate.x-source.position.x)>absf(desired.x-source.position.x) and not alternate_body.intersects(player_body): return alternate
	return desired

func _proxy_point(entry: Dictionary) -> Vector2:
	var proxy: RefCounted=entry.proxy.get_ref() if entry.proxy!=null else null
	var point: Vector2=proxy.position if proxy!=null else Vector2(entry.geometry.origin)
	if entry.role=="chengong":
		# A stable stage mark separates the scholar/scroll from Zhang Liao in
		# both comfort modes. It never changes the proxy's simulation position.
		return Vector2(entry.stage_point)
	if SETTINGS.comfort_enabled("reduced_motion"): return point
	var rush: float=smoothstep(.55,1.0,clampf((clock-entry.start)/maxf(.001,entry.windup),0,1))
	var destination: Vector2=Vector2(entry.geometry.origin)+Vector2(entry.geometry.direction)*minf(220,float(entry.geometry.get("length",0))*.28)
	return point.lerp(destination,rush)

func present_actor(enemy: RefCounted, node: Node2D, battle: RefCounted) -> bool:
	if hidden_proxies.has(enemy.id): node.visible=false; return true
	if entries.is_empty(): return false
	if enemy.definition_id!="B17" and (enemy.targetable or enemy.parent_id<=0): return false
	for entry: Dictionary in entries.values():
		var boss: bool=enemy.id==int(entry.owner_id)
		if not boss and enemy.id!=int(entry.proxy_id): continue
		var role: String="order_"+str(entry.role) if boss else str(entry.role)
		var clip: Dictionary=_clip(str(enemy.visual_id),role)
		if clip.is_empty() or not node.has_method("present_summon_frame"): entry.missing_clip=true; return false
		var frame := _pose_frame(entry,clip,boss)
		entry["source_frame" if boss else "proxy_frame"]=frame
		var alpha := 1.0
		var offset := Vector2.ZERO
		if not boss:
			var age: float=maxf(0,clock-entry.start)
			var fade_start: float=entry.lifetime-.28 if entry.role=="gaoshun" else maxf(entry.lifetime-.28,entry.last_marker-entry.start)
			alpha=clampf((age-entry.windup*.25)/.18,0,1)*clampf((entry.lifetime-age)/maxf(.05,entry.lifetime-fade_start),0,1)
			offset=(_proxy_point(entry)-enemy.position)/maxf(.01,node.scale.x)
		if not boss: entry.proxy_alpha=alpha
		node.visible=true
		return node.present_summon_frame(clip,frame,Vector2(entry.geometry.direction),alpha,offset,clock)
	return false

func _effect_frame(entry: Dictionary, clip: Dictionary, impact: float) -> int:
	var count:=maxi(1,int(clip.get("frames",8)))
	var contact:=clampi(int(clip.get("contact_frame",4 if entry.role=="gaoshun" else 5)),0,count-1)
	var release:=clampi(int(clip.get("release_frame",4)),0,contact)
	if entry.release_time<0:
		var reveal: float=entry.windup*.25
		var progress: float=clampf((clock-entry.start-reveal)/maxf(.001,entry.windup-reveal),0,1)
		return mini(maxi(0,release-1),int(floor(progress*release)))
	if entry.role=="chengong" and impact<0: return mini(contact-1,release)
	var start: float=entry.release_time if entry.role=="gaoshun" else impact
	var duration: float=entry.start+entry.lifetime-start
	if entry.role=="chengong": duration=minf(.28,duration)
	return mini(count-1,contact+int(floor(clampf((clock-start)/maxf(.001,duration),0,.9999)*(count-contact))))

func _draw_effect(painter: Node2D, role: String, point: Vector2, frame: int, alpha: float, entry: Dictionary, marker: int) -> bool:
	var clip: Dictionary=clips.get("FX:"+role,{})
	if clip.is_empty(): return false
	if alpha<=0: return true
	var dimensions: Array=clip.get("frame_size",[512,512])
	var pivot: Array=clip.get("anchor_px",[float(dimensions[0])*.5,float(dimensions[1])*.5])
	var requested: Array=clip.get("world_size",[260,260])
	var size:=Vector2(clampf(float(requested[0]),16,360),clampf(float(requested[1]),16,260))
	var selected:=clampi(frame,0,maxi(1,int(clip.get("frames",1)))-1)
	var source:=Rect2(selected*float(dimensions[0]),0,float(dimensions[0]),float(dimensions[1]))
	var destination:=Rect2(point-Vector2(float(pivot[0])/float(dimensions[0]),float(pivot[1])/float(dimensions[1]))*size,size)
	painter.draw_texture_rect_region(clip.texture,destination,source,Color(1,1,1,alpha))
	if trace_draws:
		last_drawn_effects.append({"owner_id":entry.owner_id,"form_index":entry.form_index,"action_serial":entry.action_serial,"role":role,"marker":marker,"frame":selected,"alpha":alpha,"clock":clock,"position":point,"world_size":size,"texture_id":clip.texture.get_instance_id(),"path":clip.texture.resource_path})
	return true

func draw(painter: Node2D, battle: RefCounted, visible: Rect2) -> void:
	last_drawn_effects.clear()
	if not battle.outcome.is_empty(): return
	var low_flash := SETTINGS.comfort_enabled("reduced_flash")
	for entry: Dictionary in entries.values():
		var g: Dictionary=entry.geometry
		var origin: Vector2=g.origin
		var endpoint: Vector2=origin+Vector2(g.direction)*float(g.get("length",0))
		var footprint:=Rect2(origin,Vector2.ZERO).expand(endpoint).expand(_proxy_point(entry))
		for marker: Dictionary in entry.markers: footprint=footprint.expand(Vector2(marker.origin))
		# Include every admitted marker and the full anchored 260px effect, even
		# when its primary center is outside the viewport.
		footprint=footprint.grow(maxf(320,float(g.get("radius",0))))
		if not footprint.intersects(visible): continue
		var color := BRONZE if entry.role=="gaoshun" else INK
		var opacity: float=.045 if low_flash else .09
		var reveal: float=clampf((clock-entry.start-entry.windup*.25)/.18,0,1)
		var authored := false
		if entry.role=="gaoshun":
			var clip: Dictionary=clips.get("FX:gaoshun_entry",{})
			var fade: float=clampf((entry.start+entry.lifetime-clock)/.28,0,1)
			authored=_draw_effect(painter,"gaoshun_entry",_proxy_point(entry),_effect_frame(entry,clip,entry.release_time),reveal*fade*(.24 if low_flash else .48),entry,0)
		else:
			var clip: Dictionary=clips.get("FX:chengong_seal",{})
			for marker: Dictionary in entry.markers:
				var fade:=1.0
				if marker.impact_time>=0:
					var duration: float=minf(.28,entry.start+entry.lifetime-float(marker.impact_time))
					fade=clampf(1-(clock-float(marker.impact_time))/maxf(.001,duration),0,1)
				authored=_draw_effect(painter,"chengong_seal",Vector2(marker.origin),_effect_frame(entry,clip,float(marker.impact_time)),reveal*fade*(.24 if low_flash else .48),entry,int(marker.index)) or authored
		if entry.release_time<0: painter.draw_arc(origin,32,0,TAU,24,Color(color,opacity),2,true)
		for pulse: Dictionary in entry.pulses:
			var life: float=clampf(1-(clock-float(pulse.start))/.28,0,1)
			if entry.role=="gaoshun":
				var normal: Vector2=Vector2(g.direction).orthogonal()*minf(22,float(g.get("half_width",30))*.35)
				for sign_value in [-1,1]: painter.draw_line(origin+normal*sign_value,endpoint+normal*sign_value,Color(color,opacity*life),5,true)
			else: painter.draw_arc(Vector2(pulse.origin),float(pulse.radius)*.5,0,TAU,32,Color(color,opacity*life),4,true)
			if not authored and shared_fx!=null:
				var image: Texture2D=shared_fx.texture("charge_dust" if entry.role=="gaoshun" else "command_seal",clock-float(pulse.start))
				if image!=null: painter.draw_texture_rect(image,Rect2(Vector2(pulse.origin)-Vector2(48,36),Vector2(96,48)),false,Color(1,1,1,opacity*life))

func presentation_point(enemy: RefCounted) -> Vector2:
	if entries.is_empty(): return enemy.position
	for entry: Dictionary in entries.values():
		if int(entry.proxy_id)==enemy.id: return _proxy_point(entry)
	return enemy.position

func framing_entries() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for key in entries:
		var entry: Dictionary=entries[key]
		if int(entry.proxy_id)>0: result.append({"key":str(key),"owner_id":int(entry.owner_id),"proxy_id":int(entry.proxy_id)})
	return result

func snapshot() -> Dictionary:
	var result: Array[Dictionary]=[]
	for entry: Dictionary in entries.values():
		result.append({"owner_id":entry.owner_id,"form_index":entry.form_index,"action_serial":entry.action_serial,"collaborator":entry.collaborator,"proxy_id":entry.proxy_id,
			"phase":entry.phase,"start":entry.start,"elapsed":maxf(0,clock-entry.start),"total_duration":entry.lifetime,"release_time":entry.release_time,"impact_time":entry.impact_time,"last_impact":entry.last_impact,
			"source_frame":entry.source_frame,"proxy_frame":entry.proxy_frame,"effect_frames":_effect_snapshot(entry),"proxy_alpha":entry.proxy_alpha,"pulse_count":entry.pulses.size(),"missing_clip":entry.missing_clip})
	return {"clock":clock,"active_count":entries.size(),"seen_count":seen.size(),"resource_count":clips.size(),"hidden_count":hidden_proxies.size(),"last_drawn_effects":last_drawn_effects.duplicate(true),"entries":result}

func _effect_snapshot(entry: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var role: String="gaoshun_entry" if entry.role=="gaoshun" else "chengong_seal"
	var clip: Dictionary=clips.get("FX:"+role,{})
	if entry.role=="gaoshun":
		result.append({"role":role,"marker":0,"frame":_effect_frame(entry,clip,entry.release_time),"impact_time":entry.release_time})
	else:
		for marker: Dictionary in entry.markers:
			result.append({"role":role,"marker":marker.index,"frame":_effect_frame(entry,clip,float(marker.impact_time)),"impact_time":marker.impact_time})
	return result
