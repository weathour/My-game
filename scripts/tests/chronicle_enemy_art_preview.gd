extends SceneTree
## Actual Godot raster/animation gallery; body scale stays shared within each page.
const CATALOG := preload("res://scripts/content/enemy_catalog.gd")
const CODEX := preload("res://scripts/ui/chronicle/enemy_codex.gd")
const ART := preload("res://scripts/ui/chronicle/battle_art.gd")
const MANIFEST := preload("res://scripts/ui/chronicle/enemy_visual_manifest.gd")
const ENEMY := preload("res://scripts/battle/enemy_runtime.gd")
const T := preload("res://scripts/ui/chronicle/chronicle_theme.gd")
var ids: Array = []
var capture_dir := ""
var dimensions := Vector2i(1280,720)
var three_sizes := false
var viewport: SubViewport
var page: Control
var entries: Array[Dictionary] = []
var failures := 0
var captured := 0
var bounds_reader: Control

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ids="): ids = Array(arg.trim_prefix("--ids=").split(",", false))
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
		if arg == "--three-sizes": three_sizes = true
	if ids.is_empty(): ids = CODEX.all_ids()
	call_deferred("run")

func frames(count: int = 2) -> void:
	for index in count: await process_frame

func run() -> void:
	if not ProjectSettings.globalize_path("user://").begins_with("/tmp/"): push_error("isolated user directory required"); quit(1); return
	bounds_reader = CODEX.new()
	viewport = SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sizes := [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)] if three_sizes else [dimensions]
	for size in sizes:
		viewport.size = size
		var columns := 3 if size.x < 1100 else 4
		var capacity := columns * 2
		var pages := ceili(float(ids.size()) / capacity)
		for index in pages:
			build_page(ids.slice(index * capacity, mini(ids.size(), (index + 1) * capacity)), columns)
			await frames(3)
			var clips: Array = MANIFEST.REQUIRED_CLIPS.duplicate()
			for entry in entries:
				for key in entry.metadata.get("clips", {}):
					if not clips.has(key): clips.append(key)
			for clip in clips:
				var count := 1
				for entry in entries: count = maxi(count, int(entry.metadata.get("clips", {}).get(clip, {}).get("frames", 1)))
				for entry in entries:
					if entry.actor.has_method("_select"): entry.actor._select(clip if entry.metadata.get("clips", {}).has(clip) else "idle", 0.0)
				for frame in count:
					for entry in entries:
						var actual: String = str(clip) if entry.metadata.get("clips", {}).has(clip) else "idle"
						var data: Dictionary = entry.metadata.get("clips", {}).get(actual, {})
						var elapsed := float(frame) / count * int(data.get("frames", 1)) / maxf(1, float(data.get("fps", 10)))
						if entry.actor.has_method("preview"): entry.actor.preview(actual, elapsed)
					await frames()
					await capture("gallery-%d-page%02d-%s-%02d" % [size.x,index,str(clip),frame])
			page.queue_free();await frames()
	viewport.queue_free();bounds_reader.free();await frames()
	print("CHRONICLE_ENEMY_ART_PREVIEW ","PASS" if failures == 0 else "FAIL"," identities=",ids.size()," captured=",captured," failures=",failures)
	quit(0 if failures == 0 else 1)

func build_page(visible_ids: Array, columns: int) -> void:
	entries.clear()
	page = Control.new();page.theme = T.make_theme();viewport.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new();background.color = T.DARK;page.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var header := T.label("白门楼 · 敌人动作图鉴", 24, T.LIGHT, true);header.position = Vector2(16,10);page.add_child(header)
	var cell := Vector2(viewport.size.x / columns, (viewport.size.y - 55) / 2)
	var scale := minf(1, minf((cell.y - 45) / 330.0, (cell.x - 14) / 410.0))
	for index in visible_ids.size():
		var id := str(visible_ids[index]);var definition := CATALOG.definition(id)
		if definition.is_empty(): failures += 1;push_error("unknown identity " + id);continue
		var position := Vector2(index % columns, index / columns) * cell + Vector2(0,55)
		var label := T.label(id + "  " + str(definition.name), 15, T.LIGHT);label.position = position + Vector2(10,4);page.add_child(label)
		var metadata := MANIFEST.resolved(str(definition.visual_id))
		if str(metadata.get("status", "")) != "final": failures += 1;push_error("unfinished identity " + id)
		var runtime: RefCounted = ENEMY.new(index + 1,"melee",Vector2.ZERO);runtime.configure(definition)
		var anchor := Node2D.new();anchor.position = position + Vector2(cell.x * .5,cell.y - 10);anchor.scale = Vector2.ONE * scale;page.add_child(anchor)
		var actor: Node2D = ART.create_enemy(runtime,"B02");anchor.add_child(actor)
		if actor.has_meta("temporary_enemy_art") or (actor.has_method("preview") and actor.sprite.texture == null): failures += 1;push_error("unloaded final raster " + id)
		entries.append({"id":id,"actor":actor,"metadata":metadata,"anchor":anchor})
	# Source weapons and plumes may exceed nominal body width. Fit their complete
	# animation union in each cell with one shared page scale, preserving proportions.
	for entry in entries:
		var definition := CATALOG.definition(str(entry.id))
		var native_bounds: Rect2 = bounds_reader._preview_bounds(str(definition.visual_id))
		if not native_bounds.has_area(): continue
		var world_bounds: Rect2 = entry.actor.transform * native_bounds
		var horizontal := maxf(absf(world_bounds.position.x),absf(world_bounds.end.x))
		var vertical := maxf(absf(world_bounds.position.y),absf(world_bounds.end.y))
		scale = minf(scale, minf((cell.x * .5 - 8) / maxf(1,horizontal),(cell.y - 45) / maxf(1,vertical)))
	for entry in entries: entry.anchor.scale = Vector2.ONE * scale

func capture(label: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	viewport.get_texture().get_image().save_png(capture_dir.path_join(label + ".png"))
	captured += 1
