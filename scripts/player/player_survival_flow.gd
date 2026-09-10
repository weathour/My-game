extends RefCounted

const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const PLAYER_LEVEL_CURVE := preload("res://scripts/player/player_level_curve.gd")
const PLAYER_LEVEL_FLOW := preload("res://scripts/player/player_level_flow.gd")
const PLAYER_TARGETING := preload("res://scripts/player/player_targeting.gd")
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const PLAYER_GUNNER_FLASH_TALENT_FLOW := preload("res://scripts/player/player_gunner_flash_talent_flow.gd")
const PLAYER_ABILITY_FLOW := preload("res://scripts/player/player_ability_flow.gd")

const EXPERIENCE_GAIN_MULTIPLIER := 2.43
const EXPERIENCE_FRACTION_CARRY_KEY := "__experience_fraction_carry"
const PICKUP_SCAN_CURSOR_KEY := "__pickup_scan_cursor"
const HEART_SCAN_CURSOR_KEY := "__heart_scan_cursor"
const PICKUP_SCAN_BATCH_SIZE := 80
const HEART_SCAN_BATCH_SIZE := 28
const SWORDSMAN_DEATH_DEFIANCE_COOLDOWN := 80.0
const SWORDSMAN_DEATH_DEFIANCE_INVULNERABILITY := 1.5
const DEATH_HEALTH_BAR_ANIMATION_DELAY := 0.95

static func unhandled_input(owner, event: InputEvent) -> void:
	if owner.is_dead or owner.get_tree().paused:
		return
	if event is not InputEventKey:
		return
	if not event.pressed or event.echo:
		return

	var manual_skill_slot := _get_manual_skill_slot_index(event)
	if manual_skill_slot > 0 and owner.has_method("_try_handle_manual_skill_slot") and owner._try_handle_manual_skill_slot(manual_skill_slot):
		owner.get_viewport().set_input_as_handled()
		return

	if GAME_SETTINGS.event_matches_action(event, GAME_SETTINGS.ACTION_SWITCH_PREV):
		owner._try_switch_role((owner.active_role_index - 1 + owner.roles.size()) % owner.roles.size())
	elif GAME_SETTINGS.event_matches_action(event, GAME_SETTINGS.ACTION_SWITCH_NEXT):
		owner._try_switch_role((owner.active_role_index + 1) % owner.roles.size())
	elif GAME_SETTINGS.event_matches_action(event, GAME_SETTINGS.ACTION_ULTIMATE):
		owner._try_use_ultimate()
	elif GAME_SETTINGS.event_matches_action(event, GAME_SETTINGS.ACTION_TOGGLE_ATTACK_MODE):
		owner._toggle_attack_aim_mode()
	elif GAME_SETTINGS.event_matches_action(event, GAME_SETTINGS.ACTION_TOGGLE_HURT_CORE):
		owner._toggle_hurt_core_visual()


static func _get_manual_skill_slot_index(event: InputEventKey) -> int:
	match event.keycode:
		KEY_1:
			return 1
		KEY_2:
			return 2
		KEY_3:
			return 3
		KEY_4:
			return 4
		KEY_5:
			return 5
		KEY_6:
			return 6
	return 0


static func toggle_attack_aim_mode(owner) -> void:
	owner.auto_attack_enabled = not owner.auto_attack_enabled
	var mode_text := "\u81ea\u52a8\u653b\u51fb" if owner.auto_attack_enabled else "\u9f20\u6807\u8ddf\u968f"
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -48.0), mode_text, Color(0.72, 0.96, 1.0, 1.0))
	owner.stats_changed.emit(owner.get_stat_summary())


