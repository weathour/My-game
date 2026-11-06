extends SceneTree
## Real imported actor scenes, actual cast adapter and exact battle hurtbox painter.
## Static evidence only. No save, audio, enemy AI, release export or gameplay changes.
const ART := preload("res://scripts/ui/chronicle/battle_art.gd")
const C := preload("res://scripts/content/combat_catalog.gd")
const PRESENTATION := preload("res://scripts/ui/chronicle/skill_presentation.gd")
const CANVAS := preload("res://scripts/ui/chronicle/battle_canvas.gd")
const OUT := "res://design/skill-presentation-20261105/art-preview/"
const SIZES := [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]
const ROWS_PER_PAGE := 3
const MANUAL_REPRESENTATIVES := {"F05":"F05_spread","F07":"bandit_sweep","F08":"F08_break"}
const ACTIONS := ["idle", "move", "basic", "manual"]
var gallery: SubViewport
var stage: Node2D
var marker_adapter: Control
var records: Dictionary = {}
var warnings: Array = []
var failures: Array = []
var captures: Array = []
var only_ready := false
var ids: Array[String] = []
var cast_serial := 0

class HurtboxFixture:
	extends RefCounted
	var position := Vector2.ZERO
	var outcome := ""

class CoreMarker:
	extends Node2D
	var adapter: Control
	func _draw() -> void:
		adapter._draw_controlled_hurtbox(self)

func _initialize() -> void:
	only_ready = OS.get_cmdline_user_args().has("--ready-only")
	call_deferred("run")

func text(value: String, point: Vector2, font_size: int = 15) -> void:
	var item := Label.new()
	item.text = value
	item.position = point
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", Color("eee1c4"))
	stage.add_child(item)

func preflight() -> Array[String]:
	var missing: Array[String] = []
	for id in C.IDS:
		if ART.ROSTER.has(id):
			var path := "res://assets/players/chronicle-cast/%s/manifest.json" % id
			if not FileAccess.file_exists(path): missing.append(id); continue
			var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if not manifest is Dictionary: missing.append(id); continue
			var valid := true
			for clip in manifest.get("clips", {}).values():
				var png := "res://assets/players/chronicle-cast/%s/%s" % [id,clip.get("file", "")]
				if not FileAccess.file_exists(png) or not FileAccess.file_exists(png + ".import"): valid = false
			if not valid: missing.append(id); continue
		ids.append(id)
	return missing

func effect_for(id: String, manual: bool, direction: Vector2) -> Dictionary:
	var kit := C.definition(id)
	var ability: Resource = kit.basic
	if manual and not kit.manual.is_empty():
		ability = kit.manual[0]
		if MANUAL_REPRESENTATIVES.has(id):
			for candidate in kit.manual:
				if str(candidate.id) == str(MANUAL_REPRESENTATIVES[id]): ability = candidate
	cast_serial += 1
	return PRESENTATION.decorated({"source":id,"ability":str(ability.id),"ability_kind":ability.kind,
		"direction":direction,"manual":manual,"cast":cast_serial,"presentation_id":str(cast_serial)})

func apply_action(actor: Node2D, id: String, action: String, direction: Vector2) -> Dictionary:
	actor.set_moving(action == "move", direction)
	if action in ["basic", "manual"]:
		var effect := effect_for(id, action == "manual", direction)
		actor.present_cast(effect)
		if action == "manual" and MANUAL_REPRESENTATIVES.has(id) and actor.sprite.animation != &"attack":
			failures.append(id+" NOVA representative must retain authored attack clip: "+String(actor.sprite.animation))
		return {"ability":effect.ability,"motion":effect.profile.motion,"manual":action == "manual"}
	return {"ability":"","motion":action,"manual":false}

