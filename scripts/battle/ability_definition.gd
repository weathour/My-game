extends Resource
## Shared content, never stores cooldowns or a current target.
enum Kind { SWEEP, THRUST, PROJECTILE, NOVA, HEAL, MANA, WARD }
enum DamageType { PHYSICAL, MAGIC }
@export var id: StringName
@export var title: String
@export var kind: Kind = Kind.SWEEP
@export var damage_type: DamageType = DamageType.PHYSICAL
@export var damage_scale := 1.0
@export var reach := 110.0
@export var cooldown := 1.0
@export var mana_cost := 0.0
@export var unlock_level := 1
@export var slow := 0.0
@export var duration := 0.0
@export var mechanic: String = ""
@export var params: Dictionary = {}
@export var target_scope: String = "active"

static func make(key: String, label: String, type: Kind, power: float, distance: float, interval: float, cost: float = 0.0, level: int = 1) -> Resource:
	var value := load("res://scripts/battle/ability_definition.gd").new() as Resource
	value.id = StringName(key)
	value.title = label
	value.kind = type
	value.damage_scale = power
	value.reach = distance
	value.cooldown = interval
	value.mana_cost = cost
	value.unlock_level = level
	return value