static func physics_process(owner, delta: float) -> void:
	if owner.is_dead:
		owner.velocity = Vector2.ZERO
		owner.move_and_slide()
		if owner.has_method("_update_player_health_bar"):
			owner._update_player_health_bar(owner._get_active_role())
		_tick_death_sequence(owner, delta)
		return

	owner._update_timers(delta)
	_tick_swordsman_talent_states(owner, delta)
	_update_area_control_states(owner, delta)
	owner._regenerate_energy(delta)
	owner._apply_equipment_passives(delta)
	apply_attribute_passives(owner, delta)
	owner._update_facing_direction()
	owner._update_role_idle_visual(delta)
	owner._update_player_health_bar(owner._get_active_role())
	owner._update_background_effects(delta)

	if is_movement_locked(owner):
		owner.velocity = Vector2.ZERO
		owner.move_and_slide()
		owner.gem_collection_elapsed += delta
		if owner.gem_collection_elapsed >= owner.GEM_COLLECTION_INTERVAL:
			owner.gem_collection_elapsed = 0.0
			owner._collect_nearby_gems()
		owner.contact_check_elapsed += delta
		if owner.contact_check_elapsed >= owner.CONTACT_CHECK_INTERVAL:
			owner.contact_check_elapsed = 0.0
			owner._check_enemy_contact_damage()
		return

	var direction := Vector2.ZERO
	if GAME_SETTINGS.is_action_pressed(GAME_SETTINGS.ACTION_MOVE_LEFT):
		direction.x -= 1.0
	if GAME_SETTINGS.is_action_pressed(GAME_SETTINGS.ACTION_MOVE_RIGHT):
		direction.x += 1.0
	if GAME_SETTINGS.is_action_pressed(GAME_SETTINGS.ACTION_MOVE_UP):
		direction.y -= 1.0
	if GAME_SETTINGS.is_action_pressed(GAME_SETTINGS.ACTION_MOVE_DOWN):
		direction.y += 1.0

	direction = direction.normalized()
	_update_moving_visual_facing(owner, direction)
	owner.velocity = direction * owner._get_current_move_speed() * _get_swordsman_talent_move_multiplier(owner)
	owner.move_and_slide()
	owner.gem_collection_elapsed += delta
	if owner.gem_collection_elapsed >= owner.GEM_COLLECTION_INTERVAL:
		owner.gem_collection_elapsed = 0.0
		owner._collect_nearby_gems()
	owner.contact_check_elapsed += delta
	if owner.contact_check_elapsed >= owner.CONTACT_CHECK_INTERVAL:
		owner.contact_check_elapsed = 0.0
		owner._check_enemy_contact_damage()


static func is_movement_locked(owner) -> bool:
	if owner == null:
		return false
	if owner.has_method("_is_player_action_locked") and owner._is_player_action_locked():
		return true
	return PLAYER_ABILITY_FLOW.is_gunner_infinite_reload_movement_locked(owner)


static func regenerate_energy(owner, delta: float) -> void:
	if owner.ENERGY_PASSIVE_REGEN <= 0.0:
		return
	owner._add_energy(owner.ENERGY_PASSIVE_REGEN * delta)


static func _update_area_control_states(owner, delta: float) -> void:
	owner.healing_block_remaining = max(0.0, float(owner.healing_block_remaining) - delta)
	owner.aging_remaining = max(0.0, float(owner.aging_remaining) - delta)
	if owner.aging_remaining <= 0.0:
		owner.aging_damage_carry = 0.0
	owner.confinement_remaining = max(0.0, float(owner.confinement_remaining) - delta)
	if owner.confinement_remaining <= 0.0:
		owner.confinement_radius = 0.0
		owner.confinement_polygon = PackedVector2Array()


static func _apply_aging_damage(owner, delta: float) -> void:
	if delta <= 0.0 or owner.is_dead:
		return
	var raw_damage: float = max(1.0, float(owner.max_health)) * 0.06 * delta
	owner.aging_damage_carry += raw_damage
	var stamina_loss_to_apply: float = floor(owner.aging_damage_carry)
	if stamina_loss_to_apply < 1.0:
		return
	owner.aging_damage_carry -= stamina_loss_to_apply
	var previous_health: float = float(owner.current_health)
	# Aging is stamina drain: it reduces health without counting as taking damage.
	owner.current_health = max(1.0, previous_health - stamina_loss_to_apply)
	if owner.has_method("_save_active_role_health"):
		owner._save_active_role_health()
	if owner.current_health != previous_health:
		owner.health_changed.emit(owner.current_health, owner.max_health)
		owner._update_player_health_bar(owner._get_active_role())


