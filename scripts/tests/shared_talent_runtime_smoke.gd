extends SceneTree

const DamageBatcher := preload("res://scripts/player/player_damage_batcher.gd")
const DamageResolver := preload("res://scripts/player/player_damage_resolver.gd")
const GunnerRole := preload("res://scripts/player/roles/gunner_role.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node.new()
	root.add_child(scene)
	current_scene = scene
	var owner := DamageOwner.new()
	scene.add_child(owner)
	var first := DamageEnemy.new()
	var second := DamageEnemy.new()
	first.global_position = Vector2(160.0, 0.0)
	second.global_position = Vector2(180.0, 0.0)
	scene.add_child(first)
	scene.add_child(second)

	owner.talents = {"gunner_trait_execution": true}
	owner.gunner_flash_stacks = 10
	var batcher := DamageBatcher.new(owner)
	batcher.add_enemy(first, 10.0, "gunner", 0.0, 2.0, 1.0, 0.0, Vector2.ZERO)
	batcher.add_enemy(second, 10.0, "gunner", 0.0, 2.0, 1.0, 0.0, Vector2.ZERO)
	assert(batcher.flush() == 2)
	assert(owner.gunner_flash_stacks == 5)

	var queue: Node = scene.get_node("PlayerDamageJobQueue")
	owner.talents.clear()
	queue._apply_job_at_index(0)
	queue._apply_job_at_index(1)
	assert(is_equal_approx(first.damage_taken, 16.0))
	assert(is_equal_approx(second.damage_taken, 16.0))

	owner.talents = {"gunner_trait_execution": true}
	owner.gunner_flash_stacks = 10
	owner._get_role_special_state("gunner")["talent_runtime"]["execution_cooldown_remaining"] = 0.0
	var empty_batcher := DamageBatcher.new(owner)
	assert(empty_batcher.flush() == 0)
	assert(owner.gunner_flash_stacks == 10)
	DamageResolver.deal_damage_to_enemy(owner, first, 0.0, "gunner")
	assert(owner.gunner_flash_stacks == 10)

	owner.talents = {
		"gunner_trait_far_calibration": true,
		"gunner_trait_repulse": true
	}
	var far_enemy := DamageEnemy.new()
	var near_enemy := DamageEnemy.new()
	far_enemy.global_position = Vector2(180.0, 0.0)
	near_enemy.global_position = Vector2(40.0, 0.0)
	scene.add_child(far_enemy)
	scene.add_child(near_enemy)
	DamageResolver.deal_damage_to_enemy(owner, far_enemy, 10.0, "gunner", 0.0, 2.0, 1.0, 0.0, Vector2.ZERO)
	DamageResolver.deal_damage_to_enemy(owner, near_enemy, 10.0, "gunner", 0.0, 2.0, 1.0, 0.0, Vector2.ZERO)
	assert(is_equal_approx(far_enemy.vulnerability_bonus, 0.06))
	assert(is_equal_approx(far_enemy.vulnerability_at_last_hit, 0.0))
	assert(near_enemy.global_position.x > 40.0)
	owner.global_position = Vector2(100.0, 0.0)
	var moved_owner_enemy := DamageEnemy.new()
	moved_owner_enemy.global_position = Vector2(180.0, 0.0)
	scene.add_child(moved_owner_enemy)
	DamageResolver.deal_damage_to_enemy(owner, moved_owner_enemy, 10.0, "gunner", 0.0, 2.0, 1.0, 0.0, Vector2.ZERO)
	assert(is_equal_approx(moved_owner_enemy.vulnerability_bonus, 0.0))
	assert(moved_owner_enemy.global_position.x > 180.0)

	owner.talents = {"gunner_ultimate_line": true}
	var cast_snapshot := {"gunner_ultimate_line": true, "gunner_ultimate_fan": false}
	owner.talents.clear()
	assert(owner.gunner_role._get_ultimate_cone_range(owner, cast_snapshot) > owner.gunner_role._get_ultimate_cone_range(owner))

	print("SHARED_TALENT_RUNTIME_SMOKE_OK")
	quit(0)


class DamageEnemy:
	extends Node2D
	var current_health := 100.0
	var enemy_kind := "normal"
	var damage_taken := 0.0
	var vulnerability_bonus := 0.0
	var vulnerability_at_last_hit := 0.0

	func take_damage(amount: float, _critical: bool = false) -> bool:
		vulnerability_at_last_hit = vulnerability_bonus
		damage_taken += amount
		current_health -= amount
		return current_health <= 0.0

	func apply_vulnerability(value: float, _duration: float) -> void:
		vulnerability_bonus = max(vulnerability_bonus, value)


class DamageOwner:
	extends Node2D
	var gunner_role := GunnerRole.new()
	var talents: Dictionary = {}
	var role_special_states := {"gunner": {"talent_runtime": {}}}
	var gunner_flash_stacks := 0

	func _has_skill_talent(talent_id: String) -> bool:
		return bool(talents.get(talent_id, false))

	func _get_role_special_state(role_id: String) -> Dictionary:
		if not role_special_states.has(role_id):
			role_special_states[role_id] = {}
		return role_special_states[role_id]

	func _get_gunner_safe_zone_radius() -> float:
		return 100.0

	func _get_gunner_distance_damage_multiplier(_distance: float) -> float:
		return 1.0

	func _roll_critical_hit(_role_id: String, _chance_bonus: float = 0.0) -> bool:
		return false

	func _get_critical_damage_multiplier(_role_id: String) -> float:
		return 2.0

	func _get_role_attribute_range_multiplier(_role_id: String) -> float:
		return 1.0

	func _get_role_equipment_skill_range_multiplier(_role_id: String) -> float:
		return 1.0
