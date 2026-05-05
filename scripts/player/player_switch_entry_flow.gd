extends RefCounted

const GUNNER_ENTRY_WAVE_BULLET_COUNT := 16
const GUNNER_ENTRY_WAVE_BATCH_SIZE := 4
const GUNNER_ENTRY_WAVE_BATCH_INTERVAL := 0.012
const MAGE_ATTACK_EFFECT_SCALE := 0.8
const MAGE_ENTRY_EFFECT_RADIUS := 52.0 * MAGE_ATTACK_EFFECT_SCALE
const MAGE_ENTRY_HIT_RADIUS := 104.0 * MAGE_ATTACK_EFFECT_SCALE
const ENTRY_RESCUE_DURATION := 5.0


static func fire_gunner_entry_wave(owner, role_id: String, wave_index: int, damage_scale: float = 1.0) -> void:
	owner._queue_camera_shake(4.0, 0.08)
	spawn_gunner_entry_wave_batch(owner, role_id, wave_index, 0, damage_scale)


static func spawn_gunner_entry_wave_batch(owner, role_id: String, wave_index: int, start_index: int, damage_scale: float = 1.0) -> void:
	var bullet_count: int = GUNNER_ENTRY_WAVE_BULLET_COUNT
	var angle_offset: float = (TAU / float(bullet_count)) * 0.5 * float(wave_index)
	var end_index: int = min(start_index + GUNNER_ENTRY_WAVE_BATCH_SIZE, bullet_count)
	for bullet_index in range(start_index, end_index):
		var shot_angle: float = TAU * float(bullet_index) / float(bullet_count) + angle_offset
		var bullet = owner._spawn_directional_bullet(Vector2.RIGHT.rotated(shot_angle), owner._get_role_damage(role_id) * 0.22 * max(0.0, damage_scale), Color(1.0, 0.55, 0.32, 1.0), role_id, owner.global_position)
		if bullet != null:
			bullet.speed = 1000.0
			bullet.lifetime = 0.9
			bullet.hit_radius = 12.0
	if end_index >= bullet_count:
		return
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		return
	var controller := Node2D.new()
	controller.name = "GunnerEntryWaveBatchController"
	current_scene.add_child(controller)
	var tween := controller.create_tween()
	tween.tween_interval(GUNNER_ENTRY_WAVE_BATCH_INTERVAL)
	tween.tween_callback(Callable(owner, "_spawn_gunner_entry_wave_batch").bind(role_id, wave_index, end_index, damage_scale))
	tween.tween_callback(controller.queue_free)


static func start_mage_entry_bombardment(owner, role_id: String, bombard_centers: Array, damage_scale: float = 1.0) -> void:
	if bombard_centers.is_empty():
		return

	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		return

	var controller := Node2D.new()
	controller.name = "MageEntryBombardmentController"
	current_scene.add_child(controller)

	var first_center: Vector2 = bombard_centers[0]
	var warning_duration: float = owner._get_scene_animation_duration(owner.MAGE_WARNING_EFFECT_SCENE, 0.2)
	show_mage_entry_bombardment_warning(owner, first_center)

	var tween := controller.create_tween()
	tween.tween_interval(warning_duration)
	tween.tween_callback(Callable(owner, "_trigger_mage_entry_bombardment_impact").bind(role_id, first_center, damage_scale))

	if bombard_centers.size() > 1:
		for center_index in range(1, bombard_centers.size()):
			var next_center: Vector2 = bombard_centers[center_index]
			tween.tween_interval(0.22)
			tween.tween_callback(Callable(owner, "_show_mage_entry_bombardment_warning").bind(next_center))
			tween.tween_interval(warning_duration)
			tween.tween_callback(Callable(owner, "_trigger_mage_entry_bombardment_impact").bind(role_id, next_center, damage_scale))

	tween.tween_callback(controller.queue_free)


static func show_mage_entry_bombardment_warning(owner, center: Vector2) -> void:
	var range_multiplier: float = _get_mage_entry_range_multiplier(owner)
	owner._spawn_mage_warning_scene_effect(center, MAGE_ENTRY_EFFECT_RADIUS * range_multiplier)


static func trigger_mage_entry_bombardment_impact(owner, role_id: String, center: Vector2, damage_scale: float = 1.0) -> void:
	var range_multiplier: float = _get_mage_entry_range_multiplier(owner)
	owner._queue_camera_shake(7.2, 0.14)
	owner._spawn_mage_boom_scene_effect(center, MAGE_ENTRY_EFFECT_RADIUS * range_multiplier)
	var hits: int = owner._damage_enemies_in_radius(center, MAGE_ENTRY_HIT_RADIUS * range_multiplier, owner._get_role_damage(role_id) * 0.82 * max(0.0, damage_scale), 0.0, 1.0, 0.0)
	if hits > 0:
		owner._register_attack_result(role_id, hits, false)


