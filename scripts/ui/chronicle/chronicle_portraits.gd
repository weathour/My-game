extends RefCounted
## Portrait identity is presentation data. Atlas regions never affect character rules.
const EMMA := preload("res://assets/ui/chronicle/emma.png")
const JIA := preload("res://assets/ui/chronicle/cards/jia.png")
const ROOT := "res://assets/ui/chronicle/cards/"
const STANDING_ROOT := "res://assets/ui/chronicle/characters/"
# Source-pixel viewports, composed individually around hair, face and identifying props.
# The independent RGBA masters remain untouched; standing() always returns the full image.
const FRAMING := {
	"F02":{"card":Rect2(260,20,560,760), "dialogue":Rect2(200,20,700,1050)},
	"F03":{"card":Rect2(230,0,600,740), "dialogue":Rect2(220,0,620,1040)},
	"F04":{"card":Rect2(240,24,600,760), "dialogue":Rect2(200,24,680,1040)},
	"F05":{"card":Rect2(220,0,620,800), "dialogue":Rect2(120,0,820,1080)},
	"F06":{"card":Rect2(220,0,660,790), "dialogue":Rect2(160,0,820,1040)},
	"F07":{"card":Rect2(215,0,640,800), "dialogue":Rect2(190,0,740,1060)},
	"F08":{"card":Rect2(235,0,640,800), "dialogue":Rect2(160,0,740,1050)},
	"F09":{"card":Rect2(270,0,620,820), "dialogue":Rect2(160,0,800,1080)},
	"F10":{"card":Rect2(220,0,600,780), "dialogue":Rect2(220,0,580,1040)}
}
static var cache: Dictionary = {}
static var sheets: Dictionary = {}
static var standing_cache: Dictionary = {}
static var dialogue_cache: Dictionary = {}

static func standing(id: String) -> Texture2D:
	if FRAMING.has(id):
		if not standing_cache.has(id): standing_cache[id] = load(STANDING_ROOT + id + "-standing.png")
		return standing_cache[id]
	return JIA if id == "JIA" else texture(id)

static func dialogue(id: String) -> Texture2D:
	if not FRAMING.has(id): return texture(id) if id == "JIA" else standing(id)
	if not dialogue_cache.has(id): dialogue_cache[id] = _framed(id, "dialogue")
	return dialogue_cache[id]

static func card_anchor(id: String) -> Vector2:
	return Vector2(.5, 0.0 if FRAMING.has(id) else .15)

static func _framed(id: String, purpose: String) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = standing(id)
	result.region = FRAMING[id][purpose]
	result.filter_clip = true
	return result

static func texture(id: String) -> Texture2D:
	if id.is_empty(): return null
	if id == "F11": return EMMA
	if cache.has(id): return cache[id]
	if FRAMING.has(id):
		cache[id] = _framed(id, "card")
		return cache[id]
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
