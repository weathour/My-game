extends RefCounted

const PLAYER_SKILL_COOLDOWN_FLOW := preload("res://scripts/player/player_skill_cooldown_flow.gd")


static func try_trigger_swordsman_blade_storm(owner) -> void:
	if _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.swordsman_blade_storm_ability == null or not owner.swordsman_blade_storm_ability.can_trigger(owner, active_role_id):
		return
	start_swordsman_blade_storm(owner)


static func try_trigger_swordsman_knight_thrust(owner) -> void:
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.swordsman_knight_thrust_ability != null and owner.swordsman_knight_thrust_ability.can_trigger(owner, active_role_id):
		owner.swordsman_knight_thrust_ability.try_trigger(owner)


static func try_trigger_swordsman_king_blade(owner) -> void:
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.swordsman_king_blade_ability != null and owner.swordsman_king_blade_ability.can_trigger(owner, active_role_id):
		owner.swordsman_king_blade_ability.try_trigger(owner)


static func try_trigger_swordsman_judgement_sword(owner) -> void:
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.swordsman_judgement_sword_ability != null and owner.swordsman_judgement_sword_ability.can_trigger(owner, active_role_id):
		owner.swordsman_judgement_sword_ability.try_trigger(owner)


static func try_trigger_swordsman_crescent_wave(owner) -> void:
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.swordsman_crescent_wave_ability == null or not owner.swordsman_crescent_wave_ability.can_trigger(owner, active_role_id):
		return
	start_swordsman_crescent_wave(owner)


