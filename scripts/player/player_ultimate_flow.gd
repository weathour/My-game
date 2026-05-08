extends RefCounted

const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")

const ULTIMATE_ENERGY_LOCK_AFTER_CAST := 3.2
const ULTIMATE_ENERGY_REQUIRED := 100.0

const ULTIMATE_DISPLAY := {
	"swordsman": {
		"name": "破锋连斩",
		"description": "剑士大招：短时间强化剑士体术，连续向前方斩击。"
	},
	"gunner": {
		"name": "火力压制",
		"description": "枪手大招：进入爆发射击节奏，向目标方向连续倾泻弹幕。"
	},
	"mage": {
		"name": "奥术潮汐",
		"description": "术师大招：在敌群区域引爆多段法术轰击。"
	}
}


const ULTIMATE_DISPLAY_OVERRIDE := {
	"swordsman": {
		"name": "无敌斩",
		"description": "剑士大招：短时间连续高速斩击敌人。"
	},
	"gunner": {
		"name": "火箭弹幕",
		"description": "枪手大招：向目标方向释放持续弹幕，并用锥形区域造成伤害。"
	},
	"mage": {
		"name": "奥数轰炸",
		"description": "术师大招：在敌群区域连续引发多段奥数轰炸。"
	}
}


static func get_ultimate_energy_cost(owner) -> float:
	if DEVELOPER_MODE.should_unlock_ultimate_freely():
		return 0.0
	if owner._has_elite_relic("elite_perpetual_motion"):
		return 0.0
	return ULTIMATE_ENERGY_REQUIRED


static func get_ultimate_display(owner, role_id: String) -> Dictionary:
	var fallback := {
		"name": "大招",
		"description": "当前英雄的大招。"
	}
	fallback = {"name": "大招", "description": "当前英雄的大招。"}
	var display: Dictionary = ULTIMATE_DISPLAY_OVERRIDE.get(role_id, fallback)
	var result := display.duplicate(true)
	result["skill_id"] = _get_ultimate_skill_id(role_id)
	var enhancement_text := _make_ultimate_enhancement_description(owner, role_id)
	if enhancement_text != "":
		result["description"] = "%s\n\n已获得的大招强化：\n%s" % [str(result.get("description", "")), enhancement_text]
	return result


static func _get_ultimate_skill_id(role_id: String) -> String:
	match role_id:
		"swordsman":
			return "swordsman_ultimate"
		"gunner":
			return "gunner_ultimate"
		"mage":
			return "mage_ultimate"
	return ""


static func _make_ultimate_enhancement_description(_owner, _role_id: String) -> String:
	return ""


static func can_use_ultimate(owner) -> bool:
	if owner._get_active_role_id() == "gunner" and owner.is_gunner_infinite_reload_active():
		return false
	if DEVELOPER_MODE.should_unlock_ultimate_freely():
		return true
	if owner._has_elite_relic("elite_perpetual_motion"):
		return owner.perpetual_motion_cooldown_remaining <= 0.0
	return owner._get_role_mana(owner._get_active_role_id()) >= get_ultimate_energy_cost(owner)


static func build_ultimate_cast_payload(owner) -> Dictionary:
	var duration_multiplier: float = 1.0
	var damage_multiplier: float = get_ultimate_level_damage_multiplier(owner)
	if DEVELOPER_MODE.should_unlock_ultimate_freely():
		return {
			"damage_multiplier": damage_multiplier,
			"duration_multiplier": duration_multiplier,
			"boost_units": 0
		}
	if owner._has_elite_relic("elite_perpetual_motion"):
		var consumed_mana: float = owner._get_role_mana(owner._get_active_role_id())
		owner._set_role_mana(owner._get_active_role_id(), 0.0, false)
		var boost_units: int = min(4, int(floor(min(consumed_mana, 60.0) / 15.0)))
		damage_multiplier += 0.06 * boost_units
		duration_multiplier += 0.04 * boost_units
		owner.perpetual_motion_cooldown_remaining = 26.0 * owner._get_equipment_cooldown_multiplier()
		owner._emit_active_mana_changed()
		return {
			"damage_multiplier": damage_multiplier,
			"duration_multiplier": duration_multiplier,
			"boost_units": boost_units
		}
	return {
		"damage_multiplier": damage_multiplier,
		"duration_multiplier": duration_multiplier,
		"boost_units": 0
	}


