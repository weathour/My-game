extends SceneTree
## External script: run against the shared exported PCK from an empty directory.
const ART := preload("res://scripts/ui/chronicle/battle_art.gd")
const PROFILE := preload("res://scripts/ui/chronicle/skill_presentation_profiles.gd")
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
		expect(count == 22 and feedback.voices.size() == 14, "packed runtime preserves legacy input provenance and shares fourteen voices")
		feedback.free()
	var skill_bank_path := "res://assets/sfx/skill-combat-20261103/catalog.json"
	var profiles_path := "res://assets/data/audio/skill_sound_profiles.json"
	expect(FileAccess.file_exists(skill_bank_path) and FileAccess.file_exists(profiles_path),"new audio bank and profiles remain raw-readable in independent PCK")
	if FileAccess.file_exists(skill_bank_path) and FileAccess.file_exists(profiles_path):
		var skill_bank: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(skill_bank_path))
		var profiles: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(profiles_path))
		expect(skill_bank.cues.size()==104,"complete 101-new plus three-utility cue bank packed")
		var variants:=0
		for cue: String in skill_bank.cues:
			for path: String in skill_bank.cues[cue].variants:
				var wave:=load(path) as AudioStreamWAV
				expect(wave!=null and wave.mix_rate==48000 and not wave.stereo and wave.format==AudioStreamWAV.FORMAT_16_BITS,"packed new/utility sound actually decodes: "+path)
				if wave!=null: expect(wave.loop_mode==AudioStreamWAV.LOOP_DISABLED and wave.get_length()>.02,"packed sound remains a complete one-shot: "+path)
				variants+=1
		expect(variants==309,"all 303 new and six retained utility WAV variants resolve")
		var abilities:=0
		for owner in profiles.character_abilities: abilities+=profiles.character_abilities[owner].size()
		var moves:=0
		for enemy in profiles.enemy_actions:
			for form in profiles.enemy_actions[enemy]: moves+=profiles.enemy_actions[enemy][form].size()
		expect(abilities==137 and moves==81,"export contains every character ability and unique enemy action profile")
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
	await verify_skill_presentation_pack()
	await process_frame
	finish()

func verify_skill_presentation_pack() -> void:
	var profile_path := "res://assets/data/chronicle/skill_presentation_profiles.json"
	var copy_path := "res://assets/data/chronicle/skill_presentation_copy.json"
	expect(FileAccess.file_exists(profile_path) and FileAccess.file_exists(copy_path), "137 presentation profiles and skill/owned copy are included as raw PCK data")
	if not FileAccess.file_exists(profile_path) or not FileAccess.file_exists(copy_path): return
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile_path))
	var copy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(copy_path))
	expect(profiles.get("ability_profiles", {}).size() == 137, "all 137 unique skill presentation profiles survive export")
	expect(copy.get("ability_categories", {}).size() >= 10 and copy.get("owned_bonus", {}).has("next_preview_delta"), "skill labels and owned passive cap-preview copy survive export")
	var loaded_profiles: Dictionary = PROFILE.all_profiles()
	expect(loaded_profiles.size() == 137, "packed runtime reads all exported style rows")
	var expected_ids := ["M07","M08","F01","F11","N01","N02","N03","N04","N05","N06","N07","N08","N09","N10","N11","N12","N13","N14","N15","N16","N17","N18"]
	for id in expected_ids:
		var actor_scene: PackedScene = ART.actor(id)
		var head_scene: PackedScene = ART.portrait(id)
		expect(actor_scene != null and actor_scene.resource_path.contains("/chronicle-cast/%s/" % id), "independent actor scene included for " + id)
		expect(head_scene != null and head_scene.resource_path.contains("/chronicle-cast/%s/" % id), "independent portrait scene included for " + id)
		var manifest_path := "res://assets/players/chronicle-cast/%s/manifest.json" % id
		expect(FileAccess.file_exists(manifest_path), "raw actor manifest included for " + id)
		if FileAccess.file_exists(manifest_path):
			var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
			expect(str(manifest.get("character_id", "")) == id and manifest.get("clips", {}).size() >= 5, "five manifested action clips remain addressable for " + id)
		if actor_scene != null:
			var visual: Node2D = actor_scene.instantiate()
			root.add_child(visual)
			await process_frame
			expect(visual.has_method("present_cast") and visual.has_method("presentation_snapshot"), "packed actor controller compiles its action API " + id)
			var sprite := visual.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			expect(sprite != null and sprite.sprite_frames != null, "packed actor SpriteFrames instantiate " + id)
			if sprite != null and sprite.sprite_frames != null:
				for clip in ["idle","move","attack","special","hit"]:
					expect(sprite.sprite_frames.has_animation(clip) and sprite.sprite_frames.get_frame_count(clip) > 0, "packed actor clip decodes " + id + "/" + clip)
			visual.queue_free();await process_frame
		if head_scene != null:
			var head: Node = head_scene.instantiate()
			root.add_child(head);await process_frame
			var texture_found := false
			for node in head.find_children("*", "Sprite2D", true, false):
				if (node as Sprite2D).texture != null: texture_found = true
			for node in head.find_children("*", "AnimatedSprite2D", true, false):
				if (node as AnimatedSprite2D).sprite_frames != null: texture_found = true
			for node in head.find_children("*", "TextureRect", true, false):
				if (node as TextureRect).texture != null: texture_found = true
			expect(texture_found, "packed portrait texture decodes " + id)
			head.queue_free();await process_frame

func finish() -> void:
	print("CHRONICLE_COMBAT_FEEDBACK_PACK_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
