extends SceneTree

const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")

const EXPECTED := {
	"chaser": {
		"behavior": "chaser",
		"max_health": 28.0,
		"speed": 61.6,
		"touch_damage": 10.0,
		"contact_radius": 42.0,
		"body_collision_radius": 30.0,
		"reward_tier": 1,
		"experience_reward": 4,
		"scale": 1.0,
		"visual_scene": "res://assets/enemies/Mushroom/mushroom.tscn"
	},
	"shooter": {
		"behavior": "shooter",
		"max_health": 24.0,
		"speed": 68.0,
		"touch_damage": 8.0,
		"contact_radius": 34.0,
		"body_collision_radius": 40.6,
		"reward_tier": 1,
		"experience_reward": 6,
		"scale": 0.672,
		"preferred_distance": 240.0,
		"shot_interval": 2.6,
		"projectile_speed": 220.0,
		"projectile_damage": 7.0,
		"projectile_lifetime": 4.2,
		"projectile_spread": 0.0,
		"projectile_count": 1,
		"visual_scene": "res://assets/enemies/skull/skull-soilder.tscn"
	},
	"brute": {
		"behavior": "chaser",
		"max_health": 56.0,
		"speed": 72.0,
		"touch_damage": 14.0,
		"contact_radius": 40.0,
		"body_collision_radius": 44.0,
		"reward_tier": 2,
		"experience_reward": 10,
		"scale": 1.22,
		"visual_scene": "res://assets/enemies/pumpkin/pumpkin.tscn"
	},
	"runner": {
		"behavior": "chaser",
		"max_health": 16.0,
		"speed": 126.0,
		"touch_damage": 8.0,
		"contact_radius": 38.0,
		"body_collision_radius": 40.8,
		"reward_tier": 1,
		"experience_reward": 5,
		"scale": 0.82,
		"visual_scene": "res://assets/enemies/slime/Slime.tscn"
	},
	"swarm": {
		"behavior": "swarm",
		"max_health": 10.0,
		"speed": 162.0,
		"touch_damage": 6.0,
		"contact_radius": 24.0,
		"body_collision_radius": 30.0,
		"reward_tier": 1,
		"experience_reward": 3,
		"scale": 0.68,
		"visual_scene": "res://assets/enemies/flyingeye/flyingeye.tscn"
	},
	"dasher": {
		"behavior": "dash",
		"max_health": 54.0,
		"speed": 80.0,
		"touch_damage": 16.0,
		"contact_radius": 42.0,
		"body_collision_radius": 42.0,
		"reward_tier": 2,
		"experience_reward": 12,
		"scale": 1.18,
		"dash_interval": 3.1,
		"dash_duration": 0.42,
		"dash_speed_multiplier": 3.2,
		"dash_windup_duration": 0.6
	},
	"shotgunner": {
		"behavior": "shooter",
		"max_health": 76.0,
		"speed": 70.0,
		"touch_damage": 16.0,
		"contact_radius": 48.0,
		"body_collision_radius": 51.8,
		"reward_tier": 3,
		"experience_reward": 16,
		"scale": 0.896,
		"preferred_distance": 210.0,
		"shot_interval": 2.55,
		"projectile_speed": 240.0,
		"projectile_damage": 8.0,
		"projectile_lifetime": 4.6,
		"projectile_spread": 0.22,
		"projectile_count": 5,
		"visual_scene": "res://assets/enemies/skull/skullshotgunner.tscn"
	},
	"elite_ram_trail": {
		"behavior": "dash",
		"boss_name": "裂地重锤",
		"max_health": 420.0,
		"speed": 82.0,
		"touch_damage": 28.0,
		"contact_radius": 52.0,
		"body_collision_radius": 56.0,
		"reward_tier": 4,
		"experience_reward": 45,
		"scale": 1.84,
		"dash_interval": 2.4,
		"dash_duration": 0.58,
		"dash_speed_multiplier": 3.45,
		"dash_windup_duration": 0.72
	},
	"elite_splitshot": {
		"behavior": "shooter",
		"boss_name": "碎幕炮台",
		"max_health": 380.0,
		"speed": 74.0,
		"touch_damage": 22.0,
		"contact_radius": 56.0,
		"body_collision_radius": 102.0,
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
		"visual_scene": "res://assets/enemies/skull/SkullElite.tscn"
	},
	"smallboss_glutton": {
		"behavior": "glutton",
		"boss_name": "吞晶巨核",
		"max_health": 1320.0,
		"speed": 40.0,
		"touch_damage": 24.0,
		"contact_radius": 62.0,
		"body_collision_radius": 68.0,
		"reward_tier": 4,
		"experience_reward": 60,
		"scale": 2.05,
		"glutton_absorb_radius": 190.0,
		"glutton_speed_gain_per_gem": 3.8,
		"glutton_scale_gain_per_gem": 0.018,
		"glutton_max_bonus_speed": 120.0,
		"visual_scene": "res://assets/enemies/treeboss/treeboss.tscn"
	},
	"smallboss_rebirth": {
		"behavior": "rebirth",
		"boss_name": "三命诡影",
		"max_health": 980.0,
		"speed": 88.0,
		"touch_damage": 20.0,
		"contact_radius": 50.0,
		"body_collision_radius": 54.0,
		"reward_tier": 4,
		"experience_reward": 60,
		"scale": 1.72,
		"rebirth_lives": 2,
		"rebirth_delay": 2.0,
		"rebirth_slow_multiplier": 0.5,
		"rebirth_slow_duration": 6.0
	},
	"smallboss_turret": {
		"behavior": "turret",
		"secondary_behavior": "shooter",
		"boss_name": "定点灾台",
		"max_health": 1120.0,
		"speed": 0.0,
		"touch_damage": 16.0,
		"contact_radius": 54.0,
		"body_collision_radius": 58.0,
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
		"turret_bombard_projectiles": 10
	},
	"boss_spellcore": {
		"behavior": "boss",
		"boss_name": "祸月星核",
		"max_health": 4800.0,
		"speed": 78.0,
		"touch_damage": 28.0,
		"contact_radius": 64.0,
		"body_collision_radius": 70.0,
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
		"boss_turning_bullets": 9
	}
}