static func apply_attribute_passives(owner, delta: float) -> void:
	if delta <= 0.0:
		return
	var health_regen: float = owner._get_attribute_health_regen_per_second() if owner.has_method("_get_attribute_health_regen_per_second") else 0.0
	if health_regen > 0.0:
		owner._heal(health_regen * delta)
	var mana_regen: float = owner._get_attribute_mana_regen_per_second() if owner.has_method("_get_attribute_mana_regen_per_second") else 0.0
	if mana_regen > 0.0:
		owner._add_active_role_mana(mana_regen * delta, true)


static func apply_mage_surplus_passive_energy(owner, delta: float) -> void:
	apply_attribute_passives(owner, delta)


static func update_facing_direction(owner) -> void:
	if owner.auto_attack_enabled:
		var target_enemy: Node2D = owner._get_closest_enemy()
		if target_enemy != null and is_instance_valid(target_enemy):
			var aim_point: Vector2 = PLAYER_TARGETING.get_enemy_aim_point(target_enemy, owner.global_position)
			var to_enemy: Vector2 = aim_point - owner.global_position
			if to_enemy.length_squared() > 0.001:
				owner.facing_direction = to_enemy.normalized()
				_sync_visual_facing_to_direction(owner, owner.facing_direction)
		return

	var mouse_direction: Vector2 = owner.get_global_mouse_position() - owner.global_position
	if mouse_direction.length_squared() > 16.0:
		owner.facing_direction = mouse_direction.normalized()
		_sync_visual_facing_to_direction(owner, owner.facing_direction)
		return

	var enemy: Node2D = owner._get_closest_enemy()
	if enemy != null:
		var aim_point: Vector2 = PLAYER_TARGETING.get_enemy_aim_point(enemy, owner.global_position)
		owner.facing_direction = owner.global_position.direction_to(aim_point)
		_sync_visual_facing_to_direction(owner, owner.facing_direction)


static func _update_moving_visual_facing(owner, move_direction: Vector2) -> void:
	if move_direction.length_squared() <= 0.001:
		return
	var aim_direction: Vector2 = get_attack_aim_direction(owner, owner.facing_direction)
	if abs(aim_direction.x) > 0.01:
		owner.visual_facing_direction_x = sign(aim_direction.x)
	elif abs(move_direction.x) > 0.01:
		owner.visual_facing_direction_x = sign(move_direction.x)


static func _sync_visual_facing_to_direction(owner, direction: Vector2) -> void:
	if abs(direction.x) > 0.01:
		owner.visual_facing_direction_x = sign(direction.x)


static func get_attack_aim_direction(owner, fallback_direction: Vector2 = Vector2.RIGHT) -> Vector2:
	if owner.auto_attack_enabled:
		var target_enemy: Node2D = owner._get_closest_enemy()
		if target_enemy != null and is_instance_valid(target_enemy):
			var aim_point: Vector2 = PLAYER_TARGETING.get_enemy_aim_point(target_enemy, owner.global_position)
			var target_direction: Vector2 = owner.global_position.direction_to(aim_point)
			if target_direction.length_squared() > 0.001:
				owner.facing_direction = target_direction
				return target_direction
		if owner.facing_direction.length_squared() > 0.001:
			return owner.facing_direction.normalized()
		if fallback_direction.length_squared() > 0.001:
			return fallback_direction.normalized()
		return Vector2.RIGHT

	var mouse_direction: Vector2 = owner.get_global_mouse_position() - owner.global_position
	if mouse_direction.length_squared() > 4.0:
		owner.facing_direction = mouse_direction.normalized()
		return owner.facing_direction
	if owner.facing_direction.length_squared() > 0.001:
		return owner.facing_direction.normalized()
	if fallback_direction.length_squared() > 0.001:
		return fallback_direction.normalized()
	return Vector2.RIGHT


