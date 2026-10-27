extends RefCounted
## Only this object owns stage gates and the mutually exclusive field choice.
const ENEMY := preload("res://scripts/battle/enemy_runtime.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
var config: Dictionary
var elapsed := 0.0
var kills := 0
var boss_spawned := false
var field := -1
var card_elite := false
var equipment_elite := false
var spawn_remaining := 0.6
var serial := 0
var wave_cursor := 0
var rng := RandomNumberGenerator.new()
const FIELD_POSITIONS := SPACE.FIELD_POSITIONS

func _init(value: Dictionary, seed_value: int) -> void:
	config = value.duplicate(true)
	rng.seed = seed_value

func tick(delta: float, live_count: int, actor: Vector2) -> Array:
	elapsed += delta
	var spawns: Array = []
	if not boss_spawned and (elapsed >= config.boss_time or kills >= config.boss_kills):
		boss_spawned = true
		var boss := spawn("boss", SPACE.challenge_position(actor))
		boss.hp = config.boss_hp
		boss.max_hp = boss.hp
		spawns.append(boss)
	if boss_spawned: return spawns
	spawn_remaining -= delta
	if spawn_remaining <= 0:
		var wave: Dictionary = {}
		for candidate in config.get("waves", []):
			if elapsed >= candidate.at: wave = candidate
		spawn_remaining += float(wave.get("interval", config.spawn_interval))
		var cycle: Array = wave.get("cycle", [])
		for i in mini(int(wave.get("count", 1)), maxi(0, config.enemy_cap - live_count)):
			var point := SPACE.reinforcement(actor, rng)
			var kind: String = ("ranged" if serial % 4 == 3 else "melee") if cycle.is_empty() else str(cycle[wave_cursor % cycle.size()])
			spawns.append(spawn(kind, point))
			wave_cursor += 1
	return spawns

func spawn(kind: String, point: Vector2) -> RefCounted:
	serial += 1
	var enemy := ENEMY.new(serial, kind, point)
	enemy.hp *= float(config.get("enemy_hp", 1.0))
	enemy.max_hp = enemy.hp
	enemy.damage *= float(config.get("enemy_damage", 1.0))
	if kind == "boss": enemy.attack_cycle = config.get("boss_cycle", ["charge", "fan"]).duplicate()
	return enemy

func choose_field(index: int) -> bool:
	if field != -1 or index < 0 or index > 3: return false
	field = index
	return true

func defeated(enemy: RefCounted) -> void:
	if enemy.kind == "card_elite": card_elite = true
	if enemy.kind == "equipment_elite": equipment_elite = true
	if enemy.kind != "boss": kills += 1
