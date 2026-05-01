extends RefCounted

const OMNI_PIERCE_MIN_HITS := 1
const OMNI_FAN_MIN_HITS := 2
const OMNI_RING_MIN_HITS := 3
const BLOOD_REFLUX_COOLDOWN := 0.65
const FINALE_BREAK_MIN_KILL := 1
const FINALE_UNITY_MIN_HITS := 4
const BUILD_SYSTEM := preload("res://scripts/build/build_system.gd")


static func apply_attack_theme_skills(owner, role_id: String, hit_count: int, killed: bool) -> void:
	if hit_count <= 0:
		return
	var safe_role_id := role_id
	if safe_role_id == "":
		safe_role_id = str(owner._get_active_role().get("id", ""))
	if _is_theme_skill_locked(owner, safe_role_id):
		return
	owner.theme_skill_trigger_depth += 1
	trigger_omni_pierce(owner, safe_role_id, hit_count)
	trigger_omni_fan(owner, safe_role_id, hit_count)
	trigger_omni_ring(owner, safe_role_id, hit_count, killed)
	trigger_finale_charge(owner, safe_role_id, hit_count)
	trigger_finale_break(owner, safe_role_id, killed)
	trigger_finale_unity(owner, safe_role_id, hit_count, killed)
	owner.theme_skill_trigger_depth = max(0, owner.theme_skill_trigger_depth - 1)


static func get_passive_skill_slots(owner, role_id: String) -> Array:
	var slots: Array = []
	var card_ids := [
		"battle_dangzhen_qichao",
		"battle_blood_reflux"
	]
	for card_id in card_ids:
		if not BUILD_SYSTEM.has_independent_skill_cooldown(card_id):
			continue
		if card_id == "battle_dangzhen_qichao" and _has_role_evolved_active(owner, role_id):
			continue
		var level: int = max(0, int(owner._get_card_level(card_id)))
		if level <= 0:
			continue
		var config: Dictionary = BUILD_SYSTEM.get_core_card_config(card_id, role_id)
		var color := _get_role_theme_color(owner, role_id)
		var remaining := 0.0
		var duration := 1.0
		if card_id == "battle_dangzhen_qichao":
			var cooldown_payload := _get_dangzhen_cooldown_payload(owner, role_id)
			remaining = float(cooldown_payload.get("remaining", 0.0))
			duration = float(cooldown_payload.get("duration", 1.0))
		if card_id == "battle_blood_reflux":
			remaining = float(owner.get("theme_blood_reflux_cooldown"))
			duration = BLOOD_REFLUX_COOLDOWN
		slots.append({
			"name": str(config.get("card_title", config.get("title", card_id))),
			"remaining": remaining,
			"duration": duration,
			"color": color,
			"slot_label": str(config.get("card_type_label", "新的被动技能")),
			"description": _make_passive_slot_description(config, level, role_id)
		})
	return slots


static func _has_role_evolved_active(owner, role_id: String) -> bool:
	match role_id:
		"swordsman":
			return owner.has_method("_has_swordsman_blade_storm_reward") and bool(owner._has_swordsman_blade_storm_reward())
		"gunner":
			return owner.has_method("_has_gunner_infinite_reload_reward") and bool(owner._has_gunner_infinite_reload_reward())
		"mage":
			return owner.has_method("_has_mage_tidal_surge_reward") and bool(owner._has_mage_tidal_surge_reward())
	return false


static func _get_dangzhen_cooldown_payload(owner, role_id: String) -> Dictionary:
	var ability = null
	match role_id:
		"swordsman":
			ability = _get_owner_property(owner, "swordsman_dangzhen_fan_ability")
		"gunner":
			ability = _get_owner_property(owner, "gunner_dangzhen_beam_ability")
		"mage":
			ability = _get_owner_property(owner, "mage_dangzhen_wave_ability")
	if ability != null and ability.has_method("get_cooldown_slot"):
		return ability.get_cooldown_slot(owner)
	return {"remaining": 0.0, "duration": 1.0}


static func _get_owner_property(owner, property_name: String):
	if owner == null or not is_instance_valid(owner):
		return null
	for property_info in owner.get_property_list():
		if property_info is Dictionary and str(property_info.get("name", "")) == property_name:
			return owner.get(property_name)
	return null


