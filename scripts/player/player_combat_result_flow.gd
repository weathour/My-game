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
	owner._trigger_relay_success(role_id, hit_count)
	apply_entry_lifesteal(owner, role_id, hit_count, killed)
	apply_theme_hit_returns(owner, role_id, hit_count, killed)
	if hit_count > 0 and owner._get_card_level("battle_chain") > 0:
		trigger_chain_reaction(owner, role_id)
	if hit_count >= 2 and owner._get_card_level("battle_tide") > 0:
		trigger_clean_tide(owner, role_id)
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
	if hit_count <= 0:
		return
	var capped_hits: int = min(hit_count, 6)
	var blood_drink_level: int = max(0, int(owner._get_card_level("battle_blood_drink")))
	if blood_drink_level > 0:
		var heal_amount: float = owner._get_role_damage(role_id) * 0.018 * float(blood_drink_level) * float(capped_hits)
		if killed:
			heal_amount += 0.8 * float(blood_drink_level)
		owner._heal(heal_amount)
		if role_id == "gunner":
			owner._add_energy(0.25 * float(blood_drink_level))

	var finale_charge_level: int = max(0, int(owner._get_card_level("battle_finale_charge")))
	if finale_charge_level > 0:
		owner._add_energy(0.16 * float(finale_charge_level) * float(capped_hits))

	var finale_unity_level: int = max(0, int(owner._get_card_level("battle_finale_unity")))
	if finale_unity_level > 0 and killed:
		owner._add_energy(0.65 * float(finale_unity_level))


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
	var chain_level: int = owner._get_card_level("battle_chain")
	if chain_level <= 0 or owner.chain_reaction_active:
		return
	owner.chain_reaction_active = true
	var search_center: Vector2 = owner.global_position + owner.facing_direction * 28.0
	var search_radius: float = 220.0
	var bounce_count: int = 1 if chain_level == 1 else 2
	var chain_damage_ratio: float = [0.45, 0.55, 0.65][chain_level - 1]
	var previous_target: Node2D = null
	var from_position: Vector2 = search_center
	for bounce_index in range(bounce_count):
		var chosen_target: Node2D = null
		var best_distance: float = search_radius
		for enemy in owner.get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy):
				continue
			if enemy == previous_target:
				continue
			var distance: float = from_position.distance_to(enemy.global_position)
			if distance > best_distance:
				continue
			best_distance = distance
			chosen_target = enemy
		if chosen_target == null:
			break
		owner._spawn_dash_line_effect(from_position, chosen_target.global_position, Color(0.92, 0.56, 1.0, 0.9), 6.0, 0.1)
		owner._spawn_target_lock_effect(chosen_target.global_position, 18.0 + chain_level * 4.0, Color(0.92, 0.56, 1.0, 0.76), 0.12)
		owner._spawn_burst_effect(chosen_target.global_position, 22.0 + chain_level * 4.0, Color(0.72, 0.38, 1.0, 0.2), 0.12)
		var chain_kill: bool = owner._deal_damage_to_enemy(chosen_target, owner._get_role_damage(role_id) * chain_damage_ratio, role_id, 0.02 * chain_level, 1.8, 1.0, 0.0)
		owner._register_attack_result(role_id, 1, chain_kill)
		previous_target = chosen_target
		from_position = chosen_target.global_position
	if chain_level >= 3:
		owner._add_energy(2.0)
	owner.chain_reaction_active = false


