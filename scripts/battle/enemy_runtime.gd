extends RefCounted
var id := 0
var kind := "melee"
var position := Vector2.ZERO
var hp := 40.0
var max_hp := 40.0
var radius := 14.0
var speed := 65.0
var damage := 12.0
var xp := 3.0
var dead := false
var slow := 0.0
var slow_time := 0.0
var cooldown := 1.0
var windup := 0.0
var aim := Vector2.RIGHT
var attack := ""
var attack_index := 0
var flash := 0.0
var attack_cycle: Array = ["strike"]
var attack_range := 46.0
var attack_delay := 0.4
var recovery := 1.25
var blast_radius := 145.0

func _init(key: int, type: String, point: Vector2) -> void:
	id = key
	kind = type
	position = point
	if type == "ranged": hp = 32; speed = 46; damage = 13; xp = 4
	if type in ["card_elite", "equipment_elite"]: hp = 280; radius = 23; speed = 72; damage = 23; xp = 18
	if type == "boss": hp = 550; radius = 30; speed = 53; damage = 30; xp = 30
	if type == "charger": hp = 62; radius = 16; speed = 92; damage = 17; xp = 5
	if type == "guard": hp = 105; radius = 19; speed = 43; damage = 18; xp = 6
	attack_range = radius + 32
	if type in ["card_elite", "equipment_elite", "guard"]: recovery = 2.2
	if type == "ranged": attack_cycle = ["shot"]; attack_range = 310; attack_delay = .65; recovery = 2.2
	if type == "charger": attack_cycle = ["charge"]; attack_range = 270; attack_delay = .8; recovery = 2.4
	if type == "boss": attack_cycle = ["charge", "fan"]; attack_range = 310; attack_delay = .95; recovery = 2.2
	max_hp = hp
