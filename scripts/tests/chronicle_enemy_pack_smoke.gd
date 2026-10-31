extends SceneTree
## Run this external script with --main-pack from an empty directory.
## Tests raw JSON inclusion and imported texture resolution without source-tree fallback.
const CATALOG = preload("res://scripts/content/enemy_catalog.gd")
const MANIFEST = preload("res://scripts/ui/chronicle/enemy_visual_manifest.gd")
const EFFECTS = preload("res://scripts/ui/chronicle/enemy_battle_effects.gd")
const ART = preload("res://scripts/ui/chronicle/battle_art.gd")
const PORTRAITS = preload("res://scripts/ui/chronicle/chronicle_portraits.gd")
const BOSS_IDS := ["B15", "B16", "B17", "B18"]
const HUMAN_VISUAL_IDS := ["B15_human", "B16_human", "B17_human", "B18_human", "M03_human", "M04_human"]
const FRIENDLY_IDS := ["M01", "M02", "M03", "M04", "M05", "M06"]
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("PACK CHECK FAILED: " + label)

func _run() -> void:
	_check(not FileAccess.file_exists("res://design/baimen-enemies-20261028/production-state.json"), "production sources excluded")
	_check(not FileAccess.file_exists("res://design/boss-forms-20261029/characters/B15_human/export-manifest.json"), "Boss form production sources excluded")
	_check(not FileAccess.file_exists("res://assets/enemies/baimen/E01/actor.aseprite"), "editable actor excluded")
	_check(CATALOG.DEFINITIONS.size() == 43, "all enemy definitions packed")
	var ids: Dictionary = {}
	for definition in CATALOG.DEFINITIONS.values():
		ids[str(definition.visual_id)] = true
	_check(ids.size() == 42, "all runtime visual slots packed")
	for id in BOSS_IDS:
		var boss: Dictionary = CATALOG.definition(id)
		var forms: Array = boss.get("forms", [])
		_check(forms.size() == 2, id + " has two authored forms")
		if not forms.is_empty():
			ids[id + "_human"] = true
	for id in HUMAN_VISUAL_IDS:
		ids[id] = true
	_check(ids.size() == 48, "runtime and six dynamic human visual slots packed")
	for id in ids:
		var own: Dictionary = MANIFEST.read(id)
		_check(not own.is_empty() and own.get("visual_id", "") == id, id + " raw JSON")
		var data: Dictionary = MANIFEST.resolved(id)
		_check(data.get("status", "") == "final", id + " final art")
		_check(MANIFEST.texture(id, "portrait.png") != null, id + " portrait resource")
		_check(data.get("clips", {}).size() >= 5, id + " animation metadata")
		for clip_id in data.get("clips", {}):
			var clip: Dictionary = data.clips[clip_id]
			var texture: Texture2D = MANIFEST.texture(id, str(clip.file))
			_check(texture != null, id + " " + clip_id + " texture")
			if texture != null:
				_check(texture.get_size() == Vector2(float(clip.frame_size[0]) * int(clip.frames), float(clip.frame_size[1])), id + " " + clip_id + " dimensions")
	var effects = EFFECTS.new()
	_check(effects.clips.size() == 8, "all effect JSON and textures packed")
	for id in EFFECTS.EFFECT_IDS:
		_check(effects.texture(id, 0.15) != null, str(id) + " animation readable")
	for id in ["slash", "thrust", "sweep"]:
		_check(effects.texture(id, 0.15) != null, id + " existing effect reuse")
	for id in FRIENDLY_IDS:
		var portrait: Texture2D = PORTRAITS.standing(id)
		_check(portrait != null, id + " friendly portrait resource")
		var scene: PackedScene = ART.actor(id)
		_check(scene != null, id + " dynamic friendly scene")
		if scene != null:
			var instance: Node2D = scene.instantiate()
			root.add_child(instance)
			await process_frame
			var sprite := instance.get("sprite") as AnimatedSprite2D
			_check(sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation("idle"), id + " friendly animation frames loaded")
			if is_instance_valid(instance):
				instance.queue_free()
				await process_frame
		var head_scene: PackedScene = ART.portrait(id)
		_check(head_scene != null, id + " friendly head scene")
		if head_scene != null:
			var head: Node2D = head_scene.instantiate()
			root.add_child(head)
			await process_frame
			var head_sprite := head.get_node_or_null("Sprite2D") as Sprite2D
			_check(head_sprite != null and head_sprite.texture != null, id + " dynamic friendly head loaded")
			head.queue_free()
			await process_frame
	var shell: PackedScene = load("res://scenes/chronicle/chronicle_shell.tscn")
	_check(shell != null, "main scene packed")
	if shell != null:
		var instance = shell.instantiate()
		root.add_child(instance)
		for frame in 5:
			await process_frame
		_check(is_instance_valid(instance) and instance.is_inside_tree(), "packed main scene starts")
		instance.queue_free()
		await process_frame
	effects = null
	print("ENEMY_PACK_SMOKE PASS checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
