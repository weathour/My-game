extends Node2D

const ENEMY_BODY_SEPARATION := preload("res://scripts/enemies/enemy_body_separation.gd")
const ENEMY_GLUTTON_BEHAVIOR := preload("res://scripts/enemies/enemy_glutton_behavior.gd")
const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")

const BODY_LINE_WIDTH := 2.0
const TOUCH_DAMAGE_LINE_WIDTH := 3.0
const TREE_RANGE_LINE_WIDTH := 4.0
const ELLIPSE_SEGMENTS := 48

const KIND_COLORS := {
	"normal": Color(0.2, 1.0, 0.3, 0.2),
	"elite": Color(1.0, 0.82, 0.18, 0.28),
	"small_boss": Color(1.0, 0.18, 0.86, 0.28),
	"boss": Color(1.0, 1.0, 1.0, 0.28)
}
const TREE_SQUASH_COLOR := Color(0.1, 0.48, 1.0, 0.88)
const TREE_ATTACK_COLOR := Color(1.0, 0.12, 0.08, 0.9)
const TREE_WOOD_SPIKE_COLOR := Color(1.0, 0.72, 0.08, 0.95)
const TOUCH_DAMAGE_COLOR := Color(1.0, 0.06, 0.04, 0.92)
const PLAYER_HIT_RANGE_COLOR := Color(0.22, 0.72, 1.0, 0.92)
const TOUCH_DAMAGE_SHADOW_RADIUS_SCALE := 1.048808848
const TOUCH_DAMAGE_CURRENT_SIZE_SCALE := 0.8

var battle_root: Node
var debug_enabled: bool = false
var combat_enabled: bool = true


func configure(root_node: Node, combat_ranges_enabled: bool = false) -> void:
	battle_root = root_node
	z_as_relative = false
	z_index = 4090
	set_debug_enabled(false)
	set_combat_enabled(combat_ranges_enabled)


func set_combat_enabled(enabled: bool) -> void:
	combat_enabled = enabled
	visible = combat_enabled or debug_enabled
	set_process(combat_enabled or debug_enabled)
	queue_redraw()


func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled
	visible = combat_enabled or debug_enabled
	set_process(combat_enabled or debug_enabled)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not combat_enabled and not debug_enabled:
		return
	if battle_root == null or not is_instance_valid(battle_root):
		return
	for enemy in _get_runtime_enemies():
		if enemy == null or not is_instance_valid(enemy) or enemy is not Node2D:
			continue
		if combat_enabled:
			_draw_enemy_combat_ranges(enemy as Node2D)
		if debug_enabled:
			_draw_enemy_body_collision(enemy as Node2D)
			_draw_enemy_player_hit_range(enemy as Node2D)
			if _is_tree_glutton(enemy):
				_draw_tree_debug_ranges(enemy as Node2D)


func _draw_enemy_body_collision(enemy: Node2D) -> void:
	var radius: float = ENEMY_BODY_SEPARATION.get_body_collision_radius(enemy)
	if radius <= 0.0:
		return
	var kind: String = str(enemy.get("enemy_kind"))
	draw_circle(to_local(enemy.global_position), radius, _get_kind_color(kind))
	draw_arc(to_local(enemy.global_position), radius, 0.0, TAU, ELLIPSE_SEGMENTS, Color.WHITE, 1.0, true)


func _draw_enemy_combat_ranges(enemy: Node2D) -> void:
	if _is_tree_glutton(enemy):
		_draw_tree_combat_ranges(enemy)
		return
	if not _should_draw_touch_damage_range(enemy):
		return
	var shape: Dictionary = _get_touch_damage_shape(enemy)
	if shape.is_empty():
		return
	_draw_shape(shape, TOUCH_DAMAGE_COLOR, TOUCH_DAMAGE_LINE_WIDTH)


func _draw_enemy_player_hit_range(enemy: Node2D) -> void:
	if not _is_boss_or_small_boss(enemy):
		return
	var shape: Dictionary = PLAYER_DAMAGE_RESOLVER.get_enemy_player_hit_shape(enemy)
	if shape.is_empty():
		return
	_draw_shape(shape, PLAYER_HIT_RANGE_COLOR, TOUCH_DAMAGE_LINE_WIDTH)


func _draw_tree_combat_ranges(enemy: Node2D) -> void:
	var passive_shape: Dictionary = ENEMY_GLUTTON_BEHAVIOR.get_passive_player_touch_shape(enemy)
	_draw_shape(passive_shape, TOUCH_DAMAGE_COLOR, TOUCH_DAMAGE_LINE_WIDTH)
	var active_shape: Dictionary = ENEMY_GLUTTON_BEHAVIOR.get_player_touch_shape(enemy)
	if not active_shape.is_empty():
		_draw_shape(active_shape, TREE_ATTACK_COLOR, TREE_RANGE_LINE_WIDTH)