static func collect_nearby_gems(owner) -> void:
	var attract_center: Vector2 = owner.get_hurtbox_center()
	var attract_radius: float = max(owner.GEM_ATTRACT_RADIUS, owner.get_hurtbox_radius() * 3.6)
	var attract_radius_squared: float = attract_radius * attract_radius
	var absorb_radius: float = owner.GEM_ABSORB_RADIUS
	var absorb_radius_squared: float = absorb_radius * absorb_radius
	var effective_pickup_radius: float = owner.pickup_radius
	if owner.has_method("_get_attribute_pickup_range_bonus"):
		effective_pickup_radius += float(owner._get_attribute_pickup_range_bonus())
	var pickup_radius_squared: float = effective_pickup_radius * effective_pickup_radius
	var gems: Array = _get_runtime_pickups_near(owner, "exp_gems", attract_center, max(attract_radius, absorb_radius))
	var gem_count: int = gems.size()
	var gem_cursor := int(owner.get_meta(PICKUP_SCAN_CURSOR_KEY, 0)) if owner.has_meta(PICKUP_SCAN_CURSOR_KEY) else 0
	var gem_scan_count: int = min(gem_count, PICKUP_SCAN_BATCH_SIZE)
	for offset in range(gem_scan_count):
		var gem: Node = gems[(gem_cursor + offset) % max(1, gem_count)]
		if not is_instance_valid(gem):
			continue
		var gem_distance_squared: float = attract_center.distance_squared_to(gem.global_position)
		if gem_distance_squared <= attract_radius_squared and gem.has_method("set_attraction_target"):
			gem.set_attraction_target(owner)
		if gem_distance_squared <= absorb_radius_squared:
			if gem.has_method("collect"):
				var gained_experience: int = gem.collect()
				owner.gain_experience(gained_experience)
	if gem_count > 0:
		owner.set_meta(PICKUP_SCAN_CURSOR_KEY, (gem_cursor + gem_scan_count) % gem_count)

	var hearts: Array = _get_runtime_pickups_near(owner, "heart_pickups", attract_center, effective_pickup_radius)
	var heart_count: int = hearts.size()
	var heart_cursor := int(owner.get_meta(HEART_SCAN_CURSOR_KEY, 0)) if owner.has_meta(HEART_SCAN_CURSOR_KEY) else 0
	var heart_scan_count: int = min(heart_count, HEART_SCAN_BATCH_SIZE)
	for offset in range(heart_scan_count):
		var heart_pickup: Node = hearts[(heart_cursor + offset) % max(1, heart_count)]
		if not is_instance_valid(heart_pickup):
			continue
		if attract_center.distance_squared_to(heart_pickup.global_position) <= pickup_radius_squared:
			if heart_pickup.has_method("collect"):
				var healed_amount: float = heart_pickup.collect()
				owner._heal(healed_amount)
	if heart_count > 0:
		owner.set_meta(HEART_SCAN_CURSOR_KEY, (heart_cursor + heart_scan_count) % heart_count)

	var bones: Array = _get_runtime_pickups_near(owner, "bone_pickups", attract_center, max(attract_radius, absorb_radius))
	for bone_pickup in bones:
		if not is_instance_valid(bone_pickup):
			continue
		var bone_distance_squared: float = attract_center.distance_squared_to(bone_pickup.global_position)
		if bone_distance_squared <= attract_radius_squared and bone_pickup.has_method("set_attraction_target"):
			bone_pickup.set_attraction_target(owner)
		if bone_distance_squared <= absorb_radius_squared and bone_pickup.has_method("collect"):
			_collect_bones(owner, int(bone_pickup.collect()))


