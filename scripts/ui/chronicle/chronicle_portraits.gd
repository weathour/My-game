extends RefCounted
## Portrait identity is presentation data. Atlas regions never affect character rules.
const EMMA := preload("res://assets/ui/chronicle/emma.png")
const JIA := preload("res://assets/ui/chronicle/cards/jia.png")
const ROOT := "res://assets/ui/chronicle/cards/"
static var cache: Dictionary = {}
static var sheets: Dictionary = {}

static func standing(id: String) -> Texture2D:
	return JIA if id == "JIA" else texture(id)

static func texture(id: String) -> Texture2D:
	if id.is_empty(): return null
	if id == "F11": return EMMA
	if cache.has(id): return cache[id]
	if id == "JIA":
		var portrait := AtlasTexture.new()
		portrait.atlas = JIA
		portrait.region = Rect2(155, 0, 665, 980)
		portrait.filter_clip = true
		cache[id] = portrait
		return portrait
	var sheet := "companions"
	var columns := 4
	var rows := 3
	var index := 0
	if id.begins_with("M"):
		sheet = "named"
		rows = 2
		index = int(id.substr(1)) - 1
	elif id.begins_with("N"):
		var number := int(id.substr(1))
		if number == 17: index = 11
		else:
			sheet = "common"
			columns = 3
			rows = 2
			index = mini(5, (number - 1) / 3)
	elif id.begins_with("F"):
		index = int(id.substr(1))
	if not sheets.has(sheet):
		var path := ROOT + sheet + "-transparent.png"
		if not ResourceLoader.exists(path): return null
		sheets[sheet] = load(path)
	var atlas: Texture2D = sheets[sheet]
	var cell := atlas.get_size() / Vector2(columns, rows)
	var result := AtlasTexture.new()
	result.atlas = atlas
	result.region = Rect2(Vector2(index % columns, index / columns) * cell, cell)
	result.filter_clip = true
	cache[id] = result
	return result

static func tint(id: String) -> Color:
	if not id.begins_with("N"): return Color.WHITE
	return [Color.WHITE, Color("c3d2d5"), Color("d9bea4")][posmod(int(id.substr(1)) - 1, 3)]
