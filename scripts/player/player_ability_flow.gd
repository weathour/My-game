extends RefCounted

const PLAYER_SKILL_COOLDOWN_FLOW := preload("res://scripts/player/player_skill_cooldown_flow.gd")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const PLAYER_BLESSING_SKILL_STATE := preload("res://scripts/player/player_blessing_skill_state.gd")


static func try_trigger_swordsman_blade_storm(owner) -> void:
	if GAME_SETTINGS.is_skill_manual("blade_storm"):
		return
	if _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.swordsman_blade_storm_ability == null or not owner.swordsman_blade_storm_ability.can_trigger(owner, active_role_id):
		return
	start_swordsman_blade_storm(owner)


static func try_trigger_swordsman_knight_thrust(owner) -> void:
	if GAME_SETTINGS.is_skill_manual("knight_thrust"):
		return
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.swordsman_knight_thrust_ability != null and owner.swordsman_knight_thrust_ability.can_trigger(owner, active_role_id):
		owner.swordsman_knight_thrust_ability.try_trigger(owner)


static func try_trigger_swordsman_king_blade(owner) -> void:
	if GAME_SETTINGS.is_skill_manual("king_blade"):
		return
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.swordsman_king_blade_ability != null and owner.swordsman_king_blade_ability.can_trigger(owner, active_role_id):
		owner.swordsman_king_blade_ability.try_trigger(owner)


static func try_trigger_swordsman_judgement_sword(owner) -> void:
	if GAME_SETTINGS.is_skill_manual("judgement_sword"):
		return
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.swordsman_judgement_sword_ability != null and owner.swordsman_judgement_sword_ability.can_trigger(owner, active_role_id):
		owner.swordsman_judgement_sword_ability.try_trigger(owner)


static func try_trigger_swordsman_crescent_wave(owner) -> void:
	if GAME_SETTINGS.is_skill_manual("crescent_wave"):
		return
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.swordsman_crescent_wave_ability == null or not owner.swordsman_crescent_wave_ability.can_trigger(owner, active_role_id):
		return
	start_swordsman_crescent_wave(owner)


static func try_trigger_gunner_infinite_reload(owner) -> void:
	if GAME_SETTINGS.is_skill_manual("infinite_reload"):
		return
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
	if GAME_SETTINGS.is_skill_manual("explosive_round"):
		return
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.gunner_explosive_round_ability != null and owner.gunner_explosive_round_ability.can_trigger(owner, active_role_id):
		owner.gunner_explosive_round_ability.try_trigger(owner)


static func try_trigger_gunner_magic_grenade(owner) -> void:
	if GAME_SETTINGS.is_skill_manual("magic_grenade"):
		return
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.gunner_magic_grenade_ability != null and owner.gunner_magic_grenade_ability.can_trigger(owner, active_role_id):
		owner.gunner_magic_grenade_ability.try_trigger(owner)


static func try_trigger_gunner_magic_eye(owner) -> void:
	if GAME_SETTINGS.is_skill_manual("magic_eye"):
		return
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.gunner_magic_eye_ability != null and owner.gunner_magic_eye_ability.can_trigger(owner, active_role_id):
		owner.gunner_magic_eye_ability.try_trigger(owner)


static func try_trigger_gunner_shrapnel_field(owner) -> void:
	if GAME_SETTINGS.is_skill_manual("shrapnel_field"):
		return
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.gunner_shrapnel_field_ability == null or not owner.gunner_shrapnel_field_ability.can_trigger(owner, active_role_id):
		return
	start_gunner_shrapnel_field(owner)


static func try_trigger_mage_tidal_surge(owner) -> void:
	if GAME_SETTINGS.is_skill_manual("surging_wave"):
		return
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.mage_tidal_surge_ability == null or not owner.mage_tidal_surge_ability.can_trigger(owner, active_role_id):
		return
	start_mage_tidal_surge(owner)


