extends Node2D

const RUN_ANIMATION := "run"
const HIT_FLASH_DURATION := 0.14

var sprite: AnimatedSprite2D
var hit_flash_remaining: float = 0.0


func _ready() -> void:
	_ensure_sprite()
	set_moving(false)
	set_process(false)


func _process(delta: float) -> void:
	if hit_flash_remaining <= 0.0:
		set_process(false)
		return
	hit_flash_remaining = max(0.0, hit_flash_remaining - delta)
	if hit_flash_remaining <= 0.0:
		sprite.modulate = Color.WHITE
		set_process(false)


func set_moving(_is_moving: bool, move_direction: Vector2 = Vector2.ZERO) -> void:
	_ensure_sprite()
	_update_facing(move_direction)
	if sprite.animation != RUN_ANIMATION or not sprite.is_playing():
		sprite.play(RUN_ANIMATION)


func play_hit() -> void:
	_ensure_sprite()
	hit_flash_remaining = HIT_FLASH_DURATION
	sprite.modulate = Color(1.0, 0.55, 0.55, 1.0)
	set_process(true)


func _update_facing(move_direction: Vector2) -> void:
	if abs(move_direction.x) <= 0.01:
		return
	# Skull sheets face left by default, so their flip rule is inverse to the other enemy sheets.
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
	sprite.z_index = 1
