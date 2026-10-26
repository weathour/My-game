extends Node

const PLAN := preload("res://scripts/game/combat_wave_plan.gd")
const MERCHANT := preload("res://scripts/game/wave_ruan_merchant.gd")
const VIEW := preload("res://scripts/ui/hud/combat_wave_view.gd")
const FLYBY := preload("res://scripts/enemies/enemy_swarm_flyby.gd")
const PREPARATION_SECONDS := 30.0
const DEATH_SECONDS := 0.7
const EXPERIENCE_SETTLE_SECONDS := 0.5

var main
var wave: int = 1
var phase: String = "combat"
var elapsed: float = 0.0
var remaining: float = PREPARATION_SECONDS
var token: int = 1
var claimed: bool = false
var merchant_health: float = 200.0
var merchant_position := Vector2.ZERO
var merchant
var view
var boss_started: bool = false
var elite_index: int = 0
var spawn_remaining: float = 0.0
var special_remaining: float = 0.0
var flyby_remaining: float = 12.0
var flyby_left: int = 0
var flyby_direction := Vector2.RIGHT
var flyby_origin := Vector2.ZERO
var reservations: Dictionary = {}
var blessing_pending: bool = false
var blessing_offer: Dictionary = {}
var ending_elapsed: float = 0.0
var ending_final: bool = false
var small_boss_reward_pending: bool = false
var dying_enemies: Array = []

static func enabled(scene: Node) -> bool:
	return scene != null and not scene._is_developer_mode() and not bool(scene.get("story_mode_active"))

static func setup(scene: Node) -> void:
	if not enabled(scene):
		return
	var flow := new()
	flow.main = scene
	flow.name = "CombatWaveFlow"
	scene.wave_flow = flow
	preload("res://scripts/player/player_level_curve.gd").enable_wave_curve(scene.player)
	scene.add_child(flow)
	flow.view = VIEW.new()
	flow.view.flow = flow
	flow.add_child(flow.view)
	if scene.spawn_timer != null:
		scene.spawn_timer.stop()

func tick(delta: float) -> void:
	if main.game_over:
		view.hide_all()
		return
	if phase in ["clearing", "collecting", "settling"]:
		_tick_wave_ending(delta)
	elif phase == "preparation":
		remaining = maxf(0.0, remaining - delta)
		if remaining <= 0.0:
			skip_preparation()
	elif phase == "combat":
		elapsed += delta
		_start_boss_if_needed()
		if PLAN.duration(wave) > 0 and elapsed >= PLAN.duration(wave):
			begin_preparation()
		else:
			_update_elites(delta)
			_update_spawning(delta)
			_update_flyby(delta)
	view.refresh()

func _start_boss_if_needed() -> void:
	if boss_started or not PLAN.BOSSES.has(wave):
		return
	var kind := "boss" if wave == 20 else "small_boss"
	var enemy = main.ENEMY_SPAWN_FLOW.spawn_special_enemy_with_archetype(main, kind, PLAN.BOSSES[wave])
	if enemy == null:
		return
	boss_started = true
	enemy.set_meta("combat_wave_boss", wave)
	if kind == "boss":
		main.boss_enemy = enemy
		main.boss_spawned = true
	else:
		main.small_boss_enemy = enemy
		main.spawned_small_boss_count += 1
	if wave == 6:
		for index in range(2):
			if can_spawn("shadow_tree"):
				main.ENEMY_SPAWN_FLOW.spawn_special_enemy_with_archetype(main, "normal", "shadow_tree")
		spawn_remaining = PLAN.TREE_ESCORT_INTERVAL
	elif wave == 11:
		spawn_remaining = PLAN.SKULL_ESCORT_INTERVAL

func boss_defeated(enemy: Node) -> void:
	if phase != "combat" or int(enemy.get_meta("combat_wave_boss", 0)) != wave:
		return
	if wave < 20:
		small_boss_reward_pending = true
		begin_preparation()
	else:
		_begin_wave_ending(true)

