extends SceneTree

const PLAYER := preload("res://scenes/player.tscn")
const SKILLS := preload("res://scripts/player/player_blessing_skill_state.gd")
const FLOW := preload("res://scripts/player/player_ability_flow.gd")
const COOLDOWNS := preload("res://scripts/player/player_skill_cooldown_flow.gd")
const EQUIPMENT := preload("res://scripts/player/player_equipment_flow.gd")
const SURVIVAL := preload("res://scripts/player/player_survival_flow.gd")
const SETTINGS := preload("res://scripts/game_settings.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var player = PLAYER.instantiate()
	scene.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.auto_attack_enabled = false
	player.fire_timer.stop()
	player.active_role_index = 1
	for skill_id in ["shrapnel_field", "infinite_reload"]:
		SKILLS.force_unlock_skill(player, skill_id, 1)
	var old_manual := SETTINGS.is_skill_manual("infinite_reload")
	var old_shrapnel_manual := SETTINGS.is_skill_manual("shrapnel_field")
	var old_order := SETTINGS.get_skill_slot_order("gunner")
	SETTINGS.set_skill_manual("infinite_reload", false)
	SETTINGS.set_skill_manual("shrapnel_field", false)
	SETTINGS.set_skill_slot_order("gunner", ["shrapnel_field", "infinite_reload"])
	player.role_special_states["gunner"]["skill_levels"] = {"gunner_infinite_reload": 9}
	player.role_special_states["gunner"]["infinite_reload_build"] = {"4": "light_step", "8": "soul_form", "9": "fire_control"}
	var ability := MeasuredReload.new()
	player.gunner_infinite_reload_ability = ability
	check(COOLDOWNS.get_role_active_skill_ids(player, "gunner") == ["shrapnel_field", "infinite_reload"], "hotkeys retain the configured slot order")
	check(not ability.try_trigger(player), "fire control never auto-casts")
	check(FLOW.try_handle_manual_skill_slot(player, 1) and not ability.is_active(), "another automatic slot does not activate reload")
	var base_dodge: float = EQUIPMENT.get_role_dodge_chance(player, "gunner")
	check(FLOW.try_handle_manual_skill_slot(player, 2) and ability.is_active(), "fire control hotkey opens despite the automatic release setting")
	var slot := ability.get_cooldown_slot(player)
	check(is_equal_approx(slot.remaining, 1.0) and is_equal_approx(slot.duration, 1.0) and slot.toggle_mode, "HUD shows the current one-second close lock")
	check(not FLOW.is_gunner_infinite_reload_blocking_actions(player) and not SURVIVAL.is_movement_locked(player), "reload does not lock movement or other skills")
	check(is_equal_approx(EQUIPMENT.get_role_dodge_chance(player, "gunner"), minf(1.0, base_dodge + 0.3)), "light step adds thirty dodge percentage points")
	check(ability.get_dodge_chance_bonus("swordsman") == 0.0, "light step dodge remains role-specific")
	check(ability.pending_beam_hits.size() == 1, "first beam waits for the gather visual")
	check(not FLOW.try_handle_manual_skill_slot(player, 2) and ability.is_preventing_switch(player), "cannot close or switch during the first second")
	ability.update(player, 0.9)
	check(is_equal_approx(ability.get_cooldown_slot(player).remaining, 0.1), "close lock counts down")
	check(not FLOW.try_handle_manual_skill_slot(player, 2), "cannot close at 0.9 seconds")
	ability.update(player, 0.1)
	check(not ability.is_preventing_switch(player), "switch lock expires at one second")
	check(not ability.hits.is_empty() and ability.hits[0].size() == 1, "fire control retains one lane without dual impact")
	if not ability.hits.is_empty():
		check(is_equal_approx(ability.hits[0][0].length, 600.0), "light step and LV6 each add 100 range")
	check(FLOW.try_handle_manual_skill_slot(player, 2) and not ability.is_active(), "hotkey closes after one second")
	check(ability.cooldown_remaining == 0.0, "fire control closes without cooldown")
	check(is_equal_approx(EQUIPMENT.get_role_dodge_chance(player, "gunner"), base_dodge), "closing removes light step dodge")
	check(FLOW.try_handle_manual_skill_slot(player, 2) and ability.is_active(), "fire control can reopen immediately")
	ability.stop()
	SETTINGS.set_skill_manual("infinite_reload", old_manual)
	SETTINGS.set_skill_manual("shrapnel_field", old_shrapnel_manual)
	SETTINGS.set_skill_slot_order("gunner", old_order)
	scene.queue_free()
	await process_frame
	for message in failures:
		push_error(message)
	print("GUNNER_INFINITE_RELOAD_MANUAL_SMOKE_OK" if failures.is_empty() else "GUNNER_INFINITE_RELOAD_MANUAL_SMOKE_FAILED")
	quit(0 if failures.is_empty() else 1)

class MeasuredReload:
	extends "res://scripts/abilities/gunner_infinite_reload_ability.gd"
	var hits: Array = []
	func _apply_piercing_beam_shapes(_owner, shapes: Array[Dictionary]) -> int:
		hits.append(shapes.duplicate(true))
		return 0
	func _spawn_visuals(_owner, _origin: Vector2, _direction: Vector2, _length: float, _width: float) -> void:
		pass
