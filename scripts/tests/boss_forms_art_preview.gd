extends SceneTree
const ACTOR := preload("res://scripts/ui/chronicle/enemy_actor.gd")
const MANIFEST := preload("res://scripts/ui/chronicle/enemy_visual_manifest.gd")
const PORTRAITS := preload("res://scripts/ui/chronicle/chronicle_portraits.gd")
const ART := preload("res://scripts/ui/chronicle/battle_art.gd")
const PAIRS := [["B18_human","B18","M01"],["B17_human","B17","M02"],["B15_human","B15","M06"],["B16_human","B16","M05"],["M03_human","M03_WAR","M03"],["M04_human","M04_WAR","M04"]]
const OUTPUT := "res://design/boss-forms-20261029/evidence/"
var sheet: Node2D
var gallery: SubViewport
var actors: Array[Node2D] = []

func _initialize() -> void:
	call_deferred("run")

func label_at(value: String, position: Vector2, size: int = 23) -> void:
	var label := Label.new()
	label.text = value
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	sheet.add_child(label)

func run() -> void:
	var errors := MANIFEST.validate_final(PAIRS.map(func(pair): return pair[0]))
	assert(errors.is_empty(), str(errors))
	root.size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	sheet = Node2D.new()
	gallery = SubViewport.new()
	gallery.size = Vector2i(1920,1080)
	gallery.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(gallery)
	gallery.add_child(sheet)
	var bg := ColorRect.new()
	bg.color = Color("18252b")
	bg.size = Vector2(1920,1080)
	sheet.add_child(bg)
	for i in PAIRS.size():
		var origin := Vector2((i % 3) * 640, (i / 3) * 540)
		var back := ColorRect.new()
		back.position = origin + Vector2(8,8)
		back.size = Vector2(624,524)
		back.color = Color("253840") if i % 2 == 0 else Color("31434a")
		sheet.add_child(back)
		label_at(str(PAIRS[i][0]) + " / " + str(PAIRS[i][1]), origin + Vector2(24,18))
		label_at("human 130 / war 200 / ally 72", origin + Vector2(24,51), 18)
		label_at("card view",origin+Vector2(500,246),16)
		for j in 2:
			var actor := ACTOR.new()
			actor.setup(PAIRS[i][j])
			actor.position = origin + Vector2(135 if j == 0 else 425,475)
			actor.scale = Vector2.ONE * (130.0 if j == 0 else 200.0) / actor.body_profile().x
			sheet.add_child(actor)
			actors.append(actor)
		var head := Sprite2D.new()
		head.texture = PORTRAITS.texture(PAIRS[i][2])
		head.position = origin + Vector2(550,163)
		head.scale = Vector2.ONE * minf(120.0 / head.texture.get_width(),155.0 / head.texture.get_height())
		sheet.add_child(head)
		var ally: Node2D = ART.actor(PAIRS[i][2]).instantiate()
		sheet.add_child(ally)
		ART.fit_actor(ally, PAIRS[i][2], false)
		ally.position = origin + Vector2(60,475)
		ally.set_moving(false,Vector2.RIGHT)
		var line := Line2D.new()
		line.points = PackedVector2Array([origin+Vector2(20,476),origin+Vector2(615,476)])
		line.width = 1
		line.default_color = Color("8ba2a7")
		sheet.add_child(line)
	for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		gallery.size = size
		sheet.scale = Vector2.ONE * float(size.x) / 1920.0
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		gallery.get_texture().get_image().save_png(OUTPUT+"forms-%d.png" % size.x)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT+"frames"))
	var clips := ["idle","move","attack","special","hit","death"]
	for frame in 36:
		var clip: String = clips[frame / 6]
		for actor in actors:
			actor.preview(clip, float(frame % 6) / 12.0)
			actor.sprite.flip_h = frame % 6 >= 3
		await process_frame
		await RenderingServer.frame_post_draw
		gallery.get_texture().get_image().save_png(OUTPUT+"frames/%03d.png" % frame)
	print("BOSS_FORMS_ART_PREVIEW PASS 6 pairs / 3 sizes / 36 animation samples")
	quit()