static func try_trigger_gunner_infinite_reload(owner) -> void:
	if owner.is_dead or owner.level_up_active or (owner.has_method("_is_player_action_locked") and owner._is_player_action_locked()):
		return
	if owner.gunner_infinite_reload_ability == null:
		return
	if owner.gunner_infinite_reload_ability.has_method("is_manual_toggle_enabled") and owner.gunner_infinite_reload_ability.is_manual_toggle_enabled(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if not owner.gunner_infinite_reload_ability.can_trigger(owner, active_role_id):
		return
	start_gunner_infinite_reload(owner)


static func try_trigger_gunner_explosive_round(owner) -> void:
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.gunner_explosive_round_ability != null and owner.gunner_explosive_round_ability.can_trigger(owner, active_role_id):
		owner.gunner_explosive_round_ability.try_trigger(owner)


static func try_trigger_gunner_magic_grenade(owner) -> void:
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.gunner_magic_grenade_ability != null and owner.gunner_magic_grenade_ability.can_trigger(owner, active_role_id):
		owner.gunner_magic_grenade_ability.try_trigger(owner)


static func try_trigger_gunner_magic_eye(owner) -> void:
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.gunner_magic_eye_ability != null and owner.gunner_magic_eye_ability.can_trigger(owner, active_role_id):
		owner.gunner_magic_eye_ability.try_trigger(owner)


static func try_trigger_gunner_shrapnel_field(owner) -> void:
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.gunner_shrapnel_field_ability == null or not owner.gunner_shrapnel_field_ability.can_trigger(owner, active_role_id):
		return
	start_gunner_shrapnel_field(owner)


static func try_trigger_mage_tidal_surge(owner) -> void:
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.mage_tidal_surge_ability == null or not owner.mage_tidal_surge_ability.can_trigger(owner, active_role_id):
		return
	start_mage_tidal_surge(owner)


static func try_trigger_mage_flame_path(owner) -> void:
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.mage_flame_path_ability != null and owner.mage_flame_path_ability.can_trigger(owner, active_role_id):
		owner.mage_flame_path_ability.try_trigger(owner)


static func try_trigger_mage_dark_contract(owner) -> void:
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.mage_dark_contract_ability != null and owner.mage_dark_contract_ability.can_trigger(owner, active_role_id):
		owner.mage_dark_contract_ability.try_trigger(owner)


static func try_trigger_mage_fireball(owner) -> void:
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.mage_fireball_ability != null and owner.mage_fireball_ability.can_trigger(owner, active_role_id):
		owner.mage_fireball_ability.try_trigger(owner)


static func try_trigger_mechanic_drone(owner) -> void:
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.mechanic_drone_ability != null and owner.mechanic_drone_ability.can_trigger(owner, active_role_id):
		owner.mechanic_drone_ability.try_trigger(owner)


static func try_trigger_mechanic_mine(owner) -> void:
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.mechanic_mine_ability != null and owner.mechanic_mine_ability.can_trigger(owner, active_role_id):
		owner.mechanic_mine_ability.try_trigger(owner)


static func try_trigger_mechanic_emp_burst(owner) -> void:
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.mechanic_emp_burst_ability != null and owner.mechanic_emp_burst_ability.can_trigger(owner, active_role_id):
		owner.mechanic_emp_burst_ability.try_trigger(owner)


static func try_trigger_mechanic_tulip_turret(owner) -> void:
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.mechanic_tulip_turret_ability != null and owner.mechanic_tulip_turret_ability.can_trigger(owner, active_role_id):
		owner.mechanic_tulip_turret_ability.try_trigger(owner)


static func try_trigger_mechanic_missile_volley(owner) -> void:
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.mechanic_missile_volley_ability != null and owner.mechanic_missile_volley_ability.can_trigger(owner, active_role_id):
		owner.mechanic_missile_volley_ability.try_trigger(owner)


static func try_trigger_mage_meta_field(owner) -> void:
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.mage_meta_field_ability == null or not owner.mage_meta_field_ability.can_trigger(owner, active_role_id):
		return
	start_mage_meta_field(owner)


static func start_swordsman_blade_storm(owner) -> void:
	if owner.swordsman_blade_storm_ability != null:
		owner.swordsman_blade_storm_ability.try_trigger(owner)


static func is_swordsman_blade_storm_active(owner) -> bool:
	return owner.swordsman_blade_storm_ability != null and owner.swordsman_blade_storm_ability.is_active()


static func start_swordsman_knight_thrust(owner) -> void:
	if owner.swordsman_knight_thrust_ability != null:
		owner.swordsman_knight_thrust_ability.try_trigger(owner)


static func start_swordsman_king_blade(owner) -> void:
	if owner.swordsman_king_blade_ability != null:
		owner.swordsman_king_blade_ability.try_trigger(owner)


static func start_swordsman_judgement_sword(owner) -> void:
	if owner.swordsman_judgement_sword_ability != null:
		owner.swordsman_judgement_sword_ability.try_trigger(owner)


static func start_swordsman_crescent_wave(owner) -> void:
	if owner.swordsman_crescent_wave_ability != null:
		owner.swordsman_crescent_wave_ability.try_trigger(owner)


static func trigger_swordsman_blade_storm_tick(owner) -> void:
	if owner.swordsman_blade_storm_ability != null:
		owner.swordsman_blade_storm_ability._trigger_tick(owner)


static func ensure_swordsman_blade_storm_effect(owner) -> void:
	if owner.swordsman_blade_storm_ability != null:
		owner.swordsman_blade_storm_ability.restore_effect_if_active(owner)


static func update_swordsman_blade_storm_effect(owner, delta: float) -> void:
	if owner.swordsman_blade_storm_ability != null:
		owner.swordsman_blade_storm_ability._update_effect(owner, delta)


static func stop_swordsman_blade_storm(owner) -> void:
	if owner.swordsman_blade_storm_ability != null:
		owner.swordsman_blade_storm_ability.stop()


static func cleanup_gunner_infinite_reload_effects(owner) -> void:
	if owner.gunner_infinite_reload_ability != null:
		owner.gunner_infinite_reload_ability._cleanup_effects()


static func register_gunner_infinite_reload_effect(owner, effect: Node2D) -> void:
	if owner.gunner_infinite_reload_ability != null:
		owner.gunner_infinite_reload_ability.register_effect(effect)


static func start_gunner_infinite_reload(owner) -> void:
	if owner.gunner_infinite_reload_ability != null:
		owner.gunner_infinite_reload_ability.try_trigger(owner)


static func try_handle_manual_skill_slot(owner, slot_index: int) -> bool:
	if owner == null or slot_index < 1 or owner.is_dead or owner.level_up_active:
		return false
	var active_role_id := str(owner._get_active_role().get("id", ""))
	var skill_ids := PLAYER_SKILL_COOLDOWN_FLOW.get_role_active_skill_ids(owner, active_role_id)
	if slot_index > skill_ids.size():
		return false
	var skill_id := str(skill_ids[slot_index - 1])
	if skill_id != "infinite_reload":
		return false
	if owner.gunner_infinite_reload_ability == null:
		return false
	if not owner.gunner_infinite_reload_ability.has_method("is_manual_toggle_enabled") or not owner.gunner_infinite_reload_ability.is_manual_toggle_enabled(owner):
		return false
	return owner.gunner_infinite_reload_ability.toggle_manual(owner)


static func start_gunner_explosive_round(owner) -> void:
	if owner.gunner_explosive_round_ability != null:
		owner.gunner_explosive_round_ability.try_trigger(owner)


static func start_gunner_magic_grenade(owner) -> void:
	if owner.gunner_magic_grenade_ability != null:
		owner.gunner_magic_grenade_ability.try_trigger(owner)


static func start_gunner_magic_eye(owner) -> void:
	if owner.gunner_magic_eye_ability != null:
		owner.gunner_magic_eye_ability.try_trigger(owner)


static func start_gunner_shrapnel_field(owner) -> void:
	if owner.gunner_shrapnel_field_ability != null:
		owner.gunner_shrapnel_field_ability.try_trigger(owner)


static func trigger_gunner_infinite_reload_tick(owner) -> void:
	if owner.gunner_infinite_reload_ability != null:
		owner.gunner_infinite_reload_ability._trigger_tick(owner)


static func stop_gunner_infinite_reload(owner) -> void:
	if owner.gunner_infinite_reload_ability != null:
		owner.gunner_infinite_reload_ability.stop()


static func is_gunner_infinite_reload_active(owner) -> bool:
	return owner.gunner_infinite_reload_ability != null and owner.gunner_infinite_reload_ability.is_active()


static func is_gunner_infinite_reload_blocking_actions(owner) -> bool:
	return (
		owner.gunner_infinite_reload_ability != null
		and owner.gunner_infinite_reload_ability.has_method("is_blocking_actions")
		and owner.gunner_infinite_reload_ability.is_blocking_actions(owner)
	)


static func is_gunner_infinite_reload_movement_locked(owner) -> bool:
	var ability = owner.get("gunner_infinite_reload_ability") if owner != null else null
	return (
		ability != null
		and ability.has_method("is_movement_locked")
		and ability.is_movement_locked(owner)
	)


static func is_gunner_infinite_reload_preventing_switch(owner) -> bool:
	var ability = owner.get("gunner_infinite_reload_ability") if owner != null else null
	return (
		ability != null
		and ability.has_method("is_preventing_switch")
		and ability.is_preventing_switch(owner)
	)


static func get_mage_flame_path_move_speed_multiplier(owner) -> float:
	if owner.mage_flame_path_ability != null:
		return float(owner.mage_flame_path_ability.get_move_speed_multiplier(owner))
	return 1.0


static func get_gunner_infinite_reload_move_speed_multiplier(owner) -> float:
	if owner.gunner_infinite_reload_ability != null and owner.gunner_infinite_reload_ability.has_method("get_move_speed_multiplier"):
		return float(owner.gunner_infinite_reload_ability.get_move_speed_multiplier(owner))
	return 1.0


static func get_gunner_infinite_reload_dodge_value(owner, role_id: String = "") -> float:
	var ability = owner.get("gunner_infinite_reload_ability") if owner != null else null
	if ability != null and ability.has_method("get_dodge_value_bonus"):
		return float(ability.get_dodge_value_bonus(owner, role_id))
	return 0.0


static func _is_action_blocked_by_lock_or_manual_skill(owner) -> bool:
	if owner.has_method("_is_player_action_locked") and owner._is_player_action_locked():
		return true
	if owner.has_method("is_gunner_infinite_reload_blocking_actions") and owner.is_gunner_infinite_reload_blocking_actions():
		return true
	return false


static func start_mage_tidal_surge(owner) -> void:
	if owner.mage_tidal_surge_ability == null:
		return
	var base_direction: Vector2 = owner._get_live_mouse_aim_direction(owner.facing_direction)
	owner.mage_tidal_surge_ability.try_trigger(owner, base_direction)


static func start_mage_flame_path(owner) -> void:
	if owner.mage_flame_path_ability != null:
		owner.mage_flame_path_ability.try_trigger(owner)


static func start_mage_dark_contract(owner) -> void:
	if owner.mage_dark_contract_ability != null:
		owner.mage_dark_contract_ability.try_trigger(owner)


static func start_mage_fireball(owner) -> void:
	if owner.mage_fireball_ability != null:
		owner.mage_fireball_ability.try_trigger(owner)


static func start_mage_meta_field(owner) -> void:
	if owner.mage_meta_field_ability != null:
		owner.mage_meta_field_ability.try_trigger(owner)


static func start_mechanic_drone(owner) -> void:
	if owner.mechanic_drone_ability != null:
		owner.mechanic_drone_ability.try_trigger(owner)


static func start_mechanic_mine(owner) -> void:
	if owner.mechanic_mine_ability != null:
		owner.mechanic_mine_ability.try_trigger(owner)


static func start_mechanic_emp_burst(owner) -> void:
	if owner.mechanic_emp_burst_ability != null:
		owner.mechanic_emp_burst_ability.try_trigger(owner)


static func start_mechanic_tulip_turret(owner) -> void:
	if owner.mechanic_tulip_turret_ability != null:
		owner.mechanic_tulip_turret_ability.try_trigger(owner)


static func start_mechanic_missile_volley(owner) -> void:
	if owner.mechanic_missile_volley_ability != null:
		owner.mechanic_missile_volley_ability.try_trigger(owner)
