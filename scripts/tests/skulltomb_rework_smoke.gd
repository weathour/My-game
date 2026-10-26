extends SceneTree

const ENEMY := preload("res://scenes/enemy.tscn")
const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const SKILLS := preload("res://scripts/enemies/enemy_skulltomb_behavior.gd")
const DOMAIN := preload("res://scripts/enemies/skulltomb_domain_effect.gd")
const STATUS := preload("res://scripts/enemies/enemy_status_effects.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Runtime.new()
	root.add_child(scene)
	current_scene = scene
	var player := DamagePlayer.new()
	scene.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.max_health = 1000.0
	player.current_health = 500.0
	player.switch_invulnerability_remaining = 0.0
	var enemy = _enemy(scene, player, "small_boss", "smallboss_rebirth")
	assert(is_equal_approx(enemy.attack, 30.0))
	assert(is_equal_approx(enemy.speed, 60.0))
	assert(is_equal_approx(enemy.armor, 20.0))
	assert(is_equal_approx(enemy.damage_reduction_rate, 0.1))
	assert(is_equal_approx(enemy.max_health, 3800.0))
	assert(is_equal_approx(enemy.try_stalwart_body_damage(), 45.0))
	enemy.stalwart_body_cooldown = 0.0
	enemy.dash_remaining = 1.0
	assert(is_equal_approx(enemy.try_stalwart_body_damage(), 90.0))
	enemy.dash_remaining = 0.0
	SKILLS._update_aging_aura(enemy, 1.0)
	# 500 * 12% + 1000 * 0.5% = 65; 20% reduction => 52, armor ignored.
	assert(is_equal_approx(player.current_health, 448.0))
	player.position = Vector2(751, 0)
	SKILLS._update_aging_aura(enemy, 1.0)
	assert(is_equal_approx(player.current_health, 448.0))
	# Ordinary damage must still use armor.
	player.take_damage(65.0)
	assert(player.current_health > 447.0 and player.current_health < 448.0)
	var soldier = _enemy(scene, player, "normal", "dasher")
	var shooter = _enemy(scene, player, "normal", "shooter")
	var shotgunner = _enemy(scene, player, "normal", "shotgunner")
	var splitshot = _enemy(scene, player, "elite", "elite_splitshot")
	enemy.skulltomb_summon_target_center = Vector2.ZERO
	player.position = Vector2(800, 0)
	SKILLS._finish_summon(enemy)
	assert(enemy.skulltomb_area_center == Vector2.ZERO)
	assert(not player.is_healing_blocked())
	assert(is_equal_approx(DOMAIN.get_slow_multiplier(player), 1.0))
	assert(enemy.skulltomb_pending_spawns.size() == 9)
	for request in enemy.skulltomb_pending_spawns:
		assert(request.type == "soldier")
	assert(is_equal_approx(soldier.skull_soldier_speed_multiplier, 2.0))
	assert(is_equal_approx(soldier.skull_damage_immune_timer, 5.0))
	player.position = Vector2.ZERO
	assert(player.is_healing_blocked())
	assert(is_equal_approx(DOMAIN.get_slow_multiplier(player), 0.9))
	player.position = Vector2(550, 0) # Inside circumcircle but outside triangle.
	assert(not player.is_healing_blocked())
	player.position = Vector2.ZERO
	enemy.skulltomb_area_remaining = 4.0
	var saved: Dictionary = enemy.get_save_data()
	SKILLS._clear_summon_area(enemy)
	assert(not player.is_healing_blocked())
	enemy.apply_save_data(saved, player)
	assert(is_equal_approx(DOMAIN.get_remaining(player), 4.0))
	assert(enemy.skulltomb_pending_spawns.size() == 9)
	soldier.current_health = 0.0
	SKILLS._update_summon_area(enemy, 1.0)
	assert(enemy.skulltomb_pending_spawns.size() == 10)
	SKILLS._update_pending_spawns(enemy, 0.14)
	assert(scene.requests.size() == 1)
	assert(scene.requests[0].archetype == "dasher")
	assert(is_equal_approx(scene.requests[0].skull_damage_immune_timer, 5.0))
	soldier.current_health = 60.0
	STATUS.tick_timers(soldier, 5.0)
	assert(is_equal_approx(soldier.skull_soldier_speed_multiplier, 1.0))
	assert(SKILLS.handle_lethal_damage(enemy))
	assert(not player.is_healing_blocked())
	assert(is_equal_approx(player.enemy_move_slow_multiplier, 0.25))
	assert(is_equal_approx(player.enemy_move_slow_remaining, 4.5)) # Swordsman has 10% status resistance.
	assert(is_equal_approx(soldier.skull_soldier_speed_multiplier, 1.0))
	for ranged in [shooter, shotgunner, splitshot]:
		assert(is_equal_approx(ranged.skullshot_attack_frequency_multiplier, 1.3))
		assert(is_equal_approx(ranged.skullshot_attack_frequency_timer, 5.0))
	var tomb_save: Dictionary = enemy.get_save_data()
	enemy.apply_save_data(tomb_save, player)
	assert(enemy.skulltomb_tomb_instance != null)
	SKILLS._update_rebirth(enemy, 5.0)
	assert(is_equal_approx(enemy.current_health, 3800.0))
	assert(enemy.rebirth_lives_remaining == 0)
	assert(not SKILLS.handle_lethal_damage(enemy))
	SKILLS.clear_runtime_effects_after_defeat(enemy)
	scene.free()
	current_scene = null
	print("SKULLTOMB_REWORK_SMOKE_OK")
	quit(0)


func _enemy(scene: Node, player: Node2D, kind: String, archetype: String):
	var enemy = ENEMY.instantiate()
	scene.add_child(enemy)
	enemy.apply_enemy_profile(kind, DATABASE.get_profile(kind, archetype))
	enemy.target = player
	enemy.set_physics_process(false)
	return enemy


class Runtime:
	extends Node2D
	var requests: Array[Dictionary] = []

	func queue_runtime_enemy_spawn(request: Dictionary) -> void:
		requests.append(request)


class DamagePlayer:
	extends "res://scripts/player.gd"

	func _try_equipment_dodge() -> bool:
		return false

	func _get_effective_damage_taken_multiplier() -> float:
		return 0.8

	func get_role_armor(_role_id: String = "") -> float:
		return 10000.0

	func _count_enemies_in_radius(_center: Vector2, _radius: float) -> int:
		return 0

	func _play_player_hurt_feedback() -> void:
		pass
