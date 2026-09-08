extends RefCounted

const SHRAPNEL_SCENE := preload("res://effects/gun/shrapnel/shrapnel.tscn")
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const PLAYER_SKILL_TALENT_SYSTEM := preload("res://scripts/player/player_skill_talent_system.gd")
const FIELD_TEXTURE := preload("res://effects/gun/shrapnel/散弹圈.png")
const SHRAPNEL_TEXTURES := [
	preload("res://effects/gun/shrapnel/1.png"),
	preload("res://effects/gun/shrapnel/2.png"),
	preload("res://effects/gun/shrapnel/3.png"),
	preload("res://effects/gun/shrapnel/4.png"),
	preload("res://effects/gun/shrapnel/5.png"),
	preload("res://effects/gun/shrapnel/6.png"),
	preload("res://effects/gun/shrapnel/7.png"),
	preload("res://effects/gun/shrapnel/8.png"),
	preload("res://effects/gun/shrapnel/9.png"),
	preload("res://effects/gun/shrapnel/10.png"),
	preload("res://effects/gun/shrapnel/11.png"),
	preload("res://effects/gun/shrapnel/12.png")
]

const SKILL_ID := "shrapnel_field"
const SHRAPNEL_DAMAGE_SOURCE_ROLE_ID := "gunner_no_hunt"
const COOLDOWN := 14.0
const DURATION := 4.0
const REPRISE_FIELD_DURATION := 2.0
const BASE_RADIUS := 150.0
const RADIUS_MULTIPLIER := 1.0
const TIER_ONE_TICK_INTERVAL := 0.6
const TIER_TWO_TICK_INTERVAL := 0.45
const TIER_THREE_TICK_INTERVAL := 0.25
const TIER_ONE_SLOW := 0.70
const TIER_TWO_SLOW := 0.55
const TIER_THREE_SLOW := 0.45
const TIER_ONE_DAMAGE_RATIO := 0.40
const TIER_TWO_DAMAGE_RATIO := 0.60
const TIER_THREE_DAMAGE_RATIO := 0.60
const TIER_TWO_RADIUS := 200.0
const TIER_THREE_RADIUS := 220.0
const DEFAULT_FIELD_COUNT := 2
const LEVEL_TALENT_SHRAPNEL_1 := "gunner_level_talent_shrapnel_1"
const LEVEL_TALENT_SHRAPNEL_2 := "gunner_level_talent_shrapnel_2"
const LEVEL_TALENT_SHRAPNEL_1_FIELD_COUNT := 4
const LEVEL_TALENT_SHRAPNEL_1_AREA_MULTIPLIER := 1.20
const LEVEL_TALENT_SHRAPNEL_2_DAMAGE_RATIO_BONUS := 0.05
const LEVEL_TALENT_SHRAPNEL_2_DURATION := 1.0
const LEVEL_TALENT_SHRAPNEL_2_SLOW_DURATION := 3.0
const MIN_FIELD_CENTER_DISTANCE := 150.0
const FIELD_CENTER_ENEMY_ATTEMPT_MULTIPLIER := 28
const FIELD_CENTER_ENEMY_OFFSET_RATIO := 0.72
const FIELD_CENTER_ENEMY_OFFSET_MAX := 120.0
const MAX_ACTIVE_VISUALS := 7
const VISUAL_SPAWN_INTERVAL := 0.1
const FIELD_CIRCLE_VISUAL_SCALE := 1.0
const FIELD_CIRCLE_VISIBLE_DIAMETER := 363.0
const FIELD_CIRCLE_VISIBLE_CENTER_OFFSET := Vector2(-18.0, 101.5)
const SHRAPNEL_MAX_VISIBLE_RADIUS := 127.0
const SHRAPNEL_VISUAL_MAX_SCALE := 0.62
const SHRAPNEL_ATLAS_REGION := Rect2(320.0, 320.0, 320.0, 240.0)
const MAX_CATCH_UP_TICKS := 5
const SHRAPNEL_VISUAL_POOL_LIMIT := 32
const TALENT_IDS := [
	"gunner_shrapnel_mobile",
	"gunner_shrapnel_delayed",
	"gunner_shrapnel_quick_throw",
	"gunner_shrapnel_rend",
	"gunner_shrapnel_afterfield",
	"gunner_shrapnel_snare",
	LEVEL_TALENT_SHRAPNEL_1,
	LEVEL_TALENT_SHRAPNEL_2
]

var cooldown_remaining: float = 0.0
var active_fields: Array[Dictionary] = []
var cached_shrapnel_frames: SpriteFrames
var shrapnel_visual_pool: Array[Node2D] = []
var pending_saved_fields: Array[Dictionary] = []


