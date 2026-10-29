extends RefCounted
## Resources are optional during mechanics development; final validation is deliberately strict.
const ROOT := "res://assets/enemies/baimen/"
const REQUIRED_CLIPS := ["idle", "move", "attack", "special", "hit"]

static func read(visual_id: String) -> Dictionary:
	var path := ROOT + visual_id + "/manifest.json"
	if not FileAccess.file_exists(path): return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

static func resolved(visual_id: String) -> Dictionary:
	var data := read(visual_id)
	var source := visual_id
	if not str(data.get("reuse_visual_id", "")).is_empty():
		source = str(data.reuse_visual_id)
		data = read(source)
	data = data.duplicate(true)
	data["resource_visual_id"] = source
	return data

static func texture(visual_id: String, file: String) -> Texture2D:
	var path := ROOT + str(resolved(visual_id).get("resource_visual_id", visual_id)) + "/" + file
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

static func validate_final(ids: Array) -> Array[String]:
	var errors: Array[String] = []
	for raw_id in ids:
		var id := str(raw_id)
		var own := read(id)
		var data := resolved(id)
		if own.is_empty(): errors.append(id + ": missing manifest"); continue
		if str(own.get("visual_id", "")) != id: errors.append(id + ": manifest visual identity mismatch")
		if own.has("reuse_visual_id") and id not in ["D01", "L00"]: errors.append(id + ": principal visual cannot reuse another identity")
		if str(data.get("status", "")) != "final": errors.append(id + ": art not final")
		if texture(id, "portrait.png") == null: errors.append(id + ": missing standing portrait")
		if float(data.get("body_height_px", 0)) <= 0: errors.append(id + ": missing body calibration")
		if data.get("anchor_px", []).size() != 2: errors.append(id + ": missing foot anchor")
		var provenance_path := str(data.get("provenance", ""))
		if not FileAccess.file_exists(provenance_path): errors.append(id + ": missing provenance")
		else:
			var report = JSON.parse_string(FileAccess.get_file_as_string(provenance_path))
			if not report is Dictionary or report.get("outputs", []).is_empty(): errors.append(id + ": invalid export provenance")
			else:
				if str(report.get("id", "")) != str(data.get("resource_visual_id", id)): errors.append(id + ": provenance identity mismatch")
				for output in report.outputs:
					var output_path := str(output.get("path", ""))
					if not output_path.begins_with("res://") and not output_path.begins_with("/"): output_path = "res://" + output_path
					if not FileAccess.file_exists(output_path) or FileAccess.get_sha256(output_path) != str(output.get("sha256", "")): errors.append(id + ": changed or missing export " + output_path)
		for action_id in data.get("action_clips", {}):
			if not data.get("clips", {}).has(data.action_clips[action_id]): errors.append(id + ": invalid action clip " + str(action_id))
		for key in REQUIRED_CLIPS:
			if not data.get("clips", {}).has(key): errors.append(id + ": missing " + str(key) + " clip")
		for key in data.get("clips", {}):
			var clip: Dictionary = data.get("clips", {}).get(key, {})
			var image := texture(id, str(clip.get("file", "")))
			if image == null: errors.append(id + ": missing " + key); continue
			var dimensions: Array = clip.get("frame_size", [])
			if dimensions.size() != 2 or int(clip.get("frames", 0)) < 1 or float(clip.get("fps", 0)) <= 0:
				errors.append(id + ": invalid " + key + " metadata"); continue
			if image.get_size() != Vector2(float(dimensions[0]) * int(clip.frames), float(dimensions[1])):
				errors.append(id + ": wrong " + key + " sheet dimensions")
	return errors
