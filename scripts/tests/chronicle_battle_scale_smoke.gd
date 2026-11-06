extends SceneTree
## Presentation measurements plus shared-world contracts, using real art/scenes.
const VIEW := preload("res://scripts/ui/chronicle/battle_view.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
const ART := preload("res://scripts/ui/chronicle/battle_art.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const SETTINGS := preload("res://scripts/shared/settings.gd")
const ENEMY_MANIFEST := preload("res://scripts/ui/chronicle/enemy_visual_manifest.gd")
const DIRECTOR := preload("res://scripts/battle/stage_director.gd")
const ENEMY_RUNTIME := preload("res://scripts/battle/enemy_runtime.gd")
const ENEMIES := preload("res://scripts/content/enemy_catalog.gd")
var viewport: SubViewport
var view: Control
var failures := 0
var checks := 0
var capture_dir := ""
var metrics: Array = []

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func frames(count: int = 6) -> void:
	for i in count: await process_frame

func capture(name: String) -> void:
	await frames()
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	viewport.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))

func body_bounds(visual: Node2D) -> Rect2:
	var sprite: Node2D = visual.get("sprite")
	if sprite == null and visual.has_method("body_profile"):
		# Current missing-art fallback draws a centered diamond with its feet at
		# local y=0; retain the visible body/ground assertion without a legacy sprite.
		var profile: Vector2 = visual.body_profile()
		var scale_factor := visual.scale.y
		return Rect2(Vector2(-20.0 * scale_factor, -profile.x * scale_factor), Vector2(40.0 * scale_factor, profile.x * scale_factor))
	var bounds := Rect2()
	var textures: Array[Texture2D] = []
	if sprite is AnimatedSprite2D:
		for i in sprite.sprite_frames.get_frame_count(sprite.animation): textures.append(sprite.sprite_frames.get_frame_texture(sprite.animation, i))
	else:
		for i in sprite.hframes:
			var atlas := AtlasTexture.new()
			atlas.atlas = sprite.texture
			var cell: Vector2 = sprite.texture.get_size() / Vector2(sprite.hframes, sprite.vframes)
			atlas.region = Rect2(Vector2(i, 0) * cell, cell)
			textures.append(atlas)
	for i in textures.size():
		var texture: Texture2D = textures[i]
		var opaque := Rect2(texture.get_image().get_used_rect())
		opaque.position += sprite.offset - texture.get_size() * .5
		var rect: Rect2 = visual.transform * sprite.transform * opaque
		bounds = rect if i == 0 else bounds.merge(rect)
	return bounds

func measure(visual: Node2D, expected: float, name: String) -> void:
	# Per-character roster sheets may include weapons and cloth extending beyond
	# the torso reference. Measure their manifested body, not the full alpha bbox;
	# the sheet dimensions/anchor still independently verify the fixed foot.
	if visual.has_method("body_profile") and visual.get("manifest") is Dictionary:
		var profile: Vector2 = visual.body_profile()
		var manifest: Dictionary = visual.get("manifest")
		var reference_height := float(manifest.get("body_height_px", 0.0))
		expect(reference_height > 0 and is_equal_approx(profile.x, reference_height), name + " body calibration agrees with its manifest")
		var fitted_height := profile.x * visual.scale.y
		metrics.append({"name":name,"height":fitted_height,"ground":visual.position.y + profile.y * visual.scale.y,"body_reference_px":reference_height,"scale":visual.scale.y})
		expect(absf(fitted_height - expected) < .2, name + " manifested body height follows reference (expected %.2f, got %.2f)" % [expected, fitted_height])
		var sprite: AnimatedSprite2D = visual.get("sprite")
		if sprite != null:
			var clip_name := str(sprite.animation)
			var clip: Dictionary = manifest.get("clips", {}).get(clip_name, manifest.get("clips", {}).get("idle", {}))
			var size: Array = clip.get("frame_size", [192,192])
			var anchor: Array = manifest.get("anchor_px", [96,176])
			var expected_sprite_position := Vector2(float(size[0]) * .5 - float(anchor[0]), float(size[1]) * .5 - float(anchor[1]))
			expect(sprite.position.is_equal_approx(expected_sprite_position), name + " manifested frame anchor keeps feet at actor root")
		return
	var bounds := body_bounds(visual)
	metrics.append({"name":name,"height":bounds.size.y,"ground":bounds.end.y})
	expect(absf(bounds.size.y - expected) < .2, name + " height follows visible body, not frame (expected %.2f, got %.2f)" % [expected, bounds.size.y])
	expect(absf(bounds.end.y) < .2, name + " feet align with ground")

