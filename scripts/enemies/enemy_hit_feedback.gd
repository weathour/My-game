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
const KILL_DAMAGE_NUMBER_BUDGET_PER_FRAME := 6
const LOW_FPS_KILL_DAMAGE_NUMBER_BUDGET_PER_FRAME := 3
const CRITICAL_FPS_KILL_DAMAGE_NUMBER_BUDGET_PER_FRAME := 1
const DAMAGE_LABEL_POOL_LIMIT := 64
const DEATH_BURST_POOL_LIMIT := 32
const BOSS_HIT_FLASH_OVERLAY_NAME := "BossHitFlashOverlay"
const BOSS_HIT_FLASH_TOKEN_META := "boss_hit_flash_token"

static var damage_number_budget_frame: int = -1
static var damage_number_budget_used: int = 0
static var kill_damage_number_budget_frame: int = -1
static var kill_damage_number_budget_used: int = 0
static var death_burst_budget_frame: int = -1
static var death_burst_budget_used: int = 0
static var hit_flash_budget_frame: int = -1
static var hit_flash_budget_used: int = 0
static var boss_hit_flash_shader: Shader
static var damage_label_pool: Array = []
static var death_burst_pool: Array = []
static var active_damage_labels: Array[Dictionary] = []
static var active_death_bursts: Array[Dictionary] = []
static var feedback_animation_frame: int = -1

static func clear_runtime_state() -> void:
	damage_label_pool.clear()
	death_burst_pool.clear()
	active_damage_labels.clear()
	active_death_bursts.clear()
	feedback_animation_frame = -1

static func update_feedback_animations(delta: float) -> void:
	_update_static_feedback_animations(delta)

static func play_hit_feedback(enemy, damage_amount: float, killed: bool, is_critical: bool = false) -> void:
	_update_static_feedback_animations(1.0 / float(Engine.physics_ticks_per_second))
	if killed or _consume_hit_flash_budget():
		enemy.hit_flash_remaining = HIT_FLASH_DURATION
		_play_custom_hit_visual(enemy)
		_spawn_boss_hit_flash_overlay(enemy)
		if enemy.has_method("_update_status_visuals"):
			enemy._update_status_visuals()

	var can_show_damage_number := _consume_kill_damage_number_budget() if killed else _consume_damage_number_budget()
	if can_show_damage_number:
		show_damage_number(enemy, damage_amount, killed, is_critical)
	if killed and _consume_death_burst_budget():
		spawn_death_burst(enemy)

