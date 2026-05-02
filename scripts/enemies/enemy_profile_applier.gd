extends RefCounted

static func apply_profile(enemy, kind: String, profile: Dictionary) -> void:
	enemy.enemy_kind = kind
	enemy.archetype_id = str(profile.get("archetype", enemy.archetype_id))
	enemy.behavior_id = str(profile.get("behavior", enemy.behavior_id))
	enemy.secondary_behavior_id = str(profile.get("secondary_behavior", enemy.secondary_behavior_id))
	enemy.max_health = float(profile.get("max_health", enemy.max_health))
	enemy.current_health = min(enemy.current_health if enemy.current_health > 0.0 else enemy.max_health, enemy.max_health)
	enemy.speed = float(profile.get("speed", enemy.speed))
	enemy.touch_damage = float(profile.get("touch_damage", enemy.touch_damage))
	enemy.contact_radius = float(profile.get("contact_radius", enemy.contact_radius))
	enemy.experience_reward = int(profile.get("experience_reward", enemy.experience_reward))
	enemy.reward_tier = clamp(int(profile.get("reward_tier", enemy.reward_tier)), 1, 4)

	enemy.preferred_distance = float(profile.get("preferred_distance", enemy.preferred_distance))
	enemy.shot_interval = float(profile.get("shot_interval", enemy.shot_interval))
	enemy.projectile_speed = float(profile.get("projectile_speed", enemy.projectile_speed))
	enemy.projectile_damage = float(profile.get("projectile_damage", enemy.projectile_damage))
	enemy.projectile_lifetime = float(profile.get("projectile_lifetime", enemy.projectile_lifetime))
	enemy.projectile_spread = float(profile.get("projectile_spread", enemy.projectile_spread))
	enemy.projectile_count = int(profile.get("projectile_count", enemy.projectile_count))
	enemy.projectile_split_count = int(profile.get("projectile_split_count", enemy.projectile_split_count))
	enemy.projectile_split_after = float(profile.get("projectile_split_after", enemy.projectile_split_after))
	enemy.projectile_split_spread = float(profile.get("projectile_split_spread", enemy.projectile_split_spread))

	enemy.acceleration_interval = float(profile.get("acceleration_interval", enemy.acceleration_interval))
	enemy.acceleration_boost = float(profile.get("acceleration_boost", enemy.acceleration_boost))
	enemy.acceleration_duration = float(profile.get("acceleration_duration", enemy.acceleration_duration))
	enemy.dash_interval = float(profile.get("dash_interval", enemy.dash_interval))
	enemy.dash_duration = float(profile.get("dash_duration", enemy.dash_duration))
	enemy.dash_speed_multiplier = float(profile.get("dash_speed_multiplier", enemy.dash_speed_multiplier))
	enemy.dash_windup_duration = float(profile.get("dash_windup_duration", enemy.dash_windup_duration))

	enemy.boss_radial_interval = float(profile.get("boss_radial_interval", enemy.boss_radial_interval))
	enemy.boss_radial_bullets = int(profile.get("boss_radial_bullets", enemy.boss_radial_bullets))
	enemy.boss_sine_interval = float(profile.get("boss_sine_interval", enemy.boss_sine_interval))
	enemy.boss_sine_stream_duration = float(profile.get("boss_sine_stream_duration", enemy.boss_sine_stream_duration))
	enemy.boss_sine_stream_rate = float(profile.get("boss_sine_stream_rate", enemy.boss_sine_stream_rate))
	enemy.boss_turning_interval = float(profile.get("boss_turning_interval", enemy.boss_turning_interval))
	enemy.boss_turning_bullets = int(profile.get("boss_turning_bullets", enemy.boss_turning_bullets))
	enemy.boss_display_name = str(profile.get("boss_name", enemy.boss_display_name))
	enemy.boss_attack_pressure_scale = float(profile.get("boss_attack_pressure_scale", enemy.boss_attack_pressure_scale))

	enemy.glutton_absorb_radius = float(profile.get("glutton_absorb_radius", enemy.glutton_absorb_radius))
	enemy.glutton_speed_gain_per_gem = float(profile.get("glutton_speed_gain_per_gem", enemy.glutton_speed_gain_per_gem))
	enemy.glutton_scale_gain_per_gem = float(profile.get("glutton_scale_gain_per_gem", enemy.glutton_scale_gain_per_gem))
	enemy.glutton_max_bonus_speed = float(profile.get("glutton_max_bonus_speed", enemy.glutton_max_bonus_speed))
	enemy.rebirth_lives_remaining = int(profile.get("rebirth_lives", enemy.rebirth_lives_remaining))
	enemy.rebirth_delay = float(profile.get("rebirth_delay", enemy.rebirth_delay))
	enemy.rebirth_slow_multiplier = float(profile.get("rebirth_slow_multiplier", enemy.rebirth_slow_multiplier))
	enemy.rebirth_slow_duration = float(profile.get("rebirth_slow_duration", enemy.rebirth_slow_duration))
	enemy.turret_bombard_interval = float(profile.get("turret_bombard_interval", enemy.turret_bombard_interval))
	enemy.turret_bombard_radius = float(profile.get("turret_bombard_radius", enemy.turret_bombard_radius))
	enemy.turret_bombard_projectiles = int(profile.get("turret_bombard_projectiles", enemy.turret_bombard_projectiles))

	var scale_value: float = float(profile.get("scale", 1.0))
	enemy.scale = enemy.base_scale * scale_value
	enemy.display_color = profile.get("color", enemy.display_color) if profile.has("color") else enemy.display_color
	enemy.profile_initialized = true
