extends RefCounted
## Mutable state belongs to an attempt; scene nodes only present it.
var id: String
var level := 1
var experience_units := 0
## Sixth-points exactly represent integer XP split across one, two or three actors.
var xp: float:
	get: return experience_units / 6.0
	set(value): experience_units = int(round(value * 6.0))
var hp := 0.0
var mp := 0.0
var dead := false
var stats: Dictionary
var cooldowns: Dictionary = {}
var shield := 0.0
var haste := 0.0
var hurt_lock := 0.0

func _init(key: String, record: Dictionary, attributes: Dictionary) -> void:
	id = key
	level = int(record.level)
	xp = float(record.xp)
	stats = attributes.duplicate(true)
	hp = clampf(float(record.hp), 0, stats.hp)
	mp = clampf(float(record.mp), 0, stats.mp)
	dead = record.dead
	cooldowns = record.cooldowns.duplicate(true)

func tick(delta: float) -> void:
	# Death stops capabilities, but assigned characters retain their clock.
	for key in cooldowns: cooldowns[key] = maxf(0, cooldowns[key] - delta)
	haste = maxf(0, haste - delta)
	hurt_lock = maxf(0, hurt_lock - delta)
	if not dead: mp = minf(stats.mp, mp + stats.regen * delta)

func snapshot() -> Dictionary:
	return {"level":level, "xp":xp, "hp":hp, "mp":mp, "dead":dead, "cooldowns":cooldowns.duplicate(true)}
