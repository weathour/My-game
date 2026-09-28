extends RefCounted

const DAMAGE_RATIO := 1.5
const COOLDOWN := 1.0
const MUSHROOM_SWARM := preload("res://scripts/enemies/enemy_mushroom_swarm.gd")


static func tick(enemy, delta: float) -> void:
	enemy.stalwart_body_cooldown = max(0.0, enemy.stalwart_body_cooldown - delta)


static func try_trigger(enemy) -> float:
	if enemy.stalwart_body_cooldown > 0.0 or enemy.current_health <= 0.0 or enemy.pooled_inactive:
		return 0.0
	if enemy.rebirth_timer > 0.0 or enemy.boss_phase_transition_target > 0 or enemy.boss_phase_three_intro_remaining > 0.0:
		return 0.0
	var damage_ratio: float = MUSHROOM_SWARM.get_stalwart_damage_ratio(enemy, DAMAGE_RATIO)
	var damage: float = max(0.0, enemy.attack) * damage_ratio
	if preload("res://scripts/enemies/enemy_dasher_charge.gd").is_active(enemy):
		damage += max(0.0, enemy.attack) * preload("res://scripts/enemies/enemy_dasher_charge.gd").EXTRA_DAMAGE_RATIO
	elif str(enemy.get("behavior_id")) == "skulltomb" and float(enemy.get("dash_remaining")) > 0.0:
		damage += max(0.0, enemy.attack) * 1.5
	if damage > 0.0:
		enemy.stalwart_body_cooldown = COOLDOWN
	return damage
