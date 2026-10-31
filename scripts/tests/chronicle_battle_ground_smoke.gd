extends SceneTree
## Focused ground mapping/render fixture. Does not advance the battle simulation.
const GROUND := preload("res://scripts/ui/chronicle/battle_ground.gd")
const ART := preload("res://scripts/ui/chronicle/battle_art.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
const STAGES := preload("res://scripts/content/stage_catalog.gd")
const VIEW := preload("res://scripts/ui/chronicle/battle_view.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
var checks := 0
var failures := 0
var capture_dir := ""
var capture_only := ""
var require_environments := false
var metrics: Array = []

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
		if arg.begins_with("--capture-only="): capture_only = arg.trim_prefix("--capture-only=")
		if arg == "--require-environments": require_environments = true
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func frames(count: int = 4) -> void:
	for i in count: await process_frame

func capture(viewport: SubViewport, label: String) -> void:
	if not capture_only.is_empty() and label != capture_only: return
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await frames()
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	expect(image.get_size() == viewport.size, "capture resolution " + label)
	DirAccess.make_dir_recursive_absolute(capture_dir)
	image.save_png(capture_dir.path_join(label + ".png"))

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated storage")
	if failures: quit(1); return
	var manifest := ART.environment_manifest()
	expect(manifest.stages.size() == 18, "all 18 stage overlays are explicit")
	expect(SPACE.BOUNDS == Rect2(0,0,3200,1800), "actual arena unchanged")
	expect(SPACE.FIELD_POSITIONS == [Vector2(440,320),Vector2(2760,320),Vector2(440,1480),Vector2(2760,1480)], "four field positions unchanged")
	for stage in STAGES.STAGES:
		var profile := ART.environment(stage)
		expect(manifest.stages.has(stage), stage + " has environment overlay")
		expect(profile.get("flat_traversable", false), stage + " uses traversable ground contract")
		var texture := ART.map_texture(stage)
		if require_environments: expect(ART.has_environment_texture(stage), stage + " uses delivered ground, not fallback")
		expect(texture != null, stage + " has loaded texture or safe fallback")
		var covered := GROUND.coverage(texture.get_size())
		expect(covered.grow(.01).encloses(SPACE.BOUNDS), stage + " cover fills arena")
		expect(absf(covered.size.x / covered.size.y - texture.get_size().x / texture.get_size().y) < .0001, stage + " preserves aspect ratio")
		if ART.has_environment_texture(stage):
			var preview := ART.map_preview_texture(stage) as AtlasTexture
			expect(preview != null and absf(preview.region.size.aspect() - SPACE.SIZE.aspect()) < .0001, stage + " minimap uses the arena crop")
			expect(preview.region.get_center().is_equal_approx(texture.get_size() * .5), stage + " minimap crop shares arena center")
		metrics.append({"stage":stage,"environment":profile.get("environment"),"texture":texture.resource_path,"new_ground":ART.has_environment_texture(stage),"coverage":str(covered)})
	# A non-16:9 source must crop, never distort to the arena aspect.
	expect(GROUND.coverage(Vector2(1536,1024)).size.is_equal_approx(Vector2(3200, 2133.333333)), "3:2 source gets uniform cover")
	var definitions := {}
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")): definitions[person.id] = person
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var view := VIEW.new()
	view.setup({"attempt_id":"ground-fixture","members":["JIA","F11","F07"],"characters":{"JIA":C.record("JIA"),"F11":C.record("F11"),"F07":C.record("F07")},"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":"ember_seal"},"stage":C.stage("B18"),"seed":1818,"node":{"id":"B18","name":"吕布终战"}}, definitions)
	viewport.add_child(view)
	view.set_physics_process(false)
	await frames()
	var battle: RefCounted = view.battle
	battle.enemies.clear()
	battle.director.spawn_remaining = 10000
	var boss: RefCounted = battle.director.spawn("boss", SPACE.CENTER + Vector2(240,-120))
	battle.enemies.append(boss)
	battle.director.boss_spawned = true
	for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		viewport.size = dimensions
		await frames()
		battle.position = SPACE.CENTER
		view.canvas.camera.reset()
		view.refresh()
		view.canvas.refresh(false)
		expect(view.canvas.actors.position == view.canvas.origin, "ground shares actor camera origin")
		expect(view.canvas.actors.scale == Vector2.ONE * view.canvas.world_scale, "ground shares actor camera scale")
		await capture(viewport,"whitegate-center-%d" % dimensions.x)
		battle.enemies.clear()
		for i in SPACE.FIELD_POSITIONS.size():
			battle.position = SPACE.FIELD_POSITIONS[i]
			view.canvas.camera.reset()
			view.canvas.refresh(false)
			var p: Vector2 = view.canvas.origin + SPACE.FIELD_POSITIONS[i] * view.canvas.world_scale
			expect(Rect2(Vector2.ZERO,Vector2(dimensions)).has_point(p), "field %d visible at %d" % [i,dimensions.x])
			await capture(viewport,"whitegate-field-%d-%d" % [i, dimensions.x])
		for point in [Vector2(55,65),Vector2(3145,65),Vector2(55,1735),Vector2(3145,1735)]:
			battle.position = point
			view.canvas.camera.reset()
			view.canvas.refresh(false)
			var visible := GROUND.visible_world(view.canvas.origin, view.canvas.world_scale, Vector2(dimensions))
			expect(visible.has_point(point), "actual boundary position remains visible")
			expect(SPACE.clamp_point(point, SPACE.PLAYER_MARGIN) == point, "actual player margin remains unchanged")
			if dimensions.x == 1280: await capture(viewport,"whitegate-boundary-%d-%d" % [int(point.x),int(point.y)])
		battle.enemies.append(boss)
	view.queue_free()
	await frames()
	# Representative actual stage fixtures expose all six ground themes in play.
	viewport.size = Vector2i(1280,720)
	for stage in ["B01","B03","B06","B02","B14"]:
		var theme_view := VIEW.new()
		theme_view.setup({"attempt_id":"ground-theme-"+stage,"members":["JIA","F11","F07"],"characters":{"JIA":C.record("JIA"),"F11":C.record("F11"),"F07":C.record("F07")},"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":"ember_seal"},"stage":C.stage(stage),"seed":1818,"node":{"id":stage,"name":stage}}, definitions)
		viewport.add_child(theme_view)
		theme_view.set_physics_process(false)
		await frames()
		theme_view.battle.position = SPACE.CENTER
		theme_view.canvas.refresh(false)
		await capture(viewport, "theme-%s-%s-1280" % [stage, ART.environment(stage).environment])
		theme_view.queue_free()
		await frames()
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
		FileAccess.open(capture_dir.path_join("ground-mapping.json"), FileAccess.WRITE).store_string(JSON.stringify(metrics,"  "))
	viewport.queue_free()
	await frames()
	print("CHRONICLE_BATTLE_GROUND_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
