extends SceneTree

const PlayerBlessingSystem := preload("res://scripts/player/player_blessing_system.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_low_level_tier_one_only()
	_check_tier_two_independent_offer_after_level_seven()
	_check_manual_compose_from_tier_one_level_three()
	_check_role_bound_state()
	_check_skill_bound_state_is_record_only()
	if failures.is_empty():
		print("PLAYER_BLESSING_SYSTEM_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_low_level_tier_one_only() -> void:
	var owner := _OwnerStub.new()
	owner.level = 3
	var offer: Dictionary = PlayerBlessingSystem.build_offer_for_owner(owner)
	var options: Array = offer.get("options", [])
	if options.size() != 3:
		failures.append("low level blessing offer should provide 3 options, got %d" % options.size())
	for option in options:
		if option is Dictionary and int((option as Dictionary).get("blessing_tier", 0)) != 1:
			failures.append("levels before 7 should only offer tier I blessings: %s" % str(option))


func _check_tier_two_independent_offer_after_level_seven() -> void:
	var owner := _OwnerStub.new()
	owner.level = 15
	var saw_tier_two := false
	for index in range(60):
		var offer: Dictionary = PlayerBlessingSystem.build_offer_for_owner(owner)
		for option in offer.get("options", []):
			if option is Dictionary and int((option as Dictionary).get("blessing_tier", 0)) == 2:
				saw_tier_two = true
				break
		if saw_tier_two:
			break
	if not saw_tier_two:
		failures.append("tier II should be independently offerable after level 7 without tier I Lv.3")


func _check_manual_compose_from_tier_one_level_three() -> void:
	var owner := _OwnerStub.new()
	owner.role_blessing_levels["swordsman"]["divine_grace"] = {1: 3}
	if not PlayerBlessingSystem.can_compose_role_blessing(owner, "swordsman", "divine_grace"):
		failures.append("role blessing should be composable at tier I Lv.3")
	if not PlayerBlessingSystem.compose_role_blessing(owner, "swordsman", "divine_grace"):
		failures.append("role blessing compose should succeed")
	var levels: Dictionary = owner.role_blessing_levels["swordsman"]["divine_grace"]
	if int(levels.get(1, 0)) != 3 or int(levels.get(2, 0)) != 1:
		failures.append("compose should keep I Lv.3 and add II Lv.1, got %s" % str(levels))
	for role_id in ["swordsman", "gunner", "mage"]:
		var shared_levels: Dictionary = (owner.role_blessing_levels.get(role_id, {}) as Dictionary).get("divine_grace", {})
		if int(shared_levels.get(1, 0)) != 3 or int(shared_levels.get(2, 0)) != 1:
			failures.append("composed role blessing should be shared by all roles, got %s=%s" % [role_id, str(shared_levels)])
	if PlayerBlessingSystem.can_compose_role_blessing(owner, "swordsman", "divine_grace"):
		failures.append("same blessing should not be composable again after II exists")


func _check_role_bound_state() -> void:
	var owner := _OwnerStub.new()
	var applied := PlayerBlessingSystem.apply_option(owner, "blessing:blazing_sun:1")
	if not applied:
		failures.append("role-bound blessing option did not apply")
	for role_id in ["swordsman", "gunner", "mage"]:
		var role_levels: Dictionary = owner.role_blessing_levels.get(role_id, {})
		var level := int((role_levels.get("blazing_sun", {}) as Dictionary).get(1, 0))
		if level != 1:
			failures.append("role-bound blessing should be shared by all roles, got %s" % str(owner.role_blessing_levels))
		var damage_bonus := PlayerBlessingSystem.get_role_stat_bonus(owner, role_id, "damage")
		if not is_equal_approx(damage_bonus, 0.055):
			failures.append("shared role-bound damage bonus mismatch for %s: %.3f" % [role_id, damage_bonus])


func _check_skill_bound_state_is_record_only() -> void:
	var owner := _OwnerStub.new()
	var speed_before := owner.speed
	var applied := PlayerBlessingSystem.apply_option(owner, "blessing:reprise:1")
	if not applied:
		failures.append("skill-bound blessing option did not apply")
	var level := int((owner.skill_blessing_levels.get("reprise", {}) as Dictionary).get(1, 0))
	if level != 1:
		failures.append("skill-bound blessing should be stored in skill state, got %s" % str(owner.skill_blessing_levels))
	if not is_equal_approx(speed_before, owner.speed):
		failures.append("skill-bound blessing should not mutate role stats before skill binding is implemented")


class _OwnerStub:
	var level: int = 1
	var roles: Array = [
		{"id": "swordsman", "name": "剑士"},
		{"id": "gunner", "name": "枪手"},
		{"id": "mage", "name": "术师"}
	]
	var active_role_index: int = 0
	var role_blessing_levels: Dictionary = {
		"swordsman": {},
		"gunner": {},
		"mage": {}
	}
	var skill_blessing_levels: Dictionary = {}
	var role_upgrade_levels: Dictionary = {
		"swordsman": {"damage_bonus": 0.0},
		"gunner": {"damage_bonus": 0.0},
		"mage": {"damage_bonus": 0.0}
	}
	var speed: float = 100.0
	var max_health: float = 100.0
	var current_health: float = 100.0
	var equipment_cooldown_multiplier: float = 1.0
	var equipment_skill_range_multiplier: float = 1.0
	var equipment_dodge_chance: float = 0.0
	var damage_taken_multiplier: float = 1.0
	var global_position: Vector2 = Vector2.ZERO
	var health_changed := _SignalStub.new()
	var stats_changed := _SignalStub.new()

	func _get_active_role() -> Dictionary:
		return roles[active_role_index]

	func _spawn_combat_tag(_position: Vector2, _text: String, _color: Color) -> void:
		pass

	func _update_fire_timer() -> void:
		pass

	func get_stat_summary() -> Dictionary:
		return {}


class _SignalStub:
	func emit(_a = null, _b = null, _c = null, _d = null) -> void:
		pass
