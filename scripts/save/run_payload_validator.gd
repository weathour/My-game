extends RefCounted

const PERFORMANCE_RECORDER := preload("res://scripts/game/performance_recorder.gd")

# Match restoration types; absent legacy fields still use their existing defaults.
const PLAYER_NUMBERS := [
	"active_role_index", "background_interval_multiplier", "borrow_fire_background_multiplier",
	"borrow_fire_damage_multiplier", "borrow_fire_interval_bonus", "borrow_fire_remaining", "current_health",
	"current_mana", "current_temporary_health", "damage_taken_multiplier", "enemy_move_slow_multiplier",
	"enemy_move_slow_remaining", "energy_gain_multiplier", "entry_blessing_remaining",
	"entry_haste_interval_bonus", "entry_haste_move_speed_multiplier", "entry_lifesteal_ratio",
	"equipment_cooldown_multiplier", "equipment_damage_multiplier_bonus", "equipment_dodge_chance",
	"equipment_energy_gain_bonus", "equipment_health_regen_per_second",
	"equipment_low_health_damage_reduction_rate", "equipment_low_health_damage_taken_multiplier",
	"equipment_low_health_threshold", "equipment_max_health_bonus", "equipment_skill_range_multiplier",
	"equipment_speed_bonus", "experience", "experience_to_next_level", "frenzy_overkill_counter",
	"frenzy_remaining", "frenzy_stacks", "global_damage_multiplier", "greed_heal_cooldown_remaining",
	"guard_cover_damage_multiplier", "guard_cover_remaining", "gunner_infinite_reload_cooldown_remaining",
	"gunner_infinite_reload_remaining", "gunner_infinite_reload_tick_remaining",
	"gunner_shrapnel_field_cooldown_remaining", "hidden_invulnerability_status_remaining",
	"hurt_cooldown_remaining", "level", "level_up_delay_remaining", "mage_arcane_charge_stacks",
	"mage_arcane_charge_transfer_duration", "mage_arcane_charge_transfer_remaining",
	"mage_arcane_charge_transfer_stacks", "mage_arcane_surplus_remaining",
	"mage_meta_field_cooldown_remaining", "mage_meta_field_remaining", "mage_meta_field_tick_remaining",
	"mage_tidal_surge_cooldown_remaining", "max_health", "max_mana", "necro_mark_remaining",
	"passive_damage_reduction_value", "pending_level_talent_choices", "pending_level_ups",
	"perpetual_motion_cooldown_remaining", "pickup_radius", "plague_remaining",
	"post_ultimate_flow_background_multiplier", "post_ultimate_flow_remaining", "role_switch_cooldown_bonus",
	"skill_points", "skull_mage_cold_remaining", "speed", "standby_entry_damage_multiplier",
	"standby_entry_interval_bonus", "standby_entry_remaining", "switch_cooldown_remaining", "switch_energy",
	"switch_invulnerability_remaining", "switch_power_damage_multiplier", "switch_power_interval_bonus",
	"switch_power_remaining", "swordsman_blade_storm_cooldown_remaining", "swordsman_blade_storm_remaining",
	"swordsman_blade_storm_tick_remaining", "swordsman_bloodthirst_cooldown_remaining",
	"swordsman_crescent_wave_cooldown_remaining", "swordsman_death_defiance_cooldown_remaining",
	"swordsman_entry_trait_share_remaining", "ultimate_cost_multiplier", "ultimate_energy_lock_remaining",
	"ultimate_guard_damage_multiplier", "ultimate_guard_remaining", "vulnerability_rate"
]

