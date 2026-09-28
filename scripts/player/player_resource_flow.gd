extends RefCounted

const ROLE_RESOURCE_STATE := preload("res://scripts/player/roles/role_resource_state.gd")
const PLAYER_SWORDSMAN_TRAIT_RUNTIME_FLOW := preload("res://scripts/player/player_swordsman_trait_runtime_flow.gd")

const ULTIMATE_ENERGY_GAIN_OUTPUT_MULTIPLIER := 0.625
const TEMPORARY_HEALTH_DURATION := 30.0


static func get_active_role(owner) -> Dictionary:
	return owner.roles[owner.active_role_index]


static func get_active_role_id(owner) -> String:
	return str(get_active_role(owner).get("id", ""))


static func build_role_resource_state_data(owner, default_value: Variant) -> Dictionary:
	return ROLE_RESOURCE_STATE.build_for_roles(owner.roles, default_value)


static func build_temporary_health_stack_state() -> Array:
	return []


static func normalize_temporary_health_stack_state(value: Variant) -> Array:
	var result: Array = []
	if value is not Array:
		return result
	for stack_value in value:
		if stack_value is not Dictionary:
			continue
		var stack := stack_value as Dictionary
		var amount: float = max(0.0, float(stack.get("amount", 0.0)))
		var remaining: float = max(0.0, float(stack.get("remaining", TEMPORARY_HEALTH_DURATION)))
		if amount <= 0.0 or remaining <= 0.0:
			continue
		result.append({
			"amount": amount,
			"remaining": remaining
		})
	return result


static func get_role_mana(owner, role_id: String) -> float:
	return ROLE_RESOURCE_STATE.get_mana(owner.role_mana_values, role_id, owner.max_mana)


static func set_role_mana(owner, role_id: String, value: float, emit_for_active: bool = true) -> void:
	ROLE_RESOURCE_STATE.set_mana(owner.role_mana_values, role_id, value, owner.max_mana)
	if role_id == get_active_role_id(owner):
		sync_active_role_ultimate_state(owner)
		if emit_for_active:
			owner.mana_changed.emit(owner.current_mana, owner.max_mana)


static func add_role_mana(owner, role_id: String, amount: float, emit_for_active: bool = true) -> float:
	if amount == 0.0:
		return get_role_mana(owner, role_id)
	if amount > 0.0:
		amount *= ULTIMATE_ENERGY_GAIN_OUTPUT_MULTIPLIER
		if amount <= 0.0:
			return get_role_mana(owner, role_id)
	var updated_value: float = ROLE_RESOURCE_STATE.add_mana(owner.role_mana_values, role_id, amount, owner.max_mana)
	if role_id == get_active_role_id(owner):
		sync_active_role_ultimate_state(owner)
		if emit_for_active:
			owner.mana_changed.emit(owner.current_mana, owner.max_mana)
	return updated_value


static func add_active_role_mana(owner, amount: float, emit_signal: bool = true) -> float:
	return add_role_mana(owner, get_active_role_id(owner), amount, emit_signal)


static func get_role_ultimate_lock_remaining(owner, role_id: String) -> float:
	return ROLE_RESOURCE_STATE.get_lock_remaining(owner.role_ultimate_energy_lock_remaining, role_id)


static func set_role_ultimate_lock_remaining(owner, role_id: String, value: float) -> void:
	ROLE_RESOURCE_STATE.set_lock_remaining(owner.role_ultimate_energy_lock_remaining, role_id, value)
	if role_id == get_active_role_id(owner):
		sync_active_role_ultimate_state(owner)


static func sync_active_role_ultimate_state(owner) -> void:
	var active_role_id: String = get_active_role_id(owner)
	owner.current_mana = get_role_mana(owner, active_role_id)
	owner.ultimate_energy_lock_remaining = get_role_ultimate_lock_remaining(owner, active_role_id)


static func emit_active_mana_changed(owner) -> void:
	sync_active_role_ultimate_state(owner)
	owner.mana_changed.emit(owner.current_mana, owner.max_mana)


static func get_role_special_state(owner, role_id: String) -> Dictionary:
	if not owner.role_special_states.has(role_id):
		owner.role_special_states[role_id] = {}
	return owner.role_special_states[role_id]


static func increase_role_special(owner, role_id: String, key: String, amount: int = 1) -> void:
	var special_data: Dictionary = get_role_special_state(owner, role_id)
	special_data[key] = int(special_data.get(key, 0)) + amount
	owner.role_special_states[role_id] = special_data