static func _make_passive_slot_description(config: Dictionary, level: int, role_id: String) -> String:
	var lines: Array[String] = ["Lv.%d / %d" % [level, int(config.get("max_level", 3))]]
	lines.append(str(config.get("preview", config.get("description", ""))))
	var role_effects: Array = config.get("role_effects", [])
	for effect in role_effects:
		if effect is Dictionary and str(effect.get("role_id", "")) == role_id:
			for line in effect.get("lines", []):
				lines.append("- " + str(line))
			break
	return "\n".join(lines)


static func trigger_blood_reflux_counter(owner, incoming_amount: float) -> void:
	var level: int = max(0, int(owner._get_card_level("battle_blood_reflux")))
	if level <= 0:
		return
	if owner.theme_blood_reflux_cooldown > 0.0:
		return
	owner.theme_blood_reflux_cooldown = BLOOD_REFLUX_COOLDOWN
	var role_id := str(owner._get_active_role().get("id", ""))
	var radius: float = 58.0 + 14.0 * float(level)
	var damage_amount: float = owner._get_role_damage(role_id) * (0.34 + 0.1 * float(level)) + incoming_amount * 0.22
	var color := _get_role_theme_color(owner, role_id)
	var label := _get_variant_title(owner, "battle_blood_reflux", role_id)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -48.0), label, color)
	owner._spawn_guard_effect(owner.global_position, radius * 0.72, Color(color.r, color.g, color.b, 0.24), 0.16)
	owner._spawn_ring_effect(owner.global_position, radius, Color(color.r, color.g, color.b, 0.82), 7.0, 0.18)
	owner._spawn_burst_effect(owner.global_position, radius * 0.96, Color(color.r, color.g, color.b, 0.2), 0.16)
	var slow_multiplier := 0.82
	var slow_duration := 0.75
	if role_id == "mage":
		slow_multiplier = 0.68
		slow_duration = 1.15
		owner._spawn_frost_sigils_effect(owner.global_position, radius * 0.72, Color(0.78, 0.94, 1.0, 0.82), 0.2)
	elif role_id == "gunner":
		owner._spawn_radial_rays_effect(owner.global_position, radius * 1.04, 10 + level * 2, Color(1.0, 0.62, 0.3, 0.74), 4.0, 0.18)
	else:
		owner._spawn_crescent_wave_effect(owner.global_position, owner.facing_direction, radius * 0.92, Color(1.0, 0.3, 0.26, 0.68), 0.18, 300.0, 22.0)
	var hits: int = owner._damage_enemies_in_radius(owner.global_position, radius, damage_amount, 0.04 * float(level), slow_multiplier, slow_duration, role_id)
	if hits > 0:
		owner._heal(0.6 * float(level) + 0.2 * float(hits))


static func update_cooldowns(owner, delta: float) -> void:
	if owner.theme_blood_reflux_cooldown > 0.0:
		owner.theme_blood_reflux_cooldown = max(0.0, owner.theme_blood_reflux_cooldown - delta)


static func trigger_omni_pierce(owner, role_id: String, hit_count: int) -> void:
	var level: int = max(0, int(owner._get_card_level("battle_omni_pierce")))
	if level <= 0 or hit_count < OMNI_PIERCE_MIN_HITS:
		return
	var direction := _get_aim_direction(owner)
	var length: float = 118.0 + 38.0 * float(level)
	var width: float = 16.0 + 5.0 * float(level)
	var start_position: Vector2 = owner.global_position + direction * 18.0
	var center: Vector2 = start_position + direction * (length * 0.5)
	var damage_amount: float = owner._get_role_damage(role_id) * (0.22 + 0.06 * float(level))
	var color := _get_role_theme_color(owner, role_id)
	if role_id == "swordsman":
		owner._spawn_thrust_effect(start_position, start_position + direction * length, Color(0.34, 0.94, 1.0, 0.84), width, 0.12)
	elif role_id == "gunner":
		owner._spawn_dash_line_effect(start_position, start_position + direction * length, Color(1.0, 0.64, 0.24, 0.88), width * 0.55, 0.12)
		owner._spawn_target_lock_effect(center, width * 1.8, Color(1.0, 0.68, 0.28, 0.62), 0.12)
	else:
		owner._spawn_dash_line_effect(start_position, start_position + direction * length, Color(0.85, 0.52, 1.0, 0.84), width * 0.48, 0.12)
		owner._spawn_burst_effect(center, width * 2.2, Color(0.92, 0.46, 1.0, 0.16), 0.12)
	owner._damage_enemies_in_oriented_rect(center, direction, length, width, damage_amount, 0.015 * float(level), 1.0, 0.0, role_id)


