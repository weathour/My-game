extends RefCounted
## Exact source-alpha bounds. Known battle sheets never read pixels back from the GPU.
const DATA_PATH := "res://assets/data/chronicle/battle_sprite_bounds.json"
const MAX_FALLBACK_REGIONS := 256
static var _loaded := false
static var _regions: Dictionary = {}
static var _fallback: Dictionary = {}
static var readbacks := 0
static var readback_usec := 0

static func _load_table() -> void:
	if _loaded: return
	_loaded = true
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not data is Dictionary or int(data.get("version", 0)) != 1:
		push_error("Invalid battle sprite bounds table: " + DATA_PATH)
		return
	for path in data.get("textures", {}):
		var regions: Dictionary = {}
		for raw in data.textures[path].regions:
			var values := str(raw).split(",")
			var key := Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))
			var bounds: Array = data.textures[path].regions[raw]
			regions[key] = Rect2i(int(bounds[0]), int(bounds[1]), int(bounds[2]), int(bounds[3]))
		_regions[path] = regions

static func used_rect(texture: Texture2D, region: Rect2i = Rect2i()) -> Rect2i:
	_load_table()
	var source := texture
	var source_region := region if region.has_area() else Rect2i(Vector2i.ZERO, Vector2i(texture.get_size()))
	# Atlas regions are local to their parent; nonzero margins require the fallback
	# because they add transparent padding to the virtual image.
	while source is AtlasTexture:
		if source.margin != Rect2() or source.atlas == null:
			return _read_fallback(texture, region)
		source_region.position += Vector2i(source.region.position)
		source = source.atlas
	var known: Dictionary = _regions.get(source.resource_path, {})
	if known.has(source_region): return known[source_region]
	return _read_fallback(texture, region)

static func _read_fallback(texture: Texture2D, region: Rect2i) -> Rect2i:
	var key := str(texture.get_instance_id()) + ":" + str(region)
	if _fallback.has(key): return _fallback[key]
	var started := Time.get_ticks_usec()
	var pixels := texture.get_image()
	var result := Rect2i()
	if pixels != null:
		if region.has_area(): pixels = pixels.get_region(region)
		result = pixels.get_used_rect()
	readbacks += 1
	readback_usec += Time.get_ticks_usec() - started
	if _fallback.size() >= MAX_FALLBACK_REGIONS: _fallback.erase(_fallback.keys()[0])
	_fallback[key] = result
	return result
