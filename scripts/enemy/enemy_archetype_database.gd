extends RefCounted

static func get_profile(_kind: String, archetype: String) -> Dictionary:
	match archetype:
		"shooter":
			return _make_profile({
				"archetype": "shooter",
				"behavior": "shooter",
				"max_health": 24.0,
				"speed": 68.0,
				"touch_damage": 8.0,
				"contact_radius": 34.0,
				"reward_tier": 1,
				"experience_reward": 6,
				"scale": 0.96,
				"preferred_distance": 240.0,
				"shot_interval": 2.6,
				"projectile_speed": 220.0,
				"projectile_damage": 7.0,
				"projectile_lifetime": 4.2,
				"projectile_spread": 0.0,
				"projectile_count": 1,
				"color": Color(1.0, 0.54, 0.32, 1.0),
				"boss_name": "远程怪"
			})
		"brute":
			return _make_profile({
				"archetype": "brute",
				"behavior": "chaser",
				"max_health": 56.0,
				"speed": 72.0,
				"touch_damage": 14.0,
				"contact_radius": 40.0,
				"reward_tier": 2,
				"experience_reward": 10,
				"scale": 1.22,
				"color": Color(0.96, 0.8, 0.28, 1.0)
			})
		"runner":
			return _make_profile({
				"archetype": "runner",
				"behavior": "chaser",
				"max_health": 16.0,
				"speed": 126.0,
				"touch_damage": 8.0,
				"contact_radius": 38.0,
				"reward_tier": 1,
				"experience_reward": 5,
				"scale": 0.82,
				"color": Color(0.72, 0.96, 1.0, 1.0)
			})
		"swarm":
			return _make_profile({
				"archetype": "swarm",
				"behavior": "swarm",
				"max_health": 10.0,
				"speed": 162.0,
				"touch_damage": 6.0,
				"contact_radius": 24.0,
				"reward_tier": 1,
				"experience_reward": 3,
				"scale": 0.68,
				"color": Color(0.84, 0.96, 1.0, 1.0)
			})
		"dasher":
			return _make_profile({
				"archetype": "dasher",
				"behavior": "dash",
				"max_health": 54.0,
				"speed": 80.0,
				"touch_damage": 16.0,
				"contact_radius": 42.0,
				"reward_tier": 2,
				"experience_reward": 12,
				"scale": 1.18,
				"dash_interval": 3.1,
				"dash_duration": 0.42,
				"dash_speed_multiplier": 3.2,
				"dash_windup_duration": 0.6,
				"color": Color(1.0, 0.36, 0.42, 1.0)
			})
		"shotgunner":
			return _make_profile({
				"archetype": "shotgunner",
				"behavior": "shooter",
				"max_health": 76.0,
				"speed": 70.0,
				"touch_damage": 16.0,
				"contact_radius": 48.0,
				"reward_tier": 3,
				"experience_reward": 16,
				"scale": 1.28,
				"preferred_distance": 210.0,
				"shot_interval": 2.55,
				"projectile_speed": 240.0,
				"projectile_damage": 8.0,
				"projectile_lifetime": 4.6,
				"projectile_spread": 0.22,
				"projectile_count": 5,
				"color": Color(1.0, 0.62, 0.32, 1.0)
			})
		"elite_ram_trail":
			return _make_profile({
				"archetype": "elite_ram_trail",
				"behavior": "dash",
				"max_health": 420.0,
				"speed": 82.0,
				"touch_damage": 28.0,
				"contact_radius": 52.0,
				"reward_tier": 4,
				"experience_reward": 45,
				"scale": 1.84,
				"dash_interval": 2.4,
				"dash_duration": 0.58,
				"dash_speed_multiplier": 3.45,
				"dash_windup_duration": 0.72,
				"color": Color(1.0, 0.42, 0.36, 1.0),
				"boss_name": "裂地重锤"
			})
		"elite_splitshot":
			return _make_profile({
				"archetype": "elite_splitshot",
				"behavior": "shooter",
				"max_health": 380.0,
				"speed": 74.0,
				"touch_damage": 22.0,
				"contact_radius": 56.0,
				"reward_tier": 4,
				"experience_reward": 45,
				"scale": 1.76,
				"preferred_distance": 230.0,
				"shot_interval": 2.2,
				"projectile_speed": 250.0,
				"projectile_damage": 10.0,
				"projectile_lifetime": 4.8,
				"projectile_spread": 0.18,
				"projectile_count": 5,
				"projectile_split_count": 4,
				"projectile_split_after": 0.48,
				"projectile_split_spread": 1.2,
				"color": Color(1.0, 0.7, 0.34, 1.0),
				"boss_name": "碎幕炮台"
			})
		"smallboss_glutton":
			return _make_profile({
				"archetype": "smallboss_glutton",
				"behavior": "glutton",
				"boss_name": "吞晶巨核",
				"max_health": 1320.0,
				"speed": 40.0,
				"touch_damage": 24.0,
				"contact_radius": 62.0,
				"reward_tier": 4,
				"experience_reward": 60,
				"scale": 2.05,
				"glutton_absorb_radius": 190.0,
				"glutton_speed_gain_per_gem": 3.8,
				"glutton_scale_gain_per_gem": 0.018,
				"glutton_max_bonus_speed": 120.0,
				"color": Color(0.62, 0.92, 1.0, 1.0)
			})
		"smallboss_rebirth":
			return _make_profile({
				"archetype": "smallboss_rebirth",
				"behavior": "rebirth",
				"boss_name": "三命诡影",
				"max_health": 980.0,
				"speed": 88.0,
				"touch_damage": 20.0,
				"contact_radius": 50.0,
				"reward_tier": 4,
				"experience_reward": 60,
				"scale": 1.72,
				"rebirth_lives": 2,
				"rebirth_delay": 2.0,
				"rebirth_slow_multiplier": 0.5,
				"rebirth_slow_duration": 6.0,
				"color": Color(0.78, 0.64, 1.0, 1.0)
			})
		"smallboss_turret":
			return _make_profile({
				"archetype": "smallboss_turret",
				"behavior": "turret",
				"secondary_behavior": "shooter",
				"boss_name": "定点灾台",
				"max_health": 1120.0,
				"speed": 0.0,
				"touch_damage": 16.0,
				"contact_radius": 54.0,
				"reward_tier": 4,
				"experience_reward": 60,
				"scale": 1.95,
				"preferred_distance": 0.0,
				"shot_interval": 1.1,
				"projectile_speed": 320.0,
				"projectile_damage": 10.0,
				"projectile_lifetime": 4.4,
				"projectile_spread": 0.14,
				"projectile_count": 3,
				"turret_bombard_interval": 3.3,
				"turret_bombard_radius": 112.0,
				"turret_bombard_projectiles": 10,
				"color": Color(1.0, 0.42, 0.24, 1.0)
			})
		"boss_spellcore":
			return _make_profile({
				"archetype": "boss_spellcore",
				"behavior": "boss",
				"boss_name": "祸月星核",
				"max_health": 4800.0,
				"speed": 78.0,
				"touch_damage": 28.0,
				"contact_radius": 64.0,
				"reward_tier": 4,
				"experience_reward": 40,
				"scale": 2.35,
				"preferred_distance": 230.0,
				"projectile_damage": 13.5,
				"boss_radial_interval": 0.78,
				"boss_radial_bullets": 16,
				"boss_sine_interval": 2.9,
				"boss_sine_stream_duration": 1.7,
				"boss_sine_stream_rate": 0.12,
				"boss_turning_interval": 4.2,
				"boss_turning_bullets": 9,
				"color": Color(0.95, 0.2, 0.24, 1.0)
			})
		_:
			return _make_profile({
				"archetype": "chaser",
				"behavior": "chaser",
				"max_health": 28.0,
				"speed": 88.0 * 0.7,
				"touch_damage": 10.0,
				"contact_radius": 42.0,
				"reward_tier": 1,
				"experience_reward": 4,
				"scale": 1.0,
				"color": Color(0.34, 0.8, 1.0, 1.0)
			})

static func get_boss_options() -> Array:
	return [
		{
			"id": "boss_spellcore",
			"title": "Boss+1",
			"description": "生成当前 Boss",
			"current_level": 0,
			"max_level": 1,
			"enabled": true
		}
	]

static func get_boss_archetypes() -> Array[String]:
	return ["boss_spellcore"]

static func get_small_boss_archetypes() -> Array[String]:
	return ["smallboss_glutton", "smallboss_rebirth", "smallboss_turret"]

static func is_boss_archetype(archetype: String) -> bool:
	return get_boss_archetypes().has(archetype)

static func is_small_boss_archetype(archetype: String) -> bool:
	return get_small_boss_archetypes().has(archetype)

static func _make_profile(base: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var merged := base.duplicate(true)
	for key in extra.keys():
		merged[key] = extra[key]
	return merged
