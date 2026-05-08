extends Node2D

const IDLE_TEXTURE := preload("res://assets/players/sword/sword-idle1.png")
const RUN_TEXTURE := preload("res://assets/players/sword/sword-run2.png")
const FRAME_SIZE := Vector2i(256, 256)
const FRAME_COLUMNS := 4
const FRAME_COUNT := 12
const VISUAL_SCALE := Vector2(0.62, 0.62)

var sprite: AnimatedSprite2D
var current_animation: String = ""


func _ready() -> void:
	_ensure_sprite()
	set_moving(false)


func set_moving(is_moving: bool, move_direction: Vector2 = Vector2.ZERO) -> void:
	_ensure_sprite()
	_update_facing(move_direction)
	var next_animation := "run" if is_moving else "idle"
	if current_animation == next_animation and sprite.is_playing():
		return
	current_animation = next_animation
	sprite.play(next_animation)


func _update_facing(move_direction: Vector2) -> void:
	if abs(move_direction.x) <= 0.01:
		return
	sprite.flip_h = move_direction.x > 0.0


func _ensure_sprite() -> void:
	if sprite != null:
		return
	sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		sprite = AnimatedSprite2D.new()
		sprite.name = "AnimatedSprite2D"
		add_child(sprite)
	sprite.sprite_frames = _build_frames()
	sprite.centered = true
	sprite.position = Vector2(-11.0, 10.0)
	sprite.scale = VISUAL_SCALE
	sprite.z_index = 1


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	_add_sheet_animation(frames, "idle", IDLE_TEXTURE, 8.0, true)
	_add_sheet_animation(frames, "run", RUN_TEXTURE, 12.0, true)
	return frames


func _add_sheet_animation(frames: SpriteFrames, animation_name: String, texture: Texture2D, speed: float, loop: bool) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, loop)
	frames.set_animation_speed(animation_name, speed)
	for index in range(FRAME_COUNT):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		var column := index % FRAME_COLUMNS
		var row := int(index / FRAME_COLUMNS)
		atlas.region = Rect2i(column * FRAME_SIZE.x, row * FRAME_SIZE.y, FRAME_SIZE.x, FRAME_SIZE.y)
		frames.add_frame(animation_name, atlas)