func _update_elites(delta: float) -> void:
	var elites: Array = PLAN.ELITES.get(wave, [])
	if elite_index >= elites.size() or elapsed < (PLAN.duration(wave) * 0.5 if wave == 5 else 8.0):
		return
	special_remaining -= delta
	if special_remaining > 0.0:
		return
	var living := 0
	for enemy in living_enemies():
		if str(enemy.enemy_kind) == "elite":
			living += 1
	if living >= (2 if wave == 15 else 1):
		return
	var enemy = main.ENEMY_SPAWN_FLOW.spawn_special_enemy_with_archetype(main, "elite", str(elites[elite_index]))
	if enemy != null:
		elite_index += 1
		main.spawned_elite_count += 1
		special_remaining = 10.0

func _update_spawning(delta: float) -> void:
	spawn_remaining -= delta
	if spawn_remaining > 0.0 or wave == 20:
		return
	spawn_remaining = PLAN.TREE_ESCORT_INTERVAL if wave == 6 else PLAN.SKULL_ESCORT_INTERVAL if wave == 11 else 1.0
	var pool: Array = PLAN.POOLS[wave - 1].duplicate()
	pool.shuffle()
	# Always keep basic bodies dominant, while reserving opportunities for specials.
	var budget := 1 if wave in [6, 11] else (2 if wave <= 3 or wave in PLAN.REWARD_WAVES else 3 if wave <= 12 else 4)
	var spawned := 0
	for archetype in pool:
		if spawned >= budget:
			break
		if can_spawn(str(archetype)):
			_warn_spawn(str(archetype))
			spawned += 1
	if wave not in [6, 11]:
		while spawned < budget:
			var basic: String = "chaser" if wave <= 1 else str(["chaser", "runner", "brute"][main.rng.randi_range(0, 2)])
			if basic not in PLAN.POOLS[wave - 1] or not can_spawn(basic):
				break
			_warn_spawn(basic)
			spawned += 1

func living_enemies() -> Array:
	var result: Array = []
	for enemy in main.get_runtime_enemies():
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy.pooled_inactive and enemy.current_health > 0:
			result.append(enemy)
	return result

func can_spawn(archetype: String, include_reservations: bool = true) -> bool:
	if phase != "combat" or archetype not in PLAN.POOLS[wave - 1]:
		return false
	var counts: Dictionary = reservations.duplicate() if include_reservations else {}
	var total := 0
	for enemy in living_enemies():
		var key := str(enemy.archetype_id)
		counts[key] = int(counts.get(key, 0)) + 1
		total += 1
	if include_reservations:
		for value in reservations.values():
			total += int(value)
	if total >= main.ENEMY_SPAWN_FLOW.get_runtime_enemy_limit(main):
		return false
	if int(counts.get(archetype, 0)) >= PLAN.single_limit(wave, archetype, elapsed):
		return false
	var category := PLAN.category(archetype)
	if category == "basic":
		return true
	var category_count := 0
	for key in counts:
		if PLAN.category(str(key)) == category:
			category_count += int(counts[key])
	var cap := int(PLAN.limits(wave)[category])
	return category_count < cap

func _warn_spawn(archetype: String) -> void:
	reservations[archetype] = int(reservations.get(archetype, 0)) + 1
	var pos: Vector2 = main._get_spawn_position(main.rng.randf_range(0.0, TAU), main.spawn_distance)
	main.ENEMY_SPAWN_FLOW.SPAWN_WARNING_FLOW.show_enemy_spawn_warning(
		main, archetype, main._get_spawn_enemy_health_multiplier("normal"),
		main._get_spawn_enemy_speed_multiplier(), main._get_spawn_enemy_damage_multiplier(), pos, token)

