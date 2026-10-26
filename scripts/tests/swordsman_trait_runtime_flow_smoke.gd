extends SceneTree

const BladeStorm := preload("res://scripts/abilities/swordsman_blade_storm_ability.gd")
const CrescentWave := preload("res://scripts/abilities/swordsman_crescent_wave_ability.gd")
const RuntimeFlow := preload("res://scripts/player/player_swordsman_trait_runtime_flow.gd")
const SwordsmanRole := preload("res://scripts/player/roles/swordsman_role.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_knight_glory_runtime()
	_check_bloodthirst_runtime()
	_check_charge_runtime()
	_check_blade_storm_level_talents()
	_check_basic_attack_level_talents()
	_check_crescent_wave_level_talents()

	if failures.is_empty():
		print("SWORDSMAN_TRAIT_RUNTIME_FLOW_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_knight_glory_runtime() -> void:
	var owner := OwnerStub.new()
	root.add_child(owner)
	owner.level_talents = {
		"swordsman_level_talent_knight_glory_1": true,
		"swordsman_level_talent_knight_glory_2": true
	}
	owner.role_health_values["swordsman"] = 30.0
	owner.current_health = 30.0
	owner.swordsman_death_defiance_will_remaining = 0.10
	owner.healing_block_remaining = 4.0
	owner.aging_remaining = 4.0
	owner.aging_damage_carry = 2.0
	owner.confinement_remaining = 4.0
	owner.confinement_radius = 120.0
	owner.confinement_polygon = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
	owner.enemy_move_slow_remaining = 4.0
	owner.enemy_move_slow_multiplier = 0.5

	RuntimeFlow.tick(owner, 0.20)

	var state: Dictionary = owner.role_special_states["swordsman"] as Dictionary
	_expect(is_equal_approx(float(owner.role_health_values["swordsman"]), 55.0), "knight glory I should heal swordsman by 25 percent max health")
	_expect(is_equal_approx(float(state.get("level_knight_glory_damage_reduction_remaining", 0.0)), 3.0), "knight glory I damage reduction should start at full 3s after finish")
	_expect(is_equal_approx(float(state.get("level_knight_glory_surge_remaining", 0.0)), 2.0), "knight glory II surge should start at full 2s after finish")
	_expect(is_equal_approx(RuntimeFlow.get_damage_reduction_value(owner, "swordsman"), 100.0), "knight glory I should expose 100 damage reduction value")
	_expect(is_equal_approx(RuntimeFlow.get_flat_dodge_chance_bonus(owner, "swordsman"), 0.50), "knight glory II should expose 50 percent dodge chance")
	_expect(is_equal_approx(RuntimeFlow.get_damage_multiplier(owner, "swordsman"), 1.20), "knight glory II should expose 20 percent damage multiplier")
	_expect(is_equal_approx(RuntimeFlow.get_battle_will_proc_chance_bonus(owner), 0.10), "knight glory II should expose 10 percent battle will chance bonus")
	_expect(owner.healing_block_remaining == 0.0 and owner.aging_remaining == 0.0 and owner.aging_damage_carry == 0.0, "knight glory I should cleanse healing block and aging")
	_expect(owner.confinement_remaining == 0.0 and owner.confinement_radius == 0.0 and owner.confinement_polygon.is_empty(), "knight glory I should cleanse confinement")
	_expect(owner.enemy_move_slow_remaining == 0.0 and is_equal_approx(owner.enemy_move_slow_multiplier, 1.0), "knight glory I should cleanse enemy slow state")
	_expect(owner.cleared_statuses.has("healing_block") and owner.cleared_statuses.has("aging") and owner.cleared_statuses.has("confinement"), "knight glory I should clear duration status ids")

	RuntimeFlow.tick(owner, 2.10)
	_expect(is_equal_approx(RuntimeFlow.get_damage_multiplier(owner, "swordsman"), 1.0), "knight glory II surge should expire after 2s")
	_expect(is_equal_approx(RuntimeFlow.get_flat_dodge_chance_bonus(owner, "swordsman"), 0.0), "knight glory II dodge bonus should expire after 2s")
	RuntimeFlow.tick(owner, 1.10)
	_expect(is_equal_approx(RuntimeFlow.get_damage_reduction_value(owner, "swordsman"), 0.0), "knight glory I damage reduction should expire after 3s")
	owner.queue_free()


func _check_bloodthirst_runtime() -> void:
	var owner := OwnerStub.new()
	root.add_child(owner)
	owner.level_talents = {
		"swordsman_level_talent_bloodthirst_1": true,
		"swordsman_level_talent_bloodthirst_2": true
	}
	owner.swordsman_entry_trait_share_remaining = 1.0
	owner.swordsman_bloodthirst_heal_multiplier = 1.5

	_expect(is_equal_approx(RuntimeFlow.get_damage_multiplier(owner, "swordsman"), 1.10), "bloodthirst I should expose 10 percent damage multiplier while active")
	_expect(is_equal_approx(RuntimeFlow.get_healing_multiplier(owner), 1.50), "bloodthirst II should expose 1.5x healing multiplier while active")
	_expect(is_equal_approx(RuntimeFlow.apply_healing_multiplier(owner, 10.0), 15.0), "bloodthirst II should multiply regular healing once")
	_expect(is_equal_approx(RuntimeFlow.get_swordsman_trait_heal_multiplier(owner), 1.0), "swordsman trait heal should not multiply bloodthirst twice when all-heal multiplier is active")

	RuntimeFlow.tick(owner, 1.10)
	_expect(is_equal_approx(owner.swordsman_entry_trait_share_remaining, 0.0), "bloodthirst state should expire")
	_expect(is_equal_approx(owner.swordsman_bloodthirst_heal_multiplier, 1.0), "bloodthirst heal multiplier should reset on expiry")
	_expect(is_equal_approx(owner.swordsman_bloodthirst_cooldown_remaining, owner.SWORDSMAN_BLOODTHIRST_INTERNAL_COOLDOWN), "bloodthirst expiry should start internal cooldown")
	_expect(is_equal_approx(RuntimeFlow.get_damage_multiplier(owner, "swordsman"), 1.0), "bloodthirst damage bonus should expire")
	owner.swordsman_entry_trait_share_remaining = 4.5
	owner.swordsman_bloodthirst_heal_multiplier = 1.5
	owner.role_special_states["gunner"] = {
		"swordsman_entry_bloodthirst_remaining": 4.5,
		"swordsman_entry_bloodthirst_heal_multiplier": 1.5
	}
	RuntimeFlow.clear_bloodthirst_on_role_switch(owner)
	_expect(is_zero_approx(owner.swordsman_entry_trait_share_remaining), "switching away should clear swordsman bloodthirst remaining time")
	_expect(is_equal_approx(owner.swordsman_bloodthirst_heal_multiplier, 1.0), "switching away should clear swordsman bloodthirst multiplier")
	_expect(not (owner.role_special_states["gunner"] as Dictionary).has("swordsman_entry_bloodthirst_remaining"), "switching away should clear inherited bloodthirst remaining time")
	owner.active_role_id = "gunner"
	_expect(not RuntimeFlow.is_bloodthirst_active(owner), "non-swordsman should not benefit from swordsman bloodthirst")
	owner.active_role_id = "swordsman"
	_expect(not RuntimeFlow.is_bloodthirst_active(owner), "returning to swordsman should not restore cleared bloodthirst")
	owner.queue_free()


func _check_charge_runtime() -> void:
	var owner := OwnerStub.new()
	root.add_child(owner)
	owner.level_talents = {
		"swordsman_level_talent_charge_1": true,
		"swordsman_level_talent_charge_2": true
	}
	owner.role_health_values = {
		"swordsman": 60.0,
		"gunner": 20.0,
		"mage": 40.0
	}
	owner.role_max_health_values = {
		"swordsman": 100.0,
		"gunner": 80.0,
		"mage": 60.0
	}
	owner.current_health = 60.0

	RuntimeFlow.activate_charge_talents(owner)

	var state: Dictionary = owner.role_special_states["swordsman"] as Dictionary
	_expect(is_equal_approx(float(state.get("level_charge_damage_reduction_remaining", 0.0)), 3.0), "charge I should grant 3s damage reduction state")
	_expect(is_equal_approx(RuntimeFlow.get_damage_reduction_value(owner, "swordsman"), 150.0), "charge I should expose 150 damage reduction value")
	_expect(is_equal_approx(float(owner.role_health_values["swordsman"]), 68.0), "charge II should heal swordsman by 20 percent missing health")
	_expect(is_equal_approx(float(owner.role_health_values["gunner"]), 32.0), "charge II should heal gunner by 20 percent missing health")
	_expect(is_equal_approx(float(owner.role_health_values["mage"]), 44.0), "charge II should heal mage by 20 percent missing health")

	RuntimeFlow.tick(owner, 3.10)
	_expect(is_equal_approx(RuntimeFlow.get_damage_reduction_value(owner, "swordsman"), 0.0), "charge I damage reduction should expire")
	owner.queue_free()


func _check_blade_storm_level_talents() -> void:
	var owner := OwnerStub.new()
	root.add_child(owner)
	owner.level_talents = {
		"swordsman_level_talent_blade_storm_1": true,
		"swordsman_level_talent_blade_storm_2": true
	}
	var blade := BladeStorm.new()
	blade.active_remaining = 1.0
	owner.swordsman_blade_storm_ability = blade

	_expect(is_equal_approx(blade.cast_radius, 150.0), "current storm base radius is 150; saved level talents do not replace the custom build")
	_expect(is_equal_approx(RuntimeFlow.get_move_speed_bonus(owner, "swordsman"), 20.0), "blade storm I should expose +20 move speed while active")
	_expect(is_equal_approx(RuntimeFlow.get_damage_reduction_value(owner, "swordsman"), 100.0), "blade storm I should expose 100 damage reduction while active")

	var role := SwordsmanRole.new()
	role.perform_attack(owner)
	_expect(owner.damage_rects.is_empty(), "saved blade storm II must not bypass the attached storm basic-attack lock")
	owner.queue_free()


func _check_basic_attack_level_talents() -> void:
	var owner := OwnerStub.new()
	root.add_child(owner)
	owner.level_talents = {
		"swordsman_level_talent_basic_attack_1": true,
		"swordsman_level_talent_basic_attack_2": true
	}
	var role := SwordsmanRole.new()

	_expect(is_equal_approx(role._get_basic_attack_range_multiplier(owner), 1.25), "basic attack II should enlarge hit and visual range by 25 percent")
	role.perform_attack(owner)

	_expect(owner.damage_rects.size() == 2, "basic attack II should create two immediate slash hit checks")
	_expect(owner.scheduled_sequences.size() == 1, "basic attack I should schedule one delayed second segment")
	if owner.damage_rects.size() >= 2:
		var first: Dictionary = owner.damage_rects[0] as Dictionary
		var second: Dictionary = owner.damage_rects[1] as Dictionary
		var angle_delta: float = abs(rad_to_deg(float(first["axis_angle"]) - float(second["axis_angle"])))
		angle_delta = min(angle_delta, 360.0 - angle_delta)
		_expect(is_equal_approx(angle_delta, 30.0), "basic attack II slashes should keep a 30 degree angle")
		_expect(is_equal_approx(float(first["damage"]), 100.0), "first basic slash should use base damage")
		_expect(is_equal_approx(float(second["damage"]), 100.0), "second basic slash should be able to deal full damage to the same target")
	if owner.scheduled_sequences.size() >= 1:
		var scheduled: Dictionary = owner.scheduled_sequences[0] as Dictionary
		_expect(is_equal_approx(float(scheduled["initial_delay"]), 0.10), "basic attack I second segment should be delayed by 0.1s")
		var callback: Callable = scheduled["callback"] as Callable
		callback.call(0)
	_expect(owner.damage_rects.size() == 4, "basic attack I delayed segment should also run the double slash checks")
	if owner.damage_rects.size() >= 4:
		var delayed_first: Dictionary = owner.damage_rects[2] as Dictionary
		var delayed_second: Dictionary = owner.damage_rects[3] as Dictionary
		_expect(is_equal_approx(float(delayed_first["damage"]), 60.0), "basic attack I delayed first slash should deal 60 percent damage")
		_expect(is_equal_approx(float(delayed_second["damage"]), 60.0), "basic attack I delayed second slash should deal 60 percent damage")
	owner.queue_free()


func _check_crescent_wave_level_talents() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var owner := OwnerStub.new()
	scene.add_child(owner)
	owner.level_talents = {
		"swordsman_level_talent_crescent_wave_1": true,
		"swordsman_level_talent_crescent_wave_2": true
	}
	var ability := CrescentWave.new()

	_expect(ability.try_trigger(owner), "crescent wave should trigger in the smoke owner")
	_expect(owner.crescent_slash_hits.size() == 1, "crescent wave should perform one immediate slash hit")
	_expect(ability.active_crescent_projectiles.size() == 1, "crescent wave should spawn one immediate projectile")
	_expect(owner.scheduled_sequences.size() == 2, "crescent level talents should schedule one rehit and one second wave")
	if owner.scheduled_sequences.size() >= 2:
		var slash_schedule: Dictionary = owner.scheduled_sequences[0] as Dictionary
		var wave_schedule: Dictionary = owner.scheduled_sequences[1] as Dictionary
		_expect(is_equal_approx(float(slash_schedule["initial_delay"]), 0.10), "crescent wave I slash rehit should be delayed by 0.1s")
		_expect(is_equal_approx(float(wave_schedule["initial_delay"]), 0.20), "crescent wave II second projectile should be delayed by 0.2s")
		var slash_callback: Callable = slash_schedule["callback"] as Callable
		var wave_callback: Callable = wave_schedule["callback"] as Callable
		slash_callback.call(0)
		wave_callback.call(0)
	_expect(owner.crescent_slash_hits.size() == 2, "crescent wave I should add one delayed slash hit")
	if owner.crescent_slash_hits.size() >= 2:
		var delayed_slash: Dictionary = owner.crescent_slash_hits[1] as Dictionary
		_expect(is_equal_approx(float(delayed_slash["damage"]), 78.0), "crescent wave I delayed slash should deal 60 percent damage")
	_expect(ability.active_crescent_projectiles.size() == 2, "crescent wave II should add one delayed projectile")
	if ability.active_crescent_projectiles.size() >= 2:
		var second_wave: Dictionary = ability.active_crescent_projectiles[1] as Dictionary
		_expect(is_equal_approx(float(second_wave.get("damage_amount", 0.0)), 78.0), "crescent wave II delayed projectile should deal 60 percent damage")
	scene.queue_free()
	current_scene = null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


class OwnerStub:
	extends Node2D

	const SWORDSMAN_DEATH_DEFIANCE_COOLDOWN := 80.0
	const SWORDSMAN_BLOODTHIRST_INTERNAL_COOLDOWN := 10.0
	const SWORD_SLASH_SCENE_SIZE := Vector2(256.0, 256.0)
	const SWORD_SLASH_SCENE_VISIBLE_BOUNDS := Rect2(99.0, 30.0, 27.0, 153.0)

	var level_talents: Dictionary = {}
	var role_special_states: Dictionary = {"swordsman": {}, "gunner": {}, "mage": {}}
	var blessing_skill_state: Dictionary = {"unlocked": {"blade_storm": true, "crescent_wave": true}}
	var roles: Array = [
		{"id": "swordsman", "range": 100.0},
		{"id": "gunner", "range": 100.0},
		{"id": "mage", "range": 100.0}
	]
	var role_upgrade_levels: Dictionary = {
		"swordsman": {"range_bonus": 0.0},
		"gunner": {"range_bonus": 0.0},
		"mage": {"range_bonus": 0.0}
	}
	var active_role_id: String = "swordsman"
	var role_health_values: Dictionary = {"swordsman": 100.0, "gunner": 100.0, "mage": 100.0}
	var role_max_health_values: Dictionary = {"swordsman": 100.0, "gunner": 100.0, "mage": 100.0}
	var max_health: float = 100.0
	var current_health: float = 100.0
	var is_dead: bool = false
	var level_up_active: bool = false
	var facing_direction: Vector2 = Vector2.RIGHT
	var swordsman_attack_chain: int = 0
	var swordsman_death_defiance_will_remaining: float = 0.0
	var swordsman_death_defiance_cooldown_remaining: float = 0.0
	var swordsman_bloodthirst_cooldown_remaining: float = 0.0
	var swordsman_entry_trait_share_remaining: float = 0.0
	var swordsman_bloodthirst_heal_multiplier: float = 1.0
	var switch_invulnerability_remaining: float = 0.0
	var switch_power_remaining: float = 0.0
	var switch_power_role_id: String = ""
	var switch_power_label: String = ""
	var healing_block_remaining: float = 0.0
	var aging_remaining: float = 0.0
	var aging_damage_carry: float = 0.0
	var confinement_remaining: float = 0.0
	var confinement_radius: float = 0.0
	var confinement_polygon: PackedVector2Array = PackedVector2Array()
	var enemy_move_slow_remaining: float = 0.0
	var enemy_move_slow_multiplier: float = 1.0
	var swordsman_blade_storm_ability = null
	var damage_rects: Array[Dictionary] = []
	var crescent_slash_hits: Array[Dictionary] = []
	var scheduled_sequences: Array[Dictionary] = []
	var cleared_statuses: Array[String] = []
	var healed_roles: Array[Dictionary] = []

	func _has_level_talent(talent_id: String) -> bool:
		return bool(level_talents.get(talent_id, false))

	func _has_skill_talent(_talent_id: String) -> bool:
		return false

	func _get_active_role_id() -> String:
		return active_role_id

	func _get_active_role() -> Dictionary:
		for role_value in roles:
			var role_data: Dictionary = role_value as Dictionary
			if str(role_data.get("id", "")) == active_role_id:
				return role_data
		return {}

	func _get_role_special_state(role_id: String) -> Dictionary:
		if not role_special_states.has(role_id) or role_special_states[role_id] is not Dictionary:
			role_special_states[role_id] = {}
		return role_special_states[role_id] as Dictionary

	func _get_role_max_health(role_id: String) -> float:
		return float(role_max_health_values.get(role_id, 0.0))

	func _get_role_current_health(role_id: String) -> float:
		return float(role_health_values.get(role_id, 0.0))

	func _heal_role(role_id: String, amount: float) -> void:
		var adjusted_amount: float = RuntimeFlow.apply_healing_multiplier(self, amount)
		var previous_health: float = _get_role_current_health(role_id)
		var next_health: float = min(_get_role_max_health(role_id), previous_health + adjusted_amount)
		role_health_values[role_id] = next_health
		if role_id == active_role_id:
			current_health = next_health
		healed_roles.append({"role_id": role_id, "amount": next_health - previous_health})

	func _clear_duration_status(status_id: String) -> void:
		cleared_statuses.append(status_id)

	func is_swordsman_blade_storm_active() -> bool:
		return swordsman_blade_storm_ability != null and swordsman_blade_storm_ability.has_method("is_active") and bool(swordsman_blade_storm_ability.is_active())

	func _is_blessing_skill_unlocked(_skill_id: String) -> bool:
		return true

	func _get_blessing_skill_tier(_skill_id: String) -> int:
		return 1

	func _get_blessing_skill_duration_multiplier(_skill_id: String) -> float:
		return 1.0

	func _get_blessing_skill_duration_flat_bonus(_skill_id: String) -> float:
		return 0.0

	func _get_blessing_skill_quantity_count(_skill_id: String) -> int:
		return 0

	func _get_blessing_skill_combo_scales(_skill_id: String) -> Array[float]:
		return []

	func _get_equipment_skill_range_multiplier(_role_id_or_skill_id: String = "") -> float:
		return 1.0

	func _get_role_equipment_skill_range_multiplier(_role_id: String) -> float:
		return 1.0

	func _get_role_attribute_range_multiplier(_role_id: String) -> float:
		return 1.0

	func _get_basic_attack_range_multiplier(_skill_id: String) -> float:
		return 1.0

	func _get_invoker_magic_range_multiplier(_skill_id: String) -> float:
		return 1.0

	func _get_kebiru_magic_range_multiplier(_skill_id: String) -> float:
		return 1.0

	func _get_kebiru_magic_cooldown_multiplier(_skill_id: String) -> float:
		return 1.0

	func _get_equipment_cooldown_multiplier() -> float:
		return 1.0

	func _get_role_damage(_role_id: String) -> float:
		return 100.0

	func _get_attack_aim_direction(fallback: Vector2) -> Vector2:
		return fallback.normalized()

	func _get_live_mouse_aim_direction(fallback: Vector2) -> Vector2:
		return fallback.normalized()

	func _get_swordsman_normal_attack_scale(_heart_level: float) -> float:
		return 1.0

	func _get_swordsman_normal_attack_width_scale(_heart_level: float) -> float:
		return 1.0

	func _get_downward_perpendicular(direction: Vector2) -> Vector2:
		return Vector2(-direction.y, direction.x)

	func _spawn_sword_slash_scene_effect(_center: Vector2, _axis: Vector2, _half_length: float, _color: Color, _duration: float, _width: float, _mirror: bool) -> void:
		pass

	func _get_sword_slash_scene_animation_duration() -> float:
		return 0.16

	func _damage_enemies_in_oriented_rect_unique(_center: Vector2, axis: Vector2, length: float, width: float, damage_amount: float, _vulnerability_bonus: float, _slow_multiplier: float, _slow_duration: float, _hit_registry: Dictionary, _source_role_id: String, _slow_source_id: String = "", _knockback_distance: float = 0.0) -> int:
		damage_rects.append({
			"axis_angle": axis.angle(),
			"length": length,
			"width": width,
			"damage": damage_amount
		})
		return 1

	func _damage_enemies_in_oriented_rect(center: Vector2, direction: Vector2, length: float, width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String) -> int:
		crescent_slash_hits.append({
			"center": center,
			"direction_angle": direction.angle(),
			"length": length,
			"width": width,
			"damage": damage_amount,
			"source_role_id": source_role_id,
			"vulnerability_bonus": vulnerability_bonus,
			"slow_multiplier": slow_multiplier,
			"slow_duration": slow_duration
		})
		return 1

	func _schedule_swordsman_slash_followthrough(_center: Vector2, _axis: Vector2, _length: float, _width: float, _damage_amount: float, _vulnerability_bonus: float, _slow_multiplier: float, _slow_duration: float, _delay: float, _source_role_id: String, _hit_registry: Dictionary) -> void:
		pass

	func _spawn_attack_aftershock(_center: Vector2, _role_id: String) -> void:
		pass

	func _register_attack_result(_role_id: String, _hit_count: int, _killed: bool) -> void:
		pass

	func _push_attack_result_context_tag(_tag: String) -> void:
		pass

	func _pop_attack_result_context_tag(_tag: String) -> void:
		pass

	func _schedule_repeating_sequence(interval: float, repeat_count: int, callback: Callable, initial_delay: float = 0.0) -> void:
		scheduled_sequences.append({
			"interval": interval,
			"repeat_count": repeat_count,
			"callback": callback,
			"initial_delay": initial_delay
		})

	func _spawn_sword_fan_scene_effect(_center: Vector2, _direction: Vector2, _visual_hit_multiplier: float) -> void:
		pass

	func _spawn_combat_tag(_position: Vector2, _text: String, _color: Color) -> void:
		pass

	func _spawn_ring_effect(_center: Vector2, _radius: float, _color: Color, _width: float, _duration: float) -> void:
		pass
