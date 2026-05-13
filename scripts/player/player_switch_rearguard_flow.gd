extends RefCounted

const GUNNER_REARGUARD_BULLET_BATCH_SIZE := 3
const GUNNER_REARGUARD_BULLET_BATCH_INTERVAL := 0.012

static func trigger_rearguard_attack(owner, role_id: String, origin: Vector2, level: int) -> int:
	if level <= 0:
		return 0
	var hit_count: int = 0
	var repeat_count: int = 1 if level == 1 else 2
	var damage_scale: float = 0.4 if level == 1 else (0.45 if level == 2 else 0.55)
	var accent: Color = owner._get_role_theme_color(role_id)
	owner._spawn_combat_tag(origin + Vector2(0.0, -40.0), "鍚庡崼鎺╂姢", Color(min(1.0, accent.r + 0.18), min(1.0, accent.g + 0.18), min(1.0, accent.b + 0.18), 1.0))
	owner._spawn_ring_effect(origin, 62.0 + level * 12.0, Color(accent.r, accent.g, accent.b, 0.68), 8.0, 0.24)
	if owner.get_tree() == null:
		return 0
	for attack_index in range(repeat_count):
		var queued_attack_index: int = attack_index
		owner._schedule_repeating_sequence(0.0, 1, func(_sequence_index: int) -> void:
			if owner == null or not is_instance_valid(owner):
				return
			match role_id:
				"swordsman":
					var direction: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
					var slash_direction: Vector2 = direction.rotated(0.18 if queued_attack_index % 2 == 0 else -0.18)
					owner._spawn_crescent_wave_effect(origin + direction * 10.0, slash_direction, 110.0 + level * 10.0, Color(0.26, 0.94, 1.0, 0.72), 0.2, 170.0, 28.0 + level * 3.0)
					owner._spawn_cross_slash_effect(origin, slash_direction, 126.0 + level * 10.0, 24.0 + level * 2.0, Color(1.0, 0.84, 0.48, 0.92), 0.2)
					owner._spawn_ring_effect(origin + direction * 14.0, 60.0 + level * 8.0, Color(1.0, 0.26, 0.18, 0.48), 6.0, 0.18)
					owner._damage_enemies_in_radius(origin + direction * 16.0, 64.0 + level * 8.0, owner._get_role_damage(role_id) * damage_scale, 0.03, 1.0, 0.0)
				"gunner":
					owner._spawn_radial_rays_effect(origin, 86.0 + level * 10.0, 10 + level * 2, Color(1.0, 0.66, 0.34, 0.7), 4.0 + level, 0.22, queued_attack_index * 0.16)
					_spawn_gunner_rearguard_bullet_batch(owner, role_id, origin, level, damage_scale, queued_attack_index, 0)
				"mage":
					owner._spawn_ring_effect(origin, 62.0 + level * 10.0, Color(0.68, 0.94, 1.0, 0.82), 7.0, 0.22)
					owner._spawn_frost_sigils_effect(origin, 40.0 + level * 10.0, Color(0.9, 0.98, 1.0, 0.88), 0.22)
					owner._spawn_vortex_effect(origin, 30.0 + level * 8.0, Color(0.7, 0.78, 1.0, 0.42), 0.22)
					owner._spawn_burst_effect(origin, 68.0 + level * 12.0, Color(0.52, 0.9, 1.0, 0.28), 0.22)
					owner._damage_enemies_in_radius(origin, 68.0 + level * 12.0, owner._get_role_damage(role_id) * damage_scale, 0.02, 0.74, 1.0)
		, 0.18 * float(attack_index))
		hit_count += 1
	return hit_count


static func _spawn_gunner_rearguard_bullet_batch(owner, role_id: String, origin: Vector2, level: int, damage_scale: float, attack_index: int, start_index: int) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var bullet_count: int = 6 + level * 2
	var end_index: int = min(start_index + GUNNER_REARGUARD_BULLET_BATCH_SIZE, bullet_count)
	for bullet_index in range(start_index, end_index):
		var angle: float = TAU * float(bullet_index) / float(bullet_count) + float(attack_index) * 0.14
		var bullet = owner._spawn_directional_bullet(Vector2.RIGHT.rotated(angle), owner._get_role_damage(role_id) * damage_scale, Color(1.0, 0.68, 0.42, 0.92), role_id, origin)
		if bullet != null:
			bullet.speed = 460.0
			bullet.lifetime = 0.7
			bullet.hit_radius = 10.0
			bullet.scale = Vector2(1.18, 1.18)
	if end_index >= bullet_count:
		return
	if not owner.has_method("_schedule_repeating_sequence"):
		return
	owner._schedule_repeating_sequence(GUNNER_REARGUARD_BULLET_BATCH_INTERVAL, 1, func(_index: int) -> void:
		_spawn_gunner_rearguard_bullet_batch(owner, role_id, origin, level, damage_scale, attack_index, end_index)
	, GUNNER_REARGUARD_BULLET_BATCH_INTERVAL)