func accept_spawn(request: Dictionary) -> bool:
	if int(request.get("wave_token", 0)) != token or phase != "combat":
		return false
	var archetype := str(request.get("archetype", ""))
	reservations[archetype] = maxi(0, int(reservations.get(archetype, 0)) - 1)
	return can_spawn(archetype, false)

func _update_flyby(delta: float) -> void:
	if wave not in PLAN.FLYBY_WAVES:
		return
	flyby_remaining -= delta
	if flyby_left > 0:
		var enemy = main.ENEMY_SPAWN_FLOW.spawn_special_enemy_with_archetype(main, "normal", "swarm")
		if enemy != null:
			enemy.global_position = flyby_origin + flyby_direction.orthogonal() * main.rng.randf_range(-220.0, 220.0)
			FLYBY.configure(enemy, flyby_direction)
			flyby_left -= 1
		return
	if flyby_remaining > 0:
		return
	for enemy in living_enemies():
		if enemy.has_meta("wave_flyby"):
			return
	flyby_left = 12 if wave < 14 else 18 if wave < 19 else 24
	flyby_direction = Vector2.RIGHT.rotated(main.rng.randf_range(0, TAU))
	var viewport: Vector2 = main.get_viewport_rect().size
	var camera: Camera2D = main.get_viewport().get_camera_2d()
	if camera != null:
		viewport /= camera.zoom
	flyby_origin = main.player.global_position - flyby_direction * (viewport.length() * 0.5 + 120.0)
	flyby_remaining = 30.0

func begin_preparation() -> void:
	_begin_wave_ending(false)

func _begin_wave_ending(final_wave: bool) -> void:
	if phase != "combat":
		return
	phase = "clearing"
	ending_final = final_wave
	ending_elapsed = 0.0
	token += 1
	reservations.clear()
	var warning_batch: Node = main.get_node_or_null("SpawnWarningBatch")
	if warning_batch != null:
		warning_batch.warnings.clear()
		warning_batch.pending_finished_entries.clear()
		warning_batch.queue_redraw()
	flyby_left = 0
	main.pending_enemy_spawn_requests.clear()
	main.pending_enemy_spawn_cursor = 0
	_clear_remaining_enemies_without_rewards()
	main.call_deferred("_save_run_state")

func _tick_wave_ending(delta: float) -> void:
	ending_elapsed += delta
	if phase == "clearing":
		var progress := clampf(ending_elapsed / DEATH_SECONDS, 0.0, 1.0)
		for entry in dying_enemies:
			var enemy = entry.enemy
			if not is_instance_valid(enemy):
				continue
			enemy.modulate = entry.color.lerp(Color(1.0, 0.75, 0.9, 0.0), progress)
			enemy.scale = entry.scale * Vector2(1.0 + progress * 0.2, 1.0 - progress * 0.75)
			enemy.rotation = float(entry.rotation) + progress * 0.35
		if ending_elapsed < DEATH_SECONDS:
			return
		_release_dying_enemies()
		phase = "collecting"
		ending_elapsed = 0.0
	if phase == "collecting":
		var gems_left := _attract_wave_experience()
		if gems_left:
			return
		phase = "settling"
		ending_elapsed = 0.0
	elif phase == "settling":
		# Include any late drops before opening a menu or pausing the world.
		if _attract_wave_experience():
			phase = "collecting"
			ending_elapsed = 0.0
			return
		if ending_elapsed >= EXPERIENCE_SETTLE_SECONDS:
			_finish_wave_ending()

func _attract_wave_experience() -> bool:
	var left := false
	var experience := 0
	var center: Vector2 = main.player.get_hurtbox_center()
	for gem in main.get_runtime_pickups("exp_gems").duplicate():
		if not is_instance_valid(gem) or gem.is_queued_for_deletion() or gem.pooled:
			continue
		gem.set_attraction_target(main.player)
		if gem.global_position.distance_to(center) <= main.player.GEM_ABSORB_RADIUS:
			experience += int(gem.collect())
		else:
			left = true
	if experience > 0:
		main.player.gain_experience(experience)
	return left

