extends Node2D
## Pure presentation: identity-specific sheets, fixed feet, successful cast events.
const C := preload("res://scripts/content/combat_catalog.gd")
const A := preload("res://scripts/battle/ability_definition.gd")
const CLIPS := [[&"idle", 4, 5.0, true], [&"run", 8, 11.0, true], [&"attack", 4, 16.0, false], [&"cast", 4, 10.0, false]]
@export var character_id := "F02"
@export_range(0, 3) var attack_contact_frame := 1
var sprite: AnimatedSprite2D
var moving := false
var attacking := false
var manual_attack := false
var facing_left := false

func _ready() -> void:
	sprite = $AnimatedSprite2D
	sprite.sprite_frames = SpriteFrames.new()
	sprite.sprite_frames.remove_animation(&"default")
	for clip in CLIPS:
		var path := "res://assets/players/baimen-women/%s/%s.png" % [character_id, clip[0]]
		var sheet := load(path) as Texture2D
		if sheet == null:
			push_error("Missing approved combat art: " + path)
			continue
		sprite.sprite_frames.add_animation(clip[0])
		sprite.sprite_frames.set_animation_speed(clip[0], clip[2])
		sprite.sprite_frames.set_animation_loop(clip[0], clip[3])
		for index in clip[1]:
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(index * 192, 0, 192, 192)
			sprite.sprite_frames.add_frame(clip[0], frame)
	sprite.animation_finished.connect(_finish_attack)
	set_moving(false)

func set_moving(is_moving: bool, direction: Vector2 = Vector2.ZERO) -> void:
	moving = is_moving
	if absf(direction.x) > .01: facing_left = direction.x < 0
	if attacking or sprite == null: return
	sprite.flip_h = facing_left
	sprite.play(&"run" if moving else &"idle")

static func cast_clip(id: String, ability_id: String) -> StringName:
	var kit := C.definition(id)
	var abilities: Array = [kit.basic, kit.support]
	abilities.append_array(kit.manual)
	abilities.append_array(kit.automatic)
	for ability in abilities:
		if ability != null and str(ability.id) == ability_id:
			return &"cast" if ability.kind in [A.Kind.HEAL, A.Kind.MANA, A.Kind.WARD] else &"attack"
	return &"attack"

func present_cast(effect: Dictionary) -> void:
	_play(cast_clip(character_id, str(effect.get("ability", ""))), effect.direction, effect.get("color", "") == "manual")

func play_attack(direction: Vector2, is_manual: bool = false) -> void:
	_play(&"attack", direction, is_manual)

func _play(clip: StringName, direction: Vector2, is_manual: bool) -> void:
	if attacking and manual_attack and not is_manual: return
	if absf(direction.x) > .01: sprite.flip_h = direction.x < 0
	attacking = true
	manual_attack = is_manual
	sprite.stop()
	sprite.play(clip)
	# Damage lands immediately; defensive preparation is not a fake hit.
	sprite.set_frame_and_progress(attack_contact_frame if clip == &"attack" else 0, 0.0)

func _finish_attack() -> void:
	attacking = false
	manual_attack = false
	set_moving(moving)
