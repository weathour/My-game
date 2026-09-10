extends CharacterBody2D

const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const SAVE_MANAGER := preload("res://scripts/save_manager.gd")
const PLAYER_SAVE_CODEC := preload("res://scripts/player/player_save_codec.gd")
const PLAYER_STATE_FACTORY := preload("res://scripts/player/player_state_factory.gd")
const PLAYER_LIFECYCLE_FLOW := preload("res://scripts/player/player_lifecycle_flow.gd")
const PLAYER_ROLE_PRESENTER := preload("res://scripts/player/player_role_presenter.gd")
const PLAYER_TARGETING := preload("res://scripts/player/player_targeting.gd")
const PLAYER_MATH := preload("res://scripts/player/player_math.gd")
const PLAYER_ROLE_STAT_FLOW := preload("res://scripts/player/player_role_stat_flow.gd")
const PLAYER_LEVEL_OPTIONS := preload("res://scripts/player/player_level_options.gd")
const PLAYER_LEVEL_FLOW := preload("res://scripts/player/player_level_flow.gd")
const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")
const PLAYER_BLESSING_SKILL_BRIDGE := preload("res://scripts/player/player_blessing_skill_bridge.gd")
const PLAYER_UPGRADE_APPLIER := preload("res://scripts/player/player_upgrade_applier.gd")
const PLAYER_REWARD_APPLIER := preload("res://scripts/player/player_reward_applier.gd")
const PLAYER_SKILL_COOLDOWN_FLOW := preload("res://scripts/player/player_skill_cooldown_flow.gd")
const PLAYER_STAT_PAYLOAD := preload("res://scripts/player/player_stat_payload.gd")
const PLAYER_RUN_SAVE_STATE := preload("res://scripts/player/player_run_save_state.gd")
const PLAYER_AUTHORED_EFFECTS := preload("res://scripts/player/player_authored_effects.gd")
const PLAYER_PROJECTILE_SPAWNER := preload("res://scripts/player/player_projectile_spawner.gd")
const PLAYER_DAMAGE_HELPERS := preload("res://scripts/player/player_damage_helpers.gd")
const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const PLAYER_COMBAT_RESULT_FLOW := preload("res://scripts/player/player_combat_result_flow.gd")
const PLAYER_COMBAT_MODIFIERS := preload("res://scripts/player/player_combat_modifiers.gd")
const PLAYER_EQUIPMENT_FLOW := preload("res://scripts/player/player_equipment_flow.gd")
const PLAYER_SWORDSMAN_TRAIT_RUNTIME_FLOW := preload("res://scripts/player/player_swordsman_trait_runtime_flow.gd")
const PLAYER_SWORDSMAN_ULTIMATE_FLOW := preload("res://scripts/player/player_swordsman_ultimate_flow.gd")
const PLAYER_SWORDSMAN_KING_BLADE_FLOW := preload("res://scripts/player/player_swordsman_king_blade_flow.gd")
const PLAYER_GUNNER_FLASH_TALENT_FLOW := preload("res://scripts/player/player_gunner_flash_talent_flow.gd")
const PLAYER_GUNNER_HUNT_TALENT_FLOW := preload("res://scripts/player/player_gunner_hunt_talent_flow.gd")
const PLAYER_GUNNER_ENTRY_TALENT_FLOW := preload("res://scripts/player/player_gunner_entry_talent_flow.gd")
const PLAYER_MAGE_ARCANE_CHARGE_TALENT_FLOW := preload("res://scripts/player/player_mage_arcane_charge_talent_flow.gd")
const PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW := preload("res://scripts/player/player_mage_arcane_surplus_talent_flow.gd")
const RUAN_STONE_SYSTEM := preload("res://scripts/player/ruan_stone_system.gd")
const PLAYER_HEALTH_VISUALS := preload("res://scripts/player/player_health_visuals.gd")
const PLAYER_TIMER_FLOW := preload("res://scripts/player/player_timer_flow.gd")
const PLAYER_ULTIMATE_FLOW := preload("res://scripts/player/player_ultimate_flow.gd")
const PLAYER_SWITCH_FLOW := preload("res://scripts/player/player_switch_flow.gd")
const PLAYER_SURVIVAL_FLOW := preload("res://scripts/player/player_survival_flow.gd")
const PLAYER_RESOURCE_FLOW := preload("res://scripts/player/player_resource_flow.gd")
const PLAYER_MAGE_BOMBARDMENT_FLOW := preload("res://scripts/player/player_mage_bombardment_flow.gd")
const PLAYER_ATTACK_LOOP_FLOW := preload("res://scripts/player/player_attack_loop_flow.gd")
const PLAYER_ABILITY_FLOW := preload("res://scripts/player/player_ability_flow.gd")
const PLAYER_CAMERA_FEEDBACK := preload("res://scripts/player/player_camera_feedback.gd")
const PLAYER_MAP_BOUNDS_FLOW := preload("res://scripts/player/player_map_bounds_flow.gd")
const PLAYER_FIELD_EFFECT_FLOW := preload("res://scripts/player/player_field_effect_flow.gd")
const PLAYER_ATTRIBUTE_FLOW := preload("res://scripts/player/player_attribute_flow.gd")
const PLAYER_VISUAL_LAYOUT := preload("res://scripts/player/player_visual_layout.gd")
const PLAYER_TEXTURE_LOADER := preload("res://scripts/player/player_texture_loader.gd")
const PLAYER_VISUAL_STATE := preload("res://scripts/player/player_visual_state.gd")
const PLAYER_EFFECT_PRIMITIVES := preload("res://scripts/player/player_effect_primitives.gd")
const PLAYER_EFFECT_LINE_PRIMITIVES := preload("res://scripts/player/player_effect_line_primitives.gd")
const ROLE_DATABASE := preload("res://scripts/player/roles/role_database.gd")
const ROLE_ATTRIBUTE_RULES := preload("res://scripts/player/roles/role_attribute_rules.gd")
const ROLE_RESOURCE_STATE := preload("res://scripts/player/roles/role_resource_state.gd")
const SWORDSMAN_ROLE := preload("res://scripts/player/roles/swordsman_role.gd")
const GUNNER_ROLE := preload("res://scripts/player/roles/gunner_role.gd")
const MAGE_ROLE := preload("res://scripts/player/roles/mage_role.gd")
const MECHANIC_ROLE := preload("res://scripts/player/roles/mechanic_role.gd")
const SWORDSMAN_BLADE_STORM_ABILITY := preload("res://scripts/abilities/swordsman_blade_storm_ability.gd")
const MAGE_TIDAL_SURGE_ABILITY := preload("res://scripts/abilities/mage_tidal_surge_ability.gd")
const GUNNER_INFINITE_RELOAD_ABILITY := preload("res://scripts/abilities/gunner_infinite_reload_ability.gd")
const MAGE_META_FIELD_ABILITY := preload("res://scripts/abilities/mage_meta_field_ability.gd")
const SWORDSMAN_CRESCENT_WAVE_ABILITY := preload("res://scripts/abilities/swordsman_crescent_wave_ability.gd")
const GUNNER_SHRAPNEL_FIELD_ABILITY := preload("res://scripts/abilities/gunner_shrapnel_field_ability.gd")
const SWORDSMAN_KNIGHT_THRUST_ABILITY := preload("res://scripts/abilities/swordsman_knight_thrust_ability.gd")
const GUNNER_EXPLOSIVE_ROUND_ABILITY := preload("res://scripts/abilities/gunner_explosive_round_ability.gd")
const GUNNER_MAGIC_GRENADE_ABILITY := preload("res://scripts/abilities/gunner_magic_grenade_ability.gd")
const MAGE_DARK_CONTRACT_ABILITY := preload("res://scripts/abilities/mage_dark_contract_ability.gd")
const SWORDSMAN_JUDGEMENT_SWORD_ABILITY := preload("res://scripts/abilities/swordsman_judgement_sword_ability.gd")
const GUNNER_MAGIC_EYE_ABILITY := preload("res://scripts/abilities/gunner_magic_eye_ability.gd")
const MAGE_FIREBALL_ABILITY := preload("res://scripts/abilities/mage_fireball_ability.gd")
const MAGE_FLAME_PATH_ABILITY := preload("res://scripts/abilities/mage_flame_path_ability.gd")
const SWORDSMAN_KING_BLADE_ABILITY := preload("res://scripts/abilities/swordsman_king_blade_ability.gd")
const MECHANIC_DRONE_ABILITY := preload("res://scripts/abilities/mechanic_drone_ability.gd")
const MECHANIC_MINE_ABILITY := preload("res://scripts/abilities/mechanic_mine_ability.gd")
const MECHANIC_EMP_BURST_ABILITY := preload("res://scripts/abilities/mechanic_emp_burst_ability.gd")
const MECHANIC_TULIP_TURRET_ABILITY := preload("res://scripts/abilities/mechanic_tulip_turret_ability.gd")
const MECHANIC_MISSILE_VOLLEY_ABILITY := preload("res://scripts/abilities/mechanic_missile_volley_ability.gd")
const WHITE_KEY_SHADER := preload("res://shaders/white_key.gdshader")
const SWORD_SLASH_EFFECT_SCENE := preload("res://effects/sword/slash3/slasheffect3.tscn")
const SWORD_OMNISLASH_EFFECT_SCENE := preload("res://effects/sword/omnislash/omnislash.tscn")
const SWORD_FAN_EFFECT_SCENE := preload("res://effects/sword/fan/fan.tscn")
const SWORD_TORNADO_EFFECT_SCENE := preload("res://effects/sword/tornado/tornado.tscn")
const GUNNER_INTERSECT_GATHER_EFFECT_SCENE := preload("res://effects/gun/intersect2/gathering-beam.tscn")
const GUNNER_INTERSECT_BEAM_EFFECT_SCENE := preload("res://effects/gun/intersect2/beam.tscn")
const MAGE_BOOM_EFFECT_SCENE := preload("res://effects/wizard/boom/boom.tscn")
const MAGE_WARNING_EFFECT_SCENE := preload("res://effects/wizard/warning/warning.tscn")
const MAGE_GATHERING_EFFECT_SCENE := preload("res://effects/wizard/wave/gathering/gatering.tscn")
const MAGE_WAVE_EFFECT_SCENE := preload("res://effects/wizard/wave/wave.tscn")

const SWORD_FAN_SCENE_SIZE := Vector2(1024.0, 1024.0)
const SWORD_FAN_SCENE_VISIBLE_BOUNDS := Rect2(485.0, 405.0, 117.0, 50.0)
const GUNNER_INTERSECT_SCENE_SIZE := Vector2(1024.0, 1024.0)
const GUNNER_INTERSECT_GATHER_VISIBLE_BOUNDS := Rect2(465.0, 481.0, 416.0, 57.0)
const GUNNER_INTERSECT_BEAM_VISIBLE_BOUNDS := Rect2(465.0, 487.0, 552.0, 49.0)
const GUNNER_INTERSECT_EFFECT_SPEED_SCALE := 2.4375
const GUNNER_INTERSECT_VISUAL_SCALE := 1.5
const MAGE_GATHERING_SCENE_SIZE := Vector2(1024.0, 1024.0)
const MAGE_GATHERING_SCENE_VISIBLE_BOUNDS := Rect2(298.0, 399.0, 102.0, 165.0)

signal experience_changed(current_experience: int, required_experience: int, level: int)
signal level_up_requested(options: Array)
signal stats_changed(summary: Dictionary)
signal health_changed(current_health: float, max_health: float)
signal temporary_health_changed(role_id: String, current_temporary_health: float)
signal mana_changed(current_mana: float, max_mana: float)
signal died
signal active_role_changed(role_id: String, role_name: String)
signal blessing_skill_event_announced(event: Dictionary)

const ROLE_SWITCH_COOLDOWN := 0.5
const SWITCH_INVULNERABILITY := 0.1
const ENERGY_PASSIVE_REGEN := 0.0
const ENERGY_PER_HIT := 0.3
const ENERGY_PER_KILL := 1.1
const ULTIMATE_ENERGY_GAIN_GLOBAL_MULTIPLIER := 0.858
const SMALL_ENEMY_KILL_ENERGY_MULTIPLIER := 0.75
const BACKGROUND_ULTIMATE_ENERGY_GAIN_RATIO := 0.3
const ULTIMATE_COST := 90.0
const ULTIMATE_ENERGY_REQUIRED := 100.0
const SWITCH_ENTRY_ENERGY_REQUIRED := 100.0
const SWITCH_ENTRY_ENERGY_PER_DAMAGE := 0.02
const ULTIMATE_ENERGY_LOCK_AFTER_CAST := 3.2
const SWORD_ULTIMATE_SLASH_INTERVAL := 0.12
const GUNNER_ULTIMATE_WAVE_INTERVAL := 0.14
const MAGE_ULTIMATE_BOMBARD_INTERVAL := 0.24
const GUNNER_ENTRY_WAVE_BULLET_COUNT := 16
const GUNNER_ENTRY_WAVE_BATCH_SIZE := 16
const GUNNER_ENTRY_WAVE_BATCH_INTERVAL := 0.008
const GUNNER_FLASH_STACK_INTERVAL := 2.0
const GUNNER_HUNT_STACK_INTERVAL := 1.25
const GUNNER_FLASH_MAX_STACKS := 10
const GUNNER_FLASH_DAMAGE_PER_STACK := 0.03
const GUNNER_FLASH_SPEED_PER_STACK := 0.03
const GUNNER_FLASH_COOLDOWN := 15.0
const GUNNER_FLASH_DODGE_VALUE_PER_STACK := 4.0
const GUNNER_SAFE_ZONE_RADIUS := 115.0
const GUNNER_SAFE_ZONE_FILL_COLOR := Color(0.24, 0.58, 1.0, 0.10)
const GUNNER_SAFE_ZONE_OUTLINE_COLOR := Color(0.38, 0.72, 1.0, 0.42)
const GUNNER_SAFE_ZONE_OUTLINE_WIDTH := 2.0
const MAGE_ARCANE_CHARGE_MAX_STACKS := 10
const MAGE_ARCANE_CHARGE_SHARE_PER_STACK := 0.10
const MAGE_ARCANE_CHARGE_SELF_ENERGY_PER_STACK := 0.02
const MAGE_ARCANE_CHARGE_TRANSFER_DURATION_PER_STACK := 1.0
const MAGE_ARCANE_SURPLUS_DURATION := 5.0
const MAGE_ARCANE_SURPLUS_TEAM_ULTIMATE_ENERGY_BONUS := 0.20
const MAGE_ARCANE_SURPLUS_SWITCH_ENERGY_BONUS := 0.20
const MAGE_ARCANE_SURPLUS_DAMAGE_BONUS := 0.10
const SWORDSMAN_BLOODTHIRST_DURATION := 3.0
const SWORDSMAN_BLOODTHIRST_INTERNAL_COOLDOWN := 10.0
const SWORDSMAN_DEATH_DEFIANCE_COOLDOWN := 80.0
const SWORDSMAN_DEATH_DEFIANCE_INVULNERABILITY := 1.5
const BASE_CRITICAL_DAMAGE_MULTIPLIER := 1.5
const CRITICAL_OVERFLOW_DAMAGE_RATIO := 0.10
const SHOW_GAMEPLAY_TEXT_HINTS := false

const FIRE_RATE_STEP := 0.05
const MOVE_SPEED_STEP := 12.0
const PICKUP_RANGE_STEP := 8.0
const ENERGY_GAIN_STEP := 0.08
const HEALTH_STEP := 16.0
const DAMAGE_REDUCTION_STEP := 0.05
const SWITCH_COOLDOWN_STEP := 0.4
const LEVEL_STAT_HEALTH_STEP := 14.0
const LEVEL_STAT_SPEED_STEP := 8.0
const EXIT_SWORD_LIFESTEAL_DURATION := 4.5
const EXIT_SWORD_LIFESTEAL_RATIO := 0.14
const EXIT_GUNNER_HASTE_DURATION := 4.0
const EXIT_GUNNER_ATTACK_INTERVAL_BONUS := 0.08
const EXIT_GUNNER_MOVE_SPEED_MULTIPLIER := 1.18
const ROLE_SHARE_INTERVAL_RATIO := 0.34
const ROLE_SHARE_RANGE_RATIO := 0.45
const ROLE_SHARE_SKILL_RATIO := 0.4
const SLOT_EVOLUTION_THRESHOLD := 2
const GEM_COLLECTION_INTERVAL := 0.08
const GEM_ATTRACT_RADIUS := 128.8
const GEM_ABSORB_RADIUS := 11.5
const CONTACT_CHECK_INTERVAL := 0.05
const PLAYER_HURT_CORE_RADIUS := 6.16
const PLAYER_HURT_CORE_OUTLINE_WIDTH := 3.0
const PLAYER_HURT_CORE_OFFSET := Vector2.ZERO
const PLAYER_HEALTH_BAR_HEIGHT := 5.0
const PLAYER_HEALTH_BAR_Y_OFFSET := 44.0
const ROLE_SKETCH_TARGET_HEIGHT := 72.0
const ROLE_SKETCH_PATHS := {
	"swordsman": "人设草图/剑士草图.jpg",
	"gunner": "人设草图/枪手草图.jpg",
	"mage": "人设草图/术师草图.jpg",
	"mechanic": "人设草图/机械师草图.jpg"
}
const ROLE_SKETCH_FULL_SIZES := {
	"swordsman": Vector2(589.0, 527.0),
	"gunner": Vector2(589.0, 582.0),
	"mage": Vector2(589.0, 527.0),
	"mechanic": Vector2(589.0, 527.0)
}
const ROLE_SKETCH_SCALE_MULTIPLIERS := {
	"swordsman": 1.0,
	"gunner": 1.12,
	"mage": 1.06,
	"mechanic": 1.12
}
const ROLE_SKETCH_BASE_POSITIONS := {
	"swordsman": Vector2(14.0, -4.0),
	"gunner": Vector2(2.0, -3.0),
	"mage": Vector2(10.0, -5.0),
	"mechanic": Vector2(6.0, -4.0)
}
const ROLE_SKETCH_VISIBLE_BOUNDS := {
	"swordsman": Rect2(161.0, 49.0, 368.0, 430.0),
	"gunner": Rect2(94.0, 16.0, 415.0, 539.0),
	"mage": Rect2(142.0, 31.0, 377.0, 424.0),
	"mechanic": Rect2(70.0, 8.0, 450.0, 512.0)
}
const SWORD_SLASH_TEXTURE_RELATIVE_PATH := "技能特效/斩击.jpg"
const SWORD_SLASH_TEXTURE_SIZE := Vector2(1200.0, 1600.0)
const SWORD_SLASH_VISIBLE_BOUNDS := Rect2(246.0, 537.0, 600.0, 615.0)
const SWORD_SLASH_SCENE_SIZE := Vector2(256.0, 256.0)
const SWORD_SLASH_SCENE_VISIBLE_BOUNDS := Rect2(99.0, 30.0, 27.0, 153.0)
const SWORD_SLASH_DAMAGE_FOLLOW_PULSES := 2
const SWORD_OMNISLASH_SCENE_SIZE := Vector2(1024.0, 1024.0)
const SWORD_OMNISLASH_SCENE_VISIBLE_BOUNDS := Rect2(30.0, 344.0, 951.0, 189.0)
const MAGE_WARNING_SCENE_SIZE := Vector2(256.0, 256.0)
const MAGE_WARNING_SCENE_VISIBLE_BOUNDS := Rect2(98.0, 98.0, 59.0, 30.0)
const MAGE_BOOM_SCENE_SIZE := Vector2(256.0, 256.0)
const MAGE_BOOM_SCENE_VISIBLE_BOUNDS := Rect2(101.0, 33.0, 56.0, 92.0)
const MAGE_BOOM_IMPACT_FOCUS_BOUNDS := Rect2(104.0, 99.0, 44.0, 26.0)
const GUNNER_BULLET_TEXTURE_RELATIVE_PATH := "技能特效/子弹.jpg"
const MAGE_BOMBARD_TEXTURE_RELATIVE_PATH := "技能特效/轰炸.jpg"
const MAGE_BOMBARD_TEXTURE_SIZE := Vector2(1200.0, 1600.0)
const MAGE_BOMBARD_VISIBLE_BOUNDS := Rect2(287.0, 434.0, 634.0, 561.0)

