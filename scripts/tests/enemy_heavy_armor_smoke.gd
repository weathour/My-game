extends SceneTree

const FORM := preload("res://scripts/enemies/enemy_heavy_armor_form.gd")
const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const ENEMY := preload("res://scenes/enemy.tscn")
const DAMAGE := preload("res://scripts/enemies/enemy_damage.gd")
const MOVEMENT := preload("res://scripts/enemies/enemy_movement.gd")
const POOL := preload("res://scripts/enemies/enemy_pool_lifecycle.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := RuntimeRoot.new()
	root.add_child(scene)
	current_scene = scene
	var target := Target.new()
	scene.add_child(target)
	var enemy = ENEMY.instantiate()
	enemy.target = target
	scene.add_child(enemy)
	enemy.apply_enemy_profile("normal", DATABASE.get_profile("normal", "brute"))
	enemy.current_health = enemy.max_health
	enemy._cached_direction_to_target = Vector2.RIGHT
	assert(is_equal_approx(enemy.attack, 15.0))
	assert(is_equal_approx(enemy.max_health, 60.0))
	assert(is_equal_approx(enemy.armor, 20.0))
	assert(is_equal_approx(MOVEMENT.compute_velocity(enemy, 0.0).length(), 42.0))
	assert(not FORM.is_active(enemy))
	FORM.tick(enemy, 19.0)
	assert(not FORM.is_active(enemy))
	FORM.tick(enemy, 1.0)
	assert(FORM.is_active(enemy))
	assert(is_equal_approx(enemy.heavy_armor_cooldown, 20.0))
	assert(is_equal_approx(MOVEMENT.compute_velocity(enemy, 0.0).length(), 21.0))
	assert(enemy.get_node("ProfileVisual").sprite.material != null)
	DAMAGE.apply_damage(enemy, 42.0, false)
	assert(is_equal_approx(enemy.current_health, 30.0))
	assert(is_equal_approx(target.received, 1.5))
	# Armor loss during the form must survive expiry and save/restore.
	enemy.armor -= 5.0
	FORM.tick(enemy, 1.0)
	var saved: Dictionary = enemy.get_save_data()
	var restored = ENEMY.instantiate()
	scene.add_child(restored)
	restored.apply_save_data(saved, target)
	assert(is_equal_approx(restored.heavy_armor_remaining, 2.0))
	assert(is_equal_approx(restored.heavy_armor_cooldown, 19.0))
	assert(is_equal_approx(restored.armor, 15.0))
	assert(restored.get_node("ProfileVisual").sprite.material != null)
	FORM.tick(restored, 2.0)
	assert(not FORM.is_active(restored))
	assert(is_equal_approx(restored.armor, 15.0))
	assert(restored.get_node("ProfileVisual").sprite.material == null)
	DAMAGE.apply_damage(restored, 11.5, false)
	assert(is_equal_approx(restored.current_health, 20.0))
	assert(is_equal_approx(target.received, 1.5))
	FORM.tick(restored, 17.0)
	assert(FORM.is_active(restored))
	restored.skull_damage_immune_timer = 1.0
	DAMAGE.apply_damage(restored, 100.0, false)
	assert(is_equal_approx(target.received, 1.5))
	POOL.prepare_for_pool(restored)
	assert(not FORM.is_active(restored))
	assert(restored.get_node("ProfileVisual").sprite.material == null)
	restored.apply_enemy_profile("normal", DATABASE.get_profile("normal", "chaser"))
	assert(not FORM.is_active(restored))

	for tier in [1, 2]:
		scene.difficulty_profile = {"tier": tier}
		restored.apply_enemy_profile("normal", DATABASE.get_profile("normal", "brute"))
		assert(is_equal_approx(restored.heavy_armor_cooldown, 20.0))
		assert(is_equal_approx(FORM.get_duration(restored), 3.0))
		assert(is_equal_approx(FORM.get_armor_bonus(restored), 20.0))
		assert(is_equal_approx(FORM.get_reflect_ratio(restored), 0.05))
	for tier in [3, 8]:
		scene.difficulty_profile = {"tier": tier}
		_check_enhanced_form(scene, target)
	scene.free()
	current_scene = null
	print("ENEMY_HEAVY_ARMOR_SMOKE_OK")
	quit(0)


func _check_enhanced_form(scene: Node, target: Node2D) -> void:
	var n3_enemy = ENEMY.instantiate()
	n3_enemy.target = target
	# 正常生成流程先设置模板，再加入场景；首次冷却也应是18秒。
	n3_enemy.apply_enemy_profile("normal", DATABASE.get_profile("normal", "brute"))
	assert(is_equal_approx(n3_enemy.heavy_armor_cooldown, 18.0))
	scene.add_child(n3_enemy)
	n3_enemy.set_physics_process(false)
	n3_enemy._cached_direction_to_target = Vector2.RIGHT
	assert(is_equal_approx(FORM.get_duration(n3_enemy), 5.0))
	assert(is_equal_approx(FORM.get_cooldown(n3_enemy), 18.0))
	assert(is_equal_approx(FORM.get_armor_bonus(n3_enemy), 100.0))
	assert(is_equal_approx(FORM.get_reflect_ratio(n3_enemy), 0.15))
	n3_enemy.batch_physics_process(17.5)
	assert(not FORM.is_active(n3_enemy))
	n3_enemy._physics_process(0.5)
	assert(FORM.is_active(n3_enemy))
	assert(is_equal_approx(n3_enemy.heavy_armor_remaining, 5.0))
	assert(is_equal_approx(n3_enemy.heavy_armor_cooldown, 18.0))
	assert(is_equal_approx(n3_enemy.armor, 20.0))
	assert(is_equal_approx(MOVEMENT.compute_velocity(n3_enemy, 0.0).length(), 21.0))
	assert(is_equal_approx(n3_enemy.try_stalwart_body_damage(), 22.5))
	assert(n3_enemy.get_node("ProfileVisual").sprite.material != null)
	n3_enemy.current_health = n3_enemy.max_health
	var n3_received_before: float = target.received
	DAMAGE.apply_damage(n3_enemy, 44.0, false)
	var n3_health_loss: float = 20.0
	assert(is_equal_approx(n3_enemy.current_health, 40.0))
	assert(is_equal_approx(target.received - n3_received_before, n3_health_loss * 0.15))
	n3_enemy.skull_damage_immune_timer = 1.0
	DAMAGE.apply_damage(n3_enemy, 44.0, false)
	assert(is_equal_approx(n3_enemy.current_health, 40.0))
	assert(is_equal_approx(target.received - n3_received_before, 3.0))
	n3_enemy.skull_damage_immune_timer = 0.0
	n3_enemy.armor -= 5.0
	FORM.tick(n3_enemy, 0.5)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(n3_enemy.get_save_data()))
	var restored = ENEMY.instantiate()
	scene.add_child(restored)
	restored.set_physics_process(false)
	restored.apply_save_data(saved, target)
	assert(is_equal_approx(restored.heavy_armor_remaining, 4.5))
	assert(is_equal_approx(restored.heavy_armor_cooldown, 17.5))
	assert(is_equal_approx(restored.armor, 15.0))
	assert(restored.get_node("ProfileVisual").sprite.material != null)
	DAMAGE.apply_damage(restored, 21.5, false)
	assert(is_equal_approx(restored.current_health, 30.0))
	assert(is_equal_approx(target.received - n3_received_before, 4.5))
	FORM.tick(restored, 4.5)
	assert(not FORM.is_active(restored))
	assert(restored.get_node("ProfileVisual").sprite.material == null)
	assert(is_equal_approx(restored.armor, 15.0))
	DAMAGE.apply_damage(restored, 11.5, false)
	assert(is_equal_approx(restored.current_health, 20.0))
	assert(is_equal_approx(target.received - n3_received_before, 4.5))
	FORM.tick(restored, 12.5)
	assert(not FORM.is_active(restored))
	FORM.tick(restored, 0.5)
	assert(is_equal_approx(restored.heavy_armor_remaining, 5.0))
	assert(is_equal_approx(restored.heavy_armor_cooldown, 18.0))
	POOL.prepare_for_pool(n3_enemy)
	assert(not FORM.is_active(n3_enemy))
	assert(n3_enemy.get_node("ProfileVisual").sprite.material == null)
	n3_enemy.apply_enemy_profile("normal", DATABASE.get_profile("normal", "chaser"))
	assert(not FORM.is_active(n3_enemy))
	n3_enemy.apply_enemy_profile("normal", DATABASE.get_profile("normal", "brute"))
	assert(is_equal_approx(n3_enemy.heavy_armor_cooldown, 18.0))
	saved.erase("heavy_armor_remaining")
	saved.erase("heavy_armor_cooldown")
	restored.apply_save_data(saved, target)
	assert(is_zero_approx(restored.heavy_armor_remaining))
	assert(is_equal_approx(restored.heavy_armor_cooldown, 18.0))
	n3_enemy.free()
	restored.free()


class RuntimeRoot:
	extends Node2D
	var difficulty_profile: Dictionary = {}


class Target:
	extends Node2D
	var received: float = 0.0

	func take_damage(amount: float) -> void:
		received += amount
