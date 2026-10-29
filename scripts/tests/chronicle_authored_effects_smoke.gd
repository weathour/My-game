extends SceneTree
## Real BattleSession gates + Godot-rendered evidence. The renderer cannot mutate combat.
const VIEW := preload("res://scripts/ui/chronicle/battle_view.gd")
const BATTLE := preload("res://scripts/battle/battle_session.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const FX := preload("res://scripts/ui/chronicle/authored_battle_effects.gd")
var viewport: SubViewport
var view: Control
var failures := 0
var checks := 0
var capture_dir := ""
var definitions := {}

class AttackSpy:
	extends Node2D
	var calls: Array = []
	func play_attack(direction: Vector2, manual: bool) -> void: calls.append({"direction":direction,"manual":manual})

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func frames(count: int = 3) -> void:
	for i in count: await process_frame

func request(ids: Array) -> Dictionary:
	var records := {}
	for id in ids:
		records[id] = C.record(id)
		records[id].level = 5
	var stage := C.stage("B02")
	stage.boss_time = 10000.0
	stage.boss_kills = 10000
	return {"attempt_id":"authored-vfx-fixture","members":ids,"characters":records,"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":""},"stage":stage,"seed":1702,"node":{"id":"B02","name":"入城旧街"}}

func fixture(ids: Array) -> void:
	if is_instance_valid(view):
		viewport.remove_child(view)
		view.queue_free()
		await frames()
	view = VIEW.new()
	view.setup(request(ids),definitions)
	viewport.add_child(view)
	view.set_physics_process(false)
	await frames()
	view.battle.director.spawn_remaining = 10000

func target(battle: RefCounted, offset := Vector2(180,0)) -> RefCounted:
	var enemy: RefCounted = battle.director.spawn("melee",battle.position + offset)
	enemy.hp = 10000
	enemy.max_hp = 10000
	battle.enemies.append(enemy)
	return enemy

func effects_for(battle: RefCounted, ability: String, impact := false) -> Array:
	return battle.effects.filter(func(effect: Dictionary): return effect.get("ability","") == ability and (effect.kind == "impact") == impact)

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	view.refresh()
	for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		viewport.size = dimensions
		await frames()
		view.canvas.refresh(false)
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(capture_dir)
		viewport.get_texture().get_image().save_png(capture_dir.path_join("%s-%d.png" % [name,dimensions.x]))

func snapshot(battle: RefCounted) -> Dictionary:
	var result := {"characters":{},"enemies":[],"projectiles":[],"time":battle.director.elapsed,"position":battle.position,"outcome":battle.outcome}
	for id in battle.characters:
		var person: RefCounted = battle.characters[id]
		result.characters[id] = {"hp":person.hp,"mp":person.mp,"shield":person.shield,"cooldowns":person.cooldowns.duplicate(),"xp":person.xp}
	for enemy in battle.enemies: result.enemies.append({"hp":enemy.hp,"slow":enemy.slow,"position":enemy.position})
	for projectile in battle.projectiles: result.projectiles.append(projectile.duplicate(true))
	return result