const ENEMY_NUMBERS := [
	"acceleration_boost", "acceleration_duration", "acceleration_interval", "acceleration_remaining",
	"acceleration_timer", "armor", "attack", "basic_shot_timer", "bleed_damage_per_second", "bleed_timer",
	"boss_aimed_shot_timer", "boss_aimed_shots_remaining", "boss_attack_pressure_scale",
	"boss_battle_elapsed", "boss_danmaku_count", "boss_danmaku_pattern", "boss_danmaku_rotation",
	"boss_danmaku_spin", "boss_danmaku_wave", "boss_direct_health_loss", "boss_laser_final_rotation",
	"boss_laser_hit_timer", "boss_laser_remaining", "boss_laser_rotation", "boss_laser_start_rotation",
	"boss_laser_timer", "boss_orbit_bomb_angle", "boss_orbit_bomb_remaining", "boss_orbit_bomb_shot_timer",
	"boss_orbit_bomb_timer", "boss_orbit_pull_remaining", "boss_orbit_sign", "boss_pattern_rotation",
	"boss_peacock_charge_remaining", "boss_peacock_timer", "boss_phase", "boss_phase_three_elapsed",
	"boss_phase_three_intro_remaining", "boss_phase_transition_target", "boss_radial_bullets",
	"boss_radial_interval", "boss_radial_timer", "boss_shield_max_health", "boss_sine_cooldown",
	"boss_sine_interval", "boss_sine_stream_duration", "boss_sine_stream_rate", "boss_sine_stream_remaining",
	"boss_sine_stream_timer", "boss_split_timer", "boss_turning_bullets", "boss_turning_interval",
	"boss_turning_sign", "boss_turning_timer", "combat_wave_boss", "contact_radius", "current_health",
	"damage_reduction_rate", "damage_reduction_value", "dash_distance_remaining", "dash_duration",
	"dash_interval", "dash_remaining", "dash_speed_multiplier", "dash_timer", "dash_windup_duration",
	"dash_windup_remaining", "electric_stacks", "elite_charge_haste_remaining", "experience_reward",
	"fury_armor_shred", "fury_armor_shred_remaining", "glutton_absorb_elapsed", "glutton_absorb_radius",
	"glutton_aura_damage", "glutton_aura_radius", "glutton_bonus_speed", "glutton_heart_heal_scale",
	"glutton_max_bonus_speed", "glutton_scale_gain_per_gem", "glutton_speed_gain_per_gem",
	"glutton_war_stomp_cooldown_remaining", "heavy_armor_cooldown", "heavy_armor_remaining", "max_health",
	"preferred_distance", "projectile_count", "projectile_damage", "projectile_lifetime", "projectile_speed",
	"projectile_split_after", "projectile_split_count", "projectile_split_damage_scale",
	"projectile_split_hit_radius_scale", "projectile_split_lifetime_scale", "projectile_split_size_scale",
	"projectile_split_speed_scale", "projectile_split_spread", "projectile_spread", "rebirth_delay",
	"rebirth_lives_remaining", "rebirth_slow_duration", "rebirth_slow_multiplier", "rebirth_timer",
	"reward_tier", "runner_haste_cooldown", "runner_haste_remaining", "scale_x", "scale_y", "shot_interval",
	"shot_timer", "skull_damage_immune_timer", "skull_soldier_speed_multiplier", "skull_soldier_speed_timer",
	"skullshot_attack_frequency_multiplier", "skullshot_attack_frequency_timer",
	"skulltomb_aging_aura_elapsed", "skulltomb_charge_decision_timer", "skulltomb_charge_timer",
	"skulltomb_charge_windup_remaining", "skulltomb_summon_timer", "skulltomb_summon_windup_remaining",
	"slow_multiplier", "slow_timer", "speed", "stalwart_body_cooldown", "status_resistance", "strafe_sign",
	"stun_remaining", "touch_damage", "turret_bombard_interval", "turret_bombard_projectiles",
	"turret_bombard_radius", "turret_bombard_timer", "vulnerability_bonus", "vulnerability_timer"
]

const PROJECTILE_NUMBERS := [
	"chain_follow_index", "chain_follow_spacing", "clear_fade_alpha", "clear_fade_duration",
	"clear_fade_remaining", "damage", "danmaku_angular_speed", "danmaku_brake_time", "danmaku_hold_time",
	"danmaku_release_angle", "danmaku_release_speed", "danmaku_sway", "forward_distance", "hit_radius",
	"homing_turn_rate", "lifetime", "max_lifetime", "quarter_sine_distance", "quarter_sine_side",
	"remote_update_elapsed", "return_after", "return_speed", "return_target_x", "return_target_y",
	"sine_amplitude", "sine_frequency", "sine_phase", "size_scale", "source_enemy_instance_id", "speed",
	"split_after_time", "split_count", "split_damage_override", "split_damage_scale",
	"split_hit_radius_scale", "split_lifetime", "split_size_scale", "split_speed", "split_spread",
	"split_volley_id", "travel_time", "turn_angle_step", "turn_delay_remaining", "turn_direction_sign",
	"turn_interval", "turn_start_delay", "turn_tick_remaining"
]

const PICKUP_NUMBERS := [
	"attraction_speed", "age_seconds", "heal_amount", "tier", "value"
]

