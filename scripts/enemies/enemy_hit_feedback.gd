extends RefCounted

const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")
const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")

const HIT_FLASH_DURATION := 0.18
const HIT_FLASH_DIM_ALPHA := 0.26
const DAMAGE_NUMBER_BUDGET_PER_FRAME := 12
const DEATH_BURST_BUDGET_PER_FRAME := 8
const LOW_FPS_DAMAGE_NUMBER_BUDGET_PER_FRAME := 6
const CRITICAL_FPS_DAMAGE_NUMBER_BUDGET_PER_FRAME := 3
const LOW_FPS_DEATH_BURST_BUDGET_PER_FRAME := 4
const CRITICAL_FPS_DEATH_BURST_BUDGET_PER_FRAME := 2
const HIT_FLASH_BUDGET_PER_FRAME := 28
const LOW_FPS_HIT_FLASH_BUDGET_PER_FRAME := 12
const CRITICAL_FPS_HIT_FLASH_BUDGET_PER_FRAME := 5
const DAMAGE_LABEL_POOL_LIMIT := 64
const DEATH_BURST_POOL_LIMIT := 32

static var damage_number_budget_frame: int = -1
static var damage_number_budget_used: int = 0
static var death_burst_budget_frame: int = -1
static var death_burst_budget_used: int = 0
static var hit_flash_budget_frame: int = -1
static var hit_flash_budget_used: int = 0
static var damage_label_pool: Array = []
static var death_burst_pool: Array = []

static func play_hit_feedback(enemy, damage_amount: float, killed: bool) -> void:
	if killed or _consume_hit_flash_budget():
		enemy.hit_flash_remaining = HIT_FLASH_DURATION
		_play_custom_hit_visual(enemy)

	if killed or _consume_damage_number_budget():
		show_damage_number(enemy, damage_amount, killed)
	if killed and _consume_death_burst_budget():
		spawn_death_burst(enemy)

static func _play_custom_hit_visual(enemy) -> void:
	var mushroom_visual: Node = enemy.get_node_or_null("MushroomVisual")
	if mushroom_visual != null and mushroom_visual.has_method("play_hit"):
		mushroom_visual.play_hit()
	var slime_visual: Node = enemy.get_node_or_null("SlimeVisual")
	if slime_visual != null and slime_visual.has_method("play_hit"):
		slime_visual.play_hit()
	var flying_eye_visual: Node = enemy.get_node_or_null("FlyingEyeVisual")
	if flying_eye_visual != null and flying_eye_visual.has_method("play_hit"):
		flying_eye_visual.play_hit()

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

	var label := _acquire_damage_label(current_scene)
	label.text = str(int(round(damage_amount)))
	var label_color: Color = Color(1.0, 1.0, 1.0, 0.95)
	var label_font_size: int = 15
	if killed:
		label_color = Color(1.0, 0.95, 0.75, 1.0)
		label_font_size = 18
	label.modulate = label_color
	label.scale = Vector2.ONE
	label.add_theme_font_size_override("font_size", label_font_size)
	label.z_index = 20
	label.global_position = enemy.global_position + Vector2(-10.0, -28.0)

	var target_position: Vector2 = label.global_position + Vector2(randf_range(-10.0, 10.0), -28.0)
	var tween := label.create_tween()
	tween.parallel().tween_property(label, "global_position", target_position, 0.38)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.38)
	tween.tween_callback(_release_damage_label.bind(label))

static func _consume_damage_number_budget() -> bool:
	var current_frame := Engine.get_physics_frames()
	if damage_number_budget_frame != current_frame:
		damage_number_budget_frame = current_frame
		damage_number_budget_used = 0
	if damage_number_budget_used >= _get_damage_number_budget_per_frame():
		return false
	damage_number_budget_used += 1
	return true

static func _consume_death_burst_budget() -> bool:
	var current_frame := Engine.get_physics_frames()
	if death_burst_budget_frame != current_frame:
		death_burst_budget_frame = current_frame
		death_burst_budget_used = 0
	if death_burst_budget_used >= _get_death_burst_budget_per_frame():
		return false
	death_burst_budget_used += 1
	return true

static func _get_damage_number_budget_per_frame() -> int:
	var fps := Engine.get_frames_per_second()
	if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return CRITICAL_FPS_DAMAGE_NUMBER_BUDGET_PER_FRAME
	if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return LOW_FPS_DAMAGE_NUMBER_BUDGET_PER_FRAME
	return DAMAGE_NUMBER_BUDGET_PER_FRAME