func record_motion(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	viewport.size = Vector2i(1280,720)
	var folder := capture_dir.path_join(name + "-frames")
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 20:
		view.canvas.refresh(false)
		view.refresh()
		await frames(2)
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(folder.path_join("%03d.png" % i))
		view.battle.tick(.04,Vector2.ZERO)

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"),"isolated storage")
	if failures: quit(1); return
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")): definitions[person.id] = person
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await fixture(["JIA","F11","F03"])
	var b: RefCounted = view.battle
	b.active = 1
	# Put the other supporters on cooldown so each assertion owns its event.
	b.characters.F03.cooldowns.physician_support = 100
	b.current().level = 1
	b.request_skill(1)
	b.tick(0,Vector2.ZERO)
	expect(b.effects.is_empty(),"locked skill does not emit presentation")
	b.current().level = 5
	b.request_skill(1)
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	expect(b.effects.is_empty() and b.projectiles.is_empty(),"no target does not animate or launch attacks")
	var enemy := target(b)
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	expect(effects_for(b,"F11_basic").size() == 1 and effects_for(b,"emma_ice").size() == 1,"successful basic and unlocked automatic have separate descriptors")
	expect(FX.style(b.projectiles[0].context) == "magic" and FX.style(b.projectiles[1].context) == "ice","ordinary magic and ice retain different launch identities")
	var before := snapshot(b)
	view.canvas.refresh(false)
	view.canvas.authored_effects.sync(b)
	expect(before == snapshot(b),"drawing and repeated refresh cannot modify damage, mana, cooldown or projectile state")
	var transient_count: int = view.canvas.authored_effects.transients.size()
	view.canvas.refresh(false)
	expect(view.canvas.authored_effects.transients.size() == transient_count,"repeated refresh deduplicates the same cast")
	b.current().mp = 0
	b.request_skill(1)
	b.tick(0,Vector2.ZERO)
	expect(effects_for(b,"emma_star").is_empty(),"insufficient mana has no presentation descriptor")
	b.current().mp = b.current().stats.mp
	b.request_skill(1)
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	expect(effects_for(b,"emma_star").size() == 1,"star successful cast is distinct from basic and ice")
	var paid: float = b.current().mp
	b.request_skill(1)
	b.tick(0,Vector2.ZERO)
	expect(effects_for(b,"emma_star").size() == 1 and b.current().mp == paid,"cooldown rejection adds no animation and consumes no mana")
	b.tick(.20,Vector2.ZERO)
	view.canvas.refresh(false)
	b.set_paused(true)
	view.canvas.refresh(false)
	before = snapshot(b)
	var fx_before: Array = view.canvas.authored_effects.transients.duplicate(true)
	var clock: float = view.canvas.authored_effects.clock
	var frame: int = view.canvas.authored_effects.frame_index("wave",clock)
	b.tick(1,Vector2.RIGHT)
	await frames(8)
	view.canvas.refresh(false)
	expect(before == snapshot(b) and clock == view.canvas.authored_effects.clock,"pause freezes battle positions, projectiles and presentation clock")
	expect(fx_before == view.canvas.authored_effects.transients and frame == view.canvas.authored_effects.frame_index("wave",view.canvas.authored_effects.clock),"pause freezes VFX lifetime and frame")
	await capture("emma-magic-ice-star-flight")
	b.set_paused(false)
	b.tick(.1,Vector2.ZERO)
	view.canvas.refresh(false)
	b.tick(.1,Vector2.ZERO)
	view.canvas.refresh(false)
	expect(view.canvas.authored_effects.clock > clock,"resume continues the existing battle-time animation")
	expect(enemy.hp < 10000 and not effects_for(b,"emma_star",true).is_empty(),"actual projectile collision produces star impact at its target")
	if not effects_for(b,"emma_star",true).is_empty():
		expect(effects_for(b,"emma_star",true)[0].origin == enemy.position,"impact anchored to real hit target")
	b.set_paused(true)
	view.canvas.refresh(false)
	await capture("emma-spell-impacts")
	b.set_paused(false)
	b.effects.clear()
	view.canvas.authored_effects.transients.clear()
	b.current().cooldowns.emma_frost = 0
	b.request_skill(0)
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	var frost: Dictionary = effects_for(b,"emma_frost")[0]
	expect(frost.radius == 190 and FX.style(frost) == "frost","frost ring uses actual 190-unit radius")
	b.set_paused(true)
	view.canvas.refresh(false)
	await capture("emma-frost-radius")
	b.set_paused(false)
	# An already launched spell retains F11 even after switching the controlled body.
	b.current().cooldowns.F11_basic = 0
	b.tick(0,Vector2.ZERO)
	b.request_switch(1)
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	expect(b.current().id == "F03" and b.projectiles.any(func(p: Dictionary): return not p.hostile and p.context.source == "F11"),"switch preserves projectile launch source")
	var spy := AttackSpy.new()
	var real_actor: Node2D = view.canvas.actor_visual
	view.canvas.actor_visual = spy
	var support_before := effects_for(b,"emma_support").size()
	b.characters.F11.cooldowns.emma_support = 0
	b.current().cooldowns.F03_basic = 100
	b.tick(0,Vector2.ZERO)
	view.canvas._present_casts()
	expect(spy.calls.is_empty() and effects_for(b,"emma_support").size() == support_before + 1,"background support launches magic without a foreground attack")
	b.characters.F03.cooldowns.clear()
	b.request_skill(0)
	b.tick(0,Vector2.ZERO)
	view.canvas._present_casts()
	expect(spy.calls.size() == 1 and spy.calls[0].manual,"manual skill wins same-tick foreground animation")
	view.canvas.actor_visual = real_actor
	spy.free()
	b.effects.clear()
	view.canvas.authored_effects.transients.clear()
	b.current().cooldowns.physician_heal = 0
	b.current().hp = 20
	b.current().mp = b.current().stats.mp
	var hp_before: float = b.current().hp
	b.request_skill(0)
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	var heal: Dictionary = effects_for(b,"physician_heal").back()
	expect(b.current().hp == minf(b.current().stats.hp,hp_before + 48 + 5 * 1.5),"party treatment heals the injured current actor by its approved amount")
	expect(heal.beneficiaries == ["JIA", "F11", "F03"] and heal.origin == b.position and FX.style(heal) == "heal", "party heal identifies every actual living recipient and their shared position")
	b.request_skill(1)
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	expect(b.current().shield == 55 and effects_for(b,"physician_ward").back().beneficiaries == ["JIA", "F11", "F03"], "party ward adds the approved shield to the current actor and records every living beneficiary")
	for id in b.members:
		expect(b.characters[id].shield > 0 and b.characters[id].shield <= b.characters[id].stats.hp * .35, "party ward respects personal shield caps " + id)
	b.set_paused(true)
	view.canvas.refresh(false)
	await capture("physician-heal-ward")
	b.set_paused(false)
	b.switch_cooldown = 0
	b.request_switch(1)
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	b.effects.clear()
	view.canvas.authored_effects.transients.clear()
	b.characters.JIA.hp = 20
	b.characters.F03.cooldowns.physician_support = 0
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	expect(effects_for(b,"physician_support").back().beneficiary == "JIA" and b.characters.JIA.hp > 20,"support treatment marks current recipient rather than absent physician")
	b.set_paused(true)
	view.canvas.refresh(false)
	await capture("physician-background-aid")
	b.set_paused(false)
	b.switch_cooldown = 0
	b.request_switch(1)
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	var count: int = view.canvas.authored_effects.transients.size()
	view.canvas.refresh(false)
	expect(view.canvas.authored_effects.transients.size() == count,"switching back does not replay cached effects")
	b._finish("failed")
	view.canvas.refresh(false)
	expect(b.effects.is_empty() and b.projectiles.is_empty() and view.canvas.authored_effects.transients.is_empty(),"battle outcome clears descriptors, projectiles and presentation tails")
	await fixture(["JIA","F07"])
	b = view.battle
	b.active = 1
	target(b,Vector2(-100,0))
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	expect(effects_for(b,"F07_basic")[0].direction.x < -.99,"bandit slash follows actual left target")
	b.set_paused(true)
	view.canvas.refresh(false)
	await capture("bandit-left-slash")
	b.set_paused(false)
	b.effects.clear()
	view.canvas.authored_effects.transients.clear()
	b.request_skill(0)
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	expect(effects_for(b,"bandit_sweep")[0].radius == 165,"bandit sweep preserves actual circle range")
	b.set_paused(true)
	view.canvas.refresh(false)
	await capture("bandit-ring-sweep")
	b.set_paused(false)
	b.effects.clear()
	view.canvas.authored_effects.transients.clear()
	b.request_skill(1)
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	expect(effects_for(b,"bandit_thrust")[0].radius == 230 and effects_for(b,"bandit_thrust")[0].narrow,"bandit thrust preserves long narrow reach")
	b.set_paused(true)
	view.canvas.refresh(false)
	await capture("bandit-long-thrust")
	b.set_paused(false)
	b.switch_cooldown = 0
	b.request_switch(1)
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	var support_slash: Dictionary = effects_for(b,"bandit_support").back()
	expect(not support_slash.direct and support_slash.radius == 150 and FX.style(support_slash) == "sword","bandit background support keeps its own sword arc and real reach")
	# Independently compare every simulation tick with and without renderer sync.
	var reference: RefCounted = BATTLE.new(request(["JIA","F11","F03"]))
	var presented: RefCounted = BATTLE.new(request(["JIA","F11","F03"]))
	var renderer := FX.new()
	for simulation in [reference,presented]:
		simulation.director.spawn_remaining = 10000
		target(simulation)
		simulation.active = 1
	var same := true
	for i in 90:
		if i == 5:
			for simulation in [reference,presented]: simulation.request_skill(0)
		if i == 20:
			for simulation in [reference,presented]: simulation.request_switch(1)
		reference.tick(1.0/30,Vector2.ZERO)
		presented.tick(1.0/30,Vector2.ZERO)
		renderer.sync(presented)
		same = same and snapshot(reference) == snapshot(presented)
	expect(same,"90-tick damage, resource, cooldown and targeting parity with renderer enabled")
	expect(renderer.clips.wave.textures.size() == 6 and renderer.clips.fan.textures.size() == 8,"legacy authored frames extracted without legacy scene instances")
	expect(renderer.clips.wave.bounds.size.x < 250 and renderer.clips.field.bounds.size.y < 300,"transparent gutters removed before sizing")
	expect(FX.style({"source":"JIA"}).is_empty() and FX.style({"source":"N07"}).is_empty(),"Jia and other unadapted characters retain their dedicated/fallback effects")
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		await fixture(["JIA","F11"])
		view.battle.active = 1
		target(view.battle,Vector2(230,0))
		view.battle.request_skill(0)
		view.battle.request_skill(1)
		view.battle.tick(0,Vector2.ZERO)
		await record_motion("emma-spells")
		await fixture(["JIA","F07"])
		view.battle.active = 1
		target(view.battle,Vector2(-110,0))
		view.battle.request_skill(0)
		view.battle.request_skill(1)
		view.battle.tick(0,Vector2.ZERO)
		await record_motion("bandit-strikes")
	view.queue_free()
	viewport.queue_free()
	await frames()
	print("CHRONICLE_AUTHORED_EFFECTS_SMOKE ","PASS" if failures == 0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
