extends SceneTree

const DamageResolver := preload("res://scripts/player/player_damage_resolver.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := CombatScene.new()
	root.add_child(scene)
	current_scene = scene
	var owner := StoneOwner.new()
	scene.add_child(owner)
	var enemies: Array[StoneEnemy] = []
	for index in range(4):
		var enemy := StoneEnemy.new()
		enemy.global_position = Vector2(float(index) * 100.0, 0.0)
		scene.add_child(enemy)
		enemies.append(enemy)
	scene.enemies = enemies

	owner.equipped_ruan_stone = "thunder"
	owner.ruan_stone_levels = {"thunder": 1}
	DamageResolver.deal_damage_to_enemy(owner, enemies[0], 10.0, "swordsman_basic:event_thunder")
	assert(is_equal_approx(enemies[0].damage_taken, 10.0))
	assert(is_equal_approx(enemies[1].damage_taken, 3.0))
	DamageResolver.deal_damage_to_enemy(owner, enemies[2], 10.0, "swordsman_basic:event_thunder")
	assert(is_equal_approx(enemies[3].damage_taken, 0.0))

	_reset(enemies)
	owner.ruan_stone_proc_events.clear()
	owner.equipped_ruan_stone = "flame"
	owner.ruan_stone_levels = {"flame": 1}
	owner.stone_rings = 0
	DamageResolver.deal_damage_to_enemy(owner, enemies[0], 20.0, "mage_basic:event_flame")
	assert(is_equal_approx(enemies[1].damage_taken, 0.0))
	assert(is_equal_approx(enemies[2].damage_taken, 0.0))
	assert(is_equal_approx(enemies[3].damage_taken, 0.0))
	assert(owner.stone_rings == 0)

	_reset(enemies)
	owner.ruan_stone_proc_events.clear()
	owner.equipped_ruan_stone = "frost"
	owner.ruan_stone_levels = {"frost": 1}
	DamageResolver.deal_damage_to_enemy(owner, enemies[0], 10.0, "gunner_basic:event_frost", 0.0, 2.0, 1.0, 0.0, null, false, 0.0, false, "event_frost")
	assert(is_equal_approx(enemies[0].slow_multiplier, 0.55))
	assert(is_equal_approx(enemies[0].slow_duration, 1.2))

	_reset(enemies)
	owner.ruan_stone_proc_events.clear()
	owner.equipped_ruan_stone = "fury"
	owner.ruan_stone_levels = {"fury": 1}
	DamageResolver.deal_damage_to_enemy(owner, enemies[0], 10.0, "swordsman_basic:event_fury")
	assert(is_equal_approx(enemies[0].vulnerability_at_last_hit, 0.0))
	assert(is_equal_approx(enemies[0].vulnerability_bonus, 0.06))

	_reset(enemies)
	owner.ruan_stone_proc_events.clear()
	owner.equipped_ruan_stone = "poison"
	owner.ruan_stone_levels = {"poison": 1}
	DamageResolver.deal_damage_to_enemy(owner, enemies[0], 10.0, "mage_basic:event_poison")
	var poison := enemies[0].get_node("RuanPoisonEffect")
	for _tick in range(12):
		poison._process(0.25)
	assert(is_equal_approx(enemies[0].damage_taken, 14.5))

	_reset(enemies)
	owner.ruan_stone_proc_events.clear()
	owner.equipped_ruan_stone = "poison"
	owner.ruan_stone_levels = {"poison": 1}
	DamageResolver.deal_damage_to_enemy(owner, enemies[0], 10.0, "mage_basic:event_poison_first")
	poison = enemies[0].get_node("RuanPoisonEffect")
	for _tick in range(4):
		poison._process(0.25)
	DamageResolver.deal_damage_to_enemy(owner, enemies[0], 10.0, "mage_basic:event_poison_second")
	for _tick in range(8):
		poison._process(0.25)
	assert(is_equal_approx(enemies[0].damage_taken, 27.5))
	for _tick in range(4):
		poison._process(0.25)
	assert(is_equal_approx(enemies[0].damage_taken, 29.0))

	_reset(enemies)
	owner.ruan_stone_proc_events.clear()
	owner.equipped_ruan_stone = "thunder"
	owner.ruan_stone_levels = {"thunder": 1}
	DamageResolver.damage_enemies_in_oriented_rect_unique(owner, enemies[0].global_position, Vector2.RIGHT, 20.0, 20.0, 10.0, 0.0, 1.0, 0.0, {}, "swordsman_basic:event_batched_sword")
	var queue := scene.get_node("PlayerDamageJobQueue")
	queue._apply_job_at_index(0)
	assert(is_equal_approx(enemies[0].damage_taken, 10.0))
	assert(is_equal_approx(enemies[1].damage_taken, 3.0))

	_reset(enemies)
	owner.ruan_stone_proc_events.clear()
	owner.equipped_ruan_stone = "frost"
	owner.ruan_stone_levels = {"frost": 1}
	DamageResolver.damage_enemies_in_radius(owner, enemies[0].global_position, 20.0, 10.0, 0.0, 1.0, 0.0, "mage_basic:event_batched_mage")
	queue._apply_job_at_index(1)
	assert(is_equal_approx(enemies[0].slow_multiplier, 0.55))

	_reset(enemies)
	owner.ruan_stone_proc_events.clear()
	owner.equipped_ruan_stone = "flame"
	owner.ruan_stone_levels = {"flame": 1}
	owner.stone_rings = 0
	enemies[0].max_health = 200.0
	enemies[0].current_health = 10.0
	enemies[0].remove_on_death = true
	DamageResolver.queue_damage_to_enemy(owner, enemies[0], 10.0, "mage_basic:event_batched_flame")
	queue._apply_job_at_index(2)
	assert(enemies[0].get_parent() == null)
	assert(is_equal_approx(enemies[1].damage_taken, 16.0))
	assert(is_equal_approx(enemies[2].damage_taken, 16.0))
	assert(is_equal_approx(enemies[3].damage_taken, 0.0))
	assert(owner.stone_rings == 1)
	scene.add_child(enemies[0])

	_reset(enemies)
	owner.ruan_stone_proc_events.clear()
	owner.equipped_ruan_stone = "thunder"
	owner.ruan_stone_levels = {"thunder": 1}
	DamageResolver.deal_damage_to_enemy(owner, enemies[0], 10.0, "mage")
	assert(is_equal_approx(enemies[0].damage_taken, 10.0))
	assert(is_equal_approx(enemies[1].damage_taken, 0.0))

	_reset(enemies)
	owner.ruan_stone_proc_events.clear()
	owner.equipped_ruan_stone = "flame"
	owner.ruan_stone_levels = {"flame": 1}
	owner.stone_rings = 0
	enemies[0].max_health = 200.0
	enemies[0].current_health = 200.0
	enemies[0].remove_on_death = true
	DamageResolver.deal_damage_to_enemy(owner, enemies[0], 20.0, "mage_basic:event_pooled_flame")
	DamageResolver.deal_damage_to_enemy(owner, enemies[0], 180.0, "mage_basic:event_pooled_flame")
	assert(enemies[0].get_parent() == null)
	assert(is_equal_approx(enemies[1].damage_taken, 16.0))
	assert(is_equal_approx(enemies[2].damage_taken, 16.0))
	assert(is_equal_approx(enemies[3].damage_taken, 0.0))
	assert(owner.stone_rings == 1)
	enemies[0].free()
	enemies.remove_at(0)

	_reset(enemies)
	owner.ruan_stone_proc_events.clear()
	owner.equipped_ruan_stone = "thunder"
	owner.ruan_stone_levels = {"thunder": 1}
	DamageResolver.deal_damage_to_enemy(owner, enemies[0], 10.0, "mechanic_basic:event_mechanic_spider")
	assert(is_equal_approx(enemies[0].damage_taken, 10.0))
	assert(is_equal_approx(enemies[1].damage_taken, 3.0))

	_reset(enemies)
	owner.ruan_stone_proc_events.clear()
	DamageResolver.deal_damage_to_enemy(owner, enemies[0], 10.0, "mechanic")
	assert(is_equal_approx(enemies[0].damage_taken, 10.0))
	assert(is_equal_approx(enemies[1].damage_taken, 0.0))

	print("RUAN_STONE_COMBAT_SMOKE_OK")
	quit(0)


func _reset(enemies: Array[StoneEnemy]) -> void:
	for enemy in enemies:
		enemy.max_health = 1000.0
		enemy.current_health = 1000.0
		enemy.damage_taken = 0.0
		enemy.remove_on_death = false
		enemy.slow_multiplier = 1.0
		enemy.slow_duration = 0.0
		enemy.vulnerability_bonus = 0.0
		enemy.vulnerability_at_last_hit = 0.0
		var poison := enemy.get_node_or_null("RuanPoisonEffect")
		if poison != null:
			poison.free()


class CombatScene:
	extends Node
	var enemies: Array[StoneEnemy] = []

	func get_runtime_enemies() -> Array:
		return enemies


class StoneEnemy:
	extends Node2D
	var max_health := 1000.0
	var current_health := 1000.0
	var damage_taken := 0.0
	var remove_on_death := false
	var slow_multiplier := 1.0
	var slow_duration := 0.0
	var vulnerability_bonus := 0.0
	var vulnerability_at_last_hit := 0.0

	func take_damage(amount: float, _critical: bool = false) -> bool:
		vulnerability_at_last_hit = vulnerability_bonus
		damage_taken += amount
		current_health -= amount
		var killed := current_health <= 0.0
		if killed and remove_on_death and get_parent() != null:
			get_parent().remove_child(self)
		return killed

	func take_batched_damage(amount: float) -> bool:
		return take_damage(amount)

	func apply_slow(multiplier: float, duration: float) -> void:
		slow_multiplier = min(slow_multiplier, multiplier)
		slow_duration = max(slow_duration, duration)

	func apply_vulnerability(value: float, _duration: float) -> void:
		vulnerability_bonus = max(vulnerability_bonus, value)


class StoneOwner:
	extends Node2D
	var equipped_ruan_stone := ""
	var ruan_stone_levels: Dictionary = {}
	var ruan_stone_proc_events: Dictionary = {}
	var stone_rings := 0

	func _spawn_ring_effect(_center: Vector2, _radius: float, _color: Color, _width: float, _duration: float) -> void:
		stone_rings += 1
