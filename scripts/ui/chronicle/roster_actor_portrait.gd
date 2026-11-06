extends Node2D
## Independently drawn, character-specific small HUD portrait.
@export var character_id := "F11"

func _ready() -> void:
	$Sprite2D.texture = load("res://assets/players/chronicle-cast/" + character_id + "/head.png")