const FIELD_NUMBERS := [
	"damage", "distance", "entangle_damage", "flash_remaining", "fuse", "radius", "remaining"
]

const WAVE_NUMBERS := [
	"elapsed", "elite_index", "ending_elapsed", "flyby_left", "flyby_remaining", "merchant_health",
	"remaining", "spawn_remaining", "special_remaining", "wave"
]

const ABILITY_NUMBERS := [
	"active_remaining", "arc_height", "attract_tick_elapsed", "breath_remaining", "build_version",
	"cast_duration", "cast_radius", "cast_ratio", "charges", "cooldown_credit", "cooldown_remaining",
	"damage_amount", "damage_elapsed", "damage_scale", "duration", "elapsed", "expansion_tick_count",
	"field_remaining", "last_damage_progress", "length", "linger_elapsed", "manual_active_elapsed",
	"next_wave_token", "path_remaining", "radius", "remaining", "second_shot_remaining", "serial",
	"shockwave_timer", "shockwaves_remaining", "shot_timer", "shots_remaining", "tick_elapsed",
	"tick_remaining", "token", "traveled", "visual_scale", "width"
]

const OBJECT_ARRAYS := ["enemies", "enemy_projectiles", "gems", "heart_pickups", "bone_pickups", "experience_vacuum_pickups", "swordsman_ground_cracks", "skull_mage_domains", "parasite_seeds"]

static func error(run: Variant) -> String:
	if not run is Dictionary:
		return "run: expected dictionary"
	if not run.get("player") is Dictionary:
		return "player: expected dictionary"
	PERFORMANCE_RECORDER.begin_scope("save_payload_finite_ms")
	var problem := _finite(run, "run")
	PERFORMANCE_RECORDER.end_scope("save_payload_finite_ms")
	if not problem.is_empty():
		return problem
	problem = _containers(run, "", ["player", "combat_wave", "reward_state", "story_attempt", "pending_settlement", "pending_run_end"], OBJECT_ARRAYS)
	if not problem.is_empty():
		return problem
	problem = _numbers(run, "", ["survival_time", "music_position", "spawned_elite_count", "spawned_small_boss_count", "run_tier"])
	if not problem.is_empty():
		return problem
	problem = _flags(run, "", ["boss_spawned", "story_initial"])
	if not problem.is_empty():
		return problem
	for key in ["pending_run_end", "pending_settlement"]:
		var pending: Dictionary = run.get(key, {})
		problem = _containers(pending, key, ["summary"], [])
		if not problem.is_empty():
			return problem
		if key == "pending_run_end" and pending.has("outcome") and pending.outcome not in ["failed", "abandoned"]:
			return "pending_run_end.outcome: expected failed or abandoned"
	problem = _player(run.player)
	if not problem.is_empty():
		return problem
	for key in OBJECT_ARRAYS:
		var entries: Array = run.get(key, [])
		for index in entries.size():
			var path := "%s[%d]" % [key, index]
			if not entries[index] is Dictionary:
				return path + ": expected dictionary"
			var entry: Dictionary = entries[index]
			if key in ["skull_mage_domains", "parasite_seeds"] and not entry.has("position"):
				return path + ".position: missing coordinates"
			if key == "parasite_seeds" and not entry.has("direction"):
				return path + ".direction: missing coordinates"
			problem = _vectors(entry, path, ["position", "direction", "incident_velocity", "base_position", "base_direction", "dash_direction", "skulltomb_charge_target_position"])
			if problem.is_empty():
				var numeric_keys = ENEMY_NUMBERS if key == "enemies" else PROJECTILE_NUMBERS if key == "enemy_projectiles" else FIELD_NUMBERS if key in ["swordsman_ground_cracks", "parasite_seeds"] else PICKUP_NUMBERS
				problem = _numbers(entry, path, numeric_keys)
			if problem.is_empty() and key == "skull_mage_domains":
				problem = _numbers(entry, path, ["remaining"])
			if problem.is_empty() and key == "enemies":
				problem = _enemy(entry, path)
			if problem.is_empty() and key == "enemy_projectiles":
				problem = _vectors(entry, path, ["visual_color"], 4)
			if not problem.is_empty():
				return problem
	var wave: Dictionary = run.get("combat_wave", {})
	problem = _numbers(wave, "combat_wave", WAVE_NUMBERS)
	if problem.is_empty():
		problem = _flags(wave, "combat_wave", ["ending_final", "small_boss_reward_pending", "claimed", "blessing_pending", "boss_started"])
	if problem.is_empty():
		problem = _containers(wave, "combat_wave", ["blessing_offer"], [])
	if problem.is_empty():
		problem = _vectors(wave, "combat_wave", ["merchant_position", "flyby_origin", "flyby_direction"])
	if not problem.is_empty():
		return problem
	var reward: Dictionary = run.get("reward_state", {})
	if reward.has("context") and not reward.context is String:
		return "reward_state.context: expected string"
	problem = _containers(reward, "reward_state", ["blessing_binding_choice"], ["reward_options"])
	if problem.is_empty():
		problem = _numbers(reward, "reward_state", ["direct_blessing_choices_remaining", "direct_blessing_tier"])
	if problem.is_empty():
		problem = _dictionary_entries(reward.get("reward_options", []), "reward_state.reward_options")
	return problem