static func _get_death_burst_budget_per_frame() -> int:
	var fps := Engine.get_frames_per_second()
	if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return CRITICAL_FPS_DEATH_BURST_BUDGET_PER_FRAME
	if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return LOW_FPS_DEATH_BURST_BUDGET_PER_FRAME
	return DEATH_BURST_BUDGET_PER_FRAME

static func _consume_hit_flash_budget() -> bool:
	var current_frame := Engine.get_physics_frames()
	if hit_flash_budget_frame != current_frame:
		hit_flash_budget_frame = current_frame
		hit_flash_budget_used = 0
	if hit_flash_budget_used >= _get_hit_flash_budget_per_frame():
		PERFORMANCE_COUNTERS.add("suppressed_hit_flash", 1)
		return false
	hit_flash_budget_used += 1
	return true

static func _get_hit_flash_budget_per_frame() -> int:
	var fps := Engine.get_frames_per_second()
	if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return CRITICAL_FPS_HIT_FLASH_BUDGET_PER_FRAME
	if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return LOW_FPS_HIT_FLASH_BUDGET_PER_FRAME
	return HIT_FLASH_BUDGET_PER_FRAME

static func spawn_death_burst(enemy) -> void:
	var current_scene = enemy.get_tree().current_scene
	if current_scene == null:
		return
	if not _can_spawn_temporary_effect(current_scene):
		return

	var burst := _acquire_death_burst(current_scene)
	burst.global_position = enemy.global_position
	burst.z_index = 14
	burst.color = Color(1.0, 0.88, 0.65, 0.75)
	burst.modulate = Color.WHITE
	burst.polygon = PackedVector2Array([
		Vector2(0.0, -18.0),
		Vector2(18.0, 0.0),
		Vector2(0.0, 18.0),
		Vector2(-18.0, 0.0)
	])

	burst.scale = Vector2(0.25, 0.25)
	var tween := burst.create_tween()
	tween.parallel().tween_property(burst, "scale", Vector2(1.2, 1.2), 0.16)
	tween.parallel().tween_property(burst, "modulate:a", 0.0, 0.16)
	tween.tween_callback(_release_death_burst.bind(burst))

static func _acquire_damage_label(current_scene: Node) -> Label:
	while not damage_label_pool.is_empty():
		var pooled_label: Variant = damage_label_pool.pop_back()
		if is_instance_valid(pooled_label) and pooled_label is Label:
			var label := pooled_label as Label
			_prepare_pooled_node(label, current_scene)
			return label
	var label := Label.new()
	current_scene.add_child(label)
	label.add_to_group("temporary_effects")
	return label

static func _release_damage_label(label: Label) -> void:
	if label == null or not is_instance_valid(label):
		return
	label.hide()
	label.remove_from_group("temporary_effects")
	if damage_label_pool.size() < DAMAGE_LABEL_POOL_LIMIT:
		damage_label_pool.append(label)
	else:
		label.queue_free()

static func _acquire_death_burst(current_scene: Node) -> Polygon2D:
	while not death_burst_pool.is_empty():
		var pooled_burst: Variant = death_burst_pool.pop_back()
		if is_instance_valid(pooled_burst) and pooled_burst is Polygon2D:
			var burst := pooled_burst as Polygon2D
			_prepare_pooled_node(burst, current_scene)
			return burst
	var burst := Polygon2D.new()
	current_scene.add_child(burst)
	burst.add_to_group("temporary_effects")
	return burst

static func _release_death_burst(burst: Polygon2D) -> void:
	if burst == null or not is_instance_valid(burst):
		return
	burst.hide()
	burst.remove_from_group("temporary_effects")
	if death_burst_pool.size() < DEATH_BURST_POOL_LIMIT:
		death_burst_pool.append(burst)
	else:
		burst.queue_free()

static func _prepare_pooled_node(node: Node, current_scene: Node) -> void:
	var parent := node.get_parent()
	if parent != current_scene:
		if parent != null:
			parent.remove_child(node)
		current_scene.add_child(node)
	node.show()
	node.add_to_group("temporary_effects")

static func _can_spawn_temporary_effect(root: Node) -> bool:
	if root != null and root.has_method("_can_spawn_runtime_group"):
		var limit: int = PERFORMANCE_GUARD.get_dynamic_limit(root, "temporary_effects", PERFORMANCE_GUARD.DEFAULT_TEMPORARY_EFFECT_LIMIT)
		return bool(root._can_spawn_runtime_group("temporary_effects", limit))
	return true