func update(owner, delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = max(0.0, cooldown_remaining - delta)
	if active_fields.is_empty():
		return
	if owner == null or not is_instance_valid(owner):
		stop()
		return
	if bool(owner.get("is_dead")):
		stop(owner)
		return
	if str(owner._get_active_role().get("id", "")) != "gunner":
		stop(owner)
		return
	_update_fields(owner, delta)


func can_trigger(owner, role_id: String) -> bool:
	if owner == null or not is_instance_valid(owner):
		return false
	if bool(owner.get("is_dead")) or bool(owner.get("level_up_active")):
		return false
	if role_id != "gunner":
		return false
	if not _has_required_unlock(owner):
		return false
	return active_fields.is_empty() and cooldown_remaining <= 0.0


func try_trigger(owner) -> bool:
	if not can_trigger(owner, str(owner._get_active_role().get("id", ""))):
		return false
	cooldown_remaining = _get_cooldown(owner)
	active_fields.clear()
	var duration: float = _get_duration(owner)
	var extra_field_count: int = _get_trick_extra_field_count(owner)
	var mobile: bool = _has_talent(owner, "gunner_shrapnel_mobile")
	var mobile_field_mode: bool = mobile and not _has_level_talent(owner, LEVEL_TALENT_SHRAPNEL_1)
	var base_field_count: int = _get_base_field_count(owner, mobile)
	var centers: Array = _get_field_centers(owner, base_field_count + extra_field_count)
	if mobile_field_mode and not centers.is_empty():
		centers[0] = owner.global_position
	for index in range(centers.size()):
		var center_value: Variant = centers[index]
		var center: Vector2 = center_value if center_value is Vector2 else owner.global_position
		var is_primary: bool = index < base_field_count
		_create_field(
			owner,
			center,
			1.5 if mobile_field_mode and is_primary else 1.0,
			true,
			duration,
			mobile_field_mode and is_primary,
			is_primary and _has_talent(owner, "gunner_shrapnel_delayed"),
			1.2 if mobile_field_mode and is_primary else 1.0,
			"",
			is_primary
		)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -66.0), "\u6563\u5f39", Color(1.0, 0.62, 0.32, 1.0))
	return true



func _get_field_centers(owner, field_count: int) -> Array:
	var result: Array = []
	var target_count: int = max(0, field_count)
	if target_count <= 0:
		return result

	var live_enemies: Array = _get_live_enemy_nodes(owner)
	_append_enemy_anchored_field_centers(owner, result, live_enemies, target_count)
	if result.size() >= target_count:
		return result

	var requested_count: int = max(target_count * 5, target_count)
	var candidates: Array = owner._get_random_enemy_cluster_centers(requested_count) if owner != null and owner.has_method("_get_random_enemy_cluster_centers") else []
	candidates.shuffle()
	for center_value in candidates:
		if center_value is not Vector2:
			continue
		var candidate: Vector2 = center_value + _random_field_center_offset(owner)
		if _is_field_center_far_enough(result, candidate):
			result.append(candidate)
			if result.size() >= target_count:
				return result

	var fallback_center: Vector2 = owner.global_position
	if not result.is_empty():
		fallback_center = result[0]
	elif not live_enemies.is_empty() and live_enemies[0] is Node2D:
		fallback_center = (live_enemies[0] as Node2D).global_position
	elif not candidates.is_empty() and candidates[0] is Vector2:
		fallback_center = candidates[0]

	var attempts: int = 0
	var fallback_spread: float = max(MIN_FIELD_CENTER_DISTANCE * 1.75, _get_radius(owner) * 1.2)
	while result.size() < target_count and attempts < target_count * 18:
		var candidate := fallback_center + _random_field_center_offset(owner, fallback_spread)
		if _is_field_center_far_enough(result, candidate):
			result.append(candidate)
		attempts += 1

	var fallback_attempts: int = 0
	var angle_offset: float = randf() * TAU
	while result.size() < target_count:
		var directions: int = max(1, target_count * 4)
		var angle: float = angle_offset + TAU * float(fallback_attempts % directions) / float(directions)
		var ring: float = floor(float(fallback_attempts) / float(directions)) + 1.0
		var candidate := fallback_center + Vector2.RIGHT.rotated(angle) * (MIN_FIELD_CENTER_DISTANCE + 24.0) * ring
		if _is_field_center_far_enough(result, candidate):
			result.append(candidate)
		fallback_attempts += 1
	return result


func _get_live_enemy_nodes(owner) -> Array:
	var result: Array = []
	if owner == null or not is_instance_valid(owner) or not owner.has_method("_get_live_enemies"):
		return result
	for enemy_value in owner._get_live_enemies():
		if enemy_value is Node2D and is_instance_valid(enemy_value):
			result.append(enemy_value)
	return result


