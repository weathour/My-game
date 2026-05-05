extends RefCounted

const HIT_FLASH_DURATION := 0.18
const HIT_FLASH_DIM_ALPHA := 0.26
const DAMAGE_NUMBER_BUDGET_PER_FRAME := 28
const DEATH_BURST_BUDGET_PER_FRAME := 20

static var damage_number_budget_frame: int = -1
static var damage_number_budget_used: int = 0
static var death_burst_budget_frame: int = -1
static var death_burst_budget_used: int = 0

static func play_hit_feedback(enemy, damage_amount: float, killed: bool) -> void:
	enemy.hit_flash_remaining = HIT_FLASH_DURATION

	if killed or _consume_damage_number_budget():
		show_damage_number(enemy, damage_amount, killed)
	if killed and _consume_death_burst_budget():
		spawn_death_burst(enemy)

static func get_hit_flash_alpha(hit_flash_remaining: float) -> float:
	if hit_flash_remaining <= 0.0:
		return 1.0
	var ratio: float = clamp(hit_flash_remaining / max(HIT_FLASH_DURATION, 0.001), 0.0, 1.0)
	return lerpf(1.0, HIT_FLASH_DIM_ALPHA, ratio)

static func apply_hit_flash_alpha_to_node(node: Node, alpha: float) -> void:
	if node is CanvasItem:
		var canvas_item := node as CanvasItem
		var color := canvas_item.modulate
		color.a = alpha
		canvas_item.modulate = color
	for child in node.get_children():
		apply_hit_flash_alpha_to_node(child, alpha)

static func show_damage_number(enemy, damage_amount: float, killed: bool) -> void:
	var current_scene = enemy.get_tree().current_scene
	if current_scene == null:
		return
	if not killed and not _can_spawn_temporary_effect(current_scene):
		return

	var label := Label.new()
	label.add_to_group("temporary_effects")
	label.text = str(int(round(damage_amount)))
	var label_color: Color = Color(1.0, 1.0, 1.0, 0.95)
	var label_font_size: int = 15
	if killed:
		label_color = Color(1.0, 0.95, 0.75, 1.0)
		label_font_size = 18
	label.modulate = label_color
	label.add_theme_font_size_override("font_size", label_font_size)
	label.z_index = 20
	current_scene.add_child(label)
	label.global_position = enemy.global_position + Vector2(-10.0, -28.0)

	var target_position: Vector2 = label.global_position + Vector2(randf_range(-10.0, 10.0), -28.0)
	var tween := label.create_tween()
	tween.parallel().tween_property(label, "global_position", target_position, 0.38)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.38)
	tween.tween_callback(label.queue_free)

static func _consume_damage_number_budget() -> bool:
	var current_frame := Engine.get_physics_frames()
	if damage_number_budget_frame != current_frame:
		damage_number_budget_frame = current_frame
		damage_number_budget_used = 0
	if damage_number_budget_used >= DAMAGE_NUMBER_BUDGET_PER_FRAME:
		return false
	damage_number_budget_used += 1
	return true

static func _consume_death_burst_budget() -> bool:
	var current_frame := Engine.get_physics_frames()
	if death_burst_budget_frame != current_frame:
		death_burst_budget_frame = current_frame
		death_burst_budget_used = 0
	if death_burst_budget_used >= DEATH_BURST_BUDGET_PER_FRAME:
		return false
	death_burst_budget_used += 1
	return true

static func spawn_death_burst(enemy) -> void:
	var current_scene = enemy.get_tree().current_scene
	if current_scene == null:
		return
	if not _can_spawn_temporary_effect(current_scene):
		return

	var burst := Polygon2D.new()
	burst.add_to_group("temporary_effects")
	burst.global_position = enemy.global_position
	burst.z_index = 14
	burst.color = Color(1.0, 0.88, 0.65, 0.75)
	burst.polygon = PackedVector2Array([
		Vector2(0.0, -18.0),
		Vector2(18.0, 0.0),
		Vector2(0.0, 18.0),
		Vector2(-18.0, 0.0)
	])
	current_scene.add_child(burst)

	burst.scale = Vector2(0.25, 0.25)
	var tween := burst.create_tween()
	tween.parallel().tween_property(burst, "scale", Vector2(1.2, 1.2), 0.16)
	tween.parallel().tween_property(burst, "modulate:a", 0.0, 0.16)
	tween.tween_callback(burst.queue_free)

static func _can_spawn_temporary_effect(root: Node) -> bool:
	if root != null and root.has_method("_can_spawn_runtime_group"):
		return bool(root._can_spawn_runtime_group("temporary_effects", 160))
	return true
