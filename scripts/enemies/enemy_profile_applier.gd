extends RefCounted

const ENEMY_DIRECTOR := preload("res://scripts/enemy/enemy_director.gd")
const ENEMY_BOSS_STATE := preload("res://scripts/enemies/enemy_boss_state.gd")
const ENEMY_MUSHROOM_SWARM := preload("res://scripts/enemies/enemy_mushroom_swarm.gd")

static func apply_profile(enemy, kind: String, profile: Dictionary) -> void:
	enemy.heavy_armor_remaining = 0.0
	preload("res://scripts/enemies/enemy_heavy_armor_form.gd").sync_visual(enemy)
	enemy.enemy_kind = kind
	enemy.archetype_id = str(profile.get("archetype", enemy.archetype_id))
	enemy.heavy_armor_cooldown = preload("res://scripts/enemies/enemy_heavy_armor_form.gd").get_cooldown(enemy)
	enemy.behavior_id = str(profile.get("behavior", enemy.behavior_id))
	enemy.secondary_behavior_id = str(profile.get("secondary_behavior", ""))
	enemy.profile_visual_scene = profile.get("visual_scene", null) as PackedScene
	enemy.max_health = float(profile.get("max_health", enemy.max_health))
	enemy.damage_reduction_value = float(profile.get("damage_reduction_value", 0.0))
	enemy.armor = float(profile.get("armor", 0.0))
	enemy.attack = max(0.0, float(profile.get("attack", enemy.attack)))
	enemy.damage_reduction_rate = clampf(float(profile.get("damage_reduction_rate", 0.0)), 0.0, 1.0)
	enemy.stalwart_body_cooldown = 0.0
	enemy.current_health = enemy.max_health
	enemy.boss_shield_max_health = max(0.0, float(profile.get("boss_shield_max_health", 0.0)))
	if kind == "boss":
		enemy.current_health = ENEMY_BOSS_STATE.get_boss_spawn_health(enemy)
	enemy.speed = float(profile.get("speed", enemy.speed))
	enemy.touch_damage = float(profile.get("touch_damage", enemy.touch_damage))
	enemy.contact_radius = float(profile.get("contact_radius", enemy.contact_radius))
	var raw_body_collision_radius: float = float(profile.get("body_collision_radius", -1.0))
	enemy.body_collision_radius = raw_body_collision_radius * ENEMY_DIRECTOR.get_body_collision_radius_multiplier() if raw_body_collision_radius > 0.0 else raw_body_collision_radius
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
	enemy.projectile_visual_style = str(profile.get("projectile_visual_style", ""))
	enemy.projectile_split_count = int(profile.get("projectile_split_count", 0))
	enemy.projectile_split_after = float(profile.get("projectile_split_after", 0.0))
	enemy.projectile_split_spread = float(profile.get("projectile_split_spread", 1.2))
	enemy.projectile_split_pattern = str(profile.get("projectile_split_pattern", "fan"))
	enemy.projectile_split_speed_scale = float(profile.get("projectile_split_speed_scale", 0.88))
	enemy.projectile_split_damage_scale = float(profile.get("projectile_split_damage_scale", 0.72))
	enemy.projectile_split_lifetime_scale = float(profile.get("projectile_split_lifetime_scale", 0.72))
	enemy.projectile_split_size_scale = float(profile.get("projectile_split_size_scale", 0.75))
	enemy.projectile_split_hit_radius_scale = float(profile.get("projectile_split_hit_radius_scale", 0.8))

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
	enemy.glutton_aura_radius = float(profile.get("glutton_aura_radius", enemy.glutton_absorb_radius))
	enemy.glutton_aura_damage = float(profile.get("glutton_aura_damage", 0.0))
	enemy.glutton_heart_heal_scale = float(profile.get("glutton_heart_heal_scale", 1.0))
	enemy.glutton_bonus_speed = 0.0
	enemy.rebirth_lives_remaining = int(profile.get("rebirth_lives", 0))
	enemy.rebirth_delay = float(profile.get("rebirth_delay", 2.0))
	enemy.rebirth_slow_multiplier = float(profile.get("rebirth_slow_multiplier", 0.5))
	enemy.rebirth_slow_duration = float(profile.get("rebirth_slow_duration", 6.0))
	enemy.skulltomb_summon_interval = float(profile.get("skulltomb_summon_interval", 20.0))
	enemy.skulltomb_aging_aura_radius = max(0.0, float(profile.get("skulltomb_aging_aura_radius", 750.0)))
	enemy.skulltomb_aging_aura_current_health_drain_ratio = clamp(float(profile.get("skulltomb_aging_aura_current_health_drain_ratio", 0.12)), 0.0, 1.0)
	enemy.skulltomb_aging_aura_max_health_damage_ratio = clampf(float(profile.get("skulltomb_aging_aura_max_health_damage_ratio", 0.005)), 0.0, 1.0)
	enemy.skulltomb_summon_timer = enemy.skulltomb_summon_interval
	enemy.skulltomb_summon_windup = float(profile.get("skulltomb_summon_windup", 0.7))
	enemy.skulltomb_summon_windup_remaining = 0.0
	enemy.skulltomb_charge_interval = float(profile.get("skulltomb_charge_interval", 9.0))
	enemy.skulltomb_charge_timer = enemy.skulltomb_charge_interval
	enemy.skulltomb_charge_decision_timer = 0.0
	enemy.skulltomb_charge_active = false
	enemy.skulltomb_charge_windup_duration = float(profile.get("skulltomb_charge_windup_duration", 2.0))
	enemy.skulltomb_charge_windup_remaining = 0.0
	enemy.skulltomb_charge_distance = float(profile.get("skulltomb_charge_distance", 0.0))
	enemy.skulltomb_charge_speed_multiplier = float(profile.get("skulltomb_charge_speed_multiplier", 2.0))
	enemy.skulltomb_charge_push_distance = float(profile.get("skulltomb_charge_push_distance", 116.0))
	enemy.skulltomb_min_soldiers = int(profile.get("skulltomb_min_soldiers", 10))
	enemy.skulltomb_buff_duration = float(profile.get("skulltomb_buff_duration", 5.0))
	enemy.skulltomb_death_player_slow_multiplier = float(profile.get("skulltomb_death_player_slow_multiplier", 0.25))
	enemy.skulltomb_death_player_slow_duration = float(profile.get("skulltomb_death_player_slow_duration", 5.0))
	enemy.skulltomb_death_soldier_speed_multiplier = float(profile.get("skulltomb_death_soldier_speed_multiplier", 1.2))
	enemy.skulltomb_death_shot_frequency_multiplier = float(profile.get("skulltomb_death_shot_frequency_multiplier", 1.3))
	enemy.skulltomb_tomb_scene = profile.get("skulltomb_tomb_scene", null) as PackedScene
	enemy.skull_soldier_speed_multiplier = 1.0
	enemy.skull_soldier_speed_timer = 0.0
	enemy.skull_damage_immune_timer = 0.0
	enemy.skullshot_attack_frequency_multiplier = 1.0
	enemy.skullshot_attack_frequency_timer = 0.0
	enemy.turret_bombard_interval = float(profile.get("turret_bombard_interval", 0.0))
	enemy.turret_bombard_radius = float(profile.get("turret_bombard_radius", 96.0))
	enemy.turret_bombard_projectiles = int(profile.get("turret_bombard_projectiles", 8))

	var scale_value: float = float(profile.get("scale", 1.0))
	enemy.scale = enemy.base_scale * scale_value
	enemy.body_collision_reference_scale = max(0.001, max(abs(enemy.scale.x), abs(enemy.scale.y)))
	enemy.display_color = profile.get("color", enemy.display_color) if profile.has("color") else enemy.display_color
	enemy.profile_initialized = true
	ENEMY_MUSHROOM_SWARM.invalidate_cache()