static func _collect_bones(owner, amount: int) -> void:
	if amount <= 0:
		return
	if owner == null or not owner.has_method("collect_ruan_bones"):
		push_error("Player survival flow requires collect_ruan_bones().")
		return
	owner.collect_ruan_bones(amount)

static func _get_runtime_pickups(owner, group_name: String) -> Array:
	if owner != null and owner.get_tree() != null:
		var scene: Node = owner.get_tree().current_scene
		if scene != null and scene.has_method("get_runtime_pickups"):
			return scene.get_runtime_pickups(group_name)
	return owner.get_tree().get_nodes_in_group(group_name)

static func _get_runtime_pickups_near(owner, group_name: String, center: Vector2, radius: float) -> Array:
	if owner != null and owner.get_tree() != null:
		var scene: Node = owner.get_tree().current_scene
		if scene != null and scene.has_method("get_runtime_pickups_in_radius"):
			return scene.get_runtime_pickups_in_radius(group_name, center, radius)
	return _get_runtime_pickups(owner, group_name)


static func check_enemy_contact_damage(owner) -> void:
	if owner.hurt_cooldown_remaining > 0.0 or owner.switch_invulnerability_remaining > 0.0:
		return

	var hurtbox_center: Vector2 = owner.get_hurtbox_center()
	var hurtbox_radius: float = owner.get_hurtbox_radius()
	var touch_damage: float = owner._get_touching_enemy_damage(hurtbox_center, hurtbox_radius, 36.0)
	if touch_damage > 0.0:
		owner.take_damage(touch_damage)


static func gain_experience(owner, amount: int) -> void:
	var adjusted_amount := _get_adjusted_experience_gain(owner, amount)
	if adjusted_amount <= 0:
		return
	owner.experience += adjusted_amount

	if owner.experience_to_next_level <= 0:
		owner.experience_to_next_level = PLAYER_LEVEL_CURVE.get_required_experience_for_level(owner.level)

	var level_up_guard := 0
	while owner.experience >= owner.experience_to_next_level and level_up_guard < 100:
		owner.experience -= owner.experience_to_next_level
		owner.level += 1
		owner.experience_to_next_level = PLAYER_LEVEL_CURVE.get_next_required_experience_after_level_up(owner.level)
		PLAYER_LEVEL_FLOW.handle_reached_level(owner, owner.level)
		level_up_guard += 1
	if level_up_guard >= 100:
		owner.experience = min(owner.experience, max(0, owner.experience_to_next_level - 1))

	owner.experience_changed.emit(owner.experience, owner.experience_to_next_level, owner.level)
	owner._try_request_level_up()


static func _get_adjusted_experience_gain(owner, amount: int) -> int:
	if amount <= 0:
		return 0
	var difficulty_multiplier: float = _get_difficulty_experience_multiplier(owner)
	var raw_gain := float(amount) * EXPERIENCE_GAIN_MULTIPLIER * difficulty_multiplier
	var carry := 0.0
	if owner != null and owner.has_meta(EXPERIENCE_FRACTION_CARRY_KEY):
		carry = float(owner.get_meta(EXPERIENCE_FRACTION_CARRY_KEY))
	raw_gain += carry
	var whole_gain := int(floor(raw_gain))
	var next_carry := raw_gain - float(whole_gain)
	if owner != null:
		owner.set_meta(EXPERIENCE_FRACTION_CARRY_KEY, next_carry)
	return whole_gain


static func _get_difficulty_experience_multiplier(owner) -> float:
	if owner == null or not owner.has_method("get_tree"):
		return 1.0
	var tree: SceneTree = owner.get_tree()
	if tree == null:
		return 1.0
	var main_scene: Node = tree.current_scene
	if main_scene == null or not main_scene.has_method("_get_difficulty_experience_multiplier"):
		return 1.0
	return max(0.0, float(main_scene._get_difficulty_experience_multiplier()))


static func grant_developer_level_up(owner) -> void:
	owner.level += 1
	owner.experience_to_next_level = PLAYER_LEVEL_CURVE.get_next_required_experience_after_level_up(owner.level)
	PLAYER_LEVEL_FLOW.handle_reached_level(owner, owner.level)
	owner.experience_changed.emit(owner.experience, owner.experience_to_next_level, owner.level)
	owner._try_request_level_up()


