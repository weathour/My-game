extends SceneTree
const B=preload("res://scripts/battle/battle_session.gd")
const C=preload("res://scripts/content/combat_catalog.gd")
const T=preload("res://scripts/battle/targeting.gd")
func _init(): call_deferred("run")
func run():
 for stage_id in ["B01", "B15", "B18"]:
  var records={}
  for id in ["JIA", "F06", "F11"]: records[id]=C.record(id, 12)
  var stage=C.stage(stage_id)
  var b=B.new({"attempt_id":"parity-"+stage_id,"members":["JIA","F06","F11"],"characters":records,"equipment":{"weapon":"plain_blade","armor":"iron_armor","accessory":"ember_seal"},"stage":stage,"seed":stage.seed})
  var digest=HashingContext.new()
  digest.start(HashingContext.HASH_SHA256)
  var frames=0
  for frame in 12000:
   if not b.outcome.is_empty(): break
   var target=T.nearest(b.enemies,b.position,4000)
   var movement=Vector2.ZERO
   if target!=null:
    if b.position.distance_to(target.position)>75: movement=(target.position-b.position).normalized()
    if target.kind=="boss" and target.windup>0: movement=target.aim.orthogonal()
   elif not b.gems.is_empty(): movement=(b.gems[0].position-b.position).normalized()
   if frame%15==0: b.request_skill(0);b.request_skill(1)
   if frame%240==0: b.request_switch(1)
   b.tick(1.0/60.0,movement)
   var chars={}
   for id in b.members: chars[id]=[b.characters[id].snapshot(),b.characters[id].shield,b.characters[id].hurt_lock,b.characters[id].haste,b.characters[id].stats]
   var enemies=[]
   for e in b.enemies:
    var record={}
    for key in ["id","definition_id","position","hp","max_hp","dead","form_index","phase_damage_bank","transition_remaining","observation_remaining","cooldown","windup","state","active_remaining","action_serial","aim","telegraph","slow","slow_time","flash","attack_index","age","current_action","protection_remaining"]: record[key]=e.get(key)
    enemies.append(record)
   var snapshot=[chars,enemies,b.position,b.facing,b.active,b.switch_cooldown,b.target_id,b.target_hold,b.enemy_slow,b.enemy_slow_remaining,b.cast_serial,b.delivery_serial,b.gems,b.projectiles,b.hazards,b.telegraphs,b.effects,b.director.elapsed,b.director.kills,b.director.rng.state,b.director.serial,b.director.spawn_remaining,b.director.wave_cursor,b.director.card_elite,b.director.equipment_elite,b.mechanics.states,b.mechanics.curses,b.mechanics.exposures,b.mechanics.refunds,b.mechanics.fields,b.result]
   digest.update(var_to_bytes(snapshot))
   frames+=1
  print("PARITY ",stage_id," frames=",frames," outcome=",b.outcome," digest=",digest.finish().hex_encode())
 quit()
