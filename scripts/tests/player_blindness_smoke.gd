extends SceneTree

const BLINDNESS := preload("res://scripts/player/player_blindness.gd")
const SURVIVAL := preload("res://scripts/player/player_survival_flow.gd")
const PROFILES := preload("res://scripts/enemy/enemy_archetype_database.gd")
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := DamagePlayer.new()
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	var enemy := SourceEnemy.new()
	root.add_child(enemy)
	var profile := PROFILES.get_profile("normal", "swarm")
	_expect(profile.attack == 10.0 and profile.armor == -10.0 and profile.speed == 200.0 and profile.max_health == 20.0, "swarm profile")
	player.switch_invulnerability_remaining = 1.0
	SURVIVAL.take_damage(player, 15.0, enemy)
	_expect(BLINDNESS.get_effect(player) == null, "invulnerable hit must not blind")
	player.switch_invulnerability_remaining = 0.0
	player.force_dodge = true
	SURVIVAL.take_damage(player, 15.0, enemy)
	_expect(BLINDNESS.get_effect(player) == null, "dodged hit must not blind")
	player.force_dodge = false
	var old_health: float = player.current_health
	SURVIVAL.take_damage(player, 15.0, enemy)
	var effect = BLINDNESS.get_effect(player)
	_expect(player.current_health < old_health, "swarm hit should damage")
	_expect(effect != null and effect.remaining == 2.5 and effect.cooldown_remaining == 10.0, "damage triggers blindness")
	effect.set_process(false)
	effect.tick(0.5)
	BLINDNESS.on_enemy_damage(player, enemy, 15.0)
	_expect(effect.remaining == 2.0 and effect.cooldown_remaining == 9.5, "cannot stack or refresh")
	var saved: Dictionary = BLINDNESS.save_state(player)
	BLINDNESS.cleanse(player)
	_expect(effect.remaining == 0.0 and effect.cooldown_remaining == 9.5, "cleanse keeps proc cooldown")
	BLINDNESS.restore_state(player, saved)
	_expect(effect.remaining == 2.0 and effect.cooldown_remaining == 9.5, "restore both timers")
	effect.tick(1.0)
	_expect(not effect.try_apply(), "expiry does not reset cooldown")
	effect.tick(8.5)
	enemy.archetype_id = "chaser"
	BLINDNESS.on_enemy_damage(player, enemy, 15.0)
	_expect(effect.remaining == 0.0, "other enemies do not blind")
	enemy.archetype_id = "swarm"
	BLINDNESS.on_enemy_damage(player, enemy, 0.0)
	_expect(effect.remaining == 0.0, "zero damage does not blind")
	BLINDNESS.on_enemy_damage(player, enemy, 15.0)
	_expect(effect.remaining == 2.5, "retrigger after ten seconds")
	paused = true
	var before: float = effect.remaining
	effect.set_process(true)
	await process_frame
	await process_frame
	_expect(effect.remaining == before, "pause freezes blindness")
	paused = false
	player.queue_free()
	enemy.queue_free()
	await process_frame
	if failures.is_empty():
		print("PLAYER_BLINDNESS_SMOKE_OK")
		quit(0)
	else:
		for message in failures:
			push_error(message)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


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
