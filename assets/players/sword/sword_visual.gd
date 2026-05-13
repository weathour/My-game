extends Node2D

const IDLE_ANIMATION := &"sword-idle"
const RUN_ANIMATION := &"sword-run"
const VISUAL_SCALE := Vector2(0.62, 0.62)
const RUN_VISUAL_SCALE_MULTIPLIER := 2.0
const IDLE_BODY_CENTER_OFFSET := Vector2(2.08, -3.04)
const RUN_BODY_CENTER_OFFSET := Vector2(-0.33, -0.25)

var sprite: AnimatedSprite2D
var current_animation: StringName = StringName()


func _ready() -> void:
	_ensure_sprite()
	set_moving(false)


func set_moving(is_moving: bool, move_direction: Vector2 = Vector2.ZERO) -> void:
	_ensure_sprite()
	_update_facing(move_direction)
	var next_animation: StringName = RUN_ANIMATION if is_moving else IDLE_ANIMATION
	if current_animation == next_animation and sprite.is_playing():
		return
	current_animation = next_animation
	_apply_animation_scale(next_animation)
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
	sprite.centered = true
	sprite.scale = VISUAL_SCALE
	_apply_animation_offset(IDLE_ANIMATION)
	sprite.z_index = 1


func _apply_animation_scale(animation_name: StringName) -> void:
	if sprite == null:
		return
	var scale_multiplier: float = RUN_VISUAL_SCALE_MULTIPLIER if animation_name == RUN_ANIMATION else 1.0
	sprite.scale = VISUAL_SCALE * scale_multiplier
	_apply_animation_offset(animation_name)


func _apply_animation_offset(animation_name: StringName) -> void:
	if sprite == null:
		return
	var raw_offset: Vector2 = RUN_BODY_CENTER_OFFSET if animation_name == RUN_ANIMATION else IDLE_BODY_CENTER_OFFSET
	sprite.position = raw_offset * sprite.scale