static func try_trigger_mage_flame_path(owner) -> void:
	if GAME_SETTINGS.is_skill_manual("flame_path"):
		return
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.mage_flame_path_ability != null and owner.mage_flame_path_ability.can_trigger(owner, active_role_id):
		owner.mage_flame_path_ability.try_trigger(owner)


static func try_trigger_mage_dark_contract(owner) -> void:
	if GAME_SETTINGS.is_skill_manual("dark_contract"):
		return
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.mage_dark_contract_ability != null and owner.mage_dark_contract_ability.can_trigger(owner, active_role_id):
		owner.mage_dark_contract_ability.try_trigger(owner)


static func try_trigger_mage_fireball(owner) -> void:
	if GAME_SETTINGS.is_skill_manual("fireball"):
		return
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.mage_fireball_ability != null and owner.mage_fireball_ability.can_trigger(owner, active_role_id):
		owner.mage_fireball_ability.try_trigger(owner)


static func try_trigger_mechanic_drone(owner) -> void:
	if GAME_SETTINGS.is_skill_manual("drone"):
		return
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.mechanic_drone_ability != null and owner.mechanic_drone_ability.can_trigger(owner, active_role_id):
		owner.mechanic_drone_ability.try_trigger(owner)


static func try_trigger_mechanic_mine(owner) -> void:
	if GAME_SETTINGS.is_skill_manual("mine"):
		return
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.mechanic_mine_ability != null and owner.mechanic_mine_ability.can_trigger(owner, active_role_id):
		owner.mechanic_mine_ability.try_trigger(owner)


static func try_trigger_mechanic_emp_burst(owner) -> void:
	if GAME_SETTINGS.is_skill_manual("emp_burst"):
		return
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.mechanic_emp_burst_ability != null and owner.mechanic_emp_burst_ability.can_trigger(owner, active_role_id):
		owner.mechanic_emp_burst_ability.try_trigger(owner)


static func try_trigger_mechanic_tulip_turret(owner) -> void:
	if GAME_SETTINGS.is_skill_manual("tulip_turret"):
		return
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.mechanic_tulip_turret_ability != null and owner.mechanic_tulip_turret_ability.can_trigger(owner, active_role_id):
		owner.mechanic_tulip_turret_ability.try_trigger(owner)


static func try_trigger_mechanic_missile_volley(owner) -> void:
	if GAME_SETTINGS.is_skill_manual("missile_volley"):
		return
	if owner.is_dead or owner.level_up_active or _is_action_blocked_by_lock_or_manual_skill(owner):
		return
	var active_role_id := str(owner._get_active_role().get("id", ""))
	if owner.mechanic_missile_volley_ability != null and owner.mechanic_missile_volley_ability.can_trigger(owner, active_role_id):
		owner.mechanic_missile_volley_ability.try_trigger(owner)


static func try_trigger_mage_meta_field(owner) -> void:
	if GAME_SETTINGS.is_skill_manual("meta_field"):
		return
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
	var skill_id := get_slot_skill_id(owner, slot_index)
	if skill_id == "":
		# 空槽（该角色还没有第 N 个主动技能）：给出反馈，避免看起来像按键失灵
		_spawn_slot_feedback(owner, "该技能槽暂无技能", Color(0.78, 0.82, 0.9, 1.0))
		return true
	if skill_id == "infinite_reload" and owner.gunner_infinite_reload_ability != null and owner.gunner_infinite_reload_ability.is_manual_toggle_enabled(owner):
		if owner.has_method("_is_player_action_locked") and owner._is_player_action_locked():
			return false
		return bool(owner.gunner_infinite_reload_ability.toggle_manual(owner))
	# 自动释放状态下快捷键不施放，必须先切换为手动释放
	if not GAME_SETTINGS.is_skill_manual(skill_id):
		var title := str(PLAYER_BLESSING_SKILL_STATE.get_skill_title(skill_id))
		if title == "":
			title = skill_id
		var key_text := GAME_SETTINGS.get_key_display_name(GAME_SETTINGS.load_keycode(GAME_SETTINGS.get_skill_slot_action_id(slot_index)))
		_spawn_slot_feedback(owner, "%s：自动释放（Ctrl+%s 切换）" % [title, key_text], Color(0.62, 0.86, 1.0, 1.0))
		return true
	# 普通无限装填按技能释放模式处理；火力调控在上方直接处理开关。
	if skill_id == "infinite_reload":
		var reload_ability: Variant = owner.get("gunner_infinite_reload_ability")
		if reload_ability != null and reload_ability.has_method("is_manual_toggle_enabled") and bool(reload_ability.is_manual_toggle_enabled(owner)):
			return bool(reload_ability.toggle_manual(owner))
		if _is_action_blocked_by_lock_or_manual_skill(owner):
			return false
		return start_skill_by_id(owner, skill_id)
	if _is_action_blocked_by_lock_or_manual_skill(owner):
		return false
	return start_skill_by_id(owner, skill_id)


