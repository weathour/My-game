extends SceneTree
## Confirmed damage + real renderer + cosmetic-budget and deterministic-state checks.
const VIEW := preload("res://scripts/ui/chronicle/battle_view.gd")
const BATTLE := preload("res://scripts/battle/battle_session.gd")
const FEEDBACK := preload("res://scripts/ui/chronicle/combat_feedback.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const ABILITY := preload("res://scripts/battle/ability_definition.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")
var checks := 0
var failures := 0
var capture_dir := ""
var measurements: Array = []
var definitions := {}
var viewport: SubViewport
var view: Control

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
	call_deferred("run")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func request(stage: String) -> Dictionary:
	var records := {"JIA":C.record("JIA", 10), "F11":C.record("F11",10), "F07":C.record("F07",10)}
	return {"attempt_id":"feedback-"+stage,"members":["JIA","F11","F07"],"characters":records,"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":"ember_seal"},"stage":C.stage(stage),"seed":30418,"node":{"id":stage,"name":stage}}

func context(b: RefCounted, amount: float, cast: int = 41) -> Dictionary:
	return b.delivery_context({"source":"JIA","ability":"feedback_probe","mechanic":"","cast":cast,"damage":amount,"enchant":"","direct":true,"secondary":false,"damage_type":0,"slow":0.0,"duration":0.0,"impact_origin":b.position,"impact_direction":Vector2.RIGHT})

func capture(label: String) -> void:
	await process_frame
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var image := viewport.get_texture().get_image()
	expect(image.get_size() == viewport.size, "actual viewport size " + label)
	image.save_png(capture_dir.path_join(label + ".png"))

