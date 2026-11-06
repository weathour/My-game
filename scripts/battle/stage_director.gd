extends RefCounted
## Only this object owns stage gates and the mutually exclusive field choice.
const ENEMY := preload("res://scripts/battle/enemy_runtime.gd")
const CATALOG := preload("res://scripts/content/enemy_catalog.gd")
const STAGES := preload("res://scripts/content/stage_catalog.gd")
const SPACE := preload("res://scripts/battle/battle_space.gd")
var configuration_error := ""
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
	configuration_error = "; ".join(STAGES.runtime_errors(config))

func tick(delta: float, live_count: int, actor: Vector2, living: Array = [], actor_velocity: Vector2 = Vector2.ZERO) -> Array:
	if not configuration_error.is_empty(): return []
	elapsed += delta
	var spawns: Array = []
	if not boss_spawned and (elapsed >= config.boss_time or (elapsed>=float(config.get("boss_min_time",0.0)) and kills >= config.boss_kills)):
		boss_spawned = true
		var boss := spawn("boss", SPACE.challenge_position(actor))
		if boss != null: spawns.append(boss)
	if boss_spawned: return spawns
	spawn_remaining -= delta
	if spawn_remaining <= 0:
		var wave: Dictionary = config.waves[0]
		for candidate in config.waves:
			if elapsed >= candidate.at: wave = candidate
		spawn_remaining += float(wave.get("interval", config.spawn_interval))
		var cycle: Array = wave.cycle
		var role_counts: Dictionary={}
		for existing in living:
			if not existing.dead and existing.parent_id==0:
				var role:=str(existing.params.get("role","melee"))
				role_counts[role]=int(role_counts.get(role,0))+1
		var base_angle:=rng.randf_range(-PI,PI)
		if actor_velocity.length_squared()>1: base_angle=actor_velocity.angle()
		var formation:=str(wave.get("formation","surround"))
		var count:=mini(int(wave.count),maxi(0,config.enemy_cap-live_count))
		for i in count:
			var point: Vector2
			if not wave.has("formation"): point=SPACE.reinforcement(actor,rng)
			else:
				var angle:=base_angle
				if formation=="surround": angle+=TAU*i/maxi(1,count)+rng.randf_range(-.15,.15)
				elif formation=="flank": angle+=(-1 if i%2==0 else 1)*PI*.5+rng.randf_range(-.25,.25)
				else: angle+=(float(i)/maxi(1,count-1)-.5)*float(wave.get("formation_spread",1.1))
				var center: Vector2=actor+actor_velocity*float(wave.get("intercept_lead",1.0)) if formation=="intercept" else actor
				var radius:=float(wave.get("spawn_radius",620.0))
				point=SPACE.clamp_point(center+Vector2(cos(angle)*radius,sin(angle)*radius*.70),Vector2(45,45))
				if point.distance_to(actor)<260: point=SPACE.reinforcement(actor,rng)
			var kind:=str(cycle[wave_cursor%cycle.size()])
			var definition:=CATALOG.definition(kind)
			var role:=str(definition.get("params",{}).get("role","melee"))
			if int(role_counts.get(role,0))<int(config.get("role_caps",{}).get(role,999)):
				var enemy:=spawn(kind,point)
				if enemy==null: return spawns
				spawns.append(enemy);role_counts[role]=int(role_counts.get(role,0))+1
			wave_cursor+=1
	return spawns

func spawn(kind: String, point: Vector2) -> RefCounted:
	if not configuration_error.is_empty(): return null
	var definition_id := kind
	if kind == "boss": definition_id = str(config.boss_definition)
	if kind in ["card_elite", "equipment_elite"]:
		var slot := 0 if kind == "card_elite" else 1
		if not bool(config.get("fields_enabled", true)) or config.field_elites.size() <= slot:
			configuration_error = "No field elite definition for " + kind
			return null
		definition_id = str(config.field_elites[slot])
	var definition := CATALOG.definition(definition_id)
	var errors := CATALOG.runtime_errors(definition)
	if not errors.is_empty():
		configuration_error = "Enemy %s: %s" % [definition_id, "; ".join(errors)]
		return null
	serial += 1
	var enemy := ENEMY.new(serial, definition, point)
	if kind in ["card_elite", "equipment_elite"]:
		enemy.kind = kind
		enemy.reward_tag = "card" if kind == "card_elite" else "equipment"
	if enemy.rank != "boss": enemy.hp *= float(config.enemy_hp)
	else: enemy.hp = float(config.boss_hp)
	enemy.max_hp = enemy.hp
	if enemy.rank == "boss": enemy.configure_form_budget(float(config.boss_hp))
	enemy.damage *= float(config.enemy_damage)
	return enemy

func derivative(descriptor: Dictionary, living: Array) -> RefCounted:
	var enemy := spawn(str(descriptor.definition_id), descriptor.position)
	if enemy == null: return null
	if descriptor.has("visual_id"): enemy.visual_id = str(descriptor.visual_id)
	if descriptor.has("body_height"): enemy.body_height = float(descriptor.body_height)
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
	if not bool(config.get("fields_enabled", true)): return false
	if field != -1 or index < 0 or index > 3: return false
	field = index
	return true

func defeated(enemy: RefCounted) -> void:
	if enemy.death_reason not in ["", "killed"]: return
	if enemy.reward_tag == "card" or enemy.kind == "card_elite": card_elite = true
	if enemy.reward_tag == "equipment" or enemy.kind == "equipment_elite": equipment_elite = true
	if enemy.counts_for_threshold: kills += 1
