extends Node2D

const RUN_TEXTURE := preload("res://assets/players/gun/rika_8810f644.png")
const FRAME_SIZE := Vector2i(256, 256)
const FRAME_COLUMNS := 4
const FRAME_COUNT := 12
const VISUAL_SCALE := Vector2(0.62, 0.62)

var sprite: AnimatedSprite2D


func _ready() -> void:
	_ensure_sprite()
	set_moving(false)


func set_moving(_is_moving: bool, move_direction: Vector2 = Vector2.ZERO) -> void:
	_ensure_sprite()
	_update_facing(move_direction)
	if not sprite.is_playing():
		sprite.play("run")


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
	sprite.position = Vector2(-10.0, 7.0)
	sprite.scale = VISUAL_SCALE
	sprite.z_index = 1


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("run")
	frames.set_animation_loop("run", true)
	frames.set_animation_speed("run", 12.0)
	for index in range(FRAME_COUNT):
		var atlas := AtlasTexture.new()
		atlas.atlas = RUN_TEXTURE
		var column := index % FRAME_COLUMNS
		var row := int(index / FRAME_COLUMNS)
		atlas.region = Rect2i(column * FRAME_SIZE.x, row * FRAME_SIZE.y, FRAME_SIZE.x, FRAME_SIZE.y)
		frames.add_frame("run", atlas)
	return frames
