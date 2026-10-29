extends SceneTree
## Captures imported runtime textures at the authored .9 world scale.
const ART := preload("res://scripts/ui/chronicle/battle_art.gd")
var output_dir := "res://design/baimen-women-20261028/combat-evidence/"
var viewport: SubViewport
var stage: Node2D
var sprites: Array[AnimatedSprite2D] = []

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output_dir = arg.trim_prefix("--output=").trim_suffix("/") + "/"
	call_deferred("run")

func label(text: String, point: Vector2, font_size: int = 18) -> void:
	var item := Label.new()
	item.text = text
	item.position = point
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", Color("ddd3b9"))
	stage.add_child(item)

func run() -> void:
	root.size = Vector2i(1120, 1080)
	viewport = SubViewport.new()
	viewport.size = root.size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var container := SubViewportContainer.new()
	root.add_child(container)
	container.add_child(viewport)
	stage = Node2D.new()
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(stage)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(viewport.size)
	backdrop.color = Color("252d2a")
	stage.add_child(backdrop)
	var names := ["蕾娜", "田秀", "钱绮罗", "祝青蘅", "秦雁", "马三娘", "陶小满", "柳晚晴", "陆知微"]
	for col in 4: label(["idle", "run", "attack", "cast"][col], Vector2(230 + col * 190, 15))
	label("head", Vector2(998, 15))
	var row := 0
	for id in ART.WOMEN:
		var ground := 139.0 + row * 112
		label(id + " " + names[row], Vector2(18, ground - 55))
		for col in 4:
			var actor: Node2D = ART.actor(id).instantiate()
			stage.add_child(actor)
			actor.position = Vector2(250 + col * 190, ground)
			actor.scale = Vector2.ONE * .9
			var sprite: AnimatedSprite2D = actor.sprite
			sprite.play([&"idle", &"run", &"attack", &"cast"][col])
			sprite.pause()
			sprites.append(sprite)
		var head: Node2D = ART.portrait(id).instantiate()
		stage.add_child(head)
		head.position = Vector2(1020, ground - 43)
		head.scale = Vector2.ONE * .5
		row += 1
	if not OS.get_cmdline_user_args().has("--capture"): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir + "preview-frames"))
	for frame in 48:
		for sprite in sprites:
			var fps := sprite.sprite_frames.get_animation_speed(sprite.animation)
			sprite.frame = int(frame / 12.0 * fps) % sprite.sprite_frames.get_frame_count(sprite.animation)
		await process_frame
		await RenderingServer.frame_post_draw
		var capture := viewport.get_texture().get_image()
		capture.save_png(output_dir + "preview-frames/%03d.png" % frame)
		if frame == 1: capture.save_png(output_dir + "runtime-preview.png")
	container.queue_free()
	await process_frame
	print("BAIMEN_WOMEN_ART_PREVIEW_OK")
	quit(0)
