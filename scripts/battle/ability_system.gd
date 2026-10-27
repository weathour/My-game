extends RefCounted
const A := preload("res://scripts/battle/ability_definition.gd")
## Activation is the single resource/cooldown gate for manual, automatic and support skills.
static func activate(ability: Resource, source: RefCounted, origin: Vector2, target: RefCounted, facing: Vector2, equipment: Dictionary, direct: bool, sequence: int) -> Dictionary:
	if source.dead: return {"error":"人物已阵亡"}
	if source.level < ability.unlock_level: return {"error":"Lv.%d 解锁" % ability.unlock_level}
	if float(source.cooldowns.get(ability.id, 0)) > 0: return {"error":"技能尚未冷却"}
	if source.mp < ability.mana_cost: return {"error":"魔法不足"}
	if ability.kind in [A.Kind.SWEEP, A.Kind.THRUST, A.Kind.PROJECTILE] and target == null: return {"error":"范围内没有目标"}
	source.mp -= ability.mana_cost
	var interval: float = ability.cooldown
	if str(ability.id).ends_with("_basic"): interval = 1.0 / source.stats.speed
	source.cooldowns[str(ability.id)] = interval
	var direction: Vector2 = facing if target == null else (target.position - origin).normalized()
	if direction.length_squared() < 0.1: direction = Vector2.RIGHT
	var context := {"source":source.id, "ability":str(ability.id), "cast":sequence, "damage":source.stats.attack * ability.damage_scale,
		"enchant":equipment.get("accessory", "") if direct else "", "direct":direct, "damage_type":ability.damage_type, "slow":ability.slow, "duration":ability.duration}
	# Per-cast values never read the active actor again after launch.
	context.make_read_only()
	return {"ability":ability, "context":context, "origin":origin, "direction":direction}