func _append_enemy_anchored_field_centers(owner, result: Array, enemies: Array, target_count: int) -> void:
	if enemies.is_empty():
		return
	var shuffled_enemies: Array = enemies.duplicate()
	shuffled_enemies.shuffle()
	for enemy_value in shuffled_enemies:
		if result.size() >= target_count:
			return
		if enemy_value is not Node2D or not is_instance_valid(enemy_value):
			continue
		var enemy := enemy_value as Node2D
		var candidate: Vector2 = enemy.global_position + _random_field_center_offset(owner)
		if _is_field_center_far_enough(result, candidate):
			result.append(candidate)

	var attempts: int = 0
	var max_attempts: int = max(target_count * FIELD_CENTER_ENEMY_ATTEMPT_MULTIPLIER, enemies.size() * 4)
	while result.size() < target_count and attempts < max_attempts:
		var enemy_value = enemies[randi() % enemies.size()]
		if enemy_value is Node2D and is_instance_valid(enemy_value):
			var enemy := enemy_value as Node2D
			var candidate: Vector2 = enemy.global_position + _random_field_center_offset(owner)
			if _is_field_center_far_enough(result, candidate):
				result.append(candidate)
		attempts += 1


func _random_field_center_offset(owner, max_offset_override: float = -1.0) -> Vector2:
	var max_offset: float = max_offset_override
	if max_offset < 0.0:
		max_offset = min(FIELD_CENTER_ENEMY_OFFSET_MAX, max(1.0, _get_radius(owner) * FIELD_CENTER_ENEMY_OFFSET_RATIO))
	var distance: float = sqrt(randf()) * max(0.0, max_offset)
	return Vector2.RIGHT.rotated(randf() * TAU) * distance


func _is_field_center_far_enough(existing_centers: Array, candidate: Vector2) -> bool:
	var minimum_distance_squared := MIN_FIELD_CENTER_DISTANCE * MIN_FIELD_CENTER_DISTANCE
	for center_value in existing_centers:
		if center_value is not Vector2:
			continue
		var existing_center: Vector2 = center_value
		if candidate.distance_squared_to(existing_center) <= minimum_distance_squared:
			return false
	return true
func stop(owner = null) -> void:
	for field_data in active_fields:
		if owner != null:
			_apply_snare_to_tracked_enemies(owner, field_data)
		_free_field(field_data)
	active_fields.clear()


func get_cooldown_slot(owner = null) -> Dictionary:
	var duration: float = _get_cooldown(owner)
	return {
		"name": "\u6563\u5f39",
		"remaining": clamp(cooldown_remaining, 0.0, duration),
		"duration": duration,
		"color": Color(1.0, 0.58, 0.28, 1.0),
		"description": "\u67aa\u624b\u5728\u602a\u7269\u5bc6\u96c6\u5904\u5236\u9020\u6563\u5f39\u533a\u57df\uff0c\u533a\u57df\u5185\u6301\u7eed\u9020\u6210\u4f24\u5bb3\u5e76\u51cf\u901f\u3002"
	}


func get_save_data() -> Dictionary:
	var fields: Array[Dictionary] = []
	for field_data in active_fields:
		fields.append(_serialize_field(field_data))
	return {
		"cooldown_remaining": cooldown_remaining,
		"fields": fields
	}


func apply_save_data(data: Dictionary) -> void:
	cooldown_remaining = clamp(float(data.get("cooldown_remaining", 0.0)), 0.0, COOLDOWN)
	stop()
	pending_saved_fields.clear()
	var saved_fields: Variant = data.get("fields", [])
	if saved_fields is Array:
		for saved_data in saved_fields:
			if saved_data is Dictionary:
				pending_saved_fields.append((saved_data as Dictionary).duplicate(true))


func restore_effect_if_active(owner) -> void:
	for saved_data in pending_saved_fields:
		var talents := _normalize_talent_ids(saved_data.get("talent_ids", []))
		var previous_count := active_fields.size()
		_create_field(
			owner,
			_decode_vector2(saved_data.get("center", []), owner.global_position),
			max(0.05, float(saved_data.get("effect_scale", 1.0))),
			bool(saved_data.get("spawn_reprise_on_end", false)),
			max(0.001, float(saved_data.get("remaining", 0.001))),
			bool(saved_data.get("follows_owner", false)),
			bool(saved_data.get("delayed_explosion", false)),
			1.0,
			str(saved_data.get("field_kind", "")),
			bool(saved_data.get("is_primary_cast", false)),
			talents,
			max(0.0, float(saved_data.get("damage", 0.0))),
			clamp(float(saved_data.get("slow_multiplier", 1.0)), 0.0, 1.0),
			true
		)
		if active_fields.size() <= previous_count:
			continue
		var restored: Dictionary = active_fields.back()
		restored["remaining"] = max(0.0, float(saved_data.get("remaining", restored.get("remaining", 0.0))))
		restored["tick_remaining"] = max(0.0, float(saved_data.get("tick_remaining", 0.0)))
		restored["tick_interval"] = max(0.01, float(saved_data.get("tick_interval", restored.get("tick_interval", TIER_ONE_TICK_INTERVAL))))
		restored["visual_remaining"] = max(0.0, float(saved_data.get("visual_remaining", 0.0)))
		restored["radius"] = max(1.0, float(saved_data.get("radius", restored.get("radius", BASE_RADIUS))))
		restored["reprise_scales"] = (saved_data.get("reprise_scales", []) as Array).duplicate()
		var root := restored.get("root", null) as Node2D
		var circle := root.get_node_or_null("FieldCircle") as Sprite2D if root != null else null
		if circle != null:
			circle.scale = Vector2.ONE * (float(restored["radius"]) * 2.0 / FIELD_CIRCLE_VISIBLE_DIAMETER * FIELD_CIRCLE_VISUAL_SCALE)
		active_fields[active_fields.size() - 1] = restored
	pending_saved_fields.clear()


