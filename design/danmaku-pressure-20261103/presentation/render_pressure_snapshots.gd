extends SceneTree
## Reconstructs captured real-session state for render inspection only. Never
## spawns a designed bullet pattern or advances the restored combat simulation.
const VIEW := preload("res://scripts/ui/chronicle/battle_view.gd")
const HURTBOX := preload("res://scripts/battle/player_hurtbox.gd")
const METRICS := preload("res://design/danmaku-pressure-20261103/presentation/pressure_render_metrics.gd")
var inputs: Array[String] = []
var only_stages := "B01,B12,B15,B16,B17,B18"
var all_metrics := false
var all_sizes := false
var capture_dir := "/tmp/danmaku-real-pressure"
var viewport: SubViewport
var checks := 0
var failures := 0
var reports: Array = []

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--input="): inputs.append(arg.trim_prefix("--input="))
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
		if arg.begins_with("--stages="): only_stages = arg.trim_prefix("--stages=")
		if arg == "--all-metrics": all_metrics = true
		if arg == "--all-sizes": all_sizes = true
	call_deferred("run")

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func frames(count: int = 3) -> void:
	for index in count: await process_frame

func decode(value: Variant) -> Variant:
	if value is Dictionary:
		if value.has("$vector2"): return Vector2(value["$vector2"][0], value["$vector2"][1])
		var result := {}
		for key in value: result[key] = decode(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value: result.append(decode(item))
		return result
	return value

func assign_state(target: Object, state: Dictionary, excluded: Array = []) -> void:
	var fields := {}
	for property in target.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE: fields[str(property.name)] = int(property.type)
	for key in state:
		if key in excluded or not fields.has(str(key)): continue
		var value: Variant = state[key]
		if fields[str(key)] == TYPE_INT: value = int(value)
		elif fields[str(key)] == TYPE_FLOAT: value = float(value)
		target.set(str(key), value)

func restore(view: Control, saved: Dictionary) -> void:
	var state: Dictionary = saved.state
	var battle: RefCounted = view.battle
	battle.enemies.clear()
	assign_state(battle, state, ["enemies","characters","director","director_elapsed","boss_spawned","field","kills"])
	for member in state.get("characters", {}):
		if battle.characters.has(member): assign_state(battle.characters[member], state.characters[member])
	var bodies := {}
	for enemy_state in state.enemies:
		var enemy: RefCounted = battle.director.spawn(str(enemy_state.definition_id), enemy_state.position)
		expect(enemy != null, "snapshot source definition exists")
		if enemy == null: continue
		assign_state(enemy, enemy_state, ["hp_owner"])
		battle.enemies.append(enemy)
		bodies[int(enemy.id)] = enemy
	for enemy in battle.enemies:
		if enemy.hp_owner_id != enemy.id and bodies.has(enemy.hp_owner_id): enemy.hp_owner = bodies[enemy.hp_owner_id]
	battle.director.elapsed = float(state.get("director_elapsed", state.get("elapsed", 0)))
	for key in ["boss_spawned","field","kills"]:
		if state.has(key): battle.director.set(key, state[key])
	if state.has("director"): assign_state(battle.director, state.director, ["rng"])
	battle.events.clear()

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "snapshot render player data isolated")
	expect(not inputs.is_empty(), "provide real probe snapshot --input files")
	if failures: quit(1); return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var definitions := {}
	for person in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/chronicle/characters.json")): definitions[person.id] = person
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var serial := 0
	for input in inputs:
		expect(FileAccess.file_exists(input), "real snapshot file exists " + input)
		if not FileAccess.file_exists(input): continue
		var document: Dictionary = decode(JSON.parse_string(FileAccess.get_file_as_string(input)))
		for saved in document.get("snapshots", []):
			if str(saved.stage) not in only_stages.split(","): continue
			var metric := str(saved.get("provenance",{}).get("metric", ""))
			if not all_metrics:
				if str(saved.stage) in ["B01","B05","B12"] and metric != "density": continue
				if str(saved.stage) not in ["B01","B05","B12"] and metric not in ["area","bullet"]: continue
			serial += 1
			var view := VIEW.new()
			var request: Dictionary = saved.request.duplicate(true)
			if not request.has("node"): request.node = {"id":saved.stage,"name":saved.stage}
			view.setup(request, definitions)
			restore(view, saved)
			viewport.add_child(view)
			view.set_physics_process(false)
			# Silent rendering still routes genuine snapshot visual state. No audio
			# events are manufactured and no combat tick is called after restoration.
			view.canvas.combat_feedback.audio.enabled = false
			await frames()
			var battle: RefCounted = view.battle
			var fixed_time: float = battle.director.elapsed
			var fixed_projectiles: Array = battle.projectiles.duplicate(true)
			var sizes: Array[Vector2i] = [Vector2i(1280,720)]
			if all_sizes or str(saved.stage) == "B18": sizes = [Vector2i(960,600),Vector2i(1280,720),Vector2i(1920,1080)]
			for dimensions in sizes:
				viewport.size = dimensions
				await frames(4)
				view._layout_hud()
				view.canvas.camera.initialized = false
				view.refresh()
				view.canvas.refresh(false)
				# Advance presentation only, settling composition around the captured
				# dangerous instant without aging bullets or hazards by a single tick.
				for step in 60:
					view.canvas.advance_presentation(1.0 / 60)
					view.canvas.refresh(false)
				expect(battle.director.elapsed == fixed_time and battle.projectiles == fixed_projectiles, "snapshot rendering never advances combat")
				var camera: Dictionary = view.canvas.camera_state()
				var hit: Dictionary = view.canvas.controlled_hurtbox()
				expect(hit.center == battle.position and hit.radius == HURTBOX.RADIUS, "real snapshot red core shares collision")
				var label := "real-%s-%s-%02d-%d" % [str(saved.stage),metric,serial,dimensions.x]
				var bodies: Array = []
				for enemy in battle.enemies:
					if enemy.rank == "boss": bodies.append({"definition_id":enemy.definition_id,"form_index":enemy.form_index,"move_id":str(enemy.current_action.get("id",enemy.attack)),"state":enemy.state})
				reports.append({"label":label,"source_file":input,"source_provenance":saved.get("provenance",{}),"stage":saved.stage,"dimensions":str(dimensions),"seconds":fixed_time,"enemies":battle.enemies.size(),"projectiles":battle.projectiles.size(),"bosses":bodies,"coverage":METRICS.coverage(battle,camera),"camera_scale":camera.scale,"controlled_red_screen_radius":hit.radius*camera.scale,"world_visible_size":str(camera.bounds.size),"escape_valid":camera.escape_valid})
				await frames()
				if DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					var image := viewport.get_texture().get_image()
					image.save_png(capture_dir.path_join(label + ".png"))
			view.queue_free()
			await frames()
	expect(serial > 0, "at least one actual simulation snapshot rendered")
	var report := FileAccess.open(capture_dir.path_join("real-pressure-render.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"scope":"real data/core simulation snapshots; view restoration only; phase fixture provenance retained; no campaign reachability claim","checks":checks,"failures":failures,"snapshots":reports},"\t"))
	viewport.queue_free()
	await frames()
	print("REAL_PRESSURE_RENDER ","PASS" if failures == 0 else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
