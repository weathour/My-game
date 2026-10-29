extends SceneTree
## Real Control renderer plus independent geometry/clock contracts, never a balance acceptance.
const VIEW := preload("res://scripts/ui/chronicle/battle_view.gd")
const CAMERA := preload("res://scripts/ui/chronicle/boss_camera.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")
const GEOMETRY := preload("res://scripts/battle/enemy_geometry.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
var checks := 0
var failures := 0
var viewport: SubViewport
var view: Control
var capture_dir := ""
var measurements: Array = []

func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="): capture_dir = argument.trim_prefix("--capture=")
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func frames(count: int = 3) -> void:
	for i in count: await process_frame

func settle(count: int = 120) -> void:
	for i in count:
		view.canvas.advance_presentation(1.0 / 60)
		view.canvas.refresh(false)

func screenshot(label: String) -> void:
	await frames()
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var image := viewport.get_texture().get_image()
	expect(image.get_size() == viewport.size, "capture size " + label)
	image.save_png(capture_dir.path_join(label + ".png"))

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated settings")
	if failures: quit(1); return
	var old_motion := SETTINGS.comfort_enabled("reduced_motion")
	var old_flash := SETTINGS.comfort_enabled("reduced_flash")
	SETTINGS.save_comfort("reduced_motion", false)
	SETTINGS.save_comfort("reduced_flash", false)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var definitions := {}
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")): definitions[person.id] = person
	var records := {"JIA":C.record("JIA"), "F11":C.record("F11"), "F07":C.record("F07")}
	view = VIEW.new()
	view.setup({"attempt_id":"boss-camera", "members":["JIA","F11","F07"], "characters":records, "equipment":{"weapon":"plain_blade", "armor":"cloth_armor", "accessory":"ember_seal"}, "stage":C.stage("B18"), "seed":1818, "node":{"id":"B18", "name":"白门楼终战"}}, definitions)
	viewport.add_child(view)
	view.set_physics_process(false)
	await frames()
	var battle: RefCounted = view.battle
	battle.enemies.clear()
	battle.position = SPACE.CENTER
	var boss: RefCounted = battle.director.spawn("boss", battle.position + Vector2(260,-150))
	battle.enemies.append(boss)
	boss.visual_id = "B18"
	battle.director.boss_spawned = true
	battle.director.config.fields_enabled = false
	view.refresh()
	view.canvas.refresh(false)
	var old_node: Node2D = view.canvas.enemy_views[boss.id].node
	var old_instance := old_node.get_instance_id()
	boss.visual_id = "B18_human"
	view.canvas.refresh(false)
	expect(view.canvas.enemy_views[boss.id].node.get_instance_id() != old_instance, "same enemy id rebinds changed form visual")
	expect(view.canvas.enemy_views[boss.id].node.get_meta("visual_id") == "B18_human", "human visual identity preserved")
	boss.visual_id = "B18"
	view.canvas.refresh(false)
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]:
		viewport.size = dimensions
		await frames(5)
		view._layout_hud()
		boss.position = battle.position + Vector2(0,-300)
		boss.visual_id = "B18_human"
		view.canvas.refresh(false)
		# This is an entry framing fixture, not the preceding war-to-human
		# adapter comparison. Remove that comparison's retired body explicitly.
		view.canvas._clear_transients()
		expect(view.canvas.enemy_views.size() == 1 and view.canvas.death_views.is_empty(), "human entry fixture contains exactly one body")
		var first: Dictionary = view.canvas.camera_state()
		var first_body: Rect2 = view.canvas._body_rect(view.canvas.enemy_views[boss.id].node, boss.position)
		expect(first.safe_screen.grow(1).encloses(Rect2(first.base_origin + first_body.position * first.scale, first_body.size * first.scale)), "new human silhouette fits in its very first frame")
		check_visible_body(battle.position, first, "first-frame controlled body")
		await screenshot("first-human-%d" % dimensions.x)
		boss.position = battle.position + Vector2(260,-150)
		boss.visual_id = "B18"
		view.canvas.refresh(false)
		settle()
		var normal: Dictionary = view.canvas.camera_state()
		expect(normal.zoom >= CAMERA.MIN_ZOOM and normal.zoom <= 1, "readable bounded scale " + str(dimensions))
		check_visible_body(battle.position, normal, "duel controlled body")
		expect(normal.bounds.has_point(boss.position), "boss remains visible in duel")
		var stage_clock: float = battle.director.elapsed
		var cooldowns: Dictionary = battle.current().cooldowns.duplicate()
		# A wide forward sweep covers the actor; the camera must include a real escape,
		# not merely a midpoint between player and boss.
		var g := {"owner_id":boss.id, "action_serial":1, "action_id":"slam", "shape":"line", "origin":battle.position - Vector2(240,0), "direction":Vector2.RIGHT, "length":650.0, "radius":300.0, "half_width":45.0, "remaining":1.1, "total":1.1, "phase":"tell", "damage":30.0}
		battle.telegraphs = [g]
		boss.windup = 1.1
		boss.current_action = {"major":true}
		settle()
		var warning: Dictionary = view.canvas.camera_state()
		expect(warning.mode == "warning" and warning.zoom < normal.zoom, "major attack expands readable view")
		expect(warning.escape_valid and warning.safe_route.size() == 2, "geometry finds reachable escape")
		if warning.escape_valid:
			var escape: Vector2 = warning.safe_route[1]
			expect(not GEOMETRY.contains(g, escape, 18), "framed escape is outside true hit geometry")
			expect(escape.distance_to(battle.position) <= battle.current().stats.move * g.remaining + .1, "escape remains within actual move budget")
			expect(warning.safe_screen.grow(1).has_point(warning.base_origin + escape * warning.scale), "escape lies in HUD-free viewport")
		expect(battle.director.elapsed == stage_clock and battle.current().cooldowns == cooldowns and Engine.time_scale == 1, "presentation changes no simulation clocks or cooldowns")
		measurements.append({"size":str(dimensions), "normal_zoom":normal.zoom, "warning_zoom":warning.zoom, "escape_valid":warning.escape_valid, "safe_screen":str(warning.safe_screen), "requested_bounds":str(warning.requested_bounds), "focus_bounds":str(warning.focus_bounds), "boss_height":boss.body_height})
		await screenshot("warning-%d" % dimensions.x)
		var original_height: float = boss.body_height
		var original_position: Vector2 = boss.position
		boss.body_height = 248
		boss.position = battle.position + Vector2(0, -300)
		var long_line: Dictionary = g.duplicate(true)
		long_line.length = 900.0
		battle.telegraphs = [long_line]
		view.canvas.ART.fit_enemy_instance(view.canvas.enemy_views[boss.id].node, boss, "B18")
		settle()
		var large: Dictionary = view.canvas.camera_state()
		check_visible_body(battle.position, large, "large-attack controlled body")
		expect(large.safe_screen.grow(1).has_point(large.base_origin + boss.position * large.scale), "large boss attack anchor stays in functional viewport")
		expect(large.escape_valid, "900-world-unit attack retains reachable escape")
		var real_body: Rect2 = view.canvas._body_rect(view.canvas.enemy_views[boss.id].node, boss.position)
		expect(large.safe_screen.grow(1).encloses(Rect2(large.base_origin + real_body.position * large.scale, real_body.size * large.scale)), "complete 248-high authored pose stays clear of HUD")
		measurements.append({"large_size":str(dimensions), "zoom":large.zoom, "player_pixels":72 * large.scale, "safe_screen":str(large.safe_screen), "real_body":str(real_body), "focus":str(large.focus_bounds), "requested":str(large.requested_bounds), "origin":str(large.base_origin), "center":str(large.center), "route":str(large.safe_route), "obstacles":str(view.canvas.camera.hud_obstacles)})
		await screenshot("large-warning-%d" % dimensions.x)
		view.canvas.refresh(true)
		var running_body: Rect2 = view.canvas._body_rect(view.canvas.actor_visual, battle.position)
		expect(running_body.size.y * view.canvas.world_scale >= 32.39, "actual running silhouette keeps the 32.4px readability floor")
		view.canvas.refresh(false)
		boss.body_height = original_height
		boss.position = original_position
		view.canvas.ART.fit_enemy_instance(view.canvas.enemy_views[boss.id].node, boss, "B18")
		battle.telegraphs = [g]
		settle()
		view.canvas.consume_events([{"kind":"boss_impact", "enemy_id":boss.id, "position":boss.position, "geometry":g}])
		view.canvas.advance_presentation(.025)
		view.canvas.refresh(false)
		var hit: Dictionary = view.canvas.camera_state()
		expect(hit.trauma > 0 and hit.shake.length() > 0, "key impact gets a short impulse")
		expect(view.canvas.actors.position == view.canvas.origin and view.canvas.actors.scale.x == view.canvas.world_scale, "body and warnings share world transform")
		view.canvas.consume_events([{"kind":"boss_phase", "id":boss.id, "position":boss.position}])
		var actor_sprite: AnimatedSprite2D = view.canvas.actor_visual.get("sprite")
		var actor_frame := actor_sprite.frame
		var actor_progress := actor_sprite.frame_progress
		var boss_frame: int = view.canvas.enemy_views[boss.id].node.get("sprite").frame
		var simulation_time: float = battle.director.elapsed
		var camera_time: float = view.canvas.camera.clock
		var frozen_trauma: float = view.canvas.camera.trauma
		var phase_time: float = view.canvas.boss_feedback.phase_remaining
		var stable_hud: Vector2 = view.hud.position
		var stable_clock: float = view.canvas.boss_feedback.clock
		var stable_camera: Dictionary = view.canvas.camera_state()
		battle.set_paused(true)
		view.canvas.advance_presentation(1)
		view.canvas.refresh(false)
		expect(view.canvas.camera_state() == stable_camera and view.canvas.boss_feedback.clock == stable_clock, "pause freezes complete camera and feedback state")
		expect(view.hud.position == stable_hud, "HUD is independent of impact and pause")
		for paused_size in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]:
			viewport.size = paused_size
			await frames(5)
			view._layout_hud()
			view.canvas.advance_presentation(.5)
			view.canvas.refresh(false)
			var resized: Dictionary = view.canvas.camera_state()
			expect(resized.bounds.size.is_equal_approx(Vector2(paused_size) / resized.scale), "paused resize updates actual viewport projection")
			check_visible_body(battle.position, resized, "paused resized controlled body")
			var body: Rect2 = view.canvas._body_rect(view.canvas.enemy_views[boss.id].node, boss.position)
			expect(resized.safe_screen.grow(1).encloses(Rect2(resized.base_origin + body.position * resized.scale, body.size * resized.scale)), "paused resize keeps boss silhouette readable")
			expect(battle.director.elapsed == simulation_time and battle.current().cooldowns == cooldowns and view.canvas.camera.clock == camera_time and view.canvas.camera.trauma == frozen_trauma and resized.shake == stable_camera.shake, "paused resize advances no simulation or shake time")
			expect(view.canvas.boss_feedback.clock == stable_clock and view.canvas.boss_feedback.phase_remaining == phase_time, "paused resize freezes feedback lifetime")
			expect(actor_sprite.frame == actor_frame and actor_sprite.frame_progress == actor_progress and view.canvas.enemy_views[boss.id].node.get("sprite").frame == boss_frame, "paused resize preserves actor and boss animation frames")
			var unchanged: Dictionary = view.canvas.camera_state()
			view.canvas.advance_presentation(.5)
			view.canvas.refresh(false)
			expect(view.canvas.camera_state() == unchanged, "same-size paused refresh remains exactly frozen after resize")
		var previous_top: float = view.canvas.safe_top
		view.canvas.safe_top += 18
		view.canvas.refresh(false)
		expect(view.canvas.camera.safe_screen.position.y == previous_top + 18 and view.canvas.camera.clock == camera_time and view.canvas.boss_feedback.phase_remaining == phase_time, "HUD-safe-area change reframes pause without ticking time")
		view.canvas.safe_top = previous_top
		var paused_initial: RefCounted = CAMERA.new()
		paused_initial.consume([{"kind":"boss_defeated", "position":boss.position}])
		paused_initial.update(battle, Vector2(1280,720), 2.0, false, 72, 150)
		expect(paused_initial.initialized and paused_initial.clock == 0 and paused_initial.terminal_remaining == .48 and paused_initial.trauma == .68 and paused_initial.shake == Vector2.ZERO, "first paused initialization fits without aging terminal feedback")
		paused_initial.update(battle, Vector2(960,540), 2.0, false, 72, 150)
		expect(paused_initial.clock == 0 and paused_initial.terminal_remaining == .48 and paused_initial.trauma == .68, "paused resize preserves nonzero terminal lifetime")
		viewport.size = dimensions
		await frames(5)
		view._layout_hud()
		view.canvas.refresh(false)
		battle.set_paused(false)
		SETTINGS.save_comfort("reduced_motion", true)
		SETTINGS.save_comfort("reduced_flash", true)
		settle()
		var reduced: Dictionary = view.canvas.camera_state()
		expect(reduced.shake == Vector2.ZERO and reduced.escape_valid, "comfort removes shake and preserves functional escape framing")
		await screenshot("reduced-%d" % dimensions.x)
		SETTINGS.save_comfort("reduced_motion", false)
		SETTINGS.save_comfort("reduced_flash", false)
		battle.telegraphs.clear()
		boss.windup = 0
		boss.current_action = {}
		for point in [Vector2(55,65), Vector2(3145,1735)]:
			battle.position = point
			boss.position = SPACE.clamp_point(point + (SPACE.CENTER - point).normalized() * 290, Vector2(100,100))
			settle()
			check_visible_body(point, view.canvas.camera_state(), "corner controlled body")
		await screenshot("corner-%d" % dimensions.x)
		battle.position = SPACE.CENTER
		boss.position = battle.position + Vector2(260,-150)
	var long_tell := {"shape":"disc", "origin":battle.position, "radius":185.0, "remaining":1.6, "total":1.6, "damage":20.0}
	var tell_list: Array[Dictionary] = [long_tell]
	var empty_hazards: Array[Dictionary] = []
	var long_route: Dictionary = view.canvas.camera._escape(battle.position, tell_list, empty_hazards, 180, battle.position + Vector2.UP * 100)
	expect(long_route.valid and battle.position.distance_to(long_route.point) > 180 * .9, "escape uses full actual tell rather than truncating at .9 seconds")
	# Geometry families: public camera diagnostics must not claim an impossible escape.
	for shape in ["disc", "sector", "ring_gap"]:
		var descriptor := {"shape":shape, "origin":battle.position - Vector2(90,0), "direction":Vector2.RIGHT, "radius":135.0, "inner_radius":30.0, "spread":1.7, "gap_angle":PI, "gap_width":1.3, "remaining":1.2, "total":1.2, "damage":20.0}
		battle.telegraphs = [descriptor]
		settle(1)
		var state: Dictionary = view.canvas.camera_state()
		expect(state.escape_valid, "safe route for " + shape)
		if state.escape_valid: expect(not GEOMETRY.contains(descriptor, state.safe_route[1], 18), "route respects " + shape)
	battle.telegraphs = [{"shape":"disc", "origin":battle.position, "radius":900.0, "remaining":.05, "total":1.0, "damage":20.0}]
	settle(1)
	expect(not view.canvas.camera_state().escape_valid, "unreachable escape is never fabricated")
	battle.telegraphs.clear()
	view.canvas.consume_events([{"kind":"boss_phase", "id":boss.id, "enemy_id":boss.id, "position":boss.position, "form_index":1}])
	view.canvas.advance_presentation(.08)
	view.canvas.refresh(false)
	await screenshot("phase")
	battle.outcome = "victory"
	view.canvas.consume_events([{"kind":"boss_defeated", "id":boss.id, "position":boss.position}, {"kind":"kill", "id":boss.id, "position":boss.position}])
	battle.enemies.clear()
	view.canvas.refresh(false)
	expect(view.canvas.death_views.size() == 1, "true final defeat retains a brief body fade")
	expect(view.canvas.victory_presentation_pending(), "terminal presentation has its own bounded window")
	view.canvas.advance_presentation(.1)
	view.canvas.refresh(false)
	await screenshot("victory")
	view.canvas.advance_presentation(.6)
	view.canvas.refresh(false)
	expect(not view.canvas.victory_presentation_pending() and view.canvas.boss_feedback.marks.is_empty() and view.canvas.death_views.is_empty() and view.canvas.camera.trauma == 0, "victory leaves no feedback or shake residue")
	view.canvas.consume_events([{"kind":"boss_impact", "position":boss.position}])
	battle.outcome = "failed"
	view.canvas.presentation_finished = false
	view.canvas.advance_presentation(.01)
	expect(view.canvas.boss_feedback.marks.is_empty() and view.canvas.camera.trauma == 0, "failure clears presentation immediately")
	view.queue_free()
	viewport.queue_free()
	await frames()
	# Audio stop commands cross the mixer thread. Let it release playback refs
	# after the attempt nodes disappear, rather than quitting within the same mix.
	if DisplayServer.get_name() != "headless": await create_timer(.12).timeout
	SETTINGS.save_comfort("reduced_motion", old_motion)
	SETTINGS.save_comfort("reduced_flash", old_flash)
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
		var file := FileAccess.open(capture_dir.path_join("camera-measurements.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(measurements, "  "))
	print("CHRONICLE_BOSS_CAMERA_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func check_visible_body(player: Vector2, state: Dictionary, label: String) -> void:
	var top: Vector2 = state.base_origin + (player + Vector2(0,-80)) * state.scale
	var feet: Vector2 = state.base_origin + (player + Vector2(0,20)) * state.scale
	expect(state.safe_screen.grow(1).has_point(top) and state.safe_screen.grow(1).has_point(feet), label + " stays clear of HUD")
