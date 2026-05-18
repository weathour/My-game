extends RefCounted


static func try_trigger_swordsman_blade_storm(owner) -> void:
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.swordsman_blade_storm_ability == null or not owner.swordsman_blade_storm_ability.can_trigger(owner, active_role_id):
		return
	start_swordsman_blade_storm(owner)


static func try_trigger_swordsman_crescent_wave(owner) -> void:
	if owner.is_dead or owner.level_up_active:
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.swordsman_crescent_wave_ability == null or not owner.swordsman_crescent_wave_ability.can_trigger(owner, active_role_id):
		return
	start_swordsman_crescent_wave(owner)


static func try_trigger_gunner_infinite_reload(owner) -> void:
	if owner.is_dead or owner.level_up_active:
		return
	if owner.gunner_infinite_reload_ability == null:
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if not owner.gunner_infinite_reload_ability.can_trigger(owner, active_role_id):
		return
	start_gunner_infinite_reload(owner)


static func try_trigger_gunner_shrapnel_field(owner) -> void:
	if owner.is_dead or owner.level_up_active:
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.gunner_shrapnel_field_ability == null or not owner.gunner_shrapnel_field_ability.can_trigger(owner, active_role_id):
		return
	start_gunner_shrapnel_field(owner)


static func try_trigger_mage_tidal_surge(owner) -> void:
	if owner.is_dead or owner.level_up_active:
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.mage_tidal_surge_ability == null or not owner.mage_tidal_surge_ability.can_trigger(owner, active_role_id):
		return
	start_mage_tidal_surge(owner)


static func try_trigger_mage_meta_field(owner) -> void:
	if owner.is_dead or owner.level_up_active:
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.mage_meta_field_ability == null or not owner.mage_meta_field_ability.can_trigger(owner, active_role_id):
		return
	start_mage_meta_field(owner)


static func start_swordsman_blade_storm(owner) -> void:
	if owner.swordsman_blade_storm_ability != null:
		owner.swordsman_blade_storm_ability.try_trigger(owner)


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


static func get_gunner_infinite_reload_move_speed_multiplier(owner) -> float:
	if owner.gunner_infinite_reload_ability != null and owner.gunner_infinite_reload_ability.has_method("get_move_speed_multiplier"):
		return float(owner.gunner_infinite_reload_ability.get_move_speed_multiplier(owner))
	return 1.0


static func start_mage_tidal_surge(owner) -> void:
	if owner.mage_tidal_surge_ability == null:
		return
	var base_direction: Vector2 = owner._get_live_mouse_aim_direction(owner.facing_direction)
	owner.mage_tidal_surge_ability.try_trigger(owner, base_direction)


static func start_mage_meta_field(owner) -> void:
	if owner.mage_meta_field_ability != null:
		owner.mage_meta_field_ability.try_trigger(owner)
