extends RefCounted

const STATUS_VISUAL_REFRESH_EPSILON := 0.08
const NORMAL_STATUS_VISUAL_REFRESH_EPSILON := 0.35

static func tick_timers(enemy, delta: float) -> void:
	if enemy.slow_timer > 0.0:
		enemy.slow_timer = max(0.0, enemy.slow_timer - delta)
		if enemy.slow_timer == 0.0:
			enemy.slow_multiplier = 1.0

	if enemy.vulnerability_timer > 0.0:
		enemy.vulnerability_timer = max(0.0, enemy.vulnerability_timer - delta)
		if enemy.vulnerability_timer == 0.0:
			enemy.vulnerability_bonus = 0.0

	if enemy.bleed_timer > 0.0:
		enemy.bleed_timer = max(0.0, enemy.bleed_timer - delta)
		if enemy.bleed_timer == 0.0:
			enemy.bleed_damage_per_second = 0.0

static func tick_bleed(enemy, delta: float) -> void:
	if enemy.bleed_timer <= 0.0 or enemy.bleed_damage_per_second <= 0.0:
		return

	var bleed_damage: float = enemy.bleed_damage_per_second * delta
	if bleed_damage > 0.0:
		if enemy.has_method("take_batched_damage"):
			enemy.take_batched_damage(bleed_damage)
		else:
			enemy.take_damage(bleed_damage)

static func apply_slow(enemy, multiplier: float, duration: float) -> void:
	var next_multiplier: float = min(enemy.slow_multiplier, clamp(multiplier, 0.2, 1.0))
	var next_timer: float = max(enemy.slow_timer, duration)
	var should_refresh_visual: bool = next_multiplier < enemy.slow_multiplier or next_timer > enemy.slow_timer + _get_status_visual_refresh_epsilon(enemy)
	enemy.slow_multiplier = next_multiplier
	enemy.slow_timer = next_timer
	if should_refresh_visual:
		if not _should_suppress_normal_status_visuals(enemy):
			enemy._ensure_status_visuals()
		enemy._spawn_status_burst(Color(0.56, 0.92, 1.0, 0.28), 22.0)

static func apply_vulnerability(enemy, bonus: float, duration: float) -> void:
	var next_bonus: float = max(enemy.vulnerability_bonus, bonus)
	var next_timer: float = max(enemy.vulnerability_timer, duration)
	var should_refresh_visual: bool = next_bonus > enemy.vulnerability_bonus or next_timer > enemy.vulnerability_timer + _get_status_visual_refresh_epsilon(enemy)
	enemy.vulnerability_bonus = next_bonus
	enemy.vulnerability_timer = next_timer
	if should_refresh_visual:
		if not _should_suppress_normal_status_visuals(enemy):
			enemy._ensure_status_visuals()
		enemy._spawn_status_burst(Color(1.0, 0.46, 0.36, 0.24), 18.0)

static func apply_bleed(enemy, damage_per_second: float, duration: float) -> void:
	enemy.bleed_damage_per_second = max(enemy.bleed_damage_per_second, damage_per_second)
	enemy.bleed_timer = max(enemy.bleed_timer, duration)

static func _get_status_visual_refresh_epsilon(enemy) -> float:
	if enemy == null:
		return STATUS_VISUAL_REFRESH_EPSILON
	if str(enemy.get("enemy_kind")) == "normal" and str(enemy.get("secondary_behavior_id")) == "":
		return NORMAL_STATUS_VISUAL_REFRESH_EPSILON
	return STATUS_VISUAL_REFRESH_EPSILON

static func _should_suppress_normal_status_visuals(enemy) -> bool:
	if enemy == null:
		return false
	if str(enemy.get("enemy_kind")) != "normal" or str(enemy.get("secondary_behavior_id")) != "":
		return false
	if enemy.get("status_root") != null:
		return false
	return enemy.has_method("_is_scene_under_enemy_pressure") and bool(enemy._is_scene_under_enemy_pressure())