static func increase_team_specials(owner, entries: Array) -> void:
	for entry in entries:
		if entry is Dictionary:
			increase_role_special(owner, str(entry.get("role_id", "")), str(entry.get("key", "")), int(entry.get("amount", 1)))


static func add_energy(owner, amount: float) -> void:
	if amount <= 0.0:
		return
	var effective_amount: float = amount * ULTIMATE_ENERGY_GAIN_OUTPUT_MULTIPLIER
	if effective_amount <= 0.0:
		return
	var active_role_id: String = get_active_role_id(owner)
	var total_energy_multiplier: float = owner._get_role_total_ultimate_energy_gain_multiplier(active_role_id) if owner.has_method("_get_role_total_ultimate_energy_gain_multiplier") else 1.0
	var self_amount: float = amount * max(0.01, total_energy_multiplier)
	var updated_mana: float = add_role_mana(owner, active_role_id, self_amount, false)
	if owner._has_elite_relic("elite_reactor") and is_equal_approx(updated_mana, owner.max_mana):
		owner._activate_switch_power(active_role_id, "\u6EE1\u80FD\u53CD\u5E94", 2.8, 1.14, 0.04)
	emit_active_mana_changed(owner)


static func heal(owner, amount: float) -> void:
	if amount <= 0.0 or owner.is_dead:
		return
	if owner.has_method("is_healing_blocked") and owner.is_healing_blocked():
		return
	amount = PLAYER_SWORDSMAN_TRAIT_RUNTIME_FLOW.apply_healing_multiplier(owner, amount)
	amount *= preload("res://scripts/player/player_plague_flow.gd").get_healing_multiplier(owner)
	if amount <= 0.0:
		return
	var previous_health: float = owner.current_health
	owner.current_health = min(owner.max_health, owner.current_health + amount)
	var actual_heal_amount: float = owner.current_health - previous_health
	if actual_heal_amount <= 0.0:
		return
	if owner.has_method("_save_active_role_health"):
		owner._save_active_role_health()
	owner.health_changed.emit(owner.current_health, owner.max_health)
	owner.pending_heal_combat_text += actual_heal_amount
	var displayed_heal: float = floor(owner.pending_heal_combat_text)
	if displayed_heal < 1.0:
		return
	owner.pending_heal_combat_text -= displayed_heal
	if owner.has_method("_spawn_forced_combat_tag"):
		owner._spawn_forced_combat_tag(
			owner.global_position + Vector2(0.0, -56.0),
			_format_heal_combat_text(displayed_heal),
			Color(0.48, 1.0, 0.66, 1.0)
		)
	elif owner.has_method("_spawn_combat_tag"):
		owner._spawn_combat_tag(
			owner.global_position + Vector2(0.0, -56.0),
			_format_heal_combat_text(displayed_heal),
			Color(0.48, 1.0, 0.66, 1.0)
		)


static func add_temporary_health(owner, amount: float, role_id: String = "", duration: float = TEMPORARY_HEALTH_DURATION) -> float:
	if amount <= 0.0 or owner.is_dead:
		return 0.0
	var active_role_id: String = get_active_role_id(owner)
	var signal_role_id: String = role_id if role_id != "" else active_role_id
	if signal_role_id == "":
		return 0.0
	owner.temporary_health_stacks = normalize_temporary_health_stack_state(owner.temporary_health_stacks)
	owner.temporary_health_stacks.append({
		"amount": amount,
		"remaining": max(0.01, duration)
	})
	sync_temporary_health_state(owner, true, signal_role_id)
	if owner.has_method("_update_player_health_bar"):
		owner._update_player_health_bar(owner._get_active_role())
	return amount


static func consume_temporary_health(owner, amount: float) -> float:
	if amount <= 0.0 or owner.current_temporary_health <= 0.0:
		return 0.0
	var remaining_damage: float = amount
	var absorbed_damage: float = 0.0
	var updated_stacks: Array = normalize_temporary_health_stack_state(owner.temporary_health_stacks)
	for index in range(updated_stacks.size()):
		if remaining_damage <= 0.0:
			break
		var stack: Dictionary = updated_stacks[index]
		var stack_amount: float = max(0.0, float(stack.get("amount", 0.0)))
		if stack_amount <= 0.0:
			continue
		var consumed_amount: float = min(stack_amount, remaining_damage)
		stack_amount -= consumed_amount
		remaining_damage -= consumed_amount
		absorbed_damage += consumed_amount
		stack["amount"] = stack_amount
		updated_stacks[index] = stack
	owner.temporary_health_stacks = _filter_live_temporary_health_stacks(updated_stacks)
	if absorbed_damage > 0.0:
		sync_temporary_health_state(owner, true)
	return absorbed_damage


