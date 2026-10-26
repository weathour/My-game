extends SceneTree

func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	assert(arguments.size() == 1, "Pass an absolute development PCK path after --")
	assert(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "Use isolated data")
	assert(ProjectSettings.load_resource_pack(arguments[0]), "Package must load")
	assert(FileAccess.file_exists("res://assets/story/chapter1.json"), "Story JSON included")
	assert(FileAccess.file_exists("res://data/achievements.json"), "Achievement JSON included")
	assert(not ResourceLoader.exists("res://scripts/tests/story_ui_smoke.gd"), "Tests and compiled remaps excluded from package")
	assert(not FileAccess.file_exists("res://addons/godot_mcp/plugin.cfg"), "Editor addon excluded")
	for legacy in ["game_bgm.mp3", "game_bgm.ogg", "menu_bgm.mp3", "menu_bgm.ogg"]:
		assert(not ResourceLoader.exists("res://assets/" + legacy), "Unused placeholder music excluded: " + legacy)
	var music = load("res://scripts/audio/music_catalog.gd")
	for cue in music.CUES:
		var track = load(music.path(cue))
		assert(track is AudioStreamOggVorbis and track.get_length() > 0.0, "Packaged original music loads: " + cue)
	var content = load("res://scripts/story/story_content.gd")
	var progress = load("res://scripts/story/story_progress.gd")
	var save = load("res://scripts/save_manager.gd")
	assert(content.validate().is_empty(), "Packaged content validates")
	assert(progress.open_slot(1).ok, "Packaged story creates profile")
	for quest: Dictionary in content.entries("quests"):
		assert(progress.accept_quest(1, quest.id, quest.accept_npc).ok)
		var started: Dictionary = progress.begin_stage(1, quest.stage_id, "advance")
		assert(started.ok)
		var run: Dictionary = save.load_run(1, "story")
		run.pending_settlement = started.profile.story.active_attempt.duplicate(true)
		run.pending_settlement.outcome = "victory"
		assert(save.save_run(run, 1, "story") > 0)
		assert(progress.settle_stage(1, run.story_attempt.attempt_id).ok)
		assert(progress.turn_in_quest(1, quest.id, quest.turn_in_npc).ok)
	assert(save.load_story_profile(1).current_stage_index == 3)
	save.delete_story_profile(1)
	print("PACKAGE_CONTENT_CHECK_OK")
	quit(0)
