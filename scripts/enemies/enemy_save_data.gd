extends RefCounted

const ENEMY_BOSS_STATE := preload("res://scripts/enemies/enemy_boss_state.gd")
const ENEMY_BOSS_VISUALS := preload("res://scripts/enemies/enemy_boss_visuals.gd")
const ENEMY_PROFILE_RESTORE := preload("res://scripts/enemies/enemy_profile_restore.gd")
const RUNNER_HASTE := preload("res://scripts/enemies/enemy_runner_haste.gd")

static func get_save_data(enemy) -> Dictionary:
	return {
		"position": [enemy.global_position.x, enemy.global_position.y],
		"enemy_kind": enemy.enemy_kind,
		"archetype_id": enemy.archetype_id,
		"behavior_id": enemy.behavior_id,
		"secondary_behavior_id": enemy.secondary_behavior_id,
		"max_health": enemy.max_health,
		"current_health": enemy.current_health,
		"damage_reduction_value": enemy.damage_reduction_value,
		"armor": enemy.armor,
		"fury_armor_shred": enemy.fury_armor_shred,
		"fury_armor_shred_remaining": enemy.fury_armor_shred_remaining,
		"attack": enemy.attack,
		"damage_reduction_rate": enemy.damage_reduction_rate,
		"stalwart_body_cooldown": enemy.stalwart_body_cooldown,
		"basic_shot_timer": enemy.basic_shot_timer,
		"heavy_armor_remaining": enemy.heavy_armor_remaining,
		"heavy_armor_cooldown": enemy.heavy_armor_cooldown,
		"runner_haste_remaining": enemy.runner_haste_remaining,
		"runner_haste_cooldown": enemy.runner_haste_cooldown,
		"speed": enemy.speed,
		"touch_damage": enemy.touch_damage,
		"contact_radius": enemy.contact_radius,
		"experience_reward": enemy.experience_reward,
		"reward_tier": enemy.reward_tier,
		"scale_x": enemy.scale.x,
		"scale_y": enemy.scale.y,
		"display_color": [enemy.display_color.r, enemy.display_color.g, enemy.display_color.b, enemy.display_color.a],
		"slow_multiplier": enemy.slow_multiplier,
		"slow_timer": enemy.slow_timer,
		"vulnerability_bonus": enemy.vulnerability_bonus,
		"vulnerability_timer": enemy.vulnerability_timer,
		"bleed_damage_per_second": enemy.bleed_damage_per_second,
		"bleed_timer": enemy.bleed_timer,
		"preferred_distance": enemy.preferred_distance,
		"shot_interval": enemy.shot_interval,
		"shot_timer": enemy.shot_timer,
		"projectile_speed": enemy.projectile_speed,
		"projectile_damage": enemy.projectile_damage,
		"projectile_lifetime": enemy.projectile_lifetime,
		"projectile_spread": enemy.projectile_spread,
		"projectile_count": enemy.projectile_count,
		"projectile_color": [enemy.projectile_color.r, enemy.projectile_color.g, enemy.projectile_color.b, enemy.projectile_color.a],
		"projectile_visual_style": enemy.projectile_visual_style,
		"projectile_split_count": enemy.projectile_split_count,
		"projectile_split_after": enemy.projectile_split_after,
		"projectile_split_spread": enemy.projectile_split_spread,
		"projectile_split_pattern": enemy.projectile_split_pattern,
		"projectile_split_speed_scale": enemy.projectile_split_speed_scale,
		"projectile_split_damage_scale": enemy.projectile_split_damage_scale,
		"projectile_split_lifetime_scale": enemy.projectile_split_lifetime_scale,
		"projectile_split_size_scale": enemy.projectile_split_size_scale,
		"projectile_split_hit_radius_scale": enemy.projectile_split_hit_radius_scale,
		"acceleration_interval": enemy.acceleration_interval,
		"acceleration_boost": enemy.acceleration_boost,
		"acceleration_duration": enemy.acceleration_duration,
		"acceleration_timer": enemy.acceleration_timer,
		"acceleration_remaining": enemy.acceleration_remaining,
		"dash_interval": enemy.dash_interval,
		"dash_duration": enemy.dash_duration,
		"dash_speed_multiplier": enemy.dash_speed_multiplier,
		"dash_windup_duration": enemy.dash_windup_duration,
		"dash_timer": enemy.dash_timer,
		"dash_windup_remaining": enemy.dash_windup_remaining,
		"dash_remaining": enemy.dash_remaining,
		"dash_distance_remaining": enemy.dash_distance_remaining,
		"elite_charge_haste_remaining": enemy.elite_charge_haste_remaining,
		"dash_direction": [enemy.dash_direction.x, enemy.dash_direction.y],
		"strafe_sign": enemy.strafe_sign,
		"glutton_absorb_radius": enemy.glutton_absorb_radius,
		"glutton_speed_gain_per_gem": enemy.glutton_speed_gain_per_gem,
		"glutton_scale_gain_per_gem": enemy.glutton_scale_gain_per_gem,
		"glutton_max_bonus_speed": enemy.glutton_max_bonus_speed,
		"glutton_bonus_speed": enemy.glutton_bonus_speed,
		"glutton_aura_radius": enemy.glutton_aura_radius,
		"glutton_aura_damage": enemy.glutton_aura_damage,
		"glutton_heart_heal_scale": enemy.glutton_heart_heal_scale,
		"glutton_war_stomp_cooldown_remaining": enemy.glutton_war_stomp_cooldown_remaining,
		"rebirth_lives_remaining": enemy.rebirth_lives_remaining,
		"rebirth_delay": enemy.rebirth_delay,
		"rebirth_timer": enemy.rebirth_timer,
		"rebirth_slow_multiplier": enemy.rebirth_slow_multiplier,
		"rebirth_slow_duration": enemy.rebirth_slow_duration,
		"skulltomb_summon_timer": enemy.skulltomb_summon_timer,
		"skulltomb_summon_windup_remaining": enemy.skulltomb_summon_windup_remaining,
		"skulltomb_charge_timer": enemy.skulltomb_charge_timer,
		"skulltomb_charge_decision_timer": enemy.skulltomb_charge_decision_timer,
		"skulltomb_charge_active": enemy.skulltomb_charge_active,
		"skulltomb_charge_windup_remaining": enemy.skulltomb_charge_windup_remaining,
		"skulltomb_charge_target_position": [enemy.skulltomb_charge_target_position.x, enemy.skulltomb_charge_target_position.y],
		"skulltomb_aging_aura_elapsed": enemy.skulltomb_aging_aura_elapsed,
		"skulltomb_domain": {
			"remaining": enemy.skulltomb_area_remaining,
			"center": [enemy.skulltomb_area_center.x, enemy.skulltomb_area_center.y],
			"cast_center": [enemy.skulltomb_summon_target_center.x, enemy.skulltomb_summon_target_center.y],
			"radius": enemy.skulltomb_area_radius,
			"check_elapsed": enemy.skulltomb_area_damage_elapsed,
			"pending_spawns": enemy.skulltomb_pending_spawns.duplicate(true),
			"spawn_elapsed": enemy.skulltomb_spawn_elapsed,
			"spawn_vertex": enemy.skulltomb_spawn_vertex_index
		},
		"skull_soldier_speed_multiplier": enemy.skull_soldier_speed_multiplier,
		"skull_soldier_speed_timer": enemy.skull_soldier_speed_timer,
		"skull_damage_immune_timer": enemy.skull_damage_immune_timer,
		"skullshot_attack_frequency_multiplier": enemy.skullshot_attack_frequency_multiplier,
		"skullshot_attack_frequency_timer": enemy.skullshot_attack_frequency_timer,
		"turret_bombard_interval": enemy.turret_bombard_interval,
		"turret_bombard_timer": enemy.turret_bombard_timer,
		"turret_bombard_radius": enemy.turret_bombard_radius,
		"turret_bombard_projectiles": enemy.turret_bombard_projectiles,
		"boss_radial_interval": enemy.boss_radial_interval,
		"boss_radial_timer": enemy.boss_radial_timer,
		"boss_radial_bullets": enemy.boss_radial_bullets,
		"boss_sine_interval": enemy.boss_sine_interval,
		"boss_sine_cooldown": enemy.boss_sine_cooldown,
		"boss_sine_stream_duration": enemy.boss_sine_stream_duration,
		"boss_sine_stream_remaining": enemy.boss_sine_stream_remaining,
		"boss_sine_stream_rate": enemy.boss_sine_stream_rate,
		"boss_sine_stream_timer": enemy.boss_sine_stream_timer,
		"boss_danmaku_pattern": enemy.boss_danmaku_pattern,
		"boss_danmaku_wave": enemy.boss_danmaku_wave,
		"boss_danmaku_count": enemy.boss_danmaku_count,
		"boss_danmaku_rotation": enemy.boss_danmaku_rotation,
		"boss_danmaku_spin": enemy.boss_danmaku_spin,
		"boss_routine": enemy.boss_routine.duplicate(true),
		"boss_aimed_shots_remaining": enemy.boss_aimed_shots_remaining,
		"boss_aimed_shot_timer": enemy.boss_aimed_shot_timer,
		"boss_laser_contact_version": 1,
		"boss_turning_interval": enemy.boss_turning_interval,
		"boss_turning_timer": enemy.boss_turning_timer,
		"boss_turning_bullets": enemy.boss_turning_bullets,
		"boss_turning_sign": enemy.boss_turning_sign,
		"boss_orbit_sign": enemy.boss_orbit_sign,
		"boss_pattern_rotation": enemy.boss_pattern_rotation,
		"boss_display_name": enemy.boss_display_name,
		"boss_shield_max_health": enemy.boss_shield_max_health,
		"boss_battle_elapsed": enemy.boss_battle_elapsed,
		"boss_phase": enemy.boss_phase,
		"boss_phase_three_elapsed": enemy.boss_phase_three_elapsed,
		"boss_phase_three_intro_remaining": enemy.boss_phase_three_intro_remaining,
		"boss_phase_transition_target": enemy.boss_phase_transition_target,
		"boss_shield_break_intro_played": enemy.boss_shield_break_intro_played,
		"boss_shield_break_visual_intro_active": enemy.boss_shield_break_visual_intro_active,
		"boss_split_timer": enemy.boss_split_timer,
		"boss_laser_timer": enemy.boss_laser_timer,
		"boss_laser_remaining": enemy.boss_laser_remaining,
		"boss_laser_rotation": enemy.boss_laser_rotation,
		"boss_laser_start_rotation": enemy.boss_laser_start_rotation,
		"boss_laser_final_rotation": enemy.boss_laser_final_rotation,
		"boss_laser_hit_timer": enemy.boss_laser_hit_timer,
		"boss_orbit_bomb_timer": enemy.boss_orbit_bomb_timer,
		"boss_orbit_bomb_remaining": enemy.boss_orbit_bomb_remaining,
		"boss_orbit_bomb_angle": enemy.boss_orbit_bomb_angle,
		"boss_orbit_bomb_shot_timer": enemy.boss_orbit_bomb_shot_timer,
		"boss_orbit_pull_remaining": enemy.boss_orbit_pull_remaining,
		"boss_peacock_timer": enemy.boss_peacock_timer,
		"boss_peacock_charge_remaining": enemy.boss_peacock_charge_remaining,
		"boss_attack_pressure_scale": enemy.boss_attack_pressure_scale,
		"glutton_absorb_elapsed": enemy.glutton_absorb_elapsed
	}

