extends SceneTree
## Compare precomputed geometry to imported images, including atlas/region paths.
const BOUNDS := preload("res://scripts/ui/chronicle/battle_sprite_bounds.gd")
var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BOUNDS.DATA_PATH))
	var initial_reads: int = BOUNDS.readbacks
	# Every shipped sheet and every animation cell is checked against Godot's
	# imported image, so alpha/import differences cannot silently alter framing.
	for path in parsed.textures:
		var texture := load(path) as Texture2D
		expect(texture != null, "Missing imported battle sheet: " + path)
		if texture == null: continue
		var pixels := texture.get_image()
		for raw in parsed.textures[path].regions:
			var values := str(raw).split(",")
			var region := Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))
			var actual := pixels.get_region(region).get_used_rect()
			expect(BOUNDS.used_rect(texture, region) == actual, "Imported alpha bounds differ: %s %s" % [path, raw])
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(region)
			expect(BOUNDS.used_rect(atlas) == actual, "Atlas alpha bounds differ: %s %s" % [path, raw])
			var nested := AtlasTexture.new()
			nested.atlas = atlas
			nested.region = Rect2(Vector2.ZERO, Vector2(region.size))
			expect(BOUNDS.used_rect(nested) == actual, "Nested atlas alpha bounds differ: %s %s" % [path, raw])
	expect(BOUNDS.readbacks == initial_reads, "Known art must never fall back to runtime pixel readback")
	# Unknown procedural images still retain exact bounds and reuse their result.
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(3, 4, 5, 7), Color.WHITE)
	var dynamic := ImageTexture.create_from_image(image)
	expect(BOUNDS.used_rect(dynamic) == Rect2i(3, 4, 5, 7), "Procedural fallback bounds")
	expect(BOUNDS.used_rect(dynamic) == Rect2i(3, 4, 5, 7), "Cached procedural fallback bounds")
	expect(BOUNDS.readbacks == initial_reads + 1, "Procedural fallback must read pixels only once")
	print("CHRONICLE_SPRITE_BOUNDS_SMOKE_", "OK" if failures == 0 else "FAILED", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
