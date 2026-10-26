extends SceneTree

const BUILD := preload("res://scripts/player/player_mage_surging_wave_build.gd")
const ABILITY := preload("res://scripts/abilities/mage_tidal_surge_ability.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var owner := TestOwner.new()
	_expect(BUILD.level(owner) == 0, "wave starts at LV0")
	owner.role_special_states["mage"]["skill_levels"] = {"mage_surging_wave": 4}
	_expect(BUILD.level(owner) == 4, "wave level reads LV4")
	_expect(BUILD.pending_stage(owner) == 4, "LV4 branch is pending")
	_expect(BUILD.choose(owner, 4, 1), "LV4 branch can be selected")
	owner.role_special_states["mage"]["skill_levels"]["mage_surging_wave"] = 8
	_expect(BUILD.pending_stage(owner) == 8, "LV8 branch is pending")
	_expect(BUILD.choose(owner, 8, 2), "LV8 branch can be selected")
	owner.role_special_states["mage"]["skill_levels"]["mage_surging_wave"] = 9
	_expect(BUILD.choose(owner, 9, 1), "LV9 branch can be selected")
	_expect(is_equal_approx(ABILITY.new()._get_damage_multiplier(owner), 5.9), "LV9 tidal damage is 590 percent")
	owner.free()
	if failures.is_empty():
		print("MAGE_SURGING_WAVE_LEVEL_TALENTS_SMOKE_OK")
	else:
		for message in failures:
			push_error(message)
		quit(1)
		return
	quit(0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

class TestOwner:
	extends Node
	var role_special_states: Dictionary = {"mage": {"skill_levels": {}, "mage_surging_wave_build": {}}}
	var blessing_skill_state: Dictionary = {"unlocked": {"surging_wave": true}}