func inspect_frames(actor: Node2D, id: String) -> void:
	var sprite: AnimatedSprite2D = actor.sprite
	var item := {"scene":ART.actor(id).resource_path,"root_scale":actor.scale.x,"world_reference_body_height":72,
		"foot_root":[0,0],"hurtbox_relative_center":[0,-36],"hurtbox_radius":4,"clips":{},"runtime":{}}
	for clip in sprite.sprite_frames.get_animation_names():
		var count := sprite.sprite_frames.get_frame_count(clip)
		var bounds: Array = []
		for frame in count:
			var texture := sprite.sprite_frames.get_frame_texture(clip,frame)
			if texture == null: failures.append("%s/%s/%d missing texture" % [id,clip,frame]); continue
			var image := texture.get_image()
			var rect := image.get_used_rect()
			if not rect.has_area(): failures.append("%s/%s/%d empty texture" % [id,clip,frame]); continue
			if rect.position.x == 0 or rect.position.y == 0 or rect.end.x == image.get_width() or rect.end.y == image.get_height():
				warnings.append("%s/%s/%d opaque touches authored frame edge" % [id,clip,frame])
			var world := Rect2((Vector2(rect.position)-Vector2(image.get_size())*.5+sprite.position+sprite.offset)*actor.scale,
				Vector2(rect.size)*actor.scale)
			bounds.append({"frame":frame,"texture_size":[image.get_width(),image.get_height()],
				"world_bounds":[world.position.x,world.position.y,world.size.x,world.size.y],"world_bottom":world.end.y})
		item.clips[String(clip)] = {"frames":count,"fps":sprite.sprite_frames.get_animation_speed(clip),"all_frames_read":bounds}
	records[id] = item

func make_page(page: int, direction: Vector2) -> Array:
	stage = Node2D.new()
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gallery.add_child(stage)
	var background := ColorRect.new()
	background.size = Vector2(960,540)
	background.color = Color("263331")
	stage.add_child(background)
	text("ROSTER ACTOR SCENES  /  72 world units  /  " + ("LEFT" if direction.x < 0 else "RIGHT") + "  /  page %d" % (page+1),Vector2(15,8),17)
	text("ID",Vector2(16,37),14)
	for col in 4: text(ACTIONS[col],Vector2(193+col*194,37),14)
	var instances: Array = []
	for row in ROWS_PER_PAGE:
		var index := page*ROWS_PER_PAGE+row
		if index >= ids.size(): break
		var id := ids[index]
		var ground := 184.0+row*150
		text(id,Vector2(18,ground-57),18)
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(92,ground),Vector2(950,ground)])
		line.width = 1
		line.default_color = Color("6e8172")
		stage.add_child(line)
		for col in 4:
			var actor: Node2D = ART.actor(id).instantiate()
			stage.add_child(actor)
			ART.fit_actor(actor,id,ACTIONS[col] == "move")
			actor.position = Vector2(223+col*194,ground)
			actor.modulate = ART.tint(id)
			if not records.has(id): inspect_frames(actor,id)
			var details := apply_action(actor,id,ACTIONS[col],direction)
			actor.set_process(false)
			actor.sprite.pause()
			var marker := CoreMarker.new()
			marker.adapter = marker_adapter
			marker.position = actor.position
			marker.z_index = 20
			stage.add_child(marker)
			instances.append({"id":id,"action":ACTIONS[col],"actor":actor,"details":details,
				"root_position":actor.position,"home":actor.action.home,"seen":{},"max_local_world_displacement":0.0})
	return instances

