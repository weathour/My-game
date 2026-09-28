extends SceneTree

const BLINDNESS := preload("res://scripts/player/player_blindness.gd")
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 480)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2(-2000, -2000), Vector2(2000, -2000), Vector2(2000, 2000), Vector2(-2000, 2000)])
	background.color = Color.WHITE
	background.z_index = 100
	viewport.add_child(background)
	var player := Node2D.new()
	player.position = Vector2(320, 240)
	viewport.add_child(player)
	var effect = BLINDNESS.ensure_effect(player)
	effect.set_process(false)
	effect.try_apply()
	var hud := CanvasLayer.new()
	hud.layer = 1
	viewport.add_child(hud)
	var badge := ColorRect.new()
	badge.size = Vector2(25, 25)
	badge.color = Color.RED
	hud.add_child(badge)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	_check(image.get_pixel(320, 240).r > 0.9, "player center visible")
	_check(image.get_pixel(370, 240).r > 0.9, "inside radius 60 visible")
	_check(image.get_pixel(390, 240).r < 0.05, "outside radius 60 black, including high z enemies")
	_check(image.get_pixel(10, 10).r > 0.9 and image.get_pixel(10, 10).g < 0.05, "HUD above mask")
	image.save_png(OS.get_environment("TEMP").path_join("player_blindness_render.png"))
	viewport.canvas_transform = Transform2D(Vector2(0.5, 0), Vector2(0, 0.5), Vector2(160, 120))
	player.position = Vector2(360, 240)
	effect._sync_mask()
	await process_frame
	await RenderingServer.frame_post_draw
	image = viewport.get_texture().get_image()
	_check(image.get_pixel(365, 240).r > 0.9, "zoomed visible radius follows player")
	_check(image.get_pixel(380, 240).r < 0.05, "zoom preserves world radius")
	effect.remaining = 0.0
	effect._sync_mask()
	await process_frame
	await RenderingServer.frame_post_draw
	image = viewport.get_texture().get_image()
	_check(image.get_pixel(600, 400).r > 0.9, "expiry reveals world")
	viewport.queue_free()
	await process_frame
	if failures.is_empty():
		print("PLAYER_BLINDNESS_RENDER_SMOKE_OK")
		quit(0)
	else:
		for message in failures:
			push_error(message)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