static func play_light_hit_feedback(enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	_update_static_feedback_animations(1.0 / float(Engine.physics_ticks_per_second))
	if not _consume_hit_flash_budget():
		return
	enemy.hit_flash_remaining = HIT_FLASH_DURATION
	_play_custom_hit_visual(enemy)
	_spawn_boss_hit_flash_overlay(enemy)
	if enemy.has_method("_update_status_visuals"):
		enemy._update_status_visuals()

static func _play_custom_hit_visual(enemy) -> void:
	var cached_visual: Node = enemy.get("cached_motion_visual") as Node
	if _is_valid_hit_visual(enemy, cached_visual) and cached_visual.has_method("play_hit"):
		cached_visual.play_hit()
		return
	var fallback_visual: Node = _find_hit_visual(enemy)
	if fallback_visual == null:
		return
	enemy.set("cached_motion_visual", fallback_visual)
	if fallback_visual.has_method("play_hit"):
		fallback_visual.play_hit()

static func _find_hit_visual(enemy) -> Node:
	for visual_name in ["MushroomVisual", "SlimeVisual", "FlyingEyeVisual", "PumpkinVisual"]:
		var visual: Node = enemy.get_node_or_null(visual_name)
		if _is_valid_hit_visual(enemy, visual) and visual.has_method("play_hit"):
			return visual
	return null

static func _is_valid_hit_visual(enemy, visual: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not (enemy is Node):
		return false
	if not (enemy as Node).is_inside_tree():
		return false
	if visual == null or not is_instance_valid(visual):
		return false
	if visual.is_queued_for_deletion() or not visual.is_inside_tree():
		return false
	return (enemy as Node).is_ancestor_of(visual)

static func get_hit_flash_alpha(hit_flash_remaining: float) -> float:
	if hit_flash_remaining <= 0.0:
		return 1.0
	var ratio: float = clamp(hit_flash_remaining / max(HIT_FLASH_DURATION, 0.001), 0.0, 1.0)
	return lerpf(1.0, HIT_FLASH_DIM_ALPHA, ratio)

static func apply_hit_flash_alpha_to_node(node: Node, alpha: float) -> void:
	if node is CanvasItem:
		var canvas_item := node as CanvasItem
		var color: Color = canvas_item.modulate
		var original_alpha: float = color.a
		var flash_strength: float = clamp(1.0 - alpha, 0.0, 1.0)
		color = color.lerp(Color.WHITE, flash_strength)
		color.a = original_alpha
		canvas_item.modulate = color
	for child in node.get_children():
		apply_hit_flash_alpha_to_node(child, alpha)

static func _spawn_boss_hit_flash_overlay(enemy) -> void:
	if not _should_apply_immediate_model_flash(enemy):
		return
	if enemy == null or not is_instance_valid(enemy) or not (enemy is Node):
		return
	var visual_root: Node = (enemy as Node).get_node_or_null("ProfileVisual")
	if visual_root == null and enemy.get("boss_visual_instance") != null:
		visual_root = enemy.get("boss_visual_instance") as Node
	if visual_root == null or not is_instance_valid(visual_root):
		return
	var source_sprites: Array[AnimatedSprite2D] = []
	_collect_boss_flash_sprites(visual_root, source_sprites)
	if source_sprites.is_empty():
		return
	for source_sprite: AnimatedSprite2D in source_sprites:
		_spawn_boss_hit_flash_overlay_for_sprite(source_sprite)

static func _spawn_boss_hit_flash_overlay_for_sprite(source_sprite: AnimatedSprite2D) -> void:
	if source_sprite == null or not is_instance_valid(source_sprite) or source_sprite.sprite_frames == null:
		return
	var current_frame_texture: Texture2D = source_sprite.sprite_frames.get_frame_texture(source_sprite.animation, source_sprite.frame)
	if current_frame_texture == null:
		return
	var overlay: Sprite2D = source_sprite.get_node_or_null(BOSS_HIT_FLASH_OVERLAY_NAME) as Sprite2D
	if overlay == null:
		overlay = Sprite2D.new()
		overlay.name = BOSS_HIT_FLASH_OVERLAY_NAME
		overlay.z_index = source_sprite.z_index + 20
		overlay.show_behind_parent = false
		source_sprite.add_child(overlay)
		overlay.material = _get_boss_hit_flash_material()
	overlay.texture = current_frame_texture
	overlay.centered = source_sprite.centered
	overlay.offset = source_sprite.offset
	overlay.flip_h = source_sprite.flip_h
	overlay.flip_v = source_sprite.flip_v
	overlay.position = Vector2.ZERO
	overlay.rotation = 0.0
	overlay.scale = Vector2.ONE
	overlay.modulate = Color(1.0, 1.0, 1.0, 0.7)
	overlay.visible = true
	var flash_token: int = int(overlay.get_meta(BOSS_HIT_FLASH_TOKEN_META, 0)) + 1
	overlay.set_meta(BOSS_HIT_FLASH_TOKEN_META, flash_token)
	var tween: Tween = overlay.create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, HIT_FLASH_DURATION)
	tween.tween_callback(func() -> void:
		if is_instance_valid(overlay) and int(overlay.get_meta(BOSS_HIT_FLASH_TOKEN_META, 0)) == flash_token:
			overlay.visible = false
	)

static func _get_boss_hit_flash_material() -> ShaderMaterial:
	if boss_hit_flash_shader == null:
		boss_hit_flash_shader = Shader.new()
		boss_hit_flash_shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec4 tex = texture(TEXTURE, UV);\n\tCOLOR = vec4(1.0, 1.0, 1.0, tex.a * COLOR.a);\n}\n"
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = boss_hit_flash_shader
	return material