static func get_ultimate_level_damage_multiplier(owner) -> float:
	var bonus_levels: int = max(0, owner.level - 1)
	return 1.0 + float(bonus_levels) * 0.018


static func try_use_ultimate(owner) -> void:
	var ultimate_cost: float = get_ultimate_energy_cost(owner)
	if not can_use_ultimate(owner):
		return

	var role_id: String = owner._get_active_role()["id"]
	var cast_payload: Dictionary = build_ultimate_cast_payload(owner)
	if not DEVELOPER_MODE.should_unlock_ultimate_freely():
		owner._set_role_ultimate_lock_remaining(role_id, ULTIMATE_ENERGY_LOCK_AFTER_CAST)
	if not DEVELOPER_MODE.should_unlock_ultimate_freely() and not owner._has_elite_relic("elite_perpetual_motion"):
		owner._add_role_mana(role_id, -ultimate_cost, false)
	if not DEVELOPER_MODE.should_unlock_ultimate_freely():
		owner._emit_active_mana_changed()

	match role_id:
		"swordsman":
			if owner.swordsman_role != null:
				owner.swordsman_role.perform_ultimate(owner, cast_payload)
		"gunner":
			if owner.gunner_role != null:
				owner.gunner_role.perform_ultimate(owner, cast_payload)
		"mage":
			if owner.mage_role != null:
				owner.mage_role.perform_ultimate(owner, cast_payload)


static func apply_post_ultimate_bonuses(owner, role_id: String, total_duration: float) -> void:
	var afterglow_level: int = 0
	if afterglow_level > 0:
		owner._activate_switch_power(role_id, "\u4F59\u8F89", 2.2 + afterglow_level * 0.35, 1.12 + afterglow_level * 0.05, 0.03 * afterglow_level)
	owner._spawn_ultimate_afterglow_effect(role_id, 1.8 + afterglow_level * 0.4)
	var extend_level: int = 0
	if extend_level >= 3:
		owner._add_energy(10.0)
	var borrow_fire_level: int = 0
	if borrow_fire_level > 0:
		owner.borrow_fire_role_id = role_id
		owner.borrow_fire_remaining = total_duration
		owner.borrow_fire_damage_multiplier = [1.18, 1.24, 1.30][borrow_fire_level - 1]
		owner.borrow_fire_interval_bonus = [0.04, 0.06, 0.08][borrow_fire_level - 1]
		owner.borrow_fire_background_multiplier = 0.9 if borrow_fire_level >= 2 else 1.0
		if borrow_fire_level >= 3:
			owner._add_energy(8.0)
		owner._update_fire_timer()
	var reflux_level: int = 0
	if reflux_level > 0:
		if owner.get_tree() != null:
			var flow_tween: Tween = owner.create_tween()
			flow_tween.tween_interval(total_duration)
			flow_tween.tween_callback(func() -> void:
				owner._add_energy([18.0, 24.0, 30.0][reflux_level - 1])
				owner.switch_cooldown_remaining = max(0.0, owner.switch_cooldown_remaining - [0.6, 0.9, 1.2][reflux_level - 1])
				if reflux_level >= 3:
					owner.post_ultimate_flow_remaining = 3.0
					owner.post_ultimate_flow_background_multiplier = 0.88
				owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -46.0), "回流", Color(0.84, 0.96, 1.0, 1.0))
				owner._spawn_ring_effect(owner.global_position, 68.0, Color(0.72, 0.52, 1.0, 0.72), 6.0, 0.18)
				owner._spawn_burst_effect(owner.global_position, 54.0, Color(0.6, 0.42, 1.0, 0.18), 0.16)
			)

	var reprise_level: int = 0
	if owner._has_elite_relic("elite_mirror_finisher"):
		reprise_level += 1
	if reprise_level <= 0:
		return

	if owner.get_tree() == null:
		return
	var tween: Tween = owner.create_tween()
	tween.tween_interval(total_duration + 0.12)
	tween.tween_callback(Callable(owner, "_trigger_ultimate_reprise").bind(role_id, reprise_level))


