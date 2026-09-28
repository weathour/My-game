extends RefCounted

# 飞眼群「群疫」：重复命中只刷新时间，两个负面效果共用计时。
const UNLOCK_TIER := 3
const DURATION := 1.5
const MOVE_SPEED_MULTIPLIER := 0.8
const HEALING_MULTIPLIER := 0.7


static func on_enemy_damage(player, enemy: Node, damage: float) -> void:
	if player == null or player.is_dead or damage <= 0.0:
		return
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return
	if str(enemy.get("archetype_id")) != "swarm":
		return
	var scene: Node = enemy.get_tree().current_scene
	if scene == null:
		return
	var profile: Variant = scene.get("difficulty_profile")
	if profile is not Dictionary or int(profile.get("tier", 0)) < UNLOCK_TIER:
		return
	if player.has_method("_is_status_immune") and player._is_status_immune():
		return
	player.plague_remaining = DURATION


static func get_remaining(player) -> float:
	if player == null:
		return 0.0
	var remaining: Variant = player.get("plague_remaining")
	return maxf(0.0, float(remaining)) if remaining != null else 0.0


static func tick(player, delta: float) -> void:
	if get_remaining(player) > 0.0:
		player.plague_remaining = maxf(0.0, player.plague_remaining - maxf(0.0, delta))


static func get_slow_multiplier(player) -> float:
	return MOVE_SPEED_MULTIPLIER if get_remaining(player) > 0.0 else 1.0


static func get_healing_multiplier(player) -> float:
	return HEALING_MULTIPLIER if get_remaining(player) > 0.0 else 1.0


static func get_buff_slot(player) -> Dictionary:
	var remaining := get_remaining(player)
	if remaining <= 0.0:
		return {}
	return {
		"id": "plague",
		"name": "瘟疫",
		"description": "移动速度降低20%，治疗效果降低30%，持续1.5秒；重复命中刷新持续时间，效果不叠加。",
		"text": "疫",
		"color": Color(0.65, 0.83, 0.28, 1.0),
		"base_color": Color(0.18, 0.25, 0.08, 1.0),
		"remaining": remaining,
		"duration": DURATION,
		"cooldown": false
	}
