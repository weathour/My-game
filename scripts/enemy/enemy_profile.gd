class_name EnemyProfile
extends Resource

@export var archetype: String = "chaser"
@export var behavior: String = "chaser"
@export var secondary_behavior: String = ""
@export var boss_name: String = ""
@export var max_health: float = 20.0
@export var speed: float = 80.0
@export var touch_damage: float = 10.0
@export var contact_radius: float = 36.0
@export var body_collision_radius: float = -1.0
@export var reward_tier: int = 1
@export var experience_reward: int = 10
@export var scale: float = 1.0
@export var display_color: Color = Color(0.34, 0.8, 1.0, 1.0)
@export var visual_scene: PackedScene
@export var extra: Dictionary = {}


func to_dictionary() -> Dictionary:
	var data := {
		"archetype": archetype,
		"behavior": behavior,
		"max_health": max_health,
		"speed": speed,
		"touch_damage": touch_damage,
		"contact_radius": contact_radius,
		"body_collision_radius": body_collision_radius,
		"reward_tier": reward_tier,
		"experience_reward": experience_reward,
		"scale": scale,
		"color": display_color
	}
	if secondary_behavior != "":
		data["secondary_behavior"] = secondary_behavior
	if boss_name != "":
		data["boss_name"] = boss_name
	if visual_scene != null:
		data["visual_scene"] = visual_scene
	for key in extra.keys():
		data[key] = extra[key]
	return data