func measure_authored_enemy(visual: Node2D, enemy: RefCounted, clips: Array = ["idle"]) -> void:
	var identity := str(enemy.visual_id)
	var manifest := ENEMY_MANIFEST.resolved(identity)
	expect(not manifest.is_empty(), identity + " has authored body calibration")
	if manifest.is_empty(): return
	var body_height := float(manifest.get("body_height_px", 0))
	expect(body_height > 0, identity + " has a nonzero visible-body reference")
	if body_height <= 0: return
	var factor := float(enemy.body_height) / body_height
	expect(str(visual.get_meta("visual_id", "")) == identity and str(visual.get("visual_id")) == identity, identity + " uses its own authored visual")
	expect(visual.scale.is_equal_approx(Vector2.ONE * factor), identity + " fits calibrated body, not transparent canvas")
	expect(visual.position.is_zero_approx(), identity + " calibrated ground origin remains fixed")
	for key in clips:
		visual.preview(str(key), 0.0)
		var clip: Dictionary = manifest.clips[key]
		var dimensions: Array = clip.frame_size
		var anchor := Vector2(float(manifest.anchor_px[0]), float(manifest.anchor_px[1]))
		var cell := Vector2(float(dimensions[0]), float(dimensions[1]))
		var texture := ENEMY_MANIFEST.texture(identity, str(clip.file))
		expect(body_height < cell.y, identity + " " + str(key) + " keeps transparent padding outside body reference")
		expect(visual.sprite.position.is_equal_approx(cell * .5 - anchor), identity + " " + str(key) + " places the recorded foot anchor at origin")
		var source_image := texture.get_image()
		var source_bounds := Rect2()
		for index in int(clip.frames):
			var frame_image := source_image.get_region(Rect2i(index * int(cell.x), 0, int(cell.x), int(cell.y)))
			var opaque := Rect2(frame_image.get_used_rect())
			expect(opaque.has_area(), identity + " " + str(key) + " frame " + str(index) + " has visible pixels")
			source_bounds = opaque if index == 0 else source_bounds.merge(opaque)
		var expected := Rect2((source_bounds.position - anchor) * factor, source_bounds.size * factor)
		var actual := body_bounds(visual)
		expect(actual.position.distance_to(expected.position) < .02 and actual.size.distance_to(expected.size) < .02, identity + " " + str(key) + " preserves independently read alpha silhouette at calibrated scale")
		# A weapon or plume can extend beyond the body; only idle feet define ground.
		if str(key) == "idle": expect(absf(actual.end.y) < .2, identity + " idle feet align with ground")
		metrics.append({"name":identity + " " + str(key),"calibrated_body_height":body_height * visual.scale.y,"height":actual.size.y,"ground":actual.end.y,"source_alpha_bounds":source_bounds,"scale":factor})
	visual.preview("idle", 0.0)

