extends RefCounted

static func apply_profile(enemy, kind: String, profile: Dictionary) -> void:
	enemy.enemy_kind = kind
	enemy.archetype_id = str(profile.get("archetype", enemy.archetype_id))
	enemy.behavior_id = str(profile.get("behavior", enemy.behavior_id))
	enemy.secondary_behavior_id = str(profile.get("secondary_behavior", ""))
	enemy.profile_visual_scene = profile.get("visual_scene", null) as PackedScene
	enemy.max_health = float(profile.get("max_health", enemy.max_health))
	enemy.current_health = enemy.max_health
	enemy.speed = float(profile.get("speed", enemy.speed))
	enemy.touch_damage = float(profile.get("touch_damage", enemy.touch_damage))
	enemy.contact_radius = float(profile.get("contact_radius", enemy.contact_radius))
	enemy.body_collision_radius = float(profile.get("body_collision_radius", -1.0))
	enemy.experience_reward = int(profile.get("experience_reward", enemy.experience_reward))
	enemy.reward_tier = clamp(int(profile.get("reward_tier", enemy.reward_tier)), 1, 4)

	enemy.preferred_distance = float(profile.get("preferred_distance", enemy.preferred_distance))
	enemy.shot_interval = float(profile.get("shot_interval", enemy.shot_interval))
	enemy.projectile_speed = float(profile.get("projectile_speed", enemy.projectile_speed))
	enemy.projectile_damage = float(profile.get("projectile_damage", enemy.projectile_damage))
	enemy.projectile_lifetime = float(profile.get("projectile_lifetime", enemy.projectile_lifetime))
	enemy.projectile_spread = float(profile.get("projectile_spread", enemy.projectile_spread))
	enemy.projectile_count = int(profile.get("projectile_count", enemy.projectile_count))
	enemy.projectile_color = profile.get("projectile_color", Color(-1.0, -1.0, -1.0, -1.0)) if profile.has("projectile_color") else Color(-1.0, -1.0, -1.0, -1.0)
	enemy.projectile_split_count = int(profile.get("projectile_split_count", 0))
	enemy.projectile_split_after = float(profile.get("projectile_split_after", 0.0))
	enemy.projectile_split_spread = float(profile.get("projectile_split_spread", 1.2))

	enemy.acceleration_interval = float(profile.get("acceleration_interval", 0.0))
	enemy.acceleration_boost = float(profile.get("acceleration_boost", 1.8))
	enemy.acceleration_duration = float(profile.get("acceleration_duration", 0.0))
	enemy.dash_interval = float(profile.get("dash_interval", 0.0))
	enemy.dash_duration = float(profile.get("dash_duration", 0.0))
	enemy.dash_speed_multiplier = float(profile.get("dash_speed_multiplier", 2.4))
	enemy.dash_windup_duration = float(profile.get("dash_windup_duration", 0.42))

	enemy.boss_radial_interval = float(profile.get("boss_radial_interval", 0.95))
	enemy.boss_radial_bullets = int(profile.get("boss_radial_bullets", 12))
	enemy.boss_sine_interval = float(profile.get("boss_sine_interval", 3.2))
	enemy.boss_sine_stream_duration = float(profile.get("boss_sine_stream_duration", 1.6))
	enemy.boss_sine_stream_rate = float(profile.get("boss_sine_stream_rate", 0.14))
	enemy.boss_turning_interval = float(profile.get("boss_turning_interval", 4.0))
	enemy.boss_turning_bullets = int(profile.get("boss_turning_bullets", 8))
	enemy.boss_display_name = str(profile.get("boss_name", enemy.boss_display_name))
	enemy.boss_attack_pressure_scale = float(profile.get("boss_attack_pressure_scale", 1.0))

	enemy.glutton_absorb_radius = float(profile.get("glutton_absorb_radius", 0.0))
	enemy.glutton_speed_gain_per_gem = float(profile.get("glutton_speed_gain_per_gem", 0.0))
	enemy.glutton_scale_gain_per_gem = float(profile.get("glutton_scale_gain_per_gem", 0.0))
	enemy.glutton_max_bonus_speed = float(profile.get("glutton_max_bonus_speed", 0.0))
	enemy.glutton_bonus_speed = 0.0
	enemy.rebirth_lives_remaining = int(profile.get("rebirth_lives", 0))
	enemy.rebirth_delay = float(profile.get("rebirth_delay", 2.0))
	enemy.rebirth_slow_multiplier = float(profile.get("rebirth_slow_multiplier", 0.5))
	enemy.rebirth_slow_duration = float(profile.get("rebirth_slow_duration", 6.0))
	enemy.turret_bombard_interval = float(profile.get("turret_bombard_interval", 0.0))
	enemy.turret_bombard_radius = float(profile.get("turret_bombard_radius", 96.0))
	enemy.turret_bombard_projectiles = int(profile.get("turret_bombard_projectiles", 8))

	var scale_value: float = float(profile.get("scale", 1.0))
	enemy.scale = enemy.base_scale * scale_value
	enemy.body_collision_reference_scale = max(0.001, max(abs(enemy.scale.x), abs(enemy.scale.y)))
	enemy.display_color = profile.get("color", enemy.display_color) if profile.has("color") else enemy.display_color
	enemy.profile_initialized = true
