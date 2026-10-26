extends SceneTree

const SETTINGS := preload("res://scripts/game_settings.gd")
const BGM := preload("res://scripts/bgm_player.gd")
const SAVE := preload("res://scripts/save_manager.gd")
const STORE := preload("res://scripts/save/save_file_store.gd")
const SURVIVAL := preload("res://scripts/player/player_survival_flow.gd")
var failures := 0

class CurrencyScene:
	extends Node2D
	var endless_run_id := "currency-check"

func check(ok: bool, why: String) -> void:
	if not ok:
		failures += 1
		push_error(why)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	check(ProjectSettings.globalize_path("user://").begins_with("/tmp/"), "isolated data required")
	if failures:
		quit(1)
		return
	SETTINGS.save_keycode(SETTINGS.ACTION_MOVE_UP, KEY_UP)
	BGM.save_music_volume(0.23)
	SETTINGS.save_sfx_volume(0.31)
	SETTINGS.save_comfort("reduced_motion", true)
	SETTINGS.cached_config = null
	check(is_equal_approx(BGM.load_music_volume(), 0.23), "music survives other settings writes")
	check(is_equal_approx(SETTINGS.load_sfx_volume(), 0.31) and SETTINGS.load_keycode("move_up") == KEY_UP, "sfx and remapping persist together")
	var warning := preload("res://scripts/game/spawn_warning_batch.gd").new()
	SETTINGS.save_comfort("reduced_flash", true)
	check(is_equal_approx(warning._get_alpha(0.01), warning._get_alpha(0.16)), "reduced flash keeps spawn telegraph steady")
	warning.free()
	SAVE.delete_endless_profile(9)
	SAVE.create_or_load_endless_profile(9)
	var scene := CurrencyScene.new()
	root.add_child(scene)
	current_scene = scene
	var player := preload("res://scenes/player.tscn").instantiate()
	scene.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.fire_timer.stop()
	player.configure_ruan_stones(SAVE.load_endless_profile(9))
	var bone := preload("res://scenes/bone_pickup.tscn").instantiate()
	scene.add_child(bone)
	bone.reset_pickup(player.global_position, 3)
	var old_snapshot: Dictionary = bone.get_save_data()
	var blocked := ProjectSettings.globalize_path(STORE.endless_profile_path(9) + ".tmp")
	DirAccess.make_dir_absolute(blocked)
	SURVIVAL.collect_nearby_gems(player)
	check(player.ruan_bone_count == 0 and bone.is_in_group("bone_pickups"), "failed currency save leaves balance and pickup unchanged")
	DirAccess.remove_absolute(blocked)
	player.set_meta("bone_save_retry_msec", 0)
	SURVIVAL.collect_nearby_gems(player)
	check(player.ruan_bone_count == 3 and SAVE.load_endless_profile(9).bones == 3, "retry persists currency before removing pickup")
	check(not bone.is_in_group("bone_pickups") or bone.is_queued_for_deletion(), "successful pickup removed")
	await process_frame
	var repeated := preload("res://scenes/bone_pickup.tscn").instantiate()
	scene.add_child(repeated)
	repeated.apply_save_data(old_snapshot)
	SURVIVAL.collect_nearby_gems(player)
	check(player.ruan_bone_count == 3 and SAVE.load_endless_profile(9).bones == 3, "older run snapshot cannot credit an already persisted pickup twice")
	check(not repeated.is_in_group("bone_pickups") or repeated.is_queued_for_deletion(), "duplicate pickup safely removed")
	check(SAVE.credit_bone_pickup(2, old_snapshot.pickup_id, "next-run") == 5, "receipt scope resets for a new run")
	player.role_skill_points = {"swordsman": 0, "gunner": 2, "mage": 0}
	var statuses: Array = player.get_frame_hud_summary().team_role_statuses
	check(statuses[0].skill_points == 0 and statuses[1].skill_points == 2, "HUD receives independent role skill points")
	var camera := Camera2D.new()
	player.camera_node = camera
	player.camera_shake_time = 1.0
	preload("res://scripts/player/player_camera_feedback.gd").update_camera_shake(player, 0.1)
	check(camera.offset == player.camera_base_offset and player.camera_shake_time == 0.0, "reduced motion clears camera shake")
	player.camera_node = null
	camera.free()
	SAVE.delete_endless_profile(9)
	scene.queue_free()
	await process_frame
	print("SYSTEM_FEEDBACK_SMOKE_OK" if failures == 0 else "SYSTEM_FEEDBACK_SMOKE_FAILED")
	quit(0 if failures == 0 else 1)
