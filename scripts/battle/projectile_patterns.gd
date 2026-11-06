extends RefCounted
## Deterministic authored salvos. Rotation changes the lattice; ring escape lanes stay locked.
const MAX_COUNT := 96
const MAX_BURSTS := 8

static func primary(action: Dictionary) -> Dictionary:
	if action.has("projectile_pattern"): return _inherit(action.projectile_pattern,action)
	if str(action.get("action","")) not in ["shot","fan"]: return {}
	var pattern:=action.duplicate(true)
	pattern.kind="fan"
	if not pattern.has("count"): pattern.count=1 if str(action.get("action",""))=="shot" else 5
	return pattern

static func secondary(action: Dictionary) -> Dictionary:
	return _inherit(action.get("secondary_pattern",{}),action) if not action.get("secondary_pattern",{}).is_empty() else {}

static func launch(pattern: Dictionary, context: Dictionary, pending: Array, actor: Vector2, result: Dictionary) -> void:
	if pattern.is_empty(): return
	var count:=clampi(int(pattern.get("burst_count",1)),1,MAX_BURSTS)
	var interval:=maxf(.12,float(pattern.get("burst_interval",.22)))
	for burst in count:
		var entry: Dictionary=context.duplicate(true)
		entry.pattern=pattern.duplicate(true);entry.burst=burst;entry.until=burst*interval
		if burst==0: emit(entry,actor,result)
		else: pending.append(entry)

static func advance(pending: Array, enemies: Array, actor: Vector2, delta: float, result: Dictionary) -> void:
	var owners: Dictionary={}
	for enemy in enemies: owners[enemy.id]=enemy
	for index in range(pending.size()-1,-1,-1):
		var entry: Dictionary=pending[index]
		var owner: RefCounted=owners.get(int(entry.source_id))
		if owner==null or owner.dead or owner.form_index!=int(entry.form_index) or owner.transition_remaining>0:
			pending.remove_at(index);continue
		entry.until-=delta
		if entry.until<=0: emit(entry,actor,result);pending.remove_at(index)

static func emit(entry: Dictionary, actor: Vector2, result: Dictionary) -> void:
	var pattern: Dictionary=entry.pattern
	var kind:=str(pattern.get("kind","fan"))
	var count:=clampi(int(pattern.get("count",5 if kind=="fan" else 28)),1,MAX_COUNT)
	var direction: Vector2=entry.direction
	if bool(pattern.get("aim_each_burst",false)):
		direction=(actor-Vector2(entry.origin)).normalized()
		if direction.is_zero_approx(): direction=Vector2.RIGHT
	var locked_angle: float=Vector2(entry.direction).angle()
	var base:=direction.angle()+float(pattern.get("angle_offset",0.0))+float(pattern.get("angle_step",0.0))*int(entry.burst)
	var gap:=clampf(float(pattern.get("gap_width",1.0)),.35,PI) if kind=="ring" else 0.0
	var gap_angle:=locked_angle+float(pattern.get("gap_angle_offset",0.0))
	var spread:=float(pattern.get("spread",1.15))
	var speed:=maxf(35,float(pattern.get("speed",225)))
	var lifetime:=clampf(float(pattern.get("life",3.2)),.15,8.0)
	for index in count:
		var angle:=base+TAU*index/count if kind=="ring" else base+(float(index)/maxf(1,count-1)-.5)*spread if count>1 else base
		if kind=="ring" and absf(wrapf(angle-gap_angle,-PI,PI))<gap*.5: continue
		if result.projectiles.size()>=int(result.get("projectile_room",1200)): break
		var bullet: Dictionary={"position":entry.origin,"velocity":Vector2.RIGHT.rotated(angle)*speed,"life":lifetime,"hostile":true,
			"move_id":entry.move_id,"damage":entry.damage,"source":entry.source_id,"source_id":entry.source_id,"definition_id":entry.definition_id,
			"form_index":entry.form_index,"action_serial":entry.action_serial,"burst_index":entry.burst,"visual_id":entry.visual_id,
			"new_this_tick":true,"hit_radius":clampf(float(pattern.get("hit_radius",5.0)),.5,16.0),"warning_policy":"none","bullet_style":str(pattern.get("bullet_style","orb"))}
		if pattern.has("bullet_color"): bullet.bullet_color=pattern.bullet_color
		result.projectiles.append(bullet)

static func _inherit(pattern: Dictionary, action: Dictionary) -> Dictionary:
	var result:=pattern.duplicate(true)
	for key in ["hit_radius","bullet_style","bullet_color","speed","life","burst_count","burst_interval","angle_step","angle_offset","aim_each_burst"]:
		if not result.has(key) and action.has(key): result[key]=action[key]
	return result
