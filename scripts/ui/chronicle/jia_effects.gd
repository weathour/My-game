extends RefCounted
## Authored effect strips with transparent gutters excluded from world sizing.
const SHEETS := {
	"slash":preload("res://assets/players/jia/vfx-slash.png"),
	"thrust":preload("res://assets/players/jia/vfx-thrust.png"),
	"sweep":preload("res://assets/players/jia/vfx-sweep.png"),
}
var frames: Dictionary = {}

func _init() -> void:
	for key in SHEETS:
		var sheet: Texture2D = SHEETS[key]
		var source := sheet.get_image()
		var union := Rect2i()
		for i in 4:
			var used := source.get_region(Rect2i(i * 128, 0, 128, 128)).get_used_rect()
			union = used if i == 0 else union.merge(used)
		var clip: Array[Texture2D] = []
		for i in 4:
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(Vector2i(i * 128, 0) + union.position, union.size)
			clip.append(frame)
		frames[key] = clip

func texture(effect: Dictionary) -> Texture2D:
	var key := "sweep" if effect.kind == "ring" else "thrust" if effect.get("narrow", false) else "slash"
	var index := mini(3, int(clampf(1.0 - effect.life / .22, 0.0, 1.0) * 4))
	return frames[key][index]