static func _collect_boss_flash_sprites(root: Node, output: Array[AnimatedSprite2D]) -> void:
	if root is AnimatedSprite2D:
		var sprite: AnimatedSprite2D = root as AnimatedSprite2D
		if sprite.visible and not _is_shadow_flash_sprite(sprite):
			output.append(sprite)
	for child in root.get_children():
		_collect_boss_flash_sprites(child, output)

static func _is_shadow_flash_sprite(sprite: AnimatedSprite2D) -> bool:
	if sprite == null:
		return true
	var node: Node = sprite
	while node != null:
		if str(node.name).to_lower().contains("shadow"):
			return true
		node = node.get_parent()
	return false

static func _should_apply_immediate_model_flash(enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	var kind: String = str(enemy.get("enemy_kind"))
	return kind == "small_boss" or kind == "boss"

static func show_damage_number(enemy, damage_amount: float, killed: bool, is_critical: bool = false) -> void:
	var current_scene: Node = _get_enemy_current_scene(enemy)
	if current_scene == null:
		return
	if not _can_spawn_temporary_effect(current_scene):
		return

	var label := _acquire_damage_label(current_scene)
	label.text = str(int(round(damage_amount)))
	var label_color: Color = Color(1.0, 1.0, 1.0, 0.95)
	var label_font_size: int = 15
	if killed:
		label_color = Color(1.0, 0.95, 0.75, 1.0)
		label_font_size = 18
	if is_critical:
		label_color = Color(1.0, 0.58, 0.18, 1.0)
	label.modulate = label_color
	label.scale = Vector2.ONE
	label.add_theme_font_size_override("font_size", label_font_size)
	label.add_theme_constant_override("outline_size", 4 if is_critical else 0)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0) if is_critical else Color(0.0, 0.0, 0.0, 0.0))
	label.z_index = 20
	label.global_position = enemy.global_position + Vector2(-10.0, -28.0)

	var start_position: Vector2 = label.global_position
	active_damage_labels.append({
		"node": label,
		"elapsed": 0.0,
		"duration": 0.38,
		"start_position": start_position,
		"target_position": start_position + Vector2(randf_range(-10.0, 10.0), -28.0),
		"start_alpha": label.modulate.a
	})

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
	var fps := PERFORMANCE_GUARD.get_fps()
	if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return CRITICAL_FPS_DAMAGE_NUMBER_BUDGET_PER_FRAME
	if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return LOW_FPS_DAMAGE_NUMBER_BUDGET_PER_FRAME
	return DAMAGE_NUMBER_BUDGET_PER_FRAME

static func _consume_kill_damage_number_budget() -> bool:
	var current_frame := Engine.get_physics_frames()
	if kill_damage_number_budget_frame != current_frame:
		kill_damage_number_budget_frame = current_frame
		kill_damage_number_budget_used = 0
	if kill_damage_number_budget_used >= _get_kill_damage_number_budget_per_frame():
		return false
	kill_damage_number_budget_used += 1
	return true

static func _get_kill_damage_number_budget_per_frame() -> int:
	var fps := PERFORMANCE_GUARD.get_fps()
	if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return CRITICAL_FPS_KILL_DAMAGE_NUMBER_BUDGET_PER_FRAME
	if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return LOW_FPS_KILL_DAMAGE_NUMBER_BUDGET_PER_FRAME
	return KILL_DAMAGE_NUMBER_BUDGET_PER_FRAME

static func _get_death_burst_budget_per_frame() -> int:
	var fps := PERFORMANCE_GUARD.get_fps()
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
	var fps := PERFORMANCE_GUARD.get_fps()
	if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return CRITICAL_FPS_HIT_FLASH_BUDGET_PER_FRAME
	if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return LOW_FPS_HIT_FLASH_BUDGET_PER_FRAME
	return HIT_FLASH_BUDGET_PER_FRAME

static func spawn_death_burst(enemy) -> void:
	var current_scene: Node = _get_enemy_current_scene(enemy)
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
	active_death_bursts.append({
		"node": burst,
		"elapsed": 0.0,
		"duration": 0.16,
		"start_scale": Vector2(0.25, 0.25),
		"target_scale": Vector2(1.2, 1.2)
	})