static func take_damage(owner, amount: float) -> void:
	if DEVELOPER_MODE.should_ignore_damage():
		return
	if owner.is_dead or owner.switch_invulnerability_remaining > 0.0:
		return

	if owner._try_equipment_dodge():
		PLAYER_GUNNER_FLASH_TALENT_FLOW.on_successful_dodge(owner)
		owner.hurt_cooldown_remaining = owner.hurt_cooldown * 0.55
		_show_dodge_tag(owner)
		return

	if PLAYER_GUNNER_FLASH_TALENT_FLOW.try_immunize_damage(owner):
		owner.hurt_cooldown_remaining = owner.hurt_cooldown * 0.55
		_show_gunner_flash_immunity_tag(owner)
		return

	if _try_mechanic_guard_bot_block(owner):
		owner.hurt_cooldown_remaining = owner.hurt_cooldown * 0.55
		return

	if owner._get_active_role()["id"] == "swordsman":
		var nearby_enemy_count: int = owner._count_enemies_in_radius(owner.get_hurtbox_center(), 62.0)
		if nearby_enemy_count > 0:
			amount *= max(0.84, 0.96 - min(nearby_enemy_count, 3) * 0.04)

	var adjusted_damage: float = amount * owner._get_effective_damage_taken_multiplier() * _get_swordsman_talent_damage_taken_multiplier(owner)
	var remaining_damage: float = adjusted_damage
	if adjusted_damage > 0.0 and owner.current_temporary_health > 0.0:
		var absorbed_damage: float = owner._consume_temporary_health(adjusted_damage) if owner.has_method("_consume_temporary_health") else min(owner.current_temporary_health, adjusted_damage)
		if not owner.has_method("_consume_temporary_health"):
			owner.current_temporary_health = max(0.0, owner.current_temporary_health - absorbed_damage)
		remaining_damage = max(0.0, remaining_damage - absorbed_damage)
		if not owner.has_method("_consume_temporary_health") and owner.has_method("_save_active_role_temporary_health"):
			owner._save_active_role_temporary_health()
	owner.current_health = max(0.0, owner.current_health - remaining_damage)
	if adjusted_damage > 0.0 and owner.get("gunner_role") != null and owner.gunner_role.has_method("handle_damage_taken"):
		owner.gunner_role.handle_damage_taken(owner)
	if adjusted_damage > 0.0 and owner.has_method("_break_gunner_flash_trait"):
		owner._break_gunner_flash_trait()
	if owner.current_health <= 0.0 and _try_trigger_swordsman_last_guard(owner):
		return
	if owner.current_health <= 0.0 and _try_trigger_swordsman_death_defiance(owner):
		return
	if owner.has_method("_save_active_role_health"):
		owner._save_active_role_health()
	owner.hurt_cooldown_remaining = owner.hurt_cooldown
	owner.health_changed.emit(owner.current_health, owner.max_health)
	owner._play_player_hurt_feedback()

	if owner.current_health <= 0.0:
		_start_death_sequence(owner)


static func _try_mechanic_guard_bot_block(owner) -> bool:
	var ability = owner.get("mechanic_drone_ability") if owner != null else null
	if ability == null or not ability.has_method("try_block_damage"):
		return false
	return bool(ability.try_block_damage(owner))


static func _start_death_sequence(owner) -> void:
	if owner.death_sequence_pending:
		return
	owner.death_sequence_pending = true
	owner.death_sequence_remaining = DEATH_HEALTH_BAR_ANIMATION_DELAY
	owner.is_dead = true
	owner.level_up_active = false
	owner.velocity = Vector2.ZERO
	_clear_swordsman_talent_states(owner)
	if owner.fire_timer != null:
		owner.fire_timer.stop()
	if owner.has_method("_update_player_health_bar"):
		owner._update_player_health_bar(owner._get_active_role())