func _draw_tree_debug_ranges(enemy: Node2D) -> void:
	_draw_shape(ENEMY_GLUTTON_BEHAVIOR.get_debug_aura_shape(enemy), TREE_SQUASH_COLOR, TREE_RANGE_LINE_WIDTH)
	_draw_shape(ENEMY_GLUTTON_BEHAVIOR.get_player_touch_shape(enemy), TREE_ATTACK_COLOR, TREE_RANGE_LINE_WIDTH)
	for shape in ENEMY_GLUTTON_BEHAVIOR.get_debug_wood_spike_hitboxes(enemy):
		if shape is Dictionary:
			_draw_shape(shape, TREE_WOOD_SPIKE_COLOR, TREE_RANGE_LINE_WIDTH)


func _draw_shape(shape: Dictionary, color: Color, width: float) -> void:
	if shape.is_empty():
		return
	var center: Vector2 = shape.get("center", Vector2.ZERO)
	var horizontal_radius: float = max(0.0, float(shape.get("horizontal_radius", 0.0)))
	var vertical_radius: float = max(0.0, float(shape.get("vertical_radius", 0.0)))
	if horizontal_radius <= 0.0 or vertical_radius <= 0.0:
		return
	_draw_ellipse_outline(center, horizontal_radius, vertical_radius, color, width)


func _draw_ellipse_outline(center: Vector2, horizontal_radius: float, vertical_radius: float, color: Color, width: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for index in range(ELLIPSE_SEGMENTS + 1):
		var angle: float = TAU * float(index) / float(ELLIPSE_SEGMENTS)
		points.append(to_local(center + Vector2(cos(angle) * horizontal_radius, sin(angle) * vertical_radius)))
	draw_polyline(points, color, width, true)


func _get_runtime_enemies() -> Array:
	if battle_root != null and battle_root.has_method("get_runtime_enemies"):
		return battle_root.get_runtime_enemies()
	if battle_root != null and battle_root.get_tree() != null:
		return battle_root.get_tree().get_nodes_in_group("enemies")
	return []


func _get_kind_color(kind: String) -> Color:
	return KIND_COLORS.get(kind, Color(0.4, 0.9, 1.0, 0.72))


func _is_tree_glutton(enemy: Variant) -> bool:
	if enemy == null:
		return false
	return str(enemy.get("archetype_id")) == "smallboss_glutton" or str(enemy.get("behavior_id")) == "glutton"


func _should_draw_touch_damage_range(enemy: Node2D) -> bool:
	if enemy == null:
		return false
	if not _is_boss_or_small_boss(enemy):
		return false
	return float(enemy.get("touch_damage")) > 0.0


func _is_boss_or_small_boss(enemy: Node2D) -> bool:
	if enemy == null:
		return false
	var kind: String = str(enemy.get("enemy_kind"))
	return kind == "small_boss" or kind == "boss"


func _get_touch_damage_shape(enemy: Node2D) -> Dictionary:
	var shadow_shape: Dictionary = _get_shadow_world_ellipse(enemy)
	if not shadow_shape.is_empty():
		var scale: float = TOUCH_DAMAGE_SHADOW_RADIUS_SCALE * TOUCH_DAMAGE_CURRENT_SIZE_SCALE * _get_enemy_touch_damage_shape_multiplier(enemy)
		return _scale_touch_damage_shape(shadow_shape, scale)
	var fallback_radius: float = max(1.0, float(enemy.get("contact_radius"))) * TOUCH_DAMAGE_CURRENT_SIZE_SCALE
	return {
		"center": enemy.global_position,
		"horizontal_radius": fallback_radius,
		"vertical_radius": fallback_radius
	}


func _get_shadow_world_ellipse(enemy: Node2D) -> Dictionary:
	var visual: Node = enemy.get_node_or_null("ProfileVisual")
	if visual == null:
		visual = enemy.get_node_or_null("BossVisual")
	if visual != null and visual.has_method("get_shadow_world_ellipse"):
		var ellipse: Variant = visual.call("get_shadow_world_ellipse")
		if ellipse is Dictionary and not (ellipse as Dictionary).is_empty():
			return ellipse
	return {}


func _scale_touch_damage_shape(shape: Dictionary, radius_scale: float) -> Dictionary:
	return {
		"center": shape.get("center", Vector2.ZERO),
		"horizontal_radius": float(shape.get("horizontal_radius", 0.0)) * radius_scale,
		"vertical_radius": float(shape.get("vertical_radius", 0.0)) * radius_scale
	}


func _get_enemy_touch_damage_shape_multiplier(enemy: Node2D) -> float:
	match str(enemy.get("archetype_id")):
		"smallboss_glutton":
			return 0.5
		"smallboss_rebirth":
			return 0.6
		"boss_spellcore":
			return 0.5
	return 1.0
