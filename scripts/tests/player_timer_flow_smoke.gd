extends SceneTree

const DeveloperMode := preload("res://scripts/developer_mode.gd")
const PlayerTimerFlow := preload("res://scripts/player/player_timer_flow.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_timer_expiry_and_entry_rescue()
	_check_developer_no_cooldown()
	DeveloperMode.deactivate()
	if failures.is_empty():
		print("PLAYER_TIMER_FLOW_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_timer_expiry_and_entry_rescue() -> void:
	var owner := TimerOwnerStub.new()
	owner.roles = [
		{"id": "swordsman"},
		{"id": "gunner"}
	]
	owner.active_role_id = "swordsman"
	owner.role_standby_elapsed = {
		"swordsman": 8.0,
		"gunner": 2.0
	}
	owner.entry_rescue_remaining = 0.2
	owner.entry_rescue_regen_per_second = 10.0
	owner.entry_blessing_remaining = 0.1
	owner.standby_entry_remaining = 0.1
	owner.switch_power_remaining = 0.1
	owner.switch_power_role_id = "swordsman"
	owner.switch_power_damage_multiplier = 1.2
	owner.switch_power_interval_bonus = 0.1
	owner.switch_power_label = "test"
	owner.guard_cover_remaining = 0.1
	owner.guard_cover_damage_multiplier = 1.8
	owner.borrow_fire_remaining = 0.1
	owner.borrow_fire_role_id = "gunner"
	owner.borrow_fire_damage_multiplier = 1.4
	owner.borrow_fire_interval_bonus = 0.2
	owner.borrow_fire_background_multiplier = 1.3
	owner.post_ultimate_flow_remaining = 0.1
	owner.post_ultimate_flow_background_multiplier = 1.5
	owner.ultimate_guard_remaining = 0.1
	owner.ultimate_guard_damage_multiplier = 1.6
	owner.frenzy_remaining = 0.1
	owner.frenzy_stacks = 3
	owner.frenzy_overkill_counter = 2
	owner.role_special_states["swordsman"] = {"ultimate_lifesteal_multiplier_remaining": 0.2}

	PlayerTimerFlow.update_timers(owner, 0.25)

	if not owner.sync_ultimate_called:
		failures.append("timer flow should sync active role ultimate locks")
	if owner.healed_amount <= 0.0:
		failures.append("entry rescue should heal while active")
	if owner.entry_rescue_regen_per_second != 0.0:
		failures.append("entry rescue regen should reset after expiry")
	if not owner.entry_blessing_cleared:
		failures.append("entry blessing should clear after expiry")
	if not owner.standby_entry_cleared:
		failures.append("standby entry buff should clear after expiry")
	if owner.guard_cover_damage_multiplier != 1.0:
		failures.append("guard cover multiplier should reset after expiry")
	if owner.borrow_fire_role_id != "" or owner.borrow_fire_damage_multiplier != 1.0 or owner.borrow_fire_background_multiplier != 1.0:
		failures.append("borrow fire state should reset after expiry")
	if owner.post_ultimate_flow_background_multiplier != 1.0:
		failures.append("post ultimate flow multiplier should reset after expiry")
	if owner.ultimate_guard_damage_multiplier != 1.0:
		failures.append("ultimate guard multiplier should reset after expiry")
	if owner.frenzy_stacks != 0 or owner.frenzy_overkill_counter != 0:
		failures.append("frenzy counters should reset after expiry")
	if float(owner.role_standby_elapsed.get("swordsman", -1.0)) != 0.0:
		failures.append("active role standby elapsed should reset")
	if float(owner.role_standby_elapsed.get("gunner", 0.0)) <= 2.0:
		failures.append("inactive role standby elapsed should advance")
	var swordsman_special: Dictionary = owner.role_special_states.get("swordsman", {})
	if float(swordsman_special.get("ultimate_lifesteal_multiplier_remaining", -1.0)) != 0.0:
		failures.append("swordsman temporary special timer should tick down")
	if owner.camera_update_calls != 1:
		failures.append("timer flow should update camera shake once")
	if owner.fire_timer_updates < 2:
		failures.append("expiring switch/borrow buffs should refresh fire timer")
	owner.free()


func _check_developer_no_cooldown() -> void:
	var owner := TimerOwnerStub.new()
	owner.switch_cooldown_remaining = 3.0
	owner.perpetual_motion_cooldown_remaining = 4.0
	owner.gunner_infinite_reload_ability = AbilityStub.new()
	owner.gunner_shrapnel_field_ability = AbilityStub.new()
	owner.mage_tidal_surge_ability = AbilityStub.new()
	owner.mage_meta_field_ability = AbilityStub.new()
	owner.swordsman_blade_storm_ability = AbilityStub.new()
	owner.swordsman_crescent_wave_ability = AbilityStub.new()

	DeveloperMode.activate()
	DeveloperMode.set_no_cooldown_enabled(true)
	PlayerTimerFlow.apply_developer_no_cooldown(owner)
	if owner.switch_cooldown_remaining != 0.0 or owner.perpetual_motion_cooldown_remaining != 0.0:
		failures.append("developer no cooldown should clear player cooldown timers")
	for ability in [
		owner.gunner_infinite_reload_ability,
		owner.gunner_shrapnel_field_ability,
		owner.mage_tidal_surge_ability,
		owner.mage_meta_field_ability,
		owner.swordsman_blade_storm_ability,
		owner.swordsman_crescent_wave_ability
	]:
		if ability.cooldown_remaining != 0.0:
			failures.append("developer no cooldown should clear ability cooldown timers")
			break
	DeveloperMode.deactivate()
	owner.free()


class AbilityStub:
	var cooldown_remaining: float = 9.0

	func update(_owner = null, _delta: float = 0.0) -> void:
		pass


class TimerOwnerStub:
	extends Node2D

	var role_visual_time: float = 0.0
	var role_ultimate_energy_lock_remaining: Dictionary = {}
	var roles: Array = []
	var hurt_cooldown_remaining: float = 0.0
	var switch_invulnerability_remaining: float = 0.0
	var level_up_delay_remaining: float = 0.0
	var switch_cooldown_remaining: float = 0.0
	var lifesteal_proc_cooldown_remaining: float = 0.0
	var role_special_states: Dictionary = {}
	var enemy_move_slow_remaining: float = 0.0
	var enemy_move_slow_multiplier: float = 1.0
	var gunner_infinite_reload_ability = null
	var gunner_shrapnel_field_ability = null
	var mage_tidal_surge_ability = null
	var mage_meta_field_ability = null
	var swordsman_blade_storm_ability = null
	var swordsman_crescent_wave_ability = null
	var perpetual_motion_cooldown_remaining: float = 0.0
	var switch_power_remaining: float = 0.0
	var switch_power_role_id: String = ""
	var switch_power_damage_multiplier: float = 1.0
	var switch_power_interval_bonus: float = 0.0
	var switch_power_label: String = ""
	var entry_blessing_remaining: float = 0.0
	var entry_rescue_remaining: float = 0.0
	var entry_rescue_regen_per_second: float = 0.0
	var standby_entry_remaining: float = 0.0
	var guard_cover_remaining: float = 0.0
	var guard_cover_damage_multiplier: float = 1.0
	var borrow_fire_remaining: float = 0.0
	var borrow_fire_role_id: String = ""
	var borrow_fire_damage_multiplier: float = 1.0
	var borrow_fire_interval_bonus: float = 0.0
	var borrow_fire_background_multiplier: float = 1.0
	var post_ultimate_flow_remaining: float = 0.0
	var post_ultimate_flow_background_multiplier: float = 1.0
	var ultimate_guard_remaining: float = 0.0
	var ultimate_guard_damage_multiplier: float = 1.0
	var frenzy_remaining: float = 0.0
	var frenzy_stacks: int = 0
	var frenzy_overkill_counter: int = 0
	var role_standby_elapsed: Dictionary = {}
	var active_role_id: String = "swordsman"
	var sync_ultimate_called: bool = false
	var entry_blessing_cleared: bool = false
	var standby_entry_cleared: bool = false
	var healed_amount: float = 0.0
	var camera_update_calls: int = 0
	var fire_timer_updates: int = 0

	func _sync_active_role_ultimate_state() -> void:
		sync_ultimate_called = true

	func _try_request_level_up() -> void:
		pass

	func _get_role_special_state(role_id: String) -> Dictionary:
		return role_special_states.get(role_id, {})

	func _try_trigger_swordsman_blade_storm() -> void:
		pass

	func _try_trigger_swordsman_crescent_wave() -> void:
		pass

	func _try_trigger_gunner_infinite_reload() -> void:
		pass

	func _try_trigger_gunner_shrapnel_field() -> void:
		pass

	func _try_trigger_mage_tidal_surge() -> void:
		pass

	func _try_trigger_mage_meta_field() -> void:
		pass

	func _update_fire_timer() -> void:
		fire_timer_updates += 1

	func _clear_entry_blessing() -> void:
		entry_blessing_cleared = true

	func _heal(amount: float) -> void:
		healed_amount += amount

	func _clear_standby_entry_buff() -> void:
		standby_entry_cleared = true

	func _get_active_role() -> Dictionary:
		return {"id": active_role_id}

	func _update_camera_shake(_delta: float) -> void:
		camera_update_calls += 1
