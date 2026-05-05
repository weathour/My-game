extends RefCounted

const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")

const SMALL_ENEMY_KILL_ENERGY_MULTIPLIER := 0.75
const BACKGROUND_ULTIMATE_ENERGY_GAIN_RATIO := 0.3


static func add_kill_energy(owner, amount: float) -> void:
	if amount <= 0.0:
		return
	var active_role_id: String = owner._get_active_role_id()
	for role_data in owner.roles:
		var role_id: String = str(role_data.get("id", ""))
		if role_id == "":
			continue
		if owner._get_role_ultimate_lock_remaining(role_id) > 0.0 and not DEVELOPER_MODE.should_unlock_ultimate_freely():
			continue
		var gain_scale: float = 1.0 if role_id == active_role_id else BACKGROUND_ULTIMATE_ENERGY_GAIN_RATIO
		var base_energy_gain_multiplier: float = owner.energy_gain_multiplier - owner.equipment_energy_gain_bonus + owner._get_role_equipment_energy_gain_bonus(role_id)
		var adjusted_amount: float = amount * gain_scale * max(0.01, base_energy_gain_multiplier) * owner._get_ultimate_energy_gain_multiplier_for_role(role_id)
		if adjusted_amount <= 0.0:
			continue
		var updated_mana: float = owner._add_role_mana(role_id, adjusted_amount, false)
		if role_id == active_role_id and owner._has_elite_relic("elite_reactor") and is_equal_approx(updated_mana, owner.max_mana):
			owner._activate_switch_power(active_role_id, "\u6EE1\u80FD\u53CD\u5E94", 2.8, 1.14, 0.04)
	owner._emit_active_mana_changed()


static func get_kill_energy_from_enemy(enemy: Node) -> float:
	if enemy == null or not is_instance_valid(enemy):
		return 0.0
	var enemy_kind: String = str(enemy.get("enemy_kind"))
	if enemy_kind == "boss":
		return 0.0
	if enemy_kind == "elite":
		return 10.0 * SMALL_ENEMY_KILL_ENERGY_MULTIPLIER
	var reward_tier: int = int(enemy.get("reward_tier"))
	match reward_tier:
		2:
			return 1.1 * SMALL_ENEMY_KILL_ENERGY_MULTIPLIER
		3:
			return 1.5 * SMALL_ENEMY_KILL_ENERGY_MULTIPLIER
		4:
			return 2.0 * SMALL_ENEMY_KILL_ENERGY_MULTIPLIER
		_:
			return 0.8 * SMALL_ENEMY_KILL_ENERGY_MULTIPLIER


static func get_boss_damage_energy(damage_amount: float) -> float:
	if damage_amount <= 0.0:
		return 0.0
	var energy_amount: float = sqrt(damage_amount) * 0.18
	return clamp(energy_amount, 0.25, 2.0)


static func register_attack_result(owner, role_id: String, hit_count: int, killed: bool) -> void:
	apply_entry_lifesteal(owner, role_id, hit_count, killed)
	if killed and owner._has_elite_relic("elite_execution_pact") and not owner.execution_pact_burst_active:
		owner.execution_pact_burst_active = true
		owner._spawn_burst_effect(owner.global_position + owner.facing_direction * 20.0, 42.0, Color(1.0, 0.62, 0.4, 0.16), 0.16)
		owner._damage_enemies_in_radius(owner.global_position + owner.facing_direction * 20.0, 42.0, owner._get_role_damage(role_id) * 0.34, 0.0, 1.0, 0.0)
		owner.execution_pact_burst_active = false
	if killed and owner._has_elite_relic("elite_battle_frenzy"):
		var previous_stacks: int = owner.frenzy_stacks
		owner.frenzy_stacks = min(8, owner.frenzy_stacks + 1)
		owner.frenzy_remaining = 5.0
		if previous_stacks >= 8 and owner.frenzy_stacks >= 8:
			owner.frenzy_overkill_counter += 1
			if owner.frenzy_overkill_counter >= 6:
				owner.frenzy_overkill_counter = 0


static func apply_theme_hit_returns(owner, role_id: String, hit_count: int, killed: bool) -> void:
	return


static func apply_entry_lifesteal(owner, role_id: String, hit_count: int, killed: bool) -> void:
	if owner.entry_blessing_remaining <= 0.0:
		return
	if owner.entry_blessing_role_id != role_id:
		return
	if owner.entry_lifesteal_ratio <= 0.0 or hit_count <= 0:
		return

	var capped_hits: int = min(hit_count, 6)
	var estimated_damage: float = owner._get_role_damage(role_id) * float(capped_hits) * 0.55
	if killed:
		estimated_damage += owner._get_role_damage(role_id) * 0.35
	var heal_amount: float = estimated_damage * owner.entry_lifesteal_ratio
	if heal_amount > 0.0:
		owner._heal(heal_amount)


static func trigger_chain_reaction(owner, role_id: String) -> void:
	return


static func trigger_clean_tide(owner, role_id: String) -> void:
	return


static func spawn_attack_aftershock(owner, center: Vector2, role_id: String) -> void:
	return


static func play_player_hurt_feedback(owner) -> void:
	owner._queue_camera_shake(6.0, 0.16)
	owner._pulse_player_visual(1.18, 0.16)
	owner._spawn_burst_effect(owner.get_hurtbox_center(), 54.0, Color(1.0, 0.3, 0.3, 0.18), 0.16)


static func trigger_swordsman_counter(owner) -> void:
	var special_data: Dictionary = owner._get_role_special_state("swordsman")
	var counter_level: int = int(special_data.get("counter_level", 0))
	if counter_level <= 0:
		return

	var radius: float = 62.0 + counter_level * 14.0
	var damage_amount: float = owner._get_role_damage("swordsman") * (0.38 + counter_level * 0.14)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -24.0), "\u53CD\u51FB", Color(1.0, 0.84, 0.48, 1.0))
	owner._spawn_guard_effect(owner.global_position, radius, Color(1.0, 0.84, 0.46, 0.22), 0.18)
	owner._spawn_burst_effect(owner.global_position, radius, Color(1.0, 0.76, 0.38, 0.22), 0.16)
	var hits: int = owner._damage_enemies_in_radius(owner.global_position, radius, damage_amount, 0.08 * counter_level, 1.0, 0.0)
	if hits > 0:
		owner._register_attack_result("swordsman", hits, false)
		owner._heal(1.2 + counter_level * 0.5)
		owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, 0.05 + counter_level * 0.02)


static func count_enemies_in_radius(owner, center: Vector2, radius: float) -> int:
	var count: int = 0
	for enemy in owner.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if center.distance_to(enemy.global_position) <= radius:
			count += 1
	return count
