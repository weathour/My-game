extends SceneTree

const BULLET := preload("res://scenes/enemy_bullet.tscn")
const CONTEXT := preload("res://scripts/enemies/enemy_projectile_frame_context.gd")
const RUNTIME := preload("res://scripts/tests/boss_danmaku_test_runtime.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := RUNTIME.new()
	root.add_child(scene)
	current_scene = scene
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var reference := MovingTarget.new()
	var actual := MovingTarget.new()
	scene.add_child(reference)
	scene.add_child(actual)
	var old_bullets: Array = []
	var new_bullets: Array = []
	for index in range(100):
		# The first hit moves and enlarges the hurtbox. Later hits must
		# observe that change, rather than reuse stale frame geometry.
		var config := {
			"position": Vector2(index * 9.0, 0.0), "speed": 0.0,
			"damage": index + 1.0, "lifetime": 10.0, "hit_radius": 3.0,
			"motion_mode": "straight"
		}
		for pair in [[reference, old_bullets], [actual, new_bullets]]:
			var bullet = BULLET.instantiate()
			scene.add_child(bullet)
			config.target = pair[0]
			bullet.reset_projectile(config)
			pair[1].append(bullet)
	for frame in range(3):
		var context := CONTEXT.new()
		for index in range(100):
			old_bullets[index].batch_physics_process(1.0 / 60.0)
			new_bullets[index].batch_physics_process(1.0 / 60.0, context)
			assert(old_bullets[index].pooled == new_bullets[index].pooled, "cached collision must preserve which bullets hit")
			assert(old_bullets[index].global_position == new_bullets[index].global_position, "caching cannot change movement")
		assert(reference.hits == actual.hits and reference.global_position == actual.global_position, "damage and target movement preserve original hit order")
	assert(actual.geometry_queries < reference.geometry_queries / 4, "unhit projectiles must share target geometry")
	var context := CONTEXT.new()
	assert(context.prepare(actual))
	assert(context.prepare(reference) and context.cached_target == reference, "different projectile targets cannot share cached geometry")
	var old_center := context.center
	reference.position += Vector2(13, 0)
	await physics_frame
	assert(context.prepare(reference) and context.center != old_center, "a context reused in another physics frame must refresh target geometry")
	var disappearing := MovingTarget.new()
	scene.add_child(disappearing)
	assert(context.prepare(disappearing))
	disappearing.free()
	# A target destroyed by damage invalidates the cache before the next shot.
	context.invalidate()
	assert(not context.prepare(null))
	scene.free()
	current_scene = null
	_check_merchant_and_scene_cache()
	print("ENEMY_PROJECTILE_FRAME_CONTEXT_SMOKE_OK")
	quit(0)


func _check_merchant_and_scene_cache() -> void:
	var scene := WaveRuntime.new()
	var other := WaveRuntime.new()
	root.add_child(scene)
	root.add_child(other)
	current_scene = scene
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	other.process_mode = Node.PROCESS_MODE_DISABLED
	scene.wave_flow = WaveStub.new()
	other.wave_flow = WaveStub.new()
	scene.add_child(scene.wave_flow)
	other.add_child(other.wave_flow)
	var context := CONTEXT.new()
	var target := MovingTarget.new()
	target.position = Vector2(200, 0)
	scene.add_child(target)
	var merchant := MerchantStub.new()
	merchant.wave = scene.wave_flow
	merchant.target = target
	scene.add_child(merchant)
	scene.wave_flow.merchant = merchant
	for index in range(2):
		var bullet = BULLET.instantiate()
		scene.add_child(bullet)
		bullet.reset_projectile({"position":Vector2.ZERO,"speed":0.0,"damage":5.0,"lifetime":10.0,"hit_radius":3.0,"target":target})
		bullet.batch_physics_process(1.0 / 60.0, context)
		assert(bullet.pooled)
	assert(merchant.hits == 1 and target.hits.size() == 1, "merchant death is observed and its callback invalidates target geometry before the next shot")
	scene.free()
	current_scene = other
	var other_target := MovingTarget.new()
	other_target.position = Vector2(200, 0)
	other.add_child(other_target)
	var other_merchant := MerchantStub.new()
	other_merchant.wave = other.wave_flow
	other_merchant.target = other_target
	other.add_child(other_merchant)
	other.wave_flow.merchant = other_merchant
	var shot = BULLET.instantiate()
	other.add_child(shot)
	shot.reset_projectile({"position":Vector2.ZERO,"speed":0.0,"damage":5.0,"lifetime":10.0,"hit_radius":3.0,"target":other_target})
	shot.batch_physics_process(1.0 / 60.0, context)
	assert(shot.pooled and other_merchant.hits == 1, "switching scene must read its live merchant after the previous scene was freed")
	var reflected = BULLET.instantiate()
	other.add_child(reflected)
	reflected.reset_projectile({"position":Vector2(100, 0),"speed":0.0,"lifetime":0.01,"target":other_target})
	reflected.reflected = true
	assert(context.prepare(other_target))
	reflected.batch_physics_process(0.02, context)
	assert(not context.cached, "the reflected gameplay branch cannot leave a target snapshot cached for following bullets")
	other.free()
	current_scene = null


class WaveRuntime extends RUNTIME:
	var wave_flow: Node

class WaveStub extends Node:
	var phase := "preparation"
	var merchant_health := 5.0
	var merchant: Node2D

class MerchantStub extends Node2D:
	var hits := 0
	var wave: Node
	var target: Node2D
	func take_damage(amount: float) -> void:
		hits += 1
		wave.merchant_health = maxf(0, wave.merchant_health - amount)
		target.position = Vector2.ZERO


class MovingTarget:
	extends Node2D
	var hits: Array[float] = []
	var geometry_queries := 0
	var radius := 3.0
	var center_offset := Vector2.ZERO

	func get_hurtbox_center() -> Vector2:
		geometry_queries += 1
		return global_position + center_offset

	func get_hurtbox_radius() -> float:
		return radius

	func take_damage(amount: float) -> void:
		hits.append(amount)
		if hits.size() == 1:
			position += Vector2(35, 0)
			center_offset = Vector2(7, 0)
			radius = 10.0
