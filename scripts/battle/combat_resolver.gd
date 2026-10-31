extends RefCounted
## No character-specific branches. Reactions never recursively call this resolver.
static func hit_enemy(enemy: RefCounted, context: Dictionary) -> bool:
	if enemy.dead or not enemy.targetable: return false
	enemy = enemy.damage_owner()
	if enemy.dead: return false
	var amount: float = context.damage
	if context.get("enchant", "") == "ember_seal": amount *= 1.15
	# A settled curse is an existing damage budget, not new enchanted direct damage.
	var settled := float(context.get("curse_settled", 0.0))
	var vulnerability := 1.0 + float(context.get("vulnerability", 0.0))
	amount *= vulnerability
	# Only fresh direct impacts are directional. Curse and field pools remain intact.
	if bool(context.get("direct", false)) and enemy.behavior_id == "E04" and enemy.guard_active and enemy.state != "recovery":
		var origin: Vector2 = context.get("impact_origin", context.get("origin", enemy.position - enemy.aim * 100))
		var toward: Vector2 = (origin - enemy.position).normalized()
		if toward.dot(enemy.aim) >= cos(float(enemy.params.get("shield_arc", 1.8)) * 0.5): amount *= 1 - float(enemy.params.get("shield_reduction", 0.4))
	amount += settled * vulnerability
	if enemy.protection_remaining > 0: amount *= 1 - float(enemy.params.get("link_reduction", 0.25))
	enemy.receive_damage(amount)
	enemy.flash = 0.12
	var slow: float = context.slow
	var duration: float = context.duration
	if context.get("enchant", "") == "frost_jade": slow = maxf(slow, 0.35); duration = maxf(duration, 1.5)
	if duration > 0:
		enemy.slow = maxf(enemy.slow, slow)
		enemy.slow_time = maxf(enemy.slow_time, duration)
	return enemy.dead

static func hit_character(character: RefCounted, raw: float, equipment: Dictionary, result: Dictionary = {}) -> float:
	if character.dead or character.hurt_lock > 0: return 0
	var previous_hp: float = character.hp
	var damage: float = raw * 100.0 / (100.0 + character.stats.armor * 3.0)
	var blocked := minf(character.shield, damage)
	character.shield -= blocked
	damage -= blocked
	character.hp = maxf(0, character.hp - damage)
	# Capture before armor can replenish a shield. Presentation must not infer
	# absorption from the final shield difference or mistake overkill for HP loss.
	result.merge({"processed":true, "health_loss":previous_hp - character.hp, "shield_absorbed":blocked}, true)
	# This is hit protection, not switch invulnerability. It stays on this person.
	character.hurt_lock = 0.3
	character.dead = character.hp <= 0
	if not character.dead and damage > 0:
		if equipment.get("armor") == "cloth_armor": character.haste = 1.5
		if equipment.get("armor") == "iron_armor" and character.cooldowns.get("armor_guard", 0.0) <= 0:
			character.shield = minf(character.stats.hp * 0.35, character.shield + 6)
			character.cooldowns["armor_guard"] = 2.0
	return damage
