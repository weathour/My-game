extends SceneTree

const MageRole := preload("res://scripts/player/roles/mage_role.gd")
const MageSurge := preload("res://scripts/abilities/mage_tidal_surge_ability.gd")


func _init() -> void:
	var role := MageRole.new()
	var triangle: Array = role._build_triangle_attack_contexts([
		[Vector2.ZERO], [100.0], [100.0], ["mage"]
	])
	assert((triangle[0] as Array).size() == 3)
	assert(is_equal_approx(float((triangle[1] as Array)[0]), 70.0))
	assert(is_equal_approx(float((triangle[2] as Array)[0]), 40.0))

	var owner := TalentOwner.new()
	var surge := MageSurge.new()
	var directions: Array[Vector2] = surge._get_wave_directions(owner, 1.0, true)
	assert(directions.size() == 3, "quantity two produces three evenly spaced waves")
	assert(directions[0].is_equal_approx(Vector2.RIGHT))
	assert(surge._get_wave_directions(owner, 0.5, false) == [Vector2.UP], "secondary combo waves do not repeat the quantity fan")
	owner.role_special_states["mage"] = {"skill_levels": {"mage_surging_wave": 9}, "mage_surging_wave_build": {"4": "flood", "8": "clear_spring", "9": "tidal"}}
	var tidal: Array[Vector2] = surge._get_wave_directions(owner, 1.0, true)
	assert(tidal.size() == 3 and tidal[1].is_equal_approx(Vector2.UP))
	assert(is_equal_approx(absf(tidal[0].angle_to(tidal[1])), deg_to_rad(40.0)), "current tidal branch uses three forty-degree directions")
	owner.free()
	print("MAGE_TALENT_SMOKE_OK")
	quit(0)


class TalentOwner:
	extends Node

	var facing_direction := Vector2.UP
	var role_special_states := {"mage": {"skill_talents": {"mage_surging_wave": ["mage_surge_four"]}}}

	func _has_skill_talent(talent_id: String) -> bool:
		return preload("res://scripts/player/player_skill_talent_system.gd").has_talent(self, talent_id)

	func _get_blessing_skill_quantity_count(_skill_id: String) -> int:
		return 2
