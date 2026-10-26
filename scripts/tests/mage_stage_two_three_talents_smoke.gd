extends SceneTree

const TALENTS := preload("res://scripts/player/player_skill_talent_system.gd")
const ROLE := preload("res://scripts/player/roles/mage_role.gd")
const FIELD := preload("res://scripts/abilities/mage_meta_field_ability.gd")
const WAVE := preload("res://scripts/abilities/mage_tidal_surge_ability.gd")

func _init() -> void:
	var owner := TalentOwner.new()
	var role := ROLE.new()
	assert(is_equal_approx(role.get_arcane_transfer_duration(owner, 10, 10.0), 10.0))
	assert(role.get_arcane_surplus_expire_stacks(owner, 3) == 3)
	assert(role.get_arcane_relay_limit(owner) == 0)
	assert(is_equal_approx(role.get_arcane_relay_remaining(owner, 10.0), 10.0))
	role.record_arcane_dawn(owner, 8)
	assert(is_zero_approx(role.consume_arcane_dawn_duration_bonus(owner)), "retired trait nodes cannot arm dawn")
	var field := FIELD.new()
	field.active_remaining = 1.0
	field.expansion_tick_count = 3
	assert(is_equal_approx(field._get_radius(owner), 100.0), "retired expansion does not grow the field")
	assert(is_equal_approx(field._get_slow_multiplier(owner), 0.5), "retired stasis does not add slow")
	var ultimate := role._build_ultimate_talent_target_state(owner, Vector2.ZERO)
	assert(not role._cast_has_ultimate_talent(ultimate, "mage_ultimate_eclipse"), "new casts exclude retired ultimate nodes")
	var wave := WAVE.new()
	assert(wave._capture_talents(owner).is_empty(), "old stored wave nodes do not select current wave branches")
	owner.role_special_states["mage"]["skill_levels"] = {"mage_surging_wave": 9}
	owner.role_special_states["mage"]["mage_surging_wave_build"] = {"4": "flood", "8": "water_path", "9": "tidal"}
	var captured := wave._capture_talents(owner)
	assert(captured == ["mage_surge_flood", "mage_surge_wake", "mage_surge_tidal"], "only the chosen current branches populate the wave snapshot")
	wave.cast_talent_ids = captured
	wave.cast_talent_snapshot_valid = true
	owner.role_special_states["mage"]["mage_surging_wave_build"].clear()
	assert(wave._has_talent(owner, "mage_surge_wake"), "an in-flight wave keeps its selected branch snapshot")
	owner.free()
	print("MAGE_STAGE_TWO_THREE_TALENTS_SMOKE_OK")
	quit(0)

class TalentOwner:
	extends Node2D
	var blessing_skill_state := {"unlocked": {"meta_field": true, "surging_wave": true}}
	var role_special_states := {"mage": {"skill_talents": {
		"mage_trait": ["mage_trait_flow", "mage_trait_overflow", "mage_trait_relay_chain", "mage_trait_dawn"],
		"mage_meta_field": ["mage_meta_expansion", "mage_meta_stasis", "mage_meta_inner_ring"],
		"mage_surging_wave": ["mage_surge_wake", "mage_surge_tidal"],
		"mage_ultimate": ["mage_ultimate_eclipse"]
	}}}
	func _has_skill_talent(talent_id: String) -> bool:
		return TALENTS.has_talent(self, talent_id)
	func _get_role_special_state(role_id: String) -> Dictionary:
		return role_special_states.get(role_id, {})
	func _get_blessing_skill_tier(_skill_id: String) -> int:
		return 1
	func _get_equipment_skill_range_multiplier() -> float:
		return 1.0
	func _get_invoker_magic_range_multiplier(_skill_id: String) -> float:
		return 1.0
