extends SceneTree
## Controlled combat population; real B01/B02 sessions, actors, damage and renderer.
const VIEW := preload("res://scripts/ui/chronicle/battle_view.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
const ART := preload("res://scripts/ui/chronicle/battle_art.gd")
var capture_dir := ""
var sizes: Array[Vector2i] = [Vector2i(1280,720)]
var definitions := {}
var metrics: Array = []
var viewport: SubViewport
func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
		if arg == "--three-sizes": sizes = [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]
	call_deferred("run")
func frames(count: int = 3) -> void:
	for i in count: await process_frame
func run() -> void:
	if not ProjectSettings.globalize_path("user://").begins_with("/tmp/"): push_error("isolated storage required"); quit(1); return
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")): definitions[person.id] = person
	viewport = SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for dimensions in sizes:
		viewport.size = dimensions
		for descriptor in [{"stage":"B01","count":4,"label":"sparse"},{"stage":"B01","count":24,"label":"crowd"},{"stage":"B02","count":24,"label":"crowd-reference"}]:
			await fixture(descriptor,dimensions)
	DirAccess.make_dir_recursive_absolute(capture_dir)
	FileAccess.open(capture_dir.path_join("readability-measurements.json"),FileAccess.WRITE).store_string(JSON.stringify({"seed":30418,"population":"controlled fixtures; real stage enemy stats and simulation; not a full playthrough","timing":"CPU tick and presentation samples; wall frame includes display scheduling, not input latency","fixtures":metrics},"  "))
	viewport.queue_free()
	await frames()
	await create_timer(.15).timeout # Release audio mixer references after real combat cues.
	print("GROUND_READABILITY_PLAYBACK PASS captures=",metrics.size())
	quit()
func fixture(descriptor: Dictionary, dimensions: Vector2i) -> void:
	var stage := str(descriptor.stage)
	var view := VIEW.new()
	view.setup({"attempt_id":"ground-readability-"+stage,"members":["JIA"],"characters":{"JIA":C.record("JIA")},"equipment":{"weapon":"plain_blade","armor":"cloth_armor","accessory":"ember_seal"},"stage":C.stage(stage),"seed":30418,"node":{"id":stage,"name":"城外异乡人" if stage == "B01" else "入城旧街"}}, definitions)
	viewport.add_child(view)
	view.set_physics_process(false)
	await frames()
	var battle: RefCounted = view.battle
	battle.enemies.clear()
	battle.position = SPACE.CENTER
	# Keep the chosen population reproducible; no runtime configuration is modified.
	battle.director.spawn_remaining = 10000
	var cycle: Array = battle.director.config.waves[0].cycle
	for i in int(descriptor.count):
		var angle := TAU * float(i) / float(descriptor.count) + .25
		var radius := 100.0 + float(i % 4) * 68
		var enemy: RefCounted = battle.director.spawn(str(cycle[i % cycle.size()]),battle.position + Vector2(cos(angle),sin(angle)*.7)*radius)
		battle.enemies.append(enemy)
	for i in 12: step(view)
	view.canvas.camera.reset()
	view.refresh()
	view.canvas.refresh(false)
	await frames()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var label := "%s-%s-%d" % [stage,descriptor.label,dimensions.x]
	viewport.get_texture().get_image().save_png(capture_dir.path_join(label+".png"))
	var live_at_capture: int = battle.enemies.size()
	var cpu: Array[float] = []
	var wall: Array[float] = []
	for i in 45:
		var wall_start := Time.get_ticks_usec()
		var start := Time.get_ticks_usec()
		step(view)
		cpu.append(float(Time.get_ticks_usec()-start)/1000.0)
		await process_frame
		await RenderingServer.frame_post_draw
		wall.append(float(Time.get_ticks_usec()-wall_start)/1000.0)
	cpu.sort(); wall.sort()
	metrics.append({"fixture":label,"requested_enemies":descriptor.count,"live_at_capture":live_at_capture,"stage":stage,"texture":ART.map_texture(stage).resource_path,"tint":ART.map_tint(stage).to_html(false),"cpu_tick_presentation_median_ms":cpu[22],"cpu_tick_presentation_p95_ms":cpu[42],"wall_render_frame_median_ms":wall[22],"wall_render_frame_p95_ms":wall[42],"samples":45,"screenshot":label+".png"})
	view.queue_free()
	await frames()
func step(view: Control) -> void:
	var battle: RefCounted = view.battle
	battle.tick(1.0/60,Vector2.ZERO)
	view._present_messages(battle.events)
	view.canvas.consume_events(battle.events)
	battle.events.clear()
	view.canvas.advance_presentation(1.0/60)
	view.canvas.refresh(false)
	view.refresh()