static func _tick_death_sequence(owner, delta: float) -> void:
	if not owner.death_sequence_pending:
		return
	owner.death_sequence_remaining = max(0.0, owner.death_sequence_remaining - max(delta, 0.0))
	if owner.death_sequence_remaining <= 0.0:
		owner._die()


static func _try_trigger_swordsman_death_defiance(owner) -> bool:
	if str(owner._get_active_role().get("id", "")) != "swordsman":
		return false
	if owner.swordsman_death_defiance_cooldown_remaining > 0.0:
		return false
	if owner.swordsman_death_defiance_will_remaining > 0.0:
		return false
	owner.current_health = 1.0
	if owner.has_method("_save_active_role_health"):
		owner._save_active_role_health()
	var invulnerability_duration: float = SWORDSMAN_DEATH_DEFIANCE_INVULNERABILITY + PLAYER_BUILD_SYSTEM.get_swordsman_knight_glory_duration_bonus(owner)
	owner.swordsman_death_defiance_will_remaining = invulnerability_duration
	owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, invulnerability_duration)
	owner.hurt_cooldown_remaining = owner.hurt_cooldown
	owner.health_changed.emit(owner.current_health, owner.max_health)
	if owner.has_method("_sync_invulnerability_status"):
		owner._sync_invulnerability_status()
	if owner.has_method("_spawn_forced_combat_tag"):
		owner._spawn_forced_combat_tag(owner.global_position + Vector2(0.0, -42.0), "骑士荣耀", Color(1.0, 0.72, 0.32, 1.0))
	else:
		owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -42.0), "骑士荣耀", Color(1.0, 0.72, 0.32, 1.0))
	owner._play_player_hurt_feedback()
	return true


static func _try_trigger_swordsman_last_guard(owner) -> bool:
	var active_role_id: String = str(owner._get_active_role().get("id", ""))
	if active_role_id == "" or active_role_id == "swordsman":
		return false
	if not owner.has_method("_has_skill_talent") or not owner._has_skill_talent("swordsman_trait_last_guard"):
		return false
	if owner.swordsman_death_defiance_cooldown_remaining > 0.0 or owner.swordsman_death_defiance_will_remaining > 0.0:
		return false
	if not owner.has_method("_has_full_switch_energy") or not owner._has_full_switch_energy(active_role_id):
		return false
	var swordsman_index: int = -1
	for index in range(owner.roles.size()):
		if str(owner.roles[index].get("id", "")) == "swordsman":
			swordsman_index = index
			break
	if swordsman_index < 0 or owner._get_role_current_health("swordsman") <= 0.0:
		return false

	var rescue_health_ratio: float = min(1.0, 0.30 + PLAYER_BUILD_SYSTEM.get_swordsman_trait_heal_bonus(owner))
	owner.current_health = owner._get_role_max_health(active_role_id) * rescue_health_ratio
	owner._save_active_role_health()
	owner._set_role_switch_energy(active_role_id, 0.0)
	owner.swordsman_death_defiance_cooldown_remaining = owner.SWORDSMAN_DEATH_DEFIANCE_COOLDOWN
	owner.swordsman_death_defiance_will_remaining = 0.0
	owner._try_switch_role(swordsman_index, true, true)
	owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, SWORDSMAN_DEATH_DEFIANCE_INVULNERABILITY + PLAYER_BUILD_SYSTEM.get_swordsman_knight_glory_duration_bonus(owner))
	if owner.has_method("_spawn_forced_combat_tag"):
		owner._spawn_forced_combat_tag(owner.global_position + Vector2(0.0, -42.0), "最后的换防", Color(1.0, 0.72, 0.32, 1.0))
	owner._play_player_hurt_feedback()
	return true


