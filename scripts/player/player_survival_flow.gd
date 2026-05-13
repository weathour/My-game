extends RefCounted

const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const PLAYER_LEVEL_CURVE := preload("res://scripts/player/player_level_curve.gd")

const EXPERIENCE_GAIN_MULTIPLIER := 0.45
const EXPERIENCE_FRACTION_CARRY_KEY := "__experience_fraction_carry"
const PICKUP_SCAN_CURSOR_KEY := "__pickup_scan_cursor"
const HEART_SCAN_CURSOR_KEY := "__heart_scan_cursor"
const PICKUP_SCAN_BATCH_SIZE := 80
const HEART_SCAN_BATCH_SIZE := 28

static func unhandled_input(owner, event: InputEvent) -> void:
	if owner.is_dead or owner.get_tree().paused:
		return
	if event is not InputEventKey:
		return
	if not event.pressed or event.echo:
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


static func physics_process(owner, delta: float) -> void:
	if owner.is_dead:
		owner.velocity = Vector2.ZERO
		owner.move_and_slide()
		return

	owner._update_timers(delta)
	owner._regenerate_energy(delta)
	owner._apply_equipment_passives(delta)
	apply_attribute_passives(owner, delta)
	owner._update_facing_direction()
	owner._update_role_idle_visual(delta)
	owner._update_player_health_bar(owner._get_active_role())
	owner._update_background_effects(delta)

	var direction := Vector2.ZERO
	if GAME_SETTINGS.is_action_pressed(GAME_SETTINGS.ACTION_MOVE_LEFT):
		direction.x -= 1.0
	if GAME_SETTINGS.is_action_pressed(GAME_SETTINGS.ACTION_MOVE_RIGHT):
		direction.x += 1.0
	if abs(direction.x) > 0.01:
		owner.visual_facing_direction_x = sign(direction.x)
	if GAME_SETTINGS.is_action_pressed(GAME_SETTINGS.ACTION_MOVE_UP):
		direction.y -= 1.0
	if GAME_SETTINGS.is_action_pressed(GAME_SETTINGS.ACTION_MOVE_DOWN):
		direction.y += 1.0

	direction = direction.normalized()
	owner.velocity = direction * owner._get_current_move_speed()
	owner.move_and_slide()
	owner.gem_collection_elapsed += delta
	if owner.gem_collection_elapsed >= owner.GEM_COLLECTION_INTERVAL:
		owner.gem_collection_elapsed = 0.0
		owner._collect_nearby_gems()
	owner.contact_check_elapsed += delta
	if owner.contact_check_elapsed >= owner.CONTACT_CHECK_INTERVAL:
		owner.contact_check_elapsed = 0.0
		owner._check_enemy_contact_damage()


static func regenerate_energy(owner, delta: float) -> void:
	if owner.ENERGY_PASSIVE_REGEN <= 0.0:
		return
	owner._add_energy(owner.ENERGY_PASSIVE_REGEN * owner.energy_gain_multiplier * delta)


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
			var to_enemy: Vector2 = target_enemy.global_position - owner.global_position
			if to_enemy.length_squared() > 0.001:
				owner.facing_direction = to_enemy.normalized()
		return

	var mouse_direction: Vector2 = owner.get_global_mouse_position() - owner.global_position
	if mouse_direction.length_squared() > 16.0:
		owner.facing_direction = mouse_direction.normalized()
		return

	var enemy: Node2D = owner._get_closest_enemy()
	if enemy != null:
		owner.facing_direction = owner.global_position.direction_to(enemy.global_position)


static func get_attack_aim_direction(owner, fallback_direction: Vector2 = Vector2.RIGHT) -> Vector2:
	if owner.auto_attack_enabled:
		var target_enemy: Node2D = owner._get_closest_enemy()
		if target_enemy != null and is_instance_valid(target_enemy):
			var target_direction: Vector2 = owner.global_position.direction_to(target_enemy.global_position)
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
		owner.pending_level_ups += 1
		level_up_guard += 1
	if level_up_guard >= 100:
		owner.experience = min(owner.experience, max(0, owner.experience_to_next_level - 1))

	owner.experience_changed.emit(owner.experience, owner.experience_to_next_level, owner.level)
	owner._try_request_level_up()


static func _get_adjusted_experience_gain(owner, amount: int) -> int:
	if amount <= 0:
		return 0
	var raw_gain := float(amount) * EXPERIENCE_GAIN_MULTIPLIER
	var carry := 0.0
	if owner != null and owner.has_meta(EXPERIENCE_FRACTION_CARRY_KEY):
		carry = float(owner.get_meta(EXPERIENCE_FRACTION_CARRY_KEY))
	raw_gain += carry
	var whole_gain := int(floor(raw_gain))
	var next_carry := raw_gain - float(whole_gain)
	if owner != null:
		owner.set_meta(EXPERIENCE_FRACTION_CARRY_KEY, next_carry)
	return whole_gain


static func grant_developer_level_up(owner) -> void:
	owner.level += 1
	owner.experience_to_next_level = PLAYER_LEVEL_CURVE.get_next_required_experience_after_level_up(owner.level)
	owner.pending_level_ups += 1
	owner.experience_changed.emit(owner.experience, owner.experience_to_next_level, owner.level)
	owner._try_request_level_up()


static func take_damage(owner, amount: float) -> void:
	if DEVELOPER_MODE.should_ignore_damage():
		return
	if owner.is_dead or owner.switch_invulnerability_remaining > 0.0:
		return

	if owner._try_equipment_dodge():
		owner.hurt_cooldown_remaining = owner.hurt_cooldown * 0.55
		owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -34.0), "\u95ea\u907f", Color(0.38, 1.0, 0.48, 1.0))
		return

	var attribute_dodge_chance: float = owner._get_attribute_dodge_chance() if owner.has_method("_get_attribute_dodge_chance") else 0.0
	if attribute_dodge_chance > 0.0 and randf() < attribute_dodge_chance:
		owner.hurt_cooldown_remaining = owner.hurt_cooldown * 0.55
		owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -34.0), "闪避", Color(0.38, 1.0, 0.48, 1.0))
		return

	if owner._get_active_role()["id"] == "swordsman":
		var nearby_enemy_count: int = owner._count_enemies_in_radius(owner.get_hurtbox_center(), 62.0)
		if nearby_enemy_count > 0:
			amount *= max(0.84, 0.96 - min(nearby_enemy_count, 3) * 0.04)

	var adjusted_damage: float = amount * owner._get_effective_damage_taken_multiplier()
	owner.current_health = max(0.0, owner.current_health - adjusted_damage)
	if owner.has_method("_save_active_role_health"):
		owner._save_active_role_health()
	owner.hurt_cooldown_remaining = owner.hurt_cooldown
	owner.health_changed.emit(owner.current_health, owner.max_health)
	owner._play_player_hurt_feedback()

	if owner.current_health <= 0.0:
		owner._die()


static func apply_enemy_slow(owner, multiplier: float, duration: float) -> void:
	owner.enemy_move_slow_multiplier = min(owner.enemy_move_slow_multiplier, clamp(multiplier, 0.15, 1.0))
	owner.enemy_move_slow_remaining = max(owner.enemy_move_slow_remaining, duration)
