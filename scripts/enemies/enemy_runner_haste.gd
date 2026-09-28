extends RefCounted

# 疾行：N3 起解锁，移速 +50，持续 4 秒，施放时开始 15 秒冷却。
const UNLOCK_TIER := 3
const SPEED_BONUS := 50.0
const DURATION := 4.0
const COOLDOWN := 15.0


static func is_unlocked(enemy) -> bool:
	if str(enemy.get("archetype_id")) != "runner" or not enemy.is_inside_tree():
		return false
	var scene: Node = enemy.get_tree().current_scene
	if scene == null:
		return false
	var profile: Variant = scene.get("difficulty_profile")
	return profile is Dictionary and int(profile.get("tier", 0)) >= UNLOCK_TIER


static func reset(enemy) -> void:
	enemy.runner_haste_remaining = 0.0
	enemy.runner_haste_cooldown = 0.0


static func tick(enemy, delta: float) -> void:
	if str(enemy.archetype_id) != "runner" or enemy.pooled_inactive or enemy.current_health <= 0.0:
		return
	if not is_unlocked(enemy):
		reset(enemy)
		return
	if delta <= 0.0:
		return
	enemy.runner_haste_remaining = maxf(0.0, enemy.runner_haste_remaining - delta)
	var next_cooldown: float = enemy.runner_haste_cooldown - delta
	if next_cooldown > 0.0:
		enemy.runner_haste_cooldown = next_cooldown
		return
	# Spawn ready; retain time past the cast boundary even with a large time step.
	var elapsed_since_cast: float = fposmod(-next_cooldown, COOLDOWN)
	enemy.runner_haste_cooldown = COOLDOWN - elapsed_since_cast
	enemy.runner_haste_remaining = maxf(0.0, DURATION - elapsed_since_cast)


static func get_speed_bonus(enemy) -> float:
	if str(enemy.get("archetype_id")) != "runner":
		return 0.0
	return SPEED_BONUS if enemy.runner_haste_remaining > 0.0 and is_unlocked(enemy) else 0.0
