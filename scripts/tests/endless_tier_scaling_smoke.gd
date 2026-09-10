extends SceneTree

const DIFFICULTY_PROFILE := preload("res://scripts/game/difficulty_profile.gd")
const ENEMY_DIRECTOR := preload("res://scripts/enemy/enemy_director.gd")
const DEVELOPER_ACTIONS := preload("res://scripts/developer/developer_actions.gd")
const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var n1 := DIFFICULTY_PROFILE.get_endless_tier_profile(1)
	var n2 := DIFFICULTY_PROFILE.get_endless_tier_profile(2)
	var n11 := DIFFICULTY_PROFILE.get_endless_tier_profile(11)
	var n21 := DIFFICULTY_PROFILE.get_endless_tier_profile(21)
	_expect_close(float(n1.get("enemy_health_scale")), 1.0, "N1 health")
	_expect_close(float(n1.get("boss_health_scale")), 1.0, "N1 boss health")
	_expect_close(float(n1.get("enemy_speed_scale")), 1.0, "N1 speed")
	_expect_close(float(n1.get("projectile_speed_bonus")), 0.0, "N1 projectile speed")
	_expect_close(float(n2.get("enemy_health_scale")), 1.1, "N2 health")
	_expect_close(float(n2.get("boss_health_scale")), 1.2, "N2 boss health")
	_expect_close(float(n2.get("enemy_speed_scale")), 1.08, "N2 speed")
	_expect_close(float(n2.get("projectile_speed_bonus")), 20.0, "N2 projectile speed")
	_expect_close(float(n1.get("enemy_damage_scale")), 0.80, "N1 damage")
	_expect_close(float(n11.get("enemy_health_scale")), 2.0, "N11 health")
	_expect_close(float(n11.get("boss_health_scale")), 3.0, "N11 boss health")
	_expect_close(float(n11.get("enemy_speed_scale")), 1.8, "N11 speed")
	_expect_close(float(n11.get("projectile_speed_bonus")), 200.0, "N11 projectile speed")
	_expect_close(float(n11.get("enemy_damage_scale")), 1.48, "N11 damage")
	_expect_close(float(n21.get("enemy_health_scale")), 3.0, "N21 health")
	_expect_close(float(n21.get("boss_health_scale")), 5.0, "N21 boss health")
	_expect_close(float(n21.get("enemy_speed_scale")), 2.6, "N21 speed")
	_expect_close(float(n21.get("projectile_speed_bonus")), 400.0, "N21 projectile speed")
	_expect_close(float(n21.get("enemy_damage_scale")), 2.16, "N21 damage")
	_expect_close(float(DIFFICULTY_PROFILE.get_health_scale_for_kind("small_boss", n21)), 5.0, "N21 small boss health")
	_expect_close(float(n21.get("density_pack_scale")), float(n11.get("density_pack_scale")), "density cap")
	_expect(int(n21.get("enemy_projectile_limit")) == int(n11.get("enemy_projectile_limit")), "projectile cap")
	_expect(ENEMY_DIRECTOR.get_effective_boss_spawn_time({}, false, true) == 720.0, "Each N tier must end at 12 minutes.")
	var developer_main := DeveloperMainStub.new()
	DEVELOPER_MODE.activate()
	DEVELOPER_ACTIONS.set_endless_tier(developer_main, 21)
	_expect(developer_main.endless_tier == 21, "Developer tier selection was not applied.")
	_expect_close(float(developer_main.difficulty_profile.get("enemy_health_scale")), 3.0, "Developer N21 health")
	_expect(DEVELOPER_MODE.should_disable_save(), "Developer tier test must keep official saves disabled.")
	DEVELOPER_MODE.deactivate()
	developer_main.free()

	if failures.is_empty():
		print("ENDLESS_TIER_SCALING_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _expect_close(actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s expected %.3f got %.3f" % [label, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


class DeveloperMainStub:
	extends Node

	var endless_tier := 1
	var difficulty_profile: Dictionary = {}
	var difficulty_id := ""

	func _refresh_hud() -> void:
		pass
