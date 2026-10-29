extends SceneTree
## Run this external script with --main-pack from an empty directory.
## Tests raw JSON inclusion and imported texture resolution without source-tree fallback.
const CATALOG = preload("res://scripts/content/enemy_catalog.gd")
const MANIFEST = preload("res://scripts/ui/chronicle/enemy_visual_manifest.gd")
const EFFECTS = preload("res://scripts/ui/chronicle/enemy_battle_effects.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("PACK CHECK FAILED: " + label)

func _run() -> void:
	_check(not FileAccess.file_exists("res://design/baimen-enemies-20261028/production-state.json"), "production sources excluded")
	_check(not FileAccess.file_exists("res://assets/enemies/baimen/E01/actor.aseprite"), "editable actor excluded")
	_check(CATALOG.DEFINITIONS.size() == 43, "all enemy definitions packed")
	var ids: Dictionary = {}
	for definition in CATALOG.DEFINITIONS.values():
		ids[str(definition.visual_id)] = true
	_check(ids.size() == 42, "all runtime visual slots packed")
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
	print("ENEMY_PACK_SMOKE PASS %d FAIL %d" % [passed, failed])
	quit(1 if failed else 0)
