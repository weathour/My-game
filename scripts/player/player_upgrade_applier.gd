extends RefCounted

const PLAYER_REWARD_APPLIER := preload("res://scripts/player/player_reward_applier.gd")
const PLAYER_EQUIPMENT_FLOW := preload("res://scripts/player/player_equipment_flow.gd")
const PLAYER_FINAL_UPGRADE_APPLIER := preload("res://scripts/player/player_final_upgrade_applier.gd")
const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")


static func apply_upgrade(owner, option_id: String) -> void:
	if PLAYER_REWARD_APPLIER.is_noop_upgrade(option_id):
		_finish_upgrade(owner)
		return
	var blessing_result: Dictionary = PLAYER_BLESSING_SYSTEM.apply_option_with_result(owner, option_id)
	if not blessing_result.is_empty():
		if owner.has_method("_refresh_blessing_skill_unlocks"):
			owner._refresh_blessing_skill_unlocks(
				str(blessing_result.get("blessing_id", "")),
				int(blessing_result.get("tier", 0)),
				str(blessing_result.get("binding", ""))
			)
		_finish_upgrade(owner, true, true)
		return
	if PLAYER_EQUIPMENT_FLOW.apply_equipment_reward(owner, option_id):
		_finish_upgrade(owner, true, true)
		return
	if PLAYER_REWARD_APPLIER.apply_small_boss_reward(owner, option_id):
		_finish_upgrade(owner, true, true)
		return
	if _apply_final_core(owner, option_id):
		_finish_upgrade(owner, true, true)
		return

	# Unknown ids are ignored intentionally. Stale save/editor option ids should
	# not mutate current runs.
	_finish_upgrade(owner)


static func _apply_final_core(owner, option_id: String) -> bool:
	if not ["final_body_core", "final_combat_core", "final_skill_core"].has(option_id):
		return false
	var role_id: String = str(owner._get_active_role().get("id", ""))
	var role_data: Dictionary = owner.role_upgrade_levels.get(role_id, {})
	var special_data: Dictionary = owner._get_role_special_state(role_id)
	PLAYER_FINAL_UPGRADE_APPLIER.apply_final_upgrade(owner, option_id, role_id, role_data, special_data)
	owner.role_upgrade_levels[role_id] = role_data
	owner.role_special_states[role_id] = special_data
	return true


static func _finish_upgrade(owner, refresh_stats: bool = false, refresh_health: bool = false) -> void:
	owner.level_up_active = false
	if refresh_stats:
		owner._update_fire_timer()
		owner.stats_changed.emit(owner.get_stat_summary())
		owner._emit_active_mana_changed()
	if refresh_health:
		owner.health_changed.emit(owner.current_health, owner.max_health)
	if owner.get("pending_blessing_binding_choices") is Array and not (owner.get("pending_blessing_binding_choices") as Array).is_empty():
		return
	owner._try_request_level_up()