const MAGE_ATTACK_EFFECT_SCALE := 0.8
const MAGE_ENTRY_EFFECT_RADIUS := 52.0 * MAGE_ATTACK_EFFECT_SCALE
const MAGE_ENTRY_HIT_RADIUS := 104.0 * MAGE_ATTACK_EFFECT_SCALE
@export var bullet_scene: PackedScene = preload("res://effects/gun/bullet/bullet.tscn")
@export var max_health: float = 110.0
@export var max_mana: float = 100.0
@export var base_speed: float = 192.0
@export var base_pickup_radius: float = 34.0
@export var hurt_cooldown: float = 0.55
@export var experience_to_next_level: int = 30

var fire_timer: Timer
var level: int = 1
var experience: int = 0
var pending_level_ups: int = 0
var pending_level_talent_choices: int = 0
var level_up_active: bool = false
var active_upgrade_kind: String = ""
var current_health: float = 0.0
var current_temporary_health: float = 0.0
var temporary_health_stacks: Array = []
var current_mana: float = 0.0
var ultimate_energy_lock_remaining: float = 0.0
var hurt_cooldown_remaining: float = 0.0
var switch_invulnerability_remaining: float = 0.0
var hidden_invulnerability_status_remaining: float = 0.0
var level_up_delay_remaining: float = 0.0
var switch_cooldown_remaining: float = 0.0
var enemy_move_slow_multiplier: float = 1.0
var enemy_move_slow_remaining: float = 0.0
var is_dead: bool = false
var death_sequence_pending: bool = false
var death_sequence_remaining: float = 0.0

var speed: float = 0.0
var pickup_radius: float = 0.0
var energy_gain_multiplier: float = 1.0
var global_damage_multiplier: float = 1.0
var background_interval_multiplier: float = 1.0
var ultimate_cost_multiplier: float = 1.0
var damage_taken_multiplier: float = 1.0
var passive_damage_reduction_value: float = 0.0
var role_switch_cooldown_bonus: float = 0.0

var active_role_index: int = 0
var facing_direction: Vector2 = Vector2.RIGHT
var visual_facing_direction_x: float = 1.0
var auto_attack_enabled: bool = false
var roles: Array = []
var role_upgrade_levels: Dictionary = {}
var background_cooldowns: Dictionary = {}
var role_blessing_levels: Dictionary = {}
var skill_blessing_levels: Dictionary = {}
var blessing_skill_state: Dictionary = {}
var pending_blessing_binding_choices: Array = []
var current_blessing_offer: Dictionary = {}
var owned_magic_stones: Array = []
var blessing_health_regen_elapsed: float = 0.0
var elite_relics_unlocked: Dictionary = {}
var equipment_levels: Dictionary = {}
var role_equipment_levels: Dictionary = {}
var ruan_bone_count: int = 0
var ruan_stone_levels: Dictionary = {}
var equipped_ruan_stone: String = ""
var ruan_stone_proc_events: Dictionary = {}
var basic_attack_event_serial: int = 0
var equipment_damage_multiplier_bonus: float = 0.0
var equipment_speed_bonus: float = 0.0
var equipment_max_health_bonus: float = 0.0
var equipment_energy_gain_bonus: float = 0.0
var equipment_dodge_chance: float = 0.0
var equipment_health_regen_per_second: float = 0.0
var equipment_low_health_threshold: float = 0.0
var equipment_low_health_damage_taken_multiplier: float = 1.0
var equipment_low_health_damage_reduction_value: float = 0.0
var equipment_skill_range_multiplier: float = 1.0
var equipment_cooldown_multiplier: float = 1.0
var attribute_training_levels: Dictionary = {}
var role_special_states: Dictionary = {}
var attack_result_context_tags: Dictionary = {}
var pending_attack_result_hit_count_by_role: Dictionary = {}
var pending_attack_result_kill_count_by_role: Dictionary = {}
var pending_attack_result_critical_hit_count_by_role: Dictionary = {}
var swordsman_blade_storm_ability = SWORDSMAN_BLADE_STORM_ABILITY.new()
var swordsman_crescent_wave_ability = SWORDSMAN_CRESCENT_WAVE_ABILITY.new()
var swordsman_knight_thrust_ability = SWORDSMAN_KNIGHT_THRUST_ABILITY.new()
var swordsman_king_blade_ability = SWORDSMAN_KING_BLADE_ABILITY.new()
var swordsman_judgement_sword_ability = SWORDSMAN_JUDGEMENT_SWORD_ABILITY.new()
var camera_node: Camera2D
var camera_base_offset: Vector2 = Vector2.ZERO
var camera_shake_strength: float = 0.0
var camera_shake_time: float = 0.0
var external_camera_shake_strength: float = 0.0
var external_camera_shake_time: float = 0.0
var switch_power_remaining: float = 0.0
var switch_power_role_id: String = ""
var switch_power_damage_multiplier: float = 1.0
var switch_power_interval_bonus: float = 0.0
var switch_power_label: String = ""
var pending_entry_blessing_source_role_id: String = ""
var entry_blessing_role_id: String = ""
var entry_blessing_label: String = ""
var entry_blessing_remaining: float = 0.0
var entry_lifesteal_ratio: float = 0.0
var entry_rescue_remaining: float = 0.0
var entry_rescue_regen_per_second: float = 0.0
var lifesteal_proc_cooldown_remaining: float = 0.0
var swordsman_trait_heal_cooldown_remaining: float = 0.0
var swordsman_death_defiance_cooldown_remaining: float = 0.0
var swordsman_death_defiance_will_remaining: float = 0.0
var swordsman_entry_trait_share_remaining: float = 0.0
var swordsman_bloodthirst_cooldown_remaining: float = 0.0
var swordsman_bloodthirst_heal_multiplier: float = 1.0
var swordsman_ultimate_crit_bonus_chance: float = 0.0
var mage_arcane_surplus_remaining: float = 0.0
var mage_arcane_charge_stacks: int = 0
var mage_arcane_charge_transfer_stacks: int = 0
var mage_arcane_charge_transfer_remaining: float = 0.0
var mage_arcane_charge_transfer_duration: float = 0.0
var mage_arcane_charge_transfer_target_role_id: String = ""
var mage_arcane_charge_transfer_relay_used: bool = false
var greed_heal_cooldown_remaining: float = 0.0
var entry_haste_interval_bonus: float = 0.0
var entry_haste_move_speed_multiplier: float = 1.0
var ultimate_haste_remaining: float = 0.0
var ultimate_haste_move_speed_multiplier: float = 1.0
var ultimate_haste_dodge_chance: float = 0.0
var standby_entry_role_id: String = ""
var standby_entry_label: String = ""
var standby_entry_remaining: float = 0.0
var standby_entry_damage_multiplier: float = 1.0
var standby_entry_interval_bonus: float = 0.0
var guard_cover_remaining: float = 0.0
var guard_cover_damage_multiplier: float = 1.0
var borrow_fire_role_id: String = ""
var borrow_fire_remaining: float = 0.0
var borrow_fire_damage_multiplier: float = 1.0
var borrow_fire_interval_bonus: float = 0.0
var borrow_fire_background_multiplier: float = 1.0
var post_ultimate_flow_remaining: float = 0.0
var post_ultimate_flow_background_multiplier: float = 1.0
var ultimate_guard_remaining: float = 0.0
var ultimate_guard_damage_multiplier: float = 1.0
var player_action_lock_remaining: float = 0.0
var healing_block_remaining: float = 0.0
var aging_remaining: float = 0.0
var aging_damage_carry: float = 0.0
var confinement_center: Vector2 = Vector2.ZERO
var confinement_radius: float = 0.0
var confinement_remaining: float = 0.0
var confinement_polygon: PackedVector2Array = PackedVector2Array()
var perpetual_motion_cooldown_remaining: float = 0.0
var frenzy_remaining: float = 0.0
var frenzy_stacks: int = 0
var frenzy_overkill_counter: int = 0
var role_standby_elapsed: Dictionary = {}
var role_health_values: Dictionary = {}
var role_temporary_health_values: Dictionary = {}
var role_mana_values: Dictionary = {}
var role_switch_energy_values: Dictionary = {}
var role_ultimate_energy_lock_remaining: Dictionary = {}
var role_share_initialized: bool = false
var role_visual_time: float = 0.0
var active_role_visual_hidden: bool = false
var active_role_visual_hidden_role_id: String = ""
var hurt_core_visual_visible: bool = true
var runtime_texture_cache: Dictionary = {}
var white_key_material_cache: Dictionary = {}
var swordsman_role = SWORDSMAN_ROLE.new()
var swordsman_attack_chain: int = 0
var gunner_role = GUNNER_ROLE.new()
var gunner_attack_chain: int = 0
var gunner_flash_stacks: int = 0
var gunner_flash_stack_elapsed: float = 0.0
var gunner_flash_cooldown_remaining: float = 0.0
var gunner_hunt_presence_check_remaining: float = 0.0
var gunner_hunt_has_enemy: bool = false
var gunner_infinite_reload_ability = GUNNER_INFINITE_RELOAD_ABILITY.new()
var gunner_shrapnel_field_ability = GUNNER_SHRAPNEL_FIELD_ABILITY.new()
var gunner_explosive_round_ability = GUNNER_EXPLOSIVE_ROUND_ABILITY.new()
var gunner_magic_grenade_ability = GUNNER_MAGIC_GRENADE_ABILITY.new()
var gunner_magic_eye_ability = GUNNER_MAGIC_EYE_ABILITY.new()
var mage_role = MAGE_ROLE.new()
var mage_attack_chain: int = 0
var mage_tidal_surge_ability = MAGE_TIDAL_SURGE_ABILITY.new()
var mage_meta_field_ability = MAGE_META_FIELD_ABILITY.new()
var mage_flame_path_ability = MAGE_FLAME_PATH_ABILITY.new()
var mage_dark_contract_ability = MAGE_DARK_CONTRACT_ABILITY.new()
var mage_fireball_ability = MAGE_FIREBALL_ABILITY.new()
var mechanic_role = MECHANIC_ROLE.new()
var mechanic_drone_ability = MECHANIC_DRONE_ABILITY.new()
var mechanic_mine_ability = MECHANIC_MINE_ABILITY.new()
var mechanic_emp_burst_ability = MECHANIC_EMP_BURST_ABILITY.new()
var mechanic_tulip_turret_ability = MECHANIC_TULIP_TURRET_ABILITY.new()
var mechanic_missile_volley_ability = MECHANIC_MISSILE_VOLLEY_ABILITY.new()
var gunner_lock_target: Node2D
var gunner_lock_stacks: int = 0
var gem_collection_elapsed: float = 0.0
var contact_check_elapsed: float = 0.0
var execution_pact_burst_active: bool = false
var final_set_unlock_announced: Dictionary = {}
var active_duration_statuses: Dictionary = {}

func _ready() -> void:
	PLAYER_LIFECYCLE_FLOW.ready(self)

func _get_desktop_sketch_path(relative_path: String) -> String:
	return PLAYER_TEXTURE_LOADER.get_desktop_sketch_path(relative_path)

func _get_project_sketch_path(relative_path: String) -> String:
	return PLAYER_TEXTURE_LOADER.get_project_sketch_path(relative_path)

func _get_cached_runtime_texture(relative_path: String) -> Texture2D:
	return PLAYER_TEXTURE_LOADER.get_cached_runtime_texture(relative_path, runtime_texture_cache)

func _create_white_key_material(value_threshold: float = 0.94, saturation_threshold: float = 0.08, edge_softness: float = 0.03) -> ShaderMaterial:
	return PLAYER_TEXTURE_LOADER.get_cached_white_key_material(
		WHITE_KEY_SHADER,
		white_key_material_cache,
		value_threshold,
		saturation_threshold,
		edge_softness
	)

func _get_role_sprite_offset(role_id: String) -> Vector2:
	return PLAYER_VISUAL_LAYOUT.get_role_sprite_offset(role_id, ROLE_SKETCH_FULL_SIZES, ROLE_SKETCH_VISIBLE_BOUNDS)

func _configure_role_sprite(sprite: Sprite2D, role_id: String) -> bool:
	return PLAYER_VISUAL_STATE.configure_role_sprite(self, sprite, role_id)

func _spawn_sketch_sprite_effect(
		center: Vector2,
		rotation_angle: float,
		texture_path: String,
		full_size: Vector2,
		visible_bounds: Rect2,
		target_visible_size: Vector2,
		duration: float,
		modulate_color: Color = Color.WHITE,
		z_index: int = 13,
		align_visible_center: bool = true,
		preserve_aspect: bool = false,
		value_threshold: float = 0.94,
		saturation_threshold: float = 0.08,
		edge_softness: float = 0.03,
		fade_out: bool = true
	) -> Node2D:
	return PLAYER_AUTHORED_EFFECTS.spawn_sketch_sprite_effect(
		self,
		center,
		rotation_angle,
		texture_path,
		full_size,
		visible_bounds,
		target_visible_size,
		duration,
		modulate_color,
		z_index,
		align_visible_center,
		preserve_aspect,
		value_threshold,
		saturation_threshold,
		edge_softness,
		fade_out
	)

func _spawn_sword_slash_scene_effect(center: Vector2, direction: Vector2, radius: float, color: Color, duration: float, thickness: float, mirror_horizontal: bool = false) -> Node2D:
	return PLAYER_AUTHORED_EFFECTS.spawn_sword_slash_scene_effect(self, center, direction, radius, duration, thickness, mirror_horizontal)

func _spawn_sword_omnislash_scene_effect(center: Vector2, direction: Vector2, length: float, thickness: float) -> Node2D:
	return PLAYER_AUTHORED_EFFECTS.spawn_sword_omnislash_scene_effect(self, center, direction, length, thickness)

func _set_active_role_visual_hidden(hidden: bool) -> void:
	PLAYER_VISUAL_STATE.set_active_role_visual_hidden(self, hidden)

func _spawn_authored_scene_effect(scene: PackedScene, scene_size: Vector2, visible_bounds: Rect2, center: Vector2, rotation_radians: float, scale_multiplier: float, z_index: int = 12) -> Node2D:
	return PLAYER_AUTHORED_EFFECTS.spawn_authored_scene_effect(self, scene, scene_size, visible_bounds, center, rotation_radians, scale_multiplier, z_index)

func _spawn_sword_fan_scene_effect(center: Vector2, direction: Vector2, scale_multiplier: float = 1.0) -> Node2D:
	return PLAYER_AUTHORED_EFFECTS.spawn_sword_fan_scene_effect(self, center, direction, scale_multiplier)

func _spawn_gunner_intersect_scene_effect(center: Vector2, direction: Vector2, visual_length: float = 112.0, visual_thickness: float = 18.0, gather_visual_length: float = -1.0) -> Node2D:
	return PLAYER_AUTHORED_EFFECTS.spawn_owner_gunner_intersect_effect(self, center, direction, visual_length, visual_thickness, gather_visual_length)

func _get_infinite_reload_range_multiplier() -> float:
	return PLAYER_MATH.get_infinite_reload_range_multiplier()

func _get_gunner_intersect_combo_duration() -> float:
	return PLAYER_AUTHORED_EFFECTS.get_owner_gunner_intersect_combo_duration(self)

