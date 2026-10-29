extends Node2D
## Manifest-driven raster body. Presentation clock comes exclusively from the battle.
const MANIFEST := preload("res://scripts/ui/chronicle/enemy_visual_manifest.gd")
var sprite: Sprite2D
var metadata: Dictionary = {}
var visual_id := ""
var clip_name := ""
var clip_started := 0.0
var last_serial := -1
var last_state := ""
var hit_until := 0.0
var clock := 0.0
var moving := false
var action_until := 0.0
var telling := false
var action_clip := "attack"
var action_started := 0.0

func setup(id: String) -> void:
	visual_id = id
	metadata = MANIFEST.resolved(id)
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	_select("idle", 0.0)

func body_profile() -> Vector2:
	return Vector2(float(metadata.get("body_height_px", 80)), 0)

func set_moving(value: bool, direction: Vector2) -> void:
	moving = value
	if absf(direction.x) > .01: sprite.flip_h = direction.x > 0 if bool(metadata.get("faces_left", false)) else direction.x < 0

func present(enemy: RefCounted, elapsed: float, is_paused: bool) -> void:
	if is_paused: return
	clock = elapsed
	if absf(enemy.aim.x) > .01: sprite.flip_h = enemy.aim.x > 0 if bool(metadata.get("faces_left", false)) else enemy.aim.x < 0
	var wanted := "move" if moving else "idle"
	telling = enemy.state == "tell"
	if telling:
		wanted = _clip_for_action(str(enemy.current_action.get("action", enemy.current_action.get("id", enemy.attack))), int(enemy.telegraph.get("attack_step", 0)))
	elif elapsed < action_until or enemy.state == "active":
		wanted = action_clip
	if clock < hit_until: wanted = "hit"
	if wanted != clip_name or (enemy.action_serial != last_serial and telling):
		_select(wanted, clock)
		if not telling and _is_action_clip(wanted): clip_started = action_started
	last_serial = enemy.action_serial
	last_state = enemy.state
	_update_frame(clock)

func play_release(geometry: Dictionary, elapsed: float) -> void:
	clock = elapsed
	telling = false
	var key := _clip_for_action(str(geometry.get("action_id", "")), int(geometry.get("attack_step", 0)))
	action_clip = key
	_select(key, elapsed)
	var clip: Dictionary = metadata.get("clips", {}).get(clip_name, {})
	var contact := clampi(int(clip.get("contact_frame", 1)), 0, sprite.hframes - 1)
	var fps := maxf(1, float(clip.get("fps", 8)))
	clip_started = elapsed - contact / fps
	action_started = clip_started
	action_until = elapsed + (sprite.hframes - contact) / fps
	_update_frame(elapsed)

func _clip_for_action(action_id: String, step: int = 0) -> String:
	var routes: Dictionary = metadata.get("action_clips", {})
	var mapped := str(routes.get(action_id + "@" + str(posmod(step, 2)), routes.get(action_id, "")))
	if not mapped.is_empty() and metadata.get("clips", {}).has(mapped): return mapped
	return "special" if action_id in ["charge", "pot", "pulse", "summon", "anchor", "command", "heal", "collaboration"] else "attack"

func _is_action_clip(key: String) -> bool:
	return key not in ["idle", "move", "hit"] and metadata.get("clips", {}).has(key)

func play_hit() -> void:
	hit_until = clock + .16

func preview(action: String, elapsed: float) -> void:
	telling = false
	if action != clip_name: _select(action, elapsed)
	_update_frame(elapsed)
	var clip: Dictionary = metadata.get("clips", {}).get(clip_name, {})
	sprite.frame = int(maxf(0, elapsed - clip_started) * float(clip.get("fps", 8))) % sprite.hframes

func _select(key: String, elapsed: float) -> void:
	clip_name = key if metadata.get("clips", {}).has(key) else "idle"
	clip_started = elapsed
	var clip: Dictionary = metadata.get("clips", {}).get(clip_name, {})
	sprite.texture = MANIFEST.texture(visual_id, str(clip.get("file", "idle.png")))
	sprite.hframes = maxi(1, int(clip.get("frames", 1)))
	sprite.frame = 0
	var size_data: Array = clip.get("frame_size", [192, 192])
	var anchor: Array = metadata.get("anchor_px", [96, 176])
	sprite.position = Vector2(float(size_data[0]) * .5 - float(anchor[0]), float(size_data[1]) * .5 - float(anchor[1]))

func _update_frame(elapsed: float) -> void:
	var clip: Dictionary = metadata.get("clips", {}).get(clip_name, {})
	var frame := int(maxf(0, elapsed - clip_started) * float(clip.get("fps", 8)))
	if telling and _is_action_clip(clip_name):
		sprite.frame = clampi(int(clip.get("windup_frame", 0)), 0, sprite.hframes - 1)
	else:
		sprite.frame = frame % sprite.hframes if clip_name in ["idle", "move"] else mini(frame, sprite.hframes - 1)
