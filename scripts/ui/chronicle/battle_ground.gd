extends RefCounted
## Ground presentation only. Texture size never defines movement or field geometry.
const ART := preload("res://scripts/ui/chronicle/battle_art.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")

static func coverage(texture_size: Vector2) -> Rect2:
	if texture_size.x <= 0 or texture_size.y <= 0: return SPACE.BOUNDS
	var factor := maxf(SPACE.SIZE.x / texture_size.x, SPACE.SIZE.y / texture_size.y)
	var extent := texture_size * factor
	return Rect2((SPACE.SIZE - extent) * .5, extent)

static func visible_world(origin: Vector2, scale: float, viewport_size: Vector2) -> Rect2:
	return Rect2(-origin / scale, viewport_size / scale)

func draw(painter: CanvasItem, stage: String, origin: Vector2, scale: float, viewport_size: Vector2) -> void:
	if scale <= 0: return
	var visible := visible_world(origin, scale, viewport_size)
	var texture := ART.map_texture(stage)
	if texture == null:
		painter.draw_set_transform(origin, 0, Vector2.ONE * scale)
		painter.draw_rect(visible, Color("1d2522"))
		return
	var base := coverage(texture.get_size())
	# Mirror the current flat ground beyond the arena; geometry stays simulation-owned.
	var first := Vector2i(floor((visible.position - base.position) / base.size))
	var last := Vector2i(floor((visible.end - base.position) / base.size))
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var tile := Rect2(base.position + Vector2(x,y) * base.size, base.size)
			_draw_mirrored(painter, texture, tile, x, y, origin, scale, ART.map_tint(stage))
	# Other arena commands continue in exactly the same world transform.
	painter.draw_set_transform(origin, 0, Vector2.ONE * scale)

func _draw_mirrored(painter: CanvasItem, texture: Texture2D, rect: Rect2, x: int, y: int, origin: Vector2, scale: float, tint: Color) -> void:
	var flip := Vector2(-1 if posmod(x,2) else 1, -1 if posmod(y,2) else 1)
	var corner := rect.position + Vector2(rect.size.x if flip.x < 0 else 0, rect.size.y if flip.y < 0 else 0)
	painter.draw_set_transform(origin + corner * scale, 0, flip * scale)
	painter.draw_texture_rect(texture, Rect2(Vector2.ZERO, rect.size), false, tint)