static func _player(data: Dictionary) -> String:
	var path := "player"
	var problem := _numbers(data, path, PLAYER_NUMBERS)
	if not problem.is_empty():
		return problem
	problem = _containers(data, path, ["role_skill_points", "role_health_values", "role_temporary_health_values", "role_mana_values", "role_switch_energy_values", "role_ultimate_energy_lock_remaining", "movement_slow_sources", "vine_entangle_state", "ability_runtime", "blindness", "role_standby_elapsed", "background_cooldowns", "equipment_levels", "role_equipment_levels", "role_upgrade_levels", "elite_relics_unlocked"], ["roles", "temporary_health_stacks"])
	if not problem.is_empty():
		return problem
	problem = _vectors(data, path, ["position", "gunner_infinite_reload_locked_aim_direction", "swordsman_blade_storm_cast_origin", "swordsman_blade_storm_cast_direction"])
	if not problem.is_empty():
		return problem
	for key in ["role_skill_points", "role_health_values", "role_temporary_health_values", "role_mana_values", "role_switch_energy_values", "role_ultimate_energy_lock_remaining", "role_standby_elapsed", "equipment_levels", "background_cooldowns"]:
		var values: Dictionary = data.get(key, {})
		problem = _numbers(values, path + "." + key, values.keys())
		if not problem.is_empty():
			return problem
	for key in ["roles", "temporary_health_stacks"]:
		problem = _dictionary_entries(data.get(key, []), path + "." + key)
		if not problem.is_empty():
			return problem
	for index in data.get("roles", []).size():
		var role: Dictionary = data.roles[index]
		var role_path := "player.roles[%d]" % index
		if not role.get("id") is String or str(role.id).is_empty():
			return role_path + ".id: expected role identifier"
		if role.has("name") and not role.name is String:
			return role_path + ".name: expected string"
		# Current templates replace these base stats, but preserve range and defenses.
		var role_numbers := ["range", "armor", "status_resistance", "speed_scale", "base_dodge", "background_interval"]
		if role.id not in ["swordsman", "gunner", "mage", "mechanic"]:
			role_numbers.append_array(["damage", "base_health", "move_speed", "base_attack_speed", "base_damage_reduction_rate", "base_damage_reduction_value"])
			for required in ["name", "damage"]:
				if not role.has(required):
					return role_path + "." + required + ": missing role field"
		problem = _numbers(role, role_path, role_numbers)
		if not problem.is_empty():
			return problem
		var color: Variant = role.get("color")
		if color is Array and color.size() >= 3:
			for channel in mini(4, color.size()):
				if not _is_number(color[channel]):
					return "%s.color[%d]: expected number" % [role_path, channel]
	for stack in data.get("temporary_health_stacks", []):
		problem = _numbers(stack, path + ".temporary_health_stacks", ["amount", "remaining"])
		if not problem.is_empty():
			return problem
	for key in ["role_equipment_levels", "role_upgrade_levels"]:
		var values: Dictionary = data.get(key, {})
		for id in values:
			var child_path: String = path + "." + key + "." + str(id)
			if not values[id] is Dictionary:
				return child_path + ": expected dictionary"
			problem = _numbers(values[id], child_path, values[id].keys())
			if not problem.is_empty():
				return problem
	for key in ["blindness", "vine_entangle_state"]:
		problem = _numbers(data.get(key, {}), path + "." + key, ["remaining", "cooldown_remaining", "damage", "elapsed"])
		if not problem.is_empty():
			return problem
	problem = _slow_sources(data, path)
	if not problem.is_empty():
		return problem
	var abilities: Dictionary = data.get("ability_runtime", {})
	for id in abilities:
		var child_path: String = path + ".ability_runtime." + str(id)
		if not abilities[id] is Dictionary:
			return child_path + ": expected dictionary"
		var ability: Dictionary = abilities[id]
		if id == "infinite_reload":
			problem = _numbers(ability, child_path, ["cooldown_remaining", "build_version"])
			if not problem.is_empty():
				return problem
			if int(ability.get("build_version", 0)) != 1:
				continue
		problem = _numbers(ability, child_path, ABILITY_NUMBERS)
		if problem.is_empty():
			problem = _vectors(ability, child_path, ["cast_origin", "cast_direction", "locked_aim_direction", "locked_direction", "field_position", "sword_position", "second_shot_direction"])
		if problem.is_empty():
			problem = _containers(ability, child_path, ["cast_snapshot", "cast_choices"], ["pending_beam_hits"])
		if problem.is_empty():
			problem = _dictionary_entries(ability.get("pending_beam_hits", []), child_path + ".pending_beam_hits")
		if not problem.is_empty():
			return problem
		var snapshot: Dictionary = ability.get("cast_snapshot", {})
		problem = _containers(snapshot, child_path + ".cast_snapshot", [], ["choices"])
		if problem.is_empty():
			problem = _numbers(snapshot, child_path + ".cast_snapshot", ["cooldown", "damage_ratio", "range_bonus"])
		if not problem.is_empty():
			return problem
		for key in ["fields", "projectiles", "grenades", "pending_shots", "turrets", "cannons", "mines", "guards", "spheres"]:
			if not ability.has(key):
				continue
			var collection_path: String = child_path + "." + key
			problem = _containers(ability, child_path, [], [key])
			if problem.is_empty():
				problem = _dictionary_entries(ability[key], collection_path)
			if not problem.is_empty():
				return problem
			for index in ability[key].size():
				var entry: Dictionary = ability[key][index]
				var entry_path := "%s[%d]" % [collection_path, index]
				problem = _vectors(entry, entry_path, ["position", "direction", "center", "origin", "target", "start_position", "end_position", "from", "arc_normal"])
				if problem.is_empty():
					problem = _numbers(entry, entry_path, ABILITY_NUMBERS)
				if problem.is_empty():
					problem = _numbers(entry, entry_path, ["delay", "rotation", "effect_scale", "damage", "slow_multiplier", "tick_interval", "visual_remaining"])
				if problem.is_empty():
					problem = _containers(entry, entry_path, [], ["reprise_scales"])
				if not problem.is_empty():
					return problem
				for scale_index in entry.get("reprise_scales", []).size():
					if not _is_number(entry.reprise_scales[scale_index]):
						return "%s.reprise_scales[%d]: expected number" % [entry_path, scale_index]
		for hit in ability.get("pending_beam_hits", []):
			problem = _numbers(hit, child_path + ".pending_beam_hits", ["remaining"])
			if problem.is_empty():
				problem = _containers(hit, child_path + ".pending_beam_hits", [], ["shapes"])
			if problem.is_empty():
				problem = _dictionary_entries(hit.get("shapes", []), child_path + ".pending_beam_hits.shapes")
			if not problem.is_empty():
				return problem
			for shape in hit.get("shapes", []):
				var shape_path := child_path + ".pending_beam_hits.shapes"
				if shape.get("type", "oriented_rect") != "oriented_rect":
					return shape_path + ".type: expected oriented_rect"
				if not shape.has("damage_amount"):
					return shape_path + ".damage_amount: missing number"
				problem = _vectors(shape, shape_path, ["center", "axis", "source_position"])
				if problem.is_empty():
					problem = _numbers(shape, shape_path, ["length", "width", "damage_amount"])
				if not problem.is_empty():
					return problem
	return ""

