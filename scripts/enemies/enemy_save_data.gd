extends RefCounted

const ENEMY_BOSS_STATE := preload("res://scripts/enemies/enemy_boss_state.gd")
const ENEMY_BOSS_VISUALS := preload("res://scripts/enemies/enemy_boss_visuals.gd")

static func get_save_data(enemy) -> Dictionary:
	return {
		"position": [enemy.global_position.x, enemy.global_position.y],
		"enemy_kind": enemy.enemy_kind,
		"archetype_id": enemy.archetype_id,
		"behavior_id": enemy.behavior_id,
		"secondary_behavior_id": enemy.secondary_behavior_id,
		"max_health": enemy.max_health,
		"current_health": enemy.current_health,
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
		"projectile_split_count": enemy.projectile_split_count,
		"projectile_split_after": enemy.projectile_split_after,
		"projectile_split_spread": enemy.projectile_split_spread,
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
		"dash_direction": [enemy.dash_direction.x, enemy.dash_direction.y],
		"strafe_sign": enemy.strafe_sign,
		"glutton_absorb_radius": enemy.glutton_absorb_radius,
		"glutton_speed_gain_per_gem": enemy.glutton_speed_gain_per_gem,
		"glutton_scale_gain_per_gem": enemy.glutton_scale_gain_per_gem,
		"glutton_max_bonus_speed": enemy.glutton_max_bonus_speed,
		"glutton_bonus_speed": enemy.glutton_bonus_speed,
		"rebirth_lives_remaining": enemy.rebirth_lives_remaining,
		"rebirth_delay": enemy.rebirth_delay,
		"rebirth_timer": enemy.rebirth_timer,
		"rebirth_slow_multiplier": enemy.rebirth_slow_multiplier,
		"rebirth_slow_duration": enemy.rebirth_slow_duration,
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
		"boss_turning_interval": enemy.boss_turning_interval,
		"boss_turning_timer": enemy.boss_turning_timer,
		"boss_turning_bullets": enemy.boss_turning_bullets,
		"boss_turning_sign": enemy.boss_turning_sign,
		"boss_orbit_sign": enemy.boss_orbit_sign,
		"boss_pattern_rotation": enemy.boss_pattern_rotation,
		"boss_display_name": enemy.boss_display_name,
		"boss_battle_elapsed": enemy.boss_battle_elapsed,
		"boss_phase": enemy.boss_phase,
		"boss_phase_three_elapsed": enemy.boss_phase_three_elapsed,
		"boss_phase_three_intro_remaining": enemy.boss_phase_three_intro_remaining,
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
	enemy.projectile_split_count = int(data.get("projectile_split_count", enemy.projectile_split_count))
	enemy.projectile_split_after = float(data.get("projectile_split_after", enemy.projectile_split_after))
	enemy.projectile_split_spread = float(data.get("projectile_split_spread", enemy.projectile_split_spread))

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
	enemy.rebirth_lives_remaining = int(data.get("rebirth_lives_remaining", enemy.rebirth_lives_remaining))
	enemy.rebirth_delay = float(data.get("rebirth_delay", enemy.rebirth_delay))
	enemy.rebirth_timer = float(data.get("rebirth_timer", enemy.rebirth_timer))
	enemy.rebirth_slow_multiplier = float(data.get("rebirth_slow_multiplier", enemy.rebirth_slow_multiplier))
	enemy.rebirth_slow_duration = float(data.get("rebirth_slow_duration", enemy.rebirth_slow_duration))
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
	enemy.boss_turning_interval = float(data.get("boss_turning_interval", enemy.boss_turning_interval))
	enemy.boss_turning_timer = float(data.get("boss_turning_timer", enemy.boss_turning_interval))
	enemy.boss_turning_bullets = int(data.get("boss_turning_bullets", enemy.boss_turning_bullets))
	enemy.boss_turning_sign = float(data.get("boss_turning_sign", 1.0))
	enemy.boss_orbit_sign = float(data.get("boss_orbit_sign", 1.0))
	enemy.boss_pattern_rotation = float(data.get("boss_pattern_rotation", 0.0))
	enemy.boss_display_name = str(data.get("boss_display_name", enemy.boss_display_name))
	enemy.boss_battle_elapsed = float(data.get("boss_battle_elapsed", 0.0))
	enemy.boss_phase = int(data.get("boss_phase", ENEMY_BOSS_STATE.get_boss_phase(enemy)))
	enemy.boss_phase_three_elapsed = float(data.get("boss_phase_three_elapsed", 0.0))
	enemy.boss_phase_three_intro_remaining = float(data.get("boss_phase_three_intro_remaining", 0.0))
	enemy.boss_split_timer = float(data.get("boss_split_timer", enemy.boss_split_interval))
	enemy.boss_laser_timer = float(data.get("boss_laser_timer", enemy.boss_laser_interval))
	enemy.boss_laser_remaining = float(data.get("boss_laser_remaining", 0.0))
	enemy.boss_laser_rotation = float(data.get("boss_laser_rotation", 0.0))
	enemy.boss_laser_start_rotation = float(data.get("boss_laser_start_rotation", enemy.boss_laser_rotation))
	enemy.boss_laser_final_rotation = float(data.get("boss_laser_final_rotation", enemy.boss_laser_rotation))
	enemy.boss_laser_hit_timer = float(data.get("boss_laser_hit_timer", 0.0))
	enemy.boss_orbit_bomb_timer = float(data.get("boss_orbit_bomb_timer", enemy.boss_orbit_bomb_interval))
	enemy.boss_orbit_bomb_remaining = float(data.get("boss_orbit_bomb_remaining", 0.0))
	enemy.boss_orbit_bomb_angle = float(data.get("boss_orbit_bomb_angle", 0.0))
	enemy.boss_orbit_bomb_shot_timer = float(data.get("boss_orbit_bomb_shot_timer", 0.0))
	enemy.boss_peacock_timer = float(data.get("boss_peacock_timer", enemy.boss_peacock_interval))
	enemy.boss_peacock_charge_remaining = float(data.get("boss_peacock_charge_remaining", 0.0))
	enemy.boss_attack_pressure_scale = float(data.get("boss_attack_pressure_scale", enemy.boss_attack_pressure_scale))
	enemy.glutton_absorb_elapsed = float(data.get("glutton_absorb_elapsed", 0.0))

	enemy.target = target_node
	enemy.profile_initialized = true
	enemy._ensure_status_visuals()
	enemy._apply_visuals(enemy.display_color)
	if enemy.enemy_kind == "boss":
		enemy._ensure_boss_helpers()
		if enemy.boss_phase_three_intro_remaining > 0.0:
			ENEMY_BOSS_VISUALS.update_boss_phase_three_charge_visuals(enemy)
		else:
			ENEMY_BOSS_VISUALS.clear_boss_phase_three_charge_visuals(enemy)
		if enemy.boss_orbit_bomb_remaining > 0.0:
			enemy._ensure_boss_orbit_ball()
		if enemy.boss_peacock_charge_remaining > 0.0:
			enemy._ensure_boss_peacock_markers(7)
