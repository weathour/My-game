extends SceneTree
## Reproducible visual review using the imported runtime textures, not mockups.
const VISUAL := preload("res://assets/players/jia/jia.tscn")
const OUT := "res://design/jia-combat-20261027/"
var viewport: SubViewport
var stage: Node2D
var sprites: Array[AnimatedSprite2D] = []

func _init() -> void:
	call_deferred("run")

func label(text: String, point: Vector2, font_size: int = 20) -> void:
	var item := Label.new()
	item.text = text
	item.position = point
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", Color("ddd3b9"))
	stage.add_child(item)

func run() -> void:
	root.size = Vector2i(1280, 820)
	root.title = "Jia Weisuo — combat art"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 820)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var container := SubViewportContainer.new()
	root.add_child(container)
	container.add_child(viewport)
	stage = Node2D.new()
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(stage)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(1280, 820)
	backdrop.color = Color("252d2a")
	stage.add_child(backdrop)
	label("贾苇索 · 草莽 / 战斗动作", Vector2(40, 22), 30)
	label("待机", Vector2(168, 80))
	label("移动", Vector2(480, 80))
	label("攻击", Vector2(790, 80))
	for row in 2:
		for col in 3:
			var actor := VISUAL.instantiate()
			stage.add_child(actor)
			actor.position = Vector2(200 + 310 * col, 300 + 240 * row)
			actor.scale = Vector2.ONE * 2
			var sprite: AnimatedSprite2D = actor.sprite
			sprite.play(("dao-" if row == 0 else "spear-") + ["idle", "run", "attack"][col])
			sprite.pause()
			sprites.append(sprite)
	label("刀", Vector2(40, 205))
	label("枪", Vector2(40, 450))
	var head := Sprite2D.new()
	head.texture = preload("res://assets/players/jia/jia-head.png")
	head.position = Vector2(1120, 196)
	stage.add_child(head)
	label("战斗头像", Vector2(1070, 284))
	for index in 3:
		var sprite := AnimatedSprite2D.new()
		var sheet: Texture2D = load("res://assets/players/jia/vfx-" + ["slash", "thrust", "sweep"][index] + ".png")
		sprite.sprite_frames = SpriteFrames.new()
		sprite.sprite_frames.set_animation_speed("default", 12)
		for frame in 4:
			var texture := AtlasTexture.new()
			texture.atlas = sheet
			texture.region = Rect2(frame * 128, 0, 128, 128)
			sprite.sprite_frames.add_frame("default", texture)
		sprite.position = Vector2(215 + 375 * index, 675)
		sprite.scale = Vector2.ONE * 1.5
		stage.add_child(sprite)
		sprites.append(sprite)
		label(["刀光", "破阵 · 突刺", "横扫"][index], Vector2(155 + 375 * index, 780))
	if not OS.get_cmdline_user_args().has("--capture"): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "preview-frames"))
	for frame in 48:
		for sprite in sprites:
			var fps := sprite.sprite_frames.get_animation_speed(sprite.animation)
			sprite.frame = int(frame / 12.0 * fps) % sprite.sprite_frames.get_frame_count(sprite.animation)
		await process_frame
		await RenderingServer.frame_post_draw
		var capture := viewport.get_texture().get_image()
		capture.save_png(OUT + "preview-frames/%03d.png" % frame)
		if frame == 1: capture.save_png(OUT + "preview.png")
	container.queue_free()
	await process_frame
	print("JIA_ART_PREVIEW_OK")
	quit(0)