func check_boss_form_art() -> void:
	for stage_id in ["B15", "B16", "B17", "B18"]:
		var director := DIRECTOR.new(C.stage(stage_id), 1702)
		var enemy: RefCounted = director.spawn("boss", SPACE.CENTER)
		for phase in 2:
			expect(enemy.visual_id == stage_id + ("_human" if phase == 0 else ""), stage_id + " selects the current form identity")
			var visual := ART.create_enemy(enemy, stage_id)
			viewport.add_child(visual)
			measure_authored_enemy(visual, enemy, ENEMY_MANIFEST.resolved(enemy.visual_id).clips.keys())
			visual.queue_free()
			if phase == 0: enemy.receive_damage(enemy.hp)
	# These are non-targetable collaborators; their presentation uses the human
	# descriptor without changing the war definition that owns their damage.
	var collaboration_director := DIRECTOR.new(C.stage("B17"), 1702)
	for descriptor in [{"definition_id":"M03_WAR","visual_id":"M03_human","body_height":128.0,"position":SPACE.CENTER}, {"definition_id":"M04_WAR","visual_id":"M04_human","body_height":120.0,"position":SPACE.CENTER}]:
		var enemy: RefCounted = collaboration_director.derivative(descriptor, [])
		var visual := ART.create_enemy(enemy, "B17")
		viewport.add_child(visual)
		measure_authored_enemy(visual, enemy, ENEMY_MANIFEST.resolved(enemy.visual_id).clips.keys())
		visual.queue_free()

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated storage")
	if failures: quit(1); return
	var old_layout := SETTINGS.load_hud_layout()
	SETTINGS.save_hud_layout(SETTINGS.HUD_LAYOUT_SIMPLE)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var definitions := {}
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")): definitions[person.id] = person
	var records := {}
	for id in ["JIA","F11","N07"]: records[id] = C.record(id)
	view = VIEW.new()
	view.setup({"attempt_id":"scale-fixture","members":["JIA","F11","N07"],"characters":records,"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":"ember_seal"},"stage":C.stage("B02"),"seed":1702,"node":{"id":"B02","name":"入城旧街"}},definitions)
	viewport.add_child(view)
	view.set_physics_process(false)
	await frames()
	var b: RefCounted = view.battle
	b.director.spawn_remaining = 10000
	for i in 3:
		b.active = i
		for moving in [false,true]:
			view.canvas.refresh(moving)
			# New Jia keeps one authored scale across poses; running crouches.
			measure(view.canvas.actor_visual, 63 if b.current().id == "JIA" and moving else 72, b.current().id + (" run" if moving else " idle"))
	b.active = 0
	b.equipment.weapon = "long_spear"
	for moving in [false,true]:
		view.canvas.refresh(moving)
		measure(view.canvas.actor_visual, 67.5 if moving else 72, "JIA spear " + ("run" if moving else "idle"))
	b.equipment.weapon = "plain_blade"
	var types := ["E01","E02","card_elite","equipment_elite","boss"]
	for i in types.size():
		var enemy: RefCounted = b.director.spawn(types[i], SPACE.CENTER + Vector2(-360 + i * 180, 165))
		enemy.hp *= .8
		b.enemies.append(enemy)
	view.canvas.refresh(false)
	for i in types.size():
		var enemy: RefCounted = b.enemies[i]
		var visual: Node2D = view.canvas.enemy_views[enemy.id].node
		measure_authored_enemy(visual, enemy)
	var boss: RefCounted = b.enemies.back()
	var boss_bounds := body_bounds(view.canvas.enemy_views[boss.id].node)
	var boss_screen := Rect2(view.canvas.origin + (boss.position + boss_bounds.position) * view.canvas.world_scale, boss_bounds.size * view.canvas.world_scale)
	expect(view.canvas.camera.mode == "duel" and Rect2(Vector2.ZERO, view.canvas.size).encloses(boss_screen), "Boss framing preserves the complete authored silhouette")
	check_boss_form_art()
	# Ordinary follow still has the original local-map contract. The explicit Boss
	# fixture above now invokes duel zoom, so remove it before testing follow.
	b.enemies.pop_back()
	view.canvas.camera.reset()
	var missing := ENEMY_RUNTIME.new(-77, ENEMIES.definition("E01"), SPACE.CENTER)
	missing.visual_id = "missing-art-fixture"
	var placeholder := ART.create_enemy(missing, "B01")
	viewport.add_child(placeholder)
	expect(placeholder.get_meta("missing_enemy_art", false), "missing enemy art uses current visible placeholder")
	expect(placeholder.has_method("body_profile") and is_equal_approx(placeholder.body_profile().x, 64), "placeholder retains calibrated ground contract")
	placeholder.queue_free()
	view.refresh()
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]:
		viewport.size = dimensions
		await frames()
		view.canvas.refresh(false)
		view.refresh()
		expect(view.canvas.size == Vector2(dimensions), "HUD does not reduce the battlefield viewport")
		expect(view.canvas.size.x / view.canvas.world_scale < SPACE.SIZE.x * .5, "camera shows part of the traversable map")
		check_triangle()
		await capture("proportions-%d" % dimensions.x)
		b.position = SPACE.FIELD_POSITIONS[0]
		view.canvas.refresh(false)
		expect(view.canvas.origin.x <= 0 and view.canvas.origin.y <= 0, "camera stays within map edge")
		await capture("corner-%d" % dimensions.x)
		b.position = SPACE.CENTER
	viewport.size = Vector2i(1280,720)
	await frames()
	b.request_switch(1)
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	view.refresh()
	await create_timer(.25).timeout
	check_triangle()
	await capture("switched-emma")
	b.characters.N07.dead = true
	view.refresh()
	expect(view.hud.presentation.members[2].label.text == "阵亡", "fallen companion stays identifiable")
	await capture("fallen-companion")
	b.switch_cooldown = 0
	b.request_switch(1)
	b.tick(0,Vector2.ZERO)
	expect(b.current().id == "JIA", "switch skips fallen companion")
	# The first companion must not produce a duplicated third portrait.
	b.members = ["JIA", "F11"]
	b.switch_cooldown = 0
	view.refresh()
	expect(not view.hud.presentation.members[2].root.visible, "one companion leaves the third portrait hidden")
	b.request_switch(1)
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	view.refresh()
	await create_timer(.25).timeout
	expect(b.current().id == "F11", "two-member party can switch to its companion")
	var pair: Array = view.hud.presentation.members
	var current_center: Vector2 = pair[1].root.position + pair[1].portrait.size * .5
	var reserve_center: Vector2 = pair[0].root.position + pair[0].portrait.size * .5
	expect(current_center.y + 30 < reserve_center.y, "two-member HUD keeps the active portrait raised")
	await capture("two-members")
	# Field activation remains physical; the four choices live inside the enlarged world.
	b.enemies.clear()
	for point in SPACE.FIELD_POSITIONS: expect(SPACE.BOUNDS.grow(-65).has_point(point), "field reachable inside world")
	b.position = SPACE.FIELD_POSITIONS[1]
	b.tick(0,Vector2.ZERO)
	expect(b.director.field == 1 and not b.choose_field(2), "walking onto a field locks other choices")
	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	for point in [SPACE.CENTER, Vector2(55,65), SPACE.SIZE-Vector2(55,65)]:
		var safe := true
		for i in 80:
			var spawn := SPACE.reinforcement(point,rng)
			safe = safe and SPACE.BOUNDS.has_point(spawn) and spawn.distance_to(point) >= 440 and spawn.distance_to(point) < 1000
		expect(safe,"enlarged-map reinforcement stays near combat without spawning on player")
		expect(SPACE.challenge_position(point).distance_to(point) < 320,"boss/elite arrives near the current fight")
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
		var file := FileAccess.open(capture_dir.path_join("measurements.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(metrics,"  "))
	view.queue_free()
	viewport.queue_free()
	await frames()
	SETTINGS.save_hud_layout(old_layout)
	print("CHRONICLE_BATTLE_SCALE_SMOKE ","PASS" if failures == 0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)

func check_triangle() -> void:
	var hud: Control = view.hud.presentation
	var centers: Array[Vector2] = []
	for member in hud.members: centers.append(member.root.position + member.portrait.size * .5)
	var active: int = view.battle.active
	var other: Array[int] = []
	for i in 3:
		if i != active: other.append(i)
	expect(centers[active].y + 30 < minf(centers[other[0]].y,centers[other[1]].y),"active portrait forms the top of the triangle")
	expect(centers[active].x > minf(centers[other[0]].x,centers[other[1]].x) and centers[active].x < maxf(centers[other[0]].x,centers[other[1]].x),"other two portraits flank the current actor")