static func trigger_omni_fan(owner, role_id: String, hit_count: int) -> void:
	var level: int = max(0, int(owner._get_card_level("battle_omni_fan")))
	if level <= 0 or hit_count < OMNI_FAN_MIN_HITS:
		return
	var direction := _get_aim_direction(owner)
	var color := _get_role_theme_color(owner, role_id)
	var radius: float = 64.0 + 18.0 * float(level)
	var damage_amount: float = owner._get_role_damage(role_id) * (0.2 + 0.055 * float(level))
	var angles: Array = [-0.42, 0.0, 0.42]
	if level >= 2:
		angles = [-0.58, -0.24, 0.24, 0.58]
	if level >= 3:
		angles = [-0.72, -0.42, -0.14, 0.14, 0.42, 0.72]
	for angle in angles:
		var lane_dir: Vector2 = direction.rotated(float(angle)).normalized()
		var start_position: Vector2 = owner.global_position + lane_dir * 20.0
		var end_position: Vector2 = start_position + lane_dir * radius
		if role_id == "swordsman":
			owner._spawn_crescent_wave_effect(start_position + lane_dir * radius * 0.38, lane_dir, radius * 0.42, Color(0.34, 0.94, 1.0, 0.58), 0.14, 170.0, 16.0)
		elif role_id == "gunner":
			owner._spawn_dash_line_effect(start_position, end_position, Color(1.0, 0.68, 0.34, 0.66), 4.0, 0.12)
		else:
			owner._spawn_dash_line_effect(start_position, end_position, Color(0.88, 0.62, 1.0, 0.62), 3.0, 0.12)
		owner._damage_enemies_in_line(start_position, end_position, 12.0 + 3.0 * float(level), damage_amount, 0.01 * float(level), 1.0, 0.0, role_id)


static func trigger_omni_ring(owner, role_id: String, hit_count: int, killed: bool) -> void:
	var level: int = max(0, int(owner._get_card_level("battle_omni_ring")))
	if level <= 0:
		return
	if hit_count < OMNI_RING_MIN_HITS and not killed:
		return
	var color := _get_role_theme_color(owner, role_id)
	var radius: float = 52.0 + 16.0 * float(level)
	var damage_amount: float = owner._get_role_damage(role_id) * (0.18 + 0.055 * float(level))
	owner._spawn_ring_effect(owner.global_position, radius, Color(color.r, color.g, color.b, 0.78), 6.0, 0.16)
	owner._spawn_burst_effect(owner.global_position, radius * 0.9, Color(color.r, color.g, color.b, 0.16), 0.16)
	if role_id == "gunner":
		owner._spawn_radial_rays_effect(owner.global_position, radius * 1.08, 8 + level * 2, Color(1.0, 0.65, 0.28, 0.7), 3.5, 0.16)
	elif role_id == "mage":
		owner._spawn_vortex_effect(owner.global_position, radius * 0.55, Color(0.78, 0.54, 1.0, 0.28), 0.18)
	owner._damage_enemies_in_radius(owner.global_position, radius, damage_amount, 0.015 * float(level), 1.0, 0.0, role_id)


static func trigger_finale_charge(owner, role_id: String, hit_count: int) -> void:
	var level: int = max(0, int(owner._get_card_level("battle_finale_charge")))
	if level <= 0 or hit_count < 2:
		return
	var direction := _get_aim_direction(owner)
	var center: Vector2 = owner.global_position + direction * (36.0 + 8.0 * float(level))
	var color := _get_role_theme_color(owner, role_id)
	var radius: float = 24.0 + 6.0 * float(level)
	var damage_amount: float = owner._get_role_damage(role_id) * (0.14 + 0.035 * float(level))
	owner._spawn_burst_effect(center, radius, Color(color.r, color.g, color.b, 0.18), 0.12)
	owner._spawn_ring_effect(center, radius * 1.08, Color(color.r, color.g, color.b, 0.58), 4.0, 0.12)
	owner._damage_enemies_in_radius(center, radius, damage_amount, 0.0, 1.0, 0.0, role_id)