func mount(stage: String) -> void:
	if is_instance_valid(view):
		view.free()
	view = VIEW.new()
	view.setup(request(stage), definitions)
	viewport.add_child(view)
	view.set_physics_process(false)
	await process_frame
	view.battle.enemies.clear()
	view.battle.director.spawn_remaining = 10000
	view.battle.director.config.boss_time = 10000
	view.battle.director.config.boss_kills = 10000
	view.canvas.refresh(false)

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated settings")
	if failures: quit(1); return
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")): definitions[person.id] = person
	var old_volume := SETTINGS.load_sfx_volume()
	var old_motion := SETTINGS.comfort_enabled("reduced_motion")
	var old_flash := SETTINGS.comfort_enabled("reduced_flash")
	SETTINGS.save_sfx_volume(.65)
	SETTINGS.save_comfort("reduced_motion", false)
	SETTINGS.save_comfort("reduced_flash", false)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await mount("B01")
	var feedback: Node = view.canvas.combat_feedback
	expect(feedback.voices.size() == 6, "fixed six player-feedback voices")
	var count := 0
	for category in feedback.CATEGORIES:
		expect(feedback.streams[category].size() == feedback.CATEGORIES[category], "loaded clip variants " + category)
		for stream in feedback.streams[category]:
			count += 1
			expect(stream.get_length() > .03 and stream.get_length() <= 1.2, "short real clip " + category)
			expect(stream.format == AudioStreamWAV.FORMAT_16_BITS, "explicit PCM16 import " + category)
	expect(count == 22, "22 persistent real CC0 clips")
	var sample_peak := 0.0
	for variants in feedback.streams.values():
		for stream in variants:
			for i in stream.data.size() / 2: sample_peak = maxf(sample_peak, absf(float(stream.data.decode_s16(i * 2)) / 32768))
	var common_peak_bound: float = sample_peak * feedback.VOICE_GAIN * feedback.MAX_EVENT_GAIN * feedback.MAX_VOICES
	expect(common_peak_bound + .339983 < .95, "six full-volume common voices plus measured B01 bed retain sample headroom")
	measurements.append({"fixture":"B01-bounded-level-check","first_seconds":16,"music_raw_peak":.3399829566478729,"music_raw_rms":.057429010901512846,"default_music_gain":.7,"default_sfx_gain":.65,"voice_gain":feedback.VOICE_GAIN,"max_event_gain":feedback.MAX_EVENT_GAIN,"six_common_peak_bound":common_peak_bound,"full_music_plus_six_common_bound":common_peak_bound + .339983})
	await sparse_and_lethal()
	await crowd()
	await shield_pause_comfort()
	await pickup_and_health_loss()
	await rewards_and_numbers()
	await cast_audio_routing()
	await event_priority_regressions()
	await boss_priority()
	await deterministic_budget()
	SETTINGS.save_sfx_volume(old_volume)
	SETTINGS.save_comfort("reduced_motion", old_motion)
	SETTINGS.save_comfort("reduced_flash", old_flash)
	view.free()
	viewport.free()
	await process_frame
	await create_timer(.12).timeout
	if not capture_dir.is_empty():
		var file := FileAccess.open(capture_dir.path_join("feedback-measurements.json"), FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(measurements, "  "))
	print("CHRONICLE_COMBAT_FEEDBACK_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func spawn(b: RefCounted, point: Vector2, kind: String = "E01") -> RefCounted:
	var enemy: RefCounted = b.director.spawn(kind, point)
	enemy.cooldown = 10000
	enemy.speed = 0
	enemy.hp = 9999
	enemy.max_hp = 9999
	b.enemies.append(enemy)
	return enemy

func sparse_and_lethal() -> void:
	var b: RefCounted = view.battle
	var enemy := spawn(b, b.position + Vector2(80,0))
	view.canvas.refresh(false)
	b._hits.append({"target":enemy,"context":context(b, 13)})
	b._resolve_hits()
	view.canvas.consume_events(b.events)
	view.canvas.refresh(false)
	var f: Node = view.canvas.combat_feedback
	expect(f.marks.size() == 1 and f.numbers.size() == 1, "real damage produces contact and readable number")
	expect(is_equal_approx(f.numbers[0].amount, 13), "number equals settled damage")
	expect(f.number_layout(view.canvas.origin,view.canvas.world_scale,view.canvas.get_theme_font("font"),view.canvas.size)[0].text == "13", "one confirmed target keeps plain number")
	await capture("B01-confirmed-hit")
	f.clear(); b.events.clear()
	var fresh := spawn(b, b.position + Vector2(25,-60))
	fresh.hp = 1
	expect(not view.canvas.enemy_views.has(fresh.id), "lethal target has no previous view")
	b._hits.append({"target":fresh,"context":context(b, 10, 43)})
	b._resolve_hits()
	var lethal_events: Array = b.events.duplicate(true)
	b.tick(.001, Vector2.ZERO)
	lethal_events.append_array(b.events)
	view.canvas.consume_events(lethal_events)
	view.canvas.refresh(false)
	var hit := false; var death := false
	for mark in f.marks:
		hit = hit or mark.kind == "hit"
		death = death or mark.kind == "death"
	expect(hit and death and not view.canvas.enemy_views.has(fresh.id), "first-frame lethal retains contact plus disappearance")
	await capture("B01-first-frame-lethal")

func crowd() -> void:
	await mount("B15")
	var b: RefCounted = view.battle
	var targets: Array = []
	for i in 42:
		var point: Vector2 = b.position + Vector2(cos(i * 2.39996), sin(i * 2.39996)) * (60 + (i % 6) * 20)
		targets.append(spawn(b, point))
	view.canvas.refresh(false)
	for enemy in targets: b._hits.append({"target":enemy,"context":context(b, 5)})
	b._resolve_hits()
	var f: Node = view.canvas.combat_feedback
	view.canvas.consume_events(b.events)
	view.canvas.refresh(false)
	expect(f.counters.damage_events == 42 and is_equal_approx(f.counters.damage_amount, 210), "42 settled damages preserved under presentation budget")
	expect(f.marks.size() == f.CONTACTS_PER_CAST and f.numbers.size() == 1, "crowd retains three nearby contacts and one exact total")
	expect(is_equal_approx(f.numbers[0].amount,210) and f.numbers[0].count == 42, "combined real total is 210, with 42 confirmed contacts")
	expect(f.number_layout(view.canvas.origin,view.canvas.world_scale,view.canvas.get_theme_font("font"),view.canvas.size)[0].text == "合计 210", "multiple targets explicitly label combined real damage")
	expect(f.counters.sounds_started == 1, "same cast crowd starts one impact voice")
	await capture("B15-42-target-cast")
	for round_index in 40:
		var events: Array = []
		for i in 42:
			events.append({"kind":"damage_dealt","position":b.position,"target_id":targets[i].id,"amount":1,"direct":true,"cast_id":100 + round_index * 42 + i,"source":"JIA"})
		f.consume(events, b, view.canvas.camera.bounds)
		f.advance(.004, false, "")
	expect(f.marks.size() <= f.MAX_MARKS and f.numbers.size() <= f.MAX_NUMBERS and f.counters.voices_peak <= f.MAX_VOICES, "1680-event stress obeys all fixed budgets")
	expect(f.counters.sounds_limited > 0, "rate limiter actually rejects excess sound")
	measurements.append({"fixture":"B15-42-targets","seed":30418,"counters":f.counters.duplicate(),"max_marks":f.MAX_MARKS,"max_numbers":f.MAX_NUMBERS,"max_voices":f.MAX_VOICES})

func shield_pause_comfort() -> void:
	await mount("B01")
	var b: RefCounted = view.battle
	var f: Node = view.canvas.combat_feedback
	b.current().shield = 100
	var hp: float = b.current().hp
	b.projectiles.append({"position":b.position,"velocity":Vector2.ZERO,"life":1.0,"hostile":true,"damage":5,"source_id":88,"move_id":"probe"})
	b.tick(.001, Vector2.ZERO)
	view.canvas.consume_events(b.events)
	view.canvas.refresh(false)
	expect(b.current().hp == hp and f.player_guarded, "full absorption chooses shield feedback from confirmed fact")
	expect(view.canvas.actor_visual.modulate == Color("a8dfeb"), "full shield never receives red health-loss tint")
	await capture("B01-full-shield-guard")
	var before: float = f.clock
	f.advance(.2, true, "")
	expect(f.clock == before, "pause freezes cosmetic clock")
	for voice in f.voices:
		if voice.stream != null: expect(voice.stream_paused, "pause suspends actual voice")
	f.advance(0, false, "")
	for voice in f.voices:
		if voice.stream != null: expect(not voice.stream_paused, "resume restores actual voice")
	b.active = 1
	f.consume([], b, view.canvas.camera.bounds)
	expect(f.player_flash == 0 and f.marks.is_empty() and f.numbers.is_empty(), "switch clears prior character flash and transients")
	SETTINGS.save_comfort("reduced_motion", true); SETTINGS.save_comfort("reduced_flash", true)
	f.refresh_settings()
	expect(f.reduced_motion and f.reduced_flash, "both comfort settings applied")
	var enemy := spawn(b,b.position + Vector2(70,-20))
	view.canvas.refresh(false)
	enemy.state = "tell"; enemy.current_action = {"id":"slam"}
	var body: Node2D = view.canvas.enemy_views[enemy.id].node
	expect(body.has_method("confirm_hit"), "formal E01 binds current manifest EnemyActor")
	if body.has_method("confirm_hit"):
		body.confirm_hit(b.director.elapsed, Vector2.RIGHT, true,true)
		body.present(enemy,b.director.elapsed,false)
		expect(body.clip_name != "hit" and body.sprite.modulate == Color.WHITE, "reduced flash hit preserves enemy tell animation")
		for state in ["tell","active"]:
			enemy.state = state
			body.confirm_hit(b.director.elapsed,Vector2.RIGHT,false,false)
			body.present(enemy,b.director.elapsed,false)
			expect(body.clip_name != "hit", "full feedback never replaces enemy " + state + " clip")
		enemy.state = "recovery"
		body.confirm_hit(b.director.elapsed,Vector2.RIGHT,false,false)
		body.present(enemy,b.director.elapsed,false)
		expect(body.clip_name != "hit" and body.sprite.modulate.r > 1, "confirmed idle hit preserves body silhouette with a short neutral flash")
		body.confirm_hit(b.director.elapsed,Vector2.RIGHT,true,true)
		body.present(enemy,b.director.elapsed,false)
		expect(body.clip_name != "hit", "reduced flash omits bright authored hit clip")
		enemy.state = "tell"
		body.confirm_hit(b.director.elapsed,Vector2.RIGHT,true,true)
		body.present(enemy,b.director.elapsed,false)
	view.canvas.refresh(false)
	await capture("B01-comfort-tell")
	SETTINGS.save_sfx_volume(0); f.refresh_settings()
	f.clear(); f._sound("guard",4,1)
	var playing := false
	for voice in f.voices: playing = playing or voice.playing
	expect(not playing,"SFX mute starts no voices")
	f.clear()
	expect(f.marks.is_empty() and f.numbers.is_empty() and f.contacts.is_empty(), "explicit cleanup releases transients")
	SETTINGS.save_sfx_volume(.65); SETTINGS.save_comfort("reduced_motion",false); SETTINGS.save_comfort("reduced_flash",false)

func pickup_and_health_loss() -> void:
	await mount("B01")
	var b: RefCounted = view.battle
	var f: Node = view.canvas.combat_feedback
	var hp: float = b.current().hp
	b.current().shield = 0
	b.projectiles.append({"position":b.position,"velocity":Vector2.ZERO,"life":1.0,"hostile":true,"damage":5,"source_id":88,"move_id":"probe"})
	b.tick(.001,Vector2.ZERO)
	view.canvas.consume_events(b.events); view.canvas.refresh(false)
	expect(b.current().hp < hp and not f.player_guarded and view.canvas.actor_visual.modulate == Color("ffb1a1"), "real health loss chooses damage tint")
	await capture("B01-real-health-loss")
	f.clear()
	b.gems.append({"position":b.position,"amount":1.0})
	b.tick(.001,Vector2.ZERO)
	view.canvas.consume_events(b.events)
	var pickups := 0
	for mark in f.marks:
		if mark.kind == "pickup": pickups += 1
	expect(pickups == 1 and b.gems.is_empty(), "actual collected XP produces one pickup mark")
	view.canvas.refresh(false)
	await capture("B01-xp-pickup")
	f.clear()
	var boss := spawn(b,b.position + Vector2(150,0),"boss")
	boss.dead = true; boss.hp = 0
	b.director.boss_spawned = true
	for i in 20: b.gems.append({"position":b.position + Vector2(1000 + i,0),"amount":1.0})
	b.tick(0,Vector2.ZERO)
	var sweeps := 0
	for event in b.events:
		if event.kind == "xp_pickup" and event.collection == "victory_sweep": sweeps += 1
	view.canvas.consume_events(b.events)
	pickups = 0
	for mark in f.marks:
		if mark.kind == "pickup": pickups += 1
	expect(sweeps == 1 and pickups == 1, "twenty victory XP gems stay one sweep feedback")
	view.canvas.refresh(false)
	await capture("B01-victory-xp-sweep")

func rewards_and_numbers() -> void:
	await mount("B15")
	var b: RefCounted = view.battle
	var f: Node = view.canvas.combat_feedback
	for kind in ["card_elite", "equipment_elite"]:
		var elite := spawn(b, b.position + Vector2(80,-90), kind)
		elite.dead = true
		b.tick(0,Vector2.ZERO)
		view._present_messages(b.events)
		view.canvas.consume_events(b.events)
		expect(view.feedback.text.contains("胜利后") and (b.director.card_elite if kind == "card_elite" else b.director.equipment_elite), "confirmed elite flag shown with victory requirement " + kind)
	view.refresh()
	await capture("B15-elite-provisional")
	b.events.clear()
	b.grant_experience(500)
	view._present_messages(b.events)
	view.canvas.consume_events(b.events)
	for id in b.members: expect(view.feedback.text.contains(definitions[id].name), "multi-member level retains name " + id)
	view.refresh()
	await capture("B15-multiple-levels")
	f.clear()
	var before_sounds: int = f.counters.sounds_started
	var periodic := {"kind":"damage_dealt","position":b.position,"target_id":1,"amount":2.5,"direct":false,"secondary":true,"cast_id":0,"source":"F11"}
	for i in 100: f.consume([periodic],b,view.canvas.camera.bounds)
	expect(f.marks.is_empty() and f.numbers.is_empty() and f.counters.sounds_started == before_sounds, "100 DoT facts produce no sound, flash or numeric flood")
	var remote := periodic.duplicate(); remote.secondary = false; remote.direct = true; remote.cast_id = 99; remote.position = Vector2(-9000,-9000)
	f.consume([remote],b,view.canvas.camera.bounds)
	expect(f.marks.is_empty() and f.numbers.is_empty() and f.counters.offscreen_skipped > 0, "offscreen impact drops cosmetic work")
	f.clear()
	for category in ["cast_blade","hit_light","hit_heavy","guard","death_ghost","magic","pickup","level","elite"]: f._sound(category, 1, 1)
	expect(f.counters.voices_peak == 6 and f.voices.size() == 6, "actual concurrent playback reaches fixed six-voice ceiling")
	f.clear()
	for i in 20:
		var event := remote.duplicate(); event.position = b.position + Vector2((i % 5 - 2) * 35, (i / 5) * 35); event.cast_id = 500 + i; event.amount = 11 + i
		var second: Dictionary = event.duplicate(); second.target_id = 2
		f.consume([event,second],b,view.canvas.camera.bounds)
	expect(f.numbers.size() == f.MAX_NUMBERS, "twenty independent casts retain at most six readable totals")
	for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		viewport.size = dimensions
		await process_frame
		view._layout_hud(); view.canvas.refresh(false)
		var layout: Array = f.number_layout(view.canvas.origin,view.canvas.world_scale,view.canvas.get_theme_font("font"),Vector2(dimensions))
		for number in layout: expect(number.text.begins_with("合计 "), "combined-label width included in layout measurement")
		for i in layout.size():
			for j in i: expect(not layout[i].rect.intersects(layout[j].rect), "number totals do not overlap " + str(dimensions))
		await capture("B15-number-cap-%d" % dimensions.x)
	viewport.size = Vector2i(1280,720)
	f.advance(1,false,"")
	expect(f.marks.is_empty() and f.numbers.is_empty(), "expired feedback arrays prune to zero")

func cast_audio_routing() -> void:
	var projectile_id := ""
	for id in C.IDS:
		var basic: Resource = C.basic(id,{"weapon":"plain_blade"})
		if basic.kind == ABILITY.Kind.PROJECTILE and basic.damage_type == ABILITY.DamageType.PHYSICAL:
			projectile_id = id; break
	expect(not projectile_id.is_empty(), "real catalog has a physical projectile for routing check")
	var cases: Array = [
		{"id":"F03","ability":C.definition("F03").manual[1],"expected":ABILITY.Kind.WARD},
		{"id":"N13","ability":C.definition("N13").manual[1],"expected":ABILITY.Kind.MANA}]
	if not projectile_id.is_empty(): cases.append({"id":projectile_id,"ability":C.basic(projectile_id,{"weapon":"plain_blade"}),"expected":ABILITY.Kind.PROJECTILE})
	for row in cases:
		var spec := request("B01")
		spec.members = ["JIA",row.id,"F11"]
		spec.characters = {"JIA":C.record("JIA",10),row.id:C.record(row.id,10),"F11":C.record("F11",10)}
		var b := BATTLE.new(spec)
		spawn(b,b.position + Vector2(70,0))
		var f := FEEDBACK.new(); root.add_child(f)
		expect(row.ability.kind == row.expected and row.ability.damage_type == ABILITY.DamageType.PHYSICAL, "actual catalog nonmelee physical ability " + str(row.ability.id))
		expect(b._cast(row.ability,b.characters[row.id],true,true), "actual nonmelee cast succeeds " + str(row.ability.id))
		var found := false
		for event in b.events:
			if event.kind == "cast": found = event.ability_kind == row.expected and event.damage_type == ABILITY.DamageType.PHYSICAL
		expect(found,"successful event preserves real ability kind " + str(row.ability.id))
		f.consume(b.events,b,Rect2())
		expect(f.counters.sounds_started == 0,"ward/mana/projectile never plays a blade swish " + str(row.ability.id))
		f.clear(); await process_frame; f.free()
	var b := BATTLE.new(request("B01"))
	spawn(b,b.position + Vector2(70,0))
	var f := FEEDBACK.new(); root.add_child(f)
	var melee: Array = [C.basic("JIA",{"weapon":"plain_blade"}), C.basic("JIA",{"weapon":"long_spear"}), C.definition("JIA").manual[1]]
	for ability in melee:
		b.events.clear(); b.current().cooldowns.clear(); f.clear()
		var before: int = f.counters.sounds_started
		expect(b._cast(ability,b.current(),true,true), "real JIA melee cast succeeds " + ability.title)
		var found := false
		for event in b.events:
			if event.kind == "cast": found = int(event.ability_kind) in [ABILITY.Kind.SWEEP,ABILITY.Kind.THRUST]
		expect(found,"JIA cast event carries sweep/thrust " + ability.title)
		f.consume(b.events,b,Rect2())
		expect(f.counters.sounds_started == before + 1,"JIA physical melee retains swish " + ability.title)
	f.clear(); await process_frame; f.free()

func event_priority_regressions() -> void:
	await mount("B01")
	var b: RefCounted = view.battle
	var enemy := spawn(b,b.position + Vector2(80,0))
	view.canvas.refresh(false)
	var f: Node = view.canvas.combat_feedback
	var direct := {"kind":"damage_dealt","position":enemy.position,"target_id":enemy.id,"amount":10.0,"direct":true,"secondary":false,"mechanic":"curse","cast_id":600,"source":"JIA","damage_type":0,"direction":Vector2.RIGHT}
	f.consume([direct],b,view.canvas.camera.bounds)
	expect(f.marks.size() == 1 and f.numbers.size() == 1 and not f.contacts[enemy.id].periodic, "initial direct curse has full impact feedback")
	var periodic: Dictionary = direct.duplicate(); periodic.direct = false; periodic.secondary = true
	f.clear()
	f.consume([direct,periodic],b,view.canvas.camera.bounds)
	expect(not f.contacts[enemy.id].periodic, "same-frame secondary cannot overwrite confirmed direct contact")
	f.clear()
	f.consume([periodic,direct],b,view.canvas.camera.bounds)
	expect(not f.contacts[enemy.id].periodic, "direct contact wins either same-frame event order")
	f.clear()
	var previous: int = f.counters.damage_events
	f.advance(0,true,"")
	b.paused = false
	f.consume([direct,{"kind":"kill","position":enemy.position,"id":enemy.id}],b,view.canvas.camera.bounds)
	expect(f.counters.damage_events == previous + 1 and f.marks.size() == 2 and not f.paused, "resume-first-tick consumes both contact and kill before advance")
	f.clear()
	var before: int = f.counters.sounds_started
	for i in 20:
		direct.cast_id = 1000 + i
		f.consume([{"kind":"enemy_tell","id":enemy.id},direct],b,view.canvas.camera.bounds)
		f.advance(.1,false,"")
	expect(f.counters.sounds_started > before, "frequent ordinary tells retain an audible impact channel")
	f.clear()
	enemy.current_action = {"major":true}
	f.consume([{"kind":"enemy_tell","id":enemy.id},direct],b,view.canvas.camera.bounds)
	expect(f.suppressed_until > f.clock, "genuine major warning keeps audio priority")

func boss_priority() -> void:
	await mount("B18")
	var b: RefCounted = view.battle
	var boss := spawn(b,b.position + Vector2(180,-120), "boss")
	boss.visual_id = "B18_human"
	view.canvas.refresh(false)
	var f: Node = view.canvas.combat_feedback
	f.consume([],b,view.canvas.camera.bounds)
	SETTINGS.save_sfx_volume(1); f.refresh_settings()
	for category in ["cast_blade","hit_light","hit_heavy","death_ghost","magic","pickup"]: f._sound(category,1,5)
	for voice in f.voices: expect(db_to_linear(voice.volume_db) <= f.VOICE_GAIN + .00001, "maximum settings honor event gain cap")
	view.canvas.consume_events([{"kind":"boss_phase","id":boss.id,"position":boss.position}])
	var playing := false
	for voice in f.voices: playing = playing or voice.playing
	expect(not playing and f.suppressed_until > f.clock, "Boss cue preempts all six ordinary voices")
	expect(view.canvas.boss_feedback.voices.size() == 3, "Boss retains separate bounded three-voice pool")
	view.canvas.boss_feedback.consume([{"kind":"boss_impact","position":boss.position},{"kind":"boss_defeated","position":boss.position}])
	var boss_playing := 0
	for voice in view.canvas.boss_feedback.voices:
		if voice.playing: boss_playing += 1
	if DisplayServer.get_name() != "headless": expect(boss_playing == 3, "actual Boss pool reaches three while common six stay preempted")
	f._sound("guard",4,1.15)
	for voice in f.voices:
		if voice.playing: expect(db_to_linear(voice.volume_db) <= f.VOICE_GAIN + .00001, "priority player guard retains capped maximum gain")
	SETTINGS.save_sfx_volume(.65)
	await capture("B18-boss-priority")
	f.advance(.1,false,"failed")
	expect(f.marks.is_empty() and f.numbers.is_empty(),"failure clears all common feedback")

func deterministic_budget() -> void:
	for stage in ["B01","B15","B18"]:
		var left := BATTLE.new(request(stage))
		var right := BATTLE.new(request(stage))
		var f := FEEDBACK.new()
		root.add_child(f)
		for step in 420:
			var direction := Vector2(cos(step * .019),sin(step * .019))
			left.tick(1.0/30,direction); right.tick(1.0/30,direction)
			f.consume(left.events,left,Rect2(left.position - Vector2(900,600),Vector2(1800,1200)))
			f.advance(1.0/30,left.paused,left.outcome)
			left.events.clear(); right.events.clear()
		expect(left.position == right.position and left.current().hp == right.current().hp and left.cast_serial == right.cast_serial and left.director.rng.state == right.director.rng.state,stage + " feedback leaves seed, damage, casts and simulation time unchanged")
		expect(left.enemies.size() == right.enemies.size() and left.director.elapsed == right.director.elapsed,stage + " same enemies and elapsed")
		for i in left.enemies.size(): expect(left.enemies[i].hp == right.enemies[i].hp,stage + " identical target HP " + str(i))
		measurements.append({"fixture":stage+"-420-ticks","seed":30418,"elapsed":left.director.elapsed,"same_rng":left.director.rng.state == right.director.rng.state,"counters":f.counters.duplicate()})
		f.clear()
		await process_frame
		f.free()
