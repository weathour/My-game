extends SceneTree
## External script: run against the shared exported PCK from an empty directory.
var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("run")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)

func run() -> void:
	expect(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated packed settings")
	var base := "res://assets/sfx/chronicle-feedback/"
	for file in ["catalog.json","source-license-manifest.json","CC0-LICENSE.txt"]:
		expect(FileAccess.file_exists(base + file), "raw feedback metadata packed " + file)
	if failures: finish(); return
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "catalog.json"))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "source-license-manifest.json"))
	expect(catalog.clips.size() == 22 and manifest.clips.size() == 22, "all 22 declared clips packed")
	for clip in catalog.clips:
		var path: String = base + str(clip.filename)
		expect(ResourceLoader.exists(path), "packed wave resource " + clip.filename)
		var stream := load(path) as AudioStreamWAV
		expect(stream != null, "actual WAV decoder " + clip.filename)
		if stream == null: continue
		expect(stream.mix_rate == 48000 and not stream.stereo and stream.format == AudioStreamWAV.FORMAT_16_BITS, "packed mono PCM16 " + clip.filename)
		expect(stream.data.size() > 100 and stream.get_length() > .03 and stream.get_length() <= 1.2, "packed nonempty short PCM " + clip.filename)
	for clip in manifest.clips:
		expect(clip.source.spdx == "CC0-1.0" and str(clip.source.author).length() > 0 and str(clip.source.source_sha256).length() == 64 and str(clip.qa.output_sha256).length() == 64, "source license and hashes survive export " + clip.filename)
	expect(not FileAccess.file_exists("res://scripts/tools/prepare_chronicle_feedback_audio.py"), "production script excluded")
	expect(not FileAccess.file_exists("res://assets/sfx/chronicle-feedback/source-evidence/80-cc0-rpg-sfx-oga.html"), "source webpages excluded")
	for local_dir in ["graphify-out", "scripts/graphify-out", ".omx"]:
		expect(not DirAccess.dir_exists_absolute("res://" + local_dir), "local tool indexes and caches excluded " + local_dir)
	for obsolete in ["assets/maps/baimen-feedback-20261030/road.png", "assets/maps/battle_map.png", "assets/maps/temp_reference_map.png", "assets/maps/grassland_3.png"]:
		expect(not ResourceLoader.exists("res://" + obsolete), "unused map resource excluded " + obsolete)
		expect(not FileAccess.file_exists("res://" + obsolete + ".import"), "unused map import excluded " + obsolete)
	var script := load("res://scripts/ui/chronicle/combat_feedback.gd") as Script
	expect(script != null, "compiled common feedback module loads")
	if script != null:
		var feedback: Node = script.new()
		root.add_child(feedback)
		await process_frame
		var count := 0
		for category in feedback.CATEGORIES:
			expect(feedback.streams[category].size() == feedback.CATEGORIES[category], "runtime category resolves packed clips " + category)
			count += feedback.streams[category].size()
		expect(count == 22 and feedback.voices.size() == 6, "packed runtime retains 22 clips and six voice pool")
		feedback.free()
	var environments_path := "res://assets/data/chronicle/battle_environments.json"
	expect(FileAccess.file_exists(environments_path), "raw environment manifest packed")
	if FileAccess.file_exists(environments_path):
		var environments: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(environments_path))
		expect(environments.environments.size() == 6 and environments.stages.size() == 18, "six environments and eighteen mappings packed")
		for id in environments.environments:
			var texture := load(str(environments.environments[id].texture)) as Texture2D
			expect(texture != null and texture.get_width() > 0 and texture.get_height() > 0, "packed ground actually decodes " + id)
		var art := load("res://scripts/ui/chronicle/battle_art.gd") as Script
		expect(art != null, "packed environment resolver loads")
		if art != null:
			for index in range(1,19):
				var stage := "B%02d" % index
				expect(environments.stages.has(stage), "stage mapping present " + stage)
				expect(art.has_environment_texture(stage) and art.map_texture(stage) != null and art.map_preview_texture(stage) != null, "stage ground and crop resolve " + stage)
	await process_frame
	finish()

func finish() -> void:
	print("CHRONICLE_COMBAT_FEEDBACK_PACK_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
