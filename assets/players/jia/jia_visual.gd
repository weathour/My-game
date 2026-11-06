extends Node2D
## Presentation-only controller. Successful casts own attack timing; locomotion
## remains free while an attack plays. All clips share a fixed foot anchor.
const ACTION := preload("res://scripts/ui/chronicle/actor_action_presentation.gd")
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
var action := ACTION.new()

func _ready() -> void:
	sprite = $AnimatedSprite2D
	sprite.sprite_frames = SpriteFrames.new()
	sprite.sprite_frames.remove_animation(&"default")
	for clip in clip_specifications():
		sprite.sprite_frames.add_animation(clip[0])
		sprite.sprite_frames.set_animation_speed(clip[0], clip[3])
		sprite.sprite_frames.set_animation_loop(clip[0], clip[4])
		for index in clip[2]:
			var frame := AtlasTexture.new()
			frame.atlas = clip[1]
			var dimensions := frame_size(StringName(clip[0]))
			frame.region = Rect2(Vector2(index * dimensions.x,0),Vector2(dimensions))
			sprite.sprite_frames.add_frame(clip[0], frame)
	sprite.animation_finished.connect(_finish_attack)
	configure_sprite()
	action.configure(sprite,body_profile().x)
	set_moving(false)

func _process(delta: float) -> void:
	if sprite != null: action.advance(sprite, delta)

func set_weapon(equipment_id: String) -> void:
	var next := "spear" if equipment_id == "long_spear" else "dao"
	if next == weapon: return
	weapon = next
	attacking = false
	manual_attack = false
	action.finish(sprite)
	set_moving(moving)

func set_moving(is_moving: bool, direction: Vector2 = Vector2.ZERO) -> void:
	moving = is_moving
	if absf(direction.x) > .01: facing_left = direction.x < 0
	if attacking or sprite == null: return
	sprite.flip_h = facing_left
	sprite.play(StringName(weapon + ("-run" if moving else "-idle")))

func play_attack(direction: Vector2, is_manual: bool = false) -> void:
	present_cast({"direction": direction, "manual": is_manual})

func present_cast(effect: Dictionary) -> void:
	var direction: Vector2 = effect.get("direction", Vector2.RIGHT)
	var is_manual := bool(effect.get("manual", effect.get("color", "") == "manual"))
	if attacking and manual_attack and not is_manual: return
	if not action.accepts(effect): return
	if absf(direction.x) > .01: facing_left = direction.x < 0
	sprite.flip_h = facing_left
	attacking = true
	manual_attack = is_manual
	var clip := attack_clip(effect)
	action.begin(sprite, effect, clip, is_manual)
	sprite.stop()
	sprite.play(clip)
	# Shape damage is immediate: start on contact, not a misleading wind-up.
	sprite.set_frame_and_progress(clampi(contact_frame(clip),0,sprite.sprite_frames.get_frame_count(clip)-1), 0.0)

func _finish_attack() -> void:
	attacking = false
	manual_attack = false
	action.finish(sprite)
	set_moving(moving)

func presentation_snapshot() -> Dictionary:
	return action.snapshot(attacking, manual_attack, facing_left)

# Costume controllers can extend art without replacing successful-cast semantics.
func clip_specifications() -> Array:
	return CLIPS

func frame_size(_clip: StringName) -> Vector2i:
	return Vector2i(192,192)

func configure_sprite() -> void:
	pass # The original scene already owns its exact (0,-80) ground anchor.

func body_profile() -> Vector2:
	return Vector2(80,0)

func attack_clip(_effect: Dictionary) -> StringName:
	return StringName(weapon+"-attack")

func contact_frame(_clip: StringName) -> int:
	return 1
