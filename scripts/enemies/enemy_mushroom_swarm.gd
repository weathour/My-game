extends RefCounted

const ARCHETYPE_ID := "chaser"
const UNLOCKED_TIER := 3
const MINIMUM_COUNT_EXCLUSIVE := 8
const ARMOR_BONUS := 5.0
const STALWART_DAMAGE_RATIO := 2.0

static var _cached_scene_id: int = -1
static var _cached_frame: int = -1
static var _cached_chaser_count: int = 0


static func invalidate_cache() -> void:
	_cached_scene_id = -1
	_cached_frame = -1
	_cached_chaser_count = 0


static func is_active(enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if str(enemy.get("archetype_id")) != ARCHETYPE_ID:
		return false
	if not _is_unlocked(enemy):
		return false
	return get_active_chaser_count(enemy) > MINIMUM_COUNT_EXCLUSIVE


static func get_armor_bonus(enemy) -> float:
	return ARMOR_BONUS if is_active(enemy) else 0.0


static func get_stalwart_damage_ratio(enemy, base_ratio: float) -> float:
	return STALWART_DAMAGE_RATIO if is_active(enemy) else base_ratio


static func get_active_chaser_count(enemy) -> int:
	var scene := _get_current_scene(enemy)
	if scene == null:
		return 0
	var scene_id: int = scene.get_instance_id()
	var frame: int = Engine.get_physics_frames()
	if scene_id == _cached_scene_id and frame == _cached_frame:
		return _cached_chaser_count

	_cached_scene_id = scene_id
	_cached_frame = frame
	_cached_chaser_count = 0
	var enemies: Array = scene.get_runtime_enemies() if scene.has_method("get_runtime_enemies") else scene.get_tree().get_nodes_in_group("enemies")
	for other in enemies:
		if other == null or not is_instance_valid(other) or bool(other.get("pooled_inactive")):
			continue
		if str(other.get("archetype_id")) != ARCHETYPE_ID:
			continue
		var health: Variant = other.get("current_health")
		if health != null and float(health) <= 0.0:
			continue
		_cached_chaser_count += 1
	return _cached_chaser_count


static func _is_unlocked(enemy) -> bool:
	var scene := _get_current_scene(enemy)
	if scene == null:
		return false
	var profile: Variant = scene.get("difficulty_profile")
	if profile is Dictionary and int((profile as Dictionary).get("tier", 0)) >= UNLOCKED_TIER:
		return true
	var endless_tier_value: Variant = scene.get("endless_tier")
	if endless_tier_value != null and int(endless_tier_value) >= UNLOCKED_TIER:
		return true
	var difficulty_id_value: Variant = scene.get("difficulty_id")
	var difficulty_id := str(difficulty_id_value).to_lower() if difficulty_id_value != null else ""
	if difficulty_id.begins_with("n"):
		return int(difficulty_id.trim_prefix("n")) >= UNLOCKED_TIER
	return false


static func _get_current_scene(enemy) -> Node:
	if enemy == null or not enemy.has_method("get_tree"):
		return null
	var tree: SceneTree = enemy.get_tree()
	return tree.current_scene if tree != null else null
