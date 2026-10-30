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
	var path := "res://assets/data/audio/music_catalog.json"
	expect(FileAccess.file_exists(path), "export contains the raw music catalog JSON")
	if not failures.is_empty():
		quit(1)
		return
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	expect(catalog is Dictionary and catalog.get("cues", []).size() == 70, "export contains the complete 70-cue roster")
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
		var written_seconds := float(row.beats) * 60.0 / float(row.bpm)
		if bool(row.loop):
			expect(absf(stream.get_length() - written_seconds) < 0.001, "loop remains sample-aligned after export: " + id)
		else:
			expect(stream.get_length() > 0.1 and stream.get_length() <= written_seconds + 2.001, "one-shot retains bounded release after export: " + id)
	var routing: Script = load("res://scripts/audio/music_catalog.gd")
	expect(routing != null and routing.chapter_cues().size() == 70, "exported runtime resolves the same catalog")
	print("CHRONICLE_MUSIC_PACK_SMOKE ", "PASS" if failures.is_empty() else "FAIL", " cues=", ids.size(), " checks=", checked, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
