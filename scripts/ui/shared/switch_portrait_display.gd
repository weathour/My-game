extends Control

const COOLDOWN_REDRAW_EPSILON: float = 0.01
const ENERGY_REDRAW_EPSILON: float = 0.0001
const ENERGY_READY_RATIO_EPSILON: float = 0.001
const SWITCH_COOLDOWN_MASK_RADIUS_SCALE := 0.34
const SWITCH_COOLDOWN_MASK_RADIUS_EXTRA := 0.2
const SWITCH_COOLDOWN_MASK_OFFSET := Vector2(0.0, 2.0)
const SWITCH_PORTRAIT_CONTENT_DIAMETER_SCALE := 1.0
const SWITCH_PORTRAIT_CONTENT_OFFSET := Vector2(0.0, 0.0)
const SWITCH_PORTRAIT_SIDE_CONTENT_OFFSET := Vector2(1.0, 2.0)
const SWITCH_PORTRAIT_SWORDSMAN_CONTENT_OFFSET := Vector2(-1.0, -2.5)
const SWITCH_PORTRAIT_GUNNER_CONTENT_OFFSET := Vector2(0.0, -1.0)
const SWITCH_PORTRAIT_MAGE_CONTENT_OFFSET := Vector2(0.0, -2.5)
const SWITCH_PORTRAIT_SOFT_OUTLINE_STEPS := 5
const SWITCH_PORTRAIT_SOFT_OUTLINE_SPACING := 2.0
const SWITCH_PORTRAIT_ALPHA_CROP_THRESHOLD := 0.02

class CirclePlate:
	extends Control

	var active: bool = false
	var draw_fill: bool = true
	var energy_ratio: float = 0.0

	func set_visual_state(new_active: bool, new_energy_ratio: float) -> void:
		var resolved_energy_ratio: float = clamp(new_energy_ratio, 0.0, 1.0)
		if resolved_energy_ratio >= 1.0 - ENERGY_READY_RATIO_EPSILON:
			resolved_energy_ratio = 1.0
		if active == new_active and abs(resolved_energy_ratio - energy_ratio) <= ENERGY_REDRAW_EPSILON:
			return
		active = new_active
		energy_ratio = resolved_energy_ratio
		queue_redraw()

	func set_draw_fill(new_draw_fill: bool) -> void:
		if draw_fill == new_draw_fill:
			return
		draw_fill = new_draw_fill
		queue_redraw()

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = min(size.x, size.y) * 0.5 * SWITCH_COOLDOWN_MASK_RADIUS_SCALE + SWITCH_COOLDOWN_MASK_RADIUS_EXTRA
		var base_color := Color(0.04, 0.045, 0.052, 0.94)
		var inner_color := Color(0.15, 0.13, 0.12, 0.92) if active else Color(0.08, 0.08, 0.09, 0.82)
		if draw_fill:
			_draw_soft_outline(center, radius, active)
			draw_circle(center, radius + 4.0, base_color)
			draw_circle(center, radius, inner_color)
		_draw_energy_ring(center, radius + 1.5)

	func _draw_soft_outline(center: Vector2, radius: float, is_active: bool) -> void:
		var glow_color := Color(0.36, 0.78, 1.0, 0.30) if is_active else Color(0.12, 0.16, 0.2, 0.16)
		for step in range(SWITCH_PORTRAIT_SOFT_OUTLINE_STEPS):
			var progress: float = float(step + 1) / float(SWITCH_PORTRAIT_SOFT_OUTLINE_STEPS)
			var outline_radius: float = radius + 4.0 + progress * SWITCH_PORTRAIT_SOFT_OUTLINE_SPACING * float(SWITCH_PORTRAIT_SOFT_OUTLINE_STEPS)
			var alpha: float = glow_color.a * (1.0 - progress)
			draw_arc(center, outline_radius, 0.0, TAU, 72, Color(glow_color.r, glow_color.g, glow_color.b, alpha), 2.0)

	func _draw_energy_ring(center: Vector2, radius: float) -> void:
		if not active or energy_ratio <= 0.001:
			return
		var pulse: float = 0.0
		if energy_ratio >= 0.999:
			pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0056)
		var ring_width: float = 3.0 + pulse * 1.2
		var ring_color := Color(0.28, 0.72, 1.0, 0.88)
		if energy_ratio >= 0.999:
			ring_color = Color(0.72, 0.92, 1.0, 0.78 + pulse * 0.22)
			_draw_full_energy_ring(center, radius, ring_color, ring_width)
			_draw_full_energy_ring(center, radius + 4.0 + pulse * 2.0, Color(0.55, 0.86, 1.0, 0.24 + pulse * 0.22), 2.0 + pulse)
			return
		var end_angle: float = -PI * 0.5 + TAU * clamp(energy_ratio, 0.0, 0.995)
		draw_arc(center, radius, -PI * 0.5, end_angle, 72, ring_color, ring_width)

	func _draw_full_energy_ring(center: Vector2, radius: float, ring_color: Color, ring_width: float) -> void:
		var overlap: float = 0.035
		for index in range(4):
			var start_angle: float = -PI * 0.5 + float(index) * PI * 0.5 - overlap
			var end_angle: float = start_angle + PI * 0.5 + overlap * 2.0
			draw_arc(center, radius, start_angle, end_angle, 28, ring_color, ring_width)