func runtime_progress(instances: Array, direction: Vector2) -> void:
	for item in instances:
		var actor: Node2D = item.actor
		actor.set_process(true)
		actor.sprite.play()
		item.started_clip = String(actor.sprite.animation)
		item.start_frame = actor.sprite.frame
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec()-started < 1650:
		await process_frame
		for item in instances:
			var actor: Node2D = item.actor
			var sprite: AnimatedSprite2D = actor.sprite
			var clip := String(sprite.animation)
			var key := "%s:%d" % [clip,sprite.frame]
			item.seen[key] = true
			item.max_local_world_displacement = maxf(item.max_local_world_displacement,sprite.position.distance_to(item.home)*actor.scale.x)
			if actor.position != item.root_position: failures.append(item.id+" foot/root moved during presentation")
	for item in instances:
		var actor: Node2D = item.actor
		actor.set_process(false)
		actor.sprite.pause()
		var expected_flip := direction.x < 0
		var authored_left := false
		if actor.get("manifest") is Dictionary: authored_left = bool(actor.manifest.get("faces_left",false))
		if actor.sprite.flip_h != (expected_flip != authored_left): failures.append(item.id+" facing mismatch")
		if item.max_local_world_displacement > 2.01: failures.append(item.id+" followthrough exceeds 2 world px")
		var observed: Array = item.seen.keys(); observed.sort()
		var declared_anchor_error := Vector2.ZERO
		if actor.get("manifest") is Dictionary:
			var manifest: Dictionary = actor.manifest
			var anchor: Array = manifest.get("anchor_px",[96,176])
			var dimensions: Array = manifest.clips.idle.frame_size
			var authored := Vector2(float(anchor[0])-float(dimensions[0])*.5,float(anchor[1])-float(dimensions[1])*.5)
			if actor.sprite.flip_h: authored.x *= -1
			declared_anchor_error = (actor.sprite.position+actor.sprite.offset+authored)*actor.scale
			if declared_anchor_error.length() > .01: failures.append(item.id+" declared foot anchor drift under mirror "+str(declared_anchor_error))
		var runtime := {"declared_foot_anchor_error_world":[declared_anchor_error.x,declared_anchor_error.y],"action":item.action,"direction":"left" if direction.x < 0 else "right","started_clip":item.started_clip,
			"started_frame":item.start_frame,"observed_frames":observed,"max_sprite_displacement_world":item.max_local_world_displacement,
			"foot_root_stable":actor.position == item.root_position,"details":item.details}
		if item.action in ["basic","manual"] and actor.attacking: failures.append(item.id+" action did not return to locomotion")
		if item.action == "move":
			var count: int = actor.sprite.sprite_frames.get_frame_count(item.started_clip)
			var visited := 0
			for i in count:
				if item.seen.has("%s:%d" % [item.started_clip,i]): visited += 1
			runtime.full_loop_frames_observed = visited
			if visited != count: failures.append(item.id+" move did not traverse all frames")
		records[item.id].runtime[item.action+"_"+runtime.direction] = runtime

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var missing := preflight()
	FileAccess.open(OUT+"preflight.json",FileAccess.WRITE).store_string(JSON.stringify({"status":"ready" if missing.is_empty() else "waiting_for_imported_art","missing_ids":missing,"ready_ids":ids,"roster_count":C.IDS.size()},"\t"))
	if not missing.is_empty() and not only_ready:
		var report := {"status":"waiting_for_imported_art","missing_ids":missing,"ready_ids":ids,"roster_count":C.IDS.size()}
		FileAccess.open(OUT+"preflight.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
		print("ROSTER_ART_PREVIEW_WAITING ",str(missing))
		quit(2); return
	root.size = Vector2i(960,540)
	root.title = "Roster art actual scene QA"
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	gallery = SubViewport.new()
	gallery.size = Vector2i(960,540)
	gallery.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(gallery)
	marker_adapter = CANVAS.new()
	marker_adapter.battle = HurtboxFixture.new()
	marker_adapter.world_scale = 1.0
	marker_adapter.origin = Vector2.ZERO
	for side in 2:
		var direction := Vector2.RIGHT if side == 0 else Vector2.LEFT
		for page in ceili(ids.size()/float(ROWS_PER_PAGE)):
			var instances := make_page(page,direction)
			for size in SIZES:
				gallery.size = size
				stage.scale = Vector2.ONE*float(size.x)/960.0
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				var filename := "roster-%d-%s-page%02d.png" % [size.x,"right" if side == 0 else "left",page+1]
				var error := gallery.get_texture().get_image().save_png(OUT+filename)
				if error != OK: failures.append("capture failed: "+filename)
				captures.append(filename)
			stage.scale = Vector2.ONE
			await runtime_progress(instances,direction)
			stage.queue_free()
			await process_frame
	marker_adapter.free()
	var report := {"status":"pass" if failures.is_empty() and missing.is_empty() else ("partial_ready_subset" if failures.is_empty() else "fail"),
		"roster_count":C.IDS.size(),"reviewed_count":ids.size(),"pending_ids":missing,"renderer":"native gl_compatibility actual imported actor PackedScenes",
		"manual_representatives":MANUAL_REPRESENTATIVES,"sizes":[[960,540],[1280,720],[1920,1080]],"directions":["right","left"],"captures":captures,"characters":records,
		"warnings":warnings,"failures":failures,"limits":["Static actor scene gallery; not an integrated battle gameplay test.","All authored clip frames read; actual move loops and cast-to-locomotion advance observed.","User aesthetic acceptance is not inferred from technical checks."]}
	FileAccess.open(OUT+"runtime-art-qa.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ROSTER_ART_PREVIEW ",report.status," characters=",ids.size()," captures=",captures.size()," warnings=",warnings.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