static func _get_mage_entry_range_multiplier(owner) -> float:
	var range_multiplier: float = 1.0
	if owner.has_method("_get_role_blessing_stat_bonus"):
		range_multiplier += float(owner._get_role_blessing_stat_bonus("mage", "skill_range"))
	return range_multiplier


static func queue_next_entry_blessing(owner, source_role_id: String) -> void:
	owner.pending_entry_blessing_source_role_id = source_role_id


static func apply_pending_entry_blessing(owner, _target_role_id: String) -> void:
	if owner.pending_entry_blessing_source_role_id == "":
		return
	owner.pending_entry_blessing_source_role_id = ""
	owner._update_fire_timer()
	owner.stats_changed.emit(owner.get_stat_summary())


static func clear_entry_blessing(owner) -> void:
	owner.entry_blessing_role_id = ""
	owner.entry_blessing_label = ""
	owner.entry_blessing_remaining = 0.0
	owner.entry_lifesteal_ratio = 0.0
	owner.entry_haste_interval_bonus = 0.0
	owner.entry_haste_move_speed_multiplier = 1.0
	owner._update_fire_timer()
	owner.stats_changed.emit(owner.get_stat_summary())


static func apply_shared_entry_skills(owner, role_id: String) -> void:
	_apply_entry_rescue(owner)
	_apply_hero_entry(owner, role_id)


static func _apply_entry_rescue(owner) -> void:
	if owner == null or not owner.has_method("_get_entry_rescue_regen_per_second"):
		return
	var regen: float = float(owner._get_entry_rescue_regen_per_second())
	if regen <= 0.0:
		return
	owner.entry_rescue_remaining = ENTRY_RESCUE_DURATION
	owner.entry_rescue_regen_per_second = regen
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -54.0), "协同救援", Color(0.48, 1.0, 0.66, 1.0))


static func _apply_hero_entry(owner, role_id: String) -> void:
	if owner == null or not owner.has_method("_get_hero_entry_effect"):
		return
	var effect: Dictionary = owner._get_hero_entry_effect()
	var extra_count: int = max(0, int(effect.get("extra_count", 0)))
	var effect_scale: float = max(0.0, float(effect.get("effect_scale", 0.0)))
	if extra_count <= 0 or effect_scale <= 0.0:
		return
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -74.0), "英雄登场", Color(1.0, 0.9, 0.48, 1.0))
	match role_id:
		"swordsman":
			_spawn_swordsman_hero_entry_extras(owner, role_id, extra_count, effect_scale)
		"gunner":
			_spawn_gunner_hero_entry_extras(owner, role_id, extra_count, effect_scale)
		"mage":
			_spawn_mage_hero_entry_extras(owner, role_id, extra_count, effect_scale)


static func _spawn_swordsman_hero_entry_extras(owner, role_id: String, extra_count: int, effect_scale: float) -> void:
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		return
	var direction: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	var origin: Vector2 = owner.global_position
	for index in range(extra_count):
		var controller := Node2D.new()
		controller.name = "HeroEntrySwordsmanExtra"
		current_scene.add_child(controller)
		var tween := controller.create_tween()
		tween.tween_interval(0.08 * float(index + 1))
		tween.tween_callback(func() -> void:
			if owner == null or not is_instance_valid(owner):
				return
			var slash_direction: Vector2 = direction.rotated(deg_to_rad(14.0 * (float(index) - float(extra_count - 1) * 0.5)))
			var start_position: Vector2 = origin - slash_direction * 42.0
			var end_position: Vector2 = origin + slash_direction * 128.0
			var width: float = 32.0 * effect_scale
			var center: Vector2 = start_position.lerp(end_position, 0.5)
			owner._spawn_sword_omnislash_scene_effect(center, slash_direction, start_position.distance_to(end_position) * effect_scale, width * 1.08)
			var hits: int = owner._damage_enemies_in_line(start_position, end_position, width, owner._get_role_damage(role_id) * 1.52 * effect_scale, 0.1, 1.0, 0.0, role_id)
			if hits > 0:
				owner._register_attack_result(role_id, hits, false)
		)
		tween.tween_callback(controller.queue_free)


static func _spawn_gunner_hero_entry_extras(owner, role_id: String, extra_count: int, effect_scale: float) -> void:
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		return
	for index in range(extra_count):
		var controller := Node2D.new()
		controller.name = "HeroEntryGunnerExtra"
		current_scene.add_child(controller)
		var tween := controller.create_tween()
		tween.tween_interval(0.08 * float(index + 1))
		tween.tween_callback(Callable(owner, "_fire_gunner_entry_wave").bind(role_id, index + 2, effect_scale))
		tween.tween_callback(controller.queue_free)


static func _spawn_mage_hero_entry_extras(owner, role_id: String, _extra_count: int, effect_scale: float) -> void:
	var centers: Array = owner._get_random_enemy_cluster_centers(3)
	if centers.is_empty():
		return
	owner._start_mage_entry_bombardment(role_id, centers, effect_scale)
