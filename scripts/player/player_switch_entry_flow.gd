extends RefCounted

const GUNNER_ENTRY_WAVE_BULLET_COUNT := 16
const GUNNER_ENTRY_WAVE_BATCH_SIZE := 4
const GUNNER_ENTRY_WAVE_BATCH_INTERVAL := 0.012
const EXIT_SWORD_LIFESTEAL_DURATION := 4.5
const EXIT_SWORD_LIFESTEAL_RATIO := 0.14
const EXIT_GUNNER_HASTE_DURATION := 4.0
const EXIT_GUNNER_ATTACK_INTERVAL_BONUS := 0.08
const EXIT_GUNNER_MOVE_SPEED_MULTIPLIER := 1.18
const MAGE_ATTACK_EFFECT_SCALE := 0.8
const MAGE_ENTRY_EFFECT_RADIUS := 52.0 * MAGE_ATTACK_EFFECT_SCALE
const MAGE_ENTRY_HIT_RADIUS := 104.0 * MAGE_ATTACK_EFFECT_SCALE


static func fire_gunner_entry_wave(owner, role_id: String, wave_index: int) -> void:
	owner._queue_camera_shake(4.0, 0.08)
	spawn_gunner_entry_wave_batch(owner, role_id, wave_index, 0)


static func spawn_gunner_entry_wave_batch(owner, role_id: String, wave_index: int, start_index: int) -> void:
	var bullet_count: int = GUNNER_ENTRY_WAVE_BULLET_COUNT
	var angle_offset: float = (TAU / float(bullet_count)) * 0.5 * float(wave_index)
	var end_index: int = min(start_index + GUNNER_ENTRY_WAVE_BATCH_SIZE, bullet_count)
	for bullet_index in range(start_index, end_index):
		var shot_angle: float = TAU * float(bullet_index) / float(bullet_count) + angle_offset
		var damage_multiplier := float(owner._get_role_entry_damage_multiplier(role_id)) if owner.has_method("_get_role_entry_damage_multiplier") else 1.0
		var speed_bonus := float(owner._get_gunner_entry_bullet_speed_bonus()) if owner.has_method("_get_gunner_entry_bullet_speed_bonus") else 0.0
		var bullet = owner._spawn_directional_bullet(Vector2.RIGHT.rotated(shot_angle), owner._get_role_damage(role_id) * 0.22 * damage_multiplier, Color(1.0, 0.55, 0.32, 1.0), role_id, owner.global_position)
		if bullet != null:
			bullet.speed = 660.0 + speed_bonus
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
	tween.tween_callback(Callable(owner, "_spawn_gunner_entry_wave_batch").bind(role_id, wave_index, end_index))
	tween.tween_callback(controller.queue_free)


static func start_mage_entry_bombardment(owner, role_id: String, bombard_centers: Array) -> void:
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
	tween.tween_callback(Callable(owner, "_trigger_mage_entry_bombardment_impact").bind(role_id, first_center))

	if bombard_centers.size() > 1:
		for center_index in range(1, bombard_centers.size()):
			var next_center: Vector2 = bombard_centers[center_index]
			tween.tween_interval(0.22)
			tween.tween_callback(Callable(owner, "_show_mage_entry_bombardment_warning").bind(next_center))
			tween.tween_interval(warning_duration)
			tween.tween_callback(Callable(owner, "_trigger_mage_entry_bombardment_impact").bind(role_id, next_center))

	tween.tween_callback(controller.queue_free)


static func show_mage_entry_bombardment_warning(owner, center: Vector2) -> void:
	var range_multiplier: float = owner._get_story_style_range_multiplier("mage")
	range_multiplier *= float(owner._get_mage_entry_radius_multiplier())
	owner._spawn_mage_warning_scene_effect(center, MAGE_ENTRY_EFFECT_RADIUS * range_multiplier)