static func apply_save_data(enemy, data: Dictionary, target_node: Node2D) -> void:
	var position_data = data.get("position", [0.0, 0.0])
	if position_data.size() >= 2:
		enemy.global_position = Vector2(float(position_data[0]), float(position_data[1]))

	enemy.enemy_kind = str(data.get("enemy_kind", "normal"))
	enemy.archetype_id = str(data.get("archetype_id", "chaser"))
	enemy.behavior_id = str(data.get("behavior_id", enemy.archetype_id))
	enemy.secondary_behavior_id = str(data.get("secondary_behavior_id", ""))
	enemy.max_health = float(data.get("max_health", enemy.max_health))
	enemy.current_health = float(data.get("current_health", enemy.max_health))
	enemy.damage_reduction_value = float(data.get("damage_reduction_value", 0.0))
	enemy.armor = float(data.get("armor", 0.0))
	enemy.fury_armor_shred_remaining = clampf(float(data.get("fury_armor_shred_remaining", 0.0)), 0.0, 2.0)
	enemy.fury_armor_shred = maxf(0.0, float(data.get("fury_armor_shred", 0.0))) if enemy.fury_armor_shred_remaining > 0.0 else 0.0
	enemy.attack = max(0.0, float(data.get("attack", enemy.attack)))
	enemy.damage_reduction_rate = clampf(float(data.get("damage_reduction_rate", 0.0)), 0.0, 1.0)
	enemy.stalwart_body_cooldown = clampf(float(data.get("stalwart_body_cooldown", 0.0)), 0.0, 1.0)
	enemy.basic_shot_timer = maxf(0.0, float(data.get("basic_shot_timer", 2.6)))
	var heavy_armor_form := preload("res://scripts/enemies/enemy_heavy_armor_form.gd")
	enemy.heavy_armor_remaining = clampf(float(data.get("heavy_armor_remaining", 0.0)), 0.0, heavy_armor_form.get_duration(enemy))
	enemy.heavy_armor_cooldown = clampf(float(data.get("heavy_armor_cooldown", heavy_armor_form.get_cooldown(enemy))), 0.0, heavy_armor_form.get_cooldown(enemy))
	enemy.runner_haste_remaining = clampf(float(data.get("runner_haste_remaining", 0.0)), 0.0, RUNNER_HASTE.DURATION) if enemy.archetype_id == "runner" else 0.0
	enemy.runner_haste_cooldown = clampf(float(data.get("runner_haste_cooldown", 0.0)), 0.0, RUNNER_HASTE.COOLDOWN) if enemy.archetype_id == "runner" else 0.0
	enemy.speed = float(data.get("speed", enemy.speed))
	enemy.touch_damage = float(data.get("touch_damage", enemy.touch_damage))
	enemy.contact_radius = float(data.get("contact_radius", enemy.contact_radius))
	enemy.experience_reward = int(data.get("experience_reward", enemy.experience_reward))
	enemy.reward_tier = clamp(int(data.get("reward_tier", enemy.reward_tier)), 1, 4)
	enemy.scale = Vector2(float(data.get("scale_x", 1.0)), float(data.get("scale_y", 1.0)))

	var color_data = data.get("display_color", [enemy.display_color.r, enemy.display_color.g, enemy.display_color.b, enemy.display_color.a])
	if color_data.size() >= 4:
		enemy.display_color = Color(float(color_data[0]), float(color_data[1]), float(color_data[2]), float(color_data[3]))

	enemy.slow_multiplier = float(data.get("slow_multiplier", 1.0))
	enemy.slow_timer = float(data.get("slow_timer", 0.0))
	enemy.vulnerability_bonus = float(data.get("vulnerability_bonus", 0.0))
	enemy.vulnerability_timer = float(data.get("vulnerability_timer", 0.0))
	enemy.bleed_damage_per_second = float(data.get("bleed_damage_per_second", 0.0))
	enemy.bleed_timer = float(data.get("bleed_timer", 0.0))

	enemy.preferred_distance = float(data.get("preferred_distance", enemy.preferred_distance))
	enemy.shot_interval = float(data.get("shot_interval", enemy.shot_interval))
	enemy.shot_timer = float(data.get("shot_timer", enemy.shot_interval))
	enemy.projectile_speed = float(data.get("projectile_speed", enemy.projectile_speed))
	enemy.projectile_damage = float(data.get("projectile_damage", enemy.projectile_damage))
	enemy.projectile_lifetime = float(data.get("projectile_lifetime", enemy.projectile_lifetime))
	enemy.projectile_spread = float(data.get("projectile_spread", enemy.projectile_spread))
	enemy.projectile_count = int(data.get("projectile_count", enemy.projectile_count))
	var projectile_color_data = data.get("projectile_color", [enemy.projectile_color.r, enemy.projectile_color.g, enemy.projectile_color.b, enemy.projectile_color.a])
	if projectile_color_data.size() >= 4:
		enemy.projectile_color = Color(float(projectile_color_data[0]), float(projectile_color_data[1]), float(projectile_color_data[2]), float(projectile_color_data[3]))
	enemy.projectile_visual_style = str(data.get("projectile_visual_style", enemy.projectile_visual_style))
	enemy.projectile_split_count = int(data.get("projectile_split_count", enemy.projectile_split_count))
	enemy.projectile_split_after = float(data.get("projectile_split_after", enemy.projectile_split_after))
	enemy.projectile_split_spread = float(data.get("projectile_split_spread", enemy.projectile_split_spread))
	enemy.projectile_split_pattern = str(data.get("projectile_split_pattern", enemy.projectile_split_pattern))
	enemy.projectile_split_speed_scale = float(data.get("projectile_split_speed_scale", enemy.projectile_split_speed_scale))
	enemy.projectile_split_damage_scale = float(data.get("projectile_split_damage_scale", enemy.projectile_split_damage_scale))
	enemy.projectile_split_lifetime_scale = float(data.get("projectile_split_lifetime_scale", enemy.projectile_split_lifetime_scale))
	enemy.projectile_split_size_scale = float(data.get("projectile_split_size_scale", enemy.projectile_split_size_scale))
	enemy.projectile_split_hit_radius_scale = float(data.get("projectile_split_hit_radius_scale", enemy.projectile_split_hit_radius_scale))

	enemy.acceleration_interval = float(data.get("acceleration_interval", enemy.acceleration_interval))
	enemy.acceleration_boost = float(data.get("acceleration_boost", enemy.acceleration_boost))
	enemy.acceleration_duration = float(data.get("acceleration_duration", enemy.acceleration_duration))
	enemy.acceleration_timer = float(data.get("acceleration_timer", enemy.acceleration_interval))
	enemy.acceleration_remaining = float(data.get("acceleration_remaining", 0.0))

	enemy.dash_interval = float(data.get("dash_interval", enemy.dash_interval))
	enemy.dash_duration = float(data.get("dash_duration", enemy.dash_duration))
	enemy.dash_speed_multiplier = float(data.get("dash_speed_multiplier", enemy.dash_speed_multiplier))
	enemy.dash_windup_duration = float(data.get("dash_windup_duration", enemy.dash_windup_duration))
	enemy.dash_timer = float(data.get("dash_timer", enemy.dash_interval))
	enemy.dash_windup_remaining = float(data.get("dash_windup_remaining", 0.0))
	enemy.dash_remaining = float(data.get("dash_remaining", 0.0))
	enemy.dash_distance_remaining = clampf(float(data.get("dash_distance_remaining", enemy.dash_remaining * 250.0)), 0.0, 500.0)
	enemy.elite_charge_haste_remaining = clampf(float(data.get("elite_charge_haste_remaining", 0.0)), 0.0, 3.0)
	var dash_direction_data = data.get("dash_direction", [1.0, 0.0])
	if dash_direction_data.size() >= 2:
		enemy.dash_direction = Vector2(float(dash_direction_data[0]), float(dash_direction_data[1])).normalized()
	if enemy.dash_direction == Vector2.ZERO:
		enemy.dash_direction = Vector2.RIGHT

	enemy.strafe_sign = float(data.get("strafe_sign", 1.0))
	enemy.glutton_absorb_radius = float(data.get("glutton_absorb_radius", enemy.glutton_absorb_radius))
	enemy.glutton_speed_gain_per_gem = float(data.get("glutton_speed_gain_per_gem", enemy.glutton_speed_gain_per_gem))
	enemy.glutton_scale_gain_per_gem = float(data.get("glutton_scale_gain_per_gem", enemy.glutton_scale_gain_per_gem))
	enemy.glutton_max_bonus_speed = float(data.get("glutton_max_bonus_speed", enemy.glutton_max_bonus_speed))
	enemy.glutton_bonus_speed = float(data.get("glutton_bonus_speed", enemy.glutton_bonus_speed))
	enemy.glutton_aura_radius = float(data.get("glutton_aura_radius", enemy.glutton_absorb_radius))
	enemy.glutton_aura_damage = float(data.get("glutton_aura_damage", enemy.glutton_aura_damage))
	enemy.glutton_heart_heal_scale = float(data.get("glutton_heart_heal_scale", enemy.glutton_heart_heal_scale))
	enemy.glutton_war_stomp_cooldown_remaining = float(data.get("glutton_war_stomp_cooldown_remaining", 0.0))
	enemy.drop_absorber = null
	enemy.rebirth_lives_remaining = int(data.get("rebirth_lives_remaining", enemy.rebirth_lives_remaining))
	enemy.rebirth_delay = float(data.get("rebirth_delay", enemy.rebirth_delay))
	enemy.rebirth_timer = float(data.get("rebirth_timer", enemy.rebirth_timer))
	enemy.rebirth_slow_multiplier = float(data.get("rebirth_slow_multiplier", enemy.rebirth_slow_multiplier))
	enemy.rebirth_slow_duration = float(data.get("rebirth_slow_duration", enemy.rebirth_slow_duration))
	enemy.skulltomb_summon_timer = float(data.get("skulltomb_summon_timer", enemy.skulltomb_summon_timer))
	enemy.skulltomb_summon_windup_remaining = float(data.get("skulltomb_summon_windup_remaining", 0.0))
	enemy.skulltomb_charge_timer = float(data.get("skulltomb_charge_timer", enemy.skulltomb_charge_timer))
	enemy.skulltomb_charge_decision_timer = float(data.get("skulltomb_charge_decision_timer", 0.0))
	enemy.skulltomb_charge_active = bool(data.get("skulltomb_charge_active", false))
	enemy.skulltomb_charge_windup_remaining = float(data.get("skulltomb_charge_windup_remaining", 0.0))
	var charge_target_data: Variant = data.get("skulltomb_charge_target_position", null)
	if charge_target_data is Array and charge_target_data.size() >= 2:
		enemy.skulltomb_charge_target_position = Vector2(float(charge_target_data[0]), float(charge_target_data[1]))
	else:
		enemy.skulltomb_charge_target_position = Vector2.ZERO
	enemy.skulltomb_aging_aura_elapsed = float(data.get("skulltomb_aging_aura_elapsed", 0.0))
	enemy.skull_soldier_speed_multiplier = float(data.get("skull_soldier_speed_multiplier", 1.0))
	enemy.skull_soldier_speed_timer = float(data.get("skull_soldier_speed_timer", 0.0))
	enemy.skull_damage_immune_timer = float(data.get("skull_damage_immune_timer", 0.0))
	enemy.skullshot_attack_frequency_multiplier = float(data.get("skullshot_attack_frequency_multiplier", 1.0))
	enemy.skullshot_attack_frequency_timer = float(data.get("skullshot_attack_frequency_timer", 0.0))
	enemy.turret_bombard_interval = float(data.get("turret_bombard_interval", enemy.turret_bombard_interval))
	enemy.turret_bombard_timer = float(data.get("turret_bombard_timer", enemy.turret_bombard_interval))
	enemy.turret_bombard_radius = float(data.get("turret_bombard_radius", enemy.turret_bombard_radius))
	enemy.turret_bombard_projectiles = int(data.get("turret_bombard_projectiles", enemy.turret_bombard_projectiles))
	enemy.boss_radial_interval = float(data.get("boss_radial_interval", enemy.boss_radial_interval))
	enemy.boss_radial_timer = float(data.get("boss_radial_timer", enemy.boss_radial_interval))
	enemy.boss_radial_bullets = int(data.get("boss_radial_bullets", enemy.boss_radial_bullets))
	enemy.boss_sine_interval = float(data.get("boss_sine_interval", enemy.boss_sine_interval))
	enemy.boss_sine_cooldown = float(data.get("boss_sine_cooldown", enemy.boss_sine_interval))
	enemy.boss_sine_stream_duration = float(data.get("boss_sine_stream_duration", enemy.boss_sine_stream_duration))
	enemy.boss_sine_stream_remaining = float(data.get("boss_sine_stream_remaining", 0.0))
	enemy.boss_sine_stream_rate = float(data.get("boss_sine_stream_rate", enemy.boss_sine_stream_rate))
	enemy.boss_sine_stream_timer = float(data.get("boss_sine_stream_timer", 0.0))
	enemy.boss_danmaku_pattern = clampi(int(data.get("boss_danmaku_pattern", -1)), -1, preload("res://scripts/enemies/enemy_boss_danmaku.gd").PATTERN_COUNT - 1)
	enemy.boss_danmaku_wave = clampi(int(data.get("boss_danmaku_wave", 6)), 0, 6)
	enemy.boss_danmaku_count = clampi(int(data.get("boss_danmaku_count", 0)), 0, 64)
	enemy.boss_danmaku_rotation = float(data.get("boss_danmaku_rotation", 0.0))
	enemy.boss_danmaku_spin = float(data.get("boss_danmaku_spin", 1.0))
	enemy.boss_aimed_shots_remaining = clampi(int(data.get("boss_aimed_shots_remaining", 0)), 0, 7)
	enemy.boss_aimed_shot_timer = float(data.get("boss_aimed_shot_timer", 0.0))
	enemy.boss_turning_interval = float(data.get("boss_turning_interval", enemy.boss_turning_interval))
	enemy.boss_turning_timer = float(data.get("boss_turning_timer", enemy.boss_turning_interval))
	enemy.boss_turning_bullets = int(data.get("boss_turning_bullets", enemy.boss_turning_bullets))
	enemy.boss_turning_sign = float(data.get("boss_turning_sign", 1.0))
	enemy.boss_orbit_sign = float(data.get("boss_orbit_sign", 1.0))
	enemy.boss_pattern_rotation = float(data.get("boss_pattern_rotation", 0.0))
	enemy.boss_display_name = str(data.get("boss_display_name", enemy.boss_display_name))
	if enemy.archetype_id == "boss_spellcore":
		enemy.boss_display_name = "被污染的魔法石"
	enemy.boss_shield_max_health = maxf(0.0, float(data.get("boss_shield_max_health", 5000.0 if enemy.archetype_id == "boss_spellcore" else 0.0)))
	enemy.boss_battle_elapsed = float(data.get("boss_battle_elapsed", 0.0))
	enemy.boss_phase = int(data.get("boss_phase", ENEMY_BOSS_STATE.get_boss_phase(enemy)))
	enemy.boss_phase_three_elapsed = float(data.get("boss_phase_three_elapsed", 0.0))
	enemy.boss_phase_three_intro_remaining = float(data.get("boss_phase_three_intro_remaining", 0.0))
	enemy.boss_phase_transition_target = int(data.get("boss_phase_transition_target", 0))
	enemy.boss_shield_break_intro_played = bool(data.get("boss_shield_break_intro_played", enemy.boss_phase >= 3 or enemy.boss_phase_transition_target > 0 or float(enemy.current_health) <= ENEMY_BOSS_STATE.get_phase_bar_max_health(enemy)))
	enemy.boss_shield_break_visual_intro_active = bool(data.get("boss_shield_break_visual_intro_active", enemy.boss_phase_transition_target <= 0 and enemy.boss_phase_three_intro_remaining > 0.0 and enemy.boss_shield_break_intro_played))
	enemy.boss_split_timer = float(data.get("boss_split_timer", enemy.boss_split_interval))
	enemy.boss_laser_timer = float(data.get("boss_laser_timer", enemy.boss_laser_interval))
	enemy.boss_laser_remaining = float(data.get("boss_laser_remaining", 0.0))
	enemy.boss_laser_rotation = float(data.get("boss_laser_rotation", 0.0))
	enemy.boss_laser_start_rotation = float(data.get("boss_laser_start_rotation", enemy.boss_laser_rotation))
	enemy.boss_laser_final_rotation = float(data.get("boss_laser_final_rotation", enemy.boss_laser_rotation))
	enemy.boss_laser_hit_timer = float(data.get("boss_laser_hit_timer", 0.0)) if data.has("boss_laser_contact_version") else 0.0
	enemy.boss_orbit_bomb_timer = float(data.get("boss_orbit_bomb_timer", enemy.boss_orbit_bomb_interval))
	enemy.boss_orbit_bomb_remaining = float(data.get("boss_orbit_bomb_remaining", 0.0))
	enemy.boss_orbit_bomb_angle = float(data.get("boss_orbit_bomb_angle", 0.0))
	enemy.boss_orbit_bomb_shot_timer = float(data.get("boss_orbit_bomb_shot_timer", 0.0))
	enemy.boss_orbit_pull_remaining = float(data.get("boss_orbit_pull_remaining", 0.0))
	enemy.boss_peacock_timer = float(data.get("boss_peacock_timer", enemy.boss_peacock_interval))
	enemy.boss_peacock_charge_remaining = float(data.get("boss_peacock_charge_remaining", 0.0))
	enemy.boss_attack_pressure_scale = float(data.get("boss_attack_pressure_scale", enemy.boss_attack_pressure_scale))
	enemy.glutton_absorb_elapsed = float(data.get("glutton_absorb_elapsed", 0.0))

	enemy.target = target_node
	enemy._sync_trait_flags()
	enemy.profile_initialized = true
	ENEMY_PROFILE_RESTORE.restore_profile_resources(enemy)
	enemy._ensure_status_visuals()
	enemy._apply_visuals(enemy.display_color)
	preload("res://scripts/enemies/enemy_heavy_armor_form.gd").sync_visual(enemy)
	if enemy.behavior_id == "skulltomb":
		preload("res://scripts/enemies/enemy_skulltomb_behavior.gd").restore_domain(enemy, data.get("skulltomb_domain", {}))
	if enemy.enemy_kind == "boss":
		enemy._ensure_boss_helpers()
		if enemy.boss_phase_transition_target > 0 or enemy.boss_phase_three_intro_remaining > 0.0:
			ENEMY_BOSS_VISUALS.update_boss_phase_three_charge_visuals(enemy)
		else:
			ENEMY_BOSS_VISUALS.clear_boss_phase_three_charge_visuals(enemy)
		if enemy.boss_phase >= 3 or enemy.boss_orbit_bomb_remaining > 0.0:
			enemy._ensure_boss_orbit_ball()
		if enemy.boss_peacock_charge_remaining > 0.0:
			enemy._ensure_boss_peacock_markers(7)
		if enemy.archetype_id == "boss_spellcore":
			ENEMY_BOSS_STATE.ROUTINE.restore(enemy, data.get("boss_routine", {}))