func _get_gunner_intersect_gather_duration() -> float:
	return PLAYER_AUTHORED_EFFECTS.get_scene_animation_duration(GUNNER_INTERSECT_GATHER_EFFECT_SCENE, 0.18) / max(GUNNER_INTERSECT_EFFECT_SPEED_SCALE, 0.001)

func _spawn_mage_gathering_scene_effect(center: Vector2, direction: Vector2, scale_multiplier: float = 1.0) -> Node2D:
	return PLAYER_AUTHORED_EFFECTS.spawn_mage_gathering_scene_effect(self, center, direction, scale_multiplier)

func _spawn_mage_boom_scene_effect(center: Vector2, radius: float) -> Node2D:
	return PLAYER_AUTHORED_EFFECTS.spawn_mage_boom_scene_effect(self, center, radius)

func _spawn_mage_warning_scene_effect(center: Vector2, radius: float) -> Node2D:
	return PLAYER_AUTHORED_EFFECTS.spawn_mage_warning_scene_effect(self, center, radius)

func _get_downward_perpendicular(direction: Vector2) -> Vector2:
	return PLAYER_MATH.get_downward_perpendicular(direction)

func _get_sword_slash_scene_animation_duration() -> float:
	return PLAYER_AUTHORED_EFFECTS.get_scene_animation_duration(SWORD_SLASH_EFFECT_SCENE, 0.18)

func _get_scene_animation_duration(scene: PackedScene, default_duration: float = 0.18) -> float:
	return PLAYER_AUTHORED_EFFECTS.get_scene_animation_duration(scene, default_duration)

func _build_role_data() -> Array:
	return ROLE_DATABASE.get_role_data()

func _build_team_role_data(team_ids: Array = []) -> Array:
	return ROLE_DATABASE.get_team_role_data(team_ids)

func _serialize_roles_for_save() -> Array:
	return PLAYER_SAVE_CODEC.serialize_roles_for_save(roles)

func _normalize_loaded_roles(saved_roles: Variant) -> Array:
	return PLAYER_SAVE_CODEC.normalize_loaded_roles(saved_roles, _build_role_data(), _build_team_role_data())

func _build_role_upgrade_data() -> Dictionary:
	return ROLE_DATABASE.get_role_upgrade_data()

func _build_background_cooldowns() -> Dictionary:
	return PLAYER_ROLE_STAT_FLOW.build_background_cooldowns(self)

func configure_story_loadout(team_order: Array) -> void:
	var team_roles: Array = _build_team_role_data(team_order)
	if team_roles.is_empty():
		return
	roles = team_roles
	active_role_index = clamp(active_role_index, 0, max(0, roles.size() - 1))
	_update_active_role_state()

func _get_upgrade_slot_label(slot_id: String) -> String:
	match slot_id:
		"body":
			return "祝福"
		"combat":
			return "战斗"
		"skill":
			return "技能"
		"special":
			return "奖励"
	return slot_id

func _build_role_special_state_data() -> Dictionary:
	return ROLE_DATABASE.get_role_special_state_data()

func _build_attribute_training_data() -> Dictionary:
	return PLAYER_STATE_FACTORY.build_attribute_training_data()

func _get_role_attribute_level(role_id: String, attribute_key: String) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_role_attribute_level(self, role_id, attribute_key)

func _increase_role_attribute_level(role_id: String, attribute_key: String) -> float:
	return PLAYER_ATTRIBUTE_FLOW.increase_role_attribute_level(self, role_id, attribute_key)

func _normalize_attribute_training_data(data: Variant) -> Dictionary:
	return PLAYER_ATTRIBUTE_FLOW.normalize_attribute_training_data(data)

func _get_attribute_level(attribute_key: String) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_attribute_level(self, attribute_key)

func _add_attribute_levels(deltas: Dictionary) -> Dictionary:
	return PLAYER_ATTRIBUTE_FLOW.add_attribute_levels(self, deltas)

func _format_attribute_level(level: float) -> String:
	return PLAYER_ATTRIBUTE_FLOW.format_attribute_level(level)

func _get_attribute_health_regen_per_second() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_attribute_health_regen_per_second(self)

func _get_attribute_mana_regen_per_second() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_attribute_mana_regen_per_second(self)

func _get_attribute_dodge_chance() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_attribute_dodge_chance(self)

func _get_attribute_dodge_value() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_attribute_dodge_value(self)

func _get_role_attribute_dodge_value(role_id: String) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_role_attribute_dodge_value(self, role_id)

func _get_role_base_dodge_chance(role_id: String) -> float:
	return PLAYER_EQUIPMENT_FLOW.get_role_base_dodge_chance(self, role_id)

func _get_role_permanent_dodge_value(role_id: String = "") -> float:
	var resolved_role_id: String = role_id if role_id != "" else _get_active_role_id()
	return PLAYER_EQUIPMENT_FLOW.get_role_permanent_dodge_value(self, resolved_role_id)

func _get_role_temporary_dodge_strength(role_id: String = "") -> float:
	var resolved_role_id: String = role_id if role_id != "" else _get_active_role_id()
	return PLAYER_EQUIPMENT_FLOW.get_role_temporary_dodge_strength(self, resolved_role_id)

func _get_role_dodge_chance(role_id: String = "") -> float:
	var resolved_role_id: String = role_id if role_id != "" else _get_active_role_id()
	return PLAYER_EQUIPMENT_FLOW.get_role_dodge_chance(self, resolved_role_id)

func _get_role_base_damage_reduction_value(role_id: String = "") -> float:
	var resolved_role_id: String = role_id if role_id != "" else _get_active_role_id()
	return PLAYER_COMBAT_MODIFIERS.get_role_base_damage_reduction_value(self, resolved_role_id)

func _get_role_damage_reduction_value(role_id: String = "") -> float:
	var resolved_role_id: String = role_id if role_id != "" else _get_active_role_id()
	return PLAYER_COMBAT_MODIFIERS.get_role_damage_reduction_value(self, resolved_role_id)

func _get_role_damage_reduction_rate(role_id: String = "") -> float:
	var resolved_role_id: String = role_id if role_id != "" else _get_active_role_id()
	return PLAYER_COMBAT_MODIFIERS.get_role_damage_reduction_rate(self, resolved_role_id)

func _calculate_damage_reduction_rate_from_value(damage_reduction_value: float) -> float:
	return PLAYER_COMBAT_MODIFIERS.calculate_damage_reduction_rate(damage_reduction_value)

func _get_attribute_pickup_range_bonus() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_attribute_pickup_range_bonus(self)

func _get_swordsman_trait_heal_amount() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_swordsman_trait_heal_amount(self)

func _get_swordsman_trait_heal_proc_chance() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_swordsman_trait_heal_proc_chance(self)

func _get_role_base_critical_chance(role_id: String) -> float:
	if role_id == "swordsman":
		return 0.10
	return 0.0

func _get_role_raw_critical_chance(role_id: String) -> float:
	var critical_chance: float = _get_role_base_critical_chance(role_id)
	critical_chance += float(_get_role_blessing_stat_bonus(role_id, "critical_chance"))
	if role_id == "swordsman":
		critical_chance += swordsman_ultimate_crit_bonus_chance
	return max(0.0, critical_chance)

func _get_role_critical_chance(role_id: String) -> float:
	var critical_chance: float = _get_role_raw_critical_chance(role_id)
	return clamp(critical_chance, 0.0, 1.0)

func _get_role_critical_overflow_chance(role_id: String) -> float:
	return max(0.0, _get_role_raw_critical_chance(role_id) - 1.0)

func _get_critical_damage_multiplier(role_id: String) -> float:
	var overflow_bonus: float = _get_role_critical_overflow_chance(role_id) * CRITICAL_OVERFLOW_DAMAGE_RATIO
	var blessing_bonus: float = float(_get_role_blessing_stat_bonus(role_id, "critical_damage_bonus"))
	return BASE_CRITICAL_DAMAGE_MULTIPLIER + overflow_bonus + blessing_bonus

func _roll_critical_hit(role_id: String, chance_bonus: float = 0.0) -> bool:
	var critical_chance: float = _get_role_critical_chance(role_id) + chance_bonus
	return critical_chance > 0.0 and randf() <= critical_chance

func _record_attack_result_instance(role_id: String, was_critical: bool, killed: bool, target_position: Variant = null, raw_source_role_id: String = "") -> void:
	if role_id == "":
		return
	pending_attack_result_hit_count_by_role[role_id] = int(pending_attack_result_hit_count_by_role.get(role_id, 0)) + 1
	if was_critical:
		pending_attack_result_critical_hit_count_by_role[role_id] = int(pending_attack_result_critical_hit_count_by_role.get(role_id, 0)) + 1
	if killed:
		pending_attack_result_kill_count_by_role[role_id] = int(pending_attack_result_kill_count_by_role.get(role_id, 0)) + 1
		PLAYER_GUNNER_HUNT_TALENT_FLOW.on_enemy_killed(self, role_id, target_position, raw_source_role_id)
		PLAYER_GUNNER_ENTRY_TALENT_FLOW.on_enemy_killed(self, role_id, raw_source_role_id)

func _consume_pending_attack_result_hit_count(role_id: String, fallback_hit_count: int) -> int:
	var pending_hit_count: int = int(pending_attack_result_hit_count_by_role.get(role_id, 0))
	pending_attack_result_hit_count_by_role.erase(role_id)
	return pending_hit_count if pending_hit_count > 0 else fallback_hit_count

func _consume_pending_attack_result_kill_count(role_id: String, fallback_kill_count: int, killed: bool) -> int:
	var pending_kill_count: int = int(pending_attack_result_kill_count_by_role.get(role_id, 0))
	pending_attack_result_kill_count_by_role.erase(role_id)
	if pending_kill_count > 0:
		return pending_kill_count
	return 1 if killed else fallback_kill_count

func _consume_pending_attack_result_critical_hit_count(role_id: String) -> int:
	var pending_critical_hit_count: int = int(pending_attack_result_critical_hit_count_by_role.get(role_id, 0))
	pending_attack_result_critical_hit_count_by_role.erase(role_id)
	return pending_critical_hit_count

func _get_mage_kill_energy_proc_chance() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_mage_kill_energy_proc_chance(self)

func _get_mage_kill_energy_proc_multiplier() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_mage_kill_energy_proc_multiplier(self)

func _get_mage_arcane_charge_level_talent_proc_chance_bonus() -> float:
	return PLAYER_MAGE_ARCANE_CHARGE_TALENT_FLOW.get_proc_chance_bonus(self)

func _get_role_trait_level(role_id: String) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_role_trait_level(self, role_id)

func _get_balanced_attribute_description(added_amount: float) -> String:
	return PLAYER_ATTRIBUTE_FLOW.get_balanced_attribute_description(self, added_amount)

func _add_common_prosperity() -> Dictionary:
	return PLAYER_ATTRIBUTE_FLOW.add_common_prosperity(self)

func _get_common_prosperity_switch_cooldown_multiplier() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_common_prosperity_switch_cooldown_multiplier(self)