static func _enemy(data: Dictionary, path: String) -> String:
	var problem := _containers(data, path, ["wave_flyby", "skull_mage_state", "plant_state", "necro_priest_state", "porcupine_state", "skulltomb_domain", "movement_slow_sources"], ["storm_armor_shred_timers", "status_resistance_sources"])
	if not problem.is_empty():
		return problem
	problem = _vectors(data, path, ["display_color", "projectile_color"], 4)
	if not problem.is_empty():
		return problem
	for key in ["storm_armor_shred_timers", "status_resistance_sources"]:
		var values: Array = data.get(key, [])
		for index in values.size():
			if not _is_number(values[index]):
				return "%s.%s[%d]: expected number" % [path, key, index]
	if data.get("boss_routine") is Dictionary:
		problem = _numbers(data.boss_routine, path + ".boss_routine", ["stun_extension", "elapsed", "theme", "events", "laser_aim"])
		if not problem.is_empty():
			return problem
	for key in ["skull_mage_state", "plant_state", "necro_priest_state", "porcupine_state", "wave_flyby"]:
		var state: Dictionary = data.get(key, {})
		problem = _numbers(state, path + "." + key, ["drain_cooldown", "proximity", "drain_remaining", "drain_elapsed", "ice_cooldown", "ice_remaining", "temporary_health", "domain_cooldown", "invulnerable_remaining", "seed_cooldown", "land_remaining", "distance", "damage", "health_scale", "attack_scale", "speed_scale", "prayer_cooldown", "mark_cooldown", "remaining", "rage", "age", "closest"])
		if problem.is_empty():
			problem = _vectors(state, path + "." + key, ["direction"])
		if not problem.is_empty():
			return problem
	var domain: Dictionary = data.get("skulltomb_domain", {})
	problem = _vectors(domain, path + ".skulltomb_domain", ["center", "cast_center"])
	if problem.is_empty():
		problem = _containers(domain, path + ".skulltomb_domain", [], ["pending_spawns"])
	if problem.is_empty():
		problem = _dictionary_entries(domain.get("pending_spawns", []), path + ".skulltomb_domain.pending_spawns")
	if problem.is_empty():
		problem = _numbers(domain, path + ".skulltomb_domain", ["remaining", "radius", "check_elapsed", "spawn_elapsed", "spawn_vertex"])
	return _slow_sources(data, path) if problem.is_empty() else problem

