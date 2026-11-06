extends SceneTree
const CAMERA := preload("res://scripts/ui/chronicle/boss_camera.gd")
const HURTBOX := preload("res://scripts/battle/player_hurtbox.gd")

class CountingCamera extends "res://scripts/ui/chronicle/boss_camera.gd":
	var searches := 0
	var queries := 0
	func _cached_escape(player: Vector2, dangers: Array[Dictionary], active: Array[Dictionary], move_speed: float, frame_hint: Vector2) -> Dictionary:
		queries += 1
		return super._cached_escape(player, dangers, active, move_speed, frame_hint)
	func _escape(player: Vector2, dangers: Array[Dictionary], active: Array[Dictionary], move_speed: float, frame_hint: Vector2) -> Dictionary:
		searches += 1
		return super._escape(player, dangers, active, move_speed, frame_hint)

class FixtureBattle extends RefCounted:
	var position := Vector2(1600, 900)
	var paused := false
	var enemies: Array = []
	var telegraphs: Array[Dictionary] = []
	var hazards: Array[Dictionary] = []
	var enemy_slow := 0.0
	var actor := {"shield":0.0, "haste":0.0, "stats":{"move":240.0}}
	func current() -> Dictionary: return actor

class FixtureBoss extends RefCounted:
	var rank := "boss"
	var dead := false
	var targetable := true
	var hp_owner_id := 1
	var id := 1
	var position := Vector2(1820, 770)
	var radius := 42.0
	var body_height := 128.0
	var current_action: Dictionary = {}
	var windup := 0.0

var checks := 0
var failures := 0
var updates := 0
var camera := CountingCamera.new()
var oracle := CAMERA.new()
var battle := FixtureBattle.new()
var boss := FixtureBoss.new()

func _init() -> void: call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func update(expected_searches: int, label: String, delta: float = 0.0, dimensions: Vector2 = Vector2(1280,720), top: float = 82.0) -> void:
	updates += 1
	camera.update(battle, dimensions, delta, false, top)
	oracle.update(battle, dimensions, delta, false, top)
	expect(camera.searches == expected_searches, label + " search count")
	# Force the reference to use the unchanged production algorithm on every
	# call. Its full projection must match, including routes, shake and smoothing.
	expect(camera.snapshot() == oracle.snapshot(), label + " matches uncached framing")
	oracle._escape_inputs_valid = false

