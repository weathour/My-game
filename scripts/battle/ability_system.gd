extends RefCounted
const A := preload("res://scripts/battle/ability_definition.gd")
## The sole MP/cooldown gate. Cost overrides are calculated before any mutation.
static func activate(ability: Resource, source: RefCounted, origin: Vector2, target: RefCounted, facing: Vector2, equipment: Dictionary, direct: bool, sequence: int, cost_override: float = -1.0, manual: bool = false) -> Dictionary:
	if source.dead: return {"error":"人物已阵亡"}
	if source.level < ability.unlock_level: return {"error":"Lv.%d 解锁" % ability.unlock_level}
	if float(source.cooldowns.get(ability.id, 0)) > 0: return {"error":"技能尚未冷却"}
	var cost: float = ability.mana_cost if cost_override < 0 else cost_override
	if source.mp + 0.00001 < cost: return {"error":"魔法不足"}
	if ability.kind in [A.Kind.SWEEP, A.Kind.THRUST, A.Kind.PROJECTILE] and target == null: return {"error":"范围内没有目标"}
	source.mp = maxf(0, source.mp - cost)
	var interval: float = ability.cooldown
	if str(ability.id).ends_with("_basic"): interval = 1.0 / source.stats.speed
	source.cooldowns[str(ability.id)] = interval
	var direction: Vector2 = facing if target == null else (target.position - origin).normalized()
	if direction.length_squared() < 0.1: direction = Vector2.RIGHT
	var parameters: Dictionary = ability.params.duplicate(true)
	parameters.make_read_only()
	var context := {"source":source.id, "ability":str(ability.id), "cast":sequence, "damage":source.stats.attack * ability.damage_scale,
		"attack":float(source.stats.attack), "enchant":equipment.get("accessory", "") if direct else "", "direct":direct,
		"damage_type":ability.damage_type, "slow":ability.slow, "duration":ability.duration, "paid":cost if manual else 0.0,
		"manual":manual, "basic":str(ability.id).ends_with("_basic"), "secondary":false, "mechanic":ability.mechanic, "params":parameters}
	context.make_read_only()
	return {"ability":ability, "context":context, "origin":origin, "direction":direction, "reach":ability.reach}
