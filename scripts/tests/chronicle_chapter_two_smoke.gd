extends SceneTree
## Both forks are played with production damage, resources, AI and saved campaign state.
const CAMPAIGN := preload("res://scripts/campaign/campaign_service.gd")
const BATTLE := preload("res://scripts/battle/battle_session.gd")
const VIEW := preload("res://scripts/ui/chronicle/battle_view.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const DIRECTOR := preload("res://scripts/battle/stage_director.gd")
const ENEMIES := preload("res://scripts/battle/enemy_system.gd")
const TARGET := preload("res://scripts/battle/targeting.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
const SHELL := preload("res://scripts/ui/chronicle/chronicle_shell.gd")
var checks := 0
var failures := 0
var capture_dir := ""
var viewport: SubViewport
var reports: Array = []

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated test saves")
	if failures: quit(1); return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	encounter_contracts()
	new_character_contracts()
	for branch in ["B04", "B05"]:
		await campaign_path(branch)
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
		var file := FileAccess.open(capture_dir.path_join("runs.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(reports, "  "))
	viewport.queue_free()
	await process_frame
	print("CHRONICLE_CHAPTER_TWO_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func encounter_contracts() -> void:
	for id in ["B04", "B05", "B03", "B06"]:
		var stage := C.stage(id)
		var director := DIRECTOR.new(stage, stage.seed)
		director.kills = stage.boss_kills
		var early := director.tick(.01,0,SPACE.CENTER)
		expect(early.size() == 1 and early[0].kind == "boss", id + " kill threshold spawns boss immediately")
		expect(director.tick(20,1,SPACE.CENTER).is_empty(), id + " boss stops ordinary waves")
		director = DIRECTOR.new(stage, stage.seed)
		var timed := director.tick(stage.boss_time,0,SPACE.CENTER)
		expect(timed.size() == 1 and timed[0].kind == "boss", id + " time threshold works without kills")
		director = DIRECTOR.new(stage, stage.seed)
		director.elapsed = 40
		director.spawn_remaining = 0
		expect(director.tick(.01,stage.enemy_cap-1,SPACE.CENTER).size() == 1, id + " grouped waves respect enemy cap")
	var director := DIRECTOR.new(C.stage("B03"),1703)
	var boss := director.spawn("boss",SPACE.CENTER)
	boss.attack = "nova"
	boss.windup = .05
	var dodge := ENEMIES.step([boss],SPACE.CENTER+Vector2(200,0),.1)
	expect(dodge.hits.is_empty(), "leaving the telegraphed blast avoids damage")
	boss.windup = .05
	var hit := ENEMIES.step([boss],SPACE.CENTER+Vector2(50,0),.1)
	expect(hit.hits.size() == 1 and hit.effects[0].radius == boss.blast_radius, "blast damage and shown radius share the same source")
	var charger := director.spawn("charger",SPACE.CENTER)
	charger.cooldown = 0
	var start := ENEMIES.step([charger],SPACE.CENTER+Vector2(200,0),.01)
	expect(charger.attack == "charge" and charger.windup > 0 and start.hits.is_empty(), "charger warns before striking")
	for id in ["F03","F07","N14","N18"]:
		expect(not C.definition(id).is_empty() and C.definition(id).support != null, id + " has real foreground and background capabilities")
	var bonus := C.owned_bonuses({"F03":C.record("F03",3),"N18":C.record("N18",3)})
	expect(is_equal_approx(bonus.armor,.36) and is_equal_approx(bonus.supply_mp,.09), "owned bonuses remain numeric, not free healing or shielding")

func new_character_contracts() -> void:
	for id in ["F03","F07","N14","N18"]:
		var stage := C.stage("B03")
		stage.boss_time = 1000
		stage.boss_kills = 1000
		var request := {"attempt_id":"capability", "members":["JIA",id], "characters":{"JIA":C.record("JIA",5),id:C.record(id,5)}, "equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":"ember_seal"},"stage":stage,"seed":1}
		var b := BATTLE.new(request)
		b.director.spawn_remaining = 1000
		b.characters.JIA.hp -= 60
		b.characters.JIA.mp = 0
		var enemy: RefCounted = b.director.spawn("guard",b.position+Vector2(100,0))
		enemy.hp = 10000
		enemy.cooldown = 1000
		b.enemies.append(enemy)
		var hp: float = b.characters.JIA.hp
		var mana: float = b.characters[id].mp
		for i in 30: b.tick(1.0/60.0,Vector2.ZERO)
		expect(b.characters[id].cooldowns.has(C.definition(id).support.id) and b.characters[id].mp == mana, id+" support works without spending mana")
		if id == "F03": expect(b.characters.JIA.hp > hp, "configured physician heals the current actor")
		elif id == "N18": expect(b.characters.JIA.mp >= 8, "configured clerk restores current actor mana")
		else: expect(enemy.slow_time > 0, id+" configured support slows enemies")
		request.members = ["JIA"]
		var reserve := BATTLE.new(request)
		reserve.director.spawn_remaining = 1000
		reserve.characters.JIA.hp -= 60
		var injured: float = reserve.characters.JIA.hp
		reserve.tick(.5,Vector2.ZERO)
		expect(reserve.characters.size() == 1 and reserve.characters.JIA.hp == injured, id+" unassigned card grants only its numeric owned bonus")

func claim(state: RefCounted) -> void:
	var preferred := ["F03","F07","N14","N18","N16","F11","N13","N17","N01","N04","N07"]
	for id in preferred:
		if state.data.pending.selected.size() >= state.data.pending.picks: break
		if id in state.data.pending.candidates: expect(state.select_card(id), "select " + id)
	expect(state.claim_reward(), "claim persistent reward")

func team(state: RefCounted) -> void:
	var chosen: Array = []
	for id in ["F11","F03","N16","F07","N13","N17","N18","N07","N01","N04"]:
		if state.data.owned.has(id) and not state.data.owned[id].dead: chosen.append(id)
		if chosen.size() == 2: break
	for i in chosen.size(): expect(state.assign(chosen[i],i), "assign " + chosen[i])
	if "iron_armor" in state.data.inventory: expect(state.equip("iron_armor"), "equip earned armor")

func campaign_path(branch: String) -> void:
	var state := CAMPAIGN.new()
	state.directory = "user://chapter_two/" + branch + "_" + str(Time.get_ticks_usec())
	state.data.reward_seed = 781103
	expect(state.begin_campaign() and state.resolve_event(), "begin real campaign " + branch)
	if not await play(state, branch, 3): return
	expect(state.resolve_event(), "Emma event")
	claim(state)
	team(state)
	if not await play(state, branch, 2): return
	claim(state)
	if branch == "B04": await capture_page(state,"event","market-event")
	expect(state.resolve_event() and state.data.available == ["B04","B05"], "market opens mutually exclusive fork")
	expect("F03" in state.data.pool and "N18" in state.data.pool and not state.data.owned.has("F03"), "market unlocks but does not grant new cards")
	# A previous-version save at the market must retain its choices and gain new pool entries.
	state.data.pool.erase("F03")
	state.data.pool.erase("N18")
	expect(state.save_slot("1") and state.load_slot("1"), "old market save loads")
	expect("F03" in state.data.pool and "N18" in state.data.pool, "completed gates reconcile new content on load")
	if branch == "B04": await capture_page(state,"route","two-routes")
	expect(state.choose_node(branch), "choose fork " + branch)
	var entry: Dictionary = state.data.duplicate(true)
	var abandoned := BATTLE.new(state.start_battle())
	abandoned.grant_experience(60)
	abandoned.choose_field(3)
	state.abandon_battle()
	expect(state.data == entry, "new-stage abandon rolls back growth and field")
	if not await play(state, branch, 3): return
	expect(state.data.pending.candidates.size() == 5 and state.data.pending.picks == 2, "ordinary branch rewards five choose two")
	claim(state)
	expect(state.data.current == "B03" and not state.choose_node("B05" if branch == "B04" else "B04"), "other branch cannot be replayed")
	team(state)
	if not await play(state, branch, 2): return
	if branch == "B04": await capture_page(state,"reward","stronghold-reward")
	claim(state)
	if branch == "B04": await capture_page(state,"event","followers-event")
	expect(state.resolve_event() and "F07" in state.data.pool, "stronghold story unlocks bandit leader")
	expect(state.data.current == "F01", "real route reaches first spring")
	# Injured and fallen reserves are explicit fixtures for the spring contract.
	state.data.owned.F11.hp = 0.0
	state.data.owned.F11.dead = true
	state.data.owned.F11.cooldowns = {"emma_frost":4.0}
	for i in 2:
		if state.data.party[i] == "F11": state.data.party[i] = ""
	state.data.owned.JIA.hp = 10.0
	if branch == "B04": await capture_page(state,"event","spring-event")
	expect(state.resolve_event(), "spring commits full-party recovery")
	expect(not state.data.owned.F11.dead and state.data.owned.JIA.hp == state.resource_max("JIA","hp") and state.data.owned.F11.mp == state.resource_max("F11","mp"), "spring restores living and fallen members")
	expect(state.data.owned.F11.cooldowns.emma_frost == 4.0, "spring does not reset skill cooldown")
	if branch == "B04": await capture_page(state,"route","optional-elite")
	expect(state.save_slot("2"), "save at optional elite fork")
	expect(state.choose_node("S05") and state.resolve_event(), "elite can be bypassed")
	expect("N14" not in state.data.pool and "B06" not in state.data.completed and not state.battle_available("B07"), "bypass loses elite unlock and reaches content boundary")
	expect(state.load_slot("2") and state.choose_node("B06"), "reload optional elite fork")
	team(state)
	if not await play(state, branch, 2): return
	expect("N14" in state.data.pool, "elite victory unlocks curse scholar before reward generation")
	var pending: Dictionary = state.data.pending.duplicate(true)
	expect(state.save_slot("3") and state.load_slot("3") and state.data.pending == pending, "new-stage reward survives reload without reroll")
	claim(state)
	expect(state.resolve_event() and state.data.current == "B07", "camp event reaches the next chapter segment")
	expect(state.start_battle().is_empty() and not state.in_battle, "unimplemented segment remains blocked")
	expect(state.valid(state.data), "full new-segment campaign remains save-valid")
	if branch == "B04": await capture_page(state,"route","next-segment")

func play(state: RefCounted, branch: String, field: int) -> bool:
	var id: String = state.data.current
	var request: Dictionary = state.start_battle()
	expect(not request.is_empty(), "start " + id)
	if request.is_empty(): return false
	var view := VIEW.new()
	view.setup(request,state.characters)
	viewport.add_child(view)
	view.set_physics_process(false)
	var b: RefCounted = view.battle
	var captured_wave := false
	var captured_boss := false
	var captured_blast := false
	var kinds := {}
	for frame in 18000:
		if not b.outcome.is_empty(): break
		var target := TARGET.nearest(b.enemies,b.position,4000)
		var movement := Vector2.ZERO
		if b.director.field == -1: movement = (SPACE.FIELD_POSITIONS[field]-b.position).normalized()
		elif target != null:
			var ranged: bool = C.definition(b.current().id).basic.reach > 300
			var distance: float = b.position.distance_to(target.position)
			if distance > (280 if ranged else 75): movement = (target.position-b.position).normalized()
			elif ranged and distance < 200: movement = (b.position-target.position).normalized()
		elif not b.gems.is_empty(): movement = (b.gems[0].position-b.position).normalized()
		for enemy in b.enemies:
			if enemy.windup <= 0: continue
			if enemy.attack == "nova" and b.position.distance_to(enemy.position) < enemy.blast_radius+60:
				movement = (b.position-enemy.position).normalized()
			elif enemy.attack == "charge" and Geometry2D.get_closest_point_to_segment(b.position, enemy.position, enemy.position+enemy.aim*240).distance_to(b.position) < enemy.radius+36:
				movement = enemy.aim.orthogonal()
		if b.current().hp < b.current().stats.hp * .3:
			var next: int = posmod(b.active+1,b.members.size())
			if not b.characters[b.members[next]].dead and b.characters[b.members[next]].hp > b.characters[b.members[next]].stats.hp * .5: b.request_switch(1)
		if frame % 15 == 0: b.request_skill(0); b.request_skill(1)
		b.tick(1.0/60.0,movement)
		for enemy in b.enemies: kinds[enemy.kind] = true
		if id in ["B01","B02"] or branch == "B05" and id != "B05": continue
		if frame > 2100 and not captured_wave and not b.director.boss_spawned:
			await capture(view, id+"-wave")
			captured_wave = true
		if b.director.boss_spawned and not captured_boss:
			await capture(view,id+"-boss")
			captured_boss = true
		for enemy in b.enemies:
			if enemy.attack == "nova" and enemy.windup > .3 and not captured_blast:
				await capture(view,id+"-blast")
				captured_blast = true
	var summary := {"branch":branch,"stage":id,"outcome":b.outcome,"seconds":snappedf(b.director.elapsed,.1),"kills":b.director.kills,"jia_level":b.characters.JIA.level,"jia_hp":snappedf(b.characters.JIA.hp,.1),"card_elite":b.director.card_elite,"enemy_kinds":kinds.keys()}
	reports.append(summary)
	print("CAMPAIGN_RUN ",JSON.stringify(summary))
	expect(b.outcome == "victory", "real win " + branch + ":" + id)
	var result: Dictionary = b.result.duplicate(true)
	view.queue_free()
	await process_frame
	if b.outcome != "victory": state.abandon_battle(); return false
	expect(state.complete_battle(result), "commit real win " + id)
	if not state.data.pending.is_empty() and result.card_elite:
		expect(state.data.pending.picks == 3, "defeated card elite gives five choose three")
	return true

func capture(view: Control, name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	view.canvas.refresh(true)
	view.refresh()
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	viewport.get_texture().get_image().save_png(capture_dir.path_join(name+".png"))

func capture_page(state: RefCounted, page: String, name: String) -> void:
	var shell := SHELL.new()
	shell.session = state
	shell.page = page
	shell.selected_node = state.data.current
	shell.segment = int(state.nodes[state.data.current].segment)
	viewport.add_child(shell)
	for i in 4: await process_frame
	if page == "route":
		var button := shell.find_child("route_forward",true,false) as Button
		expect(button != null and button.disabled == (state.data.current == "B07"), "route action matches real content availability: "+name)
	elif page == "event": expect(shell.find_child("event_continue",true,false) != null, "event can continue: "+name)
	else: expect(shell.find_child("reward_claim",true,false) != null, "new-stage reward has a claim action")
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(capture_dir)
		viewport.get_texture().get_image().save_png(capture_dir.path_join(name+".png"))
	shell.queue_free()
	await process_frame