func _update_fields(owner, delta: float) -> void:
	var hits: int = 0
	for index in range(active_fields.size() - 1, -1, -1):
		var field_data: Dictionary = active_fields[index]
		var remaining: float = max(0.0, float(field_data.get("remaining", 0.0)) - delta)
		field_data["remaining"] = remaining
		if remaining <= 0.0:
			if bool(field_data.get("delayed_explosion", false)):
				hits += _explode_field(owner, field_data)
			_spawn_reprise_fields_on_end(owner, field_data)
			_spawn_afterfield_on_end(owner, field_data)
			_apply_snare_to_tracked_enemies(owner, field_data)
			_free_field(field_data)
			active_fields.remove_at(index)
			continue
		if bool(field_data.get("follows_owner", false)):
			field_data["center"] = owner.global_position
			var root: Node2D = field_data.get("root", null) as Node2D
			if root != null and is_instance_valid(root):
				root.global_position = owner.global_position
		_update_snare_tracked_enemies(owner, field_data)
		field_data["tick_remaining"] = float(field_data.get("tick_remaining", 0.0)) - delta
		var catch_up_ticks: int = 0
		while float(field_data.get("tick_remaining", 0.0)) <= 0.0 and catch_up_ticks < MAX_CATCH_UP_TICKS:
			field_data["tick_remaining"] = float(field_data.get("tick_remaining", 0.0)) + float(field_data.get("tick_interval", _get_tick_interval(owner)))
			hits += _damage_field(owner, field_data)
			catch_up_ticks += 1
		field_data["visual_remaining"] = float(field_data.get("visual_remaining", 0.0)) - delta
		while float(field_data.get("visual_remaining", 0.0)) <= 0.0:
			field_data["visual_remaining"] = float(field_data.get("visual_remaining", 0.0)) + VISUAL_SPAWN_INTERVAL
			_spawn_shrapnel_visual_if_room(field_data)
	if hits > 0 and not _uses_batched_damage(owner):
		owner._register_attack_result("gunner", hits, false)


func _create_field(owner, center: Vector2, effect_scale: float = 1.0, spawn_reprise_on_end: bool = false, duration_override: float = -1.0, follows_owner: bool = false, delayed_explosion: bool = false, radius_scale: float = 1.0, field_kind: String = "", is_primary_cast: bool = false, talent_ids: Array[String] = [], damage_override: float = -1.0, slow_override: float = -1.0, talent_snapshot_valid: bool = false) -> void:
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		return
	var radius: float = _get_radius(owner) * max(0.05, radius_scale)
	var safe_scale: float = max(0.05, effect_scale)
	var snapshot_talents := talent_ids if talent_snapshot_valid else _capture_talents(owner)
	var field_duration: float = duration_override if duration_override > 0.0 else _get_duration(owner)
	var root: Node2D = null
	root = Node2D.new()
	root.name = "GunnerShrapnelField"
	root.global_position = center
	root.z_index = 10
	root.add_to_group("temporary_effects")
	current_scene.add_child(root)

	var circle: Sprite2D = Sprite2D.new()
	circle.name = "FieldCircle"
	circle.texture = FIELD_TEXTURE
	circle.centered = true
	circle.offset = FIELD_CIRCLE_VISIBLE_CENTER_OFFSET
	circle.modulate = Color(1.0, 1.0, 1.0, 0.602)
	circle.scale = Vector2.ONE * (radius * 2.0 / FIELD_CIRCLE_VISIBLE_DIAMETER * FIELD_CIRCLE_VISUAL_SCALE)
	root.add_child(circle)

	var field_data: Dictionary = {
		"root": root,
		"center": center,
		"remaining": field_duration,
		"tick_remaining": 0.0,
		"tick_interval": 0.5 if field_kind == "afterfield" else _get_field_tick_interval(owner),
		"visual_remaining": 0.0,
		"visuals": [],
		"radius": radius,
		"effect_scale": safe_scale,
		"damage": damage_override if damage_override >= 0.0 else _get_damage(owner),
		"slow_multiplier": slow_override if slow_override >= 0.0 else _get_slow_multiplier(owner),
		"talent_ids": snapshot_talents.duplicate(),
		"reprise_scales": _get_reprise_field_scales(owner).duplicate(),
		"spawn_reprise_on_end": spawn_reprise_on_end,
		"is_primary_cast": is_primary_cast,
		"follows_owner": follows_owner,
		"delayed_explosion": delayed_explosion,
		"field_kind": field_kind,
		"snare_inside": {}
	}
	active_fields.append(field_data)


