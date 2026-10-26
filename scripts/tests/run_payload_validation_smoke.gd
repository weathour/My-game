extends SceneTree

const VALIDATOR := preload("res://scripts/save/run_payload_validator.gd")
const RUNTIME := preload("res://scripts/game/run_save_runtime_flow.gd")
const PLAYER := preload("res://scenes/player.tscn")
const ENEMY := preload("res://scenes/enemy.tscn")
const BULLET := preload("res://scenes/enemy_bullet.tscn")
const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const FLYBY := preload("res://scripts/enemies/enemy_swarm_flyby.gd")
const DOMAIN := preload("res://scripts/enemies/skull_mage_domain.gd")
const SEED := preload("res://scripts/enemies/parasite_seed.gd")
const CRACK := preload("res://scripts/player/swordsman_ground_crack.gd")
const WAVE := preload("res://scripts/game/combat_wave_flow.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := RuntimeRoot.new()
	root.add_child(main)
	current_scene = main
	main.player = PLAYER.instantiate()
	main.add_child(main.player)
	main.player.set_physics_process(false)
	var player_data: Dictionary = main.player.get_save_data()
	var run := {"player": player_data}
	_expect_valid(run, "default player")
	main.player.apply_save_data(player_data)
	_expect_valid({"player": main.player.get_save_data()}, "restored player")
	var enemy := ENEMY.instantiate()
	main.add_child(enemy)
	enemy.set_physics_process(false)
	var enemy_data: Dictionary = enemy.get_save_data()
	run.enemies = [enemy_data]
	var restored_enemy := ENEMY.instantiate()
	main.add_child(restored_enemy)
	restored_enemy.apply_save_data(enemy_data, main.player)
	_expect_valid({"player": {}, "enemies": [restored_enemy.get_save_data()]}, "restored enemy")
	for archetype in ["skull_mage", "vine", "shadow_tree", "necro_priest", "angry_porcupine", "swarm"]:
		enemy.apply_enemy_profile("normal", DATABASE.get_profile("normal", archetype))
		if archetype == "swarm":
			FLYBY.configure(enemy, Vector2.RIGHT)
		var saved_enemy: Dictionary = enemy.get_save_data()
		_expect_valid({"player": {}, "enemies": [saved_enemy]}, archetype + " real state")
		var parsed_enemy: Dictionary = JSON.parse_string(JSON.stringify(saved_enemy))
		_expect_valid({"player": {}, "enemies": [parsed_enemy]}, archetype + " JSON state")
		restored_enemy.apply_save_data(parsed_enemy, main.player)
		_expect_valid({"player": {}, "enemies": [restored_enemy.get_save_data()]}, archetype + " restored state")
	var bullet := BULLET.instantiate()
	main.add_child(bullet)
	var bullet_data: Dictionary = bullet.get_save_data()
	run.enemy_projectiles = [bullet_data]
	bullet.apply_save_data(bullet_data, main.player)
	for key in ["gems", "heart_pickups", "bone_pickups", "experience_vacuum_pickups"]:
		var scene_path: String = "exp_gem" if key == "gems" else key.trim_suffix("s")
		var pickup = load("res://scenes/%s.tscn" % scene_path).instantiate()
		main.add_child(pickup)
		pickup.global_position = Vector2(23, -17)
		var saved: Dictionary = pickup.get_save_data()
		run[key] = [saved]
		pickup.apply_save_data(saved)
		_check(pickup.global_position == Vector2(23, -17), key + " position roundtrip")
	var domain := DOMAIN.new()
	main.add_child(domain)
	domain.position = Vector2(34, 56)
	run.skull_mage_domains = [domain.get_save_data()]
	RUNTIME.restore_skull_mage_domains(main, run.skull_mage_domains)
	var restored_domain = main.get_children().back()
	_check(restored_domain is Node2D and restored_domain.position == domain.position and restored_domain.remaining == domain.remaining, "domain restoration")
	var seed := SEED.new()
	main.add_child(seed)
	run.parasite_seeds = [seed.get_save_data()]
	seed.apply_save_data(run.parasite_seeds[0], main.player)
	var crack := CRACK.new()
	main.add_child(crack)
	run.swordsman_ground_cracks = [crack.get_save_data()]
	crack.apply_save_data(run.swordsman_ground_cracks[0], main.player)
	var wave := WAVE.new()
	run.combat_wave = wave.get_save_data()
	wave.free()
	run.reward_state = {"context": "small_boss_reward", "reward_options": [{"id": "old_option"}]}
	_expect_valid(run, "all runtime object payloads")
	var json_copy: Variant = JSON.parse_string(JSON.stringify(run))
	_expect_valid(json_copy, "JSON roundtrip")
	for key in VALIDATOR.OBJECT_ARRAYS:
		_expect_bad({"player": {}, key: [3]}, key + "[0]")
		_expect_bad({"player": {}, key: [{"position": [1], "direction": [1, 0]}]}, key + "[0].position")
		_expect_bad({"player": {}, key: [{"position": ["x", 0], "direction": [1, 0]}]}, key + "[0].position")
	_expect_bad({"player": {}, "skull_mage_domains": [{}]}, "skull_mage_domains[0].position")
	_expect_bad({"player": {}, "parasite_seeds": [{"position": [0, 0]}]}, "parasite_seeds[0].direction")
	_expect_bad({"player": {"role_mana_values": []}}, "player.role_mana_values")
	_expect_bad({"player": {"role_health_values": {"mage": {}}}}, "player.role_health_values.mage")
	_expect_bad({"player": {"ability_runtime": {"blade_storm": {"cast_origin": []}}}}, "player.ability_runtime.blade_storm.cast_origin")
	_expect_bad({"player": {"ability_runtime": {"infinite_reload": {"build_version": 1, "pending_beam_hits": [3]}}}}, "pending_beam_hits[0]")
	_expect_bad({"player": {"roles": [3]}}, "player.roles[0]")
	_expect_bad({"player": {"ability_runtime": {"shrapnel_field": {"fields": [{"center": [0]}]}}}}, "fields[0].center")
	_expect_bad({"player": {"temporary_health_stacks": [3]}}, "temporary_health_stacks[0]")
	_expect_bad({"player": {"movement_slow_sources": {"ice": {}}}}, "movement_slow_sources.ice")
	_expect_bad({"player": {}, "combat_wave": {"merchant_position": []}}, "combat_wave.merchant_position")
	_expect_bad({"player": {}, "combat_wave": {"blessing_offer": []}}, "combat_wave.blessing_offer")
	_expect_bad({"player": {}, "reward_state": {"reward_options": [3]}}, "reward_state.reward_options[0]")
	_expect_bad({"player": {}, "enemies": [{"wave_flyby": []}]}, "enemies[0].wave_flyby")
	_expect_bad({"player": {}, "enemies": [{"skulltomb_domain": {"center": []}}]}, "enemies[0].skulltomb_domain.center")
	_expect_bad({"player": {"current_health": INF}}, "current_health")
	_expect_bad({"player": {}, "music_position": NAN}, "music_position")
	for case in [
		[INF, "run: expected finite number"], [NAN, "run: expected finite number"],
		[{"nested": [0, {"bad": INF}]}, "run.nested[1].bad: expected finite number"],
		[{"nested": [{"deep": [1, NAN]}]}, "run.nested[0].deep[1]: expected finite number"],
		[[[], {"空键": {"": INF}}], "run[1].空键.: expected finite number"],
		[{"ordinary": [null, true, false, 0, 1.5, "text"]}, ""]
	]:
		_check(VALIDATOR._finite(case[0], "run") == case[1], "finite scan preserves exact nested diagnostic path")
	_expect_bad({"player": {"blindness": {"remaining": []}}}, "player.blindness.remaining")
	_expect_bad({"player": {}, "enemies": [{"plant_state": {"direction": []}}]}, "enemies[0].plant_state.direction")
	_expect_valid({"player": {}}, "minimal legacy")
	_expect_valid({"story_initial": true, "player": {}}, "initial story")
	_expect_valid({"player": {}, "enemies": [{"archetype_id": "unknown_legacy_id"}], "future_field": {"hello": [1, 2, 3]}}, "unknown fields and legacy enemy id")
	for flag in ["boss_spawned", "story_initial"]:
		for invalid in [{}, [], null, "true", 2]:
			_expect_bad({"player": {}, flag: invalid}, flag)
		for valid in [true, false, 0, 1.0]:
			_expect_valid({"player": {}, flag: valid}, "legacy flag " + flag)
	for flag in ["ending_final", "small_boss_reward_pending", "claimed", "blessing_pending", "boss_started"]:
		_expect_bad({"player": {}, "combat_wave": {flag: {}}}, "combat_wave." + flag)
		_expect_valid({"player": {}, "combat_wave": {flag: 1}}, "legacy wave flag " + flag)
	for key in ["pending_run_end", "pending_settlement"]:
		_expect_bad({"player": {}, key: {"summary": []}}, key + ".summary")
	_expect_bad({"player": {}, "pending_run_end": {"outcome": "victory"}}, "pending_run_end.outcome")
	_expect_bad({"player": {}, "pending_run_end": {"outcome": {}}}, "pending_run_end.outcome")
	_expect_bad({"player": {}, "reward_state": {"context": []}}, "reward_state.context")
	for pending in [{}, {"outcome": "failed"}, {"outcome": "abandoned", "summary": {}}]:
		_expect_valid({"player": {}, "pending_run_end": pending}, "pending outcome fallback and supported outcomes")
	_check_guarded_restore(main)
	main.free()
	if failures.is_empty():
		print("RUN_PAYLOAD_VALIDATION_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_guarded_restore(main: RuntimeRoot) -> void:
	var bad_gem := {"position": [0, 0], "attraction_active": true, "attraction_speed": {}}
	_expect_bad({"player": {}, "gems": [bad_gem]}, "gems[0].attraction_speed")
	var child_count := main.get_child_count()
	_check(not RUNTIME.restore_gems(main, [bad_gem]), "bad attraction speed refused at real gem restore entrance")
	_check(not RUNTIME.restore_skull_mage_domains(main, [{"position": [0]}]), "short domain position refused at real restore entrance")
	_check(not RUNTIME.restore_parasite_seeds(main, [{"position": [0, 0], "direction": {}}]), "bad seed direction refused at real restore entrance")
	_check(main.get_child_count() == child_count, "rejected restore must not add runtime children")
	_expect_bad({"player": {"roles": [{"id": "mage", "range": {}}]}}, "player.roles[0].range")
	_expect_bad({"player": {"roles": [{"id": "mage", "color": [1, {}, 1]}]}}, "player.roles[0].color[1]")
	_expect_bad({"player": {"roles": [{}]}}, "player.roles[0].id")
	var beam := {
		"build_version": 1,
		"cast_snapshot": {"choices": ["fire_control"], "cooldown": 10.0, "range_bonus": 2.0, "damage_ratio": 0.4},
		"pending_beam_hits": [{"remaining": 1.0, "shapes": [{"type": "oriented_rect", "center": [2, 3], "axis": [1, 0], "source_position": [0, 0], "damage_amount": 5.0, "length": 40.0, "width": 10.0}]}]
	}
	var saved_player: Dictionary = main.player.get_save_data()
	saved_player.ability_runtime.infinite_reload = beam
	_expect_valid({"player": saved_player}, "active beam saved shape")
	main.player.apply_save_data(JSON.parse_string(JSON.stringify(saved_player)))
	var restored: Dictionary = main.player.get_save_data()
	_expect_valid({"player": restored}, "real player beam apply and serialize")
	_check(restored.ability_runtime.infinite_reload.pending_beam_hits.size() == 1, "active beam survives real player restore")
	var bad_beam: Dictionary = beam.duplicate(true)
	bad_beam.cast_snapshot.choices = {}
	_expect_bad({"player": {"ability_runtime": {"infinite_reload": bad_beam}}}, "cast_snapshot.choices")
	bad_beam = beam.duplicate(true)
	bad_beam.cast_snapshot.damage_ratio = []
	_expect_bad({"player": {"ability_runtime": {"infinite_reload": bad_beam}}}, "cast_snapshot.damage_ratio")
	bad_beam = beam.duplicate(true)
	bad_beam.pending_beam_hits[0].shapes[0].axis = [0]
	_expect_bad({"player": {"ability_runtime": {"infinite_reload": bad_beam}}}, "shapes.axis")
	bad_beam = beam.duplicate(true)
	bad_beam.pending_beam_hits[0].remaining = {}
	_expect_bad({"player": {"ability_runtime": {"infinite_reload": bad_beam}}}, "pending_beam_hits.remaining")
	_expect_bad({"player": {"ability_runtime": {"shrapnel_field": {"fields": [{"reprise_scales": {}}]}}}}, "fields[0].reprise_scales")
	_expect_valid({"player": {"ability_runtime": {"infinite_reload": {"cooldown_remaining": 1.0, "pending_beam_hits": "obsolete cast"}}}}, "obsolete beam casts are ignored by existing migration")
	var legacy_role := {"roles": [{"id": "mage", "damage": {}, "color": []}], "role_share_initialized": true}
	_expect_valid({"player": legacy_role}, "template-overwritten stat and short legacy color use existing normalization")
	main.player.apply_save_data(legacy_role)
	_expect_valid({"player": main.player.get_save_data()}, "real legacy role normalization roundtrip")

func _expect_valid(run: Variant, label: String) -> void:
	var problem := VALIDATOR.error(run)
	_check(problem.is_empty(), label + ": " + problem)

func _expect_bad(run: Variant, path: String) -> void:
	var problem := VALIDATOR.error(run)
	_check(not problem.is_empty() and path in problem, "expected rejection at " + path + ", got " + problem)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

class RuntimeRoot extends Node2D:
	var player: Node2D
