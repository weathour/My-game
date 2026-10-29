extends SceneTree
## Read-only art review. Composites originals in Godot; never rewrites source PNGs.
const BASE := "res://design/baimen-women-20261028/"
const UI_FONT := preload("res://scripts/ui/theme/survivors_ui_theme.gd")
var viewport: SubViewport
var painter: Node2D
var people: Array = []
var textures: Array = []
var mode := "light"
var output_dir := BASE

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output_dir = arg.trim_prefix("--output=")
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	people = JSON.parse_string(FileAccess.get_file_as_string(BASE + "manifest.json")).characters
	for person in people:
		var source := Image.new()
		var source_error := source.load_png_from_buffer(FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(BASE + person.path)))
		if source_error != OK or source.is_empty(): push_error("Missing source " + person.id); quit(1); return
		textures.append(ImageTexture.create_from_image(source))
	viewport = SubViewport.new()
	viewport.size = Vector2i(1800, 2400)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	painter = Node2D.new()
	viewport.add_child(painter)
	painter.draw.connect(draw_review)
	for backdrop in ["light", "dark", "checker"]:
		mode = backdrop
		painter.queue_redraw()
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		var error := viewport.get_texture().get_image().save_png(output_dir.path_join("preview-" + mode + ".png"))
		if error != OK: push_error("Preview save failed"); quit(1); return
	print("BAIMEN_ART_PREVIEW_OK")
	quit()

func draw_review() -> void:
	var font: Font = UI_FONT.get_reading_font()
	painter.draw_rect(Rect2(0, 0, 1800, 2400), Color("e4dfd4"))
	painter.draw_string(font, Vector2(36, 56), "白门楼 · 九位人物母版", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("23392e"))
	painter.draw_string(font, Vector2(36, 91), "首轮造型 · 制作基础 · " + {"light":"浅米底", "dark":"深绿底", "checker":"棋盘底"}[mode], HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("5b6d60"))
	for i in people.size():
		var at := Vector2(36 + (i % 3) * 584, 118 + (i / 3) * 748)
		var bounds := Rect2(at, Vector2(560, 728))
		var dark: bool = mode == "dark"
		painter.draw_rect(bounds, Color("183b31") if dark else Color("f5f0e5"))
		var image_box := Rect2(at + Vector2(12, 61), Vector2(536, 650))
		if mode == "checker":
			for y in 28:
				for x in 23:
					var tile := Rect2(image_box.position + Vector2(x * 24, y * 24), Vector2(24, 24)).intersection(image_box)
					if tile.has_area(): painter.draw_rect(tile, Color("d1d5c9") if (x + y) % 2 == 0 else Color("eeeae0"))
		var texture: Texture2D = textures[i]
		var extent: Vector2 = texture.get_size() * minf(image_box.size.x / texture.get_width(), image_box.size.y / texture.get_height())
		painter.draw_texture_rect(texture, Rect2(image_box.position + (image_box.size - extent) * .5, extent), false)
		painter.draw_string(font, at + Vector2(18, 34), people[i].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color("f1e7d3") if dark else Color("23392e"))
		painter.draw_string(font, at + Vector2(180, 32), people[i].id + " · " + people[i].role, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("b6c7b9") if dark else Color("657461"))
		painter.draw_rect(bounds, Color("a0ab9b"), false, 1)
	painter.draw_string(font, Vector2(36, 2390), "背景与姓名仅用于审看；人物源图为独立 RGBA PNG。", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("5b6d60"))