func _damage_field(owner, field_data: Dictionary) -> int:
	var center: Vector2 = field_data.get("center", owner.global_position)
	var radius: float = float(field_data.get("radius", _get_radius(owner)))
	var effect_scale: float = max(0.0, float(field_data.get("effect_scale", 1.0)))
	var vulnerability_bonus := 0.05 if _field_has_talent(owner, field_data, "gunner_shrapnel_rend") else 0.0
	var slow_multiplier := 0.8 if str(field_data.get("field_kind", "")) == "afterfield" else float(field_data.get("slow_multiplier", 1.0))
	var slow_duration := LEVEL_TALENT_SHRAPNEL_2_SLOW_DURATION if _field_has_talent(owner, field_data, LEVEL_TALENT_SHRAPNEL_2) else 1.2
	return owner._damage_enemies_in_radius(center, radius, float(field_data.get("damage", 0.0)) * effect_scale, vulnerability_bonus, slow_multiplier, slow_duration, SHRAPNEL_DAMAGE_SOURCE_ROLE_ID)


func _explode_field(owner, field_data: Dictionary) -> int:
	var center: Vector2 = field_data.get("center", owner.global_position)
	var radius: float = float(field_data.get("radius", _get_radius(owner)))
	var effect_scale: float = max(0.0, float(field_data.get("effect_scale", 1.0)))
	owner._spawn_burst_effect(center, radius, Color(1.0, 0.5, 0.24, 0.22), 0.18)
	return owner._damage_enemies_in_radius(center, radius, float(field_data.get("damage", 0.0)) * effect_scale * 2.5, 0.0, float(field_data.get("slow_multiplier", 1.0)), 1.2, SHRAPNEL_DAMAGE_SOURCE_ROLE_ID)


func _spawn_reprise_fields_on_end(owner, field_data: Dictionary) -> void:
	if not bool(field_data.get("spawn_reprise_on_end", false)):
		return
	for combo_scale in field_data.get("reprise_scales", []):
		var center: Vector2 = field_data.get("center", owner.global_position)
		_create_field(owner, center, float(combo_scale), false, REPRISE_FIELD_DURATION, false, false, 1.0, "", false, _normalize_talent_ids(field_data.get("talent_ids", [])), float(field_data.get("damage", 0.0)), float(field_data.get("slow_multiplier", 1.0)), true)

func _spawn_afterfield_on_end(owner, field_data: Dictionary) -> void:
	if not _field_has_talent(owner, field_data, "gunner_shrapnel_afterfield"):
		return
	if not bool(field_data.get("is_primary_cast", false)) or str(field_data.get("field_kind", "")) == "afterfield":
		return
	var center: Vector2 = field_data.get("center", owner.global_position)
	var effect_scale: float = max(0.0, float(field_data.get("effect_scale", 1.0))) * 0.30
	_create_field(owner, center, effect_scale, false, 1.0, false, false, 0.6, "afterfield", false, _normalize_talent_ids(field_data.get("talent_ids", [])), float(field_data.get("damage", 0.0)), 0.8, true)

func _update_snare_tracked_enemies(owner, field_data: Dictionary) -> void:
	if not _field_has_talent(owner, field_data, "gunner_shrapnel_snare"):
		return
	var center: Vector2 = field_data.get("center", owner.global_position)
	var radius := float(field_data.get("radius", 0.0))
	var previous: Dictionary = field_data.get("snare_inside", {})
	var current: Dictionary = {}
	var candidates: Array = owner._get_candidate_enemies_for_circle(center, radius) if owner.has_method("_get_candidate_enemies_for_circle") else owner._get_live_enemies()
	for enemy_value in candidates:
		var enemy := enemy_value as Node2D
		if enemy == null or not is_instance_valid(enemy) or center.distance_squared_to(enemy.global_position) > radius * radius:
			continue
		current[enemy.get_instance_id()] = weakref(enemy)
	for enemy_id in previous:
		if current.has(enemy_id):
			continue
		var enemy_ref: WeakRef = previous[enemy_id] as WeakRef
		_apply_snare_tail(owner, enemy_ref.get_ref() as Node if enemy_ref != null else null)
	field_data["snare_inside"] = current

func _apply_snare_to_tracked_enemies(owner, field_data: Dictionary) -> void:
	if not _field_has_talent(owner, field_data, "gunner_shrapnel_snare"):
		return
	var tracked: Dictionary = field_data.get("snare_inside", {})
	for enemy_ref_value in tracked.values():
		var enemy_ref := enemy_ref_value as WeakRef
		_apply_snare_tail(owner, enemy_ref.get_ref() as Node if enemy_ref != null else null)
	field_data["snare_inside"] = {}

