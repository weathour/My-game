extends SceneTree

const SURVIVAL := preload("res://scripts/player/player_survival_flow.gd")
const BLINDNESS := preload("res://scripts/player/player_blindness.gd")
const PAYLOAD := preload("res://scripts/player/player_stat_payload.gd")
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := TestScene.new()
	root.add_child(scene)
	current_scene = scene
	var player := DamagePlayer.new()
	scene.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.fire_timer.stop()
	var enemy := SourceEnemy.new()
	scene.add_child(enemy)
	var other_eye := SourceEnemy.new()
	scene.add_child(other_eye)

	for tier in [0, 1, 2, 3, 8]:
		scene.difficulty_profile = {"tier": tier} if tier > 0 else {"id": "normal"}
		player.plague_remaining = 0.0
		SURVIVAL.take_damage(player, 1.0, enemy)
		_expect(is_equal_approx(player.plague_remaining, 1.5 if tier >= 3 else 0.0), "difficulty gate N%d" % tier)
	scene.difficulty_profile = {"tier": 3}
	player.plague_remaining = 0.0
	player.switch_invulnerability_remaining = 1.0
	SURVIVAL.take_damage(player, 1.0, enemy)
	_expect(player.plague_remaining == 0.0, "invulnerability prevents plague")
	player.switch_invulnerability_remaining = 0.0
	player.force_dodge = true
	SURVIVAL.take_damage(player, 1.0, enemy)
	_expect(player.plague_remaining == 0.0, "dodge prevents plague")
	player.force_dodge = false
	SURVIVAL.take_damage(player, 0.0, enemy)
	SURVIVAL.take_damage(player, 1.0)
	enemy.archetype_id = "runner"
	SURVIVAL.take_damage(player, 1.0, enemy)
	_expect(player.plague_remaining == 0.0, "zero damage, absent source and other enemies do not trigger")
	enemy.archetype_id = "swarm"

	var active_role: String = player._get_active_role_id()
	var base_speed: float = player._get_role_move_speed(active_role)
	player.grant_temporary_health(10.0)
	var hp_before: float = player.current_health
	SURVIVAL.take_damage(player, 1.0, enemy)
	_expect(is_equal_approx(player.current_health, hp_before) and player.current_temporary_health < 10.0, "temporary health absorbs actual hit")
	_expect(player.plague_remaining == 1.5, "temporary health damage still applies plague")
	player._clear_temporary_health()
	_expect(is_equal_approx(player._get_role_move_speed(active_role), base_speed * 0.8), "actual movement is reduced by 20 percent")
	player._update_timers(0.5)
	_expect(is_equal_approx(player.plague_remaining, 1.0), "normal runtime timers tick plague")
	SURVIVAL.take_damage(player, 1.0, other_eye)
	_expect(player.plague_remaining == 1.5, "another flying eye refreshes the same timer")
	_expect(is_equal_approx(player._get_role_move_speed(active_role), base_speed * 0.8), "repeated damage does not stack slow")
	var blindness = BLINDNESS.get_effect(player)
	_expect(blindness != null and blindness.cooldown_remaining > 0.0, "blindness remains independent")
	if blindness != null:
		blindness.set_process(false)

	player.current_health = 40.0
	player._save_active_role_health()
	player._heal(10.0)
	_expect(is_equal_approx(player.current_health, 47.0), "normal healing is multiplied by 0.7 exactly once")
	player._heal_role(active_role, 10.0)
	_expect(is_equal_approx(player.current_health, 54.0), "role healing is multiplied by 0.7 exactly once")
	player.equipment_health_regen_per_second = 10.0
	player._apply_equipment_passives(1.0)
	_expect(is_equal_approx(player.current_health, 61.0), "passive regeneration uses reduced healing")
	player.equipment_health_regen_per_second = 0.0
	player.healing_block_remaining = 1.0
	player._heal(10.0)
	player._heal_role(active_role, 10.0)
	_expect(is_equal_approx(player.current_health, 61.0), "healing block takes precedence")
	player.healing_block_remaining = 0.0
	player.grant_temporary_health(10.0)
	_expect(is_equal_approx(player.current_temporary_health, 10.0), "temporary health is not healing")
	player._clear_temporary_health()
	var slots: Array = PAYLOAD._build_buff_status_slots(player)
	var plague_slots: Array = slots.filter(func(slot: Dictionary) -> bool: return slot.get("id") == "plague")
	_expect(plague_slots.size() == 1 and plague_slots[0].get("remaining") == 1.5, "HUD shows one plague status and timer")

	player.apply_enemy_slow(0.5, 0.5)
	_expect(is_equal_approx(player._get_role_move_speed(active_role), base_speed * 0.5), "strongest existing slow wins")
	player._update_timers(0.5)
	_expect(is_equal_approx(player._get_role_move_speed(active_role), base_speed * 0.8), "plague remains after shorter independent slow expires")
	player.apply_enemy_slow(0.9, 3.0)
	player._update_timers(1.0)
	_expect(player.plague_remaining == 0.0, "plague expires at 1.5 seconds after refresh")
	_expect(is_equal_approx(player._get_role_move_speed(active_role), base_speed * 0.9), "plague expiry preserves another slow")
	player._heal(10.0)
	_expect(is_equal_approx(player.current_health, 71.0), "healing returns to full immediately on expiry")
	_expect(PAYLOAD._build_buff_status_slots(player).filter(func(slot: Dictionary) -> bool: return slot.get("id") == "plague").is_empty(), "expired plague leaves HUD")

	SURVIVAL.take_damage(player, 1.0, enemy)
	player._update_timers(0.5)
	var saved: Dictionary = player.get_save_data()
	var target := DamagePlayer.new()
	scene.add_child(target)
	target.set_physics_process(false)
	target.set_process(false)
	target.apply_save_data(saved)
	target.fire_timer.stop()
	_expect(is_equal_approx(target.plague_remaining, 1.0), "save restores exact remaining time")
	target.current_health = 40.0
	target._heal(10.0)
	_expect(is_equal_approx(target.current_health, 47.0), "restored plague reduces healing")
	var restored_speed: float = target._get_role_move_speed(target._get_active_role_id())
	target._update_timers(1.0)
	_expect(is_equal_approx(restored_speed / target._get_role_move_speed(target._get_active_role_id()), 0.8 / 0.9), "restored plague slow expires independently")
	saved.erase("plague_remaining")
	target.plague_remaining = 1.5
	target.apply_save_data(saved)
	target.fire_timer.stop()
	_expect(target.plague_remaining == 0.0, "save without plague field clears previous status")

	player._try_switch_role(1, true)
	player.fire_timer.stop()
	_expect(is_equal_approx(player.plague_remaining, 1.0), "role switching preserves remaining duration")
	var switched_role: String = player._get_active_role_id()
	var switched_speed: float = player._get_role_move_speed(switched_role)
	player.plague_remaining = 0.0
	_expect(is_equal_approx(switched_speed / player._get_role_move_speed(switched_role), 0.8 / 0.9), "switched character receives plague slow")
	player.plague_remaining = 1.0
	paused = true
	player.set_physics_process(true)
	await process_frame
	await process_frame
	_expect(is_equal_approx(player.plague_remaining, 1.0), "pause freezes plague timer")
	paused = false
	await physics_frame
	await physics_frame
	player.set_physics_process(false)
	player.fire_timer.stop()
	_expect(player.plague_remaining > 0.0 and player.plague_remaining < 1.0, "real physics processing advances plague timer")
	SURVIVAL._start_death_sequence(player)
	_expect(player.plague_remaining == 0.0, "death clears plague")

	scene.queue_free()
	await process_frame
	current_scene = null
	if failures.is_empty():
		print("PLAYER_PLAGUE_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


class TestScene:
	extends Node2D
	var difficulty_profile: Dictionary = {}


class SourceEnemy:
	extends Node2D
	var archetype_id := "swarm"


class DamagePlayer:
	extends "res://scripts/player.gd"
	var force_dodge: bool = false

	func _try_equipment_dodge() -> bool:
		return force_dodge

	func _play_player_hurt_feedback() -> void:
		pass
