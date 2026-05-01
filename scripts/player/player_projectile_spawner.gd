extends RefCounted

static func apply_role_projectile_modifiers(owner, projectile: Node, role_id: String) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	if role_id != "gunner":
		return
	var barrage_level: float = 0.0
	if barrage_level <= 0:
		return
	projectile.set("speed_multiplier", owner._get_gunner_barrage_speed_multiplier(barrage_level))
	projectile.set("bounce_count", owner._get_gunner_barrage_bounce_count(barrage_level))
	if owner.has_method("_get_gunner_barrage_split_count"):
		projectile.set("split_count", owner._get_gunner_barrage_split_count(barrage_level))
	projectile.set("hit_radius_multiplier", 1.2)

static func spawn_bullet(owner, bullet_scene: PackedScene, target_enemy: Node2D, damage_amount: float, color: Color, role_id: String = "", origin: Variant = null):
	if bullet_scene == null:
		return null
	var bullet = bullet_scene.instantiate()
	if bullet == null:
		return null
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		return null

	current_scene.add_child(bullet)
	bullet.global_position = origin if origin is Vector2 else owner.global_position
	bullet.source_origin_position = bullet.global_position
	bullet.direction = bullet.global_position.direction_to(target_enemy.global_position)
	bullet.target = target_enemy
	bullet.damage = damage_amount
	bullet.visual_color = color
	bullet.source_player = owner
	bullet.source_role_id = role_id if role_id != "" else owner._get_active_role()["id"]
	apply_role_projectile_modifiers(owner, bullet, str(bullet.source_role_id))
	return bullet

static func spawn_directional_bullet(owner, bullet_scene: PackedScene, direction: Vector2, damage_amount: float, color: Color, role_id: String = "", origin: Variant = null):
	return spawn_directional_bullet_from_scene(owner, bullet_scene, direction, damage_amount, color, role_id, origin)

static func spawn_directional_bullet_from_scene(owner, projectile_scene: PackedScene, direction: Vector2, damage_amount: float, color: Color, role_id: String = "", origin: Variant = null):
	if projectile_scene == null:
		return null
	var bullet = projectile_scene.instantiate()
	if bullet == null:
		return null
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		return null

	current_scene.add_child(bullet)
	bullet.global_position = origin if origin is Vector2 else owner.global_position
	bullet.source_origin_position = bullet.global_position
	bullet.direction = direction.normalized()
	bullet.target = null
	bullet.damage = damage_amount
	bullet.visual_color = color
	bullet.source_player = owner
	bullet.source_role_id = role_id if role_id != "" else owner._get_active_role()["id"]
	apply_role_projectile_modifiers(owner, bullet, str(bullet.source_role_id))
	return bullet
