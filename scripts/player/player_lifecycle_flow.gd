extends RefCounted

const PLAYER_LEVEL_CURVE := preload("res://scripts/player/player_level_curve.gd")
const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")

static func ready(owner) -> void:
	owner.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	owner.collision_layer = 0
	owner.collision_mask = 0

	owner.roles = owner._build_role_data()
	owner.role_upgrade_levels = owner._build_role_upgrade_data()
	owner.background_cooldowns = owner._build_background_cooldowns()
	owner.role_blessing_levels = PLAYER_BLESSING_SYSTEM.build_empty_role_state(owner.roles)
	PLAYER_BLESSING_SYSTEM.sync_shared_role_blessings(owner)
	owner.skill_blessing_levels = PLAYER_BLESSING_SYSTEM.build_empty_skill_state()
	owner.equipment_levels = {}
	owner.role_equipment_levels = {}
	owner.attribute_training_levels = owner._normalize_attribute_training_data(owner._build_attribute_training_data())
	owner.role_special_states = owner._build_role_special_state_data()
	owner.role_standby_elapsed = owner._build_role_timing_state_data(0.0)
	owner.role_health_values = owner._build_role_health_state()
	owner.role_mana_values = owner._build_role_timing_state_data(0.0)
	owner.role_ultimate_energy_lock_remaining = owner._build_role_timing_state_data(0.0)
	owner.experience_to_next_level = PLAYER_LEVEL_CURVE.normalize_required_experience(owner.level, owner.experience_to_next_level)

	owner.speed = owner.base_speed
	owner.pickup_radius = owner.base_pickup_radius
	owner.equipment_damage_multiplier_bonus = 0.0
	owner.equipment_speed_bonus = 0.0
	owner.equipment_max_health_bonus = 0.0
	owner.equipment_energy_gain_bonus = 0.0
	owner.equipment_dodge_chance = 0.0
	owner.equipment_health_regen_per_second = 0.0
	owner.equipment_low_health_threshold = 0.0
	owner.equipment_low_health_damage_taken_multiplier = 1.0
	owner.equipment_skill_range_multiplier = 1.0
	owner.equipment_cooldown_multiplier = 1.0
	if owner.has_method("_sync_active_role_max_health"):
		owner._sync_active_role_max_health(false, false)
	owner._sync_active_role_ultimate_state()

	owner.fire_timer = Timer.new()
	owner.fire_timer.one_shot = false
	owner.fire_timer.autostart = true
	owner.fire_timer.timeout.connect(owner._perform_active_attack)
	owner.add_child(owner.fire_timer)

	owner.camera_node = owner.get_node_or_null("Camera2D") as Camera2D
	if owner.camera_node != null:
		owner.camera_base_offset = owner.camera_node.offset

	owner._setup_hurt_core_visual()
	owner._setup_player_health_bar()

	owner._initialize_existing_role_shares()

	owner._update_active_role_state()
	owner.experience_changed.emit(owner.experience, owner.experience_to_next_level, owner.level)
	owner.stats_changed.emit(owner.get_stat_summary())
	owner.health_changed.emit(owner.current_health, owner.max_health)
	owner._emit_active_mana_changed()
