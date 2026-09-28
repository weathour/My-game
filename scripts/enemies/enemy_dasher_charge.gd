extends RefCounted

const SPEED := 250.0
const MAX_DISTANCE := 500.0
const EXTRA_DAMAGE_RATIO := 1.0
const ENHANCED_UNLOCK_TIER := 3
const ENHANCED_SPEED := 300.0
const ENHANCED_WINDUP := 0.3


static func is_enhanced(enemy) -> bool:
	if enemy == null or not uses_fixed_charge(enemy):
		return false
	var tree: SceneTree = enemy.get_tree() if enemy.is_inside_tree() else Engine.get_main_loop() as SceneTree
	var scene: Node = tree.current_scene if tree != null else null
	if scene == null:
		return false
	var profile: Variant = scene.get("difficulty_profile")
	return profile is Dictionary and int(profile.get("tier", 0)) >= ENHANCED_UNLOCK_TIER


static func get_speed(enemy) -> float:
	return ENHANCED_SPEED if is_enhanced(enemy) else SPEED


static func get_windup_duration(enemy) -> float:
	return ENHANCED_WINDUP if is_enhanced(enemy) else float(enemy.dash_windup_duration)


static func is_active(enemy) -> bool:
	return uses_fixed_charge(enemy) and float(enemy.get("dash_remaining")) > 0.0


static func uses_fixed_charge(enemy) -> bool:
	return str(enemy.get("archetype_id")) in ["dasher", "elite_ram_trail"]


static func grant_charge_haste(enemy) -> void:
	if str(enemy.archetype_id) != "elite_ram_trail" or not enemy.is_inside_tree():
		return
	for other in enemy.get_tree().get_nodes_in_group("enemies"):
		if str(other.get("archetype_id")) != "dasher":
			continue
		if float(other.get("current_health")) <= 0.0 or bool(other.get("pooled_inactive")):
			continue
		other.elite_charge_haste_remaining = 3.0


static func move(enemy, delta: float) -> void:
	# Fixed world speed: do not apply the ordinary movement speed scale again.
	var step_time: float = minf(maxf(0.0, delta), enemy.dash_remaining)
	var distance: float = minf(get_speed(enemy) * step_time, enemy.dash_distance_remaining)
	enemy.global_position += enemy.dash_direction.normalized() * distance
	enemy.dash_distance_remaining = maxf(0.0, enemy.dash_distance_remaining - distance)
	enemy.dash_remaining = maxf(0.0, enemy.dash_remaining - step_time)
	if enemy.dash_distance_remaining <= 0.001 or enemy.dash_remaining <= 0.001:
		enemy.dash_remaining = 0.0
		enemy.dash_distance_remaining = 0.0
		enemy.dash_timer = enemy.dash_interval
