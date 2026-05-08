extends Node2D

const RUN_ANIMATION := "Slime-run"
const HIT_ANIMATION := "Slime-hit"
const VISUAL_SCALE := Vector2(2.0, 2.0)

var sprite: AnimatedSprite2D
var hit_lock_remaining: float = 0.0
var last_moving_state: bool = false

func _ready() -> void:
	_ensure_sprite()
	set_moving(false)

func _process(delta: float) -> void:
	if hit_lock_remaining <= 0.0:
		return
	hit_lock_remaining = max(0.0, hit_lock_remaining - delta)
	if hit_lock_remaining <= 0.0:
		set_moving(last_moving_state)

func set_moving(is_moving: bool, move_direction: Vector2 = Vector2.ZERO) -> void:
	_ensure_sprite()
	last_moving_state = is_moving
	_update_facing(move_direction)
	if hit_lock_remaining > 0.0:
		return
	sprite.play(RUN_ANIMATION)

func play_hit() -> void:
	_ensure_sprite()
	hit_lock_remaining = 0.18
	sprite.play(HIT_ANIMATION)

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
	sprite.centered = true
	sprite.position = Vector2(0.0, -4.0)
	sprite.scale = VISUAL_SCALE
	sprite.z_index = 1
