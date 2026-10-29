extends SceneTree
const VIEW := preload("res://scripts/ui/chronicle/battle_view.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const ART := preload("res://scripts/ui/chronicle/battle_art.gd")
const VISUAL := preload("res://assets/players/baimen-women/women_visual.gd")
var viewport: SubViewport
var view: Control
var failures := 0
var checks := 0
var capture_dir := ""
var selected_ids: PackedStringArray = []

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
		if arg.begins_with("--ids="): selected_ids = arg.trim_prefix("--ids=").split(",")
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func frames(count: int = 3) -> void:
	for i in count: await process_frame

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	RenderingServer.force_draw()
	await process_frame
	DirAccess.make_dir_recursive_absolute(capture_dir)
	viewport.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))

func check_viewport_readability(actor: Node2D, id: String, resolution: Vector2i) -> void:
	var canvas: Control = view.canvas
	var base_scale := minf(resolution.x / 1280.0, resolution.y / 720.0)
	expect(canvas.size == Vector2(resolution), id + " battlefield uses the actual resolution")
	# Authored 80px body is 72 world units, independent of framing or current pose.
	expect(actor.scale.is_equal_approx(Vector2.ONE * .9) and actor.position.is_zero_approx() and actor.sprite.position.is_equal_approx(Vector2(0,-80)), id + " resizing preserves physical body and foot anchor")
	var projected_body := 80.0 * actor.global_transform.y.length()
	expect(is_equal_approx(projected_body, 72.0 * canvas.world_scale) and is_equal_approx(canvas.world_scale, canvas.camera.scale), id + " actual body projection follows the active camera")
	expect(projected_body >= 32.4 - .01 and projected_body <= 72.0 * base_scale + .01, id + " body remains within the camera readability range at this resolution")
	var texture: Texture2D = actor.sprite.sprite_frames.get_frame_texture(actor.sprite.animation, actor.sprite.frame)
	var opaque := Rect2(texture.get_image().get_used_rect())
	opaque.position -= texture.get_size() * .5
	var screen_bounds: Rect2 = actor.sprite.global_transform * opaque
	expect(screen_bounds.has_area() and Rect2(Vector2.ZERO,Vector2(resolution)).encloses(screen_bounds), id + " actual visible pose stays inside the resized battlefield")

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated test storage")
	if failures: quit(1); return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var definitions := {}
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")): definitions[person.id] = person
	for id in ART.WOMEN:
		if not selected_ids.is_empty() and not selected_ids.has(id): continue
		for clip in VISUAL.CLIPS:
			var sheet := load("res://assets/players/baimen-women/%s/%s.png" % [id, clip[0]]) as Texture2D
			expect(sheet != null and sheet.get_size() == Vector2(192 * clip[1], 192), id + " real " + str(clip[0]) + " sheet")
		var records := {id:C.record(id, 8), "JIA":C.record("JIA")}
		var stage := C.stage("B02")
		stage.boss_time = 10000.0
		stage.boss_kills = 10000
		view = VIEW.new()
		view.setup({"attempt_id":"women-art-fixture", "members":[id,"JIA"], "characters":records,"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":""},"stage":stage,"seed":1702,"node":{"id":"B02","name":"入城旧街"}}, definitions)
		viewport.add_child(view)
		view.set_physics_process(false)
		await frames()
		var b: RefCounted = view.battle
		b.director.spawn_remaining = 10000
		view.canvas.refresh(false)
		var actor: Node2D = view.canvas.actor_visual
		expect(actor.scene_file_path == ART.WOMEN[id].resource_path and actor.character_id == id, id + " dedicated actor identity")
		expect(actor.scale == Vector2.ONE * .9 and actor.position == Vector2.ZERO, id + " fixed scale and feet")
		expect(ART.tint(id) == Color.WHITE, id + " authored identity colors")
		var portrait: Node2D = ART.portrait(id).instantiate()
		viewport.add_child(portrait)
		expect(portrait.get_node("Sprite2D").texture.get_size() == Vector2(128,128), id + " dedicated HUD portrait")
		portrait.queue_free()
		actor.set_moving(true, Vector2.LEFT)
		expect(actor.sprite.animation == &"run" and actor.sprite.flip_h, id + " left running")
		actor.set_moving(false)
		b.tick(0, Vector2.ZERO)
		view.canvas.refresh(false)
		expect(not actor.attacking, id + " failed basic without target does not animate")
		var enemy: RefCounted = b.director.spawn("melee", b.position + Vector2(-60, 0))
		enemy.hp = 10000
		enemy.max_hp = 10000
		b.enemies.append(enemy)
		b.current().cooldowns.clear()
		b.tick(0, Vector2.ZERO)
		view.canvas.refresh(false)
		expect(actor.attacking and actor.sprite.animation == &"attack" and actor.sprite.flip_h, id + " actual successful attack faces target")
		expect(actor.sprite.frame == actor.attack_contact_frame, id + " immediate contact pose")
		var active_frame: int = actor.sprite.frame
		view.canvas.refresh(true)
		expect(actor.sprite.frame == active_frame, id + " cast is not replayed")
		# Classification uses the actual kit, including F06's crossbow THRUST.
		for ability in C.definition(id).manual:
			var expected: StringName = &"cast" if ability.kind in [4,5,6] else &"attack"
			expect(VISUAL.cast_clip(id, str(ability.id)) == expected, id + " " + str(ability.id) + " truthful presentation")
		b.set_paused(true)
		view.canvas.refresh(false)
		var progress: float = actor.sprite.frame_progress
		var paused_scale: float = view.canvas.world_scale
		var paused_origin: Vector2 = view.canvas.origin
		await create_timer(.1).timeout
		expect(actor.sprite.frame == active_frame and is_equal_approx(actor.sprite.frame_progress, progress), id + " pause freezes clip")
		expect(is_equal_approx(view.canvas.world_scale, paused_scale) and view.canvas.origin == paused_origin, id + " pause freezes camera framing")
		await capture(id + "-attack")
		if id in ["F02", "F06", "F09"]:
			var paused_sim_elapsed: float = b.director.elapsed
			var paused_camera_clock: float = view.canvas.camera.clock
			var paused_feedback_clock: float = view.canvas.boss_feedback.clock
			var paused_position: Vector2 = b.position
			for resolution in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
				viewport.size = resolution
				view.size = Vector2(resolution)
				await frames()
				view.refresh()
				view.canvas.refresh(false)
				check_viewport_readability(actor, id, resolution)
				expect(b.paused and is_equal_approx(b.director.elapsed,paused_sim_elapsed) and b.position == paused_position, id + " resizing while paused preserves simulation time and position")
				expect(actor.sprite.frame == active_frame and is_equal_approx(actor.sprite.frame_progress, progress), id + " resizing while paused preserves the exact animation pose")
				expect(is_equal_approx(view.canvas.camera.clock,paused_camera_clock) and is_equal_approx(view.canvas.boss_feedback.clock,paused_feedback_clock), id + " resizing while paused does not advance presentation clocks")
				await frames()
				await capture("%s-battle-%dx%d" % [id,resolution.x,resolution.y])
			viewport.size = Vector2i(1280,720)
			view.size = Vector2(viewport.size)
			await frames()
			view.refresh()
			view.canvas.refresh(false)
		b.set_paused(false)
		view.canvas.refresh(true)
		var before: Vector2 = b.position
		b.tick(.01, Vector2.UP)
		view.canvas.refresh(true)
		expect(b.position.y < before.y, id + " attack permits movement")
		await create_timer(.3).timeout
		expect(not actor.attacking, id + " finite attack returns to locomotion")
		if id == "F02":
			await check_guard_lifecycle(b, actor)
		else:
			b.current().mp = b.current().stats.mp
			b.current().cooldowns.clear()
			b.request_skill(0)
			b.tick(0, Vector2.ZERO)
			view.canvas.refresh(false)
			var skill: Resource = C.definition(id).manual[0]
			expect(actor.attacking and actor.manual_attack and actor.sprite.animation == VISUAL.cast_clip(id, str(skill.id)), id + " real manual uses its own attack or support clip and wins basic")
			b.set_paused(true)
			view.canvas.refresh(false)
			await capture(id + "-manual")
			b.set_paused(false)
		b._finish("failed")
		expect(b.effects.is_empty(), id + " terminal battle cleans effects")
		view.queue_free()
		await frames()
	viewport.queue_free()
	await frames()
	print("BAIMEN_WOMEN_COMBAT_ART_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

func check_guard_lifecycle(b: RefCounted, actor: Node2D) -> void:
	b.current().mp = 0
	b.current().cooldowns["F02_basic"] = 100
	b.request_skill(0)
	b.tick(0, Vector2.ZERO)
	view.canvas.refresh(false)
	expect(not actor.attacking, "insufficient mana does not present guard")
	b.current().mp = b.current().stats.mp
	b.current().cooldowns["F02_guard"] = 100
	b.request_skill(0)
	b.tick(0, Vector2.ZERO)
	view.canvas.refresh(false)
	expect(not actor.attacking, "cooldown does not present guard")
	b.current().cooldowns.clear()
	b.request_skill(0)
	b.tick(0, Vector2.ZERO)
	view.canvas.refresh(false)
	expect(actor.attacking and actor.manual_attack and actor.sprite.animation == &"cast" and actor.sprite.frame == 0, "guard wins same-tick basic without inventing counterattack")
	b.set_paused(true)
	view.canvas.refresh(false)
	await capture("F02-guard")
	b.set_paused(false)
	b.request_switch(1)
	b.tick(0, Vector2.ZERO)
	view.canvas.refresh(false)
	expect(view.canvas.actor_kind == "JIA", "switch changes foreground")
	b.switch_cooldown = 0
	b.request_switch(1)
	b.tick(0, Vector2.ZERO)
	view.canvas.refresh(false)
	expect(view.canvas.actor_kind == "F02" and not view.canvas.actor_visual.attacking, "returning does not replay old successful guard")
