extends SceneTree
## UI and real collision-descriptor agreement; no gameplay mutation or art-completion shortcut.
const CODEX := preload("res://scripts/ui/chronicle/enemy_codex.gd")
const CATALOG := preload("res://scripts/content/enemy_catalog.gd")
const RUNTIME := preload("res://scripts/battle/enemy_runtime.gd")
const GEOMETRY := preload("res://scripts/battle/enemy_geometry.gd")
const THREATS := preload("res://scripts/ui/chronicle/enemy_threat_view.gd")
const ACTOR := preload("res://scripts/ui/chronicle/enemy_actor.gd")
const MANIFEST := preload("res://scripts/ui/chronicle/enemy_visual_manifest.gd")
const VIEW := preload("res://scripts/ui/chronicle/battle_view.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
const SHELL := preload("res://scenes/chronicle/chronicle_shell.tscn")
var checks := 0
var failures := 0
var viewport: SubViewport
var capture_dir := ""
var final_art := false

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
		if arg == "--final-art": final_art = true
	call_deferred("run")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func frames(count: int = 3) -> void:
	for i in count: await process_frame

func capture(label: String) -> void:
	await frames()
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var image := viewport.get_texture().get_image()
	expect(image.get_size() == viewport.size, "capture dimensions " + label)
	image.save_png(capture_dir.path_join(label + ".png"))

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "test storage isolated")
	if failures: quit(1); return
	var visuals: Array = []
	for id in CODEX.all_ids():
		var value := CATALOG.definition(id)
		if not visuals.has(value.visual_id): visuals.append(value.visual_id)
	var missing := MANIFEST.validate_final(visuals)
	if final_art:
		for error in missing: expect(false, error)
	else: print("FINAL_ENEMY_ART_GATE missing=", missing.size(), " (mechanics-stage placeholders do not pass art acceptance)")
	expect(CODEX.all_ids().size() == 43, "full catalog includes 39 principal identities and derivative records")
	for index in 18:
		var stage := "B%02d" % (index + 1)
		var ids := CODEX.stage_ids(stage)
		expect(ids.has(stage), stage + " preview uses authored boss identity")
		for id in ids: expect(not CATALOG.definition(id).is_empty(), stage + " valid preview " + id)
	check_geometry()
	check_actor_clock()
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var codex := CODEX.new()
	codex.stage_id = "B17"
	codex.theme = T.make_theme()
	viewport.add_child(codex)
	await frames()
	expect(codex.mode_key == "portrait" and codex.portrait.visible and codex.preview == null, "codex opens as an illustrated catalog")
	codex.set_mode("moves")
	for id in CODEX.all_ids():
		codex.show_entry(id)
		await frames(1)
		expect(codex.selected_id == id and is_instance_valid(codex.preview), "catalog body readable " + id)
		expect(codex.portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "standing portrait uncropped " + id)
		var art_bounds := codex._preview_bounds(str(CATALOG.definition(id).visual_id))
		if art_bounds.has_area():
			var frame_rect: Rect2 = codex.preview.transform * art_bounds
			expect(Rect2(Vector2.ZERO, codex.preview.get_parent().size).grow(.2).encloses(frame_rect), "all authored poses fit codex preview " + id)
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]:
		viewport.size = dimensions
		codex.set_mode("portrait")
		codex.show_entry("B18")
		await frames(5)
		expect(codex.size == Vector2(dimensions), "codex full viewport " + str(dimensions))
		expect(codex.portrait.get_global_rect().end.x <= dimensions.x, "portrait fits " + str(dimensions))
		expect(codex.get_global_rect().encloses(codex.roster.get_parent().get_global_rect()), "roster fits " + str(dimensions))
		await capture("codex-%d" % dimensions.x)
	codex.queue_free()
	await frames()
	await check_battle()
	await check_route_entry()
	print("CHRONICLE_ENEMY_PRESENTATION_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func check_actor_clock() -> void:
	# Exercise the actor state machine without generating or accepting placeholder raster art.
	var actor := ACTOR.new()
	actor.setup("E01")
	actor.metadata = {"clips":{}}
	for key in MANIFEST.REQUIRED_CLIPS:
		actor.metadata.clips[key] = {"frames":4, "fps":10, "frame_size":[192,192], "windup_frame":0, "contact_frame":1}
	var enemy: RefCounted = RUNTIME.new(990, "melee", Vector2.ZERO)
	enemy.configure(CATALOG.definition("E01"))
	enemy.state = "tell"
	enemy.action_serial = 1
	enemy.current_action = {"major":false}
	actor.present(enemy, 1.0, false)
	actor.present(enemy, 1.5, false)
	expect(actor.clip_name == "attack" and actor.sprite.frame == 0, "windup holds preparation pose")
	actor.play_release({"action_id":"swipe"}, 1.5)
	expect(actor.sprite.frame == 1, "release starts at actual contact pose")
	enemy.state = "recovery"
	actor.present(enemy, 1.65, false)
	expect(actor.sprite.frame == 2, "release advances with battle clock")
	actor.present(enemy, 2.0, true)
	expect(actor.sprite.frame == 2, "pause freezes actor pose")
	actor.present(enemy, 2.0, false)
	expect(actor.clip_name == "idle", "recovery returns to idle after authored contact frames")
	actor.metadata.clips["slam"] = {"frames":4, "fps":10, "frame_size":[192,192], "windup_frame":0, "contact_frame":2}
	actor.metadata["action_clips"] = {"slam":"slam", "swipe":"attack", "charge":"special"}
	enemy.current_action = {"action":"slam", "major":true}
	enemy.state = "tell"; enemy.action_serial += 1
	actor.present(enemy, 3, false)
	expect(actor.clip_name == "slam", "actual action maps an additional authored clip during tell")
	actor.play_release({"action_id":"slam"}, 3.2)
	expect(actor.clip_name == "slam" and actor.sprite.frame == 2, "release uses same action clip and contact index")
	enemy.current_action = {"action":"swipe", "major":true}
	enemy.action_serial += 1
	actor.present(enemy, 4, false)
	expect(actor.clip_name == "attack", "major flag does not replace actual swipe animation")
	actor.free()

func check_geometry() -> void:
	for shape in ["disc", "marker", "sector", "fan", "line", "ring_gap"]:
		var desc := {"shape":shape, "origin":Vector2(80,90), "direction":Vector2.from_angle(.7), "radius":110.0, "inner_radius":35.0, "spread":1.8, "length":220.0, "half_width":18.0, "gap_angle":.4, "gap_width":1.3}
		var polygon := THREATS.outline(desc)
		var mismatch := 0
		var samples := 0
		for x in range(-50, 350, 13):
			for y in range(-50, 350, 13):
				var point := Vector2(x,y)
				var clearance := INF
				for i in polygon.size(): clearance = minf(clearance, Geometry2D.get_closest_point_to_segment(point, polygon[i], polygon[(i + 1) % polygon.size()]).distance_to(point))
				if clearance < 2.0: continue # polygon approximation only at subpixel boundaries
				samples += 1
				if GEOMETRY.contains(desc, point, 0) != Geometry2D.is_point_in_polygon(point, polygon): mismatch += 1
		expect(samples > 500 and mismatch == 0, shape + " rendered footprint agrees with real collision descriptor")

func check_battle() -> void:
	viewport.size = Vector2i(1280,720)
	var definitions := {}
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")): definitions[person.id] = person
	var records := {"JIA":C.record("JIA")}
	var view := VIEW.new()
	view.setup({"attempt_id":"enemy-ui", "members":["JIA"], "characters":records, "equipment":{"weapon":"plain_blade", "armor":"cloth_armor", "accessory":"ember_seal"}, "stage":C.stage("B18"), "seed":1818, "node":{"id":"B18", "name":"白门楼终战"}},definitions)
	viewport.add_child(view)
	view.set_physics_process(false)
	await frames()
	var battle: RefCounted = view.battle
	battle.enemies.clear()
	for i in 5:
		var id: String = ["E01", "E09", "L05", "B18", "M03_WAR"][i]
		var enemy: RefCounted = battle.director.spawn(id, SPACE.CENTER + Vector2(-360 + i * 180, 120))
		battle.enemies.append(enemy)
	var desc := {"owner_id":4, "action_serial":1, "shape":"ring_gap", "origin":SPACE.CENTER + Vector2(160,100), "direction":Vector2.RIGHT, "radius":150.0, "inner_radius":30.0, "gap_angle":PI, "gap_width":1.3, "phase":"tell", "remaining":.5, "total":1.0}
	battle.telegraphs.append(desc)
	view.canvas.refresh(false)
	for enemy in battle.enemies:
		var visual: Node2D = view.canvas.enemy_views[enemy.id].node
		expect(visual.get_meta("visual_id") == enemy.visual_id, "visual identity " + enemy.definition_id)
		expect(visual.scale.x > 0 and enemy.body_height != enemy.radius * 2, "independent authored body height " + enemy.definition_id)
	var main: RefCounted = battle.enemies[3]
	main.position = battle.position + Vector2(0, 45)
	view.canvas.refresh(false)
	expect(view.canvas.enemy_views[main.id].obscures_player and view.canvas.enemy_views[main.id].node.modulate.a < .5, "overlapping tall body reveals controlled actor with opacity")
	main.position = battle.position + Vector2(180, 120)
	view.canvas.refresh(false)
	expect(not view.canvas.enemy_views[main.id].obscures_player and view.canvas.enemy_views[main.id].node.modulate.a == 1, "nonoverlapping body keeps original opacity")
	var proxy: RefCounted = battle.director.spawn("B10_R", SPACE.CENTER)
	proxy.hp_owner_id = main.id
	proxy.hp_owner = main
	proxy.hp = 1; proxy.max_hp = 1
	battle.enemies.append(proxy)
	main.hp = main.max_hp * .64
	view.refresh()
	expect(is_equal_approx(view.boss_bar.value, main.hp), "shared proxy cannot replace boss owner bar")
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]:
		viewport.size = dimensions
		await frames(5)
		view.canvas.refresh(false)
		await capture("enemy-battle-%d" % dimensions.x)
	var victim: RefCounted = battle.enemies[0]
	view.canvas.consume_events([{"kind":"kill", "id":victim.id}])
	battle.enemies.erase(victim)
	view.canvas.refresh(false)
	expect(view.canvas.death_views.size() == 1, "true kill retains short death presentation")
	battle.set_paused(true)
	await frames(4)
	view.canvas.refresh(false)
	expect(view.canvas.death_views.size() == 1, "pause freezes death presentation battle clock")
	battle.set_paused(false)
	battle.director.elapsed += .31
	view.canvas.refresh(false)
	expect(view.canvas.death_views.is_empty(), "death presentation expires with battle time")
	var removed: RefCounted = battle.enemies[0]
	view.canvas.consume_events([{"kind":"enemy_remove", "id":removed.id, "reason":"source_cancel"}])
	battle.enemies.erase(removed)
	view.canvas.refresh(false)
	expect(view.canvas.death_views.is_empty(), "source cancellation has no death presentation")
	for apparition_id in ["M03_WAR", "M04_WAR"]:
		battle.enemies.clear()
		var leader: RefCounted = battle.director.spawn("B17", SPACE.CENTER + Vector2(200,100))
		leader.current_action = {"action":"collaboration", "shape":"line", "length":180.0, "windup":1.2, "major":true}
		leader.action_serial = 90
		leader.state = "tell"
		leader.telegraph = GEOMETRY.descriptor(leader, leader.current_action, battle.position)
		battle.enemies.append(leader)
		var apparition: RefCounted = battle.director.derivative({"definition_id":apparition_id, "position":leader.position + Vector2(80,-50), "parent_id":leader.id}, battle.enemies)
		battle.enemies.append(apparition)
		view.canvas.refresh(false)
		var actor: Node2D = view.canvas.enemy_views[apparition.id].node
		var wanted := "attack" if apparition_id == "M03_WAR" else "special"
		expect(actor.get("clip_name") == wanted and actor.sprite.frame == 0, apparition_id + " reads actual leader tell for collaboration pose")
		var released: Dictionary = leader.telegraph.duplicate(true)
		released.phase = "active"
		view.canvas.consume_events([{"kind":"enemy_release", "id":leader.id, "action_serial":90, "geometry":released}])
		leader.state = "recovery";leader.telegraph = {}
		battle.director.elapsed += .05
		view.canvas.refresh(false)
		expect(actor.get("clip_name") == wanted and actor.sprite.frame >= 1, apparition_id + " receives real leader release at contact pose")
	battle.enemies.clear()
	battle.telegraphs.clear()
	for index in 5:
		var id: String = ["B08", "B10", "B11", "B05", "B10_R"][index]
		var profile: RefCounted = battle.director.spawn(id, SPACE.CENTER + Vector2(-430 + index * 215, 130 if index % 2 == 0 else 100))
		battle.enemies.append(profile)
		if id == "B10_R":
			profile.hp_owner = battle.enemies[1]
			profile.hp_owner_id = battle.enemies[1].id
	battle.telegraphs.append({"owner_id":battle.enemies[0].id,"action_serial":8,"shape":"line","origin":battle.enemies[0].position,"direction":Vector2.RIGHT,"length":260.0,"half_width":28.0,"phase":"tell","remaining":.6,"total":1.2})
	battle.telegraphs.append({"owner_id":battle.enemies[2].id,"action_serial":9,"shape":"ring_gap","origin":SPACE.CENTER + Vector2(80,60),"direction":Vector2.RIGHT,"radius":150.0,"inner_radius":25.0,"gap_angle":PI,"gap_width":1.4,"phase":"tell","remaining":.4,"total":1.0})
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]:
		viewport.size = dimensions
		await frames(5)
		view.canvas.refresh(false)
		for enemy in battle.enemies:
			expect(is_instance_valid(view.canvas.enemy_views[enemy.id].node), "distinct wide/tall battle body " + enemy.definition_id)
		await capture("boss-profiles-%d" % dimensions.x)
	view.queue_free()
	await frames()

func check_route_entry() -> void:
	var shell: Control = SHELL.instantiate()
	viewport.add_child(shell)
	await frames()
	shell.page = "route"
	shell.selected_node = "B17"
	shell.render()
	await frames()
	var before: Dictionary = shell.session.data.duplicate(true)
	var rng_state: int = shell.session.reward_rng.state
	var entry := shell.find_child("route_enemy_codex", true, false) as Button
	expect(entry != null, "route detail enemy inspection entry exists")
	if entry != null: entry.pressed.emit()
	await frames()
	var codex := shell.get_node_or_null("EnemyCodex")
	expect(codex != null, "route opens actual codex")
	if codex != null:
		codex.show_entry("B18")
		codex.closed.emit()
	await frames()
	expect(shell.session.data == before and shell.session.reward_rng.state == rng_state, "inspection leaves campaign and reward RNG unchanged")
	shell.queue_free()
	await frames()
