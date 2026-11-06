extends SceneTree
## Run against an exported PCK from outside the source tree.
var failures: Array[String] = []
var checked := 0

func _init() -> void:
	call_deferred("run")

func expect(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures.append(label)
		push_error(label)

func run() -> void:
	for excluded_root in ["res://builds", "res://design", "res://scripts/tests"]:
		expect(DirAccess.open(excluded_root) == null and not FileAccess.file_exists(excluded_root), "export excludes verification/source root: " + excluded_root)
	var path := "res://assets/data/audio/music_catalog.json"
	expect(FileAccess.file_exists(path), "export contains the raw music catalog JSON")
	if not failures.is_empty():
		quit(1)
		return
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	expect(catalog is Dictionary and catalog.get("cues", []).size() == 16, "export contains the complete 16-cue roster")
	if not failures.is_empty():
		quit(1)
		return
	var ids: Dictionary = {}
	for row: Dictionary in catalog.cues:
		var id := str(row.id)
		expect(not ids.has(id), "unique exported cue: " + id)
		ids[id] = true
		var stream: AudioStream = load(str(row.path)) as AudioStream
		expect(stream is AudioStreamOggVorbis, "exported Vorbis actually decodes: " + id)
		if stream == null: continue
		expect(bool(row.loop) and stream.get_length() > 1.0, "full-song asset remains complete and loopable: " + id)
		if id.begins_with("midi_test_"):
			expect(row.has("duration_seconds") and absf(stream.get_length() - float(row.get("duration_seconds", 0.0))) < 0.001, "export retains full published render duration: " + id)
			expect(str(row.path) == "res://assets/music/midi_test/" + id + ".ogg" and str(row.get("source_midi_sha256", "")).length() == 64, "new render retains frozen-source provenance: " + id)
			expect(row.get("arrangement_variant", "") == "D2" and row.get("source_audio_variant", "") == "D2", "export identifies approved D2 arrangement: " + id)
			for field in ["arrangement_midi_sha256", "arrangement_plan_sha256", "source_audio_sha256", "render_sha256"]:
				expect(str(row.get(field, "")).length() == 64, "export retains D2 provenance " + field + ": " + id)
			expect(row.has("integrated_lufs") and row.has("true_peak_dbtp"), "export retains game-level loudness metadata: " + id)
		else:
			expect(id in ["camp_home", "rest_spring", "hero_daily", "story_warmth"], "only approved warm original remains: " + id)
			var written_seconds := float(row.beats) * 60.0 / float(row.bpm)
			expect(absf(stream.get_length() - written_seconds) < 0.001, "retained old loop remains sample aligned: " + id)
	for index in range(1, 13): expect(ids.has("midi_test_%02d" % index), "export includes every new full song: %02d" % index)
	var directory := DirAccess.open("res://assets/music/chronicle")
	if directory != null:
		for file: String in directory.get_files():
			if file.ends_with(".ogg") or file.ends_with(".ogg.remap"):
				expect(file.trim_suffix(".remap").trim_suffix(".ogg") in ["camp_home", "rest_spring", "hero_daily", "story_warmth"], "export has no retired old music: " + file)
	var routing: Script = load("res://scripts/audio/music_catalog.gd")
	expect(routing != null and routing.chapter_cues().size() == 16, "exported runtime resolves the same catalog")
	print("CHRONICLE_MUSIC_PACK_SMOKE ", "PASS" if failures.is_empty() else "FAIL", " cues=", ids.size(), " checks=", checked, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
