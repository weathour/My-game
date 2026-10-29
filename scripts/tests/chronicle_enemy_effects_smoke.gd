extends SceneTree
## Pure presentation fixtures over the real BattleSession; never a balance/combat-pass claim.
const FX := preload("res://scripts/ui/chronicle/enemy_battle_effects.gd")
const VIEW := preload("res://scripts/ui/chronicle/battle_view.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const GEOMETRY := preload("res://scripts/battle/enemy_geometry.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
var viewport: SubViewport
var view: Control
var capture_dir := ""
var checks := 0
var failures := 0

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
	call_deferred("run")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func frames(count: int = 3) -> void:
	for index in count: await process_frame

func capture(label: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var image := viewport.get_texture().get_image()
	expect(image.get_size() == viewport.size, "actual rendered dimensions " + label)
	image.save_png(capture_dir.path_join(label + ".png"))

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "test storage isolated")
	if failures: quit(1); return
	viewport = SubViewport.new();viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var definitions := {}
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")): definitions[person.id] = person
	view = VIEW.new()
	view.setup({"attempt_id":"fx-presentation-fixture", "members":["JIA"], "characters":{"JIA":C.record("JIA")}, "equipment":{"weapon":"plain_blade", "armor":"cloth_armor", "accessory":"ember_seal"}, "stage":C.stage("B06"), "seed":1818, "node":{"id":"B06", "name":"敌方特效审看"}},definitions)
	viewport.add_child(view);view.set_physics_process(false)
	await frames()
	var battle: RefCounted = view.battle
	battle.enemies.clear()
	var enemy: RefCounted = battle.director.spawn("B06", SPACE.CENTER + Vector2(280,120))
	battle.enemies.append(enemy)
	var fx: RefCounted = view.canvas.enemy_effects
	expect(fx.clips.size() == 8, "all eight original raster effect clips loaded")
	for id in FX.EFFECT_IDS:
		var hashes: Dictionary = {}
		for index in 4:
			var texture: Texture2D = fx.texture(id, index * .1)
			expect(texture != null and texture.get_image().get_used_rect().has_area(), id + " frame " + str(index))
			if texture != null: hashes[texture.get_image().get_data().hex_encode().sha256_text()] = true
		expect(hashes.size() == 4, id + " four distinct authored temporal frames")
	var hp: float = battle.current().hp
	var mana: float = battle.current().mp
	var position: Vector2 = battle.position
	var seen_count := 0
	for action in ["swipe", "shot", "fan", "charge", "pot", "heal", "command", "summon", "pulse", "anchor", "collaboration", "slam", "hook"]:
		seen_count += 1
		var geometry := GEOMETRY.descriptor(enemy, {"action":action, "shape":"sector", "radius":95.0, "spread":1.8, "windup":.9}, battle.position)
		geometry.beneficiaries = [enemy.id]
		var event := {"kind":"enemy_release", "id":enemy.id, "action_serial":seen_count, "geometry":geometry}
		var before := geometry.duplicate(true)
		fx.consume([event], battle)
		var count: int = fx.transients.size()
		fx.consume([event], battle)
		expect(fx.transients.size() == count, action + " release deduplicated")
		expect(geometry == before, action + " leaves collision descriptor untouched")
	var marker := {"action_id":"slam", "shape":"marker", "origin":battle.position + Vector2(160,0), "radius":55.0, "phase":"active"}
	fx.consume([{"kind":"enemy_hazard_release", "id":enemy.id, "action_serial":90, "geometry":marker}], battle)
	expect(fx.transients.back().style == "lightning", "actual delayed marker impact selects lightning at release")
	expect(battle.current().hp == hp and battle.current().mp == mana and battle.position == position, "all effects leave battle resources and movement unchanged")
	battle.set_paused(true)
	var count_before: int = fx.transients.size()
	battle.tick(.5, Vector2.RIGHT)
	fx.sync(battle)
	expect(fx.transients.size() == count_before, "pause freezes effect lifetime with battle clock")
	battle.set_paused(false)
	fx.consume([{"kind":"enemy_remove", "id":enemy.id}], battle)
	expect(fx.transients.is_empty(), "source cancellation removes owned effects immediately")
	# Render every authored clip in its actual canvas, and include exact persistent hazards.
	for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		viewport.size = dimensions
		await frames(4)
		fx.clear()
		for index in FX.EFFECT_IDS.size():
			var id: String = FX.EFFECT_IDS[index]
			var origin := SPACE.CENTER + Vector2((index % 4 - 1.5) * 220, (index / 4) * 180 - 80)
			fx._add(id, {"origin":origin, "radius":55, "direction":Vector2.RIGHT}, battle.director.elapsed, 10, enemy.id)
		for frame in 4:
			battle.director.elapsed = frame * .1
			for entry in fx.transients: entry.start = 0.0
			view.canvas.refresh(false)
			await frames(2)
			await capture("enemy-fx-%d-%02d" % [dimensions.x,frame])
		battle.director.elapsed = 0.0
	battle.outcome = "cleared";fx.sync(battle)
	expect(fx.transients.is_empty() and fx.seen.is_empty(), "battle end clears raster effects and deduplication state")
	view.queue_free();viewport.queue_free();await frames()
	print("CHRONICLE_ENEMY_EFFECTS_SMOKE ","PASS" if failures == 0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
