extends SceneTree

const MUSHROOM_SWARM := preload("res://scripts/enemies/enemy_mushroom_swarm.gd")
const STALWART_BODY := preload("res://scripts/enemies/enemy_stalwart_body.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := MushroomSwarmScene.new()
	root.add_child(scene)
	current_scene = scene
	scene.difficulty_profile = {"tier": 3}

	var chasers: Array = []
	for index in range(9):
		var chaser := EnemyStub.new()
		chaser.archetype_id = "chaser"
		chaser.current_health = 30.0
		scene.add_child(chaser)
		scene.enemies.append(chaser)
		chasers.append(chaser)

	var active_chaser: EnemyStub = chasers[0]
	assert(MUSHROOM_SWARM.get_active_chaser_count(active_chaser) == 9)
	assert(is_equal_approx(MUSHROOM_SWARM.get_armor_bonus(active_chaser), 5.0))
	assert(is_equal_approx(STALWART_BODY.try_trigger(active_chaser), 30.0))

	scene.difficulty_profile = {"tier": 2}
	active_chaser.stalwart_body_cooldown = 0.0
	assert(is_zero_approx(MUSHROOM_SWARM.get_armor_bonus(active_chaser)))
	assert(is_equal_approx(STALWART_BODY.try_trigger(active_chaser), 22.5))

	scene.difficulty_profile = {"tier": 3}
	scene.enemies[8].current_health = 0.0
	active_chaser.stalwart_body_cooldown = 0.0
	MUSHROOM_SWARM.invalidate_cache()
	assert(MUSHROOM_SWARM.get_active_chaser_count(active_chaser) == 8)
	assert(is_zero_approx(MUSHROOM_SWARM.get_armor_bonus(active_chaser)))
	assert(is_equal_approx(STALWART_BODY.try_trigger(active_chaser), 22.5))

	print("ENEMY_MUSHROOM_SWARM_SMOKE_OK")
	quit(0)


class MushroomSwarmScene:
	extends Node

	var difficulty_profile: Dictionary = {}
	var enemies: Array = []

	func get_runtime_enemies() -> Array:
		return enemies


class EnemyStub:
	extends Node2D

	var archetype_id: String = "chaser"
	var current_health: float = 30.0
	var attack: float = 15.0
	var armor: float = 5.0
	var stalwart_body_cooldown: float = 0.0
	var pooled_inactive: bool = false
	var rebirth_timer: float = 0.0
	var boss_phase_transition_target: int = 0
	var boss_phase_three_intro_remaining: float = 0.0
