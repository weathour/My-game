extends RefCounted

const ENEMY_VISUAL_DATA := preload("res://scripts/enemies/enemy_visual_data.gd")
const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")
const NON_BOSS_PROJECTILE_SPEED_MULTIPLIER := 0.6

static func fire_shooter_pattern(enemy) -> void:
	if enemy.target == null or not is_instance_valid(enemy.target):
		return
	var aim_direction: Vector2 = enemy.global_position.direction_to(enemy.target.global_position)
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT
	var start_position: Vector2 = enemy.global_position + aim_direction * (22.0 + enemy.scale.x * 4.0)
	var count: int = max(1, enemy.projectile_count)
	var spread_step: float = enemy.projectile_spread
	var offset_center: float = float(count - 1) * 0.5
	for index in range(count):
		var shot_direction: Vector2 = aim_direction.rotated((float(index) - offset_center) * spread_step)
		var extra_config: Dictionary = {}
		if enemy.projectile_split_count > 0 and enemy.projectile_split_after > 0.0:
			extra_config = {
				"split_count": enemy.projectile_split_count,
				"split_after_time": enemy.projectile_split_after,
				"split_pattern": "fan",
				"split_spread": enemy.projectile_split_spread,
				"split_speed": enemy.projectile_speed * 0.88,
				"split_damage_scale": 0.72,
				"split_lifetime": max(1.6, enemy.projectile_lifetime * 0.72),
				"split_motion_mode": "straight",
				"size_scale": 0.92
			}
		spawn_projectile(
			enemy,
			start_position,
			shot_direction,
			enemy.projectile_speed,
			enemy.projectile_damage,
			enemy.projectile_lifetime,
			get_projectile_color(enemy),
			"straight",
			extra_config
		)
	var projectile_color := get_projectile_color(enemy)
	enemy._spawn_status_burst(Color(projectile_color.r, projectile_color.g, projectile_color.b, 0.18), 16.0 + enemy.scale.x * 4.0)

static func spawn_projectile(enemy, origin: Vector2, shot_direction: Vector2, shot_speed: float, shot_damage: float, shot_lifetime: float, color: Color, mode: String, extra_config: Dictionary = {}) -> void:
	if enemy.projectile_scene == null:
		return
	var current_scene: Node = enemy.get_tree().current_scene
	if current_scene == null:
		return
	if not PERFORMANCE_GUARD.can_spawn_in_group(current_scene, "enemy_projectiles", _get_enemy_projectile_limit(enemy)):
		return
	var projectile = enemy.projectile_scene.instantiate()
	if projectile == null:
		return
	projectile.global_position = origin
	projectile.direction = shot_direction.normalized()
	var speed_multiplier := NON_BOSS_PROJECTILE_SPEED_MULTIPLIER if str(enemy.enemy_kind) != "boss" else 1.0
	projectile.speed = shot_speed * speed_multiplier
	projectile.damage = shot_damage
	projectile.lifetime = shot_lifetime
	projectile.visual_color = color
	projectile.motion_mode = mode
	projectile.target = enemy.target
	for key in extra_config.keys():
		if key in ["split_speed", "return_speed"]:
			projectile.set(key, float(extra_config[key]) * speed_multiplier)
		else:
			projectile.set(key, extra_config[key])
	current_scene.add_child(projectile)

static func get_projectile_color(enemy) -> Color:
	return ENEMY_VISUAL_DATA.get_projectile_color(enemy.archetype_id)

static func _get_enemy_projectile_limit(enemy) -> int:
	var current_scene: Node = enemy.get_tree().current_scene if enemy != null and enemy.get_tree() != null else null
	if current_scene != null and current_scene.has_method("_get_difficulty_limit"):
		return int(current_scene._get_difficulty_limit("enemy_projectile_limit", PERFORMANCE_GUARD.DEFAULT_ENEMY_PROJECTILE_LIMIT))
	return PERFORMANCE_GUARD.DEFAULT_ENEMY_PROJECTILE_LIMIT
