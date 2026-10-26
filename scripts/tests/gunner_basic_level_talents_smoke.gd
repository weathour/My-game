extends SceneTree

const GunnerRole := preload("res://scripts/player/roles/gunner_role.gd")
const GunnerBasicTalentFlow := preload("res://scripts/player/player_gunner_basic_talent_flow.gd")
const PlayerProjectileBatch := preload("res://scripts/player/player_projectile_batch.gd")
const DamageResolver := preload("res://scripts/player/player_damage_resolver.gd")
const ENEMY := preload("res://scenes/enemy.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_gunner_role_projectile_config()
	_check_batched_split_projectiles()
	_check_basic_hit_armor_shred()
	if failures.is_empty():
		print("GUNNER_BASIC_LEVEL_TALENTS_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_gunner_role_projectile_config() -> void:
	var owner := BasicOwner.new()
	root.add_child(owner)
	owner.level_talents = {
		"gunner_level_talent_basic_attack_1": true,
		"gunner_level_talent_basic_attack_2": true
	}
	var role := GunnerRole.new()
	role._spawn_primary_batched_bullet(owner, Vector2.RIGHT, 100.0, Color.WHITE, {"id": "gunner"}, {"range_bonus": 0.0}, 0, Vector2.ZERO, {"damage_event_id": "event"})
	_expect_float(float(owner.last_projectile.get("damage", 0.0)), 96.0, "basic I + basic II parent damage should be 100 * 1.2 * 0.8")
	_expect_float(float(owner.last_projectile.get("speed", 0.0)), 910.0, "basic I should add 150 projectile speed")
	_expect_equal(str(owner.last_projectile.get("role_id", "")), "gunner_basic:event", "gunner basic projectile should keep basic source id")
	_expect_equal(int(owner.last_projectile.get("gunner_basic_split_count", 0)), 3, "basic II should configure 3 split bullets")
	_expect_float(float(owner.last_projectile.get("gunner_basic_split_arc_degrees", 0.0)), 60.0, "basic II split arc should be 60 degrees")
	_expect_float(float(owner.last_projectile.get("gunner_basic_split_damage", 0.0)), 60.0, "basic II split damage should be 100 * 1.2 * 0.5")
	_expect_float(float(owner.last_projectile.get("gunner_basic_split_distance_bonus", 0.0)), 100.0, "basic II should add 100 split flight distance")
	owner.queue_free()


func _check_batched_split_projectiles() -> void:
	var owner := BasicOwner.new()
	root.add_child(owner)
	var enemy = ENEMY.instantiate()
	enemy.global_position = Vector2(100.0, 0.0)
	root.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.armor = 0.0
	enemy.damage_reduction_rate = 0.0
	var batch := PlayerProjectileBatch.new()
	root.add_child(batch)
	batch.configure(owner)
	batch.add_projectile({
		"position": enemy.global_position,
		"source_origin": Vector2.ZERO,
		"direction": Vector2.RIGHT,
		"damage": 0.0,
		"color": Color.WHITE,
		"role_id": "gunner_basic:event",
		"speed": 910.0,
		"lifetime": 1.0,
		"hit_radius": 10.0,
		"visual_radius": 4.0,
		"gunner_basic_split_enabled": true,
		"gunner_basic_split_count": 3,
		"gunner_basic_split_arc_degrees": 60.0,
		"gunner_basic_split_damage": 60.0,
		"gunner_basic_split_lifetime_scale": 0.72,
		"gunner_basic_split_speed_scale": 0.92,
		"gunner_basic_split_distance_bonus": 100.0,
		"gunner_basic_split_visual_scale": 0.88
	})
	batch._apply_projectile_hit(0, enemy)
	_expect_equal(batch.positions.size(), 4, "parent hit should append 3 split bullets before parent removal")
	for index in range(1, 4):
		_expect_float(batch.damages[index], 60.0, "split bullet damage should use configured 50 percent damage")
		_expect(bool(batch._has_projectile_hit_enemy(index, enemy)), "split bullets should ignore first hit enemy")
		_expect(not bool(batch.gunner_basic_split_flags[index]), "split bullets should not split again")
	_expect(batch.directions[1].is_equal_approx(Vector2.RIGHT.rotated(deg_to_rad(-30.0))), "first split should travel forward-left")
	_expect(batch.directions[2].is_equal_approx(Vector2.RIGHT), "middle split should travel forward")
	_expect(batch.directions[3].is_equal_approx(Vector2.RIGHT.rotated(deg_to_rad(30.0))), "last split should travel forward-right")
	batch.queue_free()
	enemy.queue_free()
	owner.queue_free()


func _check_basic_hit_armor_shred() -> void:
	var owner := BasicOwner.new()
	root.add_child(owner)
	owner.level_talents = {"gunner_level_talent_basic_attack_1": true}
	var enemy = ENEMY.instantiate()
	enemy.current_health = 100.0
	enemy.max_health = 100.0
	root.add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.armor = 0.0
	enemy.damage_reduction_rate = 0.0
	_expect_float(enemy.damage_reduction_value, 0.0, "enemies should default to zero damage reduction value")
	DamageResolver.deal_damage_to_enemy(owner, enemy, 10.0, "gunner_basic:event")
	_expect_float(enemy.current_health, 90.0, "first basic hit should not benefit from its own armor shred")
	_expect_float(enemy.damage_reduction_value, -2.0, "first basic hit should reduce the enemy damage reduction value by 2")
	var expected_second_damage := 10.0 * GunnerBasicTalentFlow.get_enemy_damage_taken_multiplier(enemy)
	DamageResolver.deal_damage_to_enemy(owner, enemy, 10.0, "gunner_basic:event")
	_expect_float(enemy.current_health, 90.0 - expected_second_damage, "second basic hit should benefit from previous armor shred")
	_expect_float(enemy.damage_reduction_value, -4.0, "second basic hit should stack enemy damage reduction value")
	enemy.queue_free()
	owner.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _expect_equal(actual, expected, message: String) -> void:
	if actual != expected:
		failures.append("%s: %s != %s" % [message, str(actual), str(expected)])


func _expect_float(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s: %.4f != %.4f" % [message, actual, expected])


class BasicOwner:
	extends Node2D

	var level_talents: Dictionary = {}
	var last_projectile: Dictionary = {}
	var gunner_role = null

	func _has_level_talent(talent_id: String) -> bool:
		return bool(level_talents.get(talent_id, false))

	func _spawn_batched_directional_bullet(direction: Vector2, damage_amount: float, _color: Color, role_id: String = "", origin: Variant = null, config: Dictionary = {}) -> bool:
		last_projectile = config.duplicate(true)
		last_projectile["direction"] = direction
		last_projectile["damage"] = damage_amount
		last_projectile["role_id"] = role_id
		last_projectile["origin"] = origin
		return true