static func tick_temporary_health_stacks(owner, delta: float) -> void:
	if delta <= 0.0:
		return
	var stacks: Array = normalize_temporary_health_stack_state(owner.temporary_health_stacks)
	if stacks.is_empty():
		return
	var updated_stacks: Array = []
	var expired_amount: float = 0.0
	for stack_value in stacks:
		var stack := stack_value as Dictionary
		var amount: float = max(0.0, float(stack.get("amount", 0.0)))
		var remaining: float = max(0.0, float(stack.get("remaining", 0.0)) - delta)
		if amount > 0.0 and remaining > 0.0:
			updated_stacks.append({
				"amount": amount,
				"remaining": remaining
			})
		else:
			expired_amount += amount
	owner.temporary_health_stacks = updated_stacks
	if expired_amount > 0.0:
		sync_temporary_health_state(owner, true)


static func clear_temporary_health(owner, emit_signal: bool = true) -> void:
	owner.temporary_health_stacks = []
	sync_temporary_health_state(owner, emit_signal)


static func set_temporary_health_total(owner, value: float, emit_signal: bool = true, signal_role_id: String = "") -> void:
	var safe_value: float = max(0.0, value)
	if safe_value <= 0.0:
		owner.temporary_health_stacks = []
	else:
		owner.temporary_health_stacks = [{
			"amount": safe_value,
			"remaining": TEMPORARY_HEALTH_DURATION
		}]
	sync_temporary_health_state(owner, emit_signal, signal_role_id)


static func sync_temporary_health_state(owner, emit_signal: bool = true, signal_role_id: String = "") -> void:
	if owner == null:
		return
	owner.temporary_health_stacks = normalize_temporary_health_stack_state(owner.temporary_health_stacks)
	var previous_value: float = max(0.0, float(owner.current_temporary_health))
	var total_value: float = _get_temporary_health_total(owner.temporary_health_stacks)
	owner.current_temporary_health = total_value
	_sync_shared_role_temporary_health_values(owner, total_value)
	if not emit_signal:
		return
	var role_id: String = signal_role_id if signal_role_id != "" else get_active_role_id(owner)
	if owner.has_signal("temporary_health_changed"):
		owner.temporary_health_changed.emit(role_id, owner.current_temporary_health)
	if not is_equal_approx(previous_value, total_value) and owner.has_signal("health_changed"):
		owner.health_changed.emit(owner.current_health, owner.max_health)


static func _get_temporary_health_total(stacks: Array) -> float:
	var total_value: float = 0.0
	for stack_value in stacks:
		if stack_value is not Dictionary:
			continue
		total_value += max(0.0, float((stack_value as Dictionary).get("amount", 0.0)))
	return total_value


static func _filter_live_temporary_health_stacks(stacks: Array) -> Array:
	var result: Array = []
	for stack_value in stacks:
		if stack_value is not Dictionary:
			continue
		var stack := stack_value as Dictionary
		var amount: float = max(0.0, float(stack.get("amount", 0.0)))
		var remaining: float = max(0.0, float(stack.get("remaining", 0.0)))
		if amount <= 0.0 or remaining <= 0.0:
			continue
		result.append({
			"amount": amount,
			"remaining": remaining
		})
	return result


static func _sync_shared_role_temporary_health_values(owner, total_value: float) -> void:
	var values: Dictionary = {}
	for role_data in owner.roles:
		if role_data is not Dictionary:
			continue
		var role_id: String = str((role_data as Dictionary).get("id", ""))
		if role_id == "":
			continue
		values[role_id] = total_value
	owner.role_temporary_health_values = values


static func _format_heal_combat_text(amount: float) -> String:
	if is_equal_approx(amount, roundf(amount)):
		return "+%d" % int(roundf(amount))
	return "+%.1f" % amount


static func die(owner) -> void:
	if owner.is_dead and not owner.death_sequence_pending:
		return

	owner.death_sequence_pending = false
	owner.death_sequence_remaining = 0.0
	if owner.has_method("_clear_temporary_health"):
		owner._clear_temporary_health(false)
	else:
		owner.current_temporary_health = 0.0
	owner.current_health = 0.0
	if owner.has_method("_save_active_role_health"):
		owner._save_active_role_health()
	owner.health_changed.emit(owner.current_health, owner.max_health)
	if owner.has_method("_update_player_health_bar"):
		owner._update_player_health_bar(owner._get_active_role())

	owner.is_dead = true
	owner.level_up_active = false
	if owner.fire_timer != null:
		owner.fire_timer.stop()
	owner.died.emit()
