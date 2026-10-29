extends RefCounted
## Only this object owns stage gates and the mutually exclusive field choice.
const ENEMY := preload("res://scripts/battle/enemy_runtime.gd")
const CATALOG := preload("res://scripts/content/enemy_catalog.gd")
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

func tick(delta: float, live_count: int, actor: Vector2, living: Array = []) -> Array:
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
			var definition := CATALOG.definition(kind)
			var role: String = str(definition.get("params", {}).get("role", "melee"))
			var count := 0
			for existing in living + spawns:
				if not existing.dead and existing.parent_id == 0 and str(existing.params.get("role", "melee")) == role: count += 1
			if count < int(config.get("role_caps", {}).get(role, 999)): spawns.append(spawn(kind, point))
			wave_cursor += 1
	return spawns

func spawn(kind: String, point: Vector2) -> RefCounted:
	serial += 1
	var enemy := ENEMY.new(serial, kind, point)
	var definition_id := kind
	if kind == "boss": definition_id = str(config.get("boss_definition", ""))
	if kind in ["card_elite", "equipment_elite"]:
		var choices: Array = config.get("field_elites", ["L00", "L00"])
		definition_id = str(choices[0 if kind == "card_elite" else 1])
		enemy.reward_tag = "card" if kind == "card_elite" else "equipment"
	var definition := CATALOG.definition(definition_id)
	if not definition.is_empty(): enemy.configure(definition)
	if kind in ["card_elite", "equipment_elite"]: enemy.kind = kind
	if enemy.rank != "boss": enemy.hp *= float(config.get("enemy_hp", 1.0))
	else: enemy.hp = float(config.get("boss_hp", enemy.hp))
	enemy.max_hp = enemy.hp
	enemy.damage *= float(config.get("enemy_damage", 1.0))
	if definition.is_empty() and kind == "boss": enemy.attack_cycle = config.get("boss_cycle", ["charge", "fan"]).duplicate()
	return enemy

func derivative(descriptor: Dictionary, living: Array) -> RefCounted:
	var enemy := spawn(str(descriptor.definition_id), descriptor.position)
	enemy.parent_id = int(descriptor.get("parent_id", 0))
	enemy.counts_for_threshold = false
	enemy.xp = 0
	enemy.reward_tag = ""
	if descriptor.has("lifetime"): enemy.params.lifetime = float(descriptor.lifetime)
	if descriptor.has("hp_owner_id"):
		for owner in living:
			if owner.id == int(descriptor.hp_owner_id):
				enemy.hp_owner = owner; enemy.hp_owner_id = owner.id
				enemy.hp = owner.hp; enemy.max_hp = owner.max_hp; enemy.damage = owner.damage; enemy.speed = owner.speed
				enemy.cooldown = 2.0
				owner.params.partner_body = enemy.id
				owner.params.turn_body = owner.id
	return enemy

func choose_field(index: int) -> bool:
	if field != -1 or index < 0 or index > 3: return false
	field = index
	return true

func defeated(enemy: RefCounted) -> void:
	if enemy.death_reason not in ["", "killed"]: return
	if enemy.reward_tag == "card" or enemy.kind == "card_elite": card_elite = true
	if enemy.reward_tag == "equipment" or enemy.kind == "equipment_elite": equipment_elite = true
	if enemy.counts_for_threshold: kills += 1
