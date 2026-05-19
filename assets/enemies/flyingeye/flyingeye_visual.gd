extends Node2D

const FLY_TEXTURE := preload("res://assets/enemies/flyingeye/Flight.png")
const HIT_TEXTURE := preload("res://assets/enemies/flyingeye/Take Hit.png")
const FLY_FRAME_SIZE := Vector2i(150, 150)
const HIT_FRAME_SIZE := Vector2i(150, 150)
const VISUAL_SCALE := Vector2(1.8, 1.8)

static var shared_sprite_frames: SpriteFrames

var sprite: AnimatedSprite2D
var current_animation: String = ""
var hit_lock_remaining: float = 0.0
var last_moving_state: bool = false

func _ready() -> void:
	_ensure_sprite()
	set_moving(false)
	set_process(false)

func _process(delta: float) -> void:
	if hit_lock_remaining <= 0.0:
		set_process(false)
		return
	hit_lock_remaining = max(0.0, hit_lock_remaining - delta)
	if hit_lock_remaining <= 0.0:
		current_animation = ""
		set_moving(last_moving_state)
		set_process(false)

func set_moving(is_moving: bool, move_direction: Vector2 = Vector2.ZERO) -> void:
	_ensure_sprite()
	last_moving_state = is_moving
	_update_facing(move_direction)
	if hit_lock_remaining > 0.0:
		return
	var next_animation := "fly" if is_moving else "fly"
	if current_animation == next_animation:
		return
	current_animation = next_animation
	sprite.play(next_animation)

func play_hit() -> void:
	_ensure_sprite()
	hit_lock_remaining = 0.2
	current_animation = "hit"
	sprite.play("hit")
	set_process(true)

func _update_facing(move_direction: Vector2) -> void:
	if abs(move_direction.x) <= 0.01:
		return
	sprite.flip_h = move_direction.x < 0.0

func _ensure_sprite() -> void:
	if sprite != null:
		return
	sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		sprite = AnimatedSprite2D.new()
		sprite.name = "AnimatedSprite2D"
		add_child(sprite)
	sprite.sprite_frames = _get_shared_frames()
	sprite.centered = true
	sprite.position = Vector2(0.0, -18.0)
	sprite.scale = VISUAL_SCALE
	sprite.z_index = 1

static func _get_shared_frames() -> SpriteFrames:
	if shared_sprite_frames == null:
		shared_sprite_frames = _build_frames()
	return shared_sprite_frames

static func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	_add_strip_animation(frames, "fly", FLY_TEXTURE, 8, 10.0, true, FLY_FRAME_SIZE)
	_add_strip_animation(frames, "hit", HIT_TEXTURE, 4, 14.0, false, HIT_FRAME_SIZE)
	return frames

static func _add_strip_animation(frames: SpriteFrames, animation_name: String, texture: Texture2D, frame_count: int, speed: float, loop: bool, frame_size: Vector2i) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, loop)
	frames.set_animation_speed(animation_name, speed)
	for index in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2i(index * frame_size.x, 0, frame_size.x, frame_size.y)
		frames.add_frame(animation_name, atlas)