static func trigger_finale_break(owner, role_id: String, killed: bool) -> void:
	var level: int = max(0, int(owner._get_card_level("battle_finale_break")))
	if level <= 0 or not killed:
		return
	var direction := _get_aim_direction(owner)
	var length: float = 98.0 + 28.0 * float(level)
	var width: float = 22.0 + 4.0 * float(level)
	var start_position: Vector2 = owner.global_position + direction * 18.0
	var center: Vector2 = start_position + direction * length * 0.5
	var damage_amount: float = owner._get_role_damage(role_id) * (0.34 + 0.08 * float(level))
	var color := _get_role_theme_color(owner, role_id)
	if role_id == "swordsman":
		owner._spawn_slash_effect(center, direction, length, width, Color(1.0, 0.88, 0.38, 0.72), 0.13)
	elif role_id == "gunner":
		owner._spawn_thrust_effect(start_position, start_position + direction * length, Color(1.0, 0.58, 0.2, 0.88), width * 0.75, 0.13)
	else:
		owner._spawn_dash_line_effect(start_position, start_position + direction * length, Color(0.72, 0.88, 1.0, 0.86), width * 0.46, 0.13)
		owner._spawn_frost_sigils_effect(center, width * 1.4, Color(0.82, 0.95, 1.0, 0.72), 0.14)
	owner._damage_enemies_in_oriented_rect(center, direction, length, width, damage_amount, 0.03 * float(level), 0.84, 0.7, role_id)


static func trigger_finale_unity(owner, role_id: String, hit_count: int, killed: bool) -> void:
	var level: int = max(0, int(owner._get_card_level("battle_finale_unity")))
	if level <= 0:
		return
	if hit_count < FINALE_UNITY_MIN_HITS and not killed:
		return
	var color := _get_role_theme_color(owner, role_id)
	var radius: float = 70.0 + 20.0 * float(level)
	var damage_amount: float = owner._get_role_damage(role_id) * (0.26 + 0.065 * float(level))
	owner._spawn_ring_effect(owner.global_position, radius, Color(color.r, color.g, color.b, 0.9), 8.0, 0.22)
	owner._spawn_radial_rays_effect(owner.global_position, radius * 1.08, 9 + level * 3, Color(color.r, color.g, color.b, 0.72), 4.5, 0.2)
	if role_id == "mage":
		owner._spawn_frost_sigils_effect(owner.global_position, radius * 0.58, Color(0.86, 0.98, 1.0, 0.84), 0.22)
		owner._spawn_vortex_effect(owner.global_position, radius * 0.46, Color(0.88, 0.56, 1.0, 0.3), 0.22)
	else:
		owner._spawn_burst_effect(owner.global_position, radius * 0.86, Color(color.r, color.g, color.b, 0.18), 0.2)
	owner._damage_enemies_in_radius(owner.global_position, radius, damage_amount, 0.025 * float(level), 0.78, 0.8, role_id)
	owner._add_energy(0.45 * float(level))


static func _is_theme_skill_locked(owner, role_id: String) -> bool:
	return int(owner.get("theme_skill_trigger_depth")) > 0


static func _get_aim_direction(owner) -> Vector2:
	var direction: Vector2 = owner.facing_direction
	if owner.has_method("_get_live_mouse_aim_direction"):
		direction = owner._get_live_mouse_aim_direction(direction)
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	return direction.normalized()


static func _get_role_theme_color(owner, role_id: String) -> Color:
	if owner.has_method("_get_role_theme_color"):
		return owner._get_role_theme_color(role_id)
	return Color.WHITE


static func _get_variant_title(owner, card_id: String, role_id: String) -> String:
	var config: Dictionary = BUILD_SYSTEM.get_core_card_config(card_id, role_id)
	return str(config.get("card_title", config.get("title", card_id)))
