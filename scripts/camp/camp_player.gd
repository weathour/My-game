extends CharacterBody2D

const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const ROLE_VISUALS := {
	"swordsman": {
		"scene": preload("res://assets/players/sword/sword.tscn"),
		"scale": Vector2(1.0, 1.0)
	},
	"gunner": {
		"scene": preload("res://assets/players/gun/gun.tscn"),
		"scale": Vector2(1.0, 1.0)
	},
	"mage": {
		"scene": preload("res://assets/players/wizard/wizard.tscn"),
		"scale": Vector2(1.7, 1.7)
	},
	"mechanic": {
		"scene": preload("res://assets/players/mechanic/mechanic.tscn"),
		"scale": Vector2(1.0, 1.0)
	}
}

@export var move_speed: float = 260.0
@export var movement_bounds: Rect2 = Rect2(Vector2(-600.0, -360.0), Vector2(1200.0, 720.0))

@onready var visual_root: Node2D = $VisualRoot
@onready var camera: Camera2D = $Camera2D

var role_visual: Node2D
var facing_sign: float = 1.0

func _ready() -> void:
	add_to_group("camp_player")
	role_visual = visual_root.get_node_or_null("RoleVisual") as Node2D
	_apply_camera_limits()
	_set_running(false)

func set_role_visual(role_id: String) -> void:
	var visual_data: Dictionary = ROLE_VISUALS.get(role_id, ROLE_VISUALS["swordsman"])
	var visual_scene := visual_data.get("scene") as PackedScene
	if visual_scene == null:
		return
	if role_visual != null and is_instance_valid(role_visual):
		role_visual.queue_free()
	role_visual = visual_scene.instantiate() as Node2D
	if role_visual == null:
		return
	role_visual.name = "RoleVisual"
	role_visual.scale = visual_data.get("scale", Vector2.ONE)
	visual_root.add_child(role_visual)
	_set_running(false)

func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO
	if GAME_SETTINGS.is_action_pressed(GAME_SETTINGS.ACTION_MOVE_LEFT):
		direction.x -= 1.0
	if GAME_SETTINGS.is_action_pressed(GAME_SETTINGS.ACTION_MOVE_RIGHT):
		direction.x += 1.0
	if GAME_SETTINGS.is_action_pressed(GAME_SETTINGS.ACTION_MOVE_UP):
		direction.y -= 1.0
	if GAME_SETTINGS.is_action_pressed(GAME_SETTINGS.ACTION_MOVE_DOWN):
		direction.y += 1.0
	direction = direction.normalized()
	velocity = direction * move_speed
	if abs(direction.x) > 0.01:
		facing_sign = sign(direction.x)
	_set_running(direction.length_squared() > 0.0)
	move_and_slide()
	_clamp_to_movement_bounds()

func stop_movement() -> void:
	velocity = Vector2.ZERO
	_set_running(false)

func _set_running(running: bool) -> void:
	if role_visual != null and role_visual.has_method("set_moving"):
		role_visual.set_moving(running, Vector2(facing_sign, 0.0))

func _clamp_to_movement_bounds() -> void:
	if movement_bounds.size.x <= 0.0 or movement_bounds.size.y <= 0.0:
		return
	global_position = Vector2(
		clamp(global_position.x, movement_bounds.position.x, movement_bounds.position.x + movement_bounds.size.x),
		clamp(global_position.y, movement_bounds.position.y, movement_bounds.position.y + movement_bounds.size.y)
	)

func _apply_camera_limits() -> void:
	if camera == null or movement_bounds.size.x <= 0.0 or movement_bounds.size.y <= 0.0:
		return
	camera.limit_left = floori(movement_bounds.position.x)
	camera.limit_top = floori(movement_bounds.position.y)
	camera.limit_right = ceili(movement_bounds.position.x + movement_bounds.size.x)
	camera.limit_bottom = ceili(movement_bounds.position.y + movement_bounds.size.y)
