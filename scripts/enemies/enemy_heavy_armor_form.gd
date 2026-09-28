extends RefCounted

const BASE_DURATION := 3.0
const BASE_COOLDOWN := 20.0
const BASE_ARMOR_BONUS := 20.0
const BASE_REFLECT_RATIO := 0.05
const N3_DURATION := 5.0
const N3_COOLDOWN := 18.0
const N3_ARMOR_BONUS := 100.0
const N3_REFLECT_RATIO := 0.15
const UNLOCK_TIER := 3


static func is_n3_unlocked(enemy) -> bool:
	if enemy == null or str(enemy.get("archetype_id")) != "brute":
		return false
	# 新生成的敌人在加入场景前设置模板，也要读取本局难度。
	var tree: SceneTree = enemy.get_tree() if enemy.is_inside_tree() else Engine.get_main_loop() as SceneTree
	var scene: Node = tree.current_scene if tree != null else null
	if scene == null:
		return false
	var profile: Variant = scene.get("difficulty_profile")
	return profile is Dictionary and int(profile.get("tier", 0)) >= UNLOCK_TIER


static func get_duration(enemy) -> float:
	return N3_DURATION if is_n3_unlocked(enemy) else BASE_DURATION


static func get_cooldown(enemy) -> float:
	return N3_COOLDOWN if is_n3_unlocked(enemy) else BASE_COOLDOWN


static func get_armor_bonus(enemy) -> float:
	return N3_ARMOR_BONUS if is_n3_unlocked(enemy) else BASE_ARMOR_BONUS


static func get_reflect_ratio(enemy) -> float:
	return N3_REFLECT_RATIO if is_n3_unlocked(enemy) else BASE_REFLECT_RATIO


static func is_active(enemy) -> bool:
	return str(enemy.get("archetype_id")) == "brute" and float(enemy.get("heavy_armor_remaining")) > 0.0


static func tick(enemy, delta: float) -> void:
	if str(enemy.archetype_id) != "brute" or enemy.current_health <= 0.0:
		return
	var was_active := is_active(enemy)
	enemy.heavy_armor_remaining = maxf(0.0, enemy.heavy_armor_remaining - delta)
	enemy.heavy_armor_cooldown = maxf(0.0, enemy.heavy_armor_cooldown - delta)
	if enemy.heavy_armor_cooldown <= 0.0 and enemy.target != null and is_instance_valid(enemy.target):
		enemy.heavy_armor_remaining = get_duration(enemy)
		enemy.heavy_armor_cooldown = get_cooldown(enemy)
	if was_active != is_active(enemy):
		sync_visual(enemy)


static func sync_visual(enemy) -> void:
	var visual := enemy.get_node_or_null("ProfileVisual") as Node
	if visual != null and visual.has_method("set_heavy_armor"):
		visual.set_heavy_armor(is_active(enemy))


static func reflect_damage(enemy, health_lost: float) -> void:
	if not is_active(enemy) or health_lost <= 0.0 or bool(enemy.get_meta("heavy_armor_reflecting", false)):
		return
	var player = enemy.target
	if player == null or not is_instance_valid(player) or not player.has_method("take_damage"):
		return
	enemy.set_meta("heavy_armor_reflecting", true)
	player.take_damage(health_lost * get_reflect_ratio(enemy))
	enemy.set_meta("heavy_armor_reflecting", false)
