extends Node2D
## Presentation-only friendly counterpart for the shared human-form sprite sheets.
const ROOT := "res://assets/enemies/baimen/"

@export var human_id := "B18_human"
var sprite: AnimatedSprite2D
var manifest: Dictionary = {}
var moving := false
var attacking := false
var manual_attack := false
var facing_left := false

func _ready() -> void:
	sprite = $AnimatedSprite2D
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var manifest_path := ROOT + human_id + "/manifest.json"
	if not FileAccess.file_exists(manifest_path):
		push_error("Missing human friendly manifest: " + manifest_path)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		push_error("Invalid human friendly manifest: " + manifest_path)
		return
	manifest = parsed
	facing_left = bool(manifest.get("faces_left", false))
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	for raw_name in manifest.get("clips", {}):
		var name := StringName(raw_name)
		var clip: Dictionary = manifest.clips[raw_name]
		var file := str(clip.get("file", raw_name + ".png"))
		var sheet_path := ROOT + human_id + "/" + file
		var sheet := load(sheet_path) as Texture2D
		var dimensions: Array = clip.get("frame_size", [])
		var count := int(clip.get("frames", 0))
		if sheet == null or dimensions.size() != 2 or count < 1:
			push_error("Invalid friendly human clip: " + sheet_path)
			continue
		var frame_size := Vector2(float(dimensions[0]), float(dimensions[1]))
		frames.add_animation(name)
		frames.set_animation_speed(name, float(clip.get("fps", 8.0)))
		frames.set_animation_loop(name, name in [&"idle", &"move"])
		for index in count:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(Vector2(index, 0) * frame_size, frame_size)
			frames.add_frame(name, atlas)
	sprite.sprite_frames = frames
	_position_at_manifest_anchor()
	sprite.animation_finished.connect(_finish_attack)
	_apply_facing()
	set_moving(false)

func _position_at_manifest_anchor() -> void:
	var anchor: Array = manifest.get("anchor_px", [256, 480])
	var dimensions: Array = manifest.get("clips", {}).get("idle", {}).get("frame_size", [512, 512])
	if anchor.size() != 2 or dimensions.size() != 2:
		return
	# Atlas frames are centered around Sprite2D's origin; offset the foot point to origin.
	sprite.position = Vector2(float(dimensions[0]) * 0.5 - float(anchor[0]),
		float(dimensions[1]) * 0.5 - float(anchor[1]))

func set_moving(is_moving: bool, direction: Vector2 = Vector2.ZERO) -> void:
	moving = is_moving
	if absf(direction.x) > 0.01:
		facing_left = direction.x < 0
	if attacking or sprite.sprite_frames == null:
		return
	_apply_facing()
	var animation: StringName = &"move" if moving else &"idle"
	if sprite.sprite_frames.has_animation(animation):
		sprite.play(animation)

func present_cast(effect: Dictionary) -> void:
	var action := str(effect.get("action", ""))
	var action_clips: Dictionary = manifest.get("action_clips", {})
	var clip := str(action_clips.get(action, ""))
	if clip.is_empty():
		clip = "special" if str(effect.get("color", "")) == "manual" else "attack"
	_play(StringName(clip), effect.get("direction", Vector2.RIGHT), str(effect.get("color", "")) == "manual")

func play_attack(direction: Vector2, is_manual: bool = false) -> void:
	_play(&"special" if is_manual else &"attack", direction, is_manual)

func _play(clip: StringName, direction: Vector2, is_manual: bool) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(clip):
		return
	if attacking and manual_attack and not is_manual:
		return
	if absf(direction.x) > 0.01:
		facing_left = direction.x < 0
	_apply_facing()
	attacking = true
	manual_attack = is_manual
	sprite.stop()
	sprite.play(clip)
	var metadata: Dictionary = manifest.get("clips", {}).get(String(clip), {})
	var contact := int(metadata.get("contact_frame", 0))
	sprite.set_frame_and_progress(clampi(contact, 0, sprite.sprite_frames.get_frame_count(clip) - 1), 0.0)

func _apply_facing() -> void:
	# flip_h mirrors the manifest's authored default toward the requested direction.
	sprite.flip_h = facing_left != bool(manifest.get("faces_left", false))

func _finish_attack() -> void:
	attacking = false
	manual_attack = false
	set_moving(moving)