static func _show_dodge_tag(owner) -> void:
	var tag_position: Vector2 = owner.global_position + Vector2(0.0, -34.0)
	var tag_color: Color = Color(0.38, 1.0, 0.48, 1.0)
	if owner.has_method("_spawn_forced_combat_tag"):
		owner._spawn_forced_combat_tag(tag_position, "闪避", tag_color)
	else:
		owner._spawn_combat_tag(tag_position, "闪避", tag_color)


static func _show_gunner_flash_immunity_tag(owner) -> void:
	var tag_position: Vector2 = owner.global_position + Vector2(0.0, -34.0)
	var tag_color: Color = Color(0.28, 0.84, 1.0, 1.0)
	if owner.has_method("_spawn_forced_combat_tag"):
		owner._spawn_forced_combat_tag(tag_position, "瞬杀", tag_color)
	else:
		owner._spawn_combat_tag(tag_position, "瞬杀", tag_color)


static func apply_enemy_slow(owner, multiplier: float, duration: float) -> void:
	if owner.has_method("_is_status_immune") and owner._is_status_immune():
		return
	owner.enemy_move_slow_multiplier = min(owner.enemy_move_slow_multiplier, clamp(multiplier, 0.15, 1.0))
	owner.enemy_move_slow_remaining = max(owner.enemy_move_slow_remaining, duration)


static func _tick_swordsman_talent_states(owner, delta: float) -> void:
	if owner == null or owner.get("role_special_states") is not Dictionary:
		return
	var state: Dictionary = owner.role_special_states.get("swordsman", {})
	for key in [
		"blood_surge_remaining",
		"guard_stance_remaining",
		"head_high_remaining",
		"unyielding_remaining",
		"unyielding_cooldown_remaining",
		"entry_move_speed_remaining",
		"returning_gale_remaining",
		"ultimate_triumph_remaining",
		"basic_cooldown_cut_lock_remaining"
	]:
		state[key] = max(0.0, float(state.get(key, 0.0)) - delta)
	owner.role_special_states["swordsman"] = state


static func _get_swordsman_talent_move_multiplier(owner) -> float:
	if owner == null or str(owner._get_active_role().get("id", "")) != "swordsman":
		return 1.0
	var state: Dictionary = owner.role_special_states.get("swordsman", {})
	var bonus := 0.0
	if float(state.get("head_high_remaining", 0.0)) > 0.0:
		bonus += 0.25
	if float(state.get("entry_move_speed_remaining", 0.0)) > 0.0:
		bonus += 0.25
	if float(state.get("ultimate_triumph_remaining", 0.0)) > 0.0:
		bonus += 0.20
	return 1.0 + min(0.50, bonus)


static func _get_swordsman_talent_damage_taken_multiplier(owner) -> float:
	if owner == null:
		return 1.0
	var state: Dictionary = owner.role_special_states.get("swordsman", {})
	var reduction := 0.0
	if str(owner._get_active_role().get("id", "")) == "swordsman":
		if float(state.get("guard_stance_remaining", 0.0)) > 0.0:
			reduction = max(reduction, 0.15)
		if float(state.get("unyielding_remaining", 0.0)) > 0.0:
			reduction = max(reduction, 0.40)
		if float(state.get("ultimate_triumph_remaining", 0.0)) > 0.0:
			reduction = max(reduction, 0.30)
	if (
		float(state.get("returning_gale_remaining", 0.0)) > 0.0
		and str(state.get("returning_gale_role_id", "")) == str(owner._get_active_role().get("id", ""))
	):
		reduction = max(reduction, 0.30)
	return 1.0 - reduction


static func _clear_swordsman_talent_states(owner) -> void:
	if owner == null or owner.get("role_special_states") is not Dictionary:
		return
	var state: Dictionary = owner.role_special_states.get("swordsman", {})
	for key in [
		"blood_surge_remaining",
		"guard_stance_remaining",
		"head_high_remaining",
		"unyielding_remaining",
		"entry_move_speed_remaining",
		"returning_gale_remaining",
		"ultimate_triumph_remaining"
	]:
		state[key] = 0.0
	owner.role_special_states["swordsman"] = state
