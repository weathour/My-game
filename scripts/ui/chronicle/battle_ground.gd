extends RefCounted
## Ground presentation only. Texture size never defines movement or field geometry.
const ART := preload("res://scripts/ui/chronicle/battle_art.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
var baseline := false # Code-only A/B fixture; never a player setting.
var _legacy_patches: Dictionary = {}

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
	if baseline or not ART.has_environment_texture(stage):
		_draw_legacy(painter, stage, origin, scale, visible)
	else:
		var texture := ART.map_texture(stage)
		var base := coverage(texture.get_size())
		# The asset contract allows only flat, traversable ground. Mirroring entire
		# source edges continues that floor outside the actual arena without tiny
		# repeated samples, black borders, or repeated architectural obstacles.
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

func _draw_legacy(painter: CanvasItem, stage: String, origin: Vector2, scale: float, visible: Rect2) -> void:
	var texture := ART.legacy_map_texture(stage)
	var key := texture.resource_path
	if not _legacy_patches.has(key):
		var patch := AtlasTexture.new()
		patch.atlas = texture
		patch.region = Rect2(0,432,64,64)
		_legacy_patches[key] = patch
	var patch: AtlasTexture = _legacy_patches[key]
	var step := patch.region.size * SPACE.SIZE / texture.get_size()
	var first := Vector2i(floor(visible.position / step))
	var last := Vector2i(ceil(visible.end / step))
	for y in range(first.y, last.y):
		for x in range(first.x, last.x):
			var tile := Rect2(Vector2(x,y) * step, step)
			if SPACE.BOUNDS.encloses(tile): continue
			_draw_mirrored(painter, patch, tile, x, y, origin, scale, ART.legacy_map_tint(stage) * Color(.84,.84,.84))
	painter.draw_set_transform(origin, 0, Vector2.ONE * scale)
	painter.draw_texture_rect(texture, SPACE.BOUNDS, false, ART.legacy_map_tint(stage))
