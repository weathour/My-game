extends RefCounted
## No character-specific branches. Reactions never recursively call this resolver.
static func hit_enemy(enemy: RefCounted, context: Dictionary) -> bool:
	if enemy.dead: return false
	var amount: float = context.damage
	if context.enchant == "ember_seal": amount *= 1.15
	enemy.hp = maxf(0, enemy.hp - amount)
	enemy.flash = 0.12
	var slow: float = context.slow
	var duration: float = context.duration
	if context.enchant == "frost_jade": slow = maxf(slow, 0.35); duration = maxf(duration, 1.5)
	if duration > 0:
		enemy.slow = maxf(enemy.slow, slow)
		enemy.slow_time = maxf(enemy.slow_time, duration)
	enemy.dead = enemy.hp <= 0
	return enemy.dead

static func hit_character(character: RefCounted, raw: float, equipment: Dictionary) -> float:
	if character.dead or character.hurt_lock > 0: return 0
	var damage: float = raw * 100.0 / (100.0 + character.stats.armor * 3.0)
	var blocked := minf(character.shield, damage)
	character.shield -= blocked
	damage -= blocked
	character.hp = maxf(0, character.hp - damage)
	# This is hit protection, not switch invulnerability. It stays on this person.
	character.hurt_lock = 0.3
	character.dead = character.hp <= 0
	if not character.dead and damage > 0:
		if equipment.get("armor") == "cloth_armor": character.haste = 1.5
		if equipment.get("armor") == "iron_armor" and character.cooldowns.get("armor_guard", 0.0) <= 0:
			character.shield += 6
			character.cooldowns["armor_guard"] = 2.0
	return damage