func _get_swordsman_heart_interval_multiplier(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_swordsman_heart_interval_multiplier(level)

func _get_swordsman_heart_range_multiplier(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_swordsman_heart_range_multiplier(level)

func _get_swordsman_normal_attack_scale(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_swordsman_normal_attack_scale(level)

func _get_swordsman_normal_attack_width_scale(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_swordsman_normal_attack_width_scale(level)

func _get_swordsman_bloodthirst_ratio(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_swordsman_bloodthirst_ratio(level)

func _get_swordsman_bloodthirst_heal_cap(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_swordsman_bloodthirst_heal_cap(level)

func _get_swordsman_dodge_chance(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_swordsman_dodge_chance(level)

func _get_gunner_barrage_speed_multiplier(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_barrage_speed_multiplier(level)

func _get_gunner_barrage_interval_reduction(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_barrage_interval_reduction(level)

func _get_gunner_barrage_bounce_count(level: float) -> int:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_barrage_bounce_count(level)

func _get_gunner_barrage_shotgun_wave_count(level: float) -> int:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_barrage_shotgun_wave_count(level)

func _get_gunner_barrage_shotgun_pellet_count(level: float) -> int:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_barrage_shotgun_pellet_count(level)

func _get_gunner_barrage_split_count(level: float) -> int:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_barrage_split_count(level)

func _get_gunner_footwork_range_multiplier(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_footwork_range_multiplier(level)

func _get_gunner_footwork_move_multiplier(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_footwork_move_multiplier(level)

func _get_gunner_footwork_flat_speed_bonus(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_footwork_flat_speed_bonus(level)

func _get_mage_arcane_focus_range_multiplier(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_mage_arcane_focus_range_multiplier(level)

func _get_mage_surplus_energy_multiplier(level: float, role_id: String = "") -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_mage_surplus_energy_multiplier(level, role_id)

func _get_mage_surplus_passive_energy_per_second(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_mage_surplus_passive_energy_per_second(level)

func _get_role_attribute_range_multiplier(role_id: String) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_role_attribute_range_multiplier(self, role_id)

func _get_role_attribute_move_speed_multiplier(role_id: String) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_role_attribute_move_speed_multiplier(self, role_id)

func _get_role_attack_interval_multiplier(role_id: String) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_role_attack_interval_multiplier(self, role_id)

func _get_role_attack_interval_flat_reduction(role_id: String) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_role_attack_interval_flat_reduction(self, role_id)

func _get_ultimate_energy_gain_multiplier_for_role(role_id: String) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_ultimate_energy_gain_multiplier_for_role(self, role_id)

func _get_role_equipment_damage_multiplier_bonus(role_id: String) -> float:
	return PLAYER_EQUIPMENT_FLOW.get_role_damage_multiplier_bonus(self, role_id)

func _get_role_equipment_energy_gain_bonus(role_id: String) -> float:
	return PLAYER_EQUIPMENT_FLOW.get_role_energy_gain_bonus(self, role_id) + _get_role_blessing_stat_bonus(role_id, "energy_gain")

func _get_role_total_ultimate_energy_gain_multiplier(role_id: String) -> float:
	var total_bonus: float = 0.0
	total_bonus += max(0.0, energy_gain_multiplier - 1.0)
	total_bonus += max(0.0, _get_role_equipment_energy_gain_bonus(role_id))
	total_bonus += max(0.0, _get_ultimate_energy_gain_multiplier_for_role(role_id) - 1.0)
	if _is_mage_arcane_surplus_active():
		total_bonus += max(0.0, _get_mage_arcane_surplus_team_ultimate_energy_bonus())
	total_bonus += max(0.0, _get_mage_arcane_charge_self_energy_multiplier_for_role(role_id) - 1.0)
	return 1.0 + total_bonus

func _get_role_equipment_skill_range_multiplier(role_id: String) -> float:
	return float(PLAYER_EQUIPMENT_FLOW.get_role_bonus_summary(self, role_id).get("skill_range_multiplier", 1.0)) + _get_role_blessing_stat_bonus(role_id, "skill_range")

func _get_role_equipment_levels(role_id: String) -> Dictionary:
	return PLAYER_EQUIPMENT_FLOW.get_role_equipment_levels(self, role_id)

func _get_role_equipment_bonus_summary(role_id: String) -> Dictionary:
	return PLAYER_EQUIPMENT_FLOW.get_role_bonus_summary(self, role_id)

func transfer_role_equipment_item(equipment_id: String, from_role_id: String, target_role_id: String) -> bool:
	return PLAYER_EQUIPMENT_FLOW.transfer_equipment(self, equipment_id, from_role_id, target_role_id)

func _get_role_attribute_titles(role_id: String) -> Dictionary:
	return PLAYER_ATTRIBUTE_FLOW.get_role_attribute_titles(role_id)

func _get_role_attribute_titles_for_levels(role_id: String, levels: Dictionary) -> Dictionary:
	return PLAYER_ATTRIBUTE_FLOW.get_role_attribute_titles_for_levels(role_id, levels)

func _get_role_attribute_description(role_id: String, attribute_key: String, next_level: float) -> String:
	return PLAYER_ATTRIBUTE_FLOW.get_role_attribute_description(role_id, attribute_key, next_level)

func _get_attribute_evolved_title_color() -> Color:
	return PLAYER_ATTRIBUTE_FLOW.get_evolved_title_color()

func _is_attribute_evolved(level: float) -> bool:
	return PLAYER_ATTRIBUTE_FLOW.is_attribute_evolved(level)

func _get_max_attribute_level() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_max_attribute_level()

func _build_role_timing_state_data(default_value: Variant) -> Dictionary:
	return ROLE_DATABASE.get_role_timing_state_data(default_value)

func _build_role_resource_state_data(default_value: Variant) -> Dictionary:
	return ROLE_RESOURCE_STATE.build_for_roles(roles, default_value)

func _build_role_health_state() -> Dictionary:
	return PLAYER_ROLE_STAT_FLOW.build_role_health_state(self)

func _build_role_temporary_health_state() -> Dictionary:
	return PLAYER_ROLE_STAT_FLOW.build_role_temporary_health_state(self)

func _build_temporary_health_stack_state() -> Array:
	return PLAYER_RESOURCE_FLOW.build_temporary_health_stack_state()

func _normalize_temporary_health_stack_state(value: Variant) -> Array:
	return PLAYER_RESOURCE_FLOW.normalize_temporary_health_stack_state(value)

func _get_active_role_id() -> String:
	return PLAYER_RESOURCE_FLOW.get_active_role_id(self)

func _get_role_mana(role_id: String) -> float:
	return PLAYER_RESOURCE_FLOW.get_role_mana(self, role_id)

func _set_role_mana(role_id: String, value: float, emit_for_active: bool = true) -> void:
	PLAYER_RESOURCE_FLOW.set_role_mana(self, role_id, value, emit_for_active)

func _add_role_mana(role_id: String, amount: float, emit_for_active: bool = true) -> float:
	return PLAYER_RESOURCE_FLOW.add_role_mana(self, role_id, amount, emit_for_active)

func _add_active_role_mana(amount: float, emit_signal: bool = true) -> float:
	return PLAYER_RESOURCE_FLOW.add_active_role_mana(self, amount, emit_signal)

func _get_role_ultimate_lock_remaining(role_id: String) -> float:
	return PLAYER_RESOURCE_FLOW.get_role_ultimate_lock_remaining(self, role_id)

func _set_role_ultimate_lock_remaining(role_id: String, value: float) -> void:
	PLAYER_RESOURCE_FLOW.set_role_ultimate_lock_remaining(self, role_id, value)

func _sync_active_role_ultimate_state() -> void:
	PLAYER_RESOURCE_FLOW.sync_active_role_ultimate_state(self)

func _emit_active_mana_changed() -> void:
	PLAYER_RESOURCE_FLOW.emit_active_mana_changed(self)

func _get_card_level(card_id: String) -> int:
	return 0

func _has_skill_talent(talent_id: String) -> bool:
	return PLAYER_SKILL_TALENT_SYSTEM.has_talent(self, talent_id)

func get_pending_skill_talent_choices() -> Array:
	return PLAYER_SKILL_TALENT_SYSTEM.get_pending_choices(self)

func build_next_skill_talent_offer() -> Dictionary:
	return PLAYER_SKILL_TALENT_SYSTEM.build_next_offer(self)

func refresh_skill_talent_card(option_index: int, role_id: String = "") -> Array:
	return PLAYER_SKILL_TALENT_SYSTEM.refresh_offer_card(self, option_index, role_id)

func apply_skill_talent_choice(option_id: String, expected_progress_id: String = "") -> bool:
	return PLAYER_SKILL_TALENT_SYSTEM.apply_choice(self, option_id, expected_progress_id)

func queue_level_talent_choice(_reached_level: int) -> void:
	pending_level_talent_choices += 1

func _clear_skill_talent_runtime_state(removed_ids: Array) -> void:
	var swordsman_keys := {
		"swordsman_basic_cooldown_cut": ["basic_cooldown_cut_lock_remaining"],
		"swordsman_trait_blood_surge": ["blood_surge_remaining"],
		"swordsman_trait_guard_stance": ["guard_stance_remaining"],
		"swordsman_trait_head_high": ["head_high_remaining"],
		"swordsman_trait_unyielding": ["unyielding_remaining", "unyielding_cooldown_remaining"],
		"swordsman_entry_through_ranks": ["entry_move_speed_remaining"],
		"swordsman_blade_storm_returning_gale": ["returning_gale_remaining", "returning_gale_role_id"],
		"swordsman_ultimate_triumph": ["ultimate_triumph_remaining"]
	}
	var gunner_keys := {
		"gunner_basic_steady_aim": ["steady_aim_elapsed"],
		"gunner_entry_follow_fire": ["follow_fire_remaining"],
		"gunner_trait_escape_step": ["escape_step_remaining"],
		"gunner_trait_execution": ["execution_cooldown_remaining"]
	}
	var swordsman_state := _get_role_special_state("swordsman")
	var gunner_state := _get_role_special_state("gunner")
	var gunner_runtime: Dictionary = gunner_state.get("talent_runtime", {})
	var mage_state := _get_role_special_state("mage")
	for talent_value in removed_ids:
		var talent_id := str(talent_value)
		for key in swordsman_keys.get(talent_id, []):
			swordsman_state.erase(key)
		for key in gunner_keys.get(talent_id, []):
			gunner_runtime.erase(key)
		if talent_id == "swordsman_trait_blood_battle" and switch_power_role_id == "swordsman" and switch_power_label == "血战昂扬":
			switch_power_remaining = 0.0
			switch_power_role_id = ""
			switch_power_damage_multiplier = 1.0
			switch_power_interval_bonus = 0.0
			switch_power_label = ""
		if talent_id == "mage_trait_dawn":
			mage_state.erase("arcane_dawn_armed")
		if talent_id in ["mage_trait_relay", "mage_trait_relay_chain"]:
			mage_state.erase("arcane_relay_count")
			mage_arcane_charge_transfer_relay_used = false
	role_special_states["swordsman"] = swordsman_state
	gunner_state["talent_runtime"] = gunner_runtime
	role_special_states["gunner"] = gunner_state
	role_special_states["mage"] = mage_state

func get_skill_progress_level(role_id: String, progress_id: String) -> int:
	return PLAYER_SKILL_TALENT_SYSTEM.get_skill_progress_level(self, role_id, progress_id)

func get_skill_talent_display(role_id: String, progress_id: String) -> Dictionary:
	return PLAYER_SKILL_TALENT_SYSTEM.get_display(self, role_id, progress_id)

func get_skill_talent_display_for_skill_id(skill_id: String) -> Dictionary:
	return PLAYER_SKILL_TALENT_SYSTEM.get_display_for_skill_id(self, skill_id)

func _project_skill_talent_payload(skill_id: String, payload: Dictionary, include_description: bool = true) -> Dictionary:
	return PLAYER_SKILL_TALENT_SYSTEM.project_skill_payload(self, skill_id, payload, include_description)

func _project_skill_talent_build_option(option: Dictionary) -> Dictionary:
	return PLAYER_SKILL_TALENT_SYSTEM.project_build_option(self, option)

func _get_role_blessing_stat_bonus(role_id: String, stat: String) -> float:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_role_stat_bonus(self, role_id, stat)

func _get_blazing_sun_flat_base_damage(role_id: String) -> float:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_blazing_sun_flat_base_damage(self, role_id)

func _tick_blessing_health_regen(delta: float) -> void:
	PLAYER_BLESSING_SKILL_BRIDGE.tick_blessing_health_regen(self, delta)

func _get_skill_blessing_stat_bonus(stat: String) -> float:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_skill_stat_bonus(self, stat)

func _get_skill_blessing_effect_scales(stat: String) -> Array[float]:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_skill_effect_scales(self, stat)

func _get_skill_blessing_effect_scales_for_skill(skill_id: String, stat: String) -> Array[float]:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_skill_effect_scales_for_skill(self, skill_id, stat)

func get_role_blessing_levels(role_id: String) -> Dictionary:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_role_blessing_levels(self, role_id)

func get_skill_blessing_levels() -> Dictionary:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_skill_blessing_levels(self)

func _refresh_blessing_skill_unlocks(selected_blessing_id: String = "", selected_tier: int = 0, selected_binding: String = "") -> void:
	PLAYER_BLESSING_SKILL_BRIDGE.refresh_unlocks(self, selected_blessing_id, selected_tier, selected_binding)

func consume_pending_blessing_binding_choice() -> Dictionary:
	return PLAYER_BLESSING_SKILL_BRIDGE.consume_pending_binding_choice(self)

func build_blessing_binding_options(choice: Dictionary) -> Array:
	return PLAYER_BLESSING_SKILL_BRIDGE.build_binding_options(self, choice)

func apply_blessing_binding_choice(choice: Dictionary, option_id: String) -> bool:
	return PLAYER_BLESSING_SKILL_BRIDGE.apply_binding_choice(self, choice, option_id)

func _show_blessing_skill_event_tag(event: Dictionary) -> void:
	PLAYER_BLESSING_SKILL_BRIDGE.show_skill_event_tag(self, event)

func _is_blessing_skill_unlocked(skill_id: String) -> bool:
	return PLAYER_BLESSING_SKILL_BRIDGE.is_skill_unlocked(self, skill_id)

func _get_blessing_skill_tier(skill_id: String) -> int:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_skill_tier(self, skill_id)

func _get_entry_rescue_regen_per_second() -> float:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_entry_rescue_regen_per_second(self)

func _get_hero_entry_effect() -> Dictionary:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_hero_entry_effect(self)

func _get_blessing_skill_quantity_count(skill_id: String) -> int:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_quantity_count(self, skill_id)

func _get_blessing_skill_combo_scales(skill_id: String) -> Array[float]:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_combo_scales(self, skill_id)

func _get_blessing_skill_duration_multiplier(skill_id: String) -> float:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_duration_multiplier(self, skill_id)

func _get_blessing_skill_duration_flat_bonus(skill_id: String) -> float:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_duration_flat_bonus(self, skill_id)

func _get_blessing_ultimate_damage_multiplier(skill_id: String) -> float:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_ultimate_damage_multiplier(self, skill_id)

func _get_blessing_ultimate_special_effect_multiplier(skill_id: String) -> float:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_ultimate_special_effect_multiplier(self, skill_id)

func _get_kebiru_magic_cooldown_multiplier(skill_id: String) -> float:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_kebiru_magic_cooldown_multiplier(self, skill_id)

func _get_kebiru_magic_range_multiplier(skill_id: String) -> float:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_kebiru_magic_range_multiplier(self, skill_id)

func _get_invoker_magic_range_multiplier(skill_id: String) -> float:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_invoker_magic_range_multiplier(self, skill_id)

func get_skill_next_requirement_text(skill_id: String) -> String:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_skill_next_requirement_text(self, skill_id)

func get_skill_graph_text(role_id_filter: String = "") -> String:
	var graph_text := PLAYER_BLESSING_SKILL_BRIDGE.get_skill_graph_text(self, role_id_filter)
	if role_id_filter == "":
		return graph_text
	var progress_text := PLAYER_SKILL_TALENT_SYSTEM.get_progress_text(self, role_id_filter)
	if progress_text == "":
		return graph_text
	return "%s\n\n[color=#f3d35a][b]技能构筑与质变[/b][/color]\n%s" % [graph_text, progress_text]

func _get_basic_attack_range_multiplier(skill_id: String) -> float:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_basic_attack_range_multiplier(self, skill_id)

func _get_basic_attack_projectile_speed_multiplier(skill_id: String) -> float:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_basic_attack_projectile_speed_multiplier(self, skill_id)

func _has_elite_relic(relic_id: String) -> bool:
	return bool(elite_relics_unlocked.get(relic_id, false))

func _unlock_elite_relic(relic_id: String) -> void:
	elite_relics_unlocked[relic_id] = true

func _get_role_theme_color(role_id: String) -> Color:
	return PLAYER_ROLE_STAT_FLOW.get_role_theme_color(self, role_id)

func _announce_completed_final_set(set_key: String) -> void:
	return

func _increase_role_special(role_id: String, key: String, amount: int = 1) -> void:
	PLAYER_RESOURCE_FLOW.increase_role_special(self, role_id, key, amount)

func _increase_team_specials(entries: Array) -> void:
	PLAYER_RESOURCE_FLOW.increase_team_specials(self, entries)

func _get_active_interval_bonus(role_id: String) -> float:
	return PLAYER_ROLE_STAT_FLOW.get_active_interval_bonus(self, role_id)

func _get_effective_attack_interval(role_id: String) -> float:
	return PLAYER_ROLE_STAT_FLOW.get_effective_attack_interval(self, role_id)

func _get_effective_background_attack_interval(role_id: String) -> float:
	return PLAYER_ROLE_STAT_FLOW.get_effective_background_attack_interval(self, role_id)

func _get_effective_background_interval_multiplier() -> float:
	return PLAYER_ROLE_STAT_FLOW.get_effective_background_interval_multiplier(self)

func _clear_standby_entry_buff() -> void:
	PLAYER_SWITCH_FLOW.clear_standby_entry_buff(self)

func _apply_rotation_entry_bonus(role_id: String) -> void:
	PLAYER_SWITCH_FLOW.apply_rotation_entry_bonus(self, role_id)

func _apply_swap_guard(direction: Vector2) -> void:
	PLAYER_SWITCH_FLOW.apply_swap_guard(self, direction)

func _activate_guard_cover() -> void:
	PLAYER_SWITCH_FLOW.activate_guard_cover(self)

func _trigger_rearguard_attack(role_id: String, origin: Vector2, level: int) -> int:
	return PLAYER_SWITCH_FLOW.trigger_rearguard_attack(self, role_id, origin, level)

func _get_priority_target_bonus(enemy: Node) -> float:
	return PLAYER_COMBAT_MODIFIERS.get_priority_target_bonus(self, enemy)

func _is_last_stand_active() -> bool:
	return PLAYER_COMBAT_MODIFIERS.is_last_stand_active(self)

func _get_effective_damage_taken_multiplier() -> float:
	return PLAYER_COMBAT_MODIFIERS.get_effective_damage_taken_multiplier(self)

func _get_equipment_low_health_damage_taken_multiplier() -> float:
	return PLAYER_EQUIPMENT_FLOW.get_low_health_damage_taken_multiplier(self)

func _get_equipment_low_health_damage_reduction_value() -> float:
	return PLAYER_EQUIPMENT_FLOW.get_low_health_damage_reduction_value(self)

func _get_equipment_skill_range_multiplier() -> float:
	return PLAYER_EQUIPMENT_FLOW.get_skill_range_multiplier(self) * _get_role_attribute_range_multiplier(str(_get_active_role().get("id", "")))

func _get_equipment_cooldown_multiplier() -> float:
	return PLAYER_EQUIPMENT_FLOW.get_cooldown_multiplier(self)

func _apply_equipment_passives(delta: float) -> void:
	PLAYER_EQUIPMENT_FLOW.apply_passives(self, delta)

func _try_equipment_dodge() -> bool:
	return PLAYER_EQUIPMENT_FLOW.try_dodge(self)

func _get_gunner_flash_dodge_value(role_id: String = "") -> float:
	var resolved_role_id: String = role_id if role_id != "" else str(_get_active_role().get("id", ""))
	if resolved_role_id != "gunner" or str(_get_active_role().get("id", "")) != "gunner":
		return 0.0
	var value_per_stack := GUNNER_FLASH_DODGE_VALUE_PER_STACK + PLAYER_BUILD_SYSTEM.get_gunner_flash_dodge_bonus_per_stack(self)
	return float(PLAYER_GUNNER_FLASH_TALENT_FLOW.get_active_flash_stacks(self)) * value_per_stack

func _lock_player_actions(duration: float) -> void:
	player_action_lock_remaining = max(player_action_lock_remaining, max(0.0, duration))
	velocity = Vector2.ZERO

func _unlock_player_actions() -> void:
	player_action_lock_remaining = 0.0

func _is_player_action_locked() -> bool:
	return player_action_lock_remaining > 0.0

func _is_status_immune() -> bool:
	return switch_invulnerability_remaining > 0.0

func apply_healing_block(duration: float) -> void:
	healing_block_remaining = max(healing_block_remaining, max(0.0, duration))

func is_healing_blocked() -> bool:
	return healing_block_remaining > 0.0

func apply_aging(duration: float) -> void:
	if _is_status_immune():
		return
	aging_remaining = max(aging_remaining, max(0.0, duration))

func apply_confinement(center: Vector2, radius: float, duration: float, polygon: PackedVector2Array = PackedVector2Array()) -> void:
	if _is_status_immune():
		return
	confinement_center = center
	confinement_radius = max(0.0, radius)
	confinement_polygon = polygon
	confinement_remaining = max(confinement_remaining, max(0.0, duration))

func _clamp_to_active_map_bounds() -> void:
	PLAYER_MAP_BOUNDS_FLOW.clamp_to_active_map_bounds(self)

func _unhandled_input(event: InputEvent) -> void:
	PLAYER_SURVIVAL_FLOW.unhandled_input(self, event)

func _physics_process(delta: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.update_effect_animations(delta)
	PLAYER_AUTHORED_EFFECTS.update_effect_animations(delta)
	PLAYER_VISUAL_STATE.update_visual_pulses(delta)
	PLAYER_SURVIVAL_FLOW.physics_process(self, delta)
	if not is_dead:
		PLAYER_MAP_BOUNDS_FLOW.clamp_to_active_map_bounds(self)
	queue_redraw()

func _draw() -> void:
	if is_dead:
		return
	if str(_get_active_role().get("id", "")) != "gunner":
		return
	var safe_zone_radius := _get_gunner_safe_zone_radius()
	if safe_zone_radius <= 0.0:
		return
	draw_circle(Vector2.ZERO, safe_zone_radius, GUNNER_SAFE_ZONE_FILL_COLOR)
	draw_arc(
		Vector2.ZERO,
		safe_zone_radius,
		0.0,
		TAU,
		64,
		GUNNER_SAFE_ZONE_OUTLINE_COLOR,
		GUNNER_SAFE_ZONE_OUTLINE_WIDTH,
		true
	)

func _update_timers(delta: float) -> void:
	PLAYER_TIMER_FLOW.update_timers(self, delta)

func _tick_gunner_flash_trait(delta: float) -> void:
	if delta <= 0.0:
		return
	PLAYER_GUNNER_FLASH_TALENT_FLOW.clamp_base_flash_stacks(self)
	if gunner_flash_cooldown_remaining > 0.0:
		gunner_flash_cooldown_remaining = max(0.0, gunner_flash_cooldown_remaining - delta)
		if gunner_flash_cooldown_remaining <= 0.0:
			gunner_flash_stack_elapsed = 0.0
		return
	if str(_get_active_role().get("id", "")) != "gunner":
		gunner_flash_stack_elapsed = 0.0
		return
	var clear_hunt: bool = _has_skill_talent("gunner_trait_clear_hunt")
	var invade_hunt: bool = _has_skill_talent("gunner_trait_invade_hunt")
	if clear_hunt or invade_hunt:
		gunner_hunt_presence_check_remaining -= delta
		if gunner_hunt_presence_check_remaining <= 0.0:
			gunner_hunt_presence_check_remaining = 0.25
			gunner_hunt_has_enemy = _count_enemies_in_radius(global_position, _get_gunner_safe_zone_radius()) > 0
		if (clear_hunt and gunner_hunt_has_enemy) or (invade_hunt and not gunner_hunt_has_enemy):
			return
	var base_capacity := PLAYER_GUNNER_FLASH_TALENT_FLOW.get_base_flash_stack_capacity(self)
	if gunner_flash_stacks >= base_capacity:
		gunner_flash_stacks = base_capacity
		gunner_flash_stack_elapsed = 0.0
		return
	gunner_flash_stack_elapsed += delta
	var stack_interval: float = GUNNER_HUNT_STACK_INTERVAL if clear_hunt or invade_hunt else GUNNER_FLASH_STACK_INTERVAL
	while gunner_flash_stack_elapsed >= stack_interval and gunner_flash_stacks < base_capacity:
		gunner_flash_stack_elapsed -= stack_interval
		gunner_flash_stacks = min(base_capacity, gunner_flash_stacks + 1)

func _break_gunner_flash_trait() -> void:
	if str(_get_active_role().get("id", "")) != "gunner":
		return
	gunner_flash_stacks = 0
	gunner_flash_stack_elapsed = 0.0
	gunner_flash_cooldown_remaining = GUNNER_FLASH_COOLDOWN

func _clear_gunner_flash_trait_on_switch() -> void:
	gunner_flash_stacks = 0
	gunner_flash_stack_elapsed = 0.0
	gunner_hunt_presence_check_remaining = 0.0
	gunner_hunt_has_enemy = false
	PLAYER_GUNNER_HUNT_TALENT_FLOW.clear_switch_limited_state(self)

func _get_gunner_flash_damage_multiplier() -> float:
	if str(_get_active_role().get("id", "")) != "gunner":
		return 1.0
	var bonus_per_stack := GUNNER_FLASH_DAMAGE_PER_STACK + PLAYER_BUILD_SYSTEM.get_gunner_flash_damage_bonus_per_stack(self)
	return 1.0 + float(PLAYER_GUNNER_FLASH_TALENT_FLOW.get_active_flash_stacks(self)) * bonus_per_stack

func _get_gunner_flash_move_speed_multiplier() -> float:
	var bonus_per_stack := GUNNER_FLASH_SPEED_PER_STACK + PLAYER_BUILD_SYSTEM.get_gunner_flash_speed_bonus_per_stack(self)
	return 1.0 + float(PLAYER_GUNNER_FLASH_TALENT_FLOW.get_active_flash_stacks(self)) * bonus_per_stack

func _get_gunner_hunt_dodge_value(role_id: String = "") -> float:
	var resolved_role_id: String = role_id if role_id != "" else str(_get_active_role().get("id", ""))
	return PLAYER_GUNNER_HUNT_TALENT_FLOW.get_dodge_value(self, resolved_role_id)

func _get_gunner_hunt_move_speed_bonus(role_id: String = "") -> float:
	var resolved_role_id: String = role_id if role_id != "" else str(_get_active_role().get("id", ""))
	return PLAYER_GUNNER_HUNT_TALENT_FLOW.get_move_speed_bonus(self, resolved_role_id)

func _get_gunner_hunt_damage_multiplier(role_id: String = "") -> float:
	var resolved_role_id: String = role_id if role_id != "" else str(_get_active_role().get("id", ""))
	return PLAYER_GUNNER_HUNT_TALENT_FLOW.get_damage_multiplier(self, resolved_role_id)

func _get_mage_arcane_charge_skill_cooldown_multiplier(role_id: String = "") -> float:
	var resolved_role_id: String = role_id if role_id != "" else str(_get_active_role().get("id", ""))
	return PLAYER_MAGE_ARCANE_CHARGE_TALENT_FLOW.get_skill_cooldown_multiplier(self, resolved_role_id)

func _get_mage_arcane_charge_ultimate_damage_multiplier(role_id: String = "") -> float:
	var resolved_role_id: String = role_id if role_id != "" else str(_get_active_role().get("id", ""))
	return PLAYER_MAGE_ARCANE_CHARGE_TALENT_FLOW.get_ultimate_damage_multiplier(self, resolved_role_id)

func _get_gunner_safe_zone_radius() -> float:
	return max(0.0, GUNNER_SAFE_ZONE_RADIUS + PLAYER_BUILD_SYSTEM.get_gunner_hunt_safe_radius_bonus(self))

func _get_gunner_flash_buff_slot() -> Dictionary:
	if str(_get_active_role().get("id", "")) != "gunner":
		return {}
	var total_flash_stacks := PLAYER_GUNNER_FLASH_TALENT_FLOW.get_active_flash_stacks(self)
	if gunner_flash_cooldown_remaining > 0.0:
		return {
			"name": "\u77AC\u6740\u51B7\u5374",
			"description": "\u77AC\u6740\u51B7\u5374\u4E2D\uFF0C\u51B7\u5374\u7ED3\u675F\u540E\u4ECE\u5F53\u524D\u5C42\u6570\u7EE7\u7EED\u79EF\u7D2F",
			"text": "\u77AC",
			"stacks": total_flash_stacks,
			"remaining": gunner_flash_cooldown_remaining,
			"duration": GUNNER_FLASH_COOLDOWN,
			"color": Color(0.28, 0.58, 1.0, 0.88),
			"cooldown": true
		}
	if total_flash_stacks <= 0:
		return {}
	var stack_interval: float = GUNNER_HUNT_STACK_INTERVAL if _has_skill_talent("gunner_trait_clear_hunt") or _has_skill_talent("gunner_trait_invade_hunt") else GUNNER_FLASH_STACK_INTERVAL
	var interval_label := "1.25" if stack_interval == GUNNER_HUNT_STACK_INTERVAL else "2"
	var has_execution_2 := PLAYER_GUNNER_FLASH_TALENT_FLOW.has_level_talent(self, "gunner_level_talent_execution_2")
	var stack_limit_text := "15层，其中闪避永久层最多5层" if has_execution_2 else "10层"
	return {
		"name": "\u77AC\u6740",
		"description": "\u6BCF%s\u79D2\u83B7\u5F971\u5C42\uff0c\u6BCF\u5C42\u63D0\u4F9B3%%\u4F24\u5BB3\u30013%%\u79FB\u901F\u548C4\u95EA\u907F\u503C\uff0C\u6700\u591A%s" % [interval_label, stack_limit_text],
		"text": "\u77AC",
		"stacks": total_flash_stacks,
		"remaining": max(0.0, stack_interval - gunner_flash_stack_elapsed),
		"duration": stack_interval,
		"color": Color(0.25, 0.74, 1.0, 0.95),
		"cooldown": false
	}

func _add_mage_arcane_charge_stack() -> void:
	_add_mage_arcane_charge_stacks(1)

func _add_mage_arcane_charge_stacks(count: int) -> void:
	if str(_get_active_role().get("id", "")) != "mage":
		return
	if count <= 0:
		return
	mage_arcane_charge_stacks = clampi(mage_arcane_charge_stacks + count, 0, MAGE_ARCANE_CHARGE_MAX_STACKS)
	stats_changed.emit(get_frame_hud_summary())

func _clear_mage_arcane_charge_on_switch() -> void:
	mage_arcane_charge_stacks = 0
	_clear_mage_arcane_charge_transfer(false)
	stats_changed.emit(get_frame_hud_summary())

func _transfer_mage_arcane_charge_to_role_on_switch(target_role_id: String) -> void:
	var transfer_stacks: int = clampi(mage_arcane_charge_stacks, 0, MAGE_ARCANE_CHARGE_MAX_STACKS)
	mage_arcane_charge_stacks = 0
	if transfer_stacks <= 0 or target_role_id == "":
		_clear_mage_arcane_charge_transfer(false)
		stats_changed.emit(get_frame_hud_summary())
		return
	if mage_role != null:
		mage_role.record_arcane_dawn(self, transfer_stacks)
	mage_arcane_charge_transfer_stacks = transfer_stacks
	mage_arcane_charge_transfer_target_role_id = target_role_id
	var base_duration := float(transfer_stacks) * MAGE_ARCANE_CHARGE_TRANSFER_DURATION_PER_STACK
	mage_arcane_charge_transfer_duration = mage_role.get_arcane_transfer_duration(self, transfer_stacks, base_duration) if mage_role != null else base_duration
	mage_arcane_charge_transfer_remaining = mage_arcane_charge_transfer_duration
	_set_mage_arcane_relay_count(0)
	stats_changed.emit(get_frame_hud_summary())

func _relay_mage_arcane_charge_on_switch(previous_role_id: String, target_role_id: String) -> void:
	if mage_arcane_charge_transfer_remaining <= 0.0:
		return
	if previous_role_id != mage_arcane_charge_transfer_target_role_id:
		return
	if target_role_id == "mage":
		_clear_mage_arcane_charge_transfer()
		return
	var relay_limit := mage_role.get_arcane_relay_limit(self) if mage_role != null else (1 if _has_skill_talent("mage_trait_relay") else 0)
	var relay_count := _get_mage_arcane_relay_count()
	if relay_count < relay_limit and target_role_id != "":
		mage_arcane_charge_transfer_target_role_id = target_role_id
		mage_arcane_charge_transfer_remaining = mage_role.get_arcane_relay_remaining(self, mage_arcane_charge_transfer_remaining) if mage_role != null else mage_arcane_charge_transfer_remaining
		_set_mage_arcane_relay_count(relay_count + 1)
		stats_changed.emit(get_frame_hud_summary())
		return
	_clear_mage_arcane_charge_transfer()

func _clear_mage_arcane_charge_transfer(emit_stats_changed: bool = true) -> void:
	mage_arcane_charge_transfer_stacks = 0
	mage_arcane_charge_transfer_remaining = 0.0
	mage_arcane_charge_transfer_duration = 0.0
	mage_arcane_charge_transfer_target_role_id = ""
	_set_mage_arcane_relay_count(0)
	if emit_stats_changed:
		stats_changed.emit(get_frame_hud_summary())

func _get_mage_arcane_relay_count() -> int:
	var state := _get_role_special_state("mage")
	return max(0, int(state.get("arcane_relay_count", 1 if mage_arcane_charge_transfer_relay_used else 0)))

func _set_mage_arcane_relay_count(count: int) -> void:
	var state := _get_role_special_state("mage")
	if count > 0:
		state["arcane_relay_count"] = count
	else:
		state.erase("arcane_relay_count")
	role_special_states["mage"] = state
	mage_arcane_charge_transfer_relay_used = count > 0

func _get_mage_arcane_charge_effective_stacks_for_role(role_id: String) -> int:
	if role_id == "mage":
		return clampi(mage_arcane_charge_stacks, 0, MAGE_ARCANE_CHARGE_MAX_STACKS)
	if role_id != "" and role_id == mage_arcane_charge_transfer_target_role_id and mage_arcane_charge_transfer_remaining > 0.0:
		return clampi(mage_arcane_charge_transfer_stacks, 0, MAGE_ARCANE_CHARGE_MAX_STACKS)
	return 0

func _does_role_hold_mage_arcane_charge_effect(role_id: String) -> bool:
	return _get_mage_arcane_charge_effective_stacks_for_role(role_id) > 0

func _get_mage_arcane_charge_holder_role_id() -> String:
	if mage_arcane_charge_transfer_remaining > 0.0 and mage_arcane_charge_transfer_target_role_id != "":
		return mage_arcane_charge_transfer_target_role_id
	if mage_arcane_charge_stacks > 0:
		return "mage"
	return ""

func _get_mage_arcane_charge_share_ratio_for_role(role_id: String) -> float:
	var share_per_stack := MAGE_ARCANE_CHARGE_SHARE_PER_STACK + PLAYER_BUILD_SYSTEM.get_mage_arcane_charge_share_bonus_per_stack(self)
	return float(_get_mage_arcane_charge_effective_stacks_for_role(role_id)) * share_per_stack

func _get_mage_arcane_charge_share_ratio() -> float:
	return _get_mage_arcane_charge_share_ratio_for_role(str(_get_active_role().get("id", "")))

func _get_mage_arcane_charge_self_energy_multiplier_for_role(role_id: String) -> float:
	var energy_per_stack := MAGE_ARCANE_CHARGE_SELF_ENERGY_PER_STACK + PLAYER_BUILD_SYSTEM.get_mage_arcane_charge_energy_bonus_per_stack(self)
	return 1.0 + float(_get_mage_arcane_charge_effective_stacks_for_role(role_id)) * energy_per_stack

func _get_mage_arcane_charge_self_energy_multiplier() -> float:
	return _get_mage_arcane_charge_self_energy_multiplier_for_role(str(_get_active_role().get("id", "")))

func _get_mage_arcane_charge_damage_multiplier() -> float:
	return 1.0

func _is_mage_arcane_surplus_active() -> bool:
	return mage_arcane_surplus_remaining > 0.0

func _get_mage_arcane_surplus_damage_multiplier(role_id: String = "") -> float:
	var resolved_role_id: String = role_id if role_id != "" else str(_get_active_role().get("id", ""))
	return PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.get_damage_multiplier(self, resolved_role_id)

func _get_mage_arcane_surplus_skill_cooldown_tick_multiplier(role_id: String = "") -> float:
	var resolved_role_id: String = role_id if role_id != "" else str(_get_active_role().get("id", ""))
	return PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.get_skill_cooldown_tick_multiplier(self, resolved_role_id)

func _get_mage_arcane_surplus_team_ultimate_energy_bonus() -> float:
	if not _is_mage_arcane_surplus_active():
		return 0.0
	return MAGE_ARCANE_SURPLUS_TEAM_ULTIMATE_ENERGY_BONUS

func _get_mage_arcane_surplus_switch_energy_bonus() -> float:
	if not _is_mage_arcane_surplus_active():
		return 0.0
	return MAGE_ARCANE_SURPLUS_SWITCH_ENERGY_BONUS

func _get_mage_arcane_charge_buff_slot() -> Dictionary:
	var active_role_id: String = str(_get_active_role().get("id", ""))
	var transfer_active: bool = active_role_id == mage_arcane_charge_transfer_target_role_id and mage_arcane_charge_transfer_remaining > 0.0
	if active_role_id != "mage" and mage_arcane_surplus_remaining <= 0.0 and not transfer_active:
		return {}
	var name := "奥法盈余" if mage_arcane_surplus_remaining > 0.0 else "奥数充能"
	var description := ""
	if mage_arcane_surplus_remaining > 0.0:
		var surplus_descriptions: Array[String] = ["持续5秒：全员大招回能效率+20%，切人回能效率+20%"]
		if PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.has_level_talent(self, PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.TALENT_ARCANE_SURPLUS_1):
			surplus_descriptions.append("当前角色伤害+10%")
		if PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.has_level_talent(self, PLAYER_MAGE_ARCANE_SURPLUS_TALENT_FLOW.TALENT_ARCANE_SURPLUS_2):
			surplus_descriptions.append("当前角色技能冷却计数加快，10s约9s走完")
		description = "；".join(surplus_descriptions)
	else:
		description = "每层提升法师自身2%大招回能效率，并将法师自身获得的大招能量的10%同步给另外两名角色；切人后会按当前层数完整继承给下一个角色，并持续同等秒数"
	var display_stacks: int = _get_mage_arcane_charge_effective_stacks_for_role(active_role_id)
	if mage_arcane_surplus_remaining <= 0.0 and display_stacks <= 0:
		return {}
	return {
		"name": name,
		"description": description,
		"text": "盈" if mage_arcane_surplus_remaining > 0.0 else "奥",
		"stacks": display_stacks,
		"remaining": mage_arcane_surplus_remaining if mage_arcane_surplus_remaining > 0.0 else (mage_arcane_charge_transfer_remaining if transfer_active else 1.0),
		"duration": MAGE_ARCANE_SURPLUS_DURATION if mage_arcane_surplus_remaining > 0.0 else (max(1.0, mage_arcane_charge_transfer_duration) if transfer_active else 1.0),
		"color": Color(0.25, 0.74, 1.0, 0.95),
		"cooldown": false
	}

func _get_swordsman_bloodthirst_buff_slot() -> Dictionary:
	if _get_active_role_id() != "swordsman" or swordsman_entry_trait_share_remaining <= 0.0:
		return {}
	return {
		"name": "嗜血",
		"description": "无敌期间，战意与贪婪触发的回复会同步作用到另外两名角色。无敌斩结束后会进入4.5秒的强化嗜血，回复效果提升至1.5倍",
		"text": "嗜",
		"stacks": 0,
		"remaining": swordsman_entry_trait_share_remaining,
		"duration": SWORDSMAN_BLOODTHIRST_DURATION,
		"color": Color(0.96, 0.82, 0.24, 0.95),
		"cooldown": false,
		"base_color": Color(0.66, 0.42, 0.08, 0.92)
	}

func _get_swordsman_will_buff_slot() -> Dictionary:
	if swordsman_death_defiance_will_remaining > 0.0:
		return {
			"name": "骑士荣耀",
			"description": "受到致命伤害时不会立刻死亡，而是保留1点生命并进入无敌",
			"text": "荣",
			"stacks": 0,
			"remaining": swordsman_death_defiance_will_remaining,
			"duration": SWORDSMAN_DEATH_DEFIANCE_INVULNERABILITY,
			"color": Color(0.28, 0.58, 1.0, 0.88),
			"cooldown": false,
			"base_color": Color(0.08, 0.22, 0.58, 0.92)
		}
	if swordsman_death_defiance_cooldown_remaining > 0.0:
		return {
			"name": "骑士荣耀冷却",
			"description": "骑士荣耀冷却中",
			"text": "荣",
			"stacks": 0,
			"remaining": swordsman_death_defiance_cooldown_remaining,
			"duration": SWORDSMAN_DEATH_DEFIANCE_COOLDOWN,
			"color": Color(0.28, 0.58, 1.0, 0.88),
			"cooldown": true
		}
	return {}

func _apply_developer_no_cooldown() -> void:
	PLAYER_TIMER_FLOW.apply_developer_no_cooldown(self)

func _regenerate_energy(delta: float) -> void:
	PLAYER_SURVIVAL_FLOW.regenerate_energy(self, delta)

func _update_facing_direction() -> void:
	PLAYER_SURVIVAL_FLOW.update_facing_direction(self)

func _toggle_attack_aim_mode() -> void:
	PLAYER_SURVIVAL_FLOW.toggle_attack_aim_mode(self)

func _get_attack_aim_direction(fallback_direction: Vector2 = Vector2.RIGHT) -> Vector2:
	return PLAYER_SURVIVAL_FLOW.get_attack_aim_direction(self, fallback_direction)

func _update_background_effects(delta: float) -> void:
	PLAYER_ATTACK_LOOP_FLOW.update_background_effects(self, delta)

func _trigger_background_effect(role_index: int) -> void:
	PLAYER_ATTACK_LOOP_FLOW.trigger_background_effect(self, role_index)

func _perform_active_attack() -> void:
	PLAYER_ATTACK_LOOP_FLOW.perform_active_attack(self)

func _get_live_mouse_aim_direction(fallback_direction: Vector2 = Vector2.RIGHT) -> Vector2:
	var mouse_direction: Vector2 = get_global_mouse_position() - global_position
	if mouse_direction.length_squared() > 4.0:
		facing_direction = mouse_direction.normalized()
		return facing_direction
	if facing_direction.length_squared() > 0.001:
		return facing_direction.normalized()
	if fallback_direction.length_squared() > 0.001:
		return fallback_direction.normalized()
	return Vector2.RIGHT

func _try_trigger_swordsman_knight_thrust() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_swordsman_knight_thrust(self)

func _try_trigger_swordsman_king_blade() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_swordsman_king_blade(self)

func _try_trigger_swordsman_judgement_sword() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_swordsman_judgement_sword(self)

func _try_trigger_swordsman_blade_storm() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_swordsman_blade_storm(self)

func _try_trigger_swordsman_crescent_wave() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_swordsman_crescent_wave(self)

func _try_trigger_gunner_explosive_round() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_gunner_explosive_round(self)

func _try_trigger_gunner_magic_grenade() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_gunner_magic_grenade(self)

func _try_trigger_gunner_magic_eye() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_gunner_magic_eye(self)

func _try_trigger_gunner_infinite_reload() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_gunner_infinite_reload(self)

func _try_handle_manual_skill_slot(slot_index: int) -> bool:
	return PLAYER_ABILITY_FLOW.try_handle_manual_skill_slot(self, slot_index)

func _try_trigger_gunner_shrapnel_field() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_gunner_shrapnel_field(self)

func _start_swordsman_blade_storm() -> void:
	PLAYER_ABILITY_FLOW.start_swordsman_blade_storm(self)

func is_swordsman_blade_storm_active() -> bool:
	return PLAYER_ABILITY_FLOW.is_swordsman_blade_storm_active(self)

func _start_swordsman_knight_thrust() -> void:
	PLAYER_ABILITY_FLOW.start_swordsman_knight_thrust(self)

func _start_swordsman_king_blade() -> void:
	PLAYER_ABILITY_FLOW.start_swordsman_king_blade(self)

func _start_swordsman_judgement_sword() -> void:
	PLAYER_ABILITY_FLOW.start_swordsman_judgement_sword(self)

func _start_swordsman_crescent_wave() -> void:
	PLAYER_ABILITY_FLOW.start_swordsman_crescent_wave(self)

func _trigger_swordsman_blade_storm_tick() -> void:
	PLAYER_ABILITY_FLOW.trigger_swordsman_blade_storm_tick(self)

func _ensure_swordsman_blade_storm_effect() -> void:
	PLAYER_ABILITY_FLOW.ensure_swordsman_blade_storm_effect(self)

func _update_swordsman_blade_storm_effect(delta: float) -> void:
	PLAYER_ABILITY_FLOW.update_swordsman_blade_storm_effect(self, delta)

func _stop_swordsman_blade_storm() -> void:
	PLAYER_ABILITY_FLOW.stop_swordsman_blade_storm(self)

func _cleanup_gunner_infinite_reload_effects() -> void:
	PLAYER_ABILITY_FLOW.cleanup_gunner_infinite_reload_effects(self)

func _register_gunner_infinite_reload_effect(effect: Node2D) -> void:
	PLAYER_ABILITY_FLOW.register_gunner_infinite_reload_effect(self, effect)

func _start_gunner_explosive_round() -> void:
	PLAYER_ABILITY_FLOW.start_gunner_explosive_round(self)

func _start_gunner_magic_grenade() -> void:
	PLAYER_ABILITY_FLOW.start_gunner_magic_grenade(self)

func _start_gunner_magic_eye() -> void:
	PLAYER_ABILITY_FLOW.start_gunner_magic_eye(self)

func _start_gunner_infinite_reload() -> void:
	PLAYER_ABILITY_FLOW.start_gunner_infinite_reload(self)

func _start_gunner_shrapnel_field() -> void:
	PLAYER_ABILITY_FLOW.start_gunner_shrapnel_field(self)

func _trigger_gunner_infinite_reload_tick() -> void:
	PLAYER_ABILITY_FLOW.trigger_gunner_infinite_reload_tick(self)

func _stop_gunner_infinite_reload() -> void:
	PLAYER_ABILITY_FLOW.stop_gunner_infinite_reload(self)

func is_gunner_infinite_reload_active() -> bool:
	return PLAYER_ABILITY_FLOW.is_gunner_infinite_reload_active(self)

func is_gunner_infinite_reload_blocking_actions() -> bool:
	return PLAYER_ABILITY_FLOW.is_gunner_infinite_reload_blocking_actions(self)

func is_gunner_infinite_reload_movement_locked() -> bool:
	return PLAYER_ABILITY_FLOW.is_gunner_infinite_reload_movement_locked(self)

func is_gunner_infinite_reload_preventing_switch() -> bool:
	return PLAYER_ABILITY_FLOW.is_gunner_infinite_reload_preventing_switch(self)

func _get_mage_flame_path_move_speed_multiplier() -> float:
	return PLAYER_ABILITY_FLOW.get_mage_flame_path_move_speed_multiplier(self)

func _get_gunner_infinite_reload_move_speed_multiplier() -> float:
	return PLAYER_ABILITY_FLOW.get_gunner_infinite_reload_move_speed_multiplier(self)

func _get_gunner_infinite_reload_dodge_value(role_id: String = "") -> float:
	var resolved_role_id: String = role_id if role_id != "" else str(_get_active_role().get("id", ""))
	return PLAYER_ABILITY_FLOW.get_gunner_infinite_reload_dodge_value(self, resolved_role_id)

func _try_trigger_mage_flame_path() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_mage_flame_path(self)

func _start_mage_flame_path() -> void:
	PLAYER_ABILITY_FLOW.start_mage_flame_path(self)

func _try_trigger_mage_dark_contract() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_mage_dark_contract(self)

func _try_trigger_mage_fireball() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_mage_fireball(self)

func _start_mage_dark_contract() -> void:
	PLAYER_ABILITY_FLOW.start_mage_dark_contract(self)

func _start_mage_fireball() -> void:
	PLAYER_ABILITY_FLOW.start_mage_fireball(self)

func _try_trigger_mage_tidal_surge() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_mage_tidal_surge(self)

func _start_mage_tidal_surge() -> void:
	PLAYER_ABILITY_FLOW.start_mage_tidal_surge(self)

func _try_trigger_mage_meta_field() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_mage_meta_field(self)

func _start_mage_meta_field() -> void:
	PLAYER_ABILITY_FLOW.start_mage_meta_field(self)

func _try_trigger_mechanic_drone() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_mechanic_drone(self)

func _try_trigger_mechanic_mine() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_mechanic_mine(self)

func _try_trigger_mechanic_emp_burst() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_mechanic_emp_burst(self)

func _try_trigger_mechanic_tulip_turret() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_mechanic_tulip_turret(self)

func _try_trigger_mechanic_missile_volley() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_mechanic_missile_volley(self)

func _start_mechanic_drone() -> void:
	PLAYER_ABILITY_FLOW.start_mechanic_drone(self)

func _start_mechanic_mine() -> void:
	PLAYER_ABILITY_FLOW.start_mechanic_mine(self)

func _start_mechanic_emp_burst() -> void:
	PLAYER_ABILITY_FLOW.start_mechanic_emp_burst(self)

func _start_mechanic_tulip_turret() -> void:
	PLAYER_ABILITY_FLOW.start_mechanic_tulip_turret(self)

func _start_mechanic_missile_volley() -> void:
	PLAYER_ABILITY_FLOW.start_mechanic_missile_volley(self)

func _perform_swordsman_attack() -> void:
	if swordsman_role != null:
		swordsman_role.perform_attack(self)

func _perform_gunner_attack() -> void:
	if gunner_role != null:
		gunner_role.perform_attack(self)

func _perform_mage_attack() -> void:
	if mage_role != null:
		mage_role.perform_attack(self)

func _perform_mechanic_attack() -> void:
	if mechanic_role != null:
		mechanic_role.perform_attack(self)

func _try_switch_role(new_role_index: int, ignore_restrictions: bool = false, force_entry: bool = false) -> void:
	PLAYER_SWITCH_FLOW.try_switch_role(self, new_role_index, ignore_restrictions, force_entry)

func _apply_enter_skill(role_index: int) -> int:
	return PLAYER_SWITCH_FLOW.apply_enter_skill(self, role_index)

func _apply_exit_skill(role_index: int) -> int:
	return PLAYER_SWITCH_FLOW.apply_exit_skill(self, role_index)

func _try_use_ultimate() -> void:
	PLAYER_ULTIMATE_FLOW.try_use_ultimate(self)

func _apply_post_ultimate_bonuses(role_id: String, total_duration: float) -> void:
	PLAYER_ULTIMATE_FLOW.apply_post_ultimate_bonuses(self, role_id, total_duration)

func _trigger_ultimate_reprise(role_id: String, reprise_level: int) -> void:
	PLAYER_ULTIMATE_FLOW.trigger_ultimate_reprise(self, role_id, reprise_level)

func _spawn_ultimate_afterglow_effect(role_id: String, duration: float) -> void:
	PLAYER_ULTIMATE_FLOW.spawn_ultimate_afterglow_effect(self, role_id, duration)

func _trigger_ultimate_afterglow_pulse(role_id: String, pulse_index: int) -> void:
	PLAYER_ULTIMATE_FLOW.trigger_ultimate_afterglow_pulse(self, role_id, pulse_index)

func _schedule_repeating_sequence(interval: float, repeat_count: int, callback: Callable, initial_delay: float = 0.0) -> void:
	PLAYER_ULTIMATE_FLOW.schedule_repeating_sequence(self, interval, repeat_count, callback, initial_delay)

func _fire_gunner_entry_wave(role_id: String, wave_index: int, damage_scale: float = 1.0) -> void:
	PLAYER_SWITCH_FLOW.fire_gunner_entry_wave(self, role_id, wave_index, damage_scale)

func _spawn_gunner_entry_wave_batch(role_id: String, wave_index: int, start_index: int, damage_scale: float = 1.0) -> void:
	PLAYER_SWITCH_FLOW.spawn_gunner_entry_wave_batch(self, role_id, wave_index, start_index, damage_scale)

func _start_mage_entry_bombardment(role_id: String, bombard_centers: Array, damage_scale: float = 1.0) -> void:
	PLAYER_SWITCH_FLOW.start_mage_entry_bombardment(self, role_id, bombard_centers, damage_scale)

func _show_mage_entry_bombardment_warning(center: Vector2) -> void:
	PLAYER_SWITCH_FLOW.show_mage_entry_bombardment_warning(self, center)

func _trigger_mage_entry_bombardment_impact(role_id: String, center: Vector2, damage_scale: float = 1.0) -> void:
	PLAYER_SWITCH_FLOW.trigger_mage_entry_bombardment_impact(self, role_id, center, damage_scale)

func _start_basic_mage_bombardment(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, gravity_level: int, echo_level: int, frost_level: int, role_id: String, use_boom_effect: bool = false, advance_attack_chain: bool = true) -> void:
	PLAYER_MAGE_BOMBARDMENT_FLOW.start_basic_mage_bombardment(self, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, use_boom_effect, advance_attack_chain)

func _trigger_basic_mage_bombardment_impact(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, gravity_level: int, echo_level: int, frost_level: int, role_id: String, use_boom_effect: bool = false, advance_attack_chain: bool = true) -> void:
	PLAYER_MAGE_BOMBARDMENT_FLOW.trigger_basic_mage_bombardment_impact(self, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, use_boom_effect, advance_attack_chain)

func _resolve_basic_mage_bombardment_damage(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, gravity_level: int, echo_level: int, frost_level: int, role_id: String, use_boom_effect: bool, advance_attack_chain: bool = true) -> void:
	PLAYER_MAGE_BOMBARDMENT_FLOW.resolve_basic_mage_bombardment_damage(self, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, use_boom_effect, advance_attack_chain)

func _get_enemy_nearest_to_position(position: Vector2) -> Node2D:
	if position == Vector2.ZERO:
		return _get_closest_enemy()
	return PLAYER_TARGETING.get_enemy_nearest_to_position(_get_live_enemies(), position)

func _get_enemy_near_position(position: Vector2, max_distance: float) -> Node2D:
	return PLAYER_TARGETING.get_enemy_near_position(_get_live_enemies(), position, max_distance)

func _get_mage_mouse_bombard_center(base_range: float) -> Vector2:
	return PLAYER_MAGE_BOMBARDMENT_FLOW.get_mage_mouse_bombard_center(self, base_range)

func _apply_role_projectile_modifiers(projectile: Node, role_id: String) -> void:
	PLAYER_PROJECTILE_SPAWNER.apply_role_projectile_modifiers(self, projectile, role_id)

func _spawn_bullet(target_enemy: Node2D, damage_amount: float, color: Color, role_id: String = "", origin: Variant = null):
	return PLAYER_PROJECTILE_SPAWNER.spawn_bullet(self, bullet_scene, target_enemy, damage_amount, color, role_id, origin)

func _spawn_directional_bullet(direction: Vector2, damage_amount: float, color: Color, role_id: String = "", origin: Variant = null):
	return PLAYER_PROJECTILE_SPAWNER.spawn_directional_bullet(self, bullet_scene, direction, damage_amount, color, role_id, origin)

func _spawn_directional_bullet_from_scene(projectile_scene: PackedScene, direction: Vector2, damage_amount: float, color: Color, role_id: String = "", origin: Variant = null):
	return PLAYER_PROJECTILE_SPAWNER.spawn_directional_bullet_from_scene(self, projectile_scene, direction, damage_amount, color, role_id, origin)

func _spawn_batched_directional_bullet(direction: Vector2, damage_amount: float, color: Color, role_id: String = "", origin: Variant = null, config: Dictionary = {}) -> bool:
	return PLAYER_PROJECTILE_SPAWNER.spawn_batched_directional_bullet(self, direction, damage_amount, color, role_id, origin, config)

func _spawn_batched_directional_bullet_values(
	direction: Vector2,
	damage_amount: float,
	color: Color,
	role_id: String = "",
	origin: Variant = null,
	speed: float = 620.0,
	lifetime: float = 1.0,
	hit_radius: float = 10.0,
	visual_radius: float = 4.2,
	visual_min_diameter: float = 8.0,
	visual_outline_color: Color = Color(1.0, 1.0, 1.0, 0.0),
	visual_outline_width: float = 0.0,
	enemy_hit_radius_scale: float = 0.2,
	enemy_hit_radius_min: float = 4.0,
	enemy_hit_radius_max: float = 12.0,
	vulnerability_bonus: float = 0.0,
	vulnerability_duration: float = 0.0,
	slow_multiplier: float = 1.0,
	slow_duration: float = 0.0,
	pierce_count: int = 0,
	wave_amplitude: float = 0.0,
	wave_frequency: float = 0.0,
	wave_phase: float = 0.0
) -> bool:
	return PLAYER_PROJECTILE_SPAWNER.spawn_batched_directional_bullet_values(self, direction, damage_amount, color, role_id, origin, speed, lifetime, hit_radius, visual_radius, visual_min_diameter, visual_outline_color, visual_outline_width, enemy_hit_radius_scale, enemy_hit_radius_min, enemy_hit_radius_max, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, pierce_count, wave_amplitude, wave_frequency, wave_phase)

func _get_enemy_meta_int(enemy: Node, key: String) -> int:
	return PLAYER_DAMAGE_HELPERS.get_enemy_meta_int(enemy, key)

func _get_enemy_meta_float(enemy: Node, key: String) -> float:
	return PLAYER_DAMAGE_HELPERS.get_enemy_meta_float(enemy, key)

func _apply_role_damage_lifesteal(source_role_id: String, damage_amount: float) -> void:
	PLAYER_DAMAGE_HELPERS.apply_role_damage_lifesteal(self, source_role_id, damage_amount)

func _get_gunner_distance_damage_multiplier(distance: float) -> float:
	var talent_inside_bonus: float = 0.35 if _has_skill_talent("gunner_trait_invade_hunt") else 0.0
	return PLAYER_DAMAGE_HELPERS.get_gunner_distance_damage_multiplier(
		distance,
		0.0,
		_get_gunner_safe_zone_radius(),
		PLAYER_BUILD_SYSTEM.get_gunner_hunt_inside_damage_bonus(self) + talent_inside_bonus,
		PLAYER_BUILD_SYSTEM.get_gunner_hunt_outside_damage_bonus(self)
	)

func _get_enemy_hit_radius(enemy: Node) -> float:
	return PLAYER_DAMAGE_HELPERS.get_enemy_hit_radius(enemy)

func _deal_damage_to_enemy(enemy: Node, damage_amount: float, source_role_id: String, vulnerability_bonus: float = 0.0, vulnerability_duration: float = 2.0, slow_multiplier: float = 1.0, slow_duration: float = 0.0, source_position: Variant = null, suppress_status_visual: bool = false, kill_energy_bonus: float = 0.0) -> bool:
	return PLAYER_DAMAGE_RESOLVER.deal_damage_to_enemy(self, enemy, damage_amount, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position, suppress_status_visual, kill_energy_bonus)

func _damage_enemies_in_radius(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_radius(self, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)

func _collect_enemies_in_radius_for_damage_batch(center: Vector2, radius: float) -> Array:
	return PLAYER_DAMAGE_RESOLVER.collect_enemies_in_radius(self, center, radius)

func _damage_enemies_in_radius_batched(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_radius_batched(self, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)

func _damage_enemies_in_radius_suppressing_status_visuals(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_radius_suppressing_status_visuals(self, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)

func _damage_enemies_in_radius_with_kill_energy(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "", kill_energy_bonus: float = 0.0) -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_radius_with_kill_energy(self, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id, kill_energy_bonus)

func _damage_enemies_in_multiple_radii_batched(centers: Array[Vector2], radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_multiple_radii_batched(self, centers, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)

func _damage_enemies_in_shapes_batched(shapes: Array[Dictionary]) -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_shapes_batched(self, shapes)

func _damage_enemies_in_cone_batched(origin: Vector2, direction: Vector2, cone_range: float, cone_angle_radians: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_cone(self, origin, direction, cone_range, cone_angle_radians, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)

func _damage_enemies_in_radius_count_kills(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> Dictionary:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_radius_count_kills(self, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)

func _pull_enemies_toward(center: Vector2, radius: float, pull_strength: float) -> void:
	PLAYER_DAMAGE_RESOLVER.pull_enemies_toward(self, center, radius, pull_strength)

func _damage_enemies_in_line(start_position: Vector2, end_position: Vector2, width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_line(self, start_position, end_position, width, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)

func _damage_enemies_in_oriented_rect(center: Vector2, axis_direction: Vector2, rect_length: float, rect_width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "", knockback_distance: float = 0.0) -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_oriented_rect(self, center, axis_direction, rect_length, rect_width, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id, knockback_distance)

func _damage_enemies_in_oriented_rect_tracking(center: Vector2, axis_direction: Vector2, rect_length: float, rect_width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, hit_registry: Dictionary, source_role_id: String = "", knockback_distance: float = 0.0) -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_oriented_rect_tracking(self, center, axis_direction, rect_length, rect_width, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, hit_registry, source_role_id, knockback_distance)

func _damage_enemies_in_oriented_rect_unique(center: Vector2, axis_direction: Vector2, rect_length: float, rect_width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, hit_registry: Dictionary, source_role_id: String = "") -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_oriented_rect_unique(self, center, axis_direction, rect_length, rect_width, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, hit_registry, source_role_id)

func _damage_enemies_in_ellipse(center: Vector2, horizontal_radius: float, vertical_radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_ellipse(self, center, horizontal_radius, vertical_radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)

func _damage_enemies_in_cone(origin: Vector2, direction: Vector2, cone_range: float, cone_angle_radians: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_cone(self, origin, direction, cone_range, cone_angle_radians, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)

func _schedule_swordsman_slash_followthrough(center: Vector2, axis_direction: Vector2, rect_length: float, rect_width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, animation_duration: float, source_role_id: String, hit_registry: Dictionary) -> void:
	PLAYER_DAMAGE_RESOLVER.schedule_swordsman_slash_followthrough(self, center, axis_direction, rect_length, rect_width, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, animation_duration, source_role_id, hit_registry)

func _apply_gunner_lock(target_enemy: Node2D, lock_level: int) -> void:
	gunner_role.apply_lock(self, target_enemy, lock_level)

func _update_active_role_state() -> void:
	PLAYER_EQUIPMENT_FLOW.recalculate_active_equipment_stats(self, false)
	PLAYER_BLESSING_SYSTEM.apply_active_role_runtime_bonuses(self)
	PLAYER_VISUAL_STATE.update_active_role_state(self)

func _setup_hurt_core_visual() -> void:
	PLAYER_HEALTH_VISUALS.setup_hurt_core_visual(self, PLAYER_HURT_CORE_RADIUS, PLAYER_HURT_CORE_OUTLINE_WIDTH)
	_apply_hurt_core_visibility()

func _update_hurt_core_visual(role_data: Dictionary = {}) -> void:
	PLAYER_HEALTH_VISUALS.update_hurt_core_visual(self, role_data, PLAYER_HURT_CORE_OFFSET)
	_apply_hurt_core_visibility()

func _toggle_hurt_core_visual() -> void:
	PLAYER_HEALTH_VISUALS.toggle_hurt_core_visual(self)

func _apply_hurt_core_visibility() -> void:
	PLAYER_HEALTH_VISUALS.apply_hurt_core_visibility(self)

func _setup_player_health_bar() -> void:
	PLAYER_HEALTH_VISUALS.setup_player_health_bar(self)

func _update_player_health_bar(role_data: Dictionary = {}) -> void:
	PLAYER_HEALTH_VISUALS.update_player_health_bar(self, role_data, PLAYER_HEALTH_BAR_HEIGHT, PLAYER_HEALTH_BAR_Y_OFFSET)

func _start_duration_status(status_id: String, label: String, duration: float, priority: int = 0, color: Color = Color(0.56, 0.56, 0.56, 0.95)) -> void:
	var safe_duration: float = max(0.001, duration)
	active_duration_statuses[status_id] = {
		"remaining": safe_duration,
		"duration": safe_duration,
		"label": label,
		"priority": priority,
		"color": color
	}
	PLAYER_HEALTH_VISUALS.setup_player_duration_status_bar(self)
	PLAYER_HEALTH_VISUALS.update_player_duration_status_bar(self)

func _sync_duration_status(status_id: String, label: String, remaining: float, priority: int = 0, color: Color = Color(0.56, 0.56, 0.56, 0.95)) -> void:
	if remaining <= 0.0:
		_clear_duration_status(status_id)
		return
	var current_data: Dictionary = active_duration_statuses.get(status_id, {})
	var duration: float = max(remaining, float(current_data.get("duration", remaining)))
	active_duration_statuses[status_id] = {
		"remaining": remaining,
		"duration": max(0.001, duration),
		"label": label,
		"priority": priority,
		"color": color
	}
	PLAYER_HEALTH_VISUALS.setup_player_duration_status_bar(self)
	PLAYER_HEALTH_VISUALS.update_player_duration_status_bar(self)

func _clear_duration_status(status_id: String) -> void:
	if active_duration_statuses.has(status_id):
		active_duration_statuses.erase(status_id)
	PLAYER_HEALTH_VISUALS.update_player_duration_status_bar(self)

func _sync_orbit_pull_status(remaining: float, _pull_origin: Vector2) -> void:
	if _is_status_immune():
		_clear_duration_status("orbit_pull")
		return
	_sync_duration_status("orbit_pull", "牵引", remaining, 80, Color(0.22, 0.14, 0.28, 0.95))

func _start_entangled_status(duration: float) -> void:
	if _is_status_immune():
		return
	_start_duration_status("entangled", "缠绕", duration, 100, Color(0.56, 0.56, 0.56, 0.95))

func _sync_invulnerability_status() -> void:
	var visible_invulnerability_remaining: float = max(0.0, switch_invulnerability_remaining - hidden_invulnerability_status_remaining)
	if visible_invulnerability_remaining > 0.0:
		if swordsman_entry_trait_share_remaining > 0.0:
			_sync_duration_status("invulnerable", "嗜血", visible_invulnerability_remaining, 90, Color(0.96, 0.82, 0.24, 0.95))
		elif swordsman_death_defiance_will_remaining > 0.0:
			_sync_duration_status("invulnerable", "骑士荣耀", visible_invulnerability_remaining, 90, Color(0.28, 0.58, 1.0, 0.88))
		else:
			_sync_duration_status("invulnerable", "无敌", visible_invulnerability_remaining, 90, Color(0.95, 0.82, 0.22, 0.96))
	else:
		_clear_duration_status("invulnerable")

func _tick_duration_statuses(delta: float) -> void:
	if active_duration_statuses.is_empty():
		PLAYER_HEALTH_VISUALS.update_player_duration_status_bar(self)
		return
	var expired_ids: Array[String] = []
	for status_id_value in active_duration_statuses.keys():
		var status_id: String = str(status_id_value)
		var status_data: Dictionary = active_duration_statuses.get(status_id, {})
		var remaining: float = max(0.0, float(status_data.get("remaining", 0.0)) - delta)
		status_data["remaining"] = remaining
		active_duration_statuses[status_id] = status_data
		if remaining <= 0.0:
			expired_ids.append(status_id)
	for status_id in expired_ids:
		active_duration_statuses.erase(status_id)
	PLAYER_HEALTH_VISUALS.update_player_duration_status_bar(self)

func _get_role_health_bar_width(role_id: String) -> float:
	return PLAYER_VISUAL_LAYOUT.get_player_role_health_bar_width(self, role_id)

func get_hurtbox_center() -> Vector2:
	return PLAYER_HEALTH_VISUALS.get_hurtbox_center(self)

func get_hurtbox_radius() -> float:
	return PLAYER_HURT_CORE_RADIUS

func _update_visuals(role_data: Dictionary) -> void:
	PLAYER_VISUAL_STATE.update_visuals(self, role_data, active_role_visual_hidden, active_role_visual_hidden_role_id)

func _update_fire_timer() -> void:
	PLAYER_VISUAL_STATE.update_fire_timer(self)

func _update_camera_shake(delta: float) -> void:
	PLAYER_CAMERA_FEEDBACK.update_camera_shake(self, delta)

func _queue_camera_shake(strength: float, duration: float) -> void:
	PLAYER_CAMERA_FEEDBACK.queue_camera_shake(self, strength, duration)

func queue_external_camera_shake(strength: float, duration: float) -> void:
	PLAYER_CAMERA_FEEDBACK.queue_external_camera_shake(self, strength, duration)

func _pulse_player_visual(peak_scale: float, duration: float) -> void:
	PLAYER_VISUAL_STATE.pulse_player_visual(self, peak_scale, duration)

func _update_role_idle_visual(_delta: float) -> void:
	PLAYER_VISUAL_STATE.update_role_idle_visual(self, str(_get_active_role()["id"]), facing_direction, role_visual_time)

func _activate_switch_power(role_id: String, label: String, duration: float, damage_multiplier: float, interval_bonus: float) -> void:
	PLAYER_SWITCH_FLOW.activate_switch_power(self, role_id, label, duration, damage_multiplier, interval_bonus)

func _queue_next_entry_blessing(source_role_id: String) -> void:
	PLAYER_SWITCH_FLOW.queue_next_entry_blessing(self, source_role_id)

func _apply_pending_entry_blessing(target_role_id: String) -> void:
	PLAYER_SWITCH_FLOW.apply_pending_entry_blessing(self, target_role_id)

func _clear_entry_blessing() -> void:
	PLAYER_SWITCH_FLOW.clear_entry_blessing(self)

func _apply_switch_payoff(hit_count: int, energy_gain: float, cooldown_refund: float) -> void:
	PLAYER_SWITCH_FLOW.apply_switch_payoff(self, hit_count, energy_gain, cooldown_refund)

func _apply_role_share(source_role_id: String, interval_bonus: float, range_bonus: float, skill_bonus: float) -> void:
	PLAYER_ROLE_STAT_FLOW.apply_role_share(self, source_role_id, interval_bonus, range_bonus, skill_bonus)

func _initialize_existing_role_shares() -> void:
	PLAYER_ROLE_STAT_FLOW.initialize_existing_role_shares(self)

func _show_switch_banner(prefix: String, title: String, color: Color) -> void:
	PLAYER_SWITCH_FLOW.show_switch_banner(self, prefix, title, color)

func _get_active_role() -> Dictionary:
	return PLAYER_RESOURCE_FLOW.get_active_role(self)

func _get_current_move_speed() -> float:
	return PLAYER_ROLE_STAT_FLOW.get_current_move_speed(self)

func _get_role_move_speed(role_id: String) -> float:
	return PLAYER_ROLE_STAT_FLOW.get_role_move_speed(self, role_id)

func _get_role_damage(role_id: String) -> float:
	return PLAYER_ROLE_STAT_FLOW.get_role_damage(self, role_id)

func _get_king_blade_flat_base_damage(role_id: String) -> float:
	if role_id != "swordsman":
		return 0.0
	return PLAYER_SWORDSMAN_KING_BLADE_FLOW.get_flat_attack_bonus(self)

func _get_active_role_base_health() -> float:
	return PLAYER_ROLE_STAT_FLOW.get_active_role_base_health(self)

func _get_active_role_max_health() -> float:
	return PLAYER_ROLE_STAT_FLOW.get_active_role_max_health(self)

func _get_role_max_health(role_id: String) -> float:
	return PLAYER_ROLE_STAT_FLOW.get_role_max_health(self, role_id)

func _get_role_current_health(role_id: String) -> float:
	return PLAYER_ROLE_STAT_FLOW.get_role_current_health(self, role_id)

func _get_role_temporary_health(role_id: String) -> float:
	return PLAYER_ROLE_STAT_FLOW.get_role_temporary_health(self, role_id)

func _save_active_role_health() -> void:
	PLAYER_ROLE_STAT_FLOW.save_active_role_health(self)

func _save_active_role_temporary_health() -> void:
	PLAYER_ROLE_STAT_FLOW.save_active_role_temporary_health(self)

func _set_role_temporary_health(role_id: String, value: float, emit_for_active: bool = true) -> void:
	PLAYER_ROLE_STAT_FLOW.set_role_temporary_health(self, role_id, value, emit_for_active)

func _sync_temporary_health_state(emit_signal: bool = true, signal_role_id: String = "") -> void:
	PLAYER_RESOURCE_FLOW.sync_temporary_health_state(self, emit_signal, signal_role_id)

func _set_temporary_health_total(value: float, emit_signal: bool = true, signal_role_id: String = "") -> void:
	PLAYER_RESOURCE_FLOW.set_temporary_health_total(self, value, emit_signal, signal_role_id)

func _tick_temporary_health_stacks(delta: float) -> void:
	PLAYER_RESOURCE_FLOW.tick_temporary_health_stacks(self, delta)

func _consume_temporary_health(amount: float) -> float:
	return PLAYER_RESOURCE_FLOW.consume_temporary_health(self, amount)

func _clear_temporary_health(emit_signal: bool = true) -> void:
	PLAYER_RESOURCE_FLOW.clear_temporary_health(self, emit_signal)

func _add_temporary_health(amount: float, role_id: String = "", duration: float = PLAYER_RESOURCE_FLOW.TEMPORARY_HEALTH_DURATION) -> float:
	return PLAYER_RESOURCE_FLOW.add_temporary_health(self, amount, role_id, duration)

func grant_temporary_health(amount: float, role_id: String = "", duration: float = PLAYER_RESOURCE_FLOW.TEMPORARY_HEALTH_DURATION) -> float:
	return _add_temporary_health(amount, role_id, duration)

func _add_all_role_current_health(amount: float) -> void:
	PLAYER_ROLE_STAT_FLOW.add_all_role_current_health(self, amount)

func _heal_role(role_id: String, amount: float) -> void:
	if role_id == "" or amount <= 0.0 or is_dead:
		return
	if has_method("is_healing_blocked") and is_healing_blocked():
		return
	amount = PLAYER_SWORDSMAN_TRAIT_RUNTIME_FLOW.apply_healing_multiplier(self, amount)
	if amount <= 0.0:
		return
	if role_health_values is not Dictionary or role_health_values.is_empty():
		role_health_values = _build_role_health_state()
	var role_max_health: float = _get_role_max_health(role_id)
	var current_value: float = _get_role_current_health(role_id)
	var updated_value: float = clamp(current_value + amount, 0.0, role_max_health)
	role_health_values[role_id] = updated_value
	if role_id == _get_active_role_id():
		current_health = updated_value
		health_changed.emit(current_health, max_health)

func _heal_roles_except(excluded_role_id: String, amount: float) -> void:
	if amount <= 0.0:
		return
	for role_data in roles:
		var role_id: String = str(role_data.get("id", ""))
		if role_id == "" or role_id == excluded_role_id:
			continue
		_heal_role(role_id, amount)

func _sync_active_role_max_health(preserve_ratio: bool = true, restore_gain: bool = false) -> void:
	PLAYER_ROLE_STAT_FLOW.sync_active_role_max_health(self, preserve_ratio, restore_gain)

func _get_role_special_state(role_id: String) -> Dictionary:
	return PLAYER_RESOURCE_FLOW.get_role_special_state(self, role_id)

func _get_closest_enemy() -> Node2D:
	return PLAYER_TARGETING.get_owner_closest_enemy(self)

func _get_live_enemies() -> Array:
	return PLAYER_DAMAGE_RESOLVER._get_live_enemies(self)

func _get_candidate_enemies_for_circle(center: Vector2, radius: float) -> Array:
	return PLAYER_DAMAGE_RESOLVER._get_candidate_enemies_for_circle(self, center, radius)

func _get_touching_enemy_damage(center: Vector2, radius: float, query_padding: float = 36.0) -> float:
	return PLAYER_DAMAGE_RESOLVER.get_touching_enemy_damage(self, center, radius, query_padding)

func _get_farthest_enemy() -> Node2D:
	return PLAYER_TARGETING.get_owner_farthest_enemy(self)

func _get_enemy_targets(count: int, prefer_farthest: bool = false) -> Array:
	return PLAYER_TARGETING.get_owner_enemy_targets(self, count, prefer_farthest)

func _get_low_health_enemy() -> Node2D:
	return PLAYER_TARGETING.get_owner_low_health_enemy(self)

func _get_priority_boss_target(origin: Vector2) -> Node2D:
	return PLAYER_TARGETING.get_owner_priority_boss_target(self, origin)

func _get_enemy_aim_point(enemy: Node2D, origin: Vector2) -> Vector2:
	return PLAYER_TARGETING.get_enemy_aim_point(enemy, origin)

func _get_enemy_in_aim_cone(max_angle_degrees: float, max_distance: float = INF) -> Node2D:
	return PLAYER_TARGETING.get_owner_enemy_in_aim_cone(self, max_angle_degrees, max_distance)

func _get_enemy_cluster_center() -> Vector2:
	return PLAYER_TARGETING.get_owner_enemy_cluster_center(self)

func _get_random_enemy_cluster_centers(count: int) -> Array:
	return PLAYER_TARGETING.get_owner_random_enemy_cluster_centers(self, count)

func _collect_nearby_gems() -> void:
	PLAYER_SURVIVAL_FLOW.collect_nearby_gems(self)

func _check_enemy_contact_damage() -> void:
	PLAYER_SURVIVAL_FLOW.check_enemy_contact_damage(self)

func gain_experience(amount: int) -> void:
	PLAYER_SURVIVAL_FLOW.gain_experience(self, amount)

func grant_developer_level_up() -> void:
	PLAYER_SURVIVAL_FLOW.grant_developer_level_up(self)

func take_damage(amount: float) -> void:
	PLAYER_SURVIVAL_FLOW.take_damage(self, amount)

func apply_enemy_slow(multiplier: float, duration: float) -> void:
	PLAYER_SURVIVAL_FLOW.apply_enemy_slow(self, multiplier, duration)

func _add_energy(amount: float) -> void:
	PLAYER_RESOURCE_FLOW.add_energy(self, amount)

func _get_role_switch_energy(role_id: String) -> float:
	if role_switch_energy_values is not Dictionary or role_switch_energy_values.is_empty():
		role_switch_energy_values = _build_role_resource_state_data(0.0)
	return clamp(float(role_switch_energy_values.get(role_id, 0.0)), 0.0, SWITCH_ENTRY_ENERGY_REQUIRED)

func _set_role_switch_energy(role_id: String, value: float) -> void:
	if role_id == "":
		return
	if role_switch_energy_values is not Dictionary or role_switch_energy_values.is_empty():
		role_switch_energy_values = _build_role_resource_state_data(0.0)
	role_switch_energy_values[role_id] = clamp(value, 0.0, SWITCH_ENTRY_ENERGY_REQUIRED)

func _add_switch_energy_from_damage(damage_amount: float, source_role_id: String = "") -> void:
	if damage_amount <= 0.0:
		return
	var resolved_role_id: String = source_role_id if source_role_id != "" else _get_active_role_id()
	var gain_amount: float = damage_amount * SWITCH_ENTRY_ENERGY_PER_DAMAGE
	gain_amount *= max(0.01, 1.0 + float(_get_role_blessing_stat_bonus(resolved_role_id, "switch_energy_gain")))
	if _is_mage_arcane_surplus_active():
		gain_amount *= 1.0 + _get_mage_arcane_surplus_switch_energy_bonus()
	_set_role_switch_energy(resolved_role_id, _get_role_switch_energy(resolved_role_id) + gain_amount)

func _has_full_switch_energy(role_id: String = "") -> bool:
	var resolved_role_id: String = role_id if role_id != "" else _get_active_role_id()
	return _get_role_switch_energy(resolved_role_id) >= SWITCH_ENTRY_ENERGY_REQUIRED

func _consume_switch_energy_for_entry(role_id: String = "") -> bool:
	var resolved_role_id: String = role_id if role_id != "" else _get_active_role_id()
	if not _has_full_switch_energy(resolved_role_id):
		return false
	_set_role_switch_energy(resolved_role_id, 0.0)
	return true

func _add_kill_energy(amount: float, bypass_lock_role_id: String = "", source_role_id: String = "") -> void:
	PLAYER_COMBAT_RESULT_FLOW.add_kill_energy(self, amount, bypass_lock_role_id, source_role_id)

func _get_kill_energy_from_enemy(enemy: Node) -> float:
	return PLAYER_COMBAT_RESULT_FLOW.get_kill_energy_from_enemy(enemy)

func _try_apply_mage_kill_energy_proc(source_role_id: String, base_energy: float, bypass_lock_role_id: String = "") -> void:
	PLAYER_COMBAT_RESULT_FLOW.try_apply_mage_kill_energy_proc(self, source_role_id, base_energy, bypass_lock_role_id)

func _get_boss_damage_energy(damage_amount: float) -> float:
	return PLAYER_COMBAT_RESULT_FLOW.get_boss_damage_energy(damage_amount)

func _add_boss_damage_energy(amount: float) -> void:
	PLAYER_COMBAT_RESULT_FLOW.add_boss_damage_energy(self, amount)

func _get_ultimate_energy_cost() -> float:
	return PLAYER_ULTIMATE_FLOW.get_ultimate_energy_cost(self)

func _can_use_ultimate() -> bool:
	return PLAYER_ULTIMATE_FLOW.can_use_ultimate(self)

func _build_ultimate_cast_payload() -> Dictionary:
	return PLAYER_ULTIMATE_FLOW.build_ultimate_cast_payload(self)

func _get_ultimate_level_damage_multiplier() -> float:
	return PLAYER_ULTIMATE_FLOW.get_ultimate_level_damage_multiplier(self)

func _register_attack_result(role_id: String, hit_count: int, killed: bool, kill_count: int = 0) -> void:
	PLAYER_COMBAT_RESULT_FLOW.register_attack_result(self, role_id, hit_count, killed, kill_count)

func _push_attack_result_context_tag(tag_id: String) -> void:
	if tag_id == "":
		return
	attack_result_context_tags[tag_id] = int(attack_result_context_tags.get(tag_id, 0)) + 1

func _pop_attack_result_context_tag(tag_id: String) -> void:
	if tag_id == "":
		return
	var next_count: int = int(attack_result_context_tags.get(tag_id, 0)) - 1
	if next_count > 0:
		attack_result_context_tags[tag_id] = next_count
	else:
		attack_result_context_tags.erase(tag_id)

func _has_attack_result_context_tag(tag_id: String) -> bool:
	if tag_id == "":
		return false
	return int(attack_result_context_tags.get(tag_id, 0)) > 0


func _apply_theme_hit_returns(role_id: String, hit_count: int, killed: bool) -> void:
	return

func _apply_role_flat_heal_on_hit(role_id: String, hit_count: int) -> void:
	PLAYER_COMBAT_RESULT_FLOW.apply_role_flat_heal_on_hit(self, role_id, hit_count)

func _apply_entry_lifesteal(role_id: String, hit_count: int, killed: bool) -> void:
	PLAYER_COMBAT_RESULT_FLOW.apply_entry_lifesteal(self, role_id, hit_count, killed)

func _heal(amount: float) -> void:
	PLAYER_RESOURCE_FLOW.heal(self, amount)

func _record_swordsman_ultimate_followup_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	var state := _get_role_special_state("swordsman")
	if not bool(state.get("level_ultimate_chain_damage_tracking", false)):
		return
	state["level_ultimate_chain_damage_total"] = float(state.get("level_ultimate_chain_damage_total", 0.0)) + amount
	role_special_states["swordsman"] = state

func _spawn_attack_aftershock(center: Vector2, role_id: String) -> void:
	return

func _play_player_hurt_feedback() -> void:
	PLAYER_COMBAT_RESULT_FLOW.play_player_hurt_feedback(self)

func _trigger_swordsman_counter() -> void:
	PLAYER_COMBAT_RESULT_FLOW.trigger_swordsman_counter(self)

func _count_enemies_in_radius(center: Vector2, radius: float) -> int:
	return PLAYER_DAMAGE_RESOLVER.count_enemies_in_radius(self, center, radius)

func apply_upgrade(option_id: String) -> void:
	PLAYER_UPGRADE_APPLIER.apply_upgrade(self, option_id)

func apply_upgrades(option_ids: Array) -> void:
	PLAYER_UPGRADE_APPLIER.apply_upgrades(self, option_ids)

func get_attribute_upgrade_options() -> Array:
	return PLAYER_LEVEL_FLOW.get_attribute_upgrade_options(self)

func refresh_upgrade_options() -> Array:
	return PLAYER_LEVEL_FLOW.refresh_upgrade_options(self)

func refresh_upgrade_card(option_index: int) -> Array:
	return PLAYER_LEVEL_FLOW.refresh_upgrade_card(self, option_index)

func get_selected_level_talents(role_id: String) -> Array:
	return PLAYER_SKILL_TALENT_SYSTEM.get_selected_level_talents(self, role_id)

func _has_level_talent(talent_id: String) -> bool:
	return PLAYER_SKILL_TALENT_SYSTEM.has_level_talent(self, talent_id)

func build_direct_blessing_options() -> Array:
	return PLAYER_LEVEL_FLOW.build_all_blessing_options(self)

func build_tier_blessing_options(tier: int) -> Array:
	return PLAYER_LEVEL_FLOW.build_tier_blessing_options(self, tier)

func get_current_blessing_offer_context() -> Dictionary:
	if current_blessing_offer is Dictionary:
		return (current_blessing_offer.get("context", {}) as Dictionary).duplicate(true)
	return {}

func get_small_boss_reward_options() -> Array:
	return PLAYER_LEVEL_FLOW.get_small_boss_reward_options(self)

func get_boss_skill_reward_options() -> Array:
	return PLAYER_LEVEL_FLOW.get_boss_skill_reward_options(self)

func apply_attribute_upgrade(option_id: String) -> void:
	PLAYER_LEVEL_FLOW.apply_attribute_upgrade(self, option_id)


func get_stat_summary() -> Dictionary:
	return PLAYER_STAT_PAYLOAD.build_from_player(self)

func get_frame_hud_summary() -> Dictionary:
	return PLAYER_STAT_PAYLOAD.build_frame_hud_from_player(self)

func emit_frame_stats_changed() -> void:
	stats_changed.emit(get_frame_hud_summary())

func _emit_deferred_level_up_requested() -> void:
	if is_dead or not level_up_active:
		return
	if level_up_delay_remaining > 0.0:
		if active_upgrade_kind == "" or active_upgrade_kind == "level_up":
			pending_level_ups += 1
		level_up_active = false
		active_upgrade_kind = ""
		return
	level_up_requested.emit([])

func _get_active_skill_cooldown_slots(attack_interval: float, include_descriptions: bool = true) -> Array:
	return PLAYER_SKILL_COOLDOWN_FLOW.get_active_skill_cooldown_slots(self, attack_interval, include_descriptions)

func _get_role_skill_cooldown_slots(role_id: String, attack_interval: float, include_descriptions: bool = true) -> Array:
	return PLAYER_SKILL_COOLDOWN_FLOW.get_role_skill_cooldown_slots(self, role_id, attack_interval, include_descriptions)

func get_final_core_options() -> Array:
	return PLAYER_LEVEL_OPTIONS.get_final_core_options()

func get_save_data() -> Dictionary:
	return PLAYER_RUN_SAVE_STATE.get_save_data(self)


func configure_ruan_stones(profile: Dictionary) -> void:
	var normalized := RUAN_STONE_SYSTEM.normalize_profile(profile.duplicate(true))
	ruan_bone_count = int(normalized.get("bones", 0))
	ruan_stone_levels = (normalized.get("ruan_stone_levels", {}) as Dictionary).duplicate(true)
	equipped_ruan_stone = RUAN_STONE_SYSTEM.get_equipped(normalized)
	ruan_stone_proc_events.clear()


func get_ruan_bone_count() -> int:
	return ruan_bone_count


func collect_ruan_bones(amount: int) -> int:
	if amount <= 0:
		return ruan_bone_count
	ruan_bone_count += amount
	if SAVE_MANAGER.is_endless_mode_active() and not DEVELOPER_MODE.should_disable_save():
		var profile := SAVE_MANAGER.get_current_endless_profile()
		if not profile.is_empty():
			profile["bones"] = ruan_bone_count
			SAVE_MANAGER.save_endless_profile(profile)
	return ruan_bone_count


func get_ruan_stone_level(stone_id: String) -> int:
	return max(0, int(ruan_stone_levels.get(stone_id, 0)))


func get_equipped_ruan_stone() -> String:
	return equipped_ruan_stone


func get_developer_bone_count() -> int:
	return ruan_bone_count


func set_developer_bone_count(value: int) -> void:
	ruan_bone_count = max(0, value)


func set_developer_ruan_stone_level(stone_id: String, level: int) -> void:
	if not RUAN_STONE_SYSTEM.STONE_IDS.has(stone_id):
		return
	ruan_stone_levels[stone_id] = max(0, level)
	if equipped_ruan_stone == stone_id and get_ruan_stone_level(stone_id) <= 0:
		equipped_ruan_stone = ""


func equip_developer_ruan_stone(stone_id: String) -> bool:
	if stone_id != "" and (not RUAN_STONE_SYSTEM.STONE_IDS.has(stone_id) or get_ruan_stone_level(stone_id) <= 0):
		return false
	equipped_ruan_stone = stone_id
	ruan_stone_proc_events.clear()
	return true


func _create_basic_attack_source_id(role_id: String) -> String:
	basic_attack_event_serial += 1
	return "%s_basic:%s:%s" % [role_id, get_instance_id(), basic_attack_event_serial]


func apply_save_data(data: Dictionary) -> void:
	PLAYER_RUN_SAVE_STATE.apply_save_data(self, data)

func resume_pending_level_ups() -> void:
	PLAYER_LEVEL_FLOW.resume_pending_level_ups(self)

func _delay_level_up_requests(duration: float) -> void:
	PLAYER_LEVEL_FLOW.delay_level_up_requests(self, duration)

func _try_request_level_up() -> void:
	PLAYER_LEVEL_FLOW.try_request_level_up(self)

func _build_upgrade_options() -> Array:
	return PLAYER_LEVEL_FLOW.build_blessing_upgrade_options(self)

func _get_support_offset(role_id: String, aggressive: bool) -> Vector2:
	return PLAYER_VISUAL_LAYOUT.get_support_offset(role_id, facing_direction, aggressive)

func _spawn_radial_rays_effect(center: Vector2, radius: float, ray_count: int, color: Color, width: float, duration: float, angle_offset: float = 0.0) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_radial_rays_effect(self, center, radius, ray_count, color, width, duration, angle_offset)

func _spawn_slash_effect(center: Vector2, direction: Vector2, length: float, width: float, color: Color, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_slash_effect(self, center, direction, length, width, color, duration)

func _spawn_dash_line_effect(start_position: Vector2, end_position: Vector2, color: Color, width: float, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_dash_line_effect(self, start_position, end_position, color, width, duration)

func _spawn_crescent_wave_effect(center: Vector2, direction: Vector2, radius: float, color: Color, duration: float, arc_degrees: float = 270.0, thickness: float = 26.0) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_owner_crescent_wave_effect(self, center, direction, radius, color, duration, arc_degrees, thickness)

func _spawn_cross_slash_effect(center: Vector2, direction: Vector2, length: float, width: float, color: Color, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_cross_slash_effect(self, center, direction, length, width, color, duration)

func _spawn_thrust_effect(start_position: Vector2, end_position: Vector2, color: Color, width: float, duration: float, show_arrow: bool = true) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_thrust_effect(self, start_position, end_position, color, width, duration, show_arrow)

func _spawn_cone_effect(center: Vector2, direction: Vector2, range_value: float, arc_degrees: float, color: Color, duration: float) -> void:
	PLAYER_EFFECT_LINE_PRIMITIVES.spawn_cone_effect(self, center, direction, range_value, arc_degrees, color, duration)

func _spawn_guard_effect(center: Vector2, radius: float, color: Color, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_owner_guard_effect(self, center, radius, color, duration)

func _spawn_combat_tag(position: Vector2, text: String, color: Color) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_combat_tag(self, position, text, color, SHOW_GAMEPLAY_TEXT_HINTS)

func _spawn_forced_combat_tag(position: Vector2, text: String, color: Color) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_combat_tag(self, position, text, color, true)

func _spawn_ring_effect(center: Vector2, radius: float, color: Color, width: float, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_owner_ring_effect(self, center, radius, color, width, duration)

func _spawn_mage_bombardment_warning_effect(center: Vector2, radius: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_owner_mage_bombardment_warning_effect(self, center, radius)

func _spawn_mage_bombardment_fall_effect(center: Vector2, radius: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_owner_mage_bombardment_fall_effect(self, center, radius)

func _spawn_pulsing_field(center: Vector2, radius: float, color: Color, pulse_count: int, interval: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float) -> void:
	PLAYER_FIELD_EFFECT_FLOW.spawn_pulsing_field(self, center, radius, color, pulse_count, interval, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration)

func _trigger_field_pulse(center: Vector2, radius: float, color: Color, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float) -> void:
	PLAYER_FIELD_EFFECT_FLOW.trigger_field_pulse(self, center, radius, color, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration)

func _spawn_burst_effect(center: Vector2, radius: float, color: Color, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_owner_burst_effect(self, center, radius, color, duration)

func _spawn_frost_sigils_effect(center: Vector2, radius: float, color: Color, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_frost_sigils_effect(self, center, radius, color, duration)

func _spawn_vortex_effect(center: Vector2, radius: float, color: Color, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_owner_vortex_effect(self, center, radius, color, duration)

func _spawn_target_lock_effect(center: Vector2, radius: float, color: Color, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_owner_target_lock_effect(self, center, radius, color, duration)

func _build_circle_polygon(radius: float) -> PackedVector2Array:
	return PLAYER_MATH.build_circle_polygon(radius)

func _build_arc_points(radius: float, arc_degrees: float) -> PackedVector2Array:
	return PLAYER_MATH.build_arc_points(radius, arc_degrees)

func _build_arc_band_polygon(outer_radius: float, inner_radius: float, arc_degrees: float) -> PackedVector2Array:
	return PLAYER_MATH.build_arc_band_polygon(outer_radius, inner_radius, arc_degrees)

func _die() -> void:
	PLAYER_RESOURCE_FLOW.die(self)