static func trigger_mage_entry_bombardment_impact(owner, role_id: String, center: Vector2) -> void:
	var range_multiplier: float = owner._get_story_style_range_multiplier("mage")
	range_multiplier *= float(owner._get_mage_entry_radius_multiplier())
	var damage_multiplier := float(owner._get_role_entry_damage_multiplier(role_id)) if owner.has_method("_get_role_entry_damage_multiplier") else 1.0
	owner._queue_camera_shake(7.2, 0.14)
	owner._spawn_mage_boom_scene_effect(center, MAGE_ENTRY_EFFECT_RADIUS * range_multiplier)
	var hits: int = owner._damage_enemies_in_radius(center, MAGE_ENTRY_HIT_RADIUS * range_multiplier, owner._get_role_damage(role_id) * 0.82 * damage_multiplier, 0.06, 0.58, 2.2)
	if hits > 0:
		owner._register_attack_result(role_id, hits, false)


static func queue_next_entry_blessing(owner, source_role_id: String) -> void:
	owner.pending_entry_blessing_source_role_id = source_role_id


static func apply_pending_entry_blessing(owner, target_role_id: String) -> void:
	if owner.pending_entry_blessing_source_role_id == "":
		return

	var legacy_level: int = 0

	match owner.pending_entry_blessing_source_role_id:
		"swordsman":
			owner.entry_blessing_role_id = target_role_id
			owner.entry_blessing_label = "\u8840\u5203\u5438\u6536"
			var swordsman_duration_bonus := float(owner._get_swordsman_exit_lifesteal_duration_bonus()) if owner.has_method("_get_swordsman_exit_lifesteal_duration_bonus") else 0.0
			var swordsman_lifesteal_bonus := float(owner._get_swordsman_exit_lifesteal_bonus()) if owner.has_method("_get_swordsman_exit_lifesteal_bonus") else 0.0
			owner.entry_blessing_remaining = EXIT_SWORD_LIFESTEAL_DURATION + legacy_level * 0.8 + swordsman_duration_bonus
			owner.entry_lifesteal_ratio = EXIT_SWORD_LIFESTEAL_RATIO + legacy_level * 0.03 + swordsman_lifesteal_bonus
			owner.entry_haste_interval_bonus = 0.0
			owner.entry_haste_move_speed_multiplier = 1.0
			owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -48.0), "\u5438\u8840 +%.0f%%" % (owner.entry_lifesteal_ratio * 100.0), Color(1.0, 0.58, 0.48, 1.0))
		"gunner":
			owner.entry_blessing_role_id = target_role_id
			owner.entry_blessing_label = "\u6218\u672F\u8FC7\u8F7D"
			var gunner_duration_bonus := float(owner._get_gunner_exit_haste_duration_bonus()) if owner.has_method("_get_gunner_exit_haste_duration_bonus") else 0.0
			var gunner_interval_bonus := float(owner._get_gunner_exit_haste_interval_bonus()) if owner.has_method("_get_gunner_exit_haste_interval_bonus") else 0.0
			var gunner_move_bonus := float(owner._get_gunner_exit_move_speed_multiplier_bonus()) if owner.has_method("_get_gunner_exit_move_speed_multiplier_bonus") else 0.0
			owner.entry_blessing_remaining = EXIT_GUNNER_HASTE_DURATION + legacy_level * 0.6 + gunner_duration_bonus
			owner.entry_lifesteal_ratio = 0.0
			owner.entry_haste_interval_bonus = EXIT_GUNNER_ATTACK_INTERVAL_BONUS + legacy_level * 0.02 + gunner_interval_bonus
			owner.entry_haste_move_speed_multiplier = EXIT_GUNNER_MOVE_SPEED_MULTIPLIER + legacy_level * 0.04 + gunner_move_bonus
			owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -48.0), "\u653B\u901F+\u79FB\u901F", Color(1.0, 0.72, 0.42, 1.0))
		"mage":
			var energy_bonus := float(owner._get_mage_exit_energy_bonus()) if owner.has_method("_get_mage_exit_energy_bonus") else 0.0
			if energy_bonus > 0.0:
				owner._add_role_mana(target_role_id, energy_bonus)
				owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -48.0), "\u56DE\u80FD +%.1f" % energy_bonus, Color(0.62, 0.92, 1.0, 1.0))
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
