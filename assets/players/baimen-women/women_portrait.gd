extends Node2D
@export var character_id := "F02"

func _ready() -> void:
	$Sprite2D.texture = load("res://assets/players/baimen-women/%s/head.png" % character_id)
