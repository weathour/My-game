extends Node2D
## Portrait crop for a friendly warrior, sourced from that warrior's enemy portrait.
const ROOT := "res://assets/enemies/baimen/"

@export var human_id := "B18_human"

func _ready() -> void:
	var manifest_path := ROOT + human_id + "/manifest.json"
	if not FileAccess.file_exists(manifest_path):
		push_error("Missing human portrait manifest: " + manifest_path)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		push_error("Invalid human portrait manifest: " + manifest_path)
		return
	var data: Dictionary = parsed
	var portrait_name := str(data.get("portrait", {}).get("file", "portrait.png"))
	var portrait := load(ROOT + human_id + "/" + portrait_name) as Texture2D
	if portrait == null:
		push_error("Missing human portrait: " + human_id)
		return
	var region: Array = data.get("head_rect_px", [])
	var rect: Rect2
	if region.size() == 4:
		rect = Rect2(float(region[0]), float(region[1]), float(region[2]), float(region[3]))
	else:
		# Until a reviewer records a tighter face crop, use the centered upper portrait.
		rect = Rect2(portrait.get_width() * 0.25, 0, portrait.get_width() * 0.5, portrait.get_height() * 0.42)
	var crop := AtlasTexture.new()
	crop.atlas = portrait
	crop.region = rect
	$Sprite2D.texture = crop
