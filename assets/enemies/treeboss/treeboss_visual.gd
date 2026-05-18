extends Node2D

const RUN_ANIMATION := "treewalk"
const VISUAL_SCALE := Vector2(0.48, 0.48)

var sprite: AnimatedSprite2D
var last_moving_state: bool = false


func _ready() -> void:
	_ensure_sprite()
	set_moving(false)


func set_moving(is_moving: bool, move_direction: Vector2 = Vector2.ZERO) -> void:
	_ensure_sprite()
	last_moving_state = is_moving
	_update_facing(move_direction)
	if sprite.animation != RUN_ANIMATION or not sprite.is_playing():
		sprite.play(RUN_ANIMATION)


func play_hit() -> void:
	_ensure_sprite()
	if not sprite.is_playing():
		sprite.play(RUN_ANIMATION)


func _update_facing(move_direction: Vector2) -> void:
	if abs(move_direction.x) <= 0.01:
		return
	sprite.flip_h = move_direction.x < 0.0


func _ensure_sprite() -> void:
	if sprite != null:
		return
	sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return
	sprite.centered = true
	sprite.position = Vector2(0.0, -36.0)
	sprite.scale = VISUAL_SCALE
	sprite.z_index = 1