func _init() -> void:
	var failures: Array[String] = []
	for archetype in EXPECTED.keys():
		_check_profile(archetype, EXPECTED[archetype] as Dictionary, failures)
	if failures.is_empty():
		print("enemy_profile_snapshot_smoke: OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_profile(archetype: String, expected: Dictionary, failures: Array[String]) -> void:
	var actual: Dictionary = ENEMY_ARCHETYPE_DATABASE.get_profile("normal", archetype)
	if str(actual.get("archetype", "")) != archetype:
		failures.append("%s archetype mismatch: %s" % [archetype, str(actual.get("archetype", ""))])
	for key in expected.keys():
		if key == "visual_scene":
			_check_visual_scene(archetype, actual, str(expected[key]), failures)
			continue
		if not actual.has(key):
			failures.append("%s missing %s" % [archetype, key])
			continue
		var expected_value: Variant = expected[key]
		var actual_value: Variant = actual[key]
		if expected_value is float:
			if not is_equal_approx(float(actual_value), expected_value):
				failures.append("%s %s expected %.4f got %.4f" % [archetype, key, expected_value, float(actual_value)])
		elif actual_value != expected_value:
			failures.append("%s %s expected %s got %s" % [archetype, key, str(expected_value), str(actual_value)])


func _check_visual_scene(archetype: String, actual: Dictionary, expected_path: String, failures: Array[String]) -> void:
	if not actual.has("visual_scene"):
		failures.append("%s missing visual_scene" % archetype)
		return
	var scene := actual.get("visual_scene", null) as PackedScene
	if scene == null:
		failures.append("%s visual_scene is not PackedScene" % archetype)
		return
	if scene.resource_path != expected_path:
		failures.append("%s visual_scene expected %s got %s" % [archetype, expected_path, scene.resource_path])
