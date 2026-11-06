extends SceneTree
## Deterministic view stress fixtures, not balance or campaign-completion evidence.
const VIEW := preload("res://scripts/ui/chronicle/battle_view.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const METRICS := preload("res://design/danmaku-pressure-20261103/presentation/pressure_render_metrics.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
const HURTBOX := preload("res://scripts/battle/player_hurtbox.gd")
const THREATS := preload("res://scripts/ui/chronicle/enemy_threat_view.gd")
const SETTINGS := preload("res://scripts/shared/settings.gd")
var viewport: SubViewport
var view: Control
var capture_dir := ""
var checks := 0
var failures := 0
var measurements: Array = []

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
	call_deferred("run")

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func frames(count: int = 3) -> void:
	for index in count: await process_frame

func capture(label: String) -> void:
	await frames()
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var image := viewport.get_texture().get_image()
	expect(image.get_size() == viewport.size, "rendered dimensions " + label)
	var core: Vector2i = Vector2i((view.canvas.origin + view.battle.position * view.canvas.world_scale).round())
	if Rect2i(Vector2i.ZERO, image.get_size()).has_point(core):
		var pixel := image.get_pixelv(core)
		expect(pixel.r > .9 and pixel.g < .3 and pixel.b > .15 and pixel.b < .5, "red controlled core remains above hostile bullet and decoration " + label)
	image.save_png(capture_dir.path_join(label + ".png"))

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "fixture player data isolated")
	if failures: quit(1); return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var definitions := {}
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")): definitions[person.id] = person
	view = VIEW.new()
	view.setup({"attempt_id":"danmaku-view-fixture", "members":["JIA","F11","F07"], "characters":{"JIA":C.record("JIA"),"F11":C.record("F11"),"F07":C.record("F07")}, "equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":"ember_seal"}, "stage":C.stage("B18"), "seed":1818, "node":{"id":"B18","name":"白门楼终战"}},definitions)
	viewport.add_child(view)
	view.set_physics_process(false)
	await frames()
	var battle: RefCounted = view.battle
	var old_motion := SETTINGS.comfort_enabled("reduced_motion")
	var old_flash := SETTINGS.comfort_enabled("reduced_flash")
	SETTINGS.save_comfort("reduced_motion", false)
	SETTINGS.save_comfort("reduced_flash", false)
	battle.enemies.clear()
	battle.position = SPACE.CENTER
	battle.director.config.fields_enabled = false
	battle.director.boss_spawned = true
	var boss: RefCounted = battle.director.spawn("B18", SPACE.CENTER + Vector2(280,-150))
	battle.enemies.append(boss)
	# A mob carpet deliberately exceeds the previous 28–42 enemy population.
	for index in 120:
		var angle := index * 2.399963
		var distance := 100 + sqrt(float(index)) * 36
		battle.enemies.append(battle.director.spawn("E01", battle.position + Vector2.from_angle(angle) * distance))
	var ring := {"action_id":"pulse","warning_policy":"area","shape":"ring_gap","origin":battle.position + Vector2(270,-70),"radius":470.0,"inner_radius":195.0,"gap_angle":PI,"gap_width":1.1,"direction":Vector2.LEFT,"remaining":.8,"total":1.2,"phase":"tell","damage":35.0}
	var charge := {"action_id":"charge","warning_policy":"area","shape":"line","origin":battle.position + Vector2(-420,-155),"direction":Vector2.RIGHT,"length":1050.0,"half_width":46.0,"remaining":.7,"total":1.0,"phase":"tell","damage":35.0}
	var aimed := {"action_id":"shot","warning_policy":"aim","shape":"fan","origin":boss.position,"direction":(battle.position-boss.position).normalized(),"radius":900.0,"spread":2.6,"remaining":.55,"total":.9,"phase":"tell","damage":35.0}
	var ordinary: Dictionary = aimed.duplicate(true)
	ordinary.warning_policy = "none"
	expect(not THREATS.visible(ordinary), "ordinary dense bullet fan has no blanket trajectory")
	expect(THREATS.warning_policy(aimed) == "aim", "fast shot uses directional aim cue")
	expect(THREATS.outline(charge).size() == 34, "charge keeps exact rounded capsule")
	battle.telegraphs = [ring, charge, aimed, ordinary]
	battle.hazards = [{"action_id":"marker","warning_policy":"area","shape":"marker","origin":battle.position+Vector2(-120,140),"radius":92.0,"phase":"tell","remaining":.5,"total":.8,"damage":30.0}]
	battle.telegraphs.append(battle.hazards[0])
	for index in 288:
		var angle := TAU * (index % 48) / 48 + (index / 48) * .11
		var position: Vector2 = battle.position + Vector2.from_angle(angle) * (75 + (index / 48) * 55)
		battle.projectiles.append({"position":position,"velocity":Vector2.from_angle(angle)*225,"life":2.0,"hostile":true,"hit_radius":5.0 if index % 3 else 7.0,"bullet_style":["orb","needle","bone"][index%3]})
	# One solid hostile core exactly under the player verifies draw ordering.
	battle.projectiles.append({"position":battle.position,"velocity":Vector2.RIGHT*220,"life":2.0,"hostile":true,"hit_radius":8.0,"bullet_style":"orb"})
	view.refresh()
	for dimensions in [Vector2i(960,600),Vector2i(1280,720),Vector2i(1920,1080)]:
		viewport.size = dimensions
		await frames(5)
		view._layout_hud()
		var refresh_start := Time.get_ticks_usec()
		for step in 90:
			view.canvas.advance_presentation(1.0/60)
			view.canvas.refresh(false)
		var refresh_ms := (Time.get_ticks_usec() - refresh_start) / 90000.0
		var hit: Dictionary = view.canvas.controlled_hurtbox()
		var camera: Dictionary = view.canvas.camera_state()
		expect(hit.center == HURTBOX.center(battle.position) and hit.radius == HURTBOX.RADIUS, "red core shares actual controlled collision")
		expect(hit.visible and camera.scale >= .449, "smallest actual hurt dot and controlled body retain readable scale")
		var body: Rect2 = view.canvas._body_rect(view.canvas.actor_visual, battle.position)
		expect(body.size.y * camera.scale >= 32.39, "actual controlled silhouette readability floor")
		measurements.append({"size":str(dimensions),"enemies":battle.enemies.size(),"projectiles":battle.projectiles.size(),"hurt_radius":hit.radius,"hurt_screen_radius":hit.radius*camera.scale,"camera_scale":camera.scale,"escape_valid":camera.escape_valid,"presentation_update_mean_ms":refresh_ms,"coverage":screen_coverage(battle,camera),"ring_screen_diameter":ring.radius*2*camera.scale,"charge_screen_length":charge.length*camera.scale,"visible_world_size":str(camera.bounds.size)})
		await capture("dense-%d" % dimensions.x)
		SETTINGS.save_comfort("reduced_motion", true)
		SETTINGS.save_comfort("reduced_flash", true)
		view.canvas.refresh(false)
		await capture("dense-comfort-%d" % dimensions.x)
		var before: Dictionary = view.canvas.camera_state()
		battle.set_paused(true)
		view.canvas.advance_presentation(.8)
		view.canvas.refresh(false)
		expect(before == view.canvas.camera_state(), "paused dense field freezes camera")
		battle.set_paused(false)
		SETTINGS.save_comfort("reduced_motion", false)
		SETTINGS.save_comfort("reduced_flash", false)
	battle.outcome = "failed"
	view.canvas.refresh(false)
	expect(not view.canvas.controlled_hurtbox().visible and view.canvas.released_threats.is_empty() and view.canvas.enemy_effects.transients.is_empty(), "terminal frame clears hurt marker and effects")
	SETTINGS.save_comfort("reduced_motion", old_motion)
	SETTINGS.save_comfort("reduced_flash", old_flash)
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
		var report := FileAccess.open(capture_dir.path_join("readability.json"), FileAccess.WRITE)
		report.store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements}, "\t"))
	view.queue_free()
	viewport.queue_free()
	await frames()
	print("DANMAKU_READABILITY_FIXTURE ", "PASS" if failures == 0 else "FAIL", " checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)

func screen_coverage(battle: RefCounted, camera: Dictionary) -> Dictionary:
	return METRICS.coverage(battle, camera)