static func _update_static_feedback_animations(delta: float) -> void:
	if delta <= 0.0:
		return
	var current_frame := Engine.get_process_frames()
	if feedback_animation_frame == current_frame:
		return
	feedback_animation_frame = current_frame
	_update_active_damage_labels(delta)
	_update_active_death_bursts(delta)

static func _update_active_damage_labels(delta: float) -> void:
	for index in range(active_damage_labels.size() - 1, -1, -1):
		var data: Dictionary = active_damage_labels[index]
		var label_ref: Variant = data.get("node", null)
		if not is_instance_valid(label_ref) or not (label_ref is Label):
			active_damage_labels.remove_at(index)
			continue
		var label := label_ref as Label
		if label.is_queued_for_deletion():
			active_damage_labels.remove_at(index)
			continue
		var elapsed: float = float(data.get("elapsed", 0.0)) + delta
		var duration: float = max(0.001, float(data.get("duration", 0.38)))
		var progress: float = clamp(elapsed / duration, 0.0, 1.0)
		label.global_position = (data.get("start_position", label.global_position) as Vector2).lerp(data.get("target_position", label.global_position) as Vector2, progress)
		label.modulate.a = float(data.get("start_alpha", 1.0)) * (1.0 - progress)
		if elapsed >= duration:
			active_damage_labels.remove_at(index)
			_release_damage_label(label)
			continue
		data["elapsed"] = elapsed
		active_damage_labels[index] = data

static func _update_active_death_bursts(delta: float) -> void:
	for index in range(active_death_bursts.size() - 1, -1, -1):
		var data: Dictionary = active_death_bursts[index]
		var burst_ref: Variant = data.get("node", null)
		if not is_instance_valid(burst_ref) or not (burst_ref is Polygon2D):
			active_death_bursts.remove_at(index)
			continue
		var burst := burst_ref as Polygon2D
		if burst.is_queued_for_deletion():
			active_death_bursts.remove_at(index)
			continue
		var elapsed: float = float(data.get("elapsed", 0.0)) + delta
		var duration: float = max(0.001, float(data.get("duration", 0.16)))
		var progress: float = clamp(elapsed / duration, 0.0, 1.0)
		burst.scale = (data.get("start_scale", Vector2.ONE) as Vector2).lerp(data.get("target_scale", Vector2.ONE) as Vector2, progress)
		burst.modulate.a = 1.0 - progress
		if elapsed >= duration:
			active_death_bursts.remove_at(index)
			_release_death_burst(burst)
			continue
		data["elapsed"] = elapsed
		active_death_bursts[index] = data

static func _acquire_damage_label(current_scene: Node) -> Label:
	while not damage_label_pool.is_empty():
		var pooled_label: Variant = damage_label_pool.pop_back()
		if is_instance_valid(pooled_label) and pooled_label is Label:
			var label := pooled_label as Label
			if label.is_queued_for_deletion():
				continue
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
	if damage_label_pool.size() < DAMAGE_LABEL_POOL_LIMIT and not damage_label_pool.has(label):
		damage_label_pool.append(label)
	else:
		label.queue_free()

static func _acquire_death_burst(current_scene: Node) -> Polygon2D:
	while not death_burst_pool.is_empty():
		var pooled_burst: Variant = death_burst_pool.pop_back()
		if is_instance_valid(pooled_burst) and pooled_burst is Polygon2D:
			var burst := pooled_burst as Polygon2D
			if burst.is_queued_for_deletion():
				continue
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
	if death_burst_pool.size() < DEATH_BURST_POOL_LIMIT and not death_burst_pool.has(burst):
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

static func _get_enemy_current_scene(enemy) -> Node:
	if enemy == null or not is_instance_valid(enemy):
		return null
	if enemy is Node and not (enemy as Node).is_inside_tree():
		return null
	var tree: SceneTree = enemy.get_tree()
	if tree == null:
		return null
	return tree.current_scene

static func _can_spawn_temporary_effect(root: Node) -> bool:
	if root != null and root.has_method("_can_spawn_runtime_group"):
		var limit: int = PERFORMANCE_GUARD.get_dynamic_limit(root, "temporary_effects", PERFORMANCE_GUARD.DEFAULT_TEMPORARY_EFFECT_LIMIT)
		return bool(root._can_spawn_runtime_group("temporary_effects", limit))
	return true
