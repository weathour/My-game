extends RefCounted

const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const ROLE_RESOURCE_STATE := preload("res://scripts/player/roles/role_resource_state.gd")
const PLAYER_SWORDSMAN_BATTLE_WILL_FLOW := preload("res://scripts/player/player_swordsman_battle_will_flow.gd")
const PLAYER_SWORDSMAN_TRAIT_RUNTIME_FLOW := preload("res://scripts/player/player_swordsman_trait_runtime_flow.gd")
const PLAYER_SWORDSMAN_ULTIMATE_FLOW := preload("res://scripts/player/player_swordsman_ultimate_flow.gd")
const PLAYER_GUNNER_FLASH_TALENT_FLOW := preload("res://scripts/player/player_gunner_flash_talent_flow.gd")
const PLAYER_GUNNER_ENTRY_TALENT_FLOW := preload("res://scripts/player/player_gunner_entry_talent_flow.gd")
const PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW := preload("res://scripts/player/player_mage_arcane_surplus_talent_flow.gd")
const MAGE_ARCANE_SURPLUS_EXPIRE_CHARGE_STACKS := 3


static func update_timers(owner, delta: float) -> void:
	owner.role_visual_time += delta
	if owner.has_method("_tick_duration_statuses"):
		owner._tick_duration_statuses(delta)
	if owner.has_method("_tick_temporary_health_stacks"):
		owner._tick_temporary_health_stacks(delta)
	if owner.has_method("_tick_blessing_health_regen"):
		owner._tick_blessing_health_regen(delta)
	ROLE_RESOURCE_STATE.tick_locks(owner.role_ultimate_energy_lock_remaining, owner.roles, delta)
	owner._sync_active_role_ultimate_state()
	if owner.hurt_cooldown_remaining > 0.0:
		owner.hurt_cooldown_remaining = max(0.0, owner.hurt_cooldown_remaining - delta)
	if owner.switch_invulnerability_remaining > 0.0:
		owner.switch_invulnerability_remaining = max(0.0, owner.switch_invulnerability_remaining - delta)
	if owner.hidden_invulnerability_status_remaining > 0.0:
		owner.hidden_invulnerability_status_remaining = max(0.0, owner.hidden_invulnerability_status_remaining - delta)
	if owner.has_method("_sync_invulnerability_status"):
		owner._sync_invulnerability_status()
	if owner.level_up_delay_remaining > 0.0:
		owner.level_up_delay_remaining = max(0.0, owner.level_up_delay_remaining - delta)
		if owner.level_up_delay_remaining <= 0.0:
			owner._try_request_level_up()
	if owner.switch_cooldown_remaining > 0.0:
		owner.switch_cooldown_remaining = max(0.0, owner.switch_cooldown_remaining - delta)
	if owner.lifesteal_proc_cooldown_remaining > 0.0:
		owner.lifesteal_proc_cooldown_remaining = max(0.0, owner.lifesteal_proc_cooldown_remaining - delta)
	if owner.swordsman_trait_heal_cooldown_remaining > 0.0:
		owner.swordsman_trait_heal_cooldown_remaining = max(0.0, owner.swordsman_trait_heal_cooldown_remaining - delta)
	PLAYER_SWORDSMAN_TRAIT_RUNTIME_FLOW.tick(owner, delta)
	PLAYER_GUNNER_FLASH_TALENT_FLOW.tick(owner, delta)
	PLAYER_GUNNER_ENTRY_TALENT_FLOW.tick(owner, delta)
	if owner.mage_arcane_surplus_remaining > 0.0:
		var previous_arcane_surplus_remaining: float = owner.mage_arcane_surplus_remaining
		owner.mage_arcane_surplus_remaining = max(0.0, owner.mage_arcane_surplus_remaining - delta)
		var active_role_id: String = str(owner._get_active_role().get("id", "")) if owner.has_method("_get_active_role") else ""
		if previous_arcane_surplus_remaining > 0.0 and owner.mage_arcane_surplus_remaining <= 0.0 and active_role_id == "mage" and owner.has_method("_add_mage_arcane_charge_stacks"):
			var expire_stacks := MAGE_ARCANE_SURPLUS_EXPIRE_CHARGE_STACKS
			if owner.get("mage_role") != null and owner.mage_role.has_method("get_arcane_surplus_expire_stacks"):
				expire_stacks = int(owner.mage_role.get_arcane_surplus_expire_stacks(owner, expire_stacks))
			owner._add_mage_arcane_charge_stacks(expire_stacks)
		if owner.has_method("_sync_duration_status"):
			owner._sync_duration_status("mage_arcane_surplus", "\u5965\u6CD5\u76C8\u4F59", owner.mage_arcane_surplus_remaining, 18, Color(0.34, 0.72, 1.0, 0.95))
	if owner.mage_arcane_charge_transfer_remaining > 0.0:
		owner.mage_arcane_charge_transfer_remaining = max(0.0, owner.mage_arcane_charge_transfer_remaining - delta)
		if owner.mage_arcane_charge_transfer_remaining <= 0.0 and owner.has_method("_clear_mage_arcane_charge_transfer"):
			owner._clear_mage_arcane_charge_transfer()
	if owner.greed_heal_cooldown_remaining > 0.0:
		owner.greed_heal_cooldown_remaining = max(0.0, owner.greed_heal_cooldown_remaining - delta)
	if owner.has_method("_tick_gunner_flash_trait"):
		owner._tick_gunner_flash_trait(delta)
	if owner.get("gunner_role") != null and owner.gunner_role.has_method("update_talent_states"):
		owner.gunner_role.update_talent_states(owner, delta)
	if owner.get("mechanic_role") != null and owner.mechanic_role.has_method("update_trait_state"):
		owner.mechanic_role.update_trait_state(owner, delta)
	PLAYER_SWORDSMAN_BATTLE_WILL_FLOW.tick(owner, delta)
	PLAYER_SWORDSMAN_ULTIMATE_FLOW.update(owner, delta)
	var swordsman_special: Dictionary = owner._get_role_special_state("swordsman")
	if float(swordsman_special.get("ultimate_lifesteal_multiplier_remaining", 0.0)) > 0.0:
		swordsman_special["ultimate_lifesteal_multiplier_remaining"] = max(0.0, float(swordsman_special.get("ultimate_lifesteal_multiplier_remaining", 0.0)) - delta)
		owner.role_special_states["swordsman"] = swordsman_special
	if owner.enemy_move_slow_remaining > 0.0:
		owner.enemy_move_slow_remaining = max(0.0, owner.enemy_move_slow_remaining - delta)
		if owner.enemy_move_slow_remaining <= 0.0:
			owner.enemy_move_slow_multiplier = 1.0
	if owner.gunner_infinite_reload_ability != null:
		PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.apply_skill_cooldown_tick_bonus(owner, owner.gunner_infinite_reload_ability, "gunner", delta)
		owner.gunner_infinite_reload_ability.update(owner, delta)
	if owner.gunner_explosive_round_ability != null:
		PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.apply_skill_cooldown_tick_bonus(owner, owner.gunner_explosive_round_ability, "gunner", delta)
		owner.gunner_explosive_round_ability.update(owner, delta)
	if owner.gunner_magic_grenade_ability != null:
		PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.apply_skill_cooldown_tick_bonus(owner, owner.gunner_magic_grenade_ability, "gunner", delta)
		owner.gunner_magic_grenade_ability.update(owner, delta)
	if owner.gunner_magic_eye_ability != null:
		PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.apply_skill_cooldown_tick_bonus(owner, owner.gunner_magic_eye_ability, "gunner", delta)
		owner.gunner_magic_eye_ability.update(owner, delta)
	if owner.gunner_shrapnel_field_ability != null:
		PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.apply_skill_cooldown_tick_bonus(owner, owner.gunner_shrapnel_field_ability, "gunner", delta)
		owner.gunner_shrapnel_field_ability.update(owner, delta)
	if owner.mage_flame_path_ability != null:
		PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.apply_skill_cooldown_tick_bonus(owner, owner.mage_flame_path_ability, "mage", delta)
		owner.mage_flame_path_ability.update(owner, delta)
	if owner.mage_dark_contract_ability != null:
		PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.apply_skill_cooldown_tick_bonus(owner, owner.mage_dark_contract_ability, "mage", delta)
		owner.mage_dark_contract_ability.update(owner, delta)
	if owner.mage_fireball_ability != null:
		PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.apply_skill_cooldown_tick_bonus(owner, owner.mage_fireball_ability, "mage", delta)
		owner.mage_fireball_ability.update(owner, delta)
	if owner.mage_tidal_surge_ability != null:
		PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.apply_skill_cooldown_tick_bonus(owner, owner.mage_tidal_surge_ability, "mage", delta)
		owner.mage_tidal_surge_ability.update(delta)
	if owner.mage_meta_field_ability != null:
		PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.apply_skill_cooldown_tick_bonus(owner, owner.mage_meta_field_ability, "mage", delta)
		owner.mage_meta_field_ability.update(owner, delta)
	if owner.swordsman_blade_storm_ability != null:
		PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.apply_skill_cooldown_tick_bonus(owner, owner.swordsman_blade_storm_ability, "swordsman", delta)
		owner.swordsman_blade_storm_ability.update(owner, delta)
	if owner.swordsman_knight_thrust_ability != null:
		PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.apply_skill_cooldown_tick_bonus(owner, owner.swordsman_knight_thrust_ability, "swordsman", delta)
		owner.swordsman_knight_thrust_ability.update(owner, delta)
	if owner.swordsman_king_blade_ability != null:
		PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.apply_skill_cooldown_tick_bonus(owner, owner.swordsman_king_blade_ability, "swordsman", delta)
		owner.swordsman_king_blade_ability.update(owner, delta)
	if owner.swordsman_judgement_sword_ability != null:
		PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.apply_skill_cooldown_tick_bonus(owner, owner.swordsman_judgement_sword_ability, "swordsman", delta)
		owner.swordsman_judgement_sword_ability.update(owner, delta)
	if owner.swordsman_crescent_wave_ability != null:
		PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.apply_skill_cooldown_tick_bonus(owner, owner.swordsman_crescent_wave_ability, "swordsman", delta)
		owner.swordsman_crescent_wave_ability.update(delta)
	if owner.get("mechanic_drone_ability") != null:
		PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.apply_skill_cooldown_tick_bonus(owner, owner.get("mechanic_drone_ability"), "mechanic", delta)
		owner.mechanic_drone_ability.update(owner, delta)
	if owner.get("mechanic_mine_ability") != null:
		PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.apply_skill_cooldown_tick_bonus(owner, owner.get("mechanic_mine_ability"), "mechanic", delta)
		owner.mechanic_mine_ability.update(owner, delta)
	if owner.get("mechanic_emp_burst_ability") != null:
		PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.apply_skill_cooldown_tick_bonus(owner, owner.get("mechanic_emp_burst_ability"), "mechanic", delta)
		owner.mechanic_emp_burst_ability.update(owner, delta)
	if owner.get("mechanic_tulip_turret_ability") != null:
		PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.apply_skill_cooldown_tick_bonus(owner, owner.get("mechanic_tulip_turret_ability"), "mechanic", delta)
		owner.mechanic_tulip_turret_ability.update(owner, delta)
	if owner.get("mechanic_missile_volley_ability") != null:
		PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.apply_skill_cooldown_tick_bonus(owner, owner.get("mechanic_missile_volley_ability"), "mechanic", delta)
		owner.mechanic_missile_volley_ability.update(owner, delta)
	owner._try_trigger_swordsman_blade_storm()
	owner._try_trigger_swordsman_knight_thrust()
	owner._try_trigger_swordsman_king_blade()
	owner._try_trigger_swordsman_judgement_sword()
	owner._try_trigger_swordsman_crescent_wave()
	owner._try_trigger_gunner_infinite_reload()
	owner._try_trigger_gunner_explosive_round()
	owner._try_trigger_gunner_magic_grenade()
	owner._try_trigger_gunner_magic_eye()
	owner._try_trigger_gunner_shrapnel_field()
	owner._try_trigger_mage_flame_path()
	owner._try_trigger_mage_tidal_surge()
	owner._try_trigger_mage_meta_field()
	owner._try_trigger_mage_dark_contract()
	owner._try_trigger_mage_fireball()
	if owner.has_method("_try_trigger_mechanic_drone"):
		owner._try_trigger_mechanic_drone()
	if owner.has_method("_try_trigger_mechanic_mine"):
		owner._try_trigger_mechanic_mine()
	if owner.has_method("_try_trigger_mechanic_emp_burst"):
		owner._try_trigger_mechanic_emp_burst()
	if owner.has_method("_try_trigger_mechanic_tulip_turret"):
		owner._try_trigger_mechanic_tulip_turret()
	if owner.has_method("_try_trigger_mechanic_missile_volley"):
		owner._try_trigger_mechanic_missile_volley()
	if owner.perpetual_motion_cooldown_remaining > 0.0:
		owner.perpetual_motion_cooldown_remaining = max(0.0, owner.perpetual_motion_cooldown_remaining - delta)
	apply_developer_no_cooldown(owner)
	if owner.switch_power_remaining > 0.0:
		owner.switch_power_remaining = max(0.0, owner.switch_power_remaining - delta)
		if owner.switch_power_remaining <= 0.0:
			owner.switch_power_role_id = ""
			owner.switch_power_damage_multiplier = 1.0
			owner.switch_power_interval_bonus = 0.0
			owner.switch_power_label = ""
			owner._update_fire_timer()
	if owner.entry_blessing_remaining > 0.0:
		owner.entry_blessing_remaining = max(0.0, owner.entry_blessing_remaining - delta)
		if owner.entry_blessing_remaining <= 0.0:
			owner._clear_entry_blessing()
	if owner.ultimate_haste_remaining > 0.0:
		owner.ultimate_haste_remaining = max(0.0, owner.ultimate_haste_remaining - delta)
		if owner.ultimate_haste_remaining <= 0.0:
			owner.ultimate_haste_move_speed_multiplier = 1.0
			owner.ultimate_haste_dodge_chance = 0.0
	if owner.entry_rescue_remaining > 0.0:
		owner.entry_rescue_remaining = max(0.0, owner.entry_rescue_remaining - delta)
		if owner.entry_rescue_regen_per_second > 0.0:
			owner._heal(owner.entry_rescue_regen_per_second * delta)
		if owner.entry_rescue_remaining <= 0.0:
			owner.entry_rescue_regen_per_second = 0.0
	if owner.standby_entry_remaining > 0.0:
		owner.standby_entry_remaining = max(0.0, owner.standby_entry_remaining - delta)
		if owner.standby_entry_remaining <= 0.0:
			owner._clear_standby_entry_buff()
	if owner.guard_cover_remaining > 0.0:
		owner.guard_cover_remaining = max(0.0, owner.guard_cover_remaining - delta)
		if owner.guard_cover_remaining <= 0.0:
			owner.guard_cover_damage_multiplier = 1.0
	if owner.borrow_fire_remaining > 0.0:
		owner.borrow_fire_remaining = max(0.0, owner.borrow_fire_remaining - delta)
		if owner.borrow_fire_remaining <= 0.0:
			owner.borrow_fire_role_id = ""
			owner.borrow_fire_damage_multiplier = 1.0
			owner.borrow_fire_interval_bonus = 0.0
			owner.borrow_fire_background_multiplier = 1.0
			owner._update_fire_timer()
	if owner.post_ultimate_flow_remaining > 0.0:
		owner.post_ultimate_flow_remaining = max(0.0, owner.post_ultimate_flow_remaining - delta)
		if owner.post_ultimate_flow_remaining <= 0.0:
			owner.post_ultimate_flow_background_multiplier = 1.0
	if owner.ultimate_guard_remaining > 0.0:
		owner.ultimate_guard_remaining = max(0.0, owner.ultimate_guard_remaining - delta)
		if owner.ultimate_guard_remaining <= 0.0:
			owner.ultimate_guard_damage_multiplier = 1.0
	if owner.player_action_lock_remaining > 0.0:
		owner.player_action_lock_remaining = max(0.0, owner.player_action_lock_remaining - delta)
	if owner.frenzy_remaining > 0.0:
		owner.frenzy_remaining = max(0.0, owner.frenzy_remaining - delta)
		if owner.frenzy_remaining <= 0.0:
			owner.frenzy_stacks = 0
			owner.frenzy_overkill_counter = 0
	for role_data in owner.roles:
		var role_id: String = str(role_data.get("id", ""))
		if role_id == str(owner._get_active_role().get("id", "")):
			owner.role_standby_elapsed[role_id] = 0.0
		else:
			owner.role_standby_elapsed[role_id] = float(owner.role_standby_elapsed.get(role_id, 0.0)) + delta
	owner._update_camera_shake(delta)


