extends "res://assets/players/jia/jia_visual.gd"
## Approved campaign costume; body/foot scale and combat controller remain shared.
const ROOT := "res://assets/players/jia-campaign/"
var manifest: Dictionary = {}

func _ready() -> void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
	if not parsed is Dictionary:
		push_error("Missing Jia campaign art manifest")
		return
	manifest=parsed
	super._ready()

func clip_specifications() -> Array:
	var result: Array=[]
	for kind in ["dao","spear"]:
		for motion in ["idle","run","attack","sweep","break"]:
			var key: String=str(kind)+"-"+str(motion)
			var clip: Dictionary=manifest.get("clips",{}).get(key,{})
			var texture:=load(ROOT+str(clip.get("file",key+".png"))) as Texture2D
			result.append([StringName(key),texture,int(clip.get("frames",0)),float(clip.get("fps",11.0)),motion in ["idle","run"]])
	return result

func frame_size(clip: StringName) -> Vector2i:
	var dimensions: Array=manifest.get("clips",{}).get(String(clip),{}).get("frame_size",manifest.get("frame_size",[256,256]))
	return Vector2i(int(dimensions[0]),int(dimensions[1]))

func configure_sprite() -> void:
	var anchor: Array=manifest.get("anchor_px",[128,236])
	var dimensions:=frame_size(&"dao-idle")
	sprite.position=Vector2(dimensions)*.5-Vector2(float(anchor[0]),float(anchor[1]))

func body_profile() -> Vector2:
	return Vector2(float(manifest.get("body_height_px",80)),0)

func attack_clip(effect: Dictionary) -> StringName:
	var ability:=str(effect.get("ability",""))
	var suffix: String="sweep" if ability=="jia_sweep" else "break" if ability=="jia_break" else "attack"
	return StringName(weapon+"-"+suffix)

func contact_frame(clip: StringName) -> int:
	return int(manifest.get("clips",{}).get(String(clip),{}).get("contact_frame",1))

func presentation_snapshot() -> Dictionary:
	var result:=super.presentation_snapshot()
	result.appearance="campaign"
	return result