static func trigger_ultimate_reprise(owner, role_id: String, reprise_level: int) -> void:
	if owner.is_dead:
		return

	match role_id:
		"swordsman":
			var radius := 78.0 + reprise_level * 12.0
			owner._spawn_crescent_wave_effect(owner.global_position + owner.facing_direction * 12.0, owner.facing_direction, radius, Color(1.0, 0.9, 0.62, 0.9), 0.16, 120.0, 26.0)
			var hits: int = owner._damage_enemies_in_radius(owner.global_position + owner.facing_direction * 18.0, radius * 0.52, owner._get_role_damage(role_id) * (0.72 + reprise_level * 0.08), 0.04, 1.0, 0.0)
			if hits > 0:
				owner._register_attack_result(role_id, hits, false)
		"gunner":
			for bullet_index in range(10 + reprise_level * 2):
				var angle: float = TAU * float(bullet_index) / float(10 + reprise_level * 2)
				var reprise_bullet = owner._spawn_directional_bullet(Vector2.RIGHT.rotated(angle), owner._get_role_damage(role_id) * (0.24 + reprise_level * 0.03), Color(1.0, 0.84, 0.56, 0.92), role_id, owner.global_position)
				if reprise_bullet != null:
					reprise_bullet.speed = 520.0
					reprise_bullet.lifetime = 0.7
					reprise_bullet.hit_radius = 10.0
		"mage":
			var center: Vector2 = owner._get_enemy_cluster_center()
			if center == Vector2.ZERO:
				center = owner.global_position + owner.facing_direction * 80.0
			owner._spawn_mage_bombardment_warning_effect(center, 54.0 + reprise_level * 10.0)
			owner._trigger_basic_mage_bombardment_impact(center, 54.0 + reprise_level * 10.0, owner._get_role_damage(role_id) * (0.56 + reprise_level * 0.06), 0.02, 0.7, 1.2, 0, 0, 0, role_id)


static func spawn_ultimate_afterglow_effect(owner, role_id: String, duration: float) -> void:
	if owner.get_tree() == null:
		return

	var pulse_count := 4
	var tween: Tween = owner.create_tween()
	for pulse_index in range(pulse_count):
		if pulse_index > 0:
			tween.tween_interval(max(0.08, duration / float(pulse_count)))
		tween.tween_callback(Callable(owner, "_trigger_ultimate_afterglow_pulse").bind(role_id, pulse_index))


static func trigger_ultimate_afterglow_pulse(owner, role_id: String, pulse_index: int) -> void:
	match role_id:
		"swordsman":
			var pulse_direction: Vector2 = owner.facing_direction.rotated(0.18 if pulse_index % 2 == 0 else -0.18)
			owner._spawn_crescent_wave_effect(owner.global_position + pulse_direction * 10.0, pulse_direction, 76.0 + pulse_index * 8.0, Color(1.0, 0.88, 0.56, 0.62), 0.24, 130.0, 22.0)
		"gunner":
			pass
		"mage":
			var center: Vector2 = owner._get_enemy_cluster_center()
			if center == Vector2.ZERO:
				center = owner.global_position + owner.facing_direction * 70.0
			var radius := 62.0 + pulse_index * 10.0
			owner._spawn_ring_effect(center, radius, Color(0.68, 0.96, 1.0, 0.56), 5.0, 0.22)
			owner._spawn_frost_sigils_effect(center, radius * 0.56, Color(0.86, 0.98, 1.0, 0.68), 0.22)


static func schedule_repeating_sequence(owner, interval: float, repeat_count: int, callback: Callable, initial_delay: float = 0.0) -> void:
	if owner == null or repeat_count <= 0:
		return

	var tween: Tween = owner.create_tween()
	if initial_delay > 0.0:
		tween.tween_interval(initial_delay)
	for index in range(repeat_count):
		if index > 0:
			tween.tween_interval(interval)
		var sequence_index := index
		tween.tween_callback(func() -> void:
			callback.call(sequence_index)
		)