func run() -> void:
	battle.enemies.append(boss)
	var danger := {"owner_id":boss.id, "shape":"disc", "origin":HURTBOX.center(battle.position), "radius":85.0, "phase":"tell", "remaining":1.1, "damage":20.0}
	battle.telegraphs.append(danger)
	update(1, "initial route", .016)
	var first_clock := camera.clock
	update(1, "same physics refresh")
	expect(camera.clock == first_clock, "zero-delta refresh does not advance clock")
	update(1, "unchanged input next clock", .016)
	expect(camera.clock > first_clock, "route reuse does not freeze presentation clock")
	var second := danger.duplicate(true)
	second.radius = 92.0
	battle.telegraphs.append(second)
	update(2, "new same-clock danger")
	danger.origin += Vector2(2, 0)
	update(3, "in-place danger geometry")
	danger.remaining = .8
	update(4, "in-place tell deadline")
	var hazard := {"shape":"disc", "origin":battle.position + Vector2(380, 0), "radius":18.0, "phase":"active", "damage":10.0}
	battle.hazards.append(hazard)
	update(5, "active hazard outside relevant envelope")
	hazard.radius = 24.0
	update(6, "in-place active path blocker")
	battle.actor.stats.move = 260.0
	update(7, "movement speed")
	battle.enemy_slow = .2
	update(8, "slow changes true speed")
	battle.actor.haste = 1.0
	update(9, "haste changes true speed")
	battle.position += Vector2(3, 1)
	update(10, "player movement")
	boss.position += Vector2(18, 0)
	update(11, "boss frame hint")
	var before_pose := camera.requested_bounds
	var pose := Rect2(boss.position + Vector2(-140,-280), Vector2(280,300))
	camera.visual_bounds[boss.id] = pose
	oracle.visual_bounds[boss.id] = pose
	update(11, "same-clock authored pose")
	expect(camera.requested_bounds != before_pose, "pose still changes outer framing on cache hit")
	var old_safe := camera.safe_screen
	update(11, "HUD safe inset", 0, Vector2(1280,720), 110)
	expect(camera.safe_screen != old_safe and camera.safe_screen.position.y == 110, "HUD inset immediately reframes")
	var obstacle := Rect2(camera.base_origin + battle.position * camera.scale - Vector2(25,60), Vector2(50,90))
	camera.hud_obstacles.append(obstacle)
	oracle.hud_obstacles.append(obstacle)
	update(11, "HUD obstacle", 0, Vector2(1280,720), 110)
	update(11, "window resize", 0, Vector2(960,540), 72)
	expect(camera.framed_dimensions == Vector2(960,540), "window projection updated on cache hit")
	camera.consume([{"kind":"boss_phase"}])
	oracle.consume([{"kind":"boss_phase"}])
	update(11, "shake impulse advances", .025, Vector2(960,540), 72)
	expect(camera.trauma > 0 and camera.shake.length() > 0, "cache hit retains shake computation")
	camera.reset()
	oracle.reset()
	update(12, "reset invalidates cached route")
	# A failed route is also a valid cache result; it must become invalidated as
	# soon as the same dictionary's escape deadline changes.
	battle.telegraphs.clear()
	battle.hazards.clear()
	danger.origin = HURTBOX.center(battle.position)
	danger.radius = 500.0
	danger.remaining = .01
	battle.telegraphs.append(danger)
	update(13, "unreachable route")
	expect(not camera.escape_valid and camera.escape_needed, "no fabricated route")
	update(13, "unreachable route reused")
	danger.radius = 70.0
	danger.remaining = 1.1
	update(14, "same dictionary becomes escapable")
	expect(camera.escape_valid, "changed geometry restores valid route")
	battle.telegraphs.clear()
	update(14, "no dangers clears public route")
	expect(camera.safe_route.is_empty() and not camera.escape_needed, "no stale route remains after dangers clear")
	print("CAMERA_CACHE_EVIDENCE searches=",camera.searches," updates=",updates," queries=",camera.queries," cache_hits=",camera.queries-camera.searches)
	benchmark_search()
	print("CHRONICLE_BOSS_CAMERA_CACHE_SMOKE ", "PASS" if failures == 0 else "FAIL", " checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)

func benchmark_search() -> void:
	var player := Vector2(1600,900)
	var dangers: Array[Dictionary] = [{"shape":"disc", "origin":HURTBOX.center(player), "radius":85.0, "remaining":1.1}]
	var active: Array[Dictionary] = []
	for index in 48:
		active.append({"shape":"disc", "origin":Vector2(2600 + index,1300), "radius":12.0})
	var hint := player + Vector2.UP * 100
	var measured := CountingCamera.new()
	var reference: Dictionary = oracle._escape(player, dangers, active, 240, hint)
	expect(measured._cached_escape(player,dangers,active,240,hint) == reference, "dense active route equals uncached result")
	var started := Time.get_ticks_usec()
	for iteration in 30: oracle._escape(player,dangers,active,240,hint)
	var direct_us := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	for iteration in 30: measured._cached_escape(player,dangers,active,240,hint)
	var cached_us := Time.get_ticks_usec() - started
	expect(measured.searches == 1 and measured.queries == 31, "thirty unchanged dense queries perform no new search")
	print("CAMERA_CACHE_BENCHMARK samples=30 active=48 direct_us=",direct_us," cached_us=",cached_us)