class CooldownMask:
	extends Control

	var cooldown_ratio: float = 0.0
	var active: bool = false

	func set_state(new_active: bool, new_cooldown_ratio: float) -> void:
		var resolved_ratio: float = clamp(new_cooldown_ratio, 0.0, 1.0)
		if active == new_active and abs(resolved_ratio - cooldown_ratio) <= COOLDOWN_REDRAW_EPSILON:
			return
		active = new_active
		cooldown_ratio = resolved_ratio
		queue_redraw()

	func _draw() -> void:
		if not active or cooldown_ratio <= 0.01:
			return
		var center: Vector2 = size * 0.5 + SWITCH_COOLDOWN_MASK_OFFSET
		var radius: float = min(size.x, size.y) * 0.5 * SWITCH_COOLDOWN_MASK_RADIUS_SCALE + SWITCH_COOLDOWN_MASK_RADIUS_EXTRA
		var shade := Color(0.0, 0.0, 0.0, 0.62)
		if cooldown_ratio >= 0.99:
			draw_circle(center, radius, shade)
			return
		var angle_total: float = TAU * cooldown_ratio
		var steps: int = max(6, int(ceil(32.0 * cooldown_ratio)))
		var points := PackedVector2Array()
		points.append(center)
		for step in range(steps + 1):
			var progress: float = float(step) / float(steps)
			var angle: float = -PI * 0.5 + angle_total * progress
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(points, shade)

var cooldown_ratio: float = 0.0
var energy_ratio: float = 0.0
var ready_pulse_time: float = 0.0
var active: bool = false
var role_id: String = ""
var circle_back_plate: CirclePlate
var circle_front_plate: CirclePlate
var head_node: Node2D
var head_sprite: Sprite2D
var head_texture_rect: TextureRect
var cooldown_mask: CooldownMask
var base_visual_scale: float = 1.0

func _ready() -> void:
	_update_processing()

func _update_processing() -> void:
	set_process(energy_ratio >= 0.999 and is_visible_in_tree())

func _process(delta: float) -> void:
	if energy_ratio < 0.999:
		return
	ready_pulse_time += delta
	_update_head_visual()
	for plate in [circle_back_plate, circle_front_plate]:
		if plate != null:
			plate.queue_redraw()

func set_role_scene(new_role_id: String, head_scene: PackedScene) -> void:
	if role_id == new_role_id and head_node != null:
		return
	role_id = new_role_id
	_ensure_circle_plates()
	if head_node != null:
		head_node.queue_free()
		head_node = null
		head_sprite = null
		head_texture_rect = null
	if head_scene != null:
		head_node = head_scene.instantiate() as Node2D
		if head_node != null:
			add_child(head_node)
			head_sprite = head_node.find_child("Sprite2D", true, false) as Sprite2D
			head_texture_rect = head_node.find_child("TextureRect", true, false) as TextureRect
			_crop_texture_rect_to_visible_content()
			if head_sprite != null:
				head_sprite.centered = true
				head_sprite.position = Vector2.ZERO
			_fit_head_node()
	_ensure_cooldown_mask()
	_update_head_visual()

func set_state(new_cooldown_ratio: float, new_energy_ratio: float, new_active: bool) -> void:
	var resolved_cooldown_ratio: float = clamp(new_cooldown_ratio, 0.0, 1.0)
	var resolved_energy_ratio: float = clamp(new_energy_ratio, 0.0, 1.0)
	if resolved_energy_ratio >= 1.0 - ENERGY_READY_RATIO_EPSILON:
		resolved_energy_ratio = 1.0
	var ready_changed: bool = resolved_energy_ratio >= 0.999 and energy_ratio < 0.999
	if active == new_active and not ready_changed and abs(resolved_cooldown_ratio - cooldown_ratio) <= COOLDOWN_REDRAW_EPSILON and abs(resolved_energy_ratio - energy_ratio) <= ENERGY_REDRAW_EPSILON:
		return
	cooldown_ratio = resolved_cooldown_ratio
	energy_ratio = resolved_energy_ratio
	active = new_active
	_update_processing()
	_update_head_visual()
	if cooldown_mask != null:
		cooldown_mask.set_state(active, cooldown_ratio)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_head_node()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		_update_processing()