func _finish_wave_ending() -> void:
	phase = "complete" if ending_final else "preparation"
	remaining = PREPARATION_SECONDS
	claimed = false
	merchant_health = 200.0
	merchant_position = main.player.global_position + Vector2(110, 0)
	merchant_position = merchant_position.clamp(main.map_bounds.position + Vector2(50, 50), main.map_bounds.end - Vector2(50, 50))
	if not ending_final:
		_create_merchant()
	_queue_wave_blessing()
	if small_boss_reward_pending:
		preload("res://scripts/game/reward_flow.gd").show_small_boss_reward(main)
	main.call_deferred("_save_run_state")

func _queue_wave_blessing() -> void:
	blessing_pending = true
	blessing_offer = preload("res://scripts/player/player_blessing_system.gd").build_wave_offer_for_owner(main.player)
	call_deferred("show_pending_blessing")

func show_pending_blessing() -> bool:
	if not blessing_pending or main.game_over or phase in ["clearing", "collecting", "settling"]:
		return false
	if main.reward_context != "" or main.get_tree().paused:
		return false
	return preload("res://scripts/game/reward_flow.gd").show_wave_blessing(main)

func _absorb_all_experience() -> int:
	var total := 0
	for gem in main.get_runtime_pickups("exp_gems").duplicate():
		if not is_instance_valid(gem) or gem.is_queued_for_deletion() or gem.pooled:
			continue
		total += int(gem.collect())
	if total > 0:
		main.player.gain_experience(total)
	return total

func finish_wave_blessing() -> void:
	blessing_pending = false
	blessing_offer = {}
	main.player.current_blessing_offer = {}
	main.reward_context = ""
	main._refresh_hud()
	main._save_run_state()
	if phase == "complete":
		if main.endless_mode_active:
			main.ENEMY_DEFEAT_FLOW._handle_endless_boss_defeated(main)
		else:
			main._on_stage_cleared()

func _clear_remaining_enemies_without_rewards() -> void:
	# Wave expiry is not a player kill: bypass damage, defeat signals and drops.
	for enemy in main.get_runtime_enemies().duplicate():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.pooled_inactive:
			continue
		if enemy.current_health <= 0:
			continue
		enemy.current_health = 0.0
		enemy.clear_runtime_effects_after_defeat()
		enemy.set_physics_process(false)
		enemy.set_process(false)
		enemy.velocity = Vector2.ZERO
		enemy.set_meta("wave_cleanup", true)
		dying_enemies.append({"enemy": enemy, "color": enemy.modulate, "scale": enemy.scale, "rotation": enemy.rotation})

func _release_dying_enemies() -> void:
	for entry in dying_enemies:
		var enemy = entry.enemy
		if not is_instance_valid(enemy):
			continue
		enemy.modulate = entry.color
		enemy.scale = entry.scale
		enemy.rotation = entry.rotation
		enemy.remove_meta("wave_cleanup")
		if not enemy.release_after_defeat():
			enemy.set_physics_process(false)
			enemy.hide()
			enemy.queue_free()
	dying_enemies.clear()

func _create_merchant() -> void:
	if is_instance_valid(merchant):
		merchant.queue_free()
	merchant = null
	if merchant_health <= 0:
		return
	merchant = MERCHANT.new()
	merchant.flow = self
	merchant.position = merchant_position
	add_child(merchant)

func skip_preparation() -> void:
	if phase != "preparation" or blessing_pending or main.game_over or main.get_tree().paused:
		return
	if is_instance_valid(merchant):
		merchant.queue_free()
	merchant = null
	preload("res://scripts/player/player_skill_cooldown_flow.gd").reset_team_skill_cooldowns(main.player, 0.2)
	wave = mini(20, wave + 1)
	phase = "combat"
	elapsed = 0.0
	token += 1
	claimed = false
	boss_started = false
	elite_index = 0
	spawn_remaining = 0.0
	special_remaining = 0.0
	flyby_remaining = 12.0
	flyby_left = 0
	view.close_shop()
	view.refresh()
	main._save_run_state()

