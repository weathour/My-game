extends RefCounted
## Sprite-local contact and recovery. Never moves the actor/foot or battle clock.
const SETTINGS := preload("res://scripts/shared/settings.gd")
const CAST_MOTIONS := ["burst", "heal", "mana", "ward", "guard", "temper", "rally", "extend", "field", "refund_settle", "curse_cashout"]
var successful_presentations := 0
var last_presentation_id := ""
var last_clip := ""
var elapsed := 1.0
var duration := .22
var motion := "slash"
var direction := Vector2.RIGHT
var manual := false
var home := Vector2.ZERO
var body_height := 80.0
var accent := Color.WHITE
var reduced_motion := false
var reduced_flash := false
var seen: Dictionary = {}

func configure(sprite: AnimatedSprite2D, authored_body_height: float = 80.0) -> void:
	home = sprite.position
	body_height = authored_body_height

func accepts(effect: Dictionary) -> bool:
	var identity := str(effect.get("presentation_id", ""))
	if identity.is_empty() and int(effect.get("cast", 0)) > 0:
		identity = "%s:%s:%s" % [effect.get("cast", 0), effect.get("delivery", 0), effect.get("ability", "")]
	if not identity.is_empty() and seen.has(identity): return false
	return true

func begin(sprite: AnimatedSprite2D, effect: Dictionary, clip: StringName, is_manual: bool) -> void:
	last_presentation_id = str(effect.get("presentation_id", ""))
	if last_presentation_id.is_empty() and int(effect.get("cast", 0)) > 0:
		last_presentation_id = "%s:%s:%s" % [effect.get("cast", 0), effect.get("delivery", 0), effect.get("ability", "")]
	if not last_presentation_id.is_empty():
		seen[last_presentation_id] = true
		if seen.size() > 96: seen.erase(seen.keys()[0])
	successful_presentations += 1
	last_clip = String(clip)
	var profile: Dictionary = effect.get("profile", {})
	motion = str(profile.get("motion", effect.get("action", "slash")))
	direction = effect.get("direction", Vector2.RIGHT)
	manual = is_manual
	duration = .28 if manual else .19
	elapsed = 0.0
	accent = Color(str(profile.get("accent", "f1d3a0")))
	reduced_motion = SETTINGS.comfort_enabled("reduced_motion")
	reduced_flash = SETTINGS.comfort_enabled("reduced_flash")
	sprite.position = home
	# Contact starts immediately; only the remaining visual recovery varies.
	sprite.speed_scale = 1.12 if motion in ["thrust", "shoot", "dash"] else (.90 if motion in CAST_MOTIONS else 1.0)

func advance(sprite: AnimatedSprite2D, delta: float) -> void:
	if elapsed >= duration: return
	elapsed = minf(duration, elapsed + maxf(0.0, delta))
	var progress := elapsed / duration
	var envelope := sin(progress * PI) * (1.0 - progress)
	var pixels_per_unit := body_height / 80.0
	var displacement := Vector2.ZERO
	if not reduced_motion:
		if motion in ["thrust", "dash"]:
			displacement.x = direction.x * 2.0 * envelope
		elif motion == "shoot":
			displacement.x = -direction.x * 1.6 * envelope
		elif motion == "slash":
			displacement.x = direction.x * 1.4 * envelope
		elif motion in CAST_MOTIONS:
			displacement.y = -.8 * envelope
	# Nearest source pixels retain crisp edges and the foot root stays invariant.
	sprite.position = home + (displacement * pixels_per_unit).round()
	sprite.self_modulate = Color.WHITE.lerp(accent, .10 * (1.0 - progress)) if manual and not reduced_flash else Color.WHITE
	if elapsed >= duration: finish(sprite)

func finish(sprite: AnimatedSprite2D) -> void:
	elapsed = duration
	sprite.position = home
	sprite.self_modulate = Color.WHITE
	sprite.speed_scale = 1.0

func snapshot(attacking: bool, manual_attack: bool, facing_left: bool) -> Dictionary:
	return {"successful_presentations": successful_presentations,
		"last_presentation_id": last_presentation_id, "last_clip": last_clip,
		"attacking": attacking, "manual_attack": manual_attack,
		"facing_left": facing_left, "motion": motion}