func _fit_head_node() -> void:
	if head_node == null:
		return
	var circle_radius: float = min(size.x, size.y) * 0.5 * SWITCH_COOLDOWN_MASK_RADIUS_SCALE + SWITCH_COOLDOWN_MASK_RADIUS_EXTRA
	var content_size: Vector2 = Vector2.ONE * circle_radius * 2.0 * SWITCH_PORTRAIT_CONTENT_DIAMETER_SCALE
	var content_position: Vector2 = size * 0.5 - content_size * 0.5 + SWITCH_COOLDOWN_MASK_OFFSET + SWITCH_PORTRAIT_CONTENT_OFFSET
	if role_id == "swordsman" or role_id == "mage":
		content_position += SWITCH_PORTRAIT_SIDE_CONTENT_OFFSET
	if role_id == "swordsman":
		content_position += SWITCH_PORTRAIT_SWORDSMAN_CONTENT_OFFSET
	elif role_id == "gunner":
		content_position += SWITCH_PORTRAIT_GUNNER_CONTENT_OFFSET
	elif role_id == "mage":
		content_position += SWITCH_PORTRAIT_MAGE_CONTENT_OFFSET
	var texture_size: Vector2 = Vector2(96.0, 96.0)
	for plate in [circle_back_plate, circle_front_plate]:
		if plate == null:
			continue
		plate.position = Vector2.ZERO
		plate.size = size
		plate.custom_minimum_size = size
	if head_texture_rect != null:
		head_node.position = content_position
		head_node.scale = Vector2.ONE
		head_texture_rect.anchor_left = 0.0
		head_texture_rect.anchor_top = 0.0
		head_texture_rect.anchor_right = 0.0
		head_texture_rect.anchor_bottom = 0.0
		head_texture_rect.position = Vector2.ZERO
		head_texture_rect.size = content_size
		head_texture_rect.custom_minimum_size = content_size
		head_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		head_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		head_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif head_sprite != null and head_sprite.texture != null:
		head_node.position = size * 0.5
		texture_size = head_sprite.texture.get_size()
		var max_dimension: float = max(texture_size.x, texture_size.y)
		base_visual_scale = min(content_size.x, content_size.y) / max(max_dimension, 1.0)
	if cooldown_mask != null:
		cooldown_mask.position = Vector2.ZERO
		cooldown_mask.size = size
		cooldown_mask.custom_minimum_size = size
	_update_head_visual()

func _crop_texture_rect_to_visible_content() -> void:
	if head_texture_rect == null or head_texture_rect.texture == null:
		return
	var source_texture: Texture2D = head_texture_rect.texture
	var image: Image = source_texture.get_image()
	if image == null or image.is_empty():
		return
	var min_x: int = image.get_width()
	var min_y: int = image.get_height()
	var max_x: int = -1
	var max_y: int = -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= SWITCH_PORTRAIT_ALPHA_CROP_THRESHOLD:
				continue
			min_x = min(min_x, x)
			min_y = min(min_y, y)
			max_x = max(max_x, x)
			max_y = max(max_y, y)
	if max_x < min_x or max_y < min_y:
		return
	var crop_region: Rect2 = Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	var cropped_texture: AtlasTexture = AtlasTexture.new()
	cropped_texture.atlas = source_texture
	cropped_texture.region = crop_region
	head_texture_rect.texture = cropped_texture

func _ensure_circle_plates() -> void:
	if circle_back_plate != null and circle_front_plate != null:
		return
	if circle_back_plate == null:
		circle_back_plate = CirclePlate.new()
		circle_back_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		circle_back_plate.z_index = -1
		circle_back_plate.set_draw_fill(true)
		add_child(circle_back_plate)
	if circle_front_plate == null:
		circle_front_plate = CirclePlate.new()
		circle_front_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		circle_front_plate.z_index = 14
		circle_front_plate.set_draw_fill(false)
		add_child(circle_front_plate)
	for plate in [circle_back_plate, circle_front_plate]:
		plate.position = Vector2.ZERO
		plate.size = size
		plate.custom_minimum_size = size

func _ensure_cooldown_mask() -> void:
	if cooldown_mask != null:
		return
	cooldown_mask = CooldownMask.new()
	cooldown_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_mask.z_index = 10
	add_child(cooldown_mask)
	cooldown_mask.position = Vector2.ZERO
	cooldown_mask.size = size
	cooldown_mask.custom_minimum_size = size
	cooldown_mask.set_state(active, cooldown_ratio)

func _update_head_visual() -> void:
	if head_node == null:
		return
	var pulse: float = 0.0
	if energy_ratio >= 0.999:
		pulse = 0.04 + 0.04 * sin(ready_pulse_time * 5.6)
	var target_alpha: float = 1.0 if active else 0.58
	for plate in [circle_back_plate, circle_front_plate]:
		if plate != null:
			plate.set_visual_state(active, energy_ratio)
	if head_texture_rect != null:
		head_node.scale = Vector2.ONE
		head_texture_rect.modulate = Color(1.0, 1.0, 1.0, target_alpha)
		return
	var target_scale: float = 1.0 + pulse
	head_node.scale = Vector2.ONE * base_visual_scale * target_scale
	head_node.modulate = Color(1.0, 1.0, 1.0, target_alpha)