static func _spawn_slot_feedback(owner, text: String, color: Color) -> void:
	if owner == null or not is_instance_valid(owner) or not owner.has_method("_spawn_combat_tag"):
		return
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -44.0), text, color)


static func toggle_manual_skill_slot(owner, slot_index: int) -> bool:
	if owner == null or slot_index < 1:
		return false
	return toggle_skill_manual(owner, get_slot_skill_id(owner, slot_index))


static func toggle_skill_manual(owner, skill_id: String) -> bool:
	var role_id := PLAYER_BLESSING_SKILL_STATE.get_skill_role_id(skill_id)
	if not PLAYER_SKILL_COOLDOWN_FLOW.ROLE_ACTIVE_SKILL_PROPERTIES.get(role_id, {}).has(skill_id):
		return false
	if skill_id == "infinite_reload" and owner != null and owner.get("gunner_infinite_reload_ability") != null and owner.gunner_infinite_reload_ability.is_manual_toggle_enabled(owner):
		_spawn_slot_feedback(owner, "火力调控：按技能快捷键开启或关闭", Color(1.0, 0.86, 0.42))
		return true
	var manual := GAME_SETTINGS.toggle_skill_manual(skill_id)
	if owner != null and is_instance_valid(owner):
		var title := str(PLAYER_BLESSING_SKILL_STATE.get_skill_title(skill_id))
		if title == "":
			title = skill_id
		var state_text := "手动释放" if manual else "自动释放"
		if owner.has_method("_spawn_combat_tag"):
			var tag_color := Color(1.0, 0.86, 0.42, 1.0) if manual else Color(0.62, 0.86, 1.0, 1.0)
			owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -44.0), "%s：%s" % [title, state_text], tag_color)
		if owner.has_signal("stats_changed") and owner.has_method("get_stat_summary"):
			owner.stats_changed.emit(owner.get_stat_summary())
	return true


static func get_slot_skill_id(owner, slot_index: int) -> String:
	if owner == null or slot_index < 1:
		return ""
	var active_role_id := str(owner._get_active_role().get("id", "")) if owner.has_method("_get_active_role") else ""
	var skill_ids: Array[String] = PLAYER_SKILL_COOLDOWN_FLOW.get_role_active_skill_ids(owner, active_role_id)
	if slot_index > skill_ids.size():
		return ""
	return str(skill_ids[slot_index - 1])


static func start_skill_by_id(owner, skill_id: String) -> bool:
	if owner == null:
		return false
	var role_id := str(PLAYER_BLESSING_SKILL_STATE.get_skill_role_id(skill_id))
	var property_name := str(PLAYER_SKILL_COOLDOWN_FLOW.ROLE_ACTIVE_SKILL_PROPERTIES.get(role_id, {}).get(skill_id, ""))
	if property_name == "":
		return false
	var ability: Variant = owner.get(property_name)
	if ability == null:
		return false
	# 潮涌需要施放瞬间的瞄准方向；其他主动技能共用属性表分发。
	if skill_id == "surging_wave":
		start_mage_tidal_surge(owner)
	else:
		ability.try_trigger(owner)
	return true


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
