extends Node2D
## Presentation-only controller. Successful casts own attack timing; locomotion
## remains free while an attack plays. All clips share a fixed foot anchor.
const CLIPS := [
	[&"dao-idle", preload("res://assets/players/jia/dao-idle.png"), 4, 5.0, true],
	[&"dao-run", preload("res://assets/players/jia/dao-run.png"), 8, 11.0, true],
	[&"dao-attack", preload("res://assets/players/jia/dao-attack.png"), 4, 16.0, false],
	[&"spear-idle", preload("res://assets/players/jia/spear-idle.png"), 4, 5.0, true],
	[&"spear-run", preload("res://assets/players/jia/spear-run.png"), 8, 11.0, true],
	[&"spear-attack", preload("res://assets/players/jia/spear-attack.png"), 4, 16.0, false],
]
var sprite: AnimatedSprite2D
var moving := false
var attacking := false
var manual_attack := false
var weapon := "dao"
var facing_left := false

func _ready() -> void:
	sprite = $AnimatedSprite2D
	sprite.sprite_frames = SpriteFrames.new()
	sprite.sprite_frames.remove_animation(&"default")
	for clip in CLIPS:
		sprite.sprite_frames.add_animation(clip[0])
		sprite.sprite_frames.set_animation_speed(clip[0], clip[3])
		sprite.sprite_frames.set_animation_loop(clip[0], clip[4])
		for index in clip[2]:
			var frame := AtlasTexture.new()
			frame.atlas = clip[1]
			frame.region = Rect2(index * 192, 0, 192, 192)
			sprite.sprite_frames.add_frame(clip[0], frame)
	sprite.animation_finished.connect(_finish_attack)
	set_moving(false)

func set_weapon(equipment_id: String) -> void:
	var next := "spear" if equipment_id == "long_spear" else "dao"
	if next == weapon: return
	weapon = next
	attacking = false
	set_moving(moving)

func set_moving(is_moving: bool, direction: Vector2 = Vector2.ZERO) -> void:
	moving = is_moving
	if absf(direction.x) > .01: facing_left = direction.x < 0
	if attacking or sprite == null: return
	sprite.flip_h = facing_left
	sprite.play(StringName(weapon + ("-run" if moving else "-idle")))

func play_attack(direction: Vector2, is_manual: bool = false) -> void:
	if attacking and manual_attack and not is_manual: return
	if absf(direction.x) > .01: sprite.flip_h = direction.x < 0
	attacking = true
	manual_attack = is_manual
	sprite.stop()
	sprite.play(StringName(weapon + "-attack"))
	# Shape damage is immediate: start on contact, not a misleading wind-up.
	sprite.set_frame_and_progress(1, 0.0)

func _finish_attack() -> void:
	attacking = false
	manual_attack = false
	set_moving(moving)
