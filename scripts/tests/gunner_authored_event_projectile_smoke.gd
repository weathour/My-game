extends SceneTree

const DamageBatcher := preload("res://scripts/player/player_damage_batcher.gd")
const DamageResolver := preload("res://scripts/player/player_damage_resolver.gd")
const GunnerRole := preload("res://scripts/player/roles/gunner_role.gd")
const ProjectileBatch := preload("res://scripts/player/player_projectile_batch.gd")
const SwitchEntryFlow := preload("res://scripts/player/player_switch_entry_flow.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node.new()
	root.add_child(scene)
	current_scene = scene
	var owner := DamageOwner.new()
	scene.add_child(owner)

	_check_cross_frame_pierce(scene, owner)
	_check_three_shot_group(scene, owner)
	_check_empty_event(owner)
	_check_entry_repulse_collision(owner)
	_check_no_hunt_exclusion(owner)

	scene.free()
	print("GUNNER_AUTHORED_EVENT_PROJECTILE_SMOKE_OK")
	quit(0)


func _check_cross_frame_pierce(scene: Node, owner: DamageOwner) -> void:
	owner.reset_execution()
	var first := DamageEnemy.new()
	var second := DamageEnemy.new()
	scene.add_child(first)
	scene.add_child(second)
	var batch := ProjectileBatch.new()
	batch.configure(owner)
	var event_id := owner.gunner_role.create_damage_event_id(owner, "pierce")
	assert(batch.add_projectile({
		"position": Vector2.ZERO,
		"source_origin": Vector2.ZERO,
		"direction": Vector2.RIGHT,
		"damage": 10.0,
		"role_id": "gunner",
		"pierce_count": 2,
		"damage_event_id": event_id
	}))
	batch.damage_batcher = DamageBatcher.new(owner)
	batch._apply_projectile_hit(0, first)
	batch.damage_batcher.flush()
	assert(owner.gunner_flash_stacks == 5)
	owner.gunner_flash_stacks = 10
	owner._get_role_special_state("gunner")["talent_runtime"]["execution_cooldown_remaining"] = 0.0
	batch.damage_batcher = DamageBatcher.new(owner)
	batch._apply_projectile_hit(0, second)
	batch.damage_batcher.flush()
	assert(owner.gunner_flash_stacks == 10)
	var queue: Node = scene.get_node("PlayerDamageJobQueue")
	queue._apply_job_at_index(0)
	queue._apply_job_at_index(1)
	assert(is_equal_approx(first.damage_taken, 16.0))
	assert(is_equal_approx(second.damage_taken, 16.0))
	batch._remove_projectile(0)
	assert(not owner.damage_events().has(event_id))
	batch.free()


func _check_three_shot_group(scene: Node, owner: DamageOwner) -> void:
	owner.reset_execution()
	var batch := ProjectileBatch.new()
	batch.configure(owner)
	var event_id := owner.gunner_role.create_damage_event_id(owner, "burst")
	owner.gunner_role.register_damage_event(owner, event_id, 0.5)
	var enemies: Array[DamageEnemy] = []
	for index in range(3):
		var enemy := DamageEnemy.new()
		scene.add_child(enemy)
		enemies.append(enemy)
		assert(batch.add_projectile({
			"position": Vector2.ZERO,
			"source_origin": Vector2.ZERO,
			"direction": Vector2.RIGHT,
			"damage": 10.0,
			"role_id": "gunner",
			"damage_event_id": event_id
		}))
		batch.damage_batcher = DamageBatcher.new(owner)
		batch._apply_projectile_hit(0, enemy)
		batch.damage_batcher.flush()
		if index == 0:
			assert(owner.gunner_flash_stacks == 5)
			owner.gunner_flash_stacks = 10
			owner._get_role_special_state("gunner")["talent_runtime"]["execution_cooldown_remaining"] = 0.0
		else:
			assert(owner.gunner_flash_stacks == 10)
		if index >= 2:
			owner.gunner_role.release_damage_event(owner, event_id)
		batch._remove_projectile(0)
		if index < 2:
			assert(owner.damage_events().has(event_id))
	var queue: Node = scene.get_node("PlayerDamageJobQueue")
	var start_index: int = queue.enemy_refs.size() - 3
	for index in range(start_index, queue.enemy_refs.size()):
		queue._apply_job_at_index(index)
	for enemy in enemies:
		assert(is_equal_approx(enemy.damage_taken, 16.0))
	assert(not owner.damage_events().has(event_id))
	batch.free()


func _check_empty_event(owner: DamageOwner) -> void:
	owner.reset_execution()
	var batch := ProjectileBatch.new()
	batch.configure(owner)
	var event_id := owner.gunner_role.create_damage_event_id(owner, "empty")
	assert(batch.add_projectile({
		"position": Vector2.ZERO,
		"damage": 10.0,
		"role_id": "gunner",
		"damage_event_id": event_id
	}))
	batch._remove_projectile(0)
	assert(owner.gunner_flash_stacks == 10)
	assert(not owner.damage_events().has(event_id))
	batch.free()


func _check_entry_repulse_collision(owner: DamageOwner) -> void:
	owner.talents = {"gunner_entry_repulse": true}
	owner.spawned_projectiles.clear()
	SwitchEntryFlow.fire_gunner_entry_wave(owner, "gunner", 0)
	assert(not owner.spawned_projectiles.is_empty())
	assert(bool(owner.spawned_projectiles[0].get("entry_repulse_on_first_hit", false)))

	var batch := ProjectileBatch.new()
	batch.configure(owner)
	assert(batch.add_projectile({
		"position": Vector2.ZERO,
		"direction": Vector2.RIGHT,
		"damage": 1.0,
		"role_id": "gunner",
		"entry_repulse_on_first_hit": true
	}))
	var moved_enemy := DamageEnemy.new()
	moved_enemy.global_position = Vector2(400.0, 300.0)
	var grid := batch._build_enemy_grid([moved_enemy])
	assert(batch._find_hit_enemy(0, grid) == null)
	assert(moved_enemy.global_position == Vector2(400.0, 300.0))
	moved_enemy.global_position = Vector2.ZERO
	batch.damage_batcher = DamageBatcher.new(owner)
	batch._apply_projectile_hit(0, moved_enemy)
	assert(is_equal_approx(moved_enemy.global_position.x, 48.0))
	var boss := DamageEnemy.new()
	boss.enemy_kind = "boss"
	assert(batch.add_projectile({
		"position": Vector2.ZERO,
		"direction": Vector2.RIGHT,
		"damage": 1.0,
		"role_id": "gunner",
		"entry_repulse_on_first_hit": true
	}))
	batch._apply_projectile_hit(1, boss)
	assert(boss.global_position == Vector2.ZERO)
	moved_enemy.free()
	boss.free()
	batch.free()


func _check_no_hunt_exclusion(owner: DamageOwner) -> void:
	owner.reset_execution()
	var enemy := DamageEnemy.new()
	var event_id := owner.gunner_role.create_damage_event_id(owner, "no_hunt")
	DamageResolver.deal_damage_to_enemy(owner, enemy, 10.0, "gunner_no_hunt", 0.0, 2.0, 1.0, 0.0, Vector2.ZERO, false, 0.0, false, event_id)
	assert(owner.gunner_flash_stacks == 10)
	assert(is_equal_approx(enemy.damage_taken, 10.0))
	enemy.free()


class DamageEnemy:
	extends Node2D
	var current_health := 100.0
	var enemy_kind := "normal"
	var contact_radius := 12.0
	var damage_taken := 0.0

	func take_damage(amount: float, _critical: bool = false) -> bool:
		damage_taken += amount
		current_health -= amount
		return current_health <= 0.0


class DamageOwner:
	extends Node2D
	var gunner_role := GunnerRole.new()
	var talents: Dictionary = {"gunner_trait_execution": true}
	var role_special_states := {"gunner": {"talent_runtime": {}}}
	var gunner_flash_stacks := 10
	var spawned_projectiles: Array[Dictionary] = []
	var facing_direction := Vector2.RIGHT

	func reset_execution() -> void:
		talents = {"gunner_trait_execution": true}
		gunner_flash_stacks = 10
		_get_role_special_state("gunner")["talent_runtime"] = {}

	func damage_events() -> Dictionary:
		return _get_role_special_state("gunner")["talent_runtime"].get("damage_events", {})

	func _has_skill_talent(talent_id: String) -> bool:
		return bool(talents.get(talent_id, false))

	func _get_role_special_state(role_id: String) -> Dictionary:
		if not role_special_states.has(role_id):
			role_special_states[role_id] = {}
		return role_special_states[role_id]

	func _get_active_role() -> Dictionary:
		return {"id": "gunner"}

	func _get_role_damage(_role_id: String) -> float:
		return 10.0

	func _get_gunner_safe_zone_radius() -> float:
		return 100.0

	func _get_gunner_distance_damage_multiplier(_distance: float) -> float:
		return 1.0

	func _roll_critical_hit(_role_id: String, _chance_bonus: float = 0.0) -> bool:
		return false

	func _get_critical_damage_multiplier(_role_id: String) -> float:
		return 2.0

	func _queue_camera_shake(_strength: float, _duration: float) -> void:
		pass

	func _schedule_repeating_sequence(_interval: float, _count: int, callback: Callable, _initial_delay: float = 0.0) -> void:
		callback.call(0)

	func _spawn_batched_directional_bullet(direction: Vector2, damage: float, _color: Color, role_id: String, origin: Variant, config: Dictionary) -> bool:
		var data := config.duplicate()
		data.merge({
			"direction": direction,
			"damage": damage,
			"role_id": role_id,
			"origin": origin
		})
		spawned_projectiles.append(data)
		return true

	func _spawn_batched_directional_bullet_values(_direction: Vector2, _damage: float, _color: Color, _role_id: String = "", _origin: Variant = null) -> bool:
		return false
