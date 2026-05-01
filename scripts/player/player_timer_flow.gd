extends RefCounted

const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const ROLE_RESOURCE_STATE := preload("res://scripts/player/roles/role_resource_state.gd")
const PLAYER_THEME_SKILL_FLOW := preload("res://scripts/player/player_theme_skill_flow.gd")


static func update_timers(owner, delta: float) -> void:
	owner.role_visual_time += delta
	ROLE_RESOURCE_STATE.tick_locks(owner.role_ultimate_energy_lock_remaining, owner.roles, delta)
	owner._sync_active_role_ultimate_state()
	if owner.hurt_cooldown_remaining > 0.0:
		owner.hurt_cooldown_remaining = max(0.0, owner.hurt_cooldown_remaining - delta)
	if owner.switch_invulnerability_remaining > 0.0:
		owner.switch_invulnerability_remaining = max(0.0, owner.switch_invulnerability_remaining - delta)
	if owner.level_up_delay_remaining > 0.0:
		owner.level_up_delay_remaining = max(0.0, owner.level_up_delay_remaining - delta)
		if owner.level_up_delay_remaining <= 0.0:
			owner._try_request_level_up()
	if owner.switch_cooldown_remaining > 0.0:
		owner.switch_cooldown_remaining = max(0.0, owner.switch_cooldown_remaining - delta)
	if owner.enemy_move_slow_remaining > 0.0:
		owner.enemy_move_slow_remaining = max(0.0, owner.enemy_move_slow_remaining - delta)
		if owner.enemy_move_slow_remaining <= 0.0:
			owner.enemy_move_slow_multiplier = 1.0
	PLAYER_THEME_SKILL_FLOW.update_cooldowns(owner, delta)
	if owner.swordsman_dangzhen_fan_ability != null:
		owner.swordsman_dangzhen_fan_ability.update(delta)
	if owner.gunner_dangzhen_beam_ability != null:
		owner.gunner_dangzhen_beam_ability.update(delta)
	if owner.gunner_infinite_reload_ability != null:
		owner.gunner_infinite_reload_ability.update(owner, delta)
	if owner.mage_tidal_surge_ability != null:
		owner.mage_tidal_surge_ability.update(delta)
	if owner.mage_dangzhen_wave_ability != null:
		owner.mage_dangzhen_wave_ability.update(delta)
	if owner.swordsman_blade_storm_ability != null:
		owner.swordsman_blade_storm_ability.update(owner, delta)
	owner._try_trigger_independent_sword_qichao()
	owner._try_trigger_independent_gunner_qichao()
	owner._try_trigger_independent_mage_qichao()
	owner._try_trigger_swordsman_blade_storm()
	owner._try_trigger_gunner_infinite_reload()
	owner._try_trigger_mage_tidal_surge()
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
	if owner.standby_entry_remaining > 0.0:
		owner.standby_entry_remaining = max(0.0, owner.standby_entry_remaining - delta)
		if owner.standby_entry_remaining <= 0.0:
			owner._clear_standby_entry_buff()
	if owner.guard_cover_remaining > 0.0:
		owner.guard_cover_remaining = max(0.0, owner.guard_cover_remaining - delta)
		if owner.guard_cover_remaining <= 0.0:
			owner.guard_cover_damage_multiplier = 1.0
	if owner.team_combo_remaining > 0.0:
		owner.team_combo_remaining = max(0.0, owner.team_combo_remaining - delta)
		if owner.team_combo_remaining <= 0.0:
			owner.team_combo_damage_multiplier = 1.0
			owner.team_combo_move_multiplier = 1.0
			owner.team_combo_background_multiplier = 1.0
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
	if owner.frenzy_remaining > 0.0:
		owner.frenzy_remaining = max(0.0, owner.frenzy_remaining - delta)
		if owner.frenzy_remaining <= 0.0:
			owner.frenzy_stacks = 0
			owner.frenzy_overkill_counter = 0
	if owner.relay_window_remaining > 0.0:
		owner.relay_window_remaining = max(0.0, owner.relay_window_remaining - delta)
		if owner.relay_window_remaining <= 0.0:
			owner.relay_ready_role_id = ""
			owner.relay_from_role_id = ""
			owner.relay_label = ""
			owner.relay_bonus_pending = false
	for role_data in owner.roles:
		var role_id := str(role_data.get("id", ""))
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
	if owner.swordsman_dangzhen_fan_ability != null:
		owner.swordsman_dangzhen_fan_ability.cooldown_remaining = 0.0
	if owner.gunner_dangzhen_beam_ability != null:
		owner.gunner_dangzhen_beam_ability.cooldown_remaining = 0.0
	if owner.gunner_infinite_reload_ability != null:
		owner.gunner_infinite_reload_ability.cooldown_remaining = 0.0
	if owner.mage_dangzhen_wave_ability != null:
		owner.mage_dangzhen_wave_ability.cooldown_remaining = 0.0
	if owner.mage_tidal_surge_ability != null:
		owner.mage_tidal_surge_ability.cooldown_remaining = 0.0
	if owner.swordsman_blade_storm_ability != null:
		owner.swordsman_blade_storm_ability.cooldown_remaining = 0.0