func _apply_snare_tail(owner, enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var delay: float = max(0.0, float(enemy.get("slow_timer")) if enemy.get("slow_timer") != null else 0.0)
	var apply_tail := func() -> void:
		if is_instance_valid(enemy) and enemy.has_method("apply_slow"):
			enemy.apply_slow(0.75, 0.65)
	if delay <= 0.0 or not owner.has_method("_schedule_repeating_sequence"):
		apply_tail.call()
		return
	owner._schedule_repeating_sequence(delay, 1, func(_index: int) -> void:
		apply_tail.call()
	, delay)


func _has_talent(owner, talent_id: String) -> bool:
	if talent_id.begins_with("gunner_level_talent_"):
		return _has_level_talent(owner, talent_id)
	return owner != null and owner.has_method("_has_skill_talent") and bool(owner._has_skill_talent(talent_id))


func _has_level_talent(owner, talent_id: String) -> bool:
	if owner == null or talent_id == "":
		return false
	if owner.has_method("_has_level_talent"):
		return bool(owner._has_level_talent(talent_id))
	return PLAYER_SKILL_TALENT_SYSTEM.has_level_talent(owner, talent_id)


func _field_has_talent(owner, field_data: Dictionary, talent_id: String) -> bool:
	var talent_ids: Variant = field_data.get("talent_ids", null)
	return (talent_ids as Array).has(talent_id) if talent_ids is Array else _has_talent(owner, talent_id)


func _capture_talents(owner) -> Array[String]:
	var result: Array[String] = []
	for talent_id in TALENT_IDS:
		if _has_talent(owner, talent_id):
			result.append(talent_id)
	return result


func _normalize_talent_ids(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for talent_id in value:
			var normalized := str(talent_id)
			if TALENT_IDS.has(normalized) and not result.has(normalized):
				result.append(normalized)
	return result


func _serialize_field(field_data: Dictionary) -> Dictionary:
	var center: Vector2 = field_data.get("center", Vector2.ZERO)
	return {
		"center": [center.x, center.y],
		"remaining": float(field_data.get("remaining", 0.0)),
		"tick_remaining": float(field_data.get("tick_remaining", 0.0)),
		"tick_interval": float(field_data.get("tick_interval", TIER_ONE_TICK_INTERVAL)),
		"visual_remaining": float(field_data.get("visual_remaining", 0.0)),
		"radius": float(field_data.get("radius", BASE_RADIUS)),
		"effect_scale": float(field_data.get("effect_scale", 1.0)),
		"damage": float(field_data.get("damage", 0.0)),
		"slow_multiplier": float(field_data.get("slow_multiplier", 1.0)),
		"spawn_reprise_on_end": bool(field_data.get("spawn_reprise_on_end", false)),
		"is_primary_cast": bool(field_data.get("is_primary_cast", false)),
		"follows_owner": bool(field_data.get("follows_owner", false)),
		"delayed_explosion": bool(field_data.get("delayed_explosion", false)),
		"field_kind": str(field_data.get("field_kind", "")),
		"talent_ids": _normalize_talent_ids(field_data.get("talent_ids", [])),
		"reprise_scales": (field_data.get("reprise_scales", []) as Array).duplicate()
	}


func _decode_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


func _spawn_shrapnel_visual_if_room(field_data: Dictionary) -> void:
	var root: Node2D = field_data.get("root", null) as Node2D
	if root == null or not is_instance_valid(root):
		return
	var visuals: Array = field_data.get("visuals", [])
	var live_count: int = 0
	for index in range(visuals.size()):
		var visual: Variant = visuals[index]
		if visual != null and is_instance_valid(visual) and bool(visual.get_meta("shrapnel_active", false)) and (visual as Node).get_parent() == root:
			visuals[live_count] = visual
			live_count += 1
	visuals.resize(live_count)
	if live_count >= MAX_ACTIVE_VISUALS:
		field_data["visuals"] = visuals
		return
	var visual: Node2D = _create_shrapnel_visual(root, float(field_data.get("radius", BASE_RADIUS)))
	if visual != null:
		visuals.append(visual)
	field_data["visuals"] = visuals


func _create_shrapnel_visual(root: Node2D, radius: float) -> Node2D:
	var visual: Node2D = _acquire_shrapnel_visual(root)
	if visual == null:
		visual = Node2D.new()
	visual.name = "ShrapnelVisual"
	visual.z_index = 11
	visual.visible = true
	visual.modulate = Color.WHITE
	visual.set_meta("shrapnel_active", true)
	visual.set_meta("shrapnel_released", false)
	var sprite: AnimatedSprite2D = visual.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		sprite = AnimatedSprite2D.new()
		sprite.name = "AnimatedSprite2D"
		visual.add_child(sprite)
	if sprite.sprite_frames == null:
		sprite.sprite_frames = _get_centered_shrapnel_frames()
	sprite.animation = StringName("shrapnel")
	sprite.centered = true
	sprite.position = Vector2.ZERO
	sprite.offset = Vector2.ZERO
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ONE * randf_range(0.38, 0.48)
	sprite.rotation = 0.0
	_place_visual_randomly(visual, radius)
	sprite.frame = 0
	sprite.frame_progress = 0.0
	_disconnect_shrapnel_finish_callbacks(sprite)
	sprite.play("shrapnel")
	sprite.animation_finished.connect(_release_shrapnel_visual.bind(visual), CONNECT_ONE_SHOT)
	return visual


func _acquire_shrapnel_visual(root: Node2D) -> Node2D:
	while not shrapnel_visual_pool.is_empty():
		var pooled_visual: Variant = shrapnel_visual_pool.pop_back()
		if not is_instance_valid(pooled_visual) or not (pooled_visual is Node2D):
			continue
		var visual := pooled_visual as Node2D
		if visual.is_queued_for_deletion():
			continue
		var parent := visual.get_parent()
		if parent != root:
			if parent != null:
				parent.remove_child(visual)
			root.add_child(visual)
		return visual
	var visual: Node2D = null
	if SHRAPNEL_SCENE != null:
		visual = SHRAPNEL_SCENE.instantiate() as Node2D
	if visual == null:
		visual = Node2D.new()
	root.add_child(visual)
	return visual


func _release_shrapnel_visual(visual: Node2D) -> void:
	if visual == null or not is_instance_valid(visual):
		return
	if bool(visual.get_meta("shrapnel_released", false)):
		return
	if not bool(visual.get_meta("shrapnel_active", false)) and visual.get_parent() == null:
		return
	visual.set_meta("shrapnel_released", true)
	visual.set_meta("shrapnel_active", false)
	visual.hide()
	var sprite: AnimatedSprite2D = visual.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.stop()
		_disconnect_shrapnel_finish_callbacks(sprite)
	var parent := visual.get_parent()
	if parent != null:
		parent.remove_child(visual)
	if shrapnel_visual_pool.size() < SHRAPNEL_VISUAL_POOL_LIMIT and not shrapnel_visual_pool.has(visual):
		shrapnel_visual_pool.append(visual)
	else:
		visual.queue_free()


func _disconnect_shrapnel_finish_callbacks(sprite: AnimatedSprite2D) -> void:
	for connection in sprite.animation_finished.get_connections():
		var callback: Callable = connection.get("callable", Callable())
		if callback.get_object() == self and String(callback.get_method()) == "_release_shrapnel_visual":
			sprite.animation_finished.disconnect(callback)


func _get_centered_shrapnel_frames() -> SpriteFrames:
	if cached_shrapnel_frames != null:
		return cached_shrapnel_frames
	cached_shrapnel_frames = _build_centered_shrapnel_frames()
	return cached_shrapnel_frames


func _build_centered_shrapnel_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("shrapnel")
	frames.set_animation_loop("shrapnel", false)
	frames.set_animation_speed("shrapnel", 16.0)
	for texture in SHRAPNEL_TEXTURES:
		if texture != null:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = SHRAPNEL_ATLAS_REGION
			frames.add_frame("shrapnel", atlas)
	return frames


func _place_visual_randomly(visual: Node2D, radius: float) -> void:
	var angle: float = randf() * TAU
	var safe_radius: float = radius * 0.28
	var distance: float = sqrt(randf()) * safe_radius
	visual.position = Vector2.RIGHT.rotated(angle) * distance
	visual.rotation = 0.0
	visual.scale = Vector2.ONE


func _free_field(field_data: Dictionary) -> void:
	var visuals: Array = field_data.get("visuals", [])
	for visual in visuals:
		if visual != null and is_instance_valid(visual):
			_release_shrapnel_visual(visual)
	field_data["visuals"] = []
	var root: Node = field_data.get("root", null)
	if root != null and is_instance_valid(root):
		root.queue_free()


func _has_required_unlock(owner) -> bool:
	return owner != null and owner.has_method("_is_blessing_skill_unlocked") and bool(owner._is_blessing_skill_unlocked(SKILL_ID))


func _get_tier(owner) -> int:
	if owner != null and owner.has_method("_get_blessing_skill_tier"):
		return int(owner._get_blessing_skill_tier(SKILL_ID))
	return 1


func _get_trick_extra_field_count(owner) -> int:
	if owner == null or not owner.has_method("_get_blessing_skill_quantity_count"):
		return 0
	return max(0, int(owner._get_blessing_skill_quantity_count(SKILL_ID)))


func _get_reprise_field_scales(owner) -> Array[float]:
	var result: Array[float] = []
	if owner == null or not owner.has_method("_get_blessing_skill_combo_scales"):
		return result
	for scale in owner._get_blessing_skill_combo_scales(SKILL_ID) as Array:
		result.append(float(scale))
	return result


func _get_base_field_count(owner, mobile: bool) -> int:
	if _has_level_talent(owner, LEVEL_TALENT_SHRAPNEL_1):
		return LEVEL_TALENT_SHRAPNEL_1_FIELD_COUNT
	if mobile:
		return 1
	return DEFAULT_FIELD_COUNT


func _get_cooldown(owner) -> float:
	var cooldown_multiplier: float = PLAYER_BUILD_SYSTEM.get_shrapnel_cooldown_multiplier(owner)
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_equipment_cooldown_multiplier"):
		cooldown_multiplier *= float(owner._get_equipment_cooldown_multiplier())
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_mage_arcane_charge_skill_cooldown_multiplier"):
		cooldown_multiplier *= float(owner._get_mage_arcane_charge_skill_cooldown_multiplier("gunner"))
	if owner != null and is_instance_valid(owner) and owner.has_method("_get_kebiru_magic_cooldown_multiplier"):
		cooldown_multiplier *= float(owner._get_kebiru_magic_cooldown_multiplier(SKILL_ID))
	var talent_multiplier := 0.78 if _has_talent(owner, "gunner_shrapnel_quick_throw") else 1.0
	return COOLDOWN * cooldown_multiplier * talent_multiplier


func _get_radius(owner) -> float:
	var range_multiplier: float = 1.0
	if owner != null and owner.has_method("_get_equipment_skill_range_multiplier"):
		range_multiplier *= float(owner._get_equipment_skill_range_multiplier())
	if owner != null and owner.has_method("_get_kebiru_magic_range_multiplier"):
		range_multiplier *= float(owner._get_kebiru_magic_range_multiplier(SKILL_ID))
	var tier: int = _get_tier(owner)
	var base_radius: float = BASE_RADIUS * RADIUS_MULTIPLIER
	if tier >= 3:
		base_radius = TIER_THREE_RADIUS
	elif tier >= 2:
		base_radius = TIER_TWO_RADIUS
	var radius: float = (base_radius + PLAYER_BUILD_SYSTEM.get_shrapnel_radius_bonus(owner)) * range_multiplier
	if _has_level_talent(owner, LEVEL_TALENT_SHRAPNEL_1):
		radius *= sqrt(LEVEL_TALENT_SHRAPNEL_1_AREA_MULTIPLIER)
	return radius


func _get_tick_interval(owner) -> float:
	var tier: int = _get_tier(owner)
	if tier >= 3:
		return TIER_THREE_TICK_INTERVAL
	if tier >= 2:
		return TIER_TWO_TICK_INTERVAL
	return TIER_ONE_TICK_INTERVAL


func _get_field_tick_interval(owner) -> float:
	var tick_interval: float = _get_tick_interval(owner)
	if _has_level_talent(owner, LEVEL_TALENT_SHRAPNEL_2):
		tick_interval *= LEVEL_TALENT_SHRAPNEL_2_DURATION / max(0.001, _get_uncompressed_duration(owner))
	return max(0.01, tick_interval)


func _get_slow_multiplier(owner) -> float:
	var tier: int = _get_tier(owner)
	if tier >= 3:
		return TIER_THREE_SLOW
	if tier >= 2:
		return TIER_TWO_SLOW
	return TIER_ONE_SLOW


func _get_damage(owner) -> float:
	var tier: int = _get_tier(owner)
	var ratio: float = TIER_ONE_DAMAGE_RATIO
	if tier >= 3:
		ratio = TIER_THREE_DAMAGE_RATIO
	elif tier >= 2:
		ratio = TIER_TWO_DAMAGE_RATIO
	if _has_level_talent(owner, LEVEL_TALENT_SHRAPNEL_2):
		ratio += LEVEL_TALENT_SHRAPNEL_2_DAMAGE_RATIO_BONUS
	var damage: float = float(owner._get_role_damage("gunner")) * (ratio + PLAYER_BUILD_SYSTEM.get_shrapnel_damage_ratio_bonus(owner))
	return damage


func _get_uncompressed_duration(owner) -> float:
	var duration: float = DURATION
	if owner != null and owner.has_method("_get_blessing_skill_duration_multiplier"):
		duration *= float(owner._get_blessing_skill_duration_multiplier(SKILL_ID))
	if owner != null and owner.has_method("_get_blessing_skill_duration_flat_bonus"):
		duration += float(owner._get_blessing_skill_duration_flat_bonus(SKILL_ID))
	if _has_talent(owner, "gunner_shrapnel_quick_throw"):
		duration = max(2.4, duration * 0.80)
	return duration


func _get_duration(owner) -> float:
	var duration: float = _get_uncompressed_duration(owner)
	if _has_level_talent(owner, LEVEL_TALENT_SHRAPNEL_2):
		return min(duration, LEVEL_TALENT_SHRAPNEL_2_DURATION)
	return duration

func _uses_batched_damage(owner) -> bool:
	return owner != null and owner.has_method("_damage_enemies_in_radius")