static func _slow_sources(data: Dictionary, path: String) -> String:
	var sources: Dictionary = data.get("movement_slow_sources", {})
	for id in sources:
		var child_path: String = path + ".movement_slow_sources." + str(id)
		if not sources[id] is Dictionary:
			return child_path + ": expected dictionary"
		for key in ["multiplier", "remaining"]:
			if not sources[id].has(key) or not _is_number(sources[id][key]):
				return child_path + "." + key + ": expected number"
	return ""

static func _containers(data: Dictionary, path: String, dictionaries: Array, arrays: Array) -> String:
	for key in dictionaries:
		if data.has(key) and not data[key] is Dictionary:
			return _field(path, key) + ": expected dictionary"
	for key in arrays:
		if data.has(key) and not data[key] is Array:
			return _field(path, key) + ": expected array"
	return ""

static func _dictionary_entries(entries: Array, path: String) -> String:
	for index in entries.size():
		if not entries[index] is Dictionary:
			return "%s[%d]: expected dictionary" % [path, index]
	return ""

static func _vectors(data: Dictionary, path: String, keys: Array, size: int = 2) -> String:
	for key in keys:
		if not data.has(key):
			continue
		var value: Variant = data[key]
		if not value is Array or value.size() < size:
			return _field(path, key) + ": expected coordinate array of at least %d numbers" % size
		for index in size:
			if not _is_number(value[index]):
				return "%s[%d]: expected number" % [_field(path, key), index]
	return ""

static func _numbers(data: Dictionary, path: String, keys) -> String:
	for key in keys:
		if data.has(key) and not _is_number(data[key]):
			return _field(path, str(key)) + ": expected number"
	return ""

static func _flags(data: Dictionary, path: String, keys: Array) -> String:
	for key in keys:
		if not data.has(key):
			continue
		var value: Variant = data[key]
		if not value is bool and not (_is_number(value) and (float(value) == 0.0 or float(value) == 1.0)):
			return _field(path, key) + ": expected boolean or 0/1"
	return ""

static func _is_number(value: Variant) -> bool:
	return value is int or value is float

static func _field(path: String, key: String) -> String:
	return key if path.is_empty() else path + "." + key

static func _finite(value: Variant, path: String) -> String:
	if value is float and not is_finite(value):
		return path + ": expected finite number"
	if value is Dictionary or value is Array:
		for key in (value.keys() if value is Dictionary else range(value.size())):
			var child: Variant = value[key]
			if not (child is Dictionary or child is Array or (child is float and not is_finite(child))):
				continue
			var child_path: String = _field(path, str(key)) if value is Dictionary else "%s[%d]" % [path, key]
			var problem := _finite(child, child_path)
			if not problem.is_empty():
				return problem
	return ""
