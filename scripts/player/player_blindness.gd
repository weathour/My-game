extends CanvasLayer

const DURATION := 2.5
const TRIGGER_COOLDOWN := 10.0
const SIGHT_RADIUS := 60.0
const MASK_SHADER := preload("res://shaders/blindness_mask.gdshader")
const NODE_NAME := "PlayerBlindness"

var remaining: float = 0.0
var cooldown_remaining: float = 0.0
var mask: ColorRect


static func get_effect(player: Node):
	return player.get_node_or_null(NodePath(NODE_NAME))


static func ensure_effect(player: Node):
	var effect = get_effect(player)
	if effect == null:
		effect = load("res://scripts/player/player_blindness.gd").new()
		effect.name = NODE_NAME
		player.add_child(effect)
	return effect


static func on_enemy_damage(player: Node, enemy: Node, damage: float) -> void:
	if damage <= 0.0 or enemy == null or not is_instance_valid(enemy):
		return
	if str(enemy.get("archetype_id")) == "swarm":
		ensure_effect(player).try_apply()


static func save_state(player: Node) -> Dictionary:
	var effect = get_effect(player)
	if effect == null:
		return {}
	return {"remaining": effect.remaining, "cooldown_remaining": effect.cooldown_remaining}


static func restore_state(player: Node, data: Dictionary) -> void:
	if data.is_empty() and get_effect(player) == null:
		return
	var effect = ensure_effect(player)
	effect.remaining = clampf(float(data.get("remaining", 0.0)), 0.0, DURATION)
	effect.cooldown_remaining = clampf(float(data.get("cooldown_remaining", 0.0)), 0.0, TRIGGER_COOLDOWN)
	effect._sync_mask()


static func cleanse(player: Node) -> void:
	var effect = get_effect(player)
	if effect != null:
		effect.remaining = 0.0
		effect._sync_mask()


func _ready() -> void:
	# Above the world canvas, below the HUD (layer 1).
	layer = 0
	mask = ColorRect.new()
	mask.name = "BlindnessMask"
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = MASK_SHADER
	mask.material = shader_material
	add_child(mask)
	_sync_mask()


func try_apply() -> bool:
	if remaining > 0.0 or cooldown_remaining > 0.0:
		return false
	remaining = DURATION
	cooldown_remaining = TRIGGER_COOLDOWN
	_sync_mask()
	return true


func tick(delta: float) -> void:
	remaining = max(0.0, remaining - delta)
	cooldown_remaining = max(0.0, cooldown_remaining - delta)


func _process(delta: float) -> void:
	var player = get_parent()
	if player.get("is_dead") == true:
		remaining = 0.0
	tick(delta)
	_sync_mask()


func _sync_mask() -> void:
	if mask == null:
		return
	mask.visible = remaining > 0.0
	if not mask.visible:
		return
	var player := get_parent() as Node2D
	if player == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	mask.size = viewport_size
	var inverse := player.get_canvas_transform().affine_inverse()
	var shader_material := mask.material as ShaderMaterial
	shader_material.set_shader_parameter("viewport_size", viewport_size)
	shader_material.set_shader_parameter("screen_to_world_x", inverse.x)
	shader_material.set_shader_parameter("screen_to_world_y", inverse.y)
	shader_material.set_shader_parameter("world_origin", inverse.origin)
	shader_material.set_shader_parameter("player_position", player.global_position)
	shader_material.set_shader_parameter("sight_radius", SIGHT_RADIUS)
