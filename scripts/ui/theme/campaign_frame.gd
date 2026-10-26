extends Node2D

const FRAME := preload("res://assets/ui/campaign/gilded_frame.png")
var variant := "panel"
var _frame: StyleBoxTexture
static var _grain: NoiseTexture2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_frame = StyleBoxTexture.new()
	_frame.texture = FRAME
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_frame.set_texture_margin(side, FRAME.get_width() * 0.24)
	get_parent().resized.connect(queue_redraw)
	if _grain == null:
		var noise := FastNoiseLite.new()
		noise.seed = 413
		noise.frequency = 0.14
		_grain = NoiseTexture2D.new()
		_grain.width = 256
		_grain.height = 256
		_grain.noise = noise
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.03, 0.02, 0.01, 0.08))
		ramp.set_color(1, Color(0.71, 0.53, 0.29, 0.08))
		_grain.color_ramp = ramp
	_grain.changed.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	var host := get_parent() as Control
	if host == null or _frame == null or host.size.x < 2 or host.size.y < 2:
		return
	var corner := 34.0
	if variant == "screen":
		corner = 66.0
	elif variant in ["card", "banner"]:
		corner = 24.0
	elif variant == "button":
		corner = 15.0
	corner = minf(corner, minf(host.size.x, host.size.y) * 0.40)
	var rect := Rect2(Vector2.ZERO, host.size)
	if variant == "panel" and not host is Panel and not host is PanelContainer:
		draw_rect(rect, Color("14241be8"))
	if variant != "screen" and variant != "button":
		draw_texture_rect(_grain, rect.grow(-6.0), false)
	var frame_scale := corner / (FRAME.get_width() * 0.24)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * frame_scale)
	_frame.draw(get_canvas_item(), Rect2(Vector2.ZERO, host.size / frame_scale))
	draw_set_transform(Vector2.ZERO)
