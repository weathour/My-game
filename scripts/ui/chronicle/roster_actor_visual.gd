extends Node2D
## Character-specific art, shared presentation contract. No combat calculations.
const ACTION := preload("res://scripts/ui/chronicle/actor_action_presentation.gd")
const ROOT := "res://assets/players/chronicle-cast/"
@export var character_id := "F11"
var sprite: AnimatedSprite2D
var manifest: Dictionary = {}
var moving := false
var attacking := false
var manual_attack := false
var facing_left := false
var action := ACTION.new()

func _ready() -> void:
	sprite = $AnimatedSprite2D
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path := ROOT + character_id + "/manifest.json"
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Invalid character art manifest: " + path)
		return
	manifest = parsed
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for raw_name in manifest.get("clips", {}):
		var name := StringName(raw_name)
		var clip: Dictionary = manifest.clips[raw_name]
		var sheet := load(ROOT + character_id + "/" + str(clip.file)) as Texture2D
		var dimensions: Array = clip.get("frame_size", [])
		var count := int(clip.get("frames", 0))
		if sheet == null or dimensions.size() != 2 or count < 1:
			push_error("Invalid character clip: " + character_id + "/" + str(name))
			continue
		var frame_size := Vector2(float(dimensions[0]), float(dimensions[1]))
		frames.add_animation(name)
		frames.set_animation_speed(name, float(clip.get("fps", 10.0)))
		frames.set_animation_loop(name, name in [&"idle", &"move"])
		for index in count:
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(Vector2(index * frame_size.x, 0), frame_size)
			frames.add_frame(name, frame)
	sprite.sprite_frames = frames
	var anchor: Array = manifest.get("anchor_px", [96, 176])
	var size: Array = manifest.get("clips", {}).get("idle", {}).get("frame_size", [192, 192])
	sprite.position = Vector2(float(size[0]) * .5 - float(anchor[0]), float(size[1]) * .5 - float(anchor[1]))
	action.configure(sprite, float(manifest.get("body_height_px", 80.0)))
	sprite.animation_finished.connect(_finish_attack)
	set_moving(false)

func _process(delta: float) -> void:
	if sprite != null: action.advance(sprite, delta)

func body_profile() -> Vector2:
	return Vector2(float(manifest.get("body_height_px", 80.0)), 0)

func set_moving(is_moving: bool, direction: Vector2 = Vector2.ZERO) -> void:
	moving = is_moving
	if absf(direction.x) > .01: facing_left = direction.x < 0
	if attacking or sprite == null: return
	_apply_facing()
	if sprite.sprite_frames.has_animation(&"move" if moving else &"idle"):
		sprite.play(&"move" if moving else &"idle")

func present_cast(effect: Dictionary) -> void:
	var manual := bool(effect.get("manual", effect.get("color", "") == "manual"))
	if attacking and manual_attack and not manual: return
	if not action.accepts(effect): return
	var profile: Dictionary = effect.get("profile", {})
	var motion := str(profile.get("motion", effect.get("action", "slash")))
	var clip := str(manifest.get("action_clips", {}).get(motion, ""))
	if clip.is_empty():
		clip = "special" if manual or motion in ACTION.CAST_MOTIONS else "attack"
	_play(StringName(clip), effect, manual)

func play_attack(direction: Vector2, is_manual: bool = false) -> void:
	present_cast({"direction": direction, "manual": is_manual})

func _play(clip: StringName, effect: Dictionary, manual: bool) -> void:
	if not sprite.sprite_frames.has_animation(clip): return
	var direction: Vector2 = effect.get("direction", Vector2.RIGHT)
	if absf(direction.x) > .01: facing_left = direction.x < 0
	_apply_facing()
	attacking = true
	manual_attack = manual
	action.begin(sprite, effect, clip, manual)
	sprite.stop()
	sprite.play(clip)
	var contact := int(manifest.get("clips", {}).get(String(clip), {}).get("contact_frame", 0))
	sprite.set_frame_and_progress(clampi(contact, 0, sprite.sprite_frames.get_frame_count(clip) - 1), 0.0)

func _apply_facing() -> void:
	sprite.flip_h = facing_left != bool(manifest.get("faces_left", false))
	var anchor: Array = manifest.get("anchor_px", [96, 176])
	var dimensions: Array = manifest.get("clips", {}).get("idle", {}).get("frame_size", [192, 192])
	var offset_x := float(dimensions[0]) * .5 - float(anchor[0])
	action.home.x = -offset_x if sprite.flip_h else offset_x
	sprite.position.x = action.home.x

func _finish_attack() -> void:
	attacking = false
	manual_attack = false
	action.finish(sprite)
	set_moving(moving)

func presentation_snapshot() -> Dictionary:
	return action.snapshot(attacking, manual_attack, facing_left)