static func trigger_clean_tide(owner, role_id: String) -> void:
	var tide_level: int = owner._get_card_level("battle_tide")
	if tide_level <= 0 or owner.clean_tide_active:
		return
	owner.clean_tide_active = true
	var tide_radius: float = [32.0, 40.0, 48.0][tide_level - 1]
	var tide_damage_ratio: float = [0.45, 0.55, 0.65][tide_level - 1]
	var tide_center: Vector2 = owner.global_position + owner.facing_direction * (28.0 + tide_radius * 0.4)
	owner._spawn_ring_effect(tide_center, tide_radius * 1.2, Color(0.3, 0.92, 1.0, 0.76), 6.0, 0.16)
	owner._spawn_burst_effect(tide_center, tide_radius * 1.08, Color(0.18, 0.84, 1.0, 0.2), 0.14)
	var slow_multiplier: float = 1.0
	var slow_duration: float = 0.0
	if tide_level >= 2:
		slow_multiplier = 0.8
		slow_duration = 0.8
	var tide_hits: int = owner._damage_enemies_in_radius(tide_center, tide_radius, owner._get_role_damage(role_id) * tide_damage_ratio, 0.0, slow_multiplier, slow_duration)
	if tide_hits > 0:
		owner._register_attack_result(role_id, tide_hits, false)
	if tide_level >= 3:
		owner._add_energy(6.0)
	owner.clean_tide_active = false


static func spawn_attack_aftershock(owner, center: Vector2, role_id: String) -> void:
	var aftershock_level: int = owner._get_card_level("battle_aftershock")
	if aftershock_level <= 0:
		return
	var level_index: int = clamp(aftershock_level - 1, 0, 2)
	var radius: float = [48.0, 64.0, 80.0][level_index]
	var damage_ratio: float = [0.35, 0.45, 0.55][level_index]
	var pulse_count: int = 2 if aftershock_level == 1 else 3
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		return
	var controller := Node2D.new()
	controller.name = "AttackAftershockController"
	current_scene.add_child(controller)
	var tween := controller.create_tween()
	for pulse_index in range(pulse_count):
		if pulse_index > 0:
			tween.tween_interval(0.12)
		tween.tween_callback(func() -> void:
			var current_radius: float = radius + pulse_index * 14.0
			var current_damage: float = owner._get_role_damage(role_id) * damage_ratio
			var accent: Color = owner._get_role_theme_color(role_id)
			owner._spawn_ring_effect(center, current_radius, Color(min(1.0, accent.r + 0.14), min(1.0, accent.g + 0.14), min(1.0, accent.b + 0.18), 0.88), 8.0, 0.2)
			owner._spawn_burst_effect(center, current_radius * 0.94, Color(accent.r, accent.g, accent.b, 0.26), 0.18)
			match role_id:
				"swordsman":
					var angle_shift: float = pulse_index * 0.18
					owner._spawn_crescent_wave_effect(center, Vector2.RIGHT.rotated(angle_shift), current_radius * 0.96, Color(0.24, 0.94, 1.0, 0.7), 0.2, 220.0, 18.0 + pulse_index * 4.0)
					owner._spawn_crescent_wave_effect(center, Vector2.RIGHT.rotated(PI + angle_shift), current_radius * 0.82, Color(1.0, 0.2, 0.16, 0.48), 0.18, 200.0, 14.0 + pulse_index * 3.0)
				"gunner":
					owner._spawn_radial_rays_effect(center, current_radius * 1.06, 8 + aftershock_level * 2 + pulse_index * 2, Color(1.0, 0.66, 0.34, 0.7), 4.0 + pulse_index, 0.2, pulse_index * 0.14)
				"mage":
					owner._spawn_frost_sigils_effect(center, current_radius * 0.76, Color(0.9, 0.98, 1.0, 0.84), 0.2)
					owner._spawn_vortex_effect(center, current_radius * 0.42, Color(0.72, 0.8, 1.0, 0.34), 0.2)
			var slow_multiplier: float = 1.0
			var slow_duration: float = 0.0
			if aftershock_level >= 2:
				slow_multiplier = 0.75
				slow_duration = 1.0
			var shock_hits: int = owner._damage_enemies_in_radius(center, current_radius, current_damage, 0.0, slow_multiplier, slow_duration)
			if shock_hits > 0:
				owner._register_attack_result(role_id, shock_hits, false)
		)
	tween.tween_callback(controller.queue_free)


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