static func apply_developer_no_cooldown(owner) -> void:
	if not DEVELOPER_MODE.should_ignore_cooldowns():
		return
	owner.switch_cooldown_remaining = 0.0
	owner.perpetual_motion_cooldown_remaining = 0.0
	if owner.gunner_infinite_reload_ability != null:
		owner.gunner_infinite_reload_ability.cooldown_remaining = 0.0
	if owner.gunner_explosive_round_ability != null:
		owner.gunner_explosive_round_ability.cooldown_remaining = 0.0
	if owner.gunner_magic_grenade_ability != null:
		owner.gunner_magic_grenade_ability.cooldown_remaining = 0.0
	if owner.gunner_magic_eye_ability != null:
		owner.gunner_magic_eye_ability.cooldown_remaining = 0.0
	if owner.gunner_magic_eye_ability != null:
		owner.gunner_magic_eye_ability.shots_remaining = 0
	if owner.gunner_shrapnel_field_ability != null:
		owner.gunner_shrapnel_field_ability.cooldown_remaining = 0.0
	if owner.mage_flame_path_ability != null:
		owner.mage_flame_path_ability.cooldown_remaining = 0.0
	if owner.mage_dark_contract_ability != null:
		owner.mage_dark_contract_ability.cooldown_remaining = 0.0
	if owner.mage_fireball_ability != null:
		owner.mage_fireball_ability.cooldown_remaining = 0.0
	if owner.mage_tidal_surge_ability != null:
		owner.mage_tidal_surge_ability.cooldown_remaining = 0.0
	if owner.mage_meta_field_ability != null:
		owner.mage_meta_field_ability.cooldown_remaining = 0.0
	if owner.swordsman_blade_storm_ability != null:
		owner.swordsman_blade_storm_ability.cooldown_remaining = 0.0
	if owner.swordsman_knight_thrust_ability != null:
		owner.swordsman_knight_thrust_ability.cooldown_remaining = 0.0
	if owner.swordsman_king_blade_ability != null:
		owner.swordsman_king_blade_ability.cooldown_remaining = 0.0
	if owner.swordsman_judgement_sword_ability != null:
		owner.swordsman_judgement_sword_ability.cooldown_remaining = 0.0
	if owner.swordsman_judgement_sword_ability != null:
		owner.swordsman_judgement_sword_ability.active_remaining = 0.0
	if owner.swordsman_crescent_wave_ability != null:
		owner.swordsman_crescent_wave_ability.cooldown_remaining = 0.0
	if owner.get("mechanic_drone_ability") != null:
		owner.mechanic_drone_ability.cooldown_remaining = 0.0
	if owner.get("mechanic_mine_ability") != null:
		owner.mechanic_mine_ability.cooldown_remaining = 0.0
	if owner.get("mechanic_emp_burst_ability") != null:
		owner.mechanic_emp_burst_ability.cooldown_remaining = 0.0
	if owner.get("mechanic_tulip_turret_ability") != null:
		owner.mechanic_tulip_turret_ability.cooldown_remaining = 0.0
	if owner.get("mechanic_missile_volley_ability") != null:
		owner.mechanic_missile_volley_ability.cooldown_remaining = 0.0