func claim_first_aid() -> void:
	if phase != "preparation" or claimed or merchant_health <= 0 or main.game_over or main.get_tree().paused:
		return
	if not is_instance_valid(merchant) or main.player.global_position.distance_to(merchant.global_position) > 120.0:
		return
	claimed = true
	main.player.restore_team_missing_health(0.5)
	view.refresh()
	main._refresh_hud()
	main._save_run_state()

func get_save_data() -> Dictionary:
	return {
		"version": 1, "wave": wave, "phase": phase, "elapsed": elapsed, "remaining": remaining,
		"blessing_pending": blessing_pending, "blessing_offer": blessing_offer.duplicate(true),
		"ending_elapsed": ending_elapsed, "ending_final": ending_final,
		"small_boss_reward_pending": small_boss_reward_pending,
		"claimed": claimed, "merchant_health": merchant_health,
		"merchant_position": [merchant_position.x, merchant_position.y],
		"boss_started": boss_started, "elite_index": elite_index,
		"spawn_remaining": spawn_remaining, "special_remaining": special_remaining,
		"flyby_remaining": flyby_remaining, "flyby_left": flyby_left,
		"flyby_direction": [flyby_direction.x, flyby_direction.y],
		"flyby_origin": [flyby_origin.x, flyby_origin.y]
	}

func apply_save_data(data: Dictionary) -> void:
	if data.is_empty():
		_migrate_existing_boss()
		view.refresh()
		return
	wave = clampi(int(data.get("wave", 1)), 1, 20)
	phase = str(data.get("phase", "combat"))
	if phase not in ["combat", "preparation", "complete", "clearing", "collecting", "settling"]:
		phase = "combat"
	ending_elapsed = maxf(0.0, float(data.get("ending_elapsed", 0.0)))
	ending_final = bool(data.get("ending_final", wave == 20))
	small_boss_reward_pending = bool(data.get("small_boss_reward_pending", false))
	elapsed = maxf(0, float(data.get("elapsed", 0)))
	remaining = clampf(float(data.get("remaining", 30)), 0, 30)
	claimed = bool(data.get("claimed", false))
	blessing_pending = bool(data.get("blessing_pending", false))
	blessing_offer = data.get("blessing_offer", {}).duplicate(true)
	merchant_health = clampf(float(data.get("merchant_health", 200)), 0, 200)
	var p: Array = data.get("merchant_position", [0, 0])
	merchant_position = Vector2(float(p[0]), float(p[1]))
	boss_started = bool(data.get("boss_started", false))
	elite_index = int(data.get("elite_index", 0))
	spawn_remaining = float(data.get("spawn_remaining", 0))
	special_remaining = float(data.get("special_remaining", 0))
	flyby_remaining = float(data.get("flyby_remaining", 12))
	flyby_left = int(data.get("flyby_left", 0))
	var direction: Array = data.get("flyby_direction", [1, 0])
	var origin: Array = data.get("flyby_origin", [0, 0])
	flyby_direction = Vector2(float(direction[0]), float(direction[1]))
	flyby_origin = Vector2(float(origin[0]), float(origin[1]))
	token += 1
	reservations.clear()
	if phase == "preparation":
		_create_merchant()
	view.refresh()

func _migrate_existing_boss() -> void:
	# Existing enemies and player progression stay intact when continuing a
	# pre-wave save. If a boss is already alive, adopt that encounter.
	var boss = main.boss_enemy if is_instance_valid(main.boss_enemy) else main.small_boss_enemy
	if not is_instance_valid(boss):
		return
	for number in PLAN.BOSSES:
		if str(boss.archetype_id) == str(PLAN.BOSSES[number]):
			wave = int(number)
			boss_started = true
			boss.set_meta("combat_wave_boss", wave)
			break
