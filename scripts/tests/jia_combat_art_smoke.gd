extends SceneTree
const VIEW := preload("res://scripts/ui/chronicle/battle_view.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const ART := preload("res://scripts/ui/chronicle/battle_art.gd")
var viewport: SubViewport
var view: Control
var failures := 0
var checks := 0
var capture_dir := ""

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func frames(count: int = 3) -> void:
	for i in count: await process_frame

func capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	viewport.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated test storage")
	if failures: quit(1); return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var definitions := {}
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")): definitions[person.id] = person
	var records := {"JIA":C.record("JIA"), "F11":C.record("F11")}
	records.JIA.level = 3
	var stage := C.stage("B02")
	stage.boss_time = 10000.0
	stage.boss_kills = 10000
	view = VIEW.new()
	view.setup({"attempt_id":"jia-art-fixture","members":["JIA","F11"],"characters":records,"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":""},"stage":stage,"seed":1702,"node":{"id":"B02","name":"入城旧街"}},definitions)
	viewport.add_child(view)
	view.set_physics_process(false)
	await frames()
	var b: RefCounted = view.battle
	b.director.spawn_remaining = 10000
	view.canvas.refresh(false)
	var actor: Node2D = view.canvas.actor_visual
	expect(actor.scene_file_path == ART.JIA.resource_path, "dedicated protagonist scene")
	expect(ART.actor("N01") == ART.SWORD and ART.actor("F11") == ART.MAGE, "other characters keep authored scenes")
	expect(ART.portrait("JIA") == ART.JIA_HEAD, "triangle HUD uses Jia portrait")
	expect(actor.sprite.animation == &"dao-idle", "default dao idle")
	expect(actor.scale == Vector2.ONE * .9, "fixed authored body scale")
	actor.set_moving(true, Vector2.LEFT)
	expect(actor.sprite.animation == &"dao-run" and actor.sprite.flip_h, "left running animation")
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	expect(not actor.attacking, "empty battlefield does not animate failed basic casts")
	var enemy: RefCounted = b.director.spawn("melee", b.position + Vector2(-80,0))
	enemy.hp = 10000
	enemy.max_hp = 10000
	b.enemies.append(enemy)
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	expect(actor.attacking and actor.sprite.flip_h, "successful cast attacks toward its actual left target")
	expect(actor.sprite.frame == 1 and enemy.hp < 10000, "contact pose agrees with immediate damage")
	var snapshot: Dictionary = b.effects[0].duplicate()
	var active_frame: int = actor.sprite.frame
	view.canvas.refresh(true)
	expect(actor.sprite.frame == active_frame, "repeat refresh does not restart a cast")
	expect(snapshot.source == "JIA" and snapshot.direct and snapshot.ability == "JIA_basic", "effect owns immutable cast identity")
	b.set_paused(true)
	view.canvas.refresh(false)
	var progress: float = actor.sprite.frame_progress
	b.tick(.5,Vector2.RIGHT)
	await create_timer(.12).timeout
	expect(actor.sprite.frame == active_frame and is_equal_approx(actor.sprite.frame_progress,progress), "pause freezes attack animation")
	expect(is_equal_approx(b.effects[0].life,snapshot.life), "pause freezes authored effects")
	await capture("dao-attack-paused")
	b.set_paused(false)
	view.canvas.refresh(true)
	var before: Vector2 = b.position
	b.tick(.01,Vector2.UP)
	view.canvas.refresh(true)
	expect(b.position.y < before.y, "attack does not lock locomotion")
	await create_timer(.3).timeout
	expect(not actor.attacking and actor.sprite.animation == &"dao-run", "attack restores moving pose")
	b.current().mp = 0
	b.current().cooldowns["JIA_basic"] = 100
	b.request_skill(0)
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	expect(not actor.attacking, "insufficient mana does not animate a manual skill")
	b.current().mp = b.current().stats.mp
	b.current().cooldowns.clear()
	b.request_skill(0)
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	expect(actor.attacking and actor.manual_attack, "manual attack wins over same-tick basic attack")
	var ring: Dictionary = {}
	for effect in b.effects:
		if effect.get("ability","") == "jia_sweep": ring = effect
	expect(not ring.is_empty() and ring.radius == 150 and ring.kind == "ring", "sweep keeps actual combat radius")
	view.refresh()
	b.set_paused(true)
	view.canvas.refresh(false)
	await capture("sweep-paused")
	b.set_paused(false)
	# Switch away and back while old Jia effects still exist; they must not replay.
	b.request_switch(1)
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	expect(view.canvas.actor_kind == "F11", "switch replaces the protagonist visual")
	b.switch_cooldown = 0
	b.request_switch(1)
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	actor = view.canvas.actor_visual
	expect(view.canvas.actor_kind == "JIA" and not actor.attacking, "returning to Jia does not replay stale casts")
	# The stale-cast assertion above needs old effects. Clear those only after
	# checking it, so the spear review capture isolates its own trail.
	b.effects.clear()
	b.equipment.weapon = "long_spear"
	view.canvas.refresh(true)
	expect(actor.weapon == "spear" and actor.sprite.animation == &"spear-run", "equipped spear changes held weapon and locomotion")
	b.current().cooldowns.clear()
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	expect(actor.sprite.animation == &"spear-attack", "spear attack uses distinct authored pose")
	var thrust: Dictionary = b.effects.back()
	expect(thrust.narrow and thrust.radius == 180, "spear trail retains actual narrow reach")
	b.set_paused(true)
	view.canvas.refresh(false)
	await capture("spear-attack-paused")
	b.set_paused(false)
	b.current().cooldowns.clear()
	b.request_skill(1)
	b.tick(0,Vector2.ZERO)
	view.canvas.refresh(false)
	var found_break := false
	for effect in b.effects:
		if effect.get("ability","") == "jia_break": found_break = effect.narrow and effect.radius == 245
	expect(found_break and actor.manual_attack, "manual piercing attack retains its own range and priority")
	b._finish("failed")
	expect(b.effects.is_empty(), "terminal battle clears all authored effects")
	view.queue_free()
	viewport.queue_free()
	await frames()
	print("JIA_COMBAT_ART_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
