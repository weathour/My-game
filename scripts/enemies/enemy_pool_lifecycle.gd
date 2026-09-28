extends RefCounted


static func activate_pooled_enemy(enemy) -> void:
	enemy.pooled_inactive = false
	register_runtime_enemy(enemy)


static func release_after_defeat(enemy) -> bool:
	if str(enemy.enemy_kind) != "normal":
		return false
	if not enemy.is_inside_tree():
		return false
	var scene: Node = enemy.get_tree().current_scene
	if scene == null or not scene.has_method("release_runtime_enemy"):
		return false
	prepare_for_pool(enemy)
	scene.release_runtime_enemy(enemy)
	return true


static func prepare_for_pool(enemy) -> void:
	enemy.pooled_inactive = true
	enemy.velocity = Vector2.ZERO
	enemy.separation_push = Vector2.ZERO
	enemy.cached_separation_velocity = Vector2.ZERO
	enemy.throttled_motion_delta = 0.0
	enemy.slow_multiplier = 1.0
	enemy.slow_timer = 0.0
	enemy.damage_reduction_value = 0.0
	enemy.armor = 0.0
	enemy.attack = 0.0
	enemy.damage_reduction_rate = 0.0
	enemy.stalwart_body_cooldown = 0.0
	enemy.basic_shot_timer = 0.0
	enemy.dash_distance_remaining = 0.0
	enemy.elite_charge_haste_remaining = 0.0
	enemy.heavy_armor_remaining = 0.0
	enemy.heavy_armor_cooldown = preload("res://scripts/enemies/enemy_heavy_armor_form.gd").get_cooldown(enemy)
	preload("res://scripts/enemies/enemy_runner_haste.gd").reset(enemy)
	preload("res://scripts/enemies/enemy_heavy_armor_form.gd").sync_visual(enemy)
	enemy.vulnerability_bonus = 0.0
	enemy.fury_armor_shred = 0.0
	enemy.fury_armor_shred_remaining = 0.0
	enemy.vulnerability_timer = 0.0
	enemy.bleed_damage_per_second = 0.0
	enemy.bleed_timer = 0.0
	enemy.drop_absorber = null
	enemy.hit_flash_remaining = 0.0
	enemy.status_visual_time = 0.0
	enemy.status_visual_refresh_frame = -1
	enemy.separation_refresh_frame = -1
	enemy.motion_refresh_frame = -1
	if enemy.status_root != null and is_instance_valid(enemy.status_root):
		enemy.status_root.queue_free()
	enemy.status_root = null
	enemy.slow_ring = null
	enemy.vulnerability_ring = null
	enemy.trait_ring = null
	enemy.dash_warning_ring = null
	enemy.dash_warning_rect = null
	if enemy.boss_visual_instance != null and is_instance_valid(enemy.boss_visual_instance):
		enemy.boss_visual_instance.queue_free()
	enemy.boss_visual_instance = null
	enemy.cached_motion_visual = null
	enemy.cached_motion_visual_moving = false
	enemy.cached_motion_visual_facing_sign = 0


static func register_runtime_enemy(enemy) -> void:
	if not enemy.is_inside_tree():
		return
	var scene: Node = enemy.get_tree().current_scene
	if scene != null and scene.has_method("register_runtime_enemy"):
		scene.register_runtime_enemy(enemy)


static func unregister_runtime_enemy(enemy) -> void:
	if not enemy.is_inside_tree():
		return
	var scene: Node = enemy.get_tree().current_scene
	if scene != null and scene.has_method("unregister_runtime_enemy"):
		scene.unregister_runtime_enemy(enemy)
