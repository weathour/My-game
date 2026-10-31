extends SceneTree
const B=preload("res://scripts/battle/battle_session.gd")
const C=preload("res://scripts/content/combat_catalog.gd")
const T=preload("res://scripts/battle/targeting.gd")
const I=preload("res://scripts/battle/battle_input.gd")
func _init(): call_deferred("run")
func fixture(ids=["JIA"]):
 var records={}
 for id in ids: records[id]=C.record(id)
 var stage=C.stage("B01")
 return B.new({"attempt_id":"timing","members":ids,"characters":records,"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":"ember_seal"},"stage":stage,"seed":stage.seed})
func run():
 I.install()
 for echo in [false,true]:
  var event=InputEventKey.new();event.physical_keycode=KEY_J;event.pressed=true;event.echo=echo
  print("INPUT ",JSON.stringify({"echo":echo,"is_action_pressed_default":event.is_action_pressed("battle_skill_one"),"allow_echo":event.is_action_pressed("battle_skill_one",true)}))
 for mode in ["stationary","approach","early_J_then_approach"]: natural(mode)
 input_cases()
 projectile_case()
 quit()
func natural(mode):
 var b=fixture()
 var marks={}
 var trace=[]
 var times=[]
 var peak_count=0
 for frame in 1200:
  if not b.outcome.is_empty(): break
  var target=T.nearest(b.enemies,b.position,4000)
  var movement=Vector2.ZERO
  if mode!="stationary" and target!=null and b.position.distance_to(target.position)>75: movement=(target.position-b.position).normalized()
  if mode=="early_J_then_approach" and frame==0: b.request_skill(0);b.request_skill(1)
  var before=b.director.elapsed
  var projected=b.position+movement.limit_length(1)*b.current().stats.move*(1.0/60.0)
  if target!=null:
   var dir=(target.position-projected).normalized()
   if not T.in_shape(b.enemies,projected,dir,112,false,false).is_empty() and not marks.has("first_shape_gate"):
    marks.first_shape_gate={"time":before+1.0/60.0,"gap":projected.distance_to(target.position),"radius":target.radius,"id":target.id}
   if T.nearest(b.enemies,projected,112)!=null and not marks.has("first_center_gate"):
    marks.first_center_gate={"time":before+1.0/60.0,"gap":projected.distance_to(target.position),"radius":target.radius,"id":target.id}
  var gap=-1.0 if target==null else b.position.distance_to(target.position)
  var start=Time.get_ticks_usec()
  b.tick(1.0/60.0,movement)
  times.append(Time.get_ticks_usec()-start)
  peak_count=maxi(peak_count,b.enemies.size())
  if not marks.has("spawn") and not b.enemies.is_empty():
   marks.spawn={"time":b.director.elapsed,"position":b.enemies[0].position,"gap":b.position.distance_to(b.enemies[0].position),"id":b.enemies[0].id}
  for reach in [580,125,112]:
   var key="within_"+str(reach)
   var near=T.nearest(b.enemies,b.position,reach)
   if near!=null and not marks.has(key): marks[key]={"time":b.director.elapsed,"gap":b.position.distance_to(near.position),"id":near.id}
  for event in b.events:
   if event.kind in ["cast","damage_dealt","message"]:
    if trace.size()<18:
     trace.append({"time":b.director.elapsed,"frame":frame,"kind":event.kind,"ability":event.get("ability",""),"amount":event.get("amount",0),"text":event.get("text",""),"pre_gap":gap,"cast":event.get("cast",0),"basic_cd":b.current().cooldowns.get("JIA_basic",0),"sweep_cd":b.current().cooldowns.get("jia_sweep",0)})
    if event.kind=="damage_dealt" and not marks.has("first_damage"): marks.first_damage={"time":b.director.elapsed,"ability":event.ability,"frame":frame}
 times.sort()
 print("NATURAL ",JSON.stringify({"mode":mode,"initial":C.record("JIA"),"automatic_count":C.definition("JIA").automatic.size(),"marks":marks,"trace":trace,"tick_us":{"frames":times.size(),"p50":times[times.size()/2],"p95":times[int(times.size()*.95)],"max":times[-1],"peak_enemy_count":peak_count},"outcome":b.outcome}))
func dummy(b,gap):
 var e=b.director.spawn("melee",b.position+Vector2(gap,0));e.speed=0;e.cooldown=9999;e.hp=100000;e.max_hp=e.hp;b.enemies.append(e);b.director.spawn_remaining=10000;return e
func input_cases():
 var b=fixture()
 var e=dummy(b,120)
 b.tick(0,Vector2.ZERO)
 print("BOUNDARY ",JSON.stringify({"gap":120,"radius":e.radius,"shape_has_target":T.in_shape(b.enemies,b.position,Vector2.RIGHT,112,false,false).size(),"cast_events":b.events}))
 e.position=b.position+Vector2(112,0)
 b.tick(1.0/60.0,Vector2.ZERO)
 print("BOUNDARY ",JSON.stringify({"gap":112,"cast_damage_events":b.events}))
 b=fixture();e=dummy(b,90)
 b.request_skill(0);b.tick(1.0/60.0,Vector2.ZERO)
 print("MANUAL ",JSON.stringify({"case":"J_ready","events":b.events,"time":b.director.elapsed}))
 b.current().cooldowns.jia_sweep=.03
 b.request_skill(0);b.tick(1.0/60.0,Vector2.ZERO)
 var rejected=b.events.duplicate(true)
 b.tick(1.0/60.0,Vector2.ZERO)
 print("MANUAL ",JSON.stringify({"case":"J_pressed_one_tick_before_ready","rejection":rejected,"next_frame_events":b.events,"cooldown":b.current().cooldowns.jia_sweep}))
func projectile_case():
 var b=fixture(["JIA","F11"])
 b.active=1
 var e=dummy(b,300)
 var launch=-1.0;var contact=-1.0;var path=[]
 for frame in 100:
  b.tick(1.0/60.0,Vector2.ZERO)
  for event in b.events:
   if event.kind=="cast" and event.ability=="F11_basic" and launch<0: launch=b.director.elapsed
   if event.kind=="damage_dealt" and event.ability=="F11_basic" and contact<0: contact=b.director.elapsed
  if path.size()<3 and not b.projectiles.is_empty(): path.append({"time":b.director.elapsed,"position":b.projectiles[0].position})
  if contact>=0: break
 print("PROJECTILE ",JSON.stringify({"gap":300,"radius":e.radius,"speed":420,"launch":launch,"contact":contact,"flight_seconds":contact-launch,"first_positions":path}))
